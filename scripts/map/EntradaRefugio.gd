class_name EntradaRefugio
extends Node3D

# Una entrada del refugio (Refugio.gd), abierta o atrancada con tablas: el jugador las
# pone con el boton de saltar y pasa a traves de ellas, los zombis no y les pegan. Origen
# en el piso, al centro del hueco; el hueco va a lo largo de X.

signal debil
signal rota

const TABLAS := preload("res://resources/productos/tablas.tres")
const VIDA_POR_TABLA := 40
const MAX_TABLAS := 3
const CAPA := 4          # capa 3: la tienen en su mascara los zombis, no el jugador
const ANCHO := 2.4
const ALTO := 2.0
const RADIO := 2.5       # desde donde se puede poner una tabla

var vida := 0
var _player_inside := false
var _cuerpo: StaticBody3D
var _forma: CollisionShape3D
var _tablas: Array[MeshInstance3D] = []
var _aviso: Label3D
var _voz: AudioStreamPlayer3D


func armar(material: Material) -> void:
	add_to_group("interactuable")
	_cuerpo = StaticBody3D.new()
	_cuerpo.collision_layer = CAPA
	_cuerpo.collision_mask = 0
	add_child(_cuerpo)
	_forma = CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO, ALTO, 0.4)
	_forma.shape = caja
	_forma.position.y = ALTO / 2.0
	_cuerpo.add_child(_forma)
	var malla := BoxMesh.new()
	malla.size = Vector3(ANCHO, 0.28, 0.08)
	for i in MAX_TABLAS:
		var tabla := MeshInstance3D.new()
		tabla.mesh = malla
		tabla.material_override = material
		tabla.position.y = 0.45 + i * 0.55
		tabla.rotation.z = 0.08 if i % 2 == 0 else -0.08
		add_child(tabla)
		_tablas.append(tabla)
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.position.y = ALTO + 0.5
	_aviso.pixel_size = 0.008
	_aviso.visible = false
	add_child(_aviso)
	_voz = AudioStreamPlayer3D.new()
	_voz.position.y = 1.0
	_voz.max_distance = 25.0
	add_child(_voz)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var zona := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	zona.shape = esfera
	zona.position.y = 1.0
	area.add_child(zona)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = true
			_actualizar())
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false
			_actualizar())
	_actualizar()


# Solo si de verdad se puede: si no, el boton tiene que seguir saltando
func is_player_inside() -> bool:
	return _player_inside and not llena() and _indice_tabla() >= 0


func interact() -> void:
	var indice := _indice_tabla()
	if indice < 0 or llena():
		return
	get_node("/root/Inventory").remove_item(indice)
	vida = mini(vida + VIDA_POR_TABLA, VIDA_POR_TABLA * MAX_TABLAS)
	_sonar("golpe")
	_actualizar()


func abierta() -> bool:
	return vida <= 0


func llena() -> bool:
	return vida >= VIDA_POR_TABLA * MAX_TABLAS


func recibir_golpe(dano: int) -> void:
	if abierta():
		return
	var antes := vida
	vida = maxi(vida - dano, 0)
	_sonar("golpe")
	if vida <= 0:
		rota.emit()
	elif antes > VIDA_POR_TABLA and vida <= VIDA_POR_TABLA:
		debil.emit()
	_actualizar()


func reiniciar() -> void:
	vida = 0
	_actualizar()


func _indice_tabla() -> int:
	var inventario := get_node("/root/Inventory")
	for i in inventario.get_item_count():
		if inventario.get_item(i) == TABLAS:
			return i
	return -1


func _actualizar() -> void:
	var cuantas := ceili(float(vida) / VIDA_POR_TABLA)
	for i in _tablas.size():
		_tablas[i].visible = i < cuantas
	_forma.set_deferred("disabled", abierta())
	_aviso.visible = _player_inside
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	if llena():
		_aviso.text = "Bien atrancada"
	elif _indice_tabla() >= 0:
		_aviso.text = "%s: poner tablas (%d/%d)" % [tecla, cuantas, MAX_TABLAS]
	else:
		_aviso.text = "Te faltan tablas (%d/%d)" % [cuantas, MAX_TABLAS]


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()
