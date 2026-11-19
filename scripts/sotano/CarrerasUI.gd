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

var _caballo := 0
var _apuesta := 1
var _elegido: Label
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	titulo = "Las carreras de caballitos"
	ayuda = "↑/↓ caballito  ·  ←/→ apuesta  ·  Espacio ¡arrancan!  ·  Esc salir"


func _armar() -> void:
	_rng.randomize()
	for i in 5:
		contenido.add_child(etiqueta("%d  El %s · paga %d a 1" % [i + 1, COLORES[i], MOMIOS[i]], 16))
	_elegido = etiqueta("", 18, AMARILLO)
	_elegido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(_elegido)
	_mostrar()


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
	if sotano and sotano.has_method("correr"):
		if trampa:
			await sotano.temblar(ganador)
		await sotano.correr(ganador)
	_panel.visible = true
	_oscuro.visible = true
	if ganador == _caballo:
		var pago: int = _apuesta * MOMIOS[_caballo]
		f.fichas += pago
		Sonidos.tocar(self, "moneda", -4.0)
		avisar("¡Llegó el %s! Te pagan %d fichas." % [COLORES[_caballo], pago])
	else:
		avisar("Ganó el %s. \"Ese caballito siempre arranca dormido\", dice el de junto." % COLORES[ganador])
	_ocupado = false


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
