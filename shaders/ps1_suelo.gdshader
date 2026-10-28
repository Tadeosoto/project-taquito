shader_type spatial;
// Pisos del mapa: el plano "Suelo" de map_test (lo que se ve entre casas donde
// OSM2World no pone calle ni banqueta) y los pisos de OSM2World que
// MapPostImport.GROUND_TEXTURES cambia (tierra, banqueta, asfalto, pasto...).
// La textura se repite cada tile_size metros segun la posicion en el mundo, asi
// no depende de los UV y dos pisos encimados se ven identicos (no parpadean).
// Las texturas las genera tools/map_import/make_textures.py (textures/map/).
//
// modo 1 (tierra con pasto): donde la mascara satelital (textures/map/pasto_mascara.png,
// tools/map_import/make_vegetacion.py) dice pasto, se pinta pasto en vez de
// albedo_texture. modo 2: todo es pasto (camellones y jardines de OSM2World).

#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

// Con mipmaps: a ras de piso, sin ellos la textura brilla y hace moire a lo lejos
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tile_size = 3.0;

// 0 = solo albedo_texture, 1 = tierra/pasto segun la mascara, 2 = todo pasto
uniform int modo = 0;
// Como se deteriora (ps1_deterioro piso_roto): 0 nada, 1 asfalto, 2 banqueta, 3 empedrado
uniform int piso_tipo = 0;
uniform sampler2D mascara_pasto : filter_linear, repeat_disable;
// Esquina (x, z) de la mascara en el mundo y lo que mide (m)
uniform vec2 mascara_origen = vec2(0.0);
uniform vec2 mascara_tamano = vec2(1.0);
uniform sampler2D pasto_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D pasto_seco_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform float pasto_tile = 2.5;
// Manchas de pasto seco: tamano (m) y cuanto del pasto es seco (0..1)
uniform float seco_escala = 18.0;
uniform float seco_cantidad = 0.3;
// Lo que el ruido mueve la orilla del pasto (en unidades de la mascara) y el
// tamano (m) de los cuadritos de esa orilla
uniform float orilla_ruido = 0.35;
uniform float orilla_cuadro = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	POSITION = clip_position;
}

vec3 pasto(vec2 xz, float zona) {
	vec2 uv = xz / pasto_tile;
	float n = ruido(xz / seco_escala) * 0.7 + ruido(xz / (seco_escala * 0.31)) * 0.3;
	// Sin quien lo riegue: mas pasto seco donde hay mas deterioro
	float cantidad = min(seco_cantidad + zona * 0.4, 1.0);
	float seco = smoothstep(1.0 - cantidad - 0.08, 1.0 - cantidad + 0.08, n);
	return mix(texture(pasto_texture, uv).rgb, texture(pasto_seco_texture, uv).rgb, seco);
}

void fragment() {
	float zona = zona_deterioro(world_pos.xz);
	vec3 color = piso_roto(texture(albedo_texture, world_pos.xz / tile_size).rgb, world_pos.xz, zona, piso_tipo);
	if (modo == 2) {
		color = pasto(world_pos.xz, zona);
	} else if (modo == 1) {
		float m = texture(mascara_pasto, (world_pos.xz - mascara_origen) / mascara_tamano).r;
		// Orilla en cuadritos, como si el pasto estuviera pintado en una rejilla PS1
		float n = hash(floor(world_pos.xz / orilla_cuadro)) - 0.5;
		if (m + n * orilla_ruido > 0.5) {
			color = pasto(world_pos.xz, zona);
		}
	}
	ALBEDO = color * tint.rgb;
	ROUGHNESS = 1.0;
}
