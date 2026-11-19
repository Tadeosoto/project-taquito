extends JuegoSotano

# Jugar en una maquinita OL PLEY del Sotano, como en las de frutas (TragamonedasUI): la camara se
# acerca al gabinete y el juego corre EN SU PANTALLA (un SubViewport de 256 x 192 que el gabinete
# enseña: GabineteOlPley.mostrar_en_pantalla). Carretes.gd decide; aqui solo se muestra.
# La "Loteria de carretes": tres carretes con cartas de la loteria (CartasLoteria) que ruedan de
# verdad y paran uno tras otro, la linea de premio que parpadea, los contadores, y al ganar monedas
# o (con El Tinaco) confeti de pixelfx (resources/fx/olpley_*). Los botones del gabinete se hunden.
# El fondo de la pantalla es textures/sotano/pantalla_juego.png (tools/blender/sotano/arte.py).

const FONDO_PANTALLA := preload("res://textures/sotano/pantalla_juego.png")
const PANTALLA := Vector2i(256, 192)
const CARRETE_X := [24, 96, 168]
const CARRETE_Y := 34
const CARRETE := Vector2(64, 112)
const CARTA_ALTO := 96.0
const LINEA_Y := 90                 # la linea de premio, a media ventana
const CONTADOR_X := [16, 96, 176]
const CONTADOR_Y := 166
const GIRO := [0.8, 1.15, 1.5]      # s que gira cada carrete antes de parar
const VELOCIDAD := 900.0            # px/s de los carretes girando
const OJOS := Vector3(0.0, 1.33, 0.62)   # la camara, en el gabinete
const MIRA := Vector3(0.0, 1.26, 0.1)
const FOV := 42.0
const TIEMPO_CAMARA := 0.6
const AYUDA := "←/→ apuesta  ·  Espacio jalar  ·  Esc salir"

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


func _init() -> void:
	titulo = "OL PLEY"
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
			_apretar("Boton_0")
		KEY_RIGHT, KEY_D:
			_apuesta = mini(_apuesta + 1, Carretes.APUESTA_MAX)
			_apretar("Boton_1")
		KEY_SPACE, KEY_ENTER:
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


func _apretar(boton: String) -> void:
	if gabinete:
		gabinete.apretar(boton)
	Sonidos.tocar(self, "boton", -10.0)


func jalar() -> void:
	if _ocupado:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	_ocupado = true
	_premio = 0
	_apretar("Boton_grande")
	_contar_pantalla()
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
		Sonidos.tocar(self, "moneda", -4.0)
		var tinaco: bool = final.has(CartasLoteria.TINACO) and pago > _apuesta
		var grande: bool = final.count(CartasLoteria.TINACO) == 3 or pago >= _apuesta * 20
		_lanzar_fx("olpley_confeti" if grande or tinaco else "olpley_monedas")
		_parpadear_linea()
		avisar(("¡%d fichas! El Tinaco paga doble." if tinaco else "¡Ganaste %d fichas!") % pago)
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
			c.size = Vector2(64, CARTA_ALTO)
			c.texture = CartasLoteria.textura(arranque[k] if n == 1 else _al_azar())
			recorte.add_child(c)
			cartas.append(c)
		_carretes.append([recorte, cartas])
		_acomodar(k)
	# La linea de premio: dos rayas que parpadean al ganar
	for y in [LINEA_Y - 49, LINEA_Y + 48]:
		var l := ColorRect.new()
		l.color = Color(1.0, 0.95, 0.3)
		l.position = Vector2(16, y)
		l.size = Vector2(224, 2)
		l.visible = false
		_vista.add_child(l)
		_linea.append(l)
	for k in 3:
		var c := Label.new()
		c.position = Vector2(CONTADOR_X[k], CONTADOR_Y)
		c.size = Vector2(64, 18)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_theme_font_size_override("font_size", 14)
		c.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		_vista.add_child(c)
		_contadores.append(c)
	_fx = TextureRect.new()
	_fx.position = Vector2(48, 30)
	_fx.size = Vector2(160, 88)
	_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fx.visible = false
	_vista.add_child(_fx)


func _process(delta: float) -> void:
	super._process(delta)
	for k in 3:
		if _girando[k]:
			_corrimiento[k] += VELOCIDAD * delta
			while _corrimiento[k] >= CARTA_ALTO:
				_corrimiento[k] -= CARTA_ALTO
				var cartas: Array = _carretes[k][1]
				cartas[2].texture = cartas[1].texture
				cartas[1].texture = cartas[0].texture
				cartas[0].texture = CartasLoteria.textura(_al_azar())
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
	cartas[0].texture = CartasLoteria.textura(_al_azar())
	cartas[1].texture = CartasLoteria.textura(final)
	cartas[2].texture = CartasLoteria.textura(_al_azar())
	_corrimiento[k] = 14.0
	_acomodar(k)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_corrimiento[k] = v
		_acomodar(k), 14.0, 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sonidos.tocar(self, "paso", -8.0)


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
	_fx.size = hoja["tamano"]
	_fx.position = Vector2((PANTALLA.x - _fx.size.x) / 2.0, 60.0 - _fx.size.y / 2.0 + 40.0)
	_fx.visible = true
	_fx_t = 0.0


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
