extends Node3D

# Carga solo los cuadros del mapa cercanos al jugador (y los descarga al
# alejarse), en vez de tener los ~200 cuadros en memoria con su colision.
# Los cuadros los genera tools/map_import/split_cuadros.gd a partir de
# models/zona_mapa.glb; resources/map/cuadros/indice.json dice donde esta cada uno.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")

@export_file("*.json") var indice_path := "res://resources/map/cuadros/indice.json"
@export var target_path: NodePath

# Se carga todo cuadro que tenga algo a menos de esto (m) del jugador (se mide al
# rectangulo que ocupa, no a su centro: una calle larga se sale de su cuadro).
# La niebla tapa antes de esto.
@export var load_radius := 300.0
# Se descarga al pasar de esto; mas grande que load_radius para que un cuadro
# no se cargue y descargue una y otra vez en la orilla
@export var unload_radius := 400.0
# Cada cuanto (s) se revisa la posicion del jugador
@export var check_interval := 0.25

var _cuadros := []        # [{archivo, min_x, max_x, min_z, max_z}]
var _loaded := {}         # archivo -> Node3D
var _requested := {}      # archivo -> true (cargando en otro hilo)
var _timer := 0.0
var _target: Node3D


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(indice_path))
	if not data is Dictionary:
		push_error("MapStreamer: no se pudo leer %s (corre tools/map_import/split_cuadros.gd)" % indice_path)
		return
	_cuadros = data["cuadros"]
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_error("MapStreamer: falta target_path (el jugador)")
		return
	# Lo que esta alrededor del spawn se carga de una vez, para que el jugador
	# no aparezca sin piso
	for cuadro in _cuadros:
		if _distance(cuadro) < CargaCuadro.carga(load_radius):
			_add(cuadro["archivo"], load(cuadro["archivo"]))


func _process(delta: float) -> void:
	if _target == null:
		return
	_poll_requests()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval

	for cuadro in _cuadros:
		var archivo: String = cuadro["archivo"]
		var distance := _distance(cuadro)
		if distance < CargaCuadro.carga(load_radius) and not _loaded.has(archivo) and not _requested.has(archivo):
			ResourceLoader.load_threaded_request(archivo)
			_requested[archivo] = true
		elif distance > CargaCuadro.descarga(unload_radius) and _loaded.has(archivo):
			_loaded[archivo].queue_free()
			_loaded.erase(archivo)


# Los cuadros que ya terminaron de cargar se meten al arbol dentro del presupuesto
# del cuadro (CargaCuadro); los demas esperan cargados al siguiente
func _poll_requests() -> void:
	for archivo: String in _requested.keys():
		match ResourceLoader.load_threaded_get_status(archivo):
			ResourceLoader.THREAD_LOAD_LOADED:
				if not CargaCuadro.hay():
					continue
				var inicio := Time.get_ticks_usec()
				_requested.erase(archivo)
				_add(archivo, ResourceLoader.load_threaded_get(archivo))
				CargaCuadro.gastar(inicio)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_requested.erase(archivo)
				push_warning("MapStreamer: no se pudo cargar %s" % archivo)


func _add(archivo: String, scene: PackedScene) -> void:
	var node := scene.instantiate() as Node3D
	add_child(node)
	_loaded[archivo] = node


# Distancia del jugador al rectangulo del cuadro (0 si esta adentro)
func _distance(cuadro: Dictionary) -> float:
	var p := _target.global_position
	var dx := maxf(maxf(cuadro["min_x"] - p.x, p.x - cuadro["max_x"]), 0.0)
	var dz := maxf(maxf(cuadro["min_z"] - p.z, p.z - cuadro["max_z"]), 0.0)
	return Vector2(dx, dz).length()
