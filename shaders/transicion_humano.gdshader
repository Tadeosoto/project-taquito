shader_type spatial;
// Los de en medio de las cañerías, version "humano con rasgos de zombi" (JJ, 2026-11-21; lore §8
// "Los de en medio"): un civil del pack PSX con su piel de siempre, la ropa desgarrada (hoyos que
// dejan ver la piel, rasgones, mugre) y grietas de Serenol que brillan en la piel, a manchones.
// Lo pone Transicion.gd encima del material del modelo, con su misma textura. Prototipo para
// comparar con el zombi humanizado (zombi_serenol con `carne`).

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 color_piel : source_color = vec3(0.72, 0.52, 0.40);   // la piel del modelo (Transicion la mide)
uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);  // #2EC4FF, el de la Madre
uniform vec3 color_nucleo : source_color = vec3(0.85, 0.98, 1.0);
uniform float semilla = 0.0;                            // cada uno distinto
uniform float desgarre : hint_range(0.0, 1.0) = 0.5;  // cuanto esta rota la ropa
uniform float mugre : hint_range(0.0, 1.0) = 0.6;
uniform float grietas : hint_range(0.0, 1.0) = 0.65;   // cuanta piel agrietada
uniform float celda = 14.0;                             // pixeles de textura por placa de grieta
uniform float brillo : hint_range(0.0, 4.0) = 1.6;
uniform float respiracion = 0.25;                       // late con la Madre
uniform float palidez : hint_range(0.0, 1.0) = 0.15;   // la piel un poco gris, de enfermo

varying vec2 uv_v;
varying float cabeza;   // COLOR.r de Transicion._marcar_cabeza: ahi no se rasga (el pelo)

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 azar2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x),
		mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Voronoi 2D: x = distancia a la orilla, y = azar de la celda
vec2 celdas(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	vec2 mejor = vec2(0.0);
	vec2 cual = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + azar2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				mejor = r;
				cual = g;
			}
		}
	}
	float orilla = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 g = cual + vec2(float(x), float(y));
			vec2 r = g + azar2(i + g) - f;
			if (dot(mejor - r, mejor - r) > 0.00001) {
				orilla = min(orilla, dot(0.5 * (mejor + r), normalize(r - mejor)));
			}
		}
	}
	return vec2(orilla, azar(i + cual + 17.0));
}

float es_piel(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float cb = 0.5 - 0.168736 * c.r - 0.331264 * c.g + 0.5 * c.b;
	float cr = 0.5 + 0.5 * c.r - 0.418688 * c.g - 0.081312 * c.b;
	bool piel = cb > 0.302 && cb < 0.498 && cr > 0.537 && cr < 0.686 && y > 0.2 && c.r > c.g && c.g >= c.b * 0.9;
	return piel ? 1.0 : 0.0;
}

void vertex() {
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	uv_v = uv_out;
	cabeza = COLOR.r;
	POSITION = clip_position;
}

void fragment() {
	vec4 tex = texture(albedo_texture, uv_v);
	vec3 color = tex.rgb * tint.rgb;
	float piel = es_piel(tex.rgb);
	vec2 px = floor(uv_v * vec2(textureSize(albedo_texture, 0))) + semilla * 37.0;
	float aliento = 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	vec3 piel_c = color_piel * mix(0.85, 1.05, azar(floor(px / 3.0)));

	// --- La ropa: hoyos (se ve la piel), rasgones verticales, hilos sueltos y mugre ---
	float tela = (1.0 - piel) * (1.0 - step(0.5, cabeza));
	vec2 h = celdas(px / 11.0 + 51.0);
	float zona = smoothstep(0.45, 0.65, ruido(px / 40.0 + 3.0));   // los hoyos van juntos, a rachas
	float abre = step(1.0 - desgarre * 0.45, h.y) * zona;
	float hoyo = abre * step(0.12, h.x) * tela;
	float hilo = abre * (1.0 - step(0.12, h.x)) * step(0.04, h.x) * tela;
	float rasgon = zona * step(0.95 - desgarre * 0.06, azar(vec2(floor(px.x / 2.0), floor(px.y / 14.0))))
			* step(0.35, fract(px.y / 14.0 + azar(vec2(floor(px.x / 2.0), 3.0)))) * tela;
	float abierto = max(hoyo, rasgon);
	// Mugre: tierra cafe y manchas de Serenol seco (verde azulado apagado) en la tela
	float tierra = smoothstep(0.55, 0.75, ruido(px / 9.0 + 11.0)) * mugre;
	float seco = smoothstep(0.7, 0.85, ruido(px / 13.0 + 29.0)) * mugre;
	vec3 tela_c = color * mix(1.0, 0.8, azar(floor(px / 2.0)) * mugre * 0.4);
	tela_c = mix(tela_c, vec3(0.20, 0.14, 0.09), tierra * 0.7);
	tela_c = mix(tela_c, vec3(0.20, 0.32, 0.33), seco * 0.5);
	tela_c = mix(tela_c, tela_c * 0.35, hilo);             // la orilla deshilachada, oscura
	color = mix(color, tela_c, (1.0 - piel));
	// Por el hoyo se ve la piel
	color = mix(color, piel_c, abierto);
	float carne = max(piel, abierto);

	// --- La piel: palida y gris, con venas y grietas que brillan a manchones ---
	color = mix(color, mix(color, vec3(dot(color, vec3(0.33))) * vec3(0.92, 0.97, 1.0), palidez), carne);
	vec2 g = celdas(px / celda + 7.0);
	float manchon = smoothstep(1.0 - grietas, 1.0 - grietas + 0.2, ruido(px / 18.0 + 61.0));
	float ramas = smoothstep(0.55, 0.65, ruido(px / 10.0 + 13.0) * 0.5 + manchon * 0.5);
	float linea = (1.0 - step(0.05, g.x)) * ramas * manchon * carne;
	float orilla = (1.0 - smoothstep(0.07, 0.22, g.x)) * ramas * manchon * carne * (1.0 - linea);
	// La piel alrededor de la grieta, reseca y oscura
	color *= mix(1.0, 0.6, orilla);
	color = mix(color, color_grieta * 0.3, linea);
	ALBEDO = color;
	EMISSION = mix(color_grieta, color_nucleo, 0.3 * aliento) * linea * brillo * mix(0.45, 1.0, aliento);
	EMISSION += color_grieta * orilla * 0.08 * brillo * aliento;
	ROUGHNESS = 1.0;
}
