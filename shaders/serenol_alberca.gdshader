shader_type spatial;
// El Serenol de la alberca del carcamo (CarcamoNivel): lo que esta justo bajo la superficie se ve
// (la Madre dando vueltas, una cria que cae) y conforme se hunde se pierde en negro, asi la
// alberca parece no tener fondo y no se ve donde acaba la Madre cuando sale. Lee la profundidad
// de lo que hay detras: `desvanece` m de Serenol bastan para taparlo.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D profundidad : hint_depth_texture, filter_nearest;
uniform vec3 color_orilla : source_color = vec3(0.09, 0.12, 0.14);
uniform vec3 color_hondo : source_color = vec3(0.0, 0.004, 0.008);
uniform vec3 brillo_serenol : source_color = vec3(0.04, 0.16, 0.2);
uniform float desvanece = 0.8;
uniform float alfa_orilla = 0.3;

void fragment() {
	float d = texture(profundidad, SCREEN_UV).r;
	vec4 atras = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	atras.xyz /= atras.w;
	float grueso = max(VERTEX.z - atras.z, 0.0);
	float t = clamp(grueso / desvanece, 0.0, 1.0);
	t = 1.0 - (1.0 - t) * (1.0 - t);
	ALBEDO = mix(color_orilla, color_hondo, t);
	ALPHA = mix(alfa_orilla, 0.985, t);
	// Ondas lentas en la superficie: solo mueven el reflejo
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(vec3(
		sin(w.x * 2.3 + TIME * 0.9) * 0.05 + sin(w.z * 3.7 - TIME * 0.6) * 0.03,
		1.0,
		cos(w.z * 2.1 + TIME * 0.7) * 0.05 + sin(w.x * 3.1 + TIME * 0.5) * 0.03));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	// Un brillo azul de Serenol apenas, mas en la orilla de lo que se hunde
	EMISSION = brillo_serenol * (1.0 - t) * 0.35;
}
