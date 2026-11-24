// El Panzon de piedra con Serenol (JJ 2026-11-16): placas de roca gris (cada una con su tono, grano
// y relieve) separadas por grietas de Serenol azul que nacen gruesas en la panza y llegan hasta la
// cabeza y las piernas. Los ojos (en los discos negros de las cuencas) tienen iris azul encendido;
// bigote y barba son negros; la boca brilla por dentro al abrirla. Todo lo que brilla respira al ritmo de la Madre
// del Carcamo (aliento(), igual que madre.gdshader: 0.25 Hz sobre el TIME global) y la panza se
// infla un poco al inhalar.
// Las grietas se calculan en 3D sobre la posicion de REPOSO del modelo (CUSTOM0.xyz, la copia
// Panzon._malla_serenol), asi cruzan las costuras de la UV y no resbalan cuando se mueve.
// La piel, la cara y el pantalon tienen casi el mismo color en la textura, asi que la ropa se separa
// por su lugar en el cuerpo de reposo (mirando a +Z), no por color.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D textura : source_color, filter_nearest;
uniform bool original = false;   // true = la textura de antes, para comparar
uniform bool depurar = false;    // franjas de 10 cm por altura de reposo, para medir
uniform vec3 color_piedra : source_color = vec3(0.62, 0.63, 0.63);   // gris piedra
uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);    // #2EC4FF, el de la Madre
uniform vec3 color_nucleo : source_color = vec3(0.85, 0.98, 1.0);
uniform float respiracion : hint_range(0.1, 2.0) = 0.25;   // respiraciones por segundo (la Madre: 0.25)
uniform float brillo : hint_range(0.0, 4.0) = 0.9;
uniform float aliento_fijo : hint_range(-1.0, 1.0) = -1.0;   // >= 0 congela la respiracion (fotos)
uniform float infla : hint_range(0.0, 0.08) = 0.025;   // cuanto crece la panza al inhalar (metros)
uniform vec3 centro_panza = vec3(0.0, 0.95, 0.25);   // en coordenadas de reposo del modelo
uniform float radio_panza = 0.6;
uniform float placa : hint_range(0.05, 0.6) = 0.3;       // tamano de las placas en metros
uniform float alcance : hint_range(0.5, 4.0) = 2.4;      // hasta donde llegan las grietas (en radios de panza)
uniform float grueso : hint_range(0.01, 0.06) = 0.026;   // ancho entero de las grietas en la panza, en metros
uniform float tupido : hint_range(0.0, 1.0) = 0.45;      // cuantas orillas se abren en la panza
uniform float relieve : hint_range(0.0, 3.0) = 1.0;      // que tanto se abultan las placas con la luz
uniform float resplandor : hint_range(0.0, 1.0) = 0.08;  // azul tenue entre las placas de la panza
uniform float tobillo = 0.17;          // alturas de reposo del pantalon (metros)
uniform float cintura_frente = 0.6;
uniform float cintura_atras = 0.85;
uniform float boca_desde = 1.95;       // la cara (metros de reposo): debajo de ojos_desde lo oscuro es
uniform float ojos_desde = 2.06;       // bigote y barba y lo rojo es la boca; arriba, los discos de los ojos
// 0 cerrada, 1 abierta: Panzon.gd lo sube mientras ruge (la boca del modelo nunca queda tapada del todo)
instance uniform float boca_abierta : hint_range(0.0, 1.0) = 0.0;
// 1 vivo, 0 apagado: todo lo azul se apaga (hoy nadie lo baja: al morir el Panzon desaparece)
instance uniform float vivo : hint_range(0.0, 1.0) = 1.0;
uniform vec2 boca_franja = vec2(1.965, 2.04);
uniform vec2 centro_ojo = vec2(0.052, 2.115);   // x (cada lado) y altura del centro de cada disco
uniform float iris : hint_range(0.005, 0.03) = 0.016;
uniform float ceno : hint_range(-1.0, 1.0) = 0.3;   // cuanto baja el parpado hacia la nariz (enojo)
uniform float cara_hasta = 2.26;
const float PIXEL = 0.018;   // los pixeles duros del juego, en metros de reposo

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
	// Sin la copia (CUSTOM0 en ceros) usa el vertice ya animado
	reposo = dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.0 ? CUSTOM0.xyz : VERTEX;
	// La panza se infla al inhalar, mas al centro
	panza_v = 1.0 - smoothstep(0.3, 1.3, distance(reposo, centro_panza) / radio_panza);
	if (!original) {
		VERTEX += NORMAL * panza_v * infla * aliento() * vivo;
	}
	vec2 afin;
	POSITION = ps1_vertex(VERTEX, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, afin);
}

void fragment() {
	vec3 tex = texture(textura, UV).rgb;
	ALBEDO = tex;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	if (depurar) {
		float banda = floor(reposo.y * 10.0);
		ALBEDO = mix(tex, vec3(mod(banda, 2.0), mod(banda, 3.0) / 2.0, mod(banda, 5.0) / 4.0), 0.6);
	} else if (!original) {
		vec3 srgb = pow(tex, vec3(1.0 / 2.2));
		float lum = dot(srgb, vec3(0.33));
		float cintura = cintura_frente + (cintura_atras - cintura_frente) * smoothstep(0.05, -0.3, reposo.z);
		float pantalon = step(tobillo, reposo.y) * (1.0 - step(cintura, reposo.y)) * (1.0 - step(0.3, reposo.z));
		float oro = smoothstep(0.25, 0.35, srgb.r - srgb.b) * smoothstep(0.55, 0.65, srgb.r);
		float rojo = smoothstep(0.08, 0.18, srgb.r - srgb.g);
		// La cara: lo oscuro arriba son los ojos; abajo, la boca (al abrirla se ve oscura y roja)
		float en_cara = step(boca_desde, reposo.y) * (1.0 - step(cara_hasta, reposo.y)) * step(0.0, reposo.z);
		float oscuro = 1.0 - smoothstep(0.14, 0.22, lum);
		float ojos = oscuro * en_cara * step(ojos_desde, reposo.y);
		float abajo = en_cara * (1.0 - step(ojos_desde, reposo.y));
		// La boca es lo rojo entre el bigote y la barba (boca_franja); la sangre que escurre mas abajo
		// se queda como mancha. Cerrada, el bigote la tapa
		float boca = rojo * abajo * step(boca_franja.x, reposo.y) * (1.0 - step(boca_franja.y, reposo.y));
		float barba = oscuro * abajo * (1.0 - boca);
		float luz_cara = max(ojos, max(boca, barba));
		float piel = (1.0 - pantalon) * (1.0 - oro) * (1.0 - luz_cara);
		// Sangre y heridas: se quedan como mancha encima de la piedra
		float sangre = rojo * piel;

		vec3 qp = (floor(reposo / PIXEL) + 0.5) * PIXEL;
		float cerca = 1.0 - smoothstep(0.2, alcance, distance(qp, centro_panza) / radio_panza);

		// Placas de roca, un poco torcidas para que no salgan como caparazon parejo
		vec3 torcido = qp + 0.035 * sin(qp.yzx * 11.0 + vec3(1.7, 4.1, 2.3)) + 0.02 * sin(qp.zxy * 23.0);
		vec3 c = celdas(torcido / placa);
		vec3 k = celdas(qp / (placa * 0.3) + 7.0);   // facetas chicas dentro de cada placa
		float bulto = smoothstep(0.0, 0.3, c.y);      // la placa se abulta al centro y se hunde en la orilla
		float faceta = smoothstep(0.0, 0.25, k.y);
		float grano = azar3(qp * 7.3).x;              // el grano de la piedra, un pixel cada uno
		// Altura de la roca: para el relieve y para el tono
		float alto = bulto * 0.65 + faceta * 0.25 + grano * 0.1;
		vec3 tinte = pow(color_piedra, vec3(2.2));
		// Cada placa con su tono, entre gris frio y gris calido
		tinte *= mix(0.65, 1.2, c.z) * mix(vec3(0.95, 1.0, 1.06), vec3(1.06, 1.0, 0.94), k.z);
		vec3 roca = tinte * mix(0.55, 1.25, alto);
		// Pecas de piedra: unos pixeles mas claros y otros mas oscuros
		roca *= 1.0 + step(0.93, grano) * 0.35 - step(grano, 0.06) * 0.3;

		// Grietas: gruesas en la panza, finas y en ramas sueltas hacia las puntas. El ancho va en
		// metros y nunca baja de un pixel, o se rompen en puntitos (c.y mide desde un lado: x 0.5)
		float ancho = mix(PIXEL * 0.6, grueso, cerca) * 0.5 / placa;
		float linea = 1.0 - step(ancho, c.y);
		vec3 ramas = celdas(torcido / (placa * 1.7) + 31.0);
		float hay = smoothstep(0.5, 0.75, ramas.x * 0.9 + cerca * tupido);
		float grieta = linea * hay * piel * (1.0 - sangre);
		// La orilla de la grieta se ve honda y con un poco del azul reflejado
		float orilla = (1.0 - smoothstep(ancho, ancho + 0.1, c.y)) * hay * (1.0 - linea);
		roca *= mix(1.0, 0.7, orilla);
		// La cuenca: la piedra alrededor de cada ojo se oscurece, para que se vean hundidos
		float a_ojo = length(vec2(abs(qp.x) - centro_ojo.x, (qp.y - centro_ojo.y) * 1.3));
		roca *= mix(0.3, 1.0, smoothstep(0.03, 0.075, a_ojo) + step(qp.z, 0.05) + step(qp.y, 2.04));
		// Toda orilla de placa es una juntura honda, aunque no brille
		roca *= mix(0.55, 1.0, smoothstep(0.0, 0.04, c.y));

		// Relieve: la luz sigue los bultos de las placas (gradiente de la altura en pantalla)
		float h = alto * piel * relieve * 0.03;
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);

		float latido = aliento();
		roca = mix(roca, tex * vec3(0.6, 0.25, 0.25), sangre * 0.8);
		ALBEDO = mix(tex * 0.6, mix(roca, color_grieta * 0.3, grieta), piel);
		ROUGHNESS = mix(0.9, mix(0.95, 0.75, alto), piel);
		// Mas blanca al centro de la grieta y al centro de la panza
		float centro_g = 1.0 - smoothstep(0.0, ancho, c.y);
		vec3 luz = mix(color_grieta, color_nucleo, centro_g * cerca * 0.7);
		EMISSION = luz * grieta * mix(0.35, 1.1, cerca) * brillo * latido;
		EMISSION += color_grieta * orilla * piel * cerca * 0.06 * brillo * latido;
		EMISSION += color_grieta * piel * cerca * cerca * resplandor * (1.0 - bulto * 0.7) * brillo * latido * 0.4;
		// --- La cara ---
		// Ojos, dibujados en el disco de cada cuenca con pixeles de 5 mm: almendra con el parpado de
		// piedra que baja hacia la nariz (ceno), esclerotica gris sucia, iris azul que respira y
		// pupila negra con un brillito. Lo que queda del disco fuera de la almendra es cuenca honda
		vec2 e = floor(vec2(abs(reposo.x) - centro_ojo.x, reposo.y - centro_ojo.y) / 0.005) * 0.005 + 0.0025;
		float parpado = 0.02 + e.x * ceno * 0.5 + e.x * 0.1;   // e.x < 0 es hacia la nariz
		float abajo_ojo = -0.02 + 9.0 * e.x * e.x;
		float almendra = step(abajo_ojo, e.y) * step(e.y, parpado) * step(abs(e.x), 0.036);
		float r = length(e - vec2(0.0, 0.002));
		float en_iris = step(r, iris) * almendra;
		float pupila = step(r, iris * 0.38) * almendra;
		float brillito = step(length(e - vec2(-iris * 0.35, iris * 0.3)), 0.003) * almendra;
		vec3 esclera = vec3(0.32, 0.31, 0.27);
		vec3 ojo = mix(vec3(0.015, 0.016, 0.02), esclera, almendra);   // cuenca / esclerotica
		ojo = mix(ojo, color_grieta * 0.35, en_iris);
		ojo = mix(ojo, vec3(0.01), pupila);
		// El parpado de arriba es de la misma roca, mas oscuro (sombra de la ceja)
		float ceja = step(parpado, e.y) * step(abs(e.x), 0.05);
		ojo = mix(ojo, tinte * 0.35, ceja);
		ALBEDO = mix(ALBEDO, ojo, ojos);
		ROUGHNESS = mix(ROUGHNESS, 0.35, ojos * almendra);
		// El iris: mas claro al centro (anillo de 2 escalones) y la pupila apagada
		float anillo = step(r, iris * 0.7);
		vec3 luz_iris = mix(color_grieta, mix(color_grieta, color_nucleo, 0.5), anillo);
		EMISSION += luz_iris * en_iris * (1.0 - pupila) * 2.0 * brillo * mix(0.55, 1.0, latido) * ojos;
		EMISSION += color_nucleo * brillito * (1.0 - pupila) * 0.0 + vec3(0.9) * brillito * pupila * ojos;
		// Un resplandor tenue en la esclerotica, de la luz del iris
		EMISSION += color_grieta * almendra * (1.0 - en_iris) * 0.06 * brillo * latido * ojos;

		// Bigote y barba: negros, con hebras verticales y un poco de brillo de pelo
		float hebra = azar3(vec3(floor(reposo.x / 0.006), floor(reposo.y / 0.03), 3.0)).x;
		ALBEDO = mix(ALBEDO, vec3(0.012, 0.012, 0.014) * mix(0.6, 2.2, hebra), barba);
		ROUGHNESS = mix(ROUGHNESS, 0.5, barba);
		SPECULAR = mix(SPECULAR, 0.5, barba);

		// La boca por dentro (roja al abrirla): garganta que brilla
		// Cerrada es una raya negra como el bigote; abierta, garganta que brilla
		ALBEDO = mix(ALBEDO, mix(vec3(0.02, 0.01, 0.012), color_grieta * 0.3, boca_abierta), boca);
		EMISSION += mix(color_grieta, color_nucleo, 0.3) * boca * boca_abierta * 1.4 * brillo * mix(0.5, 1.0, latido);
		EMISSION *= vivo;
	}
}
