extends JuegoSotano

# La mesa de baccarat del Sotano (Baccarat.gd decide): le vas al PUNTO, a la BANCA o al EMPATE y el
# crupier ("Don Chepe") reparte las dos manos carta por carta, volteandolas: sobre el pano (salen del
# zapato en arco y se voltean; el punto a la izquierda, la banca a la derecha) y en la pantalla. Juegas
# con tus fichas. La sena de la trampa: Don Chepe le sopla a las cartas y vuelve a barajar.

const POKER := preload("res://scripts/sotano/PokerUI.gd")   # su textura(c) de la baraja
const APUESTA_MAX := 10
const VOLTEA := 0.2
const REPARTE := 0.35
const CAMARA_DESDE := Vector3(0.0, 1.75, 0.1)  # desde la marca Baccarat (m de la escena): casi desde arriba, que se lea el pano
const CAMARA_MIRA := Vector3(0.0, 0.85, -1.05)
const NOMBRES := {"punto": "PUNTO", "banca": "BANCA", "empate": "EMPATE"}
# Las cartas en el pano (metros de la escena; la mesa mide 2.0 x 1.0, sotano.py BACCARAT)
const CARTA := Vector2(0.12, 0.18)
const MANO_X := 0.4                 # cuanto se separa cada mano del centro (punto a la izquierda)
const CARTA_SEPARA := 0.135
const ZAPATO := Vector2(0.8, 0.19)   # el zapato: x desde el centro, z desde la orilla del crupier
const VUELA := 0.3
const COLOR_UI := {"punto": Color(0.45, 0.65, 1.0), "banca": Color(1.0, 0.35, 0.3), "empate": Color(1.0, 0.85, 0.2)}

var sotano: Node3D

var _bac := Baccarat.new()
var _tipo := 0
var _apuesta := 1
var _fila_punto: HBoxContainer
var _fila_banca: HBoxContainer
var _total_punto: Label
var _total_banca: Label
var _info: Label
var _cartas: Array[TextureRect] = []
var _mesa: Array[MeshInstance3D] = []   # las cartas sobre el pano
var _pila: PilaFichas                # tu apuesta, sobre la casilla (Marca_Baccarat_banca / _empate / _punto)
var _pago: PilaFichas


func _init() -> void:
	titulo = "Baccarat"
	ayuda = "↑/↓ punto, banca o empate  ·  ←/→ apuesta  ·  Espacio repartir  ·  Esc levantarte"


func _armar() -> void:
	_panel.visible = false
	_oscuro.visible = false
	_total_punto = etiqueta("PUNTO", 16, COLOR_UI.punto)
	_total_banca = etiqueta("BANCA", 16, COLOR_UI.banca)
	_fila_punto = HBoxContainer.new()
	_fila_banca = HBoxContainer.new()
	for fila: HBoxContainer in [_fila_punto, _fila_banca]:
		fila.add_theme_constant_override("separation", 4)
	var mesa := HBoxContainer.new()
	mesa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mesa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mesa.offset_top = 10.0
	mesa.add_theme_constant_override("separation", 40)
	add_child(mesa)
	for par in [[_total_punto, _fila_punto], [_total_banca, _fila_banca]]:
		var columna := VBoxContainer.new()
		(par[0] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(par[0])
		columna.add_child(par[1])
		mesa.add_child(columna)
	_info = etiqueta("", 16, AMARILLO)
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.offset_bottom = -40.0
	add_child(_info)
	var a := etiqueta(ayuda.replace("  ·  ", "\n"), 12, Color(0.85, 0.82, 0.78))
	a.position = Vector2(8, 330)
	add_child(a)
	_aviso.reparent(self)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aviso.offset_bottom = -64.0
	if sotano:
		var m: Vector3 = sotano.call("marca", "Baccarat").origin
		acercar_camara(sotano.to_global(m + CAMARA_DESDE), sotano.to_global(m + CAMARA_MIRA), 56.0)
	_mostrar()
	avisar("\"¿Punto o banca, joven?\", dice Don Chepe.", 4.0)


func _tecla(codigo: int) -> void:
	if _ocupado:
		return
	match codigo:
		KEY_UP, KEY_W:
			_tipo = posmod(_tipo - 1, 3)
		KEY_DOWN, KEY_S:
			_tipo = posmod(_tipo + 1, 3)
		KEY_LEFT, KEY_A:
			_apuesta = maxi(_apuesta - 1, 1)
			Sonidos.tocar(self, "apuesta_sube", -8.0, 0.9)
		KEY_RIGHT, KEY_D:
			_apuesta = mini(_apuesta + 1, APUESTA_MAX)
			Sonidos.tocar(self, "apuesta_sube", -8.0)
		KEY_SPACE, KEY_ENTER:
			repartir()
	_mostrar()


func repartir() -> void:
	if _ocupado:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	var apostado: String = Baccarat.APUESTAS[_tipo]
	Sonidos.tocar(self, "ficha_mesa", -5.0)
	_acomodar_pila()
	_ocupado = true
	_bac.jugar(apostado, _apuesta)
	if _bac.arreglo:
		avisar("Don Chepe le sopla a las cartas y vuelve a barajar.", 2.5)
	for r in _cartas:
		r.queue_free()
	_cartas.clear()
	_recoger_mesa()
	_total_punto.text = "PUNTO"
	_total_banca.text = "BANCA"
	# Como en la mesa: punto, banca, punto, banca, y las terceras si las hay
	var orden := [[true, 0], [false, 0], [true, 1], [false, 1]]
	if _bac.punto.size() > 2:
		orden.append([true, 2])
	if _bac.banca.size() > 2:
		orden.append([false, 2])
	for paso: Array in orden:
		var es_punto: bool = paso[0]
		var k: int = paso[1]
		_entrar(es_punto, (_bac.punto if es_punto else _bac.banca)[k])
		await get_tree().create_timer(REPARTE).timeout
		if not is_inside_tree():
			return
		var lista: Array = (_bac.punto if es_punto else _bac.banca).slice(0, k + 1)
		(_total_punto if es_punto else _total_banca).text = "%s %d" % ["PUNTO" if es_punto else "BANCA", Baccarat.valor(lista)]
	var gana := _bac.pago(apostado, _apuesta)
	if gana > 0:
		f.fichas += gana
		Sonidos.tocar(self, "monedas_caen", -5.0)
	# Las fichas: el crupier paga junto a tu pila y te las acerca, o se las lleva
	var empate_regresa := _bac.ganador == "empate" and apostado != "empate"
	if gana > _apuesta:
		festejar(true, gana)
		_pago = _nueva_pila(gana - _apuesta, _lugar("Crupier_baccarat") + Vector3(0, 0.82, 0))
		_pago.ir_a(_lugar("Baccarat_" + apostado) + Vector3(0.075, 0, 0), 0.4)
		await get_tree().create_timer(0.9).timeout
		_llevar_pilas(_lugar("Baccarat") + Vector3(0, 0.82, -0.3))
	elif empate_regresa:
		await get_tree().create_timer(0.5).timeout
		_llevar_pilas(_lugar("Baccarat") + Vector3(0, 0.82, -0.3))
	else:
		festejar(false)
		_llevar_pilas(_lugar("Crupier_baccarat") + Vector3(0, 0.82, 0))
	var texto := "Gana %s. " % NOMBRES[_bac.ganador]
	if _bac.ganador == "empate" and apostado != "empate":
		texto += "Te regresan tus %d." % gana
	elif gana > 0:
		texto += "Te pagan %d fichas." % gana
	else:
		texto += "Se la lleva la casa."
	avisar(texto + "  (Espacio otra)", 30.0)
	_ocupado = false
	_mostrar()


# --- Las cartas sobre el pano ---

func _centro_mesa() -> Vector3:
	var crupier: Vector3 = _lugar("Crupier_baccarat")
	var empate: Vector3 = _lugar("Baccarat_empate")
	return Vector3(crupier.x, empate.y + 0.003, empate.z)


func _zapato() -> Vector3:
	var crupier: Vector3 = _lugar("Crupier_baccarat")
	return Vector3(crupier.x + ZAPATO.x, _centro_mesa().y + 0.1, crupier.z + 0.45 + ZAPATO.y)


# Una carta sale del zapato boca abajo, vuela en arco a su lugar (punto a la izquierda, banca a la
# derecha, una junto a otra; la tercera de lado, como en las mesas de verdad) y se voltea
func _carta_mesa(es_punto: bool, k: int, carta: int) -> void:
	if sotano == null:
		return
	var quad := QuadMesh.new()
	quad.size = CARTA
	quad.orientation = PlaneMesh.FACE_Y
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.material_override = POKER.material(-1)
	sotano.add_child(m)
	_mesa.append(m)
	var centro := _centro_mesa()
	var lado := -1.0 if es_punto else 1.0
	var destino := centro + Vector3(lado * (MANO_X + 0.07) - lado * k * CARTA_SEPARA * (1.0 if k < 2 else 0.0), 0.0, 0.0)
	var giro := 0.0
	if k == 2:
		# La tercera, acostada de lado junto a las otras dos
		destino = centro + Vector3(lado * (MANO_X - CARTA_SEPARA - 0.08), 0.0, 0.0)
		giro = PI / 2.0
	var desde := _zapato()
	m.position = desde
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		m.position = desde.lerp(destino, f) + Vector3.UP * sin(f * PI) * 0.08
		m.rotation.y = lerpf(PI, giro, f), 0.0, 1.0, VUELA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(f: float) -> void:
		m.rotation.z = f * PI / 2.0
		m.position.y = destino.y + f * 0.03, 0.0, 1.0, 0.08)
	t.tween_callback(func() -> void: m.material_override = POKER.material(carta))
	t.tween_method(func(f: float) -> void:
		m.rotation.z = (1.0 - f) * PI / 2.0
		m.position.y = destino.y + (1.0 - f) * 0.03, 0.0, 1.0, 0.08)


# Don Chepe junta las cartas de la mano pasada y las echa de su lado
func _recoger_mesa() -> void:
	var crupier: Vector3 = _lugar("Crupier_baccarat") + Vector3(0, 0.85, 0.3)
	for m in _mesa:
		if not is_instance_valid(m):
			continue
		var desde := m.position
		var t := create_tween()
		t.tween_method(func(f: float) -> void: m.position = desde.lerp(crupier, f), 0.0, 1.0, 0.3)
		t.tween_callback(m.queue_free)
	_mesa.clear()


func _entrar(es_punto: bool, carta: int) -> void:
	var k := (_bac.punto if es_punto else _bac.banca).find(carta)
	_carta_mesa(es_punto, maxi(k, 0), carta)
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(56, 84)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.texture = POKER.textura(-1)
	r.pivot_offset = Vector2(28, 42)
	(_fila_punto if es_punto else _fila_banca).add_child(r)
	_cartas.append(r)
	Sonidos.tocar(self, "carta", -8.0)
	var t := create_tween()
	t.tween_property(r, "scale:x", 0.0, VOLTEA / 2.0)
	t.tween_callback(func() -> void: r.texture = POKER.textura(carta))
	t.tween_property(r, "scale:x", 1.0, VOLTEA / 2.0)


func _lugar(marca: String) -> Vector3:
	return sotano.call("marca", marca).origin if sotano else Vector3.ZERO


func _nueva_pila(n: int, donde: Vector3) -> PilaFichas:
	var p := PilaFichas.new()
	sotano.add_child(p)
	p.position = donde
	p.poner(n)
	return p


func _llevar_pilas(destino: Vector3) -> void:
	for p in [_pila, _pago]:
		if p and is_instance_valid(p):
			p.llevar(destino + Vector3(randf_range(-0.05, 0.05), 0, 0))
	_pila = null
	_pago = null


# Tu pila (lo que vas a jugar) en la casilla que escogiste; se mueve cuando cambias
func _acomodar_pila() -> void:
	if sotano == null or _ocupado:
		return
	var destino := _lugar("Baccarat_" + Baccarat.APUESTAS[_tipo])
	if _pila == null or not is_instance_valid(_pila):
		_pila = _nueva_pila(_apuesta, destino)
	elif _pila.cantidad != _apuesta:
		_pila.poner(_apuesta)
	if _pila.position.distance_to(destino) > 0.01:
		_pila.ir_a(destino)


func cerrar() -> void:
	for m in _mesa:
		if is_instance_valid(m):
			m.queue_free()
	for p in [_pila, _pago]:
		if p and is_instance_valid(p):
			p.queue_free()
	super.cerrar()


func _mostrar() -> void:
	_acomodar_pila()
	var tipo: String = Baccarat.APUESTAS[_tipo]
	_info.text = "Al %s · apuesta %d · fichas %d" % [NOMBRES[tipo], _apuesta, fichas()]
	_info.add_theme_color_override("font_color", COLOR_UI[tipo])
