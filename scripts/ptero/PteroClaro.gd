class_name PteroClaro
extends Node3D
# El pterodactilo en el claro del centro-oeste de map_test (JJ, 2026-11-22): el baldio grande al
# poniente de la avenida, entre x -910 y -560, z -195 y 0. Esta ahi de dia y de noche, echado en
# medio (JefePtero en DUERME) mientras andes a menos de APARECE; si te acercas a DESPIERTA (o le
# pegas) empieza la pelea. Si te vas a mas de OLVIDA del claro peleando, se va y la proxima vez esta
# con toda la vida. Muerto, `Misiones.matar_jefe("ptero")` y no vuelve.

const CENTRO := Vector3(-736.0, 0.0, -95.0)
const RADIO := 85.0          # m que se aleja del centro (el claro mide ~350 x 195 m)
const APARECE := 220.0
const DESPIERTA := 40.0
const OLVIDA := 170.0
const ID := "ptero"

var jefe: JefePtero
var _barra: BarraPtero
var _jugador: Node3D


func _ready() -> void:
	global_position = CENTRO


func _process(_delta: float) -> void:
	var misiones := get_node_or_null("/root/Misiones")
	if misiones and misiones.jefe_muerto(ID) and (jefe == null or not is_instance_valid(jefe)):
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return
	var d := Vector2(_jugador.global_position.x - CENTRO.x, _jugador.global_position.z - CENTRO.z).length()
	if jefe == null or not is_instance_valid(jefe):
		if d < APARECE:
			_poner()
		return
	if jefe.estado == JefePtero.Estado.MUERTA:
		if d > APARECE + 30.0:
			_quitar()
		return
	if not jefe.despierto():
		if d > APARECE + 30.0:
			_quitar()
		elif _jugador.global_position.distance_to(jefe.global_position) < DESPIERTA:
			jefe.despertar()
	elif d > OLVIDA:
		_quitar()


func _poner() -> void:
	jefe = JefePtero.new()
	jefe.centro = CENTRO
	jefe.radio = RADIO
	jefe.piso = _piso()
	add_child(jefe)
	jefe.global_position = Vector3(CENTRO.x, jefe.piso, CENTRO.z)
	jefe.rotation.y = randf() * TAU
	jefe.murio.connect(_murio)
	if _barra == null:
		_barra = BarraPtero.new()
		add_child(_barra)
	_barra.jefe = jefe


func _quitar() -> void:
	if is_instance_valid(jefe):
		jefe.queue_free()
	jefe = null


func _murio() -> void:
	var misiones := get_node_or_null("/root/Misiones")
	if misiones:
		misiones.matar_jefe(ID)


# La altura del piso en el centro del claro (el suelo del mapa), 0 si todavia no hay nada
func _piso() -> float:
	var consulta := PhysicsRayQueryParameters3D.create(CENTRO + Vector3.UP * 60.0, CENTRO + Vector3.DOWN * 60.0)
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.position.y if golpe else 0.0
