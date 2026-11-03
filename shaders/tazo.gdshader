// Una cara de tazo (TazoRevelacion.gd): la textura de pixel y, en los holograficos, el brillo
// de arcoiris. El arcoiris cambia con el angulo con que lo ves (al ladearlo corre) y una franja
// mas fuerte cruza de lado a lado con `barrido`. Sin vertex snapping: es de menu, de cerca.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D cara : source_color, filter_nearest;
uniform vec4 color_orilla : source_color = vec4(1.0);
uniform bool es_orilla = false;
uniform float foil : hint_range(0.0, 1.0) = 0.0;     // que tanto brilla (0 = comun)
uniform float barrido : hint_range(-0.5, 1.5) = -0.5; // donde va la franja fuerte, de izquierda a derecha
uniform float luz : hint_range(0.0, 2.0) = 0.0;      // un destello blanco encima de todo

vec3 arcoiris(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec4 c = es_orilla ? color_orilla : texture(cara, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
	if (foil > 0.0) {
		float angulo = dot(NORMAL, VIEW);
		float t = angulo * 2.5 + (UV.x + UV.y) * 1.2 + TIME * 0.15;
		// Cuantizado en pasos para que se vea de pixel y no de degradado liso
		vec3 iris = arcoiris(floor(t * 8.0) / 8.0);
		float franja = 1.0 - smoothstep(0.0, 0.12, abs(UV.x + UV.y * 0.4 - barrido * 1.4));
		// Un brillo leve en todo el tazo para que se lea el dibujo; fuerte solo en la franja
		float fuerza = foil * (0.12 + 0.88 * franja);
		ALBEDO = mix(ALBEDO, ALBEDO * 0.5 + iris * 0.7, fuerza * 0.55);
		EMISSION = iris * fuerza * 0.35;
		METALLIC = 0.5 * foil;
		ROUGHNESS = mix(0.6, 0.25, foil);
	}
	EMISSION += vec3(luz);
}
