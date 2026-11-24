extends Node

# Autoload `Noches`: la noche sin fin (docs/especificaciones.md 1.2). Ya no hay partida de 3
# noches: el juego no se acaba y esto lleva la cuenta. Es autoload porque Partida, Zombis y
# Ciclo son nodos de cada escena y arrancan de cero al cruzar una reja (PasoColonia) o al ir a
# la arena de un jefe (PasoArena); la cuenta tiene que seguir.
#
# - `noche`: cuantas noches han caido. Desmayarte NO la reinicia (como Dark Souls).
# - `record`: la mejor noche sobrevivida, en user://noches.cfg (la pantalla de inicio la dice).
# - Los hitos (resources/noches/hitos.tres, TablaHitos): que sale desde que noche, el tazo
#   holografico de premio al sobrevivir la noche del hito y los jefes que se repiten despues.
# - `bolsa`: lo que dejaste al desmayarte, para que sobreviva a cambiar de escena y al
#   guardado (GuardiaBolsa.gd la pone en el mundo).
#
# No lo nombran los scripts de tools/ (corren sin autoloads): quien lo usa desde un script que
# tools/ podria cargar lo busca con get_node_or_null("/root/Noches").

signal cambio

const ARCHIVO_RECORD := "user://noches.cfg"
const TABLA := "res://resources/noches/hitos.tres"
const TEXTO_SOBREVIVISTE := "Sobreviviste la noche %d"
# Los jefes, en el orden en que se repiten despues del ultimo hito
const JEFES := [HitoNoche.Tipo.GARRAFONERO, HitoNoche.Tipo.MADRE_CARCAMO, HitoNoche.Tipo.MOJIGANGA]

var noche := 0
var record := 0
var hitos_dados := {}   # noche del hito -> true: ya se dio su tazo
# Lo que dejaste al desmayarte; vacio si no hay bolsa. Llaves: items (Array[InventoryItemData]),
# posicion (Vector3), escena (ruta), lider_vivo (bool), guardias_muertos (int)
var bolsa := {}
var tabla: TablaHitos


func _ready() -> void:
	tabla = load(TABLA) as TablaHitos
	if tabla == null:
		push_warning("Noches: no pude cargar %s" % TABLA)
		tabla = TablaHitos.new()
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_RECORD) == OK:
		record = int(cfg.get_value("noches", "record", 0))


# Partida nueva (Guardado.nueva): el record se queda
func reiniciar() -> void:
	noche = 0
	hitos_dados.clear()
	bolsa = {}
	cambio.emit()


# --- Las noches ---

func anochecio() -> void:
	noche += 1
	cambio.emit()


# Al amanecer: sube el record si toca. Regresa el hito de esa noche cuyo tazo hay que dar
# ahora (Partida hace el show), o null
func amanecio() -> HitoNoche:
	if noche <= 0:
		return null
	if noche > record:
		record = noche
		var cfg := ConfigFile.new()
		cfg.set_value("noches", "record", record)
		cfg.save(ARCHIVO_RECORD)
	cambio.emit()
	var hito := hito_de(noche)
	if hito and not hitos_dados.has(hito.noche):
		hitos_dados[hito.noche] = true
		return hito
	return null


func texto_sobreviviste() -> String:
	return TEXTO_SOBREVIVISTE % noche


# El hito que cae justo en la noche `n`, o null
func hito_de(n: int) -> HitoNoche:
	for hito in tabla.hitos:
		if hito.noche == n:
			return hito
	return null


# Si ese hito ya llego (sus cosas siguen todas las noches siguientes)
func hay(tipo: HitoNoche.Tipo) -> bool:
	for hito in tabla.hitos:
		if hito.tipo == tipo and noche >= hito.noche:
			return true
	return false


func _ultimo_hito() -> int:
	var ultimo := 0
	for hito in tabla.hitos:
		ultimo = maxi(ultimo, hito.noche)
	return ultimo


# El jefe de la noche `n` (un HitoNoche.Tipo de JEFES) o -1. En su hito, el suyo; despues del
# ultimo hito, uno cada `repetir_cada` noches, por turnos
func jefe_de(n := -1) -> int:
	if n < 0:
		n = noche
	var hito := hito_de(n)
	if hito and hito.tipo in JEFES:
		return hito.tipo
	var ultimo := _ultimo_hito()
	if n > ultimo and tabla.repetir_cada > 0 and (n - ultimo) % tabla.repetir_cada == 0:
		var turno := (n - ultimo) / tabla.repetir_cada - 1
		return JEFES[turno % JEFES.size()]
	return -1


# Cuanto mas vida traen los jefes: 1 hasta el ultimo hito y `repetir_fuerza` por cada vuelta
# de jefes empezada despues (la primera repeticion ya es mas fuerte)
func fuerza_jefe(n := -1) -> float:
	if n < 0:
		n = noche
	var ultimo := _ultimo_hito()
	if n <= ultimo:
		return 1.0
	var vuelta := ceili(float(n - ultimo) / float(maxi(tabla.repetir_cada, 1) * JEFES.size()))
	return pow(tabla.repetir_fuerza, vuelta)


# La arena de ese jefe esta abierta esta noche (Partida pone la flecha): desde su hito
func arena_abierta(tipo: HitoNoche.Tipo) -> bool:
	return hay(tipo)


# Lo que crecen las turbas y los sueltos vivos que caben esta noche (Zombis, Director)
func factor_turba() -> float:
	return pow(tabla.crecer_turbas, maxi(noche - 1, 0))


# --- El premio del hito ---

# El tazo del hito: el suyo si no lo tienes; si no, un holografico que te falte (sin los
# excluidos); si ya los tienes todos, uno al azar. Lo da (Tazos.dar_tazo) y lo regresa
func dar_premio(hito: HitoNoche) -> TazoData:
	var tazos := get_node("/root/Tazos")
	var tazo: TazoData = null
	if hito.tazo_id != "" and not tazos.coleccion.has(hito.tazo_id):
		for t: TazoData in tazos.todos:
			if t.id == hito.tazo_id:
				tazo = t
	if tazo == null:
		var holos: Array = tazos.todos.filter(func(t: TazoData) -> bool:
			return t.rareza == TazoData.Rareza.HOLO and not tabla.tazos_excluidos.has(t.id))
		var nuevos := holos.filter(func(t: TazoData) -> bool: return not tazos.coleccion.has(t.id))
		var de := nuevos if not nuevos.is_empty() else holos
		if de.is_empty():
			return null
		tazo = de.pick_random()
	tazos.dar_tazo(tazo)
	return tazo


# --- La bolsa del desmayo ---

func hay_bolsa() -> bool:
	return not bolsa.is_empty()


# Caiste otra vez antes de recuperarla: la vieja se pierde con todo
func nueva_bolsa(items: Array[InventoryItemData], posicion: Vector3, escena: String) -> void:
	bolsa = {"items": items, "posicion": posicion, "escena": escena, "lider_vivo": true, "guardias_muertos": 0}
	cambio.emit()


func quitar_bolsa() -> void:
	bolsa = {}
	cambio.emit()


# --- Guardado (Guardado.gd) ---

func guardar_en(cfg: ConfigFile) -> void:
	cfg.set_value("noches", "noche", noche)
	cfg.set_value("noches", "hitos_dados", hitos_dados.keys())
	if bolsa.is_empty():
		cfg.set_value("noches", "bolsa", {})
		return
	var copia := bolsa.duplicate()
	copia["items"] = get_node("/root/Guardado").rutas(bolsa["items"])
	cfg.set_value("noches", "bolsa", copia)


func cargar_de(cfg: ConfigFile) -> void:
	noche = int(cfg.get_value("noches", "noche", 0))
	hitos_dados.clear()
	for n in cfg.get_value("noches", "hitos_dados", []):
		hitos_dados[int(n)] = true
	var guardada: Dictionary = cfg.get_value("noches", "bolsa", {})
	bolsa = {}
	if not guardada.is_empty():
		bolsa = guardada.duplicate()
		bolsa["items"] = get_node("/root/Guardado").objetos(guardada.get("items", []))
		if (bolsa["items"] as Array).is_empty():
			bolsa = {}
	cambio.emit()
