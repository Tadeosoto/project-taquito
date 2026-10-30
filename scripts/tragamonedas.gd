class_name Tragamonedas
extends RefCounted

# La placa de una maquinita de frutas: un tablero de 24 focos y 8 apuestas. Solo decide
# y lleva las cuentas, sin nodos ni pantalla (scripts/map/Maquinita.gd la dibuja); en
# coop la correria el servidor y mandaria el resultado. Las ideas de que el tendero
# cambie la dificultad por dia y de que los NPCs jueguen estan en docs/tragamonedas_notas.md.

# --- SISTEMA DE CONTROL DE LA PLACA REAL ---
enum ModoDojo { DOJO_1_FACIL, DOJO_2_NORMAL, DOJO_3_DIFICIL, DOJO_4_MUY_DIFICIL }

# Lo que le toca a la maquina ahorita, y se le nota afuera (Maquinita.mostrar_estado):
# SIN_MONEDAS: casi no tiene caja y no puede dar premio; lo que le apuestes la va
# llenando. SEGURA: rara, el siguiente tiro gana seguro.
enum Estado { NORMAL, SIN_MONEDAS, SEGURA }

const FRUTAS := ["MANZANA", "NARANJA", "CEREZA", "CAMPANA", "MELON", "SANDIA", "SIETE", "BAR"]

# Cuantas veces paga tu apuesta
const MULTIPLICADORES := {
	"MANZANA": 3, "NARANJA": 4, "CEREZA": 5, "CAMPANA": 7,
	"MELON": 10, "SANDIA": 15, "SIETE": 25, "BAR": 35,
}

# Los 24 focos en sentido del reloj desde la esquina de arriba a la izquierda
const TABLERO := [
	"BAR", "MANZANA", "NARANJA", "CEREZA", "MANZANA", "CAMPANA", "SANDIA",
	"MANZANA", "NARANJA", "CEREZA", "CAMPANA", "MELON",
	"SIETE", "MANZANA", "NARANJA", "CEREZA", "MANZANA", "CAMPANA", "SANDIA",
	"NARANJA", "CEREZA", "MANZANA", "NARANJA", "MELON",
]

# Lo que paga con mas frecuencia la bloquea el filtro de los DIP switches
const FRUTAS_GRANDES := ["BAR", "SIETE", "SANDIA"]
const PROBABILIDAD_BLOQUEO := {
	ModoDojo.DOJO_1_FACIL: 0.10,
	ModoDojo.DOJO_2_NORMAL: 0.35,
	ModoDojo.DOJO_3_DIFICIL: 0.60,
	ModoDojo.DOJO_4_MUY_DIFICIL: 0.85,
}
const CAJA_INICIAL := 100
# Con menos de esto en la caja, la maquina ya no da premio
const CAJA_MINIMA := 20
const PROBABILIDAD_SEGURA := 0.05
const PROBABILIDAD_SIN_MONEDAS := 0.2

# Una placa por maquina del mapa: el nodo se libera al alejarte, la caja no
static var _placas := {}

var dip_switch_actual: ModoDojo = ModoDojo.DOJO_2_NORMAL
var caja_monedas_interna: int = CAJA_INICIAL # Monedas que tiene la máquina en su interior al iniciar
# Toca ganar en el siguiente tiro
var segura := false


# La placa de la maquina `id` (su `origen`); la dificultad depende de cual sea, mas
# maquinas normales que de las otras. La caja y si es la segura se sortean en cada
# partida, para que no se aprenda cual tienda es la buena.
static func de(id: String) -> Tragamonedas:
	if not _placas.has(id):
		var placa := Tragamonedas.new()
		placa.segura = randf() < PROBABILIDAD_SEGURA
		placa.caja_monedas_interna = randi_range(3, CAJA_MINIMA - 1) if randf() < PROBABILIDAD_SIN_MONEDAS else randi_range(60, 150)
		var tiro := absi(hash(id)) % 10
		if tiro < 2:
			placa.dip_switch_actual = ModoDojo.DOJO_1_FACIL
		elif tiro < 7:
			placa.dip_switch_actual = ModoDojo.DOJO_2_NORMAL
		elif tiro < 9:
			placa.dip_switch_actual = ModoDojo.DOJO_3_DIFICIL
		else:
			placa.dip_switch_actual = ModoDojo.DOJO_4_MUY_DIFICIL
		_placas[id] = placa
	return _placas[id]


func estado() -> Estado:
	if segura:
		return Estado.SEGURA
	if caja_monedas_interna < CAJA_MINIMA:
		return Estado.SIN_MONEDAS
	return Estado.NORMAL


# Un tiro: `apuestas` es fruta -> monedas. Las monedas entran a la caja, se elige el foco
# y el premio sale de la caja. Regresa {destino, fruta, premio}
func girar(apuestas: Dictionary) -> Dictionary:
	# El estado es el de antes de las monedas de este tiro
	var estado_tiro := estado()
	var total := 0
	for fruta: String in apuestas:
		registrar_apuesta_en_caja(apuestas[fruta])
		total += apuestas[fruta]
	if estado_tiro == Estado.SEGURA and total > 0:
		return _tiro_seguro(apuestas, total)
	var destino_aleatorio := randi() % TABLERO.size()
	var destino: int
	if estado_tiro == Estado.SIN_MONEDAS:
		destino = buscar_casilla_manzana_cercana(destino_aleatorio, apuestas)
	else:
		destino = validar_y_ajustar_premio(destino_aleatorio, apuestas)
	var fruta_final: String = TABLERO[destino]
	# Si no alcanza ni el foco mas barato, paga lo que tenga
	var premio := mini(_costo(fruta_final, apuestas), caja_monedas_interna)
	restar_premio_de_caja(premio)
	return {"destino": destino, "fruta": fruta_final, "premio": premio}


# Cae en la fruta apostada que mas paga y siempre saca mas de lo apostado: con monedas
# repartidas justo al reves de lo que paga cada fruta (9, 7, 5, 4, 3, 2, 1) el mejor
# premio se queda corto. La caja se completa con lo que haga falta.
func _tiro_seguro(apuestas: Dictionary, total: int) -> Dictionary:
	var mejor := ""
	for fruta: String in apuestas:
		if apuestas[fruta] > 0 and (mejor == "" or _costo(fruta, apuestas) > _costo(mejor, apuestas)):
			mejor = fruta
	var premio := maxi(_costo(mejor, apuestas), total + 1)
	var focos: Array[int] = []
	for i in TABLERO.size():
		if TABLERO[i] == mejor:
			focos.append(i)
	segura = false
	registrar_apuesta_en_caja(maxi(premio - caja_monedas_interna, 0))
	restar_premio_de_caja(premio)
	return {"destino": focos.pick_random(), "fruta": mejor, "premio": premio}


# Filtro inteligente basado en la alcancía real
func validar_y_ajustar_premio(destino_original: int, apuestas: Dictionary) -> int:
	var fruta_original: String = TABLERO[destino_original]

	# REGLA 1: Si la máquina no tiene suficientes monedas físicas para pagar el premio, FORZAR PÉRDIDA
	if _costo(fruta_original, apuestas) > caja_monedas_interna:
		return buscar_casilla_manzana_cercana(destino_original, apuestas)

	# REGLA 2: Control de probabilidad por DIP Switches (Dojo)
	if fruta_original in FRUTAS_GRANDES and randf() < PROBABILIDAD_BLOQUEO[dip_switch_actual]:
		# El algoritmo intercepta el premio y te manda a una manzana (paga poco o nada)
		return buscar_casilla_manzana_cercana(destino_original, apuestas)

	return destino_original


# Simula el efecto "Near Miss" (Casi ganas): la manzana más cercana si no le apostaste,
# si no el foco más cercano que no pague nada, y si le apostaste a todo el que pague
# menos. Si caer en manzana te pagara, jugar solo a la manzana convendría más en las
# máquinas más difíciles.
func buscar_casilla_manzana_cercana(origen: int, apuestas: Dictionary) -> int:
	var mas_barata := origen
	var sin_premio := -1
	for i in range(1, TABLERO.size()):
		var chequeo := (origen + i) % TABLERO.size()
		var costo := _costo(TABLERO[chequeo], apuestas)
		if costo == 0:
			if TABLERO[chequeo] == "MANZANA":
				return chequeo
			if sin_premio < 0:
				sin_premio = chequeo
		if costo < _costo(TABLERO[mas_barata], apuestas):
			mas_barata = chequeo
	return sin_premio if sin_premio >= 0 else mas_barata


func _costo(fruta: String, apuestas: Dictionary) -> int:
	return apuestas.get(fruta, 0) * MULTIPLICADORES[fruta]


# Ajustar la entrada/salida de dinero de la alcancía física
func registrar_apuesta_en_caja(cantidad: int) -> void:
	caja_monedas_interna += cantidad


func restar_premio_de_caja(cantidad: int) -> void:
	caja_monedas_interna -= cantidad
