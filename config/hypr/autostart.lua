-- O que sobe junto com a sessão.
-- Tudo é protegido com `command -v`, então nada quebra se um programa não
-- estiver instalado — ele só não sobe.

local function if_present(cmd, run)
  return "command -v " .. cmd .. " >/dev/null 2>&1 && " .. (run or cmd)
end

hl.on("hyprland.start", function()
  -- Repassa as variáveis da sessão para o systemd e o D-Bus.
  -- Sem isso, portais e apps lançados pelo menu abrem lentos ou sem tema.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  -- BLOQUEIO NA ENTRADA — primeiro de tudo, e por um motivo.
  --
  -- O login desta máquina é autologin no tty1: a sessão sobe sem senha
  -- e o hyprlock é quem pede a autenticação. Ele precisa cobrir a tela
  -- ANTES de qualquer janela restaurada aparecer, senão haveria uma
  -- fresta em que o desktop fica à mostra.
  --
  -- Se algum dia ele falhar e prender a sessão: CTRL+ALT+F2 abre outro
  -- tty (esse pede senha de verdade), e lá um `pkill hyprlock` resolve.
  -- `--grace 0` e não `--immediate`: o segundo está obsoleto. O
  -- `--immediate-render` desenha o fundo sem esperar recurso nenhum,
  -- que é o que fecha a fresta em que o desktop apareceria.
  hl.exec_cmd(if_present("hyprlock", "hyprlock --grace 0 --immediate-render --no-fade-in"))

  -- Agente de autenticação: sem ele, pedidos de senha gráficos não aparecem
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

  -- Notificações: quem atende agora é a island (Quickshell), não o dunst.
  --
  -- NÃO BASTA não iniciar o dunst aqui, e por muito tempo foi só isso o
  -- que este bloco fazia. O dunst é ATIVADO POR D-BUS: o arquivo
  -- /usr/share/dbus-1/services/org.knopwob.dunst.service reivindica
  -- org.freedesktop.Notifications e manda o systemd subir dunst.service
  -- na primeira notificação que alguém disparar. Ele ganhava a corrida,
  -- ficava com o nome, e os avisos saíam na caixa azul padrão dele — que
  -- não tem nada a ver com o tema e parece sistema quebrado.
  --
  -- O que segura de verdade é a máscara, já aplicada e persistente:
  --     systemctl --user mask dunst.service
  -- (o symlink mora em ~/.config/systemd/user/dunst.service -> /dev/null,
  -- então sobrevive a atualização do pacote). Para desfazer:
  --     systemctl --user unmask dunst.service
  --
  -- Assim que o dunst para, o servidor do Quickshell (Notificacoes.qml)
  -- assume o nome sozinho — não precisa reiniciar a barra.

  -- Vigia: percebe a barra sumindo da tela e a traz de volta.
  -- O processo pode ficar vivo sem superfície nenhuma, então checar
  -- por pgrep não bastaria.
  hl.exec_cmd(if_present("qs", os.getenv("HOME") .. "/.local/bin/rice-bar-watch"))

  -- A pill (nossa barra, em Quickshell) — ~/.config/rice/shell
  hl.exec_cmd(if_present("qs", "qs -p " .. os.getenv("HOME") .. "/.config/rice/shell"))

  -- Papel de parede.
  --
  -- Vai pelo rice-paper-start, e não pelo `hyprpaper` cru, porque o
  -- hyprpaper às vezes sobe antes do monitor existir e aplica o papel
  -- em ninguém — processo vivo, tela preta, nada nos logs. O script
  -- confere pelo `listactive` e reaplica se preciso.
  hl.exec_cmd(if_present("hyprpaper", os.getenv("HOME") .. "/.local/bin/rice-paper-start"))

  -- Bloqueio automático por inatividade
  hl.exec_cmd(if_present("hypridle"))

  -- Histórico da área de transferência (SUPER + CTRL + V)
  hl.exec_cmd(if_present("cliphist", "wl-paste --type text  --watch cliphist store"))
  hl.exec_cmd(if_present("cliphist", "wl-paste --type image --watch cliphist store"))
end)
