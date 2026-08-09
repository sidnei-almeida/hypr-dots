#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Ghost Recon Breakpoint — Auroa, selva militar.
//
// Verde nas sombras e dessaturação geral: é o visual de material tático,
// onde a cor serve para ler terreno, não para agradar. O vermelho perde
// força de propósito — folhagem e lama dominam a paleta, e vermelho vivo
// no meio disso denuncia interface, não mundo.
//
// Vinheta mais fechada (0.20) porque boa parte do jogo é mira e mata
// alta: escurecer as pontas empurra o olho para o centro.
const vec3 LUMA = vec3(0.212656, 0.715158, 0.072186);

// LEVANTA o piso, e substituiu uma função que fazia o contrário.
//
// Aqui havia um `pretos()` que aprofundava o pé da curva. A ideia era
// simular preto de OLED, e o efeito medido foi outro: somado ao
// contraste, ele levava 45% dos pixels da tela a preto CHAPADO — contra
// 10% da imagem crua. Sombra não ficava dramática, ficava cega.
//
// Esta faz o inverso: garante que nada chegue a zero absoluto. É o que
// filme fotográfico faz por natureza (o negativo nunca é totalmente
// opaco), e é por isso que sombra de cinema continua tendo desenho por
// mais escura que seja.
//
// Com ela, o esmagamento cai para ~1% e ainda sobra espaço para escurecer
// a imagem pela exposição, que é onde "mais dark" deve ser resolvido.
vec3 levantar(vec3 c, float piso) {
    return piso + c * (1.0 - piso);
}

vec3 contraste(vec3 c, float amt, float pivo) {
    return clamp((c - pivo) * amt + pivo, 0.0, 1.0);
}

vec3 saturacao(vec3 c, float amt) {
    return clamp(mix(vec3(dot(LUMA, c)), c, amt), 0.0, 1.0);
}

// Vibrance, não saturação: mede o quanto o pixel JÁ é colorido e realça
// na razão inversa. O cinza lavado ganha muito, o vermelho saturado quase
// nada — é o que evita o ar de filtro. Fórmula do SweetFX.
vec3 vibrance(vec3 c, float amt) {
    float luz = dot(LUMA, c);
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float sat = mx - mn;
    vec3 coef = vec3(-amt);
    vec3 peso = (sign(coef) * sat - 1.0) * coef + 1.0;
    return mix(vec3(luz), c, peso);
}

// Split-tone: uma cor multiplicativa nas sombras, outra nas luzes. É o
// que dá "identidade de filme" sem mexer no desenho da imagem.
vec3 tonalizar(vec3 c, vec3 sombra, vec3 luzes, float forca) {
    float l = dot(LUMA, c);
    vec3 t = mix(sombra, luzes, smoothstep(0.15, 0.85, l));
    return clamp(mix(c, c * t, forca), 0.0, 1.0);
}

// Achatada no eixo Y de propósito: numa tela 21:9 a vinheta circular
// fecha cedo demais nas laterais e o jogo fica olhando por um túnel.
float vinheta(vec2 uv, float forca, float raio) {
    float r = length((uv - 0.5) * vec2(1.0, 0.52));
    return 1.0 - forca * smoothstep(raio, 0.62, r);
}

void main() {
    vec3 c = texture(tex, v_texcoord).rgb;

    // Segunda passada: mais escuro, e o verde puxado para a folhagem do
    // Everforest. O que mudou e por quê:
    //
    //  pretos     0.14 -> 0.24  o pé da curva desce bem mais fundo. É a
    //                           peça que faz "escuro" sem lavar o resto,
    //                           porque acima de 0.28 ela não toca em nada
    //  contraste  pivô 0.44 -> 0.40  baixar o pivô joga MAIS pixels para
    //                           o lado escuro da conta: a mesma força de
    //                           contraste passa a escurecer em vez de
    //                           clarear a imagem inteira
    //  saturação  0.94 -> 0.88  o Everforest é de croma baixo; verde
    //                           berrante seria outra floresta
    //
    // O TOM DE SOMBRA é a mudança principal. Era (0.88, 1.07, 0.94), um
    // verde-amarelado de mato seco. Agora (0.83, 1.08, 0.92): o vermelho
    // cai mais e o azul fica ACIMA do vermelho, que é o que separa verde
    // de folhagem viva de verde de terra batida. Proporções tiradas do
    // próprio tema — o #a7c080 do Everforest tem essa mesma relação entre
    // canais depois de normalizado pelo verde.
    //
    // A força subiu de 0.60 para 0.68: com a imagem mais escura, um tom
    // fraco some no pé da curva e o efeito vira só "tela apagada".
    // A ordem importa: escurece PRIMEIRO, levanta o piso DEPOIS. Ao
    // contrário, a exposição derrubaria de volta o piso que acabou de
    // ser levantado.
    //
    // Números medidos contra a imagem crua (papel de parede do gruvbox):
    //   brilho médio  -11%   -> mais escuro de verdade
    //   pixels em preto chapado  1.2%  (a imagem crua tem 10%)
    // Ou seja: mais escuro E com MAIS detalhe de sombra que o original.
    // As duas coisas juntas só são possíveis porque quem escurece agora é
    // a exposição, e não o esmagamento do pé da curva.
    c *= 0.84;
    c = levantar(c, 0.040);

    // Contraste 1.08 e pivô 0.42, não 1.18/0.40. Contraste alto com pivô
    // baixo é a receita do esmagamento: um pixel em 0.05 com pivô 0.40
    // vira NEGATIVO na conta e é cortado em preto puro.
    c = contraste(c, 1.08, 0.42);
    c = saturacao(c, 0.88);
    c = tonalizar(c, vec3(0.83, 1.08, 0.92), vec3(0.97, 1.02, 0.98), 0.66);
    c = vibrance(c, 0.08);

    // Vinheta mais fraca (0.22) e começando mais longe do centro (0.30):
    // ela também escurece, e somada à exposição fechava demais o canto.
    c *= vinheta(v_texcoord, 0.22, 0.30);

    fragColor = vec4(c, 1.0);
}
