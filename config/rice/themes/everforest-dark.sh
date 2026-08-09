# Everforest Dark — ajustado para o papel das folhas no escuro.
#
# ESTA IMAGEM NÃO TEM COR, e isso muda o método.
#
# Nos outros temas com papel (Maré, Catppuccin, Samurai) a paleta foi
# tirada da foto: havia areia, ouro, âmbar de onde puxar um acento. Aqui
# não há. Medido: o croma máximo da imagem é 4.6 — as folhas mais
# iluminadas dão #83787a, o meio-tom #3d413b, o fundo #0c0d0c. Para
# comparar, as cores cromáticas do Everforest ficam entre 21 e 35 de
# croma. A foto é, na prática, cinza com um sussurro de verde.
#
# Então a divisão de trabalho é outra:
#
#   NEUTROS (BG, BG_ALT, DIM, MUTED)  vêm da imagem — é o que ela tem
#     para dar, e dá com precisão: o BG está a dE 1 da folha escura e o
#     DIM a dE 4 da folha média.
#   CROMÁTICOS (ACCENT, ACCENT2, OK, WARN, ERR)  são Everforest oficial,
#     sem torção. A imagem não os apoia nem os contradiz, e inventar um
#     acento "extraído" de uma foto acromática seria inventar mesmo.
#
# AVISO A QUEM LER DEPOIS: houve aqui uma versão com ACCENT=yellow, e o
# comentário explicava longamente que o acento era "o vaga-lume e o olho
# aceso do lêmure". Aquilo estava certo para OUTRA foto — um lêmure
# noturno cheio de vaga-lumes dourados, que foi trocada por esta. O
# raciocínio morreu junto com a imagem. Não o restaure sem uma foto que
# tenha ouro dentro.
#
# POR QUE O ACENTO NÃO É O `green`, que seria o óbvio num tema de mata:
# green (#a7c080) e aqua (#83c092) estão a dE 15.9 um do outro, e o OK
# já é o green. Acento e "deu certo" quase da mesma cor é o tipo de
# colisão que só aparece quando você precisa distinguir os dois com
# pressa. O blue do Everforest (que na paleta dele é teal, não azul)
# fica a dE 31.8 do OK — é o único da família fria que separa limpo.
NAME="Everforest Dark"

BG=0e1210        # a folha no escuro (#111411), dE 1. Quase preto de
                 # propósito: o papel é quase preto, e um fundo mais
                 # claro faria a barra flutuar por cima em vez de nele
BG_ALT=252a26    # superfície: a folha um passo dentro da luz
FG=d3c6aa        # fg oficial. É a única coisa quente da tela, e é o que
                 # impede o conjunto de virar um cinza sobre cinza
MUTED=859289     # grey1 oficial — coincide com o realce da folha (dE 14)
DIM=333a35       # folha média (#3d413b), dE 4

ACCENT=7fbbb3   # blue oficial (teal, apesar do nome). Ver a nota acima
ACCENT2=d699b6  # purple oficial — os realces da folha puxam de leve
                # para o malva (#83787a), então ele não destoa

OK=a7c080       # green oficial
WARN=dbbc7f     # yellow oficial
ERR=e67e80      # red oficial

# Cor das pastas do Papirus que acompanha este tema.
# darkcyan (#45abb7): dE 15 do acento, e 7.0:1 de contraste sobre um
# fundo quase preto — a cor mais próxima que ainda se acha na tela.
PASTAS=darkcyan

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
#
# A imagem original é 5999x2571 (2.33:1), quase a proporção da tela
# (2.39:1) — então aqui não há enquadramento a escolher como nos outros
# temas: sobram 60px de altura, cortados metade em cima e metade embaixo.
# Recortar de lado seria jogar fora resolução sem ganhar composição, já
# que o assunto (folhas cruzando o quadro) não tem um ponto focal.
WALLPAPER=everforest-dark.jpg
