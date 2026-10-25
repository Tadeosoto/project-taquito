shader_type spatial;
// Fachadas y azoteas de las casas del mapa (models/zona_mapa.glb), con el mismo
// vertex PS1 que ps1_combined. Las texturas las genera
// tools/map_import/make_textures.py: cada mosaico es un tramo de 2.5 m de un piso.

#include "res://shaders/ps1_vertex.gdshaderinc"

// Fachadas: atlas de 4x2 mosaicos (fila 0 = pisos de arriba, fila 1 = planta baja)
uniform sampler2D fachadas : source_color, filter_nearest;
// Blanco = pared, se pinta del color de la casa (color de vertice)
uniform sampler2D fachadas_mascara : filter_nearest;
// Azoteas: atlas de 2 mosaicos (impermeabilizante rojo, losa gris)
uniform sampler2D azoteas : source_color, filter_nearest;
uniform bool azotea = false;

// Lo que mide un piso y un mosaico en OSM2World (metros)
uniform float level_height = 2.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	if (jitter_enabled) {
		POSITION = clip_position;
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (azotea) {
		// Una variante por color de casa, asi cada casa tiene una sola azotea
		float variant = floor(hash(COLOR.rg * 97.0 + COLOR.b) * 2.0);
		vec2 tile_uv = fract(world_pos.xz / level_height);
		ALBEDO = texture(azoteas, vec2((variant + tile_uv.x) / 2.0, tile_uv.y)).rgb;
	} else {
		// UV.x de OSM2World ya va en tramos de 2.5 m a lo largo de cada pared
		float level = floor(world_pos.y / level_height + 0.001);
		float bay = floor(UV.x);
		float h = hash(floor(world_pos.xz / 5.0) + vec2(bay * 3.1, level * 13.7));

		float col;
		float row;
		if (level < 1.0) {
			// Planta baja: puerta, cortina, ventana con proteccion, zaguan
			row = 1.0;
			col = h < 0.3 ? 0.0 : (h < 0.5 ? 1.0 : (h < 0.85 ? 2.0 : 3.0));
		} else {
			row = 0.0;
			col = floor(h * 4.0);
		}
		vec2 tile_uv = vec2(fract(UV.x), 1.0 - fract(world_pos.y / level_height + 0.001));
		vec2 atlas_uv = (vec2(col, row) + tile_uv) / vec2(4.0, 2.0);
		vec3 tex = texture(fachadas, atlas_uv).rgb;
		float wall = texture(fachadas_mascara, atlas_uv).r;
		ALBEDO = mix(tex, tex * COLOR.rgb, wall);
	}
	ROUGHNESS = 1.0;
}
