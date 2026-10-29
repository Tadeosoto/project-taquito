class_name TiendaUI
extends CanvasLayer

# Lo que se ve encima de un interior (docs/especificaciones.md 4.6): tu dinero arriba a
# la derecha y abajo la ficha del producto que gira en la Vitrina (nombre, efecto,
# descripcion y precio) con la ayuda de teclas. Lo crea Interior.activar().
# La pantalla es de 640x480 (stretch viewport), los tamanos estan pensados para eso.

const AMARILLO := Color(1.0, 0.85, 0.1)
const AGUA := Color(0.55, 0.85, 1.0)
const DIALOGO_Y := 225.0
const AYUDA := "Q/E cambiar  ·  Espacio comprar  ·  S/Esc salir"

var _pesos: Label
var _agua: Label
var _nombre: Label
var _precio: Label
var _efecto: Label
var _descripcion: Label
var _dialogo: Label
var _aviso_tween: Tween


func _ready() -> void:
	layer = 9
	# Dinero
	var dinero := VBoxContainer.new()
	dinero.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dinero.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dinero.offset_right = -14.0
	dinero.offset_top = 10.0
	dinero.alignment = BoxContainer.ALIGNMENT_END
	add_child(dinero)
	_pesos = _label(20, Color(0.75, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	_agua = _label(16, AGUA, HORIZONTAL_ALIGNMENT_RIGHT)
	dinero.add_child(_pesos)
	dinero.add_child(_agua)
	Cartera.cambio.connect(_dinero)
	_dinero()

	# Ficha del producto en una franja abajo
	var franja := PanelContainer.new()
	franja.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	franja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.05, 0.06, 0.82)
	fondo.border_width_top = 2
	fondo.border_color = AMARILLO.darkened(0.3)
	fondo.content_margin_left = 16.0
	fondo.content_margin_right = 16.0
	fondo.content_margin_top = 8.0
	fondo.content_margin_bottom = 8.0
	franja.add_theme_stylebox_override("panel", fondo)
	add_child(franja)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	franja.add_child(columna)
	var renglon := HBoxContainer.new()
	columna.add_child(renglon)
	_nombre = _label(22, AMARILLO)
	_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renglon.add_child(_nombre)
	_precio = _label(22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	renglon.add_child(_precio)
	_efecto = _label(15, Color.WHITE)
	_efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_efecto)
	_descripcion = _label(13, Color(0.7, 0.7, 0.72))
	_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_descripcion)
	var ayuda := _label(12, Color(0.6, 0.6, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	ayuda.text = AYUDA
	columna.add_child(ayuda)

	# Lo que dice el que atiende, como subtitulo debajo de su cara (el producto flota mas
	# abajo, frente al mostrador)
	_dialogo = _label(16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_dialogo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_dialogo.offset_top = DIALOGO_Y
	_dialogo.modulate.a = 0.0
	add_child(_dialogo)


func _label(tamano: int, color: Color, alineado := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alineado
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


# `factor` sube o baja los precios en pesos de esa tienda (el OXO mas caro)
func mostrar(producto: InventoryItemData, factor := 1.0) -> void:
	if producto == null:
		_nombre.text = ""
		_precio.text = ""
		_efecto.text = ""
		_descripcion.text = ""
		return
	_nombre.text = producto.item_name.to_upper()
	_efecto.text = producto.efecto
	_descripcion.text = producto.description
	if producto.moneda == 1:
		_precio.text = "%d AGUA" % producto.precio
		_precio.add_theme_color_override("font_color", AGUA)
	else:
		_precio.text = "$%d" % roundi(producto.precio * factor)
		_precio.add_theme_color_override("font_color", Color.WHITE)


# Texto que se desvanece solo (lo que dice el vendedor, avisos)
func decir(texto: String, segundos := 3.0) -> void:
	_dialogo.text = texto
	_dialogo.modulate.a = 1.0
	if _aviso_tween:
		_aviso_tween.kill()
	_aviso_tween = create_tween()
	_aviso_tween.tween_interval(segundos)
	_aviso_tween.tween_property(_dialogo, "modulate:a", 0.0, 0.8)


func _dinero() -> void:
	_pesos.text = "$%d" % Cartera.pesos
	_agua.text = "AGUA %d" % Cartera.agua
