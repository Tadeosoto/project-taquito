class_name Barricada
extends Node3D

# La barricada alrededor del tinaco para la defensa de una noche, armada como la
# armarian los vecinos a las prisas: dos "anillos" chuecos de tiras rectas, cada
# tira con lo que hubo a la mano (costales, tarimas, anaqueles y banos tumbados).
# Los huecos del de afuera no quedan enfrente de los de adentro, asi que los
# zombis tienen que zigzaguear. Todo va a media altura (~1 m) para ver y disparar
# por encima.
#
# Sale al azar de una semilla: generar(semilla) la arma (0 = al azar) y la vuelve a
# armar si ya habia una. El tinaco se queda. Para cambiar como sale se mueven los
# numeros de aqui abajo.
#
# En el mapa real primero se planea todo y luego cada pieza se baja al suelo y se
# brinca si choca con algo que ya esta (capa 1: casas, bardas, arboles, postes): una
# casa o una fila de casas hace de barricada en ese tramo. Por eso generar() va
# despues de que cargo el mapa de alrededor.

enum { COSTALES, TARIMAS, PILA_TARIMAS, ESTANTE, BANO, TAMBO }

# Cada anillo: radio de sus esquinas (m, min y max), cuantos lados, cuantos huecos
# y su ancho (m, min y max), y que tan seguido un lado lleva quiebre y de cuanto (m).
# Los huecos miden casi 4 m: los zombis se guian por una rejilla de 1.25 m
# (CampoFlujo.gd) y un hueco mas angosto en diagonal les quedaba cerrado.
# El de afuera tiene pocos lados, radios muy dispares y quiebres grandes: con mas
# lados y radios parejos se veia redondo.
const ANILLOS := [
	{"radio": [6.5, 8.5], "lados": [5, 7], "huecos": 3, "hueco": [3.8, 4.4], "quiebre": 0.35, "quiebre_m": [0.3, 0.8]},
	{"radio": [12.0, 19.0], "lados": [5, 7], "huecos": 3, "hueco": [4.0, 4.8], "quiebre": 0.5, "quiebre_m": [0.8, 2.2]},
]
const LIBRE_TINACO := 4.5        # m que el anillo de adentro deja libres alrededor del tinaco
const SEPARACION_MIN := 3.5      # m libres entre los dos anillos en cualquier punto
const HUECOS_DESFASE := 35.0     # grados minimos entre un hueco de afuera y uno de adentro
# Esquinas: cada tira se pasa de su esquina y a veces se corre, asi las uniones se
# enciman o hacen escalon en vez de cerrar limpias
const ESQUINA_PASA := [0.2, 0.7]
const ESQUINA_CORRE := 0.3
# De que se arma cada tira: pesos (se saca de una bolsa barajada, asi sale parejo)
const MEZCLA := {COSTALES: 4, BANO: 2, ESTANTE: 2, TARIMAS: 2, PILA_TARIMAS: 1}
const LARGO_COSTALES := [2.5, 5.0]
const LARGO_TARIMAS := [2.0, 4.0]
const PIEZA_MIN := 0.8           # lo menos que mide una pieza que se estira
# Lo que se encima cada pieza con la siguiente (m): alcanza para que el desorden de
# abajo no abra rendijas
const TRASLAPE := 0.35
# Desorden: cada pieza se sale de su tira hasta DESORDEN_RADIAL m y se tuerce hasta
# DESORDEN_GIRO grados (las de largo fijo, el doble)
const DESORDEN_RADIAL := 0.25
const DESORDEN_GIRO := 5.0
# Tambos: a los lados de cada hueco de afuera, uno a un lado de cada hueco de adentro y
# unos cuantos alrededor del tinaco
const TAMBOS_TINACO := [3, 4]
const TAMBOS_TINACO_RADIO := [3.2, 3.8]   # entre el tinaco y el anillo, sin tapar el paso
const TAMBOS_SEPARACION := 2.8
const JUGADOR_SALE := Vector3(2.5, 0.0, 2.5)  # donde aparece el jugador: ahi no va tambo

# Todo va 15 % mas grande que en la vida real: junto al ninja cabezon, a tamano real
# se veia de juguete. Con esto la barda de costales mide ~1 m
const ESCALA := 1.15
# Costal de cemento de 50 kg acostado
const COSTAL := Vector3(0.6, 0.15, 0.4) * ESCALA
const COSTAL_CAPAS := 6
const COSTAL_FILAS := 2           # de fondo
# Unos de papel gris y otros de kraft cafe, unos mas sucios
const COSTAL_COLORES := [Color(0.82, 0.8, 0.76), Color(0.74, 0.72, 0.68), Color(0.86, 0.74, 0.56), Color(0.78, 0.66, 0.5), Color(0.66, 0.64, 0.6)]
# Tarima estandar
const TARIMA := Vector3(1.2, 0.144, 1.0) * ESCALA
const TARIMA_COLOR := Color(0.62, 0.48, 0.32)
const RAMPA_CAIDA := 30.0   # grados de las orillas del lomo de las tarimas acostadas
const PILA_ALTO := 6
# Anaquel metalico tumbado de espaldas: su fondo queda de alto y las repisas, paradas,
# hacen pared hacia afuera. Largo en el anillo, alto (fondo del anaquel), y lo que
# mide parado (radial). El estante_oxidado de las bodegas es pura armazon y no tapaba.
const ANAQUEL := Vector3(2.0, 0.9, 1.8) * ESCALA
const ANAQUEL_REPISAS := 5
const ANAQUEL_COLOR := Color(0.36, 0.42, 0.38)
# El bano, de lado
const BANO_ALTO := 1.15 * ESCALA
const BANO_LARGO := 1.95 * ESCALA   # lo que mide acostado a lo largo del anillo (su alto, escalado)
const BANO_ACOSTAR := Basis(Vector3.BACK, PI / 2.0)
const TINACO_ALTO := 2.8   # uno de 10 mil litros: ~2.8 m de alto y ~2.2 m de ancho
const TINACO_PIEZAS := ["Tinaco_3er_capa", "Bomba_1", "Tapa"]  # el modelo trae tres tinacos; uno completo
const FUEGO_LUZ := Color(1.0, 0.55, 0.2)
const FUEGO_RANGO := 7.0
const FUEGO_ENERGIA := 1.6
# Revisar donde cae cada pieza: el suelo por un rayo, y no se pone si a CHOCA_DESDE m del
# suelo su caja (con CHOCA_HOLGURA m menos por lado) toca algo. Mas alto que SUELO_MAX
# sobre el tinaco no es suelo (una azotea, un tronco).
const CHOCA_DESDE := 0.35
const CHOCA_ALTO := 0.8
const CHOCA_HOLGURA := 0.1
const SUELO_MAX := 0.6

const SHADER := preload("res://shaders/ps1_combined.gdshader")
const MapAlumbrado := preload("res://scripts/map/MapAlumbrado.gd")
const MODELO_TINACO := preload("res://models/props/tinaco/tinaco.scn")
const MODELO_BANO := preload("res://models/props/bano_portatil/bano_portatil.scn")

var semilla_usada := 0
# Lo que ocupa cada pieza en el piso, para el minimapa: [Transform3D del centro, Vector2 ancho y fondo]
var huellas: Array = []
var tambos: Array[Transform3D]:
	get: return _tambos
var tinaco_radio := 0.0
# El centro de cada hueco del anillo de afuera, en el mundo: cada zombi escoge uno (Zombie._hueco)
var huecos_mundo: Array[Vector3] = []
var _destino: Node3D             # de donde cuelga lo generado; se tira al volver a generar
var _costales: Array = []   # [Transform3D, Color]
var _tarimas: Array = []    # [Transform3D]
var _anaqueles: Array = []  # [Transform3D]
var _tambos: Array[Transform3D] = []
var _bolsa: Array[int] = []
var _plan: Array = []       # [tipo, Transform3D, largo]: lo planeado, antes de revisar si cabe
var quitadas := 0           # piezas que no se pusieron porque ahi ya habia algo
var _consulta: PhysicsShapeQueryParameters3D
var _rng := RandomNumberGenerator.new()
var _malla_costal_lista: ArrayMesh
var _malla_tarima_lista: ArrayMesh
var _malla_anaquel_lista: ArrayMesh
var _mat_costal: ShaderMaterial
var _mat_tarima: ShaderMaterial
var _mat_metal: ShaderMaterial


func _ready() -> void:
	# Mallas y materiales una vez, siempre iguales
	_rng.seed = 7
	_tinaco()
	_malla_costal_lista = _malla_costal()
	_malla_tarima_lista = _malla_tarima()
	_malla_anaquel_lista = _malla_anaquel()
	_mat_costal = _material_costal()
	_mat_tarima = _material_color(Color.WHITE)
	_mat_metal = _material_color(Color.WHITE)
	_mat_metal.set_shader_parameter("deterioro_modo", 4)
	_mat_metal.set_shader_parameter("metal", true)
	_consulta = PhysicsShapeQueryParameters3D.new()
	_consulta.shape = BoxShape3D.new()
	_consulta.collision_mask = 1


func generar(semilla := 0) -> void:
	if _destino:
		remove_child(_destino)
		_destino.queue_free()
	_destino = Node3D.new()
	_destino.name = "Generado"
	add_child(_destino)
	huellas.clear()
	_costales.clear()
	_tarimas.clear()
	_anaqueles.clear()
	_tambos.clear()
	_bolsa.clear()
	_plan.clear()
	quitadas = 0
	if semilla == 0:
		semilla = randi_range(1, 999999)
	semilla_usada = semilla
	_rng.seed = semilla
	var adentro := _poligono(ANILLOS[0], LIBRE_TINACO)
	var afuera := _poligono(ANILLOS[1], _radio_max(adentro) + SEPARACION_MIN)
	var huecos_adentro := _angulos_huecos(ANILLOS[0]["huecos"], [])
	var huecos_afuera := _angulos_huecos(ANILLOS[1]["huecos"], huecos_adentro)
	var abiertos_adentro := _armar_anillo(adentro, huecos_adentro, ANILLOS[0])
	var abiertos_afuera := _armar_anillo(afuera, huecos_afuera, ANILLOS[1])
	_poner_tambos(abiertos_adentro, abiertos_afuera)
	huecos_mundo.clear()
	for hueco: Array in abiertos_afuera:
		huecos_mundo.append(to_global(hueco[0]))
	_construir()
	_destino.add_child(_multimesh(_malla_costal_lista, _mat_costal, _costales))
	_destino.add_child(_multimesh(_malla_tarima_lista, _mat_tarima, _tarimas))
	if not _anaqueles.is_empty():
		_destino.add_child(_multimesh(_malla_anaquel_lista, _mat_metal, _anaqueles))
	for nodo in MapAlumbrado.armar_tambos(_tambos, 0.0):
		_destino.add_child(nodo)
	var tambos := StaticBody3D.new()
	tambos.name = "Tambos"
	_destino.add_child(tambos)
	for lugar in _tambos:
		tambos.add_child(MapAlumbrado.colision_tambo(lugar))
		var luz := OmniLight3D.new()
		luz.light_color = FUEGO_LUZ
		luz.light_energy = FUEGO_ENERGIA
		luz.omni_range = FUEGO_RANGO
		luz.position = lugar.origin + Vector3.UP * (MapAlumbrado.TAMBO_ALTO + 0.4)
		_destino.add_child(luz)


# Lo planeado que cabe, ya en el suelo. Se revisa todo antes de armar nada, para que
# las piezas no choquen con las suyas
func _construir() -> void:
	var espacio := get_world_3d().direct_space_state
	var excluir: Array[RID] = [get_node("Tinaco").get_rid()]
	var jugador := get_tree().get_first_node_in_group("jugador") as CollisionObject3D
	if jugador:
		excluir.append(jugador.get_rid())
	_consulta.exclude = excluir
	var caben := []
	for pieza: Array in _plan:
		var lugar: Variant = _en_el_suelo(espacio, excluir, pieza[0], pieza[1], pieza[2])
		if lugar == null:
			quitadas += 1
		else:
			caben.append([pieza[0], lugar, pieza[2]])
	for pieza: Array in caben:
		_poner(pieza[0], pieza[1], pieza[2])


# `lugar` bajado al suelo, o null si ahi no cabe
func _en_el_suelo(espacio: PhysicsDirectSpaceState3D, excluir: Array[RID], tipo: int, lugar: Transform3D, largo: float) -> Variant:
	var mundo := global_transform * lugar
	var rayo := PhysicsRayQueryParameters3D.create(mundo.origin + Vector3.UP * 3.0, mundo.origin + Vector3.DOWN * 3.0, 1, excluir)
	var pego := espacio.intersect_ray(rayo)
	if pego.is_empty() or pego.position.y - global_position.y > SUELO_MAX:
		return null
	var medida := _medida(tipo, largo)
	(_consulta.shape as BoxShape3D).size = Vector3(maxf(medida.x - CHOCA_HOLGURA * 2.0, 0.2), CHOCA_ALTO, maxf(medida.y - CHOCA_HOLGURA * 2.0, 0.2))
	_consulta.transform = Transform3D(mundo.basis, pego.position + Vector3.UP * (CHOCA_DESDE + CHOCA_ALTO / 2.0))
	if not espacio.intersect_shape(_consulta, 1).is_empty():
		return null
	lugar.origin.y = pego.position.y - global_position.y
	return lugar


# Lo que ocupa en el piso: a lo largo de la tira y de fondo
func _medida(tipo: int, largo: float) -> Vector2:
	match tipo:
		COSTALES: return Vector2(largo, COSTAL.z * COSTAL_FILAS)
		TARIMAS: return Vector2(largo, TARIMA.z + 0.3)
		PILA_TARIMAS: return Vector2(TARIMA.x, TARIMA.z)
		ESTANTE: return Vector2(ANAQUEL.x, ANAQUEL.z)
		BANO: return Vector2(BANO_LARGO, BANO_ALTO)
	return Vector2.ONE * (MapAlumbrado.TAMBO_RADIO * 2.0)


func _poner(tipo: int, lugar: Transform3D, largo: float) -> void:
	match tipo:
		COSTALES: _hilera_costales(lugar, largo)
		TARIMAS: _tarimas_paradas(lugar, largo)
		PILA_TARIMAS: _pila_tarimas(lugar)
		ESTANTE:
			_anaquel(lugar)
			_costales_encima(lugar, ANAQUEL.x, ANAQUEL.y)
		BANO:
			_acostado(MODELO_BANO, lugar, BANO_ACOSTAR, Vector3(0.0, BANO_ALTO, 0.0), "Bano")
			_costales_encima(lugar, BANO_LARGO, BANO_ALTO)
		TAMBO: _tambos.append(lugar)


# --- La forma de cada anillo ---

# Esquinas en orden horario (angulo creciente), cada lado a no menos de `libre` m del
# centro. Algunos lados llevan un quiebre a medio camino.
func _poligono(anillo: Dictionary, libre: float) -> Array[Vector3]:
	var lados := _rng.randi_range(anillo["lados"][0], anillo["lados"][1])
	var paso := TAU / lados
	var giro := _rng.randf_range(0.0, TAU)
	var esquinas: Array[Vector3] = []
	for i in lados:
		var a := giro + i * paso + _rng.randf_range(-0.4, 0.4) * paso
		esquinas.append(_en_angulo(a) * _rng.randf_range(anillo["radio"][0], anillo["radio"][1]))
	# Los lados no deben entrar a menos de `libre` del centro: se empujan sus esquinas
	for vuelta in 4:
		for i in lados:
			var a := esquinas[i]
			var b := esquinas[(i + 1) % lados]
			var cerca := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, a, b).length()
			if cerca < libre:
				esquinas[i] = a * (libre / cerca)
				esquinas[(i + 1) % lados] = b * (libre / cerca)
	var con_quiebres: Array[Vector3] = []
	for i in lados:
		var a := esquinas[i]
		var b := esquinas[(i + 1) % lados]
		con_quiebres.append(a)
		if _rng.randf() < anillo["quiebre"]:
			var medio := a.lerp(b, _rng.randf_range(0.35, 0.65))
			# Siempre hacia afuera, para no acercarse al otro anillo ni al tinaco
			con_quiebres.append(medio + medio.normalized() * _rng.randf_range(anillo["quiebre_m"][0], anillo["quiebre_m"][1]))
	return con_quiebres


func _radio_max(esquinas: Array[Vector3]) -> float:
	var r := 0.0
	for e in esquinas:
		r = maxf(r, e.length())
	return r


# Angulos (radianes) de los huecos: repartidos con jitter. Si hay `evitar`, cada uno
# queda a HUECOS_DESFASE de todos esos
func _angulos_huecos(cuantos: int, evitar: Array[float]) -> Array[float]:
	var paso := TAU / cuantos
	var mejor: Array[float] = []
	var mejor_distancia := -1.0
	for intento in 60:
		var giro := _rng.randf_range(0.0, TAU)
		var angulos: Array[float] = []
		for i in cuantos:
			angulos.append(fposmod(giro + i * paso + _rng.randf_range(-0.2, 0.2) * paso, TAU))
		var distancia := PI
		for a in angulos:
			for b in evitar:
				distancia = minf(distancia, absf(angle_difference(a, b)))
		if distancia > mejor_distancia:
			mejor = angulos
			mejor_distancia = distancia
		if distancia >= deg_to_rad(HUECOS_DESFASE):
			break
	return mejor


# Llena cada lado con tiras, dejando los huecos. Devuelve los huecos como
# [centro, direccion del lado, ancho, hacia afuera]
func _armar_anillo(esquinas: Array[Vector3], angulos: Array[float], anillo: Dictionary) -> Array:
	var n := esquinas.size()
	# Huecos por lado: [desde, hasta] en metros sobre el lado
	var cortes := []
	for i in n:
		cortes.append([])
	var abiertos := []
	for angulo in angulos:
		var ancho := _rng.randf_range(anillo["hueco"][0], anillo["hueco"][1])
		var rayo := _en_angulo(angulo) * 100.0
		for i in n:
			var a := esquinas[i]
			var b := esquinas[(i + 1) % n]
			var cruce: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, Vector2(rayo.x, rayo.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
			if cruce == null:
				continue
			var largo := a.distance_to(b)
			var t: float = a.distance_to(Vector3(cruce.x, 0.0, cruce.y))
			t = clampf(t, ancho / 2.0, largo - ancho / 2.0)
			cortes[i].append([t - ancho / 2.0, t + ancho / 2.0])
			var dir := (b - a) / largo
			abiertos.append([a + dir * t, dir, ancho, _afuera(a, b)])
			break
	for i in n:
		var a := esquinas[i]
		var b := esquinas[(i + 1) % n]
		var largo := a.distance_to(b)
		var dir := (b - a) / largo
		var tramos := [[0.0, largo]]
		for corte: Array in cortes[i]:
			var nuevos := []
			for t: Array in tramos:
				if corte[1] <= t[0] or corte[0] >= t[1]:
					nuevos.append(t)
					continue
				if corte[0] > t[0]:
					nuevos.append([t[0], corte[0]])
				if corte[1] < t[1]:
					nuevos.append([corte[1], t[1]])
			tramos = nuevos
		for t: Array in tramos:
			# Las puntas que dan a una esquina se pasan de ella; las de un hueco no
			var desde: float = t[0] - (_rng.randf_range(ESQUINA_PASA[0], ESQUINA_PASA[1]) if t[0] <= 0.0 else 0.0)
			var hasta: float = t[1] + (_rng.randf_range(ESQUINA_PASA[0], ESQUINA_PASA[1]) if t[1] >= largo else 0.0)
			var corrido := _afuera(a, b) * _rng.randf_range(-ESQUINA_CORRE, ESQUINA_CORRE)
			_tira(a + dir * desde + corrido, a + dir * hasta + corrido, _afuera(a, b))
	return abiertos


# Una tira recta de `a` a `b`, llena de lo que salga de la bolsa
func _tira(a: Vector3, b: Vector3, afuera: Vector3) -> void:
	var largo := a.distance_to(b)
	if largo < PIEZA_MIN:
		return
	var dir := (b - a) / largo
	# Igual que en el resto de las piezas: X a lo largo, Z hacia adentro
	var base := Basis(Vector3.UP.cross(-afuera), Vector3.UP, -afuera)
	var s := 0.0
	while largo - s > 0.3:
		var tipo := _de_la_bolsa()
		var fijo := _largo_fijo(tipo)
		var pieza: float
		if fijo > 0.0:
			# Si ya no cabe, en su lugar va lo que se estira
			if s + fijo > largo + 0.3:
				tipo = COSTALES if _rng.randf() < 0.6 else TARIMAS
				pieza = largo - s
			else:
				pieza = fijo
		else:
			var rango: Array = LARGO_COSTALES if tipo == COSTALES else LARGO_TARIMAS
			pieza = minf(_rng.randf_range(rango[0], rango[1]), largo - s)
			# Lo que sobraria no alcanza para otra pieza: esta se estira hasta el final
			if largo - s - pieza < PIEZA_MIN:
				pieza = largo - s
		pieza = maxf(pieza, PIEZA_MIN)
		var centro := a + dir * (s + pieza / 2.0) + afuera * _rng.randf_range(-DESORDEN_RADIAL, DESORDEN_RADIAL)
		var giro := deg_to_rad(_rng.randf_range(-DESORDEN_GIRO, DESORDEN_GIRO) * (2.0 if fijo > 0.0 else 1.0))
		var lugar := Transform3D(base.rotated(Vector3.UP, giro), centro)
		_plan.append([tipo, lugar, pieza + (TRASLAPE if _largo_fijo(tipo) == 0.0 else 0.0)])
		s += pieza


func _de_la_bolsa() -> int:
	if _bolsa.is_empty():
		for tipo: int in MEZCLA:
			for i in MEZCLA[tipo]:
				_bolsa.append(tipo)
		# Barajar con la semilla
		for i in range(_bolsa.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t := _bolsa[i]
			_bolsa[i] = _bolsa[j]
			_bolsa[j] = t
	return _bolsa.pop_back()


func _largo_fijo(tipo: int) -> float:
	match tipo:
		PILA_TARIMAS: return TARIMA.x
		ESTANTE: return ANAQUEL.x
		BANO: return BANO_LARGO
	return 0.0


# La normal del lado de `a` a `b` que se aleja del centro
func _afuera(a: Vector3, b: Vector3) -> Vector3:
	var dir := (b - a).normalized()
	var n := Vector3(dir.z, 0.0, -dir.x)
	return n if n.dot((a + b) / 2.0) > 0.0 else -n


# 0 = norte (-Z), horario visto desde arriba
func _en_angulo(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, -cos(a))


# --- Tambos ---

func _poner_tambos(adentro: Array, afuera: Array) -> void:
	for hueco: Array in afuera:
		for lado in [-1.0, 1.0]:
			var donde: Vector3 = hueco[0] + hueco[3] * 1.3 + hueco[1] * lado * (hueco[2] / 2.0 + 0.7)
			_plan.append([TAMBO, Transform3D(Basis.IDENTITY, donde), 0.0])
	# A un lado de cada hueco de adentro, por fuera: enfrente lo tapaba
	for hueco: Array in adentro:
		var lado := 1.0 if _rng.randf() < 0.5 else -1.0
		_plan.append([TAMBO, Transform3D(Basis.IDENTITY, hueco[0] + hueco[3] * 1.2 + hueco[1] * lado * (hueco[2] / 2.0 + 0.6)), 0.0])
	var cuantos := _rng.randi_range(TAMBOS_TINACO[0], TAMBOS_TINACO[1])
	var puestos: Array[Vector3] = []
	for intento in 100:
		if puestos.size() >= cuantos:
			break
		var donde := _en_angulo(_rng.randf_range(0.0, TAU)) * _rng.randf_range(TAMBOS_TINACO_RADIO[0], TAMBOS_TINACO_RADIO[1])
		if donde.distance_to(JUGADOR_SALE) < 1.5:
			continue
		var libre := true
		for otro in puestos:
			if otro.distance_to(donde) < TAMBOS_SEPARACION:
				libre = false
		if libre:
			puestos.append(donde)
			_plan.append([TAMBO, Transform3D(Basis.IDENTITY, donde), 0.0])


# --- El tinaco, en el piso ---

func _tinaco() -> void:
	var cuerpo := TinacoDefensa.new()
	cuerpo.name = "Tinaco"
	add_child(cuerpo)
	var modelo := MODELO_TINACO.instantiate() as Node3D
	for pieza in modelo.find_children("*", "Node3D"):
		if pieza.name.begins_with("Tinaco_") and pieza.get_parent().name == "Tinaco" and not pieza.name in TINACO_PIEZAS:
			pieza.queue_free()
			pieza.get_parent().remove_child(pieza)
	var caja := _caja_de(modelo)
	var escala := TINACO_ALTO / caja.size.y
	var sosten := Node3D.new()
	sosten.scale = Vector3.ONE * escala
	sosten.position = Vector3(-caja.get_center().x * escala, -caja.position.y * escala, -caja.get_center().z * escala)
	sosten.add_child(modelo)
	cuerpo.add_child(sosten)
	var radio := maxf(caja.size.x, caja.size.z) * escala / 2.0
	tinaco_radio = radio
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = TINACO_ALTO
	forma.shape = cilindro
	forma.position.y = cilindro.height / 2.0
	cuerpo.add_child(forma)
	cuerpo.armar(radio, TINACO_ALTO)


# --- Costales: hilera de COSTAL_FILAS de fondo y COSTAL_CAPAS de alto, cuatrapeados ---

# Apilados a mano: cada hilera tiene su alto, arriba faltan algunos y otros se cayeron
func _hilera_costales(lugar: Transform3D, largo: float) -> void:
	var por_capa := maxi(1, roundi(largo / COSTAL.x))
	var capas := COSTAL_CAPAS - (1 if _rng.randf() < 0.35 else 0)
	for capa in capas:
		var corrido := COSTAL.x / 2.0 if capa % 2 == 1 else 0.0
		var cuantos := por_capa - (1 if capa % 2 == 1 else 0)
		# En las dos de arriba faltan costales aqui y alla
		var faltan := 0.0 if capa < capas - 2 else (0.1 if capa == capas - 2 else 0.25)
		for fila in COSTAL_FILAS:
			var z := (fila - (COSTAL_FILAS - 1) / 2.0) * COSTAL.z
			for i in cuantos:
				if _rng.randf() < faltan:
					continue
				var x := -largo / 2.0 + COSTAL.x / 2.0 + corrido + i * COSTAL.x * (largo / (por_capa * COSTAL.x))
				var y := COSTAL.y * (capa + 0.5) - capa * 0.012
				var giro := Basis(Vector3.UP, _rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.06, 0.06))
				var donde := Vector3(x + _rng.randf_range(-0.07, 0.07), y, z + _rng.randf_range(-0.06, 0.06))
				_costal(lugar * Transform3D(giro, donde))
	# Uno a tres tirados al pie, de cualquier lado
	for i in _rng.randi_range(1, 3):
		var lado := 1.0 if _rng.randf() < 0.5 else -1.0
		var donde := Vector3(_rng.randf_range(-largo / 2.0, largo / 2.0), COSTAL.y / 2.0, lado * (COSTAL.z * COSTAL_FILAS / 2.0 + _rng.randf_range(0.25, 0.6)))
		_costal(lugar * Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), donde))
	_colision(lugar, Vector3(largo, COSTAL.y * capas, COSTAL.z * COSTAL_FILAS))


# Unos costales aventados encima de un bano o un anaquel
func _costales_encima(lugar: Transform3D, largo: float, alto: float) -> void:
	for i in _rng.randi_range(0, 3):
		var donde := Vector3(_rng.randf_range(-largo / 2.0 + 0.3, largo / 2.0 - 0.3), alto + COSTAL.y / 2.0, _rng.randf_range(-0.15, 0.15))
		var giro := Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.1, 0.1))
		_costal(lugar * Transform3D(giro, donde))


func _costal(donde: Transform3D) -> void:
	_costales.append([donde, COSTAL_COLORES[_rng.randi() % COSTAL_COLORES.size()]])


# --- Tarimas ---

# Paradas de canto, una junto a otra, recargadas en una pila chica de atras
func _tarimas_paradas(lugar: Transform3D, largo: float) -> void:
	var cuantas := maxi(1, roundi(largo / TARIMA.x))
	for i in cuantas:
		var x := -largo / 2.0 + TARIMA.x * (i + 0.5) * (largo / (cuantas * TARIMA.x))
		# De canto: el lado de 1 m queda vertical, las tablas de cubierta hacia afuera
		var basis := Basis(Vector3.RIGHT, -PI / 2.0).rotated(Vector3.UP, _rng.randf_range(-0.12, 0.12))
		basis = Basis(Vector3.RIGHT, _rng.randf_range(-0.2, -0.03)) * Basis(Vector3.BACK, _rng.randf_range(-0.06, 0.06)) * basis
		_tarimas.append([lugar * Transform3D(basis, Vector3(x + _rng.randf_range(-0.1, 0.1), TARIMA.z / 2.0, 0.0))])
		# Una o dos acostadas atras para que no se caigan
		for capa in _rng.randi_range(1, 2):
			var atras := Vector3(x + _rng.randf_range(-0.15, 0.15), TARIMA.y * capa, -TARIMA.z / 2.0 - 0.1 + _rng.randf_range(-0.1, 0.1))
			_tarimas.append([lugar * Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3)), atras)])
	_colision(lugar, Vector3(largo, TARIMA.z, TARIMA.y), Vector3.ZERO)
	_rampa(lugar, Vector3(largo, TARIMA.y * 2.0, TARIMA.z), Vector3(0.0, 0.0, -TARIMA.z / 2.0 - 0.1))


func _pila_tarimas(lugar: Transform3D) -> void:
	for capa in PILA_ALTO:
		var giro := Basis(Vector3.UP, _rng.randf_range(-0.3, 0.3))
		_tarimas.append([lugar * Transform3D(giro, Vector3(_rng.randf_range(-0.12, 0.12), TARIMA.y * capa, _rng.randf_range(-0.1, 0.1)))])
	_colision(lugar, Vector3(TARIMA.x, TARIMA.y * PILA_ALTO, TARIMA.z))


# --- Anaquel tumbado ---

func _anaquel(lugar: Transform3D) -> void:
	_anaqueles.append([lugar])
	_colision(lugar, ANAQUEL)


# Con el pie en y = 0 y centrado: postes a lo radial, repisas paradas y el fondo en el piso
func _malla_anaquel() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var poste := 0.05 * ESCALA
	var lamina := 0.02 * ESCALA
	for x in [-1.0, 1.0]:
		for y in [poste / 2.0, ANAQUEL.y - poste / 2.0]:
			_caja(st, Vector3(x * (ANAQUEL.x / 2.0 - poste / 2.0), y, 0.0), Vector3(poste, poste, ANAQUEL.z), ANAQUEL_COLOR.darkened(0.2))
	for i in ANAQUEL_REPISAS:
		var z := -ANAQUEL.z / 2.0 + lamina / 2.0 + i * (ANAQUEL.z - lamina) / (ANAQUEL_REPISAS - 1)
		_caja(st, Vector3(0.0, ANAQUEL.y / 2.0, z), Vector3(ANAQUEL.x - poste * 2.0, ANAQUEL.y - 0.04, lamina), ANAQUEL_COLOR)
	_caja(st, Vector3(0.0, lamina / 2.0, 0.0), Vector3(ANAQUEL.x, lamina, ANAQUEL.z), ANAQUEL_COLOR.darkened(0.35))
	st.generate_normals()
	return st.commit()


# --- Modelos acostados (el bano), con lo largo a lo largo del anillo ---

# `medida`: lo que debe medir ya acostado; un eje en 0 sigue la escala del alto
func _acostado(escena: PackedScene, lugar: Transform3D, acostar: Basis, medida: Vector3, nombre: String) -> void:
	var modelo := escena.instantiate() as Node3D
	var acostada := Transform3D(acostar, Vector3.ZERO) * _caja_de(modelo)
	var uniforme := medida.y / acostada.size.y
	var escala := Vector3(
		medida.x / acostada.size.x if medida.x > 0.0 else uniforme,
		uniforme,
		medida.z / acostada.size.z if medida.z > 0.0 else uniforme)
	var sosten := Node3D.new()
	sosten.name = nombre
	sosten.transform = lugar
	_destino.add_child(sosten)
	var dentro := Node3D.new()
	var centro := acostada.get_center()
	dentro.transform = Transform3D(Basis.from_scale(escala) * acostar, -Vector3(centro.x, acostada.position.y, centro.z) * escala)
	dentro.add_child(modelo)
	sosten.add_child(dentro)
	var tamano := acostada.size * escala
	huellas.append([lugar, Vector2(tamano.x, tamano.z)])
	var cuerpo := StaticBody3D.new()
	sosten.add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var caja_forma := BoxShape3D.new()
	caja_forma.size = tamano
	forma.shape = caja_forma
	forma.position.y = tamano.y / 2.0
	cuerpo.add_child(forma)


# --- Ayudas ---

func _colision(lugar: Transform3D, medida: Vector3, centro := Vector3.ZERO) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.transform = lugar
	_destino.add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medida
	forma.shape = caja
	forma.position = centro + Vector3.UP * medida.y / 2.0
	cuerpo.add_child(forma)
	huellas.append([lugar * Transform3D(Basis.IDENTITY, centro), Vector2(medida.x, medida.z)])


# Las tarimas acostadas: una caja de 33 cm era un escalon que los zombis no suben, y el campo
# de flujo (que mira a 1 m del piso) no la ve, asi que se atoraban ahi. Un lomo con caidas de
# ~30 grados (menos que el piso maximo de un CharacterBody3D) lo pasan caminando por encima
func _rampa(lugar: Transform3D, medida: Vector3, centro := Vector3.ZERO) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.transform = lugar
	_destino.add_child(cuerpo)
	var x := medida.x / 2.0
	var z := medida.z / 2.0
	var cresta := maxf(x - medida.y / tan(deg_to_rad(RAMPA_CAIDA)), 0.0)
	var forma := CollisionShape3D.new()
	var lomo := ConvexPolygonShape3D.new()
	lomo.points = PackedVector3Array([
		Vector3(-x, 0.0, -z), Vector3(x, 0.0, -z), Vector3(-x, 0.0, z), Vector3(x, 0.0, z),
		Vector3(-cresta, medida.y, 0.0), Vector3(cresta, medida.y, 0.0),
	])
	forma.shape = lomo
	forma.position = centro
	cuerpo.add_child(forma)
	huellas.append([lugar * Transform3D(Basis.IDENTITY, centro), Vector2(medida.x, medida.z)])


static func _caja_de(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for malla: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
		if malla.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var nodo: Node = malla
		while nodo != raiz:
			t = (nodo as Node3D).transform * t
			nodo = nodo.get_parent()
		var b := t * malla.mesh.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	return caja


func _multimesh(malla: Mesh, material: Material, instancias: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malla
	mm.instance_count = instancias.size()
	for i in instancias.size():
		mm.set_instance_transform(i, instancias[i][0])
		mm.set_instance_color(i, instancias[i][1] if instancias[i].size() > 1 else Color.WHITE)
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = mm
	nodo.material_override = material
	return nodo


func _material_color(color: Color, textura: Texture2D = null) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("use_vertex_color", true)
	if textura:
		material.set_shader_parameter("albedo_texture", textura)
	return material


# Papel de costal: papel kraft gris con fibras, polvo de cemento, las puntas cosidas y
# dobladas, una franja de color y el letrero impreso en la cara de arriba
const TEXTURA_COSTAL := Vector2i(64, 32)
const COSTAL_LETRERO := ["CEMENTO", "GRIS 50KG"]
const COSTAL_TINTA := Color(0.55, 0.14, 0.1)
const COSTAL_FRANJA := Color(0.2, 0.3, 0.55)
# Letras de 3×5 (filas de arriba a abajo, # = tinta)
const LETRAS := {
	"C": ["###", "#..", "#..", "#..", "###"], "E": ["###", "#..", "##.", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."], "O": ["###", "#.#", "#.#", "#.#", "###"],
	"G": ["###", "#..", "#.#", "#.#", "###"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "S": ["###", "#..", "###", "..#", "###"],
	"5": ["###", "#..", "###", "..#", "##."], "0": ["###", "#.#", "#.#", "#.#", "###"],
	"K": ["#.#", "##.", "#..", "##.", "#.#"], " ": ["...", "...", "...", "...", "..."],
}
# Donde empieza cada cara de la seccion en v: la de arriba (de 5 a 6) se lleva media textura
const V_SECCION := [0.0, 0.07, 0.17, 0.24, 0.3, 0.38, 0.88, 0.94, 1.0]


func _material_costal() -> ShaderMaterial:
	var w := TEXTURA_COSTAL.x
	var h := TEXTURA_COSTAL.y
	var imagen := Image.create(w, h, false, Image.FORMAT_RGB8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 3
	ruido.frequency = 0.12
	var arriba := [int(V_SECCION[5] * h), int(V_SECCION[6] * h)]
	for x in w:
		for y in h:
			# Papel: fibras a lo largo y manchas
			var v := 0.84 + _rng.randf_range(-0.04, 0.04) + sin(y * 2.7 + x * 0.15) * 0.015
			var c := Color(v, v * 0.97, v * 0.9)
			# Polvo de cemento: manchas claras y grises
			var polvo := ruido.get_noise_2d(x, y)
			if polvo > 0.25:
				c = c.lerp(Color(0.78, 0.78, 0.76), 0.6)
			elif polvo < -0.45:
				c = c.darkened(0.15)
			# Franja de color a un lado
			if y >= arriba[0] - 3 and y < arriba[0] - 1:
				c = COSTAL_FRANJA.lerp(c, 0.15)
			# Las puntas dobladas y cosidas
			var punta := mini(x, w - 1 - x)
			if punta < 6:
				c = c.darkened(0.08 + 0.03 * (6 - punta))
				if punta == 3 and y % 2 == 0:
					c = Color(0.35, 0.3, 0.25)
			imagen.set_pixel(x, y, c)
	# Letrero arriba, centrado, una linea abajo de otra; la tinta salteada como gastada
	var alto_letrero := COSTAL_LETRERO.size() * 6 - 1
	var y0: int = arriba[0] + (arriba[1] - arriba[0] - alto_letrero) / 2
	for n in COSTAL_LETRERO.size():
		var texto: String = COSTAL_LETRERO[n]
		var x0 := (w - texto.length() * 4 + 1) / 2
		for k in texto.length():
			var letra: Array = LETRAS.get(texto[k], LETRAS[" "])
			for fy in 5:
				for fx in 3:
					if letra[fy][fx] == "#" and _rng.randf() > 0.12:
						imagen.set_pixel(x0 + k * 4 + fx, y0 + n * 6 + fy, COSTAL_TINTA.lerp(Color(0.8, 0.75, 0.68), _rng.randf_range(0.0, 0.25)))
	return _material_color(Color.WHITE, ImageTexture.create_from_image(imagen))


# Costal (caras en el orden de Godot, horario visto de afuera): prisma de seccion octagonal achatada, con las puntas pellizcadas
func _malla_costal() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mx := COSTAL.x / 2.0
	var my := COSTAL.y / 2.0
	var mz := COSTAL.z / 2.0
	# Seccion (z, y) alrededor del eje X; en las puntas se encoge
	var seccion := [Vector2(-mz, -my * 0.6), Vector2(-mz * 0.75, -my), Vector2(mz * 0.75, -my), Vector2(mz, -my * 0.6),
		Vector2(mz, my * 0.3), Vector2(mz * 0.7, my), Vector2(-mz * 0.7, my), Vector2(-mz, my * 0.3)]
	var anillos := [[-mx, 0.55], [-mx * 0.8, 1.0], [mx * 0.8, 1.0], [mx, 0.55]]
	var puntos := []
	for anillo: Array in anillos:
		var fila := []
		for p: Vector2 in seccion:
			fila.append(Vector3(anillo[0], p.y * (0.5 + 0.5 * anillo[1]) - my * (1.0 - anillo[1]) * 0.5, p.x * anillo[1]))
		puntos.append(fila)
	var n := seccion.size()
	for a in anillos.size() - 1:
		for i in n:
			var j := (i + 1) % n
			var u0: float = (anillos[a][0] + mx) / (mx * 2.0)
			var u1: float = (anillos[a + 1][0] + mx) / (mx * 2.0)
			var v0: float = V_SECCION[i]
			var v1: float = V_SECCION[i + 1]
			_tri(st, puntos[a][i], puntos[a + 1][i], puntos[a + 1][j], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
			_tri(st, puntos[a][i], puntos[a + 1][j], puntos[a][j], Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
	# Tapas
	for a in [0, anillos.size() - 1]:
		var centro := Vector3(anillos[a][0], -my * 0.2, 0.0)
		for i in n:
			var j := (i + 1) % n
			if a == 0:
				_tri(st, centro, puntos[a][j], puntos[a][i], Vector2(0.02, 0.5), Vector2(0.02, 0.5), Vector2(0.02, 0.5))
			else:
				_tri(st, centro, puntos[a][i], puntos[a][j], Vector2(0.98, 0.5), Vector2(0.98, 0.5), Vector2(0.98, 0.5))
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_color(Color.WHITE)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ub)
	st.add_vertex(b)


# Tarima: 7 tablas de cubierta, 3 largueros y 3 tablas de abajo, con el pie en y = 0
func _malla_tarima() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tabla := 0.022 * ESCALA
	var larguero := TARIMA.y - tabla * 2.0
	for i in 7:
		var z := -TARIMA.z / 2.0 + 0.05 + i * (TARIMA.z - 0.1) / 6.0
		var tono := TARIMA_COLOR.darkened(0.12 * (i % 3) / 2.0)
		_caja(st, Vector3(0.0, TARIMA.y - tabla / 2.0, z), Vector3(TARIMA.x, tabla, 0.1 * ESCALA), tono)
	for i in 3:
		var x := (i - 1) * (TARIMA.x / 2.0 - 0.05)
		_caja(st, Vector3(x, tabla + larguero / 2.0, 0.0), Vector3(0.1 * ESCALA, larguero, TARIMA.z), TARIMA_COLOR.darkened(0.25))
	for i in 3:
		var z := (i - 1) * (TARIMA.z / 2.0 - 0.05)
		_caja(st, Vector3(0.0, tabla / 2.0, z), Vector3(TARIMA.x, tabla, 0.1 * ESCALA), TARIMA_COLOR.darkened(0.1))
	st.generate_normals()
	return st.commit()


func _caja(st: SurfaceTool, centro: Vector3, medida: Vector3, color: Color) -> void:
	var m := medida / 2.0
	var caras := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for cara: Array in caras:
		var n: Vector3 = cara[0]
		var u: Vector3 = cara[1]
		var v: Vector3 = cara[2]
		var c := centro + n * m
		var du := u * m
		var dv := v * m
		var p := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(p[k])
