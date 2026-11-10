shader_type spatial;
// El aire que tiembla alrededor de la bocina (scripts/lombrices/Bocina.gd, opcion D de JJ): lee
// la pantalla y la empuja hacia afuera en ONDAS aros que crecen, con un filo blanco tenue. Siempre
// de frente a la camara. Va con los aros del piso (shaders/ondas_bocina.gdshader), al mismo ritmo.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform vec3 color_filo = vec3(1.0, 1.0, 1.0);   // blanco, como los aros (JJ)
uniform float filo = 0.18;
uniform int ondas = 3;
uniform float rapidez = 0.9;
uniform float empuje = 0.012;     // de la pantalla, en cada aro
uniform float pulso = 2.0;
instance uniform float desfase = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float t = TIME + desfase;
	float golpe = pow(1.0 - fract(t * pulso), 3.0);
	float suma = 0.0;
	float borde = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= ondas) break;
		float f = fract(t * rapidez + float(i) / float(ondas));
		float onda = exp(-pow((d - mix(0.08, 1.0, f)) / 0.05, 2.0)) * (1.0 - f);
		suma += onda;
		borde = max(borde, onda);
	}
	vec2 hacia = d > 0.001 ? p / d : vec2(0.0);
	vec2 uv = SCREEN_UV - hacia * suma * (empuje + golpe * empuje * 0.8) * vec2(1.0, -1.0);
	ALBEDO = texture(pantalla, uv).rgb + color_filo * borde * filo;
	ALPHA = step(d, 1.0);
}
