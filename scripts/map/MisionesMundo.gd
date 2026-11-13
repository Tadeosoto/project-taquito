class_name MisionesMundo
extends Node3D

# Lo que se ve de las misiones (Misiones.gd): los vecinos que las dan, con su signo amarillo; a
# donde ir, con una flecha y en los mapas; lo que falta, en pantalla. Salen del mapa de datos,
# como los pedazos de mapa de Partida.gd. El safehouse le da sus propios lugares. El lugar
# que sobra despues de los vecinos es para el nino de los tazos (NinoTazos.gd).

const NPC := preload("res://scenes/npc.tscn")
const PERRO := preload("res://models/personajes/perro/perro.scn")
const ALTO_PERSONA := 1.7
const ALTO_PERRO := 0.55
const LADO_POSTE := 1.5       # m junto al poste, que siempre esta en la banqueta
const ENTRE_VECINOS := 15.0
const CERCA_INICIO := 7.0
const CASAS_DISTANCIA := Vector2(18.0, 120.0)
const CASAS_ENTRE := 22.0
const CASA_FRENTE := 1.6      # m frente a la fachada
const PUNTO_RADIO := 2.2
const PERRO_DISTANCIA := Vector2(110.0, 240.0)
const PERRO_BUSCAR := 30.0    # m de radio del area marcada en los mapas
const PERRO_LADRA := Vector2(2.0, 4.0)
const PERRO_OIDO := 65.0
const SIGNO_ALTO := 2.75
const TEXTO_ACEPTAR := "\nEspacio: aceptar"
const TEXTO_TARDE := "Ya va a oscurecer. Mejor mañana."
# Al aceptar una que no es de esta hora (Misiones.hora_que_falta): lo piensa el protagonista
const ACOMPANANTE_SALE_A := 30.0  # m: si el que dio la mision esta mas lejos, sale junto a ti
const ESCOLTA_LLEGA := 4.0        # m a la meta, de los dos
const CAMIONETA_CANDIDATAS := 14   # casas que se prueban para armar la ruta de la camioneta
const CAMIONETA_NOCHE_SIN_CICLO := 300.0 # s de ruta si el Ciclo no esta de noche
const CAMIONETA_CASAS := Vector2(40.0, 400.0)   # m del que da la mision a las casas de la ruta (toda la noche)
const CAMIONETA_PRIMERA_OLA := 1.5 # s despues de pararse la camioneta llega la primera turba
const CAMIONETA_LEJOS := 25.0      # m: mas lejos que esto, la linea de abajo dice a cuanto esta
# "salida_colonia": de donde arranca la camioneta, afuera de la reja de la avenida (apareces a
# MuroColonia.LLEGADA_FUERA, detras de ella)
const CAMIONETA_AFUERA := 13.0     # m de la reja hacia afuera
const CAMIONETA_AL_LADO := 3.5     # m a un lado, para no tapar la flecha de entrada
const CAMIONETA_PRIMERA_OLA_AFUERA := 4.0   # s para la primera turba al salir
const CAMIONETA_CORTE := 1.5       # s despues de aceptar, para leer al chofer, antes del corte
const DEFENDER_RADIO := 20.0      # m del lugar: mas lejos, el tiempo no corre
const DEFENDER_PRIMERA := 4.0     # s para la primera turba
const CAZA_BUSCAR := 25.0         # m de radio del area marcada en los mapas
## Donde para Gabriel en el mapa grande (afuera de las fortalezas), cada uno [el, de donde sale la camioneta]:
## 1 poniente (junto a un poste), 2 en la Av. Padre Xavier Scheifler, 3 en la calle Bahia de Acapulco y
## 4 en la Av. Agricola (JJ, 2026-11-12): el, en la banqueta, y la camioneta en el eje de la calle, el punto de
## la avenida mas cerca de donde estaba
const GABRIEL_SITIOS := [
	[Vector2(-542.0, 159.8), Vector2(-538.5, 159.8)],
	[Vector2(92.7, 279.3), Vector2(97.6, 280.3)],
	[Vector2(-104.6, -422.5), Vector2(-104.1, -417.5)],
	[Vector2(529.6, 55.2), Vector2(528.4, 60.0)],
]
## Las dos piezas de la antena de Sofia (tubos y un repetidor): afuera, a ~330 m de la reja poniente,
## junto a un poste de avenida, una al norte y otra al sur (M4)
const PIEZAS_ANTENA := [Vector2(-415.9, 125.7), Vector2(-102.3, 578.1)]
const PIEZAS_NOMBRES := ["los tubos", "el repetidor"]
# Los papeles del Decreto 47 (M6), al fondo de la bodega de GelA (BodegaGela.PAPELES): RECOGER como las piezas
const PAPELES_NOMBRES := ["el expediente del Decreto 47", "la hoja de conteo"]
const PIEZAS_ZOMBIS := 2          # zombis sueltos que salen junto a cada pieza al acercarte
const PIEZAS_AVISO := 60.0        # m de la pieza a los que salen
const TEXTO_REJA_ANTES := "Hay un herido, pero de noche se sale por la reja y sigue cerrada. Antes habla con el padre Chuy."
const TINACO_CORTE := 1.4         # s entre aceptar con Chava y el corte a la defensa
const CAZA_APARECE := 70.0        # m del lugar a los que sale el zombi marcado
const TEXTO_HORA := "%s: \"Esto me toca %s.\""
# Las entregas de la mafia (M7): se entrega a un lado de la puerta del punto, lejos de su flecha amarilla (pisarla
# te mete a la tienda), y el puntero espera junto; sin la entrega de antes no te conoce
const ENTREGA_AL_LADO := 3.5
const PUNTERO_AL_LADO := 4.6
const TEXTO_NO_TE_CONOZCO := "¿Y tú quién eres? Aquí no se vende nada, compa."
const TEXTO_FALTA_CAJA := "Sin la caja no hay entrega. Ve por ella."
const TEXTO_PUNTO_REJA := "Tengo trabajo, pero es allá afuera y la reja sigue cerrada. Cuando te dejen salir, regresas."
const PUNTOS_MAPA := "res://resources/map/puntos_mapa.json"

@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"
@export_file("*.json") var casas_path := "res://resources/map/casas_mapa.json"
@export_file("*.json") var postes_path := "res://resources/map/alumbrado_mapa.json"
# El safehouse: donde van, en vez de buscar postes
@export var vecinos_fijos: Array[Vector3] = []
@export var perro_fijo := Vector3.INF
# El safehouse: donde estan los negocios "punto" de la mafia, por su `origen` (en el mapa salen del JSON)
@export var puntos_fijos := {}

var vecinos: Array[Dictionary] = []
var _piezas: Array[Node3D] = []
var _piezas_zombis: Array[bool] = []
var _piezas_de: MisionData
var nino: NinoTazos
var _nino_lugar := Vector3.ZERO

var _casas: Array = []
var _tiendas: Array = []
var _postes: Array = []
var _jugador: Node3D
var _ciclo: Node
var _supervivencia: Node
var _flecha: Node3D
var _puntos: Array[Area3D] = []
var _perro: Node3D
var _perro_lugar := Vector3.ZERO
var _ladra_en := 0.0
var _voz_perro: AudioStreamPlayer3D
var _texto: Label
var _voz: AudioStreamPlayer
# Lo que trae en las manos: el `carga` del paso (solo a su hora) o la cosa levantada (el perro)
var _carga_item: InventoryItemData = null
var _cosa_en_manos := false
# De que mision son la cosa (en el suelo o en las manos) y los puntos de visita
var _perro_de: MisionData = null
var _puntos_de: MisionData = null
# ESCOLTAR: el que te sigue, de que paso, y a donde lo llevas (se guarda para no cambiarla en cada _cambio)
var _acomp: Acompanante = null
var _acomp_de: PasoMision = null
var _camioneta: CamionetaReparto = null
var _camioneta_de: PasoMision = null
var _camioneta_parada := false
var _ola_andando_en := 0.0         # s para la siguiente turba con la camioneta andando
var _escolta_de: PasoMision = null
var _escolta_meta := Vector3.ZERO
# DEFENDER: de que paso es la cuenta de turbas y en cuanto sale la siguiente
var _defensa_de: PasoMision = null
var _ola_en := 0.0
# CAZAR: el zombi marcado, de que paso, y su "!"
var _cazado: Zombie = null
var _cazado_de: PasoMision = null
var _marca_cazado: Label3D = null
# La caja de la mafia en el piso (PasoMision.soltable): de que paso es; levantarla la vuelve a la mano
var _caja_suelo: Node3D = null
var _caja_de: PasoMision = null
# Donde estan los "punto" del mapa grande, por `origen` (para dibujar los que ya conoces aunque estes en la colonia)
static var _puntos_del_mapa := {}


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador")
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	_armar_pantalla()
	_cargar_datos()
	_flecha = MapPuntos.flecha()
	_flecha.visible = false
	add_child(_flecha)
	# No se reinicia: la mision sigue de una escena a otra (Inicio y la safehouse la reinician).
	# La hora la pone el Ciclo: si esta escena empieza de noche, emite anochecio en su primer cuadro
	Misiones.cambio_de_escena()
	# Lo que traias en brazos se quedo en la otra escena
	Misiones.manos_ocupadas = false
	Misiones.cambio.connect(_cambio)
	Misiones.termino.connect(_termino)
	Misiones.sobra.connect(_sobra)
	Misiones.entrega.connect(_entrega)
	if _jugador.has_signal("pidio_soltar_carga"):
		_jugador.pidio_soltar_carga.connect(_soltar_caja_al_piso)
	if _ciclo:
		_ciclo.aviso_atardecer.connect(Misiones.atardecer)
		_ciclo.anochecio.connect(_anochecio)
		_ciclo.amanecio.connect(_amanecio)
	_poner_vecinos()
	_cambio()
	_resolver_jefe(PasoJefe.tomar_resultado())


# Se vuelve de una escena de jefe: ganar cumple el paso ENTRAR_A (cuando el Ciclo ya dijo la hora);
# perder lo deja para otro intento
func _resolver_jefe(resultado: PasoJefe.Resultado) -> void:
	if resultado == PasoJefe.Resultado.NADA:
		return
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	var paso := Misiones.paso()
	if resultado == PasoJefe.Resultado.GANO:
		if paso and paso.tipo == PasoMision.Tipo.ENTRAR_A and paso.escena != "":
			_sonar("moneda")
			Misiones.visitado()
	elif _supervivencia:
		_supervivencia.avisar("Te sacaron de ahí. Ya habrá otra.")


func _exit_tree() -> void:
	Misiones.dadores.clear()
	if Misiones.cambio.is_connected(_cambio):
		Misiones.cambio.disconnect(_cambio)
		Misiones.termino.disconnect(_termino)
		Misiones.sobra.disconnect(_sobra)
		Misiones.entrega.disconnect(_entrega)


# Al cargar y no al aceptar una mision: leer las casas (1 MB) trabaria el juego a medio dia
func _cargar_datos() -> void:
	_casas = _lista(casas_path, "casas")
	_tiendas = _lista(puntos_path, "puntos")
	_postes = _lista(postes_path, "postes")


func _lista(ruta: String, llave: String) -> Array:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return datos[llave] if datos is Dictionary else []


func avisos_por(supervivencia: Node) -> void:
	_supervivencia = supervivencia


# --- Los que las dan ---

func _poner_vecinos() -> void:
	_poner_punteros()
	var normales := _misiones_normales()
	var lugares := vecinos_fijos if not vecinos_fijos.is_empty() else _lugares_vecinos()
	var cuantos := mini(lugares.size(), normales.size())
	for i in cuantos:
		var mision := normales[i]
		# Defender el tinaco, en el mapa grande: Chava esta parado afuera de cada uno de los cinco tinacos
		if mision.donde == "tinacos" and get_tree().get_first_node_in_group("fortalezas") != null:
			for k in SitiosTinaco.SITIOS.size():
				var centro := SitiosTinaco.centro(k)
				var lugar := Vector3(centro.x + SitiosTinaco.CHAVA_A, _jugador.global_position.y - 1.0, centro.z)
				var dador := _nuevo_dador(mision, lugar, centro - lugar)
				dador["sitio"] = k
				vecinos.append(dador)
			continue
		# La camioneta de Gabriel, en el mapa grande: parado en cada uno de sus puntos de afuera
		if mision.donde == "gabrieles" and get_tree().get_first_node_in_group("fortalezas") != null:
			for sitio: Array in GABRIEL_SITIOS:
				var piso := _jugador.global_position.y - 1.0
				var lugar := Vector3(sitio[0].x, piso, sitio[0].y)
				var calle := Vector3(sitio[1].x, piso, sitio[1].y)
				var dador := _nuevo_dador(mision, lugar, calle - lugar)   # mirando a la calle
				dador["gabriel"] = calle
				vecinos.append(dador)
			continue
		# Una sola persona por marca: Sofia da la antena y, ya puesta, el Decreto 47
		if mision.donde.begins_with("marca:") and not _dador_de_su_marca(mision):
			continue
		var marca: Variant = _marca(mision.donde)
		if marca != null:
			# Parado en su marca de la colonia, viendo a donde ve la marca
			lugares[i] = (marca as Transform3D).origin
		var hacia := _jugador.global_position - lugares[i]
		vecinos.append(_nuevo_dador(mision, lugares[i], hacia, marca if marca != null else null))
	if lugares.size() > cuantos:
		_nino_lugar = lugares[cuantos]
		nino = NinoTazos.new()
		add_child(nino)
		nino.global_position = _nino_lugar
		var hacia := _jugador.global_position - _nino_lugar
		nino.rotation.y = atan2(hacia.x, hacia.z)
	_actualizar_signos()


# Las que da un vecino (todas menos las de los puntos de la mafia, que tienen su lugar fijo)
func _misiones_normales() -> Array[MisionData]:
	var normales: Array[MisionData] = []
	for mision in Misiones.todas:
		if not mision.donde.begins_with("punto:"):
			normales.append(mision)
	return normales


# Los punteros de la mafia (M7): cada uno a un lado de la puerta de su negocio "punto", mirando a la calle. Solo
# los de esta escena: El Punto en la colonia, los otros ocho en el mapa grande
func _poner_punteros() -> void:
	for mision in Misiones.todas:
		if not mision.donde.begins_with("punto:"):
			continue
		var punto := _punto_mafia(mision.donde.trim_prefix("punto:"))
		if punto.is_empty():
			continue
		var frente: Vector3 = punto[0]
		var hacia: Vector3 = punto[1]
		vecinos.append(_nuevo_dador(mision, frente + _lado(hacia) * PUNTERO_AL_LADO, hacia))


# Hacia que lado de la puerta del punto van la entrega y el puntero
static func _lado(hacia: Vector3) -> Vector3:
	return hacia.cross(Vector3.UP)


# [frente de la puerta, hacia afuera] del negocio "punto" con ese `origen`, o [] si no esta en esta escena
func _punto_mafia(origen: String) -> Array:
	if puntos_fijos.has(origen):
		var fijo: Vector3 = puntos_fijos[origen]
		return [fijo, Vector3(0.0, 0.0, 1.0)]
	for p: Dictionary in _tiendas:
		if p.get("tipo", "") == "punto" and p.get("origen", "") == origen:
			var r := float(p["rotacion_y"])
			var frente := Vector2(sin(r), cos(r))
			var en := Vector2(p["x"], p["z"]) + frente * (float(p.get("fondo", 8.0)) / 2.0 + 1.5)
			return [Vector3(en.x, _jugador.global_position.y - 1.0, en.y), Vector3(frente.x, 0.0, frente.y)]
	return []


# Los "punto" del mapa grande ya conocidos (a donde ya llevaste una caja), para el mapa de papel y el minimapa
func _puntos_conocidos() -> Array:
	var conocidos := []
	if not puntos_fijos.is_empty():
		return conocidos   # el safehouse no esta en el mapa de papel
	if _puntos_del_mapa.is_empty():
		for p: Dictionary in _lista(PUNTOS_MAPA, "puntos"):
			if p.get("tipo", "") == "punto":
				_puntos_del_mapa[p.get("origen", "")] = Vector2(p["x"], p["z"])
	for mision in Misiones.todas:
		if mision.id.begins_with(Misiones.MAFIA) and Misiones.hecha_siempre(mision) and not mision.pasos.is_empty():
			var origen := mision.pasos[0].lugar.trim_prefix("punto:")
			if _puntos_del_mapa.has(origen):
				conocidos.append([_puntos_del_mapa[origen], mision.nombre.trim_prefix("Entrega a ")])
	return conocidos


# De las misiones que se dan en la misma marca, la que toca: la primera que no se ha cumplido para siempre
# (MisionData.una_vez), o la ultima si ya se cumplieron todas
func _dador_de_su_marca(mision: MisionData) -> bool:
	var toca: MisionData = null
	for otra: MisionData in Misiones.todas:
		if otra.donde != mision.donde:
			continue
		toca = otra
		if not Misiones.hecha_siempre(otra):
			break
	return toca == mision


# Un dador parado en `lugar` mirando hacia `hacia` (o con el giro de su `marca`), con su signo de
# admiracion. Lo que se guarda en `vecinos`; `_hablar` lo busca por su lugar en esa lista
func _nuevo_dador(mision: MisionData, lugar: Vector3, hacia: Vector3, marca: Variant = null) -> Dictionary:
	var npc := NPC.instantiate() as Node3D
	var ninja := npc.get_node("Model")
	npc.remove_child(ninja)
	ninja.free()
	add_child(npc)
	npc.global_position = lugar
	npc.rotation.y = atan2(hacia.x, hacia.z) if marca == null else (marca as Transform3D).basis.get_euler().y
	Gente.poner_modelo(npc, load("res://models/personajes/%s/%s.scn" % [mision.modelo, mision.modelo]), ALTO_PERSONA)
	var signo := Label3D.new()
	signo.text = "!"
	signo.font_size = 96
	signo.pixel_size = 0.012
	signo.modulate = MapPuntos.MARCADOR_COLOR
	signo.outline_size = 24
	signo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	signo.position.y = SIGNO_ALTO
	npc.add_child(signo)
	npc.set("al_hablar", _hablar.bind(vecinos.size()))
	return {"mision": mision, "nodo": npc, "signo": signo, "lugar": lugar, "visto": false}


# Junto a los postes mas cercanos a donde empiezas, sin caer en el refugio
func _lugares_vecinos() -> Array[Vector3]:
	var inicio := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	var cerca := []
	for p: Dictionary in _postes:
		var d := inicio.distance_to(Vector2(p["x"], p["z"]))
		if d >= CERCA_INICIO:
			cerca.append([d, Vector2(p["x"], p["z"])])
	cerca.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var refugio := get_tree().get_first_node_in_group("refugio") as Refugio
	var lugares: Array[Vector3] = []
	var piso := _jugador.global_position.y - 1.0
	for c: Array in cerca:
		var punto: Vector2 = c[1] + Vector2(LADO_POSTE, 0.0)
		var en_mundo := Vector3(punto.x, piso, punto.y)
		if refugio and refugio.adentro(en_mundo, 2.0):
			continue
		var lejos := true
		for otro in lugares:
			if otro.distance_to(en_mundo) < ENTRE_VECINOS:
				lejos = false
		if lejos:
			lugares.append(en_mundo)
		# Uno mas para el nino de los tazos
		if lugares.size() >= _misiones_normales().size() + 1:
			break
	return lugares


func _hablar(i: int) -> String:
	var v: Dictionary = vecinos[i]
	var mision: MisionData = v["mision"]
	if Misiones.activa == mision:
		if Misiones.paso().tipo == PasoMision.Tipo.ENTREGAR and Misiones.entregar():
			return ("%s %s" % [mision.gracias, Personaje.linea("paga")]).strip_edges()
		return mision.recuerda
	if Misiones.aceptada(mision):
		return mision.recuerda
	if Misiones.hecha_hoy(mision) or Misiones.ya_tienes_el_premio(mision):
		return mision.despedida
	if not Misiones.ofreciendo and not mision.abierto_de_noche:
		return TEXTO_TARDE
	# La cadena de la mafia: sin la entrega de antes, este puntero no te conoce
	if not Misiones.requisito_cumplido(mision):
		return TEXTO_NO_TE_CONOZCO
	# El Punto de Santa Mugre manda la caja afuera: hasta que se abra la reja (la guardia del padre Chuy) no la da
	if _entrega_afuera_de_la_colonia(mision) and not Misiones.reja_abierta():
		return TEXTO_PUNTO_REJA
	# Al medico se sale por la reja: hasta que se abra (la guardia del padre Chuy) no se ofrece
	if not mision.pasos.is_empty() and mision.pasos[0].lugar == "clinica" and not Misiones.reja_abierta():
		return TEXTO_REJA_ANTES
	if not v["visto"]:
		v["visto"] = true
		var saludo: String = "" if mision.abierto_de_noche else Personaje.linea("vecino")
		return ("%s %s" % [saludo, mision.oferta]).strip_edges() + TEXTO_ACEPTAR
	v["visto"] = false
	Misiones.aceptar(mision)
	if v.has("sitio"):
		_entrar_al_tinaco(mision, v["sitio"])
		return mision.aceptada
	if v.has("gabriel"):
		_salir_con_gabriel(mision, v["lugar"], v["gabriel"])
		return mision.aceptada
	if _empieza_en_la_reja(mision):
		_ir_a_la_reja(mision)
		return mision.aceptada
	if _sale_por_la_reja(mision):
		_salir_por_la_reja(mision)
		return mision.aceptada
	var falta := Misiones.hora_que_falta(mision.pasos[0] if not mision.pasos.is_empty() else null)
	if falta != "" and _supervivencia:
		_supervivencia.avisar(TEXTO_HORA % [Personaje.nombre, falta])
	return mision.aceptada


# Una entrega de la mafia que se acepta en la colonia y se entrega en el mapa grande
func _entrega_afuera_de_la_colonia(mision: MisionData) -> bool:
	return not mision.pasos.is_empty() and mision.pasos[0].lugar.begins_with("punto:") \
			and get_tree().get_first_node_in_group("colonia") != null \
			and _punto_mafia(mision.pasos[0].lugar.trim_prefix("punto:")).is_empty()


# Defender el tinaco, aceptada con Chava en el tinaco `k`: ese es el que toca y paga lo suyo; se corta y
# la defensa de ese tinaco empieza de noche (ENTRAR_A con `escena`), como si el dia pasara de golpe
func _entrar_al_tinaco(mision: MisionData, k: int) -> void:
	SitiosTinaco.elegido = k
	Misiones.pagos_especiales[mision.id] = SitiosTinaco.sitio(k)["pesos"]
	if not Misiones.elegir(mision):
		return
	await get_tree().create_timer(TINACO_CORTE).timeout
	var paso := Misiones.paso()
	if not is_inside_tree() or Misiones.activa != mision or paso == null or paso.escena == "":
		return
	PasoJefe.entrar(self, paso.escena, true)


# Las que arrancan de noche adentro de una reja, aceptadas en la colonia de Blender: la guardia de la reja (padre Chuy,
# primer paso DEFENDER en "reja_guardia") y Al medico (Karla, ESCOLTAR a la "clinica": el herido sale contigo)
func _empieza_en_la_reja(mision: MisionData) -> bool:
	return not mision.pasos.is_empty() and mision.pasos[0].lugar in ["reja_guardia", "clinica"] \
			and get_tree().get_first_node_in_group("colonia") != null


# Una de las dos rejas al azar: se corta la pantalla y se recarga la colonia de noche con el jugador adentro de
# esa reja (PasoColonia, igual que al volver de afuera) y el paso DEFENDER la toma de lugar (`_meta_de_escolta`)
func _ir_a_la_reja(mision: MisionData) -> void:
	if not Misiones.elegir(mision):
		return
	Misiones.reja_guardia = ["poniente", "oriente"].pick_random()
	await get_tree().create_timer(CAMIONETA_CORTE).timeout
	if not is_inside_tree() or Misiones.activa != mision:
		return
	var hora := -2.0
	if _ciclo:
		hora = _ciclo.dia_duracion / (_ciclo.dia_duracion + _ciclo.noche_duracion)
	PasoColonia.ir_a(self, PasoColonia.MAPA_COLONIA, Misiones.reja_guardia, hora)


# La camioneta de Gabriel, aceptada donde para: se corta la pantalla y se recarga el mapa de noche, con
# el jugador en ese mismo lugar y la camioneta arrancando de ahi (`Misiones.arranque_camioneta`)
func _salir_con_gabriel(mision: MisionData, lugar: Vector3, calle: Vector3) -> void:
	if not Misiones.elegir(mision):
		return
	Misiones.arranque_camioneta = calle
	await get_tree().create_timer(CAMIONETA_CORTE).timeout
	if not is_inside_tree() or Misiones.activa != mision:
		return
	var hora := -2.0
	if _ciclo:
		hora = _ciclo.dia_duracion / (_ciclo.dia_duracion + _ciclo.noche_duracion)
	# El jugador, del otro lado de Gabriel (lejos de la calle)
	var fuera := (lugar - calle).normalized()
	PasoJefe.regreso = Vector3(lugar.x + fuera.x * CAMIONETA_AL_LADO, 1.5, lugar.z + fuera.z * CAMIONETA_AL_LADO)
	PasoColonia.ir_a(self, PasoColonia.MAPA_GRANDE, "", hora)


# La del chofer: su primer paso es CAMIONETA desde la reja, y se acepta en la colonia
func _sale_por_la_reja(mision: MisionData) -> bool:
	return not mision.pasos.is_empty() and mision.pasos[0].tipo == PasoMision.Tipo.CAMIONETA \
			and mision.pasos[0].lugar == "salida_colonia" and get_tree().get_first_node_in_group("colonia") != null


func _actualizar_signos() -> void:
	Misiones.puntos_vistos = _puntos_conocidos()
	Misiones.dadores.clear()
	for v: Dictionary in vecinos:
		var mision: MisionData = v["mision"]
		var con_trabajo: bool = Misiones.disponible(mision)
		var esperando: bool = Misiones.activa == mision and Misiones.paso().tipo == PasoMision.Tipo.ENTREGAR
		(v["signo"] as Label3D).visible = con_trabajo or esperando
		# Su inicial en los mapas mientras ofrece (de noche no esta)
		if con_trabajo and mision.inicial != "" and (v["nodo"] as Node3D).is_inside_tree():
			var lugar: Vector3 = v["lugar"]
			Misiones.dadores.append([Vector2(lugar.x, lugar.z), mision.inicial])


# De noche no estan: se quitan del arbol y regresan al amanecer
func _anochecio() -> void:
	Misiones.anochecer()
	for v: Dictionary in vecinos:
		var npc: Node3D = v["nodo"]
		# Los puntos de la mafia no cierran
		if (v["mision"] as MisionData).abierto_de_noche:
			continue
		if npc.is_inside_tree():
			npc.set("_player_inside", false)
			remove_child(npc)
	if nino and nino.is_inside_tree():
		nino.soltar()
		remove_child(nino)
	_actualizar_signos()


func _amanecio() -> void:
	Misiones.amanecer()
	for v: Dictionary in vecinos:
		var npc: Node3D = v["nodo"]
		if not npc.is_inside_tree():
			add_child(npc)
			npc.global_position = v["lugar"]
		v["visto"] = false
	if nino and not nino.is_inside_tree():
		add_child(nino)
		nino.global_position = _nino_lugar
	_actualizar_signos()


# --- A donde ir ---

func _cambio() -> void:
	if not is_inside_tree():
		return
	_actualizar_signos()
	_quitar_puntos()
	var paso := Misiones.paso()
	_ajustar_acompanante(paso)
	_ajustar_camioneta(paso)
	_ajustar_cazado(paso)
	# Se acabo la mision de la cosa (y ya entro la siguiente): se suelta
	if _cosa_en_manos and _perro_de != Misiones.activa:
		_soltar_carga()
	if _perro and (_perro_de != Misiones.activa or paso == null or paso.tipo != PasoMision.Tipo.RECOGER):
		_quitar_cosa()
	if not _piezas.is_empty() and (_piezas_de != Misiones.activa or paso == null or not _de_piezas(paso.lugar)):
		_quitar_piezas()
	if paso == null:
		_soltar_carga()
		_quitar_caja_suelo()
		Misiones.hay_objetivo = false
		_flecha.visible = false
		return
	_ajustar_carga(paso)
	match paso.tipo:
		PasoMision.Tipo.TENER_OBJETOS:
			_apuntar(_tienda(paso.lugar))
		PasoMision.Tipo.ENTREGAR:
			_apuntar(_lugar_de_vecino(Misiones.activa))
		PasoMision.Tipo.ESCOLTAR:
			_apuntar(_meta_de_escolta(paso))
		PasoMision.Tipo.CAZAR:
			# El area, no el punto: hay que buscarlo
			var meta := _meta_de_escolta(paso)
			var corrido := Vector2.from_angle(randf() * TAU) * randf() * CAZA_BUSCAR * 0.6
			_apuntar(meta + Vector3(corrido.x, 0.0, corrido.y), CAZA_BUSCAR)
		PasoMision.Tipo.ENTRAR_A:
			if paso.lugar.begins_with("entrada:"):
				# La entrada ya existe en el mapa: solo se apunta a ella
				_apuntar(_meta_de_escolta(paso))
			elif _puntos.is_empty():
				_puntos_de = Misiones.activa
				Misiones.meta_visitas = 1
				_puntos.append(_punto_de_visita(_meta_de_escolta(paso)))
				_apuntar_al_punto_cercano()
		PasoMision.Tipo.CAMIONETA:
			if is_instance_valid(_camioneta):
				_apuntar(_camioneta.global_position)
		PasoMision.Tipo.DEFENDER:
			_apuntar(_meta_de_escolta(paso))
			if _defensa_de != paso:
				_defensa_de = paso
				_ola_en = DEFENDER_PRIMERA
		PasoMision.Tipo.VISITAR, PasoMision.Tipo.LLEVAR_CARGA:
			# Tambien llega aqui en cada entrega: los que quedan se quedan
			if _puntos.is_empty():
				_poner_puntos(paso)
		PasoMision.Tipo.RECOGER:
			if _de_piezas(paso.lugar):
				_poner_piezas(paso)
			elif paso.lugar.begins_with("marca:") and _marca(paso.lugar) != null:
				_poner_cosa(paso)
			else:
				_poner_perro()


func _apuntar(donde: Vector3, radio := 0.0) -> void:
	Misiones.hay_objetivo = true
	Misiones.objetivo = Vector2(donde.x, donde.z)
	Misiones.objetivo_radio = radio
	_flecha.visible = radio == 0.0
	_flecha.global_position = donde


func _lugar_de_vecino(mision: MisionData) -> Vector3:
	for v: Dictionary in vecinos:
		if v["mision"] == mision:
			return v["lugar"]
	return _jugador.global_position


# "giro:farmacia": la mas cercana al que la pidio
func _tienda(lugar: String) -> Vector3:
	var giro := lugar.trim_prefix("giro:")
	var desde := _lugar_de_vecino(Misiones.activa)
	var mejor := desde
	var cerca := INF
	for p: Dictionary in _tiendas:
		if p.get("interactivo", false) and p.get("giro", "") == giro:
			var frente := Vector2(sin(float(p["rotacion_y"])), cos(float(p["rotacion_y"])))
			var en := Vector2(p["x"], p["z"]) + frente * (float(p.get("fondo", 8.0)) / 2.0 + 1.5)
			var d := Vector2(desde.x, desde.z).distance_to(en)
			if d < cerca:
				cerca = d
				mejor = Vector3(en.x, desde.y, en.y)
	# Los negocios que solo son una flecha de la colonia del mapa en Blender (la tortilleria)
	if cerca == INF:
		for puerta: Dictionary in Colonia.puertas:
			if puerta["giro"] == giro:
				var en: Vector3 = puerta["frente"]
				var d := Vector2(desde.x, desde.z).distance_to(Vector2(en.x, en.z))
				if d < cerca:
					cerca = d
					mejor = Vector3(en.x, desde.y, en.z)
	return mejor


# Casas a repartir: frente a la fachada, cerca del que la dio y lejos entre ellas
func _poner_puntos(paso: PasoMision) -> void:
	if paso.lugar.begins_with("punto:"):
		_poner_punto_mafia(paso)
		return
	var desde := _lugar_de_vecino(Misiones.activa)
	# Al volver de otra escena, solo las que faltan
	var lugares := _lugares_de_casas(desde, paso.cuantos - Misiones.visitados)
	# Si no hay tantas casas (el safehouse), con las que haya
	Misiones.meta_visitas = Misiones.visitados + lugares.size()
	_puntos_de = Misiones.activa
	for lugar in lugares:
		_puntos.append(_punto_de_visita(lugar))
	_apuntar_al_punto_cercano()


# La entrega de la mafia: la puerta de ese negocio "punto". Si no esta en esta escena (sales de la colonia
# hacia el mapa grande), la flecha va a la salida poniente de la colonia
func _poner_punto_mafia(paso: PasoMision) -> void:
	Misiones.meta_visitas = 1
	var punto := _punto_mafia(paso.lugar.trim_prefix("punto:"))
	if punto.is_empty():
		if Colonia.salidas.has("poniente"):
			_apuntar(Colonia.salidas["poniente"])
		return
	_puntos_de = Misiones.activa
	var frente: Vector3 = punto[0]
	_puntos.append(_punto_de_visita(frente + _lado(punto[1]) * ENTREGA_AL_LADO))
	_apuntar_al_punto_cercano()


# `faltan` frentes de casa a `distancia` (min, max) de `desde`, lejos entre si
func _lugares_de_casas(desde: Vector3, faltan: int, distancia := CASAS_DISTANCIA) -> Array[Vector3]:
	var opciones := []
	for c: Dictionary in _casas:
		var d := Vector2(desde.x, desde.z).distance_to(Vector2(c["x"], c["z"]))
		if d >= distancia.x and d <= distancia.y:
			opciones.append(c)
	opciones.shuffle()
	var lugares: Array[Vector3] = []
	for c: Dictionary in opciones:
		var ry := float(c["rotacion_y"])
		var punto := Vector3(c["x"] + sin(ry) * CASA_FRENTE, desde.y, c["z"] + cos(ry) * CASA_FRENTE)
		var lejos := true
		for otro in lugares:
			if otro.distance_to(punto) < CASAS_ENTRE:
				lejos = false
		if lejos:
			lugares.append(punto)
		if lugares.size() >= faltan:
			break
	return lugares


func _punto_de_visita(lugar: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = PUNTO_RADIO
	forma.shape = esfera
	forma.position.y = 1.0
	area.add_child(forma)
	var flecha := MapPuntos.flecha()
	area.add_child(flecha)
	add_child(area)
	area.global_position = lugar
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_llegar_a(area))
	return area


# Fuera de su hora el punto se queda: cuenta cuando sea de noche (o de dia)
func _llegar_a(area: Area3D) -> void:
	if not Misiones.en_hora() or not _puntos.has(area):
		return
	var paso_actual := Misiones.paso()
	# La caja de la mafia se entrega en brazos: si la dejaste tirada, no cuenta
	if paso_actual and paso_actual.soltable and is_instance_valid(_caja_suelo):
		if _supervivencia:
			_supervivencia.avisar(TEXTO_FALTA_CAJA)
		return
	_puntos.erase(area)
	area.queue_free()
	# ENTRAR_A con `escena`: se entra al jefe y el paso se cumple al ganar (PasoJefe)
	if paso_actual and paso_actual.tipo == PasoMision.Tipo.ENTRAR_A and paso_actual.escena != "":
		PasoJefe.entrar(self, paso_actual.escena, true)
		return
	_sonar("moneda")
	Misiones.visitado()


func _apuntar_al_punto_cercano() -> void:
	var mas_cerca := INF
	for area in _puntos:
		var d := area.global_position.distance_to(_jugador.global_position)
		if d < mas_cerca:
			mas_cerca = d
			_apuntar(area.global_position)
	_flecha.visible = false


func _quitar_puntos() -> void:
	# Los que siguen pendientes del mismo paso se quedan
	var paso := Misiones.paso()
	if paso and (paso.tipo == PasoMision.Tipo.VISITAR or paso.tipo == PasoMision.Tipo.LLEVAR_CARGA \
			or paso.tipo == PasoMision.Tipo.ENTRAR_A) and not _puntos.is_empty() and _puntos_de == Misiones.activa:
		return
	for area in _puntos:
		area.queue_free()
	_puntos.clear()


# --- El zombi que cazas ---

# Se quita si el paso ya no es de CAZAR o no es su hora; el nuevo sale al acercarte (_revisar_caza)
func _ajustar_cazado(paso: PasoMision) -> void:
	var quiere := paso != null and paso.tipo == PasoMision.Tipo.CAZAR and Misiones.en_hora()
	if not quiere or _cazado_de != paso:
		_quitar_cazado()
	if quiere:
		_cazado_de = paso


func _quitar_cazado() -> void:
	if is_instance_valid(_marca_cazado):
		_marca_cazado.queue_free()
	_marca_cazado = null
	_cazado = null
	_cazado_de = null


# Sale cuando estas a CAZA_APARECE m del lugar (los lejanos se guardan solos: si se le pierde,
# vuelve a salir); al morir a golpes se cumple el paso
func _revisar_caza(paso: PasoMision) -> void:
	if _cazado_de != paso:
		_cazado_de = paso
	if _cazado != null:
		if not is_instance_valid(_cazado) or (not _cazado.despierto and _cazado.estado != Zombie.Estado.MUERTO):
			_quitar_cazado()
			_cazado_de = paso
		elif _cazado.estado == Zombie.Estado.MUERTO:
			var por_amanecer := _cazado.cayo_al_amanecer
			_quitar_cazado()
			if not por_amanecer:
				_sonar("moneda")
				Misiones.cazado()
			return
		else:
			return
	var meta := _meta_de_escolta(paso)
	if Vector2(_jugador.global_position.x, _jugador.global_position.z).distance_to(Vector2(meta.x, meta.z)) > CAZA_APARECE:
		return
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando == null:
		return
	_cazado = mando.sacar(meta, false)
	_marca_cazado = Label3D.new()
	_marca_cazado.text = "!"
	_marca_cazado.font_size = 96
	_marca_cazado.pixel_size = 0.012
	_marca_cazado.modulate = Color(0.9, 0.1, 0.1)
	_marca_cazado.outline_size = 24
	_marca_cazado.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marca_cazado.position.y = SIGNO_ALTO
	_cazado.add_child(_marca_cazado)


# --- A quien escoltas ---

# Sale al empezar su hora, donde el que dio la mision (o junto a ti si ya estas lejos, o viniste de
# otra escena), con la vida que traia; se quita al acabar el paso
func _ajustar_acompanante(paso: PasoMision) -> void:
	var quiere := paso != null and Misiones.en_hora() and (paso.tipo == PasoMision.Tipo.ESCOLTAR \
			or (paso.tipo == PasoMision.Tipo.DEFENDER and paso.acompanante != ""))
	if is_instance_valid(_acomp) and (not quiere or _acomp_de != paso):
		_quitar_acompanante()
	if not quiere or is_instance_valid(_acomp):
		return
	var se_queda := paso.tipo == PasoMision.Tipo.DEFENDER
	var donde := _meta_de_escolta(paso) if se_queda else _lugar_de_vecino(Misiones.activa)
	if not se_queda and donde.distance_to(_jugador.global_position) > ACOMPANANTE_SALE_A:
		donde = _jugador.global_position + Vector3(1.5, 0.0, 0.0)
	var vida := Misiones.vida_acompanante if Misiones.vida_acompanante >= 0 else paso.vida_acompanante
	if paso.acompanante.begins_with("carretilla"):
		# El herido de "Al medico": en una carretilla que jalas (`carretilla` o `carretilla:<modelo del herido>`)
		var partes := paso.acompanante.split(":")
		_acomp = Carretilla.crear_carretilla(self, donde, partes[1] if partes.size() > 1 else "", vida, paso.vida_acompanante)
	else:
		_acomp = Acompanante.crear(self, donde, paso.acompanante, vida, paso.vida_acompanante, se_queda)
	_acomp_de = paso
	_acomp.cayo.connect(Misiones.acompanante_cayo)


func _quitar_acompanante() -> void:
	if is_instance_valid(_acomp):
		_acomp.queue_free()
	_acomp = null
	_acomp_de = null


# --- La camioneta de reparto ---

# Sale al empezar su hora, donde el que dio la mision (o junto a ti si ya estas lejos), con la
# ruta armada para que acabe antes del amanecer; se quita al acabar el paso. Con `lugar`
# "salida_colonia" (el chofer de Santa Mugre) sale afuera de la reja de la colonia por la que
# llegaste (Misiones.salida_camioneta, al azar al aceptar: _salir_por_la_reja), en el mapa grande
func _ajustar_camioneta(paso: PasoMision) -> void:
	var quiere := paso != null and paso.tipo == PasoMision.Tipo.CAMIONETA and Misiones.en_hora()
	if is_instance_valid(_camioneta) and (not quiere or _camioneta_de != paso):
		_quitar_camioneta()
	if not quiere or is_instance_valid(_camioneta):
		return
	if paso.lugar == "salida_colonia":
		var muro := get_tree().get_first_node_in_group("muro_colonia") as MuroColonia
		if muro == null or not muro.rejas.has(Misiones.salida_camioneta):
			return   # en la colonia no sale: la ruta es afuera
		var lado := Misiones.salida_camioneta
		var afuera := MuroColonia.hacia_afuera(lado)
		_salir_camioneta(paso, muro.afuera(lado, CAMIONETA_AFUERA) + afuera.cross(Vector3.UP) * CAMIONETA_AL_LADO, afuera)
		# Los zombis no tardan: la primera turba llega casi de inmediato
		_ola_andando_en = CAMIONETA_PRIMERA_OLA_AFUERA
		return
	if paso.lugar == "salida_giver" and Misiones.arranque_camioneta != Vector3.INF:
		# La de Gabriel: sale de donde lo encontraste, y los zombis no tardan (se acaba de hacer de noche)
		_salir_camioneta(paso, Misiones.arranque_camioneta, Vector3.ZERO)
		_ola_andando_en = CAMIONETA_PRIMERA_OLA_AFUERA
		return
	var desde := _lugar_de_vecino(Misiones.activa)
	if desde.distance_to(_jugador.global_position) > ACOMPANANTE_SALE_A:
		desde = _jugador.global_position + Vector3(6.0, 0.0, 0.0)
	_salir_camioneta(paso, desde, Vector3.ZERO)


# Al aceptar la del chofer en la colonia: se corta la pantalla y apareces ya de noche afuera de una
# de las rejas de la avenida, al azar, con la camioneta arrancando (PasoColonia)
func _salir_por_la_reja(mision: MisionData) -> void:
	if not Misiones.elegir(mision):
		return
	Misiones.salida_camioneta = ["poniente", "oriente"].pick_random()
	await get_tree().create_timer(CAMIONETA_CORTE).timeout
	if not is_inside_tree() or Misiones.activa != mision:
		return
	var hora := -2.0
	if _ciclo:
		hora = _ciclo.dia_duracion / (_ciclo.dia_duracion + _ciclo.noche_duracion)
	PasoColonia.ir_a(self, PasoColonia.MAPA_GRANDE, Misiones.salida_camioneta, hora)


# Arma la ruta desde `desde` (con `rumbo`, hacia donde arranca) y la echa a andar
func _salir_camioneta(paso: PasoMision, desde: Vector3, rumbo: Vector3) -> void:
	var vida := Misiones.vida_acompanante if Misiones.vida_acompanante >= 0 else paso.vida_acompanante
	var restante: float = _ciclo.segundos_para_amanecer() if _ciclo else 0.0
	if restante <= 0.0:
		restante = CAMIONETA_NOCHE_SIN_CICLO   # el Ciclo no sabe de noche (escenas de prueba)
	var casas := _lugares_de_casas(desde, CAMIONETA_CANDIDATAS * 2, CAMIONETA_CASAS)
	# Ninguna adentro de la colonia amurallada (ahi no entra)
	var muro := get_tree().get_first_node_in_group("muro_colonia") as MuroColonia
	var candidatas: Array[Vector3] = []
	for casa in casas:
		if (muro == null or not muro.rect.grow(CAMIONETA_AFUERA).has_point(Vector2(casa.x, casa.z))) and candidatas.size() < CAMIONETA_CANDIDATAS:
			candidatas.append(casa)
	_camioneta = CamionetaReparto.crear_reparto(self, desde, candidatas, paso.cuantos, vida, paso.vida_acompanante, \
			restante, paso.descarga_s, rumbo)
	_camioneta_de = paso
	_camioneta_parada = false
	_ola_en = paso.ola_cada
	_ola_andando_en = paso.ola_andando
	# Las entregas son las paradas que cupieron antes del amanecer
	Misiones.meta_visitas = _camioneta.paradas.size()
	_camioneta.cayo.connect(Misiones.acompanante_cayo)
	_camioneta.entrega.connect(_camioneta_entrego)


func _quitar_camioneta() -> void:
	if is_instance_valid(_camioneta):
		_camioneta.queue_free()
	_camioneta = null
	_camioneta_de = null


func _camioneta_entrego(_numero: int) -> void:
	_sonar("moneda")
	Misiones.visitado()


# Mientras descarga llega una turba cada `ola_cada` s (el tinaco movil) y andando una mas chica cada
# `ola_andando` s; lo que se agrega a la
# linea de abajo
func _revisar_camioneta(paso: PasoMision, delta: float) -> String:
	if not is_instance_valid(_camioneta) or _camioneta_de != paso:
		return ""
	Misiones.vida_acompanante = _camioneta.vida
	_apuntar(_camioneta.global_position)
	var linea := " · camioneta %d%%" % roundi(100.0 * _camioneta.vida / maxf(_camioneta.vida_max, 1))
	if _camioneta.estado == CamionetaReparto.Estado.DESCARGA:
		if not _camioneta_parada:
			_camioneta_parada = true
			_ola_en = CAMIONETA_PRIMERA_OLA
		_ola_en -= delta
		if _ola_en <= 0.0:
			_ola_en = paso.ola_cada
			_turba(paso.turba)
		linea += " · descarga %d s" % ceili(_camioneta.descargando_queda())
	elif _camioneta.estado == CamionetaReparto.Estado.ANDA:
		# Andando tambien la alcanzan, menos y mas espaciadas que en las paradas
		_camioneta_parada = false
		if paso.ola_andando > 0.0:
			_ola_andando_en -= delta
			if _ola_andando_en <= 0.0:
				_ola_andando_en = paso.ola_andando
				_turba(paso.turba_andando)
		var lejos := Vector2(_jugador.global_position.x, _jugador.global_position.z).distance_to(Vector2(_camioneta.global_position.x, _camioneta.global_position.z))
		if lejos > CAMIONETA_LEJOS:
			linea += " · a %d m" % roundi(lejos)
	return linea


func _turba(cuantos: int) -> void:
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando:
		mando.aparecer_turba(cuantos)


# A donde lo llevas o donde aguantas: "giro:<giro>", "marca:<nombre>" o "casas" (una al azar), una sola vez por paso
func _meta_de_escolta(paso: PasoMision) -> Vector3:
	if _escolta_de == paso:
		return _escolta_meta
	_escolta_de = paso
	var desde := _lugar_de_vecino(Misiones.activa)
	if paso.lugar.begins_with("entrada:"):
		# Una EntradaJefe fija del mapa
		_escolta_meta = desde
		for entrada: EntradaJefe in get_tree().get_nodes_in_group("entradas_jefe"):
			if entrada.id == paso.lugar.trim_prefix("entrada:"):
				_escolta_meta = entrada.global_position
	elif paso.lugar == "clinica":
		_escolta_meta = Vector3(FortalezasMapa.CLINICA_LLEGADA.x, 0.0, FortalezasMapa.CLINICA_LLEGADA.y)
	elif paso.lugar == "torre_antena":
		_escolta_meta = Vector3(FortalezasMapa.TORRE_ANTENA.x + 3.0, 0.0, FortalezasMapa.TORRE_ANTENA.y)
	elif paso.lugar == "reja_guardia":
		# La guardia: la marca de la reja que le toco (Guardia_poniente / Guardia_oriente)
		var marca_reja: Variant = _marca("marca:Guardia_" + (Misiones.reja_guardia if Misiones.reja_guardia != "" else "poniente"))
		_escolta_meta = (marca_reja as Transform3D).origin if marca_reja != null else desde
	elif paso.lugar == "sitio_tinaco" and SitiosTinaco.elegido >= 0:
		# Volver al tinaco (si perdiste): la flecha junto a su Chava, no encima del tinaco
		_escolta_meta = SitiosTinaco.centro() + Vector3(SitiosTinaco.CHAVA_A, 0.0, 0.0)
	elif paso.lugar.begins_with("giro:"):
		_escolta_meta = _tienda(paso.lugar)
	elif _marca(paso.lugar) != null:
		_escolta_meta = (_marca(paso.lugar) as Transform3D).origin
	else:
		var casas := _lugares_de_casas(desde, 1)
		_escolta_meta = casas[0] if not casas.is_empty() else desde + Vector3(40.0, 0.0, 0.0)
	return _escolta_meta


# DEFENDER: el tiempo corre solo cerca del lugar, y cada `ola_cada` s llega otra turba. Lo que
# se agrega a la linea de abajo
func _revisar_defensa(paso: PasoMision, delta: float) -> String:
	if is_instance_valid(_acomp) and _acomp_de == paso:
		Misiones.vida_acompanante = _acomp.vida
	var meta := _meta_de_escolta(paso)
	var lejos := Vector2(_jugador.global_position.x, _jugador.global_position.z).distance_to(Vector2(meta.x, meta.z)) > DEFENDER_RADIO
	if lejos:
		return " · vuelve al lugar"
	Misiones.defendiendo(delta)
	_ola_en -= delta
	if _ola_en <= 0.0:
		_ola_en = paso.ola_cada
		var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
		if mando:
			mando.aparecer_turba(paso.cuantos)
	return ""


# Llegaron los dos a la meta
func _revisar_escolta(paso: PasoMision) -> void:
	if not is_instance_valid(_acomp) or _acomp_de != paso or _acomp.vida <= 0:
		return
	Misiones.vida_acompanante = _acomp.vida
	var meta := _meta_de_escolta(paso)
	var a := Vector2(meta.x, meta.z)
	if Vector2(_jugador.global_position.x, _jugador.global_position.z).distance_to(a) <= ESCOLTA_LLEGA \
			and Vector2(_acomp.global_position.x, _acomp.global_position.z).distance_to(a) <= ESCOLTA_LLEGA:
		_sonar("moneda")
		Misiones.escoltado()


func _poner_perro() -> void:
	if _perro:
		return
	_perro_lugar = _lugar_perro()
	_perro = load("res://scripts/map/CosaMision.gd").new()
	_perro_de = Misiones.activa
	add_child(_perro)
	_perro.global_position = _perro_lugar
	Gente.poner_modelo(_perro, PERRO, ALTO_PERRO)
	_perro.set("al_recoger", _perro_recogido)
	_voz_perro = AudioStreamPlayer3D.new()
	_voz_perro.position.y = 0.5
	_voz_perro.max_distance = PERRO_OIDO
	_voz_perro.unit_size = 12.0
	_perro.add_child(_voz_perro)
	_ladra_en = 0.5
	# El circulo no esta centrado en el: hay que buscar y oir
	var corrido := Vector2.from_angle(randf() * TAU) * randf() * PERRO_BUSCAR * 0.7
	_apuntar(_perro_lugar + Vector3(corrido.x, 0.0, corrido.y), PERRO_BUSCAR)


# Una marca "mision" de la colonia del mapa en Blender ("marca:<nombre>"), o null
func _marca(lugar: String) -> Variant:
	if not lugar.begins_with("marca:"):
		return null
	return Colonia.puntos_mision.get(lugar.trim_prefix("marca:"))


# Lo que hay que recoger en una marca (la pelota en la azotea): como el perro, pero se sabe
# donde esta, asi que va con flecha y sin ladridos
# Las piezas de la antena: en el mapa grande y de a una por lugar (en la colonia de Blender no estan); al
# acercarte salen unos zombis sueltos. Cada una recogida cuenta y paga (Misiones.pieza_recogida)
func _poner_piezas(paso: PasoMision) -> void:
	if not _piezas.is_empty() or get_tree().get_first_node_in_group("colonia") != null:
		_apuntar_a_pieza()
		return
	_piezas_de = Misiones.activa
	_piezas_zombis.clear()
	var piso := _jugador.global_position.y - 1.0
	var papeles := paso.lugar == "papeles_decreto"
	for i in mini(paso.cuantos, (BodegaGela.PAPELES if papeles else PIEZAS_ANTENA).size()):
		var donde := BodegaGela.punto(BodegaGela.PAPELES[i]) if papeles \
				else Vector3(PIEZAS_ANTENA[i].x, piso, PIEZAS_ANTENA[i].y)
		var pieza: Node3D = load("res://scripts/map/CosaMision.gd").new()
		pieza.set("que", PAPELES_NOMBRES[i] if papeles else PIEZAS_NOMBRES[i])
		pieza.add_child(_modelo_papeles(i) if papeles else _modelo_pieza(i))
		add_child(pieza)
		pieza.global_position = donde
		pieza.set("al_recoger", _pieza_recogida.bind(pieza))
		_piezas.append(pieza)
		_piezas_zombis.append(false)
	_apuntar_a_pieza()


func _quitar_piezas() -> void:
	for pieza in _piezas:
		if is_instance_valid(pieza):
			pieza.queue_free()
	_piezas.clear()
	_piezas_zombis.clear()
	_piezas_de = null


func _pieza_recogida(pieza: Node3D) -> void:
	_piezas.erase(pieza)
	pieza.queue_free()
	_sonar("moneda")
	Misiones.pieza_recogida()
	_apuntar_a_pieza()


func _de_piezas(lugar: String) -> bool:
	return lugar == "piezas_antena" or lugar == "papeles_decreto"


func _apuntar_a_pieza() -> void:
	# Los papeles: mientras la bodega siga cerrada (o no la veas aun, desde la colonia), a su cortina
	var paso := Misiones.paso()
	if paso and paso.lugar == "papeles_decreto" and (not Misiones.bodega_gela_abierta or _piezas.is_empty()):
		_apuntar(BodegaGela.frente_cortina if BodegaGela.frente_cortina != Vector3.INF else BodegaGela.punto(Vector3(0.0, 0.0, 2.0)))
		return
	var mas_cerca := INF
	for pieza in _piezas:
		var d := pieza.global_position.distance_to(_jugador.global_position)
		if d < mas_cerca:
			mas_cerca = d
			_apuntar(pieza.global_position)


# Al acercarte a una pieza salen unos zombis sueltos junto a ella (una vez por pieza)
func _revisar_piezas() -> void:
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando == null:
		return
	for i in _piezas.size():
		var pieza := _piezas[i]
		if not is_instance_valid(pieza) or pieza.global_position.distance_to(_jugador.global_position) > PIEZAS_AVISO:
			continue
		var clave := PIEZAS_ANTENA.find(Vector2(pieza.global_position.x, pieza.global_position.z))
		if clave >= _piezas_zombis.size():
			continue
		if clave < 0 or _piezas_zombis[clave]:
			continue
		_piezas_zombis[clave] = true
		for k in PIEZAS_ZOMBIS:
			var cerca := Vector2.from_angle(randf() * TAU) * (6.0 + randf() * 6.0)
			var donde := pieza.global_position + Vector3(cerca.x, 0.0, cerca.y)
			mando.sacar(donde, false)


# Una pieza hecha de cajas y cilindros, para cada una: 0 unos tubos, 1 un repetidor con su antena
static func _modelo_pieza(i: int) -> Node3D:
	var raiz := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.64, 0.66) if i == 0 else Color(0.2, 0.22, 0.24)
	material.roughness = 0.8
	if i == 0:
		for k in 3:
			var tubo := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.top_radius = 0.07
			cil.bottom_radius = 0.07
			cil.height = 1.3
			cil.radial_segments = 8
			cil.material = material
			tubo.mesh = cil
			tubo.rotation.z = PI / 2.0
			tubo.position = Vector3(0.0, 0.1 + 0.14 * (k % 2), (k - 1) * 0.16)
			raiz.add_child(tubo)
	else:
		var caja := MeshInstance3D.new()
		var cubo := BoxMesh.new()
		cubo.size = Vector3(0.5, 0.28, 0.34)
		cubo.material = material
		caja.mesh = cubo
		caja.position.y = 0.14
		raiz.add_child(caja)
		var antena := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.015
		cil.bottom_radius = 0.015
		cil.height = 0.6
		cil.material = material
		antena.mesh = cil
		antena.position = Vector3(0.18, 0.55, 0.0)
		raiz.add_child(antena)
	return raiz


# Una caja de archivo de carton con un folder amarillo encima (0 el expediente, 1 la hoja de conteo)
static func _modelo_papeles(i: int) -> Node3D:
	var raiz := Node3D.new()
	var carton := StandardMaterial3D.new()
	carton.albedo_color = Color(0.55, 0.42, 0.27)
	carton.roughness = 1.0
	var caja := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3(0.45, 0.3, 0.33)
	cubo.material = carton
	caja.mesh = cubo
	caja.position.y = 0.15
	raiz.add_child(caja)
	var folder := MeshInstance3D.new()
	var hoja := BoxMesh.new()
	hoja.size = Vector3(0.32, 0.02, 0.24) if i == 0 else Vector3(0.22, 0.01, 0.3)
	var papel := StandardMaterial3D.new()
	papel.albedo_color = Color(0.86, 0.74, 0.38) if i == 0 else Color(0.92, 0.92, 0.88)
	hoja.material = papel
	folder.mesh = hoja
	folder.position.y = 0.31
	folder.rotation.y = 0.3 if i == 0 else -0.2
	raiz.add_child(folder)
	return raiz


func _poner_cosa(paso: PasoMision) -> void:
	if _perro:
		return
	var donde := (_marca(paso.lugar) as Transform3D).origin
	_perro = load("res://scripts/map/CosaMision.gd").new()
	_perro_de = Misiones.activa
	var objeto: InventoryItemData = paso.objetos[0] if not paso.objetos.is_empty() else null
	if objeto:
		_perro.set("que", objeto.item_name.to_lower())
		_perro.add_child(objeto.crear_modelo(0.3))
	else:
		_perro.set("que", "la pelota")
		_perro.add_child(_pelota())
	add_child(_perro)
	_perro.global_position = donde
	_perro.set("al_recoger", _perro_recogido)
	_apuntar(donde)


static func _pelota() -> MeshInstance3D:
	var malla := SphereMesh.new()
	malla.radius = 0.11
	malla.height = 0.22
	malla.radial_segments = 8
	malla.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.9)
	malla.material = material
	var pelota := MeshInstance3D.new()
	pelota.mesh = malla
	pelota.position.y = 0.11
	return pelota


func _lugar_perro() -> Vector3:
	if perro_fijo != Vector3.INF:
		return perro_fijo
	var desde := _lugar_de_vecino(Misiones.activa)
	var opciones := []
	for p: Dictionary in _postes:
		var d := Vector2(desde.x, desde.z).distance_to(Vector2(p["x"], p["z"]))
		if d >= PERRO_DISTANCIA.x and d <= PERRO_DISTANCIA.y:
			opciones.append(p)
	if opciones.is_empty():
		return desde + Vector3(20.0, 0.0, 0.0)
	var p: Dictionary = opciones.pick_random()
	return Vector3(float(p["x"]) + LADO_POSTE, desde.y, float(p["z"]))


func _perro_recogido() -> void:
	var cuerpo := _perro
	_perro = null
	_voz_perro = null
	cuerpo.get_parent().remove_child(cuerpo)
	_carga_item = null
	_cosa_en_manos = true
	# Con la cosa en brazos no se cambia de mision en el diario
	Misiones.manos_ocupadas = true
	_jugador.cargar(cuerpo)
	Misiones.recogido()


# --- Lo que trae en las manos ---

# El `carga` del paso, solo a su hora: la medicina de noche no se carga todo el dia
func _ajustar_carga(paso: PasoMision) -> void:
	if _cosa_en_manos:
		return
	var quiere: InventoryItemData = paso.carga if paso and Misiones.en_hora() else null
	# La caja tirada en el piso es de este paso: hasta que la levantes, las manos van vacias
	if is_instance_valid(_caja_suelo):
		if quiere != null and _caja_de == paso:
			return
		_quitar_caja_suelo()
	if quiere == _carga_item:
		_jugador.set("carga_soltable", quiere != null and paso.soltable)
		return
	if _carga_item:
		_jugador.soltar_carga()
		_carga_item = null
	if quiere:
		_jugador.cargar(quiere.crear_modelo(0.5))
		_carga_item = quiere
		_caja_de = paso
	_jugador.set("carga_soltable", quiere != null and paso.soltable)


# El clic de ataque con la caja en brazos (Player.pidio_soltar_carga): queda a tus pies y se levanta con Espacio
func _soltar_caja_al_piso() -> void:
	var paso := Misiones.paso()
	if _carga_item == null or paso == null or not paso.soltable:
		return
	var item := _carga_item
	_jugador.soltar_carga()
	_carga_item = null
	_caja_suelo = load("res://scripts/map/CosaMision.gd").new()
	_caja_suelo.set("que", "la caja")
	_caja_suelo.add_child(item.crear_modelo(0.5))
	add_child(_caja_suelo)
	_caja_suelo.global_position = _jugador.global_position + Vector3.DOWN * 1.0
	_caja_suelo.set("al_recoger", _caja_levantada)
	_caja_de = paso


func _caja_levantada() -> void:
	_quitar_caja_suelo()
	_ajustar_carga(Misiones.paso())
	# Si la levantas ya parado en la puerta del punto, ahi mismo cuenta
	for area in _puntos.duplicate():
		if is_instance_valid(area) and area.overlaps_body(_jugador):
			_llegar_a(area)


func _quitar_caja_suelo() -> void:
	if is_instance_valid(_caja_suelo):
		_caja_suelo.queue_free()
	_caja_suelo = null


func _soltar_carga() -> void:
	if _carga_item or _cosa_en_manos:
		_jugador.soltar_carga()
	_jugador.set("carga_soltable", false)
	_carga_item = null
	_cosa_en_manos = false
	Misiones.manos_ocupadas = false
	_quitar_cosa()


# La cosa que seguia en el suelo
func _quitar_cosa() -> void:
	if _perro:
		_perro.queue_free()
		_perro = null
		_voz_perro = null


func _termino(mision: MisionData, exito: bool, texto: String) -> void:
	_escolta_de = null
	_defensa_de = null
	_sonar("moneda" if exito else "perder")
	# Al llegar con la caja, el del punto te dice algo y te paga
	if exito and mision.id.begins_with(Misiones.MAFIA) and mision.gracias != "":
		texto = "%s %s" % [mision.gracias, texto]
	if _supervivencia:
		_supervivencia.avisar(texto)


func _entrega(pesos: int) -> void:
	_sonar("moneda")
	if _supervivencia:
		_supervivencia.avisar("+$%d" % pesos)


func _sobra(objeto: InventoryItemData) -> void:
	var tirado: Node3D = load("res://scripts/WorldItem.gd").new()
	tirado.set("item_data", objeto)
	add_child(tirado)
	tirado.global_position = _jugador.global_position + Vector3.DOWN * 0.5


# --- En pantalla ---

func _process(delta: float) -> void:
	var paso := Misiones.paso()
	if paso == null:
		_texto.text = ""
		return
	var linea := paso.texto
	# Los papeles del Decreto: la flecha va a la cortina (en cuanto se arma su celda) y, abierta, a los papeles
	if paso.lugar == "papeles_decreto":
		_apuntar_a_pieza()
	var falta := Misiones.hora_que_falta(paso)
	if falta != "":
		_texto.text = "%s (%s)" % [linea, falta]
		return
	if paso.tipo == PasoMision.Tipo.VISITAR or paso.tipo == PasoMision.Tipo.LLEVAR_CARGA:
		linea += " (%d/%d)" % [Misiones.visitados, Misiones.meta_visitas]
		_apuntar_al_punto_cercano()
	elif paso.tipo == PasoMision.Tipo.RECOGER and _de_piezas(paso.lugar):
		linea += " (%d/%d)" % [Misiones.visitados, Misiones.meta_visitas]
		_revisar_piezas()
	elif paso.tipo == PasoMision.Tipo.ESCOLTAR:
		_revisar_escolta(paso)
	elif paso.tipo == PasoMision.Tipo.CAMIONETA:
		linea += " (%d/%d)" % [Misiones.visitados, Misiones.meta_visitas]
		linea += _revisar_camioneta(paso, delta)
	elif paso.tipo == PasoMision.Tipo.DEFENDER:
		linea += _revisar_defensa(paso, delta)
	elif paso.tipo == PasoMision.Tipo.CAZAR:
		_revisar_caza(paso)
	if paso.segundos > 0.0:
		linea += " · %d s" % ceili(Misiones.tiempo_queda)
	_texto.text = linea
	if _voz_perro:
		_ladra_en -= delta
		if _ladra_en <= 0.0:
			_ladra_en = randf_range(PERRO_LADRA.x, PERRO_LADRA.y)
			_voz_perro.stream = Sonidos.sonido("ladrido")
			_voz_perro.play()


func _armar_pantalla() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_texto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto.offset_left = 8.0
	_texto.offset_bottom = -26.0
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.add_theme_color_override("font_color", MapPuntos.MARCADOR_COLOR)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 4)
	capa.add_child(_texto)
	_voz = AudioStreamPlayer.new()
	add_child(_voz)


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()
