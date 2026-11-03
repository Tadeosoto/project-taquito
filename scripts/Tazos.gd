extends Node

# Autoload `Tazos`: los tazos que te han salido en las bolsas especiales de Takis, los puntos
# de habilidad y en que los gastaste (Habilidades.gd). Como PiezasMapa: no se pierden al
# desmayarte y duran lo que la partida (reiniciar). Propuesta de AG (docs/especificaciones.md).
#
# Puntos: los de los tazos, uno por noche que sobrevives (Partida.gd) y PUNTOS_SERIE por juntar
# una serie completa, una vez. Subir una habilidad cuesta su `costo` de ese nivel; bajarla te
# los regresa.
#
# No nombra Cartera, Salud ni Inventory: lo cargan scripts de tools/ a traves de player.gd.

signal cambio
signal nuevo_tazo(tazo: TazoData)
signal serie_completa(serie: int)

# Todos los .tres de esta carpeta (los escribe tools/tazos/caras.gd), ordenados por numero
const CARPETA := "res://resources/tazos/"
# Que tan seguido sale cada rareza en una bolsa (comun, raro, holo)
const PESOS_RAREZA := [65, 28, 7]
const PUNTOS_INICIO := 2
const PUNTOS_POR_NOCHE := 1
const PUNTOS_SERIE := 2     # por juntar los 12 de una serie, una vez

var todos: Array[TazoData] = []
var puntos := PUNTOS_INICIO
var niveles := {}           # id de habilidad -> nivel
var desbloqueadas := {}     # id de habilidad -> true
var coleccion: Array[String] = []   # ids de tazo, con repetidos, en el orden en que salieron
var series_premiadas := {}          # serie -> true, ya dio sus PUNTOS_SERIE
var ultima_serie := -1              # la serie que completo la ultima bolsa, o -1 (para el show)
var segundo_aire_usado := false     # se puede una vez por noche
var rareza_forzada := -1            # para probar el show en el safehouse (Shift+O); -1 = al azar


func _ready() -> void:
	for archivo in ResourceLoader.list_directory(CARPETA):
		if not archivo.ends_with(".tres"):
			continue
		var tazo := load(CARPETA + archivo) as TazoData
		if tazo:
			todos.append(tazo)
		else:
			push_warning("Tazos: no pude cargar %s" % archivo)
	todos.sort_custom(func(a: TazoData, b: TazoData) -> bool: return a.numero < b.numero)


func reiniciar() -> void:
	puntos = PUNTOS_INICIO
	niveles.clear()
	desbloqueadas.clear()
	coleccion.clear()
	series_premiadas.clear()
	ultima_serie = -1
	segundo_aire_usado = false
	cambio.emit()


# --- Puntos y habilidades ---

func gastados() -> int:
	var total := 0
	for id: String in niveles:
		var costos: Array = Habilidades.dato(id)["costo"]
		for i in niveles[id]:
			total += costos[i]
	return total


func libres() -> int:
	return puntos - gastados()


func nivel(id: String) -> int:
	return niveles.get(id, 0)


func disponible(id: String) -> bool:
	return not Habilidades.dato(id)["bloqueada"] or desbloqueadas.has(id)


# Lo que cuesta el siguiente nivel; -1 si ya esta al maximo
func costo_siguiente(id: String) -> int:
	var dato := Habilidades.dato(id)
	var n := nivel(id)
	return dato["costo"][n] if n < dato["niveles"] else -1


func puede_subir(id: String) -> bool:
	var costo := costo_siguiente(id)
	return disponible(id) and costo >= 0 and costo <= libres()


func subir(id: String) -> bool:
	if not puede_subir(id):
		return false
	niveles[id] = nivel(id) + 1
	cambio.emit()
	return true


func bajar(id: String) -> bool:
	if nivel(id) <= 0:
		return false
	niveles[id] = nivel(id) - 1
	if niveles[id] == 0:
		niveles.erase(id)
	cambio.emit()
	return true


func dar_puntos(cuantos: int) -> void:
	puntos += cuantos
	cambio.emit()


# Al anochecer se puede volver a usar Segundo aire (Partida.gd)
func nueva_noche() -> void:
	segundo_aire_usado = false


# --- Lo que hace cada habilidad, para quien la usa ---

func factor_vida() -> float:
	return 1.0 + nivel("vida") * Habilidades.VIDA_POR_NIVEL


func factor_dano() -> float:
	return 1.0 + nivel("fuerza") * Habilidades.FUERZA_POR_NIVEL


func factor_velocidad() -> float:
	return 1.0 + nivel("velocidad") * Habilidades.VELOCIDAD_POR_NIVEL


func factor_alcance() -> float:
	return 1.0 + nivel("alcance") * Habilidades.ALCANCE_POR_NIVEL


func factor_curacion() -> float:
	return 1.0 + nivel("buen_diente") * Habilidades.BUEN_DIENTE_POR_NIVEL


func factor_dano_noche() -> float:
	return 1.0 - nivel("piel_dura") * Habilidades.PIEL_DURA_POR_NIVEL


func pesos_extra() -> int:
	return nivel("mas_pesos") * Habilidades.MAS_PESOS_POR_NIVEL


func factor_precio() -> float:
	return 1.0 - nivel("regateo") * Habilidades.REGATEO_POR_NIVEL


func espacio_extra() -> int:
	return nivel("mochilero") * Habilidades.MOCHILERO_POR_NIVEL


func factor_persigue() -> float:
	return pow(Habilidades.PIES_DE_GATO_PERSIGUE, nivel("pies_de_gato"))


func extra_aparicion() -> float:
	return nivel("pies_de_gato") * Habilidades.PIES_DE_GATO_LEJOS


func probabilidad_bolsa() -> float:
	return Habilidades.BUENA_RACHA_BOLSA[nivel("buena_racha")]


func tiene(id: String) -> bool:
	return nivel(id) > 0


# --- Bolsas ---

# El tazo que sale en una bolsa. Primero la rareza (PESOS_RAREZA, o `rareza` para probar) y
# luego uno de esa rareza, de preferencia uno que no tengas. Uno repetido da sus puntos igual
func abrir_bolsa(rareza := -1) -> TazoData:
	if todos.is_empty():
		return null
	if rareza < 0:
		rareza = rareza_forzada
	if rareza < 0:
		var tiro := randi_range(1, PESOS_RAREZA[0] + PESOS_RAREZA[1] + PESOS_RAREZA[2])
		rareza = 0 if tiro <= PESOS_RAREZA[0] else (1 if tiro <= PESOS_RAREZA[0] + PESOS_RAREZA[1] else 2)
	var de_esa := todos.filter(func(t: TazoData) -> bool: return t.rareza == rareza)
	if de_esa.is_empty():
		de_esa = todos.duplicate()
	var nuevos := de_esa.filter(func(t: TazoData) -> bool: return not coleccion.has(t.id))
	var tazo: TazoData = (nuevos if not nuevos.is_empty() else de_esa).pick_random()
	dar_tazo(tazo)
	return tazo


# Lo agrega a la coleccion con sus puntos, lo que desbloquea y el premio si completa su serie
func dar_tazo(tazo: TazoData) -> void:
	coleccion.append(tazo.id)
	puntos += tazo.puntos
	if tazo.desbloquea != "":
		desbloqueadas[tazo.desbloquea] = true
	ultima_serie = -1
	if completa(tazo.serie) and not series_premiadas.has(tazo.serie):
		series_premiadas[tazo.serie] = true
		puntos += PUNTOS_SERIE
		ultima_serie = tazo.serie
		serie_completa.emit(tazo.serie)
	nuevo_tazo.emit(tazo)
	cambio.emit()


func es_repetido(tazo: TazoData) -> bool:
	return coleccion.count(tazo.id) > 1


func cuantos(tazo: TazoData) -> int:
	return coleccion.count(tazo.id)


func de_serie(serie: int) -> Array[TazoData]:
	return todos.filter(func(t: TazoData) -> bool: return t.serie == serie)


func cuantos_de_serie(serie: int) -> int:
	var n := 0
	for tazo in de_serie(serie):
		if coleccion.has(tazo.id):
			n += 1
	return n


func completa(serie: int) -> bool:
	var de_esa := de_serie(serie)
	return not de_esa.is_empty() and cuantos_de_serie(serie) == de_esa.size()


func numero_de_series() -> int:
	var mayor := -1
	for tazo in todos:
		mayor = maxi(mayor, tazo.serie)
	return mayor + 1


# Uno de cada que tienes, en el orden en que te salieron
func distintos() -> Array[TazoData]:
	var vistos: Array[TazoData] = []
	for id in coleccion:
		for tazo in todos:
			if tazo.id == id and not vistos.has(tazo):
				vistos.append(tazo)
	return vistos


func tazo_que_desbloquea(habilidad: String) -> TazoData:
	for tazo in todos:
		if tazo.desbloquea == habilidad:
			return tazo
	return null
