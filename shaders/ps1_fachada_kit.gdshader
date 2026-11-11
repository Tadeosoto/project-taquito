shader_type spatial;
// Paredes de las casas del mapa hecho en Blender (tools/blender/mapa/kit.py, material
// "fachada_kit"). A diferencia de ps1_facade, aqui no se escoge nada: las UV ya apuntan al
// mosaico del atlas que se puso en Blender (lo que se ve alla es lo que sale aca). El color
// de la casa viene como color de vertice y solo pinta donde la mascara es blanca; la mugre y
// las grietas son las de ps1_facade, segun el deterioro de la zona; encima, la humedad y el
// salitre de abajo (humedad()).

#define PS1_MUNDO
#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

uniform sampler2D fachadas : source_color, filter_nearest;
uniform sampler2D fachadas_mascara : filter_nearest;
// Que tan vivo sale el color de la casa (1 = el de Blender): las fachadas se veian deslavadas
uniform float saturacion = 1.2;
// Humedad que sube del piso (m, alto de la mancha) y su costra de salitre en la orilla
uniform vec2 humedad_alto = vec2(0.5, 1.2);
uniform float humedad_fuerza = 0.3;
uniform float salitre_fuerza = 0.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	POSITION = clip_position;
}

// La humedad que sube por capilaridad: una franja oscura y verdosa de borde ondulado y, en su
// orilla, costra blanca de salitre. Cuadritos de 1/16 m como muro_sucio
vec3 humedad(vec3 c, vec3 p) {
	p = floor(p * 16.0) / 16.0;
	float h = p.x + p.z;
	float tope = mix(humedad_alto.x, humedad_alto.y, ruido(vec2(h * 0.8, 7.0)));
	float moja = 1.0 - smoothstep(tope - 0.15, tope, p.y);
	c *= 1.0 - moja * humedad_fuerza;
	c = mix(c, c * vec3(0.85, 0.9, 0.8), moja * 0.5);
	float borde = smoothstep(tope - 0.22, tope - 0.05, p.y) * (1.0 - smoothstep(tope - 0.05, tope + 0.06, p.y));
	float costra = step(0.55, ruido(vec2(h * 9.0, p.y * 14.0)));
	return mix(c, vec3(0.86, 0.84, 0.78), borde * costra * salitre_fuerza);
}

void fragment() {
	vec3 tex = texture(fachadas, UV).rgb;
	float wall = texture(fachadas_mascara, UV).r;
	float zona = zona_deterioro(world_pos.xz);
	vec3 color = mix(vec3(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114))), COLOR.rgb, saturacion);
	vec3 muro = humedad(muro_sucio(tex * clamp(color, 0.0, 1.0), world_pos, zona), world_pos);
	ALBEDO = mix(mugre(tex, world_pos, zona), muro, wall);
	ROUGHNESS = 1.0;
}
