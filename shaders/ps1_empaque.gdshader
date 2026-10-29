shader_type spatial;

// Mercancia de los estantes y mostradores de los interiores (Mostrador.gd, Estante.gd):
// un MultiMesh de cajas de 1 m escaladas. INSTANCE_CUSTOM.x = etiqueta del atlas
// (textures/interiores/empaques.png, tools/make_empaques.py), INSTANCE_CUSTOM.y = 1 si
// lleva etiqueta (0: solo su color, p. ej. las herramientas y las piezas sueltas).
// El frente (+Z) lleva la etiqueta entera; los lados y arriba estiran su orilla, asi
// la caja se ve del mismo empaque. COLOR oscurece la hilera de atras.
// Con `desgaste` > 0 se ensucia como los muebles (ps1_gastado.gdshaderinc).

render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/ps1_deterioro.gdshaderinc"
#include "res://shaders/ps1_gastado.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform vec2 celdas = vec2(8.0, 4.0);
// Uso y polvo (ps1_gastado); las piezas sin etiqueta (alambres, herramientas) son
// fierro pintado y se despostillan
uniform float desgaste = 0.0;

varying vec3 world_pos;

varying vec2 uv_etiqueta;
varying flat float etiqueta;
varying flat float con_etiqueta;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	etiqueta = INSTANCE_CUSTOM.x;
	con_etiqueta = INSTANCE_CUSTOM.y;
	vec3 p = VERTEX + 0.5;
	if (NORMAL.z > 0.5) {
		uv_etiqueta = vec2(p.x, 1.0 - p.y);
	} else if (abs(NORMAL.x) > 0.5) {
		uv_etiqueta = vec2(NORMAL.x > 0.0 ? 0.96 : 0.04, 1.0 - p.y);
	} else if (NORMAL.y > 0.5) {
		uv_etiqueta = vec2(p.x, 0.03);
	} else {
		uv_etiqueta = vec2(p.x, 0.97);
	}
}

void fragment() {
	vec3 color = COLOR.rgb;
	if (con_etiqueta > 0.5) {
		vec2 celda = vec2(mod(etiqueta, celdas.x), floor(etiqueta / celdas.x));
		vec2 uv = (celda + clamp(uv_etiqueta, 0.02, 0.98)) / celdas;
		color *= texture(atlas, uv).rgb;
	}
	if (desgaste > 0.0) {
		vec3 normal_mundo = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		color = gastado(color, world_pos, normal_mundo, clamp(desgaste + zona_deterioro(world_pos.xz) * 0.4, 0.0, 1.0), con_etiqueta < 0.5);
	}
	ALBEDO = color;
}
