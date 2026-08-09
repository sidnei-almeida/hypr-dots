// O balão de notificação: a island virando uma cápsula com o aviso.
//
// Mesma ideia do OSD de volume — não é janela nova, é a mesma
// superfície mudando de forma. Clicar dispensa.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool aberto: false
    readonly property var item: Notificacoes.atual

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 120 : 0 }
            NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(16 * Theme.scale)
        anchors.rightMargin: Math.round(16 * Theme.scale)
        spacing: Math.round(12 * Theme.scale)

        // Ícone do app, ou um sino quando não vem nada
        Rectangle {
            Layout.preferredWidth: Math.round(30 * Theme.scale)
            Layout.preferredHeight: Layout.preferredWidth
            radius: width / 2
            color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                           PraxeConfig.colFg.b, 0.06)

            Image {
                anchors.centerIn: parent
                width: Math.round(18 * Theme.scale)
                height: width
                source: root.item?.imagem !== "" ? (root.item?.imagem ?? "")
                                                 : (root.item?.icone ?? "")
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }

            Text {
                readonly property bool kanji: PraxeConfig.simbolos === "kanji"
                anchors.centerIn: parent
                text: kanji ? Notificacoes.marcador(root.item?.urgencia) : "󰂚"
                color: PraxeConfig.colAccent
                font.family: kanji ? Notificacoes.fonteMarcador : Theme.nerdFontFamily
                font.pixelSize: Math.round((kanji ? 17 : 15) * Theme.scale)
                visible: (root.item?.imagem ?? "") === "" && (root.item?.icone ?? "") === ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.item?.titulo ?? ""
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.item?.corpo ?? ""
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                visible: text !== ""
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notificacoes.dispensarAtual()
    }
}
