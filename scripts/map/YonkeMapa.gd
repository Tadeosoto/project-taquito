class_name YonkeMapa
extends Node3D

# El Yonke de Don Chava en el mundo (en map_test.tscn, en un baldio de Parques de Santa Mugre;
# en el safehouse, con su propia barda): un letrero, un tejaban de lamina y montones de
# chatarra detras de la barda, y la flecha amarilla en la banqueta que mete al interior
# (scenes/interiores/yonke.tscn, por Interiores.gd como cualquier tienda).
# +Z del nodo da a la calle (la flecha va de ese lado).

const NOMBRE := "El Yonke de Don Chava"
const LEJOS := 140.0             # m hasta donde se dibuja
const SHADER := preload("res://shaders/ps1_combined.gdshader")
const LAMINA := Color(0.5, 0.36, 0.25)
const LAMINA_GRIS := Color(0.55, 0.56, 0.58)
const FLECHA_EN := Vector3(0.0, 0.0, 3.0)
const FLECHA_RADIO := 0.9
const CHATARRA_EN := [Vector3(-4.0, 0.0, -3.0), Vector3(3.5, 0.0, -4.5), Vector3(-1.0, 0.0, -9.0)]
const CARROS := [Vector3(5.5, 0.4, -8.5), Vector3(5.6, 1.2, -8.4), Vector3(-6.0, 0.4, -7.0)]
const CARRO := Vector3(1.9, 0.8, 3.6)
const CARRO_COLORES := [Color(0.55, 0.18, 0.15), Color(0.2, 0.35, 0.5), Color(0.6, 0.55, 0.3)]

@export var puntos_path: NodePath
# En el mapa la barda ya existe (MapBardas: el baldio); en el safehouse se arma aqui
@export var con_barda := false
@export var barda_largo := 14.0

var _puntos: MapPuntos


func _ready() -> void:
	add_to_group("yonke")
	_puntos = get_node_or_null(puntos_path) as MapPuntos
	# Tejaban de lamina al fondo
	_caja(Vector3(3.4, 2.6, 3.0), Vector3(0.0, 1.3, -6.0), LAMINA)
	_caja(Vector3(3.9, 0.08, 3.6), Vector3(0.0, 2.65, -5.9), LAMINA_GRIS)
	for i in CARROS.size():
		_caja(CARRO, CARROS[i], CARRO_COLORES[i % CARRO_COLORES.size()])
	for en: Vector3 in CHATARRA_EN:
		var monton := Chatarra.new()
		monton.adorno = true
		monton.position = en
		monton.scale = Vector3.ONE * 1.8
		monton.rotation.y = en.x
		add_child(monton)
	if con_barda:
		_caja(Vector3(barda_largo, 2.2, 0.12), Vector3(0.0, 1.1, 0.0), LAMINA_GRIS)
	var letrero := Label3D.new()
	letrero.text = "YONKE\nDON CHAVA"
	letrero.font_size = 64
	letrero.pixel_size = 0.012
	letrero.modulate = Color(1.0, 0.85, 0.1)
	letrero.outline_size = 12
	letrero.position = Vector3(0.0, 2.9, 0.2)
	letrero.visibility_range_end = 60.0
	add_child(letrero)
	_marcador()


func _caja(tamano: Vector3, en: Vector3, color: Color) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("affine_enabled", false)
	m.set_shader_parameter("jitter_enabled", false)
	m.set_shader_parameter("wobble_enabled", false)
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = m
	nodo.position = en
	nodo.visibility_range_end = LEJOS
	add_child(nodo)


# La flecha de las tiendas (MapPuntos.flecha) y su area: al pisarla se entra
func _marcador() -> void:
	var area := Area3D.new()
	area.name = "Marcador"
	area.position = FLECHA_EN
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = FLECHA_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and _puntos:
			_puntos.entrar_negocio.emit("yonke", "yonke", NOMBRE, false, area))
