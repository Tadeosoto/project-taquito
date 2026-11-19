extends JuegoSotano

# La ruleta del Sotano (Ruleta.gd decide): solo rojo, negro o verde. La camara ve la rueda y el
# pano desde arriba; tu pila de fichas (PilaFichas) va en la casilla del color que escoges. La rueda
# (Ruleta_rueda del cuarto) gira y se frena; la bola (una esfera propia con manchitas, para que se
# vea rodar: la del cuarto se esconde) corre al reves por la pista, cae con brincos de verdad
# (gravedad) y brinca de separador en separador hasta su casilla, rodando segun lo que avanza.
# Despues de ganar: C cobras o D dobleteas (todo o nada, una vez). Ganar, ganar seguido y perder se
# festejan (JuegoSotano.festejar). La sena de la trampa: el crupier "le da un golpecito a la mesa".

enum Estado { APOSTAR, GIRANDO, GANASTE, FIN }

const APUESTA_MAX := 10
const GIRO := 4.6                    # s que gira
const VUELTAS_RUEDA := 2.2           # vueltas que da la rueda
const VUELTAS_BOLA := 5.0            # vueltas de la bola (al reves)
const RUEDA_RADIO := 0.3             # sotano.py RUEDA (radio) y RUEDA_DENTRO: el anillo de casillas
const RUEDA_DENTRO := 0.18
const PISTA := 0.35                  # radio de la pista de afuera por donde corre la bola
const CAE := Vector2(0.5, 0.7)       # cuando cae de la pista a las casillas (fraccion del giro)
const BOLA_RADIO := 0.018
const ALTO_PISTA := 0.07             # alto de la bola sobre la rueda: en la pista y en una casilla
const ALTO_CASILLA := 0.053
const GRAVEDAD := 3.2                # m/s2 (escena): para los brincos
const CAMARA_DESDE := Vector3(-0.2, 1.6, -0.5)   # desde la marca Ruleta (m de la escena)
const CAMARA_MIRA := Vector3(-0.2, 0.8, -1.5)
const NOMBRES := {"rojo": "ROJO", "negro": "NEGRO", "verde": "VERDE"}
const COLOR_UI := {"rojo": Color(1.0, 0.3, 0.25), "negro": Color(0.85, 0.85, 0.85), "verde": Color(0.3, 1.0, 0.45)}

var sotano: Node3D

var _ruleta := Ruleta.new()
var _estado := Estado.APOSTAR
var _color := 0
var _apuesta := 1
var _en_juego := 0                   # lo que esta arriesgado en esta tirada
var _premio := 0                     # lo que llevas ganado (sin cobrar)
var _doblete := false                # si esta tirada es el doblete
var _rueda: Node3D
var _bola: MeshInstance3D
var _bola_cuarto: Node3D
var _alto := ALTO_PISTA              # la bola: alto y velocidad vertical (brincos)
var _vy := 0.0
var _pila: PilaFichas
var _pago: PilaFichas
var _info: Label
var _sale: Label


func _init() -> void:
	titulo = "Ruleta"
	ayuda = "↑/↓ color  ·  ←/→ apuesta  ·  Espacio girar  ·  C cobrar  ·  D dobletear  ·  Esc levantarte"


func _armar() -> void:
	_panel.visible = false
	_oscuro.visible = false
	_info = etiqueta("", 16, AMARILLO)
	_info.position = Vector2(8, 8)
	add_child(_info)
	_sale = etiqueta("", 30, AMARILLO)
	_sale.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_sale.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sale.offset_top = 40.0
	add_child(_sale)
	var a := etiqueta(ayuda.replace("  ·  ", "\n"), 12, Color(0.85, 0.82, 0.78))
	a.position = Vector2(8, 320)
	add_child(a)
	_aviso.reparent(self)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aviso.offset_bottom = -10.0
	if sotano:
		var cuarto := sotano.get_node_or_null("Cuarto")
		if cuarto:
			_rueda = cuarto.find_child("Ruleta_rueda", true, false) as Node3D
			_bola_cuarto = cuarto.find_child("Ruleta_bola", true, false) as Node3D
		if _rueda:
			_armar_bola()
		var m: Vector3 = sotano.call("marca", "Ruleta").origin
		acercar_camara(sotano.to_global(m + CAMARA_DESDE), sotano.to_global(m + CAMARA_MIRA), 58.0)
	_mostrar()
	avisar("\"Rojo, negro o verde. Nada más\", dice el crupier.", 4.0)


# La bola propia: esfera lisa con unas manchitas grises (una bola blanca lisa no se ve rodar), en el
# mismo padre que la rueda; la del cuarto se esconde mientras juegas
func _armar_bola() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = BOLA_RADIO
	esfera.height = BOLA_RADIO * 2.0
	esfera.radial_segments = 16
	esfera.rings = 10
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.97, 0.96, 0.92))
	for p in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(9, 5), Vector2i(10, 5), Vector2i(13, 2), Vector2i(6, 6), Vector2i(6, 1)]:
		img.set_pixelv(p, Color(0.45, 0.45, 0.48))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.25
	m.metallic_specular = 0.8
	esfera.material = m
	_bola = MeshInstance3D.new()
	_bola.mesh = esfera
	_bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rueda.get_parent().add_child(_bola)
	_bola.position = _rueda.position + Vector3(PISTA, ALTO_PISTA, 0.0)
	if _bola_cuarto:
		_bola_cuarto.visible = false


func cerrar() -> void:
	if _estado == Estado.GANASTE:
		cobrar()
	for p in [_pila, _pago]:
		if p and is_instance_valid(p):
			p.queue_free()
	if _bola_cuarto and _bola:
		_bola_cuarto.position = _bola.position
		_bola_cuarto.visible = true
	if _bola:
		_bola.queue_free()
	super.cerrar()


func _tecla(codigo: int) -> void:
	if _estado == Estado.GIRANDO:
		return
	match codigo:
		KEY_UP, KEY_W:
			_color = posmod(_color - 1, 3)
			Sonidos.tocar(self, "ficha_mesa", -12.0, 1.3)
		KEY_DOWN:
			_color = posmod(_color + 1, 3)
			Sonidos.tocar(self, "ficha_mesa", -12.0, 1.3)
		KEY_LEFT, KEY_A:
			if _estado != Estado.GANASTE:
				_apuesta = maxi(_apuesta - 1, 1)
				Sonidos.tocar(self, "apuesta_sube", -8.0, 0.9)
		KEY_RIGHT:
			if _estado != Estado.GANASTE:
				_apuesta = mini(_apuesta + 1, APUESTA_MAX)
				Sonidos.tocar(self, "apuesta_sube", -8.0)
		KEY_SPACE, KEY_ENTER:
			if _estado != Estado.GANASTE:
				girar()
		KEY_C:
			cobrar()
		KEY_D:
			dobletear()
	_mostrar()


func girar() -> void:
	if _estado == Estado.GIRANDO or _estado == Estado.GANASTE:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	Sonidos.tocar(self, "ficha_mesa", -5.0)
	_doblete = false
	_en_juego = _apuesta
	await _tirar()


# Todo o nada, una vez: lo que llevas ganado vuelve a la mesa (puedes cambiar de color)
func dobletear() -> void:
	if _estado != Estado.GANASTE or _doblete:
		return
	_doblete = true
	_en_juego = _premio
	_premio = 0
	if _pago and is_instance_valid(_pago):
		_pago.queue_free()
	_pago = null
	avisar("¡Doblete! %d fichas al %s." % [_en_juego, NOMBRES[Ruleta.COLORES[_color]]], 3.0)
	await _tirar()


func cobrar() -> void:
	if _estado != Estado.GANASTE:
		return
	var f := get_node_or_null("/root/Fichas")
	if f:
		f.fichas += _premio
	Sonidos.tocar(self, "monedas_caen", -5.0)
	avisar("Cobras %d fichas." % _premio, 3.0)
	_premio = 0
	_estado = Estado.FIN
	_llevar_pilas(_lugar("Ruleta"))
	_mostrar()


func _tirar() -> void:
	_estado = Estado.GIRANDO
	_ocupado = true
	_sale.text = ""
	_mostrar()
	var apostado: String = Ruleta.COLORES[_color]
	var n := _ruleta.tirar(apostado, _en_juego)
	if _ruleta.freno:
		avisar("El crupier le da un golpecito a la mesa.", 2.5)
	Sonidos.tocar(self, "caballitos", -8.0, 1.3)
	await _animar(n)
	if not is_inside_tree():
		return
	_ocupado = false
	Sonidos.tocar(self, "slot_carrete", -6.0)
	var color := Ruleta.color(n)
	_sale.text = "%d %s" % [n, NOMBRES[color]]
	_sale.add_theme_color_override("font_color", COLOR_UI[color])
	var gana := Ruleta.premio(apostado, _en_juego, n)
	if gana > 0:
		_premio = gana
		festejar(true, gana)
		# El crupier pone tu premio junto a tu pila
		_pago = _nueva_pila(gana - _en_juego, _lugar("Crupier_ruleta") + Vector3(0, 0.85, 0))
		_pago.ir_a(_lugar("Ruleta_" + apostado) + Vector3(0.075, 0, 0), 0.4)
		_estado = Estado.GANASTE
		if _doblete:
			# El doblete ganado se cobra solo (solo se puede una vez)
			avisar("¡Doblete ganado!", 2.0)
			await get_tree().create_timer(0.6).timeout
			cobrar()
		else:
			avisar("¡Ganas %d! C cobras o D dobleteas (todo o nada)." % gana, 30.0)
	else:
		_premio = 0
		_estado = Estado.FIN
		festejar(false)
		_llevar_pilas(_lugar("Crupier_ruleta") + Vector3(0, 0.85, 0))
		avisar("Se va todo al doblete. \"Así es esto, mijo.\"" if _doblete else "Gana la casa. Otra, Espacio.", 30.0)
	_mostrar()


# --- Las fichas en el pano ---

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


# Tu pila en la casilla del color escogido, con lo que vas a jugar (o lo que llevas, para el doblete)
func _acomodar_pila() -> void:
	if sotano == null or _estado == Estado.GIRANDO:
		return
	var destino := _lugar("Ruleta_" + Ruleta.COLORES[_color])
	if _pila == null or not is_instance_valid(_pila):
		_pila = _nueva_pila(_apuesta, destino)
	elif _estado != Estado.GANASTE and _pila.cantidad != _apuesta:
		_pila.poner(_apuesta)
	if _pila.position.distance_to(destino) > 0.01:
		_pila.ir_a(destino)
		if _pago and is_instance_valid(_pago):
			_pago.ir_a(destino + Vector3(0.075, 0, 0))


# --- La bola ---

# La rueda gira frenandose. La bola corre al reves por la pista de afuera, cae (con brincos que
# se van apagando) al anillo de casillas, brinca en cada separador que cruza (y suena) y queda en la
# casilla de `n`. Todo el tiempo rueda: gira sobre el eje de lado segun lo que avanza.
# Angulos en el plano de la rueda como en Blender: un punto local (cos a, -sin a) en x, z queda en el
# angulo a + giro de la rueda
func _animar(n: int) -> void:
	if _rueda == null or _bola == null:
		await get_tree().create_timer(1.0).timeout
		return
	var total := Ruleta.ORDEN.size()
	var casilla := Ruleta.ORDEN.find(n)
	var a := (casilla + 0.5) * TAU / total
	var inicio := _rueda.rotation.y
	var vuelta_rueda := VUELTAS_RUEDA * TAU
	var t := 0.0
	var casilla_antes := -1
	var cayo := false
	_alto = ALTO_PISTA
	_vy = 0.0
	while t < GIRO:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var dt := get_process_delta_time()
		t = minf(t + dt, GIRO)
		var f := t / GIRO
		var giro := inicio + vuelta_rueda * (f - f * f / 2.0) * 2.0    # se frena hasta parar en f = 1
		_rueda.rotation.y = giro
		var cae := clampf((f - CAE.x) / (CAE.y - CAE.x), 0.0, 1.0)
		# En las casillas se pasa de su casilla y regresa, cada vez menos
		var rebote := sin(f * 48.0) * (TAU / total) * 3.5 * cae * pow(1.0 - f, 1.4)
		var atraso := -VUELTAS_BOLA * TAU * pow(1.0 - f, 2.0)           # al reves; llega a la casilla
		var fi := giro + a + atraso + rebote
		var r := lerpf(PISTA, (RUEDA_DENTRO + RUEDA_RADIO) / 2.0, ease(cae, 0.5))
		var piso := lerpf(ALTO_PISTA, ALTO_CASILLA, cae)
		if cae > 0.0 and not cayo:
			cayo = true
			_vy = 0.35                                                  # sale de la pista de un brinco
		# Cada separador que cruza ya adentro: un brinco y su tic
		var en := posmod(int(floor((fi - giro) / (TAU / total))), total)
		if cae > 0.3 and en != casilla_antes:
			if casilla_antes >= 0 and _alto - piso < 0.004:
				Sonidos.tocar(self, "paso", -14.0 + (1.0 - f) * 4.0, randf_range(1.3, 1.7))
				_vy = 0.28 * (1.0 - f) + 0.04
			casilla_antes = en
		# Gravedad y rebote contra el piso (pista o casilla)
		_vy -= GRAVEDAD * dt
		_alto += _vy * dt
		if _alto < piso:
			_alto = piso
			_vy = -_vy * 0.35 if absf(_vy) > 0.08 else 0.0
		var antes := _bola.position
		_bola.position = _rueda.position + Vector3(cos(fi) * r, _alto, -sin(fi) * r)
		_rodar(_bola.position - antes)
	_bola.position.y = _rueda.position.y + ALTO_CASILLA


# Rueda lo que avanzo: gira sobre el eje acostado que es perpendicular al camino
func _rodar(paso: Vector3) -> void:
	paso.y = 0.0
	var largo := paso.length()
	if largo < 0.0001:
		return
	var eje := Vector3.UP.cross(paso / largo).normalized()
	_bola.basis = (Basis(eje, largo / BOLA_RADIO) * _bola.basis).orthonormalized()


func _mostrar() -> void:
	var c: String = Ruleta.COLORES[_color]
	var linea := "Al %s · apuesta %d · fichas %d" % [NOMBRES[c], _apuesta, fichas()]
	if _estado == Estado.GANASTE:
		linea = "Llevas %d · C cobrar · D dobletear al %s" % [_premio, NOMBRES[c]]
	var r := racha()
	if r >= 2:
		linea += "  ·  racha %d" % r
	_info.text = linea
	_info.add_theme_color_override("font_color", COLOR_UI[c])
	_acomodar_pila()
