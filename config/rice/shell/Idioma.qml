// Idioma da interface — segue o locale do sistema.
//
// CUIDADO: não use chave de abertura em comentário neste arquivo. O
// Quickshell acha o objeto raiz contando chaves e não pula comentários;
// uma chave solta faz o singleton sumir sem erro no log.
//
// ── POR QUE ISTO EXISTE ──────────────────────────────────────────
//
// O rice foi escrito inteiro em português enquanto o sistema roda em
// en_US.UTF-8 (o pt_BR nem está gerado nesta máquina). Interface que não
// acompanha o locale é interface errada: quem abre o painel espera ler no
// idioma em que escolheu usar o computador.
//
// ── COMO FUNCIONA ────────────────────────────────────────────────
//
// Dicionários em ~/.config/rice/idioma/<código>.json, um objeto plano de
// chave para texto. A chave é SEMÂNTICA e em inglês (`bar.shape`), nunca
// a frase em si: frase como chave quebra na primeira revisão de texto e
// obriga a mexer nos dois dicionários para trocar uma vírgula.
//
// O texto NÃO é traduzido em tempo de execução por nenhuma mágica — os
// dois arquivos são escritos à mão. Tradução automática de interface
// erra justamente nos termos curtos, que é quase tudo aqui.
//
// ── DECISÕES QUE VALEM SABER ─────────────────────────────────────
//
// O inglês é a BASE, e não o português. Chave faltando cai no inglês
// antes de cair na própria chave, porque é o idioma do sistema e o que
// mais gente lê. Se faltar nos dois, aparece a chave crua na tela: é
// feio de propósito, para o buraco ser notado em vez de virar espaço em
// branco silencioso.
//
// COMENTÁRIOS DE CÓDIGO CONTINUAM EM PORTUGUÊS. Eles são documentação
// para quem mantém, não interface para quem usa — e traduzir centenas de
// notas cuidadosas para agradar uma regra que não se aplica a elas seria
// destruir o que há de mais útil neste repositório.

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Pega as DUAS PRIMEIRAS LETRAS do locale, e não uma lista de casos.
    //
    // `pt_BR.UTF-8` vira "pt", `es_AR.UTF-8` vira "es", `de_DE` vira "de".
    // Não há `if` por idioma aqui de propósito: acrescentar um idioma
    // passa a ser SÓ largar um `<código>.json` na pasta, sem tocar em
    // código. Foi assim que o espanhol entrou.
    //
    // Idioma sem dicionário não quebra nada: o FileView abaixo falha ao
    // abrir, o `onLoadFailed` zera o mapa, e todo texto cai no inglês pela
    // cadeia do `t()`. Um alemão vê a interface em inglês, que é o
    // comportamento certo — não uma tela de chaves cruas.
    //
    // `C` e `POSIX` viram "c" e "po", que não têm dicionário e portanto
    // caem em inglês pelo mesmo caminho. Locale vazio idem.
    readonly property string codigo: {
        const l = (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES")
                                            || Quickshell.env("LANG") || "").toLowerCase()
        const c = l.substring(0, 2)
        return c.length === 2 ? c : "en"
    }

    property var dic: ({})
    property var base: ({})

    // `blockLoading` nos DOIS — mas NÃO conte com ele para leitura
    // síncrona.
    //
    // MEDIDO, sondando de 400 em 400ms: a consulta feita no
    // `Component.onCompleted` de quem sobe junto ainda devolve a CHAVE
    // crua; entre 400ms e 800ms o dicionário chega e a partir daí tudo
    // responde traduzido. A opção encurta essa janela, não a elimina.
    //
    // O detalhe que explica o resto: um singleton QML só é CRIADO no
    // primeiro acesso, e é aí que o FileView começa a ler. Quem tocar o
    // Idioma pela primeira vez e ler no mesmo instante recebe a chave —
    // não porque esteja quebrado, mas porque acabou de dar a partida.
    //
    // Na prática isso não aparece: o painel de aparência é instanciado
    // junto com a barra, então o primeiro toque acontece na subida e a
    // leitura termina muito antes de alguém abrir o painel. E todo texto
    // aqui é binding — quando o dicionário chega, tudo reavalia sozinho.
    FileView {
        id: arqDic
        path: Quickshell.env("HOME") + "/.config/rice/idioma/" + root.codigo + ".json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: { try { root.dic = JSON.parse(arqDic.text()) } catch (e) { root.dic = ({}) } }
        onLoadFailed: root.dic = ({})
    }

    // O inglês é carregado SEMPRE, mesmo quando já é o idioma ativo.
    // Custa um arquivo pequeno e garante que uma chave nova, ainda não
    // traduzida, apareça em inglês em vez de aparecer como chave.
    FileView {
        id: arqBase
        path: Quickshell.env("HOME") + "/.config/rice/idioma/en.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: { try { root.base = JSON.parse(arqBase.text()) } catch (e) { root.base = ({}) } }
        onLoadFailed: root.base = ({})
    }

    // t de "texto". Nome curto porque aparece centenas de vezes no QML —
    // `Idioma.traduzir(...)` empurraria metade das linhas para a coluna 80.
    function t(chave) {
        const a = root.dic[chave]
        if (a !== undefined) return a
        const b = root.base[chave]
        if (b !== undefined) return b
        return chave
    }

    // Com um substituto: t("folders.unavailable", "Tela") troca o {0}.
    // Existe para frase que embute um nome — concatenar pedaço traduzido
    // com pedaço fixo produz ordem errada em outro idioma.
    function tf(chave, valor) {
        return root.t(chave).replace("{0}", valor === undefined ? "" : valor)
    }
}
