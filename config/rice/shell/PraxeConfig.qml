// Configuração da barra, lida de ~/.config/rice/pill.json.
//
// O arquivo é observado: salvou, a barra muda na hora — não precisa
// reiniciar nada. Se o arquivo não existir ou faltar uma chave, valem
// os padrões declarados no JsonAdapter abaixo.
//
//   layout      "pill"  cápsula flutuante centralizada
//               "bar"   barra de ponta a ponta na tela
//   position    "top" | "bottom"
//   sideMargin  só afeta o modo "bar": respiro nas laterais
//
// Exemplo mínimo de pill.json: uma linha com layout igual a "bar"
// e position igual a "bottom" já basta.
//
// CUIDADO AO EDITAR ESTE CABEÇALHO: o Quickshell descobre o objeto raiz
// contando chaves e NÃO pula comentários. Uma chave de abertura dentro
// de um comentário faz o singleton inteiro deixar de existir, sem erro
// nenhum no log — as propriedades só chegam como undefined. Por isso
// não há chaves nos comentários deste arquivo.
//
// Nota de implementação: usamos *bindings* com fallback (?? valor) em
// vez de `property alias`. O alias é resolvido na criação do componente
// e fica preso em undefined enquanto o arquivo não chegou; o binding
// reavalia quando o FileView termina de carregar.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick   // necessário para o tipo `color` e para Qt.rgba/Qt.color

Singleton {
    id: root

    // ── Pastas do usuário ───────────────────────────────────────
    //
    // O nome da pasta de imagens NÃO é escolha do rice: é `Pictures`,
    // `Imagens`, `Bilder`... conforme o locale de quando a conta foi
    // criada. Quem decide é o xdg-user-dirs, que grava a resposta em
    // ~/.config/user-dirs.dirs — este arquivo é a fonte de verdade.
    //
    // Aqui estava cravado "/Imagens/Wallpapers". Numa conta en_US, como
    // esta, o sistema pedia `Pictures` e o rice criava uma `Imagens`
    // paralela: os papéis e os prints iam para a pasta errada e a do
    // sistema ficava vazia. O equivalente em shell está no rice-pastas.sh,
    // com a explicação longa.
    FileView {
        id: pastasXdg
        path: Quickshell.env("HOME") + "/.config/user-dirs.dirs"
        // Síncrono na subida pelo mesmo motivo do pill.json abaixo: é
        // caminho de arquivo, e resolver tarde faria o seletor de papéis
        // abrir apontando para o lugar errado.
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // Lê uma chave do user-dirs.dirs. O formato é uma linha por pasta:
    //   XDG_PICTURES_DIR="$HOME/Pictures"
    // com aspas e `$HOME` literal — daí a substituição na volta.
    //
    // Devolve "" quando não encontra, para o chamador decidir a reserva:
    // devolver $HOME aqui faria os papéis caírem soltos na raiz da conta.
    function pastaXdg(chave) {
        const texto = pastasXdg.text()
        if (!texto) return ""
        const m = texto.match(new RegExp("^\\s*XDG_" + chave + "_DIR\\s*=\\s*\"([^\"]*)\"", "m"))
        if (!m) return ""
        return m[1].replace("$HOME", Quickshell.env("HOME"))
    }

    readonly property string pastaImagens: {
        const d = pastaXdg("PICTURES")
        return d !== "" ? d : Quickshell.env("HOME") + "/Pictures"
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/rice/pill.json"
        watchChanges: true
        onFileChanged: reload()

        // Leitura SÍNCRONA na subida: sem isto o primeiro quadro é
        // desenhado com os PADRÕES daqui de baixo e o pill.json chega um
        // instante depois, o que faz a barra piscar na forma errada.
        //
        // NÃO conte com isto para propriedades que o Quickshell
        // compromete uma vez só com o compositor (as `margins` da
        // PanelWindow são o caso conhecido). Foi tentado para consertar a
        // margem do notch e NÃO bastou — a superfície de layer já tinha
        // sido criada. Ver a nota longa no shell.qml, onde o problema foi
        // resolvido de outro jeito.
        blockLoading: true

        JsonAdapter {
            id: cfg

            property string layout: "pill"
            // "top" | "bottom" | "left" | "right"
            property string position: "top"

            property real scale: 1.0
            property int margin: 6          // distância da borda da tela
            property int gap: 4             // respiro entre a barra e as janelas
            property int sideMargin: 12
            property int barRadius: 14

            // Como a barra se comporta perante as janelas:
            //   "always"   sempre visível, reservando espaço
            //   "compact"  cápsula pequena com logo e relógio, abre no hover
            //   "hover"    encolhe num filete e cresce ao passar o mouse
            property string reveal: "always"

            // Flutuar por cima das janelas em vez de reservar espaço.
            //   "auto"  pill flutua, barra reserva — o padrão
            //   "sim"   sempre por cima
            //   "nao"   sempre reservando
            property string overlap: "auto"

            // "lista" ou "grade" — como o lançador exibe os apps
            property string launcherView: "lista"

            // Pasta oficial: é para cá que os papéis são adotados.
            //
            // Vazio = "siga o sistema", que é o padrão e o que quase todo
            // mundo quer. O caminho de verdade é montado em
            // `wallpaperDir` lá embaixo, a partir da pasta de imagens do
            // xdg-user-dirs. Cravar aqui foi o que criou a `~/Imagens`
            // paralela — ver a nota em `pastasXdg`.
            property string wallpaperDir: ""

            // Pastas extras que o seletor também mostra. Escolher uma
            // imagem daqui COPIA para a pasta oficial antes de aplicar.
            // Separe por dois-pontos, como um PATH.
            // Vazio = Downloads + a pasta de imagens do sistema.
            property string wallpaperExtras: ""

            // Quantos pontos de área de trabalho ficam SEMPRE à vista,
            // mesmo vazios. É um piso, não um teto: ir para uma área acima
            // deste número faz a fileira crescer e a cápsula acompanhar.
            // Ver a nota em Workspaces.qml.
            property int workspaces: 5
            property string clockFormat: "HH:mm"

            property bool showMenuDot: true
            property bool showWorkspaces: true
            property bool showMedia: true
            property bool showResources: true
            property bool showVolume: true
            property bool showClock: true

            // Cores só da barra. Vazio = usa a cor do tema atual.
            // Serve para destoar a barra do resto de propósito, sem
            // precisar criar um tema novo. Ex.: "barBg": "#101010cc"
            // Tema automático a partir do papel de parede.
            //
            // DESLIGADO por padrão, de propósito: ligado, escolher um papel
            // SUBSTITUI o tema em vigor — e quem só queria trocar a imagem
            // perderia a paleta que ajustou à mão, sem ter pedido nada.
            // Ligar é uma escolha; perder trabalho não pode ser o padrão.
            property bool autoTema: false

            property string barBg: ""
            property string barBorder: ""
            property string barFg: ""
            property string barAccent: ""
            property string barMuted: ""
            property string barDim: ""
            property real barOpacity: -1

            // ── Transparência ──────────────────────────────────────
            // Desligada por padrão de propósito: transparência é gosto,
            // e ligar sozinho é decidir pelo usuário. Quando ligada,
            // vale para a barra, os painéis, o terminal e as janelas.
            // Transparência das JANELAS. Continua global e continua saindo
            // daqui para o Hyprland (opacity.lua/windows.lua, escritos pelo
            // rice-theme) — não é elemento do rice, é o resto da tela.
            property bool transparencia: false
            property real opacidadeJanelas: 0.94

            // Transparência POR ELEMENTO do rice.
            //
            // Antes era um interruptor global mais duas intensidades, e a
            // dos "painéis" acabava valendo para o pill e o dock também,
            // porque os três liam o mesmo colBg. Agora cada um tem o seu
            // par, e o colBg virou cor pura — quem quer alpha compõe.
            //
            // Os padrões abaixo repetem o comportamento antigo, então
            // ninguém perde ajuste na migração: herdam de opacidadePaineis
            // e do interruptor global, que continuam sendo lidos.
            property real opacidadePaineis: 0.90

            property bool pillTransp: false
            property real pillOpacidade: 0.90
            property bool dockTransp: false
            property real dockOpacidade: 0.90
            property bool paineisTransp: false
            property real paineisOpacidade: 0.90

            // Marcador das notificações: "nerd" usa o glifo da fonte,
            // "kanji" usa um ideograma escolhido pela urgência.
            property string simbolos: "nerd"

            // ── Dock ───────────────────────────────────────────────
            // "off" | "always" | "hover". Os favoritos guardam o id do
            // .desktop; o rice-dock é quem escreve nesta lista.
            property string dock: "hover"
            property int dockTamanho: 44
            property list<string> dockFavoritos: []

            // Quanto os ícones do dock puxam para uma cor só, 0..100.
            // Preserva a luminância, então o desenho continua legível — é
            // harmonização, não pintura por cima. 0 desliga.
            //
            // DESLIGADA por padrão: pintar por cima do ícone alheio nunca
            // fica tão bom quanto um pacote de ícones que já nasceu na
            // paleta certa. O caminho oficial é o tema de ícones que cada
            // tema do rice indica; isto aqui ficou como escape para quem
            // usar um pacote que não combina com nada.
            property int dockTinta: 0

            // Cor da tinta. Vazio acompanha o acento do tema, que é o que
            // faz o dock seguir a troca de tema sem ninguém mexer aqui.
            property string dockTintaCor: ""

            // Adequação dos ícones ao tema: "original", "suave", "escuro"
            // ou "mono". Mexe em brilho e saturação — não confundir com
            // dockTinta/dockTintaCor, que mexem na MATIZ. Ver a nota longa
            // em Dock.qml (satIcone).
            property string dockAdequacao: "original"

            // O quanto do preset aplicar, 0..100. Cheio por padrão: quem
            // escolhe um preset quer vê-lo, e daí regula para baixo.
            property int dockAdequacaoForca: 100

            // Lixeira na ponta direita do dock.
            property bool dockLixeira: true

            // Realce de cor da tela, 0..100. Aplicado por um shader do
            // Hyprland; quem escreve é o rice-vivido.
            property int vivido: 25

            // Tema de ícones e cor das pastas (geridos pelo rice-icons)
            property string iconTheme: ""
            property string folderColor: ""

            // Clima. A cidade é só rótulo, para você reconhecer o que
            // escolheu; quem a API consulta são a lat/lon. Guardamos as
            // três para não depender de refazer geocoding a cada consulta.
            //
            // Vazias por padrão: sem local escolhido o módulo não aparece,
            // em vez de assumir uma cidade que não é a sua.
            property bool   showWeather: true
            // Clima também na cápsula FECHADA, ao lado da hora.
            property bool   showWeatherFilete: true
            property string weatherCidade: ""
            property string weatherLat: ""
            property string weatherLon: ""
        }
    }

    readonly property bool   autoTema:    cfg.autoTema    ?? false
    readonly property string layout:      cfg.layout      ?? "pill"
    readonly property string position:    cfg.position    ?? "top"
    readonly property real   scale:       cfg.scale       ?? 1.0
    readonly property int    margin:      cfg.margin      ?? 6
    readonly property int    gap:         cfg.gap         ?? 4
    readonly property string reveal:      cfg.reveal      ?? "always"
    readonly property string overlapModo: cfg.overlap ?? "auto"
    // A cápsula solta pede para flutuar: ela é pequena e o espaço
    // reservado ficaria maior que ela. A barra de ponta a ponta é o
    // contrário — vira moldura da tela, então reserva.
    readonly property bool   overlap:     overlapModo === "sim" ? true
                                        : overlapModo === "nao" ? false
                                        : isPill
    readonly property bool   autoHide:    reveal === "hover"
    readonly property bool   compacto:    reveal === "compact"
    readonly property int    sideMargin:  cfg.sideMargin  ?? 12
    readonly property int    barRadius:   cfg.barRadius   ?? 14
    readonly property string launcherView: cfg.launcherView ?? "lista"
    // `||` e não `??`: aqui string VAZIA também significa "siga o
    // sistema", e `??` só cobre null/undefined — um "" no pill.json
    // passaria direto e o seletor abriria numa pasta sem nome.
    readonly property string wallpaperDir:
        (cfg.wallpaperDir || "") !== "" ? cfg.wallpaperDir
                                        : root.pastaImagens + "/Wallpapers"

    readonly property string wallpaperExtras:
        (cfg.wallpaperExtras || "") !== "" ? cfg.wallpaperExtras
                                           : Quickshell.env("HOME") + "/Downloads:"
                                             + root.pastaImagens
    readonly property int    workspaces:  cfg.workspaces  ?? 5
    readonly property string clockFormat: cfg.clockFormat ?? "HH:mm"

    readonly property bool showMenuDot:    cfg.showMenuDot    ?? true
    readonly property bool showWorkspaces: cfg.showWorkspaces ?? true
    readonly property bool showMedia:      cfg.showMedia      ?? true
    readonly property bool showResources:  cfg.showResources  ?? true
    readonly property bool showVolume:     cfg.showVolume     ?? true
    readonly property bool showClock:      cfg.showClock      ?? true

    readonly property int    vivido:       cfg.vivido       ?? 25
    readonly property string dock:         cfg.dock         ?? "hover"
    readonly property int    dockTamanho:  cfg.dockTamanho  ?? 44
    readonly property var    dockFavoritos: cfg.dockFavoritos ?? []
    readonly property int    dockTinta:     cfg.dockTinta     ?? 0
    readonly property string dockTintaCor:  cfg.dockTintaCor  ?? ""
    readonly property string dockAdequacao:      cfg.dockAdequacao      ?? "original"
    readonly property int    dockAdequacaoForca: cfg.dockAdequacaoForca ?? 100
    readonly property bool   dockLixeira:   cfg.dockLixeira   ?? true
    readonly property bool   transparencia:    cfg.transparencia    ?? false
    readonly property real   opacidadeJanelas: cfg.opacidadeJanelas ?? 0.94
    // Sem transparência ligada, o painel é opaco — 1.0, não o valor guardado.
    readonly property real   opacidadePaineis: transparencia
                                             ? (cfg.opacidadePaineis ?? 0.90) : 1.0
    readonly property string simbolos:    cfg.simbolos    ?? "nerd"
    readonly property string iconTheme:   cfg.iconTheme   ?? ""
    readonly property string folderColor: cfg.folderColor ?? ""

    readonly property bool   showWeather:       cfg.showWeather       ?? true
    readonly property bool   showWeatherFilete: cfg.showWeatherFilete ?? true
    readonly property string weatherCidade: cfg.weatherCidade ?? ""
    readonly property string weatherLat:    cfg.weatherLat    ?? ""
    readonly property string weatherLon:    cfg.weatherLon    ?? ""

    readonly property bool isPill: layout !== "bar"

    // Notch: a cápsula colada na borda de cima, cantos superiores retos e
    // só os de baixo arredondados — pendurada na tela em vez de flutuando.
    // Continua sendo `isPill` para toda a lógica de forma e colapso; o que
    // muda é a margem (zero) e o raio dos cantos de cima.
    readonly property bool isNotch: layout === "notch"
    // Caminho absoluto dos nossos scripts.
    //
    // A barra NÃO pode depender do PATH herdado: dependendo de como o
    // processo sobe, ele chega com apenas /usr/bin e todo botão que
    // chama rice-* falha em silêncio, sem erro visível na tela.
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool atTop:    position === "top"
    readonly property bool atBottom: position === "bottom"
    readonly property bool atLeft:   position === "left"
    readonly property bool atRight:  position === "right"

    // ── Cores em vigor ──────────────────────────────────────────
    // O que estiver preenchido em pill.json vence o tema; o resto cai
    // no Theme.qml. É assim que a barra pode ter identidade própria
    // sem obrigar o usuário a manter um tema separado só para isso.
    function _ou(valor, padrao) {
        return (valor !== undefined && valor !== null && valor !== "") ? valor : padrao
    }

    readonly property color colBg: {
        const base = _ou(cfg.barBg, Theme.pillBg)
        let o = cfg.barOpacity ?? -1
        // barOpacity explícito manda; senão vale a transparência global
        if (o < 0 && transparencia) o = cfg.opacidadePaineis ?? 0.90
        if (o < 0) return base
        const c = Qt.color(base)
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, o)))
    }
    // ── Transparência por elemento ──────────────────────────────
    //
    // Cada elemento tem interruptor e intensidade próprios. Desligado, a
    // opacidade é 1.0 — opaco de verdade, e não "a intensidade guardada",
    // para o interruptor ter efeito visível sozinho.
    //
    // A migração lê as chaves ANTIGAS como padrão: quem já tinha
    // transparência ligada com 0.90 continua exatamente igual, sem
    // precisar reconfigurar os três.
    function _transp(chaveLiga, chaveOpac) {
        const liga = cfg[chaveLiga] ?? (cfg.transparencia ?? false)
        if (!liga) return 1.0
        const o = cfg[chaveOpac] ?? cfg.opacidadePaineis ?? 0.90
        return Math.max(0, Math.min(1, o))
    }

    // Os interruptores precisam existir como propriedade, e não só como
    // chave no cfg: é `PraxeConfig.pillTransp` que o Chave do painel lê
    // para saber se acende. Sem isto ele vale `undefined`, o botão nunca
    // muda de estado e o `undefined ? "false" : "true"` grava sempre true.
    //
    // O padrão herda do interruptor global antigo, igual ao `_transp`.
    readonly property bool pillTransp:    cfg.pillTransp    ?? (cfg.transparencia ?? false)
    readonly property bool dockTransp:    cfg.dockTransp    ?? (cfg.transparencia ?? false)
    readonly property bool paineisTransp: cfg.paineisTransp ?? (cfg.transparencia ?? false)

    readonly property real opacidadePill:   _transp("pillTransp",    "pillOpacidade")
    readonly property real opacidadeDock:   _transp("dockTransp",    "dockOpacidade")
    readonly property real opacidadePainel: _transp("paineisTransp", "paineisOpacidade")

    // A cor de fundo SEM alpha. Quem precisa só da matiz — uma borda, o
    // furo da amostra de cor — usa esta e não pega transparência junto.
    readonly property color colBgPuro: Qt.color(_ou(cfg.barBg, Theme.pillBg))

    function _comAlpha(o) {
        const c = colBgPuro
        return Qt.rgba(c.r, c.g, c.b, o)
    }

    // `barOpacity` continua vencendo tudo: é o escape de quem quer um
    // valor cravado no pill.json, independente de interruptor.
    readonly property color colBgPill:
        (cfg.barOpacity ?? -1) >= 0 ? _comAlpha(cfg.barOpacity)
                                    : _comAlpha(opacidadePill)
    readonly property color colBgDock:   _comAlpha(opacidadeDock)
    readonly property color colBgPainel: _comAlpha(opacidadePainel)

    readonly property color colBorder: _ou(cfg.barBorder, Theme.pillBorder)
    readonly property color colFg:     _ou(cfg.barFg,     Theme.fg)

    // Tema claro ou escuro, decidido pela luminância do papel.
    //
    // Sai do FUNDO e não de um campo do tema porque o fundo é o que
    // sempre existe: qualquer tema, inclusive um que você escreva à mão
    // depois, tem `bg`. Um campo "claro: true" seria mais uma coisa para
    // esquecer de preencher.
    //
    // Os pesos são os da luminância perceptual (Rec. 601): o olho lê
    // verde muito mais que azul, então média simples classificaria um
    // azul-marinho como claro.
    readonly property bool temaClaro:
        (0.299 * colBg.r + 0.587 * colBg.g + 0.114 * colBg.b) > 0.5
    readonly property color colAccent: _ou(cfg.barAccent, Theme.accent)
    readonly property color colMuted:  _ou(cfg.barMuted,  Theme.muted)
    readonly property color colDim:    _ou(cfg.barDim,    Theme.dim)
}
