// Barrinhas que pulsam com o que está tocando.
//
// Quem mede o áudio é o cava, num processo à parte: ele lê o monitor do
// PipeWire, faz a FFT e cospe uma linha por quadro. Aqui só desenhamos.
//
// Sem o cava instalado, o componente simplesmente não aparece — não
// quebra nada e não deixa buraco no layout.
//   sudo pacman -S cava
//
// DESEMPENHO — duas decisões que parecem detalhe e não são:
//
//   1. Nada de Canvas. Canvas é rasterizado na CPU e repinta inteiro a
//      cada quadro; foi o que inviabilizou as texturas.
//   2. Row de itens de LARGURA FIXA, não RowLayout. Num RowLayout, cada
//      mudança de altura dispara um passe de layout — dez alturas
//      mudando 30 vezes por segundo são 300 passes/s. O Row só olha a
//      largura, que aqui é constante, então a altura muda de graça.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: raiz

    property int barras: 10
    property bool ativo: false          // só mede quando há som tocando

    readonly property bool disponivel: cava.running || nivel.length > 0
    property var nivel: []

    // Nada de som, nada de barras: o Item some e o layout se fecha.
    visible: ativo && nivel.length > 0
    implicitWidth: visible ? linha.implicitWidth : 0
    implicitHeight: Math.round(14 * Theme.scale)

    // O cava não tem opção de linha de comando para tudo que precisamos,
    // então o arquivo de config vai junto. `raw` + `ascii` dá uma linha
    // de números separados por ponto e vírgula, um por quadro.
    //
    // 30 quadros por segundo, e o `noise_reduction` do próprio cava faz
    // a suavização. Medido: a 44 fps e COM `Behavior on height`, a barra
    // repintava a 100 Hz (a taxa do monitor, não a dos dados) porque
    // cada quadro virava uma animação de 90 ms — 4,2% de CPU por dez
    // retângulos. Suavizar no cava, que já calcula isso, sai de graça.
    FileView {
        id: conf
        path: Quickshell.env("HOME") + "/.cache/praxe-cava.conf"
        preload: false
    }

    Process {
        id: prep
        command: ["bash", "-c",
            "printf '%s\\n' " +
            "'[general]' 'mode = normal' 'framerate = 30' 'autosens = 1' " +
            "'bars = " + raiz.barras + "' " +
            "'[smoothing]' 'noise_reduction = 35' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "> \"$HOME/.cache/praxe-cava.conf\""]
    }

    Process {
        id: cava
        running: false
        command: ["cava", "-p", Quickshell.env("HOME") + "/.cache/praxe-cava.conf"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: linhaLida => {
                const partes = linhaLida.trim().split(";")
                const v = []
                for (const p of partes) {
                    if (p === "") continue
                    const n = parseInt(p)
                    if (!isNaN(n)) v.push(n)
                }
                if (v.length > 0) raiz.nivel = v
            }
        }
    }

    // Só roda enquanto há música. Deixar o cava vivo o tempo todo
    // acordaria o processo 30 vezes por segundo para desenhar zeros.
    onAtivoChanged: gerenciar()
    Component.onCompleted: { prep.running = true; gerenciar() }

    function gerenciar() {
        if (ativo) {
            if (!cava.running) cava.running = true
        } else {
            cava.running = false
            nivel = []
        }
    }

    Row {
        id: linha
        anchors.centerIn: parent
        spacing: Math.max(1, Math.round(2 * Theme.scale))

        Repeater {
            model: raiz.barras

            // A casca tem tamanho fixo; só o retângulo de dentro muda de
            // altura. É isso que impede o Row de recalcular nada.
            delegate: Item {
                id: casca
                required property int index

                readonly property real valor:
                    casca.index < raiz.nivel.length ? raiz.nivel[casca.index] / 100 : 0

                width: Math.max(2, Math.round(2.5 * Theme.scale))
                height: raiz.implicitHeight

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    radius: width / 2
                    // Um mínimo sempre visível: com altura zero as barras
                    // somem e o conjunto pisca em vez de pulsar.
                    height: Math.max(Math.round(2 * Theme.scale),
                                     casca.valor * raiz.implicitHeight)

                    // Acento nos picos, tom apagado no resto. O acento
                    // marca o que se destaca; não pinta tudo.
                    //
                    // A transparência entra na PRÓPRIA cor, e não em
                    // `opacity`: opacity variável cria um nó de composição
                    // separado por barra, refeito a cada quadro. Dentro
                    // da cor é só mais um valor no mesmo retângulo.
                    color: {
                        const base = casca.valor > 0.55 ? PraxeConfig.colAccent
                                                        : PraxeConfig.colMuted
                        return Qt.rgba(base.r, base.g, base.b,
                                       0.45 + casca.valor * 0.55)
                    }
                }
            }
        }
    }
}
