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
# LLEVAR_CARGA: lo que pago una entrega
signal entrega(pesos: int)

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
	"res://resources/misiones/escolta_noche.tres",
	"res://resources/misiones/reparto_noche.tres",
	"res://resources/misiones/antena_noche.tres",
	"res://resources/misiones/caceria_noche.tres",
	"res://resources/misiones/entrada_dia.tres",
	"res://resources/misiones/defender_tinaco.tres",
	"res://resources/misiones/camioneta_noche.tres",
	"res://resources/misiones/camioneta_gabriel.tres",
	"res://resources/misiones/guardia_reja.tres",
	"res://resources/misiones/antena_sofia.tres",
	"res://resources/misiones/al_medico.tres",
	"res://resources/misiones/decreto_47.tres",
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
# ESCOLTAR: la vida del que escoltas; -1 si todavia no sale (se queda al cambiar de escena)
var vida_acompanante := -1
# CAMIONETA con lugar "salida_colonia": afuera de que reja de la colonia sale la camioneta
# ("poniente", "oriente"); MisionesMundo la escoge al azar al aceptar y ahi te deja
var salida_camioneta := ""
# Lo que paga una mision distinta de su `pesos`, por id (Defender el tinaco: cada tinaco paga lo suyo,
# SitiosTinaco); se borra al cobrar
var pagos_especiales := {}
# CAMIONETA con lugar "salida_giver" (Gabriel, en el mapa grande): de donde sale la camioneta, que es donde
# lo encontraste; MisionesMundo lo pone al aceptar y la escena de noche lo lee (Vector3.INF: ninguno)
var arranque_camioneta := Vector3.INF
# La guardia de la reja (padre Chuy, una sola vez: el tutorial de la primera horda): en cual de las dos rejas de
# Santa Mugre toca ("poniente", "oriente"; la escoge MisionesMundo al aceptar). Con una guardia cumplida la
# colonia deja salir (`reja_abierta`: Colonia, las flechas de salida)
var reja_guardia := ""
var guardias_reja := 0
# La antena de Sofia ya esta puesta (mision `antena_sofia` cumplida): su radio llega mas lejos (A3, "La verdad")
var antena_instalada := false
# El Decreto 47 (Sofia): la cortina de la bodega de GelA ya se forzo (se queda abierta; BodegaGela) y ya le
# llevaste el expediente y la hoja de conteo (Buenrostro empieza a buscar al Guero)
var bodega_gela_abierta := false
var decreto_47 := false
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
# Las `una_vez` ya cumplidas: no se borran al amanecer
var _hechas_siempre := {}
var _espera := 0.0
# id -> {"paso", "visitados", "tiempo"} de las que no son la activa
var _guardado := {}
# La que estaba activa antes de empezar una de LUGAR: vuelve al acabar esta
var _previa: MisionData = null
# La hora del paso de ruta (ESCOLTAR, LLEVAR_CARGA) ya estaba en curso: si se acaba, falla
var _ruta_hora := false


func _ready() -> void:
	for ruta: String in ARCHIVOS:
		var mision := load(ruta) as MisionData
		if mision:
			todas.append(mision)


func paso() -> PasoMision:
	return activa.pasos[indice_paso] if activa else null


func hecha_hoy(mision: MisionData) -> bool:
	return _hechas.has(mision.id) or _hechas_siempre.has(mision.id)


# Santa Mugre deja salir una vez que cumpliste la guardia de la reja
func reja_abierta() -> bool:
	return guardias_reja > 0


func aceptada(mision: MisionData) -> bool:
	return aceptadas.has(mision)


# Las de una sola vez (MisionData.una_vez) que ya cumpliste
func hecha_siempre(mision: MisionData) -> bool:
	return _hechas_siempre.has(mision.id)


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
	if not aceptada(mision) or en_lugar() or manos_ocupadas or ruta_en_curso():
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


# El paso de la activa es de ruta (ESCOLTAR, LLEVAR_CARGA, DEFENDER, CAMIONETA) y ya esta en su hora: lleva a alguien o
# algo, y no se puede dejar a medias ni cambiar de mision
func ruta_en_curso() -> bool:
	var p := paso()
	return p != null and en_hora() and (p.tipo == PasoMision.Tipo.ESCOLTAR \
			or p.tipo == PasoMision.Tipo.LLEVAR_CARGA or p.tipo == PasoMision.Tipo.DEFENDER \
			or p.tipo == PasoMision.Tipo.CAMIONETA)


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
	vida_acompanante = -1
	salida_camioneta = ""
	_ruta_hora = ruta_en_curso()
	cambio.emit()


func _entrar_paso(i: int) -> void:
	indice_paso = i
	visitados = 0
	meta_visitas = paso().cuantos
	tiempo_queda = paso().segundos
	vida_acompanante = -1
	salida_camioneta = ""
	_ruta_hora = ruta_en_curso()
	cambio.emit()


func _avanzar() -> void:
	if indice_paso + 1 < activa.pasos.size():
		_entrar_paso(indice_paso + 1)
	else:
		_completar()


func _process(delta: float) -> void:
	if activa == null:
		return
	# Se acabo la hora con la ruta en camino: los cuicos (amanecer) o la oscuridad
	var en_ruta := ruta_en_curso()
	if _ruta_hora and not en_ruta:
		_ruta_hora = false
		fallar(_texto_ruta_perdida(paso()))
		return
	_ruta_hora = en_ruta
	if not en_hora():
		return
	# En DEFENDER el tiempo es lo que aguantas (defendiendo()), y al acabarse ganas
	if tiempo_queda > 0.0 and paso().tipo != PasoMision.Tipo.DEFENDER:
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
	if activa == null or not en_hora():
		return
	var tipo := paso().tipo
	if tipo != PasoMision.Tipo.VISITAR and tipo != PasoMision.Tipo.LLEVAR_CARGA \
			and tipo != PasoMision.Tipo.ENTRAR_A and tipo != PasoMision.Tipo.CAMIONETA:
		return
	var pago := roundi(paso().pesos_por_entrega * get_node("/root/Personaje").factor_paga())
	if (tipo == PasoMision.Tipo.LLEVAR_CARGA or tipo == PasoMision.Tipo.CAMIONETA) and pago > 0:
		get_node("/root/Cartera").pesos += pago
		entrega.emit(pago)
	visitados += 1
	if visitados >= meta_visitas:
		_avanzar()
	else:
		cambio.emit()


# RECOGER con varias piezas (`cuantos`, las de la antena): cada una paga `pesos_por_entrega`
func pieza_recogida() -> void:
	if activa == null or paso().tipo != PasoMision.Tipo.RECOGER or not en_hora():
		return
	var pago := roundi(paso().pesos_por_entrega * get_node("/root/Personaje").factor_paga())
	if pago > 0:
		get_node("/root/Cartera").pesos += pago
		entrega.emit(pago)
	visitados += 1
	if visitados >= meta_visitas:
		_avanzar()
	else:
		cambio.emit()


func recogido() -> void:
	if activa and paso().tipo == PasoMision.Tipo.RECOGER and en_hora():
		_avanzar()


# CAZAR: bajaron al zombi marcado
func cazado() -> void:
	if activa and paso().tipo == PasoMision.Tipo.CAZAR and en_hora():
		_avanzar()


# ESCOLTAR: los dos llegaron
func escoltado() -> void:
	if activa and paso().tipo == PasoMision.Tipo.ESCOLTAR and en_hora():
		_avanzar()


# DEFENDER: otro segundo aguantado (MisionesMundo, solo si estas en el lugar); al acabar, ganas
func defendiendo(delta: float) -> void:
	if activa == null or paso().tipo != PasoMision.Tipo.DEFENDER or not en_hora():
		return
	tiempo_queda -= delta
	if tiempo_queda <= 0.0:
		_avanzar()


# ESCOLTAR, DEFENDER o CAMIONETA: lo mataron los zombis
func acompanante_cayo() -> void:
	if not ruta_en_curso() or paso().tipo == PasoMision.Tipo.LLEVAR_CARGA:
		return
	if paso().tipo == PasoMision.Tipo.CAMIONETA:
		fallar("La camioneta no aguantó. Se perdió el agua.")
	else:
		fallar("Lo perdiste. No debiste dejarlo solo.")


# Te desmayaste: lo que llevabas o a quien llevabas se pierde
func desmayo() -> void:
	if ruta_en_curso():
		fallar(_texto_ruta_perdida(paso()))


func _texto_ruta_perdida(p: PasoMision) -> String:
	if p.tipo == PasoMision.Tipo.ESCOLTAR:
		return "Se te acabó la noche y lo dejaste a su suerte." if p.cuando == PasoMision.Cuando.NOCHE \
				else "Se hizo de noche y lo dejaste a su suerte."
	if p.tipo == PasoMision.Tipo.DEFENDER:
		return "No aguantaste hasta el final y el lugar se perdió."
	if p.tipo == PasoMision.Tipo.CAMIONETA:
		return "Amaneció con la camioneta en la calle: los cerdos se la llevaron." if not es_noche \
				else "Te desmayaste y la camioneta siguió sin ti."
	return "Te amaneció con la carga: los cerdos se la llevaron." if p.cuando == PasoMision.Cuando.NOCHE \
			else "Se hizo de noche con la carga encima y la perdiste."


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
	var pago: int = pagos_especiales.get(mision.id, mision.pesos)
	pagos_especiales.erase(mision.id)
	if mision.una_vez:
		_hechas_siempre[mision.id] = true
	if mision.id == "guardia_reja":
		guardias_reja += 1
	if mision.id == "antena_sofia":
		antena_instalada = true
	if mision.id == "decreto_47":
		decreto_47 = true
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
	if mision.id == "camioneta_gabriel":
		arranque_camioneta = Vector3.INF
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


# Escena nueva: no se sabe la hora hasta que el Ciclo la diga (anochecio sale en su primer cuadro);
# una ruta en curso no debe fallar por ese cuadro de duda
func cambio_de_escena() -> void:
	es_noche = false
	_ruta_hora = false


# Partida nueva (Inicio, la safehouse): no al cambiar de escena
func reiniciar() -> void:
	PasoJefe.reiniciar()
	activa = null
	aceptadas.clear()
	_guardado.clear()
	_previa = null
	manos_ocupadas = false
	vida_acompanante = -1
	salida_camioneta = ""
	pagos_especiales.clear()
	arranque_camioneta = Vector3.INF
	reja_guardia = ""
	guardias_reja = 0
	antena_instalada = false
	bodega_gela_abierta = false
	decreto_47 = false
	SitiosTinaco.elegido = -1
	_ruta_hora = false
	indice_paso = 0
	ofreciendo = true
	es_noche = false
	tiempo_queda = 0.0
	hay_objetivo = false
	dadores.clear()
	_hechas.clear()
	_hechas_siempre.clear()
	cambio.emit()
