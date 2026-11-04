extends SkeletonModifier3D

# Como se sostiene la pistola (Pistola.gd), encima de la animacion, igual que el tajo de
# Barrido.gd: el ninja no trae animaciones de pistola, y las de Quaternius son de otro esqueleto
# (el retarget sigue pendiente, docs/especificaciones.md 10.2). Las piernas siguen con su
# animacion; los brazos y el torso se ponen en pose. Como en Fortnite:
# - sosteniendo: el brazo derecho con el codo abajo y la pistola al frente, un poco abajo;
# - apuntando (clic derecho, o recien disparaste desde la cadera): los dos brazos estirados
#   hacia la mira, la izquierda agarrando la derecha, y el torso inclinado con la altura;
# - cada tiro sube los brazos unos grados y regresan.
# Player le pasa cada cuadro sostiene, apunta y blanco; sin pistola el peso baja a 0 y no toca nada.

const BRAZO_D := ["UpperArm.R", "LowerArm.R", "Fist.R"]
const BRAZO_I := ["UpperArm.L", "LowerArm.L", "Fist.L"]
const TORSO := "Torso"
const CAMBIA := 8.0           # que tan rapido entra y sale cada pose (por segundo)
# Sosteniendo: direcciones del brazo (frente, derecha, arriba del personaje)
const SOSTIENE_BRAZO := Vector3(0.35, 0.15, -1.0)   # el codo pegado, abajo
const SOSTIENE_ANTEBRAZO := Vector3(1.0, -0.1, -0.25) # la pistola al frente, un poco abajo
# Apuntando
const TORSO_INCLINA := 0.5    # de lo que sube o baja la mira, lo que se inclina el torso
const TORSO_GIRA := 12.0      # grados que el torso gira a la izquierda, para que entren los dos brazos
const MANO_I_ATRAS := 0.06    # m: la izquierda agarra la derecha un poco atras del puno
const MANO_I_ABAJO := 0.05
const CODO_I := Vector3(0.0, -0.4, -1.0) # hacia donde se dobla el codo izquierdo (frente, derecha, arriba)
# Retroceso de cada tiro
const RETROCESO := 14.0       # grados que suben los brazos
const RETROCESO_DURA := 0.12  # s en regresar

var frijol: Node3D            # el cuerpo visible: de ahi salen el frente y la derecha
var sostiene := false
var apunta := false
var blanco := Vector3.ZERO    # a donde va la mira, en el mundo

var _peso := 0.0
var _peso_apunta := 0.0
var _retroceso := 0.0


func tiro() -> void:
	_retroceso = 1.0


func _process_modification_with_delta(delta: float) -> void:
	_peso = move_toward(_peso, 1.0 if sostiene else 0.0, CAMBIA * delta)
	_peso_apunta = move_toward(_peso_apunta, 1.0 if apunta and sostiene else 0.0, CAMBIA * delta)
	_retroceso = move_toward(_retroceso, 0.0, delta / RETROCESO_DURA)
	var esqueleto := get_skeleton()
	if _peso <= 0.0 or esqueleto == null or frijol == null:
		return
	# Del mundo al espacio del esqueleto, sin su escala
	var al_esqueleto := esqueleto.global_basis.orthonormalized().inverse()
	var frente := (al_esqueleto * -frijol.global_basis.z).normalized()
	var derecha := (al_esqueleto * frijol.global_basis.x).normalized()
	var arriba := (al_esqueleto * Vector3.UP).normalized()
	var meta := esqueleto.to_local(blanco)

	# El torso gira e inclina hacia la mira antes que los brazos, que salen de el
	var torso := esqueleto.find_bone(TORSO)
	var hombro := esqueleto.find_bone(BRAZO_D[0])
	if torso >= 0 and hombro >= 0:
		var hacia_mira := (meta - esqueleto.get_bone_global_pose(hombro).origin).normalized()
		var altura := asin(clampf(hacia_mira.dot(arriba), -1.0, 1.0))
		var pose := esqueleto.get_bone_global_pose(torso)
		var giro := Basis(arriba, deg_to_rad(TORSO_GIRA) * _peso_apunta * _peso) \
			* Basis(derecha, altura * TORSO_INCLINA * _peso_apunta * _peso)
		esqueleto.set_bone_global_pose(torso, Transform3D(giro * pose.basis, pose.origin))

	# Brazo derecho: de sostener a estirado hacia la mira
	var origen := esqueleto.get_bone_global_pose(hombro).origin if hombro >= 0 else Vector3.ZERO
	var mira := (meta - origen).normalized()
	var alzado := Basis(derecha, deg_to_rad(RETROCESO) * ease(_retroceso, 0.4))
	mira = alzado * mira
	var sostiene_brazo := _en(SOSTIENE_BRAZO, frente, derecha, arriba)
	var sostiene_antebrazo := alzado * _en(SOSTIENE_ANTEBRAZO, frente, derecha, arriba)
	_apuntar(esqueleto, BRAZO_D[0], sostiene_brazo.slerp(mira, _peso_apunta), _peso)
	for nombre: String in BRAZO_D.slice(1):
		_apuntar(esqueleto, nombre, sostiene_antebrazo.slerp(mira, _peso_apunta), _peso)

	# Brazo izquierdo: solo apuntando, con el codo doblado hasta la mano derecha
	if _peso_apunta <= 0.0:
		return
	var puno_d := esqueleto.find_bone(BRAZO_D[2])
	var huesos_i: Array[int] = []
	for nombre: String in BRAZO_I:
		huesos_i.append(esqueleto.find_bone(nombre))
	if puno_d < 0 or huesos_i.has(-1):
		return
	# El esqueleto del ninja es diminuto y escalado: los metros se pasan a su escala
	var metro := 1.0 / maxf(esqueleto.global_basis.get_scale().x, 0.0001)
	var agarre := esqueleto.get_bone_global_pose(puno_d).origin - (mira * MANO_I_ATRAS + arriba * MANO_I_ABAJO) * metro
	var desde := esqueleto.get_bone_global_pose(huesos_i[0]).origin
	var codo := esqueleto.get_bone_global_pose(huesos_i[1]).origin
	var muneca := esqueleto.get_bone_global_pose(huesos_i[2]).origin
	var largo_a := desde.distance_to(codo)
	var largo_b := codo.distance_to(muneca)
	var a_codo := _codo(desde, agarre, largo_a, largo_b, _en(CODO_I, frente, derecha, arriba))
	var peso := _peso * _peso_apunta
	_apuntar(esqueleto, BRAZO_I[0], a_codo, peso)
	var codo_nuevo := esqueleto.get_bone_global_pose(huesos_i[1]).origin
	var antebrazo := (agarre - codo_nuevo).normalized()
	_apuntar(esqueleto, BRAZO_I[1], antebrazo, peso)
	_apuntar(esqueleto, BRAZO_I[2], antebrazo, peso)


# Una direccion dada en (frente, derecha, arriba) del personaje
func _en(v: Vector3, frente: Vector3, derecha: Vector3, arriba: Vector3) -> Vector3:
	return (frente * v.x + derecha * v.y + arriba * v.z).normalized()


# Gira el hueso para que su eje Y (a lo largo del hueso) vaya hacia `hacia`, como Barrido.gd
func _apuntar(esqueleto: Skeleton3D, nombre: String, hacia: Vector3, peso: float) -> void:
	var hueso := esqueleto.find_bone(nombre)
	if hueso < 0 or hacia.length_squared() < 0.0001:
		return
	var pose := esqueleto.get_bone_global_pose(hueso)
	var vuelta := Quaternion(pose.basis.y.normalized(), hacia.normalized())
	var parcial := Quaternion.IDENTITY.slerp(vuelta, peso)
	esqueleto.set_bone_global_pose(hueso, Transform3D(Basis(parcial) * pose.basis, pose.origin))


# Hacia donde va el brazo para que, con el codo doblado hacia `polo`, la mano llegue a `meta`
# (ley de cosenos); si no alcanza, estirado hacia ella
func _codo(desde: Vector3, meta: Vector3, a: float, b: float, polo: Vector3) -> Vector3:
	var recta := meta - desde
	var d := clampf(recta.length(), 0.001, a + b - 0.001)
	var hacia := recta.normalized()
	var coseno := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var lado := (polo - hacia * polo.dot(hacia))
	if lado.length_squared() < 0.0001:
		return hacia
	lado = lado.normalized()
	var angulo := acos(coseno)
	return (hacia * cos(angulo) + lado * sin(angulo)).normalized()
