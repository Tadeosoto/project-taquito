// Los pedazos de pixel art que deja un zombi al reventar (RestosZombi.gd): cuadros planos en el
// piso, de un MultiMesh, cada uno con su dibujo del atlas y su desvanecido en INSTANCE_CUSTOM
// (r = cual dibujo, g = cuanto se oscurece y enrojece, a = cuanto se ve). Sin luz, pixeles duros (filter_nearest) y el
// desvanecido con tramado de Bayer, como PS1, en vez de transparencia.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform int dibujos = 8;

varying flat float v_cual;
varying flat float v_alfa;
varying flat float v_tinte;

void vertex() {
	v_cual = INSTANCE_CUSTOM.r;
	v_alfa = INSTANCE_CUSTOM.a;
	v_tinte = INSTANCE_CUSTOM.g;
	UV = vec2((UV.x + v_cual) / float(dibujos), UV.y);
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(atlas, UV);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float umbral = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (c.a < 0.5 || v_alfa < umbral) {
		discard;
	}
	// Cada pedazo un poco distinto: mas oscuro y mas rojo con el tinte
	ALBEDO = c.rgb * mix(vec3(1.0), vec3(0.8, 0.55, 0.5), v_tinte);
}
