shader_type spatial;
// Piso de relleno del mapa (el plano "Suelo" de map_test, lo que se ve entre casas
// donde OSM2World no pone calle ni banqueta). La textura se repite cada
// tile_size metros segun la posicion en el mundo, asi no depende de los UV del plano.
// La genera tools/map_import/make_textures.py (textures/map/suelo.png).

#include "res://shaders/ps1_vertex.gdshaderinc"

// Con mipmaps: a ras de piso, sin ellos la textura brilla y hace moire a lo lejos
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tile_size = 3.0;

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
	ALBEDO = texture(albedo_texture, world_pos.xz / tile_size).rgb * tint.rgb;
	ROUGHNESS = 1.0;
}
