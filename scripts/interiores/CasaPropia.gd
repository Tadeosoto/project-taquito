extends Node

# Entrada a la casa propia del personaje: una flecha amarilla frente a una casa del patio lleva
# a scenes/casa_personaje.tscn. A diferencia de los negocios (Interiores.gd: escenas fijas en
# primera persona) la casa se camina de verdad con el jugador. Se crea ALTURA m arriba de la
# flecha, como los interiores, para no estorbar en el patio, y se sale pisando la flecha de
# adentro, junto a la puerta.
# La casa es el lugar donde despiertas al desmayarte: no es de pelea. Adentro no hay enemigos
# (Zombis.espontaneos apagado; los que habia se quitan solos, por lejanos, en
# Zombis._quitar_lejanos) y el jugador queda sin armas, sin rodar, sin curarse y sin que nada
# lo lastime ni lo desmaye (Player.poner_sin_combate). Solo se camina, se salta y se sale.

const ALTURA := 500.0
const FUNDIDO := 0.35
# Que tan lejos de la flecha de la calle te deja al salir (su radio es 0.8 m)
const SALIDA_DISTANCIA := 2.2
# Dentro de la casa (scenes/casa_personaje.tscn; su puerta esta en la pared oeste, x = 0):
# donde apareces, ya adentro y mirando al este, y la flecha de salida
const ADENTRO := Vector3(2.2, 1.2, 3.11)
const PUERTA := Vector3(0.35, 0.0, 3.11)
const TEXTO_PUERTA := "Sal por la puerta"

@export var escena: PackedScene
@export var player_path: NodePath
@export var zombis_path: NodePath
# Flecha de la calle: donde esta, y el giro en y de modo que su +Z mire a la calle
@export var flecha_en := Vector3.ZERO
@export var calle_giro := 0.0
@export var nombre := "Mi casa"

var _player: Player
var _zombis: Zombis
var _area: Area3D
var _casa: Node3D
var _salida: Transform3D
var _espontaneos := true
var _ocupado := false
var _negro: ColorRect
var _letrero: Label


func _ready() -> void:
	_player = get_node(player_path) as Player
	_zombis = get_node_or_null(zombis_path) as Zombis
	_area = _marcador(flecha_en, calle_giro, _entrar)
	add_child(_area)
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	capa.add_child(_negro)
	_letrero = Label.new()
	_letrero.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_letrero.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.offset_top = 24.0
	_letrero.add_theme_color_override("font_color", MapPuntos.MARCADOR_COLOR)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.modulate.a = 0.0
	capa.add_child(_letrero)


# Un Area3D con su flecha amarilla (la de las tiendas) que llama a `al_pisar` cuando el jugador la pisa
func _marcador(lugar: Vector3, giro: float, al_pisar: Callable) -> Area3D:
	var area := Area3D.new()
	area.name = "Marcador"
	area.position = lugar
	area.rotation.y = giro
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			al_pisar.call())
	var flecha := MapPuntos.flecha()
	flecha.name = "Flecha"
	area.add_child(flecha)
	return area


func _physics_process(_delta: float) -> void:
	# Si te desmayas adentro, Supervivencia te saca de la casa por su cuenta: se limpia aqui
	if _casa and not _ocupado and _player.global_position.y < ALTURA - 50.0:
		_limpiar()


func _entrar() -> void:
	if _ocupado or _casa:
		return
	_ocupado = true
	_salida = _area.global_transform
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _fundir(1.0)
	_casa = escena.instantiate() as Node3D
	# El ambiente de la casa (su WorldEnvironment) se queda fuera: aqui manda el del patio
	var ambiente := _casa.get_node_or_null("Ambiente")
	if ambiente:
		ambiente.free()
	_casa.position = Vector3(flecha_en.x, ALTURA, flecha_en.z)
	add_child(_casa)
	_casa.add_child(_marcador(PUERTA, 0.0, _salir))
	_poner_jugador(_casa.global_position + ADENTRO, -PI / 2.0)
	_player.poner_sin_combate(true)
	if _zombis:
		_espontaneos = _zombis.espontaneos
		_zombis.espontaneos = false
	_afuera(false)
	await _fundir(0.0)
	_mostrar_letrero(nombre)
	_ocupado = false


func _salir() -> void:
	if _ocupado or _casa == null:
		return
	_ocupado = true
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _fundir(1.0)
	var calle := _salida.basis.z
	calle.y = 0.0
	calle = calle.normalized()
	_limpiar()
	# Frente a la flecha, mirando a la calle (el origen del jugador esta a 1 m del piso)
	_poner_jugador(_salida.origin + calle * SALIDA_DISTANCIA + Vector3.UP * 1.2, atan2(-calle.x, -calle.z))
	await _fundir(0.0)
	_ocupado = false


# Quita la casa y deja todo como estaba afuera
func _limpiar() -> void:
	_casa.queue_free()
	_casa = null
	_player.poner_sin_combate(false)
	if _zombis:
		_zombis.espontaneos = _espontaneos
	_afuera(true)


func _poner_jugador(donde: Vector3, giro: float) -> void:
	_player.global_position = donde
	_player.velocity = Vector3.ZERO
	_player.camera_pivot.global_rotation.y = giro
	_player.frijol.global_rotation.y = giro
	_player.process_mode = Node.PROCESS_MODE_INHERIT


# El dron y el panel de ayuda (lo mismo que esconden los interiores de los negocios)
func _afuera(visible_afuera: bool) -> void:
	var interiores := get_tree().get_first_node_in_group("interiores")
	if interiores:
		interiores.mostrar_afuera(visible_afuera)


func _fundir(alfa: float) -> void:
	var tween := create_tween()
	tween.tween_property(_negro, "modulate:a", alfa, FUNDIDO)
	await tween.finished


func _mostrar_letrero(texto: String) -> void:
	_letrero.text = "%s\n%s" % [texto, TEXTO_PUERTA]
	var tween := create_tween()
	tween.tween_property(_letrero, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(_letrero, "modulate:a", 0.0, 0.8)
