class_name Saltabardas
extends CharacterBody3D

# El Saltabardas (docs/prompts/blender_saltabardas.md, propuesta de AG): el chavo de la esquina
# que se brincaba las bardas. Zombi especial que se te echa encima, con su modelo propio
# (models/personajes/saltabardas, sus clips en su lugar):
#   ACECHA: se acerca agachado (Stalk_Walk) o a cuatro patas (Run_AllFours) por el campo de flujo;
#     sin verte olfatea (Sniff_Scan).
#   GRITA: a SALTA_DESDE m y viendote, grita (Shriek, pico en el cuadro 10): es el aviso.
#   ENROSCA (Pounce_Windup) y VUELA (Pounce_Air) en arco hacia donde vas a estar.
#   ENCIMA: si te alcanza te tira (Player.atrapar) y te araña (Pin_Maul, garras en 8 y 23).
#     Machacando golpe o brinco (forcejear) te lo quitas (Knocked_Off). Rodando lo esquivas y
#     cubriendote de frente (bloquear) lo paras.
#   Pegarle en el aire lo tumba (Stagger). Al amanecer se cae como los demas.
# Esta en el grupo "zombis" para que lo alcancen el machete y la pistola; `estado` 3 es MUERTO
# como en Zombie (el minimapa lo lee asi). No nombra autoloads (tools/ carga a Zombis).

signal murio

enum Estado { ACECHA, GRITA, ENROSCA, MUERTO, VUELA, ENCIMA, TAMBALEA, ZAFADO }

const MODELO := preload("res://models/personajes/saltabardas/saltabardas.glb")
const BUCLES := ["Idle_Crouch", "Sniff_Scan", "Stalk_Walk", "Run_AllFours", "Pounce_Air", "Pin_Maul", "Perch_Idle"]
const VIDA := 40
const GRAVEDAD := 30.0
const VE_DESDE := 30.0          # m a los que te detecta si te ve
const SALTA_DESDE := 13.0       # m: de aqui para adentro grita y salta
const SALTA_MINIMO := 3.0
const CORRE := 6.5              # m/s a cuatro patas
const ACECHA_VEL := 2.0         # m/s agachado, ya cerca
const CORRE_DESDE := 18.0       # m: mas lejos corre
const PASO_CORRE := 3.2         # m/s que avanza Run_AllFours a 1x
const PASO_ACECHA := 0.56       # m/s de Stalk_Walk a 1x
const GRITO_DURA := 0.8         # s de Shriek
const ENROSCA_DURA := 0.4       # s de Pounce_Windup
const VUELO := 13.0             # m/s de lado en el salto
const VUELO_MAX := 1.4          # s: si no ha caido, cae
const ADELANTA := 0.35          # s: salta hacia donde vas a estar
const ATRAPA := 1.4             # m del pecho del jugador para tirarlo
const DANO_SALTO := 10
const DANO_GARRA := 8
const GARRAS := [8.0 / 30.0, 23.0 / 30.0]   # s del Pin_Maul donde pegan
const ZAFARSE := 7.0            # apretones para quitartelo
const OLVIDA := 1.4             # apretones que se olvidan por segundo
const ZAFADO_DURA := 1.0        # s de Knocked_Off
const ZAFADO_EMPUJE := 3.0      # m que sale volando
const TAMBALEA_DURA := 0.6
const TUMBADO_DURA := 1.1       # si le pegaste en el aire
const ESPERA_SALTO := Vector2(3.0, 5.0)   # s entre un salto fallido y el siguiente
const MUERTO_DURA := 8.0
const LEJOS := 75.0
const PECHO := 0.9
const PESOS := Vector2i(4, 8)
const CAPA_ZOMBIS := 2
const MEZCLA := 0.15

var jugador: Player
var zombis: Node            # Zombis (campo de flujo, efectos); puede no haber
var estado := Estado.ACECHA

var _vida := VIDA
var _t := 0.0
var _espera := 0.0
var _modelo: Node3D
var _anim: AnimationPlayer
var _clip := ""
var _destino := Vector3.ZERO
var _forcejeo := 0.0
var _pego_garra := [false, false]
var _visto := false


func _ready() -> void:
	add_to_group("zombis")
	add_to_group("saltabardas")
	collision_layer = CAPA_ZOMBIS
	collision_mask = 1 | CAPA_ZOMBIS
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.1
	forma.shape = capsula
	forma.position.y = 0.55
	add_child(forma)
	_modelo = MODELO.instantiate()
	# El modelo mira a +Z (exportado de Blender); el cuerpo, a -Z como todos
	_modelo.rotation.y = PI
	add_child(_modelo)
	_anim = _modelo.find_children("*", "AnimationPlayer")[0]
	for nombre in BUCLES:
		if _anim.has_animation(nombre):
			_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	_animar("Idle_Crouch")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo and ciclo.has_signal("amanecio"):
		ciclo.amanecio.connect(func() -> void: _morir(false))
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Player


func _animar(nombre: String, velocidad := 1.0, reiniciar := false) -> void:
	if _clip != nombre or reiniciar:
		_anim.play(nombre, MEZCLA)
		_clip = nombre
	_anim.speed_scale = velocidad


func _mirar(hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length_squared() > 0.0001:
		rotation.y = atan2(-hacia.x, -hacia.z)


func _jugador_libre() -> bool:
	return jugador != null and jugador.can_process() and jugador.is_physics_processing()


func _physics_process(delta: float) -> void:
	if jugador == null:
		return
	# Como los demas zombis: con el jugador congelado (tienda, dron, desmayado) no hace nada
	if not _jugador_libre() and estado != Estado.MUERTO:
		return
	_t += delta
	_espera = maxf(_espera - delta, 0.0)
	match estado:
		Estado.ACECHA: _acechar(delta)
		Estado.GRITA: _gritar(delta)
		Estado.ENROSCA: _enroscar(delta)
		Estado.VUELA: _volar(delta)
		Estado.ENCIMA: _encima(delta)
		Estado.TAMBALEA: _tambalear(delta)
		Estado.ZAFADO: _zafado(delta)
		Estado.MUERTO: _muerto(delta)


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0


func _caer(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVEDAD * delta


# --- Acechar ---

func _te_ve() -> bool:
	var ojos := global_position + Vector3.UP * 0.8
	var pecho := jugador.global_position + Vector3.UP * PECHO
	if ojos.distance_to(pecho) > VE_DESDE:
		return false
	var excluir: Array[RID] = [get_rid(), jugador.get_rid()]
	var rayo := PhysicsRayQueryParameters3D.create(ojos, pecho, 1, excluir)
	return get_world_3d().direct_space_state.intersect_ray(rayo).is_empty()


func _acechar(delta: float) -> void:
	_caer(delta)
	var al_jugador := jugador.global_position - global_position
	al_jugador.y = 0.0
	var lejos := al_jugador.length()
	if lejos > LEJOS:
		_quitar()
		return
	_visto = _te_ve()
	if _visto and lejos <= SALTA_DESDE and lejos >= SALTA_MINIMO and _espera <= 0.0 and is_on_floor() and not jugador.atrapado():
		velocity = Vector3.ZERO
		_mirar(al_jugador)
		_cambiar(Estado.GRITA)
		_animar("Shriek", 1.0, true)
		Sonidos.tocar(self, "gemido", 0.0, 1.7)
		return
	# Por el campo de flujo de los zombis si lo hay; derecho si te ve o no hay campo
	var rumbo := al_jugador.normalized()
	if zombis and not _visto:
		var campo: Vector3 = zombis.campo_jugador.direccion_suave(global_position)
		if campo != Vector3.ZERO:
			rumbo = campo
	var cerca := lejos < SALTA_MINIMO or (_espera > 0.0 and lejos < SALTA_DESDE)
	var vel := 0.0 if cerca else (CORRE if lejos > CORRE_DESDE or not _visto else ACECHA_VEL)
	velocity.x = rumbo.x * vel
	velocity.z = rumbo.z * vel
	_mirar(rumbo if vel > 0.0 else al_jugador)
	move_and_slide()
	if vel <= 0.0:
		_animar("Idle_Crouch" if _visto else "Sniff_Scan")
	elif vel >= CORRE:
		_animar("Run_AllFours", vel / PASO_CORRE)
	else:
		_animar("Stalk_Walk", vel / PASO_ACECHA)


func _gritar(delta: float) -> void:
	_caer(delta)
	move_and_slide()
	_mirar(jugador.global_position - global_position)
	if _t >= GRITO_DURA:
		_cambiar(Estado.ENROSCA)
		_animar("Pounce_Windup", 1.0, true)


func _enroscar(delta: float) -> void:
	_caer(delta)
	move_and_slide()
	_mirar(jugador.global_position - global_position)
	if _t >= ENROSCA_DURA:
		_saltar()


# Arco hacia donde vas a estar: de lado a VUELO m/s, el tiempo que eso tarde
func _saltar() -> void:
	var blanco := jugador.global_position + jugador.velocity * ADELANTA
	blanco.y = jugador.global_position.y
	var lado := blanco - global_position
	var alto := lado.y
	lado.y = 0.0
	var tiempo := clampf(lado.length() / VUELO, 0.25, VUELO_MAX)
	velocity = lado / tiempo
	velocity.y = (alto + 0.5 * GRAVEDAD * tiempo * tiempo) / tiempo
	_mirar(lado)
	collision_mask = 1
	_cambiar(Estado.VUELA)
	_animar("Pounce_Air")
	Sonidos.tocar(self, "silbido", -6.0, 1.4)


func _volar(delta: float) -> void:
	velocity.y -= GRAVEDAD * delta
	move_and_slide()
	var pecho := jugador.global_position + Vector3.UP * PECHO
	if (global_position + Vector3.UP * 0.5).distance_to(pecho) <= ATRAPA:
		_alcanzar()
		return
	if (is_on_floor() and _t > 0.15) or _t > VUELO_MAX:
		# Cayo sin alcanzarte
		collision_mask = 1 | CAPA_ZOMBIS
		velocity = Vector3.ZERO
		_espera = randf_range(ESPERA_SALTO.x, ESPERA_SALTO.y)
		_tambalearse(TAMBALEA_DURA)


func _alcanzar() -> void:
	collision_mask = 1 | CAPA_ZOMBIS
	var de_frente := (global_position - jugador.global_position).normalized().dot(-jugador.frijol.global_basis.z) > 0.0
	if jugador.esquivando():
		# Rodando: se le pasa por encima
		return
	if jugador.bloqueando() and de_frente:
		# Parado de frente: el golpe le toca al machete y el se va de espaldas
		jugador.recibir_dano(DANO_SALTO, global_position, 1.5, self)
		velocity = (global_position - jugador.global_position).normalized() * 4.0
		velocity.y = 3.0
		_espera = randf_range(ESPERA_SALTO.x, ESPERA_SALTO.y)
		_tambalearse(TUMBADO_DURA)
		return
	if not jugador.atrapar(self):
		return
	jugador.recibir_dano(DANO_SALTO, global_position, 0.0, self)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_forcejeo = 0.0
	_pego_garra = [false, false]
	_cambiar(Estado.ENCIMA)
	_animar("Pin_Maul", 1.0, true)
	Sonidos.tocar(self, "gemido", -2.0, 1.4)


# --- Encima del jugador ---

func _encima(delta: float) -> void:
	var salud := get_node_or_null("/root/Salud")
	if salud and salud.vida <= 0:
		# Te desmayaste (Supervivencia.gd): se va
		_soltar_jugador()
		_quitar()
		return
	var frente := -jugador.frijol.global_basis.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.001 else Vector3.FORWARD
	# Montado sobre el, mirando a su cabeza
	global_position = jugador.global_position - frente * 0.35
	_mirar(frente)
	_forcejeo = maxf(_forcejeo - OLVIDA * delta, 0.0)
	var en_clip := fmod(_t, 1.0)
	for i in GARRAS.size():
		if not _pego_garra[i] and en_clip >= GARRAS[i]:
			_pego_garra[i] = true
			jugador.recibir_dano(DANO_GARRA, global_position, 0.0, self)
	if en_clip < GARRAS[0]:
		_pego_garra = [false, false]


# Player llama esto con cada apreton de golpe o brinco mientras lo tiene encima
func forcejear() -> void:
	if estado != Estado.ENCIMA:
		return
	_forcejeo += 1.0
	if _forcejeo >= ZAFARSE:
		_soltar_jugador()
		var atras := global_position - jugador.global_position
		atras.y = 0.0
		atras = atras.normalized() if atras.length_squared() > 0.001 else Vector3.BACK
		velocity = atras * ZAFADO_EMPUJE / ZAFADO_DURA
		_mirar(-atras)
		collision_layer = CAPA_ZOMBIS
		collision_mask = 1 | CAPA_ZOMBIS
		_espera = randf_range(ESPERA_SALTO.x, ESPERA_SALTO.y)
		_cambiar(Estado.ZAFADO)
		_animar("Knocked_Off", 1.0, true)


func _soltar_jugador() -> void:
	if jugador and jugador.atrapado_por == self:
		jugador.soltar_atrapado()
	collision_layer = CAPA_ZOMBIS
	collision_mask = 1 | CAPA_ZOMBIS


func _zafado(delta: float) -> void:
	_caer(delta)
	velocity.x = move_toward(velocity.x, 0.0, ZAFADO_EMPUJE * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, ZAFADO_EMPUJE * 2.0 * delta)
	move_and_slide()
	if _t >= ZAFADO_DURA:
		_cambiar(Estado.ACECHA)


func _tambalearse(dura: float) -> void:
	_cambiar(Estado.TAMBALEA)
	_espera = maxf(_espera, dura)
	_animar("Stagger", 0.6 / dura, true)


func _tambalear(delta: float) -> void:
	_caer(delta)
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	move_and_slide()
	if _t >= _anim.current_animation_length / maxf(_anim.speed_scale, 0.01):
		_cambiar(Estado.ACECHA)


# --- Golpes que recibe (machete, pistola) ---

# Igual que Zombie.recibir_golpe: 0 = nada, 1 = pego, 2 = mato
func recibir_golpe(dano: int, desde: Vector3, fuerza := 1.0, _truena_en := 80, _cuerpo_a_cuerpo := true, cabeza := false) -> int:
	if estado == Estado.MUERTO:
		return 0
	_vida -= dano * (2 if cabeza else 1)
	if zombis and zombis.get("efectos"):
		zombis.efectos.lanzar("impacto", global_position + Vector3.UP * 0.6, (global_position - desde).normalized())
	Sonidos.tocar(self, "whack", -8.0)
	if _vida <= 0:
		_morir(true)
		return 2
	var atras := global_position - desde
	atras.y = 0.0
	atras = atras.normalized() if atras.length_squared() > 0.001 else Vector3.BACK
	match estado:
		Estado.VUELA:
			# Bateado en el aire: se cae de espaldas
			collision_mask = 1 | CAPA_ZOMBIS
			velocity = atras * 3.0 * fuerza
			velocity.y = 2.0
			_espera = randf_range(ESPERA_SALTO.x, ESPERA_SALTO.y)
			_tambalearse(TUMBADO_DURA)
		Estado.ACECHA, Estado.GRITA, Estado.ENROSCA:
			velocity = atras * 2.0 * fuerza
			_tambalearse(TAMBALEA_DURA * 0.6)
	return 1


func _morir(pagado: bool) -> void:
	if estado == Estado.MUERTO:
		return
	_soltar_jugador()
	_cambiar(Estado.MUERTO)
	remove_from_group("zombis")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_animar("Death", 1.0, true)
	Sonidos.tocar(self, "morir_zombi", -2.0, 1.3)
	murio.emit()
	if not pagado:
		return
	var tazos := get_node_or_null("/root/Tazos")
	var bonos := get_node_or_null("/root/Bonos")
	var paga: int = randi_range(PESOS.x, PESOS.y) + (tazos.pesos_extra() if tazos else 0)
	paga = roundi(paga * (bonos.factor_pesos() if bonos else 1.0))
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	var de_noche: bool = ciclo != null and ciclo.es_noche()
	# Suelta como un cazador (Materiales.botin)
	CajaBotin.soltar(get_parent(), global_position + Vector3.UP * PECHO, Materiales.botin(Deterioro.zona(global_position.x, global_position.z), de_noche, true), paga)
	if zombis and zombis.get("efectos"):
		zombis.efectos.lanzar("muerte", global_position, Vector3.ZERO, 1.0)


func _muerto(delta: float) -> void:
	_caer(delta)
	move_and_slide()
	if _t >= MUERTO_DURA:
		queue_free()


func _quitar() -> void:
	_soltar_jugador()
	remove_from_group("zombis")
	queue_free()


func _exit_tree() -> void:
	_soltar_jugador()
