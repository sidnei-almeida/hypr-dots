# Gruvbox Dark — vestido para a foto da oficina.
#
# A imagem anterior (arte do cassete VHS) era vetor chapado: preto,
# listras de areia e uma esfera. Bonita e sem profundidade — e o tema em
# cima dela ficava com a mesma cara. Esta é uma FOTO, com sombra funda,
# luz de janela e superfície gasta, e é isso que o tema agora acompanha.
#
# A foto é território nativo do Gruvbox, e dá para medir: os neutros
# OFICIAIS dele já caíam a dE 6–12 das cores da cena antes de eu encostar
# em nada (bg2 a 7.3 do cinza da oficina, fg4 a 5.9 da madeira da
# bancada, gray a 6.2 do mauve das sombras). Não houve conversão a fazer;
# houve aproximação fina.
#
# A SURPRESA ÚTIL: as sombras desta foto são VIOLETA-AZULADAS (#1e1827),
# não marrons. Um galpão escuro com luz fria entrando de lado não produz
# preto quente — produz ameixa. Isso reordenou duas escolhas:
#
#   · o fundo saiu do bg0_h (#1d2021, quase neutro) e foi para o violeta
#     da sombra real, a dE 4;
#   · o `purple` do ACCENT2, que no cassete era um chute educado, aqui
#     tem lastro: os meios-tons da cena são ameixa e mauve.
NAME="Gruvbox Dark"

BG=1c1a24        # a sombra funda do galpão (#1e1827), dE 4
BG_ALT=4a3a44    # a sombra MÉDIA da foto, amostrada exata (dE 0).
                 # Também é o que dá profundidade: 1.62 de contraste
                 # contra o fundo, ante 1.44 da primeira tentativa.
                 # Aqui os dois objetivos apontaram para a mesma cor —
                 # o valor mais fiel à foto é o que separa melhor
FG=ebdbb2        # fg1 oficial — o creme do corpo do robô (dE 10)
MUTED=a89984     # fg4 oficial — a madeira da bancada (dE 6)
DIM=5e5154       # o cinza morno das caixas ao fundo (dE 2)

ACCENT=fe8019    # orange — o peito laranja do robô e a ferrugem do carro.
                 # O laranja da foto (#f59e6c) é desbotado, de brinquedo
                 # velho; o acento é mais saturado de propósito, porque
                 # marcar exige estar um passo à frente da cena
ACCENT2=d3869b   # purple — as sombras de ameixa e o mauve dos meios-tons

OK=b8bb26        # green
WARN=fabd2f      # yellow — a luz quente na madeira
ERR=fb4934       # red

# Cor das pastas do Papirus que acompanha este tema.
#
# palebrown (#d1bfae) ganhou em todos os critérios de uma vez: dE 5.4 do
# creme do robô, 9.3 da madeira da bancada, 9.6:1 de contraste, e a dE 71
# do acento — longe o bastante para não virar o farol laranja repetido em
# toda janela.
PASTAS=palebrown

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
#
# Recortado de 7680x2160 (32:9) para 3440x1440 na janela +1400+0. É o
# único enquadramento em que as TRÊS peças cabem: a frente do carro
# entrando pela esquerda, o robô fora do centro, e a TV inteira. Cortes
# mais à esquerda partem a TV ao meio; mais à direita perdem o carro e
# jogam o robô para debaixo do notch.
#
# O papel antigo (gruvbox-vhs.jpg) segue na pasta, disponível no seletor.
WALLPAPER=gruvbox-oficina.jpg
