// Áreas de trabalho como pontos. A ativa vira uma pill alongada —
// é a própria linguagem da barra se repetindo lá dentro.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// GridLayout com `flow` variável: os mesmos pontos servem para a barra
// deitada e para a em pé, sem duplicar o Repeater.
GridLayout {
    id: root
    flow: PraxeConfig.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    columns: PraxeConfig.vertical ? 1 : -1
    rows:    PraxeConfig.vertical ? -1 : 1
    rowSpacing: Theme.itemGap
    columnSpacing: Theme.itemGap

    // Piso, não teto: `PraxeConfig.workspaces` diz quantos pontos ficam
    // SEMPRE à vista, mesmo vazios. Acima disso a fileira acompanha o
    // Hyprland.
    //
    // No modo BARRA o piso sobe para o teto: as dez áreas aparecem sempre.
    //
    // O piso existe porque na CÁPSULA cada ponto custa largura, e ela é
    // curta por definição — mostrar dez pontos quando só três existem seria
    // gastar o espaço mais disputado do rice com buraco. Numa barra de
    // 3440px esse argumento não existe: sobra espaço, e o mapa completo vale
    // mais que a economia. Com as dez à vista, SUPER+7 deixa de ser um salto
    // às cegas — o destino já estava na tela antes de você apertar.
    property int minimo: PraxeConfig.layout === "bar" && !PraxeConfig.vertical
                         ? teto
                         : PraxeConfig.workspaces

    // Até onde a régua é CONTÍGUA. Dez porque é o alcance do teclado:
    // SUPER+1 a SUPER+0 vão exatamente até a área 10, então essa é a
    // faixa que a pessoa navega às cegas e sobre a qual precisa ter um
    // mapa completo. Passando disso, desenhar todos os buracos custaria
    // uma fileira enorme para representar áreas que ninguém alcança
    // sem passar por aqui de propósito.
    readonly property int teto: 10

    // Folga extra antes de um ponto que não é o sucessor do anterior.
    // É ela que abre espaço para o traço de salto.
    readonly property int folgaSalto: Math.round(9 * Theme.scale)

    // ── Quais áreas mostrar ─────────────────────────────────────
    //
    // O Hyprland cria área de trabalho por demanda e não tem limite: as
    // teclas vão até SUPER+0 (área 10) e o SUPER+TAB passa disso. Aqui a
    // fileira era `model: PraxeConfig.workspaces`, um número fixo, com o
    // id saindo de `index + 1` — cinco pontos, sempre 1 a 5.
    //
    // Depois passou a ser a união do piso com as áreas existentes, o que
    // resolveu o sumiço mas criou um problema pior: como o Hyprland
    // destrói área vazia, ir para a 6, a 8 ou a 12 dava sempre a MESMA
    // figura — cinco pontos e a pill acesa em sexto lugar. A posição
    // parou de dizer qual área é, que é a única coisa que a fileira
    // existe para dizer.
    //
    // Agora a régua é CONTÍGUA: de 1 até a maior área em uso dentro do
    // teto (nunca menos que o piso). Os pontos das áreas que ainda não
    // existem entram como fantasmas — apagados, mas clicáveis, porque um
    // ponto desenhado que não responde é pior que ponto nenhum, e clicar
    // nele faz o mesmo que SUPER+n: o Hyprland cria a área na hora.
    //
    // Áreas acima do teto entram avulsas no fim, separadas por um traço.
    // Ordenada por número, senão a ordem seria a de criação e os pontos
    // dançariam de lugar.
    //
    // id > 0 descarta as áreas ESPECIAIS (o scratchpad do SUPER+S vem com
    // id negativo). Elas não pertencem à régua: aparecem por cima da área
    // atual em vez de substituí-la, e um ponto para elas sugeriria uma
    // navegação que não existe.
    readonly property var lista: {
        const existentes = []
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0) existentes.push(w.id)

        // A área em foco pode ser recém-criada e ainda estar vazia — o
        // Hyprland já a considera ativa antes de ela ter qualquer janela.
        const foco = Hyprland.focusedWorkspace?.id ?? 0
        if (foco > 0) existentes.push(foco)

        // A régua vai até a maior área em uso que ainda cabe no teto.
        // Quem está na área 12 não estica a fileira até 12: a 12 aparece
        // avulsa depois do traço.
        let maiorNoTeto = 0
        for (const id of existentes)
            if (id <= root.teto && id > maiorNoTeto) maiorNoTeto = id

        const vistos = {}
        for (let i = 1; i <= Math.max(root.minimo, maiorNoTeto); i++) vistos[i] = true
        for (const id of existentes) vistos[id] = true
        return Object.keys(vistos).map(Number).sort((a, b) => a - b)
    }

    Repeater {
        // Números soltos, e não os objetos de área do Hyprland: um
        // ponteiro de objeto dentro do model derruba o Quickshell quando o
        // objeto morre antes de o delegate acabar de nascer — e área de
        // trabalho o Hyprland destrói sozinho assim que esvazia. A nota
        // longa sobre isso está no Dock.qml.
        model: root.lista

        delegate: Rectangle {
            id: dot
            required property int modelData
            required property int index

            readonly property int wsId: modelData
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
            readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsId
            // `ws` pode não existir e lastIpcObject pode vir vazio:
            // sem o === true isto vira `undefined` e o QML reclama.
            readonly property bool hasWindows: (ws?.lastIpcObject?.windows ?? 0) > 0

            // Fantasma: o ponto existe só para a numeração fechar. Vale
            // para a área que o Hyprland ainda não criou e também para a
            // que ele já destruiu por ter esvaziado.
            readonly property bool fantasma: !dot.ws

            // Descontinuidade em relação ao ponto anterior — é onde o
            // traço de salto entra. Só acontece acima do teto.
            readonly property bool salto: index > 0
                                          && root.lista[index - 1] !== wsId - 1

            Layout.alignment: Qt.AlignCenter
            Layout.leftMargin: (!PraxeConfig.vertical && salto) ? root.folgaSalto : 0
            Layout.topMargin:  (PraxeConfig.vertical && salto)  ? root.folgaSalto : 0

            // A ativa é uma pill com o número dentro; as outras são
            // pontos. O número só aparece na ativa porque é a única
            // informação que muda: saber que existe uma área 7 importa
            // menos do que saber que é NELA que você está. Numerar todas
            // trocaria a fileira de pontos por uma fileira de dígitos, que
            // é outro desenho de barra.
            //
            // A largura sai do texto e não de um número fixo: "12" é mais
            // largo que "8" e ficaria cortado numa pill de tamanho cravado.
            // ── Ponto menor no modo barra ────────────────────
            //
            // Na CÁPSULA os pontos são poucos (o piso costuma ser 5) e
            // dividem uma peça curta: ali eles precisam de corpo para serem
            // alvo de clique e para a fileira não sumir.
            //
            // Na BARRA são sempre DEZ, numa régua que agora ocupa um pedaço
            // visível do topo. O mesmo tamanho que ficava bem em cinco vira
            // peso demais em dez — a fileira passa a competir com o resto da
            // barra em vez de ser o pano de fundo dela.
            //
            // O que NÃO encolhe é o piso de forma da ativa: ele existe para
            // a pill continuar sendo alongada em vez de virar círculo, e um
            // dígito de ~10px precisa de altura para não ser cortado. Por
            // isso 14 e não 12.
            readonly property bool naBarra: PraxeConfig.layout === "bar" && !PraxeConfig.vertical

            // ── QUANDO O DÍGITO GANHA O ESPAÇO DELE ─────────────
            //
            // Só quando a POSIÇÃO MENTE, e ela mente num caso só.
            //
            // A régua é contígua de 1 até a maior área em uso dentro do
            // teto: o ponto na posição N é a área N, sempre. O dígito
            // resolvia a ambiguidade do desenho ANTIGO, em que a fileira
            // pulava números e ir para a 6, 8 ou 12 dava a mesma figura.
            // Com a régua contígua ele passou a repetir, dentro de uma
            // pill que custa o DOBRO da altura dos pontos, o que a posição
            // já dizia de graça. Era esse o caroço no meio da linha.
            //
            // Acima do teto a coisa muda: a área 12 aparece avulsa depois
            // do traço de salto, e ali a posição realmente não diz o
            // número. Aí o dígito é a única informação disponível e vale a
            // altura que cobra.
            //
            // Só na ATIVA: saber que existe uma área longínqua importa
            // menos do que saber que é nela que você está, e numerar todas
            // as avulsas traria de volta a fileira de dígitos.
            readonly property bool comNumero: isActive && wsId > root.teto

            // ── A ALTURA É A MESMA PARA TODOS. ──────────────────
            //
            // Era isto que fazia a fileira parecer grosseira: a área ativa
            // tinha 16px de altura contra 8px dos pontos, o dobro. Uma
            // fileira com um caroço no meio deixa de ser uma linha.
            //
            // O indicador ativo agora é mais LONGO, nunca mais alto — o
            // princípio do indicador de página do iOS. A régua continua
            // sendo uma linha reta e a ativa se lê pelo comprimento e pela
            // cor, que é informação de sobra.
            //
            // ── E o número sai no modo barra ────────────────────
            //
            // Ele existia porque o Hyprland destrói área vazia: sem as dez
            // sempre à vista, ir para a 6, 8 ou 12 dava a MESMA figura e a
            // posição deixava de significar o número.
            //
            // Em modo barra isso não vale mais: o piso subiu para o teto e a
            // régua é contígua de 1 a 10, então a posição já diz qual é. O
            // dígito passou a resolver um problema que não existe ali, ao
            // custo de dobrar a altura da peça inteira.
            //
            // Na CÁPSULA ele fica: lá a régua é curta e pode começar em
            // qualquer ponto, e sem o número a ambiguidade volta.
            Layout.preferredWidth: PraxeConfig.vertical
                ? Math.round((isActive ? 18 : 7) * Theme.scale)
                : (isActive
                     ? (comNumero
                          // Com dígito: piso de FORMA, para a pill de um
                          // dígito não virar círculo. Dois dígitos passam
                          // disso sozinhos.
                          ? Math.max(Math.round(22 * Theme.scale),
                                     Math.round(numero.implicitWidth + 11 * Theme.scale))
                          // Sem dígito: comprimento fixo, ~3x o ponto. É o
                          // indicador de página do iOS — mais LONGO, e a
                          // linha continua reta.
                          : Math.round((naBarra ? 20 : 22) * Theme.scale))
                     : Math.round((naBarra ? 6 : 7) * Theme.scale))
            Layout.preferredHeight: PraxeConfig.vertical
                ? (isActive ? Math.max(Math.round(22 * Theme.scale),
                                       Math.round(numero.implicitHeight + 8 * Theme.scale))
                            : Math.round(7 * Theme.scale))
                // MESMA ALTURA para ativo e inativo, nos dois modos. A
                // fileira é uma linha reta de ponta a ponta, e a ativa se lê
                // pelo comprimento e pela cor — informação de sobra. A
                // exceção é a pill que carrega dígito, que precisa de corpo
                // para o número caber; e ela só aparece acima do teto, onde
                // o traço de salto já quebrou a linha de qualquer forma.
                : (comNumero ? Math.round(15 * Theme.scale)
                             : Math.round((naBarra ? 6 : 7) * Theme.scale))
            radius: height / 2

            // Fantasma fica em DIM, a mesma cor da área existente e vazia:
            // as duas são, para quem olha, a mesma coisa — lugar sem nada.
            // Distingui-las com uma terceira cor seria informação sobre a
            // contabilidade interna do compositor, não sobre o trabalho.
            // Os inativos recuam pelo ALFA DA COR, não por `opacity`.
            //
            // A tentação era `opacity: isActive ? 1 : 0.45`, e ela quebra:
            // este mesmo retângulo já usa `opacity` para a animação de
            // ENTRADA (nasce em 0 e sobe no Component.onCompleted, lá
            // embaixo). Dois interceptadores na mesma propriedade não se
            // somam — o QML avisa "another interceptor... unsupported" e
            // ignora um deles, então ou a entrada ou o recuo deixaria de
            // funcionar, sem ficar claro qual.
            //
            // Pelo alfa não há conflito: é a cor, que já tem o seu próprio
            // Behavior logo abaixo, e as duas coisas convivem.
            color: {
                if (isActive) return PraxeConfig.colAccent
                const c = hasWindows ? PraxeConfig.colMuted : PraxeConfig.colDim
                return Qt.rgba(c.r, c.g, c.b, hasWindows ? 0.85 : 0.45)
            }

            // Mesmo tempo da cápsula que os contém. Ver Theme.animForma.
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animForma; easing.type: Easing.OutCubic }
            }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: Theme.animForma; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: Theme.animForma } }

            // ── O número da área ────────────────────────────────
            //
            // A cor sai da LUMINÂNCIA do acento, não do tema: o acento é
            // escolhido a partir do papel de parede e tanto pode ser um
            // dourado claro quanto um vinho escuro. Cravar "texto escuro"
            // daria número invisível na metade dos temas.
            Text {
                id: numero
                anchors.centerIn: parent
                text: dot.wsId
                color: (0.299 * PraxeConfig.colAccent.r
                      + 0.587 * PraxeConfig.colAccent.g
                      + 0.114 * PraxeConfig.colAccent.b) > 0.5
                       ? PraxeConfig.colBgPuro : PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(8, Theme.fontSize - 3)
                font.weight: Font.DemiBold

                // Some junto com a pill fechando. Sem o `visible` ele
                // continuaria compondo mesmo a zero, e são vários pontos.
                opacity: dot.comNumero ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            // ── Traço de salto ──────────────────────────────────
            //
            // Marca que a numeração pulou (área 11 logo depois da 10, por
            // exemplo). Sem ele a fileira mentiria: dois pontos vizinhos
            // sempre leem como áreas vizinhas.
            //
            // Posição por x/y e não por âncoras porque o sentido muda com
            // a barra em pé — e âncora atribuída não se desfaz (a nota
            // longa está no shell.qml). Fica no meio da folga que o
            // Layout.leftMargin/topMargin abriu.
            Rectangle {
                readonly property int folga: root.folgaSalto + Theme.itemGap
                visible: dot.salto
                // Menor que o `Sep` da barra de propósito: os dois são um
                // filete vertical em DIM, e no mesmo tamanho o salto lia
                // como fim de grupo — como se as áreas depois dele fossem
                // outro módulo, e não a mesma fileira.
                width:  PraxeConfig.vertical ? Math.round(6 * Theme.scale) : 1
                height: PraxeConfig.vertical ? 1 : Math.round(6 * Theme.scale)
                color: PraxeConfig.colDim
                opacity: 0.8
                x: PraxeConfig.vertical ? (dot.width - width) / 2
                                        : -folga / 2 - width / 2
                y: PraxeConfig.vertical ? -folga / 2 - height / 2
                                        : (dot.height - height) / 2
            }

            // Entrada suave do ponto.
            //
            // Com a fileira dinâmica, um ponto pode nascer a qualquer
            // momento — basta ir para uma área nova. Aparecer pronto, no
            // tamanho final, lê como falha de desenho; aparecer crescendo
            // lê como "surgiu agora", que é o que aconteceu. Vale também
            // para a subida da barra, em que a fileira inteira se monta.
            //
            // Valor literal e não binding: nada mais escreve nestes dois,
            // então não há binding a ser quebrado pela atribuição.
            // SEM overshoot, e é a metade do conserto do "shaky".
            //
            // Era `Easing.OutBack`, que por definição passa do alvo e volta.
            // Num ponto que nasce uma vez isso é charme; aqui não é: o
            // Hyprland DESTRÓI área vazia, então trocar de área destrói e
            // recria pontos o tempo todo, e cada um renascia quicando. A
            // fileira inteira parecia gelatina a cada troca.
            //
            // Coisa sólida não quica ao aparecer. Cresce e para.
            //
            // E a escala parte de 0.8, não de 0.6: um salto menor é menos
            // movimento para o olho registrar, e o que se quer comunicar é
            // "surgiu agora", não "olhe para mim".
            opacity: 0
            scale: 0.8
            Component.onCompleted: { opacity = 1; scale = 1 }
            Behavior on opacity { NumberAnimation { duration: Theme.animForma } }
            Behavior on scale {
                NumberAnimation { duration: Theme.animForma; easing.type: Easing.OutCubic }
            }

            // Cursor no HoverHandler, não no MouseArea — ver a nota no
            // Resources.qml. Aqui pesa em dobro: são vários pontos, cada
            // um seria um ladrão de hover.
            HoverHandler { cursorShape: Qt.PointingHandCursor }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6          // alvo de clique maior que o ponto
                // Serve igual para ponto fantasma: o dispatcher cria a
                // área que não existe, exatamente como a tecla faria.
                onClicked: Hyprland.dispatch(
                    "hl.dsp.focus({ workspace = " + dot.wsId + " })")
            }
        }
    }
}
