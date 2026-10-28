shader_type spatial;
// Sin culling: varios modelos de Sketchfab traen caras al reves (Mexican House 3)
render_mode cull_disabled;
// Casas modelo del mapa (MapCasas.gd): como ps1_combined, pero cada casa del
// MultiMesh pinta su muro de su propio color (el color por instancia llega en
// COLOR). Solo cambian los texeles parecidos a muro_key, asi puertas, ventanas
// y herreria se quedan como en la textura. Todo se ensucia segun el deterioro
// de la zona (ps1_deterioro) y los vidrios de `ventanas` se rompen.

#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Color del muro en la textura original y que tan parecido debe ser un texel
// para tomarse como muro (distancia de croma, 0..1)
uniform bool recolor = false;
uniform vec3 muro_key : source_color = vec3(0.9, 0.9, 0.9);
uniform float muro_tol : hint_range(0.0, 1.0) = 0.12;
// Rango de brillo (relativo a muro_key) que todavia es muro: sombras horneadas si,
// marcos negros no
uniform vec2 muro_brillo = vec2(0.45, 1.6);

// Rectangulos de UV (x0, y0, x1, y1) con vidrio, que se rompe o se oscurece
uniform vec4 ventanas[8];
uniform int n_ventanas = 0;

varying vec2 affine_uv;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	affine_uv = uv_out;
	POSITION = clip_position;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 texel = texture(albedo_texture, affine_uv);
	// Recortes (rejas, calcomanias): lo transparente no se dibuja
	if (texel.a < 0.5) {
		discard;
	}
	vec3 tex = texel.rgb * tint.rgb;
	ALBEDO = tex;
	float wall = 0.0;
	if (recolor) {
		float key_luma = max(luma(muro_key), 0.001);
		float tex_luma = max(luma(tex), 0.001);
		float chroma = distance(tex / tex_luma, muro_key / key_luma) / 3.0;
		float ratio = tex_luma / key_luma;
		wall = 1.0 - smoothstep(muro_tol * 0.6, muro_tol, chroma);
		wall *= step(muro_brillo.x, ratio) * step(ratio, muro_brillo.y);
		ALBEDO = mix(tex, COLOR.rgb * ratio, wall);
	}
	float zona = zona_deterioro(world_pos.xz);
	vec3 sucio = mugre(ALBEDO, world_pos, zona);
	if (recolor) {
		sucio = mix(sucio, muro_sucio(ALBEDO, world_pos, zona), wall);
	}
	vec2 uv = fract(affine_uv);
	for (int i = 0; i < n_ventanas; i++) {
		vec4 r = ventanas[i];
		if (uv.x >= r.x && uv.x <= r.z && uv.y >= r.y && uv.y <= r.w) {
			// Cada casa rompe distintas ventanas (el color de la casa sirve de semilla)
			sucio = vidrio_roto(tex, world_pos, zona, hash(COLOR.rg * 31.0 + COLOR.b));
			break;
		}
	}
	ALBEDO = sucio;
	ROUGHNESS = 1.0;
}
