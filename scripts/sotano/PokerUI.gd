extends JuegoSotano

# La mesa de poker del Sotano: Texas Hold'em de limite fijo (Holdem.gd decide) contra tres vecinos,
# con el crupier de la casa. La camara se acerca a la mesa como en las maquinitas (TragamonedasUI):
# las cartas de en medio y las de los vecinos (boca abajo hasta el final) van sobre el pano en 3D;
# abajo, tus dos cartas, el bote y lo que dijo cada quien. Juegas con tus fichas (Fichas.fichas).
# Las cartas se mueven: el crupier reparte de una en una desde su mazo (vuelan en arco, girando),
# las de en medio salen boca abajo y se voltean, el que se retira avienta las suyas al mazo, al
# final se voltean las de los vecinos y las tuyas entran a la pantalla volteandose.

const BARAJA := preload("res://textures/sotano/baraja.png")
const VECINOS := [["Doña Cuca", "cerrado"], ["El de la gorra", "tramposo"], ["Tacho", "farol"]]
const FICHAS_VECINO := 60
const PIENSA := 0.8                  # s que tarda un vecino en hablar
const CARTA := Vector2(0.12, 0.18)   # m de una carta sobre el pano (escena)
const TIEMPO_CAMARA := 0.6
const FOV := 58.0
const REPARTE := 0.12                # s entre carta y carta al repartir
const VUELA := 0.28                  # s que tarda una carta del mazo a su lugar
const VOLTEA := 0.2                  # s de voltear una carta
const ARCO := 0.09                   # m que sube una carta volando

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
var _mazo := Vector3.ZERO            # de donde salen las cartas: frente al crupier
var _mesa_vista := 0                 # cuantas cartas de en medio ya salieron
var _vecino_fuera: Array[bool] = [false, false, false]
var _ensenado := false
var _repartiendo := false
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
	await _repartir()
	if not is_inside_tree():
		return
	_mostrar()
	_seguir()


# La accion del jugador (C/R/F), solo en su turno
func jugar(accion: String) -> void:
	if not _esperando:
		return
	_esperando = false
	_actuar(0, accion)
	_seguir()


# Una accion en la mesa; si entraron fichas al bote suenan en el pano
func _actuar(i: int, accion: String) -> void:
	var antes := _h.bote
	_h.actuar(i, accion)
	if _h.bote > antes:
		Sonidos.tocar(self, "ficha_mesa", -6.0)
	_mostrar()


# Hablan los vecinos hasta que te toque a ti o acabe la mano
func _seguir() -> void:
	while _h.fase != Holdem.Fase.FIN and _h.turno != 0:
		_ocupado = true
		await get_tree().create_timer(PIENSA).timeout
		if not is_inside_tree():
			return
		var i := _h.turno
		_actuar(i, _h.decidir(i))
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
		Sonidos.tocar(self, "monedas_caen", -5.0)
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
	if not _repartiendo:
		for k in 2:
			_tuyas[k].texture = textura(tu.cartas[k]) if tu.cartas.size() > k else null
	_bote.text = "Bote: %d   ·   Tus fichas: %d" % [_h.bote, tu.fichas]
	for k in 4:
		var j: Dictionary = _h.jugadores[k]
		var turno := " ◀" if _h.turno == k else ""
		var estado: String = "fuera" if j.fuera else j.ultima
		_lineas[k].text = "%s (%d): %s%s" % [j.nombre, j.fichas, estado, turno]
		_lineas[k].modulate = Color(0.6, 0.6, 0.6) if j.fuera else Color.WHITE
	if _cartas_mesa.is_empty() or _repartiendo:
		return
	# En la mesa: las que van saliendo vuelan del mazo boca abajo y se voltean
	var nuevas := 0
	while _mesa_vista < _h.mesa.size():
		_sacar_de_mesa(_mesa_vista, nuevas * REPARTE * 1.5)
		_mesa_vista += 1
		nuevas += 1
	# El que se retira avienta sus cartas al mazo
	for v in _cartas_vecinos.size():
		var j: Dictionary = _h.jugadores[v + 1]
		if j.fuera and not _vecino_fuera[v]:
			_vecino_fuera[v] = true
			for k in 2:
				_tirar_al_mazo(_cartas_vecinos[v][k], k * 0.06)
	# Al final, si hubo quien viera, se voltean las de los vecinos que siguen, una por una
	if al_final and not _ensenado and _h.vivos().size() > 1:
		_ensenado = true
		var n := 0
		for v in _cartas_vecinos.size():
			var j: Dictionary = _h.jugadores[v + 1]
			if j.fuera:
				continue
			for k in 2:
				if j.cartas.size() > k:
					_voltear(_cartas_vecinos[v][k], material(j.cartas[k]), 0.3 + n * 0.25)
			n += 1


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


# --- Las cartas que se mueven ---

# Reparte: dos vueltas, una carta a cada vecino y una a ti, de una en una desde el mazo
func _repartir() -> void:
	_repartiendo = true
	_mesa_vista = 0
	_vecino_fuera = [false, false, false]
	_ensenado = false
	for m in _cartas_mesa:
		m.visible = false
	for par: Array in _cartas_vecinos:
		for m: MeshInstance3D in par:
			m.visible = false
	for r in _tuyas:
		r.texture = null
		r.modulate.a = 0.0
	var tu: Dictionary = _h.jugadores[0]
	var espera := 0.0
	for vuelta in 2:
		for v in _cartas_vecinos.size():
			var m: MeshInstance3D = _cartas_vecinos[v][vuelta]
			m.material_override = material(-1)
			_volar(m, espera)
			espera += REPARTE
		if tu.cartas.size() > vuelta:
			_entrar_tuya(vuelta, tu.cartas[vuelta], espera)
		espera += REPARTE
	await get_tree().create_timer(espera + VUELA + VOLTEA * 2.0).timeout
	_repartiendo = false


# Una carta vuela del mazo a su lugar (meta "casa"), en arco y dando media vuelta
func _volar(m: MeshInstance3D, espera: float) -> Tween:
	var casa: Vector3 = m.get_meta("casa")
	var giro: float = m.get_meta("giro", 0.0)
	m.position = _mazo
	m.rotation = Vector3(0.0, giro + PI, 0.0)
	m.visible = false
	var t := create_tween()
	t.tween_interval(espera)
	t.tween_callback(func() -> void:
		m.visible = true
		Sonidos.tocar(self, "carta", -8.0))
	t.tween_method(func(f: float) -> void:
		m.position = _mazo.lerp(casa, f) + Vector3.UP * sin(f * PI) * ARCO
		m.rotation.y = giro + PI * (1.0 - f), 0.0, 1.0, VUELA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return t


# La carta se levanta, se voltea sobre su largo y enseña `cara` (el material)
func _voltear(m: MeshInstance3D, cara: Material, espera := 0.0) -> void:
	var casa: Vector3 = m.get_meta("casa")
	var t := create_tween()
	t.tween_interval(espera)
	t.tween_method(func(f: float) -> void:
		m.rotation.z = f * PI / 2.0
		m.position = casa + Vector3.UP * f * 0.03, 0.0, 1.0, VOLTEA / 2.0)
	t.tween_callback(func() -> void:
		m.material_override = cara
		Sonidos.tocar(self, "carta", -12.0, 1.2))
	t.tween_method(func(f: float) -> void:
		m.rotation.z = (1.0 - f) * PI / 2.0
		m.position = casa + Vector3.UP * (1.0 - f) * 0.03, 0.0, 1.0, VOLTEA / 2.0)


# Una de en medio: sale boca abajo y al llegar se voltea
func _sacar_de_mesa(k: int, espera: float) -> void:
	var m := _cartas_mesa[k]
	m.material_override = material(-1)
	var t := _volar(m, espera)
	var cara := material(_h.mesa[k])
	t.tween_callback(func() -> void: _voltear(m, cara))


# Al mazo y se esconde (el que se retira)
func _tirar_al_mazo(m: MeshInstance3D, espera: float) -> void:
	if not m.visible:
		return
	var desde := m.position
	var t := create_tween()
	t.tween_interval(espera)
	t.tween_method(func(f: float) -> void:
		m.position = desde.lerp(_mazo, f) + Vector3.UP * sin(f * PI) * ARCO * 0.6
		m.rotation.y += 0.25, 0.0, 1.0, VUELA * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: m.visible = false)


# Tu carta en la pantalla: aparece de reverso y se voltea (escala en x, con el centro de pivote)
func _entrar_tuya(k: int, carta: int, espera: float) -> void:
	var r := _tuyas[k]
	r.pivot_offset = r.custom_minimum_size / 2.0
	var t := create_tween()
	t.tween_interval(espera)
	t.tween_callback(func() -> void:
		r.texture = textura(-1)
		r.scale = Vector2(0.2, 1.0)
		r.modulate.a = 1.0)
	t.tween_property(r, "scale:x", 1.0, VUELA * 0.6)
	t.tween_property(r, "scale:x", 0.0, VOLTEA / 2.0)
	t.tween_callback(func() -> void: r.texture = textura(carta))
	t.tween_property(r, "scale:x", 1.0, VOLTEA / 2.0)


# --- Las cartas sobre el pano y la camara ---

func _armar_cartas_3d() -> void:
	var quad := QuadMesh.new()
	quad.size = CARTA
	quad.orientation = PlaneMesh.FACE_Y
	# El mazo: frente al crupier, sobre el pano
	var crupier: Vector3 = sotano.call("marca", "Crupier").origin
	_mazo = _centro + (Vector3(crupier.x, _centro.y, crupier.z) - _centro).normalized() * 0.55 + Vector3(0, 0.004, 0)
	for k in 5:
		var m := _carta_3d(quad, _centro + Vector3((k - 2) * 0.145, 0.0, 0.05))
		_cartas_mesa.append(m)
	# Las de los vecinos, frente a su silla (Poker_0..2), hacia el centro
	for v in VECINOS.size():
		var silla: Vector3 = sotano.call("marca", "Poker_%d" % v).origin
		var hacia := (_centro - Vector3(silla.x, _centro.y, silla.z)).normalized()
		var p := Vector3(silla.x, _centro.y, silla.z) + hacia * 0.75
		var lado := hacia.cross(Vector3.UP).normalized()
		var giro := atan2(hacia.x, hacia.z)
		var par := [_carta_3d(quad, p + lado * 0.068), _carta_3d(quad, p - lado * 0.068)]
		for m: MeshInstance3D in par:
			m.set_meta("giro", giro)
			m.rotation.y = giro
		_cartas_vecinos.append(par)


func _carta_3d(quad: QuadMesh, donde: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = donde + Vector3(0, 0.002, 0)
	m.set_meta("casa", m.position)
	m.visible = false
	sotano.add_child(m)
	return m


# Como TragamonedasUI: una camara nueva vuela de la del jugador a ver la mesa desde tu silla
func _acercar_camara() -> void:
	_camara_jugador = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	var silla: Vector3 = sotano.call("marca", "Poker_tu").origin
	var ojos := sotano.to_global(Vector3(silla.x, _centro.y + 0.85, silla.z + 0.15))
	var mira := sotano.to_global(_centro + Vector3(0, 0, -0.1))
	if _camara_jugador:
		_camara.global_transform = _camara_jugador.global_transform
		_camara.fov = _camara_jugador.fov
	_camara.make_current()
	var destino := Transform3D(Basis.looking_at(mira - ojos), ojos)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camara, "global_transform", destino, TIEMPO_CAMARA)
	tween.tween_property(_camara, "fov", FOV, TIEMPO_CAMARA)
