class_name Cargador
extends RigidBody3D

# El cargador vacio que se cae al recargar la pistola (Pistola, SUELTA_EN): cuerpo de fisica
# aparte del arma, como Casquillo.gd. Su sonido (recarga_suelta, pistol_mag_drop) arranca al
# soltarse y viaja con el; el golpe contra el piso viene a los CHOCA_EN s del archivo, asi que
# se avienta con la velocidad justa para tocar el piso en ese momento (soltar). Solo choca con
# el mundo. La pistola guarda CARGADORES y los reusa, el mas viejo primero; a los DURA s se
# hunde tantito y se esconde. La malla (y su material) y la forma son una para todos.

const DURA := 20.0            # s en el piso
const HUNDE := 0.02           # m que se hunde en el ultimo segundo
const MEDIDA := Vector3(0.03, 0.11, 0.02) # m: lo largo es Y, como la cacha
# En pistol_mag_drop.wav: se desliza 0-0.2 s, silencio, y pega en el piso a los 0.32 s
# (rebotes hasta 0.65). Medido de su envolvente
const CHOCA_EN := 0.32
const VOLUMEN := -3.0        # dB del golpe en el piso: igual que el cock (Pistola.CIERRA_VOLUMEN, AG)
const LADO := 0.6             # m/s hacia un lado al azar, para que no caiga siempre igual
const COLOR := Color(0.12, 0.12, 0.13)
const COLOR_LATON := Color(0.8, 0.62, 0.25)
const SHADER := preload("res://shaders/ps1_combined.gdshader")

static var _malla: ArrayMesh
static var _forma: BoxShape3D

var _voz: AudioStreamPlayer3D
var _desde := 0


# La malla del cargador: el cuerpo oscuro y la punta de laton (los tiros) arriba. La usa
# tambien el que trae la mano izquierda (Player.cargador_en_mano)
static func malla() -> ArrayMesh:
	if _malla:
		return _malla
	_malla = ArrayMesh.new()
	var cuerpo := SurfaceTool.new()
	cuerpo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caja := BoxMesh.new()
	caja.size = MEDIDA
	cuerpo.append_from(caja, 0, Transform3D())
	var base := BoxMesh.new()
	base.size = Vector3(MEDIDA.x * 1.15, MEDIDA.y * 0.08, MEDIDA.z * 1.2)
	cuerpo.append_from(base, 0, Transform3D(Basis(), Vector3(0, -MEDIDA.y * 0.5, 0)))
	cuerpo.commit(_malla)
	_malla.surface_set_material(0, _material(COLOR))
	var punta := SurfaceTool.new()
	punta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bala := BoxMesh.new()
	bala.size = Vector3(MEDIDA.x * 0.6, MEDIDA.y * 0.1, MEDIDA.z * 0.8)
	punta.append_from(bala, 0, Transform3D(Basis(), Vector3(0, MEDIDA.y * 0.53, 0)))
	punta.commit(_malla)
	_malla.surface_set_material(1, _material(COLOR_LATON))
	return _malla


static func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	return material


func _init() -> void:
	if _forma == null:
		_forma = BoxShape3D.new()
		_forma.size = MEDIDA
	collision_layer = 0
	collision_mask = 1
	mass = 0.1
	continuous_cd = true
	var fisica := PhysicsMaterial.new()
	fisica.bounce = 0.25
	fisica.friction = 0.7
	physics_material_override = fisica
	var vista := MeshInstance3D.new()
	vista.mesh = malla()
	vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vista)
	var choque := CollisionShape3D.new()
	choque.shape = _forma
	add_child(choque)
	_voz = AudioStreamPlayer3D.new()
	_voz.unit_size = 3.0
	_voz.max_distance = 30.0
	_voz.volume_db = VOLUMEN
	add_child(_voz)


# Al estar listo Godot vuelve a prender _physics_process: se apaga aqui
func _ready() -> void:
	_guardar()


# Se suelta en `donde` y cae al piso justo cuando suena el golpe del archivo
func soltar(donde: Transform3D, excluir: Array[RID]) -> void:
	freeze = false
	visible = true
	global_transform = donde
	angular_velocity = Vector3.ZERO
	_desde = Time.get_ticks_msec()
	var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var vel := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * LADO
	var espacio := get_world_3d().direct_space_state
	var rayo := PhysicsRayQueryParameters3D.create(donde.origin, donde.origin + Vector3.DOWN * 3.0, 1, excluir)
	var piso := espacio.intersect_ray(rayo)
	if piso:
		# alto + vy t - g t^2 / 2 = 0 con t = CHOCA_EN (lo que le falta a la punta mas baja)
		var alto: float = donde.origin.y - (piso.position as Vector3).y - MEDIDA.y * 0.5
		vel.y = (gravedad * CHOCA_EN * CHOCA_EN * 0.5 - alto) / CHOCA_EN
	if is_inside_tree():
		linear_velocity = Vector3.ZERO
		apply_central_impulse(vel * mass)
	else:
		linear_velocity = vel
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	_voz.stream = Sonidos.sonido("recarga_suelta")
	if _voz.stream:
		_voz.pitch_scale = 1.0
		_voz.play()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	var t := (Time.get_ticks_msec() - _desde) / 1000.0
	if t > DURA:
		_guardar()
	elif t > DURA - 1.0 and freeze == false and linear_velocity.length_squared() < 0.01:
		# Se queda quieto y se hunde tantito antes de irse
		freeze = true
	if freeze and visible and t > DURA - 1.0:
		global_position.y -= HUNDE * get_physics_process_delta_time()


func _guardar() -> void:
	freeze = true
	visible = false
	set_physics_process(false)
