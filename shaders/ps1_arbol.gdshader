shader_type spatial;
// Arboles del mapa (MapArboles.gd). La textura es un atlas: corteza a la
// izquierda (u < 0.5) y hojas a la derecha. Las hojas se multiplican por el
// color de cada arbol del MultiMesh (llega en COLOR), la corteza no.

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;

varying vec2 atlas_uv;

void vertex() {
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	atlas_uv = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec3 texel = texture(albedo_texture, atlas_uv).rgb;
	ALBEDO = UV.x < 0.5 ? texel : texel * COLOR.rgb;
	ROUGHNESS = 1.0;
}
