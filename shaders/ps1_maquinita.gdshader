shader_type spatial;
// La maquinita de frutas (scripts/map/Maquinita.gd): un solo material para todas, con lo
// que muestra cada una por instancia. El atlas lo dibuja tools/map_import/make_maquinita.gd.
// Las medidas en px son las de Maquinita.gd: si cambian alla, cambiarlas aqui.

#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

global uniform float noche;

uniform sampler2D atlas : source_color, filter_nearest;

const float ATLAS = 1024.0;
const vec2 TABLERO_ORIGEN = vec2(86.0, 172.0);
const float CASILLA = 44.0;
const vec4 CONTADOR_PREMIOS = vec4(60.0, 116.0, 164.0, 44.0);
const vec4 CONTADOR_CREDITOS = vec4(256.0, 116.0, 164.0, 44.0);
const float APUESTA_X = 40.0;
const float APUESTA_Y = 490.0;
const float APUESTA_COLUMNA = 50.0;
const float APUESTA_LADO = 32.0;
// La normal de la rampa de los botones (se hunden contra ella)
const vec3 RAMPA_NORMAL = vec3(0.0, 0.832, 0.555);
const float HUNDIR = 0.009;
// Botones de adorno, que no hacen nada: van apagados (Maquinita: 9, 10 y 12)
const int SEGMENTOS[10] = {63, 6, 91, 79, 102, 109, 125, 7, 127, 111};

// Foco prendido (0-23); -1 = la maquina esta sola y corre su luz de adorno
instance uniform int foco = -1;
// 1 = todos los focos parpadean (acaba de pagar)
instance uniform float festejo = 0.0;
instance uniform vec3 color_gabinete = vec3(1.0, 0.82, 0.1);
// Cuanta luz tiene: menos de 1 = sin monedas, tenue y parpadeando
instance uniform float energia = 1.0;
instance uniform int premios = 0;
instance uniform int creditos = 0;
// 8 digitos de 4 bits, uno por fruta
instance uniform int apuestas = 0;
instance uniform int boton_elegido = -1;
instance uniform int boton_apretado = -1;

varying vec2 atlas_uv;
varying vec3 world_pos;
varying float pinta;
varying float boton;
varying float llama;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// El foco de la casilla (x, y) del tablero de 7 x 7, en sentido del reloj; -1 en medio.
// Igual que Maquinita.celda_foco
int foco_de_casilla(ivec2 c) {
	if (c.y == 0) return c.x;
	if (c.x == 6) return 6 + c.y;
	if (c.y == 6) return 18 - c.x;
	if (c.x == 0) return 24 - c.y;
	return -1;
}

// Un digito de 7 segmentos en `p` (0-1 dentro de su cuadro): 1 segmento prendido,
// 0.5 segmento apagado, 0 fuera de los segmentos
float digito(vec2 p, int valor, bool prendido) {
	float g = 0.13;
	int bits = prendido ? SEGMENTOS[clamp(valor, 0, 9)] : 0;
	float r = 0.0;
	bool ancho = p.x > 0.24 && p.x < 0.76;
	bool izq = p.x > 0.14 && p.x < 0.14 + g;
	bool der = p.x > 0.86 - g && p.x < 0.86;
	bool arriba = p.y > 0.12 && p.y < 0.5;
	bool abajo = p.y > 0.5 && p.y < 0.88;
	if (ancho && p.y > 0.06 && p.y < 0.06 + g) r = (bits & 1) != 0 ? 1.0 : 0.5;
	if (der && arriba) r = (bits & 2) != 0 ? 1.0 : 0.5;
	if (der && abajo) r = (bits & 4) != 0 ? 1.0 : 0.5;
	if (ancho && p.y > 0.94 - g && p.y < 0.94) r = (bits & 8) != 0 ? 1.0 : 0.5;
	if (izq && abajo) r = (bits & 16) != 0 ? 1.0 : 0.5;
	if (izq && arriba) r = (bits & 32) != 0 ? 1.0 : 0.5;
	if (ancho && p.y > 0.5 - g * 0.5 && p.y < 0.5 + g * 0.5) r = (bits & 64) != 0 ? 1.0 : 0.5;
	return r;
}

// Un contador de 4 digitos sin ceros a la izquierda
float contador(vec2 px, vec4 ventana, int valor) {
	vec2 p = (px - ventana.xy) / ventana.zw;
	if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
		return 0.0;
	}
	float cuadro = p.x * 4.0;
	int lugar = 3 - int(cuadro);
	int potencia = lugar == 3 ? 1000 : (lugar == 2 ? 100 : (lugar == 1 ? 10 : 1));
	return digito(vec2(fract(cuadro), p.y), (valor / potencia) % 10, valor >= potencia || lugar == 0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// COLOR.r: esta cara lleva el color del gabinete; .g: que boton es (+1, en 16avos);
	// .b: la llama de la veladora
	pinta = COLOR.r;
	boton = COLOR.g * 16.0 - 1.0;
	llama = COLOR.b;
	vec3 vertex = VERTEX;
	if (boton_apretado >= 0 && int(round(boton)) == boton_apretado) {
		vertex -= RAMPA_NORMAL * HUNDIR;
	}
	if (llama > 0.5) {
		vertex.xz += vec2(sin(TIME * 11.0 + vertex.y * 40.0), cos(TIME * 7.0)) * 0.004;
	}
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	atlas_uv = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec4 tex = texture(atlas, atlas_uv);
	vec2 px = atlas_uv * ATLAS;
	if (llama > 0.5) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(1.0, 0.55, 0.15) * (1.6 + 0.4 * sin(TIME * 13.0));
	} else {
		vec3 base = tex.rgb * mix(vec3(1.0), color_gabinete, pinta);
		float zona = zona_deterioro(world_pos.xz);
		ALBEDO = mugre(base, world_pos, zona * 0.6);
		// Sin monedas se nota de dia: la mica sin su lampara se ve apagada
		if (pinta < 0.5 && energia < 1.0) {
			ALBEDO *= 0.45;
		}
		vec3 luz = vec3(0.0);

		// Sin monedas parpadea a pedazos
		float e = energia;
		if (energia < 1.0) {
			e *= step(0.3, azar(floor(px / 40.0) + floor(TIME * 5.0)));
		}

		int id = int(round(boton));
		if (id >= 0) {
			// Los botones: el elegido brilla y el apretado mas; los de adorno, apagados
			float brillo = (id == 9 || id == 10 || id == 12) ? 0.04 : 0.3 * e;
			if (id == boton_elegido) {
				brillo = 0.9 + 0.35 * sin(TIME * 7.0);
			}
			if (id == boton_apretado) {
				brillo = 2.2;
			}
			luz += tex.rgb * brillo;
		} else {
			// Luz de adorno de la maquina sola: cada una a su ritmo, por donde esta
			float tiempo = TIME * 6.0 + fract(world_pos.x * 0.37 + world_pos.z * 0.71) * 24.0;
			int adorno = energia < 1.0 ? -1 : int(mod(tiempo, 24.0));

			vec2 tablero = (px - TABLERO_ORIGEN) / CASILLA;
			if (px.x < 480.0 && tablero.x >= 0.0 && tablero.y >= 0.0 && tablero.x < 7.0 && tablero.y < 7.0) {
				int f = foco_de_casilla(ivec2(tablero));
				if (f >= 0) {
					int prendido = foco >= 0 ? foco : adorno;
					bool encendido = f == prendido || (festejo > 0.5 && mod(TIME * 8.0, 2.0) < 1.0);
					if (encendido) {
						luz = tex.rgb * 1.3 + vec3(0.25, 0.2, 0.05);
					} else {
						ALBEDO *= 0.55;
					}
				}
			}

			// Contadores: rojo prendido, apagado casi negro
			float digitos = 0.0;
			if (px.x < 480.0 && px.y < 640.0) {
				digitos = max(contador(px, CONTADOR_PREMIOS, premios), contador(px, CONTADOR_CREDITOS, creditos));
				if (px.y >= APUESTA_Y && px.y < APUESTA_Y + APUESTA_LADO && px.x >= APUESTA_X + 9.0) {
					float columna = (px.x - APUESTA_X - 9.0) / APUESTA_COLUMNA;
					int i = int(columna);
					float dentro = fract(columna) * APUESTA_COLUMNA / APUESTA_LADO;
					if (i < 8 && dentro < 1.0) {
						int valor = (apuestas >> (i * 4)) & 15;
						digitos = max(digitos, digito(vec2(dentro, (px.y - APUESTA_Y) / APUESTA_LADO), valor, valor > 0));
					}
				}
			}
			if (digitos > 0.75) {
				luz = vec3(1.0, 0.08, 0.04) * 1.8 * mix(0.5, 1.0, e);
			} else if (digitos > 0.25) {
				luz = vec3(0.16, 0.01, 0.01);
			}

			// Foquitos del atlas (alfa < 0.75): la orilla de LEDs corre
			if (tex.a < 0.75) {
				float corre = step(0.45, fract((px.x + px.y) * 0.0167 - TIME * 0.8));
				luz += tex.rgb * (0.25 + 0.95 * corre) * e * mix(1.0, 1.5, noche);
			}
		}

		// De noche se ve lo pintado de atras de la mica (como si tuviera su lampara)
		if (pinta < 0.5) {
			luz += ALBEDO * noche * 0.35 * energia;
		}
		EMISSION = luz;
	}
	ROUGHNESS = 0.9;
}
