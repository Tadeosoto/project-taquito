class_name Carretes
extends RefCounted

# La placa de una maquinita EL GORDO (OlPley en el codigo) (la "Loteria de carretes" del Sotano): tres carretes con
# cartas de la loteria y El Tinaco de comodin. Solo decide y lleva las cuentas, como
# scripts/tragamonedas.gd con las de frutas; OlPleyUI la muestra. Una por gabinete.
# La casa hace trampa, como toda la vida (docs/lore.md 11, El Sotano):
#   NORMAL     gira al azar con los pesos de PESOS.
#   SIN_CAJA   la maquina casi no tiene: un premio que no alcance a pagar no sale.
#   CALIENTE   rara: el siguiente tiro gana seguro. Se le nota: la marquesina parpadea
#              (Sotano.gd, por `estado`).
# Pagos: tres iguales pagan PAGOS[carta] x la apuesta; si entre los tres hay un Tinaco que hace
# de comodin, paga doble ("EL TINACO PAGA DOBLE"). Las dos primeras iguales, o un Tinaco suelto,
# regresan la apuesta. Con PESOS el retorno es ~89 % y gana uno de cada cuatro tiros (calculado
# con todas las combinaciones, AG 2026-11-18); la caja y CALIENTE lo mueven tantito.

enum Estado { NORMAL, SIN_CAJA, CALIENTE }

const TINACO := 23
# carta (indice de CartasLoteria) -> veces la apuesta con tres iguales
const PAGOS := {8: 6, 5: 8, 0: 10, 6: 12, 1: 14, 4: 18, 9: 22, 2: 35, TINACO: 70}
# Cuantas veces sale cada carta en un carrete (mas peso = mas seguido)
const PESOS := {8: 9, 5: 8, 0: 7, 6: 6, 1: 5, 4: 4, 9: 3, 2: 2, TINACO: 2}
const CAJA_INICIO := 250
const CAJA_POCA := 60
const CALIENTE_PROB := 0.04
const CALIENTE_CAJA := 300
const APUESTA_MAX := 5

var caja := CAJA_INICIO
var estado := Estado.NORMAL
var rng := RandomNumberGenerator.new()


func _init(semilla := 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()


# Un tiro: {carretes: [a, b, c], pago: fichas que paga (ya con la apuesta multiplicada)}
func tirar(apuesta: int) -> Dictionary:
	caja += apuesta
	var r: Array[int] = []
	var pago := 0
	if estado == Estado.CALIENTE:
		r = _ganador()
		pago = pagar(r, apuesta)
		estado = Estado.NORMAL
	else:
		for _intento in 30:
			r = [_carta(), _carta(), _carta()]
			pago = pagar(r, apuesta)
			if pago <= caja:
				break
		if pago > caja:
			r = _perdedor()
			pago = 0
	caja -= pago
	_siguiente_estado()
	return {"carretes": r, "pago": pago}


# Lo que paga una tirada (sin tocar la caja)
static func pagar(r: Array, apuesta: int) -> int:
	var tinacos := r.count(TINACO)
	if tinacos == 3:
		return PAGOS[TINACO] * apuesta
	var otras := r.filter(func(c: int) -> bool: return c != TINACO)
	if otras.size() > 0 and otras.all(func(c: int) -> bool: return c == otras[0]):
		return PAGOS[otras[0]] * apuesta * (2 if tinacos > 0 else 1)
	if r[0] == r[1] or tinacos == 1:
		return apuesta
	return 0


func _carta() -> int:
	var total := 0
	for p: int in PESOS.values():
		total += p
	var tiro := rng.randi_range(1, total)
	for c: int in PESOS:
		tiro -= PESOS[c]
		if tiro <= 0:
			return c
	return 8


func _ganador() -> Array[int]:
	var cartas: Array = PESOS.keys().filter(func(c: int) -> bool: return c != TINACO and PAGOS[c] <= 10)
	var c: int = cartas[rng.randi_range(0, cartas.size() - 1)]
	return [c, c, c]


func _perdedor() -> Array[int]:
	var cartas: Array = PESOS.keys().filter(func(c: int) -> bool: return c != TINACO)
	cartas.shuffle()
	return [cartas[0], cartas[1], cartas[2]]


func _siguiente_estado() -> void:
	if caja < CAJA_POCA:
		estado = Estado.SIN_CAJA
	elif estado == Estado.SIN_CAJA:
		estado = Estado.NORMAL
	if estado == Estado.NORMAL and caja > CALIENTE_CAJA and rng.randf() < CALIENTE_PROB:
		estado = Estado.CALIENTE
