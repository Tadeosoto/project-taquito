// La mancha de gasolina ardiendo en el piso (ZonaLombrices._mancha): un poligono irregular cuyo
// COLOR.r es la distancia al centro (0) y a la orilla (1). La orilla se deshilacha con ruido, el
// centro queda chamuscado y por la orilla corre brasa que titila.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float semilla = 0.0;

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
		p = p * 2.07 + 11.0;
		a *= 0.5;
	}
	return v;
}

varying vec2 v_mundo;

void vertex() {
	v_mundo = VERTEX.xz;
}

void fragment() {
	float f = COLOR.r;
	float n = fbm(v_mundo * 2.2 + semilla);
	float orilla = f + (n - 0.5) * 0.45;
	float alfa = smoothstep(1.0, 0.78, orilla);
	if (alfa < 0.03) {
		discard;
	}
	float brasa_n = fbm(v_mundo * 4.0 + vec2(TIME * 0.6, -TIME * 0.4) + semilla);
	float brasa = smoothstep(0.55, 0.85, brasa_n) * smoothstep(0.3, 0.85, orilla) * 0.8;
	vec3 carbon = vec3(0.05, 0.03, 0.02);
	vec3 gasolina = vec3(0.2, 0.07, 0.02);
	vec3 fuego = vec3(1.0, 0.45, 0.08);
	vec3 c = mix(carbon, gasolina, smoothstep(0.0, 0.9, orilla));
	c = mix(c, fuego, brasa);
	ALBEDO = c;
	ALPHA = alfa * 0.9;
}
