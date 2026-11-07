class_name BarraMadre
extends CanvasLayer
# La barra de la Madre del Carcamo, arriba al centro en Pixelify Sans (como la defensa del
# tinaco): su nombre, una barra de SACOS pedazos (lo que le queda a cada saco) con marcas donde
# cambia de fase, y abajo una delgada con cuantas crias quedan (EnjambreLombrices.biomasa).

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ANCHO := 300.0
const ALTO := 10.0
const ALTO_CRIAS := 3.0
const COLOR_SACO := Color(0.2, 1.0, 0.85)
const COLOR_VACIO := Color(0.08, 0.1, 0.1)
const COLOR_CRIAS := Color(0.75, 0.5, 0.45)

var madre: MadreCarcamo
var enjambre: EnjambreLombrices
var _titulo: Label
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
	_titulo = Label.new()
	_titulo.text = "LA MADRE DEL CÁRCAMO"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_color_override("font_color", Color(0.85, 1.0, 0.95))
	_titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_titulo.add_theme_constant_override("outline_size", 4)
	caja.add_child(_titulo)
	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(ANCHO, ALTO + ALTO_CRIAS + 4.0)
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
	visible = madre != null and is_instance_valid(madre) and madre.visible
	if not visible:
		return
	_barra.queue_redraw()
	var fase := enjambre.fase if enjambre else 1
	_fase.text = "Fase %d · sacos %d/%d · crías %d%%" % [fase, madre.quedan(), MadreCarcamo.SACOS,
		roundi(enjambre.biomasa() * 100.0) if enjambre else 0]


func _dibujar() -> void:
	var n := MadreCarcamo.SACOS
	var hueco := 2.0
	var cada := (ANCHO - hueco * (n - 1)) / n
	_barra.draw_rect(Rect2(-2, -2, ANCHO + 4, ALTO + 4), Color.BLACK)
	for k in n:
		var x := k * (cada + hueco)
		_barra.draw_rect(Rect2(x, 0, cada, ALTO), COLOR_VACIO)
		var lleno := clampf(madre.sacos[k] / MadreCarcamo.SACO_VIDA, 0.0, 1.0)
		_barra.draw_rect(Rect2(x, 0, cada * lleno, ALTO), COLOR_SACO)
		# Marca de fase cada dos sacos
		if k % 2 == 1 and k < n - 1:
			_barra.draw_rect(Rect2(x + cada, -3, hueco, ALTO + 6), Color(1.0, 0.3, 0.2))
	if enjambre:
		var y := ALTO + 3.0
		_barra.draw_rect(Rect2(0, y, ANCHO, ALTO_CRIAS), COLOR_VACIO)
		_barra.draw_rect(Rect2(0, y, ANCHO * enjambre.biomasa(), ALTO_CRIAS), COLOR_CRIAS)
