#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────┐
# │  PraXe — instalação numa máquina limpa.                       │
# └──────────────────────────────────────────────────────────────┘
#
#   ./install.sh                 instala tudo
#   ./install.sh --sem-pacotes   só as configurações
#   ./install.sh --sem-papeis    sem copiar os papéis de parede
#   ./install.sh --seco          mostra o que faria, sem tocar em nada
#
# ── DUAS DECISÕES QUE EXPLICAM O RESTO ──────────────────────────
#
# 1. LIGAÇÃO SIMBÓLICA, NÃO CÓPIA.
#
#    O repositório VIRA a configuração viva: `~/.config/hypr` passa a
#    apontar para `config/hypr` daqui. Assim o que você editar amanhã já
#    está versionado, sem um passo de "copiar de volta para o repo" que
#    ninguém lembra de fazer — e é justamente esse passo esquecido que
#    transforma dotfiles em museu.
#
#    Os papéis de parede e as entradas .desktop são CÓPIA, não ligação:
#    são dados que você mexe por fora (baixa um papel novo, o Steam
#    escreve um atalho), e ligar a pasta inteira faria o repositório
#    crescer sozinho sem você pedir.
#
# 2. O REPOSITÓRIO GUARDA FONTE, NUNCA ARTEFATO GERADO.
#
#    O `rice-theme` escreve catorze arquivos a cada troca de tema —
#    hyprlock.conf, colors.lua, fuzzel.ini, kitty/colors.conf, GTK,
#    kdeglobals e companhia. Nenhum deles está aqui, e é de propósito:
#    versionar saída de gerador é garantir conflito em toda troca de tema
#    e arquivo velho sobrevivendo a um `git pull`.
#
#    Por isso o último passo desta instalação é rodar `rice-theme set`.
#    É ele que materializa os catorze a partir da paleta — e é por isso
#    que a instalação não está completa até ele rodar.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.config/praxe-backup-$(date +%Y%m%d-%H%M%S)"
SECO=0; SEM_PACOTES=0; SEM_PAPEIS=0

verde=$'\e[32m'; verm=$'\e[31m'; ama=$'\e[33m'; azul=$'\e[34m'; forte=$'\e[1m'; zero=$'\e[0m'
ok()    { printf '%s  ✓%s %s\n' "$verde" "$zero" "$1"; }
aviso() { printf '%s  !%s %s\n' "$ama" "$zero" "$1"; }
erro()  { printf '%s  ✗%s %s\n' "$verm" "$zero" "$1" >&2; }
etapa() { printf '\n%s%s▸ %s%s\n' "$forte" "$azul" "$1" "$zero"; }

for arg in "$@"; do
    case "$arg" in
        --seco)        SECO=1 ;;
        --sem-pacotes) SEM_PACOTES=1 ;;
        --sem-papeis)  SEM_PAPEIS=1 ;;
        -h|--help)     sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             erro "argumento desconhecido: $arg"; exit 1 ;;
    esac
done

exec_ou_mostra() {
    if (( SECO )); then printf '      %s\n' "$*"; else "$@"; fi
}

# ── Verificações ────────────────────────────────────────────────
#
# Falhar aqui, cedo e explicando, é muito melhor que falhar no meio com
# metade das ligações feitas e a sessão num estado que ninguém entende.
etapa "Verificando o terreno"

[[ $EUID -ne 0 ]] || { erro "não rode como root — as configurações são do SEU usuário"; exit 1; }
command -v pacman >/dev/null || { erro "isto é feito para Arch (ou derivado): não achei o pacman"; exit 1; }
ok "Arch com pacman, usuário $USER"

if ! command -v paru >/dev/null 2>&1; then
    aviso "sem 'paru' — os $(wc -l < "$REPO/packages/aur.txt") pacotes do AUR serão pulados"
    aviso "instale depois com: sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru.git"
fi

# ── Pacotes ─────────────────────────────────────────────────────
if (( ! SEM_PACOTES )); then
    etapa "Instalando pacotes"

    # `--needed` para não reinstalar o que já está lá: numa máquina que já
    # tem metade dos pacotes, sem ele o pacman baixa tudo de novo à toa.
    n=$(wc -l < "$REPO/packages/pacman.txt")
    printf '      %s pacotes dos repositórios oficiais\n' "$n"
    exec_ou_mostra sudo pacman -S --needed --noconfirm - < "$REPO/packages/pacman.txt" || {
        erro "o pacman falhou — veja a saída acima e rode de novo com --sem-pacotes se quiser seguir"
        exit 1
    }
    ok "pacotes oficiais"

    # ── Ferramentas de desenvolvimento ──────────────────────────
    #
    # Lista à parte porque o `pacman.txt` só tem pacotes EXPLÍCITOS, e o
    # nodejs/npm desta máquina entraram como dependência de outra coisa —
    # numa instalação nova eles só apareceriam por acaso. Ver a nota no
    # topo do `packages/dev.txt`.
    #
    # O `grep` tira os comentários: o pacman lê a lista pela entrada
    # padrão e trataria cada `#` como nome de pacote.
    if [[ -s $REPO/packages/dev.txt ]]; then
        mapfile -t DEV < <(grep -vE '^\s*(#|$)' "$REPO/packages/dev.txt")
        printf '      %s ferramentas de desenvolvimento: %s\n' "${#DEV[@]}" "${DEV[*]}"
        exec_ou_mostra sudo pacman -S --needed --noconfirm "${DEV[@]}" || \
            aviso "alguma ferramenta de desenvolvimento falhou"
        ok "ferramentas de desenvolvimento"
    fi

    if command -v paru >/dev/null 2>&1 && [[ -s $REPO/packages/aur.txt ]]; then
        printf '      %s pacotes do AUR\n' "$(wc -l < "$REPO/packages/aur.txt")"
        exec_ou_mostra paru -S --needed --noconfirm - < "$REPO/packages/aur.txt" || \
            aviso "algum pacote do AUR falhou — siga e resolva depois, nada aqui depende deles para subir"
        ok "pacotes do AUR"
    fi
else
    etapa "Pacotes (pulado por --sem-pacotes)"
fi

# ── Ligações ────────────────────────────────────────────────────
etapa "Ligando as configurações"

# Move o que existir para o backup ANTES de ligar. Nunca sobrescreve nada
# em silêncio: a pasta que você está prestes a perder pode ser a única
# cópia de uma configuração de meses.
ligar() {
    local origem="$1" destino="$2"

    [[ -e $origem ]] || { aviso "não existe no repo: ${origem#$REPO/}"; return 0; }

    # Já ligado para cá? Nada a fazer — o script tem de poder rodar duas
    # vezes seguidas sem estragar o que fez na primeira.
    if [[ -L $destino && $(readlink -f "$destino") == "$(readlink -f "$origem")" ]]; then
        ok "${destino/#$HOME/\~} (já ligado)"
        return 0
    fi

    if [[ -e $destino || -L $destino ]]; then
        exec_ou_mostra mkdir -p "$BACKUP/$(dirname "${destino#$HOME/}")"
        exec_ou_mostra mv "$destino" "$BACKUP/${destino#$HOME/}"
        aviso "${destino/#$HOME/\~} → backup"
    fi

    exec_ou_mostra mkdir -p "$(dirname "$destino")"
    exec_ou_mostra ln -s "$origem" "$destino"
    ok "${destino/#$HOME/\~}"
}

ligar "$REPO/config/hypr"  "$HOME/.config/hypr"
ligar "$REPO/config/rice"  "$HOME/.config/rice"
ligar "$REPO/config/kitty" "$HOME/.config/kitty"

# Os scripts vão um a um, e não pela pasta inteira: `~/.local/bin` é do
# usuário e costuma ter coisa que não é do rice. Ligar a pasta toda
# sequestraria tudo que estivesse lá.
exec_ou_mostra mkdir -p "$HOME/.local/bin"
for s in "$REPO"/bin/*; do
    ligar "$s" "$HOME/.local/bin/$(basename "$s")"
done

# VSCode: só os dois arquivos que são seus. O resto de ~/.config/Code é
# cache, histórico e estado de janela — nada disso se leva para outra
# máquina, e levar atrapalha.
if [[ -f $REPO/config/Code/User/settings.json ]]; then
    ligar "$REPO/config/Code/User/settings.json" "$HOME/.config/Code/User/settings.json"
    [[ -f $REPO/config/Code/User/keybindings.json ]] && \
        ligar "$REPO/config/Code/User/keybindings.json" "$HOME/.config/Code/User/keybindings.json"
fi

# ── Papéis de parede ────────────────────────────────────────────
if (( ! SEM_PAPEIS )); then
    etapa "Papéis de parede"

    # `xdg-user-dir` e não `~/Pictures` cravado: o nome da pasta de imagens
    # depende do idioma do sistema (Imagens, Pictures, Imágenes). É a mesma
    # regra que o rice segue por dentro — quem manda é o xdg-user-dirs.
    PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
    DEST="$PICTURES/Wallpapers"
    exec_ou_mostra mkdir -p "$DEST"
    # `-n` para não sobrescrever: se você já tem papéis lá, eles ficam.
    exec_ou_mostra cp -rn "$REPO/wallpapers/." "$DEST/"
    ok "${DEST/#$HOME/\~} ($(ls "$REPO/wallpapers" | wc -l) arquivos)"
else
    etapa "Papéis de parede (pulado por --sem-papeis)"
fi

# ── Entradas .desktop ───────────────────────────────────────────
etapa "Atalhos de aplicativo"
exec_ou_mostra mkdir -p "$HOME/.local/share/applications"
exec_ou_mostra cp -n "$REPO"/apps/applications/*.desktop "$HOME/.local/share/applications/" 2>/dev/null || true
ok "$(ls "$REPO/apps/applications" 2>/dev/null | wc -l) atalhos"

# ── Extensões do VSCode ─────────────────────────────────────────
if command -v code >/dev/null 2>&1 && [[ -s $REPO/packages/vscode-extensions.txt ]]; then
    etapa "Extensões do VSCode"
    while read -r ext; do
        [[ -n $ext ]] || continue
        exec_ou_mostra code --install-extension "$ext" --force >/dev/null 2>&1 || aviso "falhou: $ext"
    done < "$REPO/packages/vscode-extensions.txt"
    ok "$(wc -l < "$REPO/packages/vscode-extensions.txt") extensões"
fi

# ── O tema, que materializa os arquivos gerados ─────────────────
#
# ESTE PASSO NÃO É ENFEITE. Os catorze arquivos que o rice-theme escreve
# não estão no repositório (ver a nota no topo), então até aqui a máquina
# tem os GERADORES mas não a saída deles: sem isto, o hyprlock não tem
# config, o kitty não tem paleta e o Hyprland não acha `colors.lua`.
etapa "Gerando os arquivos de tema"

if (( SECO )); then
    printf '      rice-theme set <tema atual ou samurai>\n'
else
    export PATH="$HOME/.local/bin:$PATH"
    TEMA="$(cat "$HOME/.config/rice/current" 2>/dev/null || echo samurai)"
    [[ -f "$HOME/.config/rice/themes/$TEMA.sh" ]] || TEMA=samurai
    if rice-theme set "$TEMA" >/dev/null 2>&1; then
        ok "tema '$TEMA' aplicado — colors.lua, hyprlock.conf, kitty, GTK e o resto"
    else
        erro "o rice-theme falhou. Rode à mão para ver o motivo:  rice-theme set $TEMA"
    fi
fi

# ── Fim ─────────────────────────────────────────────────────────
etapa "Pronto"
[[ -d $BACKUP ]] && printf '      backup do que havia antes: %s\n' "${BACKUP/#$HOME/\~}"
cat <<FIM

      Falta o que precisa de root ou de sessão nova:

        1. O cofre de senhas destravar junto com a tela:
             rice-keyring          (diz o que falta e dá o comando com sudo)

        2. Entrar na sessão do Hyprland para valer.
           O que está rodando agora não conhece nada disto.

      Depois, dentro da sessão:
        rice-theme menu     trocar de tema
        rice-anim           ritmo e estilo das animações
        SUPER+ALT+SPACE     painel de aparência

FIM
