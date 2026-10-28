shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Halo de cada lampara prendida (scripts/map/MapAlumbrado.gd): un cuadro de frente a
// la camara con un degradado redondo, sumado. Con poca resolucion se ve de lejos
// como en los juegos de PS1. Mismo INSTANCE_CUSTOM que ps1_lampara.

#include "res://shaders/ps1_deterioro.gdshaderinc"
#include "res://shaders/ps1_lampara.gdshaderinc"

uniform float tamano = 5.0;
uniform float intensidad = 0.9;

varying float brillo;

void vertex() {
	brillo = lampara_brillo(INSTANCE_CUSTOM);
	// Billboard: el centro de la instancia y el cuadro de frente a la camara
	vec4 centro = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	// De cerca estorba (tapa media pantalla): se desvanece
	brillo *= smoothstep(6.0, 15.0, length(centro.xyz));
	centro.xy += VERTEX.xy * tamano;
	POSITION = PROJECTION_MATRIX * centro;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = dot(p, p);
	if (brillo <= 0.0 || d >= 1.0) {
		discard;
	}
	// Escalones en lugar de degradado suave (paleta corta de PS1)
	float a = floor((1.0 - d) * 4.0) / 4.0;
	ALBEDO = COLOR.rgb * a * a * brillo * intensidad;
}
