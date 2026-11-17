// La cucarrata (scripts/cucarrata/Cucarrata.gd) con la piel de la Madre del Carcamo (madre.gdshader):
// keloides gris carbon en pixeles duros y grietas de Serenol azul que respiran al mismo ritmo que
// la Madre y sus crias (aliento() sobre el TIME global, 15 respiraciones por minuto). La textura
// original solo deja sus sombras (las placas del caparazon, los ojos y la nariz de la rata).
// Las celdas van sobre la UV porque la malla tiene esqueleto: en coordenadas del objeto el dibujo
// resbalaria al caminar. El brinco de vertices de los personajes viene de ps1_vertex.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;   // las alas son planos

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D textura : source_color, filter_nearest;
uniform vec3 color_piel : source_color = vec3(0.247, 0.267, 0.278);   // #3F4447, el de la Madre
uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);     // #2EC4FF
uniform vec3 color_nucleo : source_color = vec3(0.85, 0.98, 1.0);
uniform float respiracion : hint_range(0.1, 2.0) = 0.25;
uniform float brillo : hint_range(0.0, 4.0) = 1.0;
// Cuanto de la textura original se nota (sus oscuros), y cuantas grietas lleva (la cabeza menos)
uniform float sombras_textura : hint_range(0.0, 1.0) = 0.7;
uniform float grietas : hint_range(0.0, 1.0) = 1.0;
// Tamano de los keloides en la UV (los atlas de cada modelo tienen otra densidad)
uniform vec2 escala_celdas = vec2(12.0, 12.0);
uniform vec2 pixeles = vec2(192.0, 192.0);
// Las grietas brillan mas hacia la cola, como en la Madre: el eje hacia la cola en el espacio de
// la malla y donde empieza y acaba (Cucarrata._material_cuerpo los calcula)
uniform vec3 eje_cola = vec3(0.0, 0.0, 1.0);
uniform float cola_desde = -0.6;
uniform float cola_hasta = 1.0;

varying vec2 uv_afin;
varying float hacia_cola;

vec2 azar2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Celdas de Voronoi (las de madre.gdshader): x = distancia al centro, y = distancia a la orilla
vec2 celdas(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	vec2 mejor = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + azar2(i + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				mejor = r;
			}
		}
	}
	float orilla = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + azar2(i + g) - f;
			if (dot(mejor - r, mejor - r) > 0.00001) {
				orilla = min(orilla, dot(0.5 * (mejor + r), normalize(r - mejor)));
			}
		}
	}
	return vec2(sqrt(d1), orilla);
}

float aliento() {
	float f = 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	return mix(0.05, 1.0, smoothstep(0.0, 1.0, f));
}

void vertex() {
	hacia_cola = clamp((dot(VERTEX, eje_cola) - cola_desde) / (cola_hasta - cola_desde), 0.0, 1.0);
	vec2 afin;
	POSITION = ps1_vertex(VERTEX, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, afin);
	uv_afin = afin;
}

void fragment() {
	vec3 original = texture(textura, uv_afin).rgb;
	// Sombras de la textura: 1 en lo claro, baja en lo oscuro (placas, ojos, hocico)
	float valor = dot(original, vec3(0.299, 0.587, 0.114));
	float sombra = mix(1.0, smoothstep(0.02, 0.55, valor) * 1.3, sombras_textura);
	vec2 q = (floor(UV * pixeles) + 0.5) / pixeles;
	vec2 p = q * escala_celdas;
	vec2 c = celdas(p);
	vec2 c2 = celdas(p * 2.3 + 9.0);
	float alto = smoothstep(0.0, 0.35, c.y) * (1.0 - c.x * 0.6);
	float rugoso = alto * 0.7 + smoothstep(0.0, 0.2, c2.y) * 0.3;
	vec3 tinte = pow(color_piel, vec3(2.2));
	vec3 carne = tinte * mix(0.12, 1.2, rugoso) * sombra;
	carne = mix(carne, carne * vec3(1.15, 1.05, 0.95), smoothstep(0.55, 0.9, rugoso));
	// Grietas en parches, mas hacia la cola
	vec2 gran = celdas(q * escala_celdas * 0.45 + 5.0);
	float parche = smoothstep(0.4, 0.8, gran.x + (hacia_cola - 0.5) * 0.9);
	float linea = 1.0 - smoothstep(0.015, 0.07, c.y);
	float grieta = linea * parche * grietas;
	ALBEDO = mix(carne, color_grieta * 0.35, grieta);
	vec3 luz = mix(color_grieta, color_nucleo, smoothstep(0.02, 0.0, c.y - 0.03) * 0.6);
	EMISSION = luz * grieta * 3.0 * mix(0.35, 1.0, hacia_cola) * brillo * aliento();
	ROUGHNESS = mix(0.95, 0.55, alto);
	SPECULAR = 0.3;
}
