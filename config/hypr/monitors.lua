-- Monitores. Ver os nomes/modos disponíveis com:  hyprctl monitors
--
-- Exemplos:
--   hl.monitor({ output = "eDP-1",  mode = "1920x1080@60", position = "0x0",    scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "preferred",  position = "auto-right", scale = 1 })
--   hl.monitor({ output = "eDP-1",  disabled = true })

-- Samsung Odyssey S34CG50 — ultrawide 3440x1440 a 100Hz.
-- O modo "preferred" estava escolhendo 59.97Hz; aqui a taxa é explícita.
hl.monitor({
  output   = "DP-2",
  mode     = "3440x1440@100",
  position = "0x0",
  scale    = 1,
})

-- Qualquer outra tela que aparecer entra no automático, à direita.
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto-right",
  scale    = "auto",
})
