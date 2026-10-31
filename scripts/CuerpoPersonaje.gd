extends SkeletonModifier3D

# La complexion y la cabeza del personaje (Personaje.vestir), encima de lo que pose la animacion.
# El tronco se ensancha desde la cadera; lo que sale de el (cuello, hombros, piernas) se encoge
# al reves para que brazos, piernas y cabeza no se inflen con el.

const TRONCO := "Hips"
const SALEN := ["Neck", "Shoulder.L", "Shoulder.R", "UpperLeg.L", "UpperLeg.R"]

var ancho := 1.0
var cabeza := 1.0


func _process_modification_with_delta(_delta: float) -> void:
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	_escalar(esqueleto, TRONCO, Vector3(ancho, 1.0, ancho))
	var contra := 1.0 / ancho
	for hueso: String in SALEN:
		_escalar(esqueleto, hueso, Vector3(contra, 1.0, contra))
	_escalar(esqueleto, "Head", Vector3.ONE * cabeza)


func _escalar(esqueleto: Skeleton3D, hueso: String, escala: Vector3) -> void:
	var i := esqueleto.find_bone(hueso)
	if i >= 0:
		esqueleto.set_bone_pose_scale(i, esqueleto.get_bone_pose_scale(i) * escala)
