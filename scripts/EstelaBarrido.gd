extends MeshInstance3D

# La estela del barrido: una cinta en el mundo entre la mano y la punta del arma, que Barrido.gd
# va dejando mientras el brazo pasa. Asi siempre sigue al brazo y a donde mira el personaje, desde
# cualquier angulo (un dibujo plano de cara a la camara se veia siempre de lado). Corre con el
# tiempo del juego: se queda en la congelada del golpe como todo lo demas.
# Cada tantos pedazos suelta una nube de polvo cerca de la punta, como las de la hoja 2D.

const VIDA := 0.18             # s que dura cada pedazo
const DESDE := 0.45            # la orilla de adentro, en fraccion del largo desde la mano
# m que baja la orilla de adentro: acostada (el brazo va casi parejo) desde atras se veia de canto
const ADENTRO_BAJA := 0.3
# Una media luna solida como la hoja de la barrida (golpe_barrida en tools/pixelfx/efectos.json):
# franjas de su paleta, de la orilla clara de la punta hacia adentro mas oscuro, sin mezclar. UV.x va
# de adentro (0) a la punta (1) y UV.y es la edad: lo viejo se adelgaza hasta quedar en la orilla
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 PALETA[6] = vec3[](
	vec3(0.110, 0.133, 0.188), vec3(0.180, 0.212, 0.282), vec3(0.290, 0.329, 0.408),
	vec3(0.431, 0.478, 0.565), vec3(0.604, 0.651, 0.729), vec3(0.816, 0.847, 0.902));

void fragment() {
	float borde = UV.y * 0.9;
	if (UV.x < borde) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	int paso = clamp(int(k * 6.0), 0, 5);
	ALBEDO = pow(PALETA[paso], vec3(2.2));
}
"""

# PRUEBA (JJ): estela de agua azul con blanco, al estilo de la respiracion del agua de Tanjiro.
# Solo la prende el safehouse (tecla 8); false = la estela de siempre. Mas ancha y dura mas, con
# franjas que ondulan a lo largo de la estela, crestas blancas que corren y la orilla de adentro
# rota en gotas. UV2.x cuenta los pedazos, para saber donde va cada uno a lo largo
static var agua := false
var forzar_agua := false      # el giro del ataque cargado siempre sale de agua (Player._girar)
const AGUA_VIDA := 0.32
const AGUA_DESDE := 0.15
const AGUA_BAJA := 0.15
const SHADER_AGUA := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

const vec3 AGUA[6] = vec3[](
	vec3(0.035, 0.090, 0.280), vec3(0.055, 0.200, 0.520), vec3(0.110, 0.380, 0.780),
	vec3(0.330, 0.620, 0.940), vec3(0.680, 0.860, 1.000), vec3(0.970, 0.990, 1.000));

void fragment() {
	float edad = UV.y;
	float u = UV2.x * 0.18;
	float borde = edad * 0.85;
	// La orilla de adentro se rompe en gotas conforme envejece
	float ruido = fract(sin(floor(UV2.x) * 12.9898 + floor(UV.x * 10.0) * 78.233) * 43758.5453);
	if (UV.x < borde + ruido * 0.12 * edad) {
		discard;
	}
	float k = (UV.x - borde) / (1.0 - borde);
	// Las franjas ondulan como agua que corre
	float onda = sin(u * 6.2832 - TIME * 10.0) * 0.08 + sin(u * 13.0 + TIME * 6.0) * 0.04;
	float kk = clamp(k + onda, 0.0, 0.999);
	int paso = int(kk * 6.0);
	vec3 c = AGUA[paso];
	// Rayitas blancas entre franja y franja, como el agua dibujada
	if (paso >= 2 && fract(kk * 6.0) < 0.12) {
		c = AGUA[5];
	}
	// Crestas que se enroscan hacia la punta y corren por la estela
	float s = fract(u - TIME * 1.5);
	float cresta = 0.8 - 0.25 * s * s;
	if (k > cresta && k < cresta + 0.07) {
		c = AGUA[5];
	}
	ALBEDO = pow(c, vec3(2.2));
}
"""

# Nubes de polvo: una bola pixeleada de cara a la camara, blanca (JJ no la quiso cafe como la de
# la hoja), mas clara arriba a la izquierda, que crece, sube y se deshace.
# `edad` va de 0 a 1 y `semilla` cambia la forma de cada una
const NUBES := 12              # en la reserva; se reusa la mas vieja
const NUBE_CADA := 5           # pedazos de estela entre nube y nube
const NUBE_VIDA := 0.45
const NUBE_TAMANO := Vector2(0.2, 0.5)  # m, al salir y al final
const NUBE_SUBE := 0.35        # m/s
const NUBE_ABAJO := 0.12       # m por debajo de la punta
const SHADER_NUBE := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

instance uniform float edad = 0.0;
instance uniform float semilla = 0.0;

const vec3 POLVO[4] = vec3[](
	vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549));

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// 12 x 12 pixeles por nube, como pixel art
	vec2 p = (floor(UV * 12.0) + 0.5) / 12.0 - 0.5;
	float angulo = atan(p.y, p.x);
	float d = length(p) + 0.06 * sin(angulo * 3.0 + semilla * 6.283) + 0.04 * sin(angulo * 5.0 - semilla * 3.1);
	// Se deshace al final: se encoge y se le hacen hoyos
	float radio = 0.42 * (1.0 - edad * edad * 0.6);
	float hoyo = fract(sin(dot(floor(UV * 12.0), vec2(12.9898, 78.233)) + semilla) * 43758.5453);
	if (d > radio || hoyo < (edad - 0.5) * 1.6) {
		discard;
	}
	float luz = clamp(0.55 - (p.x - p.y) * 1.1 - d * 0.6 - edad * 0.5, 0.0, 0.999);
	ALBEDO = pow(POLVO[3 - int(luz * 4.0)], vec3(2.2));
}
"""

static var _material: ShaderMaterial
static var _material_nube: ShaderMaterial
static var _quad: QuadMesh
static var _material_agua: ShaderMaterial
static var _material_espuma: ShaderMaterial

var _pedazos: Array = []       # [mano, punta, edad]
var _malla := ImmediateMesh.new()
var _nubes: Array[MeshInstance3D] = []
var _nube_edad: Array[float] = []
var _siguiente := 0
var _cuenta := 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _malla
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	material_override = _material
	if _material_nube == null:
		var shader := Shader.new()
		shader.code = SHADER_NUBE
		_material_nube = ShaderMaterial.new()
		_material_nube.shader = shader
		_quad = QuadMesh.new()
		# El shader voltea el cuadro hacia la camara: sin esto se recortaba al verlo de lado
		_quad.custom_aabb = AABB(Vector3.ONE * -0.5, Vector3.ONE)
	for i in NUBES:
		var nube := MeshInstance3D.new()
		nube.mesh = _quad
		nube.material_override = _material_nube
		nube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nube.top_level = true
		nube.visible = false
		add_child(nube)
		_nubes.append(nube)
		_nube_edad.append(-1.0)
	if _material_agua == null:
		var shader := Shader.new()
		shader.code = SHADER_AGUA
		_material_agua = ShaderMaterial.new()
		_material_agua.shader = shader
		# La espuma: las mismas nubes en azul clarito y blanco
		var espuma := Shader.new()
		espuma.code = SHADER_NUBE.replace("""vec3(0.961, 0.957, 0.937), vec3(0.851, 0.847, 0.827), vec3(0.698, 0.698, 0.686),
	vec3(0.549, 0.553, 0.549)""", """vec3(0.970, 0.990, 1.000), vec3(0.760, 0.900, 1.000), vec3(0.450, 0.720, 0.980),
	vec3(0.200, 0.470, 0.850)""")
		_material_espuma = ShaderMaterial.new()
		_material_espuma.shader = espuma
	set_process(false)


func agregar(mano: Vector3, punta: Vector3) -> void:
	var de_agua := agua or forzar_agua
	if _pedazos.is_empty():
		material_override = _material_agua if de_agua else _material
	var desde := AGUA_DESDE if de_agua else DESDE
	var baja := AGUA_BAJA if de_agua else ADENTRO_BAJA
	_pedazos.append([mano.lerp(punta, desde) + Vector3.DOWN * baja, punta, 0.0, float(_cuenta)])
	_cuenta += 1
	if _cuenta % NUBE_CADA == 0:
		_soltar_nube(punta.lerp(mano, 0.15) + Vector3.DOWN * NUBE_ABAJO)
	set_process(true)


func _soltar_nube(donde: Vector3) -> void:
	var i := _siguiente
	_siguiente = (_siguiente + 1) % NUBES
	var nube := _nubes[i]
	nube.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * NUBE_TAMANO.x), donde)
	nube.material_override = _material_espuma if agua or forzar_agua else _material_nube
	nube.set_instance_shader_parameter("semilla", randf())
	nube.set_instance_shader_parameter("edad", 0.0)
	nube.visible = true
	_nube_edad[i] = 0.0


func _process(delta: float) -> void:
	for pedazo: Array in _pedazos:
		pedazo[2] += delta
	var vida := AGUA_VIDA if agua or forzar_agua else VIDA
	while not _pedazos.is_empty() and _pedazos[0][2] >= vida:
		_pedazos.pop_front()
	var hay_nubes := _mover_nubes(delta)
	_malla.clear_surfaces()
	if _pedazos.size() < 2:
		if _pedazos.is_empty() and not hay_nubes:
			set_process(false)
		return
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for pedazo: Array in _pedazos:
		var edad: float = pedazo[2] / vida
		_malla.surface_set_uv(Vector2(0.0, edad))
		_malla.surface_set_uv2(Vector2(pedazo[3], 0.0))
		_malla.surface_add_vertex(pedazo[0])
		_malla.surface_set_uv(Vector2(1.0, edad))
		_malla.surface_set_uv2(Vector2(pedazo[3], 0.0))
		_malla.surface_add_vertex(pedazo[1])
	_malla.surface_end()


func _mover_nubes(delta: float) -> bool:
	var hay := false
	for i in NUBES:
		if _nube_edad[i] < 0.0:
			continue
		_nube_edad[i] += delta
		var nube := _nubes[i]
		var edad := _nube_edad[i] / NUBE_VIDA
		if edad >= 1.0:
			_nube_edad[i] = -1.0
			nube.visible = false
			continue
		hay = true
		var tamano := lerpf(NUBE_TAMANO.x, NUBE_TAMANO.y, ease(edad, 0.4))
		nube.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * tamano),
			nube.global_position + Vector3.UP * NUBE_SUBE * delta)
		nube.set_instance_shader_parameter("edad", edad)
	return hay
