extends SkeletonModifier3D

# Dobla la columna hacia adelante y baja la cadera doblando las rodillas, encima de lo que pose
# la animacion (character_animation.inclinar): corriendo con Shift a medio machetazo se agacha
# como embistiendo (JJ). Quaternius no trae un trote inclinado, y asi el barrido y el trote se
# siguen viendo, solo que agachado.

const COLUMNA := ["Spine", "Chest"]   # se reparte entre los dos para que se curve, no se quiebre
const PIERNAS := [["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"], ["RightUpperLeg", "RightLowerLeg", "RightFoot"]]
const CADERA := "Hips"
# Las rodillas se doblan RODILLA grados por cada grado de columna (muslo adelante, espinilla
# atras el doble, pie de regreso): asi el pie queda debajo y la cadera baja lo que se acortan
# las piernas, sin hundir los pies en el piso
const RODILLA := 0.75
# Los brazos se regresan lo que se doblo la columna (enderezar_brazos): a punetazos, inclinado,
# los punos le pegaban al piso; asi el golpe sale al frente aunque el cuerpo vaya agachado
const BRAZOS := ["LeftUpperArm", "RightUpperArm"]

var angulo := 0.0     # grados que quieres
var _actual := 0.0    # grados que lleva, para que entre y salga suave
var rapidez := 150.0  # grados por segundo
var brazos := 0.0     # 0-1: cuanto de la inclinacion se les quita a los brazos
var _brazos := 0.0    # lo que lleva, para que no brinquen


func _process_modification_with_delta(delta: float) -> void:
	_actual = move_toward(_actual, angulo, rapidez * delta)
	_brazos = move_toward(_brazos, brazos, 6.0 * delta)
	if absf(_actual) < 0.01:
		return
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	var a := deg_to_rad(_actual)
	# Rodillas: la cadera baja lo que suba el pie mas bajo al doblarlas, asi ese pie se queda en
	# el piso (las piernas del trote ya van dobladas y una cuenta con cosenos se quedaba corta)
	var rodilla := a * RODILLA
	var antes := _pie_mas_bajo(esqueleto)
	for pierna: Array in PIERNAS:
		var muslo := esqueleto.find_bone(pierna[0])
		var espinilla := esqueleto.find_bone(pierna[1])
		var pie := esqueleto.find_bone(pierna[2])
		if muslo < 0 or espinilla < 0 or pie < 0:
			continue
		_girar(esqueleto, muslo, -rodilla)
		_girar(esqueleto, espinilla, rodilla * 2.0)
		_girar(esqueleto, pie, -rodilla)
	var baja := _pie_mas_bajo(esqueleto) - antes
	var cadera := esqueleto.find_bone(CADERA)
	if cadera >= 0 and baja > 0.0:
		var padre := esqueleto.get_bone_parent(cadera)
		var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
		esqueleto.set_bone_pose_position(cadera, esqueleto.get_bone_pose_position(cadera) + base.inverse() * (Vector3.DOWN * baja))
	for nombre: String in COLUMNA:
		var i := esqueleto.find_bone(nombre)
		if i >= 0:
			_girar(esqueleto, i, a / COLUMNA.size())
	if _brazos > 0.0:
		for nombre: String in BRAZOS:
			var i := esqueleto.find_bone(nombre)
			if i >= 0:
				_girar(esqueleto, i, -a * _brazos)


func _pie_mas_bajo(esqueleto: Skeleton3D) -> float:
	var y := INF
	for pierna: Array in PIERNAS:
		var pie := esqueleto.find_bone(pierna[2])
		if pie >= 0:
			y = minf(y, esqueleto.get_bone_global_pose(pie).origin.y)
	return y if y < INF else 0.0


# Gira un hueso alrededor del eje de lado del esqueleto (X), en el espacio del esqueleto;
# positivo = hacia adelante (medido con la cabeza)
func _girar(esqueleto: Skeleton3D, i: int, angulo_rad: float) -> void:
	var global := esqueleto.get_bone_global_pose(i)
	var nuevo := Basis(Vector3.RIGHT, angulo_rad) * global.basis
	var padre := esqueleto.get_bone_parent(i)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(i, (base.inverse() * nuevo).get_rotation_quaternion())
