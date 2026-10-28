shader_type canvas_item;
// Radar redondo estilo GTA (scripts/map/MapMinimapa.gd): muestra el pedazo de
// textures/map/minimapa.png alrededor del jugador, girado para que lo que ve la
// camara quede hacia arriba.

uniform sampler2D mapa : source_color, filter_nearest;
// Posicion del jugador en el PNG (0..1)
uniform vec2 centro = vec2(0.5);
// Adelante y derecha de la camara en el plano XZ (unitarios)
uniform vec2 adelante = vec2(0.0, -1.0);
uniform vec2 derecha = vec2(1.0, 0.0);
// Radio del radar en metros / tamano del PNG en metros
uniform vec2 radio_uv = vec2(0.05);
uniform vec4 fondo : source_color = vec4(0.16, 0.18, 0.15, 1.0);
uniform vec4 borde : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform float grosor_borde = 0.07;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	// p.y crece hacia abajo en pantalla: arriba = adelante
	vec2 uv = centro + (p.x * derecha - p.y * adelante) * radio_uv;
	vec4 color = texture(mapa, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		color = fondo;
	}
	COLOR = r > 1.0 - grosor_borde ? borde : color;
}
