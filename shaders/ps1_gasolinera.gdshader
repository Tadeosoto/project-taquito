shader_type spatial;
// La gasolinera del mapa (models/tiendas/gasolinera, AspectStudios): el modelo trae todo en
// colores planos de una paleta de 8x8 celdas (albedo_texture, por UV), lo que se veia de
// caricatura (JJ). Aqui cada color se vuelve un material, segun de que pieza sea: el color de
// vertice trae la clase que le pone MapPuntos (_clasificar_gasolinera, porque el modelo pinta
// igual de blanco la pared de la tienda, la isla, el techo y la columna): 0.2 pared de concreto
// (la tienda), 0.4 banqueta (la isla y la base del cartel), 0.6 metal (el techo, la columna y el
// poste del cartel); 1.0 sin clase. Lo gris (los postes de las bombas) tambien es metal, lo blanco
// sin clase (las bombas) es fierro pintado con grano, el verde pintura de fierro despostillada y
// el vidrio azul se oscurece con reflejos. Las texturas (textures/map/
// gasolinera_*.png, tools/make_texturas_gasolinera.py) se proyectan en 3D, en el espacio del
// modelo (alineadas con sus paredes aunque el lote este girado), y encima va `gastado()`
// (ps1_gastado: mugre que sube del piso, escurrimientos, polvo, rayones) con el deterioro de la
// zona. Sin brinco de vertices: es mundo (PS1_MUNDO), como las casas y las tiendas.

#define PS1_MUNDO
#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"
#include "res://shaders/ps1_gastado.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D concreto : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D aplanado : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D metal : source_color, filter_nearest_mipmap, repeat_enable;
// textures/map/banqueta.png, la de las banquetas del mapa; su luz media, para no oscurecer
uniform sampler2D banqueta : source_color, filter_nearest_mipmap, repeat_enable;
const vec3 BANQUETA_MEDIA = vec3(0.26, 0.24, 0.19);
// Mosaicos de textura por metro (del modelo)
uniform float escala = 0.45;
// Toda la estacion con la textura de la banqueta (JJ, 2026-11-10): lo blanco y lo gris (isla, pared,
// techo, columnas, postes, bombas) es concreto de banqueta; sigue pintado lo verde y rojo, y el
// vidrio; el verde y el rojo conservan su color. Apagado, cada pieza usa su clase (pared, banqueta, metal)
uniform bool todo_banqueta = true;
// Cuanto uso tiene (se le suma la zona): poco, que los colores se sigan viendo
uniform float desgaste = 0.28;

varying vec2 affine_uv;
varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = VERTEX;
	local_normal = NORMAL;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	vec4 clip_position = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
	affine_uv = uv_out;
	POSITION = clip_position;
}

// La textura proyectada por los tres ejes, mezclada por hacia donde ve la cara
vec3 triplanar(sampler2D t, vec3 p, vec3 n, float tamano) {
	vec3 w = pow(abs(n), vec3(8.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy * tamano).rgb * w.x + texture(t, p.xz * tamano).rgb * w.y + texture(t, p.xy * tamano).rgb * w.z;
}

void fragment() {
	vec3 c = texture(albedo_texture, affine_uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 n_mundo = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float zona = zona_deterioro(world_pos.xz);
	// Los colores de la paleta (en lineal): blancos, grises, el verde de las barras y el azul del vidrio
	bool blanco = l > 0.7 && sat < 0.12;
	bool gris = l > 0.25 && l <= 0.7 && sat < 0.1;
	bool verde = c.g > 2.0 * c.r && c.g > 1.4 * c.b;
	bool vidrio = c.b > 0.8 && c.b - c.r > 0.5;
	bool pintura = verde || (c.r > 2.0 * c.g && c.r > 2.0 * c.b);   // verde o rojo: fierro pintado
	// La clase de la pieza (color de vertice; sin ella, blanco)
	float clase = COLOR.r;
	bool es_pared = clase < 0.3;
	bool es_banqueta = clase >= 0.3 && clase < 0.5;
	bool es_metal = (clase >= 0.5 && clase < 0.7) || gris;
	bool de_clase = clase < 0.7;
	float brillo = 1.0;
	vec3 col = c;
	if (vidrio) {
		// Vidrio sucio: oscuro, con una franja de reflejo en diagonal
		float reflejo = smoothstep(0.42, 0.5, fract((local_pos.y * 0.35 + local_pos.z * 0.25 + local_pos.x * 0.25) * 1.2));
		col = mix(vec3(0.02, 0.06, 0.1), c * 0.5, 0.5) + vec3(reflejo * 0.05);
	} else if (pintura) {
		// Pintura: su color sobre la textura de la banqueta (o, sin todo_banqueta, grano suave)
		if (todo_banqueta) {
			col = c * triplanar(banqueta, local_pos, local_normal, escala * 1.2) / BANQUETA_MEDIA * vec3(0.5, 0.5, 0.5) * 2.0;
		} else {
			col = c * triplanar(aplanado, local_pos, local_normal, escala * 2.2) / 0.7;
		}
	} else if ((es_banqueta || todo_banqueta) && (blanco || gris)) {
		// La banqueta: concreto como el de las banquetas del mapa
		col = vec3(l) * triplanar(banqueta, local_pos, local_normal, escala * 1.2) / BANQUETA_MEDIA * vec3(0.78, 0.75, 0.7);
	} else if (es_pared && (blanco || gris)) {
		// Pared de concreto: poros, manchas y alguna grieta de pelo, color de cemento
		vec3 g = triplanar(concreto, local_pos, local_normal, escala * 0.9) / 0.62;
		vec3 manchas = triplanar(concreto, local_pos, local_normal, escala * 0.3) / 0.62;
		col = vec3(l) * vec3(0.8, 0.78, 0.74) * g * mix(vec3(1.0), manchas, 0.6);
	} else if (es_metal && (blanco || gris)) {
		// Lamina galvanizada: gris frio con vetas, juntas y remaches, y algo de brillo
		vec3 m = triplanar(metal, local_pos, local_normal, escala * 1.1) / 0.7;
		col = mix(c, vec3(0.3, 0.34, 0.4), 0.72) * m;
		brillo = 0.35;
	} else if (blanco && !de_clase) {
		// Fierro pintado de blanco (las bombas): grano fino
		col = c * vec3(1.06, 1.05, 1.0) * triplanar(aplanado, local_pos, local_normal, escala * 2.2) / 0.7;
	}
	bool fierro = pintura || es_metal || (blanco && !de_clase);
	if (!vidrio) {
		col = gastado(col, world_pos, n_mundo, clamp(desgaste + zona * 0.4, 0.0, 1.0), fierro);
	}
	ALBEDO = col;
	ROUGHNESS = brillo;
	SPECULAR = brillo < 1.0 ? 0.9 : 0.5;
}
