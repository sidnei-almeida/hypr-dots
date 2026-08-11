// Lançador de aplicativos do PraXe.
//
// É mais um estado da island: a mesma cápsula crescendo, com a mesma
// paleta e os mesmos raios. Duas formas de ver a lista, alternadas com
// Tab ou pelo botão no canto:
//
//   lista   ícone + nome + descrição, uma por linha
//   grade   só ícone e nome, em colunas
//
// A escolha fica salva em pill.json, na chave launcherView.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property bool aberto: false
    signal fechar

    // "lista" ou "grade"
    property string modo: PraxeConfig.launcherView
    readonly property bool emGrade: modo === "grade"

    property string busca: ""
    property int selecionado: 0

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 130 : 0 }
            NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
        }
    }

    // ── Aplicativos ─────────────────────────────────────────────
    property var todos: []

    // O item guarda o ID da entrada, e NUNCA a entrada em si.
    //
    // Guardar `entrada: e` aqui era um DesktopEntry* — um ponteiro cru —
    // dentro de um mapa que vira model de ListView/GridView. O mapa não
    // segura o objeto vivo, e a view não constrói o delegate na hora: ela
    // INCUBA, adiando a construção. Se a entrada morresse nesse intervalo
    // (e morre: a varredura substitui entradas duplicadas enquanto roda, e
    // um `pacman` reescreve .desktop debaixo do shell), o Qt convertia um
    // ponteiro morto e derrubava o Quickshell inteiro — o SIGSEGV em
    // fromQVariantMap -> fromData que aparecia no coredump.
    //
    // Com o id, o mapa é só texto. Quem precisa do objeto o pede na hora
    // de usar, e aí ele está vivo por construção. Ver a mesma nota, mais
    // longa, no Dock.qml.
    function carregar() {
        const lista = []
        const entradas = DesktopEntries.applications.values
        for (let i = 0; i < entradas.length; i++) {
            const e = entradas[i]
            if (e.noDisplay) continue
            lista.push({
                id: e.id,
                nome: e.name,
                descricao: e.comment || "",
                icone: e.icon
            })
        }
        lista.sort((a, b) => a.nome.localeCompare(b.nome))
        todos = lista
    }

    readonly property var filtrados: {
        if (busca.length === 0) return todos
        const q = busca.toLowerCase()
        return todos.filter(a => a.nome.toLowerCase().includes(q)
                              || a.descricao.toLowerCase().includes(q))
    }

    onFiltradosChanged: selecionado = 0

    // `applicationsChanged` dispara UMA VEZ POR ENTRADA achada — mais de
    // cem na subida do shell. Sem o timer, `carregar()` refazia e reordenava
    // a lista inteira cem vezes, e a cada vez as views jogavam fora e
    // re-incubavam todos os delegates. Além de ser desperdício puro na hora
    // mais cara (a subida), era esse vaivém que dava chance de o delegate
    // nascer com dado já vencido.
    //
    // O timer engole a rajada: recarrega uma vez, quando ela para.
    Timer {
        id: assentarApps
        interval: 120
        onTriggered: root.carregar()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { assentarApps.restart() }
    }

    Component.onCompleted: carregar()

    onAbertoChanged: {
        if (aberto) {
            busca = ""
            campo.text = ""
            selecionado = 0
            campo.forceActiveFocus()
        }
    }

    // A entrada é buscada AGORA, pelo id, e não guardada desde a listagem.
    // No instante do clique ela está viva por construção — ver a nota em
    // `carregar()` sobre por que guardar o ponteiro derrubava o shell.
    function lancar() {
        if (filtrados.length === 0) return
        const app = DesktopEntries.byId(filtrados[selecionado].id)
        if (!app) return
        if (app.runInTerminal) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", app.command.join(" ")])
        } else {
            app.execute()
        }
        root.fechar()
    }

    function mover(passo) {
        const n = filtrados.length
        if (n === 0) return
        selecionado = (selecionado + passo % n + n) % n
    }

    // Quantas colunas cabem na grade
    readonly property int colunas: 5

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * Theme.scale)
        spacing: Math.round(10 * Theme.scale)

        // ── Campo de busca ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * Theme.scale)

            Text {
                text: "󰍉"
                color: PraxeConfig.colAccent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(15 * Theme.scale)
            }

            TextField {
                id: campo
                Layout.fillWidth: true
                placeholderText: Idioma.t("app.launcher.search")
                color: PraxeConfig.colFg
                placeholderTextColor: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                background: null
                padding: 0
                onTextChanged: root.busca = text

                Keys.onDownPressed: root.mover(root.emGrade ? root.colunas : 1)
                Keys.onUpPressed:   root.mover(root.emGrade ? -root.colunas : -1)
                Keys.onRightPressed: if (root.emGrade) root.mover(1)
                Keys.onLeftPressed:  if (root.emGrade) root.mover(-1)
                Keys.onReturnPressed: root.lancar()
                Keys.onEnterPressed:  root.lancar()
                Keys.onEscapePressed: root.fechar()
                Keys.onTabPressed: root.modo = root.emGrade ? "lista" : "grade"
            }

            // Alterna lista/grade
            Text {
                text: root.emGrade ? "󰋲" : "󰕰"
                color: alterna.containsMouse ? PraxeConfig.colAccent : PraxeConfig.colMuted
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(15 * Theme.scale)
                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: alterna
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modo = root.emGrade ? "lista" : "grade"
                }
            }

            Text {
                text: root.filtrados.length
                // Regra da casa: DIM só para traço decorativo (separador,
                // borda). Como TEXTO ele fica entre 1.6 e 2.2 de contraste
                // sobre o fundo em todos os temas — ilegível. Texto
                // secundário usa MUTED.
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

        // ── Em lista ────────────────────────────────────────
        ListView {
            id: emLista
            visible: !root.emGrade
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.emGrade ? [] : root.filtrados
            currentIndex: root.selecionado
            highlightMoveDuration: 160
            spacing: Math.round(2 * Theme.scale)

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: emLista.width
                height: Math.round(42 * Theme.scale)
                radius: Theme.raioM
                // Elevação neutra + traço de acento à esquerda. Acento
                // preenchendo a linha inteira pesa e cansa a vista.
                color: index === root.selecionado
                       ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                 PraxeConfig.colFg.b, 0.10)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 130 } }

                // O traço que marca a seleção
                Rectangle {
                    visible: index === root.selecionado
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Math.round(3 * Theme.scale)
                    width: Math.round(2 * Theme.scale)
                    height: parent.height * 0.55
                    radius: width / 2
                    color: PraxeConfig.colAccent
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * Theme.scale)
                    anchors.rightMargin: Math.round(10 * Theme.scale)
                    spacing: Math.round(11 * Theme.scale)

                    IconImage {
                        Layout.preferredWidth: Math.round(24 * Theme.scale)
                        Layout.preferredHeight: Layout.preferredWidth
                        source: Quickshell.iconPath(modelData.icone, true)
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.nome
                            color: PraxeConfig.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.descricao
                            color: PraxeConfig.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            visible: text !== ""
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selecionado = index
                    onClicked: { root.selecionado = index; root.lancar() }
                }
            }
        }

        // ── Em grade ────────────────────────────────────────
        GridView {
            id: emGradeView
            visible: root.emGrade
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.emGrade ? root.filtrados : []
            currentIndex: root.selecionado

            cellWidth: Math.floor(width / root.colunas)
            cellHeight: Math.round(86 * Theme.scale)

            delegate: Item {
                required property var modelData
                required property int index

                width: emGradeView.cellWidth
                height: emGradeView.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(3 * Theme.scale)
                    radius: Theme.raioM
                    color: index === root.selecionado
                           ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                     PraxeConfig.colFg.b, 0.10)
                           : "transparent"
                    border.width: index === root.selecionado ? 1 : 0
                    border.color: Qt.rgba(PraxeConfig.colAccent.r, PraxeConfig.colAccent.g,
                                          PraxeConfig.colAccent.b, 0.55)
                    Behavior on color { ColorAnimation { duration: 130 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * Theme.scale)

                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Math.round(34 * Theme.scale)
                            Layout.preferredHeight: Layout.preferredWidth
                            source: Quickshell.iconPath(modelData.icone, true)
                            asynchronous: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: emGradeView.cellWidth - Math.round(12 * Theme.scale)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            text: modelData.nome
                            color: PraxeConfig.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selecionado = index
                        onClicked: { root.selecionado = index; root.lancar() }
                    }
                }
            }
        }
    }
}
