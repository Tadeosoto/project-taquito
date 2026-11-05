class_name DialogueBox
extends CanvasLayer

# Caja de dialogo abajo de la pantalla: retrato a la izquierda y texto que se escribe
# letra por letra, con blips, palabras animadas y acentos de pixelfx encima.
#
#   caja.decir(["Hola.", "Ya me voy."], "Doña Chuy", retrato, 1.2)
#   await caja.termino
#
# Etiquetas para quien escribe los textos (ademas del BBCode normal):
#   [feliz]...[/feliz]  la palabra ondea
#   [enojo]...[/enojo]  la palabra tiembla, sale la marca de rabia junto al retrato
#   [clave]...[/clave]  amarillo de marcador y un brillo cuando aparece
#
# Mientras esta abierta pausa el arbol, como el inventario: la caja siempre procesa.
# El tiempo va con el reloj real (Time.get_ticks_msec), no con SceneTreeTimer: esos se
# quedaban atorados con la congelada de los golpes.
# Corrida sola (godot --path . scenes/dialogue_box.tscn) repite unas lineas de prueba.

signal termino

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const AMARILLO := Color(1.0, 0.85, 0.1)

# Tamanos en pixeles de la pantalla de 640x480
const MARGEN := 12.0
const ALTO := 124.0
const RETRATO := 96.0
const RETRATO_PX := 32         # cada cuadro del retrato de prueba

# Maquina de escribir (ms)
const LETRA_MS := 28
const PAUSA_PUNTO_MS := 200    # despues de . ? ! …
const PAUSA_COMA_MS := 100     # despues de , ; :
const PUNTOS := ".?!…"
const COMAS := ",;:"
const BOCA_MS := 100           # la boca abre y cierra a este paso mientras escribe
const PARPADEO_MS := 120
const PARPADEO_CADA := Vector2(2.0, 5.0)   # s
const TONO_VAIVEN := 0.05

# BBCode de cada etiqueta (amp y level de Godot ya vienen divididos entre 10: 50 = 5 px)
const ETIQUETAS := {
	"[feliz]": "[wave amp=50.0 freq=2.0]", "[/feliz]": "[/wave]",
	"[enojo]": "[shake rate=20.0 level=10]", "[/enojo]": "[/shake]",
	"[clave]": "[color=#ffd91a]", "[/clave]": "[/color]",
}

const PRUEBA: Array[String] = [
	"¡Órale, compa! Llegaste justo a tiempo.",
	"Dicen que el [clave]tinaco de la Virgen[/clave] ya no aguanta... y que esta noche se va a [enojo]tronar[/enojo].",
	"Pero tranquilo: con [feliz]3 tacos[/feliz] y 1.5 litros de tejuino en la panza, cualquiera aguanta, ¿no?",
]

var abierta := false

static var _compartida: DialogueBox

var _caja: PanelContainer
var _retrato: TextureRect
var _cuadro: AtlasTexture
var _nombre: Label
var _texto: RichTextLabel
var _flecha: Polygon2D
var _fx: Control
var _voz: AudioStreamPlayer
var _retrato_base := Vector2.ZERO

var _lineas: Array[String] = []
var _linea := 0
var _tono := 1.0
var _plano := ""
var _escribiendo := false
var _siguiente_ms := 0
var _pausa_hasta_ms := 0
var _parpadeo_ms := 0
var _parpadea_hasta_ms := 0
var _pausaba := false
var _claves: Array[Vector2i] = []   # inicio y fin en el texto sin etiquetas
var _enojos: Array[int] = []
var _sin_etiquetas := RegEx.create_from_string("\\[[^\\]]*\\]")
var _sola := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_armar()
	visible = false
	_sola = get_tree().current_scene == self
	if _sola:
		_repetir_prueba()


func _repetir_prueba() -> void:
	decir(PRUEBA, "Doña Chuy", null, 1.15)
	await termino
	await get_tree().create_timer(1.0, true, false, true).timeout
	_repetir_prueba()


# --- API ---------------------------------------------------------------------

# Una caja por escena, para los NPC (npc.gd): se crea la primera vez dentro de la escena
# actual, asi que se va con ella al cambiar de escena
static func compartida(nodo: Node) -> DialogueBox:
	if not is_instance_valid(_compartida) or not _compartida.is_inside_tree():
		_compartida = (load("res://scenes/dialogue_box.tscn") as PackedScene).instantiate()
		var escena := nodo.get_tree().current_scene
		(escena if escena else nodo.get_tree().root).add_child(_compartida)
	return _compartida


# `retrato`: hoja de 3 cuadros en fila (boca cerrada, boca abierta, parpadeo); sin ella
# usa uno de prueba. `tono`: el blip de quien habla (1 = normal, mas alto = mas agudo).
func decir(lineas: Array[String], hablante: String, retrato: Texture2D = null, tono := 1.0) -> void:
	if lineas.is_empty():
		return
	_lineas = lineas
	_linea = 0
	_tono = tono
	_nombre.text = hablante
	_nombre.visible = hablante != ""
	_cuadro.atlas = retrato if retrato else _retrato_prueba()
	_poner_cuadro(0)
	if not abierta:
		_abrir()
	_empezar_linea()


# --- Abrir y cerrar ------------------------------------------------------------

func _abrir() -> void:
	abierta = true
	visible = true
	_pausaba = get_tree().paused
	get_tree().paused = true
	_caja.pivot_offset = Vector2(_caja.size.x * 0.5, _caja.size.y)
	_caja.scale = Vector2(0.8, 0.8)
	_caja.modulate.a = 0.0
	var tween := _caja.create_tween()
	tween.tween_property(_caja, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(_caja, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_caja, "scale", Vector2.ONE, 0.06)
	Sonidos.tocar(self, "inv_abrir", -8.0)
	# Polvito de pixelfx en las dos esquinas de arriba
	var arriba := _caja.position
	_humo(arriba + Vector2(28.0, 8.0), 0.75)
	_humo(arriba + Vector2(_caja.size.x - 28.0, 8.0), 0.75)


func _cerrar() -> void:
	abierta = false
	_escribiendo = false
	_humo(_caja.position + Vector2(_caja.size.x * 0.5, 6.0), 0.6)
	var tween := _caja.create_tween()
	tween.tween_property(_caja, "scale", Vector2(0.9, 0.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		visible = false
		_caja.scale = Vector2.ONE
		get_tree().paused = _pausaba
		termino.emit())


# --- Escribir ------------------------------------------------------------------

func _empezar_linea() -> void:
	var fuente := _lineas[_linea]
	_marcas(fuente)
	var bbcode := fuente
	for etiqueta: String in ETIQUETAS:
		bbcode = bbcode.replace(etiqueta, ETIQUETAS[etiqueta])
	_texto.text = bbcode
	_plano = _texto.get_parsed_text()
	_texto.visible_characters = 0
	_flecha.visible = false
	_escribiendo = true
	_siguiente_ms = Time.get_ticks_msec() + LETRA_MS
	_pausa_hasta_ms = 0


# Donde empiezan [clave] y [enojo] contando solo las letras que se ven
func _marcas(fuente: String) -> void:
	_claves.clear()
	_enojos.clear()
	var desde := fuente.find("[clave]")
	while desde >= 0:
		var hasta := fuente.find("[/clave]", desde)
		if hasta < 0:
			hasta = fuente.length()
		_claves.append(Vector2i(_letras_antes(fuente, desde), _letras_antes(fuente, hasta)))
		desde = fuente.find("[clave]", hasta)
	desde = fuente.find("[enojo]")
	while desde >= 0:
		_enojos.append(_letras_antes(fuente, desde))
		desde = fuente.find("[enojo]", desde + 1)


func _letras_antes(fuente: String, indice: int) -> int:
	return _sin_etiquetas.sub(fuente.substr(0, indice), "", true).length()


func _process(_delta: float) -> void:
	if not abierta:
		return
	var ahora := Time.get_ticks_msec()
	if _escribiendo:
		var total := _texto.get_total_character_count()
		while _escribiendo and ahora >= _siguiente_ms:
			var i := _texto.visible_characters
			if i >= total:
				_terminar_linea()
				break
			_texto.visible_characters = i + 1
			var letra := _plano[i] if i < _plano.length() else ""
			var espera := LETRA_MS
			if letra.strip_edges() != "":
				_voz.pitch_scale = _tono * randf_range(1.0 - TONO_VAIVEN, 1.0 + TONO_VAIVEN)
				_voz.play()
			# Pausa solo si lo que sigue es espacio o fin: "3.5" y "..." no se detienen en medio
			var sigue := _plano[i + 1] if i + 1 < _plano.length() else " "
			if sigue.strip_edges() == "" or sigue == "¿" or sigue == "¡":
				if PUNTOS.contains(letra):
					espera += PAUSA_PUNTO_MS
					_pausa_hasta_ms = _siguiente_ms + espera
				elif COMAS.contains(letra):
					espera += PAUSA_COMA_MS
					_pausa_hasta_ms = _siguiente_ms + espera
			_acentos(i)
			_siguiente_ms += espera
		# La boca se mueve mientras escribe, cerrada en las pausas
		var abre := ahora >= _pausa_hasta_ms and (ahora / BOCA_MS) % 2 == 0
		_poner_cuadro(1 if (abre and _escribiendo) else 0)
	else:
		if ahora >= _parpadeo_ms:
			_parpadea_hasta_ms = ahora + PARPADEO_MS
			_parpadeo_ms = ahora + int(randf_range(PARPADEO_CADA.x, PARPADEO_CADA.y) * 1000.0)
		_poner_cuadro(2 if ahora < _parpadea_hasta_ms else 0)
		_flecha.visible = (ahora / 400) % 2 == 0


func _terminar_linea() -> void:
	_escribiendo = false
	_texto.visible_characters = -1
	_parpadeo_ms = Time.get_ticks_msec() + int(randf_range(PARPADEO_CADA.x, PARPADEO_CADA.y) * 1000.0)
	_poner_cuadro(0)


func _input(event: InputEvent) -> void:
	if not abierta:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if _escribiendo:
			_terminar_linea()
		elif _linea + 1 < _lineas.size():
			_linea += 1
			Sonidos.tocar(self, "ui_mover", -10.0)
			_empezar_linea()
		elif _caja.scale == Vector2.ONE:
			_cerrar()
	# Que no se abra el inventario ni el mapa encima
	elif event.is_action_pressed("inventory_toggle") or event.is_action_pressed("inventory_map"):
		get_viewport().set_input_as_handled()


# --- Retrato -------------------------------------------------------------------

func _poner_cuadro(cual: int) -> void:
	if _cuadro.atlas == null:
		return
	var ancho := _cuadro.atlas.get_width() / 3.0
	_cuadro.region = Rect2(ancho * cual, 0.0, ancho, _cuadro.atlas.get_height())


static var _prueba: Texture2D

# Cara de prueba hecha en codigo hasta que haya retratos dibujados
static func _retrato_prueba() -> Texture2D:
	if _prueba:
		return _prueba
	var n := RETRATO_PX
	var imagen := Image.create(n * 3, n, false, Image.FORMAT_RGBA8)
	var piel := Color("#c68a5a")
	var sombra := Color("#8a5636")
	var pelo := Color("#2a1a12")
	for cuadro in 3:
		var x0 := cuadro * n
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.55).length()
				if d < n * 0.4:
					imagen.set_pixel(x0 + x, y, piel if d < n * 0.36 else sombra)
				if y < n * 0.32 and d < n * 0.42:
					imagen.set_pixel(x0 + x, y, pelo)
		# Ojos: abiertos 2x2, parpadeo una raya
		for ojo: int in [11, 19]:
			if cuadro == 2:
				imagen.fill_rect(Rect2i(x0 + ojo, 15, 3, 1), sombra.darkened(0.5))
			else:
				imagen.fill_rect(Rect2i(x0 + ojo, 14, 2, 2), Color.BLACK)
		# Boca: raya cerrada o hueco abierto
		if cuadro == 1:
			imagen.fill_rect(Rect2i(x0 + 13, 21, 6, 3), Color("#3a0a0a"))
		else:
			imagen.fill_rect(Rect2i(x0 + 13, 22, 6, 1), sombra.darkened(0.3))
	_prueba = ImageTexture.create_from_image(imagen)
	return _prueba


# --- pixelfx -------------------------------------------------------------------

# Brillo en la palabra [clave] cuando sale su primera letra; marca de rabia con [enojo]
func _acentos(indice: int) -> void:
	if not EfectosPixel.extras:
		return
	for clave in _claves:
		if clave.x == indice:
			_brillo(clave)
	if _enojos.has(indice) and _enojos.find(indice) == 0:
		_rabia()


func _brillo(clave: Vector2i) -> void:
	var linea := _texto.get_character_line(clave.x)
	if linea < 0:
		return
	var rango := _texto.get_line_range(linea)
	var fuente := _texto.get_theme_font("normal_font")
	var tamano := _texto.get_theme_font_size("normal_font_size")
	var fin := mini(clave.y, rango.y)
	var x0 := fuente.get_string_size(_plano.substr(rango.x, clave.x - rango.x), HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var x1 := fuente.get_string_size(_plano.substr(rango.x, fin - rango.x), HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var y := _texto.get_line_offset(linea) + fuente.get_height(tamano) * 0.5
	var punto := _texto.global_position + Vector2((x0 + x1) * 0.5, y)
	var hoja := EfectosPixel.hoja_de("recoger_brillo")
	if hoja.is_empty():
		return
	var escala := 0.5
	EfectosPixel.hoja_ui(_fx, "recoger_brillo", Rect2(punto - hoja["pivote"] * escala + Vector2(0.0, hoja["tamano"].y * escala * 0.35), hoja["tamano"] * escala), true)
	Sonidos.tocar(self, "brillo", -14.0)


func _rabia() -> void:
	var hoja := EfectosPixel.hoja_de("rabia")
	if hoja.is_empty():
		return
	var escala := 1.2
	var donde := _retrato.global_position + Vector2(RETRATO - 10.0, -4.0)
	var marca := EfectosPixel.hoja_ui(_fx, "rabia", Rect2(donde - hoja["pivote"] * escala * 0.5, hoja["tamano"] * escala))
	if marca:
		# Es de las que se repiten: la caja la quita sola
		var quita := marca.create_tween()
		quita.tween_interval(0.7)
		quita.tween_property(marca, "modulate:a", 0.0, 0.2)
		quita.tween_callback(marca.queue_free)
	# El retrato tiembla tantito
	var tiembla := _retrato.create_tween()
	for i in 4:
		tiembla.tween_property(_retrato, "position", _retrato_base + Vector2(2.0 if i % 2 == 0 else -2.0, 0.0), 0.03)
	tiembla.tween_property(_retrato, "position", _retrato_base, 0.03)


func _humo(punto: Vector2, escala: float) -> void:
	if not EfectosPixel.extras:
		return
	var hoja := EfectosPixel.hoja_de("dialogo_abre")
	if hoja.is_empty():
		return
	EfectosPixel.hoja_ui(_fx, "dialogo_abre", Rect2(punto - hoja["pivote"] * escala, hoja["tamano"] * escala))


# --- Armar la caja ---------------------------------------------------------------

func _armar() -> void:
	var pantalla := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var raiz := Control.new()
	raiz.theme = TEMA
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_caja = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	estilo.border_color = Color(0.85, 0.85, 0.85)
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(10.0)
	_caja.add_theme_stylebox_override("panel", estilo)
	_caja.position = Vector2(MARGEN, pantalla.y - ALTO - MARGEN)
	_caja.size = Vector2(pantalla.x - MARGEN * 2.0, ALTO)
	raiz.add_child(_caja)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	_caja.add_child(fila)

	# El retrato va dentro de un Control fijo para poder temblar sin mover la fila
	var marco := Control.new()
	marco.custom_minimum_size = Vector2(RETRATO, RETRATO)
	fila.add_child(marco)
	_cuadro = AtlasTexture.new()
	_retrato = TextureRect.new()
	_retrato.texture = _cuadro
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato.size = Vector2(RETRATO, RETRATO)
	marco.add_child(_retrato)

	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 2)
	fila.add_child(columna)
	_nombre = Label.new()
	_nombre.add_theme_color_override("font_color", AMARILLO)
	columna.add_child(_nombre)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.scroll_active = false
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Que las palabras no brinquen de renglon mientras se escriben
	_texto.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_texto.add_theme_constant_override("outline_size", 4)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("line_separation", 2)
	columna.add_child(_texto)

	# Flechita de "sigue" en la esquina, parpadea cuando termina el renglon
	_flecha = Polygon2D.new()
	_flecha.polygon = PackedVector2Array([Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Vector2(0.0, 6.0)])
	_flecha.color = AMARILLO
	_flecha.position = _caja.size - Vector2(16.0, 16.0)
	_flecha.visible = false
	_caja.add_child(_flecha)

	# Los efectos van encima de todo y no se encogen con la caja
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_fx)

	_voz = AudioStreamPlayer.new()
	_voz.stream = Sonidos.sonido("blip")
	_voz.volume_db = -12.0
	add_child(_voz)

	_retrato_base = _retrato.position
