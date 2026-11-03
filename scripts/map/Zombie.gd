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
const EMPUJON := 9.0        # m/s con el golpe de un machete; se escala con el dano
# Lo que se siente al pegarle (Player._golpear). Los tiempos van en reloj real: el juego se
# congela en cada golpe y si no estos tambien se detendrian
const FLASH_MS := 55
const JEFE_ARRASTRE := 0.3  # m: al jefe solo se le mueve un poco
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
static var _material_charco: StandardMaterial3D
static var activos: Array[Zombie] = []   # los despiertos

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
	if not es_jefe:
		_rabia = EfectosPixel.cuadro_bucle("rabia", RABIA_ESCALA * tamano)
		if _rabia:
			_rabia.position.y = RABIA_ALTO * tamano
			_rabia.visible = false
			add_child(_rabia)


func _exit_tree() -> void:
	activos.erase(self)


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
		_velocidad = randf_range(VELOCIDAD.x, VELOCIDAD.y) * (CAZADOR_VELOCIDAD if con_prisa else 1.0)
	_tiempo = 0.0
	_golpeo = false
	_atorado = 0.0
	_rodeo = 0.0
	_empuje = Vector3.ZERO
	_ultimo = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = lugar
	_restaurar()
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
	if estado != Estado.HERIDO:
		velocity.x = movimiento.x
		velocity.z = movimiento.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, EMPUJON * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, EMPUJON * 3.0 * delta)
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
		return Vector3.ZERO
	_animar("run", _velocidad / 3.5)
	_gemido -= delta
	if _gemido <= 0.0:
		_gemido = randf_range(4.0, 9.0)
		_sonar("gemido")
	_tick += 1
	# Lejos no se nota: sigue con lo ultimo que decidio
	if _tick % TICKS_LEJOS != 0 and global_position.distance_squared_to(jugador.global_position) > LEJOS_AHORRA * LEJOS_AHORRA:
		return _ultimo
	var hacia := _destino() - global_position
	hacia.y = 0.0
	var distancia := hacia.length()
	# Al tinaco se le pega desde su orilla, no desde su centro
	var alcance := _alcance + (_tinaco.radio if _blanco and _blanco == _tinaco else 0.0)
	if _blanco and distancia <= alcance:
		_mirar(hacia)
		_empezar_ataque()
		return Vector3.ZERO
	var direccion := hacia / maxf(distancia, 0.01)
	if _guia and distancia > DERECHO:
		var por_calle := _guia.direccion(global_position)
		if por_calle != Vector3.ZERO:
			direccion = por_calle
	# Atorado en una pared: un rato hacia un lado
	if _rodeo > 0.0:
		_rodeo -= delta
		direccion = direccion.rotated(Vector3.UP, _lado * PI * 0.45)
	elif distancia <= FILA_CERCA and _lo_detiene_un_zombi():
		_atorado = 0.0
	elif get_real_velocity().length() < _velocidad * 0.3 and _tiempo > 0.3:
		_atorado += delta
		if _atorado >= ATORADO_EN:
			_atorado = 0.0
			_rodeo = RODEO
			_lado = -_lado
	else:
		_atorado = 0.0
	if _tick % TICKS_SEPARAR == 0:
		_empuje = _separarse()
	direccion = (direccion + _empuje).normalized()
	_mirar(direccion)
	_ultimo = direccion * _velocidad
	return _ultimo


func radio() -> float:
	return RADIO * _tamano


# Salirse de encima de otro: choca con paredes, pero no con los zombis, que lo detendrian
func apartarse(cuanto: Vector3) -> void:
	var mascara := collision_mask
	collision_mask = mascara & ~CAPA_ZOMBIS
	move_and_collide(cuanto)
	collision_mask = mascara


func _lo_detiene_un_zombi() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is Zombie:
			return true
	return false


# A donde camina; deja en _blanco a quien le pegaria al llegar y en _guia su camino
func _destino() -> Vector3:
	_guia = zombis.campo_jugador if zombis else null
	# Defensa del tinaco: van por el tinaco, y por el jugador solo si lo tienen cerca y mas
	# que al tinaco (pararse junto al tinaco no lo protege). Ya roto, por el jugador
	var al_jugador := global_position.distance_to(jugador.global_position)
	if is_instance_valid(_tinaco) and _tinaco.vida > 0 and (al_jugador > _persigue() or al_jugador > global_position.distance_to(_tinaco.global_position) - _tinaco.radio):
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
	_tiempo = 0.0
	_golpeo = false
	_animar(["attack1", "attack2"].pick_random(), ATAQUE_VELOCIDAD, true)


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
	_tiempo = 0.0


# El golpe del jugador (Player._golpear). `fuerza`: 1 con un machete, menos a puño limpio.
# `truena_en`: ms que dura la congelada si este golpe lo mata, para tronar justo al soltar.
# Regresa GOLPE_NADA, GOLPE_PEGO o GOLPE_MATO.
func recibir_golpe(dano: int, desde: Vector3, fuerza := 1.0, truena_en := 80) -> int:
	if estado == Estado.MUERTO:
		return GOLPE_NADA
	_vida -= dano
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
	velocity = atras * EMPUJON * fuerza
	estado = Estado.HERIDO
	_tiempo = 0.0
	_animar("hit", 2.0, true)
	return GOLPE_PEGO


# `truena_en`: lo mato el jugador, trae unos pesos y revienta como globo de agua sucia. Sin
# el, se cae (al amanecer)
func _morir(pagado: bool, truena_en := 0) -> void:
	estado = Estado.MUERTO
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
