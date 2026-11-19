extends JuegoSotano

# La ruleta del Sotano (Ruleta.gd decide): solo rojo, negro o verde. La camara ve la rueda desde
# arriba; la rueda (Ruleta_rueda del cuarto) gira y se frena, y la bola (Ruleta_bola) da vueltas al
# reves, baja y cae en su casilla. Despues de ganar: C cobras o D dobleteas (todo o nada, una vez).
# La sena de la trampa: el crupier "le da un golpecito a la mesa" cuando la bola brinca.

enum Estado { APOSTAR, GIRANDO, GANASTE, FIN }

const APUESTA_MAX := 10
const GIRO := 4.2                    # s que gira
const VUELTAS_RUEDA := 2.2           # vueltas que da la rueda
const VUELTAS_BOLA := 5.0            # vueltas de la bola (al reves)
const RUEDA_RADIO := 0.3             # sotano.py RUEDA (radio) y RUEDA_DENTRO: el anillo de casillas
const RUEDA_DENTRO := 0.18
const PISTA := 0.35                  # radio de la pista de afuera por donde corre la bola
const CAE := Vector2(0.55, 0.72)     # cuando cae de la pista a las casillas (fraccion del giro)
const CAMARA_DESDE := Vector3(-0.25, 1.25, -0.3)  # desde la marca Ruleta (m de la escena): casi encima de la rueda
const CAMARA_MIRA := Vector3(-0.22, 0.75, -1.08)
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
var _bola: Node3D
var _brinco := 0.0                   # lo que sube la bola al pegar en un separador
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
			_bola = cuarto.find_child("Ruleta_bola", true, false) as Node3D
		var m: Vector3 = sotano.call("marca", "Ruleta").origin
		acercar_camara(sotano.to_global(m + CAMARA_DESDE), sotano.to_global(m + CAMARA_MIRA), 52.0)
	_mostrar()
	avisar("\"Rojo, negro o verde. Nada más\", dice el crupier.", 4.0)


func _tecla(codigo: int) -> void:
	if _estado == Estado.GIRANDO:
		return
	match codigo:
		KEY_UP, KEY_W:
			_color = posmod(_color - 1, 3)
		KEY_DOWN:
			_color = posmod(_color + 1, 3)
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
	_mostrar()


# Si te levantas con un premio sin cobrar, se cobra solo
func cerrar() -> void:
	if _estado == Estado.GANASTE:
		cobrar()
	super.cerrar()


func _tirar() -> void:
	_estado = Estado.GIRANDO
	_ocupado = true
	_sale.text = ""
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
		Sonidos.tocar(self, "slot_gana_grande" if color == "verde" else "slot_gana", -3.0)
		if _doblete:
			# El doblete ganado se cobra solo (solo se puede una vez)
			_estado = Estado.GANASTE
			avisar("¡Doblete ganado!", 2.0)
			cobrar()
		else:
			_estado = Estado.GANASTE
			avisar("¡Ganas %d! C cobras o D dobleteas (todo o nada)." % gana, 30.0)
	else:
		_premio = 0
		_estado = Estado.FIN
		avisar("Se va todo al doblete. \"Así es esto, mijo.\"" if _doblete else "Gana la casa. Otra, Espacio.", 30.0)
	_mostrar()


# La rueda gira frenandose. La bola corre al reves por la pista de afuera (PISTA), al frenarse cae
# al anillo de casillas y ahi brinca de separador en separador (cada brinco suena) hasta quedar en
# la casilla de `n`. Angulos en el plano de la rueda como en Blender: un punto local (cos a, -sin a)
# en x, z queda en el angulo a + giro de la rueda
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
	while t < GIRO:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		t = minf(t + get_process_delta_time(), GIRO)
		var f := t / GIRO
		var giro := inicio + vuelta_rueda * (f - f * f / 2.0) * 2.0    # se frena hasta parar en f = 1
		_rueda.rotation.y = giro
		# Cae de la pista a las casillas entre CAE.x y CAE.y
		var cae := clampf((f - CAE.x) / (CAE.y - CAE.x), 0.0, 1.0)
		# En las casillas va brincando: se pasa de su casilla y regresa, cada vez menos
		var rebote := sin(f * 55.0) * (TAU / total) * 1.6 * cae * pow(1.0 - f, 1.3) * 3.0
		var atraso := -VUELTAS_BOLA * TAU * pow(1.0 - f, 2.0)           # al reves; llega a la casilla
		var fi := giro + a + atraso + rebote
		var r := lerpf(PISTA, (RUEDA_DENTRO + RUEDA_RADIO) / 2.0, ease(cae, 0.6))
		var alto := lerpf(0.07, 0.053, cae)
		# Cada separador que cruza ya adentro: un brinquito y su tic
		var en := posmod(int(floor((fi - giro) / (TAU / total))), total)
		if cae > 0.0 and en != casilla_antes:
			if casilla_antes >= 0:
				Sonidos.tocar(self, "paso", -14.0 + (1.0 - f) * 4.0, randf_range(1.3, 1.7))
				_brinco = 0.018 * (1.0 - f) + 0.004
			casilla_antes = en
		_brinco = maxf(_brinco - get_process_delta_time() * 0.12, 0.0)
		_bola.position = _rueda.position + Vector3(cos(fi) * r, alto + _brinco, -sin(fi) * r)
	_bola.position.y = _rueda.position.y + 0.053


func _mostrar() -> void:
	var c: String = Ruleta.COLORES[_color]
	var linea := "Al %s · apuesta %d · fichas %d" % [NOMBRES[c], _apuesta, fichas()]
	if _estado == Estado.GANASTE:
		linea = "Llevas %d · C cobrar · D dobletear al %s" % [_premio, NOMBRES[c]]
	_info.text = linea
	_info.add_theme_color_override("font_color", COLOR_UI[c])
