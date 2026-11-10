// La Madre del Carcamo (MallaLombriz.material_madre): piel de keloides gris carbon como la cola
// de Godzilla Minus One, con grietas de Serenol azul que brillan, mas hacia la cola, y espinas
// en el lomo que se encienden por la punta. Los pixeles duros del juego (la UV se redondea) y el
// brinco de vertices de los personajes. De un MultiMesh: COLOR es el tinte (alfa = quemada),
// INSTANCE_CUSTOM.r = que tan abierta la boca, .g = que tanto brillan las grietas (0 cabeza -> 1
// cola), .b = brillo extra, .a = semilla de la piel de ese tramo.
// Mismos marcadores de UV que lombriz.gdshader (dientes x > 1.2, garganta y > 1.5) y espinas x > 3.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);   // #2EC4FF: entre el azul de Godzilla y el turquesa del Serenol
uniform vec3 color_azul : source_color = vec3(0.18, 0.77, 1.0);   // el de las grietas del cuerpo: de donde arrancan las de los puntos debiles
uniform vec3 color_nucleo : source_color = vec3(0.85, 0.98, 1.0);
uniform vec3 color_boca : source_color = vec3(0.25, 0.02, 0.04);
uniform vec3 color_diente : source_color = vec3(0.85, 0.82, 0.7);
uniform float es_saco : hint_range(0.0, 1.0) = 0.0;   // 1 = punto debil de la Madre (MadreCarcamo.gd), con su propio color
uniform float respiracion : hint_range(0.1, 2.0) = 0.25;   // respiraciones por segundo: 0.25 = 15 por minuto (inhalar y exhalar)
uniform float brillo : hint_range(0.0, 4.0) = 1.0;
// Las crias (MallaLombriz.material_crias): una linea azul por el lomo, de la cabeza a la cola, para
// que se distingan (JJ); con ella tampoco llevan grietas. En el tubo de cada tramo (MallaLombriz.tramo) la +Z
// local es el lomo
uniform float linea_lomo : hint_range(0.0, 1.0) = 0.0;
const vec2 PIXELES = vec2(48.0, 24.0);

varying vec4 dato;
varying vec2 uv_crudo;
varying vec3 local;

vec2 azar2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Celdas de Voronoi: x = distancia al centro mas cercano, y = distancia a la orilla de la celda
vec2 celdas(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	vec2 mejor = vec2(0.0);
	vec2 cual = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = azar2(i + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				mejor = r;
				cual = i + g;
			}
		}
	}
	float orilla = 8.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = azar2(i + g);
			vec2 r = g + o - f;
			if (dot(mejor - r, mejor - r) > 0.00001) {
				orilla = min(orilla, dot(0.5 * (mejor + r), normalize(r - mejor)));
			}
		}
	}
	return vec2(sqrt(d1), orilla);
}

// La Madre respira: todo lo que brilla sube al inhalar y se apaga al exhalar (el mismo ritmo en
// todos los materiales, porque TIME es global)
float aliento() {
	float f = 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	return mix(0.05, 1.0, smoothstep(0.0, 1.0, f));
}

void vertex() {
	dato = INSTANCE_CUSTOM;
	uv_crudo = UV;
	local = VERTEX;
	if (UV.x > 2.0 && UV.x < 3.0) {
		float abre = dato.r;
		VERTEX.xz *= mix(1.0, 3.2, abre);
		VERTEX.y += abre * 0.12;
	}
	vec2 afin;
	POSITION = ps1_vertex(VERTEX, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, afin);
}

void fragment() {
	// Los sacos son MeshInstance3D (COLOR blanco): usan el gris de la piel de la Madre
	vec3 tinte = pow(mix(COLOR.rgb, vec3(0.25, 0.27, 0.28), es_saco), vec3(2.2));
	float quemada = mix(0.08, 1.0, COLOR.a);
	if (uv_crudo.x > 3.0) {
		// Espinas y aletas: la piel del cuerpo (los mismos keloides y grietas, en coordenadas del
		// objeto) hasta la mitad, y solo la punta se enciende (uv_crudo.y = 0 base, 1 punta).
		// Los puntos debiles (es_saco) son igual, en su color y mas fuertes.
		float punta = smoothstep(0.45, 1.0, uv_crudo.y);
		// En los puntos debiles las grietas pasan del azul del cuerpo al color de la punta
		vec3 color_g = mix(color_grieta, mix(color_azul, color_grieta, smoothstep(0.0, 0.75, uv_crudo.y)), es_saco);
		vec2 qe = (floor(vec2(local.x + local.z * 2.0, local.y) * 24.0) + 0.5) / 24.0;
		vec2 pe = qe * vec2(2.6, 2.6) + es_saco * 7.0 + dato.a * 19.0;
		vec2 ce = celdas(pe);
		vec2 ce2 = celdas(pe * 2.3 + 9.0);
		float alto_e = smoothstep(0.0, 0.35, ce.y) * (1.0 - ce.x * 0.6);
		float rugoso_e = alto_e * 0.7 + smoothstep(0.0, 0.2, ce2.y) * 0.3;
		vec3 piel = tinte * mix(0.12, 1.2, rugoso_e);
		piel = mix(piel, piel * vec3(1.15, 1.05, 0.95), smoothstep(0.55, 0.9, rugoso_e));
		vec2 gran_e = celdas(qe * 1.6 + 5.0 + es_saco * 3.0);
		float grieta_e = (1.0 - smoothstep(0.015, 0.07, ce.y)) * smoothstep(0.4, 0.8, gran_e.x + 0.2) * (1.0 - punta) * (1.0 - linea_lomo);
		ALBEDO = mix(piel, color_g * 0.3, max(punta * punta, grieta_e)) * quemada;
		ROUGHNESS = mix(0.95, 0.55, alto_e);
		SPECULAR = 0.3;
		float luz_e = punta * punta * (0.5 + dato.b * 0.5 + es_saco * 0.5) + grieta_e * 1.2;
		EMISSION = mix(color_g, color_nucleo, punta * punta) * luz_e * brillo * aliento() * COLOR.a;
	} else if (uv_crudo.y > 1.5) {
		// El fondo de la boca: en la Madre un circulo que brilla (JJ: se veia hueca), blanco azulado
		// al centro y azul hacia la orilla, en pixeles; en las crias oscuro como antes
		float r = clamp(length(local.xz) / 0.6, 0.0, 1.0);
		r = floor(r * 6.0) / 6.0;
		float madre = 1.0 - linea_lomo;
		ALBEDO = mix(color_boca * 0.5, mix(color_nucleo, color_grieta, r) * 0.4, madre);
		ROUGHNESS = 1.0;
		vec3 luz_boca = mix(color_nucleo, color_grieta, smoothstep(0.0, 0.9, r)) * mix(2.5, 1.2, r) * brillo * mix(0.6, 1.0, aliento());
		EMISSION = mix(color_grieta * dato.b * 0.25, luz_boca, madre) * COLOR.a;
	} else if (uv_crudo.x > 1.2) {
		ALBEDO = color_diente;
		ROUGHNESS = 0.4;
	} else {
		// La piel: keloides irregulares, con la semilla del tramo para que no se repita
		vec2 q = (floor(uv_crudo * PIXELES) + 0.5) / PIXELES;
		vec2 p = q * vec2(5.0, 2.5) + vec2(dato.a * 31.0, dato.a * 17.0);
		vec2 c = celdas(p);
		vec2 c2 = celdas(p * 2.3 + 9.0);
		// Altura: abultado al centro de cada keloide, hundido en las orillas
		float alto = smoothstep(0.0, 0.35, c.y) * (1.0 - c.x * 0.6);
		float fino = smoothstep(0.0, 0.2, c2.y);
		float rugoso = alto * 0.7 + fino * 0.3;
		vec3 carne = tinte * mix(0.12, 1.2, rugoso);
		// Un poco de gris calido en las crestas, como la roca ahumada
		carne = mix(carne, carne * vec3(1.15, 1.05, 0.95), smoothstep(0.55, 0.9, rugoso));
		// Grietas: orillas de las celdas grandes, en parches (mas parches hacia la cola)
		vec2 gran = celdas(q * vec2(3.0, 1.6) + dato.a * 13.0 + 5.0);
		float parche = smoothstep(0.4, 0.8, gran.x + (dato.g - 0.5) * 0.9);
		float linea = 1.0 - smoothstep(0.015, 0.07, c.y);
		// Las crias no llevan grietas, solo la linea del lomo (JJ)
		float grieta = linea * parche * step(0.2, dato.g) * (1.0 - linea_lomo);
		float latido = aliento();
		ALBEDO = mix(carne, color_grieta * 0.35, grieta) * quemada;
		vec3 luz = mix(color_grieta, color_nucleo, smoothstep(0.02, 0.0, c.y - 0.03) * 0.6);
		EMISSION = luz * grieta * (3.0 + dato.b) * dato.g * brillo * latido * COLOR.a;
		ROUGHNESS = mix(0.95, 0.55, alto);
		SPECULAR = 0.3;
		if (linea_lomo > 0.0) {
			float arriba = local.z / max(length(local.xz), 0.0001);
			float raya = step(0.982, arriba) * linea_lomo;
			ALBEDO = mix(ALBEDO, color_grieta * 0.45, raya);
			EMISSION = mix(EMISSION, color_grieta * 1.3 * brillo * mix(0.6, 1.0, latido) * COLOR.a, raya);
		}
	}
}
