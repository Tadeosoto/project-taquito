class_name Carretilla
extends Acompanante

## El herido de "Al medico" (M5): una persona echada en una carretilla que el jugador lleva de los mangos.
## Espacio cerca de los mangos la agarra (Player.agarrar_carretilla) y otra vez la suelta: agarrada,
## el jugador trota de frente con las manos en los mangos (ManosMangos.gd) y la carretilla va detras de el,
## inclinada sobre la llanta; solo avanza y gira despacio. Suelta, se queda donde la dejaste, parada en sus
## patas. Es un Acompanante: los zombis le pegan a ella igual que a un escoltado (`recibir_golpe`, `cayo`);
## con `vida` 24 (dos golpes de zombi de 12) se muere el herido (Misiones.acompanante_cayo).
## Los modelos: models/props/carretilla (Lowpoly Wheelbarrow, Sketchfab) y el herido, uno de Civiles
## (por defecto la viejita `mujer_29`) con el clip "Sitting_Idle", acomodado como en la foto de JJ.

const MODELO := preload("res://models/props/carretilla/carretilla.scn")
## El herido, de entre las personas mayores del pack (Civiles.MODELOS); el primero es la viejita
const HERIDOS := ["mujer_29", "mujer_29", "hombre_30", "mujer_31", "hombre_32", "mujer_32"]

## El modelo mide 2 m de largo: al 80% queda de 1.6 m, como una de verdad. Sus mangos van hacia +Z
const ESCALA_CARRETILLA := 0.8
## En el marco del modelo ya escalado: el eje de la llanta y donde se agarran los mangos (x = ±)
const EJE := Vector3(0.0, 0.17, -0.54)
const MANGO := Vector3(0.22, 0.46, 0.76)
## El herido (la foto de JJ): sentado en la tina, echado hacia atras con la cabeza recargada en el borde del
## lado de la llanta y las piernas por encima del borde, hacia los mangos
const ASIENTO := Vector3(0.0, 0.47, 0.55)
const ESCALA_HERIDO := 1.0
const RECLINADO := 64.0
## Grados que se estiran las rodillas (Rodillas): suben los pies para que no atraviesen el borde de la tina
const RODILLAS := -18.0
## Agarrada: a que altura van los mangos (m sobre el piso) y que tan atras del centro del jugador
const MANOS_ALTO := 1.0
const MANOS_ATRAS := -0.15
const ALCANCE := 1.6           # m del jugador a los mangos para poder agarrarla
const VEL_MAX := 30.0          # m/s: agarrada llega a donde va en un cuadro (con resorte se quedaba atras y las manos se despegaban)
const LEJOS := 2.5             # m: agarrada y mas lejos que esto de donde va, aparece ahi (se atoro)

var agarrada := false
var asiento: Node3D           # el herido cuelga de aqui
var _inclina: Node3D           # gira sobre el eje de la llanta: sube los mangos al agarrarla
var _herido := ""


static func crear_carretilla(padre: Node, donde: Vector3, herido: String, con_vida: int, vida_total: int) -> Carretilla:
	var c := Carretilla.new()
	c.quieto = true
	c.atrae = 0.0
	c.vida = con_vida
	c.vida_max = vida_total
	c._herido = herido if herido != "" else HERIDOS.pick_random()
	padre.add_child(c)
	c.global_position = donde
	c._mirar_al_jugador()
	return c


## Tambien se puede poner suelta en una escena (la safehouse, para probarla): se arma sola
func _ready() -> void:
	super()
	_armar()


func _armar() -> void:
	if _herido == "":
		_herido = HERIDOS[0]
	add_to_group("interactuable")
	# Despues del jugador: se acomoda a donde ya quedo el en este cuadro
	process_physics_priority = 10
	cayo.connect(soltar)
	# Todo cuelga de un nodo en el eje de la llanta, para inclinarla sin que se separen
	_inclina = Node3D.new()
	_inclina.position = EJE
	add_child(_inclina)
	var modelo := MODELO.instantiate() as Node3D
	modelo.scale = Vector3.ONE * ESCALA_CARRETILLA
	modelo.position = -EJE
	_inclina.add_child(modelo)
	asiento = Node3D.new()
	asiento.position = ASIENTO - EJE
	asiento.rotation = Vector3(deg_to_rad(RECLINADO), PI, 0.0)
	asiento.scale = Vector3.ONE * ESCALA_HERIDO
	_inclina.add_child(asiento)
	_animacion = Civiles.poner(asiento, _herido, "Sitting_Idle")
	var esqueletos := asiento.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		var rodillas := Rodillas.new()
		rodillas.name = "Rodillas"
		rodillas.grados = RODILLAS
		esqueletos[0].add_child(rodillas)
	_clip = ""
	_poner_clip("Sitting_Idle")


func _mirar_al_jugador() -> void:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador:
		var hacia := _jugador.global_position - global_position
		hacia.y = 0.0
		if hacia.length() > 0.1:
			rotation.y = atan2(hacia.x, hacia.z)


func _exit_tree() -> void:
	soltar()
	super()


## Donde se agarra el mango (global): 0 = el de la izquierda del jugador, 1 = el de la derecha
func mango(lado: int) -> Vector3:
	return _inclina.global_transform * (Vector3(MANGO.x if lado == 0 else -MANGO.x, MANGO.y, MANGO.z) - EJE)


## Para el Espacio del jugador (Player._nearby_interactable): cerca de los mangos y sin el herido muerto
func is_player_inside() -> bool:
	if _cayo or agarrada or _jugador == null:
		return false
	var punto := (mango(0) + mango(1)) / 2.0
	return Vector2(punto.x, punto.z).distance_to(Vector2(_jugador.global_position.x, _jugador.global_position.z)) <= ALCANCE


func interact() -> void:
	if _cayo or agarrada or _jugador == null or not _jugador.has_method("agarrar_carretilla"):
		return
	agarrada = true
	_jugador.agarrar_carretilla(self)


func soltar() -> void:
	if not agarrada:
		return
	agarrada = false
	if is_instance_valid(_jugador) and _jugador.get("carretilla") == self:
		_jugador.soltar_carretilla()


# El modelo del jugador se dibuja suavizado entre cuadros de fisica (Player._process): agarrada, la carretilla
# se dibuja con el mismo desfase para que los mangos no se le adelanten ni se le queden a las manos
func _process(_delta: float) -> void:
	if _inclina == null:
		return
	var desfase := Vector3.ZERO
	if agarrada and is_instance_valid(_jugador):
		var figura := _jugador.get_node_or_null("Frijol") as Node3D
		var base = _jugador.get("_frijol_base")
		if figura and base is Vector3:
			desfase = figura.global_position - _jugador.to_global(base)
	_inclina.global_position = to_global(EJE) + desfase


func _physics_process(delta: float) -> void:
	if _cayo or _jugador == null:
		return
	# Inclinada sobre la llanta mientras la llevas: los mangos a la altura de las manos
	var inclina := 0.0
	if agarrada:
		var brazo := Vector2(MANGO.z - EJE.z, MANGO.y - EJE.y)
		inclina = asin(clampf((MANOS_ALTO - EJE.y) / brazo.length(), -1.0, 1.0)) - atan2(brazo.y, brazo.x)
	_inclina.rotation.x = lerp_angle(_inclina.rotation.x, -inclina, clampf(10.0 * delta, 0.0, 1.0))
	if not agarrada:
		velocity = Vector3(0.0, velocity.y - GRAVEDAD * delta if not is_on_floor() else 0.0, 0.0)
		move_and_slide()
		return
	# Detras del jugador, con los mangos hacia el: el cuerpo ve hacia donde el ve
	var figura := _jugador.get_node_or_null("Frijol") as Node3D
	var frente := -(figura if figura else _jugador).global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	rotation.y = atan2(frente.x, frente.z)
	var alcance := EJE.z + Vector2(MANGO.z - EJE.z, MANGO.y - EJE.y).length() * cos(inclina)
	var meta := _jugador.global_position - frente * (alcance + MANOS_ATRAS)
	var falta := meta - global_position
	falta.y = 0.0
	if falta.length() > LEJOS:
		global_position = Vector3(meta.x, global_position.y, meta.z)
		velocity = Vector3.ZERO
		return
	var quiere := falta / maxf(delta, 0.0001)
	if quiere.length() > VEL_MAX:
		quiere = quiere.normalized() * VEL_MAX
	velocity.x = quiere.x
	velocity.z = quiere.z
	velocity.y = velocity.y - GRAVEDAD * delta if not is_on_floor() else 0.0
	move_and_slide()


## Las rodillas del herido un poco estiradas encima del clip sentado: los pies suben y pasan por encima del borde
class Rodillas extends SkeletonModifier3D:
	const ESPINILLAS := ["LeftLowerLeg", "RightLowerLeg"]
	var grados := 0.0

	func _process_modification_with_delta(_delta: float) -> void:
		var esqueleto := get_skeleton()
		if esqueleto == null or absf(grados) < 0.01:
			return
		for nombre: String in ESPINILLAS:
			var i := esqueleto.find_bone(nombre)
			if i < 0:
				continue
			var global := esqueleto.get_bone_global_pose(i)
			var nuevo := Basis(Vector3.RIGHT, deg_to_rad(grados)) * global.basis
			var padre := esqueleto.get_bone_parent(i)
			var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
			esqueleto.set_bone_pose_rotation(i, (base.inverse() * nuevo).get_rotation_quaternion())
