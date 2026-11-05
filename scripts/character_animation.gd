extends Node3D
# Las animaciones del protagonista (scenes/protagonista.tscn, el_compa del pack PSX). Son las de
# Quaternius (UAL1 y UAL2, CC0) pasadas a sus huesos con el retarget de Godot: todos los modelos
# quedan con los huesos de SkeletonProfileHumanoid en un %GeneralSkeleton
# (tools/personajes/mapas_huesos.gd) y tools/personajes/animaciones.gd junta los clips en
# resources/personajes/animaciones_humanas.res.
#
# Un AnimationTree armado aqui, de abajo hacia arriba:
#   pies (quieto, trote, carrera, carga, aire) a la velocidad a la que caminas
#   + la pistola solo de la cintura para arriba: sostenerla, o apuntar segun la camara
#   + recargar (cintura para arriba)
#   + una accion de todo el cuerpo: los machetazos, recibir un golpe
#   + caido (Death01 se queda en el piso)
# Player.gd le habla por accion(), golpe(), pistola(), update_animation()...

const BIBLIOTECA := preload("res://resources/personajes/animaciones_humanas.res")
const LIB := "h"
const MEZCLA_PIES := 0.15     # s de un modo de caminar a otro
const TROTE_VEL := 4.0        # m/s a los que el trote se ve a su velocidad
const CARRERA_VEL := 8.0
const PASO_MIN := 0.8         # de la velocidad del clip: mas rapido parecia caricatura
const PASO_MAX := 1.6
# Apuntar: la inclinacion de la camara (grados) que corresponde a Pistol_Aim_Up / _Down
const MIRA_ARRIBA := 40.0
const MIRA_ABAJO := 50.0
const PATADA := 0.22          # de la mira que sube el arma en cada tiro
const PATADA_BAJA := 2.0      # por segundo
const RECARGA_DURA := 1.5     # s (Pistola.RECARGA); el clip dura 1.67
# Los dos machetazos del combo, cada uno al reves del otro: A de derecha a izquierda, B de regreso.
# Pasan por enfrente a los 0.23 s, como Player.ATAQUE_PEGA_EN
const GOLPE_DERECHA := "Sword_Regular_A"
const GOLPE_IZQUIERDA := "Sword_Regular_B"
const ACCIONES := {
	"golpe_a": GOLPE_DERECHA,
	"golpe_b": GOLPE_IZQUIERDA,
	"herido": "Hit_Chest",
	"recoger": "PickUp_Table",
}
# Lo que antes pedia Player con los nombres del ninja
const PISTAS := {"RecieveHit": "herido", "Punch": "golpe_a", "PickUp": "recoger"}
const BUCLES := ["Idle", "Jog_Fwd", "Sprint", "Walk_Carry", "Jump", "Pistol_Idle",
	"Pistol_Aim_Up", "Pistol_Aim_Neutral", "Pistol_Aim_Down"]
# De la cintura para arriba (la pistola y recargar); las piernas siguen caminando
const ARRIBA := ["Spine", "Chest", "UpperChest", "Neck", "Head"]
const ARRIBA_LADOS := ["Shoulder", "UpperArm", "LowerArm", "Hand", "IndexProximal",
	"IndexIntermediate", "IndexDistal"]

# Trae algo en las manos: camina distinto (Player.cargar)
var cargando := false

var _arbol: AnimationTree
var _accion_nodo: AnimationNodeOneShot  # su filtro (parte de arriba) se prende al caminar golpeando
var _patada := 0.0
var _mira := 0.0
# El machetazo que va: el clip y cuanto lleva (lo lee la estela del arma)
var _golpe_clip := ""
var _golpe_t := -1.0


func _ready() -> void:
	var reproductor := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if reproductor == null:
		reproductor = AnimationPlayer.new()
		add_child(reproductor)
	for nombre in BUCLES:
		if BIBLIOTECA.has_animation(nombre):
			BIBLIOTECA.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	if not reproductor.has_animation_library(LIB):
		reproductor.add_animation_library(LIB, BIBLIOTECA)
	_arbol = AnimationTree.new()
	_arbol.name = "Arbol"
	add_child(_arbol)
	_arbol.anim_player = _arbol.get_path_to(reproductor)
	_arbol.root_node = _arbol.get_path_to(self)
	_arbol.tree_root = _armar_arbol()
	_arbol.active = true
	# Las transiciones empiezan sin estado: sin esto todo sale en pose T
	for inicio: Array in [["pies", "quieto"], ["apunta", "sostiene"], ["cual", "golpe_a"], ["estado", "vivo"]]:
		_arbol.set("parameters/%s/transition_request" % inicio[0], inicio[1])
	process_priority = 100


func _armar_arbol() -> AnimationNodeBlendTree:
	var raiz := AnimationNodeBlendTree.new()
	var arriba := _filtro_arriba()

	var pies := AnimationNodeTransition.new()
	pies.xfade_time = MEZCLA_PIES
	for entrada in ["quieto", "trote", "carrera", "carga", "aire"]:
		pies.add_input(entrada)
	raiz.add_node("pies", pies)
	_clip(raiz, "c_quieto", "Idle", "pies", 0)
	_clip(raiz, "c_trote", "Jog_Fwd", "pies", 1)
	_clip(raiz, "c_carrera", "Sprint", "pies", 2)
	_clip(raiz, "c_carga", "Walk_Carry", "pies", 3)
	_clip(raiz, "c_aire", "Jump", "pies", 4)
	raiz.add_node("paso", AnimationNodeTimeScale.new())
	raiz.connect_node("paso", 0, "pies")

	# La pistola: sostenerla abajo, o apuntar con la mira (arriba, al frente, abajo)
	var mira := AnimationNodeBlendSpace1D.new()
	mira.min_space = -1.0
	mira.max_space = 1.0
	for punto: Array in [["Pistol_Aim_Down", -1.0], ["Pistol_Aim_Neutral", 0.0], ["Pistol_Aim_Up", 1.0]]:
		var nodo := AnimationNodeAnimation.new()
		nodo.animation = LIB + "/" + punto[0]
		mira.add_blend_point(nodo, punto[1], -1, punto[0])
	raiz.add_node("mira", mira)
	var apunta := AnimationNodeTransition.new()
	apunta.xfade_time = 0.12
	apunta.add_input("sostiene")
	apunta.add_input("apunta")
	raiz.add_node("apunta", apunta)
	_clip(raiz, "c_sostiene", "Pistol_Idle", "apunta", 0)
	raiz.connect_node("apunta", 1, "mira")
	var pistola := AnimationNodeBlend2.new()
	_filtrar(pistola, arriba)
	raiz.add_node("pistola", pistola)
	raiz.connect_node("pistola", 0, "paso")
	raiz.connect_node("pistola", 1, "apunta")

	var recarga := AnimationNodeOneShot.new()
	recarga.fadein_time = 0.1
	recarga.fadeout_time = 0.2
	_filtrar(recarga, arriba)
	raiz.add_node("recarga", recarga)
	raiz.connect_node("recarga", 0, "pistola")
	raiz.add_node("recarga_vel", AnimationNodeTimeScale.new())
	_clip(raiz, "c_recarga", "Pistol_Reload", "recarga_vel", 0)
	raiz.connect_node("recarga", 1, "recarga_vel")

	# Todo el cuerpo: cambiar de clip a medio machetazo mezcla del uno al otro (el combo)
	var cual := AnimationNodeTransition.new()
	cual.xfade_time = 0.06
	var i := 0
	for entrada: String in ACCIONES:
		cual.add_input(entrada)
		_clip(raiz, "c_" + entrada, ACCIONES[entrada], "", 0)
		i += 1
	raiz.add_node("cual", cual)
	i = 0
	for entrada: String in ACCIONES:
		raiz.connect_node("cual", i, "c_" + entrada)
		i += 1
	var accion := AnimationNodeOneShot.new()
	accion.fadein_time = 0.05
	accion.fadeout_time = 0.15
	# Parado, todo el cuerpo; caminando (golpe_caminando), solo arriba y las piernas trotan
	_filtrar(accion, arriba)
	accion.filter_enabled = false
	_accion_nodo = accion
	raiz.add_node("accion", accion)
	raiz.connect_node("accion", 0, "recarga")
	raiz.connect_node("accion", 1, "cual")

	var estado := AnimationNodeTransition.new()
	estado.xfade_time = 0.2
	estado.add_input("vivo")
	estado.add_input("caido")
	raiz.add_node("estado", estado)
	raiz.connect_node("estado", 0, "accion")
	_clip(raiz, "c_caido", "Death01", "estado", 1)
	raiz.connect_node("output", 0, "estado")
	return raiz


# Un nodo con el clip, conectado a la entrada `puerto` de `destino` ("" = sin conectar)
func _clip(raiz: AnimationNodeBlendTree, nodo: String, clip: String, destino: String, puerto: int) -> void:
	var animacion := AnimationNodeAnimation.new()
	animacion.animation = LIB + "/" + clip
	raiz.add_node(nodo, animacion)
	if destino != "":
		raiz.connect_node(destino, puerto, nodo)


func _filtro_arriba() -> Array[NodePath]:
	var huesos: Array[NodePath] = []
	for hueso: String in ARRIBA:
		huesos.append(NodePath("%GeneralSkeleton:" + hueso))
	for lado in ["Left", "Right"]:
		for hueso: String in ARRIBA_LADOS:
			huesos.append(NodePath("%GeneralSkeleton:" + lado + hueso))
	return huesos


func _filtrar(nodo: AnimationNode, huesos: Array[NodePath]) -> void:
	nodo.filter_enabled = true
	for hueso in huesos:
		nodo.set_filter_path(hueso, true)


func _process(delta: float) -> void:
	if _golpe_t >= 0.0:
		_golpe_t += delta
		if _golpe_t > BIBLIOTECA.get_animation(_golpe_clip).length:
			_golpe_t = -1.0
	_patada = move_toward(_patada, 0.0, PATADA_BAJA * delta)
	_arbol.set("parameters/mira/blend_position", clampf(_mira + _patada, -1.0, 1.0))


# --- Lo que pide Player ---

func update_animation(is_moving: bool, is_airborne: bool, is_sprinting: bool = false, velocidad := -1.0) -> void:
	if _arbol == null:
		return
	var modo := "quieto"
	var natural := TROTE_VEL
	if is_airborne:
		modo = "aire"
	elif is_moving:
		modo = "carga" if cargando else ("carrera" if is_sprinting else "trote")
		natural = CARRERA_VEL if is_sprinting else TROTE_VEL
	_pedir("pies", modo)
	var paso := 1.0
	if is_moving and not is_airborne and velocidad > 0.0:
		paso = clampf(velocidad / natural, PASO_MIN, PASO_MAX)
	_arbol.set("parameters/paso/scale", paso)


# Un machetazo del combo: lado 1 de derecha a izquierda, -1 el de regreso. Si ya va uno, se
# mezcla de donde va el brazo al otro sin regresar al cuerpo
func golpe(lado: float) -> void:
	var entrada := "golpe_a" if lado > 0.0 else "golpe_b"
	_golpe_clip = ACCIONES[entrada]
	_golpe_t = 0.0
	_lanzar(entrada)


# Caminando a medio machetazo: el barrido solo en la parte de arriba, las piernas trotan
func golpe_caminando(si: bool) -> void:
	if _accion_nodo and _accion_nodo.filter_enabled != si:
		_accion_nodo.filter_enabled = si


# Te moviste a medio combo: el brazo se suelta y regresa a caminar
func soltar_golpe() -> void:
	_golpe_t = -1.0
	if _arbol and _arbol.get("parameters/accion/active"):
		_arbol.set("parameters/accion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


# Cuanto lleva el machetazo que va (s), o -1
func tiempo_golpe() -> float:
	return _golpe_t


func clip_golpe() -> String:
	return _golpe_clip


func accion(pista: String) -> void:
	if _arbol == null:
		return
	if pista == "Defeat" or pista == "caido":
		_golpe_t = -1.0
		_arbol.set("parameters/accion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_pedir("estado", "caido")
		return
	var entrada: String = PISTAS.get(pista, pista)
	if ACCIONES.has(entrada):
		_golpe_t = -1.0
		_lanzar(entrada)


func terminar_accion() -> void:
	if _arbol == null:
		return
	_golpe_t = -1.0
	_arbol.set("parameters/accion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_pedir("estado", "vivo")


# Cada cuadro: con la pistola en la mano, si apunta y a que inclinacion (grados de la camara,
# arriba positivo)
func pistola(sostiene: bool, apunta: bool, inclinacion: float) -> void:
	if _arbol == null:
		return
	_arbol.set("parameters/pistola/blend_amount", 1.0 if sostiene else 0.0)
	_pedir("apunta", "apunta" if apunta else "sostiene")
	_mira = clampf(inclinacion / (MIRA_ARRIBA if inclinacion > 0.0 else MIRA_ABAJO), -1.0, 1.0)


# Cada tiro patea el arma hacia arriba un instante
func tiro() -> void:
	_patada = PATADA


func recarga() -> void:
	if _arbol == null:
		return
	_arbol.set("parameters/recarga_vel/scale", BIBLIOTECA.get_animation("Pistol_Reload").length / RECARGA_DURA)
	_arbol.set("parameters/recarga/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _lanzar(entrada: String) -> void:
	var activa: bool = _arbol.get("parameters/accion/active")
	var actual: String = _arbol.get("parameters/cual/current_state")
	_pedir("cual", entrada)
	# Otro clip a medio golpe: la transicion lo empieza de cero y mezcla. El mismo, o nada
	# andando: se lanza otra vez
	if not activa or actual == entrada:
		_arbol.set("parameters/accion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _pedir(transicion: String, estado: String) -> void:
	if _arbol.get("parameters/%s/current_state" % transicion) != estado:
		_arbol.set("parameters/%s/transition_request" % transicion, estado)
