// O que está tocando. Some por completo quando não há player —
// a pill encolhe sozinha, sem deixar buraco.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Qual player a barra mostra.
    //
    // A regra do meio é o conserto, e vale entender o que ela substitui.
    //
    // Antes era: "quem estiver tocando; se ninguém, o PRIMEIRO da lista".
    // O primeiro da lista costuma ser o `playerctld` — um proxy que
    // espelha os outros e não tem metadados próprios — ou uma instância
    // de navegador que ficou pendurada no barramento sem faixa nenhuma.
    //
    // Enquanto algo tocava, o laço de cima achava o player certo e tudo
    // funcionava. Ao PAUSAR, nenhum estava tocando, a escolha caía nesse
    // primeiro sem título, o `titulo` ficava vazio, o `active` virava
    // falso — e o bloco de mídia SUMIA da pill. Não havia botão de play
    // para clicar: o sistema parecia ter esquecido o vídeo.
    //
    // Pausado é um estado, não uma ausência. Quem tem faixa carregada
    // ainda é o que você estava assistindo.
    readonly property var player: {
        const ps = Mpris.players.values
        // 1. tocando agora
        for (const p of ps) if (p.isPlaying) return p
        // 2. pausado, mas com faixa carregada — é o vídeo que você pausou
        for (const p of ps) if ((p.trackTitle ?? "") !== "") return p
        // 3. nada com faixa: sem mídia de verdade. Devolver o primeiro
        //    aqui seria devolver o proxy, e o bloco apareceria vazio.
        return null
    }

    readonly property string titulo: {
        if (!player) return ""
        const t = player.trackTitle ?? ""
        const a = player.trackArtist ?? ""
        if (t === "") return ""
        return a !== "" ? a + " — " + t : t
    }

    readonly property bool active: titulo !== ""

    visible: active
    implicitWidth: active ? Math.min(row.implicitWidth, Math.round(300 * Theme.scale)) : 0
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.itemGap

        Text {
            text: (root.player && root.player.isPlaying) ? "󰏤" : "󰐊"
            color: Theme.accent2
            font.family: Theme.nerdFontFamily
            font.pixelSize: Theme.iconSize
        }

        // ── O título, correndo quando não cabe ──────────────────
        //
        // Era `elide: ElideRight`: "Pink Floyd — Shine On You Crazy Dia…".
        // Reticências dizem que há mais e não deixam ler — e num bloco
        // limitado a 300px isso acontece com quase toda faixa que tem
        // artista no nome.
        //
        // Três decisões que separam isto de um letreiro de loja:
        //
        // 1. SÓ CORRE SE PRECISA. Título que cabe fica parado. Texto que se
        //    move sem necessidade é ruído permanente no canto do olho.
        //
        // 2. VAI E VOLTA, não dá a volta. O laço clássico corta o texto no
        //    fim e emenda no começo, e o corte é sempre feio. Indo e
        //    voltando não há emenda nenhuma.
        //
        // 3. PARA NAS PONTAS. Sem as pausas, o começo do título passa
        //    varrido: quando o olho chega, já saiu. Dois segundos parado em
        //    cada ponta é o que dá para ler antes de o movimento recomeçar.
        //
        // A velocidade é em PIXELS POR SEGUNDO, não duração fixa: com
        // duração fixa um título curto anda devagar e um longo dispara, e a
        // leitura fica impossível justamente no caso que mais precisa dela.
        Item {
            id: trilho
            Layout.fillWidth: true
            Layout.preferredHeight: rotulo.implicitHeight
            clip: true

            // ESTAS DUAS LINHAS SÃO O QUE FAZ O TÍTULO EXISTIR.
            //
            // Um `Item` não tem tamanho implícito próprio — ele é 0x0 até
            // alguém dizer o contrário. Sem o `implicitWidth` abaixo, o
            // RowLayout deixava de saber que havia texto aqui dentro; o
            // `row.implicitWidth` passava a somar só o ícone e as barrinhas,
            // o `Math.min(...)` lá em cima devolvia essa largura miúda e o
            // título simplesmente NÃO APARECIA. (Antes, quem carregava essa
            // informação era o próprio Text, que tem implicitWidth.)
            //
            // E o `minimumWidth: 0` é o outro lado: com a largura implícita
            // declarada, o layout tentaria respeitá-la e o trilho nunca
            // ficaria menor que o texto — ou seja, nunca haveria excesso e o
            // carrossel jamais correria. Zerar o mínimo é o que autoriza o
            // encolhimento que cria o excesso.
            implicitWidth: rotulo.implicitWidth
            Layout.minimumWidth: 0

            readonly property real excesso: Math.max(0, rotulo.implicitWidth - width)
            readonly property bool correndo: excesso > 1

            Text {
                id: rotulo
                text: root.titulo
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                y: 0

                // Parado quando cabe: `x` fica em 0 e a animação nem roda.
                x: 0
            }

            SequentialAnimation {
                id: passeio
                running: trilho.correndo && root.visible
                loops: Animation.Infinite

                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: rotulo; property: "x"
                    from: 0; to: -trilho.excesso
                    duration: Math.max(1, trilho.excesso / 30 * 1000)  // 30 px/s
                    easing.type: Easing.InOutSine
                }
                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    target: rotulo; property: "x"
                    from: -trilho.excesso; to: 0
                    duration: Math.max(1, trilho.excesso / 30 * 1000)
                    easing.type: Easing.InOutSine
                }
            }

            // Trocar de faixa reposiciona o texto no começo. Sem isto, a
            // faixa nova entra na posição em que a anterior tinha parado —
            // e o título aparece cortado ao meio sem nenhum motivo.
            Connections {
                target: root
                function onTituloChanged() {
                    passeio.stop()
                    rotulo.x = 0
                    if (trilho.correndo) passeio.start()
                }
            }
        }

        // As barrinhas de áudio. Só medem enquanto algo toca de fato —
        // com a mídia pausada elas ficariam paradas em zero, o que é
        // pior que não existirem.
        Visualizador {
            Layout.alignment: Qt.AlignVCenter
            ativo: root.player !== null && root.player.isPlaying
        }
    }

    // Cursor no HoverHandler, não no MouseArea — ver a nota no
    // Resources.qml.
    HoverHandler { cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.player) return
            if (mouse.button === Qt.RightButton) root.player.next()
            else root.player.togglePlaying()
        }
        onWheel: wheel => {
            if (!root.player) return
            if (wheel.angleDelta.y > 0) root.player.next()
            else root.player.previous()
        }
    }
}
