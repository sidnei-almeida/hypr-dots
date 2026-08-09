# Catppuccin Mocha — ajustado para o papel viperpuccin.
#
# O Catppuccin oficial é uma paleta, não um tema de tela: ele não diz
# QUAL das dezesseis cores manda. A versão anterior daqui elegia o
# `blue` (#89b4fa) como acento, o que é a escolha padrão da comunidade e
# estava certa enquanto não havia papel de parede.
#
# Com o viperpuccin no fundo ela deixou de estar. Na imagem NÃO EXISTE
# azul: é uma serpente violeta atravessando um campo dourado sob céu
# rosa. Um acento azul sobre isso não combina nem contrasta — só flutua,
# como se a barra fosse de outro tema.
#
# O que mudou, e só isso:
#   ACCENT  blue #89b4fa  ->  peach #fab387   (o olho âmbar e o campo)
#   BG      #181825       ->  #191322          (mantle puxado à berinjela)
#   BG_ALT/MUTED/DIM: mesma torção de matiz do BG, para as superfícies
#                     não ficarem azuis sobre um fundo que virou roxo.
#
# Todas as cores VIVAS continuam sendo hex oficial do Catppuccin Mocha
# (peach, mauve, green, yellow, red). A adaptação mora nos neutros e na
# escolha de papel de cada uma — não em tinta inventada.
#
# Por que o acento é o OURO e não o violeta da serpente:
# mesmo raciocínio do Maré. O violeta é a massa da imagem e já é o
# fundo; destacar com ele não destacaria nada. O ouro aparece como luz —
# no olho, na borda das escamas, no campo — e é isso que um acento faz.
NAME="Catppuccin Mocha"

# As duas primeiras linhas foram AFASTADAS uma da outra numa segunda
# passada, e o motivo vale registrar.
#
# Na primeira versão o fundo era o mantle (#181825) e a superfície o
# #342b4a — 1.37 de contraste entre os dois. Está dentro da faixa dos
# outros temas (1.26 a 1.47), mas o conjunto lia como CHAPADO: painel,
# cartão e fundo quase no mesmo plano, sem hierarquia visível.
#
# Agora o fundo desce até a altura do crust e a superfície sobe até a do
# surface1, o que leva a separação a 1.62 — mais do que qualquer outro
# tema daqui. É deliberado: esta paleta é a de croma mais alto do
# conjunto, e cor saturada num fundo pouco separado achata tudo. Quanto
# mais viva a paleta, mais a estrutura precisa aparecer por luminância.
BG=140f1c        # crust (#11111b) puxado para a berinjela da sombra
BG_ALT=3d3357    # surface1 em violeta: a escama fora da luz
FG=cdd6f4        # text oficial. Frio de propósito: é o único descanso
                 # numa tela em que todo o resto é quente ou roxo
MUTED=8a80a8     # overlay violeta — o ventre malva da serpente
DIM=453d5c       # surface1 torcido, traço apagado ainda dentro do roxo

ACCENT=fab387    # peach — o olho âmbar, e a luz rasante no campo
ACCENT2=cba6f7   # mauve — as escamas; a segunda voz é a própria bicha

OK=a6e3a1        # green oficial — o verde dos talos entre as margaridas
WARN=f9e2af      # yellow oficial — capim seco
ERR=f38ba8       # red oficial. Fica: erro precisa gritar, e o rosa do
                 # céu (mais próximo da imagem) é fraco demais para isso

# Cor das pastas do Papirus que acompanha este tema.
# Violeta, e não pêssego. O acento é ouro, e pasta dourada sobre um
# desktop roxo vira farol repetido — o mesmo erro que o Samurai recusa
# ao não usar o paleorange. O `violet` do Papirus (#7e57c2) é quase um
# grau mais claro da própria escama da serpente (#593fa2): pertence à
# massa da imagem em vez de competir com o acento.
PASTAS=violet

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
# Recortado de 7680x2160 (32:9) para 3440x1440 pegando a janela
# +976+0: é o único enquadramento em que a cabeça cai no terço direito
# COM o olho inteiro e o corpo ainda entrando pela esquerda. Cortes mais
# à direita espremem o focinho contra a borda; mais à esquerda centralizam
# a cabeça e matam a diagonal.
WALLPAPER=viperpuccin.jpg
