class_name Zombie
extends CharacterBody3D

# Un zombi (docs/especificaciones.md 4.8): camina derecho hacia su blanco y le pega. Lo
# crea Zombis.gd. Si hay refugio, su blanco es el jugador solo si lo tiene cerca y del
# mismo lado de la barda; si no, la entrada mas cercana y luego el tinaco (_destino). Si se
# atora en una pared se hace a un lado un rato: no hay rutas, eso queda para las hordas.
# No hace nada si el jugador esta congelado (volando en el safehouse, desmayado). Con
# `es_jefe` es el garrafonero de la ultima noche (Partida.gd).

signal murio

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
const EMPUJON := 5.0
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
const JEFE_VIDA := 400
const JEFE_DANO := 25
const JEFE_TAMANO := 1.7
const JEFE_VELOCIDAD := 3.0
const JEFE_COLOR := Color(0.35, 0.5, 0.95)
const JEFE_SHADER := preload("res://shaders/ps1_combined.gdshader")

enum Estado { CAMINA, ATACA, HERIDO, MUERTO }

static var _material_jefe: ShaderMaterial

var estado := Estado.CAMINA
var jugador: Player
var es_jefe := false

var _refugio: Refugio
var _blanco: Node3D         # a quien va a pegarle; null = solo va de paso
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
	add_to_group("zombis")
	collision_layer = 2
	# La capa 3 son las barricadas: el jugador pasa, ellos no
	collision_mask = 1 | EntradaRefugio.CAPA
	_refugio = get_tree().get_first_node_in_group("refugio") as Refugio
	_velocidad = randf_range(VELOCIDAD.x, VELOCIDAD.y)
	var tamano := 1.0
	if es_jefe:
		tamano = JEFE_TAMANO
		_vida = JEFE_VIDA
		_dano = JEFE_DANO
		_velocidad = JEFE_VELOCIDAD
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
	capsula.radius = 0.42 * tamano
	capsula.height = 1.8 * tamano
	forma.shape = capsula
	forma.position.y = 0.9 * tamano
	add_child(forma)
	var modelo := MODELO.instantiate() as Node3D
	modelo.scale = Vector3.ONE * tamano
	add_child(modelo)
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if es_jefe:
			malla.material_override = _material_jefe
		# El tubo que el modelo trae flotando
		if String(malla.name).contains("Tube"):
			malla.visible = false
	_animacion = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for nombre in ["run", "idle"]:
		_animacion.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	_animar("run", _velocidad / 3.5)
	_voz = AudioStreamPlayer3D.new()
	_voz.position.y = 1.5
	_voz.max_distance = 25.0
	add_child(_voz)


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
				queue_free()
			return
	if estado != Estado.HERIDO:
		velocity.x = movimiento.x
		velocity.z = movimiento.z
	else:
		velocity.x = move_toward(velocity.x, 0.0, EMPUJON * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, EMPUJON * 3.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVEDAD * delta
	move_and_slide()


func _caminar(delta: float) -> Vector3:
	if not is_instance_valid(jugador) or not _jugador_libre():
		_animar("idle", 1.0)
		return Vector3.ZERO
	_animar("run", _velocidad / 3.5)
	_gemido -= delta
	if _gemido <= 0.0:
		_gemido = randf_range(4.0, 9.0)
		_sonar("gemido")
	var hacia := _destino() - global_position
	hacia.y = 0.0
	var distancia := hacia.length()
	if _blanco and distancia <= _alcance:
		_mirar(hacia)
		_empezar_ataque()
		return Vector3.ZERO
	var direccion := hacia / maxf(distancia, 0.01)
	# Atorado en una pared: un rato hacia un lado
	if _rodeo > 0.0:
		_rodeo -= delta
		direccion = direccion.rotated(Vector3.UP, _lado * PI * 0.45)
	elif get_real_velocity().length() < _velocidad * 0.3 and _tiempo > 0.3:
		_atorado += delta
		if _atorado >= ATORADO_EN:
			_atorado = 0.0
			_rodeo = RODEO
			_lado = -_lado
	else:
		_atorado = 0.0
	direccion = (direccion + _separarse()).normalized()
	_mirar(direccion)
	return direccion * _velocidad


# A donde camina, y deja en _blanco a quien le pegaria al llegar
func _destino() -> Vector3:
	var yo_adentro := _refugio != null and _refugio.adentro(global_position)
	if _refugio == null or (yo_adentro == _refugio.adentro(jugador.global_position) and global_position.distance_to(jugador.global_position) <= PERSIGUE):
		_blanco = jugador
		return jugador.global_position
	if yo_adentro:
		_blanco = _refugio
		return _refugio.global_position
	var entrada := _refugio.entrada_cercana(global_position)
	if not entrada.abierta():
		_blanco = entrada
		return entrada.global_position
	_blanco = null
	return entrada.global_position + (_refugio.global_position - entrada.global_position).normalized() * PASA_ENTRADA


func _separarse() -> Vector3:
	var empuje := Vector3.ZERO
	for otro: Node3D in get_tree().get_nodes_in_group("zombis"):
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
				jugador.recibir_dano(_dano)
		elif is_instance_valid(_blanco) and _blanco.has_method("recibir_golpe"):
			_blanco.recibir_golpe(JEFE_DANO_RECINTO if es_jefe else DANO_RECINTO)
	if _tiempo >= ATAQUE_DURA:
		_seguir_caminando()


func _seguir_caminando() -> void:
	estado = Estado.CAMINA
	_tiempo = 0.0


# El machete del jugador (Player._golpear)
func recibir_golpe(dano: int, desde: Vector3) -> void:
	if estado == Estado.MUERTO:
		return
	_vida -= dano
	var atras := global_position - desde
	atras.y = 0.0
	velocity = atras.normalized() * EMPUJON
	_sangre()
	if _vida <= 0:
		_morir(true)
		return
	_sonar("golpe")
	# Al jefe no se le interrumpe con cada machetazo
	if es_jefe:
		velocity = Vector3.ZERO
		return
	estado = Estado.HERIDO
	_tiempo = 0.0
	_animar("hit", 2.0, true)


# `pagado`: lo mato el jugador, trae unos pesos (al amanecer se caen solos)
func _morir(pagado: bool) -> void:
	estado = Estado.MUERTO
	_tiempo = 0.0
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_animar("die", 1.0, true)
	_sonar("morir_zombi")
	murio.emit()
	if pagado:
		var cartera := get_node_or_null("/root/Cartera")
		if cartera:
			cartera.pesos += randi_range(PESOS.x, PESOS.y)


func caer_al_amanecer() -> void:
	if estado != Estado.MUERTO:
		_morir(false)


func _sangre() -> void:
	var chispas := Cohetes.chispas(14, 0.5, Color(0.55, 0.02, 0.02), 0.14)
	chispas.initial_velocity_min = 1.5
	chispas.initial_velocity_max = 3.5
	chispas.gravity = Vector3(0.0, -9.0, 0.0)
	chispas.position.y = 1.2
	add_child(chispas)
	get_tree().create_timer(1.0).timeout.connect(chispas.queue_free)


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
