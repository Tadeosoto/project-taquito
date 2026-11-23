// El Simi gigante con Serenol (JJ 2026-11-22): la piel del Panzon y los zombis (placas de piedra gris con
// grietas azules que nacen en la panza) debajo de la bata blanca, que va sucia y rota: por los hoyos se
// ven las placas y las grietas, y las orillas de la tela estan quemadas de azul. La cara y las manos son
// piedra; la corbata azul se queda. Los ojos (otra malla) brillan con iris azul.
// CUSTOM0 = reposo centrado y en metros de un Simi de 1.75 m (lo llena SimiSerenol.gd).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D textura : source_color, filter_nearest;
uniform int parte = 0;           // 0 cuerpo, 1 bigote y pelo, 2 ojos
uniform bool original = false;   // true = la textura de antes, para comparar
uniform vec3 color_piedra : source_color = vec3(0.62, 0.63, 0.63);
uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);    // #2EC4FF, el de la Madre
uniform vec3 color_nucleo : source_color = vec3(0.85, 0.98, 1.0);
uniform vec3 color_bata : source_color = vec3(0.82, 0.83, 0.80);
uniform float respiracion : hint_range(0.1, 2.0) = 0.25;
uniform float brillo : hint_range(0.0, 4.0) = 0.85;
uniform float aliento_fijo : hint_range(-1.0, 1.0) = -1.0;   // >= 0 congela la respiracion (fotos)
uniform float infla : hint_range(0.0, 0.08) = 0.03;
uniform float unidades = 1.0;   // unidades de la malla por metro de reposo (SimiSerenol lo pone)
uniform vec3 centro_panza = vec3(0.0, 0.95, 0.1);
uniform float radio_panza = 0.3;
uniform float placa : hint_range(0.05, 0.6) = 0.12;
uniform float alcance : hint_range(0.5, 6.0) = 1.9;
uniform float grueso : hint_range(0.01, 0.06) = 0.024;
uniform float tupido : hint_range(0.0, 1.0) = 0.2;
uniform float relieve : hint_range(0.0, 3.0) = 1.0;
uniform float resplandor : hint_range(0.0, 1.0) = 0.0;
// 1 con la bata puesta, 0 sin ella (fase 2 del jefe: se le cae y queda toda la piedra a la vista)
instance uniform float con_bata : hint_range(0.0, 1.0) = 1.0;
uniform float desgarre : hint_range(0.0, 1.0) = 0.3;   // cuanto esta rota la bata (en la panza; lejos, casi nada)
uniform vec3 ojo_a = vec3(-0.04, 1.55, 0.1);   // centro de cada ojo (reposo)
uniform vec3 ojo_b = vec3(0.04, 1.55, 0.1);
uniform float ojo_radio = 0.03;
uniform float venas_bata : hint_range(0.0, 1.0) = 0.5;   // que tanto brillan las grietas a traves de la tela
instance uniform float vivo : hint_range(0.0, 1.0) = 1.0;
const float PIXEL = 0.012;

varying vec3 reposo;
varying float panza_v;

vec3 azar3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Voronoi 3D: x = distancia al centro, y = distancia a la orilla, z = un azar de la celda
vec3 celdas(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	vec3 mejor = vec3(0.0);
	vec3 cual = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + azar3(i + g) - f;
				float d = dot(r, r);
				if (d < d1) {
					d1 = d;
					mejor = r;
					cual = g;
				}
			}
		}
	}
	float orilla = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = cual + vec3(float(x), float(y), float(z));
				vec3 r = g + azar3(i + g) - f;
				if (dot(mejor - r, mejor - r) > 0.00001) {
					orilla = min(orilla, dot(0.5 * (mejor + r), normalize(r - mejor)));
				}
			}
		}
	}
	return vec3(sqrt(d1), orilla, azar3(i + cual + 17.0).x);
}

float aliento() {
	float f = aliento_fijo >= 0.0 ? aliento_fijo : 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	return mix(0.05, 1.0, smoothstep(0.0, 1.0, f));
}

void vertex() {
	reposo = dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.0 ? CUSTOM0.xyz : VERTEX;
	panza_v = 1.0 - smoothstep(0.3, 1.4, distance(reposo, centro_panza) / radio_panza);
	if (!original && parte == 0) {
		VERTEX += NORMAL * panza_v * infla * aliento() * vivo * unidades;
	}
	vec2 afin;
	POSITION = ps1_vertex(VERTEX, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, afin);
}

void fragment() {
	vec3 tex = texture(textura, UV).rgb;
	ALBEDO = tex;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	float latido = aliento();
	vec3 qp = (floor(reposo / PIXEL) + 0.5) * PIXEL;
	if (original) {
		// nada
	} else if (parte == 2) {
		// Los ojos: esclerotica gris sucia, iris azul que respira, pupila negra con su brillito
		vec3 ca = distance(qp, ojo_a) < distance(qp, ojo_b) ? ojo_a : ojo_b;
		vec2 rel = (qp - ca).xy / ojo_radio;
		float d = length(rel);
		float iris = 1.0 - step(0.55, d);
		float pupila = 1.0 - step(0.22, d);
		float brillito = 1.0 - step(0.12, length(rel - vec2(-0.18, 0.2)));
		vec3 c = mix(vec3(0.28, 0.27, 0.24), color_grieta * 0.35, iris);
		ALBEDO = mix(c, vec3(0.01), pupila);
		ROUGHNESS = 0.35;
		EMISSION = mix(color_grieta, color_nucleo, 1.0 - step(0.38, d)) * iris * (1.0 - pupila) * 2.4 * brillo * mix(0.55, 1.0, latido);
		EMISSION += vec3(0.9) * brillito;
		EMISSION += color_grieta * (1.0 - iris) * 0.1 * brillo * latido;
		EMISSION *= vivo;
	} else if (parte == 1) {
		// Bigote, barba y cejas: canas sucias con polvo de piedra, azul en la raiz
		float lum = dot(tex, vec3(0.33));
		ALBEDO = mix(vec3(0.30, 0.31, 0.32), vec3(0.62, 0.64, 0.66), lum);
		ROUGHNESS = 1.0;
		EMISSION = color_grieta * smoothstep(0.35, 0.1, lum) * 0.15 * brillo * latido * vivo;
	} else {
		vec3 srgb = pow(tex, vec3(1.0 / 2.2));
		float lum = dot(srgb, vec3(0.333));
		float rosa = smoothstep(0.08, 0.16, srgb.r - srgb.b);
		float azul = smoothstep(0.15, 0.3, srgb.b - srgb.r);
		float oscuro = 1.0 - smoothstep(0.15, 0.3, lum);
		// La bata: lo blanco
		float blanco = (1.0 - rosa) * (1.0 - azul) * (1.0 - oscuro);

		float cerca = 1.0 - smoothstep(0.2, alcance, distance(qp, centro_panza) / radio_panza);
		// --- La piedra (debajo de todo) ---
		vec3 torcido = qp + 0.03 * sin(qp.yzx * 13.0 + vec3(1.7, 4.1, 2.3)) + 0.015 * sin(qp.zxy * 27.0);
		vec3 c = celdas(torcido / placa);
		vec3 k = celdas(qp / (placa * 0.3) + 7.0);
		float bulto = smoothstep(0.0, 0.3, c.y);
		float faceta = smoothstep(0.0, 0.25, k.y);
		float grano = azar3(qp * 7.3).x;
		float alto = bulto * 0.65 + faceta * 0.25 + grano * 0.1;
		vec3 tinte = pow(color_piedra, vec3(2.2));
		tinte *= mix(0.65, 1.2, c.z) * mix(vec3(0.95, 1.0, 1.06), vec3(1.06, 1.0, 0.94), k.z);
		vec3 roca = tinte * mix(0.55, 1.25, alto);
		roca *= 1.0 + step(0.93, grano) * 0.35 - step(grano, 0.06) * 0.3;
		// La cara y las manos (lo rosa): grietas de un pixel, aunque las manos queden junto a la panza
		float ancho = mix(mix(PIXEL * 0.6, grueso, cerca), PIXEL * 1.1, rosa) * 0.5 / placa;
		float linea = 1.0 - step(ancho, c.y);
		vec3 ramas = celdas(torcido / (placa * 1.7) + 31.0);
		float hay = smoothstep(0.66, 0.86, ramas.x * 0.9 + cerca * tupido * (1.0 - rosa));
		// En la cara y las manos, grietas finas pero que si llegan
		hay = max(hay, rosa * smoothstep(0.45, 0.7, ramas.x));
		float grieta = linea * hay;
		float orilla = (1.0 - smoothstep(ancho, ancho + 0.1, c.y)) * hay * (1.0 - linea);
		roca *= mix(1.0, 0.7, orilla);
		roca *= mix(0.55, 1.0, smoothstep(0.0, 0.04, c.y));

		// --- La bata encima, con hoyos (mas y mas grandes en la panza) y rasgones ---
		float jiron = azar3(vec3(floor(qp.x / 0.03), floor(qp.z / 0.03), 5.0)).x;
		vec3 h1 = celdas(qp / 0.07 + 51.0);
		float umbral = mix(1.01, 0.35, desgarre * (0.12 + 1.3 * cerca * cerca));
		float borde_h = 0.05 + 0.1 * azar3(floor(qp / PIXEL) * 3.1).x;
		float hoyo = step(umbral, h1.z) * step(borde_h, h1.y);
		float rasgon = step(0.94, azar3(vec3(floor(qp.x / 0.025), floor(qp.y / 0.14), 2.0)).x * (0.6 + 0.8 * desgarre * cerca))
				* step(0.55, fract(qp.y / 0.14 + jiron));
		// el dobladillo de abajo comido en jirones (los zapatos y el pantalon son bata tambien en la textura)
		float tela = blanco * (1.0 - max(hoyo, rasgon)) * step(0.5, con_bata);
		float quemado = step(0.5, con_bata) * blanco * step(umbral, h1.z) * step(h1.y, borde_h + PIXEL * 1.6 / 0.07) * (1.0 - hoyo);

		// Relieve de las placas donde se ve piedra
		float piedra = 1.0 - tela;
		float h = alto * relieve * 0.03 * piedra * (1.0 - azul);
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);

		// Lo oscuro de la textura (boca, pelos parados, cejas) se queda oscuro sobre la piedra
		roca = mix(roca, vec3(0.03, 0.03, 0.035), oscuro);
		grieta *= 1.0 - oscuro;
		ALBEDO = mix(roca, color_grieta * 0.3, grieta);
		ROUGHNESS = mix(0.95, 0.75, alto);
		float centro_g = 1.0 - smoothstep(0.0, ancho, c.y);
		vec3 luz = mix(color_grieta, color_nucleo, centro_g * cerca * 0.7);
		vec3 emi = luz * grieta * mix(0.35, 1.1, cerca) * brillo * latido;
		emi += color_grieta * cerca * cerca * resplandor * (1.0 - bulto * 0.7) * brillo * latido * 0.4;
		EMISSION = emi;

		// La bata: blanca sucia, manchas de tierra y de Serenol seco, mas mugre abajo
		float mugre = azar3(floor(qp / 0.05) + 3.0).x;
		vec3 bata = color_bata * mix(0.72, 1.0, mugre);
		bata = mix(bata, vec3(0.30, 0.25, 0.18), step(0.84, azar3(floor(qp / 0.07) + 8.0).x) * 0.55);
		bata *= mix(0.6, 1.0, smoothstep(0.0, 0.6, qp.y));   // tierra en las piernas
		ALBEDO = mix(ALBEDO, bata, tela);
		ROUGHNESS = mix(ROUGHNESS, 0.95, tela);
		SPECULAR = mix(SPECULAR, 0.1, tela);
		EMISSION *= 1.0 - tela;
		ALBEDO = mix(ALBEDO, bata * 0.3, quemado);
		// Las grietas siguen por debajo de la tela: lineas que brillan a traves de ella, como venas
		float vena = grieta * tela * (1.0 - quemado);
		ALBEDO = mix(ALBEDO, mix(bata, color_grieta, 0.5) * 0.6, vena * venas_bata);
		EMISSION += luz * vena * mix(0.25, 0.8, cerca) * venas_bata * brillo * latido;
		// La corbata se queda azul (sucia)
		ALBEDO = mix(ALBEDO, tex * 0.8, azul);
		EMISSION *= (1.0 - azul) * vivo;
	}
}
