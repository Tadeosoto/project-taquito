// La ola sonica del Simi jefe (JefeSimi): un anillo azul que crece por el piso. Un plano grande por ola;
// el anillo se dibuja en `radio` con su `ancho`, en pixeles duros, con rayitas de ecualizador.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.18, 0.77, 1.0);   // #2EC4FF, el Serenol
uniform float tam = 70.0;                // lado del plano en metros (PlaneMesh.size)
instance uniform float radio = 0.0;      // metros
instance uniform float ancho = 1.3;
instance uniform float fuerza = 1.0;     // se apaga al llegar lejos
const float PIXEL = 0.25;

void fragment() {
	vec2 p = (UV - 0.5) * tam;
	p = (floor(p / PIXEL) + 0.5) * PIXEL;
	float d = length(p);
	float a = atan(p.y, p.x);
	float dentro = abs(d - radio);
	float anillo = 1.0 - step(ancho * 0.5, dentro);
	float orilla = 1.0 - step(ancho * 0.5 + PIXEL * 2.0, dentro);
	// Rayitas de ecualizador por dentro del anillo: unas mas largas que otras
	float barra = step(0.5, fract(a * 24.0 / 6.2832));
	float largo = 0.6 + 1.4 * fract(sin(floor(a * 24.0 / 6.2832) * 12.9898) * 43758.5453);
	float eco = barra * step(radio - ancho * 0.5 - largo, d) * step(d, radio - ancho * 0.5) * step(0.5, radio);
	float luz = anillo + orilla * 0.35 + eco * 0.5;
	ALBEDO = color * luz * fuerza * 2.0;
	ALPHA = clamp(luz, 0.0, 1.0);
}
