extends SkeletonModifier3D

# Las dos manos en la pistola al apuntar (Player._posar, character_animation.agarre), encima de lo
# que pose la animacion y de InclinarCuerpo (AG). El apuntado de Quaternius dejaba el canon
# chueco (hacia arriba y a la izquierda) y la izquierda abierta al lado del arma. Cada cuadro:
# 1. Endereza el canon hacia la mira girando antebrazo y muneca derechos (tope GIRO_MAX).
# 2. Lleva la muneca izquierda a AGARRE (en m, en el marco de la mira: lado, alto, frente desde
#    la muneca derecha) con un IK de dos huesos (brazo y antebrazo); el codo se queda en el plano
#    en que lo puso la animacion, jalado tantito hacia abajo.
# 3. Gira la mano izquierda en "taza" bajo la cacha: palma arriba, dedos envolviendo hacia la
#    derecha, pulgar al frente (MANO_IZQ_EJES, si el hueso trae otros ejes).
# En la corredera (recarga en seco, Pistola.rack) la izquierda va a `corredera` (un Marker3D
# atras y arriba de la corredera, que se mueve con ella) con la palma sobre ella, los dedos
# envolviendo a la derecha y el pulgar hacia atras; `apunta` 0 deja el arma como la pone el clip.

const BRAZO_DER := "RightLowerArm"
const MANO_DER := "RightHand"
const BRAZO := "LeftUpperArm"
const ANTEBRAZO := "LeftLowerArm"
const MANO := "LeftHand"
const CODO_ABAJO := 0.15        # cuanto se jala el codo izquierdo hacia abajo (fraccion del brazo)
const GIRO_MAX := 60.0          # grados que puede corregir el canon como mucho
const GIRO_ANTEBRAZO := 0.5     # parte del giro que hace el antebrazo; el resto, la muneca
# Muneca izquierda desde la derecha, en m: x = hacia la derecha del canon, y = arriba, z = al frente
const AGARRE := Vector3(-0.1, -0.10, 0.1)
# Ejes de la mano izquierda (en su hueso) que van al frente, a la derecha y arriba.
# Perfil humanoide en espejo: el pulgar sale por -X, los dedos por +Y, la palma por +Z
const MANO_IZQ_EJES := [Vector3.LEFT, Vector3.UP, Vector3.BACK]
# La muneca izquierda desde el punto de la corredera, en m (derecha, arriba, frente): la palma
# queda encima y los dedos bajan por el lado derecho
const RACK_MANO := Vector3(-0.05, 0.03, 0.0)

var peso := 0.0                 # 0-1: cuanto quieres
var apunta_a := Vector3.ZERO    # el punto de la mira, global
var canon_local := Vector3.LEFT # hacia donde sale el tiro, en el espacio del hueso RightHand
var rapidez := 8.0              # por segundo (~0.12 s)
var apunta := 1.0               # cuanto endereza el canon a la mira
var corredera: Node3D           # el punto de la corredera (Player._agarre_corredera)
var corredera_peso := 0.0       # 0-1: cuanto va la izquierda en la corredera
var _actual := 0.0


func _process_modification_with_delta(delta: float) -> void:
	_actual = move_toward(_actual, peso, rapidez * delta)
	if _actual < 0.001:
		return
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	var brazo_der := esqueleto.find_bone(BRAZO_DER)
	var mano_der := esqueleto.find_bone(MANO_DER)
	var brazo := esqueleto.find_bone(BRAZO)
	var antebrazo := esqueleto.find_bone(ANTEBRAZO)
	var mano := esqueleto.find_bone(MANO)
	if brazo_der < 0 or mano_der < 0 or brazo < 0 or antebrazo < 0 or mano < 0:
		return
	var al_esqueleto := esqueleto.global_transform.affine_inverse()
	var mira := al_esqueleto * apunta_a
	var escala := esqueleto.global_transform.basis.get_scale().x

	# 1. El canon hacia la mira: primero el antebrazo, luego la muneca
	for paso: Array in [[brazo_der, GIRO_ANTEBRAZO], [mano_der, 1.0]]:
		var pose := esqueleto.get_bone_global_pose(mano_der)
		var ahora := (pose.basis * canon_local).normalized()
		var quiere := (mira - pose.origin).normalized()
		var angulo := ahora.angle_to(quiere)
		if angulo < 0.001:
			break
		var cuanto: float = minf(1.0, deg_to_rad(GIRO_MAX) / angulo) * float(paso[1]) * _actual * apunta
		var giro := Quaternion.IDENTITY.slerp(Quaternion(ahora, quiere), cuanto)
		_girar(esqueleto, int(paso[0]), Basis(giro))

	# El marco de la mira desde la muneca derecha ya derecha
	var der := esqueleto.get_bone_global_pose(mano_der)
	var frente := (der.basis * canon_local).normalized()
	var arriba_mundo := (al_esqueleto.basis * Vector3.UP).normalized()
	var derecha := frente.cross(arriba_mundo).normalized()
	var arriba := derecha.cross(frente).normalized()
	var meta := der.origin + (derecha * AGARRE.x + arriba * AGARRE.y + frente * AGARRE.z) / escala
	var en_corredera := corredera_peso if corredera and is_instance_valid(corredera) and corredera.is_inside_tree() else 0.0
	if en_corredera > 0.0:
		var punto := al_esqueleto * corredera.global_position
		var sobre := punto + (derecha * RACK_MANO.x + arriba * RACK_MANO.y + frente * RACK_MANO.z) / escala
		meta = meta.lerp(sobre, en_corredera)

	# 2. IK del brazo izquierdo
	var a := esqueleto.get_bone_global_pose(brazo).origin
	var b := esqueleto.get_bone_global_pose(antebrazo).origin
	var c := esqueleto.get_bone_global_pose(mano).origin
	meta = c.lerp(meta, _actual)
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	if l1 < 0.0001 or l2 < 0.0001:
		return
	var hacia := meta - a
	var d := clampf(hacia.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := hacia.normalized()
	var polo := (b - a) + Vector3.DOWN * l1 * CODO_ABAJO
	var v := polo - u * polo.dot(u)
	if v.length_squared() < 0.000001:
		v = Vector3.DOWN - u * u.y
	v = v.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var codo := a + u * l1 * cos_a + v * l1 * sqrt(1.0 - cos_a * cos_a)
	_apuntar(esqueleto, brazo, b - a, codo - a)
	var b2 := esqueleto.get_bone_global_pose(antebrazo).origin
	var c2 := esqueleto.get_bone_global_pose(mano).origin
	_apuntar(esqueleto, antebrazo, c2 - b2, (a + u * d) - b2)

	# 3. La mano izquierda en taza: pulgar al frente, dedos a la derecha, palma arriba
	var actual := esqueleto.get_bone_global_pose(mano).basis.orthonormalized()
	var en_hueso := Basis(MANO_IZQ_EJES[0], MANO_IZQ_EJES[1], MANO_IZQ_EJES[2])
	var en_mira := Basis(frente, derecha, arriba)
	var quiere := en_mira * en_hueso.inverse()
	if en_corredera > 0.0:
		# Palma sobre la corredera, dedos a la derecha, pulgar hacia atras
		var sobre_corredera := Basis(-frente, derecha, -arriba) * en_hueso.inverse()
		quiere = Basis(quiere.get_rotation_quaternion().slerp(sobre_corredera.get_rotation_quaternion(), en_corredera))
	var nueva := Basis(actual.get_rotation_quaternion().slerp(quiere.get_rotation_quaternion(), _actual))
	var padre := esqueleto.get_bone_parent(mano)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(mano, (base.orthonormalized().inverse() * nueva).get_rotation_quaternion())


# Gira el hueso `i` por `giro` (en el espacio del esqueleto)
func _girar(esqueleto: Skeleton3D, i: int, giro: Basis) -> void:
	var global := esqueleto.get_bone_global_pose(i)
	var nuevo := giro * global.basis
	var padre := esqueleto.get_bone_parent(i)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(i, (base.inverse() * nuevo).get_rotation_quaternion())


# Gira el hueso `i` (en el espacio del esqueleto) para que `de` quede apuntando hacia `a`
func _apuntar(esqueleto: Skeleton3D, i: int, de: Vector3, a: Vector3) -> void:
	if de.length_squared() < 0.000001 or a.length_squared() < 0.000001:
		return
	_girar(esqueleto, i, Basis(Quaternion(de.normalized(), a.normalized())))
