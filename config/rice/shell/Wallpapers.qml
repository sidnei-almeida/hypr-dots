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
            // O bloqueio usa o papel de fundo, e o caminho fica gravado
            // dentro do hyprlock.conf. Sem reaplicar o tema, a tela de
            // bloqueio continuaria mostrando a imagem antiga.
            "\"$HOME/.local/bin/rice-theme\" set " +
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
