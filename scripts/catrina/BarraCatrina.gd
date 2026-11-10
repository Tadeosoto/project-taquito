class_name BarraCatrina
extends CanvasLayer
# La barra de La Mojiganga (Catrina.gd), arriba al centro en Pixelify Sans como la de la Madre
# (BarraMadre.gd): su nombre, una barra de vida con marcas donde cambia de fase, y abajo las
# flores que le quedan, que tan seca esta y cuantas partes se le quemaron.

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ANCHO := 300.0
const ALTO := 10.0
const COLOR_VIDA := Color(0.75, 0.3, 0.85)
const COLOR_VACIO := Color(0.1, 0.06, 0.12)
const COLOR_MARCA := Color(1.0, 0.6, 0.2)

var catrina: Catrina
var _barra: Control
var _abajo: Label


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
	titulo.text = "LA MOJIGANGA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95))
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 4)
	caja.add_child(titulo)
	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(ANCHO, ALTO + 2.0)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar)
	caja.add_child(_barra)
	_abajo = Label.new()
	_abajo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_abajo.add_theme_font_size_override("font_size", 10)
	_abajo.add_theme_color_override("font_outline_color", Color.BLACK)
	_abajo.add_theme_constant_override("outline_size", 3)
	caja.add_child(_abajo)


func _process(_delta: float) -> void:
	visible = catrina != null and is_instance_valid(catrina) and not catrina.dormida and catrina.vida() > 0
	if not visible:
		return
	_barra.queue_redraw()
	var seca := 0.0
	for parte in catrina.humedad:
		seca += 1.0 - clampf(catrina.humedad[parte], 0.0, 1.0)
	seca /= catrina.humedad.size()
	var partes: Array[String] = ["Fase %d" % catrina.fase]
	if catrina.fase < 3:
		partes.append("flores %d/%d" % [catrina.flores_vivas(), Catrina.FLORES])
	else:
		partes.append("¡el nudo!")
	partes.append("seca %d%%" % roundi(seca * 100.0))
	if catrina.quemadas() > 0:
		partes.append("quemada x%d" % catrina.quemadas())
	_abajo.text = " · ".join(partes)


func _dibujar() -> void:
	_barra.draw_rect(Rect2(-2, -2, ANCHO + 4, ALTO + 4), Color.BLACK)
	_barra.draw_rect(Rect2(0, 0, ANCHO, ALTO), COLOR_VACIO)
	var lleno := clampf(float(catrina.vida()) / Catrina.VIDA, 0.0, 1.0)
	_barra.draw_rect(Rect2(0, 0, ANCHO * lleno, ALTO), COLOR_VIDA)
	for borde in [Catrina.FASE_2, Catrina.FASE_3]:
		var x := ANCHO * float(borde) / Catrina.VIDA
		_barra.draw_rect(Rect2(x - 1.0, -3, 2.0, ALTO + 6), COLOR_MARCA)
