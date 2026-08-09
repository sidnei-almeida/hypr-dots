<div align="center">

# PraXe

**Um rice de Hyprland que se reconstrói inteiro a partir de uma paleta.**

Sete temas, uma barra em Quickshell, tela de bloqueio, dock, lançador e
trinta e sete utilitários — todos lendo as mesmas dez cores.

![Hyprland](https://img.shields.io/badge/Hyprland-0.56-58E1FF?style=flat-square&logo=hyprland&logoColor=white)
![Quickshell](https://img.shields.io/badge/Quickshell-QML-41CD52?style=flat-square&logo=qt&logoColor=white)
![Arch](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)
![Lua](https://img.shields.io/badge/config-Lua-2C2D72?style=flat-square&logo=lua&logoColor=white)
![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-black?style=flat-square)

</div>

---

## Instalação

```bash
git clone https://github.com/sidnei-almeida/hypr-dots.git ~/Documents/GitHub/hypr-dots
cd ~/Documents/GitHub/hypr-dots
./install.sh
```

Antes de confiar, veja o que ele faria sem tocar em nada:

```bash
./install.sh --seco
```

| Argumento | Efeito |
|---|---|
| `--seco` | Mostra cada comando, não executa nenhum |
| `--sem-pacotes` | Só as configurações — nada de `pacman` |
| `--sem-papeis` | Não copia os 40 papéis de parede |

O que existia antes **nunca é sobrescrito em silêncio**: tudo vai para
`~/.config/praxe-backup-<data>/` antes de qualquer ligação. E o script é
idempotente — rodar duas vezes seguidas não estraga o que fez na primeira.

---

## Duas decisões que explicam o resto

### 1. O repositório *é* a configuração viva

`~/.config/hypr` e `~/.config/rice` viram **ligações simbólicas** para
`config/` daqui. Não há cópia, e por isso não há o passo de "copiar de
volta para o repo" que ninguém lembra de fazer — que é exatamente o passo
esquecido que transforma dotfiles em museu.

Editou hoje, está versionado agora.

> Papéis de parede e atalhos `.desktop` são a exceção: vão como cópia.
> São dados que você mexe por fora (baixa um papel, o Steam escreve um
> atalho), e ligar a pasta faria o repositório crescer sem você pedir.

### 2. Aqui mora fonte, nunca artefato gerado

O `rice-theme` **escreve catorze arquivos** a cada troca de tema:

```
hyprlock.conf · colors.lua · decor.lua · opacity.lua · hyprpaper.conf
fuzzel.ini · kitty/colors.conf · gtk-3.0/gtk.css · gtk-4.0/gtk.css
gtk-*/settings.ini · kdeglobals · fastfetch/config.jsonc · mpv.conf · imv/config
```

Nenhum deles está no repositório, e é de propósito: versionar saída de
gerador é garantir um diff sujo em toda troca de tema, e um `git pull` que
traz a paleta de outra máquina por cima da sua.

**Consequência prática:** logo depois de clonar, a máquina tem os
geradores mas não a saída deles. Por isso o último passo do `install.sh` é
rodar `rice-theme set` — e a instalação não está completa sem ele.

---

## O que tem dentro

```
hypr-dots/
├── install.sh              instalação numa máquina limpa
├── config/
│   ├── hypr/               Hyprland em Lua, hypridle, 7 shaders de tela
│   ├── rice/
│   │   ├── themes/         7 paletas — uma por arquivo
│   │   ├── shell/          a barra em Quickshell (20 arquivos, 7.9k linhas)
│   │   ├── idioma/         pt · en · es
│   │   └── assets/
│   ├── kitty/
│   └── Code/User/          settings e keybindings do VSCode
├── bin/                    37 utilitários rice-*
├── wallpapers/             40 imagens
├── apps/applications/      atalhos .desktop
└── packages/               pacman · AUR · dev · extensões do VSCode
```

### Por que `packages/dev.txt` existe separado

`pacman.txt` é gerado por `pacman -Qqen`, que lista apenas os pacotes
**explícitos**. O `nodejs` e o `npm` desta máquina entraram como
*dependência* de outro pacote — então não apareciam ali, e numa instalação
nova só existiriam se algum outro pacote os puxasse por acaso.

É uma falha silenciosa: no dia em que a árvore de dependências mudar, a
máquina nova sobe sem Node e a lista continua parecendo completa.
`dev.txt` registra a **intenção** (`nodejs`, `npm`, `typescript`) em vez do
efeito colateral.

> O TypeScript vem do repositório do Arch, não de `npm i -g`. O prefixo do
> npm aqui é `/usr`, então todo global exigiria `sudo` e escreveria dentro
> do território do pacman. Se precisar de globais do npm, mude o prefixo
> antes: `npm config set prefix "$HOME/.local"`.

### O Hyprland é configurado em **Lua**, não em hyprlang

Não existe `hyprland.conf`. O ponto de entrada é `hyprland.lua`, que dá
`require` nos módulos. Isso muda o `hyprctl dispatch`, e a forma clássica
falha:

```bash
hyprctl dispatch workspace 3                    # ✗ erro de sintaxe Lua
hyprctl dispatch "hl.dsp.focus({ workspace = 3 })"   # ✓
```

---

## Temas

`Catppuccin Mocha` · `Everforest Dark` · `Gruvbox Dark` · `Hotrod` ·
`Maré` · `Nord` · `Samurai`

Cada tema é um arquivo com dez cores, a cor de pasta do Papirus e um papel
de parede:

```bash
BG · BG_ALT · FG · MUTED · DIM · ACCENT · ACCENT2 · OK · WARN · ERR
PASTAS · WALLPAPER · NAME
```

Nenhuma cor é inventada: sai da imagem do papel de parede ou de uma paleta
oficial, e a escolha se justifica por **ΔE em CIELAB**. Não há campo de
borda — nenhum tema pode desenhar contorno em nada, e isso é regra de
identidade, não omissão.

```bash
rice-theme menu          # escolher pela interface
rice-theme set nord      # direto
rice-theme current       # qual está em uso
rice-cores               # criar um tema a partir de uma imagem
```

---

## Comandos do dia a dia

| Comando | O que faz |
|---|---|
| `rice-theme` | Troca de tema e regera os catorze arquivos |
| `rice-cores` | Cria um tema novo a partir de uma imagem |
| `rice-anim` | Ritmo, quique (ζ) e estilo das animações |
| `rice-wallpaper` | Troca o papel de parede e recalcula a paleta |
| `rice-keyring` | Faz o desbloqueio da tela destravar o cofre de senhas |
| `rice-vivido` | Realce de cor por shader, na tela inteira |
| `rice-icons` · `rice-folders` | Tema de ícones e cor das pastas |
| `rice-screenshot` · `rice-record` · `rice-ocr` | Captura, gravação e texto de imagem |
| `rice-keybindings` | Lista todos os atalhos |

### Animações

As curvas são **molas** (`type = "spring"`), não bezier — o mesmo modelo do
`spring(response:dampingFraction:)` do SwiftUI. A diferença que se sente:
quando o alvo muda no meio do caminho, a mola preserva a velocidade atual
em vez de reiniciar do zero.

```bash
rice-anim ritmo 0.8      # 20% mais rápido, a família inteira
rice-anim quique 0.85    # menos overshoot (1.0 = nenhum)
rice-anim estilo genio   # mola · cortina · deslize · genio
```

Rigidez e atrito nunca são digitados à mão: saem do período `T` e do
amortecimento `ζ`, calculados no `looknfeel.lua`.

---

## Depois de instalar

**1. O cofre de senhas.** Esta máquina entra por autologin — login sem
senha significa que o PAM não tem o que repassar ao gnome-keyring no boot,
e cada aplicativo passa o dia pedindo a senha do cofre por conta própria. A
única autenticação real do dia é a tela de bloqueio, então é ela que
destrava:

```bash
rice-keyring     # diz o que falta e imprime o comando com sudo
```

**2. Entrar na sessão do Hyprland.** A sessão em execução não conhece nada
do que acabou de ser ligado.

---

## Requisitos

Arch Linux (ou derivado) com `pacman`. O `install.sh` cuida de 156 pacotes
oficiais e 8 do AUR — para estes últimos é preciso ter o `paru`:

```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si
```

Sem `paru`, o script avisa e segue: nada aqui depende do AUR para subir.

---

## Convenções do código

Todo arquivo é comentado **em português**, e o comentário explica o
**porquê** da decisão — e o que estava errado antes — em vez de descrever o
que o código faz. Comentário que narra a linha abaixo dele envelhece junto
com ela; comentário que guarda o motivo sobrevive à reescrita.

Há armadilhas documentadas no próprio código que custaram sessões inteiras
para achar. Duas que valem ser lidas antes de mexer:

- **`Dock.qml`** — por que o model de um `Repeater` é lista de *strings* e
  nunca de objetos. Guardar `Toplevel*` num mapa derruba o Quickshell com
  SIGSEGV: o delegate é *incubado*, e o ponteiro pode morrer no intervalo.
- **`rice-keyring`** — por que a linha do PAM é uma só, de `auth`. O
  hyprlock chama apenas `pam_authenticate()`; qualquer linha `session`
  naquele arquivo nunca executa.

---

<div align="center">
<sub>MIT · feito para uma tela de 3440×1440</sub>
</div>
