shader_type spatial;
// Matas de pasto (MapPasto.gd): dos cuadros cruzados con una textura recortada.
// Se mecen con el viento (solo la punta), toman el color de cada instancia
// (COLOR) y se desvanecen con tramado antes de distancia_fin para no aparecer
// de golpe al caminar.
render_mode cull_disabled;

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float viento = 0.08;
uniform float distancia_inicio = 28.0;
uniform float distancia_fin = 38.0;

varying vec2 tuft_uv;
varying float distancia;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// UV.y = 0 arriba: la punta se mueve, la base no
	float punta = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.7 + world.x * 0.6 + world.z * 0.4) * viento * punta;
	VERTEX.z += cos(TIME * 1.3 + world.z * 0.5) * viento * 0.5 * punta;
	// Luz como si fuera piso, para que no se vean mas oscuras de un lado
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	distancia = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	tuft_uv = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec4 texel = texture(albedo_texture, tuft_uv);
	// Tramado de 4x4 que se va comiendo la mata entre distancia_inicio y _fin
	const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float umbral = (bayer[p.y * 4 + p.x] + 0.5) / 16.0;
	float fade = clamp((distancia - distancia_inicio) / (distancia_fin - distancia_inicio), 0.0, 1.0);
	if (texel.a < 0.5 || fade > umbral) {
		discard;
	}
	ALBEDO = texel.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
