# Pastas do usuário para os scripts do rice. NÃO é executável: para ser
# LIDO com `source`, e por isso não tem shebang nem `set -e` (herdaria o
# do chamador e mudaria o comportamento dele).
#
#   source "$HOME/.local/bin/rice-pastas.sh"
#   dir="$(rice_pasta PICTURES)/Screenshots"
#
# ── POR QUE ISTO EXISTE ─────────────────────────────────────────
#
# O rice traduz a INTERFACE (ver rice-idioma.sh), e por engano tratava o
# nome das PASTAS como se fosse texto de interface também. Os scripts
# traziam o caminho em português cravado, com o inglês como plano B:
#
#     dir="$HOME/Imagens/Screenshots"
#     [[ -d "$HOME/Pictures" && ! -d "$HOME/Imagens" ]] && dir="$HOME/Pictures/..."
#
# Isso está errado duas vezes.
#
# Primeiro porque o nome da pasta não é decisão do rice: quem decide é o
# xdg-user-dirs, que escreve ~/.config/user-dirs.dirs conforme o locale
# na criação da conta. Nesta máquina o locale é en_US e o sistema pediu
# `Pictures` — o rice ignorou e usou `Imagens`.
#
# Segundo, e pior, porque a condição se auto-sabota: ela só aceita o
# inglês enquanto a pasta em português NÃO existir. Como o próprio rice
# criava `~/Imagens` no primeiro screenshot, a partir dali a condição era
# falsa para sempre. O resultado foi uma `~/Imagens` paralela à `Pictures`
# do sistema, com os prints indo para a errada e a certa vazia.
#
# `xdg-user-dir` é o programa oficial para essa pergunta e já lê o
# user-dirs.dirs, então não há o que adivinhar nem lista de idiomas para
# manter aqui.
#
# ── SOBRE AS SUBPASTAS (Screenshots, Wallpapers, Recordings) ─────
#
# Essas o rice cria mesmo, e ficam em INGLÊS, fixas — de propósito.
# Traduzi-las repetiria o bug original numa escala pior: trocar o idioma
# da interface passaria a criar `Capturas` ao lado de `Screenshots`, e os
# arquivos antigos sumiriam de vista. Nome de pasta é endereço no disco,
# não legenda de botão.

# Devolve o caminho de uma pasta XDG do usuário.
#   $1  chave (PICTURES, VIDEOS, DOCUMENTS, DOWNLOAD, MUSIC, DESKTOP)
#   $2  nome de reserva, se o sistema não souber responder (opcional)
#
# `xdg-user-dir` devolve o próprio $HOME quando a chave é desconhecida —
# e gravar screenshot solto no home seria pior que o bug que isto conserta.
# Por isso esse caso cai na reserva em vez de ser aceito.
rice_pasta() {
    local chave="$1" reserva="${2:-$1}" dir=""

    if command -v xdg-user-dir >/dev/null 2>&1; then
        dir="$(xdg-user-dir "$chave" 2>/dev/null)"
    fi

    [[ -z $dir || $dir == "$HOME" || $dir == "$HOME/" ]] && dir="$HOME/$reserva"

    printf '%s' "$dir"
}
