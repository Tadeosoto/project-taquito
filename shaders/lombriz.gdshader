// Las lombrices y la Madre del Carcamo (MallaLombriz.gd): carne gris parda con anillos, panza
// mas clara y venas de Serenol turquesa que brillan de noche, con los pixeles duros del juego
// (la UV se redondea a una rejilla de PIXELES) y el brinco de vertices de los personajes.
// De un MultiMesh: COLOR es el tinte (sRGB; alfa = quemada), INSTANCE_CUSTOM.r = que tan abierta
// la boca, .g = semilla de las venas, .b = brillo extra (la Madre, los sacos).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform float brillo_venas : hint_range(0.0, 4.0) = 0.6;  // EnjambreLombrices lo sube de noche
uniform vec3 color_vena : source_color = vec3(0.15, 0.95, 0.85);
uniform vec3 color_boca : source_color = vec3(0.25, 0.02, 0.04);
uniform vec3 color_diente : source_color = vec3(0.92, 0.88, 0.72);
const vec2 PIXELES = vec2(12.0, 6.0);

varying vec4 dato;
varying vec2 uv_crudo;

void vertex() {
	dato = INSTANCE_CUSTOM;
	uv_crudo = UV;
	// Puntas de los dientes: la boca se abre hacia afuera y adelante
	if (UV.x > 2.0) {
		float abre = dato.r;
		VERTEX.xz *= mix(1.0, 3.2, abre);
		VERTEX.y += abre * 0.12;
	}
	vec2 afin;
	POSITION = ps1_vertex(VERTEX, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, afin);
}

void fragment() {
	vec3 tinte = pow(COLOR.rgb, vec3(2.2));
	if (uv_crudo.y > 1.5) {
		// Garganta
		ALBEDO = color_boca * 0.5;
		ROUGHNESS = 1.0;
		EMISSION = color_vena * dato.b * 0.2;
	} else if (uv_crudo.x > 1.2) {
		ALBEDO = color_diente;
		ROUGHNESS = 0.4;
	} else {
		vec2 q = (floor(uv_crudo * PIXELES) + 0.5) / PIXELES;
		// Anillos: los extremos de cada tramo mas oscuros
		float anillo = smoothstep(0.62, 0.9, abs(q.y - 0.5) * 2.0);
		// Panza mas clara (el lado de abajo del tubo, aprox.)
		float panza = smoothstep(0.35, 0.0, abs(q.x - 0.75));
		vec3 carne = tinte * (1.0 - anillo * 0.45) * (1.0 + panza * 0.35);
		// Venas: una linea por cada costado (arriba y abajo del tubo) que serpentea tantito
		float onda = sin(q.y * 6.2832 + dato.g * 6.2832) * 0.04;
		float x = fract(uv_crudo.x - onda);
		float vena = 1.0 - step(0.045, min(abs(x - 0.25), abs(x - 0.75)));
		vena *= step(0.5, fract(q.y * 2.0 + dato.g));
		ALBEDO = mix(carne, color_vena * 0.4, vena * 0.4);
		EMISSION = color_vena * vena * (brillo_venas + dato.b) * 0.6;
		// Mojada: brillo en escalones, como plastico de PS1
		ROUGHNESS = 0.3;
		SPECULAR = 0.7;
		// Quemada: negra y opaca
		ALBEDO *= mix(0.08, 1.0, COLOR.a);
		EMISSION *= COLOR.a;
	}
}
