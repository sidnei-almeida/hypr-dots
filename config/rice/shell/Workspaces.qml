// Áreas de trabalho como DÍGITOS. A ativa ganha uma cápsula de acento
// apertada em volta do número — a própria linguagem da barra se repetindo
// lá dentro, no menor tamanho em que ela ainda se lê.
//
// ── POR QUE SAIU O PONTO ────────────────────────────────────────
//
// A régua era de pontos, com a ativa virando uma pill alongada e sem
// número. Funcionava e era discreta, mas dizia uma coisa só: "você está
// na terceira posição". Para saber QUAL área é a terceira era preciso
// contar — e contar é exatamente o trabalho que um indicador existe para
// poupar.
//
// O dígito diz posição e identidade no mesmo espaço, porque o número é o
// nome da área. Cinco dígitos de 9px ocupam praticamente a mesma largura
// que cinco pontos de 7px com as folgas que eles precisavam.
//
// A altura CAIU: a pill da ativa tinha 15px quando carregava número, e
// agora a fileira inteira tem ~14 e nada mais salta dela.
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
    // Espaçamento PRÓPRIO, menor que o `Theme.itemGap` que separa os
    // módulos da cápsula.
    //
    // O itemGap (7px) foi calibrado para separar coisas diferentes — o
    // relógio do volume, o logo das áreas. Entre dígitos da MESMA régua
    // ele é folga demais: com a folga interna de cada item somando mais
    // 4, davam 11px de vão entre glífos de 9px, e a régua deixava de ler
    // como uma coisa só para virar cinco números soltos.
    //
    // Proximidade é o que agrupa. Ver a nota do `Sep` no shell.qml, que
    // é o mesmo raciocínio um nível acima.
    rowSpacing: Math.round(2 * Theme.scale)
    columnSpacing: Math.round(2 * Theme.scale)

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

        delegate: Item {
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

            // Descontinuidade em relação ao item anterior — é onde o
            // traço de salto entra. Só acontece acima do teto.
            readonly property bool salto: index > 0
                                          && root.lista[index - 1] !== wsId - 1

            Layout.alignment: Qt.AlignCenter
            Layout.leftMargin: (!PraxeConfig.vertical && salto) ? root.folgaSalto : 0
            Layout.topMargin:  (PraxeConfig.vertical && salto)  ? root.folgaSalto : 0

            // ── A GEOMETRIA SAI DO DÍGITO ───────────────────────
            //
            // Nada de largura cravada: "10" é mais largo que "3" e ficaria
            // cortado numa caixa de tamanho fixo. Foi por isso que a pill
            // antiga já media o texto — a diferença é que agora TODOS
            // medem, não só a ativa.
            //
            // Duas folgas, e é só isso que separa ativa de inativa:
            //
            //   ativa    folga larga, porque a cápsula precisa de ar em
            //            volta do dígito para ler como cápsula e não como
            //            um retângulo encostado no número.
            //
            //   inativa  folga estreita, só o bastante para os dígitos não
            //            se tocarem. Não há nada desenhado ali para dar ar.
            //
            // A ALTURA É A MESMA PARA TODOS, e é o que faz a fileira ser
            // uma linha reta em vez de ter um caroço no meio. Era esse o
            // defeito do desenho anterior, quando a pill com número tinha
            // o dobro da altura dos pontos.
            readonly property int folgaH: Math.round((isActive ? 9 : 4) * Theme.scale)

            Layout.preferredWidth:  Math.round(numero.implicitWidth) + folgaH
            Layout.preferredHeight: Math.round(numero.implicitHeight)
                                  + Math.round(4 * Theme.scale)

            // Mesmo tempo da cápsula que os contém. Ver Theme.animForma.
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.animForma; easing.type: Easing.OutCubic }
            }

            // ── A cápsula da ativa ──────────────────────────────
            //
            // Só a ativa tem forma. Dar contorno às inativas encheria a
            // régua de cinco caixas e trocaria uma linha de números por
            // uma fileira de botões — que é outro desenho de barra, e o
            // mais pesado dos três que se considerou.
            //
            // `radius: height / 2` e não um raio do Theme: cápsula é
            // definição de forma, não escolha de estilo. É a mesma regra
            // que o `isPill` da barra segue.
            Rectangle {
                id: capsula
                anchors.fill: parent
                radius: height / 2
                color: PraxeConfig.colAccent

                // Pelo `opacity` daqui, e não do `dot`: o Item de fora usa
                // opacity para a animação de ENTRADA, e dois
                // interceptadores na mesma propriedade não se somam — o
                // QML avisa "another interceptor... unsupported" e ignora
                // um deles, sem deixar claro qual. A nota original sobre
                // isso está na entrada, lá embaixo.
                opacity: dot.isActive ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: Theme.animForma ; easing.type: Theme.curva } }
                Behavior on color   { ColorAnimation  { duration: Theme.animForma } }
            }

            // ── O número ────────────────────────────────────────
            //
            // Na ativa, a cor sai da LUMINÂNCIA do acento, não do tema: o
            // acento é escolhido a partir do papel de parede e tanto pode
            // ser um dourado claro quanto um vinho escuro. Cravar "texto
            // escuro" daria número invisível na metade dos temas.
            //
            // Fora dela, DOIS pesos do mesmo `muted`, e não muted contra
            // dim como os pontos usavam. O `colDim` foi calibrado para um
            // ponto sólido de 7px; um glífo de 9px com hastes de 1px
            // simplesmente desaparece nele. Área vazia continua sendo mais
            // apagada que área com janela — o que muda é que agora as duas
            // se leem.
            Text {
                id: numero
                anchors.centerIn: parent
                text: dot.wsId
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(9, Theme.fontSize - 3)
                font.weight: dot.isActive ? Font.DemiBold : Font.Normal

                color: {
                    if (dot.isActive)
                        return (0.299 * PraxeConfig.colAccent.r
                              + 0.587 * PraxeConfig.colAccent.g
                              + 0.114 * PraxeConfig.colAccent.b) > 0.5
                               ? PraxeConfig.colBgPuro : PraxeConfig.colFg
                    const c = PraxeConfig.colMuted
                    return Qt.rgba(c.r, c.g, c.b, dot.hasWindows ? 0.9 : 0.4)
                }

                Behavior on color { ColorAnimation { duration: Theme.animForma } }
            }

            // ── Traço de salto ──────────────────────────────────
            //
            // Marca que a numeração pulou (área 11 logo depois da 10, por
            // exemplo). Com dígitos ele importa menos que importava com
            // pontos — o número já denuncia o pulo — mas continua sendo o
            // que separa "12 vem depois de 10" de "12 é vizinha de 10".
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

            // Entrada suave.
            //
            // Com a fileira dinâmica, uma área pode nascer a qualquer
            // momento — basta ir para uma nova. Aparecer pronta, no
            // tamanho final, lê como falha de desenho; aparecer crescendo
            // lê como "surgiu agora", que é o que aconteceu. Vale também
            // para a subida da barra, em que a fileira inteira se monta.
            //
            // Valor literal e não binding: nada mais escreve nestes dois,
            // então não há binding a ser quebrado pela atribuição.
            // SEM overshoot, e é a metade do conserto do "shaky".
            //
            // Era `Easing.OutBack`, que por definição passa do alvo e volta.
            // Num item que nasce uma vez isso é charme; aqui não é: o
            // Hyprland DESTRÓI área vazia, então trocar de área destrói e
            // recria itens o tempo todo, e cada um renascia quicando. A
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
            Behavior on opacity { NumberAnimation { duration: Theme.animForma ; easing.type: Theme.curva } }
            Behavior on scale {
                NumberAnimation { duration: Theme.animForma; easing.type: Easing.OutCubic }
            }

            // Cursor no HoverHandler, não no MouseArea — ver a nota no
            // Resources.qml. Aqui pesa em dobro: são vários itens, cada
            // um seria um ladrão de hover.
            HoverHandler { cursorShape: Qt.PointingHandCursor }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6          // alvo de clique maior que o dígito
                // Serve igual para área fantasma: o dispatcher cria a
                // área que não existe, exatamente como a tecla faria.
                onClicked: Hyprland.dispatch(
                    "hl.dsp.focus({ workspace = " + dot.wsId + " })")
            }
        }
    }
}
