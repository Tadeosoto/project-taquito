// Un efecto de pixelfx que se repite (como sprite_pixel.gdshader) pero estirado a lo largo de una
// linea del mundo: el cuadro solo gira alrededor de su eje para verse de frente. Para el trazo de
// la bala (Pistola.gd): una hoja que ve a la derecha, con la punta en el pivote, se pone con la
// punta en el origen del MeshInstance3D y la cola hacia atras de `eje`, estirada a `largo` m.
// La malla es un QuadMesh de 1 x 1 compartido; necesita custom_aabb porque el shader la estira.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform sampler2D hoja : source_color, filter_nearest;
uniform int columnas = 1;
uniform int filas = 1;
uniform int cuadros = 1;
uniform float fps = 30.0;
uniform float periodo = 1.0;
uniform vec2 tamano = vec2(64.0);   // px de un cuadro
uniform vec2 pivote = vec2(32.0);   // px desde la esquina de arriba a la izquierda
uniform float pixel = 0.047;        // m por pixel de alto
uniform float largo_px = 120.0;     // px del trazo en la hoja: esos se estiran a `largo` m
uniform float alfa : hint_range(0.0, 1.0) = 1.0;

instance uniform float fase = 0.0;
instance uniform vec3 eje = vec3(1.0, 0.0, 0.0);   // hacia donde va la punta, en el mundo
instance uniform float largo = 1.0;                // m

varying flat float v_oculto;

void vertex() {
	float t = mod(TIME + fase, periodo);
	float cuadro = floor(t * fps);
	v_oculto = cuadro >= float(cuadros) ? 1.0 : 0.0;
	cuadro = min(cuadro, float(cuadros - 1));
	vec2 esquina = VERTEX.xy + 0.5;   // 0..1, y hacia arriba
	vec2 px = vec2(esquina.x * tamano.x - pivote.x, (1.0 - esquina.y) * tamano.y - pivote.y);
	// En el mundo: x a lo largo de `eje`, y de lado, viendo a la camara
	vec3 punta = MODEL_MATRIX[3].xyz;
	vec3 x = normalize(eje);
	vec3 a_camara = normalize(INV_VIEW_MATRIX[3].xyz - punta);
	vec3 y = cross(x, a_camara);
	y = length(y) > 0.0001 ? normalize(y) : vec3(0.0, 1.0, 0.0);
	vec3 mundo = punta + x * px.x * (largo / largo_px) - y * px.y * pixel;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = mundo;
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
