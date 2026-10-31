extends Node

# Las misiones de dia (docs/especificaciones.md 6). Autoload `Misiones`: cual esta activa, en
# que paso va, cuales ya se hicieron hoy y la paga. Lo que esta en el mundo (los que las dan,
# los lugares, la flecha) es de scripts/map/MisionesMundo.gd. Una a la vez y cada una una vez
# al dia; si anochece o se acaba el tiempo, falla y se puede volver a intentar mañana.

signal cambio
signal termino(mision: MisionData, exito: bool, texto: String)
signal sobra(objeto: InventoryItemData)

const ARCHIVOS := [
	"res://resources/misiones/encargo.tres",
	"res://resources/misiones/garrafones.tres",
	"res://resources/misiones/perro.tres",
]
const REVISAR_CADA := 0.25

var todas: Array[MisionData] = []
var activa: MisionData = null
var indice_paso := 0
# Ya no se ofrecen: falta poco para oscurecer
var ofreciendo := true
var tiempo_queda := 0.0
var visitados := 0
var meta_visitas := 1
# Lo pone MisionesMundo: a donde apuntan los mapas
var hay_objetivo := false
var objetivo := Vector2.ZERO
var objetivo_radio := 0.0

var _hechas := {}
var _espera := 0.0


func _ready() -> void:
	for ruta: String in ARCHIVOS:
		var mision := load(ruta) as MisionData
		if mision:
			todas.append(mision)


func paso() -> PasoMision:
	return activa.pasos[indice_paso] if activa else null


func hecha_hoy(mision: MisionData) -> bool:
	return _hechas.has(mision.id)


func disponible(mision: MisionData) -> bool:
	return ofreciendo and activa == null and not hecha_hoy(mision)


func aceptar(mision: MisionData) -> void:
	if not disponible(mision):
		return
	activa = mision
	_entrar_paso(0)


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
	if activa == null:
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
	var hay: Array = inventario.items.duplicate()
	for pedido in p.objetos:
		var i := hay.find(pedido)
		if i < 0:
			return false
		hay.remove_at(i)
	return true


func visitado() -> void:
	if activa == null or paso().tipo != PasoMision.Tipo.VISITAR:
		return
	visitados += 1
	if visitados >= meta_visitas:
		_avanzar()
	else:
		cambio.emit()


func recogido() -> void:
	if activa and paso().tipo == PasoMision.Tipo.RECOGER:
		_avanzar()


# Con el que dio la mision. Falso si todavia no le traes lo que pidio
func entregar() -> bool:
	if activa == null or paso().tipo != PasoMision.Tipo.ENTREGAR or not tiene_objetos(paso()):
		return false
	var inventario := get_node("/root/Inventory")
	for pedido in paso().objetos:
		inventario.remove_item(inventario.items.find(pedido))
	_avanzar()
	return true


func _completar() -> void:
	var mision := activa
	_hechas[mision.id] = true
	activa = null
	var pago := mision.pesos
	if mision.pieza_de_mapa:
		var piezas := get_node("/root/PiezasMapa")
		var falta: int = piezas.siguiente_faltante()
		if falta >= 0:
			piezas.recoger(falta)
		else:
			pago += mision.pesos_si_sobra
	get_node("/root/Cartera").pesos += pago
	var inventario := get_node("/root/Inventory")
	for premio in mision.premios:
		if not inventario.add_item(premio):
			sobra.emit(premio)
	cambio.emit()
	termino.emit(mision, true, "%s: +$%d" % [mision.nombre, pago])


func fallar(texto: String) -> void:
	if activa == null:
		return
	var mision := activa
	_hechas[mision.id] = true
	activa = null
	cambio.emit()
	termino.emit(mision, false, texto)


# Al avisar que va a oscurecer: lo que traes aun lo puedes acabar, pero ya no hay mas
func atardecer() -> void:
	ofreciendo = false
	cambio.emit()


func anochecer() -> void:
	ofreciendo = false
	fallar("Ya oscureció y se fueron a sus casas. Mañana será.")


func amanecer() -> void:
	ofreciendo = true
	_hechas.clear()
	cambio.emit()


func reiniciar() -> void:
	activa = null
	indice_paso = 0
	ofreciendo = true
	tiempo_queda = 0.0
	hay_objetivo = false
	_hechas.clear()
	cambio.emit()
