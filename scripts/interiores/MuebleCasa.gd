class_name MuebleCasa
extends Area3D

# Algo que se usa adentro de una casa (MueblesCasa.gd en la del jugador, CasaVecino.gd en las de
# los vecinos): un Area3D del grupo "interactuable" (el jugador usa el mas cercano con el boton de
# brincar/interactuar) con su letrero "Espacio: ..." mientras estas cerca. `accion` es lo que hace.

var accion: Callable
var _dentro := false
var _letrero: Label3D


static func crear(texto: String, lugar: Vector3, al_usar: Callable, radio := 1.3) -> MuebleCasa:
	var area := MuebleCasa.new()
	area.accion = al_usar
	area.position = lugar
	area._armar(texto, radio)
	return area


func _armar(texto: String, radio: float) -> void:
	add_to_group("interactuable")
	monitorable = false
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio
	forma.shape = esfera
	forma.position.y = 1.0
	add_child(forma)
	_letrero = Label3D.new()
	_letrero.text = "Espacio: %s" % texto
	_letrero.font_size = 32
	_letrero.pixel_size = 0.005
	_letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_letrero.no_depth_test = true
	_letrero.outline_size = 8
	_letrero.position.y = 1.9
	_letrero.visible = false
	add_child(_letrero)
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_dentro = true
			_letrero.visible = true)
	body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			_dentro = false
			_letrero.visible = false)


func is_player_inside() -> bool:
	return _dentro


func interact() -> void:
	accion.call()
