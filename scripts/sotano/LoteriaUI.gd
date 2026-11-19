extends JuegoSotano

# La loteria cantada en la mesa del Sotano: el griton canta una carta (CartasLoteria, con su
# verso) cada LLAMADA s, tu y tres vecinos marcan su tabla de 4 x 4 y gana el primero que grite
# "¡Loteria!" con una linea, una columna, una diagonal o las cuatro esquinas. Cada tabla cuesta
# ENTRADA fichas; el que gana se lleva la bolsa menos lo de la casa.
# La casa hace trampa: Tacho es su palero. Con PALERO_PROB el mazo viene acomodado para que su
# tabla se llene primero, y el canta mas rapido. Se le nota: siempre se sienta junto al griton
# y nunca pierde dos seguidas (docs/lore.md 11, El Sotano).

const ENTRADA := 3
const CASA := 2                      # fichas de la bolsa que se quedan en la casa
const LLAMADA := 2.4
const PALERO_PROB := 0.3
const VECINOS := ["Doña Cuca", "El Chino", "Tacho"]
const PALERO := 2
const GRITA := Vector2(1.2, 2.6)     # s que tarda un vecino en gritar con la tabla llena
const GRITA_PALERO := 0.6
const PATRONES := [
	[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11], [12, 13, 14, 15],
	[0, 4, 8, 12], [1, 5, 9, 13], [2, 6, 10, 14], [3, 7, 11, 15],
	[0, 5, 10, 15], [3, 6, 9, 12], [0, 3, 12, 15],
]

static var _palero_gano := false     # para que no pierda dos seguidas

var _tablas: Array = []              # [tuya, vecino 0, 1, 2]: 16 cartas cada una
var _marcas: Array = []              # [jugador] -> Array[bool] de 16
var _mazo: Array = []
var _salidas: Array[int] = []
var _jugando := false
var _t := 0.0
var _grita_en := [-1.0, -1.0, -1.0]  # s de juego en que grita cada vecino; -1 = todavia no
var _celdas: Array[TextureRect] = []
var _frijoles: Array[Label] = []
var _cantada: TextureRect
var _verso: Label
var _vecinos_l: Array[Label] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	titulo = "La lotería de la mesa"
	ayuda = "Espacio comprar tabla (%d fichas)  ·  clic marca  ·  L ¡Lotería!  ·  Esc salir" % ENTRADA


func _armar() -> void:
	_rng.randomize()
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	contenido.add_child(fila)
	var rejilla := GridContainer.new()
	rejilla.columns = 4
	rejilla.add_theme_constant_override("h_separation", 3)
	rejilla.add_theme_constant_override("v_separation", 3)
	fila.add_child(rejilla)
	for i in 16:
		var c := carta(0, 50.0)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(_clic.bind(i))
		var frijol := etiqueta("●", 30, Color(0.45, 0.25, 0.12))
		frijol.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		frijol.grow_horizontal = Control.GROW_DIRECTION_BOTH
		frijol.grow_vertical = Control.GROW_DIRECTION_BOTH
		frijol.visible = false
		c.add_child(frijol)
		rejilla.add_child(c)
		_celdas.append(c)
		_frijoles.append(frijol)
	var derecha := VBoxContainer.new()
	derecha.add_theme_constant_override("separation", 6)
	fila.add_child(derecha)
	derecha.add_child(etiqueta("Canta el gritón:", 14, AMARILLO))
	_cantada = carta(CartasLoteria.TINACO, 88.0)
	derecha.add_child(_cantada)
	_verso = etiqueta("Compra tu tabla y empezamos.", 13)
	_verso.autowrap_mode = TextServer.AUTOWRAP_WORD
	_verso.custom_minimum_size = Vector2(240, 54)
	derecha.add_child(_verso)
	for v in VECINOS:
		var l := etiqueta(v, 13)
		derecha.add_child(l)
		_vecinos_l.append(l)
	_tablas = [_tabla(), _tabla(), _tabla(), _tabla()]
	_mostrar_tabla()


func _tecla(codigo: int) -> void:
	match codigo:
		KEY_SPACE, KEY_ENTER:
			if not _jugando:
				empezar()
		KEY_L:
			gritar()


func empezar() -> void:
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(ENTRADA):
		avisar("La tabla cuesta %d fichas." % ENTRADA)
		return
	_tablas = [_tabla(), _tabla(), _tabla(), _tabla()]
	_marcas = []
	for i in 4:
		var m: Array[bool] = []
		m.resize(16)
		m.fill(false)
		_marcas.append(m)
	_mazo = range(CartasLoteria.cuantas())
	_mazo.shuffle()
	if not _palero_gano and _rng.randf() < PALERO_PROB:
		_acomodar_para_palero()
	_salidas.clear()
	_grita_en = [-1.0, -1.0, -1.0]
	_t = 0.0
	_jugando = true
	_ocupado = true
	_mostrar_tabla()
	avisar("¡Corre y se va corriendo!", 2.0)


func _process(delta: float) -> void:
	super._process(delta)
	if not _jugando:
		return
	var antes := _t
	_t += delta
	# Cada LLAMADA s, una carta
	if floor(_t / LLAMADA) > floor(antes / LLAMADA):
		_cantar()
	# Los vecinos marcan solos y gritan cuando se llenan
	for v in 3:
		if _grita_en[v] >= 0.0 and _t >= _grita_en[v]:
			_gana(v + 1)
			return


func _cantar() -> void:
	if _mazo.is_empty():
		_terminar("Se acabó el mazo y nadie gritó. La casa se queda la bolsa.")
		return
	var c: int = _mazo.pop_front()
	_salidas.append(c)
	_cantada.texture = CartasLoteria.textura(c)
	_verso.text = CartasLoteria.VERSOS[c]
	for v in 3:
		var tabla: Array = _tablas[v + 1]
		var i := tabla.find(c)
		if i >= 0:
			_marcas[v + 1][i] = true
		if _grita_en[v] < 0.0 and _completa(v + 1):
			_grita_en[v] = _t + (GRITA_PALERO if v == PALERO else _rng.randf_range(GRITA.x, GRITA.y))
	_mostrar_vecinos()


func _clic(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		marcar(i)


# Marca la casilla `i` de tu tabla (solo si su carta ya salio)
func marcar(i: int) -> void:
	if not _jugando:
		return
	if not _salidas.has(_tablas[0][i]):
		avisar("¡Esa no ha salido!", 1.5)
		return
	_marcas[0][i] = true
	_frijoles[i].visible = true


func gritar() -> void:
	if not _jugando:
		return
	if _completa(0):
		_gana(0)
	else:
		avisar("\"¡Mentirosa!\", te grita Doña Cuca. Todavía no llenas nada.", 2.0)


func _gana(quien: int) -> void:
	var bolsa := ENTRADA * 4 - CASA
	if quien == 0:
		var f := get_node_or_null("/root/Fichas")
		if f:
			f.fichas += bolsa
		Sonidos.tocar(self, "moneda", -4.0)
		_terminar("¡LOTERÍA! Te llevas %d fichas." % bolsa)
		_palero_gano = false
	else:
		_terminar("\"¡Lotería!\", grita %s, y se lleva la bolsa." % VECINOS[quien - 1])
		_palero_gano = quien - 1 == PALERO


func _terminar(texto: String) -> void:
	_jugando = false
	_ocupado = false
	avisar(texto + "  (Espacio otra tabla)", 6.0)


# La tabla llena con algun patron
func _completa(quien: int) -> bool:
	if _marcas.size() <= quien:
		return false
	var m: Array = _marcas[quien]
	for p: Array in PATRONES:
		if p.all(func(i: int) -> bool: return m[i]):
			return true
	return false


func _tabla() -> Array:
	var cartas: Array = range(CartasLoteria.cuantas())
	cartas.shuffle()
	return cartas.slice(0, 16)


# El mazo acomodado: la primera fila del palero sale entre las primeras cartas, revuelta con
# otras para que no se note
func _acomodar_para_palero() -> void:
	var fila: Array = _tablas[PALERO + 1].slice(0, 4)
	for c in fila:
		_mazo.erase(c)
	var lugares := [1, 3, 5, 7]
	for k in 4:
		_mazo.insert(lugares[k] + _rng.randi_range(0, 1), fila[k])


func _mostrar_tabla() -> void:
	for i in 16:
		_celdas[i].texture = CartasLoteria.textura(_tablas[0][i])
		_frijoles[i].visible = _marcas.size() > 0 and _marcas[0][i]
	_mostrar_vecinos()


func _mostrar_vecinos() -> void:
	for v in 3:
		var n := 0
		if _marcas.size() > v + 1:
			for b: bool in _marcas[v + 1]:
				n += int(b)
		_vecinos_l[v].text = "%s: %d frijoles" % [VECINOS[v], n]
