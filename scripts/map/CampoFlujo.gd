class_name CampoFlujo
extends RefCounted

# Por donde caminar hacia una meta sin chocar (docs/especificaciones.md 4.8): una rejilla
# alrededor de la meta, y cada celda sabe hacia que vecina se llega mas pronto. Se llena a
# lo ancho desde la meta, poco a poco y sin trabar: Zombis.gd le da un rato en cada cuadro.
# Lo que estorba se pregunta a la fisica (capa 1), asi que siempre coincide con las paredes
# de verdad. Las barricadas no cuentan (capa 3): el camino llega hasta ellas.

const CELDA := 1.25
const RADIO := 38            # celdas: unos 48 m alrededor de la meta
const LADO := RADIO * 2 + 1
const ALTO_PRUEBA := 1.0     # m del centro de la caja de prueba sobre el piso
const CADA := 0.5            # s entre recalculos
const VECINOS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONALES: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static var _libre := {}      # Vector2i -> bool: compartido, las paredes no se mueven

var listo := false
# Metas que no se mueven (los huecos de la barricada): se llena una vez y otra solo si cambian
var una_vez := false

var _dist := PackedInt32Array()
var _origen := Vector2i.ZERO
var _nuevo := PackedInt32Array()
var _nuevo_origen := Vector2i.ZERO
var _cola: Array[Vector2i] = []
var _cabeza := 0
var _trabajando := false
var _espera := 0.0
var _metas: Array[Vector3] = []
var _consulta: PhysicsShapeQueryParameters3D
var _rayo: PhysicsRayQueryParameters3D
var _pendiente := true


func _init() -> void:
	var caja := BoxShape3D.new()
	# Del tamano de la celda: una barda delgada entre dos centros tambien cuenta
	caja.size = Vector3(CELDA * 0.96, 1.0, CELDA * 0.96)
	_consulta = PhysicsShapeQueryParameters3D.new()
	_consulta.shape = caja
	_consulta.collision_mask = 1
	_rayo = PhysicsRayQueryParameters3D.new()
	_rayo.collision_mask = 1
	_rayo.hit_back_faces = true


# Las paredes si se movieron (la barricada de la defensa se vuelve a armar)
static func olvidar() -> void:
	_libre.clear()


func excluir(cuerpo: RID) -> void:
	_consulta.exclude = [cuerpo]
	_rayo.exclude = [cuerpo]


func metas(nuevas: Array[Vector3]) -> void:
	_metas = nuevas
	_pendiente = true


func avanzar(espacio: PhysicsDirectSpaceState3D, delta: float, presupuesto_us: int) -> void:
	_espera -= delta
	if not _trabajando:
		if _espera > 0.0 or _metas.is_empty() or (una_vez and not _pendiente):
			return
		_empezar()
	var inicio := Time.get_ticks_usec()
	var cuenta := 0
	while _cabeza < _cola.size():
		var celda := _cola[_cabeza]
		_cabeza += 1
		var siguiente := _nuevo[_indice(celda, _nuevo_origen)] + 1
		for paso in VECINOS:
			var otra := celda + paso
			var i := _indice(otra, _nuevo_origen)
			if i >= 0 and _nuevo[i] < 0 and _pasable(espacio, otra):
				_nuevo[i] = siguiente
				_cola.append(otra)
		cuenta += 1
		if cuenta % 8 == 0 and Time.get_ticks_usec() - inicio > presupuesto_us:
			return
	_dist = _nuevo.duplicate()
	_origen = _nuevo_origen
	_trabajando = false
	_espera = CADA
	listo = true


# Hacia donde ir desde `punto`; cero si esta fuera de la rejilla o no hay camino
func direccion(punto: Vector3) -> Vector3:
	if not listo:
		return Vector3.ZERO
	var celda := _celda(punto)
	var i := _indice(celda, _origen)
	if i < 0:
		return Vector3.ZERO
	var mejor := _dist[i] if _dist[i] >= 0 else 2147483647
	var hacia := Vector2i.ZERO
	for paso in VECINOS:
		var j := _indice(celda + paso, _origen)
		if j >= 0 and _dist[j] >= 0 and _dist[j] < mejor:
			mejor = _dist[j]
			hacia = paso
	for paso in DIAGONALES:
		var j := _indice(celda + paso, _origen)
		if j < 0 or _dist[j] < 0 or _dist[j] >= mejor:
			continue
		# Sin cortar esquinas: las dos celdas de al lado tienen que estar libres
		var a := _indice(celda + Vector2i(paso.x, 0), _origen)
		var b := _indice(celda + Vector2i(0, paso.y), _origen)
		if a >= 0 and b >= 0 and _dist[a] >= 0 and _dist[b] >= 0:
			mejor = _dist[j]
			hacia = paso
	if hacia == Vector2i.ZERO:
		return Vector3.ZERO
	return Vector3(hacia.x, 0.0, hacia.y).normalized()


func _empezar() -> void:
	_nuevo_origen = _celda(_metas[0])
	if _nuevo.size() != LADO * LADO:
		_nuevo.resize(LADO * LADO)
	_nuevo.fill(-1)
	_cola.clear()
	_cabeza = 0
	for meta in _metas:
		var celda := _celda(meta)
		var i := _indice(celda, _nuevo_origen)
		if i >= 0 and _nuevo[i] < 0:
			_nuevo[i] = 0
			_cola.append(celda)
	_trabajando = true
	_pendiente = false


func _pasable(espacio: PhysicsDirectSpaceState3D, celda: Vector2i) -> bool:
	var sabido: Variant = _libre.get(celda)
	if sabido != null:
		return sabido
	var centro := Vector3((celda.x + 0.5) * CELDA, ALTO_PRUEBA, (celda.y + 0.5) * CELDA)
	_consulta.transform = Transform3D(Basis.IDENTITY, centro)
	var libre := espacio.intersect_shape(_consulta, 1).is_empty() and not _cruza_pared(espacio, centro)
	_libre[celda] = libre
	return libre


# Las paredes huecas del mapa horneado (ConcavePolygonShape3D de los cuadros de OSM2World)
# la caja no siempre las ve: se le escapaban tramos enteros y los zombis se atoraban contra
# un edificio que el campo daba por libre. Los rayos ven otros tramos; juntos cierran el
# contorno. Cuatro rayos de orilla a orilla de la celda: a lo largo, a lo ancho y diagonales
func _cruza_pared(espacio: PhysicsDirectSpaceState3D, centro: Vector3) -> bool:
	var medio := CELDA * 0.48
	for hacia in [Vector3(medio, 0.0, 0.0), Vector3(0.0, 0.0, medio), Vector3(medio, 0.0, medio), Vector3(medio, 0.0, -medio)]:
		_rayo.from = centro - hacia
		_rayo.to = centro + hacia
		if not espacio.intersect_ray(_rayo).is_empty():
			return true
	return false


func _celda(punto: Vector3) -> Vector2i:
	return Vector2i(floori(punto.x / CELDA), floori(punto.z / CELDA))


func _indice(celda: Vector2i, origen: Vector2i) -> int:
	var x := celda.x - origen.x + RADIO
	var y := celda.y - origen.y + RADIO
	if x < 0 or y < 0 or x >= LADO or y >= LADO:
		return -1
	return y * LADO + x
