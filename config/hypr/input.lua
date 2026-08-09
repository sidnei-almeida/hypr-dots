-- Teclado, mouse e touchpad.
-- https://wiki.hypr.land/Configuring/Variables/#input

hl.config({
  input = {
    kb_layout  = "us",
    -- Para acentuação em português mantendo layout US, troque para:
    --   kb_variant = "intl"
    -- Para teclado ABNT2 brasileiro:
    --   kb_layout = "br"
    kb_variant = "",
    kb_model   = "",
    kb_rules   = "",
    kb_options = "",

    repeat_rate  = 40,
    repeat_delay = 400,

    follow_mouse = 1,
    sensitivity  = 0, -- -1.0 a 1.0, 0 = sem modificação

    touchpad = {
      natural_scroll     = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      scroll_factor      = 0.4,
    },
  },

  cursor = {
    hide_on_key_press = true,
  },
})

-- Deslizar 3 dedos no touchpad troca de área de trabalho
hl.gesture({
  fingers   = 3,
  direction = "horizontal",
  action    = "workspace",
})
