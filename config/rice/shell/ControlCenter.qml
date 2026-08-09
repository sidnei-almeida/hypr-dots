// Painel que a island revela quando expande.
//
// Mídia em cima, volume no meio, atalhos embaixo. Ele NÃO anima o
// próprio tamanho: quem cresce é a island, e o clip dela revela este
// conteúdo. Aqui só cuidamos do fade, com um atraso curto na abertura
// para a cápsula começar a se mover antes do conteúdo aparecer.

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property bool aberto: false

    // Pedido de troca de painel, atendido pelo shell.qml.
    //
    // Sinal e não acesso direto a `bar.painel`: este componente é filho da
    // island, mas não deve conhecer o nome nem a estrutura de quem o
    // hospeda — quem manda no painel é quem tem o painel. É também o que
    // dispensa o rodeio do `qs ipc call` para falar com o próprio processo
    // (ver a nota no atalho de aparência, mais abaixo).
    signal pedirPainel(string nome)

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 130 : 0 }
            NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
        }
    }

    // Mesma regra do MediaInfo.qml, e pelo mesmo motivo — a nota longa
    // está lá. Em resumo: pausado é estado, não ausência; o player com
    // faixa carregada continua sendo o que você estava assistindo, e cair
    // no primeiro da lista pegava o proxy `playerctld`, sem metadados.
    readonly property var player: {
        const ps = Mpris.players.values
        for (const p of ps) if (p.isPlaying) return p
        for (const p of ps) if ((p.trackTitle ?? "") !== "") return p
        return null
    }
    readonly property bool temMidia: player !== null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioPronto: sink !== null && sink.ready === true

    PwObjectTracker { objects: [root.sink] }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(16 * Theme.scale)
        spacing: Math.round(14 * Theme.scale)

        // ── Mídia ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * Theme.scale)
            visible: root.temMidia

            // Capa do álbum, quando o player informa
            Rectangle {
                Layout.preferredWidth: Math.round(46 * Theme.scale)
                Layout.preferredHeight: Layout.preferredWidth
                radius: Math.round(8 * Theme.scale)
                color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                               PraxeConfig.colFg.b, 0.05)
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Math.round(20 * Theme.scale)
                    visible: (root.player?.trackArtUrl ?? "") === ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.player?.trackTitle ?? ""
                    color: PraxeConfig.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.player?.trackArtist ?? ""
                    color: PraxeConfig.colMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            // Transporte
            RowLayout {
                spacing: Math.round(10 * Theme.scale)

                component Botao: Text {
                    id: botao
                    property string glifo: ""
                    signal acionado

                    text: botao.glifo
                    color: mouse.containsMouse ? PraxeConfig.colAccent : PraxeConfig.colFg
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Math.round(16 * Theme.scale)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: botao.acionado()
                    }
                }

                Botao { glifo: "󰒮"; onAcionado: root.player?.previous() }
                Botao {
                    glifo: (root.player && root.player.isPlaying) ? "󰏤" : "󰐊"
                    onAcionado: root.player?.togglePlaying()
                }
                Botao { glifo: "󰒭"; onAcionado: root.player?.next() }
            }
        }

        // ── Volume ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * Theme.scale)

            Text {
                text: root.audioPronto && root.sink.audio.muted ? "󰝟" : "󰕾"
                color: PraxeConfig.colMuted
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(15 * Theme.scale)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.audioPronto) root.sink.audio.muted = !root.sink.audio.muted
                }
            }

            Slider {
                id: volSlider
                Layout.fillWidth: true
                from: 0; to: 1

                // Nada de binding em `value`, e nada de escrever no
                // `moved`: recálculo de layout (ao esconder o painel)
                // dispara `moved` mesmo sem o usuário tocar em nada, e o
                // valor velho voltava para o Pipewire — o volume mudado
                // pela tecla de mídia "voltava sozinho" segundos depois.
                //
                // Em vez disso: sincronizamos de fora para dentro sempre
                // que o volume muda, e só escrevemos de dentro para fora
                // enquanto o slider está de fato pressionado.
                property bool sincronizando: false

                function sincronizar() {
                    if (pressed) return
                    sincronizando = true
                    value = root.audioPronto ? root.sink.audio.volume : 0
                    sincronizando = false
                }

                onValueChanged: {
                    if (sincronizando || !pressed || !root.audioPronto) return
                    root.sink.audio.volume = value
                }

                Component.onCompleted: sincronizar()
                onVisibleChanged: if (visible) sincronizar()

                Connections {
                    target: root.audioPronto ? root.sink.audio : null
                    function onVolumeChanged() { volSlider.sincronizar() }
                }

                background: Rectangle {
                    x: volSlider.leftPadding
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    width: volSlider.availableWidth
                    height: Math.round(5 * Theme.scale)
                    radius: height / 2
                    color: Theme.bgAlt

                    Rectangle {
                        width: volSlider.visualPosition * parent.width
                        height: parent.height
                        radius: height / 2
                        color: PraxeConfig.colAccent
                    }
                }

                handle: Rectangle {
                    x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    width: Math.round(13 * Theme.scale)
                    height: width
                    radius: width / 2
                    color: PraxeConfig.colAccent
                }
            }

            Text {
                text: root.audioPronto ? Math.round(root.sink.audio.volume * 100) + "%" : "—"
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: Math.round(38 * Theme.scale)
            }
        }

        // ── Atalhos ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * Theme.scale)

            component Acao: Rectangle {
                id: acao
                property string glifo: ""
                property string dica: ""
                property var comando: []

                // Ação interna, para o que NÃO precisa de processo nenhum.
                // Quando presente, manda nela e o `comando` é ignorado.
                property var aoClicar: null

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(30 * Theme.scale)
                radius: height / 2
                color: area.containsMouse ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g, PraxeConfig.colFg.b, 0.08) : "transparent"
                border.width: 1
                border.color: PraxeConfig.colDim
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: acao.glifo
                    color: area.containsMouse ? PraxeConfig.colAccent : PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Math.round(15 * Theme.scale)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // `execDetached` e NÃO um `Process` com `running = true`.
                //
                // ISTO É O QUE CONSERTA "O BOTÃO PAROU DE FUNCIONAR".
                //
                // Um `Process` é uma máquina de estado com UMA execução por
                // vez. Setar `running = true` num Process que JÁ está rodando
                // não faz nada — sem erro, sem aviso, o clique some. Basta o
                // comando pendurar uma vez para o botão morrer em definitivo,
                // e só ele: os outros atalhos têm cada um o seu Process, então
                // continuam funcionando e o defeito parece aleatório.
                //
                // Foi exatamente o que aconteceu com o botão de tema, que
                // chamava um `qs ipc call` (ver abaixo). A chamada travou, o
                // Process ficou preso em running, e a partir dali o botão
                // ficou morto para sempre.
                //
                // `execDetached` não guarda estado: cada clique é um disparo
                // independente. Um comando que trave prende só a si mesmo.
                // Nada aqui lê saída nem espera código de retorno — é tudo
                // disparar e esquecer, que é o caso de uso do execDetached.
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (acao.aoClicar) { acao.aoClicar(); return }
                        if (acao.comando.length > 0) Quickshell.execDetached(acao.comando)
                    }
                }
            }

            Acao { glifo: "󰍜"; comando: [PraxeConfig.bin + "rice-menu"] }
            Acao { glifo: "󰕾"; comando: [PraxeConfig.bin + "rice-audio"] }
            Acao { glifo: "󰛳"; comando: [PraxeConfig.bin + "rice-network"] }

            // Abre o painel de aparência DIRETO, sem processo externo.
            //
            // Antes isto lançava `qs -p ... ipc call island estilo`: o shell
            // subia um segundo processo Quickshell inteiro, só para pedir por
            // socket que ELE MESMO trocasse uma propriedade sua. Três defeitos
            // de uma vez:
            //
            //  1. cada chamada registra uma instância em
            //     /run/user/1000/quickshell/by-shell/<id>/ e não a remove ao
            //     sair, então o diretório acumula entradas mortas e a escolha
            //     de "com qual instância falar" vai ficando ambígua;
            //  2. se essa escolha cai numa instância que já morreu, o cliente
            //     fica pendurado esperando resposta que não vem;
            //  3. pendurado, ele trava o Process do botão — ver a nota acima.
            //
            // O sinal resolve na origem: o painel é deste mesmo processo, o
            // shell.qml está a um passo de distância, e não há socket, nem
            // processo, nem instância no meio. Sobra o que sempre foi: trocar
            // uma string.
            Acao { glifo: "󰸌"; aoClicar: () => root.pedirPainel("aparencia") }

            Acao { glifo: "󰌾"; comando: ["loginctl", "lock-session"] }
        }

        // ── Notificações ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: Notificacoes.quantidade > 0 || Notificacoes.silencioso

            Text {
                Layout.fillWidth: true
                text: Notificacoes.silencioso
                      ? Idioma.t("notif.silenced")
                      : Idioma.tf("notif.count", Notificacoes.quantidade)
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }

            // Alterna o não perturbe
            Text {
                text: Notificacoes.silencioso ? "󰂛" : "󰂚"
                color: sinoArea.containsMouse ? PraxeConfig.colAccent : PraxeConfig.colMuted
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(14 * Theme.scale)
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: sinoArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notificacoes.alternarSilencio()
                }
            }

            Text {
                text: "  " + Idioma.t("notif.clear")
                color: limparArea.containsMouse ? Theme.err : PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                visible: Notificacoes.quantidade > 0
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: limparArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notificacoes.limpar()
                }
            }
        }

        ListView {
            id: listaNotif
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notificacoes.quantidade > 0
            clip: true
            spacing: Math.round(6 * Theme.scale)
            model: Notificacoes.lista

            delegate: Rectangle {
                required property var modelData

                width: listaNotif.width
                height: Math.round(44 * Theme.scale)
                radius: Math.round(10 * Theme.scale)

                // Véu translúcido sobre o próprio fundo, não um cinza
                // opaco. Em tema escuro, superfície opaca mais clara vira
                // um bloco cinza que briga com o resto; o véu eleva de
                // leve e a borda de 1px é quem define a aresta.
                color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                               PraxeConfig.colFg.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                      PraxeConfig.colFg.b, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * Theme.scale)
                    anchors.rightMargin: Math.round(10 * Theme.scale)
                    spacing: Math.round(9 * Theme.scale)

                    Text {
                        readonly property bool kanji: PraxeConfig.simbolos === "kanji"
                        text: kanji ? Notificacoes.marcador(modelData.urgencia) : "󰄰"
                        color: modelData.urgencia === NotificationUrgency.Critical
                             ? PraxeConfig.colAccent
                             : Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                       PraxeConfig.colFg.b, 0.55)
                        font.family: kanji ? Notificacoes.fonteMarcador : Theme.nerdFontFamily
                        font.pixelSize: Math.round((kanji ? 14 : 9) * Theme.scale)
                        Layout.preferredWidth: Math.round(16 * Theme.scale)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.titulo
                            color: PraxeConfig.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: modelData.corpo
                            color: PraxeConfig.colMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                            visible: text !== ""
                        }
                    }

                    Text {
                        text: Qt.formatDateTime(modelData.quando, "HH:mm")
                        // MUTED, não DIM: o card usa bgAlt, e DIM fica a
                        // menos de 1.5 de contraste dele em todos os temas
                        // — o horário simplesmente não aparecia.
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
}
