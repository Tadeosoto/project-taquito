// Prueba (JJ 2026-11-17): el monstruo_02 con la piel del Panzon: placas de piedra gris con grietas
// de Serenol que nacen en la panza. Los ojos se dibujan sobre los de la textura (en la UV): esclerotica
// sucia e iris azul que respira con la Madre.
// CUSTOM0 = reposo centrado y en metros (lo llena quien le pone el material).
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
uniform vec3 centro_panza = vec3(0.0, 1.15, 0.08);   // en coordenadas de reposo del modelo
uniform float radio_panza = 0.32;
uniform float placa : hint_range(0.05, 0.6) = 0.16;       // tamano de las placas en metros
uniform float alcance : hint_range(0.5, 4.0) = 2.6;      // hasta donde llegan las grietas (en radios de panza)
uniform float grueso : hint_range(0.01, 0.06) = 0.022;   // ancho entero de las grietas en la panza, en metros
uniform float tupido : hint_range(0.0, 1.0) = 0.35;      // cuantas orillas se abren en la panza
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
uniform float tex_px = 512.0;                  // lado de la textura en pixeles
uniform vec2 ojo_a = vec2(441.0, 161.0);        // pupila de cada lado de la cara, en pixeles de la textura
uniform vec2 ojo_b = vec2(36.5, 229.0);
uniform float ojo_radio = 7.0;
uniform float iris_px = 3.6;
// Camisa rayada roja y blanca, desgarrada (las grietas se ven por los hoyos). Medidas de reposo en T
uniform bool camisa = false;
// diseno: 0 rayas verticales (base y raya), 1 lisa con costados y orillas de color (detalle),
// 2 lisa con rayas diagonales tenues (raya) y orillas de color, 3 polo de escuela: lisa con cuello,
// punos, tapeta y bolsa de color
uniform int diseno = 0;
uniform vec3 color_base : source_color = vec3(0.86, 0.84, 0.78);
uniform vec3 color_raya : source_color = vec3(0.82, 0.10, 0.13);
uniform vec3 color_detalle : source_color = vec3(0.86, 0.84, 0.78);
uniform float raya = 0.032;             // ancho de cada raya (m)
uniform float camisa_desde = 0.98;      // el dobladillo (m de reposo)
uniform float camisa_hasta = 1.74;      // los hombros
uniform float cuello_abre = 1.65;       // el cuello (alrededor del pescuezo)
uniform float manga_hasta = 0.36;       // |x| donde acaba la manga corta
uniform float desgarre : hint_range(0.0, 1.0) = 0.35;   // cuanto esta rota
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
		float pantalon = 0.0;
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
		float luz_cara = 0.0;
		float piel = (1.0 - pantalon) * (1.0 - oro) * (1.0 - luz_cara);
		// Sangre y heridas: se quedan como mancha encima de la piedra
		float sangre = rojo * piel;

		vec3 qp = (floor(reposo / PIXEL) + 0.5) * PIXEL;
		// La camisa: torso entre el dobladillo y el cuello, y mangas cortas sobre los brazos en T.
		// Las orillas van mordidas (jirones) y tiene hoyos, mas grandes en la panza
		float tela = 0.0;
		float orilla_tela = 0.0;
		if (camisa) {
			float jiron = azar3(vec3(floor(qp.x / 0.035), floor(qp.z / 0.035), 5.0)).x * 0.6;
			float jiron2 = azar3(vec3(floor(qp.y / 0.03), floor(qp.z / 0.03), 9.0)).x;
			float dobladillo = camisa_desde + jiron * 0.09;
			// Hasta los hombros; el cuello redondo se abre donde esta el pescuezo (|x| chico)
			float cuello = mix(camisa_hasta, cuello_abre, step(abs(qp.x), 0.075))
					- step(0.0, qp.z) * smoothstep(0.08, 0.0, abs(qp.x)) * 0.04;
			float torso = step(dobladillo, qp.y) * step(qp.y, cuello) * step(abs(qp.x), 0.2);
			float manga = step(0.12, abs(qp.x)) * step(abs(qp.x), manga_hasta - jiron2 * 0.07)
					* step(abs(qp.y - 1.665), 0.1) ;
			float forma = max(torso, manga);
			// Hoyos: celdas grandes; se abren mas cerca de la panza
			float cerca_t = 1.0 - smoothstep(0.2, 2.0, distance(qp, centro_panza) / radio_panza);
			vec3 h1 = celdas(qp / 0.075 + 51.0);
			float abajo_t = 1.0 - smoothstep(1.3, 1.5, qp.y);   // los hombros y el pecho aguantan
			float umbral = mix(1.01, 0.45, desgarre * (0.3 + 0.9 * cerca_t) * abajo_t);
			float hoyo = step(umbral, h1.z) * step(0.06 + 0.1 * azar3(qp * 3.1).x, h1.y);
			// rasgones largos verticales
			float rasgon = step(0.93, azar3(vec3(floor(qp.x / 0.03), floor(qp.y / 0.15), 2.0)).x * (0.6 + 0.8 * desgarre))
					* step(0.6, fract(qp.y / 0.15 + jiron)) * abajo_t;
			tela = forma * (1.0 - max(hoyo, rasgon));
			// La orilla del hoyo: hilos sueltos, un pixel
			float casi = step(umbral, h1.z) * step(h1.y, 0.06 + 0.1 * azar3(qp * 3.1).x + PIXEL * 1.5 / 0.075);
			orilla_tela = forma * casi * (1.0 - hoyo);
		}
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
		// Toda orilla de placa es una juntura honda, aunque no brille
		roca *= mix(0.55, 1.0, smoothstep(0.0, 0.04, c.y));

		// Relieve: la luz sigue los bultos de las placas (gradiente de la altura en pantalla)
		float h = alto * piel * relieve * 0.03 * (1.0 - tela);
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
		// --- La camisa encima ---
		if (camisa) {
			float ax = abs(qp.x);
			float en_torso = step(ax, 0.2) * step(qp.y, camisa_hasta + 0.01);
			float en_manga = step(0.2, ax);
			// Orillas: el cuello (una franja bajo la orilla) y los punos de la manga
			float cuello_y = mix(camisa_hasta, cuello_abre, step(ax, 0.075)) - step(0.0, qp.z) * smoothstep(0.08, 0.0, ax) * 0.04;
			float orilla_cuello = step(cuello_y - 0.03, qp.y) * step(ax, 0.13) * en_torso;
			float puno = en_manga * step(manga_hasta - 0.075, ax);
			vec3 tela_c = color_base;
			float detalle = 0.0;
			if (diseno == 0) {
				tela_c = mix(color_base, color_raya, step(0.5, fract(qp.x / (raya * 2.0) + 0.25)));
			} else if (diseno == 1) {
				// costados de color de la axila al dobladillo
				detalle = max(step(0.165, ax) * en_torso * step(qp.y, 1.58), max(orilla_cuello, puno));
			} else if (diseno == 2) {
				float diag = step(0.5, fract((qp.x * sign(qp.z + 0.001) + qp.y) / (raya * 2.0)));
				tela_c = mix(color_base, color_raya, diag * en_torso);
				detalle = max(orilla_cuello, puno);
			} else {
				// polo: cuello y punos, tapeta con botones al frente y una bolsa en el pecho izquierdo
				float frente = step(0.04, qp.z);
				float tapeta = step(ax, 0.012) * step(1.5, qp.y) * frente;
				float bolsa = step(0.05, qp.x) * step(qp.x, 0.11) * step(1.47, qp.y) * step(qp.y, 1.56) * frente;
				float bolsa_orilla = bolsa * (1.0 - step(0.06, qp.x) * step(qp.x, 0.1) * step(1.48, qp.y) * step(qp.y, 1.545));
				detalle = max(max(orilla_cuello, puno), max(bolsa_orilla, tapeta * 0.0));
				float boton = tapeta * step(fract(qp.y / 0.05), 0.35);
				tela_c = mix(tela_c, color_detalle * 0.6, boton);
				tela_c = mix(tela_c, color_detalle, step(ax, 0.004) * step(1.5, qp.y) * frente);
			}
			tela_c = mix(tela_c, color_detalle, detalle);
			// Mugre: manchas de tierra y de Serenol seco, y el sudor de la textura
			float mugre = azar3(floor(qp / 0.05) + 3.0).x;
			tela_c *= mix(0.75, 1.0, mugre) * mix(0.8, 1.05, lum);
			tela_c = mix(tela_c, vec3(0.25, 0.2, 0.15), step(0.82, azar3(floor(qp / 0.08) + 8.0).x) * 0.6);
			ALBEDO = mix(ALBEDO, tela_c, tela);
			ROUGHNESS = mix(ROUGHNESS, 0.95, tela);
			SPECULAR = mix(SPECULAR, 0.1, tela);
			EMISSION *= 1.0 - tela;
			// Los hilos de la orilla quemados de azul por la grieta de abajo
			ALBEDO = mix(ALBEDO, tela_c * 0.4, orilla_tela);
			EMISSION += color_grieta * orilla_tela * 0.25 * brillo * latido;
		}
		// --- Los ojos, en la textura (pixeles de la textura, se ven duros) ---
		// Cada ojo es un circulo alrededor de su pupila en la UV: esclerotica gris sucia, iris azul que
		// brilla y respira, pupila negra con su brillito
		vec2 px = floor(UV * tex_px) + 0.5;
		float d_ojo = min(distance(px, ojo_a), distance(px, ojo_b));
		vec2 rel = distance(px, ojo_a) < distance(px, ojo_b) ? px - ojo_a : px - ojo_b;
		float esclera_m = step(d_ojo, ojo_radio) * smoothstep(0.45, 0.6, lum + step(d_ojo, iris_px));
		float en_iris2 = step(d_ojo, iris_px);
		float pupila2 = step(d_ojo, iris_px * 0.4);
		float brillo_p = step(length(rel - vec2(-1.0, -1.0)), 0.8);
		vec3 ojo_c = mix(vec3(0.30, 0.29, 0.25) * mix(0.7, 1.1, lum), color_grieta * 0.35, en_iris2);
		ojo_c = mix(ojo_c, vec3(0.01), pupila2);
		ALBEDO = mix(ALBEDO, ojo_c, esclera_m);
		ROUGHNESS = mix(ROUGHNESS, 0.35, esclera_m);
		float anillo2 = step(d_ojo, iris_px * 0.7);
		vec3 luz_iris2 = mix(color_grieta, mix(color_grieta, color_nucleo, 0.5), anillo2);
		EMISSION += luz_iris2 * en_iris2 * (1.0 - pupila2) * 2.2 * brillo * mix(0.55, 1.0, latido);
		EMISSION += vec3(0.9) * brillo_p * en_iris2;
		EMISSION += color_grieta * esclera_m * (1.0 - en_iris2) * 0.08 * brillo * latido;
		// La cuenca: la piedra alrededor del ojo, mas oscura
		ALBEDO *= mix(0.35, 1.0, smoothstep(ojo_radio, ojo_radio + 4.0, d_ojo) + esclera_m);
		EMISSION *= vivo;
	}
}
