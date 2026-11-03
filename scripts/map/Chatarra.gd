class_name Chatarra
extends Node3D

# Un monton de chatarra en la banqueta (Partida.gd los pone junto a postes): se hurga con el
# boton de saltar, como un WorldItem, y da unos materiales sueltos para el taller
# (Materiales.chatarra, al Morral). Una vez por partida. Mallas y material compartidos.

const RADIO := 1.8
const VISTA := 22.0          # m hasta donde se ve el letrero
const LEJOS := 70.0          # m hasta donde se dibuja
const ALAMBRON := Vector2i(1, 2)
const SHADER := preload("res://shaders/ps1_combined.gdshader")
const PIEZAS := [
	# tamano, posicion, giro y, color
	[Vector3(0.7, 0.35, 0.5), Vector3(0.0, 0.175, 0.0), 0.3, Color(0.42, 0.25, 0.14)],
	[Vector3(0.5, 0.25, 0.4), Vector3(0.25, 0.47, 0.05), -0.5, Color(0.5, 0.5, 0.52)],
	[Vector3(1.0, 0.08, 0.08), Vector3(-0.1, 0.38, 0.2), 1.1, Color(0.35, 0.3, 0.28)],
	[Vector3(0.4, 0.3, 0.3), Vector3(-0.45, 0.15, -0.2), 0.8, Color(0.3, 0.33, 0.4)],
]

static var _mallas: Array[Mesh] = []
static var _materiales: Array[ShaderMaterial] = []

# Solo para ver (el yonke): sin letrero ni area, no se hurga
var adorno := false
# Frente a una casa en obra negra: ademas trae alambron (Partida._poner_obras)
var obra := false
# Un plano del taller tirado aqui (Recetas.PLANOS); con su haz para encontrarlo
var plano := ""

var _player_inside := false
var _aviso: Label3D


func _ready() -> void:
	if not adorno:
		add_to_group("interactuable")
		add_to_group("chatarra")
	if _mallas.is_empty():
		for pieza: Array in PIEZAS:
			var caja := BoxMesh.new()
			caja.size = pieza[0]
			_mallas.append(caja)
			var m := ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter("tint", pieza[3])
			m.set_shader_parameter("affine_enabled", false)
			_materiales.append(m)
		# La llanta
		var llanta := CylinderMesh.new()
		llanta.top_radius = 0.32
		llanta.bottom_radius = 0.32
		llanta.height = 0.16
		llanta.radial_segments = 10
		_mallas.append(llanta)
		var negro := ShaderMaterial.new()
		negro.shader = SHADER
		negro.set_shader_parameter("tint", Color(0.08, 0.08, 0.09))
		negro.set_shader_parameter("affine_enabled", false)
		_materiales.append(negro)
	for i in PIEZAS.size():
		_pieza(_mallas[i], _materiales[i], PIEZAS[i][1], PIEZAS[i][2], Vector3.ZERO)
	_pieza(_mallas[-1], _materiales[-1], Vector3(0.45, 0.22, 0.3), 0.0, Vector3(1.2, 0.0, 0.3))
	if adorno:
		return
	if plano != "":
		var haz := EfectosPixel.cuadro_bucle("haz", PiezaMapa.HAZ_ESCALA, PiezaMapa.HAZ_ALFA)
		if haz:
			add_child(haz)
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.position.y = 1.2
	_aviso.pixel_size = 0.005
	_aviso.modulate = Color(0.85, 0.85, 0.85)
	_aviso.text = "Chatarra"
	_aviso.visibility_range_end = VISTA
	add_child(_aviso)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	forma.shape = esfera
	forma.position.y = 0.8
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


func _pieza(malla: Mesh, material: Material, en: Vector3, giro_y: float, giro: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = malla
	m.material_override = material
	m.position = en
	m.rotation = giro + Vector3(0.0, giro_y, 0.0)
	m.visibility_range_end = LEJOS
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func is_player_inside() -> bool:
	return _player_inside


func interact() -> void:
	var morral := get_node("/root/Morral")
	morral.dar_varios(Materiales.chatarra())
	if obra:
		morral.dar("alambron", randi_range(ALAMBRON.x, ALAMBRON.y))
	if plano != "":
		get_node("/root/Taller").dar_plano(plano)
		morral.avisar("¡Plano! " + Recetas.PLANOS.get(plano, plano))
	Sonidos.tocar(self, "inv_examinar", -4.0)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("recoger", global_position)
	queue_free()


func _actualizar_aviso() -> void:
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	var que := "Un plano entre la chatarra" if plano != "" else ("Fierros de obra negra" if obra else "Chatarra")
	_aviso.text = "%s: hurgar" % tecla if _player_inside else que
