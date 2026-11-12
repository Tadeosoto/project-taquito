extends Node

# Las misiones (docs/especificaciones.md 6, docs/misiones.md 5). Autoload `Misiones`: las que
# traes aceptadas (el diario), cual es la activa, en que paso va cada una y la paga. Lo que esta
# en el mundo (los que las dan, los lugares, la flecha) es de scripts/map/MisionesMundo.gd.
#
# - La gente las da de dia, sean de dia o de noche. Se pueden traer todas las que quieras, pero
#   solo avanza la activa: las demas esperan con su avance guardado.
# - Cada paso tiene su hora (PasoMision.cuando). Fuera de ella la mision espera: no falla y su
#   tiempo no corre. Una de dia que no acabaste sigue al dia siguiente.
# - Las de LUGAR (MisionData.inicio) no entran al diario: empiezan en el sitio y se juegan ahi.
# - Cada una se hace una vez al dia; si se acaba el tiempo, falla y se puede intentar mañana.
# - Sobrevive al cambio de escena (es autoload); `reiniciar()` solo al empezar partida.

signal cambio
signal termino(mision: MisionData, exito: bool, texto: String)
signal sobra(objeto: InventoryItemData)

const ARCHIVOS := [
	"res://resources/misiones/encargo.tres",
	"res://resources/misiones/garrafones.tres",
	"res://resources/misiones/perro.tres",
	"res://resources/misiones/cangurera.tres",
	"res://resources/misiones/pelota.tres",
	"res://resources/misiones/tortillas.tres",
	"res://resources/misiones/agua_fila.tres",
	"res://resources/misiones/chiles.tres",
	"res://resources/misiones/medicina_noche.tres",
]
const REVISAR_CADA := 0.25

var todas: Array[MisionData] = []
# Las del diario, en el orden en que se aceptaron (la activa incluida si es de DADOR)
var aceptadas: Array[MisionData] = []
var activa: MisionData = null
var indice_paso := 0
# La gente ofrece de dia; al aviso de atardecer ya no
var ofreciendo := true
var es_noche := false
# Traes algo levantado para la activa (el perro): MisionesMundo lo pone
var manos_ocupadas := false
var tiempo_queda := 0.0
var visitados := 0
var meta_visitas := 1
# Lo pone MisionesMundo: a donde apuntan los mapas
var hay_objetivo := false
var objetivo := Vector2.ZERO
var objetivo_radio := 0.0
# Lo pone MisionesMundo: los dadores con inicial (MisionData.inicial) que tienen trabajo ahorita,
# [[Vector2 xz, "C"], ...], para los mapas
var dadores: Array = []

var _hechas := {}
var _espera := 0.0
# id -> {"paso", "visitados", "tiempo"} de las que no son la activa
var _guardado := {}
# La que estaba activa antes de empezar una de LUGAR: vuelve al acabar esta
var _previa: MisionData = null


func _ready() -> void:
	for ruta: String in ARCHIVOS:
		var mision := load(ruta) as MisionData
		if mision:
			todas.append(mision)


func paso() -> PasoMision:
	return activa.pasos[indice_paso] if activa else null


func hecha_hoy(mision: MisionData) -> bool:
	return _hechas.has(mision.id)


func aceptada(mision: MisionData) -> bool:
	return aceptadas.has(mision)


func disponible(mision: MisionData) -> bool:
	return ofreciendo and not aceptada(mision) and not hecha_hoy(mision) \
			and not ya_tienes_el_premio(mision)


# La de la cangurera ya no se ofrece si traes una: solo se puede traer una
func ya_tienes_el_premio(mision: MisionData) -> bool:
	var inventario := get_node("/root/Inventory")
	for premio in mision.premios:
		if premio.cangurera and inventario.cangurera != null:
			return true
	return false


# --- La hora ---

func a_su_hora(p: PasoMision) -> bool:
	if p == null:
		return false
	match p.cuando:
		PasoMision.Cuando.DIA:
			return not es_noche
		PasoMision.Cuando.NOCHE:
			return es_noche
	return true


# El paso actual de la activa se puede cumplir ahora
func en_hora() -> bool:
	return a_su_hora(paso())


# "de noche" / "de día" / "": para el diario y la linea de abajo
func hora_que_falta(p: PasoMision) -> String:
	if p == null or a_su_hora(p):
		return ""
	return "de noche" if p.cuando == PasoMision.Cuando.NOCHE else "de día"


# --- Aceptar y elegir ---

func aceptar(mision: MisionData) -> void:
	if not disponible(mision):
		return
	aceptadas.append(mision)
	_guardado[mision.id] = _nuevo_avance(mision, 0)
	if activa == null:
		_poner_activa(mision)
	else:
		cambio.emit()


# La que avanza (el diario, MisionesUI). Lo de la anterior se queda guardado. Falso si no se
# puede: con una de LUGAR en juego o con algo de la activa en brazos
func elegir(mision: MisionData) -> bool:
	if mision == activa:
		return true
	if not aceptada(mision) or en_lugar() or manos_ocupadas:
		return false
	_guardar_activa()
	_poner_activa(mision)
	return true


# Las de LUGAR: falso si no es su hora o ya se hizo hoy (el sitio lo dice). La activa del
# diario se aparta mientras tanto y regresa al acabar
func empezar_en_lugar(mision: MisionData) -> bool:
	if hecha_hoy(mision) or en_lugar():
		return false
	if not a_su_hora(mision.pasos[0] if not mision.pasos.is_empty() else null):
		return false
	_guardar_activa()
	_previa = activa
	_guardado[mision.id] = _nuevo_avance(mision, 0)
	_poner_activa(mision)
	return true


# {"paso", "visitados", "tiempo"} de cualquiera de las aceptadas (el diario)
func avance(mision: MisionData) -> Dictionary:
	if mision == activa:
		return {"paso": indice_paso, "visitados": visitados, "tiempo": tiempo_queda}
	return _guardado.get(mision.id, _nuevo_avance(mision, 0))


# Se esta jugando una de LUGAR: el diario espera
func en_lugar() -> bool:
	return activa != null and activa.inicio == MisionData.Inicio.LUGAR


func _nuevo_avance(mision: MisionData, i: int) -> Dictionary:
	var p: PasoMision = mision.pasos[i]
	return {"paso": i, "visitados": 0, "tiempo": p.segundos}


func _guardar_activa() -> void:
	if activa:
		_guardado[activa.id] = {"paso": indice_paso, "visitados": visitados, "tiempo": tiempo_queda}


func _poner_activa(mision: MisionData) -> void:
	activa = mision
	if mision == null:
		indice_paso = 0
		visitados = 0
		tiempo_queda = 0.0
		cambio.emit()
		return
	var avance: Dictionary = _guardado.get(mision.id, _nuevo_avance(mision, 0))
	_guardado.erase(mision.id)
	indice_paso = avance["paso"]
	visitados = avance["visitados"]
	meta_visitas = paso().cuantos
	tiempo_queda = avance["tiempo"]
	cambio.emit()


func _entrar_paso(i: int) -> void:
	indice_paso = i
	visitados = 0
	meta_visitas = paso().cuantos
	tiempo_queda = paso().segundos
	cambio.emit()


func _avanzar() -> void:
	if indice_paso + 1 < activa.pasos.size():
		_entrar_paso(indice_paso + 1)
	else:
		_completar()


func _process(delta: float) -> void:
	if activa == null or not en_hora():
		return
	if tiempo_queda > 0.0:
		tiempo_queda -= delta
		if tiempo_queda <= 0.0:
			fallar("Se te fue el tiempo. Mañana será.")
			return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = REVISAR_CADA
	if paso().tipo == PasoMision.Tipo.TENER_OBJETOS and tiene_objetos(paso()):
		_avanzar()


# Cuenta repetidos: pedir dos galones son dos en el inventario
func tiene_objetos(p: PasoMision) -> bool:
	var inventario := get_node("/root/Inventory")
	var hay: Array = inventario.unidades()
	for pedido in p.objetos:
		var i := hay.find(pedido)
		if i < 0:
			return false
		hay.remove_at(i)
	return true


func visitado() -> void:
	if activa == null or paso().tipo != PasoMision.Tipo.VISITAR or not en_hora():
		return
	visitados += 1
	if visitados >= meta_visitas:
		_avanzar()
	else:
		cambio.emit()


func recogido() -> void:
	if activa and paso().tipo == PasoMision.Tipo.RECOGER and en_hora():
		_avanzar()


# Con el que dio la mision. Falso si todavia no le traes lo que pidio
func entregar() -> bool:
	if activa == null or paso().tipo != PasoMision.Tipo.ENTREGAR or not en_hora() \
			or not tiene_objetos(paso()):
		return false
	var inventario := get_node("/root/Inventory")
	for pedido in paso().objetos:
		inventario.remove_item(inventario.items.find(pedido))
	_avanzar()
	return true


func _completar() -> void:
	var mision := activa
	_quitar(mision)
	var pago := mision.pesos
	if mision.pieza_de_mapa:
		var piezas := get_node("/root/PiezasMapa")
		var falta: int = piezas.siguiente_faltante()
		if falta >= 0:
			piezas.recoger(falta)
		else:
			pago += mision.pesos_si_sobra
	# Lo que te pagan depende de quien cree que eres (Personaje.gd); los objetos no
	pago = roundi(pago * get_node("/root/Personaje").factor_paga())
	get_node("/root/Cartera").pesos += pago
	var inventario := get_node("/root/Inventory")
	for premio in mision.premios:
		if not inventario.add_item(premio):
			sobra.emit(premio)
	_siguiente()
	termino.emit(mision, true, "%s: +$%d" % [mision.nombre, pago])


func fallar(texto: String) -> void:
	if activa == null:
		return
	var mision := activa
	_quitar(mision)
	_siguiente()
	termino.emit(mision, false, texto)


func _quitar(mision: MisionData) -> void:
	_hechas[mision.id] = true
	aceptadas.erase(mision)
	_guardado.erase(mision.id)
	activa = null


# Al acabar una: la que estaba antes de la de LUGAR, o la primera del diario que quede.
# Sin diario todavia (S1b), asi no se queda nada parado
func _siguiente() -> void:
	var sigue := _previa if _previa != null else (aceptadas[0] if not aceptadas.is_empty() else null)
	_previa = null
	_poner_activa(sigue)


# Al avisar que va a oscurecer: la gente ya no ofrece
func atardecer() -> void:
	ofreciendo = false
	cambio.emit()


# Ya no falla nada: lo que es de dia espera a mañana
func anochecer() -> void:
	ofreciendo = false
	es_noche = true
	cambio.emit()


func amanecer() -> void:
	ofreciendo = true
	es_noche = false
	_hechas.clear()
	cambio.emit()


# Partida nueva (Inicio, la safehouse): no al cambiar de escena
func reiniciar() -> void:
	activa = null
	aceptadas.clear()
	_guardado.clear()
	_previa = null
	manos_ocupadas = false
	indice_paso = 0
	ofreciendo = true
	es_noche = false
	tiempo_queda = 0.0
	hay_objetivo = false
	dadores.clear()
	_hechas.clear()
	cambio.emit()
