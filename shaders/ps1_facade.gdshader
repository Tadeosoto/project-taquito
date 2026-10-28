shader_type spatial;
// Fachadas y azoteas de las casas del mapa (models/zona_mapa.glb), con el mismo
// vertex PS1 que ps1_combined. Las texturas las genera
// tools/map_import/make_textures.py: cada mosaico es un tramo de 2.5 m de un piso.

#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

// Fachadas: atlas de 4x4 mosaicos (fila 0 = pisos de arriba, fila 1 = planta baja;
// filas 2 y 3 = lo mismo deteriorado: ventanas rotas o tapiadas, cortinas oxidadas)
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
	POSITION = clip_position;
}

void fragment() {
	if (azotea) {
		// Una variante por color de casa, asi cada casa tiene una sola azotea
		float variant = floor(hash(COLOR.rg * 97.0 + COLOR.b) * 2.0);
		vec2 tile_uv = fract(world_pos.xz / level_height);
		vec3 roof = texture(azoteas, vec2((variant + tile_uv.x) / 2.0, tile_uv.y)).rgb;
		ALBEDO = piso_roto(roof, world_pos.xz, zona_deterioro(world_pos.xz), 2);
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
		// Deteriorado (filas 2 y 3) segun la zona
		float zona = zona_deterioro(world_pos.xz);
		if (hash(vec2(h * 17.0, bay + level * 5.0)) < zona * 0.85) {
			row += 2.0;
		}
		vec2 tile_uv = vec2(fract(UV.x), 1.0 - fract(world_pos.y / level_height + 0.001));
		vec2 atlas_uv = (vec2(col, row) + tile_uv) / vec2(4.0, 4.0);
		vec3 tex = texture(fachadas, atlas_uv).rgb;
		float wall = texture(fachadas_mascara, atlas_uv).r;
		ALBEDO = mix(mugre(tex, world_pos, zona), muro_sucio(tex * COLOR.rgb, world_pos, zona), wall);
	}
	ROUGHNESS = 1.0;
}
