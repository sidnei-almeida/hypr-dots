#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

// Lies of P — Krat, Belle Époque em ruína.
//
// A cena do jogo é lanterna a gás contra pedra molhada: ouro quente nas
// luzes, azul-petróleo nas sombras. É esse par que dá o ar de fábula
// sombria, e não saturação — Krat é elegante, não colorida.
//
// Contraste contido (1.10): o jogo já entrega preto profundo, e empurrar
// mais fecha os interiores, que é onde se joga.
const vec3 LUMA = vec3(0.212656, 0.715158, 0.072186);

// Aprofunda SÓ o pé da curva. Acima de 0.28 nada muda, então sombra com
// detalhe continua com detalhe — é o contrário de baixar o brilho geral.
// É esta peça que simula o preto de OLED num painel que não tem.
vec3 pretos(vec3 c, float f) {
    vec3 k = smoothstep(vec3(0.0), vec3(0.28), c);
    return c * mix(vec3(1.0 - f), vec3(1.0), k);
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

    c = pretos(c, 0.10);
    c = contraste(c, 1.10, 0.45);
    c = tonalizar(c, vec3(0.90, 0.97, 1.12), vec3(1.09, 1.02, 0.88), 0.55);
    c = vibrance(c, 0.16);
    c *= vinheta(v_texcoord, 0.16, 0.30);

    fragColor = vec4(c, 1.0);
}
