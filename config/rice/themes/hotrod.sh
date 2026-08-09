# Hotrod — derivado do Gruvbox, vestido para a foto do carro de corrida.
#
# É a versão 2 do Gruvbox: mesma família quente e terrosa, outra cena. Lá
# é oficina parada e luz de janela; aqui é pista, poeira e sol de fim de
# tarde num F1 dos anos 60.
#
# SEIS DAS DEZ CORES SÃO AMOSTRAS DIRETAS DA IMAGEM, a dE 0 — fundo,
# superfície, texto, apagado, traço e acento saíram do arquivo com
# conta-gotas, sem ajuste. Não é sorte: a foto tem uma paleta curta e bem
# separada (preto de pneu, vinho de lataria na sombra, creme de céu
# enevoado, marrom de terra batida, ouro de roda), que é exatamente a
# estrutura de que um tema precisa.
NAME="Hotrod"

BG=121417        # o preto do pneu. Frio, e isso surpreende num tema
                 # quente — mas as sombras profundas desta foto são
                 # azuladas de verdade, e forçar um preto marrom aqui
                 # brigaria com a imagem em vez de acompanhá-la
BG_ALT=4f2f28    # o vinho da lataria na sombra. Superfície quente sobre
                 # fundo frio: é essa tensão que dá relevo aos painéis
FG=faedcb        # o creme do céu enevoado — a cor que mais ocupa a foto
MUTED=aa8e6e     # a terra batida além da pista
DIM=5e584e       # o cinza morno das arquibancadas

# ── Os dois acentos, e por que NÃO é o vermelho ──────────────────────
#
# Num tema chamado Hotrod, o óbvio seria o acento ser o vermelho do
# carro. Foi medido e não dá: a lataria iluminada é #992f28, que sobre o
# preto do pneu rende 2.4:1. Acento é cursor, foco, link e seleção —
# coisas que precisam ser lidas. Clareá-lo até um contraste utilizável o
# afastaria tanto do original que deixaria de ser a cor do carro.
#
# O ouro rende 8.9:1 e também está na foto, três vezes: capacete, bico e
# raios das rodas. É onde a luz bate — e acento é luz, não massa. Mesma
# lógica da areia no Maré.
#
# O vermelho não sumiu: virou a segunda voz, clareado o mínimo para
# passar de 2.4:1 para 4.4:1, que é o que um papel decorativo pede.
ACCENT=e2ab46    # ouro do bico, do capacete e dos raios (dE 0 da foto)
ACCENT2=cf5340   # a lataria, clareada para poder ser lida (dE 18)

OK=a9b665        # verde de oliva. NÃO está na foto: os pinheiros do
                 # fundo estão lavados pela névoa e não dão verde nenhum.
                 # É cor funcional, e cor funcional não precisa de fonte
WARN=bf6a1f      # laranja queimado. Escolhido por eliminação com régua:
                 # o âmbar óbvio ficava a dE 17.7 do acento, perto demais
                 # para distinguir com pressa. Este é o único candidato
                 # que passou dos 25 de distância do acento, do erro E da
                 # segunda voz ao mesmo tempo, mantendo 4.7:1
ERR=fb4934       # vermelho de alarme, mais vivo que o da lataria

# Cor das pastas do Papirus que acompanha este tema.
#
# `red` (#e25252) é a única escolha que fecha os dois lados: pertence à
# família do carro (dE 22.6 da lataria) e está a dE 56 do acento — a
# maior distância entre as candidatas quentes. Pasta dourada aqui seria o
# acento repetido em toda janela, o erro que o Samurai recusa ao
# dispensar o paleorange.
PASTAS=red

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
#
# Recortado de 7680x2160 (32:9) para 3440x1440 na janela +1300+0. É o
# enquadramento em que o carro cabe INTEIRO — do pneu traseiro ao bico
# amarelo — com o número 1 caindo no terço esquerdo e a arquibancada
# fechando a direita. Cortes mais à direita decepam a roda traseira, que
# é metade da silhueta de um F1 daquela época.
WALLPAPER=hotrod.jpg
