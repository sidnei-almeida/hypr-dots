# Idioma para os scripts do rice. NÃO é executável: para ser LIDO com
# `source`, e por isso não tem shebang nem `set -e` (herdaria o do
# chamador e mudaria o comportamento dele).
#
#   source "$HOME/.local/bin/rice-idioma.sh"
#   notify-send "$(txt dock.title)" "$(txt dock.pinned "$app")"
#
# Mesmos dicionários do QML — ~/.config/rice/idioma/<código>.json. Um só
# lugar para traduzir a interface inteira, barra e scripts juntos; dois
# arquivos separados sairiam do compasso na primeira revisão de texto.
#
# ── POR QUE `source` E NÃO UM COMANDO `rice-txt` ─────────────────
#
# Um comando por string custaria um processo e uma leitura de JSON a cada
# frase. Um script como o rice-audio dispara várias notificações seguidas;
# lido de uma vez, o dicionário inteiro fica na memória do próprio script
# e as consultas seguintes são acesso a array.

# `-g` porque isto roda dentro de uma função `source`ada em alguns
# scripts, e sem o global o array morre ao sair dela.
declare -gA RICE_TXT=()

_rice_idioma_carregar() {
    local dir="$HOME/.config/rice/idioma"

    # As DUAS PRIMEIRAS LETRAS do locale, sem lista de casos — mesma regra
    # do Idioma.qml, e divergir aqui daria barra num idioma e notificação
    # em outro.
    #
    # `pt_BR.UTF-8` vira "pt", `es_MX.UTF-8` vira "es". Acrescentar um
    # idioma é largar um `<código>.json` na pasta; nenhum script muda.
    #
    # Código sem dicionário cai em inglês sozinho: o laço abaixo só lê o
    # arquivo se ele existir, e o inglês já entrou antes.
    local loc="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    local cod="${loc:0:2}"
    cod="${cod,,}"
    [[ $cod =~ ^[a-z]{2}$ ]] || cod="en"

    command -v jq >/dev/null 2>&1 || return 0

    # O inglês entra PRIMEIRO e o idioma ativo por cima. Assim, chave que
    # ainda não foi traduzida aparece em inglês em vez de aparecer como
    # chave crua na notificação.
    local arq
    for arq in "$dir/en.json" "$dir/$cod.json"; do
        [[ -f $arq ]] || continue
        while IFS=$'\t' read -r k v; do
            [[ -n $k ]] && RICE_TXT["$k"]="$v"
        done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$arq" 2>/dev/null)
    done
}
_rice_idioma_carregar

# txt <chave> [substituto]
#
# Sem tradução, devolve a PRÓPRIA CHAVE. É feio de propósito: buraco de
# tradução tem de aparecer na tela, não virar notificação vazia.
txt() {
    local s="${RICE_TXT[$1]:-$1}"
    [[ $# -gt 1 ]] && s="${s//\{0\}/$2}"
    printf '%s' "$s"
}
