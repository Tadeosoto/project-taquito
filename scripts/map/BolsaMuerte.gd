extends Node3D

# Lo que traias cuando caiste (docs/especificaciones.md 1.5): se queda donde caiste hasta
# que vuelvas por ello. La crea Supervivencia.gd, que quita la anterior si caes otra vez.
# Se recoge como un WorldItem; si no te cabe todo, lo demas se queda en la bolsa.

const MODELO := preload("res://resources/productos/mochila_escolar.tres")
const TAMANO := 0.8
const RADIO := 1.8

var items: Array[InventoryItemData] = []

var _player_inside := false
var _aviso: Label3D


func _ready() -> void:
	add_to_group("interactuable")
	add_to_group("bolsa_muerte")
	var modelo: Node3D = MODELO.crear_modelo(TAMANO)
	if modelo:
		modelo.position.y = TAMANO / 2.0
		add_child(modelo)
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.position = Vector3.UP * 1.3
	_aviso.pixel_size = 0.008
	_aviso.modulate = Color(1.0, 0.85, 0.1)
	add_child(_aviso)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	forma.shape = esfera
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
	_actualizar_aviso()


func is_player_inside() -> bool:
	return _player_inside


func interact() -> void:
	var inventario := get_node("/root/Inventory")
	while not items.is_empty() and inventario.add_item(items[0]):
		items.remove_at(0)
	if items.is_empty():
		queue_free()
	else:
		_actualizar_aviso()


func _actualizar_aviso() -> void:
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	_aviso.text = "%s: recoger tus cosas (%d)" % [tecla, items.size()] if _player_inside else "Tus cosas"
