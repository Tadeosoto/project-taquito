shader_type spatial;
// Muros pintados de blanco del carcamo (CarcamoNivel), descuidados: moho y humedad que suben del
// piso, bajan del techo y se juntan bajo el mezzanine, con escurridos. Todo sale de ruido en
// coordenadas del mundo, asi no hay dos manchas iguales ni se repite el dibujo.
render_mode specular_schlick_ggx;

uniform sampler2D pintura : source_color, filter_nearest, repeat_enable;
uniform sampler2D ruido : filter_nearest, repeat_enable;      // manchas grandes
uniform sampler2D detalle : filter_nearest, repeat_enable;    // borde comido del moho
uniform vec3 color_moho : source_color = vec3(0.1, 0.12, 0.08);
uniform vec3 color_humedad : source_color = vec3(0.58, 0.53, 0.4);
uniform float muro_alto = 7.0;
uniform float mezz_alto = 3.5;

varying vec3 mundo;
varying vec3 normal_mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Coordenada a lo largo del muro y altura
	float u = normal_mundo.x > normal_mundo.z ? mundo.z : mundo.x;
	float y = mundo.y;
	vec2 p = vec2(u, y);
	vec3 base = texture(pintura, p / 3.0).rgb;
	float grande = texture(ruido, p * 0.04).r;
	float fino = texture(detalle, p * 0.18).r;
	// Donde le gusta crecer: abajo (humedad que sube), arriba en el techo y justo bajo el mezzanine
	float abajo = 1.0 - smoothstep(0.0, 2.6, y);
	float techo = smoothstep(muro_alto - 2.0, muro_alto, y);
	float losa = 1.0 - smoothstep(0.0, 0.9, abs(y - (mezz_alto - 0.35)));
	float lugar = abajo * 0.35 + techo * 0.3 + losa * 0.2;
	// Escurridos: ruido estirado a lo alto, mas largos bajo el mezzanine y el techo
	float escurre = texture(detalle, vec2(u * 0.9, y * 0.04)).r;
	float chorro = smoothstep(0.72, 0.82, escurre) * (techo * 0.8 + losa * 0.9 + 0.25) * smoothstep(0.0, 1.2, y);
	float m = grande * 0.9 + fino * 0.25 + lugar - 0.82;
	float moho = smoothstep(0.1, 0.16, m);
	float halo = smoothstep(-0.06, 0.1, m) * (1.0 - moho);
	vec3 c = mix(base, base * color_humedad * 1.6, clamp(halo * 0.55 + chorro * 0.45, 0.0, 1.0));
	c = mix(c, color_moho, moho * (0.75 + fino * 0.25));
	ALBEDO = c;
	ROUGHNESS = mix(0.7, 0.95, moho);
}
