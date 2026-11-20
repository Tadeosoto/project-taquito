extends JuegoSotano

# Las carreras de caballitos del Sotano: cinco caballitos de lamina en su riel (Caballo_1..5 del
# cuarto, los mueve Sotano.correr). Le apuestas a uno con su momio; si llega primero te paga la
# apuesta por el momio. La probabilidad de cada uno es 1/momio repartida (la casa se queda ~20 %,
# como en la feria). Trampa: si la apuesta es grande (APUESTA_FUERTE o mas) a tu caballo le toca
# FRENO de su suerte. Sena: antes de arrancar, el que la casa quiere que gane "se ve nervioso"
# (tiembla en su riel) cuando hay trampa.

const MOMIOS := [2, 3, 5, 8, 12]
const COLORES := ["rojo", "azul", "amarillo", "verde", "morado"]
const APUESTA_MAX := 10
const APUESTA_FUERTE := 5
const FRENO := 0.5

var sotano: Node                     # el cuarto (Sotano.gd): mueve los caballitos

# La camara de la tele (AG 2026-11-19: la de antes la tapaban el jugador o la gente): alta, sobre el
# lado sur de la isla, entre los tubos de luz y la cabeza de los que pasan, viendo hacia abajo y
# siguiendo al que va adelante. En metros del cuarto, desde los caballitos
const CAMARA_ALTO := 1.15            # sobre los caballitos (el techo esta a ~1.5; los tubos, a ~1.2 pero en z 5.4)
const CAMARA_SUR := 1.0              # hacia el sur de la fila de caballitos
const CAMARA_ATRAS := 0.9            # detras del puntero
const CAMARA_FOV := 62.0
const CAMARA_TIEMPO := 0.6
# Los efectos (resources/fx): polvo atras de cada uno, brillo sobre el tuyo, confeti en la meta
const POLVO_CADA := 0.12
const BRILLO_CADA := 0.35

var _caballo := 0
var _camara: Camera3D
var _camara_jugador: Camera3D
var _apuesta := 1
var _elegido: Label
var _rng := RandomNumberGenerator.new()
var _corriendo := false
var _polvo_t := 0.0
var _brillo_t := 0.0
var _tele: Control                   # lo de la tele: EN VIVO, quien va adelante
var _lugares: Label
var _vivo: Label


func _init() -> void:
	titulo = "Las carreras de caballitos"
	ayuda = AYUDA_FILA


func _armar() -> void:
	_rng.randomize()
	for i in 5:
		contenido.add_child(etiqueta("%d  El %s · paga %d a 1" % [i + 1, COLORES[i], MOMIOS[i]], 16))
	_elegido = etiqueta("", 18, AMARILLO)
	_elegido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(_elegido)
	_mostrar()


func _caballos() -> Array:
	return sotano.get("_caballos") if sotano else []


# Donde va la camara para ver al puntero (en global): alta al sur, un poco atras, viendo hacia abajo
func _toma() -> Transform3D:
	var cs := _caballos()
	if cs.is_empty():
		return Transform3D()
	var s := sotano as Node3D
	var x := -INF
	var z := 0.0
	var y := 0.0
	for c: Node3D in cs:
		x = maxf(x, c.position.x)
		z += c.position.z
		y += c.position.y
	z /= cs.size()
	y /= cs.size()
	x = minf(x, float(sotano.get("PISTA_META")) - 0.4)    # en la meta se queda
	var ojos := s.to_global(Vector3(x - CAMARA_ATRAS, y + CAMARA_ALTO, z + CAMARA_SUR))
	var mira := s.to_global(Vector3(x + 0.5, y, z))
	return Transform3D(Basis.looking_at(mira - ojos), ojos)


func _ver_pista() -> void:
	_camara_jugador = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	if _camara_jugador:
		_camara.global_transform = _camara_jugador.global_transform
		_camara.fov = _camara_jugador.fov
	_camara.make_current()
	if _player is Node3D:
		(_player as Node3D).visible = false
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", _toma(), CAMARA_TIEMPO)
	tween.tween_property(_camara, "fov", CAMARA_FOV, CAMARA_TIEMPO)
	await tween.finished
	_armar_tele()


func _regresar_camara() -> void:
	if _player is Node3D:
		(_player as Node3D).visible = true
	if _tele:
		_tele.queue_free()
		_tele = null
	if _camara_jugador:
		_camara_jugador.make_current()
	if _camara:
		_camara.queue_free()
		_camara = null


func cerrar() -> void:
	_regresar_camara()
	super.cerrar()


func _tecla(codigo: int) -> void:
	if _ocupado:
		return
	match codigo:
		KEY_UP, KEY_W:
			_caballo = posmod(_caballo - 1, 5)
		KEY_DOWN, KEY_S:
			_caballo = posmod(_caballo + 1, 5)
		KEY_LEFT, KEY_A:
			_apuesta = maxi(_apuesta - 1, 1)
		KEY_RIGHT, KEY_D:
			_apuesta = mini(_apuesta + 1, APUESTA_MAX)
		KEY_SPACE, KEY_ENTER:
			arrancar()
			return
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_caballo = codigo - KEY_1
	_mostrar()


func arrancar() -> void:
	if _ocupado:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No te alcanzan las fichas.")
		return
	_ocupado = true
	var trampa := _apuesta >= APUESTA_FUERTE
	var ganador := elegir_ganador(_caballo, trampa)
	_panel.visible = false
	_oscuro.visible = false
	_fila_botones.visible = false
	if sotano and sotano.has_method("correr"):
		# Si estan corriendo los de afuera (VidaSotano), espera a que acaben
		while sotano.get("corriendo"):
			await get_tree().create_timer(0.1).timeout
		await _ver_pista()
		if trampa:
			await sotano.temblar(ganador)
		await _cuenta()
		Sonidos.tocar(self, "caballitos", -6.0)
		_corriendo = true
		await sotano.correr(ganador)
		_corriendo = false
		await _meta(ganador)
		_regresar_camara()
	_panel.visible = true
	_oscuro.visible = true
	_fila_botones.visible = true
	if ganador == _caballo:
		var pago: int = _apuesta * MOMIOS[_caballo]
		f.fichas += pago
		Sonidos.tocar(self, "monedas_caen", -5.0)
		avisar("¡Llegó el %s! Te pagan %d fichas." % [COLORES[_caballo], pago])
	else:
		avisar("Ganó el %s. \"Ese caballito siempre arranca dormido\", dice el de junto." % COLORES[ganador])
	_ocupado = false


# --- La tele de la carrera ---

func _process(delta: float) -> void:
	super._process(delta)
	if not _corriendo or _camara == null:
		return
	_camara.global_transform = _camara.global_transform.interpolate_with(_toma(), minf(delta * 5.0, 1.0))
	var cs := _caballos()
	_polvo_t += delta
	if _polvo_t >= POLVO_CADA:
		_polvo_t = 0.0
		for c: Node3D in cs:
			_efecto_en("lodo_choque" if _rng.randf() < 0.5 else "impacto_seco", c.global_position, 0.5)
	_brillo_t += delta
	if _brillo_t >= BRILLO_CADA and _caballo < cs.size():
		_brillo_t = 0.0
		_efecto_en("recoger_brillo", (cs[_caballo] as Node3D).global_position + Vector3.UP * 0.35, 0.8)
	if _vivo:
		_vivo.visible = fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.3
	# Quien va adelante, como en la tele
	if _lugares:
		var orden := range(cs.size())
		orden.sort_custom(func(a: int, b: int) -> bool: return (cs[a] as Node3D).position.x > (cs[b] as Node3D).position.x)
		var lineas := PackedStringArray()
		for k in orden.size():
			var i: int = orden[k]
			lineas.append("%d. %s%s" % [k + 1, COLORES[i], "  ◀ tú" if i == _caballo else ""])
		_lugares.text = "\n".join(lineas)


func _armar_tele() -> void:
	_tele = Control.new()
	_tele.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tele)
	_vivo = etiqueta("● EN VIVO", 16, Color(1.0, 0.2, 0.2))
	_vivo.position = Vector2(10, 8)
	_tele.add_child(_vivo)
	var nombre := etiqueta("HIPÓDROMO DEL SÓTANO", 14, AMARILLO)
	nombre.position = Vector2(10, 28)
	_tele.add_child(nombre)
	_lugares = etiqueta("", 14)
	_lugares.position = Vector2(10, 52)
	_tele.add_child(_lugares)
	# Bandas de cine arriba y abajo
	for arriba in [true, false]:
		var banda := ColorRect.new()
		banda.color = Color(0, 0, 0, 0.85)
		banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banda.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
		banda.custom_minimum_size = Vector2(0, 6)
		_tele.add_child(banda)


# 3, 2, 1, ¡ARRANCAN! con su onda en pantalla
func _cuenta() -> void:
	for texto in ["3", "2", "1", "¡ARRANCAN!"]:
		var l := etiqueta(texto, 40 if texto.length() == 1 else 32, AMARILLO)
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.pivot_offset = l.get_combined_minimum_size() / 2.0
		add_child(l)
		var t := create_tween()
		t.tween_property(l, "scale", Vector2.ONE * 1.6, 0.35).from(Vector2.ONE * 0.6).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.25)
		t.tween_callback(l.queue_free)
		Sonidos.tocar(self, "boton", -6.0, 1.6 if texto.length() > 1 else 1.0)
		_efecto("fase_onda" if texto.length() > 1 else "fogonazo_auto", 1.2)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return


# La foto final: un flashazo, confeti en la meta y lo tuyo (monedas o humo)
func _meta(ganador: int) -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.5)
	get_tree().create_timer(0.6).timeout.connect(flash.queue_free)
	Sonidos.tocar(self, "boton", -2.0, 0.5)
	var cs := _caballos()
	if ganador < cs.size():
		var donde := (cs[ganador] as Node3D).global_position
		_efecto_en("olpley_confeti", donde + Vector3.UP * 0.3, 1.3)
		_efecto_en("tazo_rayos", donde, 1.0)
		if ganador == _caballo:
			_efecto_en("premio_monedas", donde + Vector3.UP * 0.2, 1.2)
		elif _caballo < cs.size():
			_efecto_en("muerte_humo", (cs[_caballo] as Node3D).global_position, 0.8)
	await get_tree().create_timer(1.2).timeout


# Un efecto de resources/fx dibujado en pantalla sobre un punto del mundo (lo ve la camara de la tele)
func _efecto_en(nombre: String, donde: Vector3, escala := 1.0) -> void:
	if _camara == null or _camara.is_position_behind(donde):
		return
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
	cuadro.position = _camara.unproject_position(donde) - cuadro.size / 2.0
	add_child(cuadro)
	var cuadros := int(hoja["cuadros"])
	var columnas := int(hoja["columnas"])
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		var i := mini(int(f), cuadros - 1)
		atlas.region = Rect2(Vector2(i % columnas, i / columnas) * tam, tam), 0.0, float(cuadros), cuadros / float(hoja["fps"]))
	t.tween_callback(cuadro.queue_free)


# El que gana: al azar con 1/momio, y con trampa tu caballo pierde FRENO de su suerte
func elegir_ganador(tuyo: int, trampa: bool) -> int:
	var pesos: Array[float] = []
	var total := 0.0
	for i in 5:
		var p: float = 1.0 / MOMIOS[i]
		if trampa and i == tuyo:
			p *= FRENO
		pesos.append(p)
		total += p
	var tiro := _rng.randf() * total
	for i in 5:
		tiro -= pesos[i]
		if tiro <= 0.0:
			return i
	return 0


func _mostrar() -> void:
	_elegido.text = "Al %s (%d)  ·  %d ficha%s" % [COLORES[_caballo], _caballo + 1, _apuesta, "" if _apuesta == 1 else "s"]


# La fila: un boton por caballito (el tuyo marcado), la apuesta y a correr
func _armar_botones() -> void:
	var lista := []
	for k in COLORES.size():
		lista.append({"texto": str(COLORES[k]).capitalize(), "hacer": func() -> void:
				_caballo = k
				_mostrar(),
			"marcado": func() -> bool: return _caballo == k})
	botones(lista + botones_apuesta(func() -> String: return "%d fichas" % _apuesta,
			func(paso: int) -> void: _tecla(KEY_RIGHT if paso > 0 else KEY_LEFT), func() -> bool: return true) + [
		{"texto": "¡Arrancan!", "hacer": _tecla.bind(KEY_SPACE), "principal": true}])
