extends Node3D

# Modo dron para recorrer el mapa desde arriba: vuela a altura fija sobre las
# casas a `velocidad` m/s, con la camara viendo hacia abajo. V cambia entre dron
# y jugador (el jugador se queda congelado mientras vuelas y al volver aparece
# debajo del dron).
# MapStreamer y MapPuntos siguen a este nodo (target_path), que cuando no esta
# volando va pegado al jugador.
#
# Controles: WASD / flechas / stick para moverse, mouse o Q/E para girar,
# Shift para ir al triple de rapido.

@export var player_path: NodePath
@export var environment_path: NodePath
@export var iniciar_en_dron := true
@export var altura := 30.0
@export var velocidad := 15.0
@export_range(-89.0, -10.0) var inclinacion := -55.0
@export var giro_teclas := 1.5          # rad/s con Q/E
@export var sensibilidad_mouse := 0.003
# La niebla del mapa tapa a ~100 m; desde arriba se baja para ver mas lejos
@export var niebla_dron := 0.006
# El jugador congelado no pierde nada: de noche seria escondite (en el safehouse se deja)
@export var cerrado_de_noche := false

var _ciclo: Node
var _active := false
var _camera: Camera3D
var _player: CharacterBody3D
var _environment: Environment
var _fog_normal := 0.0


# En _enter_tree y no en _ready: MapStreamer hace su primera carga en su _ready
# y para entonces el dron ya tiene que estar arriba del jugador
func _enter_tree() -> void:
	_player = get_node(player_path) as CharacterBody3D
	global_position = Vector3(_player.global_position.x, altura, _player.global_position.z)
	global_rotation.y = _player.global_rotation.y


func _ready() -> void:
	var world_env := get_node_or_null(environment_path) as WorldEnvironment
	if world_env:
		_environment = world_env.environment
		_fog_normal = _environment.fog_density

	_camera = Camera3D.new()
	_camera.rotation_degrees.x = inclinacion
	_camera.far = 1000.0
	add_child(_camera)
	_set_active(iniciar_en_dron)
	if cerrado_de_noche:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
		if _ciclo:
			_ciclo.anochecio.connect(func() -> void:
				if _active:
					_set_active(false))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if not (_ciclo and _ciclo.es_noche()):
			_set_active(not _active)
	elif _active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensibilidad_mouse


func _process(delta: float) -> void:
	if not _active:
		# Pegado al jugador para que el mapa se cargue alrededor de el
		global_position = Vector3(_player.global_position.x, altura, _player.global_position.z)
		return

	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		turn -= 1.0
	rotation.y += turn * giro_teclas * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (global_basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	var speed := velocidad * (3.0 if Input.is_action_pressed("sprint") else 1.0)
	global_position += direction.normalized() * input.length() * speed * delta
	global_position.y = altura


func volando() -> bool:
	return _active


func _set_active(active: bool) -> void:
	_active = active
	preload("res://scripts/map/CargaCuadro.gd").volando = active
	if active:
		_camera.make_current()
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		# El jugador aterriza debajo del dron (en la calle o en la azotea, lo que
		# haya), mirando hacia donde veia el dron
		var landing := Vector3(global_position.x, 3.0, global_position.z)
		var query := PhysicsRayQueryParameters3D.create(global_position, landing - Vector3(0.0, 10.0, 0.0))
		query.exclude = [_player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			landing = hit.position + Vector3(0.0, 1.0, 0.0)
		_player.global_position = landing
		_player.velocity = Vector3.ZERO
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		(_player.find_child("Camera3D", true, false) as Camera3D).make_current()
		(_player.get_node("CameraPivot") as Node3D).global_rotation.y = global_rotation.y
	if _environment:
		_environment.fog_density = niebla_dron if active else _fog_normal
