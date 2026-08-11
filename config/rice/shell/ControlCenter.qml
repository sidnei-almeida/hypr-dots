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

    // Na RAIZ, e não junto do bloco de brilho lá embaixo.
    //
    // Em QML, LER uma propriedade sobe a cadeia de escopo, mas ESCREVER de
    // dentro de um objeto aninhado (aqui, o StdioCollector dentro do
    // Process) exige uma referência explícita. Declarada no meio da
    // árvore, a leitura funcionava e a escrita virava "Invalid write to
    // global property" — em tempo de execução, sem quebrar a carga, que é
    // o tipo de erro que passa despercebido.
    property bool brilhoDisponivel: false

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

    // ── Posição da faixa ────────────────────────────────────────
    //
    // Puxada por relógio, e não por binding, porque o MPRIS não avisa que o
    // tempo passou: `positionChanged` existe como SINAL e não como método,
    // então não há como pedir uma atualização. O protocolo só emite quando
    // alguém SALTA na faixa — tocar do começo ao fim não gera evento nenhum.
    //
    // Meio segundo é o intervalo certo aqui: a barra tem alguns milímetros,
    // e num player de três minutos cada amostra move menos de um pixel. Ler
    // mais rápido gastaria acordar a barra à toa; mais devagar faria a linha
    // andar aos saltos visíveis.
    //
    // O relógio só corre com algo TOCANDO. Pausado, a posição não muda, e um
    // temporizador acordando a cada meio segundo para reler o mesmo número é
    // exatamente o tipo de coisa que faz barra de status ter fama de pesada.
    property real posicao: 0
    readonly property real duracao: player?.lengthSupported ? (player?.length ?? 0) : 0

    Timer {
        running: root.temMidia && (root.player?.isPlaying ?? false)
                 && (root.player?.positionSupported ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.posicao = root.player?.position ?? 0
    }

    // Trocou de faixa: zera na hora, sem esperar o próximo tique. Sem isto a
    // barra da música nova começaria mostrando o ponto em que a anterior
    // parou, por até meio segundo.
    Connections {
        target: root.player ?? null
        enabled: root.temMidia
        function onTrackTitleChanged() { root.posicao = 0 }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioPronto: sink !== null && sink.ready === true

    PwObjectTracker { objects: [root.sink] }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(16 * Theme.scale)
        // Ritmo mais apertado, mesma ideia aplicada na cápsula: o painel
        // ganha ar quando as coisas que pertencem uma à outra ficam
        // próximas, não quando tudo fica igualmente distante. 14 uniformes
        // separavam mídia de volume tanto quanto separavam o ícone do seu
        // próprio controle.
        spacing: Math.round(11 * Theme.scale)

        // ── Mídia ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * Theme.scale)
            visible: root.temMidia

            // Capa do álbum, quando o player informa
            Rectangle {
                Layout.preferredWidth: Math.round(46 * Theme.scale)
                Layout.preferredHeight: Layout.preferredWidth
                radius: Theme.raioM
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

                // ── Onde a faixa está ───────────────────────────
                //
                // Dava para ver O QUE toca e não ONDE está. Num player de
                // 46px de capa, uma linha de 3px é a informação inteira:
                // faltam trinta segundos ou faltam vinte minutos.
                //
                // Aparece só quando o player informa duração. Rádio e
                // transmissão ao vivo não informam, e uma barra parada em
                // zero seria pior que barra nenhuma — diria que o player
                // travou.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(5 * Theme.scale)
                    implicitHeight: Math.round(3 * Theme.scale)
                    radius: height / 2
                    visible: root.duracao > 0
                    color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                   PraxeConfig.colFg.b, 0.14)

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.posicao / root.duracao))
                        height: parent.height
                        radius: height / 2
                        color: PraxeConfig.colAccent
                        // Sem Behavior: a posição já chega de meio em meio
                        // segundo pelo relógio, e animar entre amostras
                        // faria a barra correr atrás do próprio passo.
                    }

                    // Clicar salta na faixa, quando o player deixa. Sem
                    // pino: alvo de 3px seria cruel, e a área de clique
                    // aqui é a linha inteira.
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: (root.player?.canSeek ?? false) && root.duracao > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => {
                            const alvo = Math.max(0, Math.min(1, mouse.x / width)) * root.duracao
                            root.player.position = alvo
                            root.posicao = alvo
                        }
                    }
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

        // ── Brilho ───────────────────────────────────────────
    //
    // Lido UMA VEZ, ao abrir o painel, e não continuamente: cada leitura
    // custa ~36 ms de conversa com o monitor, e o valor só muda quando
    // alguém o muda. Um Timer repetindo isso seria pagar por nada.

    Process {
        id: lerBrilho
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim())
                if (isNaN(v)) { root.brilhoDisponivel = false; return }
                root.brilhoDisponivel = true
                // Direto no `valor`, sem guarda de "sincronizando": esta
                // barra não reenvia ao ser escrita de fora, porque o envio
                // sai de `soltou`, que só o dedo dispara.
                brilhoBarra.valor = v / 100
            }
        }
    }
    Process { id: aplicarBrilho }

    // Relê ao ABRIR, porque as teclas XF86MonBrightness mudam o brilho por
    // fora daqui — sem isto o controle mostraria o valor de quando o painel
    // foi aberto pela última vez.
    //
    // Via `Connections`, e não `onAbertoChanged:` direto: este bloco vive
    // dentro do ColumnLayout, e `aberto` é propriedade da RAIZ do
    // componente. Um handler `onXChanged` só existe onde a propriedade
    // existe — fora dali o QML recusa a carga inteira do arquivo.
    Connections {
        target: root
        function onAbertoChanged() {
            if (root.aberto) lerBrilho.exec([PraxeConfig.bin + "rice-brilho"])
        }
    }
    Component.onCompleted: lerBrilho.exec([PraxeConfig.bin + "rice-brilho"])

        // ── Barra deslizante própria ─────────────────────────
        //
        // Substitui o `Slider` do QtQuick Controls, que RENDERIZAVA certo e
        // não arrastava: clicar e puxar não movia nada, embora o botão de
        // mudo ao lado respondesse normalmente. Ou seja, a entrada chegava
        // ao painel; o Slider é que perdia o gesto.
        //
        // A causa é o arrasto ser ROUBADO por um ancestral. Esta superfície
        // tem HoverHandler em três níveis (surface, content, alvo) mais o
        // rastreador que decide quando a barra recolhe. Num arrasto, quem
        // reivindicar o ponteiro primeiro leva, e o Slider desiste sem
        // reclamar. `preventStealing` é o que resolve: uma vez pressionada,
        // esta área não devolve o gesto a ninguém até soltar.
        //
        // E de quebra o controle passa a ser nosso, o que importa aqui: o
        // volume escreve a CADA movimento (PipeWire é instantâneo) e o
        // brilho só ao SOLTAR (DDC/CI custa 87 ms). Dois comportamentos
        // diferentes sob o mesmo desenho.
        component BarraDeslizante: Item {
            id: bd
            property real valor: 0        // 0..1
            // Exposto de propósito: quem sincroniza de fora precisa saber
            // se o dedo está no controle, e alcançar a MouseArea por
            // `children[2]` quebraria no dia em que alguém acrescentasse um
            // retângulo antes dela.
            readonly property bool pressionado: area.pressed
            signal movido(real v)
            signal soltou(real v)

            implicitHeight: Math.round(16 * Theme.scale)

            function valorEm(x) { return Math.max(0, Math.min(1, x / Math.max(1, width))) }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.round(5 * Theme.scale)
                radius: height / 2
                color: Theme.bgAlt
                Rectangle {
                    width: bd.valor * parent.width
                    height: parent.height
                    radius: height / 2
                    color: PraxeConfig.colAccent

                    // Só desliza quando a mudança vem DE FORA — tecla de
                    // mídia, roda do mouse, outro aplicativo. Com o dedo no
                    // controle a animação vira atraso: o preenchimento
                    // persegue o ponteiro e chega sempre depois dele, que é
                    // a sensação de controle emperrado.
                    Behavior on width {
                        enabled: !area.pressed
                        NumberAnimation { duration: Theme.animRapido
                                          easing.type: Theme.curva }
                    }
                }
            }

            Rectangle {
                x: bd.valor * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(13 * Theme.scale)
                height: width
                radius: width / 2
                color: PraxeConfig.colAccent

                // ANEL DA COR DO FUNDO, e é o que faz o pino existir.
                //
                // Pino e preenchimento eram os dois `colAccent`. Como o pino
                // fica sempre na fronteira entre o que está preenchido e o
                // que não está, metade dele cai sobre acento — ou seja, ele
                // desaparecia justamente na metade que importa, e o controle
                // parecia uma barra que enche sozinha sem nada para agarrar.
                //
                // Um anel de 2px da cor do painel separa os dois sem
                // introduzir cor nova nenhuma na paleta.
                border.width: Math.round(2 * Theme.scale)
                border.color: Theme.bg

                // Cresce sob o dedo: confirma que o controle PEGOU o gesto,
                // que é exatamente a informação que faltava quando ele não
                // pegava e nada acontecia. E cresce um pouco ao passar o
                // ponteiro, antes de qualquer clique — é o que anuncia que
                // ali há algo para pegar.
                scale: area.pressed ? 1.25 : (area.containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true     // a linha que conserta o arrasto

                // Clicar em qualquer ponto salta para lá: não é preciso
                // acertar a bolinha de 13px, que seria um alvo cruel.
                onPressed: mouse => { bd.valor = bd.valorEm(mouse.x); bd.movido(bd.valor) }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    bd.valor = bd.valorEm(mouse.x); bd.movido(bd.valor)
                }
                onReleased: bd.soltou(bd.valor)

                // Roda em passos de 5%: é o gesto que se usa sem olhar.
                onWheel: wheel => {
                    bd.valor = Math.max(0, Math.min(1, bd.valor + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                    bd.movido(bd.valor); bd.soltou(bd.valor)
                }
            }
        }

        // ── Volume ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * Theme.scale)

            Text {
                text: root.audioPronto && root.sink.audio.muted ? "󰝟" : "󰕾"
                color: PraxeConfig.colMuted
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(14 * Theme.scale)

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.audioPronto) root.sink.audio.muted = !root.sink.audio.muted
                }
            }

            BarraDeslizante {
                id: volBarra
                Layout.fillWidth: true

                // Volume escreve a cada movimento: o PipeWire é memória, e
                // esperar soltar deixaria o som atrasado em relação ao dedo.
                onMovido: v => { if (root.audioPronto) root.sink.audio.volume = v }

                // Sincroniza de fora para dentro, mas NUNCA durante o
                // arrasto: o valor que volta do PipeWire chega defasado e
                // empurraria o controle para trás debaixo do dedo.
                Connections {
                    target: root.audioPronto ? root.sink.audio : null
                    function onVolumeChanged() {
                        if (!volBarra.pressionado) volBarra.valor = root.sink.audio.volume
                    }
                }
                Component.onCompleted: if (root.audioPronto) valor = root.sink.audio.volume
            }

            Text {
                text: root.audioPronto ? Math.round(volBarra.valor * 100) + "%" : "—"
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: Math.round(38 * Theme.scale)
            }
        }

        // ── Brilho do monitor ────────────────────────────────
        //
        // Só aparece se houver monitor DDC/CI. Num notebook com
        // retroiluminação normal, ou num monitor com DDC desligado no menu
        // físico, a linha inteira some em vez de virar um controle que não
        // move nada.
        //
        // ── POR QUE ESTE SLIDER É DIFERENTE DO DE VOLUME ───────
        //
        // Volume é PipeWire, em memória: escrever custa microssegundos e o
        // slider pode mandar o valor a cada quadro do arrasto.
        //
        // Brilho é DDC/CI, conversa com o MONITOR pelo cabo de vídeo.
        // Medido aqui, com o barramento em cache: 87 ms por escrita. Mandar
        // a cada quadro empilharia dezenas de comandos numa fila serial, e
        // o brilho chegaria segundos depois do dedo — arrastar pareceria
        // travado mesmo com tudo funcionando.
        //
        // Então: o CONTROLE anda na hora (é só estado local) e o valor é
        // mandado quando o movimento PARA. O temporizador abaixo é o que
        // separa as duas coisas.
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * Theme.scale)
            visible: root.brilhoDisponivel

            Text {
                // Glifo cheio ou vazio conforme o nível: a própria forma do
                // ícone já diz onde está, antes de o olho chegar no número.
                text: brilhoBarra.valor > 0.55 ? "󰃠" : "󰃞"
                color: PraxeConfig.colMuted
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(15 * Theme.scale)
            }

            BarraDeslizante {
                id: brilhoBarra
                Layout.fillWidth: true

                // Brilho só ao SOLTAR. Cada escrita custa 87 ms de conversa
                // com o monitor; mandar a cada movimento empilharia dezenas
                // de comandos numa fila serial e o brilho chegaria segundos
                // depois do dedo. O controle anda na hora porque é estado
                // local — só o envio espera.
                onSoltou: v => aplicarBrilho.exec([PraxeConfig.bin + "rice-brilho",
                                                   String(Math.max(5, Math.round(v * 100)))])
            }

            Text {
                text: Math.round(brilhoBarra.valor * 100) + "%"
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
                Layout.preferredHeight: Math.round(28 * Theme.scale)
                radius: height / 2

                // PREENCHIMENTO em vez de CONTORNO, e é a mesma decisão que
                // tirou os separadores da cápsula: linha desenhada é a
                // solução mais barata e a mais barulhenta.
                //
                // Eram cinco contornos de 1px em DIM, permanentes, lado a
                // lado — cinco retângulos vazios competindo com os glifos
                // que eles deveriam emoldurar. Um preenchimento fraco dá o
                // mesmo recorte de área clicável sem desenhar nada.
                //
                // O hover sobe o preenchimento em vez de acender a borda:
                // muda a MESMA propriedade, então o botão responde como uma
                // superfície e não como um contorno que pisca.
                color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                               PraxeConfig.colFg.b, area.containsMouse ? 0.12 : 0.05)
                Behavior on color { ColorAnimation { duration: Theme.animCor } }

                Text {
                    anchors.centerIn: parent
                    text: acao.glifo
                    color: area.containsMouse ? PraxeConfig.colAccent : PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Math.round(14 * Theme.scale)
                    Behavior on color { ColorAnimation { duration: Theme.animCor } }
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
                radius: Theme.raioM

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
