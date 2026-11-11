shader_type spatial;
// Paredes y fondo de la alberca del carcamo (CarcamoNivel): concreto arriba que se va a negro
// conforme baja, para que la alberca parezca no tener fondo.
render_mode specular_schlick_ggx;

uniform sampler2D concreto : source_color, filter_nearest, repeat_enable;
uniform float escala = 0.42;      // 1 / m de la textura
uniform float arriba = -0.05;     // altura donde empieza a oscurecerse
uniform float negro = -0.6;       // altura donde ya es negro

varying vec3 mundo;
varying vec3 normal_mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = normal_mundo.y > 0.5 ? mundo.xz : (normal_mundo.x > normal_mundo.z ? mundo.zy : mundo.xy);
	vec3 c = texture(concreto, uv * escala).rgb;
	float t = smoothstep(arriba, negro, mundo.y);
	ALBEDO = mix(c, vec3(0.0), t);
	ROUGHNESS = 0.9;
	SPECULAR = mix(0.4, 0.0, t);
}
