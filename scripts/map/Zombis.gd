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
const MAX_RESTOS := 16
const SEPARADO := 1.1         # m entre centros al aparecer: chocan entre ellos
const NO_ENCIMAR_PASADAS := 2
const RESTOS_ALTO := 0.03     # m sobre el piso, y arriba del charco
const RESTOS_LANZA := 1.2     # m que caen los restos hacia donde iba el golpe

@export var jugador_path: NodePath
@export var ciclo_path: NodePath
# La defensa del tinaco los saca ella (scripts/defensa/Hordas.gd): sin sueltos ni turbas
@export var espontaneos := true
# Las turbas del Director (cazadores que salen juntos); sin ellas solo hay sueltos, segun el
# deterioro. Con `ritmo` no cuenta: las turbas las pone el ritmo
@export var turbas := true
# Como salen de noche (RitmoNoche.gd): ratos tranquilos, uno o dos sueltos de vez en cuando
# y una o dos turbas por noche. Sin el, el Director (sueltos cada 3 s hasta el tope y turbas
# cada 1.5-3 min). map_test y el safehouse usan resources/zombis/noche_mapa.tres
@export var ritmo: RitmoNoche
# Mas lejos del jugador se quitan; en la defensa salen al otro lado de la barricada
@export var lejos := LEJOS
# Cuantos puede haber a la vez (y cuantos se arman en la reserva); la defensa trae mas
@export var max_total := MAX_TOTAL
# Lo que le quita cada golpe al jugador (Zombie.DANO); la defensa le baja. El jefe no cambia
@export var dano_jugador := Zombie.DANO
# Mandos de diseno de los enemigos (vida, dano base, velocidad, cadencia, alcance). Si no se
# asigna, se carga resources/zombis/balance_enemigos.tres; cambiarlo afecta a los dos tests y
# al mapa, y Registro guarda una copia efectiva en cada noche.
@export var config: Resource
# Los tests de economia/mecanicas no pagan pesos por zombi (todo se compra con la paga)
@export var paga_muertes := true
# Defensa del tinaco: cuantos van por el tinaco a la vez; los de mas salen por el jugador
# (Zombie.por_jugador, Hordas.gd). 0 = sin tope
@export var cupo_tinaco := 0

var noches := 0
var director := Director.new()
var campo_jugador := CampoFlujo.new()
var campo_refugio := CampoFlujo.new()
var campo_tinaco := CampoFlujo.new()   # al tinaco de la defensa, si hay
# Los huecos de la barricada de afuera (defensa) y un campo hacia cada uno (Zombie._hueco)
var huecos: Array[Vector3] = []
var campos_huecos: Array[CampoFlujo] = []
var corredores_al_cercano := false   # los corredores entran por el hueco mas cercano (Hordas, modo)
var liquido: Liquido
var efectos: EfectosPixel

var _jugador: Player
var _ciclo: Ciclo
var _salud: Node
var _vida_antes := 0
var _espera := 0.0
var _calentando: Array[Zombie] = []   # uno de cada skin
var _calentar := 0
var _libres: Array[Zombie] = []
var _armados := 0
var _turba_pendiente := 0
var _turba_angulo := 0.0
var _refugio_puesto := false
var _tinaco_puesto := false
var _restos: Array = []
var _turba_abre := TURBA_ABRE
var _turba_cazadores := true
# El ritmo de esta noche: s desde que anochecio, cuando sale el siguiente grupito y a que
# horas las turbas que faltan
var _noche_t := 0.0
var _siguiente_grupo := 0.0
var _horas_turbas: Array[float] = []
var _cayendo := false
# Para ajustar jugando: lo de la noche que va (Partida los dice al amanecer)
var salieron_noche := 0
var muertos_noche := 0
var turbas_noche := 0


func _ready() -> void:
	if config == null:
		config = load("res://resources/zombis/balance_enemigos.tres")
	# Pistola busca aqui al Director (la mira se abre con la intensidad)
	add_to_group("zombis_mando")
	_jugador = get_node(jugador_path) as Player
	_ciclo = get_node(ciclo_path) as Ciclo
	process_physics_priority = 10
	liquido = Liquido.new()
	add_child(liquido)
	efectos = EfectosPixel.new()
	add_child(efectos)
	_salud = get_node("/root/Salud")
	_vida_antes = _salud.vida
	_salud.cambio.connect(_cambio_vida)
	_ciclo.anochecio.connect(_anochecio)
	_ciclo.amanecio.connect(_amanecer)
	campo_jugador.excluir(_jugador.get_rid())
	campo_refugio.excluir(_jugador.get_rid())
	campo_tinaco.excluir(_jugador.get_rid())
	# Se dibuja uno diminuto al cargar: si no, su shader con esqueleto se compilaba en el
	# cuadro del primer zombi de la primera noche
	# Uno de cada skin, que cada uno trae su textura
	for i in Zombie.SKINS.size():
		var zombi := Zombie.new()
		zombi.skin = i
		zombi.scale = Vector3.ONE * 0.002
		add_child(zombi)
		# Despues de add_child: al estar listo, el nodo vuelve a prender su _physics_process
		zombi.set_physics_process(false)
		zombi.collision_layer = 0
		zombi.calentar()
		_calentando.append(zombi)
	_calentar = CALENTAR_CUADROS


func _anochecio() -> void:
	noches += 1
	director.reiniciar()
	_turba_pendiente = 0
	salieron_noche = 0
	muertos_noche = 0
	turbas_noche = 0
	_noche_t = 0.0
	if ritmo:
		_siguiente_grupo = ritmo.calma_inicial
		_horas_turbas = ritmo.horas_turbas(_ciclo.noche_duracion)
		_turba_abre = ritmo.turba_abre
		_turba_cazadores = ritmo.turba_cazadores
		print("Noche %d: turbas a los %s s" % [noches, _horas_turbas.map(func(h: float) -> int: return roundi(h))])


func _process(delta: float) -> void:
	if _calentar > 0:
		var camara := get_viewport().get_camera_3d()
		if camara:
			for zombi in _calentando:
				zombi.global_transform = camara.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * 0.002), Vector3(0.0, 0.0, -2.0))
		_calentar -= 1
		if _calentar == 0:
			for zombi in _calentando:
				zombi.queue_free()
			_calentando.clear()
	_armar_reserva()
	_campos(delta)


# Uno por cuadro, dentro del presupuesto del mapa, hasta tener todos los que caben
func _armar_reserva() -> void:
	if _armados >= max_total or not CargaCuadro.hay():
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
	_campo_tinaco(espacio, delta)
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


# Metas en un anillo alrededor del tinaco: el tinaco mismo no es pasable
func _campo_tinaco(espacio: PhysicsDirectSpaceState3D, delta: float) -> void:
	var tinaco := get_tree().get_first_node_in_group("tinaco_defensa") as TinacoDefensa
	if tinaco == null:
		return
	if not _tinaco_puesto:
		_tinaco_puesto = true
		var metas: Array[Vector3] = []
		var radio := tinaco.radio + CampoFlujo.CELDA
		for i in 16:
			metas.append(tinaco.global_position + Vector3(cos(i * TAU / 16.0), 0.0, sin(i * TAU / 16.0)) * radio)
		campo_tinaco.metas(metas)
	campo_tinaco.avanzar(espacio, delta, CAMPO_US)
	for campo in campos_huecos:
		campo.avanzar(espacio, delta, CAMPO_US)


# La barricada (otra vez) armada: un campo hacia cada hueco de afuera
func usar_huecos(lugares: Array[Vector3]) -> void:
	huecos = lugares
	campos_huecos.clear()
	for lugar in lugares:
		var campo := CampoFlujo.new()
		campo.una_vez = true
		campo.excluir(_jugador.get_rid())
		var metas: Array[Vector3] = [lugar]
		campo.metas(metas)
		campos_huecos.append(campo)


# Cambio lo que estorba (otra barricada): los campos se vuelven a llenar desde cero
func olvidar_paredes() -> void:
	CampoFlujo.olvidar()
	_tinaco_puesto = false


# Dos que caminan uno hacia el otro en el mismo tick si se llegan a encimar un poco, aunque
# choquen: el que quede encimado se separa aqui, sin atravesar paredes. Corre despues de que
# todos se movieron (process_physics_priority) y dos veces, por las filas apretadas.
func _no_encimar() -> void:
	for pasada in NO_ENCIMAR_PASADAS:
		_separar_encimados()


func _separar_encimados() -> void:
	var lista := Zombie.activos
	for i in lista.size():
		var a := lista[i]
		if a.estado == Zombie.Estado.MUERTO:
			continue
		for j in range(i + 1, lista.size()):
			var b := lista[j]
			if b.estado == Zombie.Estado.MUERTO:
				continue
			var entre := a.global_position - b.global_position
			entre.y = 0.0
			var minimo: float = (a.radio() + b.radio())
			var d := entre.length_squared()
			if d >= minimo * minimo:
				continue
			d = sqrt(d)
			var hacia := entre / d if d > 0.001 else Vector3.RIGHT
			var falta := (minimo - d) * 0.5
			a.apartarse(hacia * falta)
			b.apartarse(-hacia * falta)


func _physics_process(delta: float) -> void:
	_no_encimar()
	_quitar_lejanos()
	if not espontaneos:
		return
	if not _ciclo.es_noche() or not _jugador.can_process() or not _jugador.is_physics_processing():
		return
	var turba := director.avanzar(delta, _atacado(), _jugador.velocity.length() > MOVIENDOSE, noches)
	if turba > 0 and turbas and ritmo == null:
		aparecer_turba(turba)
	if _turba_pendiente > 0:
		_sacar_de_turba()
	if ritmo:
		_seguir_ritmo(delta)
		return
	if not director.puede_sueltos():
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = ENTRE_ZOMBIS
	if _sueltos() < maximo() and _vivos() < max_total:
		_aparecer()


# RitmoNoche: las turbas a su hora y los grupitos de sueltos cada tanto
func _seguir_ritmo(delta: float) -> void:
	_noche_t += delta
	if not _horas_turbas.is_empty() and _noche_t >= _horas_turbas[0] and _turba_pendiente == 0:
		_horas_turbas.pop_front()
		turbas_noche += 1
		aparecer_turba(randi_range(ritmo.turba.x, ritmo.turba.y))
	if _noche_t < _siguiente_grupo:
		return
	if ritmo.respetar_director and not director.puede_sueltos():
		return
	var p := _jugador.global_position
	var deterioro := Deterioro.relativo(p.x, p.z)
	var caben := mini(ritmo.vivos_max(deterioro) - _sueltos(), max_total - _vivos())
	if caben <= 0:
		_siguiente_grupo = _noche_t + ENTRE_ZOMBIS
		return
	# Del mismo lado, juntitos
	var lado := randf() * TAU
	var salio := 0
	for i in mini(randi_range(ritmo.grupo.x, ritmo.grupo.y), caben):
		var lugar := _lugar_libre(p, lado)
		if lugar != Vector3.INF:
			sacar(lugar, false)
			salio += 1
	# Ese lado se veia o no habia calle: otro intento pronto
	_siguiente_grupo = _noche_t + (ritmo.cada(deterioro, noches) if salio > 0 else 1.0)


# Cuantos sueltos puede haber aqui y esta noche
func maximo() -> int:
	var p := _jugador.global_position
	return mini(MAX_BASE + roundi(Deterioro.zona(p.x, p.z) * MAX_POR_ZONA) + (noches - 1) * MAX_POR_NOCHE, MAX_SUELTOS)


# Una turba: `cuantos` que salen del mismo lado, de a poco, y corren hacia el jugador
func aparecer_turba(cuantos: int) -> void:
	_turba_pendiente = mini(cuantos, max_total - _vivos())
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
	# La turba ya viene por ti, sean cazadores o no
	sacar(lugar, _turba_cazadores).alertar(false)


func vivos() -> int:
	return _vivos()


# Los vivos que van por el tinaco (no los emboscados ni los que se pasaron del cupo)
func al_tinaco() -> int:
	var cuantos := 0
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO and not z.es_jefe and not z.emboscada and not z.por_jugador:
			cuantos += 1
	return cuantos


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
	if not _cayendo and not zombi.es_jefe:
		muertos_noche += 1
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
	salieron_noche += 1
	return zombi


# El garrafonero (Partida.gd), alrededor de `centro`; null si no encontro lugar este intento
func aparecer_jefe(centro: Vector3) -> Zombie:
	var lugar := _lugar_libre(centro, INF, SEPARADO * Zombie.JEFE_TAMANO)
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
# Si un zombi parado en `punto` saldria en pantalla (Hordas.gd tambien lo usa)
static func a_la_vista(camara: Camera3D, punto: Vector3) -> bool:
	return camara != null and not camara.is_position_behind(punto) and camara.is_position_in_frustum(punto + Vector3.UP)


func _lugar_libre(centro: Vector3, angulo := INF, separado := SEPARADO) -> Vector3:
	var camara := get_viewport().get_camera_3d()
	var espacio := get_world_3d().direct_space_state
	var refugio := get_tree().get_first_node_in_group("refugio") as Refugio
	# Pies de gato (Tazos.gd) aleja a los sueltos; las turbas (con angulo) son cazadores y no
	var tazos := get_node_or_null("/root/Tazos")
	var extra: float = tazos.extra_aparicion() if tazos and angulo == INF else 0.0
	for i in INTENTOS:
		var giro := randf() * TAU if angulo == INF else angulo + randf_range(-_turba_abre, _turba_abre)
		var radio := randf_range(ANILLO.x, ANILLO.y) + extra
		var punto := centro + Vector3(cos(giro) * radio, 0.0, sin(giro) * radio)
		if a_la_vista(camara, punto):
			continue
		if refugio and refugio.adentro(punto, MARGEN_REFUGIO):
			continue
		if _encima_de_otro(punto, separado):
			continue
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, 30.0, punto.z), Vector3(punto.x, -2.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and pego.position.y < ALTO_CALLE:
			return pego.position + Vector3.UP * 0.05
	return Vector3.INF


func _encima_de_otro(punto: Vector3, separado: float) -> bool:
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO and Vector2(z.global_position.x - punto.x, z.global_position.z - punto.z).length_squared() < separado * separado:
			return true
	return false


func _quitar_lejanos() -> void:
	for z: Zombie in Zombie.activos.duplicate():
		if not z.es_jefe and z.global_position.distance_to(_jugador.global_position) > lejos:
			_devolver(z)


func _amanecer() -> void:
	_turba_pendiente = 0
	_cayendo = true
	for z: Zombie in Zombie.activos.duplicate():
		z.caer_al_amanecer()
	_cayendo = false
	if noches > 0:
		print("Noche %d: salieron %d, mataste %d, turbas %d" % [noches, salieron_noche, muertos_noche, turbas_noche])


func _devolver(zombi: Zombie) -> void:
	if zombi.es_jefe:
		zombi.queue_free()
		return
	if not zombi.despierto:
		return
	zombi.dormir()
	_libres.append(zombi)


# Pellejo y luego huesos. Con tope, para que una noche larga no vaya costando cuadros
# `hacia`: a donde iba el golpe que lo mato; los restos caen RESTOS_LANZA m para alla
func dejar_restos(donde: Vector3, tamano: float, hacia := Vector3.ZERO) -> void:
	# Sin tipo: uno ya borrado no se puede convertir a Node3D
	_restos = _restos.filter(func(r) -> bool: return is_instance_valid(r))
	while _restos.size() >= MAX_RESTOS:
		_restos.pop_front().queue_free()
	var restos := RestosZombi.new()
	restos.tamano(tamano)
	add_child(restos)
	donde += hacia * RESTOS_LANZA
	restos.global_position = Vector3(donde.x, donde.y + RESTOS_ALTO, donde.z)
	_restos.append(restos)


# Teclas de prueba y reinicios: se van todos
func limpiar() -> void:
	_turba_pendiente = 0
	for restos in _restos:
		if is_instance_valid(restos):
			restos.queue_free()
	_restos.clear()
	liquido.limpiar()
	efectos.limpiar()
	for z: Zombie in Zombie.activos.duplicate():
		_devolver(z)


# Al desmayarse el jugador: que no despierte con uno encima, pero los demas siguen
func limpiar_cerca(centro: Vector3, radio: float) -> void:
	for z: Zombie in Zombie.activos.duplicate():
		if not z.es_jefe and z.global_position.distance_to(centro) <= radio:
			_devolver(z)
