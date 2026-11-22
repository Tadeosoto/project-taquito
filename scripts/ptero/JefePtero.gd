class_name JefePtero
extends Node3D
# El pterodactilo de Juarez (JJ, 2026-11-22): 8 m de punta a punta, no es nada en la historia, en Ciudad
# Juarez hay pterodactilos y este se vino. Vive en el claro del centro-oeste de map_test (PteroClaro).
# Modelo: Picky the Pterodactyl (Sketchfab, CC-BY, models/personajes/ptero_picky/), 26 clips de aire y
# piso; mira a -Z como Godot.
#
# La pelea, en dos fases por vida:
#   1. En el aire: da vueltas sobre ti (RONDA) y cada tanto se para, chilla (AVISO, el aviso para rodar)
#      y se avienta en picada con las garras (PICADA). Pasa de largo rozando el piso (RASANTE): ahi lo
#      alcanza el machete; arriba solo la pistola y lo que avientas.
#   2. Con la mitad de la vida se cae (CAE) y pelea en el piso: camina hacia ti, picotea y aletea
#      (ATACA, el golpe sale de los huesos de la cabeza y las alas del clip), ruge y embiste (RUGE,
#      CARGA). Si le bajas mucho de golpe se tambalea (HERIDO). Cada VUELO_CADA s vuelve a volar,
#      da PICADAS_POR_VUELO picadas y aterriza (ATERRIZA).
# Los clips traen movimiento horneado: los de vuelo llevan el cuerpo VUELO_CUERPO m arriba del origen,
# Land baja el cuerpo de 4.9 a 1.5 m y Take Off avanza 33 m al final (se corta en DESPEGUE_CORTE). El
# cambio aire/piso se hace cuando el cuerpo va a la altura de pie (CUERPO_PIE), asi no brinca.
# Responde a las llamadas del grupo "lombrices" (golpe_cuerpo, query_ray_hit, bullet_hit,
# apply_explosion_impulse) como la cucarrata: el machete y la pistola le pegan sin tocar player.gd.

signal murio
signal desperto
signal cambio_fase(fase: int)

enum Estado { DUERME, DESPIERTA, DESPEGA, RONDA, AVISO, PICADA, RASANTE, SUBE, BAJA, ATERRIZA,
	CAE, CAMINA, ATACA, RUGE, CARGA, HERIDO, MUERTA }
const EN_AIRE := [Estado.DESPEGA, Estado.RONDA, Estado.AVISO, Estado.PICADA, Estado.RASANTE, Estado.SUBE,
	Estado.BAJA, Estado.CAE]

const MODELO := "res://models/personajes/ptero_picky/ptero_picky.scn"
const ENVERGADURA_MODELO := 7.74   # m de punta a punta a escala 1 (huesos de los dedos)
const ENVERGADURA := 8.0           # JJ: grande
const VUELO_CUERPO := 4.2          # m del origen al cuerpo en los clips de vuelo (escala 1)
const CUERPO_PIE := 1.5            # m del piso al cuerpo parado (escala 1)
const DESPEGUE_CORTE := 1.75       # s de Take Off antes de que se vaya 33 m adelante
const LOOPS := ["Ground_Idle", "Ground_Walk", "Ground_Run", "Fly_Idle", "Fly_Flap", "Fly_Injure 2"]
# Esferas de golpe en los huesos: [hueso, radio a escala 1]
const ESFERAS := [["head_06", 0.55], ["neck001_05", 0.45], ["neck_04", 0.5], ["back002_03", 0.9],
	["back001_02", 0.9], ["back_00", 0.8], ["l_arm_a_09", 0.6], ["l_hand_010", 0.6], ["r_arm_a_013", 0.6],
	["r_hand_014", 0.6], ["l_foot_018", 0.35], ["r_foot_022", 0.35]]
const PICO := ["head_06", "jaw_07"]
const ALAS := ["l_hand_010", "r_hand_014", "l_finger_011", "r_finger_015"]
const GARRAS_HUESOS := ["l_foot_018", "r_foot_022", "head_06"]

# Todos los numeros son primeras ideas (docs/pruebas-balance.md)
const VIDA := 1500.0
const FASE_2 := 0.5                # fraccion de vida en que se cae y pelea en el piso
# Aire
const RONDA_RADIO := 20.0
const RONDA_ALTO := 11.0           # m del piso al cuerpo
const RONDA_VEL := 10.0
const PICADA_CADA := Vector2(5.0, 8.0)
const AVISO_DURA := 1.1
const PICADA_VEL := 24.0
const PICADA_ALTO := 1.8           # el cuerpo al fondo de la picada
const PICADA_CLIP := 9.0           # m antes de ti empieza el zarpazo (Fly_Attack 2, 0.83 s)
const RASANTE_DURA := 1.8
const RASANTE_VEL := 7.0
const SUBE_VEL := 7.0
const GARRAS := 25
const GARRAS_ALCANCE := 2.2        # hueso de las patas o la cabeza al pecho
const ESQUIVA := 0.15              # chance de esquivar de lado al recibir un balazo dando vueltas
# Piso
const GIRA := 2.6                  # rad/s
const CAMINA_VEL := 3.2
const ATAQUE_DIST := 7.0
const ATAQUE_PAUSA := 0.7
const PICO_ALCANCE := 1.7
const PICOTAZO := 20
const ALETAZO := 15
const CARGA_CADA := Vector2(9.0, 14.0)
const RUGE_VEL := 1.4              # Ground_Roar 2 acelerado: 1.45 s de aviso
const CARGA_VEL := 13.0
const CARGA_DURA := 1.6
const CARGA_DANO := 30
const CARGA_ALCANCE := 2.8
const VUELO_CADA := Vector2(22.0, 30.0)
const PICADAS_POR_VUELO := 2
const HERIDO_CADA := 160.0         # dano acumulado en el piso que lo tambalea
const CAE_VEL := 8.0
# Armas
const DANO_BALA := 12.0
const DANO_EXPLOSION := 90.0

var vida := VIDA
var fase := 1
var estado := Estado.DUERME
## Donde puede andar: centro y radio del claro (PteroClaro) y la altura del piso
var centro := Vector3.ZERO
var radio := 80.0
var piso := 0.0

var _modelo: Node3D
var _ap: AnimationPlayer
var _sk: Skeleton3D
var _huesos := {}                  # nombre -> indice
var _e := 1.0                      # escala
var _jugador: Node3D
var _t := 0.0                      # tiempo en el estado
var _yaw := 0.0
var _alto := 0.0                   # del piso al cuerpo, en el aire
var _ang := 0.0                    # en la ronda, alrededor del jugador
var _sentido := 1.0
var _picada_reloj := 6.0
var _carga_reloj := 10.0
var _vuelo_reloj := 25.0
var _picadas := 0                  # las que le quedan antes de aterrizar (fase 2)
var _dir := Vector3.FORWARD
var _meta := Vector3.ZERO
var _pego := false                 # ya pego en este ataque
var _clip_ataque := ""
var _acumulado := 0.0


func _ready() -> void:
	add_to_group("lombrices")
	_e = ENVERGADURA / ENVERGADURA_MODELO
	_modelo = (load(MODELO) as PackedScene).instantiate() as Node3D
	_modelo.scale = Vector3.ONE * _e
	add_child(_modelo)
	_ap = _modelo.find_children("*", "AnimationPlayer", true, false)[0]
	_sk = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	for b in _sk.get_bone_count():
		_huesos[_sk.get_bone_name(b)] = b
	for clip: String in LOOPS:
		if _ap.has_animation(clip):
			_ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	_yaw = rotation.y
	piso = global_position.y if piso == 0.0 else piso
	if centro == Vector3.ZERO:
		centro = global_position
	_animar("Ground_Idle")


## Que empiece la pelea (PteroClaro cuando te acercas; un golpe o un balazo tambien)
func despertar() -> void:
	if estado != Estado.DUERME:
		return
	desperto.emit()
	_cambiar(Estado.DESPIERTA)
	_mirar_al_jugador(TAU)
	_animar("Ground_Roar 2", 0.2)
	_sonar("ruge")


func despierto() -> bool:
	return estado != Estado.DUERME


func en_aire() -> bool:
	return estado in EN_AIRE


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return
	_t += delta
	match estado:
		Estado.DUERME:
			# Echado en el claro; de vez en cuando chilla al cielo
			if _t > 14.0:
				_t = randf_range(-6.0, 0.0)
				_animar("Ground_Roar 1", 0.3)
				_sonar("chillido", -6.0)
			elif _ap.current_animation != "Ground_Idle" and (not _ap.is_playing() or _ap.current_animation_position > 2.8):
				_animar("Ground_Idle", 0.4)
		Estado.DESPIERTA:
			if _t > 2.0:
				_despegar(1)
		Estado.DESPEGA:
			_despega(delta)
		Estado.RONDA:
			_ronda(delta)
		Estado.AVISO:
			_aviso(delta)
		Estado.PICADA:
			_picada(delta)
		Estado.RASANTE:
			_rasante(delta)
		Estado.SUBE:
			_sube(delta)
		Estado.BAJA:
			_baja(delta)
		Estado.ATERRIZA:
			if _t > _ap.get_animation("Land").length - 0.1:
				_a_camina()
		Estado.CAE:
			_cae(delta)
		Estado.CAMINA:
			_camina(delta)
		Estado.ATACA:
			_ataca()
		Estado.RUGE:
			_mirar_al_jugador(GIRA * delta)
			if _t > _ap.get_animation("Ground_Roar 2").length / RUGE_VEL:
				_cambiar(Estado.CARGA)
				_dir = _frente()
				_pego = false
				_animar("Ground_Run", 0.15, 1.3)
				_sonar("carga")
		Estado.CARGA:
			_carga(delta)
		Estado.HERIDO:
			if _t > _ap.get_animation("Ground_Injure 1").length:
				_a_camina()
	rotation.y = _yaw


# --- Aire ---

func _despegar(picadas: int) -> void:
	_cambiar(Estado.DESPEGA)
	_picadas = picadas
	_animar("Take Off", 0.25)
	_sonar("despega")


func _despega(_delta: float) -> void:
	if _t < DESPEGUE_CORTE:
		return
	# El cuerpo va a la altura de pie: de aqui sigue el codigo con los clips de vuelo
	_alto = CUERPO_PIE * _e
	_poner_alto()
	_animar("Fly_Flap", 0.3)
	_ang = _angulo_al_jugador()
	_cambiar(Estado.SUBE)


func _ronda(delta: float) -> void:
	_ang += RONDA_VEL / RONDA_RADIO * delta * _sentido
	var j := _jugador.global_position
	var meta := Vector3(j.x + cos(_ang) * RONDA_RADIO, 0.0, j.z + sin(_ang) * RONDA_RADIO)
	_volar_a(meta, RONDA_ALTO, RONDA_VEL * 1.4, delta)
	_picada_reloj -= delta
	if _picada_reloj <= 0.0:
		_cambiar(Estado.AVISO)
		_animar("Fly_Roar 1", 0.2)
		_sonar("chillido")


func _aviso(delta: float) -> void:
	# Se queda en el aire viendote y chilla: el aviso para rodar
	_mirar_al_jugador(GIRA * 2.0 * delta)
	if _t > _ap.get_animation("Fly_Roar 1").length:
		_animar("Fly_Idle", 0.2)
	if _t < AVISO_DURA:
		return
	_cambiar(Estado.PICADA)
	_picadas -= 1
	_pego = false
	_meta = _jugador.global_position
	_meta.y = piso + PICADA_ALTO
	_dir = (_meta - _cuerpo()).normalized()
	_animar("Fly_Flap", 0.15, 1.6)
	_sonar("picada")


func _picada(delta: float) -> void:
	var cuerpo := _cuerpo() + _dir * PICADA_VEL * delta
	_mover_cuerpo(cuerpo)
	_girar_a(_dir, GIRA * 3.0 * delta)
	var falta := (_meta - cuerpo).dot(_dir)
	if falta < PICADA_CLIP and _ap.current_animation != "Fly_Attack 2":
		_animar("Fly_Attack 2", 0.1)
	_garras()
	if falta <= 0.0:
		_cambiar(Estado.RASANTE)
		_dir.y = 0.0
		_dir = _dir.normalized()
		_animar("Fly_Idle", 0.3)


func _rasante(delta: float) -> void:
	# Pasa de largo rozando el piso y frenando: aqui lo alcanza el machete
	var vel := lerpf(PICADA_VEL * 0.6, RASANTE_VEL, minf(_t / 0.6, 1.0))
	var cuerpo := _cuerpo() + _dir * vel * delta
	cuerpo.y = piso + PICADA_ALTO
	_mover_cuerpo(cuerpo)
	if _t < 0.4:
		_garras()
	if _t > RASANTE_DURA:
		_animar("Fly_Flap", 0.3)
		_cambiar(Estado.SUBE)


func _sube(delta: float) -> void:
	var adelante := _cuerpo() + _frente() * 10.0
	_volar_a(adelante, RONDA_ALTO, SUBE_VEL, delta)
	if _alto >= RONDA_ALTO - 0.5:
		_ang = _angulo_al_jugador()
		_sentido = 1.0 if randf() < 0.5 else -1.0
		_picada_reloj = randf_range(PICADA_CADA.x, PICADA_CADA.y)
		# En la fase 2 vuela solo un rato: se acabaron sus picadas, a aterrizar
		if fase == 2 and _picadas <= 0:
			_cambiar(Estado.BAJA)
			var lado := Vector3(cos(_ang), 0.0, sin(_ang))
			_meta = _dentro(_jugador.global_position + lado * 12.0)
			_animar("Fly_Idle", 0.3)
		else:
			_cambiar(Estado.RONDA)
			_animar("Fly_Flap", 0.3)


func _baja(delta: float) -> void:
	# Al lugar donde aterriza, bajando hasta que el origen toca el piso; ahi Land baja el cuerpo
	_volar_a(_meta, VUELO_CUERPO * _e, RONDA_VEL, delta)
	_mirar_al_jugador(GIRA * delta)
	var plano := Vector2(_meta.x - global_position.x, _meta.z - global_position.z).length()
	if plano < 1.0 and _alto <= VUELO_CUERPO * _e + 0.2:
		_alto = VUELO_CUERPO * _e
		_poner_alto()
		_cambiar(Estado.ATERRIZA)
		_animar("Land", 0.2)
		_sonar("aterriza")


func _cae(delta: float) -> void:
	_alto = maxf(_alto - CAE_VEL * delta, CUERPO_PIE * _e)
	_poner_alto()
	if _alto <= CUERPO_PIE * _e:
		global_position.y = piso
		_sonar("cae")
		if vida <= 0.0:
			_quedar_muerto()
		else:
			_cambiar(Estado.HERIDO)
			_animar("Ground_Injure 1", 0.15)


# Vuela hacia meta (en el plano) a `alto` del piso, con el cuerpo viendo a donde va
func _volar_a(meta: Vector3, alto: float, rapidez: float, delta: float) -> void:
	meta = _dentro(meta)
	var aqui := Vector3(global_position.x, 0.0, global_position.z)
	var hacia := Vector3(meta.x, 0.0, meta.z) - aqui
	var paso := minf(hacia.length(), rapidez * delta)
	if hacia.length() > 0.01:
		global_position += hacia.normalized() * paso
		_girar_a(hacia, GIRA * 1.5 * delta)
	_alto = move_toward(_alto, alto, SUBE_VEL * delta)
	_poner_alto()


func _poner_alto() -> void:
	global_position.y = piso + _alto - VUELO_CUERPO * _e


func _cuerpo() -> Vector3:
	return global_position + Vector3.UP * (VUELO_CUERPO * _e)


func _mover_cuerpo(cuerpo: Vector3) -> void:
	var p := _dentro(cuerpo)
	_alto = cuerpo.y - piso
	global_position = Vector3(p.x, piso + _alto - VUELO_CUERPO * _e, p.z)


func _garras() -> void:
	if _pego:
		return
	var pecho := _jugador.global_position
	for h: String in GARRAS_HUESOS:
		if _hueso(h).distance_to(pecho) < GARRAS_ALCANCE * _e:
			_pego = true
			_pegar(GARRAS, 2.0)
			_sonar("garras")
			return


# --- Piso ---

func _a_camina() -> void:
	global_position.y = piso
	_cambiar(Estado.CAMINA)
	_animar("Ground_Walk", 0.25)


func _camina(delta: float) -> void:
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	var d := hacia.length()
	_girar_a(hacia, GIRA * delta)
	var de_frente := d > 0.1 and _frente().dot(hacia / d) > 0.85
	if d > ATAQUE_DIST * 0.8:
		var p := _dentro(global_position + _frente() * CAMINA_VEL * delta)
		global_position = Vector3(p.x, piso, p.z)
		_animar("Ground_Walk", 0.25)
	elif _t > ATAQUE_PAUSA:
		_animar("Ground_Idle", 0.3)
	_carga_reloj -= delta
	_vuelo_reloj -= delta
	if _vuelo_reloj <= 0.0:
		_vuelo_reloj = randf_range(VUELO_CADA.x, VUELO_CADA.y)
		_despegar(PICADAS_POR_VUELO)
		return
	if _carga_reloj <= 0.0 and d > ATAQUE_DIST:
		_carga_reloj = randf_range(CARGA_CADA.x, CARGA_CADA.y)
		_cambiar(Estado.RUGE)
		_animar("Ground_Roar 2", 0.2, RUGE_VEL)
		_sonar("ruge")
		return
	if d < ATAQUE_DIST and de_frente and _t > ATAQUE_PAUSA:
		_cambiar(Estado.ATACA)
		_pego = false
		_clip_ataque = ["Ground_Attack 1", "Ground_Attack 2", "Ground_Attack 3"].pick_random()
		_animar(_clip_ataque, 0.15)


func _ataca() -> void:
	# El golpe sale del clip: si el pico o las puntas de las alas pasan por tu pecho a mitad del ataque
	var largo := _ap.get_animation(_clip_ataque).length
	if not _pego and _t > largo * 0.25 and _t < largo * 0.75:
		var pecho := _jugador.global_position
		for h: String in PICO + ALAS:
			if _hueso(h).distance_to(pecho) < PICO_ALCANCE * _e:
				_pego = true
				_pegar(PICOTAZO if h in PICO else ALETAZO, 1.5)
				_sonar("picotazo" if h in PICO else "aletazo")
				break
	if _t > largo:
		_a_camina()


func _carga(delta: float) -> void:
	var antes := global_position
	var p := _dentro(global_position + _dir * CARGA_VEL * delta)
	global_position = Vector3(p.x, piso, p.z)
	if not _pego:
		var j := _jugador.global_position
		if Vector2(j.x - global_position.x, j.z - global_position.z).length() < CARGA_ALCANCE * _e:
			_pego = true
			_pegar(CARGA_DANO, 3.0)
	# Se acaba el tiempo o topa con la orilla del claro
	if _t > CARGA_DURA or antes.distance_to(global_position) < CARGA_VEL * delta * 0.3:
		_a_camina()


# --- Vida y armas ---

func _herir(dano: float) -> void:
	if estado == Estado.MUERTA:
		return
	if estado == Estado.DUERME:
		despertar()
	vida = maxf(vida - dano, 0.0)
	if vida <= 0.0:
		_morir()
		return
	if fase == 1 and vida <= VIDA * FASE_2:
		fase = 2
		cambio_fase.emit(fase)
		_vuelo_reloj = randf_range(VUELO_CADA.x, VUELO_CADA.y)
		_carga_reloj = randf_range(CARGA_CADA.x, CARGA_CADA.y) * 0.5
		if en_aire() and estado != Estado.DESPEGA:
			_caer()
		return
	_sonar("herido", -4.0)
	# En el piso, mucho dano junto lo tambalea (la ventana para castigarlo)
	if estado in [Estado.CAMINA, Estado.ATACA]:
		_acumulado += dano
		if _acumulado >= HERIDO_CADA:
			_acumulado = 0.0
			_cambiar(Estado.HERIDO)
			_animar(["Ground_Injure 1", "Ground_Injure 2"].pick_random(), 0.1)


func _caer() -> void:
	_cambiar(Estado.CAE)
	_animar("Fly_Injure 2", 0.15)
	_sonar("chillido")


func _morir() -> void:
	remove_from_group("lombrices")
	murio.emit()
	_sonar("muere")
	if en_aire():
		_caer()
	else:
		_quedar_muerto()


func _quedar_muerto() -> void:
	global_position.y = piso
	_cambiar(Estado.MUERTA)
	_animar("Ground_Die", 0.2)


func _esferas() -> Array:
	var lista := []
	for e: Array in ESFERAS:
		lista.append([_hueso(e[0]), float(e[1]) * _e])
	return lista


func query_ray_hit(origen: Vector3, dir: Vector3, max_dist: float, radio_rayo: float) -> Dictionary:
	if estado == Estado.MUERTA:
		return {}
	var d := dir.normalized()
	var mejor := max_dist
	var pego := false
	for e in _esferas():
		var t := JefeCucarrata._esfera(origen, d, e[0], e[1] + radio_rayo)
		if t >= 0.0 and t < mejor:
			mejor = t
			pego = true
	if not pego:
		return {}
	return {"dot_index": 0, "position": origen + d * mejor, "distance": mejor}


func bullet_hit(_i: int, punto: Vector3, _d: Vector3) -> void:
	_fx("cria_corte", punto)
	# Dando vueltas a veces se hace a un lado (Fly_Dodge): cambia de sentido y se acerca
	if estado == Estado.RONDA and randf() < ESQUIVA:
		_animar("Fly_Dodge", 0.1)
		_sentido = -_sentido
		_picada_reloj = minf(_picada_reloj, 1.5)
		return
	_herir(DANO_BALA)


func golpe_cuerpo(origen: Vector3, frente: Vector3, alcance: float, cono: float, dano: int, giro := false, _todas := false) -> bool:
	if estado == Estado.MUERTA:
		return false
	for e in _esferas():
		var hacia: Vector3 = e[0] - origen
		if absf(hacia.y) > 2.0 + e[1]:
			continue
		hacia.y = 0.0
		if hacia.length() - e[1] > alcance:
			continue
		if not giro and hacia.length() > 0.3 and hacia.normalized().dot(frente) < cono:
			continue
		_fx("cria_corte", e[0] - hacia.normalized() * e[1])
		_herir(float(dano))
		return true
	return false


func apply_explosion_impulse(punto: Vector3, radio_exp: float, _fuerza: float, _algo = null) -> void:
	for e in _esferas():
		if punto.distance_to(e[0]) < radio_exp + e[1]:
			_herir(DANO_EXPLOSION)
			return


# --- Ayudas ---

func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0


func _animar(clip: String, mezcla := 0.2, vel := 1.0) -> void:
	_ap.speed_scale = vel
	if _ap.current_animation == clip and _ap.is_playing():
		return
	if _ap.has_animation(clip):
		_ap.play(clip, mezcla)


func _pegar(dano: int, empuja: float) -> void:
	if _jugador.has_method("recibir_dano"):
		_jugador.recibir_dano(dano, global_position, empuja, self)


func _hueso(nombre: String) -> Vector3:
	return _sk.global_transform * _sk.get_bone_global_pose(_huesos[nombre]).origin


func _frente() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func _girar_a(hacia: Vector3, maximo: float) -> void:
	if Vector2(hacia.x, hacia.z).length() < 0.01:
		return
	var quiere := atan2(-hacia.x, -hacia.z)
	_yaw += clampf(wrapf(quiere - _yaw, -PI, PI), -maximo, maximo)


func _mirar_al_jugador(maximo: float) -> void:
	_girar_a(_jugador.global_position - global_position, maximo)


func _angulo_al_jugador() -> float:
	var desde := global_position - _jugador.global_position
	return atan2(desde.z, desde.x)


# Un punto del plano adentro del claro
func _dentro(p: Vector3) -> Vector3:
	var plano := Vector2(p.x - centro.x, p.z - centro.z)
	if plano.length() > radio:
		plano = plano.normalized() * radio
	return Vector3(centro.x + plano.x, p.y, centro.z + plano.y)


func _fx(lugar: String, donde: Vector3) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, Vector3.ZERO, 1.0)


# Sonidos pendientes (JJ los escoge en Splice): suenan solos en cuanto `Sonidos.ARCHIVOS` tenga
# "ptero_<evento>". Eventos: ruge, chillido, despega, picada, garras, aterriza, cae, carga, picotazo,
# aletazo, herido, muere
func _sonar(evento: String, volumen_db := 0.0) -> void:
	var nombre := "ptero_" + evento
	if Sonidos.ARCHIVOS.has(nombre):
		Sonidos.tocar(self, nombre, volumen_db)
