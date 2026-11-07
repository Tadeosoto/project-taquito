shader_type spatial;
// La cortina de lamina de los locales (MapPuntos._cortina): de dia enrollada arriba del vano
// y al anochecer baja. Todas las tiendas comparten este material y el global `cortina`
// (0 arriba, 1 abajo) que pone MapPuntos desde Ciclo.cierre_negocios(), asi que no hay un
// tween por tienda y la que se carga de noche ya sale cerrada.
// La malla es una caja de `alto` centrada en su origen: se enrolla hacia su orilla de arriba.
// Mundo: no brinca como los personajes (sin ps1_vertex).

render_mode cull_disabled;

#include "res://shaders/ps1_deterioro.gdshaderinc"

global uniform float cortina;
uniform float alto = 2.4;
uniform vec3 color : source_color = vec3(0.55, 0.57, 0.6);
uniform vec3 oxido : source_color = vec3(0.42, 0.24, 0.13);
// m entre canal y canal de la lamina
uniform float canal = 0.08;

varying float desde_abajo;
varying float lado;
varying vec3 mundo;

void vertex() {
	float arriba = alto * 0.5;
	float bajada = clamp(cortina, 0.0, 1.0);
	VERTEX.y = arriba - (arriba - VERTEX.y) * bajada;
	// Lo que va de la orilla de abajo de la cortina hacia arriba (m): los canales y la
	// solera bajan con ella, como lamina que se desenrolla
	desde_abajo = VERTEX.y - (arriba - alto * bajada);
	lado = VERTEX.x;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Cuadritos de 1/16 m como lo demas del mundo
	float y = floor(desde_abajo * 64.0) / 64.0;
	float onda = fract(y / canal);
	float sombra = mix(0.78, 1.08, smoothstep(0.0, 0.5, onda) * (1.0 - smoothstep(0.5, 1.0, onda)));
	vec3 c = color * sombra;
	// Mas sucia abajo, donde salpica la calle
	c *= mix(0.75, 1.0, smoothstep(0.0, 0.6, desde_abajo));
	// Oxido segun lo deteriorado de la cuadra
	vec3 p = floor(mundo * 16.0) / 16.0;
	float zona = zona_deterioro(mundo.xz);
	float mancha = smoothstep(0.55, 0.8, ruido2(vec2(p.x + p.z, p.y) * 2.5) + zona * 0.35);
	c = mix(c, oxido * sombra, mancha * zona);
	// La solera de abajo y la jaladera con su candado al centro
	if (desde_abajo < 0.07) {
		c = color * 0.45;
	}
	if (abs(lado) < 0.07 && desde_abajo > 0.09 && desde_abajo < 0.2) {
		c = vec3(0.12, 0.12, 0.13);
	}
	ALBEDO = c;
	ROUGHNESS = 0.6;
	METALLIC = 0.3;
}
