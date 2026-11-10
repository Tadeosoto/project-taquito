shader_type spatial;
// Las ondas de la bocina en el piso (scripts/lombrices/Bocina.gd, opcion B de JJ): ONDAS aros que
// salen de la bocina acostados en el suelo, crecen y se desvanecen con tramado Bayer, en una reja
// de PIXELES como los efectos de pixelfx. Al ritmo (pulso por segundo) los aros engordan. Va sobre
// un PlaneMesh; el aire que tiembla encima es shaders/aire_bocina.gdshader. Escribe profundidad
// (es opaco con discard): con depth_draw_never no salia en la copia de pantalla que lee el aire
// y se borraban los aros detras de la bocina.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // blancas (JJ)
uniform float pixeles = 96.0;
uniform int ondas = 4;
uniform float rapidez = 0.8;      // vueltas por segundo de cada aro
uniform float desde = 0.06;       // radio donde nace (la bocina), de 0 a 1
uniform float ancho = 0.018;
uniform float pulso = 2.0;        // golpes por segundo (120 bpm)
instance uniform float desfase = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 celda = floor(UV * pixeles);
	vec2 p = (celda + 0.5) / pixeles * 2.0 - 1.0;
	float d = length(p);
	float t = TIME + desfase;
	float golpe = pow(1.0 - fract(t * pulso), 3.0);
	float alfa = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= ondas) break;
		float f = fract(t * rapidez + float(i) / float(ondas));
		float r = mix(desde, 1.0, f);
		if (abs(d - r) < ancho * (1.0 + golpe * 1.5)) {
			alfa = max(alfa, 1.0 - f);
		}
	}
	int bx = int(mod(celda.x, 4.0));
	int by = int(mod(celda.y, 4.0));
	if (alfa * 1.1 <= (BAYER[by * 4 + bx] + 0.5) / 16.0) {
		discard;
	}
	ALBEDO = color.rgb;
}
