class_name CucarrataCalle
extends Node3D
# La cucarrata suelta en el mapa grande (JJ, 2026-11-17; docs/misiones.md "La cucarrata"): de noche
# vive en una bodega de La Gigantera, la #34 de bodegas_mapa.json, frente a la reja poniente de Santa
# Mugre (JJ, 2026-11-18: la pelea es adentro, en el piso de concreto; antes rondaba un baldio de pasto
# donde no se veian las ratas y atravesaba las casas). MapBodegas la deja vacia (es_guarida) y
# JefeCucarrata no sale de sus muros (encerrar). Te la topas con o sin la mision, aunque no hayas
# hecho la guardia de la reja. Los zombis de la noche entran por los vanos abiertos. Solo existe
# mientras andas cerca (APARECE). Entras o le disparas y se arma la pelea, con su barra. Si te alejas
# mucho (o te desmayas y amaneces en el refugio) se va y vuelve otra noche con la vida llena. Muerta,
# Misiones.matar_jefe(): no vuelve a salir, cumple el paso JEFE_CALLE y abre la cadena de la mafia.
# Despierta al verte adentro (adentro) o si le disparas. Lo pone MisionesMundo en map_test.

const ID := "cucarrata"
# La bodega: el centro de su frente en bodegas_mapa.json (como BodegaGela.CENTRO)
const BODEGA := Vector2(-438.47, 643.39)
const BODEGAS := "res://resources/map/bodegas_mapa.json"
const PUERTA := -0.5           # m del frente hacia afuera que cuentan como adentro: negativo, ya pasaste el vano
const MARGEN := 4.0            # m de su centro a los muros: mide ~7 de largo y gira en su lugar
const CABEZA := 3.5            # m del origen a la cabeza parada (APUNTA): lo que le queda bajo el techo
const ARCO_FLECHA := 0.1       # el de MapBodegas: el arco del techo sube eso por metro de ancho
const APARECE := 260.0         # m del jugador a la bodega para que salga
const SE_VA := 340.0           # m: tranquila y mas lejos que esto, se va
const OLVIDA := 160.0          # m: en pelea y mas lejos que esto (huiste, te desmayaste), se va
const SALE_LEJOS := 20.0       # m del jugador, como minimo, a donde sale (que no aparezca en tu cara)
const REVISAR_CADA := 0.5
const INTENTOS := 24

static var instancia: CucarrataCalle
# La bodega: de su frente hacia adentro es -Z, de lado a lado X (como en MapBodegas)
static var _lote := Transform3D.IDENTITY
static var _ancho := 0.0
static var _fondo := 0.0
static var _alto := 0.0

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
	return _lote * Vector3(0.0, 0.0, -_fondo / 2.0)


func radio_zona() -> float:
	return minf(_ancho, _fondo) / 2.0


# Un punto en el eje de la bodega a tantos metros de su frente (+ afuera, - adentro), en el piso
static func frente(metros: float) -> Vector3:
	return en_bodega(Vector3(0.0, 0.0, metros))


# Un punto del marco de la bodega (x de lado a lado, +x al norte; z hacia afuera del frente) en el mundo
static func en_bodega(local: Vector3) -> Vector3:
	_cargar()
	return _lote * local


# MapBodegas no le pone racks ni cajas (se llama desde su hilo: solo constantes)
static func es_guarida(bodega: Dictionary) -> bool:
	return Vector2(bodega["x"], bodega["z"]).distance_to(BODEGA) < 1.0


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
	var centro := centro_zona()
	if yo.distance_to(Vector2(centro.x, centro.z)) < APARECE:
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
	jefe.encerrar = encerrar
	jefe.te_ve = adentro
	jefe.position = donde
	jefe.rotation.y = randf() * TAU
	add_child(jefe)
	jefe.desperto.connect(_desperto)
	jefe.murio.connect(_murio)


# Un punto del piso de la bodega, lejos de los muros
func _punto_libre() -> Vector3:
	var x := randf_range(-_ancho / 2.0 + MARGEN, _ancho / 2.0 - MARGEN)
	var z := randf_range(-_fondo + MARGEN, -MARGEN)
	return _lote * Vector3(x, 0.0, z)


# JefeCucarrata la pide al acabar la anterior: otro punto de la bodega, en linea recta (adentro no
# hay nada: MapBodegas la deja vacia)
func _ruta_desde(_desde: Vector3) -> PackedVector3Array:
	return PackedVector3Array([_punto_libre()])


# JefeCucarrata se pasa por aqui cada cuadro: no atraviesa los muros (MARGEN) ni el techo de arco
# (la cabeza parada, CABEZA, cabe bajo el techo de ese lado)
static func encerrar(p: Vector3) -> Vector3:
	var l := _lote.affine_inverse() * p
	l.x = clampf(l.x, -_ancho / 2.0 + MARGEN, _ancho / 2.0 - MARGEN)
	l.z = clampf(l.z, -_fondo + MARGEN, -MARGEN)
	var t := 2.0 * l.x / _ancho
	var techo := _alto + ARCO_FLECHA * _ancho * (1.0 - t * t)
	l.y = minf(l.y, techo - CABEZA)
	return _lote * l


# Estas dentro de la bodega (medio metro pasando los vanos): solo asi te ve la cucarrata, no a traves del muro
# (en el callejon, pegado al frente, aun no)
static func adentro(p: Vector3) -> bool:
	var l := _lote.affine_inverse() * p
	return absf(l.x) < _ancho / 2.0 and l.z > -_fondo and l.z < PUERTA


static func _cargar() -> bool:
	if _ancho > 0.0:
		return true
	var datos = JSON.parse_string(FileAccess.get_file_as_string(BODEGAS))
	if not datos is Dictionary:
		return false
	for b: Dictionary in datos["bodegas"]:
		if es_guarida(b):
			_lote = Transform3D(Basis(Vector3.UP, b["rotacion_y"]), Vector3(b["x"], 0.0, b["z"]))
			_ancho = b["ancho"]
			_fondo = b["fondo"]
			_alto = b["alto"]
			return true
	push_warning("CucarrataCalle: no esta su bodega en " + BODEGAS)
	return false


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
