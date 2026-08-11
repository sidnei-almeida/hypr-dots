#version 300 es
precision highp float;

in  vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// NÃO declare `uniform float time` aqui. O Hyprland recusa o shader com
//
//   screen shader uses uniform 'time' which requires debug:damage_tracking
//   to be switched off
//
// e desligar o damage tracking manda a GPU redesenhar a tela inteira todo
// quadro — custo alto e permanente, para animar grão. Não vale a troca.
// Como o grão é semeado pela luminância do pixel (ver o passo 11), ele se
// renova sozinho quando a imagem se move, que é quando o olho notaria.

// ══════════════════════════════════════════════════════════════════════
//  Alien (1979) — a Nostromo, não a Sevastopol
// ══════════════════════════════════════════════════════════════════════
//
// Este perfil é do FILME, não do jogo, e a diferença está nas luzes.
//
// O jogo tem sombra fria E luz fria: tudo puxa para o ciano do CRT, o que
// na tela lê como visão noturna. O filme do Ridley Scott faz o contrário
// nas altas: as práticas a bordo são LÂMPADAS DE SÓDIO e incandescentes,
// âmbar sujo, contra corredores azul-esverdeados. É esse choque
// quente-contra-frio que dá a memória visual do filme. Sem ele, escurecer
// só produz uma tela apagada.
//
// Ganho (1.070, 0.995, 0.880) contra lift (0.0012, 0.0022, 0.0034): as duas
// pontas puxam para lados opostos e o meio fica quase neutro. É o desenho
// clássico de complementares, e agora é possível porque o lift/gama/ganho
// separa as três faixas — o split-tone de dois pontos da versão anterior
// não conseguia manter o meio-tom fora da briga.
//
// A HALAÇÃO É A PEÇA PRINCIPAL AQUI, em 0.10, a mais forte do conjunto.
// Alien de 1979 foi filmado em 35mm com muita fumaça em cena e as práticas
// dentro do quadro. Cada mostrador, cada luz de emergência, cada monitor
// CRT sangra um halo alaranjado no ar carregado. Isso NÃO é cor, é ótica —
// e é o motivo de nenhuma versão anterior deste perfil lembrar o filme por
// mais que se mexesse nas curvas.
//
// Grão em 0.038, também o mais alto. A referência é o Kodak 5247, o
// negativo de produção em 1979 e o mesmo que os presets de ReShade
// dedicados ao filme citam. Ele é visivelmente granulado nos meios-tons, e
// o perfil ficaria limpo demais sem isso.
//
// Saturação 0.86, a mais baixa: metade do filme se passa em corredor mal
// iluminado, e cor demais entrega o espaço antes da hora.
//
// É o perfil mais escuro do conjunto — exposição 0.95, pivô 0.580 e o
// contraste mais alto depois do GTA V. Repare que o escuro vem todo daí, e
// nenhum dele de piso levantado: o preto sai em zero, como deve.

// ── Exposição e curva ──
const float EXPOSICAO     = 0.950                     ;
const float CONTRASTE     = 1.380                     ;
const float PIVO          = 0.586                     ;
const float CALCANHAR     = 0.022                     ;
const float ABERTURA_PE   = 0.568                     ;
const float JOELHO        = 0.860                     ;

// ── Cor: lift/gama/ganho = sombras/meios/luzes ──
const vec3  LIFT          = vec3(0.0004, 0.0007, 0.0011);  // corredor azul-esverdeado
const vec3  GAMA          = vec3(0.9900, 1.0000, 1.0120);
const vec3  GANHO         = vec3(1.0700, 0.9950, 0.8800);  // lâmpada de sódio: separa cinema de visão noturna

// ── Croma ──
const float SATURACAO     = 0.920                     ;
const float SAT_SOMBRA    = 0.900                     ;
const float VIBRANCE      = 0.250                     ;
const float BLEACH        = 0.000                     ;

// ── Ótica ──
const float CLAREZA       = 0.200                     ;
const float CLAREZA_RAIO  = 8.000                     ;
const float LIMITE_CLAREZA = 3.500                     ;
const float HALACAO       = 0.100                     ;  // a peça principal deste perfil
const float HAL_LIMIAR    = 0.700                     ;
const float HAL_RAIO      = 22.000                    ;
const vec3  HAL_TINT      = vec3(1.0000, 0.4400, 0.1800);
const float ABERRACAO     = 0.550                     ;
const float VINHETA       = 0.190                     ;
const float VIN_RAIO      = 0.300                     ;
const float VIN_CROMA     = 0.060                     ;

// ── Filme e painel ──
const float GRAO          = 0.038                     ;  // Kodak 5247, o negativo de produção em 1979
const float PISO          = 0.000                     ;  // zero, como em todos: o escuro vem do pivô

// ══════════════════════════════════════════════════════════════════════
//  BIBLIOTECA — idêntica, byte a byte, nos sete perfis.
//
//  O Hyprland não tem #include para shader de tela. Se alterar qualquer
//  coisa daqui para baixo, altere nos sete arquivos:
//      ~/.config/hypr/shaders/{alien-isolation,breakpoint,gaming,gtav,
//                              lies-of-p,rdr2,witcher3}.frag
//  Os marcadores BIBLIOTECA / FIM DA BIBLIOTECA delimitam o bloco.
// ══════════════════════════════════════════════════════════════════════

const vec3 LUMA = vec3(0.212656, 0.715158, 0.072186);

// ── Espaço de cor ─────────────────────────────────────────────────────
//
// TUDO daqui para baixo acontece em LUZ LINEAR, e essa é a mudança que
// separa "cor de cinema" de "filtro por cima da tela".
//
// O pixel que sai do jogo está codificado em sRGB: uma curva de ~2.2 feita
// para distribuir 256 níveis onde o olho enxerga, não para descrever
// fótons. Contraste e saturação multiplicados EM CIMA dessa curva misturam
// tons que na luz real jamais se misturariam — e o resultado é chapado,
// uniforme, colado na frente da imagem. Era o que a versão anterior destes
// perfis fazia, e é a causa raiz da queixa.
//
// Decodificar antes e recodificar depois custa dois pow por pixel, e é a
// linha divisória entre graduação e filtro.
vec3 para_linear(vec3 c) {
    return mix(c / 12.92,
               pow((c + 0.055) / 1.055, vec3(2.4)),
               step(vec3(0.04045), c));
}

vec3 para_srgb(vec3 c) {
    c = max(c, 0.0);
    return mix(c * 12.92,
               1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055,
               step(vec3(0.0031308), c));
}

// Aproximação barata de sRGB->linear (erro < 1%). Usada só nas 32 amostras
// de borrão por pixel, onde o pow exato custaria caro e ninguém veria a
// diferença: é um borrão.
vec3 linear_rapido(vec3 c) {
    return c * c * (0.7532 + 0.2468 * c);
}

// ── Espaço de trabalho logarítmico ────────────────────────────────────
//
// Contraste aplicado em luz linear estoura as altas e esmaga as baixas,
// porque em linear uma parada de luz no alto ocupa metade do eixo e uma
// parada no pé ocupa migalhas. Câmera e mesa de correção trabalham em LOG
// exatamente por isso: lá toda parada ocupa a MESMA fatia, e o contraste
// passa a girar a imagem em torno de um pivô sem privilegiar ponta nenhuma.
//
// Faixa: 16 paradas, de 2^-12 a 2^+4. O piso 2^-12 vale 0.00024 em linear,
// que é ~1/255 em sRGB — o menor nível que 8 bits sabe representar. Cortar
// abaixo disso não perde nada que a tela pudesse mostrar.
const float LOG_BASE = 12.0;
const float LOG_FAIXA = 16.0;

vec3 para_log(vec3 c) {
    return (log2(max(c, exp2(-LOG_BASE))) + LOG_BASE) / LOG_FAIXA;
}

vec3 do_log(vec3 c) {
    return exp2(c * LOG_FAIXA - LOG_BASE);
}

// Contraste em torno de um pivô, dentro do log. O cinza médio (18% de
// reflectância, a carta cinza do fotógrafo) cai em 0.595 nesta codificação:
// girar em torno dali é o que mantém a exposição da cena de pé enquanto o
// contraste sobe. Pivô abaixo de 0.595 escurece a imagem inteira; acima,
// clareia.
vec3 contraste(vec3 c, float ganho, float pivo) {
    return (c - pivo) * ganho + pivo;
}

// ── Correção primária de três vias ────────────────────────────────────
//
// Lift / Gama / Ganho, o modelo de qualquer mesa de correção de cor.
// Cada operação pega naturalmente uma faixa da imagem:
//
//   lift   é uma SOMA, e soma pesa onde o sinal é pequeno   -> SOMBRAS
//   ganho  é um PRODUTO, e produto pesa onde ele é grande   -> ALTAS LUZES
//   gama   é um expoente, e expoente move o que está no meio -> MEIOS-TONS
//
// Substituiu o split-tone de dois pontos da versão anterior, que
// interpolava sombra->luz e por construção NÃO tinha como tocar o
// meio-tom sem arrastar as duas pontas junto. Metade do ar de filtro
// vinha dali: o tom vazava para a imagem inteira.
//
// O GANHO LEVA MÁSCARA, e sem ela o problema acima voltava por outra porta.
// Produto pesa mais nas altas, mas "mais" não é "só": medido, um ganho de
// (1.065, 1.005, 0.885) deixava o cinza de 50% a 0.064 do neutro. O olho
// não lê isso como luz quente, lê como a imagem inteira amarelada — que é o
// mesmo defeito de que o tom azulado das sombras foi acusado, virado do
// avesso. Restringir o ganho à faixa onde ele deve morar devolve o
// meio-tom, e é lá que estão as cores dos objetos.
//
// A faixa vai de 0.22 a 0.75 em LUZ LINEAR, que é de 54% a 89% de sinal em
// sRGB. Abaixo de 54% o ganho não toca em nada; acima de 89% age inteiro.
const float ALTA_INI = 0.22;
const float ALTA_FIM = 0.75;

// E O TOM NÃO TOCA O CINZA. É esta linha que separa graduação de filtro, e
// ela faltava — nenhum ajuste de quantidade resolvia, porque o problema não
// era quanto tom, era ONDE.
//
// Filtro é uma folha de cor na frente da tela. O que denuncia uma folha de
// cor não é o vermelho que ficou mais quente: é o CINZA que deixou de ser
// cinza. Concreto, névoa, fumaça, asfalto, HUD e texto são neutros, e num
// jogo isso é metade do quadro. Tingir esse meio-tom neutro é exatamente o
// que o olho reconhece na hora como "tem algo por cima da tela".
//
// Aqui o peso do tom é o croma que o pixel JÁ tem: neutro sai intacto,
// pixel já colorido recebe o tom inteiro. É o princípio do vibrance,
// aplicado ao balanço de cor em vez da saturação — e é o que deixa a
// folhagem ficar mais oliva sem que a pedra ao lado dela fique verde.
const float CROMA_INI = 0.030;
const float CROMA_FIM = 0.220;

vec3 lgg(vec3 c, vec3 lift, vec3 gama, vec3 ganho) {
    float alta = smoothstep(ALTA_INI, ALTA_FIM, dot(LUMA, c));
    vec3 tom = pow(max(c * mix(vec3(1.0), ganho, alta) + lift, 0.0), 1.0 / gama);

    float mx = max(c.r, max(c.g, c.b));
    float croma = (mx - min(c.r, min(c.g, c.b))) / max(mx, 1e-4);
    return mix(c, tom, smoothstep(CROMA_INI, CROMA_FIM, croma));
}

// ── Saturação ─────────────────────────────────────────────────────────
//
// Até onde vai "sombra", para o segundo passe de croma. O valor está em LUZ
// LINEAR, e essa distinção derrubou a versão anterior: lá o limiar era 0.16
// linear, que corresponde a 44% de sinal em sRGB. Ou seja, "sombra" cobria
// quase metade do quadro, e a dessaturação de sombra estava comendo a cor
// da imagem inteira — o jogo ficava azulado e apagado ao mesmo tempo, e a
// causa parecia ser o tom das sombras quando era o alcance dele.
//
// 0.020 linear é 15% de sinal em sRGB. Isso é sombra de verdade.
const float LIMIAR_SOMBRA = 0.020;

vec3 saturacao(vec3 c, float amt) {
    return mix(vec3(dot(LUMA, c)), c, amt);
}

// Vibrance, não saturação: mede o quanto o pixel JÁ é colorido e realça na
// razão inversa. O cinza lavado ganha muito, o vermelho saturado quase
// nada. Fórmula do SweetFX, e aplicada em espaço de tela e não em linear
// porque é lá que ela foi ajustada — em linear o mesmo número realça o
// dobro. Ver rice-vivido, que usa a mesma peça.
vec3 vibrance(vec3 c, float amt) {
    float luz = dot(LUMA, c);
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    vec3 coef = vec3(-amt);
    vec3 peso = (sign(coef) * (mx - mn) - 1.0) * coef + 1.0;
    return mix(vec3(luz), c, peso);
}

// ── Curva de saída ────────────────────────────────────────────────────
//
// PÉ. Esta peça faltava, e a falta dela custou duas versões deste arquivo.
//
// Contraste em torno de um pivô é uma reta: tudo acima do pivô sobe, tudo
// abaixo DESCE, e desce tanto mais quanto mais fundo estiver. Quer dizer
// que todo ganho de contraste é pago com detalhe de sombra. A saída óbvia
// é baixar o pivô, mas isso clareia a imagem inteira — troca o problema de
// lugar em vez de resolvê-lo. Medido: para salvar a sombra só pelo pivô,
// os meios-tons iam a 75 nits contra os 54 corretos.
//
// O pé resolve porque age SÓ embaixo. Abaixo do calcanhar a reta vira
// curva de expoente < 1, que levanta a faixa onde o painel em modo Cinema
// deixa de separar níveis — e mapeia 0 em 0, então o preto absoluto
// continua absoluto. É a diferença entre abrir a sombra e pôr véu na tela.
//
// O peso da mistura é o próprio t: vale 0 no preto (onde a curva manda) e
// 1 no calcanhar (onde a reta volta a mandar), o que emenda as duas sem
// degrau. Toda curva de filme tem pé, ombro e uma reta entre os dois; aqui
// faltava justamente o pé.
vec3 pe(vec3 c, float calcanhar, float abertura) {
    vec3 t = min(c / calcanhar, 1.0);
    return mix(calcanhar * pow(t, vec3(abertura)), c, t);
}

// Ombro: acima do joelho a imagem deixa de bater no teto e passa a se
// aproximar dele por assíntota, como a emulsão faz. Sem isto, contraste
// alto transforma toda fonte de luz num disco branco chapado — e a
// halação, que SOMA energia, estouraria sozinha.
vec3 ombro(vec3 c, float joelho) {
    vec3 e = max(c - joelho, 0.0);
    return min(c, vec3(joelho)) + (1.0 - joelho) * (e / (e + (1.0 - joelho)));
}

// ── Ótica ─────────────────────────────────────────────────────────────
//
// Borrão de 16 amostras em espiral de ângulo áureo. Com tão poucos pontos,
// uma grade regular deixaria padrão visível nas altas luzes; o ângulo
// áureo (2.39996 rad) é a distribuição que menos se repete. O raio cresce
// com sqrt(i/n) para que as amostras cubram o disco por igual em vez de se
// amontoarem no centro.
//
// Devolve luz aproximadamente linear.
vec3 borrar(vec2 uv, float raio) {
    vec2 px = raio / vec2(textureSize(tex, 0));
    vec3 soma = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        float a = float(i) * 2.3999632;
        float r = sqrt((float(i) + 0.5) / 16.0);
        soma += linear_rapido(texture(tex, uv + vec2(cos(a), sin(a)) * r * px).rgb);
    }
    return soma / 16.0;
}

// Halação. No filme fotoquímico a luz forte atravessa a emulsão, reflete no
// suporte e volta, espalhando um halo em volta das altas luzes. O halo é
// AVERMELHADO porque o vermelho é o comprimento de onda que a camada
// anti-halo retém pior — não é escolha estética, é a física do material.
//
// É o efeito que o olho lê como "isto foi filmado". Nenhuma curva de cor
// sozinha o produz, e por isso nenhuma versão anterior destes perfis
// chegava perto de parecer cinema: faltava a ótica, não a cor.
vec3 halacao(vec3 borrao, float limiar, vec3 tinta) {
    return max(borrao - limiar, 0.0) * tinta;
}

// Aberração cromática: a lente não foca os três comprimentos de onda no
// mesmo ponto, e o erro cresce com o quadrado da distância ao eixo. Aqui
// vale menos de um pixel na borda e ZERO no centro — o bastante para o
// olho ler "lente", pouco o bastante para não borrar mira nem legenda.
vec3 ler(vec2 uv, float pixels) {
    vec2 px = 1.0 / vec2(textureSize(tex, 0));
    vec2 d = uv - 0.5;
    float r2 = dot(d, d) * 4.0;
    vec2 off = normalize(d + 1e-6) * r2 * pixels * px;
    return vec3(texture(tex, uv + off).r,
                texture(tex, uv).g,
                texture(tex, uv - off).b);
}

// Vinheta. Duas correções em relação à versão anterior:
//
//  1. A forma vem da geometria REAL da tela (textureSize), não de um 0.52
//     escrito à mão. Numa 21:9 a vinheta circular fecha nas laterais e o
//     jogo passa a ser visto por um túnel.
//  2. Ela tira CROMA junto com a luz. Lente de verdade perde os dois na
//     borda; só escurecer lê como mancha preta colada no canto — que é
//     outra parte do ar de "filtro".
//
// Devolve o fator de luz; o croma sai no `main`.
float vinheta(vec2 uv, float forca, float raio) {
    vec2 s = vec2(textureSize(tex, 0));
    vec2 d = (uv - 0.5) * vec2(1.0, 1.2 / (s.x / s.y));
    return 1.0 - forca * smoothstep(raio, 0.62, length(d));
}

// Bleach bypass: no laboratório, pular o branqueamento deixa a prata no
// negativo JUNTO com a cor. Sai contraste alto e croma baixo ao mesmo
// tempo — que é o contrário do que qualquer controle de saturação sabe
// fazer, porque saturação mexe só no croma. Overlay da luminância sobre a
// própria imagem é a reprodução digital padrão do processo.
vec3 sobrepor(vec3 base, vec3 cima) {
    return mix(2.0 * base * cima,
               1.0 - 2.0 * (1.0 - base) * (1.0 - cima),
               step(vec3(0.5), base));
}

// ── Painel ────────────────────────────────────────────────────────────
//
// ESTA É A PEÇA QUE FAZ O PRETO VOLTAR A EXISTIR.
//
// O modo Cinema deste monitor segue a BT.1886, gama ~2.4 — o padrão de
// masterização de vídeo. O sinal que o jogo manda é sRGB, gama ~2.2. Quem
// manda 2.2 para uma tela em 2.4 vê TUDO abaixo do meio-tom mais escuro do
// que deveria, e o erro cresce quanto mais escuro o pixel: em 20% de sinal
// a perda já é de um terço.
//
// Somado a um painel VA de 250 nits, é literalmente por isso que "o preto
// está quase invisível". Nenhum ajuste de sombra dentro do shader resolvia,
// porque o problema estava DEPOIS do shader.
//
// Corrigir é elevar o sinal à razão entre as duas gamas. Se um dia trocar
// o monitor para o modo Padrão/sRGB, ponha GAMA_TELA = 2.2 e esta função
// vira identidade.
const float GAMA_TELA = 2.4;
const float GAMA_FONTE = 2.2;

vec3 compensar_tela(vec3 c) {
    return pow(max(c, 0.0), vec3(GAMA_FONTE / GAMA_TELA));
}

// Ruído branco de um hash. Serve ao grão e ao dither.
float ruido(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// ══════════════════════════════════════════════════════════════════════
//  FIM DA BIBLIOTECA
// ══════════════════════════════════════════════════════════════════════

void main() {
    vec2 uv = v_texcoord;

    // ── 1. Leitura ────────────────────────────────────────────────────
    vec3 c = ler(uv, ABERRACAO);

    // Dois borrões: um largo para a halação, um estreito para a clareza.
    // São 32 buscas de textura por pixel; num painel de 3440x1440 a 100 Hz
    // isso é fração do que a GPU faz por quadro. O custo real deste shader
    // não está aqui, está em desligar o scanout direto — e esse já era
    // pago pela versão anterior.
    vec3 largo    = borrar(uv, HAL_RAIO);
    vec3 estreito = borrar(uv, CLAREZA_RAIO);

    // ── 2. Luz linear ─────────────────────────────────────────────────
    //
    // A exposição mora AQUI, e só aqui. Na versão anterior o escuro vinha
    // de um `c *= 0.84` no fim, em espaço de tela: é a maneira mais crua
    // possível de escurecer, porque derruba a sombra na mesma proporção
    // em que derruba o céu — e a sombra é quem não tinha folga. Agora o
    // escuro vem da curva e da cor; a exposição fica perto de 1.0.
    c = para_linear(c) * EXPOSICAO;
    largo    *= EXPOSICAO;
    estreito *= EXPOSICAO;

    // ── 3. Clareza (contraste local) ──────────────────────────────────
    //
    // Soma de volta a diferença entre a imagem e uma versão borrada dela.
    // É o que dá volume — separa o personagem do fundo, faz a folhagem ter
    // camadas — SEM mexer no contraste global, que é justamente quem
    // esmaga a sombra. Antes, "mais dramático" só podia ser pedido subindo
    // o contraste global, e cada pedido custava detalhe de sombra.
    //
    // O DETALHE É UMA RAZÃO, NÃO UMA DIFERENÇA, e a versão anterior errou
    // aqui — foi o que deixou o contorno preto grosso em volta do texto.
    //
    // Unsharp clássico soma `c - borrão` em luz linear. Do lado escuro de
    // uma borda de texto isso é uma SUBTRAÇÃO de valor absoluto: tirar
    // 0.026 de um pixel que vale 0.010 zera o pixel. O resultado é um anel
    // de preto puro colado na letra, e nenhum limitador salva, porque o
    // pixel escuro simplesmente não tem de onde tirar.
    //
    // Em paradas de luz o mesmo detalhe é proporcional: 10% é 10% tanto no
    // branco quanto na sombra, e por construção nada pode chegar a zero.
    // O limitador então corta só o exagero das bordas de alto contraste.
    // Medido: textura de 5% mantém quase toda a força, borda de texto cai
    // de 13% para 6.7% — visível como volume, não como contorno.
    vec3 detalhe = log2(max(c, 1e-4)) - log2(max(estreito, 1e-4));
    detalhe /= 1.0 + abs(detalhe) * LIMITE_CLAREZA;
    c *= exp2(detalhe * CLAREZA);

    // ── 4. Halação ────────────────────────────────────────────────────
    c += halacao(largo, HAL_LIMIAR, HAL_TINT) * HALACAO;

    // ── 5. Contraste em log, e o pé que paga a conta dele ─────────────
    c = do_log(contraste(para_log(c), CONTRASTE, PIVO));
    c = pe(c, CALCANHAR, ABERTURA_PE);

    // ── 6. Cor: três vias ─────────────────────────────────────────────
    c = lgg(c, LIFT, GAMA, GANHO);

    // ── 7. Croma ──────────────────────────────────────────────────────
    //
    // Saturação global primeiro, depois um segundo passe SÓ nas sombras.
    // Filme perde croma no pé da curva, e é isso que separa sombra de
    // cinema de sombra de videogame: no jogo a sombra continua colorida,
    // só que escura, o que o olho lê como plástico.
    c = saturacao(c, SATURACAO);
    float peso_sombra = 1.0 - smoothstep(0.0, LIMIAR_SOMBRA, dot(LUMA, c));
    c = mix(c, saturacao(c, SATURACAO * SAT_SOMBRA), peso_sombra);

    // ── 8. Ombro e volta para espaço de tela ──────────────────────────
    c = para_srgb(ombro(c, JOELHO));

    // ── 9. Acabamento em espaço de tela ───────────────────────────────
    c = mix(c, sobrepor(c, vec3(dot(LUMA, c))), BLEACH);
    c = vibrance(c, VIBRANCE);

    float v = vinheta(uv, VINHETA, VIN_RAIO);
    c = saturacao(c, mix(1.0 - VIN_CROMA, 1.0, v)) * v;

    // ── 10. Preto e painel ────────────────────────────────────────────
    //
    // PISO É ZERO, e a primeira versão desta refatoração errou aqui.
    //
    // O raciocínio de lá era o do negativo fotográfico, que nunca é
    // totalmente opaco. Mas o negativo é atravessado por um projetor de
    // 10000 nits; este painel tem 250, e o preto dele já emite 0.083 nits
    // sozinho. Um piso de 0.024 punha 0.42 nits de luz em CADA pixel da
    // tela — cinco vezes o preto do painel, espalhado por tudo. Isso não é
    // sombra com desenho, é véu, e foi o que lavou a imagem inteira: o
    // contraste entre 5% e 50% de sinal caiu de 158x (o correto) para 66x.
    //
    // Quem devolve detalhe de sombra é a compensação de gama abaixo, que
    // mapeia 0 em 0 — preto absoluto continua absoluto. A constante fica
    // aqui porque é o botão certo caso um jogo específico precise, mas o
    // valor certo para esta tela é zero.
    c = PISO + c * (1.0 - PISO);
    c = compensar_tela(c);

    // ── 11. Grão ──────────────────────────────────────────────────────
    //
    // Duas coisas o separam de "ruído por cima da tela":
    //
    //   · vive nos MEIOS-TONS. A prata satura no branco e rareia no preto,
    //     então grão de amplitude constante entrega na hora que é digital.
    //     O peso 4*l*(1-l) vale 1 no meio-tom e 0 nas duas pontas.
    //   · é monocromático. Grão colorido é ruído de sensor, não de filme.
    //
    // A distribuição é triangular (soma de dois uniformes), que é a que
    // reproduz a nuvem de grãos; um uniforme só parece chuvisco de TV.
    //
    // A SEMENTE INCLUI A LUMINÂNCIA DO PIXEL, e não o tempo. O caminho
    // óbvio seria `time`, mas o Hyprland recusa o shader que o use sem
    // damage tracking desligado, e desligá-lo faz a GPU redesenhar a tela
    // inteira todo quadro. Semeado pelo conteúdo, o grão fica parado em
    // tela parada — onde ninguém repara — e se renova a cada mudança de
    // luminância, que é exatamente quando o olho notaria um padrão fixo.
    float l = dot(LUMA, c);
    vec2 semente = gl_FragCoord.xy + floor(l * 255.0) * 7.31;
    float g = ruido(semente) + ruido(semente + 19.19) - 1.0;
    c += g * GRAO * 4.0 * l * (1.0 - l);

    // ── 12. Dither ────────────────────────────────────────────────────
    //
    // A graduação produz gradientes que 8 bits não representam, e um painel
    // VA os mostra como faixas concêntricas — céu e neblina são onde
    // aparece. Meio nível de ruído antes do arredondamento troca a faixa
    // por textura que o olho não resolve. Custa um hash e resolve um
    // artefato que nenhum ajuste de cor resolveria.
    c += (ruido(gl_FragCoord.xy * 1.618 + 7.0) - 0.5) / 255.0;

    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
