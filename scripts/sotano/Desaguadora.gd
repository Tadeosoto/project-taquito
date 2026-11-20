class_name Desaguadora
extends Node3D

# LA DESAGUADORA: la jefa del desague de abajo del bano del Sotano (Desague.gd la pone; el modelo
# es models/sotano/desaguadora.glb de tools/blender/sotano/desague.py). Una mujer hinchada sin cara,
# de pelo de coladera y agua negra, que se hunde en una coladera y sale por otra.
# Con rig (tools/blender/sotano/desaguadora_rig.py, AG 2026-11-19): cada estado toca su clip del
# AnimationPlayer (CLIPS), acelerado para que el aviso del clip caiga en el aviso del estado; el pelo
# y la falda se mecen con un SpringBoneSimulator3D (_resortes). Avisa cada ataque antes:
#   ZARPAZO  levanta el brazo derecho (AVISO_ZARPAZO s) y barre enfrente (cono, ZARPAZO_RADIO).
#   CHARCOS  marca circulos rojos donde estas (y dos mas cerca); al rato revientan de agua negra.
#   PELO     (fase 2+) una raya roja hacia ti y luego el latigo de pelo por esa raya.
#   GOTAS    (fase 3) del techo caen chorros donde estas, cada GOTAS_CADA s.
#   HUNDIRSE se va por una coladera lejos de ti y sale por otra.
# Despues del zarpazo se le abre el pecho (EXPUESTA_DURA s): el corazon brilla, el machete le pega
# x EXPUESTA_MULT y la pistola al corazon (PuntoDebil) x CORAZON_MULT. Al cuerpo la pistola le da
# por el PuntoDebil "cuerpo" (x1). El machete le llega porque esta en el grupo "zombis" con
# recibir_golpe y radio_golpe (como La Mojiganga).
# Fases por vida: FASE_2 y FASE_3 (grita, mas rapida). Te avisa Desague.gd con las senales.
# Mas dura (AG 2026-11-19, "muy facil para jefa"): el zarpazo es un combo de 2 o 3 (alterna brazos),
# GRITO (fase 2+) avienta con un anillo, ATRAS: si te quedas a su espalda te azota con el pelo, el
# pecho solo se abre tras el combo o el grito y menos tiempo; en fase 2 y 3 salen ahogados por las
# coladeras (Desague.soltar_ahogados) y en la 3 sube el agua negra (Desague.subir_agua).

signal vida_cambio(fraccion: float)
signal fase_cambio(fase: int)
signal murio

enum Estado { SALE, ESPERA, ZARPAZO, CHARCOS, PELO, HUNDE, EXPUESTA, MUERTA, GRITO, ATRAS }

const MODELO := preload("res://models/sotano/desaguadora.glb")
const VIDA := 1800
const FASE_2 := 0.6
const FASE_3 := 0.25
const AVISO_ZARPAZO := 0.5           # el primero del combo; los siguientes, AVISO_SEGUIDO
const AVISO_SEGUIDO := 0.3
const ZARPAZO_RADIO := 3.2
const ZARPAZO_CONO := 0.35           # dot minimo (unos 70 grados de cada lado)
const DANO_ZARPAZO := 35
const AVISO_CHARCO := 0.85
const CHARCO_RADIO := 1.0
const DANO_CHARCO := 22
const AVISO_PELO := 0.55
const PELO_LARGO := 7.0
const PELO_ANCHO := 0.7
const DANO_PELO := 28
const GOTAS_CADA := 2.0
const DANO_GOTA := 14
const AVISO_GRITO := 0.9
const GRITO_RADIO := 3.5
const DANO_GRITO := 18
const ATRAS_TARDA := 0.8             # s a su espalda antes de que te azote
const DANO_ATRAS := 22
const AHOGADOS_CADA := 12.0          # s entre tandas de ahogados (fase 2 y 3)
const EXPUESTA_DURA := 1.1
const EXPUESTA_MULT := 2.0
const CORAZON_MULT := 2.5
const VELOCIDAD := 0.7               # m/s (escena) cuando se te acerca
const SALE_DURA := 1.6
const HUNDE_DURA := 1.1
const PROFUNDO := 3.4                # lo que se hunde

var arena: Node3D                    # Desague.gd: coladeras, marcas, el jugador y el rescate
var estado := Estado.SALE
var vida := VIDA
var fase := 1
var radio_golpe := 0.75              # Player._radio_de: lo ancho del cuerpo
var es_jefe := true

var _modelo: Node3D
var _hombros: Array[Node3D] = []
var _cabeza: Node3D
var _pelo: Node3D
var _corazon_luz: Node3D
var _cuerpo_punto: PuntoDebil
var _corazon_punto: PuntoDebil
var _t := 0.0                        # tiempo en el estado
var _vivo := 0.0                     # tiempo total (respira, se mece)
var _gotas_t := 0.0
var _ataques := 0
var _jugador: Node3D
var _avisos: Array[Node3D] = []
var _atras_t := 0.0
var _anim: AnimationPlayer
# Estado -> [clip, segundos del clip hasta su golpe (para acelerarlo)]
const CLIPS := {
	Estado.SALE: ["emerge", 1.6], Estado.ESPERA: ["idle", 0.0], Estado.CHARCOS: ["charcos", 0.0],
	Estado.PELO: ["latigo", 0.5], Estado.HUNDE: ["hundir", 1.1], Estado.EXPUESTA: ["expuesta", 0.0],
	Estado.GRITO: ["grito", 0.9], Estado.ATRAS: ["atras", 0.3],
}
var _muerte_ms := -1
var _modelo_y := 0.0
const HUNDE_MUERTA := 3.0
var _ahogados_t := 0.0


func _ready() -> void:
	add_to_group("zombis")
	_modelo = MODELO.instantiate()
	add_child(_modelo)
	_anim = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim and _anim.has_animation("idle"):
		_anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	_resortes()
	for nombre in ["Hombro_L", "Hombro_R"]:
		_hombros.append(_modelo.find_child(nombre, true, false) as Node3D)
	_cabeza = _modelo.find_child("Cabeza", true, false) as Node3D
	_pelo = _modelo.find_child("Pelo", true, false) as Node3D
	_corazon_luz = _modelo.find_child("Corazon_luz", true, false) as Node3D
	if _corazon_luz:
		_corazon_luz.visible = false
	var corazon := _modelo.find_child("Corazon", true, false) as Node3D
	var rojo := StandardMaterial3D.new()
	rojo.albedo_color = Color(0, 0, 0, 0)
	rojo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cuerpo_punto = PuntoDebil.new()
	_cuerpo_punto.armar(self, "cuerpo", 0.65, rojo)
	add_child(_cuerpo_punto)
	_cuerpo_punto.position = Vector3(0, 1.75, 0)
	_corazon_punto = PuntoDebil.new()
	_corazon_punto.armar(self, "corazon", 0.2, rojo)
	if corazon:
		corazon.add_child(_corazon_punto)
	else:
		add_child(_corazon_punto)
	_corazon_punto.activo(false)
	_cuerpo_punto.malla.visible = false
	_corazon_punto.malla.visible = false
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	_cambiar(Estado.SALE)


func _process(delta: float) -> void:
	_vivo += delta
	_t += delta
	_mecer()
	if estado == Estado.MUERTA:
		if _muerte_ms >= 0:
			var f := clampf((Time.get_ticks_msec() - _muerte_ms) / (HUNDE_MUERTA * 1000.0), 0.0, 1.0)
			_modelo.position.y = lerpf(_modelo_y, -PROFUNDO, f * f)
			if f >= 1.0:
				_muerte_ms = -1
				murio.emit()
		return
	match estado:
		Estado.SALE:
			_modelo.position.y = lerpf(-PROFUNDO, 0.0, ease(clampf(_t / SALE_DURA, 0.0, 1.0), 0.4))
			if _t >= SALE_DURA:
				_cambiar(Estado.ESPERA)
		Estado.ESPERA:
			_esperar(delta)
		Estado.ZARPAZO:
			_zarpazo()
		Estado.CHARCOS:
			_charcos()
		Estado.PELO:
			_latigo()
		Estado.HUNDE:
			_hundir()
		Estado.GRITO:
			_grito()
		Estado.ATRAS:
			_atras()
		Estado.EXPUESTA:
			_inclinar(-0.25)
			if _t >= EXPUESTA_DURA * (0.8 if fase == 3 else 1.0):
				_exponer(false)
				_cambiar(Estado.ESPERA)
	# Fase 2 y 3: ahogados por las coladeras cada rato
	if fase >= 2 and arena and arena.has_method("soltar_ahogados"):
		_ahogados_t += delta
		if _ahogados_t >= AHOGADOS_CADA:
			_ahogados_t = 0.0
			arena.call("soltar_ahogados", 2 if fase == 2 else 3)
	# Fase 3: le llueve agua negra del techo encima de ti
	if fase >= 3 and estado != Estado.SALE:
		_gotas_t += delta
		if _gotas_t >= GOTAS_CADA:
			_gotas_t = 0.0
			_aviso_circulo(_al_jugador(Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))), 0.8, 0.9, DANO_GOTA, true)


# --- Estados ---

func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0
	if CLIPS.has(nuevo):
		var c: Array = CLIPS[nuevo]
		var aviso := 0.0
		match nuevo:
			Estado.SALE:
				aviso = SALE_DURA
			Estado.HUNDE:
				aviso = HUNDE_DURA
			Estado.PELO:
				aviso = AVISO_PELO
			Estado.GRITO:
				aviso = AVISO_GRITO * (0.8 if fase == 3 else 1.0)
			Estado.ATRAS:
				aviso = 0.35
			Estado.EXPUESTA:
				aviso = EXPUESTA_DURA
		_clip(c[0], c[1] / aviso if aviso > 0.0 and c[1] > 0.0 else 1.0)
	elif nuevo == Estado.ZARPAZO:
		_clip_zarpazo(0)


# Toca un clip (con un fundido corto); velocidad 1 = como en Blender
func _clip(nombre: String, velocidad := 1.0) -> void:
	if _anim == null or not _anim.has_animation(nombre):
		return
	_anim.play(nombre, 0.12, velocidad)


# Un zarpazo del combo: derecho los pares, izquierdo los nones; el clip sube el brazo en 0.5 s
func _clip_zarpazo(k: int) -> void:
	var aviso := (AVISO_ZARPAZO if k == 0 else AVISO_SEGUIDO) * (0.8 if fase == 3 else 1.0)
	_clip("zarpazo_d" if k % 2 == 0 else "zarpazo_i", 0.5 / aviso)


# El pelo y la falda se mecen: una cadena de resorte por cada Pelo_k_* y Falda_k_* del esqueleto
func _resortes() -> void:
	var esqueletos := _modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty() or not ClassDB.class_exists("SpringBoneSimulator3D"):
		return
	var esq := esqueletos[0] as Skeleton3D
	var resorte: Node = ClassDB.instantiate("SpringBoneSimulator3D")
	esq.add_child(resorte)
	var cadenas := []
	for prefijo in ["Pelo", "Falda"]:
		var k := 0
		while esq.find_bone("%s_%d_0" % [prefijo, k]) >= 0:
			var fin := 3 if prefijo == "Pelo" else 2
			cadenas.append(["%s_%d_0" % [prefijo, k], "%s_%d_%d" % [prefijo, k, fin], prefijo == "Pelo"])
			k += 1
	resorte.set("setting_count", cadenas.size())
	for i in cadenas.size():
		resorte.call("set_root_bone_name", i, cadenas[i][0])
		resorte.call("set_end_bone_name", i, cadenas[i][1])
		if resorte.has_method("set_extend_end_bone"):
			resorte.call("set_extend_end_bone", i, true)
		resorte.call("set_stiffness", i, 1.6 if cadenas[i][2] else 2.2)
		resorte.call("set_drag", i, 0.5)
		resorte.call("set_gravity", i, 0.6)


func _esperar(delta: float) -> void:
	_mirar_al_jugador(delta, 2.0)
	_brazos(0.0, 0.0, delta)
	var lejos := _distancia()
	if lejos > ZARPAZO_RADIO * 0.85:
		var hacia := (_jugador.global_position - global_position) if _jugador else Vector3.ZERO
		hacia.y = 0.0
		if hacia.length() > 0.01:
			global_position += hacia.normalized() * VELOCIDAD * (1.4 if fase == 3 else 1.0) * delta * global_basis.get_scale().x
	# A su espalda mucho rato: te azota con el pelo
	if _a_su_espalda() and lejos < ZARPAZO_RADIO:
		_atras_t += delta
		if _atras_t >= ATRAS_TARDA:
			_atras_t = 0.0
			_cambiar(Estado.ATRAS)
			return
	else:
		_atras_t = 0.0
	var pausa := 0.6 if fase == 1 else (0.4 if fase == 2 else 0.25)
	if _t < pausa:
		return
	_ataques += 1
	if _ataques % 6 == 0 or lejos > 7.0:
		_cambiar(Estado.HUNDE)
	elif fase >= 2 and randf() < 0.25:
		_cambiar(Estado.GRITO)
	elif lejos <= ZARPAZO_RADIO:
		_cambiar(Estado.ZARPAZO)
	elif fase >= 2 and randf() < 0.5:
		_cambiar(Estado.PELO)
	else:
		_cambiar(Estado.CHARCOS)


# El combo: 2 zarpazos (3 desde la fase 2), alternando brazos; el pecho se abre al final
func _zarpazo() -> void:
	var k: int = get_meta("golpe_k", 0)
	var total := 2 if fase == 1 else 3
	var aviso := (AVISO_ZARPAZO if k == 0 else AVISO_SEGUIDO) * (0.8 if fase == 3 else 1.0)
	var der := k % 2 == 0
	if _t < aviso:
		_mirar_al_jugador(get_process_delta_time(), 4.0)
		var alto := lerpf(0.0, 2.4, _t / aviso)
		_brazos(0.0 if der else alto, alto if der else 0.0, get_process_delta_time(), true)
		return
	var golpe := (_t - aviso) / 0.22
	var baja := lerpf(2.4, 0.6, clampf(golpe, 0.0, 1.0))
	_brazos(0.0 if der else baja, baja if der else 0.0, get_process_delta_time(), true)
	if golpe >= 0.5 and not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "golpe", -2.0, 0.6)
		if _jugador and _distancia() <= ZARPAZO_RADIO:
			var frente := -global_basis.z
			frente.y = 0.0
			var hacia := _jugador.global_position - global_position
			hacia.y = 0.0
			if hacia.length() < 0.6 or frente.normalized().dot(hacia.normalized()) >= ZARPAZO_CONO:
				_herir_jugador(DANO_ZARPAZO, 1.6)
	if golpe >= 1.0:
		remove_meta("pego")
		if k + 1 < total:
			set_meta("golpe_k", k + 1)
			_t = 0.0
			_clip_zarpazo(k + 1)
			return
		remove_meta("golpe_k")
		_exponer(true)
		_cambiar(Estado.EXPUESTA)


# El grito: levanta la cabeza y abre los brazos; un anillo rojo avisa y luego revienta y avienta
func _grito() -> void:
	var aviso := AVISO_GRITO * (0.8 if fase == 3 else 1.0)
	if not has_meta("anillo"):
		set_meta("anillo", true)
		_aviso_circulo(global_position, GRITO_RADIO, aviso, 0, false, true)
		Sonidos.tocar(self, "rugido", -6.0, 0.35)
	if _t < aviso:
		_brazos(lerpf(0.0, 1.6, _t / aviso), lerpf(0.0, 1.6, _t / aviso), get_process_delta_time(), true)
		if _cabeza:
			_cabeza.rotation.x = lerpf(0.15, -0.6, _t / aviso)
		return
	if not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "rugido", 2.0, 0.3)
		if _jugador and _distancia() <= GRITO_RADIO:
			_herir_jugador(DANO_GRITO, 2.5)
	if _t >= aviso + 0.5:
		remove_meta("pego")
		remove_meta("anillo")
		_exponer(true)
		_cambiar(Estado.EXPUESTA)


# Si te quedas a su espalda: la cabeza se voltea y el pelo te azota de reversa (aviso corto)
func _atras() -> void:
	if _t < 0.35:
		if _pelo:
			_pelo.rotation.x = lerpf(0.0, 0.6, _t / 0.35)
		return
	if not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "golpe", -2.0, 1.1)
		if _jugador and _distancia() <= ZARPAZO_RADIO and _a_su_espalda():
			_herir_jugador(DANO_ATRAS, 2.0)
	if _pelo:
		_pelo.rotation.x = lerpf(0.6, 0.0, clampf((_t - 0.35) / 0.3, 0.0, 1.0))
	if _t >= 0.8:
		remove_meta("pego")
		_cambiar(Estado.ESPERA)


func _a_su_espalda() -> bool:
	if _jugador == null:
		return false
	var frente := -global_basis.z
	frente.y = 0.0
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	return hacia.length() > 0.3 and frente.normalized().dot(hacia.normalized()) < -0.4


func _charcos() -> void:
	if _t == get_process_delta_time() or not has_meta("charcos"):
		set_meta("charcos", true)
		_brazos(1.2, 1.2, 0.0, true)
		Sonidos.tocar(self, "rugido", -10.0, 0.6)
		var n := 3 if fase == 1 else 5
		for k in n:
			var p := _al_jugador(Vector3.ZERO if k == 0 else Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2)))
			_aviso_circulo(p, CHARCO_RADIO, AVISO_CHARCO * (0.85 if fase == 3 else 1.0), DANO_CHARCO, false)
	_brazos(1.2, 1.2, get_process_delta_time(), true)
	if _t >= 1.4:
		remove_meta("charcos")
		_cambiar(Estado.ESPERA)


func _latigo() -> void:
	if not has_meta("raya"):
		var hacia := (_jugador.global_position - global_position) if _jugador else -global_basis.z
		hacia.y = 0.0
		set_meta("raya", hacia.normalized())
		_aviso_raya(hacia.normalized(), AVISO_PELO)
	var dir: Vector3 = get_meta("raya")
	_girar_a(dir, get_process_delta_time(), 6.0)
	if _pelo:
		_pelo.rotation.x = lerpf(0.0, -1.2, clampf((_t - AVISO_PELO) / 0.15, 0.0, 1.0)) if _t > AVISO_PELO else -0.15 * sin(_t * 20.0)
	if _t >= AVISO_PELO + 0.1 and not get_meta("pego", false):
		set_meta("pego", true)
		Sonidos.tocar(self, "golpe", -4.0, 1.3)
		if _jugador:
			var p := _jugador.global_position - global_position
			p.y = 0.0
			var largo := p.dot(dir)
			var lado := (p - dir * largo).length()
			var escala := global_basis.get_scale().x
			if largo > 0.0 and largo <= PELO_LARGO * escala and lado <= PELO_ANCHO * escala:
				_herir_jugador(DANO_PELO, 1.2)
	if _t >= AVISO_PELO + 0.6:
		remove_meta("raya")
		remove_meta("pego")
		if _pelo:
			_pelo.rotation.x = 0.0
		_cambiar(Estado.ESPERA)


func _hundir() -> void:
	if _t < HUNDE_DURA:
		_modelo.position.y = lerpf(0.0, -PROFUNDO, ease(_t / HUNDE_DURA, 2.0))
		return
	# Sale por la coladera mas lejos de ti
	if arena:
		var mejor: Vector3 = global_position
		var lejos := -1.0
		for p: Vector3 in arena.call("coladeras"):
			var d := p.distance_to(_jugador.global_position) if _jugador else 0.0
			if d > lejos:
				lejos = d
				mejor = p
		global_position = mejor
	Sonidos.tocar(self, "rugido", -8.0, 0.5)
	_cambiar(Estado.SALE)


# --- Golpes que recibe ---

# Igual que Zombie.recibir_golpe (el machete): 0 nada, 1 pego, 2 mato
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, cuerpo_a_cuerpo := true, _cabeza_ := false, _fuente := "", _revienta := false) -> int:
	return _herir(int(dano * (EXPUESTA_MULT if estado == Estado.EXPUESTA and cuerpo_a_cuerpo else 1.0)), desde)


# Los PuntoDebil (la pistola): "cuerpo" x1, "corazon" x CORAZON_MULT
func golpe_punto(id: String, dano: int, desde: Vector3, _cuerpo_a_cuerpo: bool) -> int:
	return _herir(int(dano * (CORAZON_MULT if id == "corazon" else 1.0)), desde)


func _herir(dano: int, _desde: Vector3) -> int:
	if estado == Estado.MUERTA or estado == Estado.SALE and _t < SALE_DURA * 0.5 or estado == Estado.HUNDE and _t > HUNDE_DURA * 0.5:
		return 0
	vida = maxi(vida - dano, 0)
	vida_cambio.emit(float(vida) / VIDA)
	_parpadeo()
	# Se encoge del golpe si estaba esperando
	if estado == Estado.ESPERA and _anim and _anim.current_animation == "idle":
		_clip("golpeada")
		_anim.queue("idle")
	if vida <= 0:
		_morir()
		return 2
	var fr := float(vida) / VIDA
	var nueva := 1 if fr > FASE_2 else (2 if fr > FASE_3 else 3)
	if nueva != fase:
		fase = nueva
		fase_cambio.emit(fase)
		Sonidos.tocar(self, "rugido", 0.0, 0.45)
		if arena:
			if arena.has_method("soltar_ahogados"):
				arena.call("soltar_ahogados", 2 if fase == 2 else 3)
			if fase == 3 and arena.has_method("subir_agua"):
				arena.call("subir_agua")
	return 1


func _morir() -> void:
	estado = Estado.MUERTA
	_exponer(false)
	_cuerpo_punto.activo(false)
	for a in _avisos:
		if is_instance_valid(a):
			a.queue_free()
	Sonidos.tocar(self, "rugido", 2.0, 0.4)
	# Se hunde en tiempo real (la congelada de los golpes baja el time_scale y un tween se quedaba
	# atorado: nunca avisaba que murio)
	_muerte_ms = Time.get_ticks_msec()
	_modelo_y = _modelo.position.y
	_clip("muerte")


# --- Movimiento y poses ---

func _mecer() -> void:
	var temblor := 0.0 if estado != Estado.MUERTA else sin(_vivo * 40.0) * 0.03
	if _cabeza:
		_cabeza.rotation = Vector3(0.15 + sin(_vivo * 0.9) * 0.08, sin(_vivo * 0.6) * 0.12, sin(_vivo * 1.3) * 0.05 + temblor)
	if _pelo and estado != Estado.PELO:
		_pelo.rotation.z = sin(_vivo * 1.1) * 0.06
	_modelo.rotation.z = sin(_vivo * 0.7) * 0.03


func _brazos(izq: float, der: float, delta: float, rapido := false) -> void:
	var v := 1.0 if rapido else minf(delta * 3.0, 1.0)
	for k in 2:
		var h := _hombros[k]
		if h == null:
			continue
		var meta := (izq if k == 0 else der) + sin(_vivo * 1.4 + k) * 0.06
		h.rotation.x = lerpf(h.rotation.x, meta, v)


func _inclinar(cuanto: float) -> void:
	_modelo.rotation.x = lerpf(_modelo.rotation.x, cuanto, 0.1)


func _mirar_al_jugador(delta: float, rapidez: float) -> void:
	if _jugador == null:
		return
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	_girar_a(hacia, delta, rapidez)


func _girar_a(hacia: Vector3, delta: float, rapidez: float) -> void:
	if hacia.length() < 0.01:
		return
	var meta := atan2(-hacia.x, -hacia.z)
	rotation.y = lerp_angle(rotation.y, meta, minf(delta * rapidez, 1.0))


func _distancia() -> float:
	if _jugador == null:
		return 99.0
	var d := _jugador.global_position - global_position
	d.y = 0.0
	return d.length() / global_basis.get_scale().x


func _al_jugador(corre: Vector3) -> Vector3:
	var p := _jugador.global_position if _jugador else global_position
	return p + corre * global_basis.get_scale().x


func _exponer(si: bool) -> void:
	if _corazon_luz:
		_corazon_luz.visible = si
	_corazon_punto.activo(si)
	_corazon_punto.malla.visible = false
	if not si:
		_modelo.rotation.x = 0.0


func _parpadeo() -> void:
	var t := create_tween()
	t.tween_property(_modelo, "scale", Vector3.ONE * 1.04, 0.05)
	t.tween_property(_modelo, "scale", Vector3.ONE, 0.1)


func _herir_jugador(dano: int, empuje: float) -> void:
	if arena and arena.has_method("herir_jugador"):
		arena.call("herir_jugador", dano, global_position, empuje)


# --- Avisos en el piso (rojos) y lo que revienta ---

# Un circulo rojo que crece en `donde`; al acabar revienta de agua negra y hiere si sigues adentro
func _aviso_circulo(donde: Vector3, radio: float, espera: float, dano: int, del_techo: bool, solo_aviso := false) -> void:
	var escala := global_basis.get_scale().x
	var disco := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radio
	m.bottom_radius = radio
	m.height = 0.01
	m.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.05, 0.05, 0.35)
	m.material = mat
	disco.mesh = m
	get_parent().add_child(disco)
	disco.global_position = Vector3(donde.x, global_position.y + 0.03, donde.z)
	disco.scale = Vector3(0.2, 1, 0.2) * escala
	_avisos.append(disco)
	# (el tween es del disco: si lo borran antes, al morir ella, muere con el; del de ella, la lambda
	# llamaba con el disco ya liberado)
	var t := disco.create_tween()
	t.tween_property(disco, "scale", Vector3(1, 1, 1) * escala, espera).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		if not is_instance_valid(disco):
			return
		if estado == Estado.MUERTA or solo_aviso:
			disco.queue_free()
			return
		_chorro(disco.global_position, radio * escala, del_techo)
		if _jugador:
			var d := _jugador.global_position - disco.global_position
			d.y = 0.0
			if d.length() <= radio * escala:
				_herir_jugador(dano, 0.6)
		disco.queue_free())


# La raya roja del latigo de pelo
func _aviso_raya(dir: Vector3, espera: float) -> void:
	var escala := global_basis.get_scale().x
	var raya := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(PELO_ANCHO * 2.0, PELO_LARGO)
	q.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.05, 0.05, 0.3)
	q.material = mat
	raya.mesh = q
	get_parent().add_child(raya)
	raya.global_position = global_position + dir * PELO_LARGO * 0.5 * escala + Vector3.UP * 0.03
	raya.global_basis = Basis(Vector3.UP, atan2(dir.x, dir.z)).scaled(Vector3.ONE * escala)
	_avisos.append(raya)
	var t := create_tween()
	t.tween_interval(espera + 0.3)
	t.tween_callback(raya.queue_free)


# Un chorro de agua negra que sube (o cae del techo) y se deshace
func _chorro(donde: Vector3, radio: float, del_techo: bool) -> void:
	var chorro := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radio * 0.5
	c.bottom_radius = radio * 0.8
	c.height = 1.0
	c.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.025, 0.03)
	mat.roughness = 0.1
	mat.metallic_specular = 1.0
	c.material = mat
	chorro.mesh = c
	get_parent().add_child(chorro)
	var alto := 3.2 * global_basis.get_scale().x
	chorro.global_position = donde + Vector3.UP * (alto * 0.5 if del_techo else 0.0)
	chorro.scale = Vector3(1, 0.05, 1)
	Sonidos.tocar(chorro, "paso", -2.0, 0.4)
	var t := create_tween()
	t.tween_property(chorro, "scale:y", alto if del_techo else alto * 0.6, 0.12)
	t.tween_property(chorro, "position:y", chorro.position.y + (0.0 if del_techo else alto * 0.3), 0.12)
	t.tween_property(chorro, "scale", Vector3(0.2, 0.05, 0.2), 0.35)
	t.tween_callback(chorro.queue_free)
