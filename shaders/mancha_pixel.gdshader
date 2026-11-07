// Una mancha de Liquido.gd en el piso, en pixel art (AG): un atlas de formas blancas de 16x16
// (Liquido._atlas_manchas) pintado con el color de la instancia. La forma sale de
// INSTANCE_CUSTOM.r y el desvanecido de COLOR.a, con tramado de Bayer (como restos_pixel) en
// vez de transparencia: los pixeles se quedan duros.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform int formas = 4;

varying flat float v_cual;

void vertex() {
	v_cual = INSTANCE_CUSTOM.r;
	UV = vec2((UV.x + v_cual) / float(formas), UV.y);
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(atlas, UV);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float umbral = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (c.a < 0.5 || COLOR.a < umbral) {
		discard;
	}
	ALBEDO = c.rgb * pow(COLOR.rgb, vec3(2.2));
}
