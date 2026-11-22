shader_type spatial;
// La gente de afuera de las fortalezas toma Serenol y se le nota en la piel (JJ, 2026-11-21; lore §6):
// venas como varices, sutiles (JJ: "no se nota"), en la cara, el cuello, los brazos y las manos. Lo pone VenasSerenol.gd encima del
// material del modelo, con su misma textura. La piel se reconoce por color (YCbCr, sirve para todos
// los tonos) y las venas son un ruido en crestas en pixeles de la textura, en toda la piel visible, mas
// marcadas a manchones. La vena oscurece la piel hacia azul morado, sin brillo; el hilo
// azul de en medio (`hilo_serenol`, `brillo`, late con la Madre a 0.25 Hz) queda apagado por omision. Adentro de las fortalezas la gente se ve tal cual: no lleva esto.

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 color_vena : source_color = vec3(0.36, 0.38, 0.74);   // tiñe la piel: azul morado de varice
uniform vec3 color_serenol : source_color = vec3(0.18, 0.77, 1.0); // #2EC4FF, el de la Madre
uniform float cuanto : hint_range(0.0, 1.0) = 1.0;     // 0 = sin venas
uniform float tupido : hint_range(0.0, 1.0) = 0.5;     // donde se marcan mas (fuera de ahi se ven tenues)
uniform float tenue : hint_range(0.0, 1.0) = 0.5;      // que tanto se ven fuera de los manchones
uniform float escala = 16.0;                            // pixeles de textura entre venas
uniform float grueso : hint_range(0.0, 0.3) = 0.15;    // ancho de la vena
uniform float fuerza : hint_range(0.0, 1.0) = 0.75;    // que tanto se marca la vena (sutil: no se nota)
uniform float hilo_serenol : hint_range(0.0, 1.0) = 0.0; // el hilo azul de en medio (0 = nada)
uniform float brillo : hint_range(0.0, 2.0) = 0.0;     // luz propia del hilo (0 = nada)
uniform float respiracion = 0.25;
uniform bool ver_piel = false;                          // pinta de azul la piel detectada (para ajustar)

varying vec2 uv_v;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x),
		mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 en la piel, 0 en ropa, pelo y fondo. Rangos clasicos de piel en YCbCr, mas que sea rojiza
float es_piel(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float cb = 0.5 - 0.168736 * c.r - 0.331264 * c.g + 0.5 * c.b;
	float cr = 0.5 + 0.5 * c.r - 0.418688 * c.g - 0.081312 * c.b;
	bool piel = cb > 0.302 && cb < 0.498 && cr > 0.537 && cr < 0.686 && y > 0.2 && c.r > c.g && c.g >= c.b * 0.9;
	return piel ? 1.0 : 0.0;
}

// Crestas del ruido: x = la vena (1 encima, 0 lejos; la gruesa y sus ramitas), y = el hilo de en
// medio de las gruesas, que es el que brilla
vec2 vena(vec2 p) {
	vec2 q = p + vec2(ruido(p * 0.5 + 3.7), ruido(p * 0.5 + 9.1)) * 1.6;   // que serpenteen
	float gruesa = 1.0 - abs(ruido(q) * 2.0 - 1.0);
	float fina = 1.0 - abs(ruido(q * 2.3 + 5.0) * 2.0 - 1.0);
	float v = smoothstep(1.0 - grueso, 1.0 - grueso * 0.3, gruesa);
	v = max(v, smoothstep(1.0 - grueso * 0.55, 1.0 - grueso * 0.15, fina) * 0.7);
	float hilo = smoothstep(1.0 - grueso * 0.22, 1.0 - grueso * 0.05, gruesa);
	return vec2(v, hilo);
}

void vertex() {
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	uv_v = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec4 tex = texture(albedo_texture, uv_v);
	vec3 color = tex.rgb * tint.rgb;
	float piel = es_piel(tex.rgb);
	// En pixeles de la textura, para que las venas caigan en su rejilla como lo demas
	vec2 px = floor(uv_v * vec2(textureSize(albedo_texture, 0)));
	float mancha = mix(tenue, 1.0, smoothstep(1.0 - tupido, 1.0 - tupido + 0.15, ruido(px / (escala * 3.5) + 21.0)));
	vec2 vh = vena(px / escala) * mancha * piel * cuanto;
	float v = vh.x;
	float aliento = 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	float nucleo = vh.y;
	// La piel alrededor un poco mas palida y gris, como de quien duerme mal
	color = mix(color, color * vec3(0.96, 0.97, 1.0), piel * mancha * cuanto * 0.5);
	// Como varice: la vena oscurece y enfria la piel (multiplica), no la pinta encima
	color = mix(color, color * color_vena, v * fuerza);
	color = mix(color, color_serenol, nucleo * hilo_serenol);
	if (ver_piel) {
		color = mix(color, vec3(0.0, 0.4, 1.0), piel * 0.7);
	}
	ALBEDO = color;
	EMISSION = color_serenol * nucleo * brillo * mix(0.4, 1.0, aliento);
	ROUGHNESS = 1.0;
}
