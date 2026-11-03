extends SkeletonModifier3D

# El golpe del jugador como tajo en diagonal, encima de la animacion: el modelo solo trae Punch,
# una estocada al frente. El brazo derecho se lleva estirado de arriba atras a la derecha hasta
# abajo adelante a la izquierda, y el torso lo acompana. El de regreso del combo baja de la
# izquierda a la derecha, asi que dos golpes seguidos dibujan una X.
# Player.golpe() lo arranca; sin golpe no toca nada.

const BRAZO := ["UpperArm.R", "LowerArm.R", "Fist.R"]
const TORSO := "Torso"
# Tiempos en s desde que arranca. Al pegar (Player.ATAQUE_PEGA_EN, 0.22) el brazo pasa al frente
const PREPARA := 0.10     # lleva el brazo atras
const BARRE := 0.30       # termina de barrer
const SOSTIENE := 0.42    # se queda estirado
const SUELTA := 0.58      # regresa a la animacion
# Grados desde el frente, a la derecha positivos, para el primer golpe del combo; el segundo es
# el mismo al reves (de izquierda a derecha)
const ATRAS := 110.0
const INICIO := 30.0
const FIN := -80.0
const TORSO_SIGUE := 0.35 # cuanto gira el torso con el brazo
# Que tan arriba va el brazo (componente vertical de su direccion; 1 = 45 grados): empieza arriba,
# a la altura de la cabeza al pasar por el frente, y termina abajo
const ALTO_INICIO := 1.2
const ALTO_FIN := -0.3
const TORSO_INCLINA := 10.0 # grados que el torso se ladea con el brazo: el hombro sube con el
const ESTELA_DESDE := PREPARA # la estela va solo mientras barre, no al llevar el brazo atras
const ESTELA_HASTA := 0.33
const ESTELA_PASO := 6.0  # grados entre pedazos de la estela

var frijol: Node3D        # el cuerpo visible del jugador: de ahi salen el frente y la derecha
var estela: Node          # EstelaBarrido.gd, opcional
var largo := 0.6          # m de la mano a la punta de lo que traes
var _t := -1.0
var _lado := 1.0
var _desde := INICIO      # angulo de donde arranca a preparar
var _peso_desde := 0.0
var _peso := 0.0
var _angulo_antes := 0.0
var _alto_desde := ALTO_INICIO
var _alto_antes := ALTO_INICIO
var _delta_ultimo := 0.0
var _soltando := false


# `lado` 1: de la derecha a la izquierda (primer golpe del combo); -1: de regreso
# Si el anterior no ha terminado, sigue desde donde quedo el brazo, sin regresarlo al cuerpo
func golpe(lado := 1.0) -> void:
	if _t >= 0.0:
		_desde = _angulo_antes
		_alto_desde = _alto_antes
		_peso_desde = _peso
	else:
		_desde = INICIO * lado
		_alto_desde = ALTO_INICIO
		_peso_desde = 0.0
	_t = 0.0
	_lado = lado
	_soltando = false


# Regresa el brazo a la animacion desde donde va, sin terminar el barrido (Player._soltar_combo)
func soltar() -> void:
	if _t >= 0.0:
		_soltando = true


func _process_modification_with_delta(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_delta_ultimo = delta
	if _t >= SUELTA:
		_t = -1.0
		_peso = 0.0
		return
	var esqueleto := get_skeleton()
	if esqueleto == null or frijol == null:
		return
	var angulo: float
	var alto := ALTO_FIN
	var peso := 1.0
	if _soltando:
		angulo = _angulo_antes
		alto = _alto_antes
		peso = _peso - delta / (SUELTA - SOSTIENE)
		if peso <= 0.0:
			_t = -1.0
			_peso = 0.0
			_soltando = false
			return
	elif _t < PREPARA:
		var f := _t / PREPARA
		angulo = lerpf(_desde, ATRAS * _lado, ease(f, 0.5))
		alto = lerpf(_alto_desde, ALTO_INICIO, ease(f, 0.5))
		peso = lerpf(_peso_desde, 1.0, f)
	elif _t < BARRE:
		var f := (_t - PREPARA) / (BARRE - PREPARA)
		angulo = lerpf(ATRAS, FIN, f) * _lado
		alto = lerpf(ALTO_INICIO, ALTO_FIN, f)
	else:
		angulo = FIN * _lado
		if _t > SOSTIENE:
			peso = 1.0 - (_t - SOSTIENE) / (SUELTA - SOSTIENE)
	_peso = peso
	# Del mundo al espacio del esqueleto, sin su escala
	var al_esqueleto := esqueleto.global_basis.orthonormalized().inverse()
	var frente := al_esqueleto * -frijol.global_basis.z
	var derecha := al_esqueleto * frijol.global_basis.x
	var arriba := al_esqueleto * Vector3.UP
	var torso := esqueleto.find_bone(TORSO)
	if torso >= 0:
		var pose := esqueleto.get_bone_global_pose(torso)
		var giro := Basis(arriba, -deg_to_rad(angulo) * TORSO_SIGUE * peso) \
			* Basis(frente, -deg_to_rad(TORSO_INCLINA) * alto * peso)
		esqueleto.set_bone_global_pose(torso, Transform3D(giro * pose.basis, pose.origin))
	var hacia := _direccion(angulo, alto, frente, derecha, arriba)
	for nombre: String in BRAZO:
		var hueso := esqueleto.find_bone(nombre)
		if hueso < 0:
			continue
		var pose := esqueleto.get_bone_global_pose(hueso)
		var vuelta := Quaternion(pose.basis.y.normalized(), hacia)
		var parcial := Quaternion.IDENTITY.slerp(vuelta, peso)
		esqueleto.set_bone_global_pose(hueso, Transform3D(Basis(parcial) * pose.basis, pose.origin))
	if estela and not _soltando and _t >= ESTELA_DESDE and _t <= ESTELA_HASTA:
		_dejar_estela(esqueleto, angulo, alto, frente, derecha, arriba)
	_angulo_antes = angulo
	_alto_antes = alto


# Hacia donde apunta el brazo, en el espacio del esqueleto
func _direccion(angulo: float, alto: float, frente: Vector3, derecha: Vector3, arriba: Vector3) -> Vector3:
	var rad := deg_to_rad(angulo)
	return (frente * cos(rad) + derecha * sin(rad) + arriba * alto).normalized()


# El arco entre el cuadro anterior y este, en pedazos de ESTELA_PASO grados: con pocos cuadros por
# segundo la estela salia en tiras rectas. Se calcula desde el hombro con el brazo estirado
func _dejar_estela(esqueleto: Skeleton3D, angulo: float, alto: float, frente: Vector3, derecha: Vector3, arriba: Vector3) -> void:
	var hombro := esqueleto.find_bone(BRAZO[0])
	var puno := esqueleto.find_bone(BRAZO[-1])
	if hombro < 0 or puno < 0:
		return
	var desde := esqueleto.get_bone_global_pose(hombro).origin
	var brazo := desde.distance_to(esqueleto.get_bone_global_pose(puno).origin)
	var al_mundo := esqueleto.global_transform
	var sigue := _t - _delta_ultimo > ESTELA_DESDE
	var antes := _angulo_antes if sigue else angulo
	var alto_antes := _alto_antes if sigue else alto
	var pasos := maxi(ceili(absf(angulo - antes) / ESTELA_PASO), 1)
	for i in range(1, pasos + 1):
		var f := float(i) / pasos
		var hacia := _direccion(lerpf(antes, angulo, f), lerpf(alto_antes, alto, f), frente, derecha, arriba)
		var mano := al_mundo * (desde + hacia * brazo)
		estela.agregar(mano, mano + al_mundo.basis.orthonormalized() * hacia * largo)
