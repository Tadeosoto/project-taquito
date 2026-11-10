shader_type spatial;
// El escupitajo de la Madre (Arrojadizo tipo 3): Serenol como agua radioactiva, parecido a su piel.
// Casi negro azulado, cruzado por grietas delgadas del azul de sus venas que corren por dentro,
// burbujas negras que prenden y apagan, apenas la orilla encendida (fresnel) y un pulso. El ruido va en la direccion de cada punto de la esfera,
// cuantizada en pixeles grandes, asi se mueve con la gota aunque se estire.
render_mode specular_schlick_ggx;

uniform vec3 color_hondo : source_color = vec3(0.012, 0.025, 0.05);
uniform vec3 color_brillo : source_color = vec3(0.18, 0.77, 1.0);   // #2EC4FF, el de las espinas
uniform vec3 color_nucleo : source_color = vec3(0.0, 0.0, 0.0);   // centro de las venas y burbujas
uniform float energia = 2.2;
uniform float pixeles = 9.0;      // cuantos "pixeles" por radio

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 d = floor(normalize(local) * pixeles) / pixeles;
	vec3 corre = vec3(0.0, TIME * 1.7, TIME * 0.9);
	float n = ruido(d * 1.6 + corre) * 0.7 + ruido(d * 3.2 - corre * 1.3) * 0.3;
	// Venas: donde el ruido cruza la mitad, delgadas y de borde duro como las grietas de la Madre
	float vena = step(0.9, 1.0 - abs(n * 2.0 - 1.0));
	// Burbujas que prenden y apagan
	float burbuja = step(0.86, ruido(d * 7.0 + vec3(TIME * 2.3, 0.0, -TIME * 1.1)));
	float orilla = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulso = 0.85 + 0.15 * sin(TIME * 7.0);
	vec3 luz = color_brillo * (vena * 1.5 + orilla * 0.08) * energia * pulso;
	float nucleo = burbuja * (1.0 - vena);
	ALBEDO = mix(color_hondo, color_nucleo, nucleo);
	EMISSION = mix(luz, color_nucleo, nucleo);
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
