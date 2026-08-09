-- Programas padrão. Trocar aqui muda os atalhos e o menu de uma vez só.

local home = os.getenv("HOME")

App = {
  terminal     = "kitty",
  browser      = "zen-browser",
  -- Nautilus no lugar do Dolphin: sendo GTK4/libadwaita, ele segue
  -- o gtk.css que o rice-theme gera. O Dolphin dependia do kdeglobals
  -- e destoava do resto.
  filemanager  = "nautilus",
  editor       = "kitty -e micro",

  -- diretório dos scripts do rice (rice-menu, rice-screenshot, ...)
  bin          = home .. "/.local/bin/",
}

-- Atalho: App.run("rice-menu") -> caminho absoluto do script
function App.run(script)
  return App.bin .. script
end

return App
