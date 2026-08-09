// Paleta e medidas da barra.
//
// As cores vêm de ~/.config/rice/theme.json, que o rice-theme gera a
// partir da paleta do tema atual. O arquivo é observado, então trocar
// de tema repinta a barra AO VIVO — sem reiniciar o processo e sem
// fechar o painel que estiver aberto.
//
// CUIDADO AO EDITAR OS COMENTÁRIOS: o Quickshell acha o objeto raiz
// contando chaves e não pula comentários. Uma chave de abertura solta
// num comentário faz este singleton deixar de existir, sem erro no log.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    FileView {
        id: arquivo
        path: Quickshell.env("HOME") + "/.config/rice/theme.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: p
            property string nome: "PraXe"
            property string bg: "#0a0a0a"
            property string bgAlt: "#302e28"
            property string fg: "#e8e2d4"
            property string muted: "#8a8378"
            property string dim: "#3a352a"
            property string accent: "#c9a94e"
            property string accent2: "#e6c878"
            property string ok: "#9aa86a"
            property string warn: "#e6c878"
            property string err: "#c9694e"
            // ATENÇÃO ao acrescentar uma chave NOVA nesta lista: o hot
            // reload do Quickshell não basta. O JsonAdapter fica com o
            // esquema com que subiu, e a chave nova é lida como vazia
            // mesmo estando no theme.json — o valor cai no padrão e
            // parece que a leitura está quebrada. Só um `pkill -x qs`
            // seguido de reinício faz o adapter enxergá-la.
            property string aviso: ""
            property string fontFamily: "JetBrainsMono Nerd Font"
            property int fontSize: 12
        }
    }

    // Bindings com fallback, não alias: o alias fica preso em undefined
    // enquanto o arquivo não chegou.
    readonly property color bg:      p.bg      ?? "#0a0a0a"
    readonly property color bgAlt:   p.bgAlt   ?? "#302e28"
    readonly property color fg:      p.fg      ?? "#e8e2d4"
    readonly property color muted:   p.muted   ?? "#8a8378"
    readonly property color dim:     p.dim     ?? "#3a352a"
    readonly property color accent:  p.accent  ?? "#c9a94e"
    readonly property color accent2: p.accent2 ?? "#e6c878"
    readonly property color ok:      p.ok      ?? "#9aa86a"
    readonly property color warn:    p.warn    ?? "#e6c878"
    readonly property color err:     p.err     ?? "#c9694e"

    // Cor do ponto de aviso do notch fechado.
    //
    // Cai no acento quando o tema não declara nada, que é o caso de
    // quase todos — e é o certo: o ponto acompanha a identidade da
    // paleta em vez de ser vermelho de badge em toda parte.
    //
    // A saída existe porque há tema em que o acento não serve. No
    // Samurai o acento é o âmbar da lanterna, cor de coisa acesa e
    // tranquila; um aviso pedindo atenção precisa do vermelho de alarme.
    // Cuidado ao declarar: o ponto tem 6px sobre uma barra quase
    // transparente, então a cor escolhida precisa de contraste de
    // verdade — o vermelhão das bandeiras do Samurai (#c1382a) dá só
    // 3.7:1 e foi recusado justamente por isso.
    readonly property color aviso:
        (p.aviso && p.aviso.length > 0) ? p.aviso : accent

    readonly property string nome: p.nome ?? "PraXe"

    // Derivadas
    readonly property color pillBg:     Qt.rgba(bg.r, bg.g, bg.b, 0.92)
    readonly property color pillBorder: Qt.rgba(fg.r, fg.g, fg.b, 0.10)
    readonly property color hoverBg:    Qt.rgba(fg.r, fg.g, fg.b, 0.10)

    // ── Medidas ────────────────────────────────────────────────
    readonly property real  scale:       1.0
    readonly property int   pillHeight:  Math.round(34 * scale)
    readonly property int   pillTop:     10
    readonly property int   padH:        Math.round(18 * scale)
    readonly property int   groupGap:    Math.round(16 * scale)
    readonly property int   itemGap:     Math.round(7 * scale)

    // ── Tempos ─────────────────────────────────────────────────
    //
    // Aqui porque estavam em DOIS lugares e divergiram: a cápsula animava
    // forma em 200ms (shell.qml) e os pontos de área em 300ms
    // (Workspaces.qml). Como os pontos vivem DENTRO da cápsula, por 100ms
    // o conteúdo ainda se movia numa cápsula que já tinha parado — e a
    // fileira, sendo centralizada, escorregava de lado nesse intervalo.
    // Era parte do "shaky" ao trocar de área.
    //
    // Peça aninhada tem de assentar JUNTO com a que a contém, senão são
    // dois movimentos onde o olho espera um.
    readonly property int   animForma:   200
    readonly property int   animCor:     150

    readonly property string fontFamily:     p.fontFamily ?? "JetBrainsMono Nerd Font"
    readonly property string nerdFontFamily: fontFamily
    readonly property int    fontSize:       Math.round((p.fontSize ?? 12) * scale)
    readonly property int    iconSize:       Math.round(((p.fontSize ?? 12) + 1) * scale)
}
