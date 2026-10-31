class_name RestosZombi
extends Node3D

# Lo que queda de un zombi que revento (Zombie._reventar, docs/especificaciones.md 4.2): su
# pellejo mojado cae al piso, a los pocos segundos se pudre y deja el esqueleto, que dura un
# rato y se hunde. Es aparte del Zombie porque ese vuelve a la reserva a los 5 s. Las mallas
# y los materiales se arman una vez y los comparten todos. Todo va en reloj real, como los
# demas efectos de los golpes. Los pone y los limita Zombis.gd.

const PELLEJO_CAE := 0.1      # s de la caida
const PELLEJO_GRANDE := 1.3
const PUDRE_EN := 6.0         # s en que empieza a pudrirse
const PUDRE_DURA := 3.0
const SE_HUNDE_EN := 57.0     # s
const VIDA := 60.0
const HUNDE := 0.35           # m
const ALTO_PIEZA := 0.13
const COLOR_PELLEJO := Color(0.3, 0.33, 0.2)
const COLOR_PODRIDO := Color(0.1, 0.09, 0.05)
const COLOR_HUESO := Color(0.72, 0.68, 0.52)
const COLOR_OSCURO := Color(0.05, 0.04, 0.03)
const SHADER := preload("res://shaders/ps1_combined.gdshader")
# Del pellejo: [x, z, ancho, largo, giro, cuando empieza a irse (0..1 de lo que dura pudrirse)]
const PIEZAS := [
	[0.0, 0.25, 0.5, 0.75, 0.05, 0.1],     # torso
	[0.03, 0.82, 0.32, 0.34, 0.2, 0.0],    # cabeza
	[-0.42, 0.42, 0.2, 0.72, -0.5, 0.35],  # brazos
	[0.44, 0.38, 0.2, 0.7, 0.55, 0.2],
	[-0.2, -0.5, 0.24, 0.85, -0.14, 0.45], # piernas
	[0.22, -0.48, 0.24, 0.85, 0.2, 0.3],
]

static var _malla_pieza: BoxMesh
static var _malla_esqueleto: ArrayMesh
static var _material_pellejo: ShaderMaterial
static var _material_podrido: ShaderMaterial

var _inicio := 0
var _escala := 1.0
var _pedazos: Array[MeshInstance3D] = []
var _esqueleto: MeshInstance3D
var _podrido := false


static func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


static func _preparar() -> void:
	if _malla_esqueleto:
		return
	_malla_pieza = BoxMesh.new()
	_malla_pieza.size = Vector3.ONE
	_material_pellejo = _material(COLOR_PELLEJO)
	_material_podrido = _material(COLOR_PODRIDO)
	var huesos := SurfaceTool.new()
	huesos.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoyos := SurfaceTool.new()
	hoyos.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Acostado boca arriba, con la cabeza hacia +Z
	var craneo := SphereMesh.new()
	craneo.radius = 0.13
	craneo.height = 0.26
	craneo.radial_segments = 7
	craneo.rings = 3
	huesos.append_from(craneo, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.13, 0.82)))
	_caja(huesos, Vector3(0.14, 0.05, 0.08), Vector3(0.0, 0.05, 0.93), 0.0)      # quijada
	_caja(hoyos, Vector3(0.05, 0.02, 0.06), Vector3(-0.05, 0.25, 0.87), 0.0)     # ojos
	_caja(hoyos, Vector3(0.05, 0.02, 0.06), Vector3(0.05, 0.25, 0.87), 0.0)
	_caja(hoyos, Vector3(0.03, 0.02, 0.03), Vector3(0.0, 0.25, 0.92), 0.0)       # nariz
	_caja(huesos, Vector3(0.06, 0.05, 0.72), Vector3(0.0, 0.05, 0.3), 0.0)       # espinazo
	for i in 5:
		var z := 0.56 - i * 0.09
		var ancho := 0.17 - i * 0.008
		for lado: float in [-1.0, 1.0]:
			_caja(huesos, Vector3(ancho, 0.04, 0.035), Vector3(lado * (ancho / 2.0 + 0.02), 0.08, z), lado * 0.25)
	_caja(huesos, Vector3(0.34, 0.07, 0.15), Vector3(0.0, 0.05, -0.1), 0.0)      # cadera
	_caja(huesos, Vector3(0.36, 0.04, 0.05), Vector3(0.0, 0.06, 0.62), 0.0)      # hombros
	for lado: float in [-1.0, 1.0]:
		# Brazo, abierto, y antebrazo
		_caja(huesos, Vector3(0.05, 0.05, 0.3), Vector3(lado * 0.27, 0.04, 0.48), lado * -0.4)
		_caja(huesos, Vector3(0.04, 0.04, 0.28), Vector3(lado * 0.41, 0.03, 0.22), lado * -0.15)
		_caja(huesos, Vector3(0.09, 0.03, 0.09), Vector3(lado * 0.44, 0.02, 0.04), 0.0)
		# Pierna, espinilla y pie
		_caja(huesos, Vector3(0.06, 0.06, 0.42), Vector3(lado * 0.15, 0.05, -0.36), lado * -0.1)
		_caja(huesos, Vector3(0.05, 0.05, 0.42), Vector3(lado * 0.2, 0.04, -0.78), lado * -0.05)
		_caja(huesos, Vector3(0.09, 0.05, 0.14), Vector3(lado * 0.22, 0.03, -1.02), 0.0)
	_malla_esqueleto = ArrayMesh.new()
	huesos.commit(_malla_esqueleto)
	_malla_esqueleto.surface_set_material(0, _material(COLOR_HUESO))
	hoyos.commit(_malla_esqueleto)
	_malla_esqueleto.surface_set_material(1, _material(COLOR_OSCURO))


static func _caja(st: SurfaceTool, medida: Vector3, donde: Vector3, giro: float) -> void:
	var caja := BoxMesh.new()
	caja.size = medida
	st.append_from(caja, 0, Transform3D(Basis(Vector3.UP, giro), donde))


func _ready() -> void:
	_preparar()
	_inicio = Time.get_ticks_msec()
	rotation.y = randf() * TAU
	_esqueleto = MeshInstance3D.new()
	_esqueleto.mesh = _malla_esqueleto
	_esqueleto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_esqueleto.visible = false
	add_child(_esqueleto)
	for p: Array in PIEZAS:
		var pedazo := MeshInstance3D.new()
		pedazo.mesh = _malla_pieza
		pedazo.material_override = _material_pellejo
		pedazo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pedazo.transform = _lugar_pedazo(p, 1.0)
		add_child(pedazo)
		_pedazos.append(pedazo)
	scale = Vector3(PELLEJO_GRANDE, 1.0, PELLEJO_GRANDE) * _escala


func tamano(cuanto: float) -> void:
	_escala = cuanto


# Se dibuja una vez todo junto para que el primero no trabe (Zombie.calentar)
func calentar() -> void:
	_esqueleto.visible = true
	set_process(false)


func _lugar_pedazo(p: Array, cuanto: float) -> Transform3D:
	var medida := Vector3(p[2] * cuanto, ALTO_PIEZA * maxf(cuanto, 0.05), p[3] * cuanto)
	return Transform3D(Basis(Vector3.UP, p[4]).scaled(medida), Vector3(p[0], medida.y / 2.0, p[1]))


func _process(_delta: float) -> void:
	var t := (Time.get_ticks_msec() - _inicio) / 1000.0
	if t < PELLEJO_CAE:
		var caida := lerpf(PELLEJO_GRANDE, 1.0, t / PELLEJO_CAE)
		scale = Vector3(caida, 1.0, caida) * _escala
		return
	if t < PUDRE_EN:
		scale = Vector3.ONE * _escala
		return
	if not _pedazos.is_empty():
		_pudrir((t - PUDRE_EN) / PUDRE_DURA)
		return
	if t >= VIDA:
		queue_free()
	elif t >= SE_HUNDE_EN:
		position.y = _altura_inicial() - HUNDE * (t - SE_HUNDE_EN) / (VIDA - SE_HUNDE_EN)


var _alto_inicial := INF


func _altura_inicial() -> float:
	if _alto_inicial == INF:
		_alto_inicial = position.y
	return _alto_inicial


# El pellejo se oscurece y se va encogiendo a pedazos, y debajo queda el esqueleto
func _pudrir(avance: float) -> void:
	if not _podrido:
		_podrido = true
		_esqueleto.visible = true
		for pedazo in _pedazos:
			pedazo.material_override = _material_podrido
	if avance >= 1.0:
		for pedazo in _pedazos:
			pedazo.queue_free()
		_pedazos.clear()
		return
	for i in _pedazos.size():
		var p: Array = PIEZAS[i]
		var cuanto := 1.0 - clampf((avance - p[5]) / (1.0 - p[5]), 0.0, 1.0)
		_pedazos[i].transform = _lugar_pedazo(p, cuanto)
