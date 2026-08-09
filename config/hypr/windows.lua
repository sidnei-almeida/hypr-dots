-- Regras de janela.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Apps que fazem mais sentido flutuando e centralizados
hl.window_rule({
  name  = "utilitarios-flutuantes",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|org.kde.polkit-kde-authentication-agent-1|imv|mpv|swayimg|Calculator)$",
  },
  float  = true,
  size   = "900 600",
  center = true,
})

-- Diálogos (abrir/salvar arquivo, etc.)
hl.window_rule({
  name  = "dialogos",
  match = { title = "^(Open File|Save File|Save As|Escolher arquivo|Abrir arquivo)" },
  float  = true,
  center = true,
})

-- Terminal flutuante (usado pelo menu para comandos interativos)
hl.window_rule({
  name   = "terminal-flutuante",
  match  = { class = "^rice-float$" },
  float  = true,
  size   = "1000 620",
  center = true,
})

-- Picture-in-picture sempre por cima
hl.window_rule({
  name  = "pip",
  match = { title = "^(Picture-in-Picture|Imagem picture-in-picture)$" },
  float = true,
  pin   = true,
  size  = "640 360",
})

-- Ignora pedidos de maximizar (recomendado no tiling)
hl.window_rule({
  name  = "sem-maximizar",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Corrige arrastar em apps XWayland
hl.window_rule({
  name  = "fix-xwayland-drag",
  match = { class = "^$", title = "^$", xwayland = true },
  no_focus = true,
})

-- Blur é ligado globalmente no looknfeel, mas só a barra e os menus
-- devem recebê-lo: janela com blur atrás pesa e não combina com o
-- desenho chapado do resto.
hl.window_rule({ name = "sem-blur-nas-janelas", match = { class = ".*" }, no_blur = true })

-- A BARRA NÃO LEVA BLUR, e o motivo é uma linha que aparecia em volta
-- do notch.
--
-- O blur do Hyprland não desfoca só: ele aplica `brightness`, `contrast`
-- e `vibrancy` no que desfocou. Isso vale APENAS para dentro da região
-- borrada — e a região borrada termina exatamente no contorno do notch,
-- porque o `ignore_alpha` recorta pelo alfa da superfície. O resultado é
-- um degrau de tom no perímetro: fundo realçado de um lado, papel de
-- parede cru do outro. O olho lê aquilo como BORDA.
--
-- Era o que fazia o notch parecer contornado "em vários temas" sem que
-- tema nenhum definisse borda — a visibilidade do degrau depende do
-- papel de parede atrás, não da paleta. O `shell.qml` sempre teve
-- `border.width: 0`; a linha nunca foi desenhada pelo shell.
--
-- O que se perde: o comentário do looknfeel.lua contava com o blur para
-- deixar o filete colapsado legível. Ele não é mais necessário — o notch
-- é 92% opaco por conta própria (`pillBg` no Theme.qml), e opacidade
-- resolve legibilidade sem inventar contorno.
hl.layer_rule({ match = { namespace = "^praxe-bar$" }, blur = false })
hl.layer_rule({ match = { namespace = "^launcher$" },  blur = true, animation = "fade" })
hl.layer_rule({ match = { namespace = "^notifications$" }, animation = "slide" })

-- ── Transparência opcional ──────────────────────────────────────────
-- Gerada pelo rice-theme a partir do pill.json; o painel de aparência é
-- quem liga e desliga. O arquivo existe sempre (com opacidade 1.0
-- quando desligada), então o require não precisa de guarda.
--
-- `opacity` é campo de STRING no parser Lua, com a mesma sintaxe do
-- .conf ("ativo inativo") — passar uma tabela {0.9, 0.85} é recusado.
--
-- kitty fica de fora: quem cuida dele é o background_opacity do próprio
-- terminal. Aplicar os dois multiplica as opacidades e o texto some.
--
-- São DUAS regras em ordem, e não uma com lookahead negativo, porque
-- nem todo motor de regex aceita "(?!...)" — a regra passaria a casar
-- com nada e a transparência simplesmente não apareceria, sem erro.
-- Regra posterior vence, então a segunda devolve o terminal ao opaco.
-- O type() não é paranoia: quando o módulo existe mas não devolve uma
-- tabela (arquivo vazio, ou pego no meio de uma reescrita pelo
-- rice-theme), `require` devolve o booleano `true`. Sem a checagem,
-- op.ativa vira "attempting to index a boolean" e o Hyprland reclama do
-- config inteiro na hora de trocar de tema.
local ok_op, op = pcall(require, "opacity")
if ok_op and type(op) == "table" and op.ativa then
  hl.window_rule({
    name    = "transparencia",
    match   = { class = ".*" },
    opacity = string.format("%.2f %.2f", op.ativo, op.inativo),
  })
  hl.window_rule({
    name    = "transparencia-terminal-fora",
    match   = { class = "^(kitty|rice-float)$" },
    opacity = "1.00 1.00",
  })
end
