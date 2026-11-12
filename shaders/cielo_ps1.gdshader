shader_type sky;
// Cielo del mapa de Blender (scenes/mapa.tscn): degradado en bandas con tramado, el sol entre el
// esmog, nubes de pixeles, atardecer naranja, y de noche estrellas y luna. Ciclo.gd le pasa
// `noche` (Ciclo.valor(): 0 de dia, 1 de noche) y `niebla` (el color de la niebla, que es el del
// horizonte: asi la orilla del mundo se pierde en el cielo sin costura).
// La niebla del ambiente no debe taparlo: Environment.fog_sky_affect = 0.

uniform float noche : hint_range(0.0, 1.0) = 0.0;
uniform vec3 niebla : source_color = vec3(0.545, 0.554, 0.535);
uniform vec3 cenit_dia : source_color = vec3(0.34, 0.42, 0.52);
uniform vec3 cenit_noche : source_color = vec3(0.012, 0.014, 0.035);
uniform vec3 atardecer : source_color = vec3(0.95, 0.46, 0.16);
uniform vec3 sol_color : source_color = vec3(1.0, 0.9, 0.66);
uniform vec3 luna_color : source_color = vec3(0.82, 0.85, 0.92);
// Hasta que altura (seno del angulo) llega la capa de esmog del horizonte
uniform float esmog_alto : hint_range(0.02, 1.0) = 0.42;
uniform float nubes : hint_range(0.0, 1.0) = 0.45;
uniform float bandas : hint_range(4.0, 64.0) = 20.0;
uniform float tramado : hint_range(0.0, 1.0) = 0.6;
// Tamano del pixel del cielo en radianes (lo que lo hace verse de baja resolucion)
uniform float pixel : hint_range(0.002, 0.05) = 0.008;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x), mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	const float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[y * 4 + x] / 16.0 - 0.5;
}

void sky() {
	// La direccion, cuantizada: bloques parejos en el cielo
	vec3 dir = normalize(EYEDIR);
	float altura = max(dir.y, 0.0);
	float giro = atan(dir.x, dir.z);
	vec2 celda = floor(vec2(giro, asin(clamp(dir.y, -1.0, 1.0))) / pixel);

	// Degradado: del color de la niebla en el horizonte al cenit
	float sube = smoothstep(0.0, esmog_alto, altura);
	vec3 cenit = mix(cenit_dia, cenit_noche, noche);
	vec3 color = mix(niebla, cenit, sube);

	// Atardecer y amanecer: naranja bajo, del lado del sol, solo a media transicion
	float medio = 4.0 * noche * (1.0 - noche);
	vec3 al_sol = normalize(vec3(LIGHT0_DIRECTION.x, 0.0, LIGHT0_DIRECTION.z) + vec3(0.0001));
	float lado = max(dot(normalize(vec3(dir.x, 0.0, dir.z) + vec3(0.0001)), al_sol), 0.0);
	color = mix(color, atardecer, medio * (1.0 - sube) * (0.35 + 0.65 * lado));

	// El sol de dia y la luna de noche (la misma luz direccional), apagados por el esmog
	float disco = dot(dir, LIGHT0_DIRECTION);
	float calima = smoothstep(0.985, 0.9995, disco);
	color += sol_color * calima * 0.5 * (1.0 - noche);
	color = mix(color, mix(sol_color, luna_color, noche), step(0.9992, disco) * (0.9 - 0.25 * noche));

	// Nubes de pixeles que se arrastran despacio, mas ralas hacia el horizonte
	if (dir.y > 0.02) {
		vec2 plano = dir.xz / (dir.y + 0.12);
		vec2 bloque = floor(plano * 9.0 + vec2(TIME * 0.02, 0.0));
		float masa = ruido(bloque * 0.22) * 0.7 + ruido(bloque * 0.6) * 0.3;
		float nube = step(1.0 - nubes * 0.55, masa) * smoothstep(0.02, 0.25, dir.y);
		vec3 tono = mix(vec3(0.78, 0.77, 0.72), vec3(0.025, 0.027, 0.04), noche);
		tono = mix(tono, atardecer * 1.05, medio * 0.6);
		color = mix(color, tono, nube * 0.55);
	}

	// Estrellas: pocas, de un pixel, solo arriba del esmog
	float estrella = step(0.9965, azar(celda)) * smoothstep(0.5, 1.0, noche) * sube;
	color += vec3(0.8, 0.82, 0.9) * estrella * (0.5 + 0.5 * azar(celda + 7.0));

	// Bandas con tramado ordenado (el cielo de PS1 no era liso)
	color += bayer4(FRAGCOORD.xy) * tramado / bandas;
	COLOR = floor(color * bandas + 0.5) / bandas;
}
