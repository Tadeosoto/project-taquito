// Una gota de Liquido.gd en pixel art (AG): un cuadro que se estira a lo largo de hacia donde
// vuela y por lo ancho ve a la camara (como sprite_eje.gdshader), con una textura chiquita de
// pixeles duros: cabeza al frente, cola atras. De un MultiMesh: la escala de la instancia es lo
// grueso, INSTANCE_CUSTOM.rgb la direccion (de 0..1 a -1..1) y .a lo largo en m; COLOR, el color.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D gota : source_color, filter_nearest;

void vertex() {
	vec3 centro = MODEL_MATRIX[3].xyz;
	float grueso = length(MODEL_MATRIX[0].xyz);
	vec3 eje = INSTANCE_CUSTOM.rgb * 2.0 - 1.0;
	eje = length(eje) > 0.0001 ? normalize(eje) : vec3(0.0, 1.0, 0.0);
	float largo = max(INSTANCE_CUSTOM.a, grueso);
	vec3 a_camara = normalize(INV_VIEW_MATRIX[3].xyz - centro);
	vec3 y = cross(eje, a_camara);
	y = length(y) > 0.0001 ? normalize(y) : vec3(0.0, 1.0, 0.0);
	vec3 mundo = centro + eje * VERTEX.x * largo + y * VERTEX.y * grueso;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = mundo;
}

void fragment() {
	vec4 c = texture(gota, UV);
	if (c.a < 0.5) {
		discard;
	}
	// Los colores de Liquido vienen en sRGB
	vec3 color = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c.rgb * color;
}
