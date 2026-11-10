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
# Caminando mientras haces otra cosa (pistola en mano, machetazos) o retrocediendo, las piernas
# tocan Walk, al reves si vas hacia la espalda (Quaternius no trae caminar para atras); el trote
# es solo para cuando no haces nada mas (JJ). Medido por el pie de apoyo, Walk avanza ~1.3 m/s
# con la cabeza a 1.62 m
const CAMINA_VEL := 1.3
const PASO_MIN := 0.8         # de la velocidad del clip: mas rapido parecia caricatura
const PASO_MAX := 1.6
# Apuntar: la inclinacion de la camara (grados) que corresponde a Pistol_Aim_Up / _Down
const MIRA_ARRIBA := 40.0
const MIRA_ABAJO := 50.0
const PATADA := 0.22          # de la mira que sube el arma en cada tiro
const PATADA_BAJA := 2.0      # por segundo
const RECARGA_DURA := 1.5     # s (Pistola.RECARGA); el clip dura 1.67
# Los dos machetazos del combo, cada uno al reves del otro: A de derecha a izquierda, B de regreso.
# Pasan por enfrente a los 0.24 s, como Player.ATAQUE_PEGA_EN
# Mezcla de un machetazo al siguiente del combo (y a la pose de carga): con 0.06 el brazo
# saltaba de pose
const MEZCLA_COMBO := 0.12
const GOLPE_DERECHA := "Sword_Regular_A"
const GOLPE_IZQUIERDA := "Sword_Regular_B"
const ACCIONES := {
	"golpe_a": GOLPE_DERECHA,
	"golpe_b": GOLPE_IZQUIERDA,
	# Si el combo acaba ahi (no sale otro golpe), sigue su _Rec, que empieza justo donde termina
	# el golpe y regresa a la guardia (medido: el primer cuadro es el ultimo del golpe)
	"golpe_a_rec": "Sword_Regular_A_Rec",
	"golpe_b_rec": "Sword_Regular_B_Rec",
	# A mano limpia (Player.PUNOS): jab, cruzado y gancho; el gancho tambien tiene su _Rec
	"puno_jab": "Punch_Jab",
	"puno_cruzado": "Punch_Cross",
	"puno_gancho": "Melee_Hook",
	"puno_gancho_rec": "Melee_Hook_Rec",
	"golpe_giro": "Sword_Regular_C",   # el golpe con brinco (Player.giro_aereo)
	"estocada": "Sword_Dash_RM",       # la estocada desde el aire (Player.giro_aereo + Shift)
	"tajo": "Sword_Attack",            # el ataque cargado (Player.golpe_cargado): tajo de arriba abajo
	"pose_carga": "Sword_Attack",      # la pose mientras cargas: el arma arriba, quieta
	"rodar": "Roll",                   # el esquive (Player._rodar)
	"bloqueo": "Sword_Block",          # clic derecho con el machete (Player.bloquear)          # la pose mientras cargas: el amago de la estocada, quieto
	"herido": "Hit_Chest",
	"recoger": "PickUp_Table",
	"curar": "Drink",                 # curarse con Q (Player._curarse): UAL1 Source, el brazo sube, toma y baja
	"aventar": "Sword_Heavy_A",       # el punado de sal (Player.aventar_sal): el tajo pesado de UAL2 Source
	"molotov": "OverhandThrow",        # la molotov (Player.aventar_molotov): por encima del hombro
	"aturdido": "Crying",              # te tronó la palomita en la mano (Player.aturdirte): te tapas la cara
}
const PUNETAZOS := ["puno_jab", "puno_cruzado", "puno_gancho"]
# Que sigue a cada golpe cuando nadie lo corta
const REC := {"golpe_a": "golpe_a_rec", "golpe_b": "golpe_b_rec", "puno_gancho": "puno_gancho_rec"}
# Los golpes que se sueltan al caminar en cuanto se acaba el enfriamiento: con el filtro de arriba
# apagado, sus piernas (paradas, en guardia) pisaban las de caminar
const SUELTAN_CAMINANDO := ["golpe_a", "golpe_b", "golpe_a_rec", "golpe_b_rec", "puno_jab",
	"puno_cruzado", "puno_gancho", "puno_gancho_rec"]
# Lo que antes pedia Player con los nombres del ninja
const PISTAS := {"RecieveHit": "herido", "Punch": "golpe_a", "PickUp": "recoger"}
const BUCLES := ["Idle", "Jog_Fwd", "Walk", "Sprint", "Walk_Carry", "Jump", "Pistol_Idle",
	"Pistol_Aim_Up", "Pistol_Aim_Neutral", "Pistol_Aim_Down"]
# De la cintura para arriba (la pistola y recargar); las piernas siguen caminando
const ARRIBA := ["Spine", "Chest", "UpperChest", "Neck", "Head"]
const ARRIBA_LADOS := ["Shoulder", "UpperArm", "LowerArm", "Hand", "IndexProximal",
	"IndexIntermediate", "IndexDistal"]

# Trae algo en las manos: camina distinto (Player.cargar)
var cargando := false

var _arbol: AnimationTree
var _accion_nodo: AnimationNodeBlend2  # su filtro (parte de arriba) se prende al caminar golpeando
var _cual: AnimationNodeTransition
# La accion (machetazos, pose de carga, herido...) se mezcla encima con un peso que lleva este
# script, no con un OneShot: el OneShot se apagaba a la duracion del primer clip aunque la
# transicion ya fuera en otro, y al machacar uno de cada dos golpes salia con el brazo quieto.
# Redispararlo regresaba el brazo a la pose de reposo un instante. Asi el peso se queda en 1
# todo el combo y la transicion mezcla de un golpe al otro
var _accion_peso := 0.0
var _accion_resta := 0.0      # s que le quedan a la accion; INF = la pose de carga, hasta soltarla
const ACCION_ENTRA := 0.05    # s en que entra desde nada
const ACCION_SALE := 0.15     # s en que se suelta al terminar
# Al acabar un machetazo el brazo se queda ACCION_QUEDA s en el remate antes de soltarse: se
# soltaba al instante y, si el siguiente golpe llegaba un poco tarde, salia desde la pose de
# reposo y brincaba a su preparacion en 3 cuadros. El final de A es el principio de B
const ACCION_QUEDA := 0.2
var _patada := 0.0
var _mira := 0.0
# El machetazo que va: el clip y cuanto lleva (lo lee la estela del arma)
var _golpe_clip := ""
var _golpe_t := -1.0
var _golpe_vel := 1.0   # el giro en el aire va mas rapido (golpe_giro)
# Sword_Block (medido con la mano): sube la espada 0-0.15 s, se queda en guardia 0.2-0.64 y la baja
# 0.65-1.1. Bloqueando se queda quieto en GUARDIA_EN; al soltar sigue desde BAJA_DESDE
const GUARDIA_EN := 0.3
const BAJA_DESDE := 0.65
const SACUDIDA_DESDE := 0.06  # un golpe parado regresa el clip aqui: la espada vuelve a subir
var _bloqueando := false
var _bloqueo_t := -1.0       # s del clip Sword_Block mientras sube a la guardia; -1 = ya quieto
var _ultima := ""            # la ultima accion lanzada
var _rec_en := -1.0          # s para que acabe el golpe y siga su _Rec (REC); -1 = nada
var _moviendo := false       # lo ultimo que dijo update_animation
var _inclinar: SkeletonModifier3D   # InclinarCuerpo.gd: la columna hacia adelante (inclinar)
var _agarre: SkeletonModifier3D     # AgarrePistola.gd: canon a la mira y la izquierda en la cacha (agarre)


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
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		_inclinar = preload("res://scripts/InclinarCuerpo.gd").new()
		_inclinar.name = "Inclinar"
		esqueletos[0].add_child(_inclinar)
		# Despues de inclinar, para que la mano llegue a la pistola aunque vaya agachado
		_agarre = preload("res://scripts/AgarrePistola.gd").new()
		_agarre.name = "AgarrePistola"
		esqueletos[0].add_child(_agarre)


func _armar_arbol() -> AnimationNodeBlendTree:
	var raiz := AnimationNodeBlendTree.new()
	var arriba := _filtro_arriba()

	var pies := AnimationNodeTransition.new()
	pies.xfade_time = MEZCLA_PIES
	for entrada in ["quieto", "trote", "carrera", "carga", "aire", "camina"]:
		pies.add_input(entrada)
	raiz.add_node("pies", pies)
	_clip(raiz, "c_quieto", "Idle", "pies", 0)
	_clip(raiz, "c_trote", "Jog_Fwd", "pies", 1)
	_clip(raiz, "c_carrera", "Sprint", "pies", 2)
	_clip(raiz, "c_carga", "Walk_Carry", "pies", 3)
	_clip(raiz, "c_aire", "Jump", "pies", 4)
	_clip(raiz, "c_camina", "Walk", "pies", 5)
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
	cual.xfade_time = MEZCLA_COMBO
	# El mismo golpe otra vez (el combo empezo de nuevo) vuelve a empezar el clip
	cual.allow_transition_to_self = true
	_cual = cual
	var i := 0
	for entrada: String in ACCIONES:
		cual.add_input(entrada)
		_clip(raiz, "c_" + entrada, ACCIONES[entrada], "", 0)
		i += 1
	raiz.add_node("cual", cual)
	# El giro pasa por su propia velocidad y un salto al inicio: en el aire empieza ya girando
	raiz.add_node("giro_salta", AnimationNodeTimeSeek.new())
	raiz.connect_node("giro_salta", 0, "c_golpe_giro")
	raiz.add_node("giro_vel", AnimationNodeTimeScale.new())
	raiz.connect_node("giro_vel", 0, "giro_salta")
	# La estocada y la pose de carga pueden empezar a media animacion: al soltar la carga, la
	# estocada sale del mismo cuadro en que estaba la pose. La pose va a velocidad 0
	for entrada: String in ["estocada", "tajo", "pose_carga", "rodar", "bloqueo", "curar"]:
		raiz.add_node(entrada + "_salta", AnimationNodeTimeSeek.new())
		raiz.connect_node(entrada + "_salta", 0, "c_" + entrada)
		raiz.add_node(entrada + "_vel", AnimationNodeTimeScale.new())
		raiz.connect_node(entrada + "_vel", 0, entrada + "_salta")
	var entra_por := {"golpe_giro": "giro_vel", "estocada": "estocada_vel", "tajo": "tajo_vel", "pose_carga": "pose_carga_vel", "rodar": "rodar_vel", "bloqueo": "bloqueo_vel", "curar": "curar_vel"}
	i = 0
	for entrada: String in ACCIONES:
		raiz.connect_node("cual", i, entra_por.get(entrada, "c_" + entrada))
		i += 1
	var accion := AnimationNodeBlend2.new()
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
		_golpe_t += delta * _golpe_vel
		if _golpe_t > BIBLIOTECA.get_animation(_golpe_clip).length:
			_golpe_t = -1.0
	if _bloqueando and _bloqueo_t >= 0.0:
		_bloqueo_t += delta
		if _bloqueo_t >= GUARDIA_EN:
			_bloqueo_t = -1.0
			_arbol.set("parameters/bloqueo_vel/scale", 0.0)
	if _rec_en >= 0.0:
		_rec_en -= delta
		if _rec_en < 0.0 and REC.has(_ultima):
			# Caminando no: el _Rec es de cuerpo entero y parado; el golpe se suelta como antes
			if not _moviendo:
				_lanzar(REC[_ultima], 0.0, 1.0, false)
	_accion_resta = maxf(_accion_resta - delta, 0.0)
	_accion_peso = minf(move_toward(_accion_peso, 1.0, delta / ACCION_ENTRA), _accion_resta / ACCION_SALE)
	_arbol.set("parameters/accion/blend_amount", _accion_peso)
	_patada = move_toward(_patada, 0.0, PATADA_BAJA * delta)
	_arbol.set("parameters/mira/blend_position", clampf(_mira + _patada, -1.0, 1.0))


# --- Lo que pide Player ---

# camina: haces otra cosa a la vez (o retrocedes) y las piernas tocan Walk en vez del trote;
# al_reves: te mueves hacia la espalda del modelo y Walk va al reves
func update_animation(is_moving: bool, is_airborne: bool, is_sprinting: bool = false, velocidad := -1.0,
		camina := false, al_reves := false) -> void:
	if _arbol == null:
		return
	var modo := "quieto"
	var natural := TROTE_VEL
	if is_airborne:
		modo = "aire"
	elif is_moving and (camina or al_reves) and not cargando:
		modo = "camina"
		natural = CAMINA_VEL
	elif is_moving:
		modo = "carga" if cargando else ("carrera" if is_sprinting else "trote")
		natural = CARRERA_VEL if is_sprinting else TROTE_VEL
	_pedir("pies", modo)
	_moviendo = is_moving
	# Te echaste a andar con un golpe todavia de cuerpo entero (ya sin el filtro de arriba): se suelta
	if is_moving and not _accion_nodo.filter_enabled and _ultima in SUELTAN_CAMINANDO \
			and _accion_resta > ACCION_SALE:
		_rec_en = -1.0
		_accion_resta = ACCION_SALE * _accion_peso
	var paso := 1.0
	if is_moving and not is_airborne and velocidad > 0.0:
		paso = clampf(velocidad / natural, PASO_MIN, PASO_MAX)
	if modo == "camina" and al_reves:
		paso = -paso
	_arbol.set("parameters/paso/scale", paso)


# Un machetazo del combo: lado 1 de derecha a izquierda, -1 el de regreso. Si ya va uno, se
# mezcla de donde va el brazo al otro sin regresar al cuerpo
func golpe(lado: float) -> void:
	var entrada := "golpe_a" if lado > 0.0 else "golpe_b"
	_golpe_clip = ACCIONES[entrada]
	_golpe_t = 0.0
	_golpe_vel = 1.0
	_lanzar(entrada)


# El ataque cargado: el espadazo giratorio, de todo el cuerpo
func golpe_giro(velocidad := 1.0, desde := 0.0) -> void:
	_golpe_clip = ACCIONES["golpe_giro"]
	_golpe_t = desde
	_golpe_vel = velocidad
	_arbol.set("parameters/giro_vel/scale", velocidad)
	_arbol.set("parameters/giro_salta/seek_request", desde)
	if _accion_nodo:
		_accion_nodo.filter_enabled = false
	_lanzar("golpe_giro", desde, velocidad)


# Clic derecho con el machete: sube la espada y se queda en guardia mientras si; al soltar la baja
func bloquear(si: bool) -> void:
	if si == _bloqueando or _arbol == null:
		return
	if si:
		_golpe_t = -1.0
		_bloqueo_t = 0.0
		_arbol.set("parameters/bloqueo_vel/scale", 1.0)
		_arbol.set("parameters/bloqueo_salta/seek_request", 0.0)
		_lanzar("bloqueo")
		_bloqueando = true
	else:
		_bloqueando = false
		# Si otra accion ya lo tapo (un golpe, la rodada) no hay nada que bajar
		if _ultima == "bloqueo":
			_arbol.set("parameters/bloqueo_vel/scale", 1.0)
			_arbol.set("parameters/bloqueo_salta/seek_request", BAJA_DESDE)
			_accion_resta = BIBLIOTECA.get_animation(ACCIONES["bloqueo"]).length - BAJA_DESDE + ACCION_SALE


# Te pegaron bloqueando: la espada cede y vuelve a subir a la guardia
func bloqueo_golpe() -> void:
	if not _bloqueando or _ultima != "bloqueo":
		return
	_bloqueo_t = SACUDIDA_DESDE
	_arbol.set("parameters/bloqueo_vel/scale", 1.0)
	_arbol.set("parameters/bloqueo_salta/seek_request", SACUDIDA_DESDE)


# La rodada para esquivar, de todo el cuerpo, a `velocidad` (el avance lo hace Player: el clip
# rueda en su lugar)
func rodar(velocidad: float) -> void:
	_golpe_t = -1.0
	_arbol.set("parameters/rodar_vel/scale", velocidad)
	_arbol.set("parameters/rodar_salta/seek_request", 0.0)
	if _accion_nodo:
		_accion_nodo.filter_enabled = false
	_lanzar("rodar", 0.0, velocidad)


# Curarse: el trago de Drink (3 s a 1x) a `velocidad`, de todo el cuerpo
func curar(velocidad: float) -> void:
	_golpe_t = -1.0
	_arbol.set("parameters/curar_vel/scale", velocidad)
	_arbol.set("parameters/curar_salta/seek_request", 0.0)
	if _accion_nodo:
		_accion_nodo.filter_enabled = false
	_lanzar("curar", 0.0, velocidad)


# Grados que se dobla la columna hacia adelante (0 = derecho); entra y sale suave
func inclinar(grados: float) -> void:
	if _inclinar:
		_inclinar.angulo = grados


# Inclinado, los brazos no se agachan con la columna (los punetazos salen al frente)
# Pistola a dos manos mientras `activo`: el canon (`canon_local`, en el hueso RightHand) hacia
# `mira` (global) y la izquierda cubriendo a la derecha (AgarrePistola.gd)
# `apunta`: cuanto endereza el canon a la mira (0 en la corredera: el arma se queda como la pone el clip)
func agarre(activo: bool, mira: Vector3, canon_local: Vector3, apunta := 1.0) -> void:
	if _agarre:
		_agarre.peso = 1.0 if activo else 0.0
		_agarre.apunta_a = mira
		_agarre.canon_local = canon_local
		_agarre.apunta = apunta


# La izquierda en la corredera (`objetivo`, un Marker3D que se mueve con ella), `peso` 0-1
func corredera(objetivo: Node3D, peso: float) -> void:
	if _agarre:
		_agarre.corredera = objetivo
		_agarre.corredera_peso = peso


func enderezar_brazos(si: bool) -> void:
	if _inclinar:
		_inclinar.brazos = 1.0 if si else 0.0


# El giro cambia de velocidad a medio clip (en el aire va acelerado; tras el azote, normal)
func velocidad_giro(velocidad: float) -> void:
	if _golpe_t < 0.0 or _golpe_clip != ACCIONES["golpe_giro"]:
		return
	_golpe_vel = velocidad
	_arbol.set("parameters/giro_vel/scale", velocidad)
	_accion_resta = (BIBLIOTECA.get_animation(_golpe_clip).length - _golpe_t) / velocidad + ACCION_SALE


# La estocada con avance: de todo el cuerpo (el avance lo hace Player, el clip ya no trae Root).
# desde > 0 al salir de la pose de carga, que estaba quieta en ese cuadro
# velocidad > 1: desde el aire, para caer en el cuadro justo (Player.ESTOCADA_AIRE_CAE)
func golpe_estocada(desde := 0.0, velocidad := 1.0) -> void:
	_golpe_clip = ACCIONES["estocada"]
	_golpe_t = desde
	_golpe_vel = velocidad
	_arbol.set("parameters/estocada_vel/scale", velocidad)
	_arbol.set("parameters/estocada_salta/seek_request", desde)
	if _accion_nodo:
		_accion_nodo.filter_enabled = false
	_lanzar("estocada", desde, velocidad)


# El tajo cargado: de todo el cuerpo, desde el cuadro de la pose de carga (el avance lo hace Player)
func golpe_tajo(desde := 0.0) -> void:
	_golpe_clip = ACCIONES["tajo"]
	_golpe_t = desde
	_golpe_vel = 1.0
	_arbol.set("parameters/tajo_vel/scale", 1.0)
	_arbol.set("parameters/tajo_salta/seek_request", desde)
	if _accion_nodo:
		_accion_nodo.filter_enabled = false
	_lanzar("tajo", desde, 1.0)


# La estocada desde el aire ya cayo: lo demas a velocidad normal (0: se queda quieta)
func velocidad_estocada(velocidad: float) -> void:
	if _golpe_t < 0.0 or _golpe_clip != ACCIONES["estocada"]:
		return
	_golpe_vel = velocidad
	_arbol.set("parameters/estocada_vel/scale", velocidad)
	# 0 = quieta en el aire esperando el piso
	_accion_resta = INF if velocidad <= 0.0 else \
			(BIBLIOTECA.get_animation(_golpe_clip).length - _golpe_t) / velocidad + ACCION_SALE


# Mientras cargas: el amago de la estocada, quieto en el cuadro en (s del clip). Entra mezclando
# desde donde vaya el machetazo. Caminando, solo arriba (golpe_caminando)
func pose_carga(en: float) -> void:
	_golpe_t = -1.0
	_arbol.set("parameters/pose_carga_vel/scale", 0.0)
	_arbol.set("parameters/pose_carga_salta/seek_request", en)
	_lanzar("pose_carga")


# Caminando a medio machetazo: el barrido solo en la parte de arriba, las piernas trotan
func golpe_caminando(si: bool) -> void:
	if _accion_nodo and _accion_nodo.filter_enabled != si:
		_accion_nodo.filter_enabled = si


# Un golpe del combo a mano limpia: 0 jab, 1 cruzado, 2 gancho (Player.PUNOS)
func punetazo(paso: int) -> void:
	var entrada: String = PUNETAZOS[clampi(paso, 0, PUNETAZOS.size() - 1)]
	_golpe_clip = ACCIONES[entrada]
	_golpe_t = 0.0
	_golpe_vel = 1.0
	_lanzar(entrada)


# Te moviste a medio combo: el brazo se suelta y regresa a caminar
func soltar_golpe() -> void:
	_golpe_t = -1.0
	_rec_en = -1.0
	_accion_resta = minf(_accion_resta, ACCION_SALE * _accion_peso)


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
		_abortar_accion()
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
	_abortar_accion()
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


# Recarga en seco: el clip se va (se desvanece) en cuanto mete el cargador, y la corredera la hace
# AgarrePistola sobre la pose de sostenerla
func cortar_recarga() -> void:
	if _arbol:
		_arbol.set("parameters/recarga/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


# Empieza una accion (desde s del clip, a velocidad vel; la pose de carga dura hasta que la
# sueltes). A media accion la transicion mezcla del clip que iba al nuevo; sin nada andando
# entra directo, sin mezclar con un clip viejo
# mezcla false: entra seco (el _Rec empieza en el cuadro en que acaba su golpe)
func _lanzar(entrada: String, desde := 0.0, vel := 1.0, mezcla := true) -> void:
	_cual.xfade_time = MEZCLA_COMBO if _accion_peso > 0.0 and mezcla else 0.0
	_arbol.set("parameters/cual/transition_request", entrada)
	_ultima = entrada
	_rec_en = (BIBLIOTECA.get_animation(ACCIONES[entrada]).length - desde) / vel if REC.has(entrada) else -1.0
	if entrada != "bloqueo":
		_bloqueando = false
	if entrada == "pose_carga" or entrada == "bloqueo":
		_accion_resta = INF
	else:
		_accion_resta = (BIBLIOTECA.get_animation(ACCIONES[entrada]).length - desde) / vel + ACCION_SALE
		if entrada == "golpe_a" or entrada == "golpe_b":
			_accion_resta += ACCION_QUEDA


func _abortar_accion() -> void:
	_accion_resta = 0.0
	_accion_peso = 0.0
	_arbol.set("parameters/accion/blend_amount", 0.0)


func _pedir(transicion: String, estado: String) -> void:
	if _arbol.get("parameters/%s/current_state" % transicion) != estado:
		_arbol.set("parameters/%s/transition_request" % transicion, estado)
