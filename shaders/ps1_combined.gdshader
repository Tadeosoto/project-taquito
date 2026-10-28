shader_type spatial;
// Combined PS1 look: screen-space vertex jitter + view-space vertex wobble
// + affine (non-perspective-correct) texture warping.
// Merges jittershader.gdshader, vertex_wobble.gdshader and affine_warp.gdshader;
// the vertex stage lives in ps1_vertex.gdshaderinc (shared with ps1_facade).

#include "res://shaders/ps1_vertex.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 base_color : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Multiplica por el color de vertice (el mapa de OSM2World guarda ahi el color de cada casa).
uniform bool use_vertex_color = false;

varying vec2 affine_uv;

void vertex() {
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	affine_uv = uv_out;
	POSITION = clip_position;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, affine_uv);
	ALBEDO = tex_color.rgb * tint.rgb;
	if (use_vertex_color) {
		ALBEDO *= COLOR.rgb;
	}
	ROUGHNESS = 1.0;
}
