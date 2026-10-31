extends Node3D

# Los demas jugadores en la escena. En cada computadora el nodo `Player` de la escena es
# TU jugador, y todo lo que sigue a `Player` (mapa, dron, minimapa...) sigue funcionando
# igual; a los demas se les ve como copias sin fisica (companero.tscn), que siguen lo que
# mandan por Red. Aqui se manda el tuyo y se les da vida a los de ellos.

const COMPANERO := preload("res://scenes/red/companero.tscn")
const ENVIOS_POR_SEGUNDO := 20.0

@export var jugador_path: NodePath

var _jugador: Player
var _companeros := {}
var _espera := 0.0


func _ready() -> void:
	_jugador = get_node(jugador_path) as Player
	Red.jugadores_cambiaron.connect(_sincronizar)
	Red.estado_recibido.connect(_recibir)
	_sincronizar()


func _physics_process(delta: float) -> void:
	if not Red.en_red():
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = 1.0 / ENVIOS_POR_SEGUNDO
	var moviendose := Vector2(_jugador.velocity.x, _jugador.velocity.z).length() > 0.3
	var corriendo := moviendose and Input.is_action_pressed("sprint")
	# En una tienda, volando o en un acercamiento no se te ve en la calle
	var se_ve := _jugador.visible and _jugador.can_process()
	Red.enviar_estado(_jugador.global_position, _jugador.frijol.global_rotation.y, moviendose, not _jugador.is_on_floor(), corriendo, se_ve)


func _sincronizar() -> void:
	for id: int in Red.jugadores:
		if id != Red.mi_id() and not _companeros.has(id):
			var companero: Node3D = COMPANERO.instantiate()
			companero.name = "Companero%d" % id
			add_child(companero)
			companero.poner_nombre(Red.jugadores[id])
			_companeros[id] = companero
	for id: int in _companeros.keys():
		if not Red.jugadores.has(id):
			_companeros[id].queue_free()
			_companeros.erase(id)


func _recibir(id: int, posicion: Vector3, giro: float, moviendose: bool, en_aire: bool, corriendo: bool, se_ve: bool) -> void:
	if _companeros.has(id):
		_companeros[id].actualizar(posicion, giro, moviendose, en_aire, corriendo, se_ve)
