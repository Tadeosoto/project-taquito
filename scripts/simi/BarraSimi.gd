class_name BarraSimi
extends CanvasLayer
# La barra del Simi bailador, arriba al centro como la del pterodactilo: nombre, vida con la marca de
# la mitad (ahi se le cae la bata), cuantos zombis tiene bailando de los que junta, y abajo, mientras
# bailas, la barra para zafarte (con la marca del tope hasta que te peguen).

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ANCHO := 300.0
const ALTO := 10.0
const COLOR_VIDA := Color(0.3, 0.75, 1.0)
const COLOR_VACIO := Color(0.06, 0.08, 0.12)
const COLOR_ZAFARSE := Color(1.0, 0.85, 0.3)

var jefe: JefeSimi
var _arriba: Control
var _barra: Control
var _cuenta: Label
var _abajo: Control
var _zafarse: Control


func _ready() -> void:
	layer = 6
	_arriba = VBoxContainer.new()
	_arriba.theme = TEMA
	_arriba.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_arriba.position = Vector2(-ANCHO / 2.0, 8.0)
	_arriba.custom_minimum_size.x = ANCHO
	_arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arriba)
	_arriba.add_child(_etiqueta("EL SIMI BAILADOR", 0, Color(0.85, 0.97, 1.0)))
	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(ANCHO, ALTO + 4.0)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_dibujar_vida)
	_arriba.add_child(_barra)
	_cuenta = _etiqueta("", 10, Color.WHITE)
	_arriba.add_child(_cuenta)
	# Abajo al centro: zafarse del baile
	var caja := VBoxContainer.new()
	caja.theme = TEMA
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caja.position = Vector2(-ANCHO / 2.0, -96.0)
	caja.custom_minimum_size.x = ANCHO
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	_abajo = caja
	caja.add_child(_etiqueta("¡TE AGARRÓ EL BAILE!", 0, COLOR_ZAFARSE))
	caja.add_child(_etiqueta("machaca golpe o brinco para zafarte", 10, Color.WHITE))
	_zafarse = Control.new()
	_zafarse.custom_minimum_size = Vector2(ANCHO, ALTO + 4.0)
	_zafarse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zafarse.draw.connect(_dibujar_zafarse)
	caja.add_child(_zafarse)


func _etiqueta(texto: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if tam > 0:
		l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4 if tam == 0 else 3)
	return l


func _process(_delta: float) -> void:
	var hay := jefe != null and is_instance_valid(jefe) and jefe.vida > 0.0 and jefe.activa
	_arriba.visible = hay
	_abajo.visible = hay and jefe.jugador_bailando()
	if not hay:
		return
	_barra.queue_redraw()
	_cuenta.text = "Bailando con él: %d/%d" % [jefe.bailando_cuantos(), jefe.junta()]
	if _abajo.visible:
		_zafarse.queue_redraw()


func _dibujar_vida() -> void:
	if not is_instance_valid(jefe):
		return
	_barra.draw_rect(Rect2(-2, -2, ANCHO + 4, ALTO + 4), Color.BLACK)
	_barra.draw_rect(Rect2(0, 0, ANCHO, ALTO), COLOR_VACIO)
	_barra.draw_rect(Rect2(0, 0, ANCHO * jefe.vida / JefeSimi.VIDA, ALTO), COLOR_VIDA)
	_barra.draw_rect(Rect2(ANCHO * JefeSimi.FASE_2 - 1.0, -3, 2, ALTO + 6), Color(1.0, 0.3, 0.2))


func _dibujar_zafarse() -> void:
	if not is_instance_valid(jefe):
		return
	_zafarse.draw_rect(Rect2(-2, -2, ANCHO + 4, ALTO + 4), Color.BLACK)
	_zafarse.draw_rect(Rect2(0, 0, ANCHO, ALTO), COLOR_VACIO)
	_zafarse.draw_rect(Rect2(0, 0, ANCHO * jefe.zafarse, ALTO), COLOR_ZAFARSE)
	if not jefe.golpeado_bailando:
		_zafarse.draw_rect(Rect2(ANCHO * JefeSimi.ZAFARSE_TOPE - 1.0, -3, 2, ALTO + 6), Color(1.0, 0.3, 0.2))
