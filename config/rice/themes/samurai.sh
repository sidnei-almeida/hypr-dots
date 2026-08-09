# Samurai — o tema da casa do PraXe OS.
#
# Tirado pixel a pixel do santuário noturno na neve: o preto quente da
# noite, o âmbar das lanternas de papel e o vermelhão das bandeiras.
#
# O acento é o âmbar, não o vermelho, porque a luz das lanternas é o que
# domina a cena. O vermelho entra como segunda voz, em marcas pontuais —
# se preenchesse área ficaria agressivo.
#
# O FUNDO é preto neutro, não amarronzado. Puxar o fundo para o quente
# deixa a tela inteira com um tom sujo; o calor do tema tem que vir das
# lanternas (acento), não da base.
#
# A superfície (BG_ALT) é um cinza levemente FRIO de propósito: serve de
# contrapeso ao calor de tudo o mais. Superfície quente sobre fundo
# quente vira aquele dourado embarrado.
NAME="Samurai"

BG=0a0a0a        # preto neutro. O quente fica nas lanternas, não no fundo
BG_ALT=2e2e30    # superfície fria, contrapeso
FG=e6dcc8        # papel das lanternas
MUTED=9a8b72     # madeira envelhecida
DIM=3a3226       # traço apagado

ACCENT=d4ab60    # âmbar da lanterna acesa
ACCENT2=c1382a   # vermelhão das bandeiras

OK=7f8f5e        # verde do musgo sob a neve
WARN=e8cb98      # lanterna mais clara
ERR=d9534a       # vermelho de alarme, mais vivo que o das bandeiras

# Cor do ponto de aviso do notch fechado (opcional; sem esta linha, vale
# o ACCENT). Aqui o acento NÃO serve: âmbar de lanterna é cor de coisa
# acesa e tranquila, e um ponto pedindo atenção precisa soar como alarme.
#
# Usa o ERR e não o ACCENT2, apesar de o ACCENT2 ser o vermelhão das
# bandeiras e parecer a escolha temática: aquele vermelho (#c1382a) dá
# 3.7:1 sobre o preto do fundo, e o ponto tem 6px numa barra quase
# transparente. O ERR sobe para 5.0:1 — ainda é o vermelho do tema, e
# este é legível.
AVISO=d9534a

# Cor das pastas do Papirus que acompanha este tema.
# Madeira da lanterna. O paleorange fica mais perto do acento em ΔE, mas pasta clara sobre fundo quase preto vira facho de luz.
PASTAS=brown

# Papel de parede deste tema, em a subpasta Wallpapers da pasta de imagens do sistema.
# O santuário na neve de onde esta paleta foi tirada, pixel a pixel.
WALLPAPER=msv2zgjzbojg1.png
