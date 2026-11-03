extends SkeletonModifier3D

# El golpe del jugador como barrido de lado, encima de la animacion: el modelo solo trae Punch,
# una estocada al frente, y el efecto de la barrida va de lado. El brazo derecho se lleva
# estirado de atras a la derecha hasta adelante a la izquierda, y el torso lo acompana.
# Player.golpe() lo arranca; sin golpe no toca nada.

const BRAZO := ["UpperArm.R", "LowerArm.R", "Fist.R"]
const TORSO := "Torso"
# Tiempos en s desde que arranca. Al pegar (Player.ATAQUE_PEGA_EN, 0.22) el brazo pasa al frente
const PREPARA := 0.10     # lleva el brazo atras
const BARRE := 0.30       # termina de barrer
const SOSTIENE := 0.42    # se queda estirado
const SUELTA := 0.58      # regresa a la animacion
# Grados desde el frente, a la derecha positivos
const ATRAS := 110.0
const INICIO := 30.0
const FIN := -80.0
const TORSO_SIGUE := 0.35 # cuanto gira el torso con el brazo
const BAJA := 0.15        # el brazo va un poco hacia abajo
const ESTELA_DESDE := PREPARA # la estela va solo mientras barre, no al llevar el brazo atras
const ESTELA_HASTA := 0.33
const ESTELA_PASO := 6.0  # grados entre pedazos de la estela

var frijol: Node3D        # el cuerpo visible del jugador: de ahi salen el frente y la derecha
var estela: Node          # EstelaBarrido.gd, opcional
var largo := 0.6          # m de la mano a la punta de lo que traes
var _t := -1.0
var _angulo_antes := 0.0
var _delta_ultimo := 0.0


func golpe() -> void:
	_t = 0.0


func _process_modification_with_delta(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_delta_ultimo = delta
	if _t >= SUELTA:
		_t = -1.0
		return
	var esqueleto := get_skeleton()
	if esqueleto == null or frijol == null:
		return
	var angulo: float
	var peso := 1.0
	if _t < PREPARA:
		var f := _t / PREPARA
		angulo = lerpf(INICIO, ATRAS, ease(f, 0.5))
		peso = f
	elif _t < BARRE:
		angulo = lerpf(ATRAS, FIN, (_t - PREPARA) / (BARRE - PREPARA))
	else:
		angulo = FIN
		if _t > SOSTIENE:
			peso = 1.0 - (_t - SOSTIENE) / (SUELTA - SOSTIENE)
	# Del mundo al espacio del esqueleto, sin su escala
	var al_esqueleto := esqueleto.global_basis.orthonormalized().inverse()
	var frente := al_esqueleto * -frijol.global_basis.z
	var derecha := al_esqueleto * frijol.global_basis.x
	var arriba := al_esqueleto * Vector3.UP
	var torso := esqueleto.find_bone(TORSO)
	if torso >= 0:
		var pose := esqueleto.get_bone_global_pose(torso)
		var giro := Basis(arriba, -deg_to_rad(angulo) * TORSO_SIGUE * peso)
		esqueleto.set_bone_global_pose(torso, Transform3D(giro * pose.basis, pose.origin))
	var rad := deg_to_rad(angulo)
	var hacia := (frente * cos(rad) + derecha * sin(rad) - arriba * BAJA).normalized()
	for nombre: String in BRAZO:
		var hueso := esqueleto.find_bone(nombre)
		if hueso < 0:
			continue
		var pose := esqueleto.get_bone_global_pose(hueso)
		var vuelta := Quaternion(pose.basis.y.normalized(), hacia)
		var parcial := Quaternion.IDENTITY.slerp(vuelta, peso)
		esqueleto.set_bone_global_pose(hueso, Transform3D(Basis(parcial) * pose.basis, pose.origin))
	if estela and _t >= ESTELA_DESDE and _t <= ESTELA_HASTA:
		_dejar_estela(esqueleto, angulo, frente, derecha, arriba)
	_angulo_antes = angulo


# El arco entre el cuadro anterior y este, en pedazos de ESTELA_PASO grados: con pocos cuadros por
# segundo la estela salia en tiras rectas. Se calcula desde el hombro con el brazo estirado
func _dejar_estela(esqueleto: Skeleton3D, angulo: float, frente: Vector3, derecha: Vector3, arriba: Vector3) -> void:
	var hombro := esqueleto.find_bone(BRAZO[0])
	var puno := esqueleto.find_bone(BRAZO[-1])
	if hombro < 0 or puno < 0:
		return
	var desde := esqueleto.get_bone_global_pose(hombro).origin
	var brazo := desde.distance_to(esqueleto.get_bone_global_pose(puno).origin)
	var al_mundo := esqueleto.global_transform
	var antes := _angulo_antes if _t - _delta_ultimo > ESTELA_DESDE else angulo
	var pasos := maxi(ceili(absf(angulo - antes) / ESTELA_PASO), 1)
	for i in range(1, pasos + 1):
		var rad := deg_to_rad(lerpf(antes, angulo, float(i) / pasos))
		var hacia := (frente * cos(rad) + derecha * sin(rad) - arriba * BAJA).normalized()
		var mano := al_mundo * (desde + hacia * brazo)
		estela.agregar(mano, mano + al_mundo.basis.orthonormalized() * hacia * largo)
