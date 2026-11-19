class_name Blackjack
extends RefCounted

# El blackjack del Sotano (BlackjackUI.gd lo muestra): solo reglas y cuentas, nada de nodos.
# Cartas como en Holdem.gd: 0..51 = palo * 13 + (rango - 2), rango 2..14 (14 = as); la baraja es
# textures/sotano/baraja.png. Un mazo nuevo cada mano. El crupier se planta en 17 (en todos los 17).
# Blackjack natural paga 3 a 2 (redondeado hacia abajo); se puede doblar con dos cartas.
# La trampa (docs/lore.md 11): con apuestas de CARGADO_DESDE o mas, a veces (CARGADO) la crupier
# "carga el zapato": su carta tapada es la que la deja en 20 o 21. Se le nota: se acomoda el arete
# antes de repartir (BlackjackUI lo dice).

enum Fase { APOSTAR, JUGANDO, FIN }

const CARGADO_DESDE := 5
const CARGADO := 0.35
const PLANTA := 17

var mazo: Array[int] = []
var tuyas: Array[int] = []
var crupier: Array[int] = []
var apuesta := 0
var fase := Fase.APOSTAR
var cargado := false
var resultado := ""                  # "blackjack", "ganas", "empate", "pierdes", "te pasaste"
var pago := 0                        # lo que te regresa al final (con tu apuesta)
var rng := RandomNumberGenerator.new()


func _init(semilla := 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()


static func puntos(c: int) -> int:
	var rango := c % 13 + 2
	if rango == 14:
		return 11
	return mini(rango, 10)


static func valor(cartas: Array) -> int:
	var total := 0
	var ases := 0
	for c: int in cartas:
		total += puntos(c)
		if c % 13 + 2 == 14:
			ases += 1
	while total > 21 and ases > 0:
		total -= 10
		ases -= 1
	return total


static func es_blackjack(cartas: Array) -> bool:
	return cartas.size() == 2 and valor(cartas) == 21


func empezar(cuanto: int) -> void:
	apuesta = cuanto
	resultado = ""
	pago = 0
	cargado = false
	mazo = []
	for c in 52:
		mazo.append(c)
	for i in range(mazo.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := mazo[i]
		mazo[i] = mazo[j]
		mazo[j] = t
	tuyas = [mazo.pop_back()]
	crupier = [mazo.pop_back()]
	tuyas.append(mazo.pop_back())
	crupier.append(mazo.pop_back())
	# La trampa: cambia la tapada por una que la deja en 20 o 21, si hay
	if apuesta >= CARGADO_DESDE and rng.randf() < CARGADO:
		for k in mazo.size():
			var total := valor([crupier[0], mazo[k]])
			if total == 20 or total == 21:
				var t := crupier[1]
				crupier[1] = mazo[k]
				mazo[k] = t
				cargado = true
				break
	fase = Fase.JUGANDO
	if es_blackjack(tuyas) or es_blackjack(crupier):
		_cerrar()


func pedir() -> void:
	if fase != Fase.JUGANDO:
		return
	tuyas.append(mazo.pop_back())
	if valor(tuyas) > 21:
		resultado = "te pasaste"
		pago = 0
		fase = Fase.FIN
	elif valor(tuyas) == 21:
		plantarte()


func plantarte() -> void:
	if fase != Fase.JUGANDO:
		return
	while valor(crupier) < PLANTA:
		crupier.append(mazo.pop_back())
	_cerrar()


# Dobla la apuesta, una carta mas y se planta (la UI cobra la otra apuesta antes)
func doblar() -> bool:
	if fase != Fase.JUGANDO or tuyas.size() != 2:
		return false
	apuesta *= 2
	tuyas.append(mazo.pop_back())
	if valor(tuyas) > 21:
		resultado = "te pasaste"
		pago = 0
		fase = Fase.FIN
	else:
		plantarte()
	return true


func _cerrar() -> void:
	var tu := valor(tuyas)
	var el := valor(crupier)
	if es_blackjack(tuyas) and not es_blackjack(crupier):
		resultado = "blackjack"
		pago = apuesta + apuesta * 3 / 2
	elif es_blackjack(crupier) and not es_blackjack(tuyas):
		resultado = "pierdes"
		pago = 0
	elif tu > 21:
		resultado = "te pasaste"
		pago = 0
	elif el > 21 or tu > el:
		resultado = "ganas"
		pago = apuesta * 2
	elif tu == el:
		resultado = "empate"
		pago = apuesta
	else:
		resultado = "pierdes"
		pago = 0
	fase = Fase.FIN
