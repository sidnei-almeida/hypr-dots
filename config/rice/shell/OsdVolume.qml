// A cápsula pequena que aparece ao mexer no volume.
//
// Não é uma janela nova: é a própria island encolhida, com este
// conteúdo por cima. Por isso volume, barra e centro de controle
// parecem a mesma coisa mudando de forma.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool aberto: false

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 110 : 0 }
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool pronto: sink !== null && sink.ready === true
    readonly property bool mudo: pronto && sink.audio.muted === true
    readonly property int vol: pronto ? Math.round(sink.audio.volume * 100) : 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(18 * Theme.scale)
        anchors.rightMargin: Math.round(18 * Theme.scale)
        spacing: Math.round(12 * Theme.scale)

        Text {
            text: {
                if (root.mudo)     return "󰝟"
                if (root.vol === 0) return "󰕿"
                if (root.vol < 50)  return "󰖀"
                return "󰕾"
            }
            color: root.mudo ? Theme.err : PraxeConfig.colAccent
            font.family: Theme.nerdFontFamily
            font.pixelSize: Math.round(15 * Theme.scale)
        }

        // Trilho
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(5 * Theme.scale)
            radius: height / 2
            color: Theme.bgAlt

            Rectangle {
                width: parent.width * (root.mudo ? 0 : root.vol / 100)
                height: parent.height
                radius: height / 2
                color: PraxeConfig.colAccent
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            text: root.mudo ? "mudo" : root.vol + "%"
            color: PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: Math.round(42 * Theme.scale)
        }
    }
}
