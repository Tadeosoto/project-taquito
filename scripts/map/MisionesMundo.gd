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
const TEXTO_HORA := "%s: \"Esto me toca %s.\""

@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"
@export_file("*.json") var casas_path := "res://resources/map/casas_mapa.json"
@export_file("*.json") var postes_path := "res://resources/map/alumbrado_mapa.json"
# El safehouse: donde van, en vez de buscar postes
@export var vecinos_fijos: Array[Vector3] = []
@export var perro_fijo := Vector3.INF

var vecinos: Array[Dictionary] = []
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
var _escolta_de: PasoMision = null
var _escolta_meta := Vector3.ZERO


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
	if _ciclo:
		_ciclo.aviso_atardecer.connect(Misiones.atardecer)
		_ciclo.anochecio.connect(_anochecio)
		_ciclo.amanecio.connect(_amanecio)
	_poner_vecinos()
	_cambio()


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
	var lugares := vecinos_fijos if not vecinos_fijos.is_empty() else _lugares_vecinos()
	var cuantos := mini(lugares.size(), Misiones.todas.size())
	for i in cuantos:
		var mision := Misiones.todas[i]
		var npc := NPC.instantiate() as Node3D
		var ninja := npc.get_node("Model")
		npc.remove_child(ninja)
		ninja.free()
		add_child(npc)
		var marca: Variant = _marca(mision.donde)
		if marca != null:
			# Parado en su marca de la colonia, viendo a donde ve la marca
			lugares[i] = (marca as Transform3D).origin
		npc.global_position = lugares[i]
		var hacia := _jugador.global_position - lugares[i]
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
		npc.set("al_hablar", _hablar.bind(i))
		vecinos.append({"mision": mision, "nodo": npc, "signo": signo, "lugar": lugares[i], "visto": false})
	if lugares.size() > cuantos:
		_nino_lugar = lugares[cuantos]
		nino = NinoTazos.new()
		add_child(nino)
		nino.global_position = _nino_lugar
		var hacia := _jugador.global_position - _nino_lugar
		nino.rotation.y = atan2(hacia.x, hacia.z)
	_actualizar_signos()


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
		if lugares.size() >= Misiones.todas.size() + 1:
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
	if not Misiones.ofreciendo:
		return TEXTO_TARDE
	if not v["visto"]:
		v["visto"] = true
		return ("%s %s" % [Personaje.linea("vecino"), mision.oferta]).strip_edges() + TEXTO_ACEPTAR
	v["visto"] = false
	Misiones.aceptar(mision)
	var falta := Misiones.hora_que_falta(mision.pasos[0] if not mision.pasos.is_empty() else null)
	if falta != "" and _supervivencia:
		_supervivencia.avisar(TEXTO_HORA % [Personaje.nombre, falta])
	return mision.aceptada


func _actualizar_signos() -> void:
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
	# Se acabo la mision de la cosa (y ya entro la siguiente): se suelta
	if _cosa_en_manos and _perro_de != Misiones.activa:
		_soltar_carga()
	if _perro and (_perro_de != Misiones.activa or paso == null or paso.tipo != PasoMision.Tipo.RECOGER):
		_quitar_cosa()
	if paso == null:
		_soltar_carga()
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
		PasoMision.Tipo.VISITAR, PasoMision.Tipo.LLEVAR_CARGA:
			# Tambien llega aqui en cada entrega: los que quedan se quedan
			if _puntos.is_empty():
				_poner_puntos(paso)
		PasoMision.Tipo.RECOGER:
			if paso.lugar.begins_with("marca:") and _marca(paso.lugar) != null:
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
	var desde := _lugar_de_vecino(Misiones.activa)
	# Al volver de otra escena, solo las que faltan
	var lugares := _lugares_de_casas(desde, paso.cuantos - Misiones.visitados)
	# Si no hay tantas casas (el safehouse), con las que haya
	Misiones.meta_visitas = Misiones.visitados + lugares.size()
	_puntos_de = Misiones.activa
	for lugar in lugares:
		_puntos.append(_punto_de_visita(lugar))
	_apuntar_al_punto_cercano()


# `faltan` frentes de casa a CASAS_DISTANCIA de `desde`, lejos entre si
func _lugares_de_casas(desde: Vector3, faltan: int) -> Array[Vector3]:
	var opciones := []
	for c: Dictionary in _casas:
		var d := Vector2(desde.x, desde.z).distance_to(Vector2(c["x"], c["z"]))
		if d >= CASAS_DISTANCIA.x and d <= CASAS_DISTANCIA.y:
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
		# Fuera de su hora el punto se queda: cuenta cuando sea de noche (o de dia)
		if body is Player and Misiones.en_hora():
			_puntos.erase(area)
			area.queue_free()
			_sonar("moneda")
			Misiones.visitado())
	return area


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
	if paso and (paso.tipo == PasoMision.Tipo.VISITAR or paso.tipo == PasoMision.Tipo.LLEVAR_CARGA) \
			and not _puntos.is_empty() and _puntos_de == Misiones.activa:
		return
	for area in _puntos:
		area.queue_free()
	_puntos.clear()


# --- A quien escoltas ---

# Sale al empezar su hora, donde el que dio la mision (o junto a ti si ya estas lejos, o viniste de
# otra escena), con la vida que traia; se quita al acabar el paso
func _ajustar_acompanante(paso: PasoMision) -> void:
	var quiere := paso != null and paso.tipo == PasoMision.Tipo.ESCOLTAR and Misiones.en_hora()
	if is_instance_valid(_acomp) and (not quiere or _acomp_de != paso):
		_quitar_acompanante()
	if not quiere or is_instance_valid(_acomp):
		return
	var donde := _lugar_de_vecino(Misiones.activa)
	if donde.distance_to(_jugador.global_position) > ACOMPANANTE_SALE_A:
		donde = _jugador.global_position + Vector3(1.5, 0.0, 0.0)
	var vida := Misiones.vida_acompanante if Misiones.vida_acompanante >= 0 else paso.vida_acompanante
	_acomp = Acompanante.crear(self, donde, paso.acompanante, vida, paso.vida_acompanante)
	_acomp_de = paso
	_acomp.cayo.connect(Misiones.acompanante_cayo)


func _quitar_acompanante() -> void:
	if is_instance_valid(_acomp):
		_acomp.queue_free()
	_acomp = null
	_acomp_de = null


# A donde lo llevas: "giro:<giro>", "marca:<nombre>" o "casas" (una al azar), una sola vez por paso
func _meta_de_escolta(paso: PasoMision) -> Vector3:
	if _escolta_de == paso:
		return _escolta_meta
	_escolta_de = paso
	var desde := _lugar_de_vecino(Misiones.activa)
	if paso.lugar.begins_with("giro:"):
		_escolta_meta = _tienda(paso.lugar)
	elif _marca(paso.lugar) != null:
		_escolta_meta = (_marca(paso.lugar) as Transform3D).origin
	else:
		var casas := _lugares_de_casas(desde, 1)
		_escolta_meta = casas[0] if not casas.is_empty() else desde + Vector3(40.0, 0.0, 0.0)
	return _escolta_meta


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
	if quiere == _carga_item:
		return
	if _carga_item:
		_jugador.soltar_carga()
		_carga_item = null
	if quiere:
		_jugador.cargar(quiere.crear_modelo(0.5))
		_carga_item = quiere


func _soltar_carga() -> void:
	if _carga_item or _cosa_en_manos:
		_jugador.soltar_carga()
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


func _termino(_mision: MisionData, exito: bool, texto: String) -> void:
	_escolta_de = null
	_sonar("moneda" if exito else "perder")
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
	var falta := Misiones.hora_que_falta(paso)
	if falta != "":
		_texto.text = "%s (%s)" % [linea, falta]
		return
	if paso.tipo == PasoMision.Tipo.VISITAR or paso.tipo == PasoMision.Tipo.LLEVAR_CARGA:
		linea += " (%d/%d)" % [Misiones.visitados, Misiones.meta_visitas]
		_apuntar_al_punto_cercano()
	elif paso.tipo == PasoMision.Tipo.ESCOLTAR:
		_revisar_escolta(paso)
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
