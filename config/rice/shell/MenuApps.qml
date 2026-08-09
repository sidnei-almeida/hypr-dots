// ┌──────────────────────────────────────────────────────────────┐
// │  O menu de aplicativos do modo BARRA.                         │
// └──────────────────────────────────────────────────────────────┘
//
// Desce do logo do Arch, na ponta esquerda. É o gesto do botão iniciar:
// canto da tela, menu colado nele.
//
// ── POR QUE NÃO É O Launcher.qml ────────────────────────────────
//
// O Launcher é a GOTA DO NOTCH: nasce de um recorte de 95px no centro da
// tela e cresce para 620x440, um retângulo largo e baixo, centralizado.
// Faz sentido lá — o notch está no meio, e crescer para os lados é o
// movimento natural dele.
//
// Um menu de barra nasce num BOTÃO DE CANTO e desce colado à borda. Alto
// e estreito, porque largo a partir do canto cobre metade da tela e
// porque a lista cresce para baixo, não para os lados. São geometrias
// opostas; forçar uma na outra é o que não encaixava.
//
// O que É reaproveitado: o jeito de listar e lançar, que já está certo e
// tem cicatriz. Ver a nota das strings logo abaixo.

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool aberto: false
    signal fechar()

    // Medidas do desenho escolhido: coluna estreita e alta.
    readonly property int larguraMenu: Math.round(380 * Theme.scale)
    readonly property int alturaMenu:  Math.round(520 * Theme.scale)

    property string busca: ""
    property int selecionado: 0
    property var todos: []

    // ── A REGRA DAS STRINGS (não simplifique de volta) ──────────
    //
    // A lista guarda TEXTO, nunca o `DesktopEntry*`. Um mapa comum não
    // segura o objeto vivo — é ponteiro cru — e o Repeater INCUBA o
    // delegate, adiando a construção. Se a entrada morrer no intervalo (e
    // morre: a varredura substitui duplicadas enquanto roda, e um pacman
    // reescreve .desktop debaixo do shell), o Qt converte ponteiro morto e
    // derruba o Quickshell inteiro. É o SIGSEGV documentado no Dock.qml e
    // no Launcher.qml. Quem precisa do objeto o pede pelo id na hora.
    function carregar() {
        const lista = []
        const entradas = DesktopEntries.applications.values
        for (let i = 0; i < entradas.length; i++) {
            const e = entradas[i]
            if (e.noDisplay) continue
            lista.push({ id: e.id, nome: e.name, descricao: e.comment || "", icone: e.icon })
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

    // `applicationsChanged` dispara UMA VEZ POR ENTRADA na subida — mais de
    // cem. Sem o timer, `carregar()` reordena a lista inteira cem vezes e as
    // views re-incubam todos os delegates a cada uma. O timer engole a
    // rajada e recarrega uma vez, quando ela para.
    Timer {
        id: assentar
        interval: 120
        onTriggered: root.carregar()
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { assentar.restart() }
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

    function lancar(id) {
        const app = DesktopEntries.byId(id ?? filtrados[selecionado]?.id)
        if (!app) return
        if (app.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", app.command.join(" ")])
        else
            app.execute()
        root.fechar()
    }

    function mover(passo) {
        const n = filtrados.length
        if (n === 0) return
        selecionado = (selecionado + passo + n) % n
        lista.positionViewAtIndex(selecionado, ListView.Contain)
    }

    visible: aberto
    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * Theme.scale)
        spacing: Math.round(10 * Theme.scale)

        // ── Busca ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(34 * Theme.scale)
            radius: Math.round(8 * Theme.scale)
            color: PraxeConfig.colBgPuro
            opacity: 0.55

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * Theme.scale)
                anchors.rightMargin: Math.round(10 * Theme.scale)
                spacing: Math.round(8 * Theme.scale)

                Text {
                    text: "󰍉"
                    color: PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Theme.iconSize
                }

                TextInput {
                    id: campo
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: PraxeConfig.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    clip: true
                    onTextChanged: root.busca = text

                    // Teclado: setas andam, Enter lança, Esc fecha. É o
                    // mínimo para o menu ser usável sem tirar a mão do
                    // teclado — que é como um menu iniciar costuma ser usado
                    // depois da primeira semana.
                    Keys.onDownPressed:   root.mover(1)
                    Keys.onUpPressed:     root.mover(-1)
                    Keys.onReturnPressed: root.lancar(null)
                    Keys.onEnterPressed:  root.lancar(null)
                    Keys.onEscapePressed: root.fechar()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Idioma.t("launcher.search")
                        color: PraxeConfig.colDim
                        font: campo.font
                        visible: campo.text.length === 0
                    }
                }
            }
        }

        // ── A lista ─────────────────────────────────────────────
        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filtrados
            currentIndex: root.selecionado
            boundsBehavior: Flickable.StopAtBounds
            spacing: Math.round(2 * Theme.scale)

            delegate: Item {
                required property int index
                required property var modelData

                width: lista.width
                height: Math.round(40 * Theme.scale)

                readonly property bool marcado: index === root.selecionado

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(8 * Theme.scale)
                    color: PraxeConfig.colAccent
                    // Só o item sob o teclado ou sob o mouse recebe fundo:
                    // uma lista inteira com caixas atrás vira uma escada de
                    // retângulos e o nome do app deixa de ser o que se lê.
                    opacity: parent.marcado ? 0.20 : (sonda.hovered ? 0.10 : 0)
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * Theme.scale)
                    anchors.rightMargin: Math.round(10 * Theme.scale)
                    spacing: Math.round(10 * Theme.scale)

                    IconImage {
                        implicitSize: Math.round(22 * Theme.scale)
                        // `file://` via iconPath: ele devolve caminho de
                        // sistema e o IconImage espera URL.
                        source: modelData.icone ? Quickshell.iconPath(modelData.icone, true) : ""
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.nome
                        color: PraxeConfig.colFg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: sonda
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selecionado = index
                }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.lancar(modelData.id)
                }
            }
        }

        // ── Rodapé: sessão e energia ────────────────────────────
        //
        // Mesmos comandos do rice-menu, de propósito: dois caminhos para a
        // mesma ação têm de fazer exatamente a mesma coisa, senão um dia um
        // deles desliga diferente do outro.
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(6 * Theme.scale)

            component Energia: Item {
                id: bt
                property string glifo: ""
                property var comando: []
                property string dica: ""

                implicitWidth: Math.round(38 * Theme.scale)
                implicitHeight: Math.round(30 * Theme.scale)

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(7 * Theme.scale)
                    color: PraxeConfig.colFg
                    opacity: btHover.hovered ? 0.12 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: bt.glifo
                    color: btHover.hovered ? PraxeConfig.colFg : PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Theme.iconSize
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                HoverHandler { id: btHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: { Quickshell.execDetached(bt.comando); root.fechar() }
                }
            }

            Energia { glifo: "󰌾"; comando: ["loginctl", "lock-session"] }
            Energia { glifo: "󰤄"; comando: ["systemctl", "suspend"] }
            Item { Layout.fillWidth: true }
            Energia { glifo: "󰜉"; comando: ["systemctl", "reboot"] }
            Energia { glifo: "󰐥"; comando: ["systemctl", "poweroff"] }
        }
    }
}
