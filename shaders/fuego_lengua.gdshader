// Una lengua de fuego de la molotov (ZonaLombrices._llamas): un quad vertical que gira solo
// sobre Y hacia la camara. La forma sale de ruido fbm que sube, se angosta hacia la punta y se
// mece mas arriba; el color va de blanco amarillento en la base a naranja y rojo oscuro en la
// orilla. Instancia: `semilla` (fase del ruido) y `altura` (alto en m, para estirar el ruido).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float semilla = 0.0;
instance uniform float opacidad = 1.0;
uniform float velocidad = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruido(p);
		p = p * 2.03 + 17.0;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Billboard solo en Y (como BILLBOARD_FIXED_Y), respetando la escala del nodo
	vec3 arriba = vec3(0.0, 1.0, 0.0);
	vec3 derecha = normalize(cross(arriba, INV_VIEW_MATRIX[2].xyz));
	vec3 atras = normalize(cross(derecha, arriba));
	float ex = length(MODEL_MATRIX[0].xyz);
	float ey = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(derecha * ex, 0.0), vec4(arriba * ey, 0.0),
		vec4(atras * ex, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float h = 1.0 - UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float t = TIME * velocidad;
	vec2 p = vec2(UV.x * 2.2 + semilla * 13.0, h * 2.6 - t * 1.7);
	float n = fbm(p);
	float n2 = fbm(p * 2.1 + vec2(7.0 - semilla * 5.0, -t * 2.6));

	// Se mece mas hacia la punta
	x += (n - 0.5) * 1.5 * h * h + (n2 - 0.5) * 0.35 * h;
	float ancho = 1.0 - pow(h, 1.5);
	float cuerpo = 1.0 - abs(x) / max(ancho, 0.001);
	// Las puntas se rompen en lenguas sueltas
	float dens = cuerpo - h * 0.18 + (n2 - 0.5) * (0.5 + h * 0.9);
	dens += (1.0 - h) * 0.25;

	float alfa = smoothstep(0.0, 0.3, dens);
	alfa *= smoothstep(0.0, 0.05, h);
	if (alfa < 0.02) {
		discard;
	}

	// Rampa de color: rojo oscuro (orilla) -> naranja -> amarillo -> casi blanco (nucleo, abajo)
	float calor = clamp(dens * 1.0 + (1.0 - h) * 0.2 - h * 0.1, 0.0, 1.2);
	vec3 rojo = vec3(0.45, 0.06, 0.02);
	vec3 naranja = vec3(1.0, 0.38, 0.05);
	vec3 amarillo = vec3(1.0, 0.82, 0.25);
	vec3 blanco = vec3(1.0, 0.96, 0.75);
	vec3 c = mix(rojo, naranja, smoothstep(0.0, 0.4, calor));
	c = mix(c, amarillo, smoothstep(0.45, 0.85, calor));
	c = mix(c, blanco, smoothstep(0.95, 1.2, calor));

	ALBEDO = c;
	ALPHA = alfa * (0.95 - h * 0.25) * opacidad;
}
