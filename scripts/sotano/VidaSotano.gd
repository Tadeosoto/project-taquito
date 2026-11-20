extends Node

# La vida del Sotano (AG 2026-11-19: "que nadie nomas este parado, que se sienta vivo"). Lo crea
# Sotano.gd despues de la gente. Todo es de adorno: no toca tus fichas ni los juegos.
# - Los de las maquinitas (sentados en Silla_k frente a OlPley_k) jalan la palanca cada rato: el
#   brazo derecho hace Interact encima de Sitting_Idle (un OneShot con filtro, _brazo), la pantalla
#   gira, a veces ganan (foco y monedas) y a veces le dan un manotazo.
# - Las mesas juegan solas mientras no estas sentado en ellas: la ruleta gira con fichas de otros,
#   el poker reparte y alguien se lleva el bote, el blackjack y el baccarat reparten a los de la
#   mesa y los caballitos corren. Solo si andas cerca (LEJOS).
# - Mirones de pie en la ruleta, las carreras y el poker, que gritan o se quejan con el resultado.
# - Reacciones a ti: JuegoSotano.festejar llama reaccionar(); si ganas en grande los de cerca te
#   voltean a ver y dicen algo; si pierdes seguido se burlan. Si ganas mucho, el guardia te vigila.
# Los letreros son Label3D (globo de texto) arriba de la cabeza. Sonidos 3D bajitos (_sonar).

const POKER := preload("res://scripts/sotano/PokerUI.gd")
const LEJOS := 16.0                  # m (escena) del jugador hasta donde se mueve todo
const MAQUINA_CADA := Vector2(4.0, 9.0)
const RULETA_CADA := Vector2(20.0, 30.0)
const POKER_CADA := Vector2(16.0, 24.0)
const BJ_CADA := Vector2(14.0, 22.0)
const CARRERA_CADA := Vector2(35.0, 50.0)
const CARTA := Vector2(0.12, 0.18)
const PANO := 0.803
const FICHA := 1.6
const GANA_MUCHO := 100              # fichas ganadas en la noche para que el guardia te vigile
const PISO := -2.6

# Los mirones: modelo, donde (x, z), hacia donde ven (x, z), que miran
const MIRONES := [
	["hombre_09", Vector2(31.3, 1.1), Vector2(32.8, -0.4), "ruleta"],
	["mujer_10", Vector2(34.0, 1.35), Vector2(33.0, -0.4), "ruleta"],
	["hombre_14", Vector2(12.6, 4.15), Vector2(13.0, 5.4), "carreras"],
	["mujer_05", Vector2(15.2, 4.15), Vector2(15.0, 5.4), "carreras"],
	["hombre_11", Vector2(29.7, 2.3), Vector2(27.5, 3.6), "poker"],
]
const GRITOS := {
	"gana": ["¡Esoooo!", "¡Ándale!", "¡Pagaaa!", "¡Ya se le hizo!", "¡Órale, suertudo!"],
	"pierde": ["¡No manches!", "Chale...", "Ya ni la amuelas.", "¡Arreglada!", "Otra vez la casa."],
	"tu_ganas": ["¡Mira nomás al suertudo!", "¡Invita algo, compa!", "Ese ya trae la racha.", "¿Y ese de dónde salió?"],
	"tu_pierdes": ["Jajaja, otra vez.", "Ya vete a tu casa, mijo.", "Así empecé yo.", "La casa siempre gana."],
	"maquina": ["¡Vamos, vamos!", "Una más y me voy.", "¡Pinche máquina!", "Ya casi sale el tinaco..."],
}

var sotano: Node3D
var ganado := 0                      # lo que llevas ganado en la noche (para el guardia)

var _jugador: Node3D
var _maquinas: Array = []            # [npc, gabinete, AnimationTree, siguiente]
var _mirones: Array = []             # [npc, que]
var _t := {}                         # mesa -> s para la siguiente
var _ocupada := {}                   # mesa -> true mientras juega sola
var _rueda: Node3D
var _bola: Node3D
var _rng := RandomNumberGenerator.new()
var _cosas := {}                     # mesa -> lo que puso en la mesa la partida sola (para cortarla)


func _ready() -> void:
	add_to_group("vida_sotano")
	_rng.randomize()
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	var cuarto := sotano.get_node_or_null("Cuarto")
	if cuarto:
		_rueda = cuarto.find_child("Ruleta_rueda", true, false) as Node3D
		_bola = cuarto.find_child("Ruleta_bola", true, false) as Node3D
	# Los de las maquinitas
	for n in sotano.get_children():
		if not n.has_meta("asiento"):
			continue
		var asiento: String = n.get_meta("asiento")
		if asiento.begins_with("Banco_barra"):
			var trago := _trago(n)
			if trago:
				_barra.append([trago, _rng.randf_range(2.0, TRAGO_CADA.y)])
			continue
		if not asiento.begins_with("Silla_"):
			continue
		var g := sotano.get_node_or_null("OlPley_%s" % asiento.trim_prefix("Silla_"))
		if g == null:
			continue
		var arbol := _brazo(n)
		_maquinas.append([n, g, arbol, _rng.randf_range(1.0, MAQUINA_CADA.y), _mano_a_palanca(n, g)])
	# Los mirones
	for m: Array in MIRONES:
		var nodo := Node3D.new()
		nodo.position = Vector3(m[1].x, PISO, m[1].y)
		sotano.add_child(nodo)
		Civiles.poner(nodo, m[0], "Idle_Talking")
		nodo.look_at(sotano.to_global(Vector3(m[2].x, PISO, m[2].y)), Vector3.UP)
		_mirones.append([nodo, m[3]])
	for mesa in ["ruleta", "poker", "blackjack", "baccarat", "carreras"]:
		_t[mesa] = _rng.randf_range(3.0, 10.0)
		_ocupada[mesa] = false


func _process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	for m: Array in _maquinas:
		m[3] -= delta
		if m[3] <= 0.0:
			m[3] = _rng.randf_range(MAQUINA_CADA.x, MAQUINA_CADA.y)
			if _cerca((m[0] as Node3D).global_position) and not _en_uso("OlPleyUI", m[1]):
				_jalar(m)
	for b: Array in _barra:
		b[1] -= delta
		if b[1] <= 0.0:
			b[1] = _rng.randf_range(TRAGO_CADA.x, TRAGO_CADA.y)
			(b[0] as AnimationTree).set("parameters/trago/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	for mesa: String in _t:
		if _ocupada[mesa]:
			continue
		_t[mesa] -= delta
		if _t[mesa] > 0.0:
			continue
		var cada: Vector2 = {"ruleta": RULETA_CADA, "poker": POKER_CADA, "blackjack": BJ_CADA, "baccarat": BJ_CADA, "carreras": CARRERA_CADA}[mesa]
		_t[mesa] = _rng.randf_range(cada.x, cada.y)
		var donde := _centro_de(mesa)
		if not _cerca(sotano.to_global(donde)) or _en_uso(_ui_de(mesa)):
			continue
		_ocupada[mesa] = true
		match mesa:
			"ruleta":
				_ruleta_sola()
			"poker":
				_poker_solo()
			"blackjack":
				_bj_solo()
			"baccarat":
				_baccarat_solo()
			"carreras":
				_carrera_sola()


func _cerca(p: Vector3) -> bool:
	return _jugador.global_position.distance_to(p) < LEJOS * sotano.global_basis.get_scale().x


# Si estas jugando en esa mesa (la pantalla abierta es de ese juego)
func _en_uso(guion: String, gabinete: Node = null) -> bool:
	var ui := get_tree().get_first_node_in_group("juego_sotano")
	if ui == null or ui.get_script() == null or not (ui.get_script() as Script).resource_path.ends_with(guion + ".gd"):
		return false
	if guion == "BlackjackUI":
		return ui.get("prefijo") == "Blackjack"
	if gabinete:
		return ui.get("gabinete") == gabinete
	return true


func _ui_de(mesa: String) -> String:
	return {"ruleta": "RuletaUI", "poker": "PokerUI", "blackjack": "BlackjackUI", "baccarat": "BaccaratUI", "carreras": "CarrerasUI"}[mesa]


func _centro_de(mesa: String) -> Vector3:
	match mesa:
		"ruleta":
			return _marca("Ruleta")
		"poker":
			return _marca("Poker") - Vector3(0, 0, 1.8)
		"blackjack":
			return _marca("Crupier_bj")
		"baccarat":
			return _marca("Crupier_baccarat")
		"carreras":
			return _marca("Pista")
	return Vector3.ZERO


func _marca(nombre: String) -> Vector3:
	return sotano.call("marca", nombre).origin


# --- La barra ---

# Los de la barra (Banco_barra_*) le dan un trago a su cerveza cada TRAGO_CADA s: un OneShot de Drink
# solo en el brazo derecho, el cuello y la cabeza, encima de Sitting_Idle
const TRAGO_CADA := Vector2(6.0, 12.0)
var _barra: Array = []    # [AnimationTree, s para el siguiente trago]


func _trago(npc: Node3D) -> AnimationTree:
	var ap := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(Civiles.LIB + "/Drink"):
		return null
	var arbol := AnimationTree.new()
	var bt := AnimationNodeBlendTree.new()
	var sentado := AnimationNodeAnimation.new()
	sentado.animation = Civiles.LIB + "/Sitting_Idle"
	var bebe := AnimationNodeAnimation.new()
	bebe.animation = Civiles.LIB + "/Drink"
	var trago := AnimationNodeOneShot.new()
	trago.filter_enabled = true
	trago.fadein_time = 0.3
	trago.fadeout_time = 0.4
	var anim := ap.get_animation(Civiles.LIB + "/Drink")
	for i in anim.get_track_count():
		var hueso := String(anim.track_get_path(i)).get_slice(":", 1)
		if (hueso.begins_with("Right") and not hueso.contains("Leg") and not hueso.contains("Foot") and not hueso.contains("Toe")) 				or hueso == "Neck" or hueso == "Head":
			trago.set_filter_path(anim.track_get_path(i), true)
	bt.add_node("sentado", sentado)
	bt.add_node("bebe", bebe)
	bt.add_node("trago", trago)
	bt.connect_node("trago", 0, "sentado")
	bt.connect_node("trago", 1, "bebe")
	bt.connect_node("output", 0, "trago")
	arbol.tree_root = bt
	ap.get_parent().add_child(arbol)
	arbol.anim_player = arbol.get_path_to(ap)
	arbol.active = true
	ap.active = false
	return arbol


# --- Las maquinitas ---

# Un Blend2 con filtro: el brazo derecho de Pistol_Aim_Neutral (estirado al frente) encima de
# Sitting_Idle; _jalar sube la mezcla (alcanza la palanca) y la baja (la jala). Interact era un gesto
# hacia abajo y no se notaba
const BRAZO := "Pistol_Aim_Neutral"


func _brazo(npc: Node3D) -> AnimationTree:
	var ap := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(Civiles.LIB + "/" + BRAZO):
		return null
	var arbol := AnimationTree.new()
	var bt := AnimationNodeBlendTree.new()
	var sentado := AnimationNodeAnimation.new()
	sentado.animation = Civiles.LIB + "/Sitting_Idle"
	var mano := AnimationNodeAnimation.new()
	mano.animation = Civiles.LIB + "/" + BRAZO
	var disparo := AnimationNodeBlend2.new()
	disparo.filter_enabled = true
	var anim := ap.get_animation(Civiles.LIB + "/" + BRAZO)
	for i in anim.get_track_count():
		var ruta := String(anim.track_get_path(i))
		var hueso := ruta.get_slice(":", 1)
		if hueso.begins_with("Right") and not hueso.contains("Leg") and not hueso.contains("Foot") and not hueso.contains("Toe"):
			disparo.set_filter_path(anim.track_get_path(i), true)
	bt.add_node("sentado", sentado)
	bt.add_node("mano", mano)
	bt.add_node("disparo", disparo)
	bt.connect_node("disparo", 0, "sentado")
	bt.connect_node("disparo", 1, "mano")
	bt.connect_node("output", 0, "disparo")
	arbol.tree_root = bt
	ap.get_parent().add_child(arbol)
	arbol.anim_player = arbol.get_path_to(ap)
	arbol.active = true
	# El AnimationPlayer se apaga: si sigue tocando Sitting_Idle le gana al arbol (el arbol usa sus clips)
	ap.active = false
	return arbol


# La mano llega a la bola de verdad: un FABRIK3D del pecho (UpperChest) a la mano derecha con el objetivo
# colgado del vacio "Palanca" del gabinete (asi la mano baja con la palanca). Desde la espalda y no
# solo el brazo: sentados en el banco la bola queda a dos brazos del hombro y tienen que inclinarse
# (desde Spine se doblaban como trapo; desde Chest con set_deterministic la mano caia al regazo).
# Empieza sin influencia; _jalar la sube y la baja junto con la mezcla del arbol
const _RAIZ_BRAZO := "UpperChest"
func _mano_a_palanca(npc: Node3D, g: Node) -> SkeletonModifier3D:
	var palanca := g.find_child("Palanca", true, false) as Node3D
	var esqueletos := npc.find_children("*", "Skeleton3D", true, false)
	if palanca == null or esqueletos.is_empty() or not ClassDB.class_exists("TwoBoneIK3D"):
		return null
	var esq := esqueletos[0] as Skeleton3D
	if esq.find_bone("RightUpperArm") < 0 or esq.find_bone("RightLowerArm") < 0 or esq.find_bone("RightHand") < 0:
		print("VidaSotano: sin huesos del brazo en ", npc.name)
		return null
	var bola := Node3D.new()
	bola.name = "Mano_objetivo"
	palanca.add_child(bola)
	bola.position = Vector3(0.0, 0.36, 0.03)
	var ik := ClassDB.instantiate("FABRIK3D") as SkeletonModifier3D
	esq.add_child(ik)
	ik.set("setting_count", 1)
	ik.call("set_root_bone_name", 0, _RAIZ_BRAZO if esq.find_bone(_RAIZ_BRAZO) >= 0 else "RightUpperArm")
	ik.call("set_end_bone_name", 0, "RightHand")
	ik.call("set_target_node", 0, ik.get_path_to(bola))
	ik.influence = 0.0
	return ik


func _jalar(m: Array) -> void:
	var npc := m[0] as Node3D
	var g := m[1] as Node3D
	var arbol := m[2] as AnimationTree
	var ik: SkeletonModifier3D = m[4] if m.size() > 4 else null
	if ik:
		# Alcanza la bola (0.4 s), la acompana mientras baja y la suelta cuando la palanca regresa
		var ti := create_tween()
		ti.tween_property(ik, "influence", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		ti.tween_interval(0.1 + 0.22 + 0.15)
		ti.tween_property(ik, "influence", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	if arbol:
		var t := create_tween()
		t.tween_property(arbol, "parameters/disparo/blend_amount", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.15)
		t.tween_property(arbol, "parameters/disparo/blend_amount", 0.35, 0.2).set_trans(Tween.TRANS_QUAD)
		t.tween_property(arbol, "parameters/disparo/blend_amount", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(g):
		return
	g.call("jalar_palanca", -16.0)
	# La pantalla gira: colores que cambian rapido y tres tics
	var pantalla := g.find_child("Pantalla", true, false) as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if pantalla:
		pantalla.set_surface_override_material(0, mat)
	for k in 12:
		mat.albedo_color = Color.from_hsv(_rng.randf(), 0.7, 1.0)
		await get_tree().create_timer(0.09).timeout
		if k % 4 == 3:
			_sonar("slot_carrete", g.global_position, -20.0, 1.1)
	var gana := _rng.randf() < 0.13
	if gana:
		for k in 8:
			mat.albedo_color = Color(1.0, 0.85, 0.1) if k % 2 == 0 else Color(1.0, 0.3, 0.7)
			await get_tree().create_timer(0.12).timeout
		_sonar("monedas_caen", g.global_position, -14.0)
		_globo(npc, GRITOS.gana.pick_random(), 1.8)
	elif _rng.randf() < 0.25:
		_sonar("golpe", g.global_position, -14.0, 0.8)
		_globo(npc, GRITOS.maquina.pick_random(), 1.8)
		var y0 := npc.rotation.y
		var t := create_tween()
		t.tween_property(npc, "rotation:y", y0 + 0.15, 0.06)
		t.tween_property(npc, "rotation:y", y0, 0.2)
	if pantalla and is_instance_valid(pantalla):
		pantalla.set_surface_override_material(0, null)


# --- La ruleta sola ---

func _ruleta_sola() -> void:
	var pilas: Array = _cosas_de("ruleta")
	var apuestas: Array[String] = []
	for k in _rng.randi_range(1, 3):
		var color: String = ["rojo", "negro", "rojo", "negro", "verde"].pick_random()
		var p := PilaFichas.new()
		p.tamano = FICHA
		sotano.add_child(p)
		p.position = _marca("Crupier_ruleta") + Vector3(0, 0.85, 0)
		p.poner(_rng.randi_range(2, 9))
		p.ir_a(_marca("Ruleta_" + color) + Vector3(_rng.randf_range(-0.06, 0.06), 0, _rng.randf_range(-0.05, 0.05)), 0.5)
		pilas.append(p)
		apuestas.append(color)
		_sonar("ficha_mesa", sotano.to_global(_marca("Ruleta")), -16.0)
		if await _espera("ruleta", 0.4): return
	var tiro := _rng.randi_range(0, 36)
	var sale := "verde" if tiro == 0 else ("rojo" if tiro % 2 == 1 else "negro")
	await _girar_rueda(tiro)
	if not _ocupada["ruleta"]:
		return
	var alguien := false
	for i in pilas.size():
		if not is_instance_valid(pilas[i]):
			continue
		if apuestas[i] == sale:
			alguien = true
			pilas[i].monton = true
			pilas[i].fuego = sale == "verde"
			pilas[i].poner(pilas[i].cantidad * (36 if sale == "verde" else 2))
	_gritan("ruleta", alguien)
	if await _espera("ruleta", 2.0): return
	for p in pilas:
		if is_instance_valid(p):
			p.llevar(_marca("Crupier_ruleta") + Vector3(0, 0.85, 0) if not p.monton else _marca("Ruleta") + Vector3(_rng.randf_range(-0.3, 0.3), 0.85, 0))
	_ocupada["ruleta"] = false


# Gira la rueda frenandose y la bola da vueltas al reves hasta quedar en su casilla (sin brincos)
func _girar_rueda(n: int) -> void:
	if _rueda == null:
		await get_tree().create_timer(4.0).timeout
		return
	var total := Ruleta.ORDEN.size()
	var a := (Ruleta.ORDEN.find(n) + 0.5) * TAU / total
	var inicio := _rueda.rotation.y
	var dura := 5.0
	var t := 0.0
	_sonar("caballitos", sotano.to_global(_marca("Ruleta")), -18.0, 1.3)
	while t < dura:
		await get_tree().process_frame
		if _en_uso("RuletaUI"):
			_cortar("ruleta")
			return
		t = minf(t + get_process_delta_time(), dura)
		var f := t / dura
		var giro := inicio + TAU * 1.1 * (f - f * f / 2.0) * 2.0
		_rueda.rotation.y = giro
		if _bola:
			var fi := giro + a - 3.4 * TAU * pow(1.0 - f, 2.0)
			var r := lerpf(0.35, 0.24, clampf((f - 0.55) / 0.2, 0.0, 1.0))
			_bola.position = _rueda.position + Vector3(cos(fi) * r, lerpf(0.07, 0.053, clampf((f - 0.55) / 0.2, 0.0, 1.0)), -sin(fi) * r)


# --- El poker solo ---

func _poker_solo() -> void:
	var centro := _centro_de("poker") + Vector3(0, 0.79, 0)
	var cosas: Array = _cosas_de("poker")
	var bote := PilaFichas.new()
	sotano.add_child(bote)
	bote.position = centro + Vector3(0.0, 0.0, -0.18)
	bote.poner(0)
	cosas.append(bote)
	var manos: Array = []
	for v in 3:
		var silla := _marca("Poker_%d" % v)
		var hacia := (centro - Vector3(silla.x, centro.y, silla.z)).normalized()
		var lado := hacia.cross(Vector3.UP).normalized()
		var p := centro - hacia * 0.5
		var par: Array[MeshInstance3D] = []
		for s in [1.0, -1.0]:
			var c := _carta(centro, p + lado * 0.068 * s, atan2(hacia.x, hacia.z), -1)
			par.append(c)
			cosas.append(c)
			if await _espera("poker", 0.12): return
		manos.append(par)
	# Las cinco de en medio, boca arriba
	for k in 5:
		var c := _carta(centro, centro + Vector3((k - 2) * 0.145, 0.0, 0.05), 0.0, _rng.randi_range(0, 51))
		cosas.append(c)
		if await _espera("poker", 0.15): return
	# Apuestan: fichas al bote; alguno se retira y avienta sus cartas
	for r in 2:
		for v in 3:
			if await _espera("poker", 0.5): return
			_sonar("ficha_mesa", sotano.to_global(centro), -16.0)
			bote.poner(bote.cantidad + _rng.randi_range(2, 6))
	var retira := _rng.randi_range(0, 2)
	for c: MeshInstance3D in manos[retira]:
		var t := c.create_tween()
		t.tween_property(c, "position", centro + Vector3(_rng.randf_range(-0.1, 0.1), 0.004, -0.3), 0.25)
	var ganador := (retira + _rng.randi_range(1, 2)) % 3
	if await _espera("poker", 1.0): return
	for c: MeshInstance3D in manos[ganador]:
		_voltear(c, _rng.randi_range(0, 51))
	if await _espera("poker", 0.8): return
	var silla_g := _marca("Poker_%d" % ganador)
	bote.ir_a(centro.lerp(Vector3(silla_g.x, centro.y, silla_g.z), 0.55), 0.5)
	var jugador_g := _sentado("Poker_%d" % ganador)
	if jugador_g:
		_globo(jugador_g, ["Ahí nomás.", "Gracias, gracias.", "Pa' la otra, señores.", "Les dije que traía."].pick_random(), 2.0)
	_gritan("poker", true)
	if await _espera("poker", 2.5): return
	_recoger(cosas, _marca("Crupier") + Vector3(0, 0.85, 0))
	_ocupada["poker"] = false


# --- El blackjack y el baccarat solos ---

func _bj_solo() -> void:
	var c := _marca("Crupier_bj")
	var tu := _marca("Blackjack_tu")
	var frente := Vector3(tu.x - c.x, 0, tu.z - c.z).normalized()
	var lado := Vector3.UP.cross(frente)
	var pano := c + Vector3.UP * PANO
	var cosas: Array = _cosas_de("blackjack")
	var lugares := []
	for s in ["Blackjack_0", "Blackjack_1"]:
		if _sentado(s):
			var silla := _marca(s)
			lugares.append([s, pano.lerp(Vector3(silla.x, pano.y, silla.z), 0.5)])
	var giro := atan2(frente.x, frente.z)
	for k in 2:
		for l: Array in lugares:
			cosas.append(_carta(pano, l[1] + lado * (k - 0.5) * 0.1, giro, _rng.randi_range(0, 51)))
			if await _espera("blackjack", 0.25): return
		cosas.append(_carta(pano, pano + frente * 0.9 + lado * (k - 0.5) * 0.135, giro, _rng.randi_range(0, 51) if k == 0 else -1))
		if await _espera("blackjack", 0.25): return
	if await _espera("blackjack", 2.5): return
	if cosas.size() > 0:
		_voltear(cosas[cosas.size() - 1] as MeshInstance3D, _rng.randi_range(0, 51))
	if await _espera("blackjack", 1.0): return
	if not lugares.is_empty():
		var quien := _sentado(lugares.pick_random()[0])
		var gano := _rng.randf() < 0.45
		if quien:
			_globo(quien, GRITOS.gana.pick_random() if gano else GRITOS.pierde.pick_random(), 1.8)
	if await _espera("blackjack", 1.5): return
	_recoger(cosas, c + Vector3.UP * (PANO + 0.05))
	_ocupada["blackjack"] = false


func _baccarat_solo() -> void:
	var c := _marca("Crupier_baccarat")
	var pano := Vector3(c.x, c.y + PANO, c.z + 0.45 + 0.3)
	var cosas: Array = _cosas_de("baccarat")
	for k in 2:
		for lado in [-1.0, 1.0]:
			cosas.append(_carta(pano, pano + Vector3(lado * (0.47 - k * 0.135), 0, 0), 0.0, _rng.randi_range(0, 51)))
			if await _espera("baccarat", 0.3): return
	var quien := _sentado("Baccarat_0")
	if await _espera("baccarat", 1.5): return
	if quien:
		_globo(quien, GRITOS.gana.pick_random() if _rng.randf() < 0.5 else GRITOS.pierde.pick_random(), 1.8)
	if await _espera("baccarat", 2.0): return
	_recoger(cosas, c + Vector3.UP * (PANO + 0.05))
	_ocupada["baccarat"] = false


# --- Los caballitos solos ---

func _carrera_sola() -> void:
	if sotano.has_method("correr"):
		_sonar("caballitos", sotano.to_global(_marca("Pista")), -14.0)
		await sotano.correr(_rng.randi_range(0, 4))
		_gritan("carreras", _rng.randf() < 0.5)
	_ocupada["carreras"] = false


# --- Cortar una partida sola (te sentaste en esa mesa) ---

func _cosas_de(mesa: String) -> Array:
	_cosas[mesa] = []
	return _cosas[mesa]


# Espera; si mientras tanto te sentaste en esa mesa, la corta (true) y limpia lo suyo
func _espera(mesa: String, segundos: float) -> bool:
	await get_tree().create_timer(segundos).timeout
	if not is_inside_tree() or not _ocupada[mesa]:
		return true
	if _en_uso(_ui_de(mesa)):
		_cortar(mesa)
		return true
	return false


func _cortar(mesa: String) -> void:
	for c in _cosas.get(mesa, []):
		if is_instance_valid(c):
			c.queue_free()
	_cosas[mesa] = []
	_ocupada[mesa] = false


# --- Cartas, globos y sonidos ---

# Una carta sale del lado del crupier, vuela a `donde` y se queda boca abajo (carta -1) o arriba
func _carta(desde: Vector3, donde: Vector3, giro: float, carta: int) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = CARTA
	quad.orientation = PlaneMesh.FACE_Y
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.material_override = POKER.material(-1)
	sotano.add_child(m)
	m.position = desde + Vector3.UP * 0.05
	m.rotation.y = giro
	# (los tweens son de la carta, no de Vida: si _cortar la borra a medio vuelo, mueren con ella; si
	# no, la lambda llamaba a una carta ya liberada)
	var t := m.create_tween()
	t.tween_method(func(f: float) -> void:
		m.position = (desde + Vector3.UP * 0.05).lerp(donde + Vector3.UP * 0.003, f) + Vector3.UP * sin(f * PI) * 0.06, 0.0, 1.0, 0.25)
	if carta >= 0:
		t.tween_callback(_voltear.bind(m, carta))
	_sonar("carta", sotano.to_global(donde), -18.0)
	return m


func _voltear(m: MeshInstance3D, carta: int) -> void:
	if not is_instance_valid(m):
		return
	var y := m.position.y
	var t := m.create_tween()
	t.tween_method(func(f: float) -> void:
		m.rotation.z = f * PI / 2.0
		m.position.y = y + f * 0.03, 0.0, 1.0, 0.08)
	t.tween_callback(func() -> void: m.material_override = POKER.material(carta))
	t.tween_method(func(f: float) -> void:
		m.rotation.z = (1.0 - f) * PI / 2.0
		m.position.y = y + (1.0 - f) * 0.03, 0.0, 1.0, 0.08)


func _recoger(cosas: Array, a: Vector3) -> void:
	for c in cosas:
		if not is_instance_valid(c):
			continue
		var nodo := c as Node3D
		var desde := nodo.position
		var t := nodo.create_tween()
		t.tween_method(func(f: float) -> void: nodo.position = desde.lerp(a, f), 0.0, 1.0, 0.3)
		t.tween_callback(nodo.queue_free)


func _sentado(asiento: String) -> Node3D:
	for n in sotano.get_children():
		if n.get_meta("asiento", "") == asiento:
			return n as Node3D
	return null


# Los mirones de esa mesa gritan (uno o dos)
func _gritan(que: String, gana: bool) -> void:
	var de_ahi := _mirones.filter(func(m: Array) -> bool: return m[1] == que)
	de_ahi.shuffle()
	for k in mini(de_ahi.size(), 2):
		_globo(de_ahi[k][0], (GRITOS.gana if gana else GRITOS.pierde).pick_random(), 2.0)
		await get_tree().create_timer(0.4).timeout


# Un globo de texto arriba de la cabeza que sube un poco y se va
func _globo(quien: Node3D, texto: String, segundos := 2.0) -> void:
	if quien == null or not is_instance_valid(quien) or quien.has_meta("globo"):
		return
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.0035
	l.modulate = Color(1.0, 0.95, 0.75)
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quien.add_child(l)
	quien.set_meta("globo", true)
	var alto := 1.25 if String(quien.get_meta("asiento", "")) != "" else 1.85
	l.position = Vector3(0, alto, 0)
	var t := l.create_tween()
	t.tween_property(l, "position:y", alto + 0.15, segundos)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(segundos - 0.4)
	t.tween_callback(func() -> void:
		if is_instance_valid(quien):
			quien.remove_meta("globo")
		l.queue_free())


func _sonar(nombre: String, donde: Vector3, db := -12.0, tono := 1.0) -> void:
	var stream := Sonidos.sonido(nombre)
	if stream == null:
		return
	var voz := AudioStreamPlayer3D.new()
	voz.stream = stream
	voz.volume_db = db
	voz.pitch_scale = tono
	voz.unit_size = 2.0
	voz.max_distance = 14.0
	voz.finished.connect(voz.queue_free)
	sotano.add_child(voz)
	voz.global_position = donde
	voz.play()


# --- Reacciones a ti (JuegoSotano.festejar) ---

# Ganando en grande (premio de 10 o mas, o tres seguidas) los de cerca te voltean a ver y dicen algo;
# perdiendo seguido (tres) se burlan
func reaccionar(gano: bool, premio: int, racha: int) -> void:
	if gano:
		ganado += premio
	var grande := gano and (premio >= 10 or racha >= 3)
	var burla := not gano and racha <= -3
	if not grande and not burla:
		return
	var cerca: Array[Node3D] = []
	for n in sotano.get_children():
		if n is Node3D and (n.has_meta("asiento") or _mirones.any(func(m: Array) -> bool: return m[0] == n)):
			if (n as Node3D).global_position.distance_to(_jugador.global_position) < 6.0 * sotano.global_basis.get_scale().x:
				cerca.append(n)
	cerca.shuffle()
	for k in mini(cerca.size(), 3):
		var n := cerca[k]
		_globo(n, (GRITOS.tu_ganas if grande else GRITOS.tu_pierdes).pick_random(), 2.2)
		# Los de pie te voltean a ver un rato
		if not n.has_meta("asiento"):
			var antes := n.rotation.y
			var meta := _giro_hacia(n, _jugador.global_position)
			var t := create_tween()
			t.tween_property(n, "rotation:y", meta, 0.3)
			t.tween_interval(2.5)
			t.tween_property(n, "rotation:y", antes, 0.5)
		await get_tree().create_timer(0.35).timeout


# El guardia: si llevas mucho ganado, te sigue con la mirada (lo llama Sotano._process)
func vigilar(guardia: Node3D) -> void:
	if guardia == null or ganado < GANA_MUCHO or _jugador == null:
		return
	guardia.rotation.y = lerp_angle(guardia.rotation.y, _giro_hacia(guardia, _jugador.global_position), 0.05)


# El giro (en su padre) para que un nodo vea `punto` como lo deja look_at (su frente es -Z)
func _giro_hacia(n: Node3D, punto: Vector3) -> float:
	var d: Vector3 = (n.get_parent() as Node3D).to_local(punto) - n.position
	return atan2(-d.x, -d.z)
