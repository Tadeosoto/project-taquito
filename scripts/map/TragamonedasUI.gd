class_name TragamonedasUI
extends CanvasLayer

# Jugar en una maquinita (Maquinita.gd): la camara se acerca y se juega con la maquina,
# con sus botones y contadores; en pantalla solo la ayuda y un aviso. Las monedas son
# pesos de la Cartera y se regresan si te vas sin tirar. Pantalla de 640x480.

const AMARILLO := Color(1.0, 0.85, 0.1)
const AYUDA := "←/→ fruta  ·  ↑ apostar  ·  ↓ quitar  ·  Espacio tirar  ·  S/Esc salir"
const MAX_POR_FRUTA := 9
const TIEMPO_CAMARA := 0.6
# Camara de cerca, respecto a la maquinita (m): del nombre a los botones
const OJOS := Vector3(0.0, 1.56, 1.68)
const MIRA := Vector3(0.0, 1.42, 0.05)
const FOV := 40.0
# Si el premio vale la pena la camara se aleja a ver los cohetes: de cerca no se ve el cielo
const PREMIO_CAMARA := 10
const CAMARA_COHETES := 3.0

var maquinita: Maquinita

var _apuestas := {}
var _elegida := 0
var _ocupado := true
var _player: Player
var _camara: Camera3D
var _camara_jugador: Camera3D
var _aviso: Label


func _ready() -> void:
	layer = 9
	_player = get_tree().get_first_node_in_group("jugador") as Player
	_armar_pantalla()
	Cartera.cambio.connect(_contadores)
	_contadores()
	maquinita.elegir_boton(_elegida)
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.anochecio.connect(_echar)
	_entrar()


# Anochecio jugando: termina el tiro que va y a la calle
func _echar() -> void:
	while _ocupado:
		await get_tree().process_frame
	_salir()


func _exit_tree() -> void:
	if Cartera.cambio.is_connected(_contadores):
		Cartera.cambio.disconnect(_contadores)


func _unhandled_input(event: InputEvent) -> void:
	if _ocupado:
		return
	if event.is_action_pressed("inspect_down"):
		maquinita.apretar_boton(Maquinita.BOTON_QUITAR)
		_apostar(-1)
	elif event.is_action_pressed("inspect_up"):
		maquinita.apretar_boton(_elegida)
		_apostar(1)
	elif event.is_action_pressed("inventory_previous") or event.is_action_pressed("move_left"):
		_elegir(-1)
	elif event.is_action_pressed("inventory_next") or event.is_action_pressed("move_right"):
		_elegir(1)
	elif event.is_action_pressed("jump"):
		maquinita.apretar_boton(Maquinita.BOTON_TIRAR)
		_tirar()
	elif event.is_action_pressed("move_backward") or event.is_action_pressed("ui_cancel"):
		maquinita.apretar_boton(Maquinita.BOTON_SALIR)
		_salir()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Apostar y tirar ---

func _elegir(paso: int) -> void:
	_elegida = wrapi(_elegida + paso, 0, Tragamonedas.FRUTAS.size())
	maquinita.elegir_boton(_elegida)


func _apostar(paso: int) -> void:
	var fruta: String = Tragamonedas.FRUTAS[_elegida]
	var actual: int = _apuestas.get(fruta, 0)
	if paso > 0:
		if actual >= MAX_POR_FRUTA:
			return
		if Cartera.pesos <= 0:
			_decir("No traes dinero.")
			return
	elif actual == 0:
		return
	Cartera.pesos -= paso
	_apuestas[fruta] = actual + paso
	maquinita.mostrar_apuestas(_apuestas)


func _total() -> int:
	var total := 0
	for fruta: String in _apuestas:
		total += _apuestas[fruta]
	return total


func _tirar() -> void:
	var total := _total()
	if total == 0:
		_decir("Primero apuéstale a una fruta.")
		return
	_ocupado = true
	_decir("")
	maquinita.elegir_boton(-1)
	var resultado := maquinita.placa.girar(_apuestas)
	maquinita.mostrar_giro(resultado["destino"])
	await maquinita.giro_terminado
	var premio: int = resultado["premio"]
	# Ganar es sacar mas de lo que metiste: con una moneda a cada fruta siempre cae algo
	var gano := premio > total
	Cartera.pesos += premio
	_apuestas.clear()
	maquinita.mostrar_apuestas(_apuestas)
	if gano:
		_decir("¡Ganaste $%d!" % premio)
	elif premio > 0:
		_decir("Te regresa $%d." % premio)
	else:
		_decir("Casi. Otra vez será.")
	# Sin await: los cohetes salen ya y la camara tiene que irse con ellos
	maquinita.mostrar_premio(premio, gano, _cohetes(gano, resultado["fruta"], premio))
	# Ya se ve como quedo: se acabo la veladora, o se lleno o se vacio la caja
	maquinita.mostrar_estado(maquinita.placa.estado())
	if gano and premio >= PREMIO_CAMARA:
		await _ver_cohetes()
	while maquinita.mostrando_premio:
		await get_tree().process_frame
	maquinita.elegir_boton(_elegida)
	_ocupado = false


# Uno por lo menos, hasta 8 con los premios grandes
func _cohetes(gano: bool, fruta: String, premio: int) -> int:
	if not gano:
		return 0
	if fruta in ["BAR", "SIETE"]:
		return 8
	return clampi(premio / 10 + 1, 1, 6)


func _ver_cohetes() -> void:
	var regreso := _camara.global_transform
	var fov := _camara.fov
	var lejos := maquinita.global_transform * Vector3(0.0, 1.5, 9.0)
	var cielo := maquinita.global_transform * Vector3(0.0, 26.0, 1.0)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", Transform3D(Basis.looking_at(cielo - lejos), lejos), 0.8)
	tween.tween_property(_camara, "fov", 70.0, 0.8)
	await tween.finished
	await get_tree().create_timer(CAMARA_COHETES).timeout
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", regreso, 0.8)
	tween.tween_property(_camara, "fov", fov, 0.8)
	await tween.finished


# --- Entrar y salir: igual que el acercamiento de los puestos (Interiores._acercar) ---

func _entrar() -> void:
	# Solo se pausa: con process_mode el cuerpo sale del mundo fisico y al volver las
	# areas lo detectan otra vez
	if _player:
		_player.set_physics_process(false)
		_player.set_process_unhandled_input(false)
		_player.visible = false
	_mostrar_afuera(false)
	_camara_jugador = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	get_tree().current_scene.add_child(_camara)
	if _camara_jugador:
		_camara.global_transform = _camara_jugador.global_transform
		_camara.fov = _camara_jugador.fov
	_camara.make_current()
	var ojos := maquinita.global_transform * OJOS
	var mira := maquinita.global_transform * MIRA
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", Transform3D(Basis.looking_at(mira - ojos), ojos), TIEMPO_CAMARA)
	tween.tween_property(_camara, "fov", FOV, TIEMPO_CAMARA)
	await tween.finished
	_ocupado = false


func _salir() -> void:
	_ocupado = true
	# Lo que no se tiro se regresa
	Cartera.pesos += _total()
	_apuestas.clear()
	maquinita.descansar()
	if _camara_jugador:
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_camara, "global_transform", _camara_jugador.global_transform, TIEMPO_CAMARA)
		tween.tween_property(_camara, "fov", _camara_jugador.fov, TIEMPO_CAMARA)
		await tween.finished
		_camara_jugador.make_current()
	_camara.queue_free()
	if _player:
		_player.visible = true
		_player.set_physics_process(true)
		_player.set_process_unhandled_input(true)
	_mostrar_afuera(true)
	queue_free()


func _mostrar_afuera(si: bool) -> void:
	var interiores := get_tree().get_first_node_in_group("interiores")
	if interiores:
		interiores.mostrar_afuera(si)


# --- Pantalla: lo demas se lee en la maquina ---

func _armar_pantalla() -> void:
	var columna := VBoxContainer.new()
	columna.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	columna.offset_bottom = -6.0
	add_child(columna)
	_aviso = _label(18, AMARILLO)
	columna.add_child(_aviso)
	var ayuda := _label(12, Color(0.85, 0.85, 0.87))
	ayuda.text = AYUDA
	columna.add_child(ayuda)


# CREDITOS es tu dinero: se ve bajar al apostar y subir al ganar
func _contadores() -> void:
	maquinita.mostrar_contador_creditos(Cartera.pesos)


func _decir(texto: String) -> void:
	_aviso.text = texto


func _label(tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
