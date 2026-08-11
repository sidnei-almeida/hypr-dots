// ┌──────────────────────────────────────────────────────────────┐
// │  PraXe OS — a island.                                         │
// └──────────────────────────────────────────────────────────────┘
//
// Uma superfície só, que muda de forma. Não são janelas diferentes:
// largura, altura e raio são derivados do estado, e o clip revela o
// conteúdo conforme ela cresce.
//
// Formatos, em ~/.config/rice/pill.json:
//   "pill"  cápsula solta e centralizada
//   "notch" cápsula colada no topo, cantos de cima retos
//   "bar"   barra de ponta a ponta
//
// Estados:
//   idle       só a barra
//   control    centro de controle: mídia, volume, atalhos
//   osd        cápsula pequena de volume, ao mexer no som
//
// Três detalhes fazem a animação parecer viva, e valem a leitura:
//   1. Largura e altura correm juntas em `animForma`, com o conteúdo
//      entrando depois — é o atraso do item 2 que faz desdobrar.
//   2. O conteúdo tem 90ms de atraso ao abrir e nenhum ao fechar: a
//      cápsula começa a se mexer antes de aparecer, e o conteúdo some
//      antes dela encolher.
//   3. Passar o mouse já alarga um pouco, antes de qualquer clique.
//
// Sobe com:  qs -p ~/.config/rice/shell

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ShellRoot {
    id: raiz

    // Controle por fora, para atalhos de teclado e scripts:
    //   qs -p ~/.config/rice/shell ipc call island toggle
    // Atenção aos nomes: `show` e `hide` colidem com os subcomandos do
    // próprio `qs ipc`, que passa a listar em vez de chamar a função.
    // Por isso abrir/fechar em português — não há colisão possível.
    IpcHandler {
        target: "island"
        // `ancoraX = -1` em todos: quem chega por atalho de teclado não tem
        // gatilho na tela para ancorar, e o menu abre no centro. Sem isto ele
        // herdaria a âncora do último clique — abrir pelo teclado colocaria o
        // menu embaixo da engrenagem sem nenhum motivo visível.
        function toggle(): void { bar.ancoraX = -1; bar.painel = bar.painel === "control" ? "" : "control" }
        function abrir(): void  { bar.ancoraX = -1; bar.painel = "control" }
        function fechar(): void { bar.painel = "" }
        function apps(): void   { bar.ancoraX = -1; bar.painel = bar.painel === "launcher" ? "" : "launcher" }
        function papel(): void  { bar.ancoraX = -1; bar.painel = bar.painel === "wallpaper" ? "" : "wallpaper" }
        function estilo(): void { bar.ancoraX = -1; bar.painel = bar.painel === "aparencia" ? "" : "aparencia" }

        // Leitura de estado, para diagnóstico de fora.
        //
        // Existe porque todo painel aqui abre por TOGGLE: quando um atalho
        // "não funciona", as duas explicações (a chamada não chegou / a
        // chamada chegou e alternou para fechado) são indistinguíveis pela
        // tela — ainda mais com papel de parede ou jogo animado por baixo.
        // Sem isto o diagnóstico vira palpite.
        function estado(): string { return bar.painel === "" ? "fechado" : bar.painel }

        function geo(): string {
            return "painel=" + (bar.painel === "" ? "fechado" : bar.painel)
                 + " expandido=" + bar.expandido
                 + " colapsada=" + bar.colapsada
                 + " vertical=" + bar.vertical
                 + " isPill=" + bar.isPill
                 + " scale=" + Theme.scale
                 + " surface=" + Math.round(surface.width) + "x" + Math.round(surface.height)
                 + " alvo=" + surface.larguraPainel + "x" + surface.alturaPainel
                 + " janela=" + bar.width + "x" + bar.height
                 // A largura da cápsula ABERTA, que é a que interessa e não
                 // dá para ler em `surface` quando ela está colapsada — ali
                 // o que se mede é o filete do relógio.
                 + " capsula=" + surface.larguraBarra
                 // As áreas de trabalho agora são dinâmicas: sem isto, "o
                 // ponto da área 8 apareceu?" só se responde olhando a tela.
                 + " areas=[" + areas.lista.join(",") + "]"
                 // O flash do número no filete dura ~1s: olhar a tela para
                 // conferir é justamente o que não dá tempo de fazer. Aqui
                 // ele fica legível — `area` é o que o filete mostra e
                 // `flash` diz se está no ar neste instante.
                 + " area=" + bar.areaMostrada
                 + " flash=" + bar.mostrandoArea
        }
    }

    IpcHandler {
        target: "notif"
        function toggleSilence(): void { Notificacoes.alternarSilencio() }
        function dismiss(): void       { Notificacoes.dispensarAtual() }
        function clear(): void         { Notificacoes.limpar() }
        function count(): string       { return String(Notificacoes.quantidade) }
    }

    // O dock. Superfície própria: some e volta sozinho, e não pode

    // compartilhar a máscara de cliques da island.

    Dock { }


    PanelWindow {
        id: bar

        readonly property bool isPill: PraxeConfig.isPill

        // Notch só faz sentido encostado no topo e na horizontal. No modo
        // vertical ou embaixo ele viraria uma cápsula com dois cantos
        // retos no lugar errado, então cai de volta na cápsula normal.
        readonly property bool notchColado:
            PraxeConfig.isNotch && PraxeConfig.atTop && !bar.vertical

        // Ritmo das animações da cápsula, num lugar só.
        //
        // Estava em 420ms para largura e 520ms para altura, herdado de
        // quando a barra era o elemento principal da tela. Para algo que
        // abre e fecha o tempo todo com o mouse, isso é lento: o cursor
        // chega no destino antes da forma.
        // Do Theme, para não divergir do que as peças de dentro usam —
        // ver a nota longa lá.
        readonly property int animForma: Theme.animForma
        readonly property int animCor: Theme.animCor
        readonly property bool atTop: PraxeConfig.atTop
        readonly property bool vertical: PraxeConfig.vertical

        // Estado da island: vazio, "control" ou "osd"
        property string painel: ""
        property string osd: ""

        // Abrir o centro de controle É o ato de olhar a lista — as
        // notificações moram lá dentro. Daqui em diante o ponto de aviso
        // do filete apaga.
        //
        // Um `onChanged` num lugar só, e não uma chamada em cada botão:
        // há pelo menos quatro caminhos que abrem esse painel (atalho,
        // toque no ponto do menu, IPC, e o retorno de outros painéis).
        // Marcar em cada um deles é garantir que o quinto, quando
        // aparecer, esqueça de marcar — e o ponto ficaria aceso sem
        // motivo, que é justamente o defeito que este contador existe
        // para evitar.
        onPainelChanged: if (painel === "control") Notificacoes.marcarVistas()

        readonly property bool expandido: painel !== ""
        readonly property bool emLauncher: painel === "launcher"
        readonly property bool emWallpaper: painel === "wallpaper"
        readonly property bool emAparencia: painel === "aparencia"

        // ── Painel solto ────────────────────────────────────
        //
        // A `surface` sempre foi UMA superfície para tudo: cápsula, barra,
        // filete, OSD, balão e os quatro painéis. Abrir painel só mudava as
        // medidas dela. Para a cápsula é o efeito certo — a gota que desce
        // do recorte. Para a BARRA era errado: ela encolhia ao meio e virava
        // painel, ou seja, deixava de ser barra para abrir um menu.
        //
        // `modoSolto` marca onde o painel tem de ser uma SEGUNDA superfície,
        // ancorada abaixo da barra. O vertical fica de fora: é uma lateral e
        // se comporta como cápsula deitada.
        readonly property bool modoSolto: !isPill && !vertical

        // x (nas coordenadas da janela) do CENTRO do gatilho que abriu o
        // painel, para ele descer embaixo de quem foi clicado — é isso que
        // separa um menu de um painel de sistema. -1 quando veio de atalho de
        // teclado: não há gatilho, e aí o menu cai no centro.
        property real ancoraX: -1
        readonly property bool emOsd: osd !== "" && painel === ""
        // O balão só aparece quando nada mais está ocupando a island
        readonly property bool emBalao: Notificacoes.mostrando && painel === "" && osd === ""

        // No modo "hover" a barra vira um filete e só cresce com o mouse
        // em cima. Nada disso vale se ela estiver ocupada com algo.
        // Carência ao sair: sem ela, qualquer buraco entre dois módulos
        // faz a barra piscar entre aberta e fechada.
        property bool mouseDentro: false

        // Quem responde "o cursor está na barra?" é a UNIÃO das sondas, e
        // não uma só.
        //
        // O `rastreador` sozinho não serve: ele vive no `alvoMouse`, que
        // com a barra aberta tem exatamente a geometria da `surface` e fica
        // inteiramente por baixo dela — a `surface` é declarada depois e
        // portanto está por cima, e leva o hover. Resultado: o rastreador
        // só via o cursor no instante em que a folga do colapsado ainda
        // sobrava para fora da superfície, `mouseDentro` nunca se sustentava,
        // o `carencia` corria os 450ms sem ninguém para pará-lo e a barra
        // piscava num ciclo fechado de 750ms.
        //
        // As sondas de `surface` e `content` cobrem o estado aberto; o
        // `rastreador` cobre a faixa de folga do colapsado, que é a única
        // parte do alvo que não fica encoberta. Juntas não deixam buraco.
        // HoverHandler é cooperativo, então todas veem o cursor ao mesmo
        // tempo sem uma roubar da outra.
        readonly property bool sobPonteiro: rastreador.hovered
                                         || sondaSurface.hovered
                                         || sondaContent.hovered
                                         || relogioHover.hovered
                                         || menuHover.hovered

        onSobPonteiroChanged: {
            if (sobPonteiro) { carencia.stop(); mouseDentro = true }
            else carencia.restart()
        }

        Timer {
            id: carencia
            interval: 450
            onTriggered: bar.mouseDentro = false
        }

        readonly property bool ocupada: expandido || emOsd || emBalao

        // "hover": some quase por completo, vira um filete
        // O `isPill` é a novidade, e é uma regra de identidade, não de
        // gosto: uma CÁPSULA pode encolher num filete e voltar — ela flutua,
        // não promete lugar nenhum. Uma BARRA promete: ela é a régua fixa do
        // topo da tela, e régua que muda de tamanho sozinha deixa de servir
        // de referência. O mesmo vale para o modo compacto logo abaixo.
        readonly property bool colapsada: PraxeConfig.autoHide && isPill && !ocupada && !bar.mouseDentro

        // "compact": fica uma cápsula pequena com o essencial, no espírito
        // da Dynamic Island — e abre a barra inteira quando o mouse chega
        readonly property bool compacto: PraxeConfig.compacto && isPill && !ocupada && !mouseDentro

        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.namespace: "praxe-bar"

        anchors {
            top:    bar.vertical || PraxeConfig.atTop
            bottom: bar.vertical || PraxeConfig.atBottom
            left:   !bar.vertical || PraxeConfig.atLeft
            right:  !bar.vertical || PraxeConfig.atRight
        }

        // A JANELA encosta na borda; quem recua é a SUPERFÍCIE lá dentro.
        //
        // Estas margens já dependeram do layout — `notchColado ? 0 :
        // margin` — e era um bug de corrida difícil de enxergar.
        //
        // `margins` é comprometida com o compositor UMA VEZ, quando a
        // superfície de layer é criada. Nesse instante o pill.json ainda
        // não chegou (FileView é assíncrono), então valia o padrão
        // `layout: "pill"`: o notch nascia "não colado" e a janela era
        // comprometida com 6px no topo. Meio segundo depois o layout
        // virava "notch" e o binding do QML ia para 0 — mas a camada
        // ficava onde estava, com uma fresta de papel de parede acima do
        // notch, para sempre.
        //
        // O sintoma engana de propósito: mexer em `margin` no pill.json
        // não mudava nada (o valor comprometido não é relido), o que faz
        // parecer que a margem não é a culpada. Só `hyprctl layers`
        // mostra a verdade — o QML dizia `margins.top=0` com a camada
        // em y=6. Tentei `blockLoading` no FileView e não bastou.
        //
        // Com a margem fixa em 0 não há o que reler: a janela nasce
        // colada e o recuo do modo "pill" vira o `y` da superfície, que é
        // um binding comum e acompanha a configuração quando ela chega.
        margins {
            top:    0
            bottom: 0
            left:   PraxeConfig.atLeft   ? PraxeConfig.margin : 0
            right:  PraxeConfig.atRight  ? PraxeConfig.margin : 0
        }

        // O recuo que a superfície faz da borda em que a janela encosta.
        // Zero no notch — é isso que o faz nascer da borda em vez de
        // flutuar perto dela.
        readonly property int recuo: bar.notchColado ? 0 : PraxeConfig.margin

        // A janela é sempre alta o bastante para o maior painel; quem
        // define o que se vê é a superfície. A zona exclusiva continua
        // sendo só a da barra, senão as janelas fugiriam do painel.
        // Tamanho FIXO, dimensionado para o maior painel.
        //
        // Duas razões, nesta ordem:
        //  1. A superfície é filha da janela e fica cortada no que
        //     exceder — painel de 530 numa janela de 420 perdia seções.
        //  2. Fazer a janela ACOMPANHAR o painel deixava rastro: cada
        //     mudança de tamanho é um buffer novo no compositor, e a
        //     área recém-exposta mostrava conteúdo velho até repintar.
        //     Com tamanho fixo o buffer é estável e só a superfície
        //     anima. O excedente é transparente e não incomoda, porque
        //     a máscara já limita o clique à cápsula.
        // Subiu de 620 para 760 por causa do painel solto: no modo barra ele
        // não ocupa mais o LUGAR da barra, desce ABAIXO dela, e a janela tem
        // de caber os dois empilhados mais o recuo e a folga. Continua FIXO —
        // o motivo 2 acima (rastro de buffer) não mudou.
        readonly property int folgaJanela: 760

        implicitHeight: bar.vertical ? 0 : folgaJanela
        implicitWidth:  bar.vertical ? folgaJanela : 0

        // O espaço que as janelas respeitam. Em "overlap" a barra flutua
        // por cima e não reserva nada; colapsada, reserva só o filete.
        //
        // O `recuo` ENTRA nesta conta, e antes não entrava.
        //
        // Enquanto o afastamento da borda era `margins`, o compositor o
        // somava sozinho por fora da zona exclusiva, e somá-lo aqui abria
        // um buraco em dobro entre a barra e as janelas. Agora o recuo
        // mora dentro da janela, no `y` da superfície — o compositor não
        // sabe dele, e sem esta soma as janelas subiriam por baixo da
        // cápsula no modo "pill".
        //
        // No notch o recuo é 0, então nada muda lá.
        exclusiveZone: PraxeConfig.overlap ? 0
                     : bar.colapsada       ? (bar.recuo + surface.alturaFilete + PraxeConfig.gap)
                                           : (bar.recuo + Theme.pillHeight + PraxeConfig.gap)

        // Com o painel aberto, o teclado vem para cá — é o que faz o Esc funcionar
        WlrLayershell.keyboardFocus: bar.expandido ? WlrKeyboardFocus.Exclusive
                                                   : WlrKeyboardFocus.None
        color: "transparent"

        // Só o alvo recebe cliques.
        //
        // ATENÇÃO: `Region` aqui só funciona com `item:`. Definir
        // x/y/width/height direto no Region não é aplicado — a região sai
        // vazia e a barra inteira fica sem receber clique nenhum.
        // Por isso o alvo é um Item invisível, que pode ser maior que a
        // superfície quando ela está colapsada num filete de 5px.
        // A máscara soma as DUAS superfícies. Sem o painelHost aqui, o menu
        // solto aparece na tela e não recebe clique nenhum: a região de
        // entrada continuaria sendo só a da barra.
        mask: Region {
            item: alvoMouse
            Region { item: painelHost }
        }


        // Esc fecha o painel. Só recebe teclado quando está aberto,
        // então não rouba o Esc de mais ninguém.
        Item {
            anchors.fill: parent
            focus: bar.expandido
            Keys.onEscapePressed: bar.painel = ""
        }

        // Clique em qualquer lugar fora da island fecha o painel.
        //
        // O grab NÃO pode ser armado no mesmo instante em que o painel
        // abre: ele avalia o foco antes de o compositor entregá-lo à
        // camada, conclui que ninguém está focado e dispara `cleared`
        // na hora — o painel fechava antes de aparecer. Daí o atraso.
        property bool grabArmado: false

        onExpandidoChanged: {
            if (expandido) armaGrab.restart()
            else { armaGrab.stop(); grabArmado = false }
        }

        Timer {
            id: armaGrab
            interval: 300
            onTriggered: bar.grabArmado = true
        }

        HyprlandFocusGrab {
            windows: [bar]
            active: bar.expandido && bar.grabArmado
            onCleared: bar.painel = ""
        }

        Item {
            id: alvoMouse

            // A zona de captura do colapsado não pode ser MAIOR que a
            // barra aberta.
            //
            // Se for, sobra uma faixa que abre a barra e que, com ela já
            // aberta, cai fora da máscara: o cursor parado ali abre, sai,
            // fecha, entra, abre — pisca sem parar. Era o caso da altura,
            // que somava 16px fixos a um filete de 5 (=21) contra os 34 da
            // barra aberta... e da largura, se a barra estivesse curta.
            //
            // Por isso as folgas são LIMITADAS ao que falta para chegar na
            // barra aberta, em vez de somadas às cegas. É o mesmo cuidado
            // que a máscara do dock documenta: os dois estados têm de se
            // conter um ao outro.
            readonly property int folgaX: bar.colapsada
                ? Math.max(0, Math.min(Math.round(40 * Theme.scale),
                                       (surface.larguraBarra - surface.width) / 2))
                : 0
            readonly property int folgaY: bar.colapsada
                ? Math.max(0, Math.min(Math.round(16 * Theme.scale),
                                       Theme.pillHeight - surface.height))
                : 0

            x: surface.x - folgaX
            y: surface.y
            width: surface.width + folgaX * 2
            height: surface.height + folgaY

            // HoverHandler, e não MouseArea, de propósito.
            //
            // MouseArea CONSOME o hover: quando o cursor entrava no
            // relógio ou no logo (que têm hoverEnabled próprio), este
            // rastreador perdia o containsMouse e a barra encolhia no
            // meio do caminho. HoverHandler é cooperativo — vários podem
            // estar ativos ao mesmo tempo, cada um vendo o cursor.
            // Só reporta. Quem decide é `bar.sobPonteiro`, que soma esta
            // sonda às da superfície e do conteúdo — ver a nota lá em cima.
            HoverHandler { id: rastreador }
        }

        // NÃO existe sombra sob a superfície, e não é esquecimento.
        //
        // Houve aqui uma faixa de gradiente que fazia o papel de sombra. A
        // ideia era certa e a execução não tinha como funcionar: um
        // Rectangle com gradiente vertical desbota de cima para baixo, mas
        // NÃO desbota nas laterais — as bordas esquerda e direita ficam
        // retas e cheias. Sob um notch de cantos arredondados isso lê como
        // um traço, uma barra a mais logo abaixo da barra, que foi
        // exatamente como apareceu na tela.
        //
        // Estreitar a faixa e começá-la 2px acima da base atenuava o
        // sintoma sem tocar na causa: o gradiente continuava tendo um lado
        // só. Uma sombra de verdade exigiria borrão nos dois eixos
        // (MultiEffect com shadow), e a tentativa anterior disso projetava
        // o borrão POR DENTRO do retângulo — sombra em cima do notch em vez
        // de atrás.
        //
        // Sem sombra o notch fica o que ele quer ser: um recorte da tela,
        // não um objeto pousado sobre ela. Recorte não projeta sombra.
        // Antes de reintroduzir qualquer coisa aqui, saiba que já falhou
        // das duas maneiras óbvias.

        Rectangle {
            id: surface
            clip: true
            HoverHandler { id: sondaSurface }

            // ── Forma conforme o estado ──────────────────────
            readonly property int larguraBarra:
                bar.isPill ? content.implicitWidth + Theme.padH * 2 + (bar.mouseDentro ? 10 : 0)
                           : bar.width - PraxeConfig.sideMargin * 2

            readonly property int larguraPainel:
                bar.emLauncher  ? Math.round(620 * Theme.scale)
              : bar.emWallpaper ? Math.round(640 * Theme.scale)
              : bar.emAparencia ? Math.round(520 * Theme.scale)
                                : Math.round(430 * Theme.scale)
            // O painel cresce conforme o que tem dentro: mídia e a
            // pilha de notificações somam altura, até um teto.
            readonly property int alturaPainel: {
                if (bar.emLauncher)  return Math.round(440 * Theme.scale)
                if (bar.emWallpaper) return Math.round(420 * Theme.scale)
                if (bar.emAparencia) return Math.round(555 * Theme.scale)
                let h = 140
                if (centro.temMidia) h += 66
                // A linha de brilho só existe quando há monitor DDC/CI, e
                // a altura do painel é CRAVADA aqui — sem esta soma a linha
                // era desenhada e ficava fora do recorte, invisível e sem
                // erro nenhum para denunciar.
                if (centro.brilhoDisponivel) h += 34
                const n = Notificacoes.quantidade
                if (n > 0) h += 26 + Math.min(n, 3) * 50
                else if (Notificacoes.silencioso) h += 26
                return Math.round(Math.min(h, 400) * Theme.scale)
            }

            readonly property int larguraOsd: Math.round(230 * Theme.scale)
            readonly property int larguraBalao: Math.round(400 * Theme.scale)
            readonly property int alturaBalao: Math.round(54 * Theme.scale)

            // ── A ilha fechada ──────────────────────────────
            //
            // Era um filete de 5px sem nada dentro. Agora mostra a hora:
            // é a informação que se olha de relance mais vezes por dia, e
            // é ela que justifica o elemento ficar sempre na tela.
            //
            // A largura SAI DO TEXTO, e não de um número fixo. Quem puser
            // segundos ou a data no clockFormat teria a hora cortada pelo
            // clip da superfície se a largura fosse fixa em 110.
            readonly property int alturaFilete: Math.round(20 * Theme.scale)
            readonly property int larguraFilete:
                Math.round(relogioIlha.implicitWidth + 24 * Theme.scale)



            // No vertical os papéis se invertem: a espessura vira a
            // largura e o conteúdo cresce na altura.
            width: bar.vertical
                 ? (bar.expandido ? larguraPainel
                                  : Math.max(Theme.pillHeight,
                                             content.implicitWidth + Math.round(14 * Theme.scale)))
                 : (bar.expandido && !bar.modoSolto) ? larguraPainel
                 : bar.emOsd     ? larguraOsd
                 : bar.emBalao   ? larguraBalao
                 // Só a CÁPSULA encolhe na largura ao se esconder. A
                 // barra de ponta a ponta some pela ALTURA e mantém a
                 // largura: encolher a largura dela faz a barra varrer a
                 // tela da esquerda para a direita toda vez que aparece,
                 // que é justamente o que não se espera de uma barra.
                 : (bar.colapsada && bar.isPill) ? larguraFilete
                                 : larguraBarra

            implicitHeight: bar.vertical
                          ? (bar.expandido ? alturaPainel
                                           : content.implicitHeight + Theme.padH * 2)
                          : (bar.expandido && !bar.modoSolto) ? alturaPainel
                          : bar.emBalao   ? alturaBalao
                          : bar.colapsada ? alturaFilete
                                          : Theme.pillHeight

            // O raio DERIVA da dimensão animada e nunca passa da metade
            // dela — assim a cápsula é sempre uma pill de verdade quando
            // pequena, e vira painel quando cresce.
            //
            // Sem o teto, e com Behavior próprio, o raio perseguia um
            // alvo em movimento: ao sair do filete a barra crescia com
            // canto reto e só arredondava no fim. É o mesmo erro do `x`.
            readonly property int raioMaximo:
                (bar.expandido && !bar.modoSolto) ? Math.round(24 * Theme.scale)
              : bar.isPill    ? 9999                       // pill total
                              : PraxeConfig.barRadius

            readonly property int raioAtual:
                Math.min(raioMaximo, (bar.vertical ? width : height) / 2)

            radius: raioAtual

            // Cantos de cima retos no notch. Os de baixo herdam o `radius`,
            // que já acompanha a altura animada — então a gota mantém a
            // proporção enquanto abre, sem raio perseguindo alvo.
            topLeftRadius:  bar.notchColado ? 0 : raioAtual
            topRightRadius: bar.notchColado ? 0 : raioAtual


            y: bar.vertical ? (bar.height - height) / 2
             : PraxeConfig.atTop ? bar.recuo
                                 : bar.height - height - bar.recuo

            x: bar.vertical
               ? (PraxeConfig.atLeft ? 0 : bar.width - width)
               : (bar.isPill || (bar.expandido && !bar.modoSolto) || bar.emOsd || bar.emBalao || bar.colapsada)
                 ? (bar.width - width) / 2
                 : PraxeConfig.sideMargin

            // Colapsada, é a MESMA cor da barra, só bem translúcida.
            // O compositor aplica blur nesta camada (regra em
            // windows.lua), então o filete lê como um vidro fosco sobre
            // o papel de parede. Antes era um traço dourado, que gritava
            // demais para um elemento que fica sempre na tela.
            // Esta Rectangle é a cápsula E todo painel: o que muda entre
            // os dois é só o tamanho. Por isso a transparência sai do
            // ESTADO, e não de duas superfícies diferentes — expandida ela
            // usa a opacidade dos painéis, fechada a do pill.
            color: (bar.expandido && !bar.modoSolto) ? PraxeConfig.colBgPainel
                                                     : PraxeConfig.colBgPill

            // O `Behavior on color` desta superfície está mais abaixo, junto
            // com o de opacity. Havia um SEGUNDO aqui, que eu acrescentei ao
            // trocar a cor por uma que depende do estado — e dois Behaviors
            // na mesma propriedade não se somam: o QML avisa
            // "another interceptor ... unsupported" e ignora um deles.

            opacity: bar.colapsada ? 0.72 : 1.0

            // Sem borda, em nenhum formato.
            //
            // O notch imita um recorte físico da tela. Qualquer linha de
            // contorno entrega que é software desenhado por cima, e a borda
            // dourada era o que mais entregava — o recorte de um celular não
            // tem contorno, ele simplesmente É o fim da tela.
            //
            // Vale igual para a cápsula: o que a separa do papel de parede
            // é o próprio contraste do fundo escuro, e nada mais. Já houve
            // uma sombra aqui para fazer esse trabalho — ver o comentário
            // logo antes desta superfície sobre por que ela saiu.
            border.width: 0

            Behavior on color   { ColorAnimation  { duration: bar.animCor } }
            Behavior on opacity { NumberAnimation { duration: bar.animCor ; easing.type: Theme.curva } }

            // NÃO anime o `x`.
            //
            // Ele é derivado da largura — centro = (tela - largura) / 2.
            // Com Behavior próprio, o x persegue um alvo que também está
            // se movendo e chega sempre atrasado: a cápsula muda de forma
            // e SÓ DEPOIS acaba de centralizar, que é o solavanco. Sem
            // Behavior, o x reavalia a cada quadro junto com a largura e
            // as duas coisas acontecem no mesmo movimento.
            Behavior on width  { NumberAnimation { duration: bar.animForma; easing.type: Easing.OutCubic } }

            // ...e a altura, mais devagar: é isso que faz desdobrar
            onImplicitHeightChanged: {
                animAltura.stop()
                animAltura.to = implicitHeight
                animAltura.start()
            }
            Component.onCompleted: height = implicitHeight
            NumberAnimation {
                id: animAltura
                target: surface
                property: "height"
                duration: bar.animForma
                easing.type: Easing.OutCubic
            }

            // Fronteira de grupo: RESPIRO, não linha.
            //
            // Era um filete de 1px em DIM entre cada grupo de módulos. Uma
            // linha divisória é a solução mais barata para "separar", e a
            // mais barulhenta: são seis traços permanentes numa peça que
            // existe para desaparecer, e cada um deles é uma coisa a mais
            // que o olho registra sem que diga nada.
            //
            // Agrupamento limpo se faz por PROXIMIDADE. O espaçamento base
            // caiu de 16 para 7 (itemGap) e a fronteira passou a valer 16
            // (groupGap): dentro do grupo os módulos ficam colados, entre
            // grupos abre um vão de ~30px. A leitura é a mesma que a linha
            // dava, sem nada desenhado — e a cápsula ainda encurta, porque
            // seis traços de 1px viraram vão só onde há fronteira de fato.
            //
            // Os pontos de chamada continuam iguais: eles já sabiam onde
            // cada grupo termina, que é a parte difícil. Só o `bar.isPill`
            // saiu, para o modo barra ganhar o mesmo ritmo — ele antes não
            // tinha separação nenhuma entre os grupos da direita.
            component Sep: Item {
                Layout.alignment: bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                Layout.preferredWidth: bar.vertical ? 1 : Theme.groupGap
                Layout.preferredHeight: bar.vertical ? Theme.groupGap : 1
                visible: !bar.compacto
            }

            // O Spacer era o que distribuía os módulos no modo barra: dois
            // vãos elásticos empurrando os grupos para as pontas. Continua
            // servindo à CÁPSULA (onde não há zonas, só uma fileira), mas no
            // modo barra ele foi substituído pelas três zonas ancoradas logo
            // abaixo — vão elástico não centraliza de verdade, ele divide o
            // que sobra, e aí o relógio anda toda vez que o título da música
            // muda de tamanho.
            component Spacer: Item {
                Layout.fillWidth: !bar.isPill
                visible: !bar.isPill
            }

            // ── A barra ──────────────────────────────────────
            // GridLayout, e não Row/Column: o `flow` troca o sentido sem
            // precisar de duas cópias dos módulos.
GridLayout {
                id: content
                HoverHandler { id: sondaContent }

                // Posição por x/y, sem âncoras, de propósito.
                //
                // `anchors.left: undefined` NÃO desfaz a âncora: o QML
                // mantém a antiga, e no modo vertical sobravam left,
                // right e horizontalCenter ao mesmo tempo. O layout
                // colapsava e a cápsula aparecia vazia. Com x/y não há
                // como entrar em conflito.
                width:  bar.vertical ? implicitWidth : surface.width - Theme.padH * 2
                height: bar.vertical ? implicitHeight : Theme.pillHeight
                x: bar.vertical ? (surface.width - width) / 2 : Theme.padH
                y: (surface.height - height) / 2

                flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                columns: bar.vertical ? 1 : -1
                rows:    bar.vertical ? -1 : 1
                // Base APERTADA, de propósito: quem separa é o `Sep` acima,
                // e só onde há fronteira de grupo. Com 16 em tudo, módulos
                // do mesmo grupo ficavam tão distantes quanto módulos de
                // grupos diferentes — e aí a única coisa que agrupava era a
                // linha desenhada, o que explica por que ela parecia
                // necessária.
                rowSpacing: Theme.itemGap
                columnSpacing: Theme.itemGap

                opacity: (bar.expandido || bar.emOsd || bar.emBalao || bar.colapsada) ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 ; easing.type: Theme.curva } }

                // O símbolo do Arch, tingido AO VIVO com a cor em vigor.
                //
                // Antes ele lia um SVG que o rice-theme regerava com o acento
                // embutido. Funcionava, mas dependia de o arquivo ser reescrito
                // E de a barra reiniciar para o Qt largar a imagem em cache — e
                // ignorava o barAccent do pill.json. Com MultiEffect a cor é um
                // binding: muda na hora, sem arquivo intermediário.
                Item {
                    id: mark
                    Layout.alignment: bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

                    // Fora do modo COMPACTO.
                    //
                    // O compacto é a cápsula reduzida ao essencial, e todo o
                    // resto já se retira dele: áreas, mídia, recursos,
                    // volume e clima têm `!bar.compacto`. O logo era o único
                    // que ficava — e ficava por esquecimento, não por
                    // decisão. Sozinho ao lado da hora, ele passava a
                    // parecer o assunto da cápsula em vez de um botão.
                    //
                    // Não se perde alcance: o compacto abre a barra inteira
                    // quando o ponteiro chega, e ali o logo está de volta.
                    visible: PraxeConfig.showMenuDot && !bar.compacto

                    Layout.preferredWidth: Math.round(20 * Theme.scale)
                    Layout.preferredHeight: Layout.preferredWidth
                    implicitWidth: Layout.preferredWidth
                    implicitHeight: Layout.preferredHeight

                    Image {
                        id: markFonte
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME")
                                + "/.config/rice/assets/arch-mark.svg"
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: false          // quem aparece é o efeito
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: markFonte
                        colorization: 1.0
                        colorizationColor: PraxeConfig.colAccent
                        opacity: menuArea.containsMouse ? 1.0 : 0.85

                        Behavior on colorizationColor { ColorAnimation { duration: 320 } }
                        Behavior on opacity { NumberAnimation { duration: 150 ; easing.type: Theme.curva } }
                    }

                    // Sem `Process` aqui, de propósito — ver a nota longa no
                    // ControlCenter.qml. Em resumo: `running = true` num
                    // Process que já está rodando é ignorado em silêncio, e o
                    // rice-menu fica aberto enquanto o fuzzel estiver na tela.
                    // Bastava um fuzzel pendurado para ESTE botão — o menu
                    // principal do rice — parar de responder até reiniciar a
                    // barra.

                    // Handlers, e não MouseArea — ver a nota do rastreador
                    // lá em cima. Um MouseArea com hoverEnabled ENGOLE o
                    // hover: o rastreador da barra deixava de ver o cursor
                    // assim que ele entrava aqui, a carência corria, a
                    // barra colapsava, o logo sumia de baixo do ponteiro e
                    // tudo recomeçava — a barra piscava sem parar.
                    Item {
                        id: menuArea
                        anchors.fill: parent
                        anchors.margins: -6
                        readonly property bool containsMouse: menuHover.hovered

                        HoverHandler {
                            id: menuHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        // Esquerdo abre o LANÇADOR DE APPS, embaixo do
                        // próprio logo — o gesto que todo mundo já traz
                        // aprendido do botão iniciar. Antes ele chamava o
                        // rice-menu (fuzzel), que aparecia no meio da tela
                        // sem relação nenhuma com o ponto clicado.
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                bar.ancoraX = mark.mapToItem(null, mark.width / 2, 0).x
                                bar.painel = bar.painel === "launcher" ? "" : "launcher"
                            }
                        }

                        // O rice-menu não sumiu: foi para o botão direito.
                        // Ele é o menu de SISTEMA (energia, sessão, ajustes
                        // do rice), coisa diferente de lançar aplicativo, e
                        // continuar alcançável importa mais que ser óbvio.
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: Quickshell.execDetached([PraxeConfig.bin + "rice-menu"])
                        }
                    }
                }

                Sep { visible: bar.isPill && PraxeConfig.showMenuDot && !bar.compacto }
                Workspaces {
                    id: areas
                    Layout.alignment: bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                    visible: PraxeConfig.showWorkspaces && !bar.compacto
                }
                Spacer {}
                Sep { visible: bar.isPill && media.active && !bar.compacto && !bar.vertical }
                MediaInfo {
                    id: media
                    Layout.alignment: Qt.AlignVCenter
                    visible: PraxeConfig.showMedia && !bar.compacto && !bar.vertical
                }
                Spacer {}
                Sep { visible: bar.isPill && !bar.compacto && !bar.vertical }
                Resources {
                    id: recursos
                    Layout.alignment: Qt.AlignVCenter
                    visible: PraxeConfig.showResources && !bar.compacto && !bar.vertical
                }
                Sep { visible: bar.isPill && PraxeConfig.showVolume && !bar.compacto && !bar.vertical }
                Volume {
                    id: volume
                    Layout.alignment: Qt.AlignVCenter
                    visible: PraxeConfig.showVolume && !bar.compacto && !bar.vertical
                }
                Sep { visible: bar.isPill && PraxeConfig.showClock && !bar.compacto }

                // O relógio é SÓ relógio.
                //
                // Ele abria o centro de controle, o que é um alvo ruim: é
                // o elemento que mais se olha sem querer clicar, e ficava
                // com cursor de mão o tempo todo prometendo uma ação que
                // não se lê no desenho. Quem abre as configurações agora é
                // a engrenagem, logo à direita — um botão que parece botão.
                //
                // O `relogioArea` continua aqui, mas só como sonda de
                // hover: ele fica na ponta da cápsula e é onde o ponteiro
                // mais passa, então some ao `bar.sobPonteiro` para a barra
                // não colapsar com o cursor em cima.
                Text {
                    id: relogioTexto
                    Layout.alignment: bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                    visible: PraxeConfig.showClock
                    text: bar.vertical
                          ? Qt.formatDateTime(relogio.date, "HH") + "\n" + Qt.formatDateTime(relogio.date, "mm")
                          : Qt.formatDateTime(relogio.date, PraxeConfig.clockFormat)
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.85
                    color: PraxeConfig.colAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: bar.vertical ? Theme.fontSize - 1 : Theme.fontSize
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: 120 } }

                    SystemClock { id: relogio; precision: SystemClock.Minutes }

                    // Mesmo motivo do logo: handlers cooperativos. Era AQUI
                    // que a barra piscava mais, porque o relógio fica na
                    // ponta e é o alvo que se passa mais tempo mirando.
                    Item {
                        id: relogioArea
                        anchors.fill: parent
                        anchors.margins: -6

                        // Sem `cursorShape`: não há mais o que clicar aqui.
                        HoverHandler { id: relogioHover }
                    }
                }

                // ── Clima ────────────────────────────────────────
                // À direita do relógio, como pedido. Se some sozinho
                // quando não há cidade configurada — ver Clima.qml.
                Sep {
                    visible: bar.isPill && PraxeConfig.showWeather
                             && clima.temValor && !bar.compacto && !bar.vertical
                }
                Clima {
                    id: clima
                    Layout.alignment: Qt.AlignVCenter
                    visible: PraxeConfig.showWeather && !bar.compacto && !bar.vertical
                }

                // ── Engrenagem ───────────────────────────────────
                // Herdou do relógio o papel de abrir o centro de controle.
                Sep { visible: bar.isPill && !bar.compacto }

                Text {
                    id: engrenagem
                    Layout.alignment: bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                    text: "󰒓"
                    color: engrenagemHover.hovered || bar.painel === "control"
                           ? PraxeConfig.colFg : PraxeConfig.colMuted
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Theme.iconSize
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Gira um oitavo ao passar o mouse: dá a entender que
                    // é mecanismo, não decoração. Um oitavo e não meia
                    // volta porque a engrenagem tem simetria de 8 dentes —
                    // mais que isso e o movimento não se lê.
                    rotation: engrenagemHover.hovered ? 45 : 0
                    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Item {
                        anchors.fill: parent
                        anchors.margins: -6

                        HoverHandler {
                            id: engrenagemHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                // O menu desce embaixo de QUEM foi clicado, e
                                // por isso a posição é lida no momento do
                                // clique: a engrenagem anda quando o título da
                                // música cresce, e uma âncora guardada antes
                                // apontaria para onde ela estava, não onde está.
                                // `null` e não `bar`: mapToItem espera um
                                // Item, e `bar` é uma PanelWindow. Passar a
                                // janela lança TypeError e o handler morre
                                // ANTES de abrir o painel — foi o que deixou
                                // a engrenagem sem resposta. Com `null` o
                                // destino é a cena, que é o mesmo sistema de
                                // coordenadas do `surface.x`.
                                bar.ancoraX = engrenagem.mapToItem(null, engrenagem.width / 2, 0).x
                                bar.painel = bar.painel === "control" ? "" : "control"
                            }
                        }
                    }
                }
            }

            // ── A hora da ilha fechada ───────────────────────
            //
            // Vive FORA do `content`, que vai a opacity 0 no colapso —
            // reaproveitar o relógio de lá obrigaria a manter o conteúdo
            // inteiro visível só por causa de um item.
            //
            // Branco puro, e não colFg: aqui o texto não está compondo com
            // a paleta, está sendo lido de canto de olho sobre um fundo
            // translúcido que tem o papel de parede por baixo. Qualquer
            // cor do tema perde contraste quando o papel é claro.
            // Virou Row para caber o clima ao lado da hora. O
            // `larguraFilete` sai do implicitWidth deste item, então a
            // cápsula fechada cresce e encolhe sozinha conforme o clima
            // entra ou sai — nada de largura fixa para acertar na mão.
            Row {
                id: relogioIlha
                anchors.centerIn: parent

                // O `visible` segura no colapsado por si, e não só pelo
                // opacity. Durante o flash da área o relógio vai a zero,
                // mas precisa CONTINUAR no layout: é o `implicitWidth`
                // dele que define `larguraFilete`, e sair do layout faria
                // a cápsula encolher até o dígito e crescer de novo a cada
                // troca de área — um repuxo a cada SUPER+n.
                //
                // Fora do colapso o `opacity > 0.01` continua mandando,
                // para a saída do filete ainda ser em fade e não um corte.
                visible: (bar.colapsada && !bar.vertical) || opacity > 0.01
                opacity: (bar.colapsada && !bar.vertical)
                         ? (bar.mostrandoArea ? 0 : 1)
                         : 0
                spacing: Math.round(6 * Theme.scale)

                // Entra depois que a barra terminou de encolher, senão o
                // texto aparece em cima de uma cápsula ainda larga.
                Behavior on opacity { NumberAnimation { duration: 220 ; easing.type: Theme.curva } }

                // Os pontos de workspace JÁ ESTIVERAM aqui, e saíram.
                //
                // A informação era boa — fechada, a barra esconde em qual
                // área de trabalho você está — mas o filete não é lugar
                // para a FILEIRA: cinco pontos ao lado de um relógio
                // pequeno encheram a cápsula sem que nada ali fosse
                // legível de relance, e o conjunto virou enfeite. Um
                // mostrador que ninguém lê é peso.
                //
                // A informação voltou, do jeito que a nota antiga mandava:
                // UM indicador, o número da área — e nem sempre, só no
                // instante da troca (ver `areaIlha`, logo abaixo). Assim
                // ela não ocupa espaço permanente nenhum: a cápsula
                // fechada continua sendo hora e clima, e o número aparece
                // exatamente quando é a pergunta que você está fazendo.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(relogioIlhaFonte.date, PraxeConfig.clockFormat)
                    color: PraxeConfig.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Theme.fontSize - 3)
                    font.weight: Font.Medium
                    // A hora fica mais legível pequena com as letras um pouco
                    // afastadas — no tamanho cheio isso viraria enfeite.
                    font.letterSpacing: 0.5

                    SystemClock { id: relogioIlhaFonte; precision: SystemClock.Minutes }
                }

                // Clima na ilha fechada.
                //
                // Lê do módulo `clima`, que vive no `content`: o content vai
                // a opacity 0 no colapso, mas continua existindo e o Process
                // dele segue consultando. Reaproveitar o dado evita uma
                // segunda consulta à API só para o filete.
                //
                // Some junto quando não há cidade (`temValor`), e aí a
                // cápsula volta à largura de só a hora.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // Comparação explícita, e não só `a && b`: no primeiro
                    // quadro do reload o `clima` ainda não existe, `temValor`
                    // vem `undefined` e `undefined && x` é `undefined` — que
                    // `visible` recusa, com aviso no log.
                    visible: PraxeConfig.showWeatherFilete === true
                             && clima.temValor === true
                    text: clima.glifo + " " + clima.temp + "°"
                    color: PraxeConfig.colFg
                    font.family: Theme.nerdFontFamily
                    font.pixelSize: Math.round(Theme.fontSize - 3)
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                }

                // ── Aviso de notificação não vista ──────────
                //
                // Só existe quando há algo na fila, e some sozinho quando
                // a fila esvazia. A PRESENÇA é a mensagem — por isso não
                // há número: contar avisos é trabalho do painel, e um
                // "3" minúsculo aqui não muda o que você faz a seguir.
                //
                // Este é o único ponto do filete que NÃO é branco, e a
                // exceção é deliberada. Os pontos de workspace e o
                // relógio estão sempre lá: o trabalho deles é ser lido,
                // e branco é o que aguenta qualquer papel de parede por
                // baixo. Este aparece raramente e o trabalho dele é ser
                // NOTADO — para isso ele precisa da cor que o resto do
                // sistema usa para chamar atenção, não da mais legível.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notificacoes.naoVistas > 0
                    width: Math.round(6 * Theme.scale)
                    height: width
                    radius: width / 2
                    // Theme.aviso, e não colAccent: quase sempre É o
                    // acento (o Theme cai nele sozinho), mas o tema pode
                    // declarar outra cor quando o acento dele não soa
                    // como aviso — ver AVISO no samurai.sh.
                    color: Theme.aviso

                    // Sem animação de entrada: um ponto que pulsa no topo
                    // da tela vira o assunto, e ele é um rodapé.
                    Behavior on opacity { NumberAnimation { duration: 180 ; easing.type: Theme.curva } }
                }
            }

            // ── A área de trabalho, no instante da troca ─────
            //
            // Fechada, a cápsula não dizia para ONDE você acabou de ir: o
            // SUPER+n mudava a tela e o único jeito de confirmar o número
            // era abrir a barra — o que anula o atalho.
            //
            // Fica IRMÃO do relógio e não dentro dele, sobreposto no mesmo
            // centro. É o que mantém a cápsula do mesmo tamanho durante o
            // flash: a largura sai do `implicitWidth` do relógio, que
            // continua no layout mesmo a opacity 0. Se este número entrasse
            // na Row, ele empurraria a hora de lado.
            //
            // Branco puro pelo mesmo motivo do relógio: é lido de canto de
            // olho sobre um fundo translúcido com o papel de parede por
            // baixo, e cor de tema perde contraste quando o papel é claro.
            Text {
                id: areaIlha
                anchors.centerIn: parent
                text: bar.areaMostrada

                // Só no colapsado: aberta, a fileira de pontos já mostra a
                // ativa como pill COM o número dentro, e um segundo número
                // por cima seria a mesma resposta duas vezes.
                opacity: (bar.mostrandoArea && bar.colapsada && !bar.vertical)
                         ? 1 : 0
                visible: opacity > 0.01

                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                // Um passo maior que a hora: é um caractere só e aparece
                // por um segundo, então precisa ser pego sem procurar.
                font.pixelSize: Math.round(Theme.fontSize - 1)
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5

                // Entra mais rápido do que sai. A entrada compete com o
                // movimento da própria troca de área e precisa chegar
                // junto; a saída não tem pressa e some sem chamar atenção.
                Behavior on opacity {
                    NumberAnimation { duration: bar.mostrandoArea ? 140 : 260 ; easing.type: Theme.curva }
                }
            }

            // ── O OSD de volume ──────────────────────────────
            OsdVolume {
                id: osdVol
                anchors.fill: parent
                aberto: bar.emOsd
            }

            // ── O balão de notificação ───────────────────────
            Balao {
                id: balao
                anchors.fill: parent
                aberto: bar.emBalao
            }
        }

        // ── O hospedeiro dos painéis ─────────────────────────
        //
        // Os quatro painéis moravam DENTRO da `surface`, com anchors.fill —
        // era isso que obrigava a superfície a crescer até virar painel, e no
        // modo barra significava a barra sumir para abrir um menu.
        //
        // Aqui eles têm container próprio, que muda de papel conforme o modo:
        //
        //   cápsula → INVISÍVEL, apenas acompanha a `surface`. Fundo, raio e
        //             animação continuam sendo dela, e a gota que desce do
        //             notch fica exatamente como estava.
        //
        //   barra   → é a própria superfície do menu: fundo, raio e recorte
        //             seus, descendo abaixo da barra, ancorado no gatilho.
        //
        // `clip` sempre ligado: é ele que faz o conteúdo ser revelado pelo
        // crescimento em vez de aparecer inteiro e ser coberto depois.
        Rectangle {
            id: painelHost
            clip: true

            width:  bar.modoSolto ? surface.larguraPainel : surface.width
            height: bar.modoSolto ? surface.alturaPainel  : surface.height

            // Ancorado no gatilho, mas PRESO à tela: menu que sangra pela
            // borda é pior que menu fora do lugar. O limite é a mesma margem
            // lateral da barra, então ele nunca passa dela.
            x: {
                if (!bar.modoSolto) return surface.x
                const alvo = bar.ancoraX < 0 ? (bar.width - width) / 2
                                             : bar.ancoraX - width / 2
                const min = PraxeConfig.sideMargin
                const max = bar.width - width - PraxeConfig.sideMargin
                return Math.round(Math.max(min, Math.min(max, alvo)))
            }

            // Desce quando a barra está em cima, sobe quando está embaixo —
            // o menu sempre abre para o lado de dentro da tela.
            y: {
                if (!bar.modoSolto) return surface.y
                return PraxeConfig.atTop
                     ? surface.y + surface.height + PraxeConfig.gap
                     : surface.y - height - PraxeConfig.gap
            }

            color:  bar.modoSolto ? PraxeConfig.colBgPainel : "transparent"
            radius: bar.modoSolto ? Math.round(24 * Theme.scale) : 0

            // Só o menu solto aparece e some por conta própria. No modo
            // cápsula quem faz isso é a superfície, e um segundo fade aqui
            // multiplicaria as duas opacidades.
            opacity: bar.modoSolto ? (bar.expandido ? 1 : 0) : 1
            visible: bar.modoSolto ? opacity > 0.01 : true
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            // ── O centro de controle ─────────────────────────
            ControlCenter {
                id: centro
                anchors.fill: parent
                aberto: bar.painel === "control"

                // Mesma regra de alternância dos IpcHandlers lá em cima:
                // clicar de novo no mesmo atalho fecha o painel.
                onPedirPainel: nome => bar.painel = (bar.painel === nome ? "" : nome)
            }

            // ── O lançador de aplicativos ────────────────────
            Launcher {
                id: lancador
                anchors.fill: parent
                aberto: bar.emLauncher
                onFechar: bar.painel = ""
            }

            // ── Papel de parede ─────────────────────────────
            Wallpapers {
                id: papeis
                anchors.fill: parent
                aberto: bar.emWallpaper
                onFechar: bar.painel = ""
            }

            // ── Central de aparência ────────────────────────
            Aparencia {
                id: aparencia
                anchors.fill: parent
                aberto: bar.emAparencia
                onFechar: bar.painel = ""
                onIrParaPapeis: bar.painel = "wallpaper"
            }
        }

        // ── Quem dispara o OSD ───────────────────────────────
        // Mexeu no volume por fora (tecla de mídia, roda do mouse), a
        // island vira uma cápsula pequena e volta sozinha.
        readonly property var sink: Pipewire.defaultAudioSink
        PwObjectTracker { objects: [bar.sink] }

        Connections {
            target: bar.sink?.audio ?? null
            enabled: bar.sink !== null

            function onVolumeChanged() { bar.mostrarOsd() }
            function onMutedChanged()  { bar.mostrarOsd() }
        }

        // Ignora o primeiro disparo, que vem só de o Pipewire conectar
        property bool osdArmado: false
        Timer {
            interval: 1500; running: true; repeat: false
            onTriggered: bar.osdArmado = true
        }

        function mostrarOsd() {
            if (!osdArmado || painel !== "") return
            osd = "volume"
            tempoOsd.restart()
        }

        Timer {
            id: tempoOsd
            interval: 1100
            onTriggered: bar.osd = ""
        }

        // ── Quem dispara o número da área ────────────────────
        //
        // `Hyprland.focusedWorkspace?.id` é LEITURA DE PROPRIEDADE, então
        // o binding reavalia sozinho a cada troca. Um método invocável
        // (`Hyprland.dispatch(...)` e afins) rodaria uma vez e nunca mais
        // — é a armadilha que já custou o dock deste rice.
        //
        // `?? 0` porque na subida ainda não há área em foco, e `undefined`
        // num `int` rende aviso no log a cada quadro.
        readonly property int areaFoco: Hyprland.focusedWorkspace?.id ?? 0

        // O número que o filete mostra. Guardado à parte do `areaFoco`
        // para o dígito não sumir no meio do fade de saída: a área já
        // mudou, mas o flash antigo ainda está desaparecendo.
        property int areaMostrada: 0
        property bool mostrandoArea: false

        // Mesmo remédio do OSD de volume: ignora o disparo da subida.
        // Sem isso a barra pisca o número sozinha ao nascer, porque o
        // `focusedWorkspace` chega depois do primeiro quadro e isso conta
        // como mudança.
        property bool areaArmada: false
        Timer {
            interval: 1500; running: true; repeat: false
            onTriggered: bar.areaArmada = true
        }

        onAreaFocoChanged: {
            if (areaFoco <= 0) return      // áreas especiais e o vazio da subida
            areaMostrada = areaFoco
            if (!areaArmada) return
            mostrandoArea = true
            tempoArea.restart()
        }

        Timer {
            id: tempoArea
            // O mesmo 1.1s do OSD de volume, e de propósito: são dois
            // avisos passageiros do mesmo lugar, e tempos diferentes
            // fariam a barra parecer ter dois relógios internos.
            interval: 1100
            onTriggered: bar.mostrandoArea = false
        }
    }
}
