class_name CucarrataCalle
extends Node3D
# La cucarrata suelta en el mapa grande (JJ, 2026-11-17; docs/misiones.md "La cucarrata"): de noche
# ronda un lugar abierto fuera de Santa Mugre, el baldio del norponiente (La Florida Marchita, ~220 m
# de la barda; JJ lo escogio de cinco) y las calles de junto (la avenida grande y sus laterales; JJ:
# que si camine en calles), y te la topas con o sin la mision. Nunca entra a la
# fortaleza. Solo existe mientras andas cerca (APARECE): de lejos no hace falta. Te le acercas o le
# disparas y se arma la pelea (JefeCucarrata), con su barra. Si te alejas mucho (o te desmayas y
# amaneces en el refugio) se va y vuelve otra noche con la vida llena. Muerta, Misiones.matar_jefe():
# no vuelve a salir, cumple el paso JEFE_CALLE y abre la cadena de la mafia. Lo pone MisionesMundo en
# map_test.

const ID := "cucarrata"
# Un circulo del minimapa: el baldio y, al oriente, la avenida grande (x ~ -551) con sus calles laterales
const CENTRO := Vector2(-575.0, 100.0)
const RADIO := 85.0
const LIBRE := 10.0            # m sin edificio alrededor de cada punto del pasto por donde camina (mide 7 de largo)
const LIBRE_CALLE := 4.0       # en la calle basta menos: va por en medio, las casas estan a la orilla
const A_LA_CALLE := 0.5        # parte de sus destinos que son calle (el pasto es mas grande: sin esto casi no pisa calle)
const PASO_REVISA := 3.0       # m entre puntos revisados en cada tramo
const APARECE := 260.0         # m del jugador al centro para que salga
const SE_VA := 340.0           # m: tranquila y mas lejos que esto, se va
const OLVIDA := 160.0          # m: en pelea y mas lejos que esto (huiste, te desmayaste), se va
const SALE_LEJOS := 35.0       # m del jugador, como minimo, a donde sale (que no aparezca en tu cara)
const REVISAR_CADA := 0.5
const INTENTOS := 24
const MINIMAPA := "res://textures/map/minimapa.png"
const MINIMAPA_DATOS := "res://resources/map/minimapa.json"
const EDIFICIO := Color8(104, 106, 112)
const EDIFICIO_ORILLA := Color8(14, 14, 12)
const CALLE := Color8(196, 192, 180)
const AVENIDA := Color8(226, 222, 206)
const EDIFICIOS := [EDIFICIO, EDIFICIO_ORILLA]
const CALLES := [CALLE, AVENIDA]

static var instancia: CucarrataCalle
static var _mapa: Image
static var _origen := Vector2.ZERO
static var _m_por_pixel := 1.0

var jefe: JefeCucarrata
var _barra: BarraCucarrata
var _jugador: Node3D
var _reloj := 0.0


func _ready() -> void:
	instancia = self
	_jugador = get_tree().get_first_node_in_group("jugador")
	if not _cargar():
		set_process(false)


func _exit_tree() -> void:
	if instancia == self:
		instancia = null


# Para los mapas: el centro de donde ronda y su radio
func centro_zona() -> Vector3:
	return Vector3(CENTRO.x, 0.0, CENTRO.y)


func radio_zona() -> float:
	return RADIO


# Esta afuera, viva y a la vista (para apuntarle en la mision)
func jefe_suelto() -> bool:
	return is_instance_valid(jefe) and jefe.vida > 0.0


func _process(delta: float) -> void:
	_reloj -= delta
	if _reloj > 0.0 or _jugador == null:
		return
	_reloj = REVISAR_CADA
	var yo := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	if is_instance_valid(jefe):
		var d := yo.distance_to(Vector2(jefe.global_position.x, jefe.global_position.z))
		var peleando := jefe.estado != JefeCucarrata.Estado.DEAMBULA
		if jefe.vida <= 0.0:
			if d > SE_VA:
				_quitar()   # el cadaver, ya lejos
		elif (peleando and d > OLVIDA) or (not peleando and (d > SE_VA or not Misiones.es_noche)):
			_quitar()
		return
	if Misiones.jefe_muerto(ID) or not Misiones.es_noche:
		return
	if yo.distance_to(CENTRO) < APARECE:
		_sacar(yo)


func _sacar(yo: Vector2) -> void:
	var donde := Vector3.INF
	for i in INTENTOS:
		var p := _punto_libre()
		if p != Vector3.INF and Vector2(p.x, p.z).distance_to(yo) > SALE_LEJOS:
			donde = p
			break
	if donde == Vector3.INF:
		return
	jefe = JefeCucarrata.new()
	jefe.deambulando = true
	jefe.pedir_ruta = _ruta_desde
	jefe.position = donde
	jefe.rotation.y = randf() * TAU
	add_child(jefe)
	jefe.desperto.connect(_desperto)
	jefe.murio.connect(_murio)


# Un punto del baldio o de sus calles que se pueda pisar (solo calle con `calle`)
func _punto_libre(calle := false) -> Vector3:
	for i in INTENTOS * (3 if calle else 1):
		var p := CENTRO + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * RADIO
		if (not calle or _es(p, CALLES)) and _libre(p):
			return Vector3(p.x, 0.0, p.y)
	return Vector3.INF


# JefeCucarrata la pide al acabar la anterior: a otro punto del baldio o de sus calles, en linea
# recta si todo el tramo se puede pisar (no atraviesa casas ni las construcciones del parque)
func _ruta_desde(desde: Vector3) -> PackedVector3Array:
	var a := Vector2(desde.x, desde.z)
	var calle := randf() < A_LA_CALLE
	for i in INTENTOS:
		var meta := _punto_libre(calle and i < INTENTOS / 2)
		if meta == Vector3.INF:
			continue
		if _tramo_libre(a, Vector2(meta.x, meta.z)):
			return PackedVector3Array([meta])
	return PackedVector3Array()


func _tramo_libre(a: Vector2, b: Vector2) -> bool:
	var pasos := maxi(1, ceili(a.distance_to(b) / PASO_REVISA))
	for k in range(1, pasos + 1):
		if not _libre(a.lerp(b, float(k) / pasos)):
			return false
	return true


# Se puede pisar: sin edificio del minimapa en el centro ni en dos anillos alrededor, de LIBRE m en
# el pasto o LIBRE_CALLE m si el punto es calle
static func _libre(p: Vector2) -> bool:
	if _edificio(p):
		return false
	var radio := LIBRE_CALLE if _es(p, CALLES) else LIBRE
	for anillo in [radio * 0.5, radio]:
		for k in 12:
			if _edificio(p + Vector2.from_angle(k * TAU / 12.0) * anillo):
				return false
	return true


static func _edificio(p: Vector2) -> bool:
	return _es(p, EDIFICIOS, true)


# El pixel del minimapa en p es de alguno de esos colores (fuera del minimapa: `afuera`)
static func _es(p: Vector2, colores: Array, afuera := false) -> bool:
	var px := int((p.x - _origen.x) / _m_por_pixel)
	var pz := int((p.y - _origen.y) / _m_por_pixel)
	if px < 0 or pz < 0 or px >= _mapa.get_width() or pz >= _mapa.get_height():
		return afuera
	var c := _mapa.get_pixel(px, pz)
	for e: Color in colores:
		if absf(c.r - e.r) + absf(c.g - e.g) + absf(c.b - e.b) < 0.09:
			return true
	return false


static func _cargar() -> bool:
	if _mapa != null:
		return true
	var datos = JSON.parse_string(FileAccess.get_file_as_string(MINIMAPA_DATOS))
	if not datos is Dictionary:
		return false
	_mapa = (load(MINIMAPA) as Texture2D).get_image()
	if _mapa.is_compressed():
		_mapa.decompress()
	_origen = Vector2(datos["x0"], datos["z0"])
	_m_por_pixel = float(datos["metros_por_pixel"])
	return true


func _desperto() -> void:
	if is_instance_valid(_barra):
		return
	_barra = BarraCucarrata.new()
	_barra.jefe = jefe
	add_child(_barra)


func _murio() -> void:
	Misiones.matar_jefe(ID)


# Se va (o se recoge el cadaver) con sus crias y su barra
func _quitar() -> void:
	for hijo in get_children():
		if hijo is CriaCucarrata or hijo == jefe or hijo == _barra:
			hijo.queue_free()
	jefe = null
	_barra = null
