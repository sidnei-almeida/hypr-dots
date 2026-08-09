// Volume da saída padrão. Clique alterna o mudo, roda ajusta,
// clique direito abre nosso menu de áudio.
//
// A raiz é um Item (não um RowLayout): assim o MouseArea pode cobrir
// tudo com anchors sem virar um item do layout e zerar a largura.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.ready === true
    readonly property bool muted: ready && sink.audio.muted === true
    readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

    PwObjectTracker { objects: [root.sink] }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.itemGap

        Text {
            text: {
                if (!root.ready || root.muted) return "󰝟"
                if (root.vol === 0)  return "󰕿"
                if (root.vol < 50)   return "󰖀"
                return "󰕾"
            }
            color: root.muted ? Theme.err : PraxeConfig.colFg
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.iconSize
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: root.ready ? (root.muted ? "mudo" : root.vol + "%") : "—"
            color: root.muted ? PraxeConfig.colMuted : PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    // Sem `Process`: o rice-audio fica aberto enquanto o fuzzel estiver na
    // tela, e um Process preso em `running` engole os cliques seguintes sem
    // avisar. Ver a nota longa no ControlCenter.qml.

    // Cursor no HoverHandler, não no MouseArea — ver a nota no
    // Resources.qml. Um MouseArea com `cursorShape` aceita hover, e
    // hover aceito aqui é hover roubado do rastreador da barra.
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (!root.ready) return
            if (mouse.button === Qt.RightButton)
                Quickshell.execDetached([PraxeConfig.bin + "rice-audio"])
            else root.sink.audio.muted = !root.sink.audio.muted
        }

        onWheel: wheel => {
            if (!root.ready) return
            const passo = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + passo))
        }
    }
}
