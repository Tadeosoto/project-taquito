extends Control

# Lanzador de los dos tests: Mecanicas (godmode) y Economia (carrera). Se abre desde Inicio >
# Pruebas; no hay que escribir comandos. Muestra la config de enemigos, la dificultad, la
# duracion y la carpeta de datos (que se puede abrir).

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const AMARILLO := Color(1.0, 0.85, 0.1)
const VERDE := Color(0.6, 1.0, 0.6)

var _pruebas: Node
var _dificultad := 1                      # 0 facil, 1 medio, 2 dificil
var _dificultades := ["facil", "medio", "dificil"]
var _duraciones := [210.0, 120.0, 60.0]
var _duracion := 0
var _etiqueta_dif: Button
var _etiqueta_dur: Button
var _etiqueta_datos: Label
var _foco := 0
var _botones: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pruebas = get_node_or_null("/root/Pruebas")
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.035, 0.05)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := VBoxContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 8)
	add_child(centro)
	var titulo := _label("PRUEBAS", 30, AMARILLO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(titulo)
	centro.add_child(_label("Los datos se guardan solos para ajustar el balance.", 12, Color(0.7, 0.7, 0.7)))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 18)
	centro.add_child(fila)
	var boton_dif := _boton("Dificultad: Medio", func() -> void:
		_dificultad = wrapi(_dificultad + 1, 0, _dificultades.size())
		_actualizar())
	_etiqueta_dif = boton_dif
	fila.add_child(boton_dif)
	var boton_dur := _boton("Duración: 3:30", func() -> void:
		_duracion = wrapi(_duracion + 1, 0, _duraciones.size())
		_actualizar())
	_etiqueta_dur = boton_dur
	fila.add_child(boton_dur)
	centro.add_child(_label(_texto_enemigos(), 12, Color(0.8, 0.8, 0.8)))
	centro.add_child(_label("El godmode es la misma defensa con todo al máximo e ítems infinitos.", 11, Color(0.65, 0.65, 0.7)))
	centro.add_child(_label("La carrera empieza en el refugio con todas las tiendas y el punto de mejoras.", 11, Color(0.65, 0.65, 0.7)))
	var mecanicas := _boton("MECÁNICAS (godmode)", func() -> void: _empezar(2))
	centro.add_child(mecanicas)
	var economia := _boton("ECONOMÍA (carrera)", func() -> void: _empezar(1))
	centro.add_child(economia)
	_etiqueta_datos = _label("", 10, Color(0.6, 0.6, 0.65))
	centro.add_child(_etiqueta_datos)
	var abrir := _boton("Abrir carpeta de datos", func() -> void:
		if _pruebas:
			OS.shell_open(ProjectSettings.globalize_path(_pruebas.carpeta_actual())))
	centro.add_child(abrir)
	var volver := _boton("Volver", func() -> void: get_tree().change_scene_to_file("res://scenes/inicio.tscn"))
	centro.add_child(volver)
	_botones = [boton_dif, boton_dur, mecanicas, economia, abrir, volver]
	_botones[0].grab_focus()
	_actualizar()


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


func _boton(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.theme = TEMA
	boton.custom_minimum_size = Vector2(320.0, 30.0)
	boton.pressed.connect(accion)
	return boton


func _texto_enemigos() -> String:
	var config := load("res://resources/zombis/balance_enemigos.tres")
	if config and config.has_method("texto"):
		return "ENEMIGOS: " + config.texto()
	return ""


func _actualizar() -> void:
	_etiqueta_dif.text = "Dificultad: " + _dificultades[_dificultad].capitalize()
	_etiqueta_dur.text = "Duración: %d:%02d" % [int(_duraciones[_duracion]) / 60, int(_duraciones[_duracion]) % 60]
	if _pruebas:
		_etiqueta_datos.text = "Datos: " + _pruebas.carpeta_actual()


func _empezar(modo: int) -> void:
	if _pruebas == null:
		return
	if modo == 2:
		_pruebas.preparar_godmode(_dificultades[_dificultad], _duraciones[_duracion])
		get_tree().change_scene_to_file("res://scenes/defensa_tinaco.tscn")
	else:
		_pruebas.preparar_carrera(_dificultades[_dificultad], _duraciones[_duracion])
		get_tree().change_scene_to_file("res://scenes/escena_carrera.tscn")
