extends JuegoSotano

# Jugar en una maquinita EL GORDO del Sotano (OlPley en el codigo), como en las de frutas
# (TragamonedasUI): la camara se acerca al gabinete y el juego corre EN SU PANTALLA (un SubViewport
# de 384 x 288 que el gabinete
# enseña: GabineteOlPley.mostrar_en_pantalla). Carretes.gd decide; aqui solo se muestra.
# La "Loteria de carretes": tres carretes con cartas de la loteria (CartasLoteria) que ruedan de
# verdad y paran uno tras otro (cada carta con su nombre en letra de pixel, LETRA, para que se
# lea), la linea de premio que parpadea, los contadores, y al ganar monedas
# o (con El Tinaco) confeti de pixelfx (resources/fx/olpley_*). Los botones del gabinete se hunden.
# El fondo de la pantalla es textures/sotano/pantalla_juego.png (tools/blender/sotano/arte.py).

const FONDO_PANTALLA := preload("res://textures/sotano/pantalla_juego.png")
const PANTALLA := Vector2i(384, 288)
const CARRETE_X := [36, 144, 252]
const CARRETE_Y := 51
const CARRETE := Vector2(96, 168)
const CARTA_ALTO := 144.0
const LINEA_Y := 135                # la linea de premio, a media ventana
const CONTADOR_X := [24, 144, 264]
const CONTADOR_Y := 249
const LETRA := preload("res://fonts/PixelifySans.ttf")
const NOMBRE := Rect2(4, 111, 88, 28)   # donde va el nombre en la carta (la banda crema)
const DIBUJO := Rect2(8, 22, 80, 80)    # el dibujo 3D sobre el campo de color
const FOCOS_PANTALLA := 0.12            # s entre turno y turno de los focos del marco
const FOCO_PRENDIDO := Color(1.0, 0.95, 0.5)
const FOCO_APAGADO := Color(0.45, 0.3, 0.1)
const GIRO := [0.8, 1.15, 1.5]      # s que gira cada carrete antes de parar
const VELOCIDAD := 1350.0           # px/s de los carretes girando
const OJOS := Vector3(0.15, 1.37, 0.78)  # la camara, en el gabinete: la pantalla grande y la palanca
const MIRA := Vector3(0.075, 1.3, 0.1)   # a la orilla derecha
const FOV := 46.0
const TIEMPO_CAMARA := 0.6
const AYUDA := "←/→ apuesta  ·  Espacio o ↓ jalar la palanca  ·  Esc salir"

var placa: Carretes
var gabinete: GabineteOlPley

var _apuesta := 1
var _vista: SubViewport
var _carretes: Array = []            # por carrete: [Control recorte, Array de 3 TextureRect]
var _corrimiento: Array[float] = [0.0, 0.0, 0.0]
var _girando: Array[bool] = [false, false, false]
var _contadores: Array[Label] = []
var _linea: Array[ColorRect] = []
var _fx: TextureRect
var _fx_hoja := {}
var _fx_t := -1.0
var _camara: Camera3D
var _camara_jugador: Camera3D
var _premio := 0
var _letra: FontFile
var _focos: Array[ColorRect] = []    # los focos del marco de la pantalla, que corren
var _focos_t := 0.0
var _focos_turno := 0
var _letrero: Label                  # el premio que cruza la pantalla


func _init() -> void:
	titulo = "EL GORDO"
	ayuda = AYUDA


func _armar() -> void:
	_panel.visible = false
	_oscuro.visible = false
	_armar_vista()
	var a := etiqueta(AYUDA, 13, Color(0.9, 0.88, 0.82))
	a.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	a.grow_horizontal = Control.GROW_DIRECTION_BOTH
	a.grow_vertical = Control.GROW_DIRECTION_BEGIN
	a.offset_bottom = -8.0
	add_child(a)
	_aviso.reparent(self)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.offset_top = 8.0
	if gabinete:
		gabinete.mostrar_en_pantalla(_vista.get_texture())
		_acercar_camara()
	_contar_pantalla()


func cerrar() -> void:
	if gabinete:
		gabinete.mostrar_en_pantalla(null)
	if _camara_jugador:
		_camara_jugador.make_current()
	if _camara:
		_camara.queue_free()
	super.cerrar()


func _tecla(codigo: int) -> void:
	if _ocupado:
		return
	match codigo:
		KEY_LEFT, KEY_A:
			_apuesta = maxi(_apuesta - 1, 1)
			_apretar("Boton_0", "apuesta_sube")
		KEY_RIGHT, KEY_D:
			_apuesta = mini(_apuesta + 1, Carretes.APUESTA_MAX)
			_apretar("Boton_1", "apuesta_sube")
		KEY_SPACE, KEY_ENTER, KEY_DOWN, KEY_S:
			jalar()
	_contar_pantalla()


func _contar() -> void:
	super._contar()
	_contar_pantalla()


func _contar_pantalla() -> void:
	if _contadores.size() < 3:
		return
	_contadores[0].text = str(_apuesta)
	_contadores[1].text = str(fichas())
	_contadores[2].text = str(_premio)


func _apretar(boton: String, sonido := "slot_boton") -> void:
	if gabinete:
		gabinete.apretar(boton)
	Sonidos.tocar(self, sonido, -8.0)


func jalar() -> void:
	if _ocupado:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	_ocupado = true
	_premio = 0
	Sonidos.tocar(self, "ficha_cae", -6.0)
	_contar_pantalla()
	# La palanca baja y ahi arrancan los carretes
	if gabinete:
		await gabinete.jalar_palanca()
		if not is_inside_tree():
			return
	for l in _linea:
		l.visible = false
	var tiro := placa.tirar(_apuesta)
	var final: Array = tiro["carretes"]
	for k in 3:
		_girando[k] = true
	var t := 0.0
	var parados := 0
	while parados < 3:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t += get_process_delta_time()
		while parados < 3 and t >= GIRO[parados]:
			_parar(parados, final[parados])
			parados += 1
	await get_tree().create_timer(0.25).timeout
	var pago: int = tiro["pago"]
	if pago > 0:
		f.fichas += pago
		_premio = pago
		var tinaco: bool = final.has(CartasLoteria.TINACO) and pago > _apuesta
		var grande: bool = final.count(CartasLoteria.TINACO) == 3 or pago >= _apuesta * 20
		if final.count(CartasLoteria.TINACO) == 3:
			Sonidos.tocar(self, "slot_premio_mayor", -2.0)
		else:
			Sonidos.tocar(self, "slot_gana_grande" if grande else "slot_gana", -3.0)
		Sonidos.tocar(self, "monedas_caen", -6.0)
		_lanzar_fx("olpley_confeti" if grande or tinaco else "olpley_monedas")
		_parpadear_linea()
		avisar(("¡%d fichas! El Tinaco paga doble." if tinaco else "¡Ganaste %d fichas!") % pago)
		_cruzar_letrero("¡PREMIO! %d FICHAS" % pago if not grande else "¡¡EL GORDO!! %d FICHAS" % pago)
	else:
		avisar("Nada. \"La que sigue es la buena\", dice el de al lado.")
	_contar_pantalla()
	if gabinete:
		gabinete.mostrar_estado(placa.estado)
	_ocupado = false


# --- La pantalla ---

func _armar_vista() -> void:
	_vista = SubViewport.new()
	_vista.size = PANTALLA
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vista)
	var fondo := TextureRect.new()
	fondo.texture = FONDO_PANTALLA
	_vista.add_child(fondo)
	# La letra sin suavizar: en la pantalla de pixeles se ve dura, como el resto
	_letra = LETRA.duplicate() as FontFile
	_letra.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var arranque := [0, CartasLoteria.TINACO, 5]
	for k in 3:
		var recorte := Control.new()
		recorte.clip_contents = true
		recorte.position = Vector2(CARRETE_X[k], CARRETE_Y)
		recorte.size = CARRETE
		_vista.add_child(recorte)
		var cartas: Array[TextureRect] = []
		for n in 3:
			var c := TextureRect.new()
			c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			c.size = Vector2(CARRETE.x, CARTA_ALTO)
			var dibujo := TextureRect.new()
			dibujo.name = "Dibujo"
			dibujo.position = DIBUJO.position
			dibujo.size = DIBUJO.size
			dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			c.add_child(dibujo)
			var nombre := Label.new()
			nombre.name = "Nombre"
			nombre.position = NOMBRE.position
			nombre.size = NOMBRE.size
			nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			nombre.add_theme_font_override("font", _letra)
			nombre.add_theme_font_size_override("font_size", 13)
			nombre.add_theme_color_override("font_color", Color(0.12, 0.07, 0.06))
			c.add_child(nombre)
			_poner_carta(c, arranque[k] if n == 1 else _al_azar())
			recorte.add_child(c)
			cartas.append(c)
		_carretes.append([recorte, cartas])
		_acomodar(k)
		# Sombra de cilindro: el carrete se ve redondo, oscuro arriba y abajo
		var sombra := TextureRect.new()
		sombra.texture = _sombra_carrete()
		sombra.position = Vector2(CARRETE_X[k], CARRETE_Y)
		sombra.size = CARRETE
		sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vista.add_child(sombra)
	# La linea de premio: dos rayas que parpadean al ganar
	for y in [LINEA_Y - 74, LINEA_Y + 72]:
		var l := ColorRect.new()
		l.color = Color(1.0, 0.95, 0.3)
		l.position = Vector2(24, y)
		l.size = Vector2(336, 3)
		l.visible = false
		_vista.add_child(l)
		_linea.append(l)
	for k in 3:
		# Contador de 7 segmentos: los "888" apagados detras del numero
		var fantasma := Label.new()
		fantasma.text = "888"
		fantasma.position = Vector2(CONTADOR_X[k], CONTADOR_Y)
		fantasma.size = Vector2(84, 27)
		fantasma.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fantasma.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fantasma.add_theme_font_override("font", _letra)
		fantasma.add_theme_font_size_override("font_size", 22)
		fantasma.add_theme_color_override("font_color", Color(0.3, 0.05, 0.05))
		_vista.add_child(fantasma)
		var c := Label.new()
		c.position = Vector2(CONTADOR_X[k], CONTADOR_Y)
		c.size = Vector2(84, 27)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_theme_font_override("font", _letra)
		c.add_theme_font_size_override("font_size", 22)
		c.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		_vista.add_child(c)
		_contadores.append(c)
	_fx = TextureRect.new()
	_fx.position = Vector2(72, 45)
	_fx.size = Vector2(240, 132)
	_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fx.visible = false
	_vista.add_child(_fx)
	# Los focos del marco (mismos lugares que los de pantalla_juego.png, que quedan abajo) y el letrero
	for k in 20:
		for y in [3, 285]:
			var foco := ColorRect.new()
			foco.size = Vector2(6, 6)
			foco.position = Vector2(9.6 + k * 19.2 - 3.0, y - 3)
			_vista.add_child(foco)
			_focos.append(foco)
	_letrero = Label.new()
	_letrero.add_theme_font_override("font", _letra)
	_letrero.add_theme_font_size_override("font_size", 40)
	_letrero.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2))
	_letrero.add_theme_color_override("font_outline_color", Color(0.5, 0.0, 0.2))
	_letrero.add_theme_constant_override("outline_size", 10)
	_letrero.visible = false
	_vista.add_child(_letrero)


# Degradado vertical para encima de un carrete: negro arriba y abajo, claro en medio
static func _sombra_carrete() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.7)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t


# El premio cruza la pantalla de derecha a izquierda
func _cruzar_letrero(texto: String) -> void:
	_letrero.text = texto
	_letrero.visible = true
	_letrero.reset_size()
	_letrero.position = Vector2(PANTALLA.x, LINEA_Y - _letrero.size.y / 2.0)
	var t := create_tween()
	t.tween_property(_letrero, "position:x", -_letrero.size.x, 2.4)
	t.tween_callback(func() -> void: _letrero.visible = false)


func _process(delta: float) -> void:
	super._process(delta)
	# Los focos del marco corren: de prisa mientras gira o al ganar, despacio si no
	_focos_t += delta
	var paso := FOCOS_PANTALLA * (1.0 if _ocupado or (_letrero and _letrero.visible) else 3.0)
	if _focos_t >= paso:
		_focos_t = 0.0
		_focos_turno = (_focos_turno + 1) % 3
		for i in _focos.size():
			_focos[i].color = FOCO_PRENDIDO if (i / 2) % 3 == _focos_turno else FOCO_APAGADO
	for k in 3:
		if _girando[k]:
			_corrimiento[k] += VELOCIDAD * delta
			while _corrimiento[k] >= CARTA_ALTO:
				_corrimiento[k] -= CARTA_ALTO
				var cartas: Array = _carretes[k][1]
				_copiar_carta(cartas[2], cartas[1])
				_copiar_carta(cartas[1], cartas[0])
				_poner_carta(cartas[0], _al_azar())
			_acomodar(k)
	if _fx_t >= 0.0:
		_fx_t += delta
		var cuadro := int(_fx_t * float(_fx_hoja["fps"]))
		if cuadro >= int(_fx_hoja["cuadros"]):
			_fx_t = -1.0
			_fx.visible = false
		else:
			var col := cuadro % int(_fx_hoja["columnas"])
			var fila := cuadro / int(_fx_hoja["columnas"])
			var tam: Vector2 = _fx_hoja["tamano"]
			(_fx.texture as AtlasTexture).region = Rect2(Vector2(col, fila) * tam, tam)


# Las tres cartas de un carrete: la de en medio centrada en la ventana mas lo que va corrido
func _acomodar(k: int) -> void:
	var cartas: Array = _carretes[k][1]
	var arriba := (CARRETE.y - CARTA_ALTO) / 2.0 - CARTA_ALTO + _corrimiento[k]
	for n in 3:
		cartas[n].position = Vector2(0, arriba + n * CARTA_ALTO)


# El carrete `k` para en la carta `final`, con un rebote
func _parar(k: int, final: int) -> void:
	_girando[k] = false
	var cartas: Array = _carretes[k][1]
	_poner_carta(cartas[0], _al_azar())
	_poner_carta(cartas[1], final)
	_poner_carta(cartas[2], _al_azar())
	_corrimiento[k] = 21.0
	_acomodar(k)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_corrimiento[k] = v
		_acomodar(k), 21.0, 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sonidos.tocar(self, "slot_carrete", -6.0)


func _parpadear_linea() -> void:
	for n in 8:
		for l in _linea:
			l.visible = n % 2 == 0
		await get_tree().create_timer(0.15).timeout
		if not is_inside_tree():
			return
	for l in _linea:
		l.visible = true


func _lanzar_fx(nombre: String) -> void:
	var hoja := EfectosPixel.hoja_de(nombre)
	if hoja.is_empty():
		return
	_fx_hoja = hoja
	var t := AtlasTexture.new()
	t.atlas = hoja["textura"]
	t.region = Rect2(Vector2.ZERO, hoja["tamano"])
	_fx.texture = t
	_fx.size = hoja["tamano"] * 1.5
	_fx.position = Vector2((PANTALLA.x - _fx.size.x) / 2.0, 150.0 - _fx.size.y / 2.0)
	_fx.visible = true
	_fx_t = 0.0


# La carta `i` en un TextureRect del carrete: su dibujo y su nombre (EL GALLO) en la banda
func _poner_carta(c: TextureRect, i: int) -> void:
	c.texture = CartasLoteria.textura(i)
	(c.get_node("Dibujo") as TextureRect).texture = CartasLoteria.dibujo(i)
	c.set_meta("carta", i)
	(c.get_node("Nombre") as Label).text = (CartasLoteria.NOMBRES[i] as String).to_upper()


func _copiar_carta(a: TextureRect, b: TextureRect) -> void:
	_poner_carta(a, int(b.get_meta("carta", 0)))


func _al_azar() -> int:
	var cartas: Array = Carretes.PESOS.keys()
	return cartas[randi() % cartas.size()]


# --- La camara ---

func _acercar_camara() -> void:
	_camara_jugador = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	var ojos := gabinete.to_global(OJOS)
	var mira := gabinete.to_global(MIRA)
	if _camara_jugador:
		_camara.global_transform = _camara_jugador.global_transform
		_camara.fov = _camara_jugador.fov
	_camara.make_current()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", Transform3D(Basis.looking_at(mira - ojos), ojos), TIEMPO_CAMARA)
	tween.tween_property(_camara, "fov", FOV, TIEMPO_CAMARA)
