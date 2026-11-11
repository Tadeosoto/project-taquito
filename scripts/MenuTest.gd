extends Control

# Menu principal alternativo para probar rapido: Map test, Mecanicas (godmode) y Economia
# (carrera). Las tres opciones se ven de una. Se abre desde Inicio > Menu test; los tests
# largos siguen teniendo su lanzador en Inicio > Pruebas (dificultad, duracion, carpeta).
# Map test carga el mapa completo con el personaje guardado, igual que Jugar pero sin creador.

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const AMARILLO := Color(1.0, 0.85, 0.1)
const VERDE := Color(0.6, 1.0, 0.6)
const GRIS := Color(0.7, 0.7, 0.72)
const MAPA := "res://scenes/map_test.tscn"
const DEFENSA := "res://scenes/defensa_tinaco.tscn"
const CARRERA := "res://scenes/escena_carrera.tscn"

var _pruebas: Node
var _dificultad := 1
var _dificultades := ["facil", "medio", "dificil"]
var _duraciones := [210.0, 120.0, 60.0]
var _duracion := 0
var _boton_dif: Button
var _boton_dur: Button
var _datos: Label
var _cargando: ColorRect


func _ready() -> void:
	_pruebas = get_node_or_null("/root/Pruebas")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.035, 0.05)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := VBoxContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 7)
	add_child(centro)
	var titulo := _label("MENÚ DE PRUEBAS", 30, AMARILLO)
	centro.add_child(titulo)
	centro.add_child(_label("Mapa, mecánicas o economía. Sin escribir comandos.", 12, GRIS))
	centro.add_child(_espacio(4))
	var mapa := _boton("MAP TEST\nEl mapa completo con tu personaje guardado", _map_test)
	centro.add_child(mapa)
	var mecanicas := _boton("TEST DE MECÁNICAS (GODMODE)\nLa defensa con todo al máximo e ítems infinitos", _mecanicas)
	centro.add_child(mecanicas)
	var economia := _boton("TEST DE ECONOMÍA (CARRERA)\nRefugio, tiendas, punto de mejoras y noches encadenadas", _economia)
	centro.add_child(economia)
	centro.add_child(_espacio(2))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	centro.add_child(fila)
	_boton_dif = _boton("Dificultad: Medio", _ciclar_dificultad)
	_boton_dif.custom_minimum_size = Vector2(170.0, 28.0)
	fila.add_child(_boton_dif)
	_boton_dur = _boton("Duración: 3:30", _ciclar_duracion)
	_boton_dur.custom_minimum_size = Vector2(160.0, 28.0)
	fila.add_child(_boton_dur)
	centro.add_child(_espacio(2))
	_datos = _label("", 10, Color(0.6, 0.6, 0.65))
	centro.add_child(_datos)
	var abrir := _boton("Abrir carpeta de datos", _abrir_carpeta)
	abrir.custom_minimum_size = Vector2(260.0, 26.0)
	centro.add_child(abrir)
	var volver := _boton("Volver al menú", _volver)
	volver.custom_minimum_size = Vector2(260.0, 26.0)
	centro.add_child(volver)
	_actualizar()
	mapa.grab_focus()
	# Capa de "Cargando..." encima (el mapa tarda en abrir y el frame se congela)
	_cargando = ColorRect.new()
	_cargando.color = Color.BLACK
	_cargando.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cargando.mouse_filter = Control.MOUSE_FILTER_STOP
	_cargando.visible = false
	add_child(_cargando)
	var texto := Label.new()
	texto.text = "Cargando..."
	texto.add_theme_font_size_override("font_size", 24)
	texto.add_theme_color_override("font_color", AMARILLO)
	texto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	texto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	texto.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cargando.add_child(texto)


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_override("font", TEMA.default_font)
	return label


func _espacio(alto: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size.y = alto
	return control


func _boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.theme = TEMA
	boton.custom_minimum_size = Vector2(420.0, 46.0)
	boton.add_theme_font_size_override("font_size", 16)
	boton.pressed.connect(accion)
	return boton


func _actualizar() -> void:
	if _boton_dif:
		_boton_dif.text = "Dificultad: " + String(_dificultades[_dificultad]).capitalize()
	if _boton_dur:
		_boton_dur.text = "Duración: %d:%02d" % [int(_duraciones[_duracion]) / 60, int(_duraciones[_duracion]) % 60]
	if _datos and _pruebas:
		_datos.text = "Datos: " + _pruebas.carpeta_actual()


func _ciclar_dificultad() -> void:
	_dificultad = wrapi(_dificultad + 1, 0, _dificultades.size())
	_actualizar()


func _ciclar_duracion() -> void:
	_duracion = wrapi(_duracion + 1, 0, _duraciones.size())
	_actualizar()


func _map_test() -> void:
	if _pruebas and _pruebas.modo != 0:
		_pruebas.cerrar()
	await _cargar(MAPA)


func _mecanicas() -> void:
	if _pruebas:
		_pruebas.preparar_godmode(_dificultades[_dificultad], _duraciones[_duracion])
	await _cargar(DEFENSA)


func _economia() -> void:
	if _pruebas:
		_pruebas.preparar_carrera(_dificultades[_dificultad], _duraciones[_duracion])
	await _cargar(CARRERA)


func _abrir_carpeta() -> void:
	if _pruebas:
		OS.shell_open(ProjectSettings.globalize_path(_pruebas.carpeta_actual()))


func _volver() -> void:
	get_tree().change_scene_to_file("res://scenes/inicio.tscn")


func _cargar(ruta: String) -> void:
	if _cargando:
		_cargando.visible = true
	await get_tree().process_frame
	get_tree().change_scene_to_file(ruta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_volver()
