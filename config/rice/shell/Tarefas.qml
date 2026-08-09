// ┌──────────────────────────────────────────────────────────────┐
// │  Os aplicativos abertos, para o modo BARRA.                   │
// └──────────────────────────────────────────────────────────────┘
//
// É o elemento que faltava para a barra ser uma barra: a lista do que
// está aberto, clicável para trazer à frente. No modo cápsula ele não
// aparece — não cabe, e a cápsula nunca se propôs a isso.
//
// ── POR QUE POR APLICATIVO, E NÃO POR JANELA ────────────────────
//
// Uma barra de tarefas clássica lista JANELAS. Aqui lista APLICATIVOS,
// agrupando as janelas de cada um, por dois motivos:
//
//   1. É o que foi pedido ("apps abertos"), e é o que o Windows moderno
//      e o macOS fazem — a janela virou detalhe interno do aplicativo.
//   2. E, principalmente, porque o model precisa ser de STRINGS.
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
// Por isso o `Toplevel` é buscado pelo appId DENTRO do delegate, no
// momento do uso, e nunca guardado no model.

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: raiz

    // Quem manda no tamanho é a fileira lá dentro.
    implicitWidth: fileira.implicitWidth
    implicitHeight: fileira.implicitHeight

    readonly property int tamIcone: Math.round(18 * Theme.scale)

    // ── A lista ─────────────────────────────────────────────────
    //
    // Um appId por aplicativo, na ordem em que o compositor entrega — que
    // é estável o bastante para os ícones não dançarem a cada foco.
    //
    // `appId` vazio é descartado: janela sem identidade não tem ícone nem
    // nome para mostrar, e um quadrado anônimo na barra só gera dúvida.
    readonly property var apps: {
        const vistos = {}
        const saida = []
        for (const t of ToplevelManager.toplevels.values) {
            const id = t.appId ?? ""
            if (id === "" || vistos[id]) continue
            vistos[id] = true
            saida.push(id)
        }
        return saida
    }

    // O appId em foco, para marcar qual está na frente. Também string, e
    // pelo mesmo motivo de cima.
    readonly property string emFoco: ToplevelManager.activeToplevel?.appId ?? ""

    // Busca a janela pelo id, no momento do clique. Ver a nota das strings.
    function janelaDe(id) {
        const alvo = (id ?? "").toLowerCase()
        for (const t of ToplevelManager.toplevels.values)
            if ((t.appId ?? "").toLowerCase() === alvo) return t
        return null
    }

    // Mesma resolução do Dock: heurística primeiro, id exato como reforço.
    // Um appId do Wayland raramente casa com o nome do .desktop na bala.
    function entradaDe(id) {
        if (!id) return null
        return DesktopEntries.heuristicLookup(id) ?? DesktopEntries.byId(id) ?? null
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
                readonly property var entrada: raiz.entradaDe(modelData)

                implicitWidth: raiz.tamIcone + Math.round(10 * Theme.scale)
                implicitHeight: raiz.tamIcone + Math.round(8 * Theme.scale)
                Layout.alignment: Qt.AlignVCenter

                // Fundo só no foco e no hover. Sem caixa permanente atrás de
                // cada ícone: numa barra de 3440px isso vira uma fileira de
                // retângulos competindo com o conteúdo das janelas de baixo.
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(6 * Theme.scale)
                    color: item.ativo   ? PraxeConfig.colAccent
                         : sonda.hovered ? PraxeConfig.colFg
                                         : "transparent"
                    // Opacidade baixa de propósito: o que identifica o app é
                    // o ÍCONE. O fundo só diz "este é o da frente", e para
                    // isso não precisa de saturação nenhuma.
                    opacity: item.ativo ? 0.22 : (sonda.hovered ? 0.10 : 0)
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on color   { ColorAnimation  { duration: 120 } }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: raiz.tamIcone
                    // `file://` não é enfeite: iconPath devolve caminho de
                    // sistema e o IconImage espera URL. Mesma armadilha
                    // documentada no Dock.
                    source: {
                        const nome = item.entrada ? item.entrada.icon : item.modelData
                        return nome ? Quickshell.iconPath(nome, true) : ""
                    }
                    // Aplicativo sem foco fica recuado, não apagado: ele
                    // continua sendo uma coisa que existe e se pode clicar.
                    opacity: item.ativo ? 1.0 : 0.72
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                // HoverHandler e não MouseArea — a nota do `rastreador` no
                // shell.qml explica: MouseArea engole o hover da barra, a
                // carência corre e a barra se fecha debaixo do ponteiro.
                HoverHandler {
                    id: sonda
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        const j = raiz.janelaDe(item.modelData)
                        if (j) j.activate()
                    }
                }

                // SEM legenda ao passar o mouse, por ora — e é omissão
                // consciente, não esquecimento. O `Balao.qml` é o balão de
                // NOTIFICAÇÃO (lê o Notificacoes.atual), não um tooltip, e a
                // legenda do Dock é interna a ele (`mostrarDica`, com o
                // triângulo posicionado na régua do próprio dock). Inventar
                // um terceiro mecanismo de legenda aqui daria três jeitos
                // diferentes de mostrar a mesma coisa no mesmo rice.
                // Se a legenda for necessária, o caminho é extrair a do Dock
                // para um componente e usar nos dois.
            }
        }
    }
}
