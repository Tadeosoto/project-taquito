class_name Acompanante
extends CharacterBody3D

# Alguien al que escoltas (PasoMision.Tipo.ESCOLTAR, MisionesMundo.gd): te sigue sin pelear, mas
# lento que tu, y los zombis le pegan si lo tienen mas cerca que a ti (Zombie._destino). Si su
# vida llega a 0 avisa con `cayo` y la mision falla.
# Para seguirte usa el campo de flujo de los zombis hacia el jugador (Zombis.campo_jugador, que
# rodea bardas y casas; Zombis lo mantiene vivo mientras haya un Acompanante). Cerca de ti, o si
# el campo no cubre el lugar, va derecho; atorado mucho rato, reaparece junto a ti.

signal cayo

const VELOCIDAD := 3.6        # m/s; el jugador corre a ~10
const SEGUIR_A := 2.4         # m: mas cerca que esto se queda parado
const SE_ADELANTA_A := 45.0   # m: mas lejos que esto aparece detras de ti (se atoro o se perdio)
const ATORADO_EN := 3.0       # s empujando una pared sin avanzar
const ALTO := 1.7
const GRAVEDAD := 25.0
const POR_CAMPO_DESDE := 3.5  # m: mas cerca que esto va derecho, sin campo

# DEFENDER: se queda donde esta (`quieto`) y atrae a los zombis desde `atrae` m, aunque estes mas cerca
const ATRAE_QUIETO := 22.0

static var activos: Array[Acompanante] = []

var vida := 60
var vida_max := 60
var quieto := false
var atrae := 0.0

var _jugador: Node3D
var _campo: CampoFlujo
var _animacion: AnimationPlayer
var _clip := ""
var _atorado := 0.0
var _cayo := false


# El mas cercano a `desde` dentro de `radio` m (o de lo que atraiga, si es mas) y mas cerca que
# `al_jugador`; null si ninguno
static func el_mas_cercano(desde: Vector3, radio: float, al_jugador: float) -> Acompanante:
	var mejor: Acompanante = null
	var cerca := al_jugador
	for a in activos:
		if not is_instance_valid(a) or a._cayo:
			continue
		var d := desde.distance_to(a.global_position)
		if d <= maxf(radio, a.atrae) and d < cerca:
			cerca = d
			mejor = a
	return mejor


static func crear(padre: Node, donde: Vector3, modelo: String, con_vida: int, vida_total: int, se_queda := false) -> Acompanante:
	var a := Acompanante.new()
	a.quieto = se_queda
	a.atrae = ATRAE_QUIETO if se_queda else 0.0
	a.vida = con_vida
	a.vida_max = vida_total
	padre.add_child(a)
	a.global_position = donde
	var nombre := modelo if modelo != "" else Civiles.al_azar()
	a._animacion = Civiles.poner(a, nombre, "Idle")
	a._clip = "Idle"
	return a


func _ready() -> void:
	# Solo el suelo lo para; los zombis lo pegan por la distancia, no por choque
	collision_layer = 0
	collision_mask = 1
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = ALTO
	forma.shape = capsula
	forma.position.y = ALTO / 2.0
	add_child(forma)
	add_to_group("acompanantes")
	activos.append(self)
	_jugador = get_tree().get_first_node_in_group("jugador")
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	_campo = mando.campo_jugador if mando else null


func _exit_tree() -> void:
	activos.erase(self)


func _physics_process(delta: float) -> void:
	if _cayo or _jugador == null or quieto:
		return
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	var distancia := hacia.length()
	if distancia > SE_ADELANTA_A:
		global_position = _jugador.global_position - hacia.normalized() * 3.0
		_atorado = 0.0
		return
	var quiere := Vector3.ZERO
	if distancia > SEGUIR_A:
		var rumbo := hacia / distancia
		if _campo and distancia > POR_CAMPO_DESDE:
			var por_calle := _campo.direccion_suave(global_position)
			if por_calle != Vector3.ZERO:
				rumbo = por_calle
		quiere = rumbo * VELOCIDAD
		rotation.y = lerp_angle(rotation.y, atan2(rumbo.x, rumbo.z), 10.0 * delta)
	velocity.x = quiere.x
	velocity.z = quiere.z
	velocity.y = velocity.y - GRAVEDAD * delta if not is_on_floor() else 0.0
	move_and_slide()
	# Empujando una pared sin avanzar: se brinca la espera y reaparece junto a ti
	if quiere != Vector3.ZERO and get_real_velocity().length() < VELOCIDAD * 0.2:
		_atorado += delta
		if _atorado > ATORADO_EN and distancia > SEGUIR_A * 3.0:
			global_position = _jugador.global_position - hacia.normalized() * 2.0
			_atorado = 0.0
	else:
		_atorado = 0.0
	_poner_clip("Walk" if quiere != Vector3.ZERO else "Idle")


func _poner_clip(clip: String) -> void:
	if clip == _clip or _animacion == null:
		return
	_clip = clip
	var nombre := Civiles.LIB + "/" + clip
	if _animacion.has_animation(nombre):
		var a := _animacion.get_animation(nombre)
		a.loop_mode = Animation.LOOP_LINEAR
		_animacion.play(nombre)


# Lo llaman los zombis al pegarle (el mismo nombre que el tinaco y la bocina)
func recibir_golpe(dano: int) -> void:
	if _cayo:
		return
	vida -= dano
	if vida <= 0:
		_cayo = true
		activos.erase(self)
		_poner_clip("Idle")
		rotation.x = deg_to_rad(-80.0)
		cayo.emit()
