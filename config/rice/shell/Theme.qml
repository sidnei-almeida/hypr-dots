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

    // ── Geometria ──────────────────────────────────────────────
    //
    // Três degraus, em razão de ~1.6, e é a razão que faz a escala ler como
    // escala: dois raios próximos demais (8 e 10) não se distinguem, então
    // parecem o mesmo valor errado duas vezes em vez de uma decisão.
    //
    // Havia SETE raios soltos no shell — 4, 5, 6, 7, 8, 10 e 18 — cada um
    // escrito no lugar onde fez falta. Nenhum estava errado sozinho; o
    // problema é que sete valores sem relação entre si é exatamente o que
    // o olho lê como "isto não foi desenhado, foi acontecendo".
    //
    //   raioP   coisa pequena dentro de outra: chip, pino, marcador
    //   raioM   o padrão: item de lista, botão, campo
    //   raioG   recipiente: cartão, seção, miniatura
    //
    // Raio de círculo continua sendo `width / 2` na peça, não daqui — ele
    // não é uma escolha de estilo, é a definição de círculo.
    readonly property int raioP: Math.round(6  * scale)
    readonly property int raioM: Math.round(10 * scale)
    readonly property int raioG: Math.round(16 * scale)

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

    // Três durações, pelo mesmo motivo dos três raios. O shell tinha QUINZE
    // valores diferentes espalhados — 100, 120, 130, 140, 150, 160, 170,
    // 180, 200, 220, 230, 260, 320 — e a nota logo acima conta o que dois
    // valores divergentes já custaram uma vez.
    //
    //   animRapido  resposta ao ponteiro: realce, cor, opacidade de item
    //   animPadrao  mudança de forma ou posição de uma peça
    //   animLento   painel abrindo e fechando, a maior distância percorrida
    readonly property int   animRapido:  120
    readonly property int   animPadrao:  200
    readonly property int   animLento:   320

    // A CURVA IMPORTA MAIS QUE A DURAÇÃO, e era o que faltava: 67 das 94
    // animações do shell não declaravam `easing.type`, e o padrão do QML é
    // `Easing.Linear`.
    //
    // Movimento linear começa e para na mesma velocidade, e não existe nada
    // assim no mundo físico — massa tem inércia. É por isso que interface
    // linear parece barata mesmo quando tudo o mais está no lugar: o olho
    // reconhece a mentira antes de saber nomeá-la.
    //
    // `OutCubic` sai rápido e assenta devagar, que é a curva certa para algo
    // que RESPONDE a você: a peça já está quase onde deveria quando o olho
    // chega nela. É a mesma que as poucas animações já bem-feitas daqui
    // usavam — este token só faz o resto do shell concordar com elas.
    //
    // Movimento com massa (janela, cápsula) continua nas MOLAS do
    // looknfeel.lua; isto é para o que acontece dentro da barra.
    readonly property int   curva:       Easing.OutCubic

    readonly property string fontFamily:     p.fontFamily ?? "JetBrainsMono Nerd Font"
    readonly property string nerdFontFamily: fontFamily
    readonly property int    fontSize:       Math.round((p.fontSize ?? 12) * scale)
    readonly property int    iconSize:       Math.round(((p.fontSize ?? 12) + 1) * scale)
}
