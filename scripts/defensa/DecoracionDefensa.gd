class_name DecoracionDefensa
extends Node3D

# Lo que le da vida a la defensa del tinaco sin cambiar como se juega (docs/plan-noche.md S10):
# bocinas de escenario en tripies alrededor del tinaco (como en el piloto: la horda llega al agua
# y al sonido) y dos pickups del gremio con tambos azules en la caja y un rollo de manguera en el
# techo, que se van una por una durante la noche, a repartir. Todo es visual: sin choque, para no cambiar el camino de los zombis.

const BOCINAS := 4
const BOCINA_RADIO := 5.4          # m del tinaco: entre sus tambos y el anillo de adentro
const BOCINA := preload("res://models/props/bocina_escenario/bocina_escenario.scn")   # Speaker Stage: frente en +Z
const BOCINA_ALTO := 1.35          # m (el modelo mide 3.3)
const BOCINA_MODELO_ALTO := 3.337
const BOCINA_BASE := Vector3(-0.012, -1.323, -0.456)   # centro de abajo del modelo (su origen esta corrido)
const POSTE_ALTO := 1.4            # el tripie: un tubo y tres patas
const POSTE_RADIO := 0.035
const PATA_LARGO := 0.9
const PATA_ABRE := 30.0            # grados contra la vertical
const POSTE_COLOR := Color(0.3, 0.3, 0.32)

const FURGONETA_CAJA := Vector3(2.2, 2.0, 5.4)      # lo que ocupa, para no ponerla sobre una casa o un arbol
const FURGONETA_ANGULOS := 36                       # pares de lados opuestos que se prueban
const FURGONETA_HOLGURA := 0.5                      # m entre la caja de la camioneta y el anillo de afuera
const FURGONETA_PASO := 0.5                         # m que se recorre hacia afuera buscando lugar
const FURGONETA_HASTA := 12.0                       # m mas alla del anillo que se busca, a lo mucho
const FURGONETA_HUECO := 4.5                        # m: no estacionarse frente a un hueco del anillo de afuera
const ANILLO_AFUERA_MIN := 9.5                      # m: las piezas mas lejos que esto son del anillo de afuera
const SALIDA_ANCHO := 2.8                           # m del camino libre que necesita para irse
const SALIDA_CALLE_HASTA := 25.0                   # m al frente que busca una calle
const SALIDA_GIRO_RADIO := 3.5                      # m de la vuelta para entrar a la calle
const CALLE_RECORRE := 120.0                        # m que sigue la calle antes de desaparecer (de noche ya no se ve)
const SALIDA_CURVA := 8                             # puntos de la vuelta
const FURGONETA_SALE := [26.0, 29.0]                # a que hora (Hordas.hora) recoge su manguera y se va: a media noche y casi al amanecer
const RUTAS_CONTRARIAS := -0.3                      # coseno: las dos se pierden por lados contrarios del parque
# La manguera: del rollo baja por atras de la cabina, pasa sobre los tambos y la compuerta y va
# por el piso (encima de la barricada) hasta el tinaco, al que le da la vuelta hasta su bomba
const MANGUERA_RADIO := 0.06                        # mas gruesa que una real: a 640x480 la de 2 cm no se ve
const MANGUERA_LADOS := 6
const MANGUERA_COLOR := Color(0.25, 0.72, 0.3)      # el verde del rollo
const MANGUERA_BRILLO := 0.25                       # algo de brillo propio: de noche el verde se perdia
const MANGUERA_PASO := 0.5                          # m entre puntos sobre el piso
const MANGUERA_ALTO := 0.04                         # sobre lo que tenga abajo
const MANGUERA_DURA := 8.0                          # s en recogerse toda
const MANGUERA_ENROLLA := 0.3                       # radio del rollo con manguera (en el modelo) para que gire a la par
const BOMBA := "Bomba_1"                            # la pieza del modelo del tinaco (Barricada.TINACO_PIEZAS)
# Por donde va sobre la camioneta (en la camioneta, en m): sale de atras del rollo, la orilla de
# la cabina, encima de los tambos, la compuerta y el piso detras
const MANGUERA_EN_CAMIONETA := [Vector3(0.0, 2.3, -0.28), Vector3(0.0, 2.0, -0.45), Vector3(0.0, 1.72, -0.9),
		Vector3(0.0, 1.72, -2.1), Vector3(0.0, 1.38, -2.58), Vector3(0.0, 0.0, -3.2)]
const SE_VA_RAPIDO := 9.0                           # m/s maximos de la camioneta al irse

enum { ESPERA, RECOGE, SE_FUE }

var hordas: Hordas
var barricada: Barricada

var _furgonetas: Array[Dictionary] = []   # {nodo, rollo, ruta, sale_a, estado, manguera, puntos, largo, queda}
var _material_manguera: StandardMaterial3D
var _armado := 0                             # cuenta los armar(): uno viejo que espera ya no pone nada


# Despues de cada Barricada.generar: se tira lo anterior y se arma de nuevo alrededor del tinaco
func armar(de_barricada: Barricada, de_hordas: Hordas) -> void:
	barricada = de_barricada
	hordas = de_hordas
	for hijo in get_children():
		hijo.queue_free()
	_furgonetas.clear()
	_armado += 1
	global_position = barricada.global_position
	_poner_bocinas()
	_poner_furgonetas()


func _poner_bocinas() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = POSTE_COLOR
	var tubo := CylinderMesh.new()
	tubo.top_radius = POSTE_RADIO
	tubo.bottom_radius = POSTE_RADIO
	tubo.radial_segments = 6
	tubo.height = 1.0
	tubo.material = material
	var arranque := randf() * TAU
	for i in BOCINAS:
		var angulo := arranque + TAU * i / BOCINAS
		var poste := Node3D.new()
		poste.position = Vector3(cos(angulo), 0.0, sin(angulo)) * BOCINA_RADIO
		# Su +Z (el frente de la bocina) hacia afuera, a donde llega la horda
		poste.rotation.y = atan2(cos(angulo), sin(angulo))
		add_child(poste)
		_tubo(poste, tubo, POSTE_ALTO, Vector3(0.0, POSTE_ALTO / 2.0, 0.0), Vector3.ZERO)
		for p in 3:
			# Del piso (afuera, en su +Z) al tubo; girada en Y para repartir las tres
			var abre := deg_to_rad(PATA_ABRE)
			_tubo(poste, tubo, PATA_LARGO, Vector3(0.0, cos(abre), sin(abre)) * PATA_LARGO / 2.0, Vector3(-abre, TAU * p / 3.0, 0.0))
		var escala := BOCINA_ALTO / BOCINA_MODELO_ALTO
		var bocina: Node3D = BOCINA.instantiate()
		bocina.scale = Vector3.ONE * escala
		bocina.position = Vector3(0.0, POSTE_ALTO, 0.0) - BOCINA_BASE * escala
		poste.add_child(bocina)


# `donde` y el giro en X van ya girados giro.y sobre el poste
func _tubo(padre: Node3D, malla: CylinderMesh, largo: float, donde: Vector3, giro: Vector3) -> void:
	var tubo := MeshInstance3D.new()
	tubo.mesh = malla
	tubo.scale.y = largo   # la malla mide 1 m
	tubo.position = donde
	tubo.rotation = Vector3(giro.x, 0.0, 0.0)
	var base := Node3D.new()
	base.rotation.y = giro.y
	padre.add_child(base)
	base.add_child(tubo)


# De reversa (la caja hacia el tinaco), lo mas pegadas que quepan al anillo de afuera, una del
# lado contrario de la otra, y con el camino libre al frente para irse sin pasar por casas o arboles
func _poner_furgonetas() -> void:
	var armado := _armado
	# Las piezas de la barricada recien puestas (y las viejas que se tiran) llegan al espacio de
	# fisica en el siguiente cuadro de fisica
	await get_tree().physics_frame
	if armado != _armado or not is_inside_tree():
		return
	var espacio := get_world_3d().direct_space_state
	var mejor: Array = []
	var mejor_lejos := INF
	var arranque := randf() * TAU
	for i in FURGONETA_ANGULOS:
		var angulo := arranque + PI * i / FURGONETA_ANGULOS
		var una := _junto_al_anillo(espacio, angulo)
		if una.is_empty():
			continue
		var otra := _junto_al_anillo(espacio, angulo + PI)
		if otra.is_empty():
			continue
		if una[1] + otra[1] >= mejor_lejos:
			continue
		# De las rutas de cada una, las que mas se van en sentidos contrarios
		var contrarias := RUTAS_CONTRARIAS
		for ruta_una: PackedVector3Array in una[2]:
			for ruta_otra: PackedVector3Array in otra[2]:
				var coseno := _hacia(ruta_una).dot(_hacia(ruta_otra))
				if coseno < contrarias:
					contrarias = coseno
					mejor_lejos = una[1] + otra[1]
					mejor = [[una[0], angulo, ruta_una], [otra[0], angulo + PI, ruta_otra]]
	for n in mejor.size():
		_furgoneta(mejor[n][0], mejor[n][1], mejor[n][2], FURGONETA_SALE[n])


# Hacia donde se pierde la ruta, visto desde el tinaco
func _hacia(ruta: PackedVector3Array) -> Vector3:
	var final := ruta[ruta.size() - 1] - global_position
	final.y = 0.0
	return final.normalized()


# [lugar, cuanto se alejo del anillo, rutas de salida] de la camioneta en `angulo`, o [] si ahi
# no cabe o no tiene por donde irse
func _junto_al_anillo(espacio: PhysicsDirectSpaceState3D, angulo: float) -> Array:
	var afuera := Vector3(cos(angulo), 0.0, sin(angulo))
	var de_lado := Vector3(-afuera.z, 0.0, afuera.x)
	# Frente a un hueco del anillo de afuera estorbaria la entrada de los zombis
	for hueco in barricada.huecos_mundo:
		var h := hueco - global_position
		h.y = 0.0
		if h.dot(afuera) > 0.0 and absf(h.dot(de_lado)) < FURGONETA_HUECO:
			return []
	# Hasta donde llega el anillo de afuera en esta direccion (las huellas de sus piezas)
	var anillo := 0.0
	for huella: Array in barricada.huellas:
		var centro: Vector3 = barricada.to_global((huella[0] as Transform3D).origin) - global_position
		var medio := (huella[1] as Vector2).length() / 2.0
		var lejos := centro.dot(afuera)
		if lejos < ANILLO_AFUERA_MIN or absf(centro.dot(de_lado)) > medio + FURGONETA_CAJA.x / 2.0:
			continue
		anillo = maxf(anillo, lejos + medio)
	if anillo == 0.0:
		return []
	var atras := anillo + FURGONETA_HOLGURA
	while atras < anillo + FURGONETA_HASTA:
		var punto := global_position + afuera * (atras + FURGONETA_CAJA.z / 2.0)
		var lugar := _suelo_libre(espacio, punto, angulo)
		if lugar != Vector3.INF:
			var rutas := _rutas_salida(espacio, lugar, angulo)
			return [lugar, atras - anillo, rutas] if not rutas.is_empty() else []
		atras += FURGONETA_PASO
	return []


# Su +Z (el frente) hacia afuera
func _de_reversa(angulo: float) -> Basis:
	return Basis(Vector3.UP, atan2(cos(angulo), sin(angulo)))


# El piso en `punto` si esta parejo y no hay nada de la capa 1 en la caja de la camioneta
func _suelo_libre(espacio: PhysicsDirectSpaceState3D, punto: Vector3, angulo: float) -> Vector3:
	var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, global_position.y + 30.0, punto.z), Vector3(punto.x, global_position.y - 3.0, punto.z), 1)
	var pego := espacio.intersect_ray(rayo)
	if pego == null or pego.is_empty() or absf(pego.position.y - global_position.y) > 0.8:
		return Vector3.INF
	if _choca(espacio, FURGONETA_CAJA, Transform3D(_de_reversa(angulo), pego.position + Vector3.UP * (FURGONETA_CAJA.y / 2.0 + 0.3))):
		return Vector3.INF
	return pego.position


# Por donde se va: derecho por el pasto (sin nada de la capa 1: casas, arboles, bardas, postes)
# hasta la calle que tenga al frente, una vuelta para entrar a ella y la sigue CALLE_RECORRE m,
# hasta perderse: una ruta por cada lado al que da la vuelta (puntos en global desde `lugar`).
# Ninguna si no tiene una calle al frente o no hay paso libre hasta ella.
func _rutas_salida(espacio: PhysicsDirectSpaceState3D, lugar: Vector3, angulo: float) -> Array[PackedVector3Array]:
	var rutas: Array[PackedVector3Array] = []
	var afuera := Vector3(cos(angulo), 0.0, sin(angulo))
	var de_lado := Vector3(-afuera.z, 0.0, afuera.x)
	var frente := lugar + afuera * FURGONETA_CAJA.z / 2.0
	var entra := -1.0
	var avance := 0.0
	while avance < SALIDA_CALLE_HASTA:
		if CallesRuta.es_calle(frente + afuera * avance):
			entra = avance
			break
		avance += 1.0
	if entra < 0.0:
		return rutas
	# El centro de la calle, a lo ancho de como entra
	var sale := entra
	while sale < entra + CallesRuta.ANCHO_MAX and CallesRuta.es_calle(frente + afuera * (sale + 1.0)):
		sale += 1.0
	var centro := frente + afuera * (entra + sale) / 2.0
	if not _tramo_libre(espacio, frente, afuera, (entra + sale) / 2.0):
		return rutas
	var radio := minf(SALIDA_GIRO_RADIO, centro.distance_to(frente))
	var antes := centro - afuera * radio
	for lado in [de_lado, -de_lado]:
		var calle := CallesRuta.seguir(centro, lado, CALLE_RECORRE)
		if calle.size() < 3:
			continue
		# Derecho hasta antes de la calle, la vuelta y la calle
		var ruta := PackedVector3Array([lugar, antes])
		var despues := calle[0] + (calle[1] - calle[0]).normalized() * radio
		for i in range(1, SALIDA_CURVA + 1):
			var t := float(i) / SALIDA_CURVA
			ruta.append(antes.lerp(centro, t).lerp(centro.lerp(despues, t), t))
		for punto in calle:
			if punto.distance_to(centro) > radio + 0.5:
				ruta.append(punto)
		rutas.append(_al_piso(espacio, CallesRuta.suavizar(ruta)))
	return rutas


# Cada punto a la altura del piso que tiene abajo (las calles no son planas)
func _al_piso(espacio: PhysicsDirectSpaceState3D, ruta: PackedVector3Array) -> PackedVector3Array:
	for i in ruta.size():
		var rayo := PhysicsRayQueryParameters3D.create(ruta[i] + Vector3.UP * 4.0, ruta[i] + Vector3.DOWN * 6.0, 1)
		var pego := espacio.intersect_ray(rayo)
		if not pego.is_empty() and absf(pego.position.y - ruta[i].y) < 2.0:
			ruta[i].y = pego.position.y
	return ruta


# Un camino de SALIDA_ANCHO desde `desde` hacia `hacia`, de `largo` m, sin nada de la capa 1
func _tramo_libre(espacio: PhysicsDirectSpaceState3D, desde: Vector3, hacia: Vector3, largo: float) -> bool:
	var caja := Vector3(SALIDA_ANCHO, FURGONETA_CAJA.y, largo)
	var centro := desde + hacia * largo / 2.0 + Vector3.UP * (caja.y / 2.0 + 0.5)
	return not _choca(espacio, caja, Transform3D(Basis(Vector3.UP, atan2(hacia.x, hacia.z)), centro))


func _choca(espacio: PhysicsDirectSpaceState3D, medida: Vector3, donde: Transform3D) -> bool:
	var caja := BoxShape3D.new()
	caja.size = medida
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = caja
	consulta.collision_mask = 1
	consulta.transform = donde
	return not espacio.intersect_shape(consulta, 1).is_empty()


func _furgoneta(lugar: Vector3, angulo: float, ruta: PackedVector3Array, sale_a: float) -> void:
	var nodo := Node3D.new()
	add_child(nodo)
	nodo.global_position = lugar
	nodo.basis = _de_reversa(angulo)
	var modelo := CamionetaModelo.crear(int(sale_a), true)
	nodo.add_child(modelo)
	var rollo := modelo.get_node("Rollo") as Node3D
	var puntos := _camino_manguera(nodo)
	var largo := 0.0
	for i in range(1, puntos.size()):
		largo += puntos[i].distance_to(puntos[i - 1])
	var manguera := MeshInstance3D.new()
	manguera.top_level = true   # sus puntos van en global
	add_child(manguera)
	var f := {"nodo": nodo, "rollo": rollo, "ruta": ruta, "sale_a": sale_a, "estado": ESPERA,
			"manguera": manguera, "puntos": puntos, "largo": largo, "queda": largo}
	_furgonetas.append(f)
	_dibujar_manguera(f)


# Para las capturas de revision (DefensaTinaco --capturas): [nombre, desde, hacia] en global
func vistas() -> Array:
	var lista := []
	var bocina := get_child(0) as Node3D
	if bocina != null:
		var frente := bocina.global_basis.z
		var alto := Vector3.UP * (POSTE_ALTO + BOCINA_ALTO / 2.0)
		lista.append(["bocina", bocina.global_position + frente * 4.0 + bocina.global_basis.x * 1.5 + Vector3.UP * 2.2, bocina.global_position + alto])
		lista.append(["bocinas", global_position + Vector3(9.0, 6.0, 9.0), global_position + Vector3.UP])
	lista.append(["camionetas", global_position + Vector3(0.0, 55.0, 0.1), global_position])
	lista.append(["rutas", global_position + Vector3(0.0, 130.0, 0.1), global_position])
	for n in _furgonetas.size():
		var nodo: Node3D = _furgonetas[n]["nodo"]
		lista.append(["camioneta_%d" % n, nodo.global_position + nodo.global_basis.x * 7.0 + nodo.global_basis.z * 4.5 + Vector3.UP * 4.0, nodo.global_position + Vector3.UP])
		lista.append(["camioneta_%d_atras" % n, nodo.global_position - nodo.global_basis.x * 5.0 - nodo.global_basis.z * 6.0 + Vector3.UP * 4.0, nodo.global_position + Vector3.UP])
	return lista


# Las rutas de salida como lineas rojas (solo para las capturas de revision)
func dibujar_rutas() -> void:
	var lineas := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.RED
	material.no_depth_test = true
	for f in _furgonetas:
		var ruta: PackedVector3Array = f["ruta"]
		lineas.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		for punto in ruta:
			lineas.surface_add_vertex(to_local(punto) + Vector3.UP * 0.5)
		lineas.surface_end()
	var malla := MeshInstance3D.new()
	malla.mesh = lineas
	add_child(malla)


func _process(delta: float) -> void:
	if hordas == null or _furgonetas.is_empty():
		return
	var hora := hordas.hora()
	for f in _furgonetas:
		match f["estado"]:
			ESPERA:
				if hora >= f["sale_a"] and hora < Hordas.HORA_EMPIEZA + Hordas.HORAS:
					f["estado"] = RECOGE
			RECOGE:
				# La punta se arrastra hacia la camioneta y el rollo gira a la par
				var recoge: float = minf(f["largo"] / MANGUERA_DURA * delta, f["queda"])
				f["queda"] -= recoge
				(f["rollo"] as Node3D).rotate_object_local(Vector3.BACK, recoge / (MANGUERA_ENROLLA * CamionetaModelo.ROLLO_ESCALA))
				_dibujar_manguera(f)
				if f["queda"] <= 0.0:
					f["estado"] = SE_FUE
					(f["manguera"] as Node3D).queue_free()
					_irse(f["nodo"], f["ruta"])


# Los puntos de la manguera en global, desde el rollo hasta la bomba del tinaco
func _camino_manguera(nodo: Node3D) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	for punto: Vector3 in MANGUERA_EN_CAMIONETA:
		puntos.append(nodo.global_transform * punto)
	var espacio := get_world_3d().direct_space_state
	var tinaco := barricada.global_position
	var radio := barricada.tinaco_radio + MANGUERA_RADIO * 4.0
	var bomba_nodo := barricada.find_child(BOMBA, true, false) as Node3D
	var bomba := bomba_nodo.global_position if bomba_nodo != null else tinaco
	# Por el piso, derecho al tinaco, pasando por encima de lo que haya
	var desde := puntos[puntos.size() - 1]
	var hacia_camioneta := desde - tinaco
	hacia_camioneta.y = 0.0
	var llega := tinaco + hacia_camioneta.normalized() * radio
	var tramos := int(desde.distance_to(llega) / MANGUERA_PASO)
	for i in range(1, tramos + 1):
		puntos.append(_sobre_el_piso(espacio, desde.lerp(llega, float(i) / tramos)))
	# La vuelta al tinaco por el lado mas corto, hasta donde esta su bomba
	var de := atan2(hacia_camioneta.z, hacia_camioneta.x)
	var a := atan2(bomba.z - tinaco.z, bomba.x - tinaco.x)
	var vuelta := angle_difference(de, a)
	var pasos := int(absf(vuelta) * radio / MANGUERA_PASO)
	for i in range(1, pasos + 1):
		var angulo := de + vuelta * i / pasos
		puntos.append(_sobre_el_piso(espacio, tinaco + Vector3(cos(angulo), 0.0, sin(angulo)) * radio))
	puntos.append(bomba)
	return puntos


# `punto` sobre lo primero que tenga abajo: el piso, o los costales y las tarimas de la barricada
func _sobre_el_piso(espacio: PhysicsDirectSpaceState3D, punto: Vector3) -> Vector3:
	var arriba := Vector3(punto.x, global_position.y + 4.0, punto.z)
	var pego := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(arriba, arriba + Vector3.DOWN * 8.0, 1))
	if pego.is_empty():
		return punto
	return pego.position + Vector3.UP * MANGUERA_ALTO


# Un tubo por los puntos, desde el rollo y solo los primeros `queda` m: lo demas ya se enrollo
func _dibujar_manguera(f: Dictionary) -> void:
	var puntos: PackedVector3Array = f["puntos"]
	var queda: float = f["queda"]
	var centro := PackedVector3Array([puntos[0]])
	for i in range(1, puntos.size()):
		var tramo := puntos[i].distance_to(puntos[i - 1])
		if tramo >= queda:
			centro.append(puntos[i - 1].lerp(puntos[i], queda / tramo))
			break
		queda -= tramo
		centro.append(puntos[i])
	var malla := f["manguera"] as MeshInstance3D
	if centro.size() < 2:
		malla.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: Array[PackedVector3Array] = []
	for i in centro.size():
		var rumbo := (centro[mini(i + 1, centro.size() - 1)] - centro[maxi(i - 1, 0)]).normalized()
		var lado := rumbo.cross(Vector3.UP)
		if lado.length() < 0.01:
			lado = rumbo.cross(Vector3.RIGHT)
		lado = lado.normalized()
		var arriba := lado.cross(rumbo)
		var anillo := PackedVector3Array()
		for k in MANGUERA_LADOS:
			var giro := TAU * k / MANGUERA_LADOS
			anillo.append(centro[i] + (lado * cos(giro) + arriba * sin(giro)) * MANGUERA_RADIO)
		anillos.append(anillo)
	for i in range(1, anillos.size()):
		for k in MANGUERA_LADOS:
			var a := anillos[i - 1][k]
			var b := anillos[i - 1][(k + 1) % MANGUERA_LADOS]
			var c := anillos[i][k]
			var d := anillos[i][(k + 1) % MANGUERA_LADOS]
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
			st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	if _material_manguera == null:
		_material_manguera = StandardMaterial3D.new()
		_material_manguera.albedo_color = MANGUERA_COLOR
		_material_manguera.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_manguera.emission_enabled = true
		_material_manguera.emission = MANGUERA_COLOR
		_material_manguera.emission_energy_multiplier = MANGUERA_BRILLO
	st.set_material(_material_manguera)
	malla.mesh = st.commit()


# Arranca por su ruta (ConductorCarro: acelera, frena en las curvas y nunca gira de golpe) y se
# libera al llegar al final, ya fuera de vista
func _irse(nodo: Node3D, ruta: PackedVector3Array) -> void:
	var conductor := ConductorCarro.new()
	conductor.vel_max = SE_VA_RAPIDO
	add_child(conductor)
	conductor.llego.connect(func() -> void:
		nodo.queue_free()
		conductor.queue_free())
	conductor.iniciar(nodo, ruta)
