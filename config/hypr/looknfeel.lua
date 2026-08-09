-- Aparência: gaps, bordas, cores, animações.
-- Estilo Omarchy: sem blur, sem sombra, canto reto. Rápido e limpo.
--
-- As CORES não moram aqui — vêm de colors.lua, que o `rice-theme` gera a
-- partir da paleta do tema atual. Trocar de tema: SUPER+ALT+SPACE → Estilo.
-- Se colors.lua ainda não existir, cai no Tokyo Night embutido abaixo.

-- type(): `require` de um módulo que não devolve tabela entrega `true`,
-- e qualquer colors.x depois disso quebra o config todo. Ver a nota
-- equivalente no windows.lua.
local ok, colors = pcall(require, "colors")

if not ok or type(colors) ~= "table" then
  colors = {
    active_border   = { colors = { "rgba(7aa2f7ee)", "rgba(bb9af7ee)" }, angle = 45 },
    inactive_border = "rgba(414868aa)",
    group_active    = "rgba(7aa2f740)",
    group_inactive  = "rgba(24283b90)",
    group_text      = "rgb(c0caf5)",
    group_text_dim  = "rgba(c0caf590)",
  }
end

local active_border   = colors.active_border
local inactive_border = colors.inactive_border

-- Espessura de borda, arredondamento e espaços vêm do painel, pelo
-- decor.lua que o rice-theme gera. Mesma guarda de tipo do colors:
-- módulo que não devolve tabela faz `require` entregar `true`.
local ok_d, decor = pcall(require, "decor")
if not ok_d or type(decor) ~= "table" then
  decor = { borda = 1, arred = 10, gaps_in = 4, gaps_out = 10, shader = "" }
end

hl.config({
  general = {
    gaps_in     = decor.gaps_in,
    gaps_out    = decor.gaps_out,

    -- Borda de 1px. Duas coisas fazem parecer "premium": o traço fino
    -- e o contraste baixo na janela inativa — a borda deve marcar o
    -- foco, não gritar. O gradiente do acento fica só na ativa.
    border_size = decor.borda,

    col = {
      active_border   = active_border,
      inactive_border = inactive_border,
    },

    resize_on_border = true,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    -- Canto arredondado, no mesmo espírito da island.
    rounding = decor.arred,

    -- Realce de cor aplicado no fim da renderização.
    --
    -- Precisa vir pelo ARQUIVO DE CONFIG. Definir por
    -- `hyprctl eval` grava a opção (o getoption confirma) mas não
    -- dispara o parser do shader: nem um .frag propositalmente
    -- quebrado gera erro. Pelo config, funciona.
    screen_shader = decor.shader or "",
    rounding_power = 2.4,

    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    shadow = { enabled = false },

    -- Blur LIGADO, porém quase ninguém recebe: as janelas ficam de fora
    -- pela regra em windows.lua e a BARRA também saiu de lá. Sobra o
    -- launcher, e é só por ele que isto continua ligado.
    --
    -- REALCE NEUTRO (1.0 / 1.0 / 0), e é o ponto todo deste bloco.
    --
    -- Estes três campos não desfocam nada: eles corrigem tom DENTRO da
    -- região borrada. E a região borrada termina no contorno da
    -- superfície — então qualquer valor diferente do neutro cria um
    -- degrau de tom no perímetro, que o olho lê como uma borda desenhada.
    -- Era exatamente isso que contornava o notch (ver windows.lua).
    --
    -- O `noise` saiu pelo mesmo motivo: ruído só dentro do recorte é uma
    -- textura que começa e termina numa linha reta.
    --
    -- Se um dia o desfoque precisar ser mais forte, o campo é `size` ou
    -- `passes` — nunca o brilho e o contraste.
    blur = {
      enabled     = true,
      size        = 6,
      passes      = 3,
      noise       = 0.0,
      contrast    = 1.0,
      brightness  = 1.0,
      vibrancy    = 0.0,
      popups      = true,
      special     = false,
      new_optimizations = true,
    },
  },

  group = {
    col = {
      border_active   = active_border,
      border_inactive = inactive_border,
    },

    groupbar = {
      font_family         = "JetBrainsMono Nerd Font",
      font_size           = 12,
      font_weight_active  = "bold",
      height              = 20,
      indicator_height    = 2,
      gaps_in             = 4,
      gaps_out            = 0,
      text_color          = colors.group_text,
      text_color_inactive = colors.group_text_dim,
      col = {
        active   = colors.group_active,
        inactive = colors.group_inactive,
      },
      gradients = false,
    },
  },

  dwindle = {
    preserve_split = true,
    force_split    = 2,
  },

  master = {
    new_status = "master",
  },

  misc = {
    disable_hyprland_logo      = true,
    disable_splash_rendering   = true,
    disable_scale_notification = true,
    focus_on_activate          = true,
    initial_workspace_tracking = 0,

    -- Sem estas duas, redimensionar e arrastar janela é instantâneo e seco:
    -- a janela vizinha "pula" para o novo tamanho. Ligadas, o rearranjo é
    -- interpolado pela animação de "windows" logo abaixo.
    animate_manual_resizes       = true,
    animate_mouse_windowdragging = true,
  },

  binds = {
    hide_special_on_workspace_change = true,
  },

  animations = { enabled = true },
})

-- ┌──────────────────────────────────────────────────────────────┐
-- │  Animações                                                    │
-- └──────────────────────────────────────────────────────────────┘
--
-- ATENÇÃO À UNIDADE: `speed` no Hyprland é em DECISSEGUNDOS, não em
-- milissegundos nem em "velocidade". `speed = 3.79` são 379ms. Era esse
-- o problema do conjunto anterior (o padrão do Omarchy): janela abrindo
-- em 410ms e barra em 381ms parecem suaves numa captura de tela e
-- pesadas no uso, porque a mão chega ao destino antes da imagem.
--
-- A meta aqui é a faixa dos 150–250ms. Abaixo de ~120ms o olho lê como
-- corte seco e a animação deixa de comunicar de onde a coisa veio;
-- acima de ~300ms ela vira espera.
--
-- ── As quatro regras que dão o ar caro ───────────────────────────
--
-- 1. ENTRAR é mais lento que SAIR. O que chega merece ser visto; o que
--    sai não deve cobrar pedágio. Todas as duplas In/Out aqui têm o Out
--    a ~60% do tempo do In.
--
-- 2. UMA FAMÍLIA DE CURVAS, não seis avulsas. O conjunto anterior tinha
--    linear, quick, almostLinear, smoothOut e duas easings misturadas
--    sem critério. Elegância vem de repetição: aqui há UMA curva de
--    entrada, UMA de saída e UMA de deslocamento, usadas em tudo.
--
-- 3. NADA DE `linear`. Movimento linear não existe no mundo físico e o
--    olho reconhece na hora como "computador desenhando". Era a curva do
--    windowsOut e do layersOut.

-- ── 4. O QUE TEM MASSA USA MOLA, NÃO BEZIER ─────────────────────
--
-- Esta é a regra que faltava, e ela conserta DOIS sintomas de uma vez:
-- o "engasgo" ao arrastar janela e o ar de coisa barata.
--
-- Bezier é uma curva FECHADA: recebe um começo, um fim e um tempo, e
-- percorre aquilo do zero. Se o destino mudar no meio do caminho, ela
-- recomeça — do zero, com VELOCIDADE ZERO. Está no hyprutils, em
-- AnimatedVariable.hpp:
--
--     onAnimationBegin(WASANIMATING && isSpringCurve(), SPRINGVELOCITYSCALE);
--
-- O primeiro argumento é `preserveCurveState`. Com bezier ele é FALSO.
--
-- Agora junte isso com `animate_mouse_windowdragging` lá em cima: ao
-- arrastar uma janela, o destino muda a cada evento do mouse — 100 vezes
-- por segundo neste monitor. Com bezier, a curva reinicia 100 vezes por
-- segundo e a janela nunca chega a acelerar: ela TREME atrás do cursor.
-- Aquilo parecia queda de quadro e não era; era a curva sendo reiniciada.
--
-- Mola não tem começo nem fim, tem ESTADO — posição e velocidade. Mudar
-- o alvo no meio não reinicia nada: a velocidade atual é transportada
-- (o `SPRINGVELOCITYSCALE` acima). É por isso que a janela passa a
-- seguir o cursor em vez de perseguí-lo, e é o mesmo motivo pelo qual o
-- iOS e o macOS usam mola em tudo que se move — `UISpringTimingParameters`
-- lá, `spring(response:dampingFraction:)` no SwiftUI.
--
-- Como os números saem (massa = 1, sempre):
--
--     rigidez (stiffness) = (2π / T)²          T  = período, em segundos
--     atrito  (dampening) = 2 · ζ · (2π / T)   ζ  = razão de amortecimento
--
-- ζ é o dial do quique: 1,0 não passa do alvo, 0,7 passa ~4,6% e volta.
-- Aqui é 0,70 — o mesmo território do padrão do Hyprland (ζ = 0,78) e do
-- `.bouncy` do SwiftUI. Abaixo de 0,6 vira gelatina.
--
-- Nem tudo ganha mola. Mola só faz sentido onde há INÉRCIA para simular:
--   • posição e tamanho  → mola   (janela, camada, área de trabalho)
--   • cor e opacidade    → bezier (não há massa; e quique em opacidade
--                                  passaria de 1.0, que é só estouro)
--   • SAÍDA              → bezier (o que sai não precisa assentar; quique
--                                  na saída faz a janela "voltar" morta)

-- Entrada: dispara rápido e assenta devagar (easeOutExpo). É o que faz
-- 220ms PARECER instantâneo — quase todo o percurso acontece no primeiro
-- terço do tempo.
hl.curve("praxeOut",  { type = "bezier", points = { { 0.16, 1 },    { 0.30, 1 }    } })
-- Saída: começa devagar e acelera embora. O contrário da de cima.
hl.curve("praxeIn",   { type = "bezier", points = { { 0.40, 0 },    { 0.90, 0.35 } } })
-- Quase instantânea, com um respiro no fim. Para cor de borda e fade,
-- onde não há deslocamento e portanto não há o que "ler".
hl.curve("praxeSnap", { type = "bezier", points = { { 0.05, 0.90 }, { 0.10, 1 }    } })

-- ── As molas, calculadas em vez de digitadas ────────────────────
--
-- Antes estes eram seis números mágicos (stiffness 223.8006 e afins).
-- Números mágicos aqui envelhecem mal: "está lento demais" vira uma ida
-- ao Python para recalcular rigidez E atrito ao mesmo tempo, porque os
-- dois dependem do período — mexer só num deles descasa a mola e o
-- movimento deixa de fechar.
--
-- Com a conta no lugar, o que se ajusta é o que se PENSA: o período T e
-- o quique ζ. O resto é física.
local function mola(nome, T, zeta)
  local w = 2 * math.pi / T
  hl.curve(nome, { type = "spring", mass = 1, stiffness = w * w, dampening = 2 * zeta * w })
  return T * 10 -- `speed` do Hyprland é em decissegundos
end

-- As escolhas moram fora, no arquivo que o `rice-anim` escreve — mesma
-- ideia do colors.lua e do decor.lua. Assim testar ritmo e estilo é um
-- comando, e não uma edição deste arquivo.
--
-- O type() não é paranoia: `require` de um módulo que não devolve tabela
-- entrega `true`, e qualquer indexação depois disso derruba o config
-- inteiro. Mesma guarda do colors e do opacity.
local ok_an, an = pcall(require, "anim-escolha")
if not ok_an or type(an) ~= "table" then
  an = {}
end

-- `ritmo` multiplica TODOS os períodos de uma vez: 0.8 = 20% mais rápido,
-- 1.2 = 20% mais lento. É um multiplicador e não valores absolutos porque
-- a família tem de continuar sendo uma família — acelerar a janela e
-- esquecer a barra é o que produz um conjunto que parece remendo.
local ritmo  = tonumber(an.ritmo)  or 1.0
local quique = tonumber(an.quique) or 0.70

-- A do dia a dia: janela abrindo, janela sendo arrastada, mosaico se
-- rearranjando. O período NÃO é a duração: a mola assenta bem antes de
-- T porque quase todo o percurso acontece no primeiro quarto de ciclo.
-- É o mesmo truque do easeOutExpo, só que emergindo da física.
local vMola   = mola("praxeMola",       0.42 * ritmo, quique)

-- Mais dura, para o que aparece muitas vezes por minuto: a barra, o
-- dock, o fuzzel. Elemento pequeno com período longo parece pesado — o
-- olho compara o tamanho da coisa com o tempo que ela leva.
local vRapida = mola("praxeMolaRapida", 0.30 * ritmo, quique)

-- Para o que move a TELA INTEIRA, com menos quique que o resto: num
-- deslocamento de 3440px, os mesmos 4,6% viram um solavanco de dezenas
-- de pixels e enjoam.
--
-- T começou em 550ms e ficou LENTO — a troca de área virava espera. O
-- erro foi tratar "move muito espaço" como "precisa de muito tempo". O
-- que o olho acompanha aqui não é a distância percorrida, é a troca de
-- CONTEXTO, e essa já aconteceu no primeiro terço do movimento; o resto
-- é a tela terminando de chegar num lugar que você já entendeu.
local vAmpla  = mola("praxeMolaAmpla",  0.36 * ritmo, math.min(quique + 0.06, 0.99))

-- ── Estilos ──────────────────────────────────────────────────────
--
-- O estilo é a FORMA do movimento; a mola é o tempo dele. São eixos
-- independentes de propósito: dá para achar o `gnomed` bonito e ainda
-- assim querer tudo 20% mais rápido, sem um ajuste desfazer o outro.
local ESTILOS = {
  -- O padrão. Janela nasce a 92% e assenta; área desliza 15% e esvanece.
  mola     = { entrada = "popin 92%", saida = "popin 94%", areas = "slidefade 15%" },
  -- Janela desce do topo. Combina com barra em cima, que é o caso aqui.
  cortina  = { entrada = "slidevert",  saida = "slidevert", areas = "slidefadevert 15%" },
  -- Tudo horizontal, sem escala. O mais sóbrio dos quatro.
  deslize  = { entrada = "slide",      saida = "slide",     areas = "slide" },
  -- O "genie" do GNOME: a janela é sugada para a posição. O mais chamativo
  -- — e o que cansa mais rápido, então experimente antes de adotar.
  genio    = { entrada = "gnomed",     saida = "gnomed",    areas = "slidefade 20%" },
}
local est = ESTILOS[an.estilo or "mola"] or ESTILOS.mola

-- `speed` continua valendo para mola, e continua em DECISSEGUNDOS. A
-- física define o FORMATO do movimento; o speed escala a linha do tempo
-- em cima dela. Aqui cada speed é o período T da própria mola (420ms →
-- 4.2), que é como o config padrão do Hyprland faz: ele casa a mola
-- `easy` (T = 407ms) com speed 4.1 e 4.79. Mantendo os dois de acordo, o
-- número no config diz a mesma coisa que a rigidez — e mexer em um só
-- deles é o caminho mais curto para um movimento que não fecha.
hl.animation({ leaf = "global",        enabled = true, speed = vMola, spring = "praxeMola" })

-- Borda: 180ms. É a cor do foco mudando — precisa acompanhar o olho ao
-- trocar de janela, não chamar atenção.
hl.animation({ leaf = "border",        enabled = true, speed = 1.8 * ritmo, bezier = "praxeSnap" })

-- O ÂNGULO do gradiente da borda, animado UMA VEZ a cada troca de foco.
--
-- A borda ativa deste rice é um gradiente accent -> accent2 a 45° (ver
-- colors.lua). Com isto, ao focar uma janela o gradiente faz uma varredura
-- curta em vez de simplesmente trocar de cor. É o detalhe mais barato de
-- "caro" que existe aqui: some sozinho em 300ms e não deixa nada girando.
--
-- SEM o estilo `loop`, de propósito. Com ele o ângulo gira para sempre,
-- o que obriga a GPU a repintar a borda em TODO quadro, o tempo inteiro,
-- mesmo com a máquina parada — custo permanente por um efeito que deixa
-- de ser notado em dois minutos.
hl.animation({ leaf = "borderangle",   enabled = true, speed = 3.0 * ritmo, bezier = "praxeOut" })

hl.animation({ leaf = "windows",       enabled = true, speed = vMola, spring = "praxeMola" })

-- `popin 92%`, e não 87%. A janela nasce a 92% do tamanho final em vez
-- de 87%: o salto é menor, então lê como um assentar e não como um pulo.
--
-- Com mola o quique acontece AQUI, e é o efeito mais reconhecível do
-- conjunto: a janela sobe de 92% até ~104% e volta para 100%. É o abrir
-- de app do iOS. Com 92% de partida o quique fica maior que o próprio
-- salto de entrada — de propósito: o que se lê é o assentar, não a subida.
hl.animation({ leaf = "windowsIn",     enabled = true, speed = vMola, spring = "praxeMola", style = est.entrada })

-- Saída fica em BEZIER, e é a única exceção deliberada à regra da mola.
-- Fechar é 1 → 0: um quique aqui faria a janela encolher além do nada e
-- voltar a aparecer por um quadro. Sai rápido e sai seco.
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.4 * ritmo, bezier = "praxeIn",  style = est.saida })

-- Rearranjo do tiling, e TAMBÉM o arrasto com o mouse. É a folha que
-- mais ganha com a mola: é ela que estava reiniciando cem vezes por
-- segundo quando você arrastava uma janela.
hl.animation({ leaf = "windowsMove",   enabled = true, speed = vMola, spring = "praxeMola" })

hl.animation({ leaf = "fade",          enabled = true, speed = 1.4 * ritmo, bezier = "praxeSnap" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.4 * ritmo, bezier = "praxeOut" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.0 * ritmo, bezier = "praxeIn" })

-- Camadas: a barra, o dock, os menus do fuzzel. Elas aparecem muitas
-- vezes por minuto — é onde a lentidão mais cansa, daí a mola dura.
-- Só o DESLOCAMENTO da camada leva mola; o `fade` dos filhos abaixo
-- continua em bezier, porque opacidade não tem massa.
hl.animation({ leaf = "layers",        enabled = true, speed = vRapida, spring = "praxeMolaRapida" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.0 * ritmo, bezier = "praxeOut", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.2 * ritmo, bezier = "praxeIn",  style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.4 * ritmo, bezier = "praxeOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.0 * ritmo, bezier = "praxeIn" })

-- ── Troca de área de trabalho ────────────────────────────────────
--
-- Estava DESLIGADA, e é a mudança que mais se nota no dia a dia: trocar
-- de workspace era um corte seco, sem dizer para que lado você foi. Com
-- o deslize, o cérebro guarda a posição espacial das áreas — e é isso
-- que faz um mosaico parecer um lugar em vez de uma lista.
--
-- `slidefade 15%`: desliza E esvanece ao mesmo tempo, com deslocamento
-- de apenas 15% da tela. O deslize completo (100%) em 3440px é longo
-- demais e enjoa na décima troca; 15% dá a direção sem o trajeto.
--
-- É a única animação que move a tela INTEIRA, e movimento grande precisa
-- de mais tempo para não parecer um tranco — daí a mola ampla, mais mole
-- (T = 550ms) e com menos quique (ζ = 0,74) que o resto da família.
--
-- O ganho da mola aqui é específico: trocar de área DUAS VEZES seguidas,
-- rápido. Com bezier a segunda troca reiniciava do zero e a tela dava um
-- tranco no meio do caminho. Com mola ela só muda de destino, sem parar.
--
-- Para desligar, troque para `enabled = false`.
hl.animation({ leaf = "workspaces",    enabled = true, speed = vAmpla, spring = "praxeMolaAmpla", style = est.areas })
