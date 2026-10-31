shader_type canvas_item;
// El cuadro de impacto al recibir un golpe (Supervivencia.gd): lo que se ve en la pantalla
// pasado a puro blanco y negro, como en el anime. `invertido` en el segundo cuadro.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
uniform bool invertido = false;
// Lo pone Supervivencia.gd segun la hora: de dia casi todo es claro y de noche casi todo oscuro
uniform float umbral = 0.4;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float blanco = step(umbral, dot(c, vec3(0.299, 0.587, 0.114)));
	COLOR = vec4(vec3(invertido ? 1.0 - blanco : blanco), 1.0);
}
