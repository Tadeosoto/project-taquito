class_name DropsRaros
extends Node3D

# Los drops raros escondidos (S5 de docs/plan-noche.md). Los escondites son fijos
# (resources/map/escondites.json, de tools/map_import/escondites.py: atras de bodegas y en
# callejones, casi todos en las orillas del mapa), pero no hay drop en todos: cada dia, al amanecer,
# se sortean `por_dia` y solo esos tienen algo. Lo recogido ya no sale hasta el siguiente sorteo.
# El sorteo es static, asi que cambiar de escena (PasoColonia, PasoJefe) no vuelve a sortear.
# Que sale: uno al azar de LISTA. La lista esta pendiente de llenar (docs/items.md, "Drops
# raros"); mientras este vacia sale PENDIENTE, un paquete morado "Algo raro". No salen en los mapas.
# Como todo lo del mapa, solo se pone cerca del jugador (los cuadros cargan su piso al acercarte).

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const WORLD_ITEM := preload("res://scripts/WorldItem.gd")
const PENDIENTE := preload("res://resources/drops_raros/pendiente.tres")
# Rutas de los .tres que pueden salir (InventoryItemData). Pendiente de llenar con JJ
const LISTA: Array[String] = []
const PONER_A := 70.0          # m: mas cerca se pone el drop
const QUITAR_A := 100.0
const CADA := 1.0
const ALTO_LIBRE := 0.6        # arriba de esto es una azotea, una barda o una caja
const BUSCAR := [0.0, 1.5, 3.0, 4.5, 6.0]   # m alrededor del escondite donde se busca piso libre
const ALTO_OBJETO := 0.5       # como los WorldItem tirados del mapa

@export_file("*.json") var escondites_path := "res://resources/map/escondites.json"
# Cuantos escondites tienen algo cada dia
@export var por_dia := 6
# Escondites a mano (x, z) en vez del JSON: el safehouse
@export var fijos: Array[Vector2] = []

static var _dia := 0
# Por escena (su JSON o "fijos"): {"dia": del sorteo, "con_drop": indices con algo hoy,
# "que": indice -> ruta del .tres ("" = PENDIENTE)}
static var _sorteos := {}

var escondites: Array[Vector2] = []
var _puestos := {}                   # indice -> WorldItem
var _jugador: Node3D
var _rayo: PhysicsRayQueryParameters3D
var _espera := 0.0
var _estado: Dictionary


func _ready() -> void:
	_rayo = PhysicsRayQueryParameters3D.new()
	_rayo.collision_mask = 1
	_jugador = get_tree().get_first_node_in_group("jugador")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.amanecio.connect(_amanecio)
	_cargar()
	var clave := "fijos" if not fijos.is_empty() else escondites_path
	if not _sorteos.has(clave):
		_sorteos[clave] = {"dia": -1, "con_drop": [] as Array[int], "que": {}}
	_estado = _sorteos[clave]
	if _estado["dia"] != _dia:
		_sortear()


func _process(delta: float) -> void:
	if _jugador == null:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = CADA
	var p := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	for i: int in _puestos.keys():
		if p.distance_to(escondites[i]) > QUITAR_A:
			_quitar(i)
	for i: int in _estado["con_drop"]:
		if not _puestos.has(i) and p.distance_to(escondites[i]) < PONER_A and CargaCuadro.hay():
			var inicio := Time.get_ticks_usec()
			_poner(i)
			CargaCuadro.gastar(inicio)


# Los de hoy, para pruebas y para el safehouse
func con_drop() -> Array[int]:
	return _estado["con_drop"]


func _amanecio() -> void:
	_dia += 1
	_sortear()


func _sortear() -> void:
	for i: int in _puestos.keys():
		_quitar(i)
	var con_drop_: Array[int] = []
	var que := {}
	var indices := range(escondites.size())
	indices.shuffle()
	for i: int in indices.slice(0, mini(por_dia, indices.size())):
		con_drop_.append(i)
		que[i] = LISTA.pick_random() if not LISTA.is_empty() else ""
	_estado["dia"] = _dia
	_estado["con_drop"] = con_drop_
	_estado["que"] = que


func _poner(i: int) -> void:
	var y := INF
	var donde := escondites[i]
	# El escondite es de los datos del mapa: si ahi hay algo encima, el piso libre mas cercano
	for radio: float in BUSCAR:
		for paso in (1 if radio == 0.0 else 8):
			var punto := escondites[i] + Vector2.from_angle(TAU * paso / 8.0) * radio
			var altura := _altura(punto)
			if altura != INF:
				y = altura
				donde = punto
				break
		if y != INF:
			break
	if y == INF:
		return   # todavia no carga el piso: se intenta otra vez en CADA s
	var ruta: String = (_estado["que"] as Dictionary).get(i, "")
	var objeto: Node3D = WORLD_ITEM.new()
	objeto.item_data = load(ruta) if ruta != "" else PENDIENTE
	objeto.name = "DropRaro%d" % i
	add_child(objeto)
	objeto.global_position = Vector3(donde.x, y + ALTO_OBJETO, donde.y)
	_puestos[i] = objeto
	# Al recogerlo (WorldItem se borra solo) ya no vuelve hoy
	objeto.tree_exiting.connect(_recogido.bind(i, objeto))


func _recogido(i: int, objeto: Node3D) -> void:
	if _puestos.get(i) != objeto:
		return   # lo quito _quitar: sigue siendo de hoy
	_puestos.erase(i)
	if objeto.get("_recogido"):
		(_estado["con_drop"] as Array).erase(i)


func _quitar(i: int) -> void:
	var objeto: Node3D = _puestos[i]
	_puestos.erase(i)
	if is_instance_valid(objeto):
		objeto.queue_free()


func _cargar() -> void:
	if not fijos.is_empty():
		escondites = fijos.duplicate()
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(escondites_path))
	if not datos is Dictionary:
		push_warning("DropsRaros: no se pudo leer %s" % escondites_path)
		return
	for e: Dictionary in datos["escondites"]:
		escondites.append(Vector2(e["x"], e["z"]))


func _altura(punto: Vector2) -> float:
	_rayo.from = Vector3(punto.x, 30.0, punto.y)
	_rayo.to = Vector3(punto.x, -2.0, punto.y)
	var pego := get_world_3d().direct_space_state.intersect_ray(_rayo)
	if pego.is_empty() or pego.position.y > ALTO_LIBRE:
		return INF
	return pego.position.y
