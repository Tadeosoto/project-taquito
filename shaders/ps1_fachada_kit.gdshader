shader_type spatial;
// Paredes de las casas del mapa hecho en Blender (tools/blender/mapa/kit.py, material
// "fachada_kit"). A diferencia de ps1_facade, aqui no se escoge nada: las UV ya apuntan al
// mosaico del atlas que se puso en Blender (lo que se ve alla es lo que sale aca). El color
// de la casa viene como color de vertice y solo pinta donde la mascara es blanca; la mugre y
// las grietas son las de ps1_facade, segun el deterioro de la zona.

#define PS1_MUNDO
#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

uniform sampler2D fachadas : source_color, filter_nearest;
uniform sampler2D fachadas_mascara : filter_nearest;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	POSITION = clip_position;
}

void fragment() {
	vec3 tex = texture(fachadas, UV).rgb;
	float wall = texture(fachadas_mascara, UV).r;
	float zona = zona_deterioro(world_pos.xz);
	ALBEDO = mix(mugre(tex, world_pos, zona), muro_sucio(tex * COLOR.rgb, world_pos, zona), wall);
	ROUGHNESS = 1.0;
}
