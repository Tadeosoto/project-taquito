class_name JuegoSotano
extends CanvasLayer

# La base de las pantallas del Sotano (OL PLEY, la loteria, las carreras, la ventanilla): un
# recuadro al centro con su titulo, las fichas que traes, un aviso y la ayuda. Mientras esta
# abierta el jugador no se mueve (process_mode DISABLED) y el raton se suelta para la loteria;
# Esc sale. Cada juego pone lo suyo en `contenido` (_armar) y su teclado en _tecla.
# Pantalla de 640 x 480, como todo el juego.

signal cerrado

const AMARILLO := Color(1.0, 0.85, 0.1)
const CREMA := Color(0.95, 0.9, 0.78)
const ROJO := Color(0.85, 0.2, 0.15)
const FONDO := Color(0.06, 0.04, 0.08, 0.92)
const MARCO := Color(0.95, 0.3, 0.7)

var titulo := ""
var ayuda := "Esc salir"
var contenido: Control

var _player: Node
var _panel: PanelContainer           # el recuadro (las carreras lo esconden mientras corren)
var _oscuro: ColorRect
var _fichas: Label
var _aviso: Label
var _aviso_t := 0.0
var _ocupado := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("jugador")
	if _player:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_oscuro = ColorRect.new()
	_oscuro.color = Color(0, 0, 0, 0.45)
	_oscuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_oscuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_oscuro)
	var panel := PanelContainer.new()
	_panel = panel
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FONDO
	estilo.border_color = MARCO
	estilo.set_border_width_all(3)
	estilo.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", estilo)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = -20.0
	panel.offset_bottom = -20.0
	add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)
	var arriba := HBoxContainer.new()
	caja.add_child(arriba)
	var t := etiqueta(titulo, 20, AMARILLO)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arriba.add_child(t)
	_fichas = etiqueta("", 16, CREMA)
	arriba.add_child(_fichas)
	contenido = VBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 6)
	caja.add_child(contenido)
	_aviso = etiqueta("", 16, AMARILLO)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD
	_aviso.custom_minimum_size = Vector2(560, 40)
	caja.add_child(_aviso)
	var a := etiqueta(ayuda, 12, Color(0.75, 0.72, 0.68))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(a)
	var fichas := get_node_or_null("/root/Fichas")
	if fichas:
		fichas.cambio.connect(_contar)
	_contar()
	_armar()


func _exit_tree() -> void:
	var fichas := get_node_or_null("/root/Fichas")
	if fichas and fichas.cambio.is_connected(_contar):
		fichas.cambio.disconnect(_contar)


func _process(delta: float) -> void:
	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0:
			_aviso.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not _ocupado:
				cerrar()
			get_viewport().set_input_as_handled()
			return
		_tecla(event.keycode)
		get_viewport().set_input_as_handled()


# Para que la prueba (tools/sotano/probar_sotano.gd) juegue sin teclado
func tecla(codigo: int) -> void:
	_tecla(codigo)


func cerrar() -> void:
	if _player:
		_player.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cerrado.emit()
	queue_free()


func avisar(texto: String, segundos := 3.0) -> void:
	_aviso.text = texto
	_aviso_t = segundos


func etiqueta(texto: String, tam := 14, color := CREMA) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func carta(i: int, ancho := 72.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = CartasLoteria.textura(i)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(ancho, ancho * 1.5)
	return r


func fichas() -> int:
	var f := get_node_or_null("/root/Fichas")
	return f.fichas if f else 0


func _contar() -> void:
	_fichas.text = "Fichas: %d" % fichas()


# Para los hijos
func _armar() -> void:
	pass


func _tecla(_codigo: int) -> void:
	pass
