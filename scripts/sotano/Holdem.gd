class_name Holdem
extends RefCounted

# Texas Hold'em de limite fijo para la mesa del Sotano (PokerUI.gd la muestra). Solo reglas,
# cuentas y la IA de los vecinos; nada de nodos.
# Cartas: 0..51 = palo * 13 + (rango - 2), rango 2..14 (14 = as), palos picas, corazones,
# diamantes, treboles; el mismo orden que textures/sotano/baraja.png (tools/sotano/dibujar_baraja.gd).
# Limite fijo: las subidas son de CIEGA_GRANDE antes del turn y del doble despues, con TOPE subidas
# por ronda. Sin botes laterales: el que va todo por menos tambien puede ganar el bote entero (la
# casa lo arregla a su favor como todo lo demas). La casa se queda RAKE del bote (hasta RAKE_MAX).
# La casa hace trampa (docs/lore.md 11): "tramposo" es el de la gorra, que en el turn y el river
# sabe si te gana; si te gana sube, si no se va. Se le nota: nunca se va antes del river y siempre
# acierta (las lineas del cantinero y del miron lo dicen).

enum Fase { PREFLOP, FLOP, TURN, RIVER, FIN }

const CIEGA_CHICA := 1
const CIEGA_GRANDE := 2
const TOPE := 3
const RAKE := 0.1
const RAKE_MAX := 5
const NOMBRES := ["Carta alta", "Par", "Dos pares", "Tercia", "Escalera", "Color", "Full", "Póquer", "Escalera de color"]
const RANGOS := ["doses", "treses", "cuatros", "cincos", "seises", "sietes", "ochos", "nueves", "dieces", "jotas", "reinas", "reyes", "ases"]

var jugadores: Array = []           # Array de Dictionary: nombre, fichas, cartas, fuera, apostado, en_mano, todo, tipo, ultima
var boton := 0
var mesa: Array[int] = []           # las cartas de en medio
var mazo: Array[int] = []
var bote := 0
var fase := Fase.FIN
var turno := -1
var apuesta := 0                    # lo que hay que poner en esta ronda
var subidas := 0
var por_hablar: Array[int] = []
var ganadores: Array[int] = []
var mano_ganadora := ""
var rake := 0
var rng := RandomNumberGenerator.new()


func _init(semilla := 0) -> void:
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()


func agregar(nombre: String, fichas: int, tipo: String) -> void:
	jugadores.append({"nombre": nombre, "fichas": fichas, "cartas": [], "fuera": false, "apostado": 0,
		"en_mano": 0, "todo": false, "tipo": tipo, "ultima": ""})


# --- La mano ---

func empezar() -> bool:
	var sentados := jugadores.filter(func(j: Dictionary) -> bool: return j.fichas > 0)
	if sentados.size() < 2:
		return false
	mazo = []
	for c in 52:
		mazo.append(c)
	_barajar()
	mesa.clear()
	bote = 0
	rake = 0
	ganadores.clear()
	mano_ganadora = ""
	for j: Dictionary in jugadores:
		j.cartas = []
		j.fuera = j.fichas <= 0
		j.apostado = 0
		j.en_mano = 0
		j.todo = false
		j.ultima = ""
	boton = _siguiente(boton)
	for _vuelta in 2:
		for i in jugadores.size():
			if not jugadores[i].fuera:
				jugadores[i].cartas.append(mazo.pop_back())
	fase = Fase.PREFLOP
	apuesta = 0
	subidas = 0
	var chica := _siguiente(boton)
	var grande := _siguiente(chica)
	_poner(chica, CIEGA_CHICA)
	jugadores[chica].ultima = "ciega chica"
	_poner(grande, CIEGA_GRANDE)
	jugadores[grande].ultima = "ciega grande"
	apuesta = CIEGA_GRANDE
	_ronda_desde(_siguiente(grande))
	return true


func _barajar() -> void:
	for i in range(mazo.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var t: int = mazo[i]
		mazo[i] = mazo[k]
		mazo[k] = t


func _siguiente(i: int) -> int:
	for _k in jugadores.size():
		i = (i + 1) % jugadores.size()
		if not jugadores[i].fuera and jugadores[i].fichas + jugadores[i].apostado > 0:
			return i
	return i


func _poner(i: int, cuanto: int) -> void:
	var j: Dictionary = jugadores[i]
	cuanto = mini(cuanto, j.fichas)
	j.fichas -= cuanto
	j.apostado += cuanto
	j.en_mano += cuanto
	bote += cuanto
	if j.fichas == 0:
		j.todo = true


func _ronda_desde(primero: int) -> void:
	por_hablar.clear()
	var i := primero
	for _k in jugadores.size():
		var j: Dictionary = jugadores[i]
		if not j.fuera and not j.todo:
			por_hablar.append(i)
		i = (i + 1) % jugadores.size()
	turno = por_hablar[0] if not por_hablar.is_empty() else -1
	if turno < 0:
		_cerrar_ronda()


func vivos() -> Array[int]:
	var r: Array[int] = []
	for i in jugadores.size():
		if not jugadores[i].fuera:
			r.append(i)
	return r


func por_igualar(i: int) -> int:
	return apuesta - jugadores[i].apostado


func tamano_subida() -> int:
	return CIEGA_GRANDE if fase <= Fase.FLOP else CIEGA_GRANDE * 2


func puede_subir(i: int) -> bool:
	return subidas < TOPE and jugadores[i].fichas > por_igualar(i)


# accion: "pasar" (o igualar si hay que poner), "subir", "retirarse". Regresa lo que hizo, en espanol
func actuar(i: int, accion: String) -> String:
	if i != turno or fase == Fase.FIN:
		return ""
	var j: Dictionary = jugadores[i]
	var debe := por_igualar(i)
	var dijo := ""
	match accion:
		"retirarse":
			if debe <= 0:
				dijo = "pasa"
			else:
				j.fuera = true
				dijo = "se retira"
		"subir":
			if puede_subir(i):
				_poner(i, debe + tamano_subida())
				apuesta = j.apostado
				subidas += 1
				dijo = "sube a %d" % apuesta
				# Todos los demas vuelven a hablar
				var resto: Array[int] = []
				var k := (i + 1) % jugadores.size()
				for _n in jugadores.size() - 1:
					if not jugadores[k].fuera and not jugadores[k].todo:
						resto.append(k)
					k = (k + 1) % jugadores.size()
				por_hablar = [i]
				por_hablar.append_array(resto)
			else:
				return actuar(i, "pasar")
		_:
			if debe > 0:
				_poner(i, debe)
				dijo = "va con %d" % debe if not j.todo else "va con todo"
			else:
				dijo = "pasa"
	j.ultima = dijo
	por_hablar.erase(i)
	if vivos().size() == 1:
		_terminar()
		return dijo
	if por_hablar.is_empty():
		_cerrar_ronda()
	else:
		turno = por_hablar[0]
	return dijo


func _cerrar_ronda() -> void:
	for j: Dictionary in jugadores:
		j.apostado = 0
	apuesta = 0
	subidas = 0
	match fase:
		Fase.PREFLOP:
			mazo.pop_back()
			for _k in 3:
				mesa.append(mazo.pop_back())
			fase = Fase.FLOP
		Fase.FLOP:
			mazo.pop_back()
			mesa.append(mazo.pop_back())
			fase = Fase.TURN
		Fase.TURN:
			mazo.pop_back()
			mesa.append(mazo.pop_back())
			fase = Fase.RIVER
		Fase.RIVER:
			_terminar()
			return
	var quedan := vivos().filter(func(i: int) -> bool: return not jugadores[i].todo)
	if quedan.size() <= 1:
		# Todos van con todo: se reparte lo que falta sin apostar
		_cerrar_ronda()
		return
	_ronda_desde(_siguiente(boton))


func _terminar() -> void:
	fase = Fase.FIN
	turno = -1
	var v := vivos()
	rake = mini(int(floor(bote * RAKE)), RAKE_MAX) if mesa.size() >= 3 else 0
	var premio := bote - rake
	if v.size() == 1:
		ganadores = [v[0]]
		mano_ganadora = ""
	else:
		var mejor: Array = []
		for i in v:
			var s := Holdem.mejor(jugadores[i].cartas + mesa)
			var c := Holdem.comparar(s, mejor) if not mejor.is_empty() else 1
			if c > 0:
				mejor = s
				ganadores = [i]
			elif c == 0:
				ganadores.append(i)
		mano_ganadora = Holdem.nombre(mejor)
	var parte := premio / ganadores.size()
	for i in ganadores:
		jugadores[i].fichas += parte
	jugadores[ganadores[0]].fichas += premio - parte * ganadores.size()
	bote = 0


# --- La IA de los vecinos ---

func decidir(i: int) -> String:
	var j: Dictionary = jugadores[i]
	var debe := por_igualar(i)
	var fuerza := _fuerza(i)
	match j.tipo:
		"tramposo":
			# Sabe si te gana en el turn y el river (la trampa de la casa)
			if fase >= Fase.TURN and not jugadores[0].fuera:
				var suya := Holdem.mejor(j.cartas + mesa)
				var tuya := Holdem.mejor(jugadores[0].cartas + mesa)
				if Holdem.comparar(suya, tuya) > 0:
					return "subir" if puede_subir(i) else "pasar"
				return "pasar" if debe <= 0 else "retirarse"
			return "pasar" if fuerza > 0.2 or debe <= 0 else "retirarse"
		"flojo":
			if fuerza > 0.85 and puede_subir(i):
				return "subir"
			return "pasar" if fuerza > 0.22 or debe <= 0 else "retirarse"
		"farol":
			if rng.randf() < 0.25 and puede_subir(i):
				return "subir"
			if fuerza > 0.7 and puede_subir(i):
				return "subir"
			return "pasar" if fuerza > 0.3 or debe <= 0 else "retirarse"
		_:   # "cerrado"
			if fuerza > 0.72 and puede_subir(i):
				return "subir"
			return "pasar" if fuerza > 0.45 or debe <= 0 else "retirarse"


# 0..1: que tan buena se ve su mano (antes del flop por sus dos cartas; despues por la categoria)
func _fuerza(i: int) -> float:
	var c: Array = jugadores[i].cartas
	var a := Holdem.rango(c[0])
	var b := Holdem.rango(c[1])
	if mesa.is_empty():
		var f := (maxi(a, b) - 2) / 12.0 * 0.5 + (mini(a, b) - 2) / 12.0 * 0.2
		if a == b:
			f += 0.35
		if Holdem.palo(c[0]) == Holdem.palo(c[1]):
			f += 0.08
		if absi(a - b) == 1:
			f += 0.05
		return clampf(f, 0.0, 1.0)
	var s := Holdem.mejor(c + mesa)
	var base: float = [0.15, 0.45, 0.65, 0.75, 0.82, 0.86, 0.92, 0.97, 1.0][s[0]]
	# Un par que esta en la mesa no es suyo
	if s[0] == 1 and not (a == s[1] or b == s[1]):
		base = 0.2
	return base


# --- Las manos ---

static func rango(c: int) -> int:
	return c % 13 + 2


static func palo(c: int) -> int:
	return c / 13


# La mejor de 5 de entre 5 a 7 cartas: [categoria, desempates...]
static func mejor(cartas: Array) -> Array:
	var mejor_s: Array = []
	var n := cartas.size()
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						var s := evaluar([cartas[a], cartas[b], cartas[c], cartas[d], cartas[e]])
						if mejor_s.is_empty() or comparar(s, mejor_s) > 0:
							mejor_s = s
	return mejor_s


static func evaluar(cinco: Array) -> Array:
	var rs: Array[int] = []
	var cuenta := {}
	var palos := {}
	for c: int in cinco:
		var r := rango(c)
		rs.append(r)
		cuenta[r] = cuenta.get(r, 0) + 1
		palos[palo(c)] = true
	rs.sort()
	rs.reverse()
	var color := palos.size() == 1
	var unicos: Array = cuenta.keys()
	unicos.sort()
	unicos.reverse()
	var escalera := 0
	if unicos.size() == 5:
		if unicos[0] - unicos[4] == 4:
			escalera = unicos[0]
		elif unicos == [14, 5, 4, 3, 2]:
			escalera = 5
	if escalera and color:
		return [8, escalera]
	# Por cuantas veces sale cada rango y luego por rango
	var grupos: Array = unicos.duplicate()
	grupos.sort_custom(func(x: int, y: int) -> bool: return cuenta[x] > cuenta[y] or (cuenta[x] == cuenta[y] and x > y))
	var veces: Array = grupos.map(func(r: int) -> int: return cuenta[r])
	if veces[0] == 4:
		return [7] + grupos
	if veces[0] == 3 and veces[1] == 2:
		return [6] + grupos
	if color:
		return [5] + rs
	if escalera:
		return [4, escalera]
	if veces[0] == 3:
		return [3] + grupos
	if veces[0] == 2 and veces[1] == 2:
		return [2] + grupos
	if veces[0] == 2:
		return [1] + grupos
	return [0] + rs


static func comparar(a: Array, b: Array) -> int:
	for k in mini(a.size(), b.size()):
		if a[k] != b[k]:
			return 1 if a[k] > b[k] else -1
	return 0


static func nombre(s: Array) -> String:
	if s.is_empty():
		return ""
	var r := func(v: int) -> String: return RANGOS[v - 2]
	match s[0]:
		1:
			return "Par de %s" % r.call(s[1])
		2:
			return "Dos pares, %s y %s" % [r.call(s[1]), r.call(s[2])]
		3:
			return "Tercia de %s" % r.call(s[1])
		6:
			return "Full de %s" % r.call(s[1])
		7:
			return "Póquer de %s" % r.call(s[1])
	return NOMBRES[s[0]]
