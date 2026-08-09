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
        const item = {
            id: n.id,
            app: n.appName ?? "",
            titulo: n.summary ?? "",
            corpo: n.body ?? "",
            imagem: n.image ?? "",
            icone: n.appIcon ?? "",
            urgencia: n.urgency,
            quando: new Date(),
            objeto: n
        }

        // ORDEM IMPORTA: publica a lista nova ANTES de soltar os velhos.
        //
        // `tracked = false` DESTRÓI a notificação. Se ela fosse solta antes
        // do `lista = nova`, existiria um instante em que a lista publicada
        // — que é o model do painel — ainda teria um item cujo `objeto` é
        // ponteiro para memória liberada. Um delegate incubando nesse
        // intervalo derruba o Quickshell inteiro: é o mesmo SIGSEGV em
        // fromQVariantMap que o dock causava (ver a nota longa no Dock.qml).
        //
        // Hoje o intervalo é curto e síncrono, então isso é cinto de
        // segurança e não conserto de bug observado. Mas a ordem certa é
        // de graça, e a errada só dá as caras sob carga.
        const nova = lista.slice()
        nova.unshift(item)
        const soltar = []
        while (nova.length > maximo) {
            const velho = nova.pop()
            if (velho.objeto) soltar.push(velho.objeto)
        }
        lista = nova
        for (const o of soltar) o.tracked = false
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
    // nota em `registrar()`: soltar antes deixaria o painel com ponteiros
    // mortos no model por um instante.
    function limpar() {
        const soltar = lista
        lista = []
        dispensarAtual()
        for (const it of soltar) if (it.objeto) it.objeto.tracked = false
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
