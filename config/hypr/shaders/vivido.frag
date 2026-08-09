#version 300 es
precision highp float;

// Vivid — realce de cor aplicado sobre a tela inteira.
//
// Gerado por rice-vivido. Não edite à mão: será sobrescrito.
// Ajuste pelo painel de aparência (aba Sistema) ou:
//   rice-vivido 25        intensidade 0..100
//   rice-vivido off
//
// DIALETO: GLSL ES 3.00. O Hyprland 0.56 compila os shaders de tela em
// `#version 300 es` — logo, `in`/`out` e `texture()`. Escrever no
// dialeto antigo (varying / gl_FragColor / texture2D) não dá erro no
// log: o parser cospe a reclamação NA TELA. Se algo aqui parecer
// ignorado, o comando é `hyprctl configerrors`.
//
// É VIBRANCE, não saturação plana. A diferença importa: saturação
// multiplica todo mundo igual, então o que já estava vivo estoura e
// vira mancha chapada — é isso que dá o ar de "filtro". Vibrance mede
// o quanto cada pixel JÁ é colorido e realça na razão inversa: o cinza
// lavado ganha muito, o vermelho saturado quase nada. Mesmo princípio
// do Digital Vibrance da NVIDIA.
//
// A fórmula é a do SweetFX, a mesma que o hyprshade usa de referência.

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float FORCA = 0.210;

void main() {
    vec4 pixel = texture(tex, v_texcoord);
    vec3 cor = pixel.rgb;

    // Pesos de Rec.709, que são os do sRGB. A média simples dos canais
    // escureceria o verde e clarearia o azul, dando um viés frio à
    // imagem inteira.
    const vec3 LUMA = vec3(0.212656, 0.715158, 0.072186);
    float luz = dot(LUMA, cor);

    float mx = max(cor.r, max(cor.g, cor.b));
    float mn = min(cor.r, min(cor.g, cor.b));
    float saturado = mx - mn;          // 0 = cinza puro, 1 = cor cheia

    // Quanto MENOS saturado o pixel já é, mais peso ele recebe.
    vec3 coef = vec3(-FORCA);
    vec3 peso = (sign(coef) * saturado - 1.0) * coef + 1.0;

    fragColor = vec4(mix(vec3(luz), cor, peso), pixel.a);
}
