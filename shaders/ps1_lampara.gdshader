shader_type spatial;
render_mode cull_disabled;

// Postes de luz (scripts/map/MapAlumbrado.gd), todo con MultiMesh:
// modo 0 = poste y brazo (color de vertice, mugre segun el deterioro);
// modo 1 = mica de la lampara: emite de noche con el color de la instancia;
// modo 2 = halo (billboard aditivo, ver ps1_lampara_halo.gdshader).
// INSTANCE_CUSTOM de las lamparas: (prendida 0/1, parpadea 0/1, semilla, umbral).
// El parpadeo es el mismo que Alumbrado.parpadeo() (hash entero y alumbrado_tiempo).

#include "res://shaders/ps1_vertex.gdshaderinc"
#include "res://shaders/ps1_deterioro.gdshaderinc"
#include "res://shaders/ps1_lampara.gdshaderinc"

uniform int modo = 0;
uniform float energia = 6.0;

varying vec3 world_pos;
varying float brillo;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	brillo = modo == 1 ? lampara_brillo(INSTANCE_CUSTOM) : 0.0;
	vec3 vertex = VERTEX;
	vec2 uv_out;
	POSITION = ps1_vertex(vertex, UV, MODELVIEW_MATRIX, PROJECTION_MATRIX, uv_out);
	VERTEX = vertex;
}

void fragment() {
	if (modo == 0) {
		ALBEDO = mugre(COLOR.rgb, world_pos, zona_deterioro(world_pos.xz));
	} else {
		// La mica: gris de dia, del color de la lampara de noche
		ALBEDO = mix(vec3(0.55), COLOR.rgb, 0.3);
		EMISSION = COLOR.rgb * brillo * energia;
	}
	ROUGHNESS = 1.0;
}
