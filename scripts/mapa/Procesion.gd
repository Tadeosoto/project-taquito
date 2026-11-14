class_name Procesion
extends Node3D

# La procesion del atardecer de Santa Mugre (marca "procesion" de Colonia.gd): cuando Ciclo avisa
# que va a oscurecer (aviso_atardecer, las campanas de la parroquia) los fieles salen del atrio con
# la Virgen del Tinaco en andas, le dan la vuelta al tinaco de la plaza y ahi se quedan: es la
# senal de que ya viene la noche, y de ahi sigue la vela del tinaco (los "vecino" de noche).
# Los que caminan se arman al empezar y se quitan al terminar: el resto del dia no cuesta nada.

const VELOCIDAD := 1.12            # m/s: el paso del clip Walk (Gente.PASO)
const SEPARA := 1.3                # m entre uno y otro
const FILA := [                    # corrido a los lados (m) y que lleva cada quien, de adelante hacia atras
	[-0.5, "vela"], [0.5, "vela"], [-0.45, "andas"], [0.45, "andas"], [-0.5, "vela"], [0.5, ""], [0.0, "vela"],
]
const LUZ_COLOR := Color(1.0, 0.78, 0.45)

## El camino, en metros del mundo: [[x, z], ...]
var puntos: Array = []

var _camino: PackedVector3Array
var _largos: PackedFloat32Array
var _total := 0.0
var _avance := -1.0                # m que lleva el primero (< 0: no hay procesion)
var _gente: Array[Node3D] = []
var _andas: Node3D


func _ready() -> void:
	for p: Array in puntos:
		_camino.append(Vector3(float(p[0]), 0.0, float(p[1])))
	_largos.append(0.0)
	for i in range(1, _camino.size()):
		_total += _camino[i - 1].distance_to(_camino[i])
		_largos.append(_total)
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo and _camino.size() >= 2:
		ciclo.aviso_atardecer.connect(empezar)
	set_process(false)


func en_marcha() -> bool:
	return _avance >= 0.0


func empezar() -> void:
	if en_marcha() or _camino.size() < 2:
		return
	for i in FILA.size():
		var nodo := Node3D.new()
		nodo.name = "Fiel_%d" % i
		add_child(nodo)
		var lleva: String = FILA[i][1]
		Civiles.poner(nodo, Civiles.elegir("procesion_%d" % i), "Walk_Carry" if lleva == "andas" else "Walk")
		if lleva == "vela":
			var veladora := Colonia._veladora()
			# En la mano, enfrente del pecho (el civil ve a -Z de su nodo)
			veladora.position = Vector3(0.18, 1.1, -0.3)
			nodo.add_child(veladora)
		_gente.append(nodo)
	_andas = _armar_andas()
	add_child(_andas)
	_avance = 0.0
	set_process(true)
	_poner()


func _process(delta: float) -> void:
	_avance += VELOCIDAD * delta
	# Termina cuando el ultimo llega al final del camino
	if _avance - (FILA.size() / 2) * SEPARA >= _total:
		_terminar()
		return
	_poner()


func _terminar() -> void:
	for nodo in _gente:
		nodo.queue_free()
	_gente.clear()
	if _andas:
		_andas.queue_free()
		_andas = null
	_avance = -1.0
	set_process(false)


func _poner() -> void:
	var cargan: Array[Vector3] = []
	var rumbo := 0.0
	for i in _gente.size():
		# De dos en dos: la pareja i/2 va SEPARA m detras de la anterior
		var s := clampf(_avance - (i / 2) * SEPARA, 0.0, _total)
		var lugar := _en_camino(s)
		var donde: Vector3 = lugar[0]
		var hacia: Vector3 = lugar[1]
		var lado := Vector3(-hacia.z, 0.0, hacia.x)
		_gente[i].global_position = global_position + donde + lado * float(FILA[i][0])
		# El civil ve hacia el -Z de su nodo
		_gente[i].rotation.y = atan2(-hacia.x, -hacia.z)
		if FILA[i][1] == "andas":
			cargan.append(_gente[i].global_position)
			rumbo = _gente[i].rotation.y
	if _andas and cargan.size() == 2:
		_andas.global_position = (cargan[0] + cargan[1]) / 2.0
		_andas.rotation.y = rumbo


# El punto a `s` m del principio del camino y hacia donde va ahi
func _en_camino(s: float) -> Array:
	for i in range(1, _camino.size()):
		if s <= _largos[i] or i == _camino.size() - 1:
			var tramo := _largos[i] - _largos[i - 1]
			var t := 0.0 if tramo <= 0.0 else clampf((s - _largos[i - 1]) / tramo, 0.0, 1.0)
			var hacia := (_camino[i] - _camino[i - 1]).normalized()
			return [_camino[i - 1].lerp(_camino[i], t), hacia]
	return [_camino[0], Vector3.FORWARD]


# Las andas: una tabla a la altura de los hombros con la Virgen (un tinaquito negro con su
# resplandor), flores, veladoras y una luz calida
func _armar_andas() -> Node3D:
	var andas := Node3D.new()
	andas.name = "Andas"
	_pieza(andas, BoxMesh.new(), Vector3(1.5, 0.06, 0.7), Vector3(0, 1.32, 0), Color(0.36, 0.26, 0.17))
	var tinaco := CylinderMesh.new()
	tinaco.radial_segments = 8
	tinaco.rings = 1
	_pieza(andas, tinaco, Vector3(0.5, 0.62, 0.5), Vector3(0, 1.66, 0), Color(0.07, 0.07, 0.08))
	_pieza(andas, BoxMesh.new(), Vector3(0.9, 0.9, 0.03), Vector3(0, 1.72, 0.27), Color(0.9, 0.72, 0.25), true)
	for x: float in [-0.6, 0.6]:
		_pieza(andas, BoxMesh.new(), Vector3(0.22, 0.2, 0.5), Vector3(x, 1.45, 0), Color(0.95, 0.5, 0.08))
		_pieza(andas, BoxMesh.new(), Vector3(0.04, 0.08, 0.04), Vector3(x * 0.6, 1.42, -0.28), Color(1.0, 0.82, 0.4), true)
	var luz := OmniLight3D.new()
	luz.light_color = LUZ_COLOR
	luz.light_energy = 1.2
	luz.omni_range = 5.0
	luz.shadow_enabled = false
	luz.position = Vector3(0, 2.2, 0)
	andas.add_child(luz)
	return andas


func _pieza(padre: Node3D, malla: PrimitiveMesh, tam: Vector3, donde: Vector3, color: Color, brilla := false) -> void:
	if malla is BoxMesh:
		(malla as BoxMesh).size = tam
	elif malla is CylinderMesh:
		(malla as CylinderMesh).top_radius = tam.x / 2.0
		(malla as CylinderMesh).bottom_radius = tam.x / 2.0
		(malla as CylinderMesh).height = tam.y
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if brilla:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = material
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.position = donde
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(nodo)
