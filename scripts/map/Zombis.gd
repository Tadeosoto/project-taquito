class_name Zombis
extends Node3D

# Los zombis de noche (docs/especificaciones.md 4.8): el Director.gd decide cuando salen y
# aqui se ponen, siempre fuera de la camara y en la calle. Los sueltos dependen de lo
# destruido que este (Deterioro.zona) y de la noche; las turbas salen juntas y corren hacia
# el jugador. Se guardan armados en una reserva: armar uno trababa el juego al aparecer.
# Al amanecer se caen. En coop los decide el servidor.

signal turba_cerca

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const ENTRE_ZOMBIS := 3.0     # s entre uno suelto y otro
const ANILLO := Vector2(24.0, 36.0)   # m del jugador donde aparecen
const LEJOS := 70.0           # mas lejos se quitan: ya perdieron al jugador
const MAX_BASE := 2
const MAX_POR_ZONA := 8
const MAX_POR_NOCHE := 1
const MAX_SUELTOS := 12
const MAX_TOTAL := 30         # con las turbas; el jefe no cuenta
const INTENTOS := 8
const ALTO_CALLE := 0.6       # arriba de esto es una azotea o una barda
const CALENTAR_CUADROS := 3
const MARGEN_REFUGIO := 2.0   # m alrededor de la barda donde no aparecen
const TURBA_ABRE := 0.7       # rad de ancho de donde sale una turba
const CAMPO_US := 1500        # tiempo por cuadro para calcular cada campo de flujo
const MOVIENDOSE := 1.0       # m/s

@export var jugador_path: NodePath
@export var ciclo_path: NodePath

var noches := 0
var director := Director.new()
var campo_jugador := CampoFlujo.new()
var campo_refugio := CampoFlujo.new()

var _jugador: Player
var _ciclo: Ciclo
var _salud: Node
var _vida_antes := 0
var _espera := 0.0
var _calentando: Node3D
var _calentar := 0
var _libres: Array[Zombie] = []
var _armados := 0
var _turba_pendiente := 0
var _turba_angulo := 0.0
var _refugio_puesto := false


func _ready() -> void:
	_jugador = get_node(jugador_path) as Player
	_ciclo = get_node(ciclo_path) as Ciclo
	_salud = get_node("/root/Salud")
	_vida_antes = _salud.vida
	_salud.cambio.connect(_cambio_vida)
	_ciclo.anochecio.connect(func() -> void:
		noches += 1
		director.reiniciar()
		_turba_pendiente = 0)
	_ciclo.amanecio.connect(_amanecer)
	campo_jugador.excluir(_jugador.get_rid())
	campo_refugio.excluir(_jugador.get_rid())
	# Se dibuja uno diminuto al cargar: si no, su shader con esqueleto se compilaba en el
	# cuadro del primer zombi de la primera noche
	_calentando = Zombie.new()
	_calentando.scale = Vector3.ONE * 0.002
	add_child(_calentando)
	# Despues de add_child: al estar listo, el nodo vuelve a prender su _physics_process
	_calentando.set_physics_process(false)
	_calentando.collision_layer = 0
	_calentando.calentar()
	_calentar = CALENTAR_CUADROS


func _process(delta: float) -> void:
	if _calentar > 0:
		var camara := get_viewport().get_camera_3d()
		if camara:
			_calentando.global_transform = camara.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * 0.002), Vector3(0.0, 0.0, -2.0))
		_calentar -= 1
		if _calentar == 0:
			_calentando.queue_free()
	_armar_reserva()
	_campos(delta)


# Uno por cuadro, dentro del presupuesto del mapa, hasta tener todos los que caben
func _armar_reserva() -> void:
	if _armados >= MAX_TOTAL or not CargaCuadro.hay():
		return
	var inicio := Time.get_ticks_usec()
	_libres.append(_armar())
	CargaCuadro.gastar(inicio)


func _armar() -> Zombie:
	var zombi := Zombie.new()
	zombi.jugador = _jugador
	zombi.zombis = self
	add_child(zombi)
	zombi.dormir()
	zombi.termino.connect(_devolver.bind(zombi))
	zombi.murio.connect(_al_morir.bind(zombi))
	_armados += 1
	return zombi


# De noche, y un poco antes para tenerlos listos
func _campos(delta: float) -> void:
	if not _ciclo.es_noche() and _ciclo.valor() <= 0.0:
		return
	var espacio := get_world_3d().direct_space_state
	var metas: Array[Vector3] = [_jugador.global_position]
	campo_jugador.metas(metas)
	campo_jugador.avanzar(espacio, delta, CAMPO_US)
	var refugio := get_tree().get_first_node_in_group("refugio") as Refugio
	if refugio == null:
		return
	if not _refugio_puesto:
		_refugio_puesto = true
		var entradas: Array[Vector3] = []
		for entrada in refugio.entradas:
			entradas.append(entrada.global_position)
		campo_refugio.metas(entradas)
	# Solo hace falta si el jugador anda por ahi: lejos, el ataque es simulado
	if refugio.global_position.distance_to(_jugador.global_position) <= LEJOS * 1.5:
		campo_refugio.avanzar(espacio, delta, CAMPO_US)


func _physics_process(delta: float) -> void:
	_quitar_lejanos()
	if not _ciclo.es_noche() or not _jugador.can_process() or not _jugador.is_physics_processing():
		return
	var turba := director.avanzar(delta, _atacado(), _jugador.velocity.length() > MOVIENDOSE, noches)
	if turba > 0:
		aparecer_turba(turba)
	if _turba_pendiente > 0:
		_sacar_de_turba()
	if not director.puede_sueltos():
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = ENTRE_ZOMBIS
	if _sueltos() < maximo() and _vivos() < MAX_TOTAL:
		_aparecer()


# Cuantos sueltos puede haber aqui y esta noche
func maximo() -> int:
	var p := _jugador.global_position
	return mini(MAX_BASE + roundi(Deterioro.zona(p.x, p.z) * MAX_POR_ZONA) + (noches - 1) * MAX_POR_NOCHE, MAX_SUELTOS)


# Una turba: `cuantos` que salen del mismo lado, de a poco, y corren hacia el jugador
func aparecer_turba(cuantos: int) -> void:
	_turba_pendiente = mini(cuantos, MAX_TOTAL - _vivos())
	_turba_angulo = randf() * TAU
	if _turba_pendiente > 0:
		turba_cerca.emit()


func _sacar_de_turba() -> void:
	var lugar := _lugar_libre(_jugador.global_position, _turba_angulo)
	if lugar == Vector3.INF:
		# Ese lado no se puede (o se ve): a probar por otro
		_turba_angulo = randf() * TAU
		return
	_turba_pendiente -= 1
	sacar(lugar, true)


func _vivos() -> int:
	var cuantos := 0
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO and not z.es_jefe:
			cuantos += 1
	return cuantos


func _sueltos() -> int:
	var cuantos := 0
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO and not z.es_jefe and not z.cazador:
			cuantos += 1
	return cuantos


# Alguien lo esta atacando: mientras, la intensidad no baja
func _atacado() -> bool:
	for z in Zombie.activos:
		if z.estado == Zombie.Estado.ATACA or z.global_position.distance_squared_to(_jugador.global_position) < Director.ATACADO_A * Director.ATACADO_A:
			return true
	return false


func _cambio_vida() -> void:
	var vida: int = _salud.vida
	if vida < _vida_antes:
		director.recibio_dano(_vida_antes - vida)
		if vida <= 0:
			director.desmayo()
	_vida_antes = vida


func _al_morir(zombi: Zombie) -> void:
	if zombi.global_position.distance_to(_jugador.global_position) <= Director.MUERTE_CERCA:
		director.mato_cerca()


func _aparecer() -> void:
	var lugar := _lugar_libre(_jugador.global_position)
	if lugar != Vector3.INF:
		sacar(lugar, false)


# Uno de la reserva, despierto en `lugar`
func sacar(lugar: Vector3, cazador: bool) -> Zombie:
	var zombi: Zombie = _libres.pop_back() if not _libres.is_empty() else _armar()
	zombi.despertar(lugar, cazador)
	return zombi


# El garrafonero (Partida.gd), alrededor de `centro`; null si no encontro lugar este intento
func aparecer_jefe(centro: Vector3) -> Zombie:
	var lugar := _lugar_libre(centro)
	if lugar == Vector3.INF:
		return null
	var jefe := Zombie.new()
	jefe.es_jefe = true
	jefe.jugador = _jugador
	jefe.zombis = self
	add_child(jefe)
	jefe.termino.connect(jefe.queue_free)
	jefe.despertar(lugar, false)
	return jefe


# Un punto en la calle, a un lado o atras de la camara; INF si no encontro. Con `angulo`,
# de ese lado del centro (las turbas)
func _lugar_libre(centro: Vector3, angulo := INF) -> Vector3:
	var camara := get_viewport().get_camera_3d()
	var espacio := get_world_3d().direct_space_state
	var refugio := get_tree().get_first_node_in_group("refugio") as Refugio
	for i in INTENTOS:
		var giro := randf() * TAU if angulo == INF else angulo + randf_range(-TURBA_ABRE, TURBA_ABRE)
		var radio := randf_range(ANILLO.x, ANILLO.y)
		var punto := centro + Vector3(cos(giro) * radio, 0.0, sin(giro) * radio)
		if camara and not camara.is_position_behind(punto) and camara.is_position_in_frustum(punto + Vector3.UP):
			continue
		if refugio and refugio.adentro(punto, MARGEN_REFUGIO):
			continue
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, 30.0, punto.z), Vector3(punto.x, -2.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and pego.position.y < ALTO_CALLE:
			return pego.position + Vector3.UP * 0.05
	return Vector3.INF


func _quitar_lejanos() -> void:
	for z: Zombie in Zombie.activos.duplicate():
		if not z.es_jefe and z.global_position.distance_to(_jugador.global_position) > LEJOS:
			_devolver(z)


func _amanecer() -> void:
	_turba_pendiente = 0
	for z: Zombie in Zombie.activos.duplicate():
		z.caer_al_amanecer()


func _devolver(zombi: Zombie) -> void:
	if zombi.es_jefe:
		zombi.queue_free()
		return
	if not zombi.despierto:
		return
	zombi.dormir()
	_libres.append(zombi)


# Teclas de prueba y reinicios: se van todos
func limpiar() -> void:
	_turba_pendiente = 0
	for z: Zombie in Zombie.activos.duplicate():
		_devolver(z)


# Al desmayarse el jugador: que no despierte con uno encima, pero los demas siguen
func limpiar_cerca(centro: Vector3, radio: float) -> void:
	for z: Zombie in Zombie.activos.duplicate():
		if not z.es_jefe and z.global_position.distance_to(centro) <= radio:
			_devolver(z)
