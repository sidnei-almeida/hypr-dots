-- ┌─────────────────────────────────────────────────────────────┐
-- │  Hyprland — rice inspirado no Omarchy                        │
-- │  Este arquivo só carrega os módulos. Edite os módulos.        │
-- └─────────────────────────────────────────────────────────────┘
--
--   apps.lua        quais programas SUPER+RETURN, browser, etc. abrem
--   envs.lua        variáveis de ambiente da sessão (inclui o PATH)
--   monitors.lua    resolução / posição / escala das telas
--   input.lua       teclado, mouse, touchpad
--   looknfeel.lua   gaps, bordas, cores, animações
--   windows.lua     regras de janela (o que flutua, o que fica opaco)
--   bindings.lua    todos os atalhos
--   autostart.lua   o que sobe junto com a sessão
--
-- Ver todos os atalhos ativos:  SUPER + K

require("apps")
require("envs")
require("monitors")
require("input")
require("looknfeel")
require("windows")
require("bindings")
require("autostart")
