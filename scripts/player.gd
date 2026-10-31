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
# Lo que se siente al pegar: `fuerza` es 1 con el machete y cambia con el dano del arma
const DANO_MACHETE := 12.0
const FUERZA_MIN := 0.5
const FUERZA_MAX := 1.5
const SWING_VOLUMEN := -8.0   # dB: para que resalte el whack
const RETROCESO := 3.0        # m/s
const RETROCESO_CAIDA := 14.0 # por segundo
const SACUDE := 0.05          # m de la camara
const SACUDE_MATA := 2.0
const SACUDE_DURA := 0.15
const CONGELA := 0.05         # s de reloj real
const CONGELA_MATA := 0.08
const CONGELA_ESCALA := 0.02

var _enfriar := 0.0
var _pega_en := -1.0
var _invulnerable := 0.0
const SALTO := 3.0   # m entre dos ticks: mas que esto no es caminar
var _pos_antes := Vector3.ZERO
var _pos_ahora := Vector3.ZERO
var _frijol_base := Vector3.ZERO
var _pivote_base := Vector3.ZERO
var _retroceso := Vector3.ZERO
var _sacude_fuerza := 0.0
var _sacude_hasta := 0
var _congelado_hasta := 0
var _camara: Camera3D
var _voz: AudioStreamPlayer3D
var _mano: BoneAttachment3D
var _arma_visible: InventoryItemData


func _ready() -> void:
	add_to_group("jugador")
	_frijol_base = frijol.position
	_pivote_base = camera_pivot.position
	_camara = spring_arm.find_child("Camera3D", true, false) as Camera3D
	var reloj := RelojCongelada.new()
	reloj.jugador = self
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(reloj)
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
	_sonar("machetazo", SWING_VOLUMEN)


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
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	# Un zombi muerto en este golpe truena justo al soltar la congelada
	var truena_en := int(CONGELA_MATA * 1000.0)
	var pego := false
	var mato := false
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if hacia.length() <= ATAQUE_ALCANCE and hacia.normalized().dot(frente) >= ATAQUE_ANGULO:
			var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, truena_en)
			pego = pego or resultado != 0
			mato = mato or resultado == 2
	if pego:
		_sentir_golpe(frente, fuerza, mato)


# Una vez por golpe, aunque le pegue a varios: el whack, el rebote, la sacudida y la congelada
func _sentir_golpe(frente: Vector3, fuerza: float, mato: bool) -> void:
	_voz.pitch_scale = randf_range(0.9, 1.12)
	_sonar("whack")
	_retroceso = -frente * RETROCESO * fuerza
	_sacude_fuerza = SACUDE * fuerza * (SACUDE_MATA if mato else 1.0)
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_MATA if mato else CONGELA)


# El juego casi se detiene unos cuadros. Un SceneTreeTimer no servia para soltarlo: con la
# escala de tiempo tan baja se quedaba en camara lenta varios segundos
func _congelar(segundos: float) -> void:
	_congelado_hasta = maxi(_congelado_hasta, Time.get_ticks_msec() + int(segundos * 1000.0))
	Engine.time_scale = CONGELA_ESCALA


func _revisar_congelada() -> void:
	if _congelado_hasta > 0 and Time.get_ticks_msec() >= _congelado_hasta:
		_congelado_hasta = 0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if _congelado_hasta > 0:
		_congelado_hasta = 0
		Engine.time_scale = 1.0


# Mira el reloj en cada cuadro aunque el juego este en pausa o el jugador apagado (el
# inventario, una tienda): la congelada siempre se suelta
class RelojCongelada extends Node:
	var jugador: Player

	func _process(_delta: float) -> void:
		jugador._revisar_congelada()


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


func _sonar(nombre: String, volumen := 0.0) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.volume_db = volumen
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


# El cuerpo se mueve a 60 por segundo y la pantalla mas seguido: sin esto el personaje y la
# camara avanzan a saltitos aunque haya muchos FPS. Solo se suaviza lo que se ve (modelo y
# camara), entre las dos ultimas posiciones del cuerpo; la fisica no cambia.
func _process(_delta: float) -> void:
	var ahora := global_position
	# Lo movieron de golpe (reaparecer, salir de una tienda) o esta congelado: sin suavizar
	if not is_physics_processing() or _pos_ahora.distance_squared_to(ahora) > SALTO * SALTO:
		_pos_antes = ahora
		_pos_ahora = ahora
	var fraccion := Engine.get_physics_interpolation_fraction()
	var desfase := global_basis.inverse() * (_pos_antes.lerp(_pos_ahora, fraccion) - ahora)
	frijol.position = _frijol_base + desfase
	camera_pivot.position = _pivote_base + desfase
	_sacudir()


# Corrimiento de la camara, no de su nodo: el resorte ni se entera. En reloj real, porque el
# golpe tambien congela el juego
func _sacudir() -> void:
	if _sacude_hasta == 0:
		return
	var queda := float(_sacude_hasta - Time.get_ticks_msec()) / (SACUDE_DURA * 1000.0)
	if queda <= 0.0:
		_sacude_hasta = 0
		_camara.h_offset = 0.0
		_camara.v_offset = 0.0
		return
	_camara.h_offset = randf_range(-1.0, 1.0) * _sacude_fuerza * queda
	_camara.v_offset = randf_range(-1.0, 1.0) * _sacude_fuerza * queda


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

	# El rebote va aparte: el frenado de arriba lo borraria
	velocity += _retroceso
	move_and_slide()
	velocity -= _retroceso
	_retroceso = _retroceso.move_toward(Vector3.ZERO, RETROCESO * RETROCESO_CAIDA * delta)
	_pos_antes = _pos_ahora
	_pos_ahora = global_position

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
