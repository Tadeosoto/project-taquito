class_name Panzon
extends CharacterBody3D

# El Panzon (docs/prompts/blender_panzon.md): el cholo de la cuadra al que el agua mala hincho.
# Propuesta de AG para el GORDO; falta que JJ la confirme, asi que es su propio script y no toca
# Zombie.Tipo.GORDO. Va por el jugador, o por el tinaco de la defensa si te alejas de el:
#   - De lejos arranca una losa del piso y te la avienta (Rip_Rock, Throw; RocaPanzon.gd).
#   - A media distancia ruge (el aviso) y embiste en linea recta: si te alcanza te agarra, te
#     azota, te pisa tres veces y te avienta (Player.atrapar); si choca con una pared o la
#     barricada se queda atarantado y recibe el doble.
#   - Pegado a ti, martillazo con los dos punos.
# Con tinaco (la defensa) las losas van siempre al tinaco y a ti solo te toca lo de cerca
# (embestida y martillazo) si te le acercas a PELEA_JUGADOR m. Su vida va en una barra sobre
# la cabeza, como la de los zombis pero mas grande y sin limite de distancia.
# Es de piedra gris con grietas de Serenol azul que respiran como la Madre del Carcamo
# (shaders/panzon_serenol.gdshader, _vestir) y sangra ese mismo azul (golpes y reventon al morir).
# Esta en el grupo "zombis" (machete y pistola) y "panzon"; `estado` 3
# es MUERTO como en Zombie. No nombra autoloads (tools/ carga a Zombis).

signal murio
signal cambio(vida: int, maxima: int)

enum Estado { ACECHA, RUGE, CARGA, MUERTO, ARRANCA, AVIENTA, AGARRA, AZOTA, PISA, LANZA, FALLA, ATARANTADO, MARTILLO, HERIDO }

const MODELO := preload("res://models/personajes/panzon/panzon.glb")
const ROCA := preload("res://models/personajes/panzon/roca.glb")
const RocaPanzon := preload("res://scripts/map/RocaPanzon.gd")
const BUCLES := ["Idle", "Walk", "Run_Charge"]
# Tamano (JJ, 2026-11-17: se veia muy chico): el modelo mide 2.3 m a 1x. Escala el modelo, la
# capsula, los alcances, la barra y de donde sale la sangre; las velocidades no (camina igual de
# lento, con pasos mas largos)
const ESCALA := 1.5
const SHADER_PIEL := preload("res://shaders/panzon_serenol.gdshader")
# Ojos hundidos (_hundir_ojos): los discos de las cuencas entran y el anillo de la frente sale,
# para que la ceja de piedra les haga sombra. La cabeza no tiene hueco: meterlos mas los esconde
const HUNDE_OJOS := 0.004      # m
const SALE_CEJA := 0.045       # m
# Clips con la boca abierta: la garganta brilla (instance uniform boca_abierta)
const BOCA_ABIERTA := ["Roar", "Run_Charge", "Ground_Slam", "Slam", "Throw", "Throw_Player"]
# Su sangre es Serenol, el azul de sus grietas (#2EC4FF) y uno marino
const SANGRE := Color(0.18, 0.77, 1.0)
const SANGRE_OSCURA := Color(0.04, 0.25, 0.45)
const PECHO := 1.3 * ESCALA    # m: de donde sale la sangre
const CUERPO_RADIO := 0.5 * ESCALA
const SALPICA := 12            # gotas por golpe
const SALPICA_VELOCIDAD := Vector2(3.0, 7.0)
const REVIENTA := 90           # gotas al morir
const REVIENTA_VELOCIDAD := Vector2(3.0, 10.0)
const VIDA := 400
const GRAVEDAD := 30.0
const CAMINA := 1.6            # m/s
const PASO_CAMINA := 1.0 * ESCALA   # m/s de Walk a 1x (con pasos mas largos)
const EMBISTE := 8.0           # m/s
const PASO_CORRE := 5.1 * ESCALA    # m/s de Run_Charge a 1x
const EMBISTE_MAX := 2.5       # s de carga como mucho
const ALCANZA := 1.6 * ESCALA  # m al jugador para agarrarlo
const MARTILLO_DESDE := 2.2 * ESCALA   # m: mas cerca, martillazo
const MARTILLO_RADIO := 2.5 * ESCALA
const EMBESTIDA := Vector2(6.0, 14.0)   # m entre los que embiste
const ROCA_DESDE := 14.0       # m: mas lejos, avienta losa
const EMBESTIDA_CADA := 7.0
const ROCA_CADA := 6.0
const MARTILLO_CADA := 2.5
const PELEA_JUGADOR := 12.0    # m: con tinaco, mas cerca va por ti (embestida, martillazo); mas lejos, por el tinaco
const TINACO_ROCA := Vector2(9.0, 20.0) # m del tinaco donde le avienta losas
const DANO_MARTILLO := 20
const DANO_AZOTON := 10
const DANO_PISOTON := 8
const DANO_LANZA := 6
const LANZA_EMPUJA := 4.0      # x el empujon normal: unos 6 m
const DANO_TINACO_MARTILLO := 30
const PISOTONES := 3
const ATARANTADO_DURA := 3.0
const ATARANTADO_MULT := 2
const DELANTE := 1.0 * ESCALA  # m: la victima tirada con el pecho a esta distancia (los clips)
const PESOS := Vector2i(15, 30)
const BOTINES := 3
# Al morir revienta y el cuerpo desaparece en ese momento (JJ, 2026-11-17); el nodo vive estos s
# mas, invisible, para que no se corte el sonido del reventon
const MUERTO_DURA := 3.0
const LEJOS := 90.0
const ATORADO_SEG := 2.0       # s caminando sin avanzar para brincar a un hueco libre (_revisar_atorado)
const BARRICADA_HASTA := 24.0  # m del tinaco: mas cerca puede ser la barricada (Barricada.ANILLOS llega a ~21)
const DERECHO_HASTA := 4.0     # m al blanco: mas cerca va derecho; mas lejos, por el campo de flujo
const CAPA_ZOMBIS := 2
# La barra de vida sobre la cabeza (shaders/barra_vida.gdshader, la de Zombie). El modelo mide 2.3 m x ESCALA
const BARRA := Vector2(1.7, 0.14)  # m
const BARRA_ALTO := 2.3 * ESCALA + 0.45   # m sobre los pies
const BARRA_SHADER := preload("res://shaders/barra_vida.gdshader")
const MEZCLA := 0.15
const DECIDE_CADA := 0.3
# Tiempos de los clips (cuadro / 30)
const RUGE_DURA := 36.0 / 30.0
const ARRANCA_DURA := 36.0 / 30.0
const ARRANCA_SALE := 10.0 / 30.0
const AVIENTA_DURA := 24.0 / 30.0
const AVIENTA_SUELTA := 14.0 / 30.0
const AGARRA_DURA := 12.0 / 30.0
const AZOTA_DURA := 20.0 / 30.0
const AZOTA_PEGA := 12.0 / 30.0
const PISA_DURA := 18.0 / 30.0
const PISA_PEGA := 10.0 / 30.0
const LANZA_DURA := 26.0 / 30.0
const LANZA_SUELTA := 16.0 / 30.0
const FALLA_DURA := 30.0 / 30.0
const BONK_DURA := 48.0 / 30.0
const MARTILLO_DURA := 30.0 / 30.0
const MARTILLO_PEGA := 16.0 / 30.0
const HERIDO_DURA := 16.0 / 30.0

var jugador: Player
var zombis: Node
var estado := Estado.ACECHA

var _vida := VIDA
var _t := 0.0
var _decide := 0.0
var _modelo: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _roca_mano: Node3D
var _tras_rugido := ""
var _rumbo := Vector3.ZERO
var _espera_embestida := 2.0
var _espera_roca := 1.0
var _espera_martillo := 0.0
var _pego := false
var _pisadas := 0
var _soltada := false
var _atorado := 0.0
var _capsula: CapsuleShape3D
var _barra: MeshInstance3D
var _blanco_roca: Node3D       # a quien va la losa: se fija al rugir, para que no cambie a medio tiro
var _piel: MeshInstance3D      # la malla del cuerpo, con el material de piedra

# Compartidos por todos los Panzones: la malla con su reposo en CUSTOM0 y un solo material
# (un material por instancia se recompila y traba; lo de cada uno va en instance uniforms)
static var _malla_serenol: ArrayMesh
static var _material_piel: ShaderMaterial


func _ready() -> void:
	add_to_group("zombis")
	add_to_group("panzon")
	collision_layer = CAPA_ZOMBIS
	collision_mask = 1 | CAPA_ZOMBIS
	var forma := CollisionShape3D.new()
	_capsula = CapsuleShape3D.new()
	_capsula.radius = 0.6 * ESCALA
	_capsula.height = 2.2 * ESCALA
	forma.shape = _capsula
	forma.position.y = 1.1 * ESCALA
	add_child(forma)
	_modelo = MODELO.instantiate()
	_modelo.rotation.y = PI
	_modelo.scale = Vector3.ONE * ESCALA
	add_child(_modelo)
	_anim = _modelo.find_children("*", "AnimationPlayer")[0]
	_vestir()
	for nombre in BUCLES:
		if _anim.has_animation(nombre):
			_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	# La losa que carga va en el hueso Roca; la que vuela es otra (RocaPanzon)
	var esqueleto := _modelo.find_children("*", "Skeleton3D")[0] as Skeleton3D
	var mano := BoneAttachment3D.new()
	mano.bone_name = "Roca"
	esqueleto.add_child(mano)
	_roca_mano = ROCA.instantiate()
	_roca_mano.visible = false
	_roca_mano.scale = Vector3.ONE / ESCALA   # del tamano de la que vuela (RocaPanzon)
	mano.add_child(_roca_mano)
	_animar("Idle")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo and ciclo.has_signal("amanecio"):
		ciclo.amanecio.connect(func() -> void: _morir(false))
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Player
	_armar_barra()
	cambio.connect(_poner_barra)
	cambio.emit(_vida, VIDA)


# Antes era una barra grande arriba al centro de la pantalla y no decia donde estaba (JJ,
# 2026-11-16). Se ve de cualquier distancia: es para encontrarlo
func _armar_barra() -> void:
	var material := ShaderMaterial.new()
	material.shader = BARRA_SHADER
	var cuadro := QuadMesh.new()
	cuadro.size = BARRA
	_barra = MeshInstance3D.new()
	_barra.mesh = cuadro
	_barra.material_override = material
	_barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Gira hacia la camara en el shader: la caja del cuadro plano no alcanzaba
	_barra.custom_aabb = AABB(-Vector3.ONE * BARRA.x / 2.0, Vector3.ONE * BARRA.x)
	_barra.position.y = BARRA_ALTO
	add_child(_barra)


func _poner_barra(cuanta: int, maxima: int) -> void:
	_barra.visible = cuanta > 0
	_barra.set_instance_shader_parameter("vida", clampf(float(cuanta) / maxima, 0.0, 1.0))


func vida() -> int:
	return _vida


func _animar(nombre: String, velocidad := 1.0, reiniciar := false) -> void:
	if _clip != nombre or reiniciar:
		_anim.play(nombre, MEZCLA)
		_clip = nombre
		if _piel:
			_piel.set_instance_shader_parameter("boca_abierta", 1.0 if nombre in BOCA_ABIERTA else 0.0)
		if reiniciar:
			_anim.seek(0.0, true)
	_anim.speed_scale = velocidad


func _mirar(hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length_squared() > 0.0001:
		rotation.y = atan2(-hacia.x, -hacia.z)


func _frente() -> Vector3:
	return -global_basis.z


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0
	_pego = false


func _jugador_libre() -> bool:
	return jugador != null and jugador.can_process() and jugador.is_physics_processing()


func _tinaco() -> Node3D:
	return get_tree().get_first_node_in_group("tinaco_defensa") as Node3D


# Sin tinaco, el jugador. Con tinaco va por el tinaco, y por el jugador solo si se le acerca:
# las losas son para el tinaco y lo de cuerpo a cuerpo para ti (JJ, 2026-11-16)
func _objetivo() -> Node3D:
	var tinaco := _tinaco()
	if tinaco == null or jugador == null:
		return jugador
	var al_jugador := jugador.global_position - global_position
	al_jugador.y = 0.0
	return jugador if al_jugador.length() < PELEA_JUGADOR else tinaco


func _physics_process(delta: float) -> void:
	if jugador == null:
		return
	if not _jugador_libre() and estado != Estado.MUERTO:
		return
	_t += delta
	_espera_embestida = maxf(_espera_embestida - delta, 0.0)
	_espera_roca = maxf(_espera_roca - delta, 0.0)
	_espera_martillo = maxf(_espera_martillo - delta, 0.0)
	match estado:
		Estado.ACECHA: _acechar(delta)
		Estado.RUGE: _rugir(delta)
		Estado.CARGA: _cargar(delta)
		Estado.ARRANCA: _arrancar(delta)
		Estado.AVIENTA: _aventar(delta)
		Estado.AGARRA, Estado.AZOTA, Estado.PISA, Estado.LANZA: _combo(delta)
		Estado.FALLA, Estado.ATARANTADO, Estado.HERIDO: _esperar_clip(delta)
		Estado.MARTILLO: _martillo(delta)
		Estado.MUERTO: _muerto(delta)


func _caer(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVEDAD * delta


func _frenar(delta: float) -> void:
	_caer(delta)
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()


# --- Andar y decidir ---

func _lo_ve(punto: Vector3) -> bool:
	var excluir: Array[RID] = [get_rid(), jugador.get_rid()]
	var rayo := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6 * ESCALA, punto + Vector3.UP * 1.0, 1, excluir)
	return get_world_3d().direct_space_state.intersect_ray(rayo).is_empty()


func _acechar(delta: float) -> void:
	_caer(delta)
	var blanco := _objetivo()
	var hacia := blanco.global_position - global_position
	hacia.y = 0.0
	var lejos := hacia.length()
	if blanco == jugador and lejos > LEJOS:
		_quitar()
		return
	_decide -= delta
	if _decide <= 0.0:
		_decide = DECIDE_CADA
		if _decidir(blanco, lejos):
			return
	# Por el campo de flujo de los zombis si lo hay; derecho de cerca o si el campo no llega. Antes iba
	# derecho mientras viera al blanco, y una barda o banca mas baja que sus ojos (el rayo de _lo_ve
	# sale a 1.6 m) lo dejaba caminando en su lugar lejos, con su barra arriba y sin verse
	var rumbo := hacia.normalized()
	if zombis:
		var campo = zombis.get("campo_tinaco") if blanco != jugador else zombis.get("campo_jugador")
		if campo and campo.has_method("direccion_suave"):
			var d: Vector3 = campo.direccion_suave(global_position)
			if d != Vector3.ZERO and (lejos > DERECHO_HASTA or not _lo_ve(blanco.global_position)):
				rumbo = d
	var cerca := (blanco == jugador and lejos < MARTILLO_DESDE) or (blanco != jugador and lejos < _radio_tinaco(blanco) + 1.5)
	var vel := 0.0 if cerca else CAMINA
	velocity.x = rumbo.x * vel
	velocity.z = rumbo.z * vel
	_mirar(rumbo if vel > 0.0 else hacia)
	move_and_slide()
	_animar("Walk" if vel > 0.0 else "Idle", vel / PASO_CAMINA if vel > 0.0 else 1.0)
	_revisar_atorado(delta, vel > 0.0, rumbo)


# A veces salia encimado en algo bajo (una banca, una jardinera: Hordas._lugar acepta hasta
# ALTO_CALLE) y se quedaba caminando en su lugar. Si camina ATORADO_SEG sin avanzar, brinca al
# primer hueco libre hacia donde iba; casi siempre esta lejos y fuera de camara
func _revisar_atorado(delta: float, caminando: bool, rumbo: Vector3) -> void:
	var avance := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if not caminando or avance > CAMINA * 0.25:
		_atorado = 0.0
		return
	_atorado += delta
	if _atorado < ATORADO_SEG:
		return
	_atorado = 0.0
	# Contra la barricada no: esa la tiene que romper (rocas, martillazo), no brincarla
	if _contra_barricada():
		return
	var espacio := get_world_3d().direct_space_state
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _capsula
	consulta.collision_mask = 1
	consulta.exclude = [get_rid()]
	for distancia in [1.5, 3.0, 4.5, 6.0]:
		for giro in [0.0, 0.7, -0.7, 1.4, -1.4]:
			var punto: Vector3 = global_position + rumbo.rotated(Vector3.UP, giro) * distancia
			var rayo := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 2.0, 1, [get_rid()])
			var suelo := espacio.intersect_ray(rayo)
			if suelo.is_empty() or suelo.position.y > global_position.y + 0.6:
				continue
			consulta.transform = Transform3D(Basis.IDENTITY, suelo.position + Vector3.UP * (1.1 * ESCALA + 0.1))
			if espacio.intersect_shape(consulta, 1).is_empty():
				global_position = suelo.position + Vector3.UP * 0.05
				return


func _contra_barricada() -> bool:
	var tinaco := _tinaco()
	if tinaco and tinaco.global_position.distance_to(global_position) < BARRICADA_HASTA:
		return true
	for i in get_slide_collision_count():
		var nodo := get_slide_collision(i).get_collider() as Node
		while nodo:
			if nodo.is_in_group("barricada"):
				return true
			nodo = nodo.get_parent()
	return false


func _radio_tinaco(tinaco: Node3D) -> float:
	var r = tinaco.get("radio")
	return r if r != null else 1.2


func _decidir(blanco: Node3D, lejos: float) -> bool:
	if blanco == jugador:
		if jugador.atrapado():
			return false
		if lejos < MARTILLO_DESDE and _espera_martillo <= 0.0:
			_empezar_martillo(blanco)
			return true
		if lejos >= EMBESTIDA.x and lejos <= EMBESTIDA.y and _espera_embestida <= 0.0 and is_on_floor() and _lo_ve(blanco.global_position):
			_rugir_para("carga")
			return true
		if lejos > ROCA_DESDE and _espera_roca <= 0.0 and _tinaco() == null and _lo_ve(blanco.global_position):
			_rugir_para("roca")
			return true
	else:
		var al_tinaco := lejos - _radio_tinaco(blanco)
		if al_tinaco < MARTILLO_DESDE and _espera_martillo <= 0.0:
			_empezar_martillo(blanco)
			return true
		if lejos >= TINACO_ROCA.x and lejos <= TINACO_ROCA.y and _espera_roca <= 0.0:
			_rugir_para("roca")
			return true
	return false


func _rugir_para(que: String) -> void:
	velocity = Vector3.ZERO
	_tras_rugido = que
	_blanco_roca = _objetivo()
	_mirar(_blanco_roca.global_position - global_position)
	_cambiar(Estado.RUGE)
	_animar("Roar", 1.0, true)
	Sonidos.tocar(self, "rugido", 2.0, 0.55)
	_nota("ver")


func _rugir(delta: float) -> void:
	_frenar(delta)
	_mirar(_blanco().global_position - global_position)
	if _t >= RUGE_DURA:
		if _tras_rugido == "carga":
			_empezar_carga()
		else:
			_cambiar(Estado.ARRANCA)
			_animar("Rip_Rock", 1.0, true)


# --- Embestida y agarron ---

func _empezar_carga() -> void:
	var hacia := jugador.global_position + jugador.velocity * 0.3 - global_position
	hacia.y = 0.0
	_rumbo = hacia.normalized() if hacia.length_squared() > 0.01 else _frente()
	_mirar(_rumbo)
	_espera_embestida = EMBESTIDA_CADA
	_cambiar(Estado.CARGA)
	_animar("Run_Charge", EMBISTE / PASO_CORRE, true)


func _cargar(delta: float) -> void:
	_caer(delta)
	velocity.x = _rumbo.x * EMBISTE
	velocity.z = _rumbo.z * EMBISTE
	move_and_slide()
	# Los zombis que estorban salen volando a un lado
	for z in get_tree().get_nodes_in_group("zombis"):
		if z == self or not z.has_method("recibir_golpe"):
			continue
		var d: Vector3 = z.global_position - global_position
		d.y = 0.0
		if d.length() < 1.4 * ESCALA and d.normalized().dot(_rumbo) > 0.2:
			z.recibir_golpe(4, global_position, 2.5)
	var al_jugador := jugador.global_position - global_position
	al_jugador.y = 0.0
	if al_jugador.length() < ALCANZA and not jugador.esquivando() and jugador.atrapar(self):
		_agarrar()
		return
	# Contra una pared o la barricada: atarantado
	for i in get_slide_collision_count():
		var choque := get_slide_collision(i)
		var cuerpo := choque.get_collider()
		if cuerpo is StaticBody3D and choque.get_normal().dot(_rumbo) < -0.5:
			_cambiar(Estado.ATARANTADO)
			_animar("Wall_Bonk", BONK_DURA / ATARANTADO_DURA, true)
			velocity = -_rumbo * 2.0
			Sonidos.tocar(self, "golpe", 0.0, 0.6)
			_sacudir(0.6)
			return
	if _t >= EMBISTE_MAX:
		_cambiar(Estado.FALLA)
		_animar("Charge_Miss", 1.0, true)


func _agarrar() -> void:
	velocity = Vector3.ZERO
	collision_mask = 1
	var hacia := jugador.global_position - global_position
	hacia.y = 0.0
	_rumbo = hacia.normalized() if hacia.length_squared() > 0.01 else _frente()
	_pisadas = 0
	_cambiar(Estado.AGARRA)
	_animar("Grab", 1.0, true)
	_nota("pelear")


func _pegar_atrapado(dano: int, empuja := 0.0) -> void:
	# La invulnerabilidad de 0.7 s se comeria los pisotones seguidos
	jugador.set("_invulnerable", 0.0)
	jugador.recibir_dano(dano, global_position, empuja, self)


func _combo(delta: float) -> void:
	# Parado con la victima a DELANTE m enfrente
	global_position = Vector3(jugador.global_position.x, global_position.y, jugador.global_position.z) - _rumbo * DELANTE
	_mirar(_rumbo)
	match estado:
		Estado.AGARRA:
			if _t >= AGARRA_DURA:
				_cambiar(Estado.AZOTA)
				_animar("Slam", 1.0, true)
		Estado.AZOTA:
			if not _pego and _t >= AZOTA_PEGA:
				_pego = true
				_pegar_atrapado(DANO_AZOTON)
				Sonidos.tocar(self, "golpe", 0.0, 0.7)
				_sacudir(0.5)
			if _t >= AZOTA_DURA:
				_cambiar(Estado.PISA)
				_animar("Stomp", 1.0, true)
		Estado.PISA:
			if not _pego and _t >= PISA_PEGA:
				_pego = true
				_pegar_atrapado(DANO_PISOTON)
				Sonidos.tocar(self, "golpe", -2.0, 0.8)
				_sacudir(0.4)
			if _t >= PISA_DURA:
				_pisadas += 1
				if _pisadas < PISOTONES:
					_cambiar(Estado.PISA)
					_animar("Stomp", 1.0, true)
				else:
					_soltada = false
					_cambiar(Estado.LANZA)
					_animar("Throw_Player", 1.0, true)
		Estado.LANZA:
			if not _soltada and _t >= LANZA_SUELTA:
				_soltada = true
				_soltar_jugador()
				# Lo avienta hacia su derecha (-X del Panzon)
				var lado := global_basis.x
				_pegar_atrapado(DANO_LANZA, 0.0)
				# 12 m/s frenando a 12 m/s2: unos 6 m (v^2 / 2a)
				jugador.set("_retroceso", (lado * -1.0 + _rumbo * 0.3).normalized() * 12.0)
				jugador.set("_retroceso_freno", 12.0)
			if _t >= LANZA_DURA:
				collision_mask = 1 | CAPA_ZOMBIS
				_espera_embestida = EMBESTIDA_CADA
				_cambiar(Estado.ACECHA)


# Player llama esto con cada apreton mientras lo tiene agarrado: del Panzon no te zafas
func forcejear() -> void:
	pass


func _soltar_jugador() -> void:
	if jugador and jugador.atrapado_por == self:
		jugador.soltar_atrapado()


# --- Losas ---

# A quien va la losa (o la embestida) que ya rugio; si ya no esta, el de ahorita
func _blanco() -> Node3D:
	return _blanco_roca if is_instance_valid(_blanco_roca) else _objetivo()


func _arrancar(delta: float) -> void:
	_frenar(delta)
	_mirar(_blanco().global_position - global_position)
	if not _roca_mano.visible and _t >= ARRANCA_SALE:
		_roca_mano.visible = true
		Sonidos.tocar(self, "golpe", -4.0, 0.5)
		_sacudir(0.3)
	if _t >= ARRANCA_DURA:
		_soltada = false
		_cambiar(Estado.AVIENTA)
		_animar("Throw", 1.0, true)


func _aventar(delta: float) -> void:
	_frenar(delta)
	var blanco := _blanco()
	_mirar(blanco.global_position - global_position)
	if not _soltada and _t >= AVIENTA_SUELTA:
		_soltada = true
		_roca_mano.visible = false
		var adonde := blanco.global_position
		if blanco == jugador:
			adonde += jugador.velocity * 0.6
		var roca: Node3D = RocaPanzon.new()
		get_parent().add_child(roca)
		roca.lanzar(_roca_mano.global_transform, adonde, self, blanco != jugador)
		_espera_roca = ROCA_CADA
	if _t >= AVIENTA_DURA:
		_cambiar(Estado.ACECHA)


# --- Martillazo ---

func _empezar_martillo(blanco: Node3D) -> void:
	velocity = Vector3.ZERO
	_mirar(blanco.global_position - global_position)
	_espera_martillo = MARTILLO_CADA
	_cambiar(Estado.MARTILLO)
	_animar("Ground_Slam", 1.0, true)


func _martillo(delta: float) -> void:
	_frenar(delta)
	if not _pego and _t >= MARTILLO_PEGA:
		_pego = true
		var donde := global_position + _frente() * 0.9
		Sonidos.tocar(self, "golpe", 2.0, 0.55)
		_sacudir(0.7)
		var al_jugador := jugador.global_position - donde
		al_jugador.y = 0.0
		if al_jugador.length() < MARTILLO_RADIO and not jugador.esquivando():
			jugador.recibir_dano(DANO_MARTILLO, donde, 2.0, self)
			_nota("pelear")
		var tinaco := _tinaco()
		if tinaco and tinaco.global_position.distance_to(donde) < _radio_tinaco(tinaco) + MARTILLO_RADIO:
			tinaco.recibir_golpe(DANO_TINACO_MARTILLO)
		var efectos := get_tree().get_first_node_in_group("efectos_pixel")
		if efectos:
			efectos.lanzar("pisada", donde, Vector3.ZERO, 1.5)
	if _t >= MARTILLO_DURA:
		_cambiar(Estado.ACECHA)


func _esperar_clip(delta: float) -> void:
	_frenar(delta)
	var dura: float = {Estado.FALLA: FALLA_DURA, Estado.ATARANTADO: ATARANTADO_DURA, Estado.HERIDO: HERIDO_DURA}[estado]
	if _t >= dura:
		_cambiar(Estado.ACECHA)


func _sacudir(fuerza: float) -> void:
	if jugador and global_position.distance_to(jugador.global_position) < 20.0:
		jugador.set("_sacude_fuerza", fuerza)
		jugador.set("_sacude_hasta", Time.get_ticks_msec() + 250)


# --- Golpes que recibe ---

# Igual que Zombie.recibir_golpe: 0 = nada, 1 = pego, 2 = mato
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, cuerpo_a_cuerpo := true, cabeza := false, _fuente := "") -> int:
	if estado == Estado.MUERTO:
		return 0
	var mult := (ATARANTADO_MULT if estado == Estado.ATARANTADO else 1) * (2 if cabeza else 1)
	_vida -= dano * mult
	cambio.emit(maxi(_vida, 0), VIDA)
	_nota("pelear")
	var zs = zombis
	# El balazo pinta su impacto donde pego (Pistola.disparar); aqui solo el machete
	var hacia := (global_position - desde)
	hacia.y = 0.0
	hacia = hacia.normalized()
	if cuerpo_a_cuerpo and zs and zs.get("efectos"):
		zs.efectos.lanzar("panzon_impacto", global_position + Vector3.UP * PECHO, hacia, ESCALA, "mata" if _vida <= 0 else "")
	# Sangra Serenol hacia donde iba el golpe (el balazo tambien)
	if zs and zs.get("liquido"):
		zs.liquido.salpicar(global_position + Vector3.UP * PECHO, CUERPO_RADIO, global_position.y,
			(hacia + Vector3.UP * 0.3).normalized(), SALPICA, SANGRE, SALPICA_VELOCIDAD, 0.5)
	Sonidos.tocar(self, "whack", -6.0, 0.8)
	if _vida <= 0:
		_morir(true)
		return 2
	if estado == Estado.ACECHA:
		_cambiar(Estado.HERIDO)
		_animar("Hit", 1.0, true)
	return 1


func _morir(pagado: bool) -> void:
	if estado == Estado.MUERTO:
		return
	_soltar_jugador()
	_cambiar(Estado.MUERTO)
	remove_from_group("zombis")
	remove_from_group("panzon")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_roca_mano.visible = false
	Sonidos.tocar(self, "morir_zombi", 2.0, 0.6)
	cambio.emit(0, VIDA)
	murio.emit()
	if not pagado:
		_reventar()
		return
	_nota("matar")
	var tazos := get_node_or_null("/root/Tazos")
	var bonos := get_node_or_null("/root/Bonos")
	var paga: int = randi_range(PESOS.x, PESOS.y) + (tazos.pesos_extra() if tazos else 0)
	paga = roundi(paga * (bonos.factor_pesos() if bonos else 1.0))
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	var de_noche: bool = ciclo != null and ciclo.es_noche()
	var zona := Deterioro.zona(global_position.x, global_position.z)
	var botin := {}
	for i in BOTINES:
		var uno := Materiales.botin(zona, de_noche, true)
		for id: String in uno:
			botin[id] = botin.get(id, 0) + uno[id]
	CajaBotin.soltar(get_parent(), global_position + Vector3.UP * 1.4 * ESCALA, botin, paga, 1.6)
	_reventar()


# Revienta en Serenol: el hongo azul y un globo de gotas que dejan manchas, y el cuerpo desaparece.
# Tambien al amanecer (sin paga)
func _reventar() -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("panzon_revienta", global_position, Vector3.ZERO, ESCALA)
	var zs = zombis
	if zs and zs.get("liquido"):
		var centro := global_position + Vector3.UP * PECHO
		zs.liquido.reventar(centro, CUERPO_RADIO, global_position.y, REVIENTA * 2 / 3, SANGRE, REVIENTA_VELOCIDAD)
		zs.liquido.reventar(centro, CUERPO_RADIO, global_position.y, REVIENTA / 3, SANGRE_OSCURA, REVIENTA_VELOCIDAD * 0.7)
	Sonidos.tocar(self, "squelch", 0.0, 0.7)
	_modelo.visible = false
	_barra.visible = false


func _muerto(delta: float) -> void:
	_caer(delta)
	move_and_slide()
	if _t >= MUERTO_DURA:
		queue_free()


func _nota(cual: String) -> void:
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.call(cual, "gordo")


func _quitar() -> void:
	_soltar_jugador()
	remove_from_group("zombis")
	remove_from_group("panzon")
	queue_free()


func _exit_tree() -> void:
	_soltar_jugador()


# --- La piel de piedra ---

# Le pone al cuerpo la malla con su reposo (las grietas no resbalan al animar) y los ojos hundidos,
# y el material de piedra con Serenol. La textura del modelo solo dice que es ropa y que es piel
func _vestir() -> void:
	var mallas := _modelo.find_children("*", "MeshInstance3D")
	if mallas.is_empty():
		return
	_piel = mallas[0] as MeshInstance3D
	if _malla_serenol == null:
		_malla_serenol = _malla_con_reposo(_piel.mesh)
		_material_piel = ShaderMaterial.new()
		_material_piel.shader = SHADER_PIEL
		var original := _piel.mesh.surface_get_material(0)
		if original == null:
			original = _piel.get_active_material(0)
		if original is BaseMaterial3D:
			_material_piel.set_shader_parameter("textura", (original as BaseMaterial3D).albedo_texture)
	_piel.mesh = _malla_serenol
	_piel.material_override = _material_piel


# Copia la posicion de reposo de cada vertice a CUSTOM0 (el shader dibuja las grietas y los ojos
# con ella) y hunde los ojos en la malla que se anima
static func _malla_con_reposo(malla: Mesh) -> ArrayMesh:
	var nueva := ArrayMesh.new()
	for s in malla.get_surface_count():
		var arr := malla.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var reposo := PackedFloat32Array()
		reposo.resize(pos.size() * 4)
		for i in pos.size():
			reposo[i * 4] = pos[i].x
			reposo[i * 4 + 1] = pos[i].y
			reposo[i * 4 + 2] = pos[i].z
			reposo[i * 4 + 3] = 1.0
		arr[Mesh.ARRAY_CUSTOM0] = reposo
		arr[Mesh.ARRAY_VERTEX] = _hundir_ojos(pos.duplicate())
		var formato := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var huesos = arr[Mesh.ARRAY_BONES]
		if huesos != null and (huesos as PackedInt32Array).size() == pos.size() * 8:
			formato |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		nueva.add_surface_from_arrays(malla.surface_get_primitive_type(s), arr, [], {}, formato)
		nueva.surface_set_material(s, malla.surface_get_material(s))
	return nueva


# Las medidas son del modelo (metros de reposo, mirando a +Z): discos de los ojos en x 0.02-0.08,
# y 2.08-2.15, z 0.185-0.197; la frente es el anillo de vertices a 2.17 m
static func _hundir_ojos(pos: PackedVector3Array) -> PackedVector3Array:
	for i in pos.size():
		var p := pos[i]
		if p.y > 2.075 and p.y < 2.155 and absf(p.x) > 0.015 and absf(p.x) < 0.09 and p.z > 0.18 and p.z < 0.2:
			p.z -= HUNDE_OJOS
		elif absf(p.y - 2.17) < 0.005 and p.z > 0.1:
			p.z += SALE_CEJA * (1.0 - absf(p.x) * 2.5)
		pos[i] = p
	return pos
