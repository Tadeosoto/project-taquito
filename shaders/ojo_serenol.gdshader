shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Un ojo de los de en medio de las cañerías (Transicion.poner_ojos, JJ 2026-11-21): todo brilla, el
// azul de la Madre por fuera y blanco en medio, y respira con ella (0.25 Hz). En pixeles duros, en un
// cuadrito frente a la cara.

uniform vec3 color_grieta : source_color = vec3(0.18, 0.77, 1.0);   // #2EC4FF
uniform vec3 color_nucleo : source_color = vec3(0.92, 0.99, 1.0);
uniform float pixeles = 9.0;
uniform float blanco = 0.45;     // radio de lo blanco (1 = la orilla del ojo)
uniform float respiracion = 0.25;

void fragment() {
	vec2 p = (floor(UV * pixeles) + 0.5) / pixeles * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}
	float aliento = 0.5 - 0.5 * cos(TIME * TAU * respiracion);
	vec3 c = mix(color_grieta, color_nucleo, 1.0 - smoothstep(blanco * 0.6, blanco * 1.15, d));
	ALBEDO = c * mix(1.0, 1.35, aliento);
}
