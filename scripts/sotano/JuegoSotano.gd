class_name JuegoSotano
extends CanvasLayer

# La base de las pantallas del Sotano (EL GORDO, el poker, el blackjack, la ruleta, las carreras, la
# ventanilla): un
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
	regresar_camara()
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


# La camara vuela de la del jugador a ver la mesa (ojos y mira en global) y regresa al cerrar.
# La usan el blackjack y la ruleta (el poker y las carreras traen la suya)
var _camara_mesa: Camera3D
var _camara_antes: Camera3D


func acercar_camara(ojos: Vector3, mira: Vector3, fov := 56.0, tiempo := 0.6) -> void:
	_camara_antes = get_viewport().get_camera_3d()
	_camara_mesa = Camera3D.new()
	add_child(_camara_mesa)
	if _camara_antes:
		_camara_mesa.global_transform = _camara_antes.global_transform
		_camara_mesa.fov = _camara_antes.fov
	_camara_mesa.make_current()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara_mesa, "global_transform", Transform3D(Basis.looking_at(mira - ojos), ojos), tiempo)
	tween.tween_property(_camara_mesa, "fov", fov, tiempo)


func regresar_camara() -> void:
	if _camara_antes and is_instance_valid(_camara_antes):
		_camara_antes.make_current()
	if _camara_mesa:
		_camara_mesa.queue_free()
		_camara_mesa = null


# --- El festejo (y el chale) de las mesas ---
# Cada juego lleva su racha (por titulo, para toda la partida): ganar seguido sube la racha y el
# festejo crece (de monedas a confeti y rayos, con el premio mayor sonando); perder la corta y,
# perdiendo seguido, el chale tambien crece. festejar(true, premio) o festejar(false).

static var _rachas := {}             # titulo -> racha (positiva ganando, negativa perdiendo)


func racha() -> int:
	return int(_rachas.get(titulo, 0))


func festejar(gano: bool, premio := 0) -> void:
	var r := racha()
	r = (maxi(r, 0) + 1) if gano else (mini(r, 0) - 1)
	_rachas[titulo] = r
	var letrero := etiqueta("", 34, AMARILLO)
	letrero.add_theme_constant_override("outline_size", 10)
	var destello := ColorRect.new()
	destello.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gano:
		if r >= 3:
			letrero.text = "¡RACHA DE %d!
+%d" % [r, premio]
			letrero.add_theme_color_override("font_color", Color(1.0, 0.45, 0.9))
			_efecto("tazo_rayos", 2.0)
			_efecto("olpley_confeti", 2.2)
			Sonidos.tocar(self, "slot_premio_mayor", -4.0)
		elif r == 2:
			letrero.text = "¡OTRA VEZ!
+%d" % premio
			_efecto("olpley_confeti", 1.8)
			Sonidos.tocar(self, "slot_gana_grande", -4.0)
		else:
			letrero.text = "¡GANASTE!
+%d" % premio
			_efecto("premio_monedas", 1.6)
		destello.color = Color(1.0, 0.85, 0.3, 0.3)
	else:
		letrero.text = "¡QUÉ SALADO!" if r <= -3 else "CHALE..."
		letrero.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		letrero.add_theme_font_size_override("font_size", 30 if r <= -3 else 26)
		_efecto("muerte_humo", 1.4 if r <= -3 else 1.0)
		Sonidos.tocar(self, "perder", -8.0)
		destello.color = Color(0.15, 0.0, 0.05, 0.35 if r <= -3 else 0.22)
	add_child(destello)
	var tw := create_tween()
	tw.tween_property(destello, "color:a", 0.0, 0.6)
	tw.tween_callback(destello.queue_free)
	letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(letrero)
	letrero.reset_size()
	letrero.pivot_offset = letrero.size / 2.0
	letrero.position = Vector2(320.0 - letrero.size.x / 2.0, 150.0 - letrero.size.y / 2.0)
	letrero.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	if gano:
		t.tween_property(letrero, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(letrero, "scale", Vector2.ONE, 0.12)
		t.tween_interval(1.0)
		t.tween_property(letrero, "position:y", letrero.position.y - 30.0, 0.5)
		t.parallel().tween_property(letrero, "modulate:a", 0.0, 0.5)
	else:
		letrero.scale = Vector2.ONE
		letrero.position.y -= 30.0
		t.tween_property(letrero, "position:y", letrero.position.y + 40.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.7)
		t.tween_property(letrero, "modulate:a", 0.0, 0.5)
	t.tween_callback(letrero.queue_free)


# Una hoja de pixelfx (resources/fx) que se reproduce una vez al centro de la pantalla
func _efecto(nombre: String, escala := 1.5) -> void:
	var hoja := EfectosPixel.hoja_de(nombre)
	if hoja.is_empty():
		return
	var cuadro := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = hoja["textura"]
	var tam: Vector2 = hoja["tamano"]
	atlas.region = Rect2(Vector2.ZERO, tam)
	cuadro.texture = atlas
	cuadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cuadro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuadro.size = tam * escala
	cuadro.position = Vector2(320.0, 170.0) - cuadro.size / 2.0
	add_child(cuadro)
	var cuadros := int(hoja["cuadros"])
	var columnas := int(hoja["columnas"])
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		var i := mini(int(f), cuadros - 1)
		atlas.region = Rect2(Vector2(i % columnas, i / columnas) * tam, tam), 0.0, float(cuadros), cuadros / float(hoja["fps"]))
	t.tween_callback(cuadro.queue_free)


# Para los hijos
func _armar() -> void:
	pass


func _tecla(_codigo: int) -> void:
	pass
