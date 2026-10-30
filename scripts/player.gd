extends CharacterBody3D
class_name Player

@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 0.0025
@export var rotation_speed: float = 16.0
@export var speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var gravity: float = 40.0
@export var acceleration: float = 15.0
@export var jump_velocity: float = 13.0
# Q / E giran la camara (lo prende map_test.tscn; en world.tscn Q es del inventario)
@export var girar_con_qe: bool = false

# Initial downward pitch. Includes the +10.4 deg that used to be baked into the
# Camera3D node's transform, so removing that offset keeps the same view.
var camera_pitch: float = -4.6

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var frijol: Node3D = $Frijol
@onready var ninja: Node3D = $Frijol/Ninja

# Con que le pega a los zombis (Zombie.gd): el mejor `dano` del inventario, o a puño limpio.
# Inventario y Salud se piden por su ruta: los scripts de tools/ cargan esta clase antes
# de que existan los autoloads
const DANO_PUNO := 5
const ATAQUE_ENFRIAR := 0.6
const ATAQUE_PEGA_EN := 0.22
const ATAQUE_ALCANCE := 2.4
const ATAQUE_ANGULO := 0.35   # coseno: lo que abarca hacia los lados
const INVULNERABLE := 0.7     # s despues de recibir un golpe
const ARMA_TAMANO := 0.6
# El mango va en el puño: crear_modelo centra y deja lo largo en X con el mango en +X
const ARMA_GIRO := Vector3(0.0, 90.0, -90.0)
const ARMA_MANGO := 0.24

var _enfriar := 0.0
var _pega_en := -1.0
var _invulnerable := 0.0
var _voz: AudioStreamPlayer3D
var _mano: BoneAttachment3D
var _arma_visible: InventoryItemData


func _ready() -> void:
	add_to_group("jugador")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_voz = AudioStreamPlayer3D.new()
	add_child(_voz)
	_armar_mano()
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.inventory_changed.connect(_mostrar_arma)
	_mostrar_arma()


# --- Pelear ---

func _atacar() -> void:
	if _enfriar > 0.0:
		return
	_enfriar = ATAQUE_ENFRIAR
	_pega_en = ATAQUE_PEGA_EN
	if ninja.has_method("accion"):
		ninja.accion("Punch")
	_sonar("machetazo")


func _golpear() -> void:
	var dano := DANO_PUNO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		var arma: InventoryItemData = inventario.arma()
		if arma:
			dano = arma.dano
	var frente := -frijol.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if hacia.length() <= ATAQUE_ALCANCE and hacia.normalized().dot(frente) >= ATAQUE_ANGULO:
			zombi.recibir_golpe(dano, global_position)


# Un golpe de zombi (Zombie.gd)
func recibir_dano(dano: int) -> void:
	if _invulnerable > 0.0:
		return
	_invulnerable = INVULNERABLE
	if ninja.has_method("accion"):
		ninja.accion("RecieveHit")
	_sonar("dolor")
	get_node("/root/Salud").vida -= dano


# Se queda quieto y deja de contestar (al desmayarse, Supervivencia.gd)
func detener() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)


func reanudar() -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
	if ninja.has_method("terminar_accion"):
		ninja.terminar_accion()


func caer() -> void:
	if ninja.has_method("accion"):
		ninja.accion("Defeat")


# La mano derecha del modelo; el arma se ve en ella
func _armar_mano() -> void:
	var esqueleto := ninja.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null:
		return
	for nombre in ["Fist.R", "Hand.R", "Wrist.R", "LowerArm.R"]:
		if esqueleto.find_bone(nombre) >= 0:
			_mano = BoneAttachment3D.new()
			esqueleto.add_child(_mano)
			_mano.bone_name = nombre
			return


func _mostrar_arma() -> void:
	if _mano == null:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var arma: InventoryItemData = inventario.arma() if inventario else null
	if arma == _arma_visible:
		return
	_arma_visible = arma
	for hijo in _mano.get_children():
		hijo.queue_free()
	if arma == null:
		return
	var modelo := arma.crear_modelo(ARMA_TAMANO)
	if modelo:
		_mano.add_child(modelo)
		modelo.visible = false
		# Un cuadro despues: antes el hueso todavia no tiene su transformacion. Sin la
		# escala del hueso, y con la hoja hacia adelante del puño
		await get_tree().process_frame
		if not is_instance_valid(modelo):
			return
		var escala := _mano.global_transform.basis.get_scale()
		modelo.scale = Vector3.ONE / maxf(escala.x, 0.001)
		modelo.rotation_degrees = ARMA_GIRO
		(modelo.get_child(0) as Node3D).position.x -= ARMA_MANGO
		modelo.visible = true


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity * 100.0
		camera_pitch = clampf(camera_pitch, -60.0, 30.0)
		spring_arm.rotation_degrees.x = camera_pitch
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_atacar()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_enfriar = maxf(_enfriar - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if _pega_en >= 0.0:
		_pega_en -= delta
		if _pega_en < 0.0:
			_golpear()
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var right: Vector3 = camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = right * input_direction.x + forward * -input_direction.y

	var is_moving: bool = direction.length_squared() > 0.01
	var is_sprinting: bool = is_moving and Input.is_action_pressed("sprint")
	var move_speed: float = sprint_speed if is_sprinting else speed
	var target_horizontal := Vector3.ZERO
	if is_moving:
		var look_target: Vector3 = frijol.global_position + direction
		var target_transform: Transform3D = frijol.global_transform.looking_at(look_target, Vector3.UP)
		frijol.global_transform = frijol.global_transform.interpolate_with(
			target_transform,
			clampf(rotation_speed * delta, 0.0, 1.0)
		)
		var facing: Vector3 = -frijol.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		target_horizontal = facing * move_speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var braking: bool = not is_moving or horizontal.length() > target_horizontal.length() + 0.05
	if not braking and horizontal.length_squared() > 0.01 and target_horizontal.length_squared() > 0.01:
		braking = horizontal.normalized().dot(target_horizontal.normalized()) < 0.92
	if braking:
		velocity.x = target_horizontal.x
		velocity.z = target_horizontal.z
	else:
		velocity.x = move_toward(velocity.x, target_horizontal.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_horizontal.z, acceleration * delta)

	# Gravity is applied exactly once per frame; on the floor we snap to zero.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	# Keyboard / gamepad camera rotation (mouse-look is handled above).
	var camera_input: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down",
		0.2
	)
	if girar_con_qe:
		var teclas := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		camera_input.x = clampf(camera_input.x + teclas, -1.0, 1.0)
	if camera_input.length() > 0.2:
		camera_pivot.rotation.y -= camera_input.x * camera_sensitivity * delta
		camera_pitch -= camera_input.y * camera_sensitivity * 50.0 * delta
	camera_pitch = clampf(camera_pitch, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch

	if Input.is_action_just_pressed("jump") and is_on_floor():
		var cercano := _nearby_interactable()
		if cercano != null:
			cercano.interact()
		else:
			velocity.y = jump_velocity

	move_and_slide()

	if ninja.has_method("update_animation"):
		ninja.update_animation(is_moving, not is_on_floor(), is_sprinting)


# El NPC o el objeto para recoger (WorldItem) mas cercano que tenga al jugador en su area
func _nearby_interactable() -> Node:
	var closest: Node = null
	var closest_distance := INF
	for grupo: String in ["npc", "interactuable"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not nodo.has_method("is_player_inside") or not nodo.is_player_inside():
				continue
			var distance := global_position.distance_squared_to(nodo.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = nodo
	return closest
