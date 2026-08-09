#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Alien (1979) — a Nostromo, não a Sevastopol.
//
// Este preset era do JOGO e foi refeito para o FILME. A diferença não é
// só escurecer, e é essa a parte que interessa:
//
// O jogo tem sombra fria E luz fria — tudo puxa para o ciano do CRT, o
// que na tela lê como visão noturna. O filme do Ridley Scott faz o
// contrário nas luzes: as práticas a bordo são LÂMPADAS DE SÓDIO e
// incandescentes, âmbar sujo, contra corredores azul-esverdeados. É esse
// choque quente-contra-frio que dá a memória visual do filme; sem ele,
// escurecer mais só produz uma tela apagada.
//
// O mais escuro e o mais dessaturado do conjunto, de propósito: metade
// do filme se passa em corredor mal iluminado, e cor demais entrega o
// espaço antes da hora.
const vec3 LUMA = vec3(0.212656, 0.715158, 0.072186);

// LEVANTA o piso — ver a nota longa no breakpoint.frag.
//
// Aqui havia um `pretos()` que afundava o pé da curva. Medido, ele levava
// metade da tela a preto chapado: sombra sem desenho, que é cegueira e
// não clima. Esta garante que nada chegue a zero absoluto, como o
// negativo de filme, que nunca é totalmente opaco.
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

    // O SPLIT-TONE (mais abaixo) é o que faz este preset lembrar o filme:
    //   sombras (0.86, 1.01, 1.09) — frias e azuladas; é o corredor.
    //   luzes   (1.07, 1.00, 0.88) — QUENTES. Antes eram (0.96,1.02,1.03),
    //     frias como as sombras. Agora o vermelho sobe e o azul cai: é a
    //     lâmpada de sódio. Esta única linha é o que separa "cinema" de
    //     "visão noturna".
    // Saturação em 0.76 pelo mesmo motivo: fora das práticas, o filme é
    // quase monocromático.
    //
    // Escurece primeiro, levanta o piso depois — a ordem inversa
    // derrubaria de volta o piso recém-levantado.
    //
    // Medido contra a imagem crua:
    //   brilho médio  -18%   (o mais escuro do conjunto, como deve ser)
    //   preto chapado  5.9%  (a imagem crua tem 10%)
    //   detalhe de sombra  idêntico ao original
    // É mais escuro que o breakpoint e MENOS cego que a foto original.
    c *= 0.80;
    c = levantar(c, 0.048);

    // Contraste 1.10 com pivô 0.46. A versão anterior usava 1.26/0.38 e
    // era ela, não a exposição, que apagava a sombra: com pivô baixo e
    // ganho alto, tudo abaixo de ~0.06 vira negativo na conta e é
    // cortado em preto puro.
    c = contraste(c, 1.10, 0.46);
    c = saturacao(c, 0.76);
    c = tonalizar(c, vec3(0.86, 1.01, 1.09), vec3(1.07, 1.00, 0.88), 0.72);
    c = vibrance(c, 0.05);
    c *= vinheta(v_texcoord, 0.28, 0.26);

    fragColor = vec4(c, 1.0);
}
