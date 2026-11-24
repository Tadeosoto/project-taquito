class_name SimiPlanicie
extends Node3D
# El Simi bailador en la planicie de pasto del sureste de map_test (JJ, 2026-11-22): el pasto grande
# entre x 642 y 898, z 469 y 787 (el punto mas abierto, 110 m libres a la redonda, es CENTRO). Solo
# de noche (`Misiones.es_noche`): al anochecer aparece bailando en medio mientras andes a menos de
# APARECE; a menos de PELEA empieza la pelea (JefeSimi.empezar: los zombis van a bailar con el, la
# ola, el aura). Al amanecer se va. Si te vas a mas de OLVIDA peleando, se va y la proxima vez esta
# con toda la vida. Muerto, `Misiones.matar_jefe("simi")` y no vuelve.

const CENTRO := Vector3(821.0, 0.0, 650.0)
const RADIO := 60.0
const APARECE := 250.0
const PELEA := 70.0
const OLVIDA := 160.0
const ID := "simi"

var jefe: JefeSimi
var _barra: BarraSimi
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
	var noche: bool = misiones.es_noche if misiones else true
	var d := Vector2(_jugador.global_position.x - CENTRO.x, _jugador.global_position.z - CENTRO.z).length()
	if jefe == null or not is_instance_valid(jefe):
		if noche and d < APARECE:
			_poner()
		return
	if jefe.estado == JefeSimi.Estado.MUERTA:
		if d > APARECE + 30.0:
			_quitar()
		return
	if not noche or d > APARECE + 30.0:
		_quitar()
	elif jefe.activa and d > OLVIDA:
		_quitar()
	elif not jefe.activa and d < PELEA:
		jefe.empezar()


func _poner() -> void:
	jefe = JefeSimi.new()
	jefe.centro = Vector3(CENTRO.x, _piso(), CENTRO.z)
	jefe.radio = RADIO
	jefe.piso = jefe.centro.y
	add_child(jefe)
	jefe.global_position = jefe.centro
	jefe.murio.connect(_murio)
	if _barra == null:
		_barra = BarraSimi.new()
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


# La altura del piso en el centro (el suelo del mapa), 0 si todavia no hay nada
func _piso() -> float:
	var consulta := PhysicsRayQueryParameters3D.create(CENTRO + Vector3.UP * 60.0, CENTRO + Vector3.DOWN * 60.0)
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.position.y if golpe else 0.0
