// Central de aparência: tema, fontes, superfície e ícones num lugar só.
//
// Mais um estado da island. Como o Theme observa o theme.json, o tema
// troca AO VIVO com o painel aberto — dá para ver o resultado sem fechar
// nada, que é o ponto de existir uma central.
//
// Dividido em abas porque virou grande demais para uma coluna só: quatro
// assuntos que não se misturam, e rolar 300px para chegar nos ícones
// seria pior que trocar de aba.
//
// Quem grava o quê:
//   rice-theme   tema (cores)
//   rice-set     fontes e tamanhos, em settings.sh
//   rice-pill    transparência e símbolos, em pill.json
//   rice-icons   tema de ícones, em GTK/Qt/gsettings
//   rice-folders cor das pastas

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property bool aberto: false
    signal fechar
    signal irParaPapeis

    opacity: aberto ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.aberto ? 130 : 0 }
            NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
        }
    }

    // Qual tema está com o apagar ARMADO, não um booleano.
    //
    // Guardar o slug e não um `true` resolve duas coisas de uma vez: só um
    // cartão pode estar armado por vez, e o estado sobrevive à reciclagem
    // do delegate — a GridView joga fora e reconstrói os itens ao rolar, e
    // um booleano dentro do cartão se perderia no meio da confirmação.
    property string apagandoTema: ""
    property int aba: 0     // 0 tema · 1 cores · 2 fontes · 3 sistema · 4 ícones

    // ── Dados ───────────────────────────────────────────────────
    property var temas: []
    property string temaAtual: ""

    property var fontesMono: []
    property var fontesProp: []
    property string fonte: "";      property int fonteTam: 12
    property string fonteTerm: "";  property int fonteTermTam: 9
    property string fonteApp: "";   property int fonteAppTam: 10

    property var icones: []
    property string iconeAtual: ""
    property var coresPasta: []

    // Recolorir pasta só é possível sobre o Papirus: as ~78 variantes
    // coloridas por tamanho (folder-teal.svg, folder-teal-documents.svg...)
    // são dele, e o rice-folders não pinta nada — apenas aponta para
    // arquivos que já existem. Sobre Tela, Kora ou qualquer outro tema
    // base não há o que apontar, e o seletor de cor abaixo seria um
    // punhado de botões sem efeito.
    //
    // "PraXe" conta como Papirus porque é o tema que o próprio
    // rice-folders gera, herdando dele.
    readonly property bool pastasRecoloriveis:
        iconeAtual === "" || iconeAtual === "PraXe"
        || iconeAtual === "Papirus" || iconeAtual === "Papirus-Dark"
        || iconeAtual === "Papirus-Light"

    property var lojaFontes: []
    property var lojaIcones: []
    property bool mostrarLojaFontes: false
    property bool mostrarLojaIcones: false

    property string papelAtual: ""

    // ── Editor de cores ─────────────────────────────────────────
    // paleta: { BG: "0a0a0a", ACCENT: "d4ab60", ... }
    property var paleta: ({})
    property string papelSel: "ACCENT"
    // Enquanto se arrasta, a cor vive aqui e o arquivo não é tocado.
    property color previa: "#000000"
    property bool arrastando: false

    readonly property var papeis: [
        { k: "BG",      t: Idioma.t("colors.role.bg")     },
        { k: "BG_ALT",  t: Idioma.t("colors.role.bgalt")  },
        { k: "FG",      t: Idioma.t("colors.role.fg")     },
        { k: "MUTED",   t: Idioma.t("colors.role.muted")  },
        { k: "DIM",     t: Idioma.t("colors.role.dim")    },
        { k: "ACCENT",  t: Idioma.t("colors.role.accent") },
        { k: "ACCENT2", t: Idioma.t("colors.role.accent2")},
        { k: "OK",      t: Idioma.t("colors.role.ok")     },
        { k: "WARN",    t: Idioma.t("colors.role.warn")   },
        { k: "ERR",     t: Idioma.t("colors.role.err")    }
    ]

    // Matiz de cor acinzentada vem como -1; cair para 0 evita o pino
    // do deslizador saltar para fora do trilho.
    readonly property real matiz: corSel.hslHue < 0 ? 0 : corSel.hslHue
    readonly property real satur: corSel.hslSaturation
    readonly property real luz:   corSel.hslLightness

    readonly property color corSel:
        arrastando ? previa
                   : (paleta[papelSel] !== undefined ? Qt.color("#" + paleta[papelSel])
                                                     : Qt.color("#888888"))

    // ── Perfis de tela por jogo ─────────────────────────────────
    //
    // A lista NÃO está escrita aqui, e é de propósito: os perfis são os
    // .frag de ~/.config/hypr/shaders, e criar um arquivo lá já o torna
    // aplicável. Manter a lista também no QML significaria que todo perfil
    // novo aparece no atalho de teclado e some do painel, sem erro nenhum
    // para denunciar. Quem responde é o `rice-shader nomes`.
    //
    // O ativo vem de uma chamada separada porque não é config nossa: é
    // estado do hyprshade, que muda por atalho de teclado e por linha de
    // comando sem passar por aqui.
    property var    perfisShader: []
    property string shaderAtual:  ""

    Process {
        id: lerPerfisShader
        command: [PraxeConfig.bin + "rice-shader", "nomes"]
        stdout: StdioCollector {
            onStreamFinished: root.perfisShader = text.trim().split("\n").filter(l => l !== "")
        }
    }

    Process {
        id: lerShaderAtual
        command: [PraxeConfig.bin + "rice-shader"]
        stdout: StdioCollector { onStreamFinished: root.shaderAtual = text.trim() }
    }

    // Aplica e relê. Reler não é paranoia: o `rice-shader` RECUSA um perfil
    // que o Hyprland não aceitou e volta sozinho para o padrão, então o que
    // ficou na tela pode não ser o que foi pedido.
    function trocarShader(passo) {
        const n = root.perfisShader.length
        if (n === 0) return
        let i = root.perfisShader.indexOf(root.shaderAtual)
        if (i < 0) i = 0
        acaoShader.command = [PraxeConfig.bin + "rice-shader",
                              root.perfisShader[(i + passo + n) % n]]
        acaoShader.running = true
    }

    Process {
        id: acaoShader
        onExited: lerShaderAtual.running = true
    }

    Process {
        id: lerCores
        command: [PraxeConfig.bin + "rice-cores", "mostrar"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                for (const l of text.trim().split("\n")) {
                    const c = l.split("\t")
                    if (c.length === 2 && c[0] !== "NAME") m[c[0]] = c[1]
                }
                root.paleta = m
            }
        }
    }

    // Lê as paletas direto dos arquivos de tema: uma linha por tema,
    // campos separados por tab.
    Process {
        id: lerTemas
        command: ["bash", "-c",
            "for f in \"$HOME\"/.config/rice/themes/*.sh; do " +
            "  [ -e \"$f\" ] || continue; " +
            "  ( NAME=''; BG=''; ACCENT=''; ACCENT2=''; OK=''; ERR=''; PROPRIO=''; WALLPAPER=''; " +
            "    . \"$f\"; " +
            "    b=$(basename \"$f\" .sh); " +
            "    printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' " +
            "      \"$b\" \"${NAME:-$b}\" \"$BG\" \"$ACCENT\" \"$ACCENT2\" \"$OK\" \"$ERR\" " +
            "      \"${PROPRIO:+1}\" \"$WALLPAPER\" ); " +
            "done | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lista = []
                for (const linha of text.trim().split("\n")) {
                    if (!linha) continue
                    const c = linha.split("\t")
                    if (c.length < 7) continue
                    lista.push({
                        arquivo: c[0], nome: c[1],
                        bg: "#" + c[2], accent: "#" + c[3],
                        accent2: "#" + c[4], ok: "#" + c[5], err: "#" + c[6],
                        // 8ª coluna: "1" quando o arquivo tem PROPRIO=.
                        // Comparação com "1" e não conversão para bool:
                        // um tema salvo antes desta coluna existir devolve
                        // undefined, e `!!undefined` já daria false — mas
                        // deixar explícito evita que alguém "simplifique"
                        // para `c[7]` e passe a tratar "" como verdadeiro.
                        proprio: c[7] === "1",

                        // Papel de parede do tema, já resolvido em caminho
                        // absoluto. O tema guarda só o NOME do arquivo
                        // (`nord-lua.jpg`), porque a pasta de imagens depende
                        // do idioma do sistema e cravá-la no tema quebraria o
                        // arquivo ao mudar de locale — a mesma regra do resto
                        // do rice. Caminho absoluto no tema também é aceito,
                        // para papel que mora fora da pasta padrão.
                        papel: !c[8] ? ""
                               : (c[8].charAt(0) === "/" ? c[8]
                                  : PraxeConfig.wallpaperDir + "/" + c[8])
                    })
                }
                root.temas = lista
            }
        }
    }

    Process {
        id: lerAtual
        command: ["bash", "-c",
            "cat \"$HOME/.config/rice/current\" 2>/dev/null || echo samurai"]
        stdout: StdioCollector { onStreamFinished: root.temaAtual = text.trim() }
    }

    Process {
        id: lerMono
        command: [PraxeConfig.bin + "rice-set", "fonts"]
        stdout: StdioCollector {
            onStreamFinished: root.fontesMono = text.trim().split("\n").filter(l => l.length > 0)
        }
    }

    Process {
        id: lerProp
        command: [PraxeConfig.bin + "rice-set", "appfonts"]
        stdout: StdioCollector {
            onStreamFinished: root.fontesProp = text.trim().split("\n").filter(l => l.length > 0)
        }
    }

    Process {
        id: lerAjustes
        command: [PraxeConfig.bin + "rice-set", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.trim().split("\n")) {
                    const i = l.indexOf("=")
                    if (i < 0) continue
                    const k = l.substring(0, i), v = l.substring(i + 1)
                    if      (k === "FONT")           root.fonte = v
                    else if (k === "FONT_SIZE")      root.fonteTam = parseInt(v) || 12
                    else if (k === "FONT_TERM")      root.fonteTerm = v
                    else if (k === "TERM_FONT_SIZE") root.fonteTermTam = parseInt(v) || 9
                    else if (k === "FONT_APP")       root.fonteApp = v
                    else if (k === "APP_FONT_SIZE")  root.fonteAppTam = parseInt(v) || 10
                }
            }
        }
    }

    Process {
        id: lerIcones
        command: [PraxeConfig.bin + "rice-icons", "listar"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.icones = JSON.parse(text) } catch (e) { root.icones = [] } }
        }
    }

    Process {
        id: lerIconeAtual
        command: [PraxeConfig.bin + "rice-icons", "atual"]
        stdout: StdioCollector { onStreamFinished: root.iconeAtual = text.trim() }
    }

    Process {
        id: lerCoresPasta
        command: [PraxeConfig.bin + "rice-folders", "cores"]
        stdout: StdioCollector {
            onStreamFinished: root.coresPasta = text.trim().split(/\s+/).filter(l => l.length > 0)
        }
    }

    Process {
        id: lerLojaFontes
        command: [PraxeConfig.bin + "rice-set", "loja"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.lojaFontes = JSON.parse(text) } catch (e) { } }
        }
    }

    Process {
        id: lerLojaIcones
        command: [PraxeConfig.bin + "rice-icons", "loja"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.lojaIcones = JSON.parse(text) } catch (e) { } }
        }
    }

    // Papel em vigor, lido do hyprpaper.conf — é o arquivo que o seletor
    // escreve, então reflete o que está na tela.
    Process {
        id: lerPapel
        command: ["bash", "-c",
            "grep -m1 '^wallpaper' \"$HOME/.config/hypr/hyprpaper.conf\" 2>/dev/null " +
            "| sed 's/^wallpaper *= *,//'"]
        stdout: StdioCollector { onStreamFinished: root.papelAtual = text.trim() }
    }

    function recarregar() {
        lerTemas.running = true;   lerAtual.running = true
        lerMono.running = true;    lerProp.running = true
        lerAjustes.running = true; lerPapel.running = true
        lerIcones.running = true;  lerIconeAtual.running = true
        lerCoresPasta.running = true
        lerLojaFontes.running = true; lerLojaIcones.running = true
        lerCores.running = true
        lerPerfisShader.running = true; lerShaderAtual.running = true
    }

    Component.onCompleted: recarregar()
    // Fechar o painel desarma a confirmação de apagar. Sem isto ela
    // sobreviveria escondida, e o próximo toque no botão — talvez horas
    // depois, já sem lembrar do primeiro — apagaria de imediato.
    onAbertoChanged: {
        apagandoTema = ""
        if (aberto) { recarregar(); entradaEpoca++ }
    }

    // Contador de ABERTURAS, e é o que faz a entrada dos cartões de tema
    // acontecer mais de uma vez na vida.
    //
    // Este painel é criado UMA vez, no arranque da barra, e abrir e fechar
    // só troca a opacidade dele. Então `Component.onCompleted` num delegado
    // dispara enquanto ninguém está olhando e nunca mais — a animação
    // existiria no código e não na tela, que é o pior tipo de recurso
    // morto: aquele que parece pronto.
    //
    // Os delegados observam este número e reiniciam a entrada quando ele
    // muda. Contador e não booleano: dois `true` seguidos não emitem sinal
    // de mudança, e reabrir o painel na mesma sessão precisa disparar.
    property int entradaEpoca: 0

    // ── Pré-carga das miniaturas de tema ────────────────────────
    //
    // As fotos entravam com atraso e SEM animação: o cartão fazia a cascata
    // sozinho e a imagem aparecia depois, de estalo. Fica pior que sem
    // animação nenhuma, porque a cascata promete que aquilo foi encenado e
    // a foto chegando fora do tempo desmente na hora.
    //
    // A carga é assíncrona de propósito — sete fotos, várias em 4K, e travar
    // a abertura do painel para descomprimir todas seria trocar um defeito
    // por outro pior. O conserto é começar ANTES: este bloco invisível pede
    // as sete assim que a lista de temas chega, no arranque da barra. Quando
    // o painel abre, o cache já está quente e o cartão nasce com a foto.
    //
    // ESTA CONSTANTE É A PEÇA QUE FAZ FUNCIONAR. O Qt indexa o cache de
    // imagem por (caminho, sourceSize) — largura diferente é OUTRA entrada,
    // e a pré-carga não serviria para nada. Antes o cartão pedia
    // `grade.cellWidth * 2`, que no arranque ainda não tem valor: qualquer
    // pré-carga erraria a chave por construção. Agora os dois pedem daqui.
    //
    // 320px porque a célula fica em torno de 250 e o dobro cobre tela HiDPI
    // sem carregar 4K para uma miniatura.
    readonly property int larguraMiniatura: Math.round(320 * Theme.scale)

    Item {
        visible: false
        Repeater {
            model: root.temas
            delegate: Image {
                required property var modelData
                source: modelData.papel ? "file://" + modelData.papel : ""
                asynchronous: true
                cache: true
                sourceSize.width: root.larguraMiniatura
                width: 1; height: 1
            }
        }
    }

    // ── Ações ───────────────────────────────────────────────────
    Process { id: acao }

    function rodar(args) { acao.command = args; acao.running = true }

    // Grava uma chave de janela e REGERA o tema.
    //
    // Duas etapas, e a segunda não é opcional: `bordaJanela`, `arredJanela`,
    // os gaps e as cores da borda não são lidos pela barra — eles alimentam
    // o `decor.lua` e o `colors.lua`, que o rice-theme ESCREVE. Gravar no
    // pill.json e parar por aí mudaria o arquivo e não a tela.
    //
    // `RICE_SO_DECOR=1` gera SÓ o que o Hyprland lê (colors.lua, decor.lua,
    // opacity.lua) e recarrega. Sem isso cada clique no `+` da borda
    // disparava o `set` completo: 17 arquivos e a reconstrução do tema de
    // ícones, medidos em 3,44 s. Com o caminho rápido, 0,10 s — e a
    // diferença importa porque este é um valor que se ajusta cinco vezes
    // seguidas até achar o ponto, não uma vez.
    //
    // Ele já implica `RICE_SEM_PAPEL`: mexer na borda nunca deve trocar a
    // imagem de fundo.
    function ajusteJanela(chave, valor) {
        rodar(["bash", "-c",
               PraxeConfig.bin + "rice-pill set " + chave + " " + JSON.stringify(String(valor)) +
               " >/dev/null 2>&1; RICE_SO_DECOR=1 " + PraxeConfig.bin + "rice-theme set " +
               "\"$(" + PraxeConfig.bin + "rice-theme current)\" >/dev/null 2>&1"])
    }

    // Os papéis oferecidos para a borda, na ordem em que fazem sentido:
    // primeiro os dois acentos (o caso comum), depois os neutros, e os
    // sinais no fim — usar ERR numa borda é escolha legítima, mas rara.
    readonly property var papeisBorda: ["accent", "accent2", "fg", "muted", "dim",
                                        "bg_alt", "ok", "warn", "err"]

    // Slug em minúsculas (como vai para o pill.json) → chave da paleta.
    function chaveDoPapel(slug) {
        return (slug || "accent").toUpperCase()
    }
    function corDoPapel(slug) {
        const k = chaveDoPapel(slug)
        return paleta[k] !== undefined ? Qt.color("#" + paleta[k]) : PraxeConfig.colDim
    }
    function nomeDoPapel(slug) {
        const k = chaveDoPapel(slug)
        for (const p of papeis) if (p.k === k) return p.t
        return slug
    }

    function papelSeguinte(atual, passo) {
        const l = papeisBorda
        const i = Math.max(0, l.indexOf(atual || l[0]))
        return l[(i + passo + l.length) % l.length]
    }

    function aplicarTema(nome) {
        rodar([PraxeConfig.bin + "rice-theme", "set", nome]); temaAtual = nome
    }

    // Troca circular dentro de uma lista. Um seletor de setas evita a
    // lista suspensa, que no layer-shell fica presa dentro do painel e
    // não tem para onde abrir.
    function vizinho(lista, atual, passo) {
        if (!lista || lista.length === 0) return atual
        let i = lista.indexOf(atual)
        if (i < 0) i = 0
        return lista[((i + passo) % lista.length + lista.length) % lista.length]
    }

    function trocarFonte(qual, passo) {
        if (qual === "font") {
            const n = vizinho(fontesMono, fonte, passo)
            fonte = n; rodar([PraxeConfig.bin + "rice-set", "font", n])
        } else if (qual === "termfont") {
            const n = vizinho(fontesMono, fonteTerm, passo)
            fonteTerm = n; rodar([PraxeConfig.bin + "rice-set", "termfont", n])
        } else {
            const n = vizinho(fontesProp, fonteApp, passo)
            fonteApp = n; rodar([PraxeConfig.bin + "rice-set", "appfont", n])
        }
    }

    function trocarTamanho(qual, delta) {
        if (qual === "fontsize") {
            const n = fonteTam + delta
            if (n < 8 || n > 20) return
            fonteTam = n; rodar([PraxeConfig.bin + "rice-set", "fontsize", String(n)])
        } else if (qual === "termsize") {
            const n = fonteTermTam + delta
            if (n < 6 || n > 20) return
            fonteTermTam = n; rodar([PraxeConfig.bin + "rice-set", "termsize", String(n)])
        } else {
            const n = fonteAppTam + delta
            if (n < 7 || n > 18) return
            fonteAppTam = n; rodar([PraxeConfig.bin + "rice-set", "appsize", String(n)])
        }
    }

    // O tema em uso é do usuário? É o que libera renomear e apagar.
    //
    // Sai da LISTA e não de um teste de nome. Antes a checagem era
    // `temaAtual === "personalizado"`, que só funcionava porque havia um
    // único tema do usuário com nome cravado. Com vários, o que separa é
    // a marca PROPRIO dentro do arquivo, que vem na lista.
    readonly property bool temaProprio: {
        for (const t of temas) if (t.arquivo === temaAtual) return t.proprio === true
        return false
    }
    readonly property string temaNome: {
        for (const t of temas) if (t.arquivo === temaAtual) return t.nome
        return temaAtual
    }

    // Grava a cor e reaplica o tema. Chamado só ao SOLTAR o deslizador.
    //
    // Processo PRÓPRIO, com stdout, e não o `rodar` compartilhado: quando
    // o tema em uso é de fábrica, o rice-cores CLONA antes de editar e
    // devolve o id do clone. Sem ler essa saída o painel continuaria
    // marcando o tema de fábrica — que a essa altura não é mais o que
    // está na tela.
    Process {
        id: acaoCor
        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim().split(" ")[0]
                if (id.length > 0) root.temaAtual = id
                lerTemas.running = true
            }
        }
    }

    function gravarCor(hex) {
        acaoCor.command = [PraxeConfig.bin + "rice-cores", "set", papelSel, hex]
        acaoCor.running = true
        const m = paleta
        m[papelSel] = hex
        paleta = m
    }

    function soltarCor() {
        if (!arrastando) return
        arrastando = false
        gravarCor(corParaHex(previa))
    }

    function corParaHex(c) {
        return c.toString().replace("#", "").substring(0, 6)
    }

    function ajustar(chave, valor) {
        rodar([PraxeConfig.bin + "rice-pill", "set", chave, String(valor)])
    }

    // ── Peças reutilizadas ──────────────────────────────────────
    component Titulo: Text {
        color: PraxeConfig.colMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 3
        font.letterSpacing: 0.8
        Layout.topMargin: Math.round(4 * Theme.scale)
    }

    component Separador: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: PraxeConfig.colDim
        opacity: 0.5
    }

    // Explicação curta sob um título, para quando um controle está
    // desligado. Quebra linha em vez de elidir de propósito: um aviso
    // cortado com reticências informa que algo não funciona e esconde
    // justamente a parte que diz como voltar a funcionar.
    component Nota: Text {
        Layout.fillWidth: true
        color: PraxeConfig.colMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 4
        lineHeight: 1.25
        wrapMode: Text.WordWrap
        opacity: 0.9
    }

    component BotaoRedondo: Rectangle {
        id: br
        property string glifo: ""
        property bool ativo: true
        signal acionado

        width: Math.round(24 * Theme.scale)
        height: width
        radius: width / 2
        opacity: ativo ? 1 : 0.35
        color: areaBr.containsMouse && ativo
               ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g, PraxeConfig.colFg.b, 0.10)
               : "transparent"
        border.width: 1
        border.color: PraxeConfig.colDim
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: br.glifo
            color: areaBr.containsMouse && br.ativo ? PraxeConfig.colAccent : PraxeConfig.colFg
            font.family: Theme.nerdFontFamily
            font.pixelSize: Math.round(12 * Theme.scale)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: areaBr
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: br.ativo ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (br.ativo) br.acionado()
        }
    }

    // Interruptor. O acento MARCA o estado ligado — é o trilho e o pino
    // que mudam de cor, não um bloco preenchido.
    component Chave: Rectangle {
        id: ch
        property bool ligado: false
        signal alternado

        implicitWidth: Math.round(38 * Theme.scale)
        implicitHeight: Math.round(20 * Theme.scale)
        radius: height / 2
        color: ligado
               ? Qt.rgba(PraxeConfig.colAccent.r, PraxeConfig.colAccent.g,
                         PraxeConfig.colAccent.b, 0.22)
               : Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g, PraxeConfig.colFg.b, 0.06)
        border.width: 1
        border.color: ligado ? PraxeConfig.colAccent : PraxeConfig.colDim
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: Math.round(14 * Theme.scale)
            height: width
            radius: width / 2
            y: (parent.height - height) / 2
            x: ch.ligado ? parent.width - width - Math.round(3 * Theme.scale)
                         : Math.round(3 * Theme.scale)
            color: ch.ligado ? PraxeConfig.colAccent : PraxeConfig.colMuted
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.alternado()
        }
    }

    // Contador − n +
    component Passo: RowLayout {
        id: ps
        property int valor: 0
        signal menos
        signal mais
        spacing: Math.round(4 * Theme.scale)

        BotaoRedondo { glifo: "󰍴"; onAcionado: ps.menos() }
        Text {
            text: ps.valor
            color: PraxeConfig.colAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: Math.round(26 * Theme.scale)
        }
        BotaoRedondo { glifo: "󰐕"; onAcionado: ps.mais() }
    }

    // Seletor de setas: ‹ valor ›
    //
    // Setas e não lista suspensa: no layer-shell o menu suspenso fica
    // preso dentro do painel e não tem para onde abrir.
    component Seletor: RowLayout {
        id: sl
        property string valor: ""
        property string amostraFonte: ""    // desenha o valor na própria fonte
        signal anterior
        signal proximo

        Layout.fillWidth: true
        spacing: Math.round(6 * Theme.scale)

        BotaoRedondo { glifo: "󰅁"; onAcionado: sl.anterior() }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: sl.valor
            color: PraxeConfig.colFg
            // Mostrar o nome da fonte NA fonte: é a única forma de
            // escolher sem aplicar e desfazer até acertar.
            font.family: sl.amostraFonte !== "" ? sl.amostraFonte : Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        BotaoRedondo { glifo: "󰅂"; onAcionado: sl.proximo() }
    }

    // Item de loja: nome, descrição e um botão de baixar.
    component ItemLoja: Rectangle {
        id: il
        property string nome: ""
        property string desc: ""
        property bool instalado: false
        signal instalar

        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(36 * Theme.scale)
        radius: Theme.raioM
        color: areaIl.containsMouse && !instalado
               ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g, PraxeConfig.colFg.b, 0.06)
               : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(10 * Theme.scale)
            anchors.rightMargin: Math.round(10 * Theme.scale)
            spacing: Math.round(8 * Theme.scale)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: il.nome
                    color: PraxeConfig.colFg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: il.desc
                    color: PraxeConfig.colMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 4
                }
            }

            Text {
                text: il.instalado ? "󰄲" : "󰇚"
                color: il.instalado ? PraxeConfig.colMuted : PraxeConfig.colAccent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(13 * Theme.scale)
            }
        }

        MouseArea {
            id: areaIl
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: il.instalado ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!il.instalado) il.instalar()
        }
    }

    // Seletor de PAPEL da paleta: ‹ ■ Nome ›
    //
    // Nasceu porque o `Seletor` genérico não servia aqui, por dois motivos.
    //
    // 1. Ele mostrava o slug cru — "accent2", "bg_alt". Texto técnico, em
    //    minúsculas e em inglês, no meio de um painel traduzido.
    //
    // 2. Ele tem `Layout.fillWidth: true`, e o rótulo do `Linha` também.
    //    Os dois disputavam a largura e cada um ficava com metade da linha,
    //    enquanto as linhas de `Passo` (que não estica) alinhavam de outro
    //    jeito. Era isso que deixava a seção torta: duas famílias de linha
    //    com dois alinhamentos diferentes, empilhadas.
    //
    // Aqui a largura é FIXA, igual para todas as linhas de cor, então o
    // rótulo à esquerda termina no mesmo ponto em toda a seção — e no mesmo
    // ponto das linhas de contador.
    //
    // E mostra a COR, que é o assunto. Escolher cor lendo o nome dela é
    // trabalho a mais para quem já está olhando a tela.
    component SeletorPapel: RowLayout {
        id: sp
        property string papel: "accent"
        signal anterior
        signal proximo

        spacing: Math.round(4 * Theme.scale)
        Layout.preferredWidth: Math.round(146 * Theme.scale)

        BotaoRedondo { glifo: "󰅁"; onAcionado: sp.anterior() }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(14 * Theme.scale)
            implicitHeight: implicitWidth
            radius: Theme.raioP
            color: root.corDoPapel(sp.papel)
            border.width: 1
            // Contorno branco a 12%: sem ele um papel escuro (BG_ALT, DIM)
            // some no fundo do painel e a amostra não mostra nada.
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.nomeDoPapel(sp.papel)
            color: PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }

        BotaoRedondo { glifo: "󰅂"; onAcionado: sp.proximo() }
    }

    // Linha de ajuste: rótulo à esquerda, controle à direita.
    component Linha: RowLayout {
        id: ln
        property string rotulo: ""
        Layout.fillWidth: true
        spacing: Math.round(8 * Theme.scale)

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: ln.rotulo
            color: PraxeConfig.colFg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }

    // Grupo segmentado: várias opções, uma escolhida. A marcada leva
    // borda e texto de acento; as outras ficam sem preenchimento
    // nenhum. Acento marca, não preenche.
    component Grupo: RowLayout {
        id: gr
        // Cada opção é um par: o rótulo que aparece e o valor gravado.
        property var opcoes: []      // [{ t: "Cápsula", v: "pill" }, ...]
        property string escolhido: ""
        signal escolher(string valor)

        Layout.fillWidth: true
        spacing: Math.round(5 * Theme.scale)

        Repeater {
            model: gr.opcoes
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool marcado: seg.modelData.v === gr.escolhido

                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(26 * Theme.scale)
                radius: Theme.raioP
                color: seg.marcado
                       ? Qt.rgba(PraxeConfig.colAccent.r, PraxeConfig.colAccent.g,
                                 PraxeConfig.colAccent.b, 0.12)
                       : (areaSeg.containsMouse
                          ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                    PraxeConfig.colFg.b, 0.06)
                          : "transparent")
                border.width: 1
                border.color: seg.marcado ? PraxeConfig.colAccent : PraxeConfig.colDim
                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Text {
                    anchors.centerIn: parent
                    text: seg.modelData.t
                    color: seg.marcado ? PraxeConfig.colAccent : PraxeConfig.colMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                MouseArea {
                    id: areaSeg
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: gr.escolher(seg.modelData.v)
                }
            }
        }
    }

    // Deslizador com o trilho mostrando o que ele controla: matiz vira
    // arco-íris, saturação vai do cinza à cor, luz do preto ao branco.
    // Sem isso o usuário arrasta às cegas e corrige por tentativa.
    //
    // Grava só ao SOLTAR: cada gravação reaplica o tema inteiro (GTK,
    // Qt, kitty, fuzzel, Hyprland), o que é caro demais para rodar a
    // cada pixel arrastado.
    component Deslizador: Item {
        id: dz
        property real valor: 0            // 0..1
        // Função que devolve a cor do trilho na posição t (0..1).
        property var  corEm: null
        signal arrastou(real v)
        signal soltou

        Layout.fillWidth: true
        implicitHeight: Math.round(18 * Theme.scale)

        // O trilho é uma fileira de segmentos, e não um Gradient: as
        // paradas de um Gradient não são graváveis em tempo de execução,
        // e o trilho da matiz precisa de doze cores calculadas.
        Row {
            id: trilho
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.round(6 * Theme.scale)

            Repeater {
                model: 24
                delegate: Rectangle {
                    required property int index
                    width: trilho.width / 24
                    height: trilho.height
                    color: dz.corEm ? dz.corEm(index / 23) : "transparent"
                }
            }
        }

        // Moldura por cima, para arredondar as pontas da fileira.
        Rectangle {
            anchors.fill: trilho
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: PraxeConfig.colDim
        }

        Rectangle {
            id: pino
            width: Math.round(14 * Theme.scale)
            height: width
            radius: width / 2
            y: (parent.height - height) / 2
            x: Math.max(0, Math.min(parent.width - width,
                                    dz.valor * (parent.width - width)))
            color: PraxeConfig.colFg
            border.width: 2
            border.color: PraxeConfig.colBgPuro
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: mouse => { if (pressed) mover(mouse.x) }
            onPressed: mouse => mover(mouse.x)
            onReleased: dz.soltou()

            function mover(mx) {
                const l = dz.width - pino.width
                if (l <= 0) return
                dz.arrastou(Math.max(0, Math.min(1, (mx - pino.width / 2) / l)))
            }
        }
    }

    // ── Corpo ───────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(16 * Theme.scale)
        spacing: Math.round(9 * Theme.scale)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * Theme.scale)

            Text {
                text: "󰸌"
                color: PraxeConfig.colAccent
                font.family: Theme.nerdFontFamily
                font.pixelSize: Math.round(16 * Theme.scale)
            }
            Text {
                Layout.fillWidth: true
                text: Idioma.t("app.appearance")
                color: PraxeConfig.colFg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                text: Theme.nome
                color: PraxeConfig.colMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        // Abas. A ativa é marcada por um traço de acento embaixo — o
        // acento marca, não preenche.
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: [
                    { g: "󰸌", t: Idioma.t("tab.theme")  },
                    { g: "󰏘", t: Idioma.t("tab.colors") },
                    { g: "󰛖", t: Idioma.t("tab.fonts")  },
                    { g: "󰒓", t: Idioma.t("tab.system") },
                    { g: "󰀻", t: Idioma.t("tab.icons")  }
                ]

                delegate: Item {
                    id: abaItem
                    required property var modelData
                    required property int index
                    readonly property bool ativa: root.aba === index

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(30 * Theme.scale)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Math.round(5 * Theme.scale)
                        Text {
                            text: abaItem.modelData.g
                            color: abaItem.ativa ? PraxeConfig.colAccent : PraxeConfig.colMuted
                            font.family: Theme.nerdFontFamily
                            font.pixelSize: Math.round(12 * Theme.scale)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        // Só a aba ativa mostra o nome. Com cinco abas
                        // não cabe rótulo em todas, e cortar os nomes
                        // seria pior que mostrar só o da que importa.
                        Text {
                            text: abaItem.modelData.t
                            visible: abaItem.ativa
                            color: PraxeConfig.colFg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: abaItem.ativa ? parent.width * 0.55 : 0
                        height: Math.max(1, Math.round(2 * Theme.scale))
                        radius: height / 2
                        color: PraxeConfig.colAccent
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.aba = abaItem.index
                    }
                }
            }
        }

        Separador {}

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.aba

            // ═══ Aba 1: Tema ════════════════════════════════════
            ColumnLayout {
                spacing: Math.round(9 * Theme.scale)

                GridView {
                    id: grade
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.temas
                    cellWidth: Math.floor(width / 2)
                    // 96 e não os 52 de antes: o cartão deixou de ser uma
                    // linha de texto com bolinhas e passou a ser a
                    // MINIATURA do tema — papel de parede ao fundo, cores
                    // por cima. Numa faixa de 52px o papel viraria borrão
                    // sem informação nenhuma; abaixo de ~80px nenhuma foto
                    // se reconhece.
                    cellHeight: Math.round(96 * Theme.scale)

                    delegate: Item {
                        id: cartao
                        required property var modelData
                        required property int index
                        width: grade.cellWidth
                        height: grade.cellHeight
                        readonly property bool atual: modelData.arquivo === root.temaAtual

                        // ── Entrada escalonada ──────────────────
                        //
                        // Os cartões entram um a um, ~28ms de atraso entre
                        // vizinhos. É a única coisa aqui que existe só para
                        // ser bonita, e vale a pena por um motivo prático:
                        // aparecendo todos no mesmo quadro, sete fotos de
                        // uma vez são uma parede, e o olho não sabe por onde
                        // começar. Em cascata ele é conduzido do primeiro ao
                        // último e lê a grade como lista.
                        //
                        // O atraso é limitado a oito posições. Sem o teto,
                        // uma pasta com quarenta temas faria o último cartão
                        // esperar mais de um segundo — animação de entrada
                        // que se faz esperar deixa de ser entrada e vira
                        // travamento.
                        //
                        // OutBack com overshoot CURTO (0.8; o padrão é 1.7):
                        // o cartão passa um fio do tamanho final e volta. É
                        // o que dá o assentar de coisa com massa. Overshoot
                        // cheio num cartão de 96px daria pulo de brinquedo.
                        opacity: 0
                        scale: 0.96

                        // Reinicia a cada abertura do painel — ver
                        // `entradaEpoca` lá em cima.
                        Connections {
                            target: root
                            function onEntradaEpocaChanged() { entrada.restart() }
                        }

                        SequentialAnimation {
                            id: entrada
                            running: true
                            // Volta ao estado inicial ANTES de cada corrida.
                            // Sem isto, a segunda abertura encontraria o
                            // cartão já em opacidade 1 e não haveria entrada
                            // nenhuma para ver.
                            PropertyAction { target: cartao; property: "opacity"; value: 0 }
                            PropertyAction { target: cartao; property: "scale";   value: 0.96 }
                            PauseAnimation { duration: Math.min(cartao.index, 8) * 28 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: cartao; property: "opacity"; to: 1
                                    duration: 220; easing.type: Theme.curva
                                }
                                NumberAnimation {
                                    target: cartao; property: "scale"; to: 1
                                    duration: 260
                                    easing.type: Easing.OutBack; easing.overshoot: 0.8
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Math.round(3 * Theme.scale)
                            radius: Theme.raioM
                            color: cartao.atual
                                   ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                             PraxeConfig.colFg.b, 0.08)
                                   : (areaCard.containsMouse
                                      ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                                PraxeConfig.colFg.b, 0.05)
                                      : "transparent")
                            border.width: 1
                            border.color: cartao.atual ? PraxeConfig.colAccent : PraxeConfig.colDim
                            Behavior on color { ColorAnimation { duration: 130 } }

                            // ── A miniatura ─────────────────────────
                            //
                            // O papel de parede é metade da identidade de um
                            // tema, e o cartão mostrava só a outra metade.
                            // Quem escolhe tema pelo nome e cinco bolinhas
                            // está adivinhando: `mare` e `nord` têm paleta
                            // fria parecida e papéis que não se confundem.
                            //
                            // `clip` no Rectangle de fora é o que faz a
                            // imagem respeitar o raio do cartão.
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: cartao.modelData.papel
                                        ? "file://" + cartao.modelData.papel : ""
                                fillMode: Image.PreserveAspectCrop
                                // Assíncrono e reamostrado: são sete fotos,
                                // várias em 4K, e carregá-las no tamanho
                                // original travaria a abertura do painel por
                                // um cartão de 100px de largura.
                                //
                                // A largura vem da constante do root, e é o
                                // que faz a pré-carga acertar a chave do
                                // cache — ver a nota longa lá em cima.
                                asynchronous: true
                                cache: true
                                sourceSize.width: root.larguraMiniatura

                                // Aparece por fade, e não por `visible`.
                                //
                                // Com `visible: status === Image.Ready` a foto
                                // ligava de um quadro para o outro. Com o
                                // cache quente isso acontece antes de alguém
                                // ver — mas o cache pode estar frio: primeira
                                // abertura logo após ligar a barra, ou papel
                                // trocado por fora. Aí o estalo aparecia, e
                                // justamente no lugar onde a cascata acabou
                                // de prometer que tudo foi encenado.
                                //
                                // Assim o caso ruim vira um fade de 200ms em
                                // vez de um susto, e o caso bom continua
                                // instantâneo: pronta desde o primeiro
                                // quadro, a opacidade já nasce no valor final.
                                opacity: status !== Image.Ready ? 0
                                       : (cartao.atual ? 1.0
                                          : (areaCard.containsMouse ? 0.92 : 0.72))
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.animPadrao
                                                      easing.type: Theme.curva }
                                }
                            }

                            // Véu de baixo para cima. Sem ele o nome fica
                            // sobre foto arbitrária e some em metade dos
                            // temas — e é justamente o `bg` do tema, então
                            // o degradê também MOSTRA a cor de fundo dele.
                            Rectangle {
                                anchors.fill: parent
                                // As paradas foram medidas contra o pior caso,
                                // e o pior caso existe: o papel do Catppuccin
                                // é um dragão rosa claro e o do Gruvbox tem um
                                // robô sobre fundo bege. Com o degradê fraco
                                // que estava aqui, o nome desses dois sumia —
                                // e um seletor em que você não lê o nome do
                                // tema claro é pior que o cartão de bolinhas
                                // que ele veio substituir.
                                //
                                // A rampa sobe tarde e forte: até 40% da
                                // altura a foto aparece quase limpa, e daí
                                // para baixo fecha rápido. É o oposto de um
                                // degradê linear, que escureceria a foto
                                // inteira para proteger duas linhas de texto.
                                gradient: Gradient {
                                    GradientStop { position: 0.0
                                        color: Qt.rgba(Qt.color(cartao.modelData.bg).r,
                                                       Qt.color(cartao.modelData.bg).g,
                                                       Qt.color(cartao.modelData.bg).b, 0.00) }
                                    GradientStop { position: 0.40
                                        color: Qt.rgba(Qt.color(cartao.modelData.bg).r,
                                                       Qt.color(cartao.modelData.bg).g,
                                                       Qt.color(cartao.modelData.bg).b, 0.20) }
                                    GradientStop { position: 0.68
                                        color: Qt.rgba(Qt.color(cartao.modelData.bg).r,
                                                       Qt.color(cartao.modelData.bg).g,
                                                       Qt.color(cartao.modelData.bg).b, 0.80) }
                                    GradientStop { position: 1.0
                                        color: Qt.rgba(Qt.color(cartao.modelData.bg).r,
                                                       Qt.color(cartao.modelData.bg).g,
                                                       Qt.color(cartao.modelData.bg).b, 0.98) }
                                }
                            }

                            // Ancorado EMBAIXO, não centralizado. Com o cartão
                            // virando miniatura, texto no meio da foto fica
                            // sobre a parte mais informativa dela e ainda
                            // exige véu forte no cartão inteiro. Embaixo, o
                            // véu só precisa cobrir a faixa que o texto
                            // ocupa — e a foto respira em cima.
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: Math.round(10 * Theme.scale)
                                // Folga maior à direita: os dois cantos
                                // daquele lado são ocupados agora (indicador
                                // em cima, lixeira embaixo), e sem isto o
                                // nome de um tema longo passaria por baixo
                                // deles em vez de ser encurtado.
                                anchors.rightMargin: Math.round(28 * Theme.scale)
                                anchors.bottomMargin: Math.round(8 * Theme.scale)
                                spacing: Math.round(8 * Theme.scale)

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(5 * Theme.scale)

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: cartao.modelData.nome
                                        color: PraxeConfig.colFg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                        // Semibold porque agora o nome está
                                        // sobre FOTO, não sobre fundo liso.
                                        // Traço fino sobre imagem some nas
                                        // partes texturizadas mesmo com véu:
                                        // o que salva legibilidade sobre
                                        // ruído é peso, não tamanho.
                                        font.weight: Font.DemiBold
                                    }

                                    RowLayout {
                                        spacing: Math.round(4 * Theme.scale)
                                        // Sem o `bg` na fileira, e ele estava
                                        // aqui desde antes da miniatura. O
                                        // véu do cartão JÁ É o bg do tema, e
                                        // uma bolinha da cor do fundo sobre o
                                        // próprio fundo é um buraco: some em
                                        // todos os sete. O que sobra são as
                                        // cores que o tema usa para FALAR —
                                        // acento, acento 2, ok e erro.
                                        Repeater {
                                            model: [cartao.modelData.accent,
                                                    cartao.modelData.accent2, cartao.modelData.ok,
                                                    cartao.modelData.err]
                                            delegate: Rectangle {
                                                required property string modelData
                                                width: Math.round(13 * Theme.scale)
                                                height: Math.round(7 * Theme.scale)
                                                radius: height / 2
                                                color: modelData
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                            }
                                        }
                                    }
                                }

                            }

                            // ── Indicador de tema em uso ────────────
                            //
                            // Ancorado ao canto SUPERIOR direito, e não mais
                            // dentro do RowLayout: ali ele ficava centralizado
                            // na vertical, que é exatamente onde a lixeira
                            // também caía. Dois controles disputando o mesmo
                            // ponto do cartão.
                            //
                            // Cantos opostos resolvem sem depender de um
                            // esconder o outro: em cima o ESTADO (este é o
                            // tema em uso), embaixo a AÇÃO (apagar). Estado e
                            // ação não se confundem quando não se tocam.
                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Math.round(7 * Theme.scale)
                                text: "󰄲"
                                visible: cartao.atual
                                color: PraxeConfig.colAccent
                                font.family: Theme.nerdFontFamily
                                font.pixelSize: Math.round(13 * Theme.scale)
                            }

                            MouseArea {
                                id: areaCard
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.aplicarTema(cartao.modelData.arquivo)
                            }

                            // ── Apagar, no próprio cartão ───────────
                            //
                            // Antes isto morava numa linha lá embaixo, na
                            // seção de configurações, e só aparecia quando o
                            // tema em uso era seu. Ou seja: para apagar um
                            // tema você tinha que APLICÁ-LO primeiro, rolar
                            // até o fim e achar o botão. Apagar o que não
                            // está em uso era o caso comum, e era o único
                            // que não dava para fazer.
                            //
                            // Aqui a ação fica onde o objeto está.
                            //
                            // Declarado DEPOIS do areaCard de propósito: em
                            // QML, quem vem depois fica por cima, e sem isso
                            // o clique na lixeira atravessaria para o cartão
                            // e aplicaria o tema em vez de apagá-lo.
                            Rectangle {
                                id: lixeira
                                visible: cartao.modelData.proprio === true
                                         && (areaCard.containsMouse || areaLixo.containsMouse
                                             || armado)
                                readonly property bool armado:
                                    root.apagandoTema === cartao.modelData.arquivo

                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: Math.round(6 * Theme.scale)
                                width: Math.round(22 * Theme.scale)
                                height: width
                                radius: width / 2
                                // Vermelho só depois de armado. Antes disso é
                                // um botão neutro: pintar de perigo o que
                                // ainda não faz nada é gritar sem motivo.
                                color: armado ? PraxeConfig.colErr
                                              : Qt.rgba(PraxeConfig.colBgPuro.r,
                                                        PraxeConfig.colBgPuro.g,
                                                        PraxeConfig.colBgPuro.b, 0.85)
                                border.width: 1
                                border.color: armado ? PraxeConfig.colErr : PraxeConfig.colDim
                                Behavior on color { ColorAnimation { duration: 130 } }

                                Text {
                                    anchors.centerIn: parent
                                    // Armado troca de glifo, e não só de cor:
                                    // quem não distingue vermelho de cinza
                                    // ainda enxerga que o botão mudou.
                                    text: lixeira.armado ? "󰀦" : "󰆴"
                                    color: lixeira.armado ? PraxeConfig.colBgPuro
                                                          : PraxeConfig.colMuted
                                    font.family: Theme.nerdFontFamily
                                    font.pixelSize: Math.round(11 * Theme.scale)
                                }

                                MouseArea {
                                    id: areaLixo
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Dois toques, sem diálogo: o primeiro
                                        // arma e o segundo apaga. Desarma
                                        // sozinho em 4s, então quem realmente
                                        // quer apagar clica duas vezes e nem
                                        // percebe o passo extra.
                                        if (!lixeira.armado) {
                                            root.apagandoTema = cartao.modelData.arquivo
                                            desarmar.restart()
                                            return
                                        }
                                        desarmar.stop()
                                        root.apagandoTema = ""
                                        root.rodar([PraxeConfig.bin + "rice-cores",
                                                    "apagar", cartao.modelData.arquivo])
                                        recarregarDepois.restart()
                                    }
                                }

                            }
                        }
                    }
                }

                // Atalho para o seletor de papel de parede.
                //
                // O papel em vigor É o fundo do botão. sourceSize é
                // obrigatório: sem ele o Qt decodifica a imagem inteira
                // (as nossas passam de 5000px) para preencher 50px.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(52 * Theme.scale)
                    radius: Theme.raioM
                    color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                   PraxeConfig.colFg.b, 0.05)
                    border.width: 1
                    border.color: areaPapel.containsMouse ? PraxeConfig.colAccent
                                                          : PraxeConfig.colDim
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // `clip: true` recorta pelo RETÂNGULO e ignora o
                    // radius — a imagem escapava nos cantos. A máscara
                    // abaixo é o único jeito de recortar na forma real.
                    Image {
                        id: imgPapel
                        anchors.fill: parent
                        source: root.papelAtual !== "" ? "file://" + root.papelAtual : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 512
                        visible: false
                        layer.enabled: true
                    }

                    Rectangle {
                        id: mascaraPapel
                        anchors.fill: parent
                        radius: Theme.raioM
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: imgPapel
                        maskEnabled: true
                        maskSource: mascaraPapel
                        visible: imgPapel.status === Image.Ready
                        opacity: areaPapel.containsMouse ? 1.0 : 0.85
                        Behavior on opacity { NumberAnimation { duration: 150 ; easing.type: Theme.curva } }
                    }

                    // Véu escuro: sem ele o texto some em papel claro.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.raioM
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.80) }
                            GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.45) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.65) }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(14 * Theme.scale)
                        anchors.rightMargin: Math.round(14 * Theme.scale)
                        spacing: Math.round(10 * Theme.scale)

                        Text {
                            text: "󰸉"
                            color: PraxeConfig.colAccent
                            font.family: Theme.nerdFontFamily
                            font.pixelSize: Math.round(15 * Theme.scale)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: Idioma.t("app.wallpaper")
                                color: PraxeConfig.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                text: root.papelAtual === "" ? Idioma.t("weather.none")
                                      : root.papelAtual.substring(root.papelAtual.lastIndexOf("/") + 1)
                                color: Qt.rgba(1, 1, 1, 0.65)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }

                        Text {
                            text: "󰅂"
                            color: Qt.rgba(1, 1, 1, 0.7)
                            font.family: Theme.nerdFontFamily
                            font.pixelSize: Math.round(13 * Theme.scale)
                        }
                    }

                    MouseArea {
                        id: areaPapel
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.irParaPapeis()
                    }
                }
            }

            // ═══ Aba 2: Cores ═══════════════════════════════════
            //
            // Editar uma cor CLONA o tema ativo em "personalizado" antes
            // de escrever — quem faz isso é o rice-cores. Sem o clone, a
            // primeira mexida destruiria um tema de fábrica.
            Flickable {
                contentHeight: colCores.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colCores
                    width: parent.width
                    spacing: Math.round(7 * Theme.scale)

                    Titulo { text: Idioma.t("colors.roles") }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Math.round(5 * Theme.scale)

                        Repeater {
                            model: root.papeis
                            delegate: Rectangle {
                                id: chipPapel
                                required property var modelData
                                readonly property bool sel: chipPapel.modelData.k === root.papelSel
                                readonly property color cor:
                                    root.paleta[chipPapel.modelData.k] !== undefined
                                        ? Qt.color("#" + root.paleta[chipPapel.modelData.k])
                                        : Qt.color("#888888")

                                width: Math.round(97 * Theme.scale)
                                height: Math.round(30 * Theme.scale)
                                radius: Theme.raioM
                                color: "transparent"
                                border.width: 1
                                border.color: chipPapel.sel ? PraxeConfig.colAccent
                                                            : PraxeConfig.colDim
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(7 * Theme.scale)
                                    anchors.rightMargin: Math.round(7 * Theme.scale)
                                    spacing: Math.round(6 * Theme.scale)

                                    // A amostra é a cor de verdade; o
                                    // resto do chip fica sem preenchimento
                                    // para não virar um bloco colorido.
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(13 * Theme.scale)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: Theme.raioP
                                        color: chipPapel.cor
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.16)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: chipPapel.modelData.t
                                        color: chipPapel.sel ? PraxeConfig.colFg
                                                             : PraxeConfig.colMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 4
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.arrastando = false
                                        root.papelSel = chipPapel.modelData.k
                                    }
                                }
                            }
                        }
                    }

                    Separador {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(9 * Theme.scale)

                        Rectangle {
                            Layout.preferredWidth: Math.round(46 * Theme.scale)
                            Layout.preferredHeight: Math.round(32 * Theme.scale)
                            radius: Theme.raioM
                            color: root.corSel
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.16)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: root.papelSel
                                color: PraxeConfig.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "#" + root.corParaHex(root.corSel)
                                color: PraxeConfig.colMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                    }

                    Titulo { text: Idioma.t("colors.hue") }
                    Deslizador {
                        valor: root.matiz
                        corEm: t => Qt.hsla(t, 0.72, 0.52, 1)
                        onArrastou: v => {
                            root.arrastando = true
                            root.previa = Qt.hsla(v, root.satur, root.luz, 1)
                        }
                        onSoltou: root.soltarCor()
                    }

                    Titulo { text: Idioma.t("colors.saturation") }
                    Deslizador {
                        valor: root.satur
                        corEm: t => Qt.hsla(root.matiz, t, root.luz, 1)
                        onArrastou: v => {
                            root.arrastando = true
                            root.previa = Qt.hsla(root.matiz, v, root.luz, 1)
                        }
                        onSoltou: root.soltarCor()
                    }

                    Titulo { text: Idioma.t("colors.lightness") }
                    Deslizador {
                        valor: root.luz
                        corEm: t => Qt.hsla(root.matiz, root.satur, t, 1)
                        onArrastou: v => {
                            root.arrastando = true
                            root.previa = Qt.hsla(root.matiz, root.satur, v, 1)
                        }
                        onSoltou: root.soltarCor()
                    }

                    Separador {}

                    // ── O tema do usuário: nome e remoção ────────
                    //
                    // Só aparece quando há um tema seu em uso. Mexer numa
                    // cor de um tema de fábrica CLONA antes de editar, e é
                    // esse clone que ganha nome — por isso o aviso abaixo
                    // quando ainda não há nenhum.
                    Text {
                        Layout.fillWidth: true
                        visible: !root.temaProprio
                        text: Idioma.tf("theme.own.hint", root.temaNome)
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                        wrapMode: Text.WordWrap
                    }

                    Linha {
                        visible: root.temaProprio
                        rotulo: Idioma.t("theme.own.name")

                        Rectangle {
                            implicitWidth: Math.round(160 * Theme.scale)
                            implicitHeight: Math.round(24 * Theme.scale)
                            radius: Theme.raioP
                            color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                           PraxeConfig.colFg.b, 0.06)
                            border.width: 1
                            border.color: campoNomeTema.activeFocus
                                          ? PraxeConfig.colAccent : PraxeConfig.colDim
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            TextInput {
                                id: campoNomeTema
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * Theme.scale)
                                anchors.rightMargin: Math.round(8 * Theme.scale)
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                color: PraxeConfig.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1

                                // Enter confirma. Digitar sem confirmar não
                                // muda nada, então dá para desistir no meio.
                                //
                                // Só o TÍTULO muda; o arquivo mantém o nome
                                // com que nasceu — ver a nota no rice-cores
                                // sobre por que renomear o arquivo é pior.
                                onAccepted: {
                                    if (text.trim() === "") return
                                    root.rodar([PraxeConfig.bin + "rice-cores",
                                                "renomear", root.temaAtual, text.trim()])
                                    focus = false
                                    recarregarDepois.restart()
                                }

                                // Mesma armadilha do campo de cidade: um
                                // TextInput com foco CONSOME o Esc, e o
                                // painel deixaria de fechar depois de um
                                // clique aqui. Desfaz, larga o foco e deixa
                                // o evento seguir.
                                Keys.onEscapePressed: {
                                    text = root.temaNome
                                    focus = false
                                    root.fechar()
                                }

                                // Não é binding: um `text:` ligado ao nome
                                // quebraria na primeira tecla digitada e
                                // nunca mais acompanharia. O Connections
                                // atualiza só quando você NÃO está editando.
                                Component.onCompleted: text = root.temaNome

                                Connections {
                                    target: root
                                    function onTemaNomeChanged() {
                                        if (!campoNomeTema.activeFocus)
                                            campoNomeTema.text = root.temaNome
                                    }
                                }
                            }
                        }
                    }

                    // O rice-cores grava e só então a lista muda. Reler na
                    // mesma batida pegaria o arquivo antigo.
                    Timer {
                        id: recarregarDepois
                        interval: 250
                        onTriggered: root.recarregar()
                    }

                    // Apagar em DOIS toques.
                    //
                    // A primeira versão apagava no primeiro clique, com o
                    // argumento de que tema de cor é barato de refazer.
                    // Está errado: refazer custa reencontrar à mão os dez
                    // valores que a pessoa ajustou aos poucos, e o botão
                    // fica a um pixel do campo de nome — o alvo errado do
                    // clique certo.
                    //
                    // Não é um diálogo. O botão só troca de cara e volta
                    // sozinho em 4s se você não confirmar, então quem
                    // realmente quer apagar clica duas vezes seguidas e
                    // nem percebe o passo extra.
                    Timer {
                        id: desarmar
                        interval: 4000
                        onTriggered: root.apagandoTema = ""
                    }
                }
            }

            // ═══ Aba 3: Fontes ══════════════════════════════════
            //
            // Três fontes e não uma: cada superfície tem uma exigência
            // diferente. Terminal PRECISA de monoespaçada; aplicativo lê
            // melhor com proporcional; a interface do rice usa mono por
            // identidade. Por isso o seletor de aplicativos percorre uma
            // lista diferente da dos outros dois.
            Flickable {
                contentHeight: colFontes.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colFontes
                    width: parent.width
                    spacing: Math.round(7 * Theme.scale)

                    Titulo { text: Idioma.t("fonts.interface") }
                    Seletor {
                        valor: root.fonte
                        amostraFonte: root.fonte
                        onAnterior: root.trocarFonte("font", -1)
                        onProximo:  root.trocarFonte("font", 1)
                    }
                    Linha {
                        rotulo: Idioma.t("bar.size")
                        Passo {
                            valor: root.fonteTam
                            onMenos: root.trocarTamanho("fontsize", -1)
                            onMais:  root.trocarTamanho("fontsize", 1)
                        }
                    }

                    Separador {}

                    Titulo { text: Idioma.t("fonts.terminal") }
                    Seletor {
                        valor: root.fonteTerm
                        amostraFonte: root.fonteTerm
                        onAnterior: root.trocarFonte("termfont", -1)
                        onProximo:  root.trocarFonte("termfont", 1)
                    }
                    Linha {
                        rotulo: Idioma.t("bar.size")
                        Passo {
                            valor: root.fonteTermTam
                            onMenos: root.trocarTamanho("termsize", -1)
                            onMais:  root.trocarTamanho("termsize", 1)
                        }
                    }

                    Separador {}

                    Titulo { text: Idioma.t("fonts.apps") }
                    Seletor {
                        valor: root.fonteApp
                        amostraFonte: root.fonteApp
                        onAnterior: root.trocarFonte("appfont", -1)
                        onProximo:  root.trocarFonte("appfont", 1)
                    }
                    Linha {
                        rotulo: Idioma.t("bar.size")
                        Passo {
                            valor: root.fonteAppTam
                            onMenos: root.trocarTamanho("appsize", -1)
                            onMais:  root.trocarTamanho("appsize", 1)
                        }
                    }

                    Separador {}

                    Linha {
                        rotulo: Idioma.t("fonts.install")
                        BotaoRedondo {
                            glifo: root.mostrarLojaFontes ? "󰅃" : "󰅀"
                            onAcionado: root.mostrarLojaFontes = !root.mostrarLojaFontes
                        }
                    }

                    Repeater {
                        model: root.mostrarLojaFontes ? root.lojaFontes : []
                        delegate: ItemLoja {
                            id: lf
                            required property var modelData
                            nome: lf.modelData.nome + "  ·  " + lf.modelData.tipo
                            desc: lf.modelData.desc
                            instalado: lf.modelData.instalado
                            onInstalar: root.rodar([PraxeConfig.bin + "rice-set",
                                                    "instalar", lf.modelData.pkg])
                        }
                    }
                }
            }

            // ═══ Aba 4: Sistema ═════════════════════════════════
            Flickable {
                contentHeight: colSis.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colSis
                    width: parent.width
                    spacing: Math.round(7 * Theme.scale)

                    Titulo { text: Idioma.t("bar.shape") }

                    Grupo {
                        opcoes: [{ t: Idioma.t("bar.shape.capsule"), v: "pill" },
                                 { t: Idioma.t("bar.shape.notch"),   v: "notch" },
                                 { t: Idioma.t("bar.shape.bar"),     v: "bar" }]
                        escolhido: PraxeConfig.layout
                        onEscolher: valor => root.ajustar("layout", valor)
                    }

                    Titulo { text: Idioma.t("bar.position") }

                    Grupo {
                        opcoes: [{ t: Idioma.t("bar.top"),  v: "top" },  { t: Idioma.t("bar.bottom"), v: "bottom" },
                                 { t: Idioma.t("bar.left"), v: "left" }, { t: Idioma.t("bar.right"),  v: "right" }]
                        escolhido: PraxeConfig.position
                        onEscolher: valor => root.ajustar("position", valor)
                    }

                    Titulo { text: Idioma.t("bar.behaviour") }

                    Grupo {
                        opcoes: [{ t: Idioma.t("bar.always"), v: "always" }, { t: Idioma.t("bar.shape.compact"), v: "compact" },
                                 { t: Idioma.t("bar.hover"), v: "hover" }]
                        escolhido: PraxeConfig.reveal
                        onEscolher: valor => root.ajustar("reveal", valor)
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: PraxeConfig.reveal === "always"
                              ? Idioma.t("bar.reveal.always.desc")
                              : PraxeConfig.reveal === "compact"
                              ? Idioma.t("bar.reveal.compact.desc")
                              : Idioma.t("bar.reveal.hover.desc")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Separador {}

                    // ── Janelas ──────────────────────────────────
                    //
                    // Estes quatro valores já existiam e alimentavam o
                    // decor.lua, mas só editando o pill.json à mão. Um
                    // painel de aparência que não deixa mudar a borda da
                    // janela é um painel pela metade.
                    Titulo { text: Idioma.t("win.title") }

                    Linha {
                        rotulo: Idioma.t("win.border")
                        Passo {
                            valor: PraxeConfig.bordaJanela
                            // Teto em 6: acima disso a borda deixa de
                            // marcar foco e vira moldura.
                            onMenos: root.ajusteJanela("bordaJanela", Math.max(0, PraxeConfig.bordaJanela - 1))
                            onMais:  root.ajusteJanela("bordaJanela", Math.min(6, PraxeConfig.bordaJanela + 1))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.rounding")
                        Passo {
                            valor: PraxeConfig.arredJanela
                            // De dois em dois: o olho não distingue 1px de
                            // raio, e o passo fino só faria clicar mais.
                            onMenos: root.ajusteJanela("arredJanela", Math.max(0, PraxeConfig.arredJanela - 2))
                            onMais:  root.ajusteJanela("arredJanela", Math.min(24, PraxeConfig.arredJanela + 2))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.gaps.in")
                        Passo {
                            valor: PraxeConfig.gapsIn
                            onMenos: root.ajusteJanela("gapsIn", Math.max(0, PraxeConfig.gapsIn - 1))
                            onMais:  root.ajusteJanela("gapsIn", Math.min(20, PraxeConfig.gapsIn + 1))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.gaps.out")
                        Passo {
                            valor: PraxeConfig.gapsOut
                            onMenos: root.ajusteJanela("gapsOut", Math.max(0, PraxeConfig.gapsOut - 2))
                            onMais:  root.ajusteJanela("gapsOut", Math.min(60, PraxeConfig.gapsOut + 2))
                        }
                    }

                    Separador {}

                    // ── Cor da borda ─────────────────────────────
                    //
                    // Subseção própria, e não mais quatro linhas soltas
                    // depois dos contadores. São assuntos diferentes: acima
                    // se ajusta GEOMETRIA (espessura, raio, espaço), aqui se
                    // escolhe COR. Misturados, o olho não achava onde uma
                    // coisa terminava e a outra começava.
                    Titulo { text: Idioma.t("win.border.color") }
                    Nota { text: Idioma.t("win.border.desc") }

                    // Prévia do que se está montando.
                    //
                    // O gradiente da borda ativa é um efeito que só existe
                    // na janela focada — para vê-lo era preciso fechar o
                    // painel, olhar, reabrir e ajustar. Aqui ele está do
                    // lado dos controles que o produzem.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(16 * Theme.scale)
                        radius: Theme.raioP
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.corDoPapel(PraxeConfig.bordaAtiva1 || "accent") }
                            GradientStop { position: 1.0; color: root.corDoPapel(PraxeConfig.bordaAtiva2 || "accent2") }
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.border.c1")
                        SeletorPapel {
                            papel: PraxeConfig.bordaAtiva1 || "accent"
                            onAnterior: root.ajusteJanela("bordaAtiva1", root.papelSeguinte(PraxeConfig.bordaAtiva1 || "accent", -1))
                            onProximo:  root.ajusteJanela("bordaAtiva1", root.papelSeguinte(PraxeConfig.bordaAtiva1 || "accent", 1))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.border.c2")
                        SeletorPapel {
                            papel: PraxeConfig.bordaAtiva2 || "accent2"
                            onAnterior: root.ajusteJanela("bordaAtiva2", root.papelSeguinte(PraxeConfig.bordaAtiva2 || "accent2", -1))
                            onProximo:  root.ajusteJanela("bordaAtiva2", root.papelSeguinte(PraxeConfig.bordaAtiva2 || "accent2", 1))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.border.angle")
                        Passo {
                            valor: PraxeConfig.bordaAngulo
                            onMenos: root.ajusteJanela("bordaAngulo", (PraxeConfig.bordaAngulo + 345) % 360)
                            onMais:  root.ajusteJanela("bordaAngulo", (PraxeConfig.bordaAngulo + 15) % 360)
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("win.border.off")
                        SeletorPapel {
                            papel: PraxeConfig.bordaInativa || "dim"
                            onAnterior: root.ajusteJanela("bordaInativa", root.papelSeguinte(PraxeConfig.bordaInativa || "dim", -1))
                            onProximo:  root.ajusteJanela("bordaInativa", root.papelSeguinte(PraxeConfig.bordaInativa || "dim", 1))
                        }
                    }

                    Separador {}

                    Titulo { text: Idioma.t("vivid.title") }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Idioma.t("vivid.desc")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Linha {
                        rotulo: PraxeConfig.vivido === 0 ? Idioma.t("transp.off") : Idioma.t("vivid.strength")
                        Passo {
                            valor: PraxeConfig.vivido
                            // Passo de 5: de 1 em 1 ninguém enxerga a
                            // diferença e cada toque recarrega o config.
                            onMenos: root.rodar([PraxeConfig.bin + "rice-vivido",
                                                 String(Math.max(0, PraxeConfig.vivido - 5))])
                            onMais:  root.rodar([PraxeConfig.bin + "rice-vivido",
                                                 String(Math.min(100, PraxeConfig.vivido + 5))])
                        }
                    }

                    Separador {}

                    // Fica logo abaixo do realce porque as duas coisas são o
                    // MESMO recurso do Hyprland — um shader de tela, e só um
                    // por vez. Escolher um perfil de jogo substitui o realce;
                    // separá-las em abas diferentes esconderia isso.
                    Titulo { text: Idioma.t("shader.title") }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Idioma.t("shader.desc")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Seletor {
                        // O nome do arquivo, cru. Um rótulo bonito por perfil
                        // teria de morar aqui, e aí a pasta de shaders
                        // deixaria de ser a única fonte da lista.
                        valor: root.shaderAtual
                        onAnterior: root.trocarShader(-1)
                        onProximo:  root.trocarShader(1)
                    }

                    Nota { text: Idioma.t("shader.hint") }

                    Separador {}

                    Titulo { text: Idioma.t("dock.title") }

                    Grupo {
                        opcoes: [{ t: Idioma.t("bar.hidden"), v: "off" }, { t: Idioma.t("bar.always"), v: "always" },
                                 { t: Idioma.t("bar.hover"), v: "hover" }]
                        escolhido: PraxeConfig.dock
                        onEscolher: valor => root.ajustar("dock", valor)
                    }

                    Linha {
                        rotulo: Idioma.t("dock.size")
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1
                        Passo {
                            valor: PraxeConfig.dockTamanho
                            onMenos: root.ajustar("dockTamanho", Math.max(28, PraxeConfig.dockTamanho - 4))
                            onMais:  root.ajustar("dockTamanho", Math.min(72, PraxeConfig.dockTamanho + 4))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("dock.trash")
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1
                        Chave {
                            ligado: PraxeConfig.dockLixeira
                            onAlternado: root.ajustar("dockLixeira",
                                                      PraxeConfig.dockLixeira ? "false" : "true")
                        }
                    }

                    // ── Tinta dos ícones ────────────────────────
                    // Desliga zerando a força, em vez de guardar um
                    // booleano separado: dois campos para o mesmo estado
                    // sempre acabam discordando um do outro.
                    Linha {
                        rotulo: Idioma.t("dock.tint")
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1
                        Chave {
                            ligado: PraxeConfig.dockTinta > 0
                            onAlternado: root.ajustar("dockTinta",
                                                      PraxeConfig.dockTinta > 0 ? 0 : 70)
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("vivid.strength")
                        visible: PraxeConfig.dockTinta > 0
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1
                        Passo {
                            valor: PraxeConfig.dockTinta
                            onMenos: root.ajustar("dockTinta",
                                                  Math.max(10, PraxeConfig.dockTinta - 10))
                            onMais:  root.ajustar("dockTinta",
                                                  Math.min(100, PraxeConfig.dockTinta + 10))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("dock.tint.color")
                        visible: PraxeConfig.dockTinta > 0
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1

                        RowLayout {
                            spacing: Math.round(6 * Theme.scale)

                            Repeater {
                                // A primeira grava vazio: é a que ACOMPANHA
                                // o tema. As outras congelam um valor, e por
                                // isso continuam iguais quando o tema muda —
                                // que é justamente o motivo de existirem.
                                model: [
                                    { c: Theme.accent,  v: "" },
                                    { c: Theme.accent2, v: String(Theme.accent2) },
                                    { c: Theme.fg,      v: String(Theme.fg) },
                                    { c: Theme.ok,      v: String(Theme.ok) },
                                    { c: Theme.err,     v: String(Theme.err) }
                                ]

                                delegate: Rectangle {
                                    id: amostra
                                    required property var modelData
                                    readonly property bool marcado:
                                        PraxeConfig.dockTintaCor === amostra.modelData.v

                                    implicitWidth: Math.round(20 * Theme.scale)
                                    implicitHeight: implicitWidth
                                    radius: width / 2
                                    color: amostra.modelData.c
                                    border.width: amostra.marcado ? 2 : 1
                                    border.color: amostra.marcado
                                                  ? PraxeConfig.colFg : PraxeConfig.colDim
                                    Behavior on border.color { ColorAnimation { duration: 130 } }

                                    // Furo no meio da primeira: sinaliza
                                    // "sem cor própria, segue o tema" sem
                                    // precisar de legenda ao lado.
                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: amostra.modelData.v === ""
                                        width: parent.width * 0.34
                                        height: width
                                        radius: width / 2
                                        color: PraxeConfig.colBgPuro
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.ajustar("dockTintaCor",
                                                                amostra.modelData.v)
                                    }
                                }
                            }
                        }
                    }

                    // Adequação ao tema.
                    //
                    // NÃO fica sob `dockTinta > 0` como os dois de cima: é
                    // eixo independente. A tinta mexe na matiz; isto mexe em
                    // brilho e saturação. Dá para querer ícones discretos sem
                    // querer ícones dourados — e é o caso mais comum.
                    Linha {
                        rotulo: Idioma.t("dock.adapt")
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1

                        RowLayout {
                            spacing: Math.round(5 * Theme.scale)

                            Repeater {
                                model: [
                                    { r: "Original", v: "original" },
                                    { r: "Suave",    v: "suave"    },
                                    { r: "Escuro",   v: "escuro"   },
                                    { r: "Mono",     v: "mono"     }
                                ]

                                delegate: Rectangle {
                                    id: chipAdeq
                                    required property var modelData
                                    readonly property bool marcado:
                                        PraxeConfig.dockAdequacao === chipAdeq.modelData.v

                                    implicitWidth: rotuloAdeq.implicitWidth
                                                 + Math.round(14 * Theme.scale)
                                    implicitHeight: Math.round(22 * Theme.scale)
                                    radius: height / 2
                                    color: chipAdeq.marcado
                                           ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                                     PraxeConfig.colFg.b, 0.10)
                                           : "transparent"
                                    border.width: 1
                                    border.color: chipAdeq.marcado
                                                  ? PraxeConfig.colAccent : PraxeConfig.colDim
                                    Behavior on border.color { ColorAnimation { duration: 130 } }
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    Text {
                                        id: rotuloAdeq
                                        anchors.centerIn: parent
                                        text: chipAdeq.modelData.r
                                        color: chipAdeq.marcado
                                               ? PraxeConfig.colFg : PraxeConfig.colMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                        Behavior on color { ColorAnimation { duration: 130 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.ajustar("dockAdequacao",
                                                                chipAdeq.modelData.v)
                                    }
                                }
                            }
                        }
                    }

                    // Piso em 10, e não 0: zero é o que "Original" já faz,
                    // e ter dois caminhos para o mesmo resultado só confunde
                    // — some do preset e ninguém sabe por quê.
                    Linha {
                        rotulo: Idioma.t("vivid.strength")
                        visible: PraxeConfig.dockAdequacao !== "original"
                        opacity: PraxeConfig.dock === "off" ? 0.4 : 1
                        Passo {
                            valor: PraxeConfig.dockAdequacaoForca
                            onMenos: root.ajustar("dockAdequacaoForca",
                                                  Math.max(10, PraxeConfig.dockAdequacaoForca - 10))
                            onMais:  root.ajustar("dockAdequacaoForca",
                                                  Math.min(100, PraxeConfig.dockAdequacaoForca + 10))
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: PraxeConfig.dock === "off"
                              ? Idioma.t("dock.off.desc")
                              : Idioma.t("dock.pin.hint") + " " +
                                (PraxeConfig.dockFavoritos.length === 0
                                 ? Idioma.t("dock.pin.none")
                                 : Idioma.tf("dock.pin.count", PraxeConfig.dockFavoritos.length)) +
                                " " + Idioma.t("dock.trash.hint")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Separador {}

                    Titulo { text: Idioma.t("transp.title") }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Idioma.t("transp.desc")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    // ── Clima ────────────────────────────────────────
                    Titulo { text: Idioma.t("weather.title") }

                    Linha {
                        rotulo: Idioma.t("weather.city")

                        Rectangle {
                            implicitWidth: Math.round(160 * Theme.scale)
                            implicitHeight: Math.round(24 * Theme.scale)
                            radius: Theme.raioP
                            color: Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                           PraxeConfig.colFg.b, 0.06)
                            border.width: 1
                            border.color: campoCidade.activeFocus
                                          ? PraxeConfig.colAccent : PraxeConfig.colDim
                            Behavior on border.color { ColorAnimation { duration: 130 } }

                            TextInput {
                                id: campoCidade
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(8 * Theme.scale)
                                anchors.rightMargin: Math.round(8 * Theme.scale)
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                color: PraxeConfig.colFg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1

                                // Enter confirma: o rice-clima faz o geocoding
                                // e grava cidade, lat e lon de uma vez. Digitar
                                // sem confirmar não muda nada, então dá para
                                // desistir no meio sem estragar o que estava lá.
                                onAccepted: if (text.trim() !== "")
                                    root.rodar([PraxeConfig.bin + "rice-clima",
                                                "definir", text.trim()])

                                // Esc precisa continuar fechando o painel.
                                //
                                // Um TextInput com foco CONSOME o Esc, e o
                                // `Keys.onEscapePressed` que fecha a island
                                // (shell.qml) deixava de receber — bastava ter
                                // clicado no campo uma vez para o Esc parar de
                                // funcionar no painel inteiro.
                                //
                                // Aqui ele desfaz a edição, larga o foco e
                                // deixa o evento seguir, em vez de morrer no
                                // campo. Fechar o painel é decisão de quem
                                // sabe o que está aberto, não deste campo.
                                Keys.onEscapePressed: {
                                    text = PraxeConfig.weatherCidade
                                    focus = false
                                    root.fechar()
                                }

                                // O texto NÃO é binding.
                                //
                                // Um `text: PraxeConfig.weatherCidade` quebraria
                                // na primeira tecla digitada — é assim que o QML
                                // funciona — e nunca mais voltaria a acompanhar.
                                // Com o Connections o campo se atualiza quando a
                                // cidade muda por fora (pelo CLI, por exemplo),
                                // mas só se você não estiver digitando nele.
                                Component.onCompleted: text = PraxeConfig.weatherCidade

                                Connections {
                                    target: PraxeConfig
                                    function onWeatherCidadeChanged() {
                                        if (!campoCidade.activeFocus)
                                            campoCidade.text = PraxeConfig.weatherCidade
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Idioma.t("weather.hint")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Linha {
                        rotulo: Idioma.t("weather.onbar")
                        Chave {
                            ligado: PraxeConfig.showWeather
                            onAlternado: root.ajustar("showWeather",
                                                      PraxeConfig.showWeather ? "false" : "true")
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("weather.oncapsule")
                        Chave {
                            ligado: PraxeConfig.showWeatherFilete
                            onAlternado: root.ajustar("showWeatherFilete",
                                          PraxeConfig.showWeatherFilete ? "false" : "true")
                        }
                    }

                    Separador {}

                    // Um par por elemento: interruptor e intensidade lado a
                    // lado, na mesma linha do que ele afeta.
                    //
                    // Antes era um interruptor global mais duas intensidades,
                    // e "Barra e painéis" valia também para o dock — os três
                    // liam o mesmo colBg. Quem quisesse o dock opaco e o pill
                    // translúcido não tinha como.
                    //
                    // A intensidade fica esmaecida, e não escondida, quando o
                    // interruptor está desligado: some da tela é como se
                    // aprende que a opção não existe.
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: Idioma.t("transp.each")
                        color: PraxeConfig.colMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 3
                    }

                    Linha {
                        rotulo: Idioma.t("bar.shape.pill")
                        RowLayout {
                            spacing: Math.round(8 * Theme.scale)
                            Chave {
                                ligado: PraxeConfig.pillTransp
                                onAlternado: root.ajustar("pillTransp",
                                              PraxeConfig.pillTransp ? "false" : "true")
                            }
                            Passo {
                                opacity: PraxeConfig.pillTransp ? 1 : 0.4
                                valor: Math.round(PraxeConfig.opacidadePill * 100)
                                onMenos: if (PraxeConfig.pillTransp)
                                    root.ajustar("pillOpacidade",
                                        Math.max(0.30, PraxeConfig.opacidadePill - 0.05).toFixed(2))
                                onMais: if (PraxeConfig.pillTransp)
                                    root.ajustar("pillOpacidade",
                                        Math.min(1.00, PraxeConfig.opacidadePill + 0.05).toFixed(2))
                            }
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("transp.panels")
                        RowLayout {
                            spacing: Math.round(8 * Theme.scale)
                            Chave {
                                ligado: PraxeConfig.paineisTransp
                                onAlternado: root.ajustar("paineisTransp",
                                              PraxeConfig.paineisTransp ? "false" : "true")
                            }
                            Passo {
                                opacity: PraxeConfig.paineisTransp ? 1 : 0.4
                                valor: Math.round(PraxeConfig.opacidadePainel * 100)
                                onMenos: if (PraxeConfig.paineisTransp)
                                    root.ajustar("paineisOpacidade",
                                        Math.max(0.30, PraxeConfig.opacidadePainel - 0.05).toFixed(2))
                                onMais: if (PraxeConfig.paineisTransp)
                                    root.ajustar("paineisOpacidade",
                                        Math.min(1.00, PraxeConfig.opacidadePainel + 0.05).toFixed(2))
                            }
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("transp.dock")
                        RowLayout {
                            spacing: Math.round(8 * Theme.scale)
                            Chave {
                                ligado: PraxeConfig.dockTransp
                                onAlternado: root.ajustar("dockTransp",
                                              PraxeConfig.dockTransp ? "false" : "true")
                            }
                            Passo {
                                opacity: PraxeConfig.dockTransp ? 1 : 0.4
                                valor: Math.round(PraxeConfig.opacidadeDock * 100)
                                onMenos: if (PraxeConfig.dockTransp)
                                    root.ajustar("dockOpacidade",
                                        Math.max(0.30, PraxeConfig.opacidadeDock - 0.05).toFixed(2))
                                onMais: if (PraxeConfig.dockTransp)
                                    root.ajustar("dockOpacidade",
                                        Math.min(1.00, PraxeConfig.opacidadeDock + 0.05).toFixed(2))
                            }
                        }
                    }

                    // Janelas continua global: não é elemento do rice, e quem
                    // aplica é o Hyprland (opacity.lua), não o Quickshell.
                    Linha {
                        rotulo: Idioma.t("transp.windows")
                        RowLayout {
                            spacing: Math.round(8 * Theme.scale)
                            Chave {
                                ligado: PraxeConfig.transparencia
                                onAlternado: root.ajustar("transparencia",
                                              PraxeConfig.transparencia ? "false" : "true")
                            }
                            Passo {
                                opacity: PraxeConfig.transparencia ? 1 : 0.4
                                valor: Math.round(PraxeConfig.opacidadeJanelas * 100)
                                onMenos: if (PraxeConfig.transparencia)
                                    root.ajustar("opacidadeJanelas",
                                        Math.max(0.60, PraxeConfig.opacidadeJanelas - 0.02).toFixed(2))
                                onMais: if (PraxeConfig.transparencia)
                                    root.ajustar("opacidadeJanelas",
                                        Math.min(1.00, PraxeConfig.opacidadeJanelas + 0.02).toFixed(2))
                            }
                        }
                    }

                    Separador {}

                    Titulo { text: Idioma.t("notif.title") }

                    Linha {
                        rotulo: Idioma.t("notif.marker.ideogram")
                        Chave {
                            ligado: PraxeConfig.simbolos === "kanji"
                            onAlternado: root.ajustar("simbolos",
                                PraxeConfig.simbolos === "kanji" ? "nerd" : "kanji")
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: PraxeConfig.simbolos === "kanji"
                              ? Idioma.t("notif.marker.ideogram.desc")
                              : Idioma.t("notif.marker.round")
                        color: PraxeConfig.colMuted
                        font.family: PraxeConfig.simbolos === "kanji"
                                     ? Notificacoes.fonteMarcador : Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    Separador {}

                    Titulo { text: Idioma.t("bar.shape") }

                    Linha {
                        rotulo: Idioma.t("bar.rounding")
                        Passo {
                            valor: PraxeConfig.barRadius
                            onMenos: root.ajustar("barRadius", Math.max(0, PraxeConfig.barRadius - 2))
                            onMais:  root.ajustar("barRadius", Math.min(40, PraxeConfig.barRadius + 2))
                        }
                    }

                    Linha {
                        rotulo: Idioma.t("bar.edge")
                        Passo {
                            valor: PraxeConfig.margin
                            onMenos: root.ajustar("margin", Math.max(0, PraxeConfig.margin - 1))
                            onMais:  root.ajustar("margin", Math.min(40, PraxeConfig.margin + 1))
                        }
                    }
                }
            }

            // ═══ Aba 5: Ícones ══════════════════════════════════
            Flickable {
                contentHeight: colIco.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: colIco
                    width: parent.width
                    spacing: Math.round(7 * Theme.scale)

                    Titulo { text: Idioma.t("icons.theme") }

                    Repeater {
                        model: root.icones
                        delegate: Rectangle {
                            id: cartaoIco
                            required property var modelData
                            readonly property bool atual: cartaoIco.modelData.id === root.iconeAtual

                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(32 * Theme.scale)
                            radius: Theme.raioM
                            color: cartaoIco.atual
                                   ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                             PraxeConfig.colFg.b, 0.08)
                                   : (areaIco.containsMouse
                                      ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                                PraxeConfig.colFg.b, 0.05)
                                      : "transparent")
                            border.width: 1
                            border.color: cartaoIco.atual ? PraxeConfig.colAccent : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Math.round(10 * Theme.scale)
                                anchors.rightMargin: Math.round(10 * Theme.scale)
                                spacing: Math.round(8 * Theme.scale)

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: cartaoIco.modelData.nome !== ""
                                          ? cartaoIco.modelData.nome : cartaoIco.modelData.id
                                    color: PraxeConfig.colFg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                Text {
                                    text: "󰄲"
                                    visible: cartaoIco.atual
                                    color: PraxeConfig.colAccent
                                    font.family: Theme.nerdFontFamily
                                    font.pixelSize: Math.round(12 * Theme.scale)
                                }
                            }

                            MouseArea {
                                id: areaIco
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.rodar([PraxeConfig.bin + "rice-icons",
                                                "aplicar", cartaoIco.modelData.id])
                                    root.iconeAtual = cartaoIco.modelData.id
                                }
                            }
                        }
                    }

                    Separador {}

                    // Cor das pastas: monta um tema que herda o Papirus e
                    // só troca a cor da pasta. É o ajuste que mais muda a
                    // cara do gerenciador de arquivos por menos esforço.
                    //
                    // O primeiro chip é "auto", e é ele o padrão: cada tema
                    // já declara a sua cor de pasta (PASTAS=), escolhida
                    // junto com a paleta. Escolher uma cor aqui é FIXAR —
                    // a partir daí ela sobrevive à troca de tema, o que é
                    // útil e é também como se chega, sem querer, a um
                    // desktop teal com pastas azuis.
                    Titulo { text: Idioma.t("icons.folders") }

                    Nota {
                        visible: !root.pastasRecoloriveis
                        // `tf` e não concatenação: em inglês o nome do tema
                        // cai em outra posição da frase, e juntar pedaços
                        // traduzidos com pedaços fixos produz ordem errada.
                        text: Idioma.tf("icons.folders.unavailable", root.iconeAtual)
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Math.round(6 * Theme.scale)

                        // `enabled` propaga para os filhos, então desligar aqui
                        // já basta para as MouseArea dos chips pararem de aceitar
                        // clique — não adianta só apagar com opacidade, que
                        // deixaria botões mortos ainda clicáveis.
                        enabled: root.pastasRecoloriveis
                        opacity: root.pastasRecoloriveis ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 140 ; easing.type: Theme.curva } }

                        Rectangle {
                            id: chipAuto
                            readonly property bool atual: PraxeConfig.folderColor === ""
                                                          || PraxeConfig.folderColor === "auto"

                            width: Math.round(62 * Theme.scale)
                            height: Math.round(24 * Theme.scale)
                            radius: Theme.raioP
                            color: areaAuto.containsMouse
                                   ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                             PraxeConfig.colFg.b, 0.06)
                                   : "transparent"
                            border.width: 1
                            border.color: chipAuto.atual ? PraxeConfig.colAccent : PraxeConfig.colDim
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.fill: parent
                                anchors.margins: Math.round(4 * Theme.scale)
                                text: Idioma.t("icons.folders.auto")
                                color: chipAuto.atual ? PraxeConfig.colAccent : PraxeConfig.colMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 4
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: areaAuto
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Um único comando de propósito: `rodar` reusa
                                // um só Process, então duas chamadas seguidas
                                // fazem a segunda atropelar a primeira antes de
                                // ela terminar. Encadear no shell é o que
                                // garante que as duas aconteçam, e nesta ordem —
                                // desfixar primeiro, reaplicar o tema depois.
                                onClicked: {
                                    root.rodar(["bash", "-c",
                                        PraxeConfig.bin + "rice-pill set folderColor '' && " +
                                        PraxeConfig.bin + "rice-theme set \"$(" +
                                        PraxeConfig.bin + "rice-theme current)\""])
                                }
                            }
                        }

                        Repeater {
                            model: root.coresPasta
                            delegate: Rectangle {
                                id: chipCor
                                required property string modelData
                                readonly property bool atual: chipCor.modelData === PraxeConfig.folderColor

                                width: Math.round(62 * Theme.scale)
                                height: Math.round(24 * Theme.scale)
                                radius: Theme.raioP
                                color: areaCor.containsMouse
                                       ? Qt.rgba(PraxeConfig.colFg.r, PraxeConfig.colFg.g,
                                                 PraxeConfig.colFg.b, 0.06)
                                       : "transparent"
                                border.width: 1
                                border.color: chipCor.atual ? PraxeConfig.colAccent : PraxeConfig.colDim
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: Math.round(4 * Theme.scale)
                                    text: chipCor.modelData
                                    color: chipCor.atual ? PraxeConfig.colAccent : PraxeConfig.colMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 4
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: areaCor
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    // Estas três coisas eram duas chamadas a
                                    // `rodar` — e como ele reusa um só Process,
                                    // a segunda cancelava a primeira: o clique
                                    // gravava a cor no pill.json e nunca chegava
                                    // a montar o tema. Some-se a isso que o
                                    // rice-folders montava sem aplicar, e o
                                    // resultado era um seletor que não mudava
                                    // nada na tela.
                                    onClicked: {
                                        root.rodar(["bash", "-c",
                                            PraxeConfig.bin + "rice-pill set folderColor " +
                                            chipCor.modelData + " && " +
                                            PraxeConfig.bin + "rice-folders " +
                                            chipCor.modelData + " aplicar"])
                                    }
                                }
                            }
                        }
                    }

                    Separador {}

                    Linha {
                        rotulo: Idioma.t("icons.install")
                        BotaoRedondo {
                            glifo: root.mostrarLojaIcones ? "󰅃" : "󰅀"
                            onAcionado: root.mostrarLojaIcones = !root.mostrarLojaIcones
                        }
                    }

                    Repeater {
                        model: root.mostrarLojaIcones ? root.lojaIcones : []
                        delegate: ItemLoja {
                            id: li
                            required property var modelData
                            nome: li.modelData.nome
                            desc: li.modelData.desc
                            instalado: li.modelData.instalado
                            onInstalar: root.rodar([PraxeConfig.bin + "rice-icons",
                                                    "instalar", li.modelData.pkg])
                        }
                    }
                }
            }
        }
    }
}
