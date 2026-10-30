class_name Zombis
extends Node3D

# De noche salen zombis alrededor del jugador (docs/especificaciones.md 4.8), siempre
# fuera de la camara y en la calle. Hay mas donde esta mas destruido (Deterioro.zona) y
# cada noche un poco mas. Al amanecer se caen. Es lo minimo: las hordas con un Director
# y campos de flujo van despues. En coop los decide el servidor.

const ENTRE_ZOMBIS := 3.0     # s entre uno y otro
const ANILLO := Vector2(24.0, 36.0)   # m del jugador donde aparecen
const LEJOS := 70.0           # mas lejos se quitan: ya perdieron al jugador
const MAX_BASE := 2
const MAX_POR_ZONA := 8
const MAX_POR_NOCHE := 1
const MAX_TOTAL := 12
const INTENTOS := 8
const ALTO_CALLE := 0.6       # arriba de esto es una azotea o una barda
const CALENTAR_CUADROS := 3

@export var jugador_path: NodePath
@export var ciclo_path: NodePath

var noches := 0
var _jugador: Player
var _ciclo: Ciclo
var _espera := 0.0
var _calentando: Node3D
var _calentar := 0


func _ready() -> void:
	_jugador = get_node(jugador_path) as Player
	_ciclo = get_node(ciclo_path) as Ciclo
	_ciclo.anochecio.connect(func() -> void: noches += 1)
	_ciclo.amanecio.connect(_amanecer)
	# Se dibuja uno diminuto al cargar: si no, su shader con esqueleto se compilaba en el
	# cuadro del primer zombi de la primera noche
	_calentando = Zombie.new()
	_calentando.scale = Vector3.ONE * 0.002
	add_child(_calentando)
	# Despues de add_child: al estar listo, el nodo vuelve a prender su _physics_process
	_calentando.set_physics_process(false)
	_calentando.collision_layer = 0
	_calentando.remove_from_group("zombis")
	_calentar = CALENTAR_CUADROS


func _process(_delta: float) -> void:
	if _calentar > 0:
		var camara := get_viewport().get_camera_3d()
		if camara:
			_calentando.global_transform = camara.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * 0.002), Vector3(0.0, 0.0, -2.0))
		_calentar -= 1
		if _calentar == 0:
			_calentando.queue_free()


func _physics_process(delta: float) -> void:
	_quitar_lejanos()
	if not _ciclo.es_noche() or not _jugador.can_process() or not _jugador.is_physics_processing():
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = ENTRE_ZOMBIS
	if _vivos() < maximo():
		_aparecer()


# Cuantos puede haber aqui y esta noche
func maximo() -> int:
	var p := _jugador.global_position
	return mini(MAX_BASE + roundi(Deterioro.zona(p.x, p.z) * MAX_POR_ZONA) + (noches - 1) * MAX_POR_NOCHE, MAX_TOTAL)


func _vivos() -> int:
	var cuantos := 0
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		if z.estado != Zombie.Estado.MUERTO:
			cuantos += 1
	return cuantos


func _aparecer() -> void:
	var lugar := _lugar_libre()
	if lugar == Vector3.INF:
		return
	var zombi := Zombie.new()
	zombi.jugador = _jugador
	add_child(zombi)
	zombi.global_position = lugar


# Un punto en la calle, a un lado o atras de la camara; INF si no encontro
func _lugar_libre() -> Vector3:
	var camara := get_viewport().get_camera_3d()
	var espacio := get_world_3d().direct_space_state
	var centro := _jugador.global_position
	for i in INTENTOS:
		var angulo := randf() * TAU
		var radio := randf_range(ANILLO.x, ANILLO.y)
		var punto := centro + Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio)
		if camara and not camara.is_position_behind(punto) and camara.is_position_in_frustum(punto + Vector3.UP):
			continue
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, 30.0, punto.z), Vector3(punto.x, -2.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and pego.position.y < ALTO_CALLE:
			return pego.position + Vector3.UP * 0.05
	return Vector3.INF


func _quitar_lejanos() -> void:
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		if z.global_position.distance_to(_jugador.global_position) > LEJOS:
			z.queue_free()


func _amanecer() -> void:
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		z.caer_al_amanecer()


# Al desmayarse el jugador: la calle queda limpia
func limpiar() -> void:
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		z.queue_free()
