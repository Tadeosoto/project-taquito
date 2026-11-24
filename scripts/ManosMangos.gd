extends SkeletonModifier3D

# Las dos manos en los mangos de la carretilla (Carretilla.gd, M5 "Al medico"), encima de lo que
# pose la animacion: el jugador trota (Jog_Fwd) y los brazos se quedan pegados a los mangos, que van
# atras de el. Cada brazo es un IK de dos huesos (brazo y antebrazo) hacia su mango; el codo se
# queda en el plano en que lo puso la animacion, jalado hacia afuera y para atras (no se dobla
# hacia el cuerpo). La mano conserva el giro de la animacion. Antes, el pecho y las clavículas regresan a su
# pose de reposo: con el balanceo del trote el hombro se iba de 0.41 a 0.68 m del mango (el brazo mide 0.53)
# y las manos se despegaban.

const LADOS := [["LeftUpperArm", "LeftLowerArm", "LeftHand"], ["RightUpperArm", "RightLowerArm", "RightHand"]]
const CODO_AFUERA := 0.25       # cuanto se jala el codo hacia afuera (fraccion del brazo)
const QUIETOS := ["Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder"]
const ALCANZA := 0.97           # del largo del brazo: mas lejos que esto la columna se echa para atras
const ECHA_MAX := 25.0          # grados que se puede echar para atras

var peso := 0.0                 # 0-1: cuanto quieres
var mangos := [Vector3.ZERO, Vector3.ZERO]   # izquierdo, derecho (globales)
var rapidez := 6.0              # por segundo
var _actual := 0.0


func _process_modification_with_delta(delta: float) -> void:
	_actual = move_toward(_actual, peso, rapidez * delta)
	if _actual < 0.001:
		return
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for nombre: String in QUIETOS:
		var i := esqueleto.find_bone(nombre)
		if i >= 0:
			var reposo := esqueleto.get_bone_rest(i).basis.get_rotation_quaternion()
			esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(reposo, _actual))
	var al_esqueleto := esqueleto.global_transform.affine_inverse()
	_echar_atras(esqueleto, al_esqueleto)
	for lado in 2:
		var brazo := esqueleto.find_bone(LADOS[lado][0])
		var antebrazo := esqueleto.find_bone(LADOS[lado][1])
		var mano := esqueleto.find_bone(LADOS[lado][2])
		if brazo < 0 or antebrazo < 0 or mano < 0:
			continue
		var a := esqueleto.get_bone_global_pose(brazo).origin
		var b := esqueleto.get_bone_global_pose(antebrazo).origin
		var c := esqueleto.get_bone_global_pose(mano).origin
		var meta := c.lerp(al_esqueleto * mangos[lado], _actual)
		var l1 := a.distance_to(b)
		var l2 := b.distance_to(c)
		if l1 < 0.0001 or l2 < 0.0001:
			continue
		var hacia := meta - a
		var d := clampf(hacia.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var u := hacia.normalized()
		# Afuera: del centro del cuerpo hacia el hombro (en x del esqueleto)
		var afuera := Vector3(signf(a.x) if absf(a.x) > 0.0001 else (1.0 if lado == 1 else -1.0), 0.0, 0.0)
		var polo := (b - a) + afuera * l1 * CODO_AFUERA
		var v := polo - u * polo.dot(u)
		if v.length_squared() < 0.000001:
			v = afuera - u * u.x
		v = v.normalized()
		var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
		var codo := a + u * l1 * cos_a + v * l1 * sqrt(1.0 - cos_a * cos_a)
		_apuntar(esqueleto, brazo, b - a, codo - a)
		var b2 := esqueleto.get_bone_global_pose(antebrazo).origin
		var c2 := esqueleto.get_bone_global_pose(mano).origin
		_apuntar(esqueleto, antebrazo, c2 - b2, (a + u * d) - b2)


# Si con el rebote del trote un mango queda fuera del alcance, la columna se echa para atras (hacia la
# carretilla) lo que falte, hasta ECHA_MAX: asi las manos no se despegan
func _echar_atras(esqueleto: Skeleton3D, al_esqueleto: Transform3D) -> void:
	var columna := esqueleto.find_bone("Spine")
	if columna < 0:
		return
	var sobra := 0.0
	var alto := 0.0
	for lado in 2:
		var brazo := esqueleto.find_bone(LADOS[lado][0])
		var antebrazo := esqueleto.find_bone(LADOS[lado][1])
		var mano := esqueleto.find_bone(LADOS[lado][2])
		if brazo < 0 or antebrazo < 0 or mano < 0:
			return
		var a := esqueleto.get_bone_global_pose(brazo).origin
		var largo := a.distance_to(esqueleto.get_bone_global_pose(antebrazo).origin) \
				+ esqueleto.get_bone_global_pose(antebrazo).origin.distance_to(esqueleto.get_bone_global_pose(mano).origin)
		sobra = maxf(sobra, a.distance_to(al_esqueleto * mangos[lado]) - largo * ALCANZA)
		alto = maxf(alto, a.distance_to(esqueleto.get_bone_global_pose(columna).origin))
	if sobra <= 0.0 or alto < 0.0001:
		return
	var angulo := minf(sobra / alto, deg_to_rad(ECHA_MAX)) * _actual
	var global := esqueleto.get_bone_global_pose(columna)
	var nuevo := Basis(Vector3.RIGHT, -angulo) * global.basis
	var padre := esqueleto.get_bone_parent(columna)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(columna, (base.inverse() * nuevo).get_rotation_quaternion())


# Gira el hueso `i` (en el espacio del esqueleto) para que `de` quede apuntando hacia `a`
func _apuntar(esqueleto: Skeleton3D, i: int, de: Vector3, a: Vector3) -> void:
	if de.length_squared() < 0.000001 or a.length_squared() < 0.000001:
		return
	var global := esqueleto.get_bone_global_pose(i)
	var nuevo := Basis(Quaternion(de.normalized(), a.normalized())) * global.basis
	var padre := esqueleto.get_bone_parent(i)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(i, (base.inverse() * nuevo).get_rotation_quaternion())
