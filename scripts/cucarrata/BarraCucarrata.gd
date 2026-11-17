class_name BarraCucarrata
extends CanvasLayer
# La barra de la cucarrata, arriba al centro como la de la Madre (BarraMadre): su nombre, la vida
# con marcas en los tercios (donde cambia de fase) y la fase.

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ANCHO := 300.0
const ALTO := 10.0
const COLOR_VIDA := Color(0.18, 0.77, 1.0)   # el azul Serenol de las grietas
const COLOR_VACIO := Color(0.08, 0.1, 0.12)
const FASES := ["", "camina y muerde", "pare crías", "vuela: túmbala a balazos y dale machete"]

var jefe: JefeCucarrata
var _barra: Control
var _fase: Label


func _ready() -> void:
	layer = 6
	var caja := VBoxContainer.new()
	caja.theme = TEMA
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caja.position = Vector2(-ANCHO / 2.0, 8.0)
	caja.custom_minimum_size.x = ANCHO
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	var titulo := Label.new()
	titulo.text = "LA CUCARRATA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 4)
	caja.add_child(titulo)
	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(ANCHO, ALTO + 4.0)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar)
	caja.add_child(_barra)
	_fase = Label.new()
	_fase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fase.add_theme_font_size_override("font_size", 10)
	_fase.add_theme_color_override("font_outline_color", Color.BLACK)
	_fase.add_theme_constant_override("outline_size", 3)
	caja.add_child(_fase)


func _process(_delta: float) -> void:
	visible = jefe != null and is_instance_valid(jefe) and jefe.vida > 0.0
	if not visible:
		return
	_barra.queue_redraw()
	_fase.text = "Fase %d · %s" % [jefe.fase, FASES[jefe.fase]]


func _dibujar() -> void:
	_barra.draw_rect(Rect2(-2, -2, ANCHO + 4, ALTO + 4), Color.BLACK)
	_barra.draw_rect(Rect2(0, 0, ANCHO, ALTO), COLOR_VACIO)
	_barra.draw_rect(Rect2(0, 0, ANCHO * jefe.vida / JefeCucarrata.VIDA, ALTO), COLOR_VIDA)
	for k in [1, 2]:
		_barra.draw_rect(Rect2(ANCHO * k / 3.0 - 1.0, -3, 2, ALTO + 6), Color(1.0, 0.3, 0.2))
