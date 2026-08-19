// ┌──────────────────────────────────────────────────────────────┐
// │  Os aplicativos abertos, na fileira da cápsula.               │
// └──────────────────────────────────────────────────────────────┘
//
// É a peça que faltava para a cápsula responder "o que está aberto?"
// sem passar pelo dock. Um ícone por aplicativo, clicável para trazer à
// frente, com menu de contexto no botão direito para ver as janelas uma
// a uma e fechar o que não serve mais.
//
// Só aparece na cápsula CHEIA: some no compacto e no colapsado, que são
// estados de "sai da frente", e no modo vertical, onde a fileira não
// caberia sem virar outra coisa.
//
// ── DE ONDE VÊM OS DADOS ────────────────────────────────────────
//
// `ToplevelManager`, do Quickshell — o protocolo
// wlr-foreign-toplevel-management, o mesmo que qualquer barra Wayland
// usa. Ele entrega appId, título, foco, `activate()` e `close()` prontos.
// Não há dependência a instalar e não se fala com o Hyprland direto:
// trocar de compositor não quebra este arquivo.
//
// ── POR QUE POR APLICATIVO, E NÃO POR JANELA ────────────────────
//
// Uma barra de tarefas clássica lista JANELAS. Aqui lista APLICATIVOS,
// agrupando as janelas de cada um, por dois motivos:
//
//   1. A cápsula tem largura de cápsula. Uma entrada por janela e ao
//      meio-dia ela é uma régua — o Firefox sozinho põe cinco.
//   2. É o que o Windows moderno e o macOS fazem: a janela virou
//      detalhe interno do aplicativo.
//
// As janelas não somem da vista, mudam de lugar: estão no menu do botão
// direito, com título e fechamento individual.
//
// ── A REGRA DAS STRINGS (não simplifique de volta) ──────────────
//
// O model deste Repeater é uma lista de `appId` — texto puro. NÃO pode
// ser uma lista de objetos com o `Toplevel*` dentro. O Dock.qml carrega
// um comentário longo sobre isto porque JÁ DERRUBOU o shell: um mapa
// comum não segura o objeto vivo, é ponteiro cru, e o Repeater INCUBA o
// delegate — constrói nos quadros seguintes, não na hora. Entre montar a
// lista e o delegate nascer, a janela pode ter fechado, e a conversão do
// ponteiro morto é SIGSEGV dentro do incubador.
//
// Vale para o model do menu também: ali vão `{ titulo, indice }`, dois
// valores simples, e a janela é reencontrada no clique.
//
// Por isso o `Toplevel` é buscado pelo appId DENTRO do delegate, no
// momento do uso, e nunca guardado no model.

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: raiz

    // Quem manda no tamanho é a fileira lá dentro.
    implicitWidth: fileira.implicitWidth
    implicitHeight: fileira.implicitHeight

    readonly property int tamIcone: Math.round(18 * Theme.scale)

    // Faixa reservada embaixo do ícone para o traço de foco/quantidade.
    // Ela é do TRAÇO, não do ícone: contar a faixa como parte do ícone
    // deixaria o ícone com o centro acima do centro da célula, e como a
    // célula é centrada na cápsula esses poucos pixels viram a fileira
    // inteira parecendo flutuar alto. É o mesmo defeito que o Dock.qml
    // documenta ter custado o alinhamento dele.
    readonly property int faixaMarca: Math.round(6 * Theme.scale)

    // Avisa a barra que há menu aberto. Sem isto a cápsula colapsa
    // debaixo do menu — `colapsada` só olha painel, OSD e balão, e um
    // menu que sobrevive à barra que o abriu fica órfão na tela.
    readonly property bool menuAberto: menu.visible

    // ── Revisão da lista de aplicativos ─────────────────────────
    //
    // `DesktopEntries.heuristicLookup()` é um MÉTODO, não uma leitura de
    // propriedade. O QML só registra dependência no que ele vê ser LIDO
    // durante a avaliação do binding — chamada de método C++ não registra
    // nada. E a lista não está pronta na subida: o Quickshell varre os
    // .desktop de forma assíncrona, começando no primeiro acesso.
    //
    // Sem este contador o binding roda uma vez, com a lista AINDA VAZIA,
    // `entrada` sai null para todo mundo, e nada jamais manda reavaliar —
    // os ícones ficam sem nome para sempre. É a mesma armadilha que
    // custou o dock inteiro; a nota longa está no Dock.qml.
    property int revApps: 0

    // `applicationsChanged` dispara UMA VEZ POR ENTRADA encontrada — mais
    // de cem na subida. Reagir a cada uma re-incubaria os delegates cem
    // vezes, que é justamente o caminho de código onde o Quickshell
    // estava morrendo. O timer engole a rajada e avisa uma vez só.
    Timer {
        id: assentarApps
        interval: 120
        onTriggered: raiz.revApps++
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { assentarApps.restart() }
    }

    // ── Revisão dos ícones ──────────────────────────────────────
    //
    // Mesma história com `Quickshell.iconPath()`: função, não
    // propriedade. O caminho depende do tema de ícones em vigor e o
    // binding só reavaliaria se o NOME mudasse — e o nome nunca muda.
    // Bastava trocar de tema para a fileira ficar com caminhos mortos.
    property int revIcones: 0

    Connections {
        target: PraxeConfig
        function onIconThemeChanged() { raiz.revIcones++ }
    }

    // O mapa que o rice-dock-icones deixa pronto no disco. É a fonte
    // PREFERIDA — a busca por ícone falha de quatro maneiras dentro do
    // QML (nome que o tema não tem, caixa diferente, ícone só em
    // /usr/share/pixmaps, corrida com a reconstrução do tema), e o
    // gerador já resolveu todas fora. O `iconPath` fica como reforço para
    // o que não está no mapa, que é o caso de app aberto e não favorito.
    property var mapaIcones: ({})

    FileView {
        id: arqMapa
        path: Quickshell.env("HOME") + "/.local/share/rice/dock-icons/mapa.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { raiz.mapaIcones = JSON.parse(arqMapa.text()) }
            catch (e) { raiz.mapaIcones = ({}) }
        }
        // Ausente antes de alguém rodar o gerador. Não é erro: cai no
        // iconPath e segue.
        onLoadFailed: raiz.mapaIcones = ({})
    }

    // ── A lista ─────────────────────────────────────────────────
    //
    // Um appId por aplicativo, na ordem em que o compositor entrega — que
    // é estável o bastante para os ícones não dançarem a cada foco.
    //
    // `appId` vazio é descartado: janela sem identidade não tem ícone nem
    // nome para mostrar, e um quadrado anônimo na barra só gera dúvida.
    //
    // ── OS DOIS MODOS (`tarefasModo` no pill.json) ──────────────
    //
    // "todos"  a régua inteira. É uma barra de tarefas: dá para VER o que
    //          está aberto sem invocar nada, e clicar direto em qualquer
    //          app. Em troca, a cápsula muda de largura toda vez que um
    //          app abre ou fecha — e ela é centralizada, então os módulos
    //          da direita escorregam junto.
    //
    // "foco"   só o app em evidência. A cápsula fica com largura estável e
    //          o módulo vira INDICADOR em vez de comutador: some o alcance
    //          de clicar em outro app, que passa a depender do dock ou do
    //          teclado. O menu do botão direito continua servindo — mas só
    //          para as janelas de quem está na frente.
    //
    // O que decide é para que serve a cápsula neste rice, e isso não é
    // questão técnica. Os dois estão prontos; o pill.json escolhe.
    readonly property var apps: {
        const vistos = {}
        const saida = []
        for (const t of ToplevelManager.toplevels.values) {
            const id = t.appId ?? ""
            if (id === "" || vistos[id]) continue
            vistos[id] = true
            saida.push(id)
        }

        if (PraxeConfig.tarefasModo !== "foco") return saida

        // No modo foco, a lista é o app em evidência — e só ele.
        //
        // Filtrar a lista já montada, em vez de ler `emFoco` direto, não é
        // rodeio: garante que o id devolvido é um que EXISTE na lista de
        // janelas. O `activeToplevel` pode apontar para algo que já saiu
        // (janela fechando, foco em trânsito), e um id fantasma aqui daria
        // um ícone que não abre menu nenhum.
        const foco = raiz.emFoco
        return saida.indexOf(foco) >= 0 ? [foco] : []
    }

    // O appId em foco, para marcar qual está na frente. Também string, e
    // pelo mesmo motivo de cima.
    readonly property string emFoco: ToplevelManager.activeToplevel?.appId ?? ""

    // Todas as janelas de um app, na ordem do compositor.
    //
    // Devolve os objetos vivos, e por isso o retorno NUNCA vai para um
    // model — é consumido na hora, dentro da função que chamou. Ler
    // `toplevels.values` aqui dentro é leitura de propriedade, que o QML
    // rastreia mesmo através da chamada de função: bindings que dependem
    // disto acompanham janelas abrindo e fechando sozinhos.
    function janelasDe(id) {
        const alvo = (id ?? "").toLowerCase()
        const saida = []
        for (const t of ToplevelManager.toplevels.values)
            if ((t.appId ?? "").toLowerCase() === alvo) saida.push(t)
        return saida
    }

    function janelaDe(id) {
        const js = janelasDe(id)
        return js.length > 0 ? js[0] : null
    }

    // Mesma resolução do Dock: heurística primeiro, id exato como reforço.
    // `byId` exige o nome EXATO do arquivo .desktop, e o appId que a
    // janela informa quase nunca bate (caixa diferente, sufixo a mais).
    function entradaDe(id) {
        raiz.revApps
        if (!id) return null
        return DesktopEntries.heuristicLookup(id) ?? DesktopEntries.byId(id) ?? null
    }

    function nomeDe(id) {
        const e = entradaDe(id)
        return e ? e.name : id
    }

    function caminhoIconeDe(id) {
        raiz.revIcones
        if (!id) return ""
        // `file://` NÃO é enfeite. O `Quickshell.iconPath` devolve uma URL
        // de provedor (`image://icon/kitty`), e o mapa devolve caminho de
        // sistema cru — que o IconImage não carrega sem esquema. Foi o que
        // fez todos os ícones do dock sumirem de uma vez.
        const doMapa = raiz.mapaIcones[id]
        if (doMapa) return "file://" + doMapa
        const e = entradaDe(id)
        const nome = e ? e.icon : id
        return nome ? Quickshell.iconPath(nome, true) : ""
    }

    // ── Clique esquerdo: trazer à frente, e CICLAR ──────────────
    //
    // Só `activate()` na primeira janela seria uma meia-ação para quem
    // tem três do mesmo app: o clique pareceria não fazer nada, porque a
    // que já estava na frente é a que voltaria à frente.
    //
    // Se o app JÁ está em foco, o clique avança para a próxima janela
    // dele. É o comportamento que o dock do macOS e o do Windows têm, e o
    // único que faz um ícone só dar conta de várias janelas.
    function acionar(id) {
        const js = raiz.janelasDe(id)
        if (js.length === 0) return

        let atual = -1
        for (let i = 0; i < js.length; i++)
            if (js[i].activated) { atual = i; break }

        js[atual < 0 ? 0 : (atual + 1) % js.length].activate()
    }

    RowLayout {
        id: fileira
        anchors.centerIn: parent
        spacing: Math.round(6 * Theme.scale)

        Repeater {
            model: raiz.apps

            delegate: Item {
                id: item
                required property string modelData

                readonly property bool ativo: modelData === raiz.emFoco
                readonly property int quantas: raiz.janelasDe(modelData).length

                // Sem a caixa de realce, a folga lateral que existia para
                // ela não tem mais função — e mantida deixaria os ícones
                // longe demais uns dos outros para se lerem como um grupo.
                implicitWidth: raiz.tamIcone + Math.round(4 * Theme.scale)
                implicitHeight: raiz.tamIcone + raiz.faixaMarca
                Layout.alignment: Qt.AlignVCenter

                // ── O ÍCONE, COM O TRATAMENTO DO DOCK ───────
                //
                // Exatamente o mesmo tratamento dos ícones do dock —
                // tinta, saturação e brilho vindos do PraxeConfig, onde a
                // fórmula mora. Quem configura é o painel de aparência DO
                // DOCK; a cápsula copia e não ganha controles próprios.
                //
                // O motivo de copiar em vez de inventar: os dois ficam na
                // mesma tela ao mesmo tempo. Dois tratamentos diferentes
                // para o ícone do MESMO aplicativo, um embaixo e outro em
                // cima, é a coisa que mais denuncia interface montada por
                // partes — e nenhum ajuste de gosto conserta, porque o
                // problema é a divergência, não o valor.
                //
                // Era isto que faltava: ícone de app vem saturado de
                // fábrica (é o trabalho dele, chamar atenção numa grade de
                // lançador), e numa cápsula que é toda texto e traço numa
                // cor só, três logotipos coloridos eram a única coisa
                // gritando. O dock já tinha resolvido esse problema.
                //
                // Sem caixa de realce atrás e sem pontinhos: eram dois
                // desenhos para dizer duas coisas ("é o da frente",
                // "tem N janelas") que um traço só diz — ver abaixo.
                Item {
                    id: icone
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: raiz.tamIcone
                    height: raiz.tamIcone

                    readonly property bool destacado:
                        item.ativo || menu.idApp === item.modelData

                    IconImage {
                        id: fonteIcone
                        anchors.fill: parent
                        implicitSize: raiz.tamIcone
                        source: raiz.caminhoIconeDe(item.modelData)
                        // Quem aparece é o efeito. A fonte fica fora da
                        // tela — se ficasse visível, o ícone original
                        // seria desenhado por baixo do tratado e a cor
                        // vazaria pelas bordas do alfa.
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: fonteIcone
                        visible: fonteIcone.source != ""

                        // As quatro linhas do dock, sem uma vírgula de
                        // diferença. Ver PraxeConfig: `tintaIcones` e
                        // `corTintaIcones` mexem na MATIZ; `satIcones` e
                        // `brilhoIcones` tiram cor e encostam no papel.
                        colorization: PraxeConfig.tintaIcones
                        colorizationColor: PraxeConfig.corTintaIcones
                        saturation: PraxeConfig.satIcones
                        brightness: PraxeConfig.brilhoIcones

                        // O FOCO NÃO MEXE NA TINTA, e isso é de propósito.
                        //
                        // Trocar a cor do ícone em foco quebraria o que o
                        // bloco acima acabou de garantir: seriam dois
                        // tratamentos diferentes de novo, agora dentro da
                        // própria fileira. O dock resolve igual — o ícone é
                        // sempre o mesmo, quem marca o foco é o marcador
                        // separado. Aqui é o traço logo abaixo.
                        //
                        // Sobra a opacidade, em três degraus. Três e não
                        // dois porque o hover precisa de um lugar entre
                        // "em foco" e "existe": sem ele o ponteiro não dá
                        // retorno nenhum, e o ícone vira um alvo que não
                        // responde.
                        opacity: icone.destacado ? 1.0
                               : sonda.hovered   ? 0.80
                                                 : 0.45

                        Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                        Behavior on colorization { NumberAnimation { duration: Theme.animPadrao ; easing.type: Theme.curva } }
                        Behavior on colorizationColor { ColorAnimation { duration: Theme.animLento } }
                        Behavior on saturation { NumberAnimation { duration: Theme.animPadrao ; easing.type: Theme.curva } }
                        Behavior on brightness { NumberAnimation { duration: Theme.animPadrao ; easing.type: Theme.curva } }
                    }

                    // `iconPath` com `true` devolve string VAZIA quando o
                    // tema não tem o ícone — não um placeholder. Sem esta
                    // saída fica um buraco do tamanho do ícone, que se lê
                    // como barra quebrada. A inicial pelo menos identifica
                    // o app, e já nasce na cor certa.
                    Text {
                        anchors.centerIn: parent
                        visible: fonteIcone.source == ""
                        text: (item.modelData.charAt(0) || "?").toUpperCase()
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(raiz.tamIcone * 0.62)
                        font.bold: true
                        // Na cor da tinta, como o dock faz com a dele —
                        // com a tinta desligada cai no papel.
                        color: PraxeConfig.tintaIcones > 0 ? PraxeConfig.corTintaIcones
                                                           : PraxeConfig.colFg
                        opacity: icone.destacado ? 1.0 : (sonda.hovered ? 0.80 : 0.45)
                        Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                        Behavior on color { ColorAnimation { duration: Theme.animCor } }
                    }
                }

                // ── O traço: foco E quantidade, num desenho só ──
                //
                // Antes eram duas peças: caixa de acento para "é o da
                // frente" e uma fileira de pontos para "tem N janelas".
                // Duas linguagens visuais para duas informações do mesmo
                // ícone é o que fazia a fileira parecer cheia — e a caixa,
                // sendo a maior coisa desenhada ali, virava o assunto.
                //
                // O traço diz as duas: a COR diz se está em foco, o
                // COMPRIMENTO diz quantas janelas. Ele existe sempre, mas
                // fora do foco fica em `muted` bem apagado — presente para
                // quem procura, invisível para quem não.
                //
                // Comprimento com teto em três janelas. Quem tem oito do
                // navegador não ganha nada com um traço da largura do
                // ícone; ganha com "são várias", que três degraus já dizem.
                // O número exato está no menu do botão direito.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    height: Math.max(1, Math.round(2 * Theme.scale))
                    radius: height / 2

                    width: Math.round((4 + 4 * (Math.min(item.quantas, 3) - 1)) * Theme.scale)

                    color: icone.destacado ? PraxeConfig.colAccent : PraxeConfig.colMuted
                    opacity: icone.destacado ? 1.0 : 0.30

                    Behavior on width   { NumberAnimation { duration: Theme.animPadrao ; easing.type: Theme.curva } }
                    Behavior on color   { ColorAnimation  { duration: Theme.animCor } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                }

                // HoverHandler e não MouseArea — a nota do `rastreador` no
                // shell.qml explica: MouseArea engole o hover da barra, a
                // carência corre e a barra se fecha debaixo do ponteiro.
                HoverHandler {
                    id: sonda
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: raiz.acionar(item.modelData)
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: menu.abrir(item.modelData,
                                         item.mapToItem(raiz, item.width / 2, 0).x)
                }

                // SEM legenda ao passar o mouse, e é omissão consciente. O
                // `Balao.qml` é o balão de NOTIFICAÇÃO, não um tooltip, e a
                // legenda do Dock é interna a ele. Inventar um terceiro
                // mecanismo de legenda daria três jeitos diferentes de
                // mostrar a mesma coisa no mesmo rice. Quem quer o nome do
                // app e o título das janelas tem o botão direito, que
                // mostra os dois de uma vez e ainda deixa agir.
            }
        }
    }

    // ── O menu do botão direito ─────────────────────────────────
    //
    // `PopupWindow`, e não um Rectangle dentro da cápsula: a cápsula tem
    // 34px de altura e recorta o que passa dela. Uma lista de janelas
    // dentro dali seria invisível.
    //
    // Também não vai pelo `painelHost` do shell.qml. Aquilo é o
    // hospedeiro dos QUATRO PAINÉIS grandes — abrir um menu de contexto
    // por ali significaria a cápsula inteira virar painel, animação de
    // 320ms e foco exclusivo de teclado, para mostrar três linhas de
    // texto. Superfície própria é mais barata e não mexe no estado da
    // barra.
    PopupWindow {
        id: menu

        // Qual app o menu está mostrando. Vazio = fechado. É string pelo
        // mesmo motivo do resto do arquivo: guardar o `Toplevel` aqui é o
        // ponteiro cru que derruba o shell quando a janela fecha com o
        // menu aberto — o que é o caso NORMAL de uso deste menu.
        property string idApp: ""

        // Onde o menu se alinha, em coordenadas da fileira. Guardado no
        // instante do clique: o ícone pode sumir da fileira enquanto o
        // menu está aberto (a última janela fechou), e um binding vivo
        // apontaria para um delegate morto.
        property real ancoraX: 0

        function abrir(id, x) {
            if (menu.idApp === id) { menu.fechar(); return }
            menu.idApp = id
            menu.ancoraX = x
            menu.visible = true
        }

        function fechar() {
            menu.visible = false
            menu.idApp = ""
        }

        // As janelas do app, em `{ titulo, indice }` — dois valores
        // simples. Ver a regra das strings no cabeçalho: o objeto fica de
        // fora, e é reencontrado no clique.
        readonly property var janelas: {
            if (menu.idApp === "") return []
            const saida = []
            const js = raiz.janelasDe(menu.idApp)
            for (let i = 0; i < js.length; i++)
                saida.push({ titulo: js[i].title ?? "", indice: i })
            return saida
        }

        // Reencontra a janela do item clicado.
        //
        // Pelo índice, MAS conferindo o título: entre abrir o menu e
        // clicar, uma janela pode ter fechado e as de baixo subido um
        // lugar. Índice sozinho fecharia a janela errada — e fechar a
        // janela errada é perda de trabalho, não um pixel torto.
        //
        // Sem correspondência, não faz nada. Melhor um clique sem efeito
        // do que um acerto no alvo errado.
        function janelaDoItem(indice, titulo) {
            const js = raiz.janelasDe(menu.idApp)
            if (indice < js.length && (js[indice].title ?? "") === titulo)
                return js[indice]
            for (const t of js)
                if ((t.title ?? "") === titulo) return t
            return null
        }

        // O menu se fecha sozinho quando o app fecha a última janela: sem
        // isto ele fica na tela listando nada, e o único jeito de sair
        // seria clicar fora.
        onJanelasChanged: if (menu.visible && menu.janelas.length === 0) menu.fechar()

        anchor.item: raiz
        anchor.rect.x: Math.round(menu.ancoraX - menu.implicitWidth / 2)
        anchor.rect.y: PraxeConfig.atTop ? raiz.height + Math.round(14 * Theme.scale)
                                         : -Math.round(14 * Theme.scale)
        anchor.rect.width: menu.implicitWidth
        anchor.rect.height: 1
        anchor.edges: PraxeConfig.atTop ? Edges.Bottom : Edges.Top
        anchor.gravity: PraxeConfig.atTop ? Edges.Bottom : Edges.Top
        // Escorrega em X para não sangrar pela borda da tela. Menu cortado
        // no canto é pior que menu fora do lugar — a mesma regra que o
        // `painelHost` do shell.qml segue com o `sideMargin`.
        anchor.adjustment: PopupAdjustment.SlideX

        implicitWidth: Math.round(280 * Theme.scale)
        implicitHeight: corpo.implicitHeight
        color: "transparent"

        // SEM `grabFocus`, e isto não é esquecimento.
        //
        // `grabFocus: true` pede ao Wayland um POPUP COM GRAB, e o
        // protocolo só concede isso com um serial de input recente da
        // superfície-mãe. Quando não há, o compositor recusa e o popup
        // não é criado — sem erro em QML, só duas linhas no log do
        // Quickshell:
        //   "Failed to create grabbing popup. Ensure popup has a
        //    transientParent set and that parent window has received input"
        //   "Cannot attach popup ... as the popup is not an xdg_popup"
        // e o menu simplesmente nunca aparece.
        //
        // O clique direito FORNECE esse serial, então com grabFocus o
        // menu até abriria no uso normal. Mas ele deixaria de abrir por
        // qualquer outro caminho (IPC, atalho, teste), e um menu que
        // funciona só quando o mouse o invoca é uma armadilha para o
        // próximo que mexer aqui. Quem fecha ao clicar fora é o
        // HyprlandFocusGrab logo abaixo, que não depende de serial.

        // ── Fechar ao clicar fora ───────────────────────────
        //
        // O grab NÃO pode ser armado no mesmo instante em que o menu
        // abre: ele avalia o foco antes de o compositor entregá-lo à nova
        // superfície, conclui que ninguém está focado e dispara `cleared`
        // na hora — o menu fechava antes de aparecer. É o mesmo atraso
        // que o painel da barra usa, e pelo mesmo motivo.
        property bool grabArmado: false

        onVisibleChanged: {
            if (menu.visible) armaGrab.restart()
            else { armaGrab.stop(); menu.grabArmado = false; menu.idApp = "" }
        }

        Timer {
            id: armaGrab
            interval: 300
            onTriggered: menu.grabArmado = true
        }

        HyprlandFocusGrab {
            windows: [menu]
            active: menu.visible && menu.grabArmado
            onCleared: menu.fechar()
        }

        Rectangle {
            id: corpo
            anchors.fill: parent
            implicitHeight: coluna.implicitHeight + Math.round(12 * Theme.scale)
            radius: Theme.raioG
            color: PraxeConfig.colBgPainel
            border.width: 1
            border.color: PraxeConfig.colBorder

            // SEM tratador de Esc: sem `grabFocus` este popup não recebe
            // teclado, então um `Keys.onEscapePressed` aqui seria código
            // morto que o próximo leitor tomaria por funcionalidade. Quem
            // fecha é o clique fora (HyprlandFocusGrab), o clique numa
            // janela da lista, ou o botão direito de novo no mesmo ícone.

            Column {
                id: coluna
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Math.round(6 * Theme.scale)
                spacing: Math.round(2 * Theme.scale)

                // ── Cabeçalho: nome do app e contagem ───────
                //
                // O nome vem do .desktop, não do appId: "Zen Browser" e
                // não "zen". O appId é identidade de máquina; quem lê o
                // menu quer o nome que viu no lançador.
                Item {
                    width: parent.width
                    height: Math.round(26 * Theme.scale)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(8 * Theme.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Math.round(48 * Theme.scale)
                        text: raiz.nomeDe(menu.idApp)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        color: PraxeConfig.colFg
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(8 * Theme.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: menu.janelas.length
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: PraxeConfig.colMuted
                    }
                }

                // Fronteira por RESPIRO seria o certo se isto fosse a
                // cápsula, onde a nota do `Sep` manda evitar traço. Aqui é
                // o contrário: dentro de um recipiente pequeno, a linha
                // separa o cabeçalho da lista sem gastar altura, e altura
                // é o que este menu não tem de sobra.
                Rectangle {
                    width: parent.width - Math.round(12 * Theme.scale)
                    x: Math.round(6 * Theme.scale)
                    height: 1
                    color: PraxeConfig.colBorder
                }

                Item { width: 1; height: Math.round(3 * Theme.scale) }

                // ── Uma linha por janela ────────────────────
                Repeater {
                    model: menu.janelas

                    delegate: Item {
                        id: linha
                        required property var modelData

                        readonly property string titulo: modelData.titulo
                        readonly property int indice: modelData.indice

                        width: coluna.width
                        height: Math.round(28 * Theme.scale)

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.raioP
                            color: PraxeConfig.colFg
                            opacity: sondaLinha.hovered ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(8 * Theme.scale)
                            anchors.right: fecharUm.left
                            anchors.rightMargin: Math.round(4 * Theme.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            // Janela sem título existe (splash, diálogo que
                            // ainda não nomeou nada). Uma linha em branco
                            // parece defeito; "sem título" parece o que é.
                            text: linha.titulo !== "" ? linha.titulo : "sem título"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.italic: linha.titulo === ""
                            color: PraxeConfig.colFg
                            opacity: linha.titulo !== "" ? 0.92 : 0.55
                        }

                        HoverHandler { id: sondaLinha ; cursorShape: Qt.PointingHandCursor }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                const j = menu.janelaDoItem(linha.indice, linha.titulo)
                                if (j) j.activate()
                                menu.fechar()
                            }
                        }

                        // ── O ✕ de cada janela ──────────────
                        //
                        // Só aparece com o ponteiro na linha. Um ✕
                        // permanente por linha é uma coluna de alvos
                        // destrutivos sempre à mostra, e a chance de
                        // acertar um sem querer cresce com a quantidade de
                        // janelas — exatamente quando a lista fica longa.
                        Item {
                            id: fecharUm
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(4 * Theme.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(20 * Theme.scale)
                            height: width

                            opacity: sondaLinha.hovered || sondaX.hovered ? 1 : 0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.err
                                opacity: sondaX.hovered ? 0.22 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(10 * Theme.scale)
                                color: sondaX.hovered ? Theme.err : PraxeConfig.colMuted
                                Behavior on color { ColorAnimation { duration: Theme.animRapido } }
                            }

                            HoverHandler { id: sondaX ; cursorShape: Qt.PointingHandCursor }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    const j = menu.janelaDoItem(linha.indice, linha.titulo)
                                    // `close()` é o pedido educado do
                                    // protocolo: o app recebe o mesmo evento
                                    // do botão de fechar dele e pode salvar,
                                    // perguntar, recusar. Não é kill.
                                    if (j) j.close()
                                    // O menu FICA ABERTO: fechar três de
                                    // cinco janelas é uma sequência, e um
                                    // menu que se fecha a cada clique
                                    // obriga a reabrir e reencontrar o
                                    // ícone entre cada uma. Ele se fecha
                                    // sozinho quando a lista esvazia.
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: Math.round(3 * Theme.scale) }

                Rectangle {
                    width: parent.width - Math.round(12 * Theme.scale)
                    x: Math.round(6 * Theme.scale)
                    height: 1
                    color: PraxeConfig.colBorder
                    visible: menu.janelas.length > 1
                }

                // ── Fechar todas ────────────────────────────
                //
                // Só com mais de uma janela. Com uma só ele seria um
                // segundo botão para o mesmo efeito do ✕ da linha, e dois
                // caminhos para a mesma ação no mesmo menu é o que faz
                // menu parecer improvisado.
                Item {
                    width: coluna.width
                    height: Math.round(28 * Theme.scale)
                    visible: menu.janelas.length > 1

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.raioP
                        color: Theme.err
                        opacity: sondaTodas.hovered ? 0.16 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animRapido ; easing.type: Theme.curva } }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(8 * Theme.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Fechar todas (" + menu.janelas.length + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: sondaTodas.hovered ? Theme.err : PraxeConfig.colMuted
                        Behavior on color { ColorAnimation { duration: Theme.animRapido } }
                    }

                    HoverHandler { id: sondaTodas ; cursorShape: Qt.PointingHandCursor }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            // A lista é copiada ANTES do laço. `close()`
                            // remove a janela do ToplevelManager, e iterar
                            // a coleção viva enquanto ela encolhe pula
                            // itens — sobrariam janelas abertas depois de
                            // "fechar todas", que é pior que não ter o
                            // botão.
                            const js = raiz.janelasDe(menu.idApp).slice()
                            for (const t of js) t.close()
                            menu.fechar()
                        }
                    }
                }
            }
        }
    }
}
