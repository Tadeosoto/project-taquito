// Un efecto de pixelfx que se repite solo (EfectosPixel.material_bucle): un cuadro que siempre
// ve a la camara y escoge su cuadro de la hoja con TIME, sin script por cuadro. Sirve en un
// MeshInstance3D (fase y direccion como instance uniforms) y en un MultiMesh (fase en
// INSTANCE_CUSTOM.r, con use_custom_data). La malla es un QuadMesh de 1 x 1 compartido.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D hoja : source_color, filter_nearest;
uniform int columnas = 1;
uniform int filas = 1;
uniform int cuadros = 1;
uniform float fps = 30.0;
// Cuanto dura una vuelta. Si es mas que la hoja, entre vuelta y vuelta no se ve nada (chispas
// de vez en cuando)
uniform float periodo = 1.0;
uniform vec2 tamano = vec2(64.0);   // px de un cuadro
uniform vec2 pivote = vec2(32.0);   // px desde la esquina de arriba a la izquierda
uniform float pixel = 0.047;        // m por pixel
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
// Las hojas de efectos con direccion ven a la derecha: se voltean si `hacia` va a la izquierda en pantalla
uniform bool con_direccion = false;
// De pie en el piso: gira solo alrededor de la vertical (no se inclina al ver desde arriba), para
// que la base de un charco o de algo que sale del suelo no flote
uniform bool de_pie = false;

// Sobre un eje del mundo: el eje X del cuadro va por `hacia` (horizontal, ya no se voltea) y solo
// gira sobre ese eje para ver a la camara. Asi un chorro sale siempre perpendicular a su pared
uniform bool eje_mundo = false;

instance uniform float fase = 0.0;
instance uniform vec3 hacia = vec3(1.0, 0.0, 0.0);

varying flat float v_oculto;

void vertex() {
	float t = mod(TIME + fase + INSTANCE_CUSTOM.r * periodo, periodo);
	float cuadro = floor(t * fps);
	v_oculto = cuadro >= float(cuadros) ? 1.0 : 0.0;
	cuadro = min(cuadro, float(cuadros - 1));
	float voltea = 1.0;
	if (con_direccion && (VIEW_MATRIX * vec4(hacia, 0.0)).x < 0.0) {
		voltea = -1.0;
	}
	// La escala de la instancia (un tambo mas grande, el jefe) sin girar el cuadro
	float escala = length(MODEL_MATRIX[0].xyz);
	vec2 esquina = VERTEX.xy + 0.5;   // 0..1, y hacia arriba
	vec2 px = vec2(esquina.x * tamano.x - pivote.x, (1.0 - esquina.y) * tamano.y - pivote.y);
	if (eje_mundo) {
		vec3 derecha = normalize(hacia + vec3(0.0001, 0.0, 0.0));
		vec3 a_camara = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
		vec3 n = a_camara - derecha * dot(a_camara, derecha);
		n = length(n) < 0.001 ? vec3(0.0, 1.0, 0.0) : normalize(n);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(derecha, 0.0), vec4(cross(n, derecha), 0.0), vec4(n, 0.0), MODEL_MATRIX[3]);
		voltea = 1.0;
	} else if (de_pie) {
		vec3 derecha = INV_VIEW_MATRIX[0].xyz;
		derecha = normalize(vec3(derecha.x, 0.0, derecha.z) + vec3(0.0001, 0.0, 0.0));
		vec3 frente = cross(derecha, vec3(0.0, 1.0, 0.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(derecha, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(-frente, 0.0), MODEL_MATRIX[3]);
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
	VERTEX = vec3(px.x * voltea, -px.y, 0.0) * pixel * escala;
	float col = mod(cuadro, float(columnas));
	float fila = floor(cuadro / float(columnas));
	UV = (vec2(col, fila) + vec2(esquina.x, 1.0 - esquina.y)) / vec2(float(columnas), float(filas));
}

void fragment() {
	if (v_oculto > 0.5) {
		discard;
	}
	vec4 c = texture(hoja, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * alfa;
}
