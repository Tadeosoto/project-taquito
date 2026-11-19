class_name Ruleta
extends RefCounted

# La ruleta del Sotano (RuletaUI.gd la muestra; la rueda es Ruleta_rueda de sotano.py): solo se le
# va al ROJO, al NEGRO o al VERDE (el cero). Rojo y negro pagan 1 a 1, verde 35 a 1. Ruleta
# europea de 37 casillas en su orden (ORDEN, el mismo de la rueda en Blender).
# Dobletear: despues de ganar puedes volver a jugar todo lo que llevas (apuesta y premio) una vez;
# si pierdes al dobletear se va todo.
# La trampa (docs/lore.md 11): con FRENO_DESDE fichas o mas en juego, a veces (FRENO) la bola "brinca"
# a la casilla de al lado, que siempre es de otro color. Se le nota: el crupier le da un golpecito a
# la mesa (RuletaUI lo dice).

const ORDEN := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14,
	31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const ROJOS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const COLORES := ["rojo", "negro", "verde"]
const PAGA := {"rojo": 1, "negro": 1, "verde": 35}
const FRENO_DESDE := 10
const FRENO := 0.3

var freno := false                   # si la ultima tirada la freno la casa
var rng := RandomNumberGenerator.new()


func _init(semilla := 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()


static func color(n: int) -> String:
	if n == 0:
		return "verde"
	return "rojo" if ROJOS.has(n) else "negro"


# Tira la bola: el numero que sale. `en_juego` son las fichas que arriesgas a `apostado`
func tirar(apostado: String, en_juego: int) -> int:
	freno = false
	var i := rng.randi_range(0, ORDEN.size() - 1)
	var n: int = ORDEN[i]
	if color(n) == apostado and en_juego >= FRENO_DESDE and rng.randf() < FRENO:
		i = (i + 1) % ORDEN.size()
		if color(ORDEN[i]) == apostado:
			i = (i + 1) % ORDEN.size()
		n = ORDEN[i]
		freno = true
	return n


# Cuanto te regresa `en_juego` a `apostado` si sale `n` (con lo que pusiste), o 0
static func premio(apostado: String, en_juego: int, n: int) -> int:
	if color(n) != apostado:
		return 0
	return en_juego * (PAGA[apostado] + 1)
