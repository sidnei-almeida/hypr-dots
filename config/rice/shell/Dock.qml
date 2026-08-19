// ┌──────────────────────────────────────────────────────────────┐
// │  PraXe OS — o dock.                                           │
// └──────────────────────────────────────────────────────────────┘
//
// Favoritos fixos à esquerda, aplicativos abertos no meio, lixeira na
// ponta direita — cada grupo separado por um traço. Some sozinho e volta
// quando o mouse encosta na borda de baixo: a ideia é ter os apps à mão
// sem gastar tela com eles.
//
// Ajustes em ~/.config/rice/pill.json:
//   dock            "off" | "always" | "hover"
//   dockFavoritos   ["zen-browser", "kitty", ...]  (id do .desktop)
//   dockTamanho     lado do ícone, em px
//   dockTinta       0..100, quanto os ícones puxam para a cor do tema
//   dockLixeira     mostra ou esconde a lixeira
//
// Botão direito num ícone fixa ou solta o favorito. Na lixeira, botão
// direito esvazia (com confirmação).
//
// Por que ToplevelManager e não Hyprland.clients: o protocolo
// foreign-toplevel já entrega appId, título, foco e activate() prontos,
// e não depende de ficar consultando o compositor por IPC.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: dock

    // ── Revisão dos ícones ──────────────────────────────────────
    //
    // `Quickshell.iconPath()` é uma FUNÇÃO, não uma propriedade: o
    // resultado dela depende do tema de ícones em vigor, e o QML não tem
    // como saber que esse tema mudou. O binding que guarda o caminho só
    // reavalia quando o NOME do ícone muda — e o nome nunca muda.
    //
    // Na prática: bastava uma troca de tema para o dock ficar com
    // caminhos apontando para arquivos que não existiam mais, ou com
    // string vazia, até o Quickshell ser reiniciado. Era metade do "os
    // ícones somem".
    //
    // Este contador é a dependência que faltava. Quem mexe em ícone o
    // incrementa, e todo caminho de ícone é reconsultado.
    property int revIcones: 0

    // O index.theme do PraXe é reescrito a cada `rice-folders`, que roda
    // a cada troca de tema. Observar o arquivo cobre a recoloração de
    // pasta sem precisar que ninguém avise a barra.
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/icons/PraXe/index.theme"
        watchChanges: true
        onFileChanged: dock.revIcones++
        // Sem `blockLoading`: aqui não há valor a ler, só o sinal de que
        // o arquivo mudou. Bloquear a subida por isso seria desperdício.
    }

    // ── Mapa de ícones já resolvidos ────────────────────────────
    //
    // Escrito pelo rice-dock-icones, que faz a busca fora do QML e deixa
    // um caminho de arquivo pronto para cada favorito. É a fonte
    // PREFERIDA; o `Quickshell.iconPath` continua como reforço para o que
    // não estiver no mapa (apps abertos que não são favoritos).
    //
    // A busca saiu do QML porque ali ela falhava de quatro maneiras
    // diferentes — nome que o tema não tem, caixa diferente, ícone só em
    // /usr/share/pixmaps, e a corrida com a reconstrução do tema. O
    // cabeçalho do rice-dock-icones detalha cada uma.
    property var mapaIcones: ({})

    FileView {
        id: arqMapa
        path: Quickshell.env("HOME") + "/.local/share/rice/dock-icons/mapa.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { dock.mapaIcones = JSON.parse(arqMapa.text()) }
            catch (e) { dock.mapaIcones = ({}) }
        }
        // Ausente na primeira execução, antes de alguém rodar o gerador.
        // Não é erro: o dock cai no iconPath e segue.
        onLoadFailed: dock.mapaIcones = ({})
    }

    // E o tema BASE pode mudar sem o PraXe ser tocado — é o caso de quem
    // escolhe Tela ou Kora no painel. `iconTheme` do pill.json é
    // reativo, então basta ouvi-lo.
    Connections {
        target: PraxeConfig
        function onIconThemeChanged() { dock.revIcones++ }
    }

    readonly property bool ligado: PraxeConfig.dock !== "off"
    readonly property bool porHover: PraxeConfig.dock === "hover"
    readonly property int lado: Math.round(PraxeConfig.dockTamanho * Theme.scale)
    readonly property int respiro: Math.round(8 * Theme.scale)
    readonly property int alturaBarra: lado + respiro * 2

    // A faixa de captura vive FORA da barra visível: é ela que percebe o
    // mouse chegando na borda de baixo quando o dock está escondido.
    readonly property int faixa: Math.round(4 * Theme.scale)
    readonly property int folga: Math.round(14 * Theme.scale)

    // Teto reservado ao balão do nome.
    //
    // ISTO É O QUE CONSERTA O BUG DO HOVER. Antes o balão era filho do
    // ícone e ancorado ao topo dele, mas a janela só tinha `folga` (14px)
    // de sobra acima da cápsula: o balão nascia em y NEGATIVO e a borda da
    // superfície o cortava. Nada no log acusava — a superfície simplesmente
    // não tem onde desenhar.
    readonly property int alturaDica: Math.round(34 * Theme.scale)

    property bool mouseEmCima: false
    readonly property bool aberto: !porHover || mouseEmCima

    // ── Tinta dos ícones ────────────────────────────────────────
    //
    // Quanto os ícones puxam para uma cor só, para o dock parecer um
    // conjunto em vez de uma prateleira de logotipos alheios.
    //
    // A CONTA MUDOU DE CASA: mora no PraxeConfig, junto com a adequação,
    // porque a fileira de apps abertos da cápsula (Tarefas.qml) usa
    // exatamente o mesmo tratamento. Duas cópias da fórmula é como o dock
    // e a cápsula acabariam com ícones diferentes na mesma tela depois de
    // alguém mexer num preset. Os controles continuam sendo os do dock —
    // é ele quem configura, a cápsula só copia.
    //
    // Estes dois nomes ficam como atalho local: são lidos em uma dúzia de
    // pontos deste arquivo, e trocar todos por `PraxeConfig.` só deixaria
    // as linhas mais longas.
    readonly property real  forcaTinta: PraxeConfig.tintaIcones
    readonly property color corTinta:   PraxeConfig.corTintaIcones

    // ── Adequação ao tema ────────────────────────────────────────────
    //
    // Coisa DIFERENTE da tinta, e a confusão entre as duas é fácil de
    // repetir: a tinta troca a MATIZ, a adequação tira COR e encosta o
    // ícone no papel. A fórmula, os presets e o porquê de os dois eixos
    // escalarem juntos estão no PraxeConfig, ao lado da tinta — pelo mesmo
    // motivo: a cápsula usa o mesmo tratamento.
    readonly property real satIcone:    PraxeConfig.satIcones
    readonly property real brilhoIcone: PraxeConfig.brilhoIcones

    visible: ligado
    screen: Quickshell.screens[0] ?? null

    anchors { bottom: true; left: true; right: true }
    // Altura fixa: a superfície não pode redimensionar junto com a
    // animação, senão o compositor deixa rastro de buffer — foi o que
    // aconteceu com a island quando ela crescia junto com o painel.
    implicitHeight: alturaDica + folga * 2 + alturaBarra
    exclusiveZone: 0        // flutua; não rouba espaço das janelas
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "praxe-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Só a cápsula e a faixa da borda recebem clique. Sem isto o dock
    // engoliria toda a faixa de baixo da tela, inclusive o que estiver
    // atrás dele. Region exige `item:` — coordenadas soltas no próprio
    // Region são ignoradas em silêncio.
    //
    // A máscara é a UNIÃO das duas, sempre, e não uma que troca conforme
    // o estado. Trocar quebra: aberto, a máscara viraria só a cápsula, o
    // cursor parado na borda de baixo ficaria fora dela, o dock fecharia,
    // a máscara voltaria a incluir a borda, abriria de novo — piscando
    // sem parar enquanto o mouse estivesse no canto.
    //
    // O balão do nome NÃO entra aqui de propósito: máscara é região de
    // ENTRADA, não de desenho. Incluí-lo faria o balão engolir cliques
    // destinados à janela atrás dele.
    // ATENÇÃO: geometria por BINDING (x/y/width/height), e NÃO por `item:`.
    //
    // Era `Region { item: corpo }`, e essa é a causa de "não consigo
    // clicar nos ícones, o cursor nem vira mãozinha".
    //
    // O `corpo` ANIMA: fechado ele fica em `dock.height - 3` (um fio de
    // 3px no rodapé) e sobe até a posição aberta com Behavior on y. A
    // forma `item:` amostra a geometria do item quando o item é
    // atribuído — e não volta a olhar quando ele se move. A máscara
    // ficava congelada na posição FECHADA, ou seja, num fio de 3px
    // colado na borda de baixo.
    //
    // O resultado enganava: a faixa de captura é estática, então passar o
    // mouse no rodapé continuava abrindo o dock normalmente. Ele aparecia
    // inteiro, com os ícones certos — e nenhum evento chegava a eles,
    // porque a região de entrada tinha ficado lá embaixo. Sem entrada,
    // nem o HoverHandler roda: por isso o cursor não mudava de forma,
    // que é o detalhe que denuncia o problema como sendo de MÁSCARA e
    // não de clique.
    //
    // As propriedades x/y/width/height do Region têm sinal de mudança
    // próprio, então o binding refaz a região a cada quadro da animação.
    //
    // A união continua sempre ativa (faixa + corpo), e não trocando
    // conforme o estado — ver o comentário acima sobre o piscar.
    mask: Region {
        x: 0
        y: dock.height - dock.faixa
        width: dock.width
        height: dock.faixa

        Region {
            intersection: Intersection.Combine
            x: corpo.x
            y: corpo.y
            width: corpo.width
            height: corpo.height
        }
    }

    Item {
        id: faixaCaptura
        y: dock.height - dock.faixa
        width: dock.width
        height: dock.faixa
    }

    // ── Revisão da lista de aplicativos ─────────────────────────
    //
    // MESMA ARMADILHA do `revIcones` logo acima, e ela custou o dock
    // inteiro: `DesktopEntries.heuristicLookup()` é um MÉTODO, não uma
    // leitura de propriedade. O QML só registra dependência no que ele vê
    // ser LIDO durante a avaliação do binding — a chamada de um método
    // C++ não registra nada.
    //
    // Isso só não seria problema se a lista estivesse pronta na subida.
    // Ela não está: o Quickshell varre os .desktop de forma ASSÍNCRONA e
    // preguiçosa, e a varredura só começa no primeiro acesso. Na prática o
    // binding de `favoritos` rodava com a lista AINDA VAZIA, `entrada`
    // saía null para todo mundo, e nada jamais mandava reavaliar.
    //
    // O sintoma era exatamente "o dock não abre os aplicativos, só mostra
    // os que já estão abertos": sem `entrada` não há `execute()`, então o
    // clique só conseguia fazer a outra metade do trabalho — `activate()`
    // numa janela que já existisse.
    //
    // Este contador é a dependência que faltava, no mesmo molde do
    // `revIcones`. Quem depende de .desktop lê `revApps` e reavalia quando
    // a varredura assenta.
    property int revApps: 0

    // O `applicationsChanged` dispara UMA VEZ POR ENTRADA encontrada — são
    // mais de cem na subida. Reagir a cada uma refaria os favoritos cem
    // vezes e re-incubaria os delegates junto, que é justamente o
    // caminho de código onde o Quickshell estava morrendo.
    //
    // O timer engole a rajada e avisa uma vez só, quando ela para.
    Timer {
        id: assentarApps
        interval: 120
        onTriggered: dock.revApps++
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { assentarApps.restart() }
    }

    // ── Favoritos e janelas ─────────────────────────────────────
    //
    // Um app aparece uma vez só: se está nos favoritos E aberto, quem
    // manda é o favorito, que só ganha o ponto de "rodando".
    // byId exige o id EXATO do arquivo .desktop; o appId que a janela
    // informa quase nunca bate (caixa diferente, sufixo a mais). O
    // heuristicLookup existe para esse caso — é ele que deve vir
    // primeiro, com o byId só como reforço.
    function acharEntrada(id) {
        if (!id) return null
        return DesktopEntries.heuristicLookup(id) ?? DesktopEntries.byId(id) ?? null
    }

    // ── Por que estas listas são de STRINGS, e não de objetos ───
    //
    // ISTO É O QUE CONSERTA O CRASH DO QUICKSHELL. Não simplifique de
    // volta para um objeto por item.
    //
    // Antes cada item era um mapa `{ id, entrada, favorito, janela }`,
    // onde `entrada` era um DesktopEntry* e `janela` um Toplevel* — dois
    // PONTEIROS de objeto guardados dentro de um mapa comum, e esse mapa
    // era o model do Repeater.
    //
    // Um mapa desses não segura o objeto vivo: não é uma referência
    // contada, é um ponteiro cru. E o Repeater não constrói o delegate na
    // hora — ele INCUBA, ou seja, adia a construção para os quadros
    // seguintes. Entre montar a lista e o delegate nascer, o objeto pode
    // ter morrido: uma janela que fecha, ou um .desktop reescrito no meio
    // da varredura (que é o normal — entradas duplicadas são substituídas
    // enquanto ela roda).
    //
    // Quando isso acontecia, o Qt tentava converter o mapa para JS e
    // esbarrava no ponteiro morto. É EXATAMENTE o backtrace do coredump:
    //   QQmlVMEMetaObject::writeKnownVarProperty
    //     -> VariantAssociationPrototype::fromQVariantMap
    //       -> ExecutionEngine::fromData        <- SIGSEGV aqui
    // partindo de um QQmlIncubator, ou seja, do delegate sendo incubado.
    //
    // String não aponta para nada e não morre. O delegate resolve o objeto
    // por conta própria, num binding que reavalia sozinho quando o objeto
    // troca — que é o lugar certo para essa resolução morar.
    readonly property var favoritos: PraxeConfig.dockFavoritos

    readonly property var abertos: {
        const ids = PraxeConfig.dockFavoritos.map(s => s.toLowerCase())
        const vistos = {}
        const saida = []
        for (const t of ToplevelManager.toplevels.values) {
            const app = (t.appId ?? "").toLowerCase()
            if (app === "" || vistos[app]) continue
            if (ids.indexOf(app) >= 0) continue
            vistos[app] = true
            saida.push(t.appId)
        }
        return saida
    }

    function rodando(id) {
        const alvoId = (id ?? "").toLowerCase()
        for (const t of ToplevelManager.toplevels.values)
            if ((t.appId ?? "").toLowerCase() === alvoId) return t
        return null
    }

    // Aberto já? traz para a frente. Senão, lança.
    //
    // O `execute()` do DesktopEntry é o caminho bom: ele respeita
    // Terminal=, campos de ação e desanexa o processo do shell. Só que ele
    // depende de ter achado a entrada — e um id de favorito pode
    // simplesmente não ter .desktop nenhum (nome errado no pill.json, app
    // desinstalado).
    //
    // Antes o clique nesse caso não fazia NADA, em silêncio. Cair no
    // `gio launch`/binário de mesmo nome não conserta o id errado, mas
    // troca "o dock está quebrado" por "esse ícone abre mesmo assim", e o
    // aviso no log diz qual id revisar.
    function acionar(id) {
        if (!id) return
        const t = rodando(id)
        if (t) { t.activate(); return }

        const entrada = acharEntrada(id)
        if (entrada) { entrada.execute(); return }

        console.warn("dock: sem .desktop para", id, "— tentando lançar direto")
        Quickshell.execDetached(["sh", "-c",
            "command -v " + id + " >/dev/null 2>&1 && exec " + id
            + " || exec gio launch /usr/share/applications/" + id + ".desktop"])
    }

    // Sem `Process`: fixar/soltar é disparar e esquecer — ninguém aqui lê a
    // saída nem espera o fim. Um Process ainda em `running` (o rice-dock
    // regenera os ícones, então não é instantâneo) descartaria em silêncio o
    // clique seguinte. Ver a nota longa no ControlCenter.qml.
    function alternarFavorito(id) {
        if (!id) return
        Quickshell.execDetached([PraxeConfig.bin + "rice-dock", "alternar", id])
    }

    // ── Lixeira ─────────────────────────────────────────────────
    //
    // A contagem é sondada, e não observada por FileView: um diretório
    // sob observação dispara evento para cada arquivo mexido, e esvaziar
    // uma lixeira cheia viraria uma rajada de recargas. De quatro em
    // quatro segundos, e só enquanto o dock está aberto, é o bastante —
    // ninguém olha para a lixeira com ela fora da tela.
    property int lixoQtd: 0

    // O ícone da lixeira é NOSSO, não do tema de ícones.
    //
    // O Qt desta máquina não resolve ícones de contexto `places`/`status`:
    // `user-trash`, `user-trash-full`, `folder-trash`, `edit-delete` e
    // companhia voltam TODOS vazios do iconPath, enquanto `kitty` e
    // `firefox` — que moram em hicolor/apps — resolvem sem problema. Por
    // isso o slot aparecia vazio, e por isso trocar o nome do ícone não
    // resolveria: nenhum nome de lixeira funciona aqui.
    //
    // O SVG próprio segue o mesmo caminho já provado pelo símbolo do Arch
    // no shell.qml: arquivo branco + MultiEffect para a cor. Não depende
    // de tema de ícones nenhum e acompanha a paleta de graça.
    readonly property string lixoIcone:
        "file://" + Quickshell.env("HOME") + "/.config/rice/assets/"
        + (lixoQtd > 0 ? "trash-full.svg" : "trash.svg")

    readonly property string lixoRotulo:
        lixoQtd === 0 ? Idioma.t("dock.trash.empty")
                      : Idioma.t("dock.trash") + " · " + lixoQtd + " "
                          + Idioma.t(lixoQtd === 1 ? "dock.trash.item" : "dock.trash.items")

    Process {
        id: contarLixo
        command: [PraxeConfig.bin + "rice-trash", "contar"]
        stdout: StdioCollector {
            onStreamFinished: dock.lixoQtd = parseInt(text.trim()) || 0
        }
    }

    Process { id: acaoLixo }

    function lixeiraAbrir() {
        acaoLixo.command = [PraxeConfig.bin + "rice-trash", "abrir"]
        acaoLixo.running = true
    }

    // O esvaziar pede confirmação no fuzzel (ver rice-trash). Quando ele
    // termina, a contagem é relida — senão o ícone continuaria "cheio"
    // até a próxima sondagem.
    function lixeiraEsvaziar() {
        acaoLixo.command = [PraxeConfig.bin + "rice-trash", "esvaziar"]
        acaoLixo.running = true
    }

    Connections {
        target: acaoLixo
        function onExited() { contarLixo.running = true }
    }

    Timer {
        interval: 4000
        repeat: true
        running: dock.ligado && dock.aberto
        triggeredOnStart: true
        onTriggered: contarLixo.running = true
    }

    Component.onCompleted: contarLixo.running = true

    // ── Balão do nome ───────────────────────────────────────────
    //
    // UM balão só, filho da janela — não um por ícone.
    //
    // Um por ícone tinha dois defeitos além do corte pelo topo: os ícones
    // à direita são desenhados DEPOIS, então passavam por cima do balão
    // do vizinho; e cada balão aparecia do nada no lugar do outro. Com um
    // só, ele desliza de um ícone para o outro, que é o que dá o
    // acabamento de dock de sistema.
    property string dicaTexto: ""
    property real   dicaCentro: 0
    property bool   dicaVisivel: false

    function mostrarDica(alvo, texto) {
        if (!texto || !alvo) return
        // mapToItem não é reativo — por isso a conta roda na entrada do
        // mouse, e não como binding. Enquanto o ponteiro está parado num
        // ícone o layout não anda, então não há o que reavaliar.
        dock.dicaCentro = alvo.mapToItem(corpo.parent, alvo.width / 2, 0).x
        dock.dicaTexto = texto
        dock.dicaVisivel = true
    }

    // Só apaga se o dono do balão ainda for quem está saindo. Sem essa
    // guarda, varrer o mouse rápido pela fileira faz o `onExited` do
    // ícone anterior chegar DEPOIS do `onEntered` do seguinte e apagar
    // um balão que já não era dele — o nome pisca e some.
    function esconderDica(texto) {
        if (dock.dicaTexto === texto) dock.dicaVisivel = false
    }

    // ── Corpo ───────────────────────────────────────────────────
    Rectangle {
        id: corpo

        readonly property int larguraConteudo:
            linha.implicitWidth + dock.respiro * 2

        width: larguraConteudo
        height: dock.alturaBarra
        x: (dock.width - width) / 2
        // Escondido, desce até quase sumir; só a beirada fica de dica.
        y: dock.aberto ? dock.alturaDica + dock.folga
                       : dock.height - Math.round(3 * Theme.scale)

        radius: Theme.raioG
        color: PraxeConfig.colBgDock

        // SEM borda, e não é esquecimento.
        //
        // Havia aqui um contorno de 1px translúcido. Num retângulo
        // arredondado e escuro ele não lê como "linha": lê como um halo
        // macio em volta do dock, aquele ar aveludado de caixa recortada
        // e colada por cima da tela.
        //
        // A cápsula da barra passou pela mesma remoção e pelo mesmo
        // motivo (ver a nota sobre contorno no shell.qml). O que separa o
        // dock do papel de parede é o próprio fundo escuro; contorno é
        // convenção de interface, e este dock quer parecer objeto.
        border.width: 0

        opacity: dock.aberto ? 1 : 0
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 ; easing.type: Theme.curva } }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Havia aqui um "fio de luz" no topo: 1px branco a 6%, para simular
        // a quina pegando luz. Removido — em vez de sugerir volume, lia
        // como um risco horizontal atravessando a fileira de ícones, que é
        // exatamente o que o truque deveria evitar. Um dock sem contorno
        // combina melhor com a cápsula, que também perdeu a borda.

        RowLayout {
            id: linha
            anchors.centerIn: parent
            spacing: Math.round(6 * Theme.scale)

            Repeater {
                model: dock.favoritos
                delegate: Icone { required property var modelData; idApp: modelData }
            }

            Divisor { visible: dock.favoritos.length > 0 && dock.abertos.length > 0 }

            Repeater {
                model: dock.abertos
                delegate: Icone { required property var modelData; idApp: modelData }
            }

            Divisor {
                visible: PraxeConfig.dockLixeira
                         && (dock.favoritos.length > 0 || dock.abertos.length > 0)
            }

            Icone {
                ehLixeira: true
                visible: PraxeConfig.dockLixeira
            }

            // Sem nada fixado, sem nada aberto e sem lixeira, o dock
            // viraria uma cápsula vazia sem explicação. Um convite resolve.
            Text {
                visible: dock.favoritos.length === 0 && dock.abertos.length === 0
                         && !PraxeConfig.dockLixeira
                text: Idioma.t("dock.empty")
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
                leftPadding: Math.round(6 * Theme.scale)
                rightPadding: Math.round(6 * Theme.scale)
            }
        }
    }

    // O balão fica FORA da cápsula e depois dela na ordem de desenho, para
    // ficar por cima de tudo. z explícito porque a cápsula é irmã.
    Rectangle {
        id: dica
        z: 10

        readonly property bool mostrando:
            dock.dicaVisivel && dock.aberto && dock.dicaTexto !== ""
        readonly property int margemTela: Math.round(8 * Theme.scale)

        width: dicaTxt.width + Math.round(18 * Theme.scale)
        height: dicaTxt.implicitHeight + Math.round(9 * Theme.scale)
        radius: Theme.raioM
        color: PraxeConfig.colBgDock
        border.width: 1
        border.color: PraxeConfig.colBorder

        // Preso à tela: um app de nome comprido no primeiro ou no último
        // ícone sairia pela lateral e ficaria cortado.
        x: Math.max(margemTela,
             Math.min(dock.width - width - margemTela, dock.dicaCentro - width / 2))
        y: corpo.y - height - Math.round(9 * Theme.scale)

        opacity: mostrando ? 1 : 0
        visible: opacity > 0.01

        // Sobe 4px ao aparecer. Movimento curto e para cima lê como "isto
        // pertence ao ícone de baixo"; aparecer parado lê como pop-up.
        transform: Translate {
            y: dica.mostrando ? 0 : Math.round(4 * Theme.scale)
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: 140 ; easing.type: Theme.curva } }
        Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        Text {
            id: dicaTxt
            anchors.centerIn: parent
            text: dock.dicaTexto
            color: PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
            // Teto de largura: nome de janela pode vir com o documento
            // inteiro junto, e um balão de 2000px não ajuda ninguém.
            width: Math.min(implicitWidth, Math.round(340 * Theme.scale))
        }
    }

    // A máscara já restringe a entrada de eventos à região de `alvo`
    // (a faixa da borda quando escondido, a cápsula quando aberto).
    // Logo, "o ponteiro está no dock?" é exatamente containsMouse — não
    // é preciso comparar coordenadas à mão.
    //
    // Comparar coordenadas foi a primeira tentativa e não funcionou: com
    // o ponteiro TELEPORTADO para a borda (o que um `movecursor` faz),
    // não há movimento dentro da área e o onPositionChanged nunca dispara.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            dock.mouseEmCima = containsMouse
            if (!containsMouse) dock.dicaVisivel = false
        }
    }

    // ── Traço divisor ───────────────────────────────────────────
    component Divisor: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: Math.round(dock.lado * 0.55)
        Layout.leftMargin: Math.round(3 * Theme.scale)
        Layout.rightMargin: Math.round(3 * Theme.scale)
        color: PraxeConfig.colDim
    }

    // ── Um ícone ────────────────────────────────────────────────
    component Icone: Item {
        id: ic
        // Só o id, nunca o objeto — ver a nota sobre o crash em `favoritos`.
        property string idApp: ""
        property bool ehLixeira: false

        // A entrada é resolvida AQUI, e não na lista.
        //
        // `revApps` é lido de propósito na primeira linha: é ele que faz
        // este binding reavaliar quando a varredura dos .desktop termina.
        // Sem essa leitura o `heuristicLookup` roda uma vez, com a lista
        // vazia, e o ícone fica sem nome e sem como abrir para sempre.
        // Não apague por parecer inútil — ela é o conserto.
        readonly property var entrada: {
            dock.revApps
            return (ehLixeira || idApp === "") ? null : dock.acharEntrada(idApp)
        }

        // `dock.rodando` lê `ToplevelManager.toplevels.values` por dentro,
        // e leitura de propriedade o QML rastreia mesmo através da chamada
        // de função — então este binding acompanha janelas que abrem e
        // fecham sozinho. (É a chamada de MÉTODO C++ que não rastreia, que
        // é o caso do heuristicLookup acima.)
        readonly property var janela:
            (!ehLixeira && idApp !== "") ? dock.rodando(idApp) : null
        readonly property bool ativo: ic.janela !== null
        readonly property bool focado: ic.janela ? ic.janela.activated : false

        readonly property string rotulo:
            ehLixeira ? dock.lixoRotulo
                      : (ic.entrada ? ic.entrada.name : ic.idApp)

        readonly property string nomeIcone:
            ehLixeira ? "" : (ic.entrada ? ic.entrada.icon : ic.idApp)

        // iconPath com `true` devolve string VAZIA quando o tema não tem
        // o ícone — não um placeholder. Guardar o resultado é o que
        // permite cair na inicial em vez de desenhar um buraco.
        //
        // A leitura de `dock.revIcones` na primeira linha existe SÓ para
        // criar dependência: sem ela este binding nunca reavaliaria após
        // uma troca de tema, porque `Quickshell.iconPath` é função e o
        // `nomeIcone` não muda. Ver a nota sobre `revIcones` lá em cima.
        // Não apague por parecer inútil — ela é o conserto.
        readonly property string caminhoIcone: {
            dock.revIcones
            if (ehLixeira || ic.idApp === "") return ""
            // O mapa vem primeiro: ele já foi resolvido no disco, com
            // preferência por contexto `apps`, variante escura e vetor.
            //
            // `file://` NÃO é enfeite. O `Quickshell.iconPath` devolve
            // uma URL de provedor de imagem — `image://icon/kitty` — e
            // não um caminho de arquivo. Quem consome isto é um
            // IconImage, que espera URL. Entregar `/home/.../kitty.svg`
            // cru fez TODOS os ícones do dock sumirem de uma vez, porque
            // o caminho sem esquema não é carregável.
            const doMapa = dock.mapaIcones[ic.idApp]
            if (doMapa) return "file://" + doMapa
            return nomeIcone ? Quickshell.iconPath(nomeIcone, true) : ""
        }
        readonly property bool temIcone: caminhoIcone !== ""

        Layout.preferredWidth: dock.lado
        Layout.preferredHeight: dock.lado

        // ── Geometria da célula ─────────────────────────────────
        //
        // A célula se divide em duas faixas: a de cima é do ícone, a de
        // baixo é do marcador de "rodando". O realce mora só na de cima.
        //
        // Antes o realce preenchia a célula INTEIRA e o ícone subia 3px
        // para abrir espaço ao marcador — então o ícone ficava fora do
        // centro do próprio realce, e era isso que dava o ar torto. Além
        // disso, preenchendo borda a borda com apenas 6px entre vizinhos,
        // dois realces lado a lado quase se encostavam e o quadrado não
        // parecia caber no dock.
        //
        // Tirando a faixa do marcador da conta, o realce volta a ser um
        // QUADRADO de verdade, centrado no ícone, e sobra margem entre um
        // e outro.
        readonly property int faixaMarca: Math.round(9 * Theme.scale)
        readonly property int ladoRealce: dock.lado - faixaMarca

        // O realce NÃO sai direto do `containsMouse`.
        //
        // Ao clicar, o ponteiro costuma sumir sem aviso: o app abre por
        // cima do dock, ou o dock se esconde, e o `leave` nunca é
        // entregue. O `containsMouse` fica preso em true e o ícone
        // continua elevado para sempre — era esse o bug.
        //
        // É a mesma família do que travava a barra: estado de hover que
        // depende de um evento de saída que pode não vir. A saída é a
        // mesma: não confiar num sinal só.
        //
        // Um clique suprime o realce; qualquer movimento real do ponteiro
        // sobre o ícone o traz de volta. Assim o ícone desce ao abrir o
        // app e sobe de novo se você voltar para cima dele, sem depender
        // de um `leave` que talvez nunca chegue.
        property bool suprimeRealce: false
        readonly property bool realce: areaIc.containsMouse && !suprimeRealce

        // CENTRADA na célula, e não grudada no topo.
        //
        // Estava `anchors.top: parent.top` com altura `lado - faixaMarca`.
        // Como a faixa do marcador é 9px, o ícone acabava com o centro 4.5px
        // ACIMA do centro da célula — e como a célula já é centrada no corpo
        // do dock, esses 4.5px viravam desalinhamento visível: a fileira
        // inteira parecia flutuar alto dentro da barra.
        //
        // O marcador de "rodando" não precisa da faixa reservada para si:
        // ele tem 2px de altura e é ancorado ao fundo da CÉLULA, não desta
        // zona. Com a zona centrada sobra 4.5px embaixo, mais que suficiente
        // — e o 1px em que ele encosta na quina do realce só existe durante
        // o hover, a 9% de opacidade.
        Item {
            id: zonaIcone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: ic.ladoRealce

            // Realce do hover. Confirma o alvo do clique — sem ele, o
            // ícone cresce mas não fica claro onde começa e termina a
            // área clicável.
            Rectangle {
                anchors.centerIn: parent
                width: ic.ladoRealce
                height: ic.ladoRealce
                radius: Math.round(width * 0.3)
                color: PraxeConfig.colFg
                opacity: ic.realce ? 0.09 : 0
                Behavior on opacity { NumberAnimation { duration: 140 ; easing.type: Theme.curva } }
            }

            Item {
                id: alvoIcone
                anchors.centerIn: parent
                // 0.62 e não 0.66: dentro de um realce de 35px o ícone de 29
                // encostava nas quinas. Em 27 sobra respiro dos dois lados,
                // inclusive com o hover crescendo para 1.14.
                width: Math.round(dock.lado * 0.62)
                height: width
    
                // Cresce e sobe no hover, a partir do CENTRO. Escala e
                // translação são de graça no GPU; mexer em width dispararia o
                // layout inteiro a cada quadro e arrastaria os vizinhos junto.
                //
                // 1.14 e não 1.18: com o fundo de hover atrás, o ícone grande
                // demais encosta na borda do próprio realce e fica apertado.
                scale: ic.realce ? 1.14 : 1.0
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    
                transform: Translate {
                    y: ic.realce ? -Math.round(3 * Theme.scale) : 0
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
    
                // Ícone do aplicativo, vindo do tema de ícones.
                IconImage {
                    id: img
                    anchors.fill: parent
                    source: ic.caminhoIcone
                    visible: false          // quem aparece é o efeito
                }
    
                // Ícone da lixeira, vindo dos nossos assets. Ver dock.lixoIcone.
                Image {
                    id: imgLixo
                    anchors.fill: parent
                    source: ic.ehLixeira ? dock.lixoIcone : ""
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: false
                }
    
                // Tinta do tema.
                //
                // O MultiEffect puxa a MATIZ para a cor escolhida preservando a
                // LUMINÂNCIA, então o desenho do ícone continua legível — não
                // vira silhueta chapada. É o que faz uma pasta azul e um globo
                // verde conviverem no mesmo dock sem parecerem colados ali de
                // fora. Em 0 o efeito é passagem limpa, e por isso não há
                // ramificação: o caminho é sempre o mesmo.
                //
                // A lixeira é caso à parte: o SVG é branco e só existe para ser
                // colorido, então ela vai sempre em 1.0. Com a tinta desligada
                // ela cai no papel (colFg), que é o cinza-claro de sistema.
                MultiEffect {
                    anchors.fill: parent
                    source: ic.ehLixeira ? imgLixo : img
                    visible: ic.ehLixeira || ic.temIcone
    
                    colorization: ic.ehLixeira ? 1.0 : dock.forcaTinta
                    colorizationColor: (ic.ehLixeira && dock.forcaTinta === 0)
                                       ? PraxeConfig.colFg : dock.corTinta
    
                    // Adequação ao tema. Ver a nota em `satIcone`: estes
                    // dois eixos é que escurecem e tiram cor — a tinta
                    // acima só troca matiz.
                    saturation: dock.satIcone
                    brightness: dock.brilhoIcone

                    Behavior on colorization { NumberAnimation { duration: 220 ; easing.type: Theme.curva } }
                    Behavior on colorizationColor { ColorAnimation { duration: 320 } }
                    Behavior on saturation { NumberAnimation { duration: 220 ; easing.type: Theme.curva } }
                    Behavior on brightness { NumberAnimation { duration: 220 ; easing.type: Theme.curva } }
                }
    
                // Último recurso: a inicial do nome.
                //
                // Existe porque um ícone que não resolve some sem deixar
                // rastro — foi exatamente o que aconteceu com a lixeira, e
                // levou uma investigação inteira para descobrir que o slot
                // não estava vazio, estava invisível. Com a inicial, o app
                // continua clicável e o problema fica à vista.
                Rectangle {
                    anchors.fill: parent
                    visible: !ic.ehLixeira && !ic.temIcone
                    radius: Math.round(width * 0.28)
                    color: Qt.rgba(dock.corTinta.r, dock.corTinta.g, dock.corTinta.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(dock.corTinta.r, dock.corTinta.g, dock.corTinta.b, 0.4)
    
                    Text {
                        anchors.centerIn: parent
                        text: ic.rotulo ? ic.rotulo.charAt(0).toUpperCase() : "?"
                        color: dock.corTinta
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(parent.height * 0.5)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Marca de "rodando": um ponto embaixo. Vira traço quando é a
        // janela em foco. Acento marca, não preenche.
        //
        // Fica CENTRADO na faixa que sobrou embaixo do realce — daí a
        // margem ser metade do que sobra, e não um valor solto. Encostado
        // na borda da célula ele parecia sobra de layout.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((ic.faixaMarca - height) / 2)
            visible: ic.ativo

            // Bem menor que antes (era 12x3 em foco, 3x3 fora).
            //
            // É informação periférica: você olha para o ÍCONE e percebe a
            // marca de canto de olho. No tamanho anterior ela competia com
            // o próprio ícone pela atenção, e num dock de poucos itens uma
            // fileira de traços grossos vira o elemento dominante.
            width: ic.focado ? Math.round(8 * Theme.scale) : Math.round(2 * Theme.scale)
            height: Math.round(2 * Theme.scale)
            radius: height / 2

            // Segue a tinta do dock, e não o acento do tema.
            //
            // A marca é acabamento do dock, então acompanha a cor que VOCÊ
            // escolheu para ele — se o dock está tingido de âmbar, a marca é
            // âmbar; trocou, ela troca junto. Antes eram duas cores fixas do
            // tema e a marca destoava de um dock tingido.
            //
            // Foco e não-foco se distinguem pela OPACIDADE, e não por duas
            // cores diferentes: mantém a família cromática e deixa a
            // diferença ser de ênfase, que é o que ela significa.
            color: ic.focado ? dock.corTinta
                             : Qt.rgba(dock.corTinta.r, dock.corTinta.g,
                                       dock.corTinta.b, 0.45)
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: areaIc
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: dock.mostrarDica(ic, ic.rotulo)
            onExited: {
                ic.suprimeRealce = false
                dock.esconderDica(ic.rotulo)
            }

            // Movimento real do ponteiro sobre o ícone desfaz a supressão.
            // É o que devolve a elevação quando você volta ao dock depois
            // de abrir um app, sem precisar do `leave` que não veio.
            onPositionChanged: ic.suprimeRealce = false

            onClicked: mouse => {
                ic.suprimeRealce = true
                if (ic.ehLixeira) {
                    if (mouse.button === Qt.RightButton) dock.lixeiraEsvaziar()
                    else dock.lixeiraAbrir()
                    return
                }
                if (mouse.button === Qt.RightButton) dock.alternarFavorito(ic.idApp)
                else dock.acionar(ic.idApp)
            }
        }

        // O rótulo da lixeira muda sozinho quando a contagem muda. Se ela
        // mudar com o ponteiro parado em cima, o balão precisa acompanhar
        // — senão fica mostrando "3 itens" numa lixeira já vazia.
        onRotuloChanged: if (areaIc.containsMouse) dock.mostrarDica(ic, ic.rotulo)
    }
}
