-- Variáveis de ambiente da sessão.
-- Diferente do PATH do shell, isto vale para tudo que o Hyprland lança —
-- inclusive os comandos disparados pelos atalhos e pelo menu.

local home = os.getenv("HOME")

-- Coloca ~/.local/bin na frente do PATH (é onde vivem os scripts rice-*)
local bin_dir = home .. "/.local/bin"
local kept = {}
for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
  if entry ~= bin_dir then
    table.insert(kept, entry)
  end
end
table.insert(kept, 1, bin_dir)
hl.env("PATH", table.concat(kept, ":"))

-- ── Jogos ───────────────────────────────────────────────────────
--
-- Cache de shader do Mesa em 12 GB, contra o padrão de 1 GB.
--
-- Numa Intel Arc isto importa mais que na média: o compilador de shader
-- do Mesa para Battlemage é novo, e jogo via Proton compila MUITO shader
-- na primeira partida. Com o cache pequeno, o que foi compilado ontem é
-- descartado para caber o de hoje — e o engasgo de primeira execução
-- volta toda vez. 12 GB guarda uma biblioteca inteira sem incomodar
-- ninguém num disco moderno.
--
-- Vale para TODOS os apps que usam Mesa, não só jogos; para o resto o
-- cache nunca chega perto do teto, então não há custo.
hl.env("MESA_SHADER_CACHE_MAX_SIZE", "12G")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Força os apps a usarem Wayland de verdade (menos borrão, menos XWayland)
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Faz os apps Qt (Dolphin, etc.) lerem a paleta gerada em ~/.config/kdeglobals.
-- Quem lê esse arquivo é o plasma-integration, e ele só assume o controle
-- quando o tema de plataforma é declarado explicitamente: como o
-- XDG_CURRENT_DESKTOP aqui é "Hyprland" (e não "KDE"), sem esta linha
-- nenhum tema assume e os apps Qt abrem claros.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- Programas padrão para quem perguntar ao ambiente
hl.env("TERMINAL", "kitty")
hl.env("BROWSER", "zen-browser")
hl.env("EDITOR", "micro")

hl.config({
  xwayland = {
    force_zero_scaling = true,
  },

  ecosystem = {
    no_update_news = true,
  },
})
