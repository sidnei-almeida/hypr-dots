// Servidor de notificações do PraXe.
//
// Substitui o dunst: quem recebe os avisos do sistema agora é a própria
// island. Guarda um histórico curto, junta repetidas e expõe um modo
// "não perturbe".
//
// CUIDADO: não use chave de abertura em comentário neste arquivo. O
// Quickshell acha o objeto raiz contando chaves e não pula comentários;
// uma chave solta aqui faz o singleton sumir sem erro no log.

pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // Histórico, do mais novo para o mais velho
    property var lista: []
    property int maximo: 20

    // Não perturbe: continua guardando, só não mostra o balão
    property bool silencioso: false

    // A notificação que está aparecendo agora, ou null
    property var atual: null
    property int tempoBalao: 4000

    // Marcador da notificação em ideograma, escolhido pela urgência.
    // Um círculo genérico não diz nada; o ideograma carrega o sentido e
    // combina com a identidade do sistema. wqy-zenhei cobre os três.
    //   微  wēi   discreto   — urgência baixa
    //   知  zhī   ciente     — urgência normal
    //   急  jí    urgente    — urgência crítica
    function marcador(urgencia) {
        if (urgencia === NotificationUrgency.Critical) return "急"
        if (urgencia === NotificationUrgency.Low)      return "微"
        return "知"
    }
    readonly property string fonteMarcador: "WenQuanYi Zen Hei"

    readonly property bool mostrando: atual !== null
    readonly property int quantidade: lista.length

    // Não vistas — contador SEPARADO do tamanho da lista, e é preciso
    // que seja.
    //
    // `quantidade` é o histórico: só esvazia quando alguém aperta limpar.
    // Um marcador ligado a ela acenderia na primeira notificação do dia e
    // não apagaria mais, o que é o mesmo que não ter marcador — pior,
    // porque ensina a ignorá-lo.
    //
    // Isto aqui conta o que chegou DESDE a última vez que a lista foi
    // olhada, e zera quando ela é olhada de verdade (o painel abrir) ou
    // apagada. Silenciado ainda conta: não perturbe é sobre não
    // interromper, não sobre esconder que houve algo.
    property int naoVistas: 0

    // ── Índice id → Notification, FORA do model ─────────────────
    //
    // O objeto da notificação NUNCA pode viver dentro do mapa que vai
    // para o `model`. Ali ele deixa de ser referência de JS e vira valor
    // de QVariantMap — ponteiro cru, sem ninguém avisando quando o alvo
    // morre. Pior: o Qt 6.9 em diante converte esse valor para JS só no
    // instante em que o delegate INCUBA, e não na hora em que a lista foi
    // montada. A conversão de um ponteiro já liberado derruba o
    // Quickshell inteiro, sempre com esta pilha:
    //   QQmlVMEMetaObject::writeKnownVarProperty
    //     -> VariantAssociationPrototype::fromQVariantMap
    //       -> ExecutionEngine::fromData        <- SIGSEGV
    // que é, byte a byte, o coredump de 07, 08, 13, 14 e 16/08 — todos
    // com a ListView de notificações do ControlCenter no meio.
    //
    // O que fecha a janela de risco é `tracked = false` DESTRUIR EM
    // DIFERIDO (deleteLater). A morte não acontece na linha que a pede:
    // acontece na volta seguinte do laço de eventos, quando um refill da
    // ListView já pode estar no ar com a fotografia ANTIGA do model. Foi
    // isso que fez o bug parecer aleatório e sempre colado a "fechei uma
    // janela": qualquer coisa que mude a largura da barra (o Tarefas
    // encolhendo quando um app fecha) força o refill.
    //
    // Reproduzido em 17/08 matando os objetos e alternando o painel logo
    // em seguida: com `objeto` no mapa cai na hora, sem ele aguenta o
    // mesmo teste repetido. Aqui a referência mora num objeto JS comum, e
    // aí ela é um QObjectWrapper do QV4 — que SABE quando o alvo morre. É
    // a mesma diferença entre ponteiro cru e QPointer. Ver a nota longa
    // no Dock.qml, que descreve o mesmo acidente com DesktopEntry.
    property var vivos: ({})

    // Solta UMA notificação pelo id: destrói o objeto e some com a
    // referência. Nunca chame com o item do model em mãos — é o id que
    // manda, porque o item é só texto.
    function soltar(id) {
        const n = vivos[id]
        if (!n) return
        delete vivos[id]
        n.tracked = false
    }

    NotificationServer {
        id: servidor
        keepOnReload: false

        // Sem isto o servidor não anuncia suporte a corpo e ícone,
        // e apps mandam texto cru sem formatação
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: function (n) {
            // `tracked` segura a notificação viva depois do sinal
            n.tracked = true
            root.registrar(n)
        }
    }

    function registrar(n) {
        // SÓ TEXTO E NÚMERO. Nada de `objeto: n` aqui — ver a nota do
        // índice `vivos` lá em cima; foi essa linha que derrubava a barra
        // quando a Steam abria.
        const item = {
            id: n.id,
            app: n.appName ?? "",
            titulo: n.summary ?? "",
            corpo: n.body ?? "",
            imagem: n.image ?? "",
            icone: n.appIcon ?? "",
            urgencia: n.urgency,
            quando: new Date()
        }

        // Id repetido é normal: o `replaces_id` do protocolo reaproveita o
        // número. Se já houver alguém guardado com esse id e não for este
        // objeto, ele é órfão — ninguém mais consegue soltá-lo depois, e
        // ficaria `tracked` para sempre. Solta agora.
        const anterior = vivos[n.id]
        if (anterior && anterior !== n) anterior.tracked = false
        vivos[n.id] = n

        // ORDEM IMPORTA: publica a lista nova ANTES de soltar os velhos.
        //
        // `tracked = false` DESTRÓI a notificação. O model já não guarda
        // ponteiro nenhum, mas o `vivos` guarda, e um binding do painel
        // pode estar lendo por lá no mesmo quadro. Publicar primeiro deixa
        // a lista coerente antes de qualquer objeto sumir.
        const nova = lista.slice()
        nova.unshift(item)
        const soltar = []
        while (nova.length > maximo) soltar.push(nova.pop().id)
        lista = nova
        for (const id of soltar) root.soltar(id)
        naoVistas = naoVistas + 1

        if (!silencioso) {
            atual = item
            relogioBalao.restart()
        }
    }

    // Chamada quando a lista fica à vista (o painel de notificações abre).
    function marcarVistas() { naoVistas = 0 }

    function dispensarAtual() {
        atual = null
        relogioBalao.stop()
    }

    // Esvazia a lista PRIMEIRO, solta os objetos depois — mesma razão da
    // nota em `registrar()`: com a lista já publicada vazia, nenhum
    // binding do painel ainda está olhando para o que vai morrer.
    function limpar() {
        const mortos = lista
        lista = []
        dispensarAtual()
        for (const it of mortos) root.soltar(it.id)
        naoVistas = 0
    }

    function alternarSilencio() {
        silencioso = !silencioso
        if (silencioso) dispensarAtual()
    }

    Timer {
        id: relogioBalao
        interval: root.tempoBalao
        onTriggered: root.atual = null
    }
}
