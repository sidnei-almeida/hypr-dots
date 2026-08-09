// Seletor de papel de parede: grade de miniaturas, mais um estado da
// island. Escolher wallpaper por nome de arquivo não faz sentido — aqui
// se escolhe olhando.
//
// A pasta vem de pill.json (wallpaperDir). Aplicar usa o hyprpaper e
// grava o hyprpaper.conf, para o papel voltar no próximo login.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool aberto: false
    signal fechar

    property int selecionado: 0
    property var arquivos: []

    readonly property int colunas: 3

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 130 : 0 }
            NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
        }
    }

    // ── Lista de arquivos ───────────────────────────────────────
    // `find` em vez de FolderListModel: assim dá para filtrar as
    // extensões que o Qt realmente abre e ordenar de uma vez só.
    Process {
        id: varredura
        // A pasta oficial vem primeiro; as extras depois. O QML descarta
        // repetidos pelo nome do arquivo, então uma imagem já adotada não
        // aparece duas vezes.
        command: ["bash", "-c",
            // `set -f` DESLIGA a expansão de caminho, e sem ele isto é uma
            // bomba-relógio.
            //
            // O `$tipos` logo abaixo vai SEM aspas de propósito: é assim
            // que ele se quebra nas palavras que o find espera. Só que
            // word splitting e globbing acontecem juntos — então os
            // `*.jpg` do meio também são expandidos, contra o DIRETÓRIO
            // DE TRABALHO do processo.
            //
            // Enquanto o qs sobe do $HOME (que não tem imagem solta), os
            // padrões não casam com nada e sobrevivem literais. Basta
            // subir a barra de dentro de uma pasta com um .jpg para o
            // find receber `-iname foto.jpg -o ...` e responder
            //   find: paths must precede expression
            // A varredura devolve zero, e o seletor anuncia "Nenhuma
            // imagem em ~/Pictures/Wallpapers" — apontando para uma pasta
            // cheia. O sintoma não tem nada a ver com a causa, e é por
            // isso que este comentário é longo.
            "set -f; " +
            "tipos=\"-iname *.jpg -o -iname *.jpeg -o -iname *.png -o -iname *.webp -o -iname *.bmp\"; " +
            "find \"$1\" -maxdepth 1 -type f \\( $tipos \\) 2>/dev/null | sort; " +
            "IFS=: read -ra extras <<< \"$2\"; " +
            "for d in \"${extras[@]}\"; do " +
            "  [ -d \"$d\" ] || continue; " +
            "  [ \"$d\" = \"$1\" ] && continue; " +
            "  find \"$d\" -maxdepth 1 -type f \\( $tipos \\) 2>/dev/null | sort; " +
            "done",
            "_", PraxeConfig.wallpaperDir, PraxeConfig.wallpaperExtras]
        stdout: StdioCollector {
            onStreamFinished: {
                const vistos = {}
                const lista = []
                for (const linha of text.trim().split("\n")) {
                    if (linha.length === 0) continue
                    const nome = linha.substring(linha.lastIndexOf("/") + 1)
                    if (vistos[nome]) continue        // já adotado
                    vistos[nome] = true
                    lista.push({
                        caminho: linha,
                        externo: linha.indexOf(PraxeConfig.wallpaperDir + "/") !== 0
                    })
                }
                root.arquivos = lista
                root.selecionado = 0
            }
        }
    }

    onAbertoChanged: if (aberto) varredura.running = true
    Component.onCompleted: varredura.running = true

    // ── Aplicar ─────────────────────────────────────────────────
    Process { id: aplicador }

    function aplicarItem(item) {
        if (item.externo) adotar(item.caminho)
        else aplicar(item.caminho)
    }

    // Copia para a pasta oficial e aplica a CÓPIA — o original fica onde
    // estava. Se já existir um arquivo com o mesmo nome, mantém o antigo.
    function adotar(origem) {
        adotador.command = ["bash", "-c",
            "mkdir -p \"$2\"; destino=\"$2/$(basename \"$1\")\"; " +
            "[ -e \"$destino\" ] || cp -- \"$1\" \"$destino\"; " +
            "printf '%s' \"$destino\"",
            "_", origem, PraxeConfig.wallpaperDir]
        adotador.running = true
    }

    Process {
        id: adotador
        stdout: StdioCollector {
            onStreamFinished: {
                const destino = text.trim()
                if (destino.length > 0) {
                    root.aplicar(destino)
                    varredura.running = true   // a grade reordena com o novo
                }
            }
        }
    }

    function aplicar(caminho) {
        // Nesta versão do hyprpaper só existem `wallpaper` e `listactive`;
        // o `wallpaper` já carrega a imagem sozinho. E gravamos o .conf
        // para o papel sobreviver ao próximo login.
        aplicador.command = ["bash", "-c",
            // Grava o .conf ANTES de subir o hyprpaper: ele lê a
            // configuração só na inicialização. Foi assim que o splash
            // do Hyprland ficou aparecendo por horas mesmo com
            // `splash = false` no arquivo — o processo era anterior a ele.
            "printf 'preload = %s\\nwallpaper = ,%s\\nsplash = false\\nipc = on\\n' \"$1\" \"$1\" " +
            "> \"$HOME/.config/hypr/hyprpaper.conf\"; " +
            "pgrep -x hyprpaper >/dev/null || (setsid -f hyprpaper >/dev/null 2>&1; sleep 1); " +
            "hyprctl hyprpaper wallpaper \",$1\" >/dev/null; " +
            // ── Tema automático, se ligado ───────────────────
            //
            // Com `autoTema` no pill.json, escolher um papel DERIVA a
            // paleta dele: o rice-auto grava um tema do usuário a partir
            // da imagem e o aplica. Desligado, o comportamento é o de
            // sempre — só reaplica o tema em vigor.
            //
            // Reaplicar é obrigatório nos dois casos: o caminho do papel
            // fica gravado dentro do hyprlock.conf, e sem isso a tela de
            // bloqueio continuaria mostrando a imagem antiga.
            // ── Com tema automático ──────────────────────────
            //
            // O rice-auto grava um tema do usuário derivado DESTA imagem e
            // o aplica. Como o tema criado já declara este papel, aplicá-lo
            // não desfaz a escolha.
            (PraxeConfig.autoTema
              ? "\"$HOME/.local/bin/rice-auto\" --aplicar \"$1\" >/dev/null 2>&1 && exit 0; "
              : "") +

            // ── Sem tema automático ─────────────────────────────
            //
            // `RICE_SEM_PAPEL=1` é o que faz a troca de papel FUNCIONAR.
            //
            // Reaplicar o tema é obrigatório: o caminho do papel fica
            // gravado dentro do hyprlock.conf, e sem isso a tela de bloqueio
            // continuaria com a imagem antiga. Só que o rice-theme, ao ser
            // reaplicado, reescrevia o hyprpaper.conf com o papel DO TEMA —
            // e a imagem recém-escolhida voltava para a anterior um quadro
            // depois, sem mensagem nenhuma. Era impossível trocar de papel.
            //
            // A variável faz aquela chamada pular só o bloco do papel de
            // parede. Tudo o mais é regerado normalmente.
            "RICE_SEM_PAPEL=1 \"$HOME/.local/bin/rice-theme\" set " +
            "\"$(\"$HOME/.local/bin/rice-theme\" current)\" >/dev/null 2>&1",
            "_", caminho]
        aplicador.running = true
    }

    function nomeDe(caminho) {
        const base = caminho.substring(caminho.lastIndexOf("/") + 1)
        const ponto = base.lastIndexOf(".")
        return ponto > 0 ? base.substring(0, ponto) : base
    }

    function mover(passo) {
        const n = arquivos.length
        if (n === 0) return
        selecionado = (selecionado + passo % n + n) % n
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * Theme.scale)
        spacing: Math.round(10 * Theme.scale)

        // ── Cabeçalho ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * Theme.scale)

            Text {
                text: "󰸉"
                color: PraxeConfig.colAccent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(15 * Theme.scale)
            }

            Text {
                Layout.fillWidth: true
                text: Idioma.t("app.wallpaper")
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }

            Text {
                text: root.arquivos.filter(a => a.externo).length > 0
                      ? "󰐕 " + Idioma.t("wall.copies")
                      : ""
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }

            Text {
                text: root.arquivos.length
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: PraxeConfig.colDim
            opacity: 0.5
        }

        // ── Criar tema a partir do papel ────────────────────
        //
        // As duas coisas são SEPARADAS, e este interruptor é o que diz
        // qual delas o clique numa imagem vai fazer:
        //
        //   desligado → troca só o papel de parede. O tema em vigor fica.
        //   ligado    → deriva a paleta DESTA imagem, cria um tema do
        //               usuário e o aplica.
        //
        // Fica aqui, e não no painel de aparência, porque a decisão é
        // sobre o que o PRÓXIMO clique faz — precisa estar à vista no
        // momento da escolha, senão vira surpresa. O estado mora no
        // pill.json e sobrevive ao fechamento do painel.
        Item {
            Layout.fillWidth: true
            implicitHeight: linhaAuto.implicitHeight

            RowLayout {
                id: linhaAuto
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Math.round(9 * Theme.scale)

                // Interruptor: trilho com um botão que corre de um lado ao
                // outro. Redondo e pequeno de propósito — não deve competir
                // com as miniaturas, que são o assunto desta tela.
                Rectangle {
                    id: trilho
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Math.round(34 * Theme.scale)
                    implicitHeight: Math.round(18 * Theme.scale)
                    radius: height / 2
                    color: PraxeConfig.autoTema ? PraxeConfig.colAccent : PraxeConfig.colDim
                    opacity: PraxeConfig.autoTema ? 0.95 : 0.55
                    Behavior on color   { ColorAnimation  { duration: 160 } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Rectangle {
                        width: Math.round(13 * Theme.scale)
                        height: width
                        radius: width / 2
                        color: PraxeConfig.colBgPuro
                        anchors.verticalCenter: parent.verticalCenter
                        x: PraxeConfig.autoTema
                           ? parent.width - width - Math.round(2.5 * Theme.scale)
                           : Math.round(2.5 * Theme.scale)
                        // Mola curta: o botão precisa CHEGAR junto com o
                        // dedo, não depois dele.
                        Behavior on x {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: Idioma.t("wall.autotheme")
                        color: PraxeConfig.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: PraxeConfig.autoTema ? Idioma.t("wall.autotheme.on")
                                                   : Idioma.t("wall.autotheme.off")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                        elide: Text.ElideRight
                    }
                }
            }

            // A área de clique cobre a linha inteira, não só o interruptor:
            // alvo de 34px é pequeno demais para um alvo de mouse, e o
            // rótulo ao lado já parece parte do mesmo controle.
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: chaveAuto.exec([PraxeConfig.bin + "rice-pill", "set",
                                          "autoTema", PraxeConfig.autoTema ? "false" : "true"])
            }
        }

        Process { id: chaveAuto }

        // ── Aviso de pasta vazia ────────────────────────────
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.arquivos.length === 0
            text: Idioma.tf("wall.empty", "\n" + PraxeConfig.wallpaperDir)
            color: PraxeConfig.colMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }

        // ── Grade de miniaturas ─────────────────────────────
        GridView {
            id: grade
            visible: root.arquivos.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.arquivos
            currentIndex: root.selecionado

            cellWidth: Math.floor(width / root.colunas)
            cellHeight: Math.round(cellWidth * 0.62)

            delegate: Item {
                required property var modelData
                required property int index

                width: grade.cellWidth
                height: grade.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(4 * Theme.scale)
                    radius: Math.round(10 * Theme.scale)
                    color: Theme.bgAlt
                    clip: true

                    border.width: index === root.selecionado ? 2 : 0
                    border.color: PraxeConfig.colAccent
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: index === root.selecionado ? 2 : 0
                        source: "file://" + modelData.caminho
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Miniatura pequena: carregar a imagem inteira para
                        // um quadro de 200px come memória à toa.
                        sourceSize.width: 320
                        cache: true
                    }

                    // Selo de "vem de fora": marca o que ainda não foi
                    // adotado, para ficar claro que escolher vai copiar.
                    Rectangle {
                        visible: modelData.externo
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Math.round(5 * Theme.scale)
                        width: Math.round(18 * Theme.scale)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(PraxeConfig.colAccent.r, PraxeConfig.colAccent.g,
                                       PraxeConfig.colAccent.b, 0.90)

                        Text {
                            anchors.centerIn: parent
                            text: "󰐕"
                            color: Theme.bg
                            font.family: Theme.nerdFontFamily
                            font.pixelSize: Math.round(11 * Theme.scale)
                        }
                    }

                    // Nome, só quando o item está selecionado ou sob o mouse
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.round(20 * Theme.scale)
                        color: Qt.rgba(0, 0, 0, 0.6)
                        visible: index === root.selecionado || area.containsMouse

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            text: root.nomeDe(modelData.caminho)
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selecionado = index
                        onClicked: {
                            root.selecionado = index
                            root.aplicarItem(modelData)
                        }
                    }
                }
            }

            // Teclado
            focus: root.aberto
            Keys.onLeftPressed:  root.mover(-1)
            Keys.onRightPressed: root.mover(1)
            Keys.onUpPressed:    root.mover(-root.colunas)
            Keys.onDownPressed:  root.mover(root.colunas)
            Keys.onReturnPressed: if (root.arquivos.length > 0) root.aplicarItem(root.arquivos[root.selecionado])
            Keys.onEnterPressed:  if (root.arquivos.length > 0) root.aplicarItem(root.arquivos[root.selecionado])
            Keys.onEscapePressed: root.fechar()
        }
    }
}
