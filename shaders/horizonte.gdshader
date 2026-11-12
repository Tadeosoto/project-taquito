shader_type spatial;
// Lo que se ve mas alla de la muralla de una colonia del mapa en Blender (scripts/mapa/Horizonte.gd):
// siluetas de casas, torres y cerros en una sola malla, con el color en los vertices. Sin luz
// (no hay normales que valgan a esa distancia): se oscurece con `noche` y la niebla del ambiente
// hace el resto. De noche se prenden algunas ventanas.
render_mode unshaded, cull_disabled;

uniform float noche : hint_range(0.0, 1.0) = 0.0;
uniform float oscuro : hint_range(0.0, 1.0) = 0.045;
uniform vec3 ventana : source_color = vec3(1.0, 0.78, 0.4);

varying vec3 mundo;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = COLOR.rgb * mix(1.0, oscuro, noche);
	// Ventanas prendidas: una rejilla de 2 x 1.5 m sobre las paredes (alfa del vertice = 1 en pared)
	vec2 celda = floor(vec2(mundo.x + mundo.z, mundo.y) / vec2(2.0, 1.5));
	vec2 dentro = fract(vec2(mundo.x + mundo.z, mundo.y) / vec2(2.0, 1.5));
	float prendida = step(0.9, azar(celda)) * step(0.3, dentro.x) * step(dentro.x, 0.7) * step(0.35, dentro.y) * step(dentro.y, 0.75);
	color = mix(color, ventana, prendida * COLOR.a * smoothstep(0.5, 1.0, noche));
	ALBEDO = color;
}
