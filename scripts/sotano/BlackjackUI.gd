extends JuegoSotano

# La mesa de blackjack del Sotano (Blackjack.gd decide): la camara se acerca a la mesa desde tu
# lugar y en la pantalla van las cartas de la crupier (arriba, una tapada) y las tuyas (abajo), que
# entran volteandose. Juegas con tus fichas. La crupier es "La Guera"; cuando carga el zapato se
# acomoda el arete (la sena).

const POKER := preload("res://scripts/sotano/PokerUI.gd")   # su textura(c) de la baraja
const APUESTA_MAX := 10
const VOLTEA := 0.2
const REPARTE := 0.25
const CAMARA_DESDE := Vector3(0.0, 1.45, 0.25)   # desde la marca Blackjack_tu (m de la escena)
const CAMARA_MIRA := Vector3(0.0, 0.8, -0.85)
const LINEAS_ARETE := [
	"La Güera se acomoda el arete antes de repartir.",
	"La Güera se toca el arete y no te ve a los ojos.",
]

var sotano: Node3D

var _bj := Blackjack.new()
var _apuesta := 1
var _arriba: HBoxContainer
var _abajo: HBoxContainer
var _total_crupier: Label
var _total_tuyo: Label
var _estado: Label
var _cartas_crupier: Array[TextureRect] = []
var _cartas_tuyas: Array[TextureRect] = []


func _init() -> void:
	titulo = "Blackjack"
	ayuda = "←/→ apuesta  ·  Espacio repartir  ·  H pedir  ·  S plantarte  ·  D doblar  ·  Esc levantarte"


func _armar() -> void:
	_panel.visible = false
	_oscuro.visible = false
	_arriba = _fila(8.0, true)
	_abajo = _fila(-30.0, false)
	_total_crupier = etiqueta("", 16, AMARILLO)
	_total_crupier.position = Vector2(8, 8)
	add_child(_total_crupier)
	_total_tuyo = etiqueta("", 16, AMARILLO)
	_estado = etiqueta("", 14)
	var lado := VBoxContainer.new()
	lado.position = Vector2(8, 300)
	lado.add_child(_total_tuyo)
	lado.add_child(_estado)
	lado.add_child(etiqueta(ayuda.replace("  ·  ", "\n"), 12, Color(0.85, 0.82, 0.78)))
	add_child(lado)
	_aviso.reparent(self)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if sotano:
		var tu: Vector3 = sotano.call("marca", "Blackjack_tu").origin
		acercar_camara(sotano.to_global(tu + CAMARA_DESDE), sotano.to_global(tu + CAMARA_MIRA), 56.0)
	_mostrar()
	avisar("\"Apuéstale, mijo\", dice La Güera. ←/→ la apuesta, Espacio reparte.", 5.0)


func _fila(desde: float, arriba: bool) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP if arriba else Control.PRESET_CENTER_BOTTOM)
	fila.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if arriba:
		fila.offset_top = desde
	else:
		fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
		fila.offset_bottom = desde
	fila.add_theme_constant_override("separation", 6)
	add_child(fila)
	return fila


func _tecla(codigo: int) -> void:
	if _ocupado:
		return
	match codigo:
		KEY_LEFT:
			if _bj.fase != Blackjack.Fase.JUGANDO:
				_apuesta = maxi(_apuesta - 1, 1)
				Sonidos.tocar(self, "apuesta_sube", -8.0, 0.9)
		KEY_RIGHT:
			if _bj.fase != Blackjack.Fase.JUGANDO:
				_apuesta = mini(_apuesta + 1, APUESTA_MAX)
				Sonidos.tocar(self, "apuesta_sube", -8.0)
		KEY_D:
			doblar()
		KEY_SPACE, KEY_ENTER:
			if _bj.fase != Blackjack.Fase.JUGANDO:
				repartir()
		KEY_H:
			pedir()
		KEY_S:
			plantarte()
	_mostrar()


func repartir() -> void:
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	Sonidos.tocar(self, "ficha_mesa", -5.0)
	_bj.empezar(_apuesta)
	if _bj.cargado:
		avisar(LINEAS_ARETE[randi() % LINEAS_ARETE.size()], 3.0)
	_limpiar()
	_ocupado = true
	# Una a ti, una a ella, una a ti, la tapada a ella
	var orden := [[true, 0], [false, 0], [true, 1], [false, 1]]
	for paso: Array in orden:
		var tuya: bool = paso[0]
		var k: int = paso[1]
		_entrar(tuya, tuya_o_suya(tuya)[k], not tuya and k == 1)
		await get_tree().create_timer(REPARTE).timeout
		if not is_inside_tree():
			return
	_ocupado = false
	if _bj.fase == Blackjack.Fase.FIN:
		await _destapar()
		_final()
	_mostrar()


func tuya_o_suya(tuya: bool) -> Array:
	return _bj.tuyas if tuya else _bj.crupier


func pedir() -> void:
	if _bj.fase != Blackjack.Fase.JUGANDO:
		return
	_bj.pedir()
	_entrar(true, _bj.tuyas[-1], false)
	if _bj.fase == Blackjack.Fase.FIN:
		_ocupado = true
		await get_tree().create_timer(REPARTE).timeout
		await _destapar()
		_ocupado = false
		_final()
	_mostrar()


func plantarte() -> void:
	if _bj.fase != Blackjack.Fase.JUGANDO:
		return
	_ocupado = true
	_bj.plantarte()
	await _destapar()
	_ocupado = false
	_final()
	_mostrar()


func doblar() -> void:
	if _bj.fase != Blackjack.Fase.JUGANDO or _bj.tuyas.size() != 2:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_bj.apuesta):
		avisar("No te alcanza para doblar.")
		return
	Sonidos.tocar(self, "ficha_mesa", -5.0)
	_ocupado = true
	_bj.doblar()
	_entrar(true, _bj.tuyas[-1], false)
	await get_tree().create_timer(REPARTE).timeout
	await _destapar()
	_ocupado = false
	_final()
	_mostrar()


# La crupier voltea su tapada y saca las que le falten, una por una
func _destapar() -> void:
	if _cartas_crupier.size() > 1:
		_voltear(_cartas_crupier[1], _bj.crupier[1])
		await get_tree().create_timer(REPARTE).timeout
	for k in range(_cartas_crupier.size(), _bj.crupier.size()):
		if not is_inside_tree():
			return
		_entrar(false, _bj.crupier[k], false)
		await get_tree().create_timer(REPARTE).timeout


func _final() -> void:
	var f := get_node_or_null("/root/Fichas")
	if f and _bj.pago > 0:
		f.fichas += _bj.pago
		Sonidos.tocar(self, "monedas_caen", -5.0)
	var texto: String = {
		"blackjack": "¡Blackjack! Te pagan %d fichas." % _bj.pago,
		"ganas": "Ganas. Te pagan %d fichas." % _bj.pago,
		"empate": "Empate: te regresan tus %d." % _bj.pago,
		"pierdes": "Gana la casa. \"Otra, mijo, que ahorita se compone.\"",
		"te pasaste": "Te pasaste de 21. La Güera ni sonríe.",
	}.get(_bj.resultado, "")
	avisar(texto + "  (Espacio otra mano)", 30.0)


func _limpiar() -> void:
	for r in _cartas_crupier + _cartas_tuyas:
		r.queue_free()
	_cartas_crupier.clear()
	_cartas_tuyas.clear()


# Una carta entra a su fila: de reverso y se voltea (si no va tapada)
func _entrar(tuya: bool, carta: int, tapada: bool) -> void:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(64, 96)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.texture = _carta_textura(-1)
	r.pivot_offset = Vector2(32, 48)
	(_abajo if tuya else _arriba).add_child(r)
	(_cartas_tuyas if tuya else _cartas_crupier).append(r)
	Sonidos.tocar(self, "carta", -8.0)
	if not tapada:
		_voltear(r, carta)


func _voltear(r: TextureRect, carta: int) -> void:
	var t := create_tween()
	t.tween_property(r, "scale:x", 0.0, VOLTEA / 2.0)
	t.tween_callback(func() -> void: r.texture = _carta_textura(carta))
	t.tween_property(r, "scale:x", 1.0, VOLTEA / 2.0)


static func _carta_textura(c: int) -> AtlasTexture:
	return POKER.textura(c)


func _mostrar() -> void:
	var jugando := _bj.fase == Blackjack.Fase.JUGANDO
	if _bj.crupier.is_empty():
		_total_crupier.text = "La Güera"
	elif jugando:
		_total_crupier.text = "La Güera: %d + ?" % Blackjack.puntos(_bj.crupier[0])
	else:
		_total_crupier.text = "La Güera: %d" % Blackjack.valor(_bj.crupier)
	_total_tuyo.text = ("Tú: %d" % Blackjack.valor(_bj.tuyas)) if not _bj.tuyas.is_empty() else "Tú"
	_estado.text = "Apuesta %d · Fichas %d" % [_bj.apuesta if jugando else _apuesta, fichas()]
