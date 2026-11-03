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

# Nubes de polvo: una bola pixeleada de cara a la camara, con la paleta de polvo de la hoja
# (`sparks` de golpe_barrida), mas clara arriba a la izquierda, que crece, sube y se deshace.
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
	vec3(0.863, 0.784, 0.635), vec3(0.722, 0.624, 0.471), vec3(0.573, 0.478, 0.345),
	vec3(0.431, 0.353, 0.251));

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
	set_process(false)


func agregar(mano: Vector3, punta: Vector3) -> void:
	_pedazos.append([mano.lerp(punta, DESDE) + Vector3.DOWN * ADENTRO_BAJA, punta, 0.0])
	_cuenta += 1
	if _cuenta % NUBE_CADA == 0:
		_soltar_nube(punta.lerp(mano, 0.15) + Vector3.DOWN * NUBE_ABAJO)
	set_process(true)


func _soltar_nube(donde: Vector3) -> void:
	var i := _siguiente
	_siguiente = (_siguiente + 1) % NUBES
	var nube := _nubes[i]
	nube.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * NUBE_TAMANO.x), donde)
	nube.set_instance_shader_parameter("semilla", randf())
	nube.set_instance_shader_parameter("edad", 0.0)
	nube.visible = true
	_nube_edad[i] = 0.0


func _process(delta: float) -> void:
	for pedazo: Array in _pedazos:
		pedazo[2] += delta
	while not _pedazos.is_empty() and _pedazos[0][2] >= VIDA:
		_pedazos.pop_front()
	var hay_nubes := _mover_nubes(delta)
	_malla.clear_surfaces()
	if _pedazos.size() < 2:
		if _pedazos.is_empty() and not hay_nubes:
			set_process(false)
		return
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for pedazo: Array in _pedazos:
		var edad: float = pedazo[2] / VIDA
		_malla.surface_set_uv(Vector2(0.0, edad))
		_malla.surface_add_vertex(pedazo[0])
		_malla.surface_set_uv(Vector2(1.0, edad))
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
