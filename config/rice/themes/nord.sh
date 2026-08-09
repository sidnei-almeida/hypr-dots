# Nord — ajustado para o papel da lua sobre as nuvens.
#
# Este é o caso mais fácil dos temas com papel, e vale entender por quê:
# a foto JÁ É Nord. Céu #1a2026, névoa #1d374a, nuvem sob a lua #6b91a6,
# limbo #a8bdc8 — tudo azul-aço dessaturado, que é exatamente a matéria
# da paleta. Não houve torção a fazer; houve alinhamento.
#
# Por isso os neutros aqui não são "inspirados" na imagem: são a imagem.
# BG, BG_ALT, MUTED e DIM saem a dE 0 — são hex amostrados do arquivo,
# não aproximações. Os cromáticos são Nord oficial, sem exceção.
#
# O ACENTO É AZUL, e desta vez isso NÃO é o erro do Catppuccin.
#
# Lá, o acento azul era a cor da massa, e destacar com a cor que ocupa a
# tela toda não destaca nada. Aqui a massa também é azul — mas a
# separação não é de matiz, é de LUZ: o céu está em L=12, a nuvem
# iluminada pela lua em L=58, o limbo em L=75. A fonte de luz da cena é
# fria, então claro e escuro compartilham o matiz e se distinguem pelo
# brilho. O nord8 (#88c0d0, dE 11 da nuvem iluminada) é literalmente o
# luar batendo na nuvem. É a mesma função da areia no Maré, num quadro
# onde o que ilumina por acaso é frio.
NAME="Nord"

BG=1a2026        # o céu, amostrado. L=12
BG_ALT=1d374a    # a névoa azul que a lua acende por trás das nuvens
FG=d8dee9        # nord4, e não o nord6 (#eceff4). Nesta cena nada é
                 # branco puro — o ponto mais claro da foto é #a8bdc8.
                 # Um branco de lâmpada sobre um quadro de luar destoa,
                 # e 12.2:1 já é contraste de sobra
MUTED=8fa5b3     # a nuvem cinza-azul fora do facho, amostrada
DIM=3b5063       # o lado sombreado da lua, amostrado

ACCENT=88c0d0    # nord8 — o luar na borda da nuvem. Ver a nota acima
ACCENT2=b48ead   # nord15. NÃO está na foto, e fica assim mesmo: é ele
                 # que ocupa a casa do magenta no terminal (color5/13),
                 # e trocá-lo por um segundo azul deixaria dois slots
                 # ANSI com a mesma cor. A imagem não o apoia, mas
                 # também não o contradiz — não há nada quente para ele
                 # brigar

OK=a3be8c        # nord14
WARN=ebcb8b      # nord13
ERR=bf616a       # nord11. Aqui há uma fraqueza conhecida do Nord, e ela
                 # não é minha: o vermelho dele é escuro, e dá 4.0:1
                 # sobre o fundo e 3.0:1 sobre o BG_ALT. O fundo mais
                 # escuro deste tema MELHOROU o número (o Nord original,
                 # sobre #2e3440, fica em ~3.5:1), mas não conserta.
                 # Mantido oficial de propósito: clarear o nord11 seria
                 # inventar uma cor Nord que não existe

# Cor das pastas do Papirus que acompanha este tema.
# `nordic` é o Nord9 (#81a1c1) — feito para esta paleta, e ainda por
# cima a dE 16 do acento e 6.1:1 sobre o fundo. Um dos raros casos em
# que o Papirus traz a cor certa com o nome certo.
PASTAS=nordic

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
#
# Recortado de 7680x2160 (32:9) para 3440x1440 na janela +0+0. A lua cai
# no terço direito e fica encaixada logo acima do banco de nuvens que
# ela mesma ilumina — que é a parte forte da composição. Cortes mais à
# direita empurram a lua para o centro (e para debaixo do notch) ou para
# a borda esquerda, com as nuvens cruzando o disco pela metade.
#
# O papel anterior (cervo na névoa) segue em nord-01.jpg, disponível no
# seletor.
WALLPAPER=nord-lua.jpg
