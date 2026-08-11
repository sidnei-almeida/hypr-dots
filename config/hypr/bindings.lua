-- Todos os atalhos. Ver a lista na tela a qualquer momento: SUPER + K
--
-- A descrição de cada bind aparece nessa lista, então mantenha-as preenchidas.

local mod = "SUPER"
local run = App.run

-- ┌──────────────────────────────────────────────┐
-- │  MENU E LAUNCHER — o coração da experiência   │
-- └──────────────────────────────────────────────┘

-- O lançador agora é da island: mesma paleta, mesmos raios, com
-- modos lista e grade. O rice-launcher (fuzzel) segue existindo como
-- reserva, caso a barra não esteja no ar.
hl.bind(mod .. " + SPACE",
  hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/rice/shell ipc call island apps"),
  { description = "Abrir aplicativo" })
hl.bind(mod .. " + ALT + SPACE", hl.dsp.exec_cmd(run("rice-menu")),
  { description = "Menu principal" })
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd(run("rice-menu") .. " system"),
  { description = "Menu de energia (desligar/reiniciar/bloquear)" })
hl.bind(mod .. " + K", hl.dsp.exec_cmd(run("rice-keybindings")),
  { description = "Mostrar todos os atalhos" })

hl.bind(mod .. " + CTRL + V", hl.dsp.exec_cmd(run("rice-clipboard")),
  { description = "Histórico da área de transferência" })
hl.bind(mod .. " + CTRL + E", hl.dsp.exec_cmd(run("rice-emoji")),
  { description = "Seletor de emoji" })
hl.bind(mod .. " + CTRL + C", hl.dsp.exec_cmd(run("rice-menu") .. " capture"),
  { description = "Menu de captura (print/gravação/cor)" })
hl.bind(mod .. " + CTRL + O", hl.dsp.exec_cmd(run("rice-menu") .. " toggle"),
  { description = "Menu de alternâncias" })
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"),
  { description = "Bloquear a tela" })

-- A island: a barra expande no centro de controle (mídia, volume, atalhos)
hl.bind(mod .. " + CTRL + SPACE",
  hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/rice/shell ipc call island toggle"),
  { description = "Abrir/fechar o centro de controle" })

-- Painéis rápidos (mesma lógica do Omarchy: um atalho por assunto)
hl.bind(mod .. " + CTRL + A", hl.dsp.exec_cmd(run("rice-audio")),
  { description = "Áudio: saída, microfone, volume" })
hl.bind(mod .. " + CTRL + W", hl.dsp.exec_cmd(run("rice-network")),
  { description = "Rede: IP, DNS, status" })
hl.bind(mod .. " + CTRL + T", hl.dsp.exec_cmd(run("rice-theme")),
  { description = "Trocar o tema" })
hl.bind(mod .. " + SHIFT + W",
  hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/rice/shell ipc call island papel"),
  { description = "Escolher papel de parede" })
hl.bind(mod .. " + CTRL + P", hl.dsp.exec_cmd(run("rice-pkg")),
  { description = "Instalar/remover programas" })

-- ┌──────────────────────────────────────────────┐
-- │  APLICATIVOS                                  │
-- └──────────────────────────────────────────────┘

hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(App.terminal),
  { description = "Terminal" })
hl.bind(mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(App.browser),
  { description = "Navegador" })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(App.browser),
  { description = "Navegador" })
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(App.filemanager),
  { description = "Gerenciador de arquivos" })
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(App.editor),
  { description = "Editor de texto" })

-- ┌──────────────────────────────────────────────┐
-- │  JANELAS                                      │
-- └──────────────────────────────────────────────┘

hl.bind(mod .. " + W", hl.dsp.window.close(),
  { description = "Fechar janela" })
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }),
  { description = "Alternar flutuante/lado a lado" })
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }),
  { description = "Tela cheia" })
hl.bind(mod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }),
  { description = "Maximizar (respeitando a barra)" })
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"),
  { description = "Alternar divisão horizontal/vertical" })
hl.bind(mod .. " + P", hl.dsp.window.pseudo(),
  { description = "Janela pseudo-tiled" })
hl.bind(mod .. " + C", hl.dsp.window.center(),
  { description = "Centralizar janela flutuante" })

-- Foco
hl.bind(mod .. " + LEFT",  hl.dsp.focus({ direction = "l" }), { description = "Focar janela à esquerda" })
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "r" }), { description = "Focar janela à direita" })
hl.bind(mod .. " + UP",    hl.dsp.focus({ direction = "u" }), { description = "Focar janela acima" })
hl.bind(mod .. " + DOWN",  hl.dsp.focus({ direction = "d" }), { description = "Focar janela abaixo" })

-- Mesmo esquema em vim-keys
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }), { description = "Focar janela à esquerda" })
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }), { description = "Focar janela à direita" })
hl.bind(mod .. " + Y", hl.dsp.focus({ direction = "u" }), { description = "Focar janela acima" })
hl.bind(mod .. " + N", hl.dsp.focus({ direction = "d" }), { description = "Focar janela abaixo" })

-- Trocar janelas de lugar
hl.bind(mod .. " + SHIFT + LEFT",  hl.dsp.window.swap({ direction = "l" }), { description = "Mover janela para a esquerda" })
hl.bind(mod .. " + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }), { description = "Mover janela para a direita" })
hl.bind(mod .. " + SHIFT + UP",    hl.dsp.window.swap({ direction = "u" }), { description = "Mover janela para cima" })
hl.bind(mod .. " + SHIFT + DOWN",  hl.dsp.window.swap({ direction = "d" }), { description = "Mover janela para baixo" })

-- Redimensionar  ( -  e  =  )
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { description = "Estreitar janela" })
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100,  y = 0, relative = true }), { description = "Alargar janela" })
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { description = "Encolher janela" })
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100,  relative = true }), { description = "Esticar janela" })

-- Alternar entre janelas (estilo alt-tab)
hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), { description = "Próxima janela" })
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }), { description = "Janela anterior" })

-- Agrupar janelas em abas
hl.bind(mod .. " + G", hl.dsp.group.toggle(), { description = "Agrupar janelas em abas" })
hl.bind(mod .. " + ALT + LEFT",  hl.dsp.group.prev(), { description = "Aba anterior do grupo" })
hl.bind(mod .. " + ALT + RIGHT", hl.dsp.group.next(), { description = "Próxima aba do grupo" })

-- Mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Arrastar janela" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar janela" })

-- ┌──────────────────────────────────────────────┐
-- │  ÁREAS DE TRABALHO                            │
-- └──────────────────────────────────────────────┘

for ws = 1, 10 do
  local key = tostring(ws % 10) -- a área 10 fica na tecla 0
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = tostring(ws) }),
    { description = "Ir para a área " .. ws })
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(ws) }),
    { description = "Mover janela para a área " .. ws })
end

hl.bind(mod .. " + TAB", hl.dsp.focus({ workspace = "e+1" }), { description = "Próxima área de trabalho" })
hl.bind(mod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), { description = "Área de trabalho anterior" })
hl.bind(mod .. " + CTRL + TAB", hl.dsp.focus({ workspace = "previous" }), { description = "Voltar para a área anterior" })

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Rolar para a próxima área" })
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Rolar para a área anterior" })

-- Scratchpad: uma janela escondida que aparece por cima
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"),
  { description = "Mostrar/esconder o scratchpad" })
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }),
  { description = "Jogar janela no scratchpad" })

-- ┌──────────────────────────────────────────────┐
-- │  CAPTURA DE TELA                              │
-- └──────────────────────────────────────────────┘

-- Mesmo arranjo do Omarchy, para quem vem de lá não reaprender.
hl.bind("PRINT", hl.dsp.exec_cmd(run("rice-screenshot") .. " region"),
  { description = "Print de uma área" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(run("rice-screenshot") .. " output"),
  { description = "Print da tela inteira" })
hl.bind("ALT + PRINT", hl.dsp.exec_cmd(run("rice-record")),
  { description = "Gravar a tela (aperte de novo para parar)" })
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"),
  { description = "Conta-gotas de cor" })
hl.bind(mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd(run("rice-screenshot") .. " window"),
  { description = "Print da janela ativa" })
hl.bind(mod .. " + CTRL + PRINT", hl.dsp.exec_cmd(run("rice-ocr")),
  { description = "Copiar texto da tela (OCR)" })

-- Os mesmos comandos no arranjo do Windows. Não substituem os de cima:
-- teclado sem PRINT dedicado é comum, e quem vem do Windows procura o
-- SUPER+SHIFT+S por reflexo. Ambos chamam exatamente o mesmo script.
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(run("rice-screenshot") .. " region"),
  { description = "Print de uma área (atalho do Windows)" })
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(run("rice-record") .. " region"),
  { description = "Gravar uma área (aperte de novo para parar)" })

-- ┌──────────────────────────────────────────────┐
-- │  TECLAS DE MÍDIA E HARDWARE                   │
-- └──────────────────────────────────────────────┘

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Aumentar volume" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true, description = "Diminuir volume" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true, description = "Mudo" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true, description = "Mudo no microfone" })

-- Brilho por DDC/CI, e não brightnessctl.
--
-- Estas duas teclas NÃO FAZIAM NADA nesta máquina, e sem dar erro: ela é
-- desktop, `/sys/class/backlight` está vazio e o brightnessctl só enxerga
-- LED de placa de rede e de tecla. Ele obedecia ao comando e mudava o
-- brilho de coisa nenhuma.
--
-- Num monitor externo o brilho mora no MONITOR, e se fala com ele pelo
-- cabo de vídeo (DDC/CI, sobre I²C). Ver ~/.local/bin/rice-brilho, que
-- guarda o barramento em cache — é o que derruba cada chamada de 335ms
-- para 67ms e torna o `repeating` abaixo utilizável.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("rice-brilho +5"), { locked = true, repeating = true, description = "Aumentar brilho" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("rice-brilho -5"), { locked = true, repeating = true, description = "Diminuir brilho" })

hl.bind("XF86AudioNext",      hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Próxima faixa" })
hl.bind("XF86AudioPrev",      hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Faixa anterior" })
hl.bind("XF86AudioPlay",      hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Tocar/pausar" })
hl.bind("XF86AudioPause",     hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Tocar/pausar" })

-- ┌──────────────────────────────────────────────┐
-- │  SESSÃO                                       │
-- └──────────────────────────────────────────────┘

-- Recarregar mudou de SUPER+SHIFT+R para SUPER+CTRL+R: o primeiro
-- passou a ser a gravação de área, no arranjo do Windows. Duas ações no
-- mesmo atalho não dão erro no Hyprland — a segunda simplesmente nunca
-- dispara, o que é pior que um conflito visível.
-- Bloquear a tela. Não existia atalho nenhum para isso até agora.
--
-- SUPER+SHIFT+L e não SUPER+L: este último já é "focar janela à
-- direita", no arranjo hjkl. Atalho duplicado não gera erro no
-- Hyprland — o segundo simplesmente nunca dispara.
--
-- O `pidof` evita empilhar instâncias quando se aperta duas vezes.
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"),
  { description = "Bloquear a tela" })

hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("hyprctl reload && notify-send 'Hyprland' 'Configuração recarregada'"),
  { description = "Recarregar a configuração" })
hl.bind(mod .. " + SHIFT + ALT + Q", hl.dsp.exit(),
  { description = "Encerrar a sessão do Hyprland" })

-- ┌──────────────────────────────────────────────┐
-- │  PERFIS DE TELA POR JOGO                      │
-- └──────────────────────────────────────────────┘
--
-- Cada perfil é uma correção de cor pensada para UM jogo — ver os
-- comentários em ~/.config/hypr/shaders/*.frag e o shaders-LEIA-ME.txt.
-- Todos partem da mesma base: a compensação da gama 2.4 do modo Cinema
-- do monitor mais o pé da curva, que juntos devolvem a sombra que o
-- painel VA engole, e vibrance no lugar de saturação plana.
--
-- O 7 é a exceção e o mais usado no dia a dia: o `gaming` é genérico,
-- sem cor nenhuma (lift, gama e ganho são a identidade matemática), para
-- jogo que ainda não tem perfil próprio.
--
-- SUPER+ALT+<número> e não SUPER+<número>: este último já troca de
-- área de trabalho. Atalho duplicado não dá erro no Hyprland — o
-- segundo simplesmente nunca dispara, e a busca pelo motivo é longa.
--
-- Os números 1 a 6 NÃO foram renumerados quando o `gaming` entrou, e é
-- por isso que o genérico ficou no 7 em vez do 1: atalho que muda de
-- destino conforme a pasta cresce é atalho que ninguém decora.
--
-- O 0 volta ao vivido, que é o padrão do sistema. NÃO é "sem shader":
-- sem shader a tela fica apagada, que é o estado que o rice corrige.
--
-- Os perfis não sobrevivem a `hyprctl reload` (SUPER+CTRL+R), porque o
-- reload devolve o shader ao que está no decor.lua. Na prática não
-- incomoda: ninguém recarrega o Hyprland no meio de uma partida.
hl.bind(mod .. " + ALT + 1", hl.dsp.exec_cmd(run("rice-shader") .. " lies-of-p"),
  { description = "Tela: Lies of P (âmbar sobre azul-petróleo)" })
hl.bind(mod .. " + ALT + 2", hl.dsp.exec_cmd(run("rice-shader") .. " breakpoint"),
  { description = "Tela: Ghost Recon Breakpoint (selva, dessaturado)" })
hl.bind(mod .. " + ALT + 3", hl.dsp.exec_cmd(run("rice-shader") .. " witcher3"),
  { description = "Tela: The Witcher 3 (terroso, contraste alto)" })
hl.bind(mod .. " + ALT + 4", hl.dsp.exec_cmd(run("rice-shader") .. " rdr2"),
  { description = "Tela: Red Dead Redemption 2 (laranja e petróleo)" })
hl.bind(mod .. " + ALT + 5", hl.dsp.exec_cmd(run("rice-shader") .. " gtav"),
  { description = "Tela: GTA V (sol de Los Santos, bleach bypass)" })
hl.bind(mod .. " + ALT + 6", hl.dsp.exec_cmd(run("rice-shader") .. " alien-isolation"),
  { description = "Tela: Alien Isolation (frio, o mais escuro)" })
hl.bind(mod .. " + ALT + 7", hl.dsp.exec_cmd(run("rice-shader") .. " gaming"),
  { description = "Tela: genérico para jogos (sem cor, só vibrance)" })
hl.bind(mod .. " + ALT + 0", hl.dsp.exec_cmd(run("rice-shader") .. " off"),
  { description = "Tela: voltar ao padrão do sistema" })
