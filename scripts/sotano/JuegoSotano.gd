class_name JuegoSotano
extends CanvasLayer

# La base de las pantallas del Sotano (EL GORDO, el poker, el blackjack, la ruleta, las carreras, la
# ventanilla): un
# recuadro al centro con su titulo, las fichas que traes, un aviso y la ayuda. Mientras esta
# abierta el jugador no se mueve (process_mode DISABLED) y el raton se suelta para la loteria;
# Esc sale. Cada juego pone lo suyo en `contenido` (_armar) y sus opciones en una fila de botones
# (botones(), AG 2026-11-19: "flechas para moverte y un boton para escoger"): flechas o cruceta
# mueven, Espacio/Enter/A aprietan, Esc/B sale. Las letras viejas (_tecla) siguen de atajo.
# Pantalla de 640 x 480, como todo el juego.

signal cerrado

const AMARILLO := Color(1.0, 0.85, 0.1)
const CREMA := Color(0.95, 0.9, 0.78)
const ROJO := Color(0.85, 0.2, 0.15)
const FONDO := Color(0.06, 0.04, 0.08, 0.92)
const MARCO := Color(0.95, 0.3, 0.7)
const AYUDA_FILA := "←/→ escoger  ·  Espacio aceptar  ·  Esc salir"

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
var _ayuda_etiqueta: Label
# La fila de botones: por boton {texto: String o Callable, hacer: Callable (sin el es solo letrero),
# activo: Callable -> bool, visible: Callable -> bool, marcado: Callable -> bool, principal: bool
# (a ese regresa la seleccion cuando el escogido se apaga)}
var _fila_botones: HBoxContainer
var _botones: Array = []
var _cajas: Array[PanelContainer] = []
var _textos: Array[Label] = []
var _sel := 0
static var _estilos := {}


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_tree().get_first_node_in_group("jugador")
	if _player:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud_arma(false)
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
	_ayuda_etiqueta = a
	add_to_group("juego_sotano")
	var fichas := get_node_or_null("/root/Fichas")
	if fichas:
		fichas.cambio.connect(_contar)
	_contar()
	_armar()
	_armar_botones()


func _exit_tree() -> void:
	var fichas := get_node_or_null("/root/Fichas")
	if fichas and fichas.cambio.is_connected(_contar):
		fichas.cambio.disconnect(_contar)


func _process(delta: float) -> void:
	if not _botones.is_empty():
		refrescar()
	if _aviso_t > 0.0:
		_aviso_t -= delta
		if _aviso_t <= 0.0:
			_aviso.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not _ocupado:
			cerrar()
		get_viewport().set_input_as_handled()
		return
	if not _botones.is_empty():
		var hecho := true
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			mover(-1)
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			mover(1)
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			apretar()
		else:
			hecho = false
		if hecho:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed:
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
	_hud_arma(true)
	cerrado.emit()
	queue_free()


# --- La fila de botones ---

# Cada juego pone aqui su fila (botones(...)); sin fila, solo sus teclas
func _armar_botones() -> void:
	pass


# Pone (o cambia) los botones, abajo al centro. Ver _botones arriba para lo que lleva cada uno.
func botones(lista: Array) -> void:
	if _fila_botones == null:
		_fila_botones = HBoxContainer.new()
		_fila_botones.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_fila_botones.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_fila_botones.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_fila_botones.offset_bottom = -6.0
		_fila_botones.add_theme_constant_override("separation", 4)
		add_child(_fila_botones)
	for c in _fila_botones.get_children():
		c.queue_free()
	_botones = lista + [{"texto": "Salir", "hacer": cerrar}]
	_cajas.clear()
	_textos.clear()
	for i in _botones.size():
		var caja := PanelContainer.new()
		var l := etiqueta("", 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(l)
		caja.mouse_filter = Control.MOUSE_FILTER_STOP
		caja.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_sel = i
				apretar())
		_fila_botones.add_child(caja)
		_cajas.append(caja)
		_textos.append(l)
	if _ayuda_etiqueta:
		_ayuda_etiqueta.text = AYUDA_FILA
	_sel = -1
	refrescar()


func _vale(i: int, para_escoger := true) -> bool:
	var b: Dictionary = _botones[i]
	if b.has("visible") and not (b.visible as Callable).call():
		return false
	if not para_escoger:
		return true
	if not b.has("hacer"):
		return false
	return not b.has("activo") or (b.activo as Callable).call()


# Mueve la seleccion (salta letreros, apagados y escondidos)
func mover(paso: int) -> void:
	var n := _botones.size()
	for k in n:
		var i := posmod(_sel + paso * (k + 1), n)
		if _vale(i):
			if i != _sel and _sel != -1:
				Sonidos.tocar(self, "apuesta_sube", -14.0, 1.4)
			_sel = i
			break
	_pintar()


func apretar() -> void:
	if _ocupado or _sel < 0 or _sel >= _botones.size() or not _vale(_sel):
		return
	Sonidos.tocar(self, "boton", -10.0, 1.2)
	(_botones[_sel].hacer as Callable).call()
	refrescar()


# El texto del boton escogido (para las pruebas)
func escogido() -> String:
	return _textos[_sel].text if _sel >= 0 and _sel < _textos.size() else ""


# Escoge el boton con ese texto y lo aprieta (para las pruebas)
func apretar_boton(texto: String) -> bool:
	_pintar()
	for i in _botones.size():
		if _textos[i].text.strip_edges() == texto and _vale(i):
			_sel = i
			apretar()
			return true
	return false


# Si el escogido se apago o se escondio, pasa al siguiente que sirva; luego pinta
func refrescar() -> void:
	if _cajas.size() != _botones.size():
		return
	# (primero el principal: Repartir, Girar, Otra mano...; si no, el primero que sirva)
	if _sel < 0 or not _vale(_sel):
		_sel = -1
		for i in _botones.size():
			if _vale(i) and _botones[i].get("principal", false):
				_sel = i
				break
		if _sel < 0:
			for i in _botones.size():
				if _vale(i):
					_sel = i
					break
	_pintar()


func _pintar() -> void:
	if _cajas.size() != _botones.size():
		return
	_fila_botones.modulate.a = 0.45 if _ocupado else 1.0
	for i in _botones.size():
		var b: Dictionary = _botones[i]
		var t = b.get("texto", "")
		_textos[i].text = (t as Callable).call() if t is Callable else str(t)
		_cajas[i].visible = _vale(i, false)
		var tipo := "letrero"
		if b.has("hacer"):
			tipo = "escogido" if i == _sel else ("apagado" if not _vale(i) else "normal")
			if tipo != "escogido" and b.has("marcado") and (b.marcado as Callable).call():
				tipo = "marcado"
		_cajas[i].add_theme_stylebox_override("panel", _estilo(tipo))
		var color := CREMA
		match tipo:
			"escogido":
				color = Color.BLACK
			"apagado":
				color = Color(0.5, 0.48, 0.45)
			"letrero", "marcado":
				color = AMARILLO
		_textos[i].add_theme_color_override("font_color", color)
		_textos[i].add_theme_constant_override("outline_size", 0 if tipo == "escogido" else 4)


static func _estilo(tipo: String) -> StyleBoxFlat:
	if _estilos.has(tipo):
		return _estilos[tipo]
	var e := StyleBoxFlat.new()
	e.set_content_margin_all(4)
	e.content_margin_left = 8
	e.content_margin_right = 8
	e.set_border_width_all(2)
	match tipo:
		"escogido":
			e.bg_color = AMARILLO
			e.border_color = Color.WHITE
		"marcado":
			e.bg_color = Color(0.3, 0.12, 0.25, 0.95)
			e.border_color = AMARILLO
		"apagado":
			e.bg_color = Color(0.08, 0.07, 0.08, 0.8)
			e.border_color = Color(0.25, 0.22, 0.24)
		"letrero":
			e.bg_color = Color(0, 0, 0, 0.6)
			e.border_color = Color(0, 0, 0, 0)
		_:
			e.bg_color = FONDO
			e.border_color = MARCO
	_estilos[tipo] = e
	return e


# El letrero de la apuesta y sus dos botones: cambiar(paso) la sube (+1) o la baja (-1)
func botones_apuesta(texto: Callable, cambiar: Callable, se_puede: Callable) -> Array:
	return [{"texto": texto},
		{"texto": " - ", "hacer": cambiar.bind(-1), "activo": se_puede},
		{"texto": " + ", "hacer": cambiar.bind(1), "activo": se_puede}]


# El letrero del arma (Pistola, de JJ: no se toca su codigo) se encimaba con la fila de botones
func _hud_arma(ver: bool) -> void:
	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	for n in jugador.find_children("*", "", true, false):
		var guion := n.get_script() as Script
		if guion == null or not guion.resource_path.ends_with("/Pistola.gd"):
			continue
		var capa = n.get("_capa")
		if capa is CanvasLayer:
			(capa as CanvasLayer).visible = ver


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
	# El jugador se esconde: la camara sale casi de su cabeza (en el baccarat se veia su pelo enfrente)
	if _player is Node3D:
		(_player as Node3D).visible = false
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara_mesa, "global_transform", Transform3D(Basis.looking_at(mira - ojos), ojos), tiempo)
	tween.tween_property(_camara_mesa, "fov", fov, tiempo)


func regresar_camara() -> void:
	if _player is Node3D:
		(_player as Node3D).visible = true
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
		# La gente del Sotano te echa porras (uno de tres pedazos, al azar)
		Sonidos.tocar(self, "festejo_%d" % randi_range(1, 3), -10.0, randf_range(0.95, 1.05))
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
