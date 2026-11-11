extends Node3D

# Algo que hay que levantar para una mision (el perro, MisionesMundo.gd): con el boton de saltar
# llama a `al_recoger`, y deja de ser algo que se recoge.

const RADIO := 2.2

var al_recoger := Callable()
# Lo que dice el aviso: "Espacio: levantar <que>"
var que := "al perro"

var _player_inside := false
var _aviso: Label3D


func _ready() -> void:
	add_to_group("interactuable")
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.pixel_size = 0.006
	_aviso.position.y = 1.0
	_aviso.visible = false
	_aviso.text = ("Espacio: levantar " if Input.get_connected_joypads().is_empty() else "X: levantar ") + que
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
			_aviso.visible = true)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false
			_aviso.visible = false)


func is_player_inside() -> bool:
	return _player_inside


func interact() -> void:
	remove_from_group("interactuable")
	_aviso.queue_free()
	for hijo in get_children():
		if hijo is Area3D:
			hijo.queue_free()
	al_recoger.call()
