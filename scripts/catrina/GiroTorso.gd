extends SkeletonModifier3D

# La Mojiganga voltea como un cuerpo pesado (AG: giraba como estatua sobre su eje): el pecho,
# el cuello y la cabeza se adelantan hacia donde voltea y la cadera los sigue. Catrina._girar
# pone `angulo` (radianes, positivo = a su izquierda, como rotation.y) segun lo rapido que gira.
# Va antes de los resortes (Catrina._resortes) para que la trenza siga al cuerpo torcido.

# Cuanto del giro se lleva cada hueso, de la cintura a la cabeza (suman 1)
const REPARTO := [["mixamorig_Spine", 0.15], ["mixamorig_Spine1", 0.2], ["mixamorig_Spine2", 0.25],
	["mixamorig_Neck", 0.15], ["mixamorig_Head", 0.25]]

var angulo := 0.0     # radianes que quieres
var _actual := 0.0    # lo que lleva, para que entre y salga suave
var rapidez := 3.0    # radianes por segundo


func _process_modification_with_delta(delta: float) -> void:
	_actual = move_toward(_actual, angulo, rapidez * delta)
	if absf(_actual) < 0.001:
		return
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for par: Array in REPARTO:
		var i := esqueleto.find_bone(par[0])
		if i >= 0:
			_torcer(esqueleto, i, _actual * par[1])


# Gira un hueso alrededor del eje vertical del esqueleto (Y), en el espacio del esqueleto
func _torcer(esqueleto: Skeleton3D, i: int, angulo_rad: float) -> void:
	var global := esqueleto.get_bone_global_pose(i)
	var nuevo := Basis(Vector3.UP, angulo_rad) * global.basis
	var padre := esqueleto.get_bone_parent(i)
	var base := esqueleto.get_bone_global_pose(padre).basis if padre >= 0 else Basis()
	esqueleto.set_bone_pose_rotation(i, (base.inverse() * nuevo).get_rotation_quaternion())
