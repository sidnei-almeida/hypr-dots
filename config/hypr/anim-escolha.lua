-- Gerado por rice-anim. Não edite à mão: será sobrescrito.
--
-- ritmo  multiplica o período de TODAS as animações.
--        0.8 = 20% mais rápido · 1.0 = padrão · 1.3 = mais calmo
-- quique é o ζ da mola: 1.0 não passa do alvo, 0.70 passa ~4.6% e volta.
-- estilo é a forma: mola cortina deslize genio
--
-- A conta que transforma isto em rigidez e atrito está no looknfeel.lua.
return {
  ritmo  = 0.8,
  quique = 0.70,
  estilo = "mola",
}
