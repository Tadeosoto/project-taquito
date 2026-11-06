shader_type spatial;
// La barra de vida sobre cada zombi (Zombie.gd): un cuadro que siempre ve a la camara, con
// su orilla negra, lo lleno en rojo y lo que falta oscuro. Un solo material para todos; la
// vida va por instancia.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;

instance uniform float vida : hint_range(0.0, 1.0) = 1.0;
uniform vec4 lleno : source_color = vec4(0.85, 0.12, 0.08, 1.0);
uniform vec4 vacio : source_color = vec4(0.12, 0.03, 0.03, 1.0);
uniform vec4 orilla : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 grueso = vec2(0.02, 0.2);   // de la orilla, en UV (x, y)

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	bool en_orilla = UV.x < grueso.x || UV.x > 1.0 - grueso.x || UV.y < grueso.y || UV.y > 1.0 - grueso.y;
	float x = (UV.x - grueso.x) / (1.0 - 2.0 * grueso.x);
	ALBEDO = en_orilla ? orilla.rgb : (x <= vida ? lleno.rgb : vacio.rgb);
}
