// CPU e memória. Os números vêm do rice-sysstat (duas amostras do /proc/stat).
// Clique abre o btop num terminal flutuante.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property int cpu: 0
    property int mem: 0

    Process {
        id: stat
        command: [PraxeConfig.bin + "rice-sysstat"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(/\s+/)
                if (p.length >= 2) {
                    root.cpu = parseInt(p[0]) || 0
                    root.mem = parseInt(p[1]) || 0
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: stat.running = true
    }

    // Sem `Process`: ele ficaria em `running` durante TODA a vida do btop, e
    // um Process em running engole os cliques seguintes sem avisar. Se o
    // kitty encerrasse mal, o clique aqui morria de vez. Ver a nota longa no
    // ControlCenter.qml.

    // Par ícone + valor. Fica âmbar quando passa do limite.
    component Metric: RowLayout {
        id: metric
        spacing: Theme.itemGap

        property string glyph: ""
        property int value: 0
        property int alertAt: 85

        readonly property bool alerta: value >= alertAt

        Text {
            text: metric.glyph
            color: metric.alerta ? Theme.warn : PraxeConfig.colMuted
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.iconSize
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            text: metric.value + "%"
            color: metric.alerta ? Theme.warn : PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.groupGap

        Metric { glyph: "󰘚"; value: root.cpu }
        Metric { glyph: "󰍛"; value: root.mem }
    }

    // O cursor vem do HoverHandler, e NÃO do MouseArea.
    //
    // `cursorShape` num MouseArea o faz aceitar eventos de hover — o Qt
    // precisa saber que o ponteiro entrou para poder trocar o cursor. E
    // um MouseArea que aceita hover ENGOLE o evento: o rastreador da
    // barra (shell.qml) para de ver o ponteiro, a carência de 450ms
    // corre até o fim, a barra colapsa, este módulo some junto, o hover
    // volta ao rastreador e a barra reabre — 510ms por ciclo, sem parar.
    //
    // O HoverHandler dá o mesmo cursor sendo cooperativo: vários podem
    // estar ativos ao mesmo tempo, cada um vendo o ponteiro. O MouseArea
    // fica só com o clique, que não depende de hover.
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["kitty", "--class", "rice-float", "-e", "btop"])
    }
}
