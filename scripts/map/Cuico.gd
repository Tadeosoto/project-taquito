class_name Cuico
extends CharacterBody3D

# Un cuico (los blancos de GelA, docs/lore.md 5): de dia camina por las banquetas como la gente
# (Cuicos.gd le da el camino). Si te ve con la caja de la mafia (Player.carga_soltable) o ya te
# buscan (Cuicos.busqueda), grita "¡Alto!", se saca la pistola, te persigue y te dispara. Se le
# puede tumbar a golpes o a balazos: esta en "zombis" para que el machete del jugador lo
# encuentre sin tocar player.gd, con recibir_golpe y radio_golpe como un Zombie. Al tumbarlo
# llegan mas (Cuicos.tumbado). Plan M7b en docs/plan-noche.md.

enum Estado { PATRULLA, AVISA, PERSIGUE, BUSCA, TUMBADO }

const LIB := Civiles.LIB
const PISTOLA := preload("res://models/armas/pistola_mk23/pistola_mk23.scn")
const PISTOLA_TAMANO := 0.4
const PISTOLA_GIRO := Vector3(0.0, 0.0, -90.0)    # como Player.PISTOLA_GIRO
const PISTOLA_MANGO := Vector3(-0.47, 0.04, 0.07)  # Player.PISTOLA_MANGO

const VIDA := 60               # 5 machetazos (Player.DANO_MACHETE 12)
const RADIO := 0.35
const ALTO := 1.8
const VISTA := 25.0            # m del cono (el minimapa lo dibuja: Cuicos.VISTA)
const VISTA_ANGULO := 35.0     # grados a cada lado del frente
const VISTA_ALTO := 1.5
const OIDO := 4.0              # tan cerca te nota aunque le des la espalda
const AVISO := 0.8             # s entre el "¡Alto!" y el primer tiro
const PATRULLA := 1.3          # m/s; Gente.VELOCIDAD es 1.4
const PERSIGUE := 4.2          # m/s: trotando (5) se le escapa, despacio
const CERCA := 6.0             # m: ya no se acerca mas, dispara parado
const DISPARA_CADA := 1.2
const DISPARO_ALCANCE := 30.0
const ATINA := Vector2(0.85, 0.25)   # probabilidad de pegar a 4 m y a DISPARO_ALCANCE
const DANO := 12
const PIERDE := 6.0            # s sin verte para irse a donde te vio la ultima vez
const BUSCA := 8.0             # s buscando ahi antes de volver a patrullar
const TUMBADO_DURA := 12.0
const CAMINA_PASO := 1.12      # Gente.PASO["Walk"]
const TROTE_PASO := 3.6        # al que el Jog_Fwd se ve a su velocidad
const GRITOS := ["¡Alto ahí!", "¡Quieto!", "¡Suelta eso!", "¡Alto, cabrón!"]

var estado := Estado.PATRULLA
var radio_golpe := RADIO       # Player._radio_de
var alertado := false          # lo llamaron (refuerzo): va hacia ti aunque no te vea
var cuicos: Node               # Cuicos.gd
# El camino de la patrulla, como un caminante de Gente: la linea de banqueta, el vertice, el sentido
var linea: Array = []
var i := 0
var sentido := 1
var avance := 0.0

var _vida := VIDA
var _jugador: Node3D
var _animacion: AnimationPlayer
var _mano: BoneAttachment3D
var _pistola: Node3D
var _destello: OmniLight3D
var _grito: Label3D
var _tiempo := 0.0             # en AVISA y BUSCA: lo que lleva; en PERSIGUE: desde el ultimo tiro
var _sin_verte := 0.0
var _ultimo_visto := Vector3.ZERO
var _vista: PhysicsRayQueryParameters3D
var _revisa := 0.0
var _tiro := 0.0               # s que se deja ver el Pistol_Shoot antes de otro clip
var _y := 0.0


func armar(modelo: String) -> void:
	add_to_group("cuicos")
	add_to_group("zombis")
	collision_layer = 2            # Zombie.CAPA_ZOMBIS: la pistola del jugador le pega
	collision_mask = 1
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = RADIO
	capsula.height = ALTO
	forma.shape = capsula
	forma.position.y = ALTO / 2.0
	add_child(forma)
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	add_child(cuerpo)
	_animacion = Civiles.poner(cuerpo, modelo, "Walk")
	_grito = Label3D.new()
	_grito.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_grito.no_depth_test = true
	_grito.fixed_size = true
	_grito.pixel_size = 0.0035
	_grito.font_size = 24
	_grito.outline_size = 8
	_grito.modulate = Color(1.0, 0.9, 0.2)
	_grito.position.y = ALTO + 0.45
	_grito.visible = false
	add_child(_grito)
	_destello = OmniLight3D.new()
	_destello.light_color = Color(1.0, 0.8, 0.4)
	_destello.light_energy = 3.0
	_destello.omni_range = 4.0
	_destello.visible = false
	_destello.position = Vector3(0.0, 1.4, -0.6)
	add_child(_destello)
	_vista = PhysicsRayQueryParameters3D.new()
	_vista.collision_mask = 1
	_vista.hit_back_faces = true


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	if _jugador is CollisionObject3D:
		_vista.exclude = [(_jugador as CollisionObject3D).get_rid()]
	_armar_mano.call_deferred()


func _armar_mano() -> void:
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	var esqueleto := esqueletos[0] as Skeleton3D
	if esqueleto.find_bone("RightHand") < 0:
		return
	_mano = BoneAttachment3D.new()
	esqueleto.add_child(_mano)
	_mano.bone_name = "RightHand"
	var dato := InventoryItemData.new()
	dato.inspection_model = PISTOLA
	_pistola = dato.crear_modelo(PISTOLA_TAMANO)
	if _pistola == null:
		return
	_mano.add_child(_pistola)
	_pistola.visible = false
	# Un cuadro despues el hueso ya tiene su escala (como Player._mostrar_arma)
	await get_tree().process_frame
	if not is_instance_valid(_pistola):
		return
	_pistola.scale = Vector3.ONE / maxf(_mano.global_transform.basis.get_scale().x, 0.001)
	_pistola.rotation_degrees = PISTOLA_GIRO
	(_pistola.get_child(0) as Node3D).position += PISTOLA_MANGO * PISTOLA_TAMANO
	_pistola.visible = estado in [Estado.AVISA, Estado.PERSIGUE, Estado.BUSCA]


# Al salir de la reserva de Cuicos, en la banqueta
func poner_en(donde: Vector3) -> void:
	global_position = donde
	_y = donde.y
	_vida = VIDA
	a_patrullar()


# Otra vez a su banqueta (Cuicos le puso linea e i)
func a_patrullar() -> void:
	alertado = false
	_cambiar(Estado.PATRULLA)


func vivo() -> bool:
	return estado != Estado.TUMBADO


func frente() -> Vector3:
	return -global_basis.z


# true si ya te esta persiguiendo o te busca (Cuicos: para la busqueda y para no quitarlo de lejos)
func activo() -> bool:
	return estado in [Estado.AVISA, Estado.PERSIGUE, Estado.BUSCA]


func _physics_process(delta: float) -> void:
	if _jugador == null:
		return
	_tiro -= delta
	match estado:
		Estado.PATRULLA:
			cuicos.patrullar(self, PATRULLA * delta)
			_animacion.speed_scale = PATRULLA / CAMINA_PASO
			_revisa -= delta
			if _revisa <= 0.0:
				_revisa = 0.2
				if alertado or (cuicos.te_buscan() or _trae_la_caja()) and _te_ve():
					_ultimo_visto = _jugador.global_position
					_cambiar(Estado.AVISA)
		Estado.AVISA:
			_mirar_a(_jugador.global_position)
			_tiempo += delta
			if _tiempo >= AVISO:
				_cambiar(Estado.PERSIGUE)
		Estado.PERSIGUE:
			_perseguir(delta)
		Estado.BUSCA:
			_buscar(delta)
		Estado.TUMBADO:
			_tiempo += delta
			if _tiempo >= TUMBADO_DURA:
				cuicos.guardar(self)


func _perseguir(delta: float) -> void:
	var ve := _te_ve(true)
	if ve:
		_sin_verte = 0.0
		_ultimo_visto = _jugador.global_position
		cuicos.te_vieron()
	else:
		_sin_verte += delta
		if _sin_verte >= PIERDE:
			_cambiar(Estado.BUSCA)
			return
	var hacia := _ultimo_visto - global_position
	hacia.y = 0.0
	var lejos := hacia.length()
	_mirar_a(_ultimo_visto)
	if lejos > (CERCA if ve else 1.0):
		_mover(hacia.normalized() * PERSIGUE)
		_clip("Jog_Fwd", PERSIGUE / TROTE_PASO)
	else:
		_mover(Vector3.ZERO)
		_clip("Pistol_Aim_Neutral")
	_tiempo += delta
	if ve and _tiempo >= DISPARA_CADA and lejos <= DISPARO_ALCANCE:
		_tiempo = randf_range(-0.2, 0.2)
		_disparar(lejos)


func _buscar(delta: float) -> void:
	if _te_ve(true):
		_cambiar(Estado.PERSIGUE)
		return
	var hacia := _ultimo_visto - global_position
	hacia.y = 0.0
	if hacia.length() > 1.0:
		_mirar_a(_ultimo_visto)
		_mover(hacia.normalized() * PATRULLA * 1.5)
		_clip("Walk", PATRULLA * 1.5 / CAMINA_PASO)
		return
	_mover(Vector3.ZERO)
	_clip("Pistol_Idle")
	rotate_y(delta * 1.2)       # se asoma a los lados
	_tiempo += delta
	if _tiempo >= BUSCA:
		cuicos.volver_a_patrullar(self)


func _disparar(lejos: float) -> void:
	_animacion.play(LIB + "/Pistol_Shoot", 0.05)
	_animacion.speed_scale = 1.0
	_tiro = 0.35
	_destello.visible = true
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(_destello):
			_destello.visible = false)
	Sonidos.tocar(self, "disparo_pistola", -4.0 - lejos * 0.4, randf_range(0.92, 1.05))
	var atina := lerpf(ATINA.x, ATINA.y, clampf((lejos - 4.0) / (DISPARO_ALCANCE - 4.0), 0.0, 1.0))
	if randf() < atina and _jugador.has_method("recibir_dano"):
		_jugador.recibir_dano(DANO, global_position, 0.4, self)


# --- Lo que el jugador le hace ---

# Como Zombie.recibir_golpe: 0 no le hizo nada, 1 le pego. Tumbarlo tambien es 1 y no 2, para
# que no cuente como zombi muerto (tazos, libreta, espada)
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, _cuerpo_a_cuerpo := true, _cabeza := false, _fuente := "") -> int:
	if estado == Estado.TUMBADO:
		return 0
	_vida -= dano
	_ultimo_visto = desde
	cuicos.lo_atacaron(self)
	if _vida <= 0:
		_tumbar()
		return 1
	_animacion.play(LIB + "/Hit_Chest", 0.05)
	if estado in [Estado.PATRULLA, Estado.AVISA, Estado.BUSCA]:
		_cambiar(Estado.PERSIGUE)
	return 1


func alertar(donde: Vector3) -> void:
	if estado == Estado.TUMBADO:
		return
	_ultimo_visto = donde
	alertado = true
	if estado == Estado.PATRULLA:
		_cambiar(Estado.AVISA)
	elif estado == Estado.BUSCA:
		_cambiar(Estado.PERSIGUE)


func _tumbar() -> void:
	_cambiar(Estado.TUMBADO)
	remove_from_group("zombis")
	collision_layer = 0
	_animacion.play(LIB + "/Death01", 0.1)
	cuicos.tumbado(self)


# --- Ayudas ---

func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_tiempo = 0.0
	_sin_verte = 0.0
	velocity = Vector3.ZERO
	if _pistola:
		_pistola.visible = nuevo in [Estado.AVISA, Estado.PERSIGUE, Estado.BUSCA]
	match nuevo:
		Estado.PATRULLA:
			_clip("Walk", PATRULLA / CAMINA_PASO)
			_grito.visible = false
		Estado.AVISA:
			_clip("Pistol_Aim_Neutral")
			_gritar(GRITOS.pick_random())
		Estado.BUSCA:
			_grito.visible = false


func _gritar(texto: String) -> void:
	_grito.text = texto
	_grito.visible = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(_grito) and _grito.text == texto:
			_grito.visible = false)


func _clip(nombre: String, velocidad := 1.0) -> void:
	var completo := LIB + "/" + nombre
	_animacion.speed_scale = velocidad
	if _animacion.current_animation != completo and _tiro <= 0.0:
		_animacion.play(completo, 0.15)


func _mover(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = -9.8 if not is_on_floor() else 0.0
	move_and_slide()


func _mirar_a(punto: Vector3) -> void:
	var hacia := punto - global_position
	if Vector2(hacia.x, hacia.z).length_squared() > 0.01:
		rotation.y = atan2(-hacia.x, -hacia.z)


func _trae_la_caja() -> bool:
	return bool(_jugador.get("carga_soltable"))


# Dentro del cono (o a OIDO m) y sin pared en medio. `persiguiendo`: ya te tiene, no hace falta el cono
func _te_ve(persiguiendo := false) -> bool:
	if cuicos.adentro(_jugador.global_position):
		return false
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	var lejos := hacia.length()
	if lejos > (DISPARO_ALCANCE if persiguiendo else VISTA):
		return false
	if not persiguiendo and lejos > OIDO and rad_to_deg(frente().angle_to(hacia)) > VISTA_ANGULO:
		return false
	_vista.from = global_position + Vector3.UP * VISTA_ALTO
	_vista.to = _jugador.global_position + Vector3.UP * VISTA_ALTO
	return get_world_3d().direct_space_state.intersect_ray(_vista).is_empty()
