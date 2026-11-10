extends Node3D
# El cuerpo provisional de La Mojiganga (Catrina.gd) mientras no exista el modelo de Blender
# (docs/prompts/blender_catrina.md): una catrina de desfile de ~6 m hecha de puras figuras
# (falda de cono, blusa de capsula, craneo de esfera, brazos de hueso, chongo, flores y aretes).
# No hay clips: Catrina le pasa una pose (`pose`) y aqui se suaviza hacia ella cada cuadro, asi
# los avisos de cada ataque se leen (alza el pie, se agacha, estira la trenza).
# Da las mismas marcas que dara el modelo: Mano_R, Mano_L, Pie_R, Cabeza, Trenza_Punta,
# Arete_L/R, Flor_0..3 y Pecho_Nudo. Mira hacia -Z; su derecha es +X.

const ALTO_FALDA := 2.6
const CINTURA := 2.6
const LARGO_BRAZO := 2.2
const SUAVE := 7.0             # que tan rapido llega a la pose (1/s)
const MORADO := Color(0.42, 0.12, 0.55)
const MORADO_ROTO := Color(0.25, 0.08, 0.3)
const BLANCO := Color(0.93, 0.9, 0.84)
const HUESO := Color(0.88, 0.84, 0.74)
const CABELLO := Color(0.3, 0.18, 0.12)
const CARRIZO := Color(0.62, 0.52, 0.3)
const NUDO := Color(0.22, 0.3, 0.12)
const FLORES := [Color(0.95, 0.2, 0.5), Color(1.0, 0.45, 0.1), Color(0.5, 0.2, 0.75), Color(0.95, 0.35, 0.45)]

static var _materiales := {}

var _cintura: Node3D
var _falda: MeshInstance3D
var _blusa: MeshInstance3D
var _hombro_r: Node3D
var _hombro_l: Node3D
var _pie_r: Node3D
var _cabeza: Node3D
var _cuello: Node3D
var _trenza: MeshInstance3D
var _carrizo: Node3D
var _nudo: MeshInstance3D
var _meta := {"inclinar": 0.0, "brazo_r": 0.0, "brazo_l": 0.0, "pie_r": 0.0, "arrodillada": 0.0, "gatea": 0.0, "trenza": 0.0}
var _ahora := _meta.duplicate()
var _trenza_meta := Vector3.ZERO
var giro := 0.0


static func _mat(color: Color) -> StandardMaterial3D:
	if not _materiales.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materiales[color] = m
	return _materiales[color]


func _ready() -> void:
	var raiz := self
	# Pies bajo la falda: el derecho se ve al alzarla para el pisoton
	_pie_r = _marca("Pie_R", raiz, Vector3(0.45, 0.15, -0.35))
	_caja(Vector3(0.45, 0.3, 0.9), Vector3.ZERO, HUESO, _pie_r)
	_falda = _cono(1.6, 0.78, ALTO_FALDA, Vector3(0, ALTO_FALDA / 2.0, 0), MORADO, raiz)
	# Bastilla blanca y una franja de flores
	_cono(1.62, 1.55, 0.25, Vector3(0, -ALTO_FALDA / 2.0 + 0.12, 0), BLANCO, _falda)
	_cintura = Node3D.new()
	_cintura.name = "Cintura"
	_cintura.position.y = CINTURA
	add_child(_cintura)
	_cono(0.86, 0.86, 0.32, Vector3(0, 0.05, 0), BLANCO, _cintura)
	for i in 8:
		var a := TAU * i / 8.0
		_bola(0.11, Vector3(sin(a) * 0.87, 0.05, cos(a) * 0.87), FLORES[i % FLORES.size()], _cintura)
	_blusa = _capsula(0.78, 2.0, Vector3(0, 1.05, 0), MORADO, _cintura)
	_caja(Vector3(0.5, 0.6, 0.05), Vector3(0, 1.75, -0.74), BLANCO, _cintura)   # escote bordado
	# El armazon de carrizo: se ve cuando se rompe el vestido (fase 2)
	_carrizo = Node3D.new()
	_carrizo.visible = false
	_cintura.add_child(_carrizo)
	for i in 6:
		var a := TAU * i / 6.0
		var vara := _cono(0.04, 0.04, 2.2, Vector3(sin(a) * 0.82, 1.05, cos(a) * 0.82), CARRIZO, _carrizo)
		vara.rotation.z = 0.05 * sin(a * 3.0)
	_nudo = _bola(0.5, Vector3(0, 1.1, -0.3), NUDO, _cintura)
	_nudo.visible = false
	_marca("Pecho_Nudo", _cintura, Vector3(0, 1.1, -0.55))
	_cuello = Node3D.new()
	_cuello.position.y = 2.05
	_cintura.add_child(_cuello)
	_cono(0.13, 0.13, 0.6, Vector3(0, 0.3, 0), HUESO, _cuello)
	_cabeza = _marca("Cabeza", _cuello, Vector3(0, 0.85, 0))
	_bola(0.62, Vector3.ZERO, HUESO, _cabeza)
	for x in [-0.22, 0.22]:
		_bola(0.16, Vector3(x, 0.08, -0.5), Color(0.05, 0.04, 0.05), _cabeza)
	_caja(Vector3(0.6, 0.22, 0.4), Vector3(0, -0.42, -0.32), HUESO, _cabeza)  # quijada con dientes
	_bola(0.5, Vector3(0, 0.2, 0.45), CABELLO, _cabeza)                       # chongo trenzado
	_marca("Trenza_Punta", _cabeza, Vector3(0, 0.1, 0.75))
	var flores := [Vector3(-0.45, 0.45, -0.2), Vector3(-0.15, 0.62, -0.2), Vector3(0.18, 0.62, -0.18), Vector3(0.45, 0.45, -0.2)]
	for i in flores.size():
		_marca("Flor_%d" % i, _cabeza, flores[i])
	for lado in [-1.0, 1.0]:
		var arete := _marca("Arete_L" if lado < 0.0 else "Arete_R", _cabeza, Vector3(0.62 * lado, -0.3, 0))
		for k in 3:
			_bola(0.07, Vector3(0, -0.15 * k, 0), FLORES[(k + 1) % FLORES.size()], arete)
	_hombro_r = _brazo("Mano_R", 0.95)
	_hombro_l = _brazo("Mano_L", -0.95)
	_trenza = MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.09
	cil.bottom_radius = 0.16
	cil.height = 1.0
	cil.radial_segments = 6
	cil.material = _mat(CABELLO)
	_trenza.mesh = cil
	_trenza.visible = false
	add_child(_trenza)


func _brazo(mano: String, x: float) -> Node3D:
	var hombro := Node3D.new()
	hombro.position = Vector3(x, 1.85, 0)
	_cintura.add_child(hombro)
	_cono(0.11, 0.08, LARGO_BRAZO, Vector3(0, -LARGO_BRAZO / 2.0, 0), HUESO, hombro)
	_capsula(0.25, 0.7, Vector3(0, -0.25, 0), MORADO, hombro)   # manga
	var m := _marca(mano, hombro, Vector3(0, -LARGO_BRAZO, 0))
	_caja(Vector3(0.22, 0.4, 0.12), Vector3(0, -0.15, 0), HUESO, m)
	return hombro


func _marca(nombre: String, padre: Node3D, donde: Vector3) -> Node3D:
	var m := Marker3D.new()
	m.name = nombre
	m.position = donde
	padre.add_child(m)
	return m


func _cono(abajo: float, arriba: float, alto: float, donde: Vector3, color: Color, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = abajo
	cm.top_radius = arriba
	cm.height = alto
	cm.radial_segments = 10
	cm.material = _mat(color)
	mi.mesh = cm
	mi.position = donde
	padre.add_child(mi)
	return mi


func _capsula(radio: float, alto: float, donde: Vector3, color: Color, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radio
	cm.height = alto
	cm.radial_segments = 10
	cm.material = _mat(color)
	mi.mesh = cm
	mi.position = donde
	padre.add_child(mi)
	return mi


func _bola(radio: float, donde: Vector3, color: Color, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radio
	sm.height = radio * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	sm.material = _mat(color)
	mi.mesh = sm
	mi.position = donde
	padre.add_child(mi)
	return mi


func _caja(medida: Vector3, donde: Vector3, color: Color, padre: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medida
	bm.material = _mat(color)
	mi.mesh = bm
	mi.position = donde
	padre.add_child(mi)
	return mi


# --- Lo que pide Catrina ---

# Llaves: inclinar (rad, hacia el frente), brazo_r/brazo_l (rad, alzar al frente), pie_r (0-1),
# arrodillada (0-1), gatea (0-1), trenza (0-1, hacia trenza_hacia). Las que no vienen vuelven a 0
func pose(valores: Dictionary) -> void:
	for k: String in _meta:
		_meta[k] = float(valores.get(k, 0.0))
	if valores.has("trenza_hacia"):
		_trenza_meta = valores["trenza_hacia"]


func roto(si: bool) -> void:
	_blusa.material_override = _mat(MORADO_ROTO) if si else null
	_falda.material_override = _mat(MORADO_ROTO) if si else null
	_carrizo.visible = si


func sin_cabeza(si: bool) -> void:
	_cuello.visible = not si


func mostrar_nudo(si: bool) -> void:
	_nudo.visible = si


func caida(t: float) -> void:
	# Muerta: el armazon se dobla y se hunde
	_cintura.rotation.x = -lerpf(0.0, 1.5, t)
	position.y = -lerpf(0.0, 1.2, t)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-SUAVE * delta)
	for llave: String in _meta:
		_ahora[llave] = lerpf(_ahora[llave], _meta[llave], k)
	var arr: float = _ahora["arrodillada"]
	var gat: float = _ahora["gatea"]
	var hundir := maxf(arr * 1.5, gat * 1.35)
	_cintura.position.y = CINTURA - hundir
	_cintura.rotation.x = -(_ahora["inclinar"] + arr * 0.45 + gat * 1.2)
	_cintura.rotation.y = giro
	_falda.scale = Vector3(1.0 + arr * 0.25 + gat * 0.2, 1.0 - arr * 0.55 - gat * 0.6, 1.0 + arr * 0.25 + gat * 0.2)
	_falda.position = Vector3(0, ALTO_FALDA / 2.0 * _falda.scale.y, gat * 1.0)
	_falda.rotation.y = giro
	# El pisoton: la falda se levanta de enfrente y se ve el pie de hueso
	var pie: float = _ahora["pie_r"]
	_falda.rotation.x = pie * 0.35
	_pie_r.position = Vector3(0.45, 0.15 + pie * 1.4, -0.35 - pie * 0.8)
	_hombro_r.rotation.x = _ahora["brazo_r"]
	# La izquierda en la cadera, como la de la foto, salvo que la ocupe
	_hombro_l.rotation.x = _ahora["brazo_l"]
	_hombro_l.rotation.z = -0.55 * (1.0 - minf(absf(_ahora["brazo_l"]), 1.0))
	var ext: float = _ahora["trenza"]
	_trenza.visible = ext > 0.03
	if _trenza.visible:
		var a := (find_child("Trenza_Punta", true, false) as Node3D).global_position
		var b := a.lerp(_trenza_meta, ext)
		var largo := a.distance_to(b)
		if largo > 0.05:
			_trenza.global_position = (a + b) / 2.0
			var y := (b - a) / largo
			var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
			_trenza.global_basis = Basis(x, y * largo, x.cross(y))
