class_name Zombie
extends CharacterBody3D

# Un zombi (docs/especificaciones.md 4.8): va hacia su blanco por las calles (CampoFlujo.gd)
# y le pega. Lo arma Zombis.gd y vive en su reserva: despertar() y dormir() en vez de crear
# y borrar. Si hay refugio, su blanco es el jugador solo si lo tiene cerca y del mismo lado
# de la barda; si no, la entrada mas cercana y luego el tinaco (_destino). Con `cazador`
# (las turbas) corre mas y siempre va por el jugador. Si se atora se hace a un lado un rato.
# No hace nada si el jugador esta congelado (volando en el safehouse, desmayado). Con
# `es_jefe` es el garrafonero de la ultima noche (Partida.gd).

signal murio
signal termino

const MODELO := preload("res://models/personajes/zombie_gordo/zombie_gordo.scn")
const VIDA := 30
const VELOCIDAD := Vector2(3.0, 5.0)
const GRAVEDAD := 30.0
const ALCANCE := 1.5        # m a los que empieza a pegar
const ALCANCE_GOLPE := 2.1  # si te alejaste mas antes del golpe, no te da
const DANO := 12
const GOLPE_EN := 0.65      # s desde que empieza el ataque hasta que pega
const ATAQUE_DURA := 1.5
const ATAQUE_VELOCIDAD := 1.8
const HERIDO_DURA := 0.45
# Golpe a tiempo (Player.pelea_a_tiempo): un golpe solo lo aturde HERIDO_DURA s si le pegas en los
# primeros CORTE s de su ataque, cuando gruñe y empieza a levantar los brazos; ya lanzado aguanta y
# te pega, asi que te toca quitarte. Aparte, cualquier golpe cuerpo a cuerpo que no lo mata
# lo aturde con ATURDE_PROB, aunque venga caminando (pedido de Alan). Al jefe nunca.
# No se pinta de rojo (JJ no lo quiso): el aviso es el gruñido y la animacion.
# ATURDIR en false lo apaga todo: aturdidos casi nunca te pegaban (8a prueba de la defensa, JJ)
const CORTE := 0.3
const ATURDE_PROB := 0.2
const ATURDIR := false
# m/s con el golpe de un machete; se escala con el dano. Con 2.5 (unos 0.5 m, pedido de Alan)
# el zombi quedaba fuera del alcance y el combo fallaba el segundo golpe (en las pruebas el
# machete pego 44-57 %): JJ lo quito. Si vuelve, se aplica camine, ataque o este aturdido
const EMPUJON := 0.0
const EMPUJON_FRENA := 6.0  # m/s por segundo
# Lo que se siente al pegarle (Player._golpear). Los tiempos van en reloj real: el juego se
# congela en cada golpe y si no estos tambien se detendrian
const FLASH_MS := 55
const JEFE_ARRASTRE := 0.0  # m que se recorre el jefe con cada golpe; en 0, no se mueve
const COLOR_AGUA := Color(0.2, 0.25, 0.1)
const COLOR_RESTOS := Color(0.12, 0.1, 0.07)
const PECHO := 1.15         # m de alto de donde sale el liquido
const CUERPO_RADIO := 0.22
const SALPICA := 10         # gotas con un machete
const SALPICA_VELOCIDAD := Vector2(3.0, 7.0)
const SALPICA_ABRE := 0.45
const HINCHADO := 1.35      # como queda justo antes de tronar
const REVIENTA := 60
const REVIENTA_VELOCIDAD := Vector2(3.0, 9.0)
const RESTOS := 8
const JEFE_REVIENTA := 2.0  # cuanto mas grande es todo con el jefe
# Efectos de pixel (EfectosPixel): polvo bajo las pisadas del jefe y la marca de los cazadores
const JEFE_PASO := 2.4      # m entre pisada y pisada
const JEFE_PISADA := 0.5    # tamano del polvo
const JEFE_ANUNCIA := 14.0  # m: sale de lado de la camara; el azote es al acercarse, donde se ve
const JEFE_AZOTE := 0.6
const RABIA_ALTO := 2.05    # m sobre los pies, por el tamano
const RABIA_ESCALA := 0.8
# Barra de vida encima (shaders/barra_vida.gdshader), arriba de la marca de cazador. De
# lejos no se dibuja, para que una horda no sea un monton de barras
const BARRA := Vector2(0.8, 0.08)   # m
const BARRA_ALTO := 2.6             # m sobre los pies, por el tamano
const BARRA_HASTA := 35.0           # m de la camara
const BARRA_SHADER := preload("res://shaders/barra_vida.gdshader")
# Sin encimarse: chocan entre ellos. Cerca del blanco, si lo que estorba es otro zombi, espera
# su turno en vez de irse de lado (la fila de atras temblaba)
const CAPA_ZOMBIS := 2
const RADIO := 0.42
const FILA_CERCA := 7.0     # m
const CHARCO_LADO := 3.0
const CHARCO_DURA := 3.0
const CHARCO_ALTO := 0.05
const MUERTO_DURA := 5.0
const SEPARACION := 1.1     # que no se encimen unos con otros
const ATORADO_EN := 0.8     # s casi sin avanzar
const RODEO := 1.2          # s haciendose a un lado
const PESOS := Vector2i(1, 3)
# Defensa del tinaco: cada uno escoge por cual hueco de la barricada de afuera entra
# (Zombis.huecos), para que no lleguen todos por el mas cercano. Los corredores tambien, salvo
# con Zombis.corredores_al_cercano (modos medio y dificil): ahi llegan todos a la vez
const HUECO_CERCANO := 0.4  # probabilidad de ir al mas cercano; si no, a otro al azar
const HUECO_LLEGA := 3.0    # m: ya paso el hueco, de ahi al tinaco
# Si ya esta HUECO_ADENTRO m mas cerca del tinaco que su hueco, se metio por otro (el camino
# mas corto a un hueco lejano cruza por dentro): lo olvida, o se atoraba contra el anillo de adentro
const HUECO_ADENTRO := 2.0
# A tablas y tinaco pegan menos: 2 de dano por segundo, parecido al asedio simulado
# (Refugio.ASEDIO); si no, quedarse a defender salia peor que irse
const DANO_RECINTO := 3
const JEFE_DANO_RECINTO := 8
const PERSIGUE := 12.0     # m: mas cerca deja el refugio y va por el jugador
const PASA_ENTRADA := 2.0   # m adentro del patio a los que apunta al cruzar una entrada
const CAZADOR_VELOCIDAD := 1.4
const DERECHO := 4.0        # m: tan cerca del blanco ya va derecho, sin campo
const LEJOS_AHORRA := 25.0  # m: mas lejos del jugador decide cada TICKS_LEJOS
const TICKS_LEJOS := 3
const TICKS_SEPARAR := 4
# Enjambre (docs/pruebas-enjambre.md): que no caminen en fila india por la
# rejilla de CampoFlujo. Siguen el campo ADELANTE celdas y, si ese punto se ve, van derecho a
# el: cortan las escaleras de la rejilla. Cada uno con su carril, a un lado del camino, que
# se mece, y se va abriendo para rebasar al que lo frena. Giran poco a poco (ACELERA) y su
# velocidad sube y baja, con arrancones, para que unos alcancen a otros y se amontonen.
const ADELANTE := 8          # celdas de CampoFlujo (10 m)
const ADELANTE_CERCA := 4
const TICKS_VISTA := 4       # cada cuantos ticks vuelve a buscar el atajo
const VISTA_ALTO := 0.8      # m sobre los pies de los rayos que buscan el atajo
const ACELERA := 14.0        # m/s por segundo
const CARRIL := 1.5          # m a un lado del camino, como mucho
const VAIVEN := 0.6          # m que se mece de un lado a otro
const VAIVEN_RAPIDEZ := Vector2(0.6, 1.2)   # rad/s
const CARRIL_DESDE := 6.0    # m: mas cerca de su meta se va juntando al camino
const REBASA := 1.5          # carril por segundo que se abre al toparse con otro
const VEL_VAIVEN := 0.15     # la velocidad sube y baja esta fraccion
const VEL_RAPIDEZ := Vector2(0.8, 1.6)      # rad/s
const ARRANQUE := 0.35       # fraccion de mas en un arrancon
const ARRANQUE_DURA := 0.6
const ARRANQUE_CADA := 7.0   # s, en promedio
const DE_FRENTE := 0.7       # coseno: tan de frente contra una pared ya se va de lado
const JEFE_VIDA := 400
const JEFE_DANO := 25
const JEFE_EMPUJA := 1.41   # velocidad del empujon al jugador: el doble de distancia
const JEFE_TAMANO := 1.7
const JEFE_VELOCIDAD := 3.0
const JEFE_COLOR := Color(0.35, 0.5, 0.95)
const JEFE_SHADER := preload("res://shaders/ps1_combined.gdshader")

enum Estado { CAMINA, ATACA, HERIDO, MUERTO }
const GOLPE_NADA := 0
const GOLPE_PEGO := 1
const GOLPE_MATO := 2

static var _material_jefe: ShaderMaterial
static var _material_blanco: StandardMaterial3D
static var _material_barra: ShaderMaterial
static var _material_charco: StandardMaterial3D
static var activos: Array[Zombie] = []   # los despiertos
# El caminar de enjambre (ADELANTE, CARRIL...). Apagado es el de antes, en fila por la
# rejilla: para comparar jugando (0 en el safehouse)
static var enjambre := true
# Dano que les ha hecho el jugador, para medir el balance (scripts/defensa/MonitorDefensa.gd)
static var dano_cuerpo := 0
static var dano_pistola := 0

var estado := Estado.CAMINA
var jugador: Player
var zombis: Zombis
var es_jefe := false
var cazador := false
var despierto := false

var _refugio: Refugio
var _tinaco: TinacoDefensa  # el de la defensa (scripts/defensa/TinacoDefensa.gd), si hay
var _blanco: Node3D        # a quien va a pegarle; null = solo va de paso
var _guia: CampoFlujo       # por donde llegar; null = derecho
var _modelo: Node3D
var _tamano := 1.0
var _mallas: Array[MeshInstance3D] = []
var _flash_hasta := 0       # ms de reloj real
var _reventar_en := 0       # ms de reloj real; 0 = no va a tronar
var _ceniza := false        # cayo al amanecer: se hace ceniza al desaparecer
var _rabia: MeshInstance3D  # la marca de cazador
var _barra: MeshInstance3D
var _paso := 0.0            # m andados desde la ultima pisada del jefe
var _anunciado := false     # el jefe ya azoto el piso al llegar
var _charco: MeshInstance3D
var _charco_desde := -1.0
var _tick := 0
var _empuje := Vector3.ZERO
var _ultimo := Vector3.ZERO
var _dano := DANO
var _alcance := ALCANCE
var _alcance_golpe := ALCANCE_GOLPE
var _vida := VIDA
var _velocidad := 4.0
var _tiempo := 0.0
var _golpeo := false
var _animacion: AnimationPlayer
var _voz: AudioStreamPlayer3D
var _gemido := 0.0
var _atorado := 0.0
var _rodeo := 0.0
var _lado := 1.0
var _retroceso := Vector3.ZERO   # el empujon del ultimo golpe, se va frenando
var _hueco := -1                 # el hueco de la barricada al que va (defensa); -1 = ninguno
var _rumbo := Vector3.ZERO       # la velocidad con la que va; gira hacia _deseado
var _deseado := Vector3.ZERO     # hacia donde quiere ir (unitario)
var _atajo := Vector3.INF        # el punto del campo que se ve, al que va derecho
var _meta_se_ve := true          # la meta de paso (un hueco, una entrada) se ve derecho desde aqui
var _carril := 0.0               # -1..1: de que lado del camino va
var _fase := 0.0
var _vaiven := 1.0
var _vel_rapidez := 1.0
var _vivo := 0.0                 # s desde que desperto
var _arranque := 0.0             # s que le quedan al arrancon
var _vista: PhysicsRayQueryParameters3D


func _ready() -> void:
	var tamano := 1.0
	set_process(false)
	_tick = randi() % TICKS_SEPARAR
	if es_jefe:
		tamano = JEFE_TAMANO
		_dano = JEFE_DANO
		_alcance = ALCANCE * JEFE_TAMANO
		_alcance_golpe = ALCANCE_GOLPE * JEFE_TAMANO
		if _material_jefe == null:
			_material_jefe = ShaderMaterial.new()
			_material_jefe.shader = JEFE_SHADER
			_material_jefe.set_shader_parameter("tint", JEFE_COLOR)
	_gemido = randf_range(1.0, 6.0)
	_lado = 1.0 if randf() < 0.5 else -1.0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = RADIO * tamano
	capsula.height = 1.8 * tamano
	forma.shape = capsula
	forma.position.y = 0.9 * tamano
	add_child(forma)
	_tamano = tamano
	_modelo = MODELO.instantiate() as Node3D
	_modelo.scale = Vector3.ONE * tamano
	add_child(_modelo)
	for malla: MeshInstance3D in _modelo.find_children("*", "MeshInstance3D", true, false):
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if es_jefe:
			malla.material_override = _material_jefe
		# El tubo que el modelo trae flotando
		if String(malla.name).contains("Tube"):
			malla.visible = false
		else:
			_mallas.append(malla)
	_animacion = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for nombre in ["run", "idle"]:
		_animacion.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	_voz = AudioStreamPlayer3D.new()
	_voz.position.y = 1.5
	_voz.max_distance = 25.0
	add_child(_voz)
	_armar_barra()
	if not es_jefe:
		_rabia = EfectosPixel.cuadro_bucle("rabia", RABIA_ESCALA * tamano)
		if _rabia:
			_rabia.position.y = RABIA_ALTO * tamano
			_rabia.visible = false
			add_child(_rabia)


func _exit_tree() -> void:
	activos.erase(self)


func _armar_barra() -> void:
	if _material_barra == null:
		_material_barra = ShaderMaterial.new()
		_material_barra.shader = BARRA_SHADER
	var cuadro := QuadMesh.new()
	cuadro.size = BARRA
	_barra = MeshInstance3D.new()
	_barra.mesh = cuadro
	_barra.material_override = _material_barra
	_barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Gira hacia la camara en el shader: la caja del cuadro plano no alcanzaba
	_barra.custom_aabb = AABB(-Vector3.ONE * BARRA.x / 2.0, Vector3.ONE * BARRA.x)
	_barra.visibility_range_end = BARRA_HASTA
	_barra.position.y = BARRA_ALTO * _tamano
	add_child(_barra)


func _poner_barra() -> void:
	if _barra:
		_barra.visible = estado != Estado.MUERTO
		_barra.set_instance_shader_parameter("vida", clampf(float(_vida) / (JEFE_VIDA if es_jefe else VIDA), 0.0, 1.0))


# Lo que dura poco y va en reloj real: se apaga solo cuando ya no queda nada de eso
func _process(_delta: float) -> void:
	var ahora := Time.get_ticks_msec()
	if _reventar_en > 0 and ahora >= _reventar_en:
		_reventar()
	if _flash_hasta > 0 and ahora >= _flash_hasta and _reventar_en == 0:
		_flash_hasta = 0
		_pintar_blanco(false)
	if _charco_desde >= 0.0:
		var t := (ahora - _charco_desde) / (CHARCO_DURA * 1000.0)
		if t >= 1.0:
			_charco_desde = -1.0
			_charco.visible = false
		else:
			_charco.scale = Vector3.ONE * (1.0 - t * t) * (JEFE_REVIENTA if es_jefe else 1.0)
	if _flash_hasta == 0 and _reventar_en == 0 and _charco_desde < 0.0:
		set_process(false)


func _pintar_blanco(prendido: bool) -> void:
	if _material_blanco == null:
		_material_blanco = StandardMaterial3D.new()
		_material_blanco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_blanco.albedo_color = Color.WHITE
		_material_blanco.disable_fog = true
	for malla in _mallas:
		malla.material_overlay = _material_blanco if prendido else null


# Esta en la ventana en que un golpe le corta el ataque
func _en_corte() -> bool:
	return Player.pelea_a_tiempo and estado == Estado.ATACA and _tiempo < CORTE and not es_jefe


# Como quedo el modelo tras tronar: de vuelta a la reserva tiene que estar entero
func _restaurar() -> void:
	_flash_hasta = 0
	_reventar_en = 0
	_ceniza = false
	_charco_desde = -1.0
	if _charco:
		_charco.visible = false
	if _modelo:
		_modelo.visible = true
		_modelo.scale = Vector3.ONE * _tamano
		_pintar_blanco(false)
	set_process(false)


# Dibuja una vez lo de los golpes para que el primero no trabe compilando (Zombis.gd)
func calentar() -> void:
	_pintar_blanco(true)
	_preparar_charco()
	_charco.visible = true
	var restos := RestosZombi.new()
	add_child(restos)
	restos.calentar()


# Sale de la reserva, como nuevo. `con_prisa`: de turba
func despertar(lugar: Vector3, con_prisa: bool) -> void:
	despierto = true
	cazador = con_prisa
	if _rabia:
		_rabia.visible = con_prisa
	_paso = 0.0
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	add_to_group("zombis")
	activos.append(self)
	estado = Estado.CAMINA
	collision_layer = 2
	# La capa 3 son las barricadas: el jugador pasa, ellos no. Y entre ellos no se enciman
	collision_mask = 1 | EntradaRefugio.CAPA | CAPA_ZOMBIS
	_refugio = get_tree().get_first_node_in_group("refugio") as Refugio
	_tinaco = get_tree().get_first_node_in_group("tinaco_defensa") as TinacoDefensa
	_vida =JEFE_VIDA if es_jefe else VIDA
	if es_jefe:
		_velocidad = JEFE_VELOCIDAD
	else:
		_dano = zombis.dano_jugador if zombis else DANO
		_velocidad = randf_range(VELOCIDAD.x, VELOCIDAD.y) * (CAZADOR_VELOCIDAD if con_prisa else 1.0)
	_tiempo = 0.0
	_golpeo = false
	_atorado = 0.0
	_rodeo = 0.0
	_empuje = Vector3.ZERO
	_ultimo = Vector3.ZERO
	_retroceso = Vector3.ZERO
	_rumbo = Vector3.ZERO
	_deseado = Vector3.ZERO
	_atajo = Vector3.INF
	_meta_se_ve = true
	_carril = randf_range(-1.0, 1.0)
	_fase = randf() * TAU
	_vaiven = randf_range(VAIVEN_RAPIDEZ.x, VAIVEN_RAPIDEZ.y)
	_vel_rapidez = randf_range(VEL_RAPIDEZ.x, VEL_RAPIDEZ.y)
	_vivo = 0.0
	_arranque = 0.0
	velocity = Vector3.ZERO
	global_position = lugar
	_hueco = _escoger_hueco(con_prisa)
	_restaurar()
	_poner_barra()
	_animar("run", _velocidad / 3.5, true)


func dormir() -> void:
	despierto = false
	if _rabia:
		_rabia.visible = false
	remove_from_group("zombis")
	activos.erase(self)
	collision_layer = 0
	collision_mask = 0
	visible = false
	if _animacion:
		_animacion.stop()
	_restaurar()
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	var movimiento := Vector3.ZERO
	_tiempo += delta
	match estado:
		Estado.CAMINA:
			movimiento = _caminar(delta)
		Estado.ATACA:
			_atacar()
		Estado.HERIDO:
			if _tiempo >= HERIDO_DURA:
				_seguir_caminando()
		Estado.MUERTO:
			if _tiempo >= MUERTO_DURA:
				if _ceniza:
					_ceniza = false
					if zombis:
						zombis.efectos.lanzar("amanecer", global_position, Vector3.ZERO, _tamano)
				termino.emit()
			return
	velocity.x = movimiento.x + _retroceso.x
	velocity.z = movimiento.z + _retroceso.z
	_retroceso = _retroceso.move_toward(Vector3.ZERO, EMPUJON_FRENA * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVEDAD * delta
	move_and_slide()
	if es_jefe and estado == Estado.CAMINA and zombis:
		if not _anunciado and is_instance_valid(jugador) and global_position.distance_to(jugador.global_position) <= JEFE_ANUNCIA:
			_anunciado = true
			zombis.efectos.lanzar("jefe", global_position, Vector3.ZERO, JEFE_AZOTE * _tamano)
		_paso += Vector2(velocity.x, velocity.z).length() * delta
		if _paso >= JEFE_PASO:
			_paso = 0.0
			zombis.efectos.lanzar("pisada", global_position, Vector3.ZERO, JEFE_PISADA * _tamano)


func _caminar(delta: float) -> Vector3:
	if not is_instance_valid(jugador) or not _jugador_libre():
		_animar("idle", 1.0)
		_rumbo = Vector3.ZERO
		return Vector3.ZERO
	_vivo += delta
	var velocidad := _velocidad_ahora(delta)
	_animar("run", velocidad / 3.5)
	_gemido -= delta
	if _gemido <= 0.0:
		_gemido = randf_range(4.0, 9.0)
		_sonar("gemido")
	_tick += 1
	# Lejos no se nota: sigue queriendo lo ultimo que decidio
	if _tick % TICKS_LEJOS == 0 or global_position.distance_squared_to(jugador.global_position) <= LEJOS_AHORRA * LEJOS_AHORRA:
		if not _decidir(delta):
			return Vector3.ZERO
	# Gira y acelera poco a poco hacia donde quiere ir; haciendose a un lado, mas rapido
	var acelera := ACELERA * (2.0 if _rodeo > 0.0 or _vivo < 0.2 else 1.0)
	_rumbo = _rumbo.move_toward(_deseado * velocidad, acelera * delta) if enjambre else _deseado * velocidad
	_mirar(_rumbo)
	_ultimo = _rumbo
	return _rumbo


# Escoge _deseado; false si ya empezo a pegar
func _decidir(delta: float) -> bool:
	var destino := _destino()
	var hacia := destino - global_position
	hacia.y = 0.0
	var distancia := hacia.length()
	# Al tinaco se le pega desde su orilla, no desde su centro
	var alcance := _alcance + (_tinaco.radio if _blanco and _blanco == _tinaco else 0.0)
	if _blanco and distancia <= alcance:
		_mirar(hacia)
		_empezar_ataque()
		return false
	# A que punto apunta: la meta si esta cerca o no hay campo; si no, el atajo que se ve
	# o, si no se ve ninguno, un poco adelante por el campo
	var objetivo := destino
	# Cerca de un hueco va derecho solo si lo ve: llegando de lado, por fuera de la barricada,
	# la punta de una pieza queda en medio y se quedaba empujandola
	if not enjambre:
		_meta_se_ve = true
	elif _blanco == null and distancia <= DERECHO and (_tick % TICKS_VISTA == 0 or _meta_se_ve):
		_meta_se_ve = _se_ve(destino)
	elif distancia > DERECHO:
		_meta_se_ve = true
	if _guia and not enjambre:
		_atajo = Vector3.INF
		if distancia > DERECHO and _guia.direccion(global_position) != Vector3.ZERO:
			objetivo = global_position + _guia.direccion(global_position)
	elif _guia and (distancia > DERECHO or not _meta_se_ve):
		if _tick % TICKS_VISTA == 0 or _atajo == Vector3.INF:
			_atajo = _buscar_atajo(distancia)
		if _atajo != Vector3.INF and Vector2(_atajo.x - global_position.x, _atajo.z - global_position.z).length() > CampoFlujo.CELDA * 0.5:
			objetivo = _atajo
		else:
			var por_calle := _guia.direccion_suave(global_position)
			if por_calle != Vector3.ZERO:
				objetivo = global_position + por_calle * CampoFlujo.CELDA * 2.0
	else:
		_atajo = Vector3.INF
	var direccion := objetivo - global_position
	direccion.y = 0.0
	direccion = direccion.normalized() if direccion.length_squared() > 0.0001 else hacia / maxf(distancia, 0.01)
	# Su carril, salvo cerca de la meta (un hueco de la barricada, el tinaco, el jugador)
	if _rodeo <= 0.0 and not es_jefe and enjambre:
		var junto := clampf((distancia - DERECHO) / CARRIL_DESDE, 0.0, 1.0)
		if junto > 0.0 and _atajo == Vector3.INF:
			var lado := Vector3(-direccion.z, 0.0, direccion.x)
			direccion = (direccion + lado * _desfase() * junto / (CampoFlujo.CELDA * 2.0)).normalized()
	# Atorado en una pared: un rato hacia un lado
	if _rodeo > 0.0:
		_rodeo -= delta
		direccion = direccion.rotated(Vector3.UP, _lado * PI * 0.45)
	else:
		var estorba := _zombi_que_estorba()
		if estorba and distancia <= FILA_CERCA:
			_atorado = 0.0
		elif estorba and enjambre:
			# Lejos de la meta, rebasa: se abre hacia el lado contrario del que lo frena
			var lado := Vector3(-direccion.z, 0.0, direccion.x)
			var de_que_lado := signf(lado.dot(global_position - estorba.global_position))
			_carril = clampf(_carril + (de_que_lado if de_que_lado != 0.0 else _lado) * REBASA * delta, -1.0, 1.0)
			_atajo = Vector3.INF
			_atorado = 0.0
		elif get_real_velocity().length() < _velocidad * 0.3 and _tiempo > 0.3:
			_atorado += delta
			if _atorado >= ATORADO_EN:
				_atorado = 0.0
				_rodeo = RODEO
				_lado = -_lado
				_atajo = Vector3.INF
		else:
			_atorado = 0.0
	if enjambre:
		direccion = _rozar_pared(direccion)
	if _tick % TICKS_SEPARAR == 0:
		_empuje = _separarse()
	_deseado = (direccion + _empuje).normalized()
	return true


# El punto del campo ADELANTE (o ADELANTE_CERCA) celdas mas alla que se ve derecho, ya
# corrido a su carril si ahi tambien se ve; INF si ninguno. `distancia`: a su meta
func _buscar_atajo(distancia: float) -> Vector3:
	for pasos in [ADELANTE, ADELANTE_CERCA]:
		var punto := _guia.adelante(global_position, pasos)
		if punto == Vector3.INF:
			return Vector3.INF
		punto.y = global_position.y
		if not es_jefe and _rodeo <= 0.0:
			var hacia := punto - global_position
			hacia.y = 0.0
			var junto := clampf((distancia - DERECHO) / CARRIL_DESDE, 0.0, 1.0)
			if junto > 0.0 and hacia.length_squared() > 0.01:
				var lado := Vector3(-hacia.z, 0.0, hacia.x).normalized()
				var corrido := punto + lado * _desfase() * junto
				if _se_ve(corrido):
					return corrido
		if _se_ve(punto):
			return punto
	return Vector3.INF


# m a un lado del camino: su carril mas lo que se mece
func _desfase() -> float:
	return _carril * CARRIL + sin(_vivo * _vaiven + _fase) * VAIVEN


# Derecho hasta `punto` sin chocar con paredes (capa 1): tres rayos, a cada orilla del cuerpo y
# al centro (entre las dos orillas cabia un tambo)
func _se_ve(punto: Vector3) -> bool:
	if _vista == null:
		_vista = PhysicsRayQueryParameters3D.new()
		_vista.collision_mask = 1
		_vista.hit_back_faces = true
	var hacia := punto - global_position
	hacia.y = 0.0
	if hacia.length_squared() < 0.0001:
		return true
	var lado := Vector3(-hacia.z, 0.0, hacia.x).normalized() * radio()
	var espacio := get_world_3d().direct_space_state
	for orilla in [lado, Vector3.ZERO, -lado]:
		_vista.from = global_position + orilla + Vector3.UP * VISTA_ALTO
		_vista.to = punto + orilla + Vector3.UP * VISTA_ALTO
		if not espacio.intersect_ray(_vista).is_empty():
			return false
	return true


# La velocidad de este momento: sube y baja, y a ratos un arrancon (el jefe, pareja)
func _velocidad_ahora(delta: float) -> float:
	if es_jefe or not enjambre:
		return _velocidad
	_arranque -= delta
	if _arranque <= 0.0 and randf() < delta / ARRANQUE_CADA:
		_arranque = ARRANQUE_DURA
	return _velocidad * (1.0 + VEL_VAIVEN * sin(_vivo * _vel_rapidez + _fase * 1.7)) * (1.0 + ARRANQUE if _arranque > 0.0 else 1.0)


func radio() -> float:
	return RADIO * _tamano


# Salirse de encima de otro: choca con paredes, pero no con los zombis, que lo detendrian
func apartarse(cuanto: Vector3) -> void:
	var mascara := collision_mask
	collision_mask = mascara & ~CAPA_ZOMBIS
	move_and_collide(cuanto)
	collision_mask = mascara


# Si al moverse dio de frente contra una pared (un tambo, un poste, la punta de una pieza),
# se va de lado a lo largo de ella en vez de quedarse empujando hasta contar como atorado:
# de frente, move_and_slide no tiene hacia donde resbalar
func _rozar_pared(direccion: Vector3) -> Vector3:
	for i in get_slide_collision_count():
		var choque := get_slide_collision(i)
		if choque.get_collider() is Zombie:
			continue
		var normal := choque.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.01:
			continue
		normal = normal.normalized()
		if direccion.dot(-normal) < DE_FRENTE:
			continue
		var de_lado := direccion - normal * direccion.dot(normal)
		if de_lado.length_squared() < 0.04:
			de_lado = Vector3(-normal.z, 0.0, normal.x) * _lado
		return (de_lado.normalized() + normal * 0.3).normalized()
	return direccion


# El zombi con el que choco al moverse; null si ninguno
func _zombi_que_estorba() -> Zombie:
	for i in get_slide_collision_count():
		var otro := get_slide_collision(i).get_collider() as Zombie
		if otro:
			return otro
	return null


# A donde camina; deja en _blanco a quien le pegaria al llegar y en _guia su camino
func _destino() -> Vector3:
	_guia = zombis.campo_jugador if zombis else null
	# Defensa del tinaco: van por el tinaco, y por el jugador solo si lo tienen cerca y mas
	# que al tinaco (pararse junto al tinaco no lo protege). Ya roto, por el jugador
	var al_jugador := global_position.distance_to(jugador.global_position)
	if is_instance_valid(_tinaco) and _tinaco.vida > 0 and (al_jugador > _persigue() or al_jugador > global_position.distance_to(_tinaco.global_position) - _tinaco.radio):
		# Primero a su hueco, de paso; ya pasandolo, al tinaco
		if _hueco >= 0 and _hueco < zombis.huecos.size():
			var hueco: Vector3 = zombis.huecos[_hueco]
			var al_tinaco := global_position.distance_to(_tinaco.global_position)
			if Vector2(hueco.x - global_position.x, hueco.z - global_position.z).length() > HUECO_LLEGA \
					and al_tinaco > hueco.distance_to(_tinaco.global_position) - HUECO_ADENTRO:
				_blanco = null
				_guia = zombis.campos_huecos[_hueco]
				return hueco
			_hueco = -1
		_blanco = _tinaco
		_guia = zombis.campo_tinaco if zombis else null
		return _tinaco.global_position
	if _refugio == null:
		_blanco = jugador
		return jugador.global_position
	var yo_adentro := _refugio.adentro(global_position)
	var el_adentro := _refugio.adentro(jugador.global_position)
	# Del otro lado de la barda no lo puede alcanzar: a la entrada
	var a_la_entrada := el_adentro and not yo_adentro
	if not a_la_entrada and (cazador or (yo_adentro == el_adentro and global_position.distance_to(jugador.global_position) <= _persigue())):
		_blanco = jugador
		return jugador.global_position
	if yo_adentro:
		_blanco = _refugio
		_guia = null
		return _refugio.global_position
	_guia = zombis.campo_refugio if zombis else null
	var entrada := _refugio.entrada_cercana(global_position)
	if not entrada.abierta():
		_blanco = entrada
		return entrada.global_position
	_blanco = null
	return entrada.global_position + (_refugio.global_position - entrada.global_position).normalized() * PASA_ENTRADA


# Por cual hueco de la barricada entra (defensa del tinaco); -1 si no hay barricada
func _escoger_hueco(corredor: bool) -> int:
	if zombis == null or es_jefe or zombis.huecos.is_empty():
		return -1
	var cercano := 0
	for i in zombis.huecos.size():
		if global_position.distance_squared_to(zombis.huecos[i]) < global_position.distance_squared_to(zombis.huecos[cercano]):
			cercano = i
	if (corredor and zombis.corredores_al_cercano) or zombis.huecos.size() == 1 or randf() < HUECO_CERCANO:
		return cercano
	var otro := randi_range(0, zombis.huecos.size() - 2)
	return otro + 1 if otro >= cercano else otro


# A cuantos m deja el refugio por el jugador: Pies de gato (Tazos.gd) lo acorta, menos al jefe
func _persigue() -> float:
	var tazos := get_node_or_null("/root/Tazos")
	return PERSIGUE * (tazos.factor_persigue() if tazos and not es_jefe else 1.0)


func _separarse() -> Vector3:
	var empuje := Vector3.ZERO
	for otro in activos:
		if otro == self:
			continue
		var lejos := global_position - otro.global_position
		lejos.y = 0.0
		var d := lejos.length()
		if d > 0.01 and d < SEPARACION:
			empuje += lejos / d * (1.0 - d / SEPARACION)
	return empuje


func _empezar_ataque() -> void:
	estado = Estado.ATACA
	_rumbo = Vector3.ZERO
	_tiempo = 0.0
	_golpeo = false
	_animar(["attack1", "attack2"].pick_random(), ATAQUE_VELOCIDAD, true)
	# La señal de que va a pegar: un gruñido, mientras se le puede cortar
	if _en_corte():
		_sonar("gemido")


func _atacar() -> void:
	if not _golpeo and _tiempo >= GOLPE_EN:
		_golpeo = true
		if not is_instance_valid(jugador) or not _jugador_libre():
			pass
		elif _blanco == jugador:
			var hacia := jugador.global_position - global_position
			hacia.y = 0.0
			if hacia.length() <= _alcance_golpe and absf(jugador.global_position.y - global_position.y) <= _alcance_golpe:
				jugador.recibir_dano(_dano, global_position, JEFE_EMPUJA if es_jefe else 1.0)
		elif is_instance_valid(_blanco) and _blanco.has_method("recibir_golpe"):
			_blanco.recibir_golpe(JEFE_DANO_RECINTO if es_jefe else DANO_RECINTO)
	if _tiempo >= ATAQUE_DURA:
		_seguir_caminando()


func _seguir_caminando() -> void:
	estado = Estado.CAMINA
	_rumbo = Vector3.ZERO
	_tiempo = 0.0


# El golpe del jugador (Player._golpear). `fuerza`: 1 con un machete, menos a puño limpio.
# `truena_en`: ms que dura la congelada si este golpe lo mata, para tronar justo al soltar.
# `cuerpo_a_cuerpo`: false con la pistola, que ni empuja ni aturde.
# Regresa GOLPE_NADA, GOLPE_PEGO o GOLPE_MATO.
func recibir_golpe(dano: int, desde: Vector3, fuerza := 1.0, truena_en := 80, cuerpo_a_cuerpo := true) -> int:
	if estado == Estado.MUERTO:
		return GOLPE_NADA
	if cuerpo_a_cuerpo:
		dano_cuerpo += mini(dano, _vida)
	else:
		dano_pistola += mini(dano, _vida)
	_vida -= dano
	_poner_barra()
	var atras := global_position - desde
	atras.y = 0.0
	atras = atras.normalized()
	_flash_hasta = Time.get_ticks_msec() + FLASH_MS
	_pintar_blanco(true)
	set_process(true)
	_salpicar(atras, fuerza)
	if zombis:
		zombis.efectos.lanzar("impacto", global_position, atras, _tamano, "mata" if _vida <= 0 else "")
	if _vida <= 0:
		velocity = Vector3.ZERO
		_morir(true, truena_en)
		return GOLPE_MATO
	# Al jefe no se le interrumpe con cada machetazo: solo lo recorre un poco
	if es_jefe:
		move_and_collide(atras * JEFE_ARRASTRE * fuerza)
		return GOLPE_PEGO
	if cuerpo_a_cuerpo:
		_retroceso = atras * EMPUJON * fuerza
	if not ATURDIR or (not _en_corte() and not (cuerpo_a_cuerpo and randf() < ATURDE_PROB)):
		return GOLPE_PEGO
	estado = Estado.HERIDO
	_tiempo = 0.0
	_animar("hit", 2.0, true)
	return GOLPE_PEGO


# `truena_en`: lo mato el jugador, trae unos pesos y revienta como globo de agua sucia. Sin
# el, se cae (al amanecer)
func _morir(pagado: bool, truena_en := 0) -> void:
	estado = Estado.MUERTO
	_poner_barra()
	if _rabia:
		_rabia.visible = false
	_tiempo = 0.0
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	if truena_en > 0:
		# Se hincha en blanco mientras el juego esta congelado, y al soltar truena
		_reventar_en = Time.get_ticks_msec() + truena_en
		_modelo.scale = Vector3(HINCHADO, HINCHADO * 0.92, HINCHADO) * _tamano
		_animacion.pause()
		set_process(true)
	else:
		_animar("die", 1.0, true)
		_sonar("morir_zombi")
		_ceniza = true
	murio.emit()
	if pagado:
		var cartera := get_node_or_null("/root/Cartera")
		if cartera:
			# Bolsillos (Tazos.gd): unos pesos de mas
			var tazos := get_node_or_null("/root/Tazos")
			cartera.pesos += randi_range(PESOS.x, PESOS.y) + (tazos.pesos_extra() if tazos else 0)


func caer_al_amanecer() -> void:
	if estado != Estado.MUERTO:
		_morir(false)


# Agua sucia hacia donde iba el golpe, saliendo de adentro del cuerpo
func _salpicar(hacia: Vector3, fuerza: float) -> void:
	if zombis == null:
		return
	zombis.liquido.salpicar(global_position + Vector3.UP * PECHO * _tamano, CUERPO_RADIO * _tamano, global_position.y,
		(hacia + Vector3.UP * 0.3).normalized(), roundi(SALPICA * clampf(fuerza, 0.5, 1.5)), COLOR_AGUA, SALPICA_VELOCIDAD, SALPICA_ABRE)


func _reventar() -> void:
	_reventar_en = 0
	_flash_hasta = 0
	_pintar_blanco(false)
	_modelo.visible = false
	var grande := JEFE_REVIENTA if es_jefe else 1.0
	if zombis:
		var centro := global_position + Vector3.UP * PECHO * _tamano
		zombis.liquido.reventar(centro, CUERPO_RADIO * 1.4 * _tamano, global_position.y, roundi(REVIENTA * grande), COLOR_AGUA, REVIENTA_VELOCIDAD)
		zombis.liquido.reventar(centro, CUERPO_RADIO * 1.4 * _tamano, global_position.y, roundi(RESTOS * grande), COLOR_RESTOS, REVIENTA_VELOCIDAD * 0.7)
	_preparar_charco()
	_charco.visible = true
	_charco.scale = Vector3.ONE * grande
	_charco_desde = Time.get_ticks_msec()
	_sonar("reventar")
	if zombis:
		zombis.dejar_restos(global_position, _tamano)
		zombis.efectos.lanzar("muerte", global_position, Vector3.ZERO, grande * _tamano)


func _preparar_charco() -> void:
	if _charco:
		return
	if _material_charco == null:
		var mancha := GradientTexture2D.new()
		mancha.width = 32
		mancha.height = 32
		mancha.fill = GradientTexture2D.FILL_RADIAL
		mancha.fill_from = Vector2(0.5, 0.5)
		mancha.fill_to = Vector2(0.5, 0.0)
		var borde := Gradient.new()
		borde.set_color(0, Color(1, 1, 1, 0.9))
		borde.set_color(1, Color(1, 1, 1, 0.0))
		borde.add_point(0.75, Color(1, 1, 1, 0.8))
		mancha.gradient = borde
		_material_charco = StandardMaterial3D.new()
		_material_charco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_charco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_charco.albedo_color = COLOR_AGUA.darkened(0.45)
		_material_charco.albedo_texture = mancha
		_material_charco.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * CHARCO_LADO
	_charco = MeshInstance3D.new()
	_charco.mesh = plano
	_charco.material_override = _material_charco
	_charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charco.position.y = CHARCO_ALTO
	_charco.visible = false
	add_child(_charco)


func _jugador_libre() -> bool:
	return jugador.can_process() and jugador.is_physics_processing()


func _mirar(direccion: Vector3) -> void:
	if direccion.length_squared() > 0.001:
		rotation.y = atan2(direccion.x, direccion.z)


func _animar(nombre: String, velocidad: float, reiniciar := false) -> void:
	if _animacion == null:
		return
	_animacion.speed_scale = velocidad
	if reiniciar or _animacion.current_animation != nombre:
		_animacion.stop()
		_animacion.play(nombre)


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()
