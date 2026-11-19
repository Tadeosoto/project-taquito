extends JuegoSotano

# La mesa de poker del Sotano: Texas Hold'em de limite fijo (Holdem.gd decide) contra tres vecinos,
# con el crupier de la casa. La camara se acerca a la mesa como en las maquinitas (TragamonedasUI):
# las cartas de en medio y las de los vecinos (boca abajo hasta el final) van sobre el pano en 3D;
# abajo, tus dos cartas, el bote y lo que dijo cada quien. Juegas con tus fichas (Fichas.fichas).

const BARAJA := preload("res://textures/sotano/baraja.png")
const VECINOS := [["Doña Cuca", "cerrado"], ["El de la gorra", "tramposo"], ["Tacho", "farol"]]
const FICHAS_VECINO := 60
const PIENSA := 0.8                  # s que tarda un vecino en hablar
const CARTA := Vector2(0.09, 0.135)  # m de una carta sobre el pano (escena)
const TIEMPO_CAMARA := 0.6
const FOV := 58.0

static var _fichas_vecinos := [FICHAS_VECINO, FICHAS_VECINO, FICHAS_VECINO]

var sotano: Node3D

var _h: Holdem
var _camara: Camera3D
var _camara_jugador: Camera3D
var _tuyas: Array[TextureRect] = []
var _bote: Label
var _lineas: Array[Label] = []
var _cartas_mesa: Array[MeshInstance3D] = []
var _cartas_vecinos: Array = []      # por vecino, sus dos MeshInstance3D
var _esperando := false
var _centro := Vector3.ZERO          # el centro del pano, en la escena del Sotano
static var _materiales := {}


func _init() -> void:
	titulo = "Póker"
	ayuda = "C pasar / ir  ·  R subir  ·  F retirarte  ·  Espacio otra mano  ·  Esc levantarte"


func _armar() -> void:
	_panel.visible = false
	_oscuro.visible = false
	_h = Holdem.new()
	_h.agregar("Tú", fichas(), "tu")
	for k in VECINOS.size():
		_h.agregar(VECINOS[k][0], _fichas_vecinos[k], VECINOS[k][1])
	_armar_pantalla()
	if sotano:
		_centro = sotano.call("marca", "Poker").origin - Vector3(0, 0, 1.8) + Vector3(0, 0.79, 0)
		_armar_cartas_3d()
		_acercar_camara()
	nueva_mano()


func cerrar() -> void:
	if _esperando or _h.fase == Holdem.Fase.FIN:
		_guardar_fichas()
	for m in _cartas_mesa:
		m.queue_free()
	for par: Array in _cartas_vecinos:
		for m: Node in par:
			m.queue_free()
	if _camara_jugador:
		_camara_jugador.make_current()
	if _camara:
		_camara.queue_free()
	super.cerrar()


func _tecla(codigo: int) -> void:
	match codigo:
		KEY_C:
			jugar("pasar")
		KEY_R:
			jugar("subir")
		KEY_F:
			jugar("retirarse")
		KEY_SPACE, KEY_ENTER:
			if _h.fase == Holdem.Fase.FIN:
				nueva_mano()


func nueva_mano() -> void:
	_guardar_fichas()
	for k in VECINOS.size():
		var j: Dictionary = _h.jugadores[k + 1]
		if j.fichas < Holdem.CIEGA_GRANDE * 2:
			j.fichas = FICHAS_VECINO    # se va a la ventanilla y regresa
	_h.jugadores[0].fichas = fichas()
	if _h.jugadores[0].fichas < Holdem.CIEGA_GRANDE:
		avisar("\"Sin fichas no hay mesa, mijo\", dice el crupier.")
		return
	if not _h.empezar():
		return
	avisar("Reparte el crupier. Ciegas de %d y %d." % [Holdem.CIEGA_CHICA, Holdem.CIEGA_GRANDE], 2.0)
	_mostrar()
	_seguir()


# La accion del jugador (C/R/F), solo en su turno
func jugar(accion: String) -> void:
	if not _esperando:
		return
	_esperando = false
	_h.actuar(0, accion)
	_mostrar()
	_seguir()


# Hablan los vecinos hasta que te toque a ti o acabe la mano
func _seguir() -> void:
	while _h.fase != Holdem.Fase.FIN and _h.turno != 0:
		_ocupado = true
		await get_tree().create_timer(PIENSA).timeout
		if not is_inside_tree():
			return
		var i := _h.turno
		_h.actuar(i, _h.decidir(i))
		_mostrar()
	_ocupado = false
	if _h.fase == Holdem.Fase.FIN:
		_fin_de_mano()
	else:
		_esperando = true
		var debe := _h.por_igualar(0)
		avisar(("Te toca: van %d. C para ir, R para subir a %d, F para irte." % [debe, debe + _h.tamano_subida()]) if debe > 0
			else "Te toca: C para pasar, R para subir %d." % _h.tamano_subida(), 30.0)


func _fin_de_mano() -> void:
	_esperando = false
	_mostrar(true)
	var nombres: Array = _h.ganadores.map(func(i: int) -> String: return _h.jugadores[i].nombre)
	var gana := " y ".join(nombres)
	var texto := ("Ganas" if _h.ganadores == [0] else "Gana %s" % gana)
	if _h.mano_ganadora != "":
		texto += " con %s" % _h.mano_ganadora.to_lower()
	texto += ". La casa se queda %d." % _h.rake if _h.rake > 0 else "."
	if _h.ganadores.has(0):
		Sonidos.tocar(self, "moneda", -4.0)
	_guardar_fichas()
	avisar(texto + "  (Espacio otra mano)", 30.0)


func _guardar_fichas() -> void:
	if _h == null or _h.jugadores.is_empty():
		return
	var f := get_node_or_null("/root/Fichas")
	if f and _h.fase == Holdem.Fase.FIN:
		f.fichas = _h.jugadores[0].fichas
	for k in VECINOS.size():
		_fichas_vecinos[k] = _h.jugadores[k + 1].fichas


# --- Pantalla ---

func _armar_pantalla() -> void:
	var abajo := HBoxContainer.new()
	abajo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	abajo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	abajo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	abajo.offset_bottom = -26.0
	abajo.add_theme_constant_override("separation", 6)
	add_child(abajo)
	for k in 2:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(64, 96)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		abajo.add_child(r)
		_tuyas.append(r)
	var lado := VBoxContainer.new()
	add_child(lado)
	lado.position = Vector2(8, 8)
	_bote = etiqueta("", 16, AMARILLO)
	lado.add_child(_bote)
	for k in 4:
		var l := etiqueta("", 13)
		lado.add_child(l)
		_lineas.append(l)
	lado.add_child(etiqueta(ayuda.replace("  ·  ", "
"), 12, Color(0.85, 0.82, 0.78)))
	# El aviso del recuadro (escondido) se muestra arriba al centro
	_aviso.reparent(self)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.offset_top = 132.0


func _mostrar(al_final := false) -> void:
	var tu: Dictionary = _h.jugadores[0]
	for k in 2:
		_tuyas[k].texture = textura(tu.cartas[k]) if tu.cartas.size() > k else null
	_bote.text = "Bote: %d   ·   Tus fichas: %d" % [_h.bote, tu.fichas]
	for k in 4:
		var j: Dictionary = _h.jugadores[k]
		var turno := " ◀" if _h.turno == k else ""
		var estado: String = "fuera" if j.fuera else j.ultima
		_lineas[k].text = "%s (%d): %s%s" % [j.nombre, j.fichas, estado, turno]
		_lineas[k].modulate = Color(0.6, 0.6, 0.6) if j.fuera else Color.WHITE
	# En la mesa
	for k in _cartas_mesa.size():
		var hay := k < _h.mesa.size()
		_cartas_mesa[k].visible = hay
		if hay:
			_cartas_mesa[k].material_override = material(_h.mesa[k])
	for v in _cartas_vecinos.size():
		var j: Dictionary = _h.jugadores[v + 1]
		for k in 2:
			var m: MeshInstance3D = _cartas_vecinos[v][k]
			m.visible = not j.fuera and j.cartas.size() > k
			var ensena: bool = al_final and _h.vivos().size() > 1 and not j.fuera
			m.material_override = material(j.cartas[k] if ensena and j.cartas.size() > k else -1)


# La carta `c` (o el reverso con -1) del atlas de la baraja
static func textura(c: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = BARAJA
	var col := 13 if c < 0 else c % 13
	var fila := 0 if c < 0 else c / 13
	t.region = Rect2(col * 64, fila * 96, 64, 96)
	return t


static func material(c: int) -> StandardMaterial3D:
	if not _materiales.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_texture = BARAJA
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var col := 13 if c < 0 else c % 13
		var fila := 0 if c < 0 else c / 13
		m.uv1_scale = Vector3(1.0 / 14.0, 1.0 / 4.0, 1.0)
		m.uv1_offset = Vector3(col / 14.0, fila / 4.0, 0.0)
		m.roughness = 0.8
		_materiales[c] = m
	return _materiales[c]


# --- Las cartas sobre el pano y la camara ---

func _armar_cartas_3d() -> void:
	var quad := QuadMesh.new()
	quad.size = CARTA
	quad.orientation = PlaneMesh.FACE_Y
	for k in 5:
		var m := _carta_3d(quad, _centro + Vector3((k - 2) * 0.11, 0.0, 0.05))
		_cartas_mesa.append(m)
	# Las de los vecinos, frente a su silla (Poker_0..2), hacia el centro
	for v in VECINOS.size():
		var silla: Vector3 = sotano.call("marca", "Poker_%d" % v).origin
		var hacia := (_centro - Vector3(silla.x, _centro.y, silla.z)).normalized()
		var p := Vector3(silla.x, _centro.y, silla.z) + hacia * 0.75
		var lado := hacia.cross(Vector3.UP).normalized()
		_cartas_vecinos.append([_carta_3d(quad, p + lado * 0.05), _carta_3d(quad, p - lado * 0.05)])


func _carta_3d(quad: QuadMesh, donde: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = donde + Vector3(0, 0.002, 0)
	m.visible = false
	sotano.add_child(m)
	return m


# Como TragamonedasUI: una camara nueva vuela de la del jugador a ver la mesa desde tu silla
func _acercar_camara() -> void:
	_camara_jugador = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	var silla: Vector3 = sotano.call("marca", "Poker_tu").origin
	var ojos := sotano.to_global(Vector3(silla.x, _centro.y + 1.35, silla.z + 0.15))
	var mira := sotano.to_global(_centro + Vector3(0, 0, -0.1))
	if _camara_jugador:
		_camara.global_transform = _camara_jugador.global_transform
		_camara.fov = _camara_jugador.fov
	_camara.make_current()
	var destino := Transform3D(Basis.looking_at(mira - ojos), ojos)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", destino, TIEMPO_CAMARA)
	tween.tween_property(_camara, "fov", FOV, TIEMPO_CAMARA)
