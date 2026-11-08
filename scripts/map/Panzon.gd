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
# Esta en el grupo "zombis" (machete y pistola) y "panzon" (la barra de la defensa); `estado` 3
# es MUERTO como en Zombie. No nombra autoloads (tools/ carga a Zombis).

signal murio
signal cambio(vida: int, maxima: int)

enum Estado { ACECHA, RUGE, CARGA, MUERTO, ARRANCA, AVIENTA, AGARRA, AZOTA, PISA, LANZA, FALLA, ATARANTADO, MARTILLO, HERIDO }

const MODELO := preload("res://models/personajes/panzon/panzon.glb")
const ROCA := preload("res://models/personajes/panzon/roca.glb")
const RocaPanzon := preload("res://scripts/map/RocaPanzon.gd")
const BUCLES := ["Idle", "Walk", "Run_Charge"]
const VIDA := 400
const GRAVEDAD := 30.0
const CAMINA := 1.6            # m/s
const PASO_CAMINA := 1.0       # m/s de Walk a 1x
const EMBISTE := 8.0           # m/s
const PASO_CORRE := 5.1        # m/s de Run_Charge a 1x
const EMBISTE_MAX := 2.5       # s de carga como mucho
const ALCANZA := 1.6           # m al jugador para agarrarlo
const MARTILLO_DESDE := 2.2    # m: mas cerca, martillazo
const MARTILLO_RADIO := 2.5
const EMBESTIDA := Vector2(6.0, 14.0)   # m entre los que embiste
const ROCA_DESDE := 14.0       # m: mas lejos, avienta losa
const EMBESTIDA_CADA := 7.0
const ROCA_CADA := 6.0
const MARTILLO_CADA := 2.5
const LEJOS_TINACO := 25.0     # m del jugador al tinaco: mas lejos, el Panzon va por el tinaco
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
const DELANTE := 1.0           # m: la victima tirada con el pecho a esta distancia (los clips)
const PESOS := Vector2i(15, 30)
const BOTINES := 3
const MUERTO_DURA := 10.0
const LEJOS := 90.0
const CAPA_ZOMBIS := 2
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


func _ready() -> void:
	add_to_group("zombis")
	add_to_group("panzon")
	collision_layer = CAPA_ZOMBIS
	collision_mask = 1 | CAPA_ZOMBIS
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.6
	capsula.height = 2.2
	forma.shape = capsula
	forma.position.y = 1.1
	add_child(forma)
	_modelo = MODELO.instantiate()
	_modelo.rotation.y = PI
	add_child(_modelo)
	_anim = _modelo.find_children("*", "AnimationPlayer")[0]
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
	mano.add_child(_roca_mano)
	_animar("Idle")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo and ciclo.has_signal("amanecio"):
		ciclo.amanecio.connect(func() -> void: _morir(false))
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Player
	cambio.emit(_vida, VIDA)


func vida() -> int:
	return _vida


func _animar(nombre: String, velocidad := 1.0, reiniciar := false) -> void:
	if _clip != nombre or reiniciar:
		_anim.play(nombre, MEZCLA)
		_clip = nombre
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


# El jugador; el tinaco si el jugador anda lejos de el (castiga dejarlo solo)
func _objetivo() -> Node3D:
	var tinaco := _tinaco()
	if tinaco and jugador and jugador.global_position.distance_to(tinaco.global_position) > LEJOS_TINACO:
		return tinaco
	return jugador


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
	var rayo := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.6, punto + Vector3.UP * 1.0, 1, excluir)
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
	# Por el campo de flujo de los zombis si lo hay; derecho si no
	var rumbo := hacia.normalized()
	if zombis:
		var campo = zombis.get("campo_tinaco") if blanco != jugador else zombis.get("campo_jugador")
		if campo and campo.has_method("direccion_suave"):
			var d: Vector3 = campo.direccion_suave(global_position)
			if d != Vector3.ZERO and not _lo_ve(blanco.global_position):
				rumbo = d
	var cerca := (blanco == jugador and lejos < MARTILLO_DESDE) or (blanco != jugador and lejos < _radio_tinaco(blanco) + 1.5)
	var vel := 0.0 if cerca else CAMINA
	velocity.x = rumbo.x * vel
	velocity.z = rumbo.z * vel
	_mirar(rumbo if vel > 0.0 else hacia)
	move_and_slide()
	_animar("Walk" if vel > 0.0 else "Idle", vel / PASO_CAMINA if vel > 0.0 else 1.0)


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
		if lejos > ROCA_DESDE and _espera_roca <= 0.0 and _lo_ve(blanco.global_position):
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
	_mirar(_objetivo().global_position - global_position)
	_cambiar(Estado.RUGE)
	_animar("Roar", 1.0, true)
	Sonidos.tocar(self, "rugido", 2.0, 0.55)
	_nota("ver")


func _rugir(delta: float) -> void:
	_frenar(delta)
	_mirar(_objetivo().global_position - global_position)
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
		if d.length() < 1.4 and d.normalized().dot(_rumbo) > 0.2:
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

func _arrancar(delta: float) -> void:
	_frenar(delta)
	_mirar(_objetivo().global_position - global_position)
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
	var blanco := _objetivo()
	_mirar(blanco.global_position - global_position)
	if not _soltada and _t >= AVIENTA_SUELTA:
		_soltada = true
		_roca_mano.visible = false
		var adonde := blanco.global_position
		if blanco == jugador:
			adonde += jugador.velocity * 0.6
		var roca: Node3D = RocaPanzon.new()
		get_parent().add_child(roca)
		roca.lanzar(_roca_mano.global_transform, adonde, self)
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
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, _cuerpo_a_cuerpo := true, cabeza := false) -> int:
	if estado == Estado.MUERTO:
		return 0
	var mult := (ATARANTADO_MULT if estado == Estado.ATARANTADO else 1) * (2 if cabeza else 1)
	_vida -= dano * mult
	cambio.emit(maxi(_vida, 0), VIDA)
	_nota("pelear")
	var zs = zombis
	if zs and zs.get("efectos"):
		zs.efectos.lanzar("impacto", global_position + Vector3.UP * 1.3, (global_position - desde).normalized())
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
	_animar("Death", 1.0, true)
	Sonidos.tocar(self, "morir_zombi", 2.0, 0.6)
	cambio.emit(0, VIDA)
	murio.emit()
	if not pagado:
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
	CajaBotin.soltar(get_parent(), global_position + Vector3.UP * 1.4, botin, paga, 1.6)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("muerte", global_position, Vector3.ZERO, 2.0)


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
