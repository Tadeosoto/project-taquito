class_name Baccarat
extends RefCounted

# El baccarat del Sotano (BaccaratUI.gd lo muestra): le apuestas al PUNTO, a la BANCA o al EMPATE.
# Cartas como en Holdem.gd (0..51 = palo * 13 + rango - 2; as = 14). Valen: as 1, del 2 al 9 lo
# que dicen, 10 y figuras 0; la mano vale la suma sin las decenas. Con 8 o 9 de entrada (natural)
# nadie pide. El punto pide con 0 a 5; la banca pide segun su tabla (BANCA_PIDE) y la tercera del
# punto. Pagos: punto 1 a 1, banca 1 a 1 menos COMISION (5 %), empate 8 a 1 (en empate, al punto y
# a la banca se les regresa lo suyo).
# La trampa (docs/lore.md 11): con apuestas de ARREGLO_DESDE o mas, si ibas a ganar a veces (ARREGLO)
# el crupier "vuelve a barajar" y reparte otra vez. Se le nota: le sopla a las cartas (BaccaratUI).

const APUESTAS := ["punto", "banca", "empate"]
const COMISION := 0.05
const EMPATE_PAGA := 8
const ARREGLO_DESDE := 5
const ARREGLO := 0.3

var punto: Array[int] = []
var banca: Array[int] = []
var ganador := ""                    # "punto", "banca" o "empate"
var arreglo := false
var rng := RandomNumberGenerator.new()


func _init(semilla := 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()


static func valor_carta(c: int) -> int:
	var rango := c % 13 + 2
	if rango == 14:
		return 1
	return 0 if rango >= 10 else rango


static func valor(cartas: Array) -> int:
	var total := 0
	for c: int in cartas:
		total += valor_carta(c)
	return total % 10


# La tabla de la banca: con su total y la tercera del punto (-1 si el punto no pidio), ¿pide?
static func banca_pide(total: int, tercera: int) -> bool:
	if tercera < 0:
		return total <= 5
	var t := valor_carta(tercera)
	match total:
		0, 1, 2:
			return true
		3:
			return t != 8
		4:
			return t >= 2 and t <= 7
		5:
			return t >= 4 and t <= 7
		6:
			return t == 6 or t == 7
	return false


# Reparte una mano completa; `apostado` y `cuanto` son tu apuesta (para la trampa)
func jugar(apostado: String, cuanto: int) -> void:
	arreglo = false
	_repartir()
	if cuanto >= ARREGLO_DESDE and ganador == apostado and rng.randf() < ARREGLO:
		arreglo = true
		_repartir()


func _repartir() -> void:
	var mazo: Array[int] = []
	for c in 52:
		mazo.append(c)
	for i in range(mazo.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := mazo[i]
		mazo[i] = mazo[j]
		mazo[j] = t
	punto = [mazo.pop_back(), mazo.pop_back()]
	banca = [mazo.pop_back(), mazo.pop_back()]
	var natural := valor(punto) >= 8 or valor(banca) >= 8
	if not natural:
		var tercera := -1
		if valor(punto) <= 5:
			tercera = mazo.pop_back()
			punto.append(tercera)
		if banca_pide(valor(banca), tercera):
			banca.append(mazo.pop_back())
	var p := valor(punto)
	var b := valor(banca)
	ganador = "empate" if p == b else ("punto" if p > b else "banca")


# Lo que te regresa `cuanto` a `apostado` (con lo que pusiste), o 0
func pago(apostado: String, cuanto: int) -> int:
	if ganador == "empate":
		if apostado == "empate":
			return cuanto * (EMPATE_PAGA + 1)
		return cuanto
	if apostado != ganador:
		return 0
	if apostado == "banca":
		return cuanto + int(floor(cuanto * (1.0 - COMISION)))
	return cuanto * 2
