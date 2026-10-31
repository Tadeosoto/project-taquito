class_name PiezaMapa
extends Node3D

# Un pedazo de mapa tirado en el mundo (docs/especificaciones.md 4.9): gira y se recoge con
# el boton de saltar, como un WorldItem. Con `zona` -1 da el primero que falte (el safehouse,
# donde las zonas no coinciden con el lugar).

const TAMANO := Vector2(0.95, 0.7)
const ALTO := 0.75
const GIRO := 70.0           # grados por segundo
const RADIO := 1.8
const VISTA := 28.0          # m hasta donde se ve el letrero
const COLOR_PAPEL := Color(0.86, 0.8, 0.62)
const SHADER := preload("res://shaders/ps1_combined.gdshader")

static var _material: ShaderMaterial

var zona := -1

var _player_inside := false
var _papel: MeshInstance3D
var _aviso: Label3D


func _ready() -> void:
	add_to_group("interactuable")
	add_to_group("piezas_mapa")
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("tint", COLOR_PAPEL)
		_material.set_shader_parameter("affine_enabled", false)
		_material.set_shader_parameter("sin_sombra", true)
	var malla := BoxMesh.new()
	malla.size = Vector3(TAMANO.x, TAMANO.y, 0.02)
	_papel = MeshInstance3D.new()
	_papel.mesh = malla
	_papel.material_override = _material
	_papel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_papel.position.y = ALTO
	_papel.rotation.x = 0.35
	add_child(_papel)
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.position.y = ALTO + 0.7
	_aviso.pixel_size = 0.006
	_aviso.modulate = Color(1.0, 0.85, 0.1)
	_aviso.text = "Pedazo de mapa"
	_aviso.visibility_range_end = VISTA
	add_child(_aviso)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	forma.shape = esfera
	forma.position.y = 1.0
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = true
			_actualizar_aviso())
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false
			_actualizar_aviso())


func _process(delta: float) -> void:
	_papel.rotation_degrees.y += GIRO * delta


func is_player_inside() -> bool:
	return _player_inside


func interact() -> void:
	var cual: int = zona if zona >= 0 else get_node("/root/PiezasMapa").siguiente_faltante()
	get_node("/root/PiezasMapa").recoger(cual)
	queue_free()


func _actualizar_aviso() -> void:
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	_aviso.text = "%s: recoger pedazo de mapa" % tecla if _player_inside else "Pedazo de mapa"
