extends Node

# Entrar y salir de los negocios (docs/especificaciones.md 4.6). Al pisar la flecha
# amarilla de una tienda (MapPuntos.entrar_negocio): pantalla negra y se ve la escena
# fija del interior de su giro (Interior.gd) con su camara, en primera persona, y su
# tienda (lo que vende dando vueltas, TiendaUI). Con S/abajo o Esc vuelves a la calle,
# frente a la puerta.
# El interior se crea `ALTURA` m arriba del negocio y no en otro lado, para que el
# mapa siga cargado alrededor (MapStreamer mide en x/z) y el deterioro de las paredes
# sea el de esa zona.
# En los puestos al aire libre (tacos, tejuino) no hay pantalla negra: la
# camara se acerca al que atiende ahi mismo, desde donde estas parado, y se aleja al salir.

const ALTURA := 500.0
const FUNDIDO := 0.35
# Que tan lejos de la flecha de la calle te deja al salir (su radio es 0.8 m)
const SALIDA_DISTANCIA := 2.2
const TEXTO_SALIR := "S / Esc: salir"
const ZOOM_TIEMPO := 0.7
const ZOOM_FOV := 38.0
# Ojos del cliente parado en la flecha y altura de la cara del que atiende (m); a la
# altura de la cara para ver por debajo de los letreros colgados de los carritos
const ZOOM_OJOS := 1.45
const ZOOM_CARA := 1.35
# Nunca mas cerca de la cara que esto (en el punto el vendedor esta junto a la flecha)
const ZOOM_DISTANCIA_MIN := 2.6

# giro -> escena del interior (scenes/interiores/); sin escena se avisa "Proximamente"
@export var escenas: Dictionary[String, PackedScene] = {}
@export var puntos_path: NodePath
@export var player_path: NodePath
# Se apaga adentro (con V volarias desde el interior)
@export var dron_path: NodePath
# Nodos que se esconden adentro (el minimapa)
@export var ocultar: Array[NodePath] = []

var _puntos: MapPuntos
var _player: Player
var _interior: Interior
var _salida: Transform3D
var _ocupado := false
var _negro: ColorRect
var _letrero: Label
var _dialogo: Label
# Zoom a un puesto: camara propia mientras dura, y la flecha (se esconde: tapaba al
# del punto, que esta junto a ella)
var _zoom: Camera3D
var _flecha: Node3D


func _ready() -> void:
	_puntos = get_node(puntos_path) as MapPuntos
	_player = get_node(player_path) as Player
	_puntos.entrar_negocio.connect(_entrar)
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	_dialogo = _label(Control.PRESET_CENTER_BOTTOM, Color.WHITE)
	_dialogo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialogo.offset_bottom = -28.0
	capa.add_child(_dialogo)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	capa.add_child(_negro)
	_letrero = _label(Control.PRESET_CENTER_TOP, MapPuntos.MARCADOR_COLOR)
	_letrero.offset_top = 24.0
	capa.add_child(_letrero)


func _label(preset: Control.LayoutPreset, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	return label


func _unhandled_input(event: InputEvent) -> void:
	if (_interior == null and _zoom == null) or _ocupado:
		return
	if event.is_action_pressed("move_backward") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _zoom:
			_alejar()
		else:
			_salir()


func _entrar(_tipo: String, giro: String, nombre: String, aire_libre: bool, marcador: Node3D) -> void:
	if _ocupado or _interior or _zoom:
		return
	# Con escena se entra aunque sea al aire libre (el punto te mete a su cuarto)
	var escena: PackedScene = escenas.get(giro)
	var vendedor := marcador.get_node_or_null("Vendedor") as Node3D
	if escena == null and vendedor:
		_acercar(marcador, vendedor, nombre)
		return
	var salida := marcador.global_transform
	if escena == null:
		_puntos.avisar("%s: Próximamente" % nombre)
		return
	_ocupado = true
	_salida = salida
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _fundir(1.0)
	_interior = escena.instantiate() as Interior
	_interior.nombre = nombre
	_interior.position = Vector3(salida.origin.x, ALTURA, salida.origin.z)
	add_child(_interior)
	_interior.camara().make_current()
	_interior.activar()
	_mostrar(false)
	await _fundir(0.0)
	_mostrar_letrero(nombre)
	_ocupado = false


func _salir() -> void:
	_ocupado = true
	await _fundir(1.0)
	_interior.queue_free()
	_interior = null
	var afuera := _salida.basis.z
	afuera.y = 0.0
	afuera = afuera.normalized()
	# El origen del jugador esta a 1 m del piso (su capsula mide 2 m)
	_player.global_position = _salida.origin + afuera * SALIDA_DISTANCIA + Vector3.UP * 1.2
	_player.velocity = Vector3.ZERO
	var giro := atan2(-afuera.x, -afuera.z)
	_player.camera_pivot.global_rotation.y = giro
	_player.frijol.global_rotation.y = giro
	(_player.find_child("Camera3D", true, false) as Camera3D).make_current()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_mostrar(true)
	await _fundir(0.0)
	_ocupado = false


# Del lugar de la camara del jugador a la cara del que atiende, cerrando el angulo
func _acercar(marcador: Node3D, vendedor: Node3D, nombre: String) -> void:
	_ocupado = true
	# Solo se pausa: con process_mode el cuerpo sale del mundo fisico y al volver la
	# flecha lo detecta otra vez (y te vuelve a acercar)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	var camara := get_viewport().get_camera_3d()
	_zoom = Camera3D.new()
	add_child(_zoom)
	_zoom.global_transform = camara.global_transform
	_zoom.fov = camara.fov
	_zoom.make_current()
	# Desde la flecha (donde estas parado), un poco hacia la calle
	var calle := marcador.global_basis.z
	calle.y = 0.0
	calle = calle.normalized()
	var lejos := maxf((marcador.global_position - vendedor.global_position).dot(calle) + 0.4, ZOOM_DISTANCIA_MIN)
	var ojos := vendedor.global_position + calle * lejos + Vector3.UP * ZOOM_OJOS
	var cara := vendedor.global_position + Vector3.UP * ZOOM_CARA
	var destino := Transform3D(Basis.looking_at(cara - ojos), ojos)
	# Todo el jugador (su Pointer tambien quedaba frente a la camara)
	_player.visible = false
	for hijo in marcador.get_children():
		if hijo is MeshInstance3D:
			_flecha = hijo
			_flecha.visible = false
	_mostrar(false)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_zoom, "global_transform", destino, ZOOM_TIEMPO)
	tween.tween_property(_zoom, "fov", ZOOM_FOV, ZOOM_TIEMPO)
	await tween.finished
	_dialogo.text = "%s\n%s" % [String(vendedor.get("dialogue")), TEXTO_SALIR]
	_dialogo.modulate.a = 1.0
	_mostrar_letrero(nombre)
	_ocupado = false


func _alejar() -> void:
	_ocupado = true
	_dialogo.modulate.a = 0.0
	var camara := _player.find_child("Camera3D", true, false) as Camera3D
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_zoom, "global_transform", camara.global_transform, ZOOM_TIEMPO)
	tween.tween_property(_zoom, "fov", camara.fov, ZOOM_TIEMPO)
	await tween.finished
	camara.make_current()
	_zoom.queue_free()
	_zoom = null
	_player.visible = true
	if is_instance_valid(_flecha):
		_flecha.visible = true
	_flecha = null
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	_mostrar(true)
	_ocupado = false


func _mostrar(visible_afuera: bool) -> void:
	var dron := get_node_or_null(dron_path)
	if dron:
		dron.process_mode = Node.PROCESS_MODE_INHERIT if visible_afuera else Node.PROCESS_MODE_DISABLED
	for ruta in ocultar:
		var nodo := get_node_or_null(ruta)
		if nodo and "visible" in nodo:
			nodo.visible = visible_afuera


func _fundir(alfa: float) -> void:
	var tween := create_tween()
	tween.tween_property(_negro, "modulate:a", alfa, FUNDIDO)
	await tween.finished


func _mostrar_letrero(texto: String) -> void:
	_letrero.text = texto
	var tween := create_tween()
	tween.tween_property(_letrero, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(_letrero, "modulate:a", 0.0, 0.8)
