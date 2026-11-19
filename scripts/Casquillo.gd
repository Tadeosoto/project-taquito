class_name Casquillo
extends RigidBody3D

# Un casquillo de laton de la pistola (Pistola._expulsar_casquillo): un cuerpo de fisica de veras,
# aparte de la mano, que salta de la corredera hacia la derecha, rebota en el piso y suena
# "tin" una sola vez al primer golpe. Solo choca con el mundo (capa 1): ni al jugador ni a los
# zombis los empuja. La pistola guarda CASQUILLOS y los reusa, el mas viejo primero; a los
# DURA s se congela y se esconde hasta el siguiente tiro. La malla, la forma y el material son
# uno para todos.

const DURA := 4.0             # s que se ve antes de guardarse
const LARGO := 0.022          # m
const RADIO := 0.0055
const COLOR := Color(0.85, 0.65, 0.25)
const TONO_MIN := 1.1         # pitch_scale del tin, al azar
const TONO_MAX := 1.3
const GRACIA := 0.05          # s tras soltarlo en que ningun choque suena (sale de junto a la pistola)
const SHADER := preload("res://shaders/ps1_combined.gdshader")

# Los de las otras armas (Pistola.ARMAS "casquillo"; AG, 2026-11-18): el cartucho rojo de la
# Tinaquera (con su base de laton, suena mas sordo) y el laton chico de la Matraca y la Chicharra.
# tipo -> [largo, radio, color, tono]; "laton" es el de la pistola, con las constantes de arriba
const TIPOS := {
	"cartucho": [0.065, 0.0105, Color(0.75, 0.12, 0.1), 0.75],
	"chico": [0.018, 0.0045, Color(0.85, 0.65, 0.25), 1.35],
}

static var _malla: CylinderMesh
static var _forma: CylinderShape3D
static var _mallas := {}      # tipo -> [CylinderMesh, CylinderShape3D]

var _voz: AudioStreamPlayer3D
var _sono := false
var _desde := 0
var _tipo := "laton"
var _vista: MeshInstance3D
var _choque: CollisionShape3D
var _tono := 1.0


static func _preparar() -> void:
	if _malla:
		return
	_malla = CylinderMesh.new()
	_malla.top_radius = RADIO
	_malla.bottom_radius = RADIO
	_malla.height = LARGO
	_malla.radial_segments = 6
	_malla.rings = 1
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", COLOR)
	material.set_shader_parameter("affine_enabled", false)
	_malla.surface_set_material(0, material)
	_forma = CylinderShape3D.new()
	_forma.radius = RADIO
	_forma.height = LARGO


func _init() -> void:
	_preparar()
	collision_layer = 0
	collision_mask = 1
	mass = 0.01
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	var fisica := PhysicsMaterial.new()
	fisica.bounce = 0.35
	fisica.friction = 0.6
	physics_material_override = fisica
	_vista = MeshInstance3D.new()
	_vista.mesh = _malla
	_vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vista)
	_choque = CollisionShape3D.new()
	_choque.shape = _forma
	add_child(_choque)
	_voz = AudioStreamPlayer3D.new()
	_voz.unit_size = 3.0
	_voz.max_distance = 25.0
	add_child(_voz)
	body_entered.connect(_al_chocar)


# Al estar listo Godot vuelve a prender _physics_process: se apaga aqui
func _ready() -> void:
	_guardar()


# Cambia a otro tipo (TIPOS, o "laton"): la malla y la forma son una por tipo para todos
func vestir(tipo: String) -> void:
	if tipo == _tipo:
		return
	_tipo = tipo
	if not TIPOS.has(tipo):
		_vista.mesh = _malla
		_choque.shape = _forma
		_tono = 1.0
		return
	if not _mallas.has(tipo):
		var t: Array = TIPOS[tipo]
		var malla := CylinderMesh.new()
		malla.top_radius = t[1]
		malla.bottom_radius = t[1]
		malla.height = t[0]
		malla.radial_segments = 6
		malla.rings = 1
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("tint", t[2])
		material.set_shader_parameter("affine_enabled", false)
		malla.surface_set_material(0, material)
		var forma := CylinderShape3D.new()
		forma.radius = t[1]
		forma.height = t[0]
		_mallas[tipo] = [malla, forma]
	_vista.mesh = _mallas[tipo][0]
	_choque.shape = _mallas[tipo][1]
	_tono = TIPOS[tipo][3]


# Sale de `donde` con el empujon `impulso` (m/s) y un giro al azar
func soltar(donde: Transform3D, impulso: Vector3) -> void:
	freeze = false
	visible = true
	# Sin la escala del modelo de la pistola: Jolt no acepta cuerpos escalados disparejo
	global_transform = Transform3D(donde.basis.orthonormalized(), donde.origin)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_sono = false
	_desde = Time.get_ticks_msec()
	var giro := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 30.0
	if is_inside_tree():
		apply_central_impulse(impulso * mass)
		apply_torque_impulse(giro * mass * 0.0000003)
	else:
		# Jolt no deja empujar un cuerpo que aun no esta en el mundo
		linear_velocity = impulso
		angular_velocity = giro
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() - _desde > DURA * 1000.0:
		_guardar()


func _guardar() -> void:
	freeze = true
	visible = false
	set_physics_process(false)


# Suena solo al primer golpe contra el mundo (piso o pared), no contra alguien en la capa 1
func _al_chocar(cuerpo: Node) -> void:
	if _sono or not visible or cuerpo is CharacterBody3D:
		return
	if Time.get_ticks_msec() - _desde < GRACIA * 1000.0:
		return
	_sono = true
	_voz.stream = Sonidos.sonido("casquillo")
	if _voz.stream == null:
		return
	_voz.pitch_scale = randf_range(TONO_MIN, TONO_MAX) * _tono
	_voz.play()
