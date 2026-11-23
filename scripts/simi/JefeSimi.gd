class_name JefeSimi
extends Node3D
# El Simi bailador (JJ 2026-11-22): un Simi de 7 m con Serenol (SimiSerenol) que baila de noche en la
# planicie de pasto del sureste de map_test (SimiPlanicie). Nunca te pega en la pelea normal: te manda
# a los zombis.
#
# - Baila siempre su baile (h/Simi_Baile). Su reloj (`baile_desde`) es el compas de todos: los zombis y
#   tu, cuando te agarra el baile, brincan a ese segundo del clip y bailan igualito que el.
# - Los zombis de la noche no van por ti: van a un puesto en anillos alrededor de el (`puesto`, lo
#   pregunta Zombie._ir_a_bailar) y bailan. Al juntar JUNTA bailando (JUNTA_2 en la fase 2) deja de
#   bailar, te señala (SENALA) y los suelta a todos contra ti (`soltar_del_baile`), estes bailando o
#   no. Si matas a la mitad de JUNTA de los que bailan antes de eso, se enoja y los suelta de una.
# - A menos de AURA de el bailas tu tambien. La ola sonica (cada ONDA_CADA, un anillo que crece por el
#   piso hasta ONDA_RADIO) tambien te pone a bailar: se brinca o se rueda.
# - Bailando no te mueves ni atacas (Player.atrapar con este nodo: tiene baile_desde y cara). Solo
#   machacando golpe o brinco (`forcejear`) se llena la barra `zafarse`, que se vacia sola; no pasa de
#   ZAFARSE_TOPE hasta que algo te pega (un zombi o la patada), asi que siempre te alcanzan. Si bailas
#   PATEA_ESPERA s sin que ningun zombi suelto venga por ti, el Simi corre y te patea (te saca del baile).
# - Le pegas: bailando le entra DANO_BAILANDO del dano; al señalar y jadeando tras la patada,
#   DANO_JADEA. A media vida (FASE_2) se le cae la bata (instance uniform `con_bata` del shader).
# - Responde a las llamadas del grupo "lombrices" (golpe_cuerpo, query_ray_hit, bullet_hit,
#   apply_explosion_impulse) como el pterodactilo, asi el machete, la pistola y los arrojables le llegan
#   sin tocar player.gd. Todos los numeros son primeros intentos (docs/pruebas-balance.md).

signal murio
signal cambio_fase(fase: int)
signal solto(cuantos: int)

enum Estado { BAILA, SENALA, CORRE, PATEA, JADEA, REGRESA, HERIDO, MUERTA }

const BAILE := SimiSerenol.BAILE
const VIDA := 1000.0
const FASE_2 := 0.5
const JUNTA := 12              # zombis bailando para soltarlos
const JUNTA_2 := 8
const AURA := 8.0              # m: mas cerca, bailas
const RECLUTA := 90.0          # m: los zombis a esta distancia van a bailar con el
const PUESTO_DESDE := 10.0     # el primer anillo de puestos
const PUESTO_SEP := 2.6        # entre anillos y entre puestos de un anillo
const SENALA_DURA := 1.4
const SUELTA_DURA := 25.0      # s que los soltados no vuelven a bailar
const SUELTA_PRISA := 1.35     # y van mas rapido
const JADEA_DURA := 3.0
const HERIDO_DURA := 0.9
const ONDA_CADA := Vector2(6.0, 9.0)
const ONDA_DOBLE := 0.7        # fase 2: la segunda ola, tantos s despues
const ONDA_VEL := 14.0
const ONDA_RADIO := 35.0
const ONDA_ANCHO := 1.3
const ZAFARSE_POR := 0.07      # cada apreton
const ZAFARSE_BAJA := 0.12     # por segundo
const ZAFARSE_TOPE := 0.8      # sin que te peguen no pasa de aqui
const INMUNE := 2.5            # s tras zafarte en que no te vuelve a agarrar
const PATEA_ESPERA := 1.5
const PATEA_ZOMBI := 12.0      # un zombi suelto a esta distancia de ti cuenta como que ya viene
const CORRE_VEL := 9.0
const CAMINA_VEL := 3.0
const PATEA_DIST := 3.5
const PATADA := 30
const PATADA_EMPUJA := 3.0
const PATADA_EN := 0.35        # fraccion del clip Kick en que pega
const GIRA := 2.2
const DANO_BAILANDO := 0.5
const DANO_JADEA := 2.0
const DANO_BALA := 12.0
const DANO_EXPLOSION := 80.0
const HERIDO_CADA := 150.0     # dano junto que lo tambalea
# Los clips de Quaternius estan medidos para alguien de ~1.8 m: el Simi da pasos de su tamaño
const PASO := {"h/Sprint": 8.0, "h/Walk": 1.4}
const ALTO_HUMANO := 1.8
# Esferas de golpe en los huesos del perfil (metros, para el Simi de 7 m)
const ESFERAS := [["Hips", 1.3], ["Spine", 1.3], ["Chest", 1.4], ["Head", 1.0], ["LeftHand", 0.5],
	["RightHand", 0.5], ["LeftLowerArm", 0.5], ["RightLowerArm", 0.5], ["LeftUpperLeg", 0.8],
	["RightUpperLeg", 0.8], ["LeftLowerLeg", 0.6], ["RightLowerLeg", 0.6], ["LeftFoot", 0.5], ["RightFoot", 0.5]]
const MAT_ONDA := preload("res://shaders/onda_simi.gdshader")

static var activo: JefeSimi = null   # el que esta peleando; Zombie lo consulta

var vida := VIDA
var fase := 1
var estado := Estado.BAILA
var centro := Vector3.ZERO     # donde baila (los puestos van alrededor)
var radio := 60.0              # no se sale de aqui
var piso := 0.0
var activa := false            # peleando (SimiPlanicie lo prende al acercarte); si no, nomas baila
var zafarse := 0.0             # la barra para salir del baile (BarraSimi la dibuja)
var golpeado_bailando := false

var _modelo: Node3D
var _ap: AnimationPlayer
var _sk: Skeleton3D
var _huesos := {}
var _jugador: Node3D
var _t := 0.0
var _yaw := 0.0
var _reloj := 0.0              # el compas: segundo del baile en que va
var _largo_baile := 1.0
var _puestos := {}             # Zombie -> indice de puesto
var _bailarines := {}          # Zombie -> true (ya llegaron y bailan)
var _conectados := {}          # Zombie -> su Callable de murio
var _muertos_ronda := 0
var _onda_reloj := 7.0
var _onda_doble := -1.0
var _ondas: Array = []         # [MeshInstance3D, radio, ya_pego]
var _mat_onda: ShaderMaterial
var _bailando_t := 0.0
var _inmune_hasta := 0
var _pego := false
var _acumulado := 0.0
var _limpia := 0.0


func _ready() -> void:
	add_to_group("lombrices")
	_modelo = SimiSerenol.modelo()
	add_child(_modelo)
	_ap = SimiSerenol.reproductor(_modelo)
	_sk = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	for b in _sk.get_bone_count():
		_huesos[_sk.get_bone_name(b)] = b
	_largo_baile = _ap.get_animation(BAILE).length
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	_yaw = rotation.y
	if centro == Vector3.ZERO:
		centro = global_position
	piso = global_position.y if piso == 0.0 else piso
	_mat_onda = ShaderMaterial.new()
	_mat_onda.shader = MAT_ONDA
	_mat_onda.set_shader_parameter("tam", ONDA_RADIO * 2.0 + 4.0)
	_reloj = randf() * _largo_baile
	_bailar()


func _exit_tree() -> void:
	if activo == self:
		activo = null
	_soltar_jugador(false)


## Que empiece la pelea (SimiPlanicie al acercarte; un golpe tambien)
func empezar() -> void:
	if activa or estado == Estado.MUERTA:
		return
	activa = true
	activo = self
	_onda_reloj = randf_range(ONDA_CADA.x, ONDA_CADA.y) * 0.5
	_sonar("musica")


func junta() -> int:
	return JUNTA if fase == 1 else JUNTA_2


func bailando_cuantos() -> int:
	return _bailarines.size()


func jugador_bailando() -> bool:
	return is_instance_valid(_jugador) and _jugador.get("atrapado_por") == self


func _process(delta: float) -> void:
	_reloj = fmod(_reloj + delta, _largo_baile)
	_avanzar_ondas(delta)
	if estado == Estado.MUERTA:
		return
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return
	_t += delta
	_limpia -= delta
	if _limpia <= 0.0:
		_limpia = 0.5
		_limpiar_puestos()
	if jugador_bailando():
		_bailando_t += delta
		zafarse = maxf(zafarse - ZAFARSE_BAJA * delta, 0.0)
	match estado:
		Estado.BAILA:
			_baila(delta)
		Estado.SENALA:
			_mirar_al_jugador(GIRA * 2.0 * delta)
			if _t >= SENALA_DURA:
				_soltar_zombis()
				_cambiar(Estado.JADEA)
				_animar("h/Zombie_Idle", 0.3)
		Estado.CORRE:
			_corre(delta)
		Estado.PATEA:
			_patea()
		Estado.JADEA:
			if _t >= JADEA_DURA:
				_a_regresar()
		Estado.REGRESA:
			_regresa(delta)
		Estado.HERIDO:
			if _t >= HERIDO_DURA:
				_a_regresar()
	rotation.y = _yaw
	global_position.y = piso


# --- Bailando ---

func _bailar() -> void:
	_cambiar(Estado.BAILA)
	_ap.speed_scale = 1.0
	_ap.play(BAILE, 0.3)
	_ap.seek(_reloj, true)


func _baila(delta: float) -> void:
	_mirar_al_jugador(GIRA * 0.25 * delta)
	if not activa:
		return
	# La ola sonica
	_onda_reloj -= delta
	if _onda_reloj <= 0.0:
		_onda_reloj = randf_range(ONDA_CADA.x, ONDA_CADA.y)
		_lanzar_onda()
		if fase == 2:
			_onda_doble = ONDA_DOBLE
	if _onda_doble > 0.0:
		_onda_doble -= delta
		if _onda_doble <= 0.0:
			_lanzar_onda()
	# Muy cerca bailas tu tambien
	var d := _plano(_jugador.global_position - global_position).length()
	if d < AURA:
		_atrapar()
	# Ya junto los suyos: te señala
	if _bailarines.size() >= junta():
		_senalar(false)
		return
	# Bailando y sin zombi que venga por ti: va a patearte
	if jugador_bailando() and _bailando_t >= PATEA_ESPERA and not _viene_zombi():
		_cambiar(Estado.CORRE)
		_sonar("corre")


func _senalar(enojado: bool) -> void:
	_cambiar(Estado.SENALA)
	# La pistola apuntando al frente es el brazo estirado: te señala con el dedo
	_animar("h/Pistol_Aim_Neutral", 0.15)
	_sonar("enojo" if enojado else "senala")


func _soltar_zombis() -> void:
	var n := 0
	for z: Variant in _puestos.keys():
		if is_instance_valid(z) and z.despierto and z.estado != Zombie.Estado.MUERTO:
			z.soltar_del_baile(SUELTA_DURA, SUELTA_PRISA)
			n += 1
	for z: Variant in _conectados.keys():
		_desconectar(z)
	_puestos.clear()
	_bailarines.clear()
	_muertos_ronda = 0
	solto.emit(n)


func _viene_zombi() -> bool:
	var ahora := Time.get_ticks_msec()
	for z: Zombie in Zombie.activos:
		if z.alerta and not z.bailando and z.estado != Zombie.Estado.MUERTO and z._suelto_hasta > ahora \
				and z.global_position.distance_to(_jugador.global_position) < PATEA_ZOMBI:
			return true
	return false


# --- Los puestos de los zombis ---

## Zombie._ir_a_bailar: a donde va a bailar este zombi (INF si no le toca)
func puesto(z: Zombie) -> Vector3:
	if not activa or estado == Estado.MUERTA:
		return Vector3.INF
	if not _puestos.has(z):
		if z.global_position.distance_to(centro) > RECLUTA:
			return Vector3.INF
		var usados := {}
		for i: int in _puestos.values():
			usados[i] = true
		var i := 0
		while usados.has(i):
			i += 1
		_puestos[z] = i
		if not _conectados.has(z):
			_conectados[z] = _zombi_murio.bind(z)
			z.murio.connect(_conectados[z])
	return _lugar_puesto(_puestos[z])


## Zombie: ya llego a su puesto y baila
func llego(z: Zombie) -> void:
	_bailarines[z] = true


func _lugar_puesto(i: int) -> Vector3:
	var anillo := 0
	var r := PUESTO_DESDE
	var caben := floori(TAU * r / PUESTO_SEP)
	while i >= caben:
		i -= caben
		anillo += 1
		r = PUESTO_DESDE + anillo * PUESTO_SEP
		caben = floori(TAU * r / PUESTO_SEP)
	var a := TAU * i / caben + anillo * 0.37
	return Vector3(centro.x + cos(a) * r, piso, centro.z + sin(a) * r)


func _zombi_murio(z: Zombie) -> void:
	_desconectar(z)
	var bailaba := _bailarines.has(z)
	_puestos.erase(z)
	_bailarines.erase(z)
	if not bailaba or estado == Estado.MUERTA:
		return
	# Le matan a los que bailan: a la mitad del contador se enoja y te suelta a los que tiene
	_muertos_ronda += 1
	if _muertos_ronda >= junta() / 2 and estado == Estado.BAILA:
		_senalar(true)


func _desconectar(z: Variant) -> void:
	if _conectados.has(z):
		if is_instance_valid(z) and z.murio.is_connected(_conectados[z]):
			z.murio.disconnect(_conectados[z])
		_conectados.erase(z)


func _limpiar_puestos() -> void:
	var ahora := Time.get_ticks_msec()
	for z: Variant in _puestos.keys():
		if not is_instance_valid(z) or not z.despierto or z.estado == Zombie.Estado.MUERTO or z._suelto_hasta > ahora:
			_puestos.erase(z)
			_bailarines.erase(z)
			_desconectar(z)
		elif _bailarines.has(z) and not z.bailando:
			_bailarines.erase(z)


# --- El baile del jugador ---

func _atrapar() -> void:
	if jugador_bailando() or Time.get_ticks_msec() < _inmune_hasta or not _jugador.has_method("atrapar"):
		return
	if _jugador.atrapado():
		return
	if _jugador.atrapar(self):
		zafarse = 0.0
		golpeado_bailando = false
		_bailando_t = 0.0
		if not _jugador.golpeado.is_connected(_te_pegaron):
			_jugador.golpeado.connect(_te_pegaron)
		_sonar("atrapa")


## Player.atrapar: bailas desde este segundo del clip, al compas
func baile_desde() -> float:
	return _reloj


## Player: bailando ves hacia el Simi
func cara() -> Vector3:
	return global_position


## Player: cada apreton de golpe o brinco mientras bailas
func forcejear() -> void:
	if not jugador_bailando():
		return
	zafarse = minf(zafarse + ZAFARSE_POR, 1.0 if golpeado_bailando else ZAFARSE_TOPE)
	if zafarse >= 1.0:
		_soltar_jugador(true)


func _te_pegaron() -> void:
	if jugador_bailando():
		golpeado_bailando = true


func _soltar_jugador(inmune: bool) -> void:
	if jugador_bailando():
		_jugador.soltar_atrapado()
	zafarse = 0.0
	_bailando_t = 0.0
	if inmune:
		_inmune_hasta = Time.get_ticks_msec() + int(INMUNE * 1000.0)


# --- La ola sonica ---

func _lanzar_onda() -> void:
	var malla := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * (ONDA_RADIO * 2.0 + 4.0)
	malla.mesh = plano
	malla.material_override = _mat_onda
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	malla.top_level = true
	add_child(malla)
	malla.global_position = Vector3(global_position.x, piso + 0.08, global_position.z)
	malla.set_instance_shader_parameter("ancho", ONDA_ANCHO)
	_ondas.append([malla, 0.5, false])
	_sonar("onda")


func _avanzar_ondas(delta: float) -> void:
	for i in range(_ondas.size() - 1, -1, -1):
		var o: Array = _ondas[i]
		var malla: MeshInstance3D = o[0]
		o[1] += ONDA_VEL * delta
		var r: float = o[1]
		if r > ONDA_RADIO or estado == Estado.MUERTA:
			malla.queue_free()
			_ondas.remove_at(i)
			continue
		malla.set_instance_shader_parameter("radio", r)
		malla.set_instance_shader_parameter("fuerza", 1.0 - smoothstep(ONDA_RADIO * 0.7, ONDA_RADIO, r))
		# Te alcanza parado en el piso: bailas. Brincando pasa por debajo; rodando no te agarra
		if not o[2] and is_instance_valid(_jugador):
			var d := _plano(_jugador.global_position - malla.global_position).length()
			if absf(d - r) < ONDA_ANCHO * 0.5 + 0.3 and _jugador.is_on_floor():
				o[2] = true
				_atrapar()


# --- La patada ---

func _corre(delta: float) -> void:
	if not jugador_bailando():
		_a_regresar()
		return
	var hacia := _plano(_jugador.global_position - global_position)
	_girar_a(hacia, GIRA * 2.0 * delta)
	_animar("h/Sprint", 0.2, _paso("h/Sprint", CORRE_VEL))
	if hacia.length() <= PATEA_DIST:
		_cambiar(Estado.PATEA)
		_pego = false
		_animar("h/Kick", 0.1)
		return
	global_position = _dentro(global_position + hacia.normalized() * minf(CORRE_VEL * delta, hacia.length()))


func _patea() -> void:
	var largo := _ap.get_animation("h/Kick").length
	if not _pego and _t >= largo * PATADA_EN:
		_pego = true
		var d := _plano(_jugador.global_position - global_position).length()
		if d <= PATEA_DIST + 2.0:
			_soltar_jugador(true)
			if _jugador.has_method("recibir_dano"):
				_jugador.recibir_dano(PATADA, global_position, PATADA_EMPUJA, self)
			_sonar("patada")
	if _t >= largo:
		_cambiar(Estado.JADEA)
		_animar("h/Zombie_Idle", 0.3)
		_sonar("jadea")


func _a_regresar() -> void:
	_cambiar(Estado.REGRESA)


func _regresa(delta: float) -> void:
	var hacia := _plano(centro - global_position)
	if hacia.length() < 0.6:
		_bailar()
		return
	_girar_a(hacia, GIRA * delta)
	_animar("h/Walk", 0.3, _paso("h/Walk", CAMINA_VEL))
	global_position += hacia.normalized() * minf(CAMINA_VEL * delta, hacia.length())


# --- Golpes que recibe ---

func _herir(dano: float) -> void:
	if estado == Estado.MUERTA:
		return
	empezar()
	var factor := 1.0
	if estado == Estado.BAILA:
		factor = DANO_BAILANDO
	elif estado in [Estado.SENALA, Estado.JADEA]:
		factor = DANO_JADEA
	vida = maxf(vida - dano * factor, 0.0)
	if vida <= 0.0:
		_morir()
		return
	if fase == 1 and vida <= VIDA * FASE_2:
		fase = 2
		_quitar_bata()
		cambio_fase.emit(fase)
		_sonar("bata")
		return
	_sonar("herido", -4.0)
	if estado == Estado.BAILA:
		_acumulado += dano * factor
		if _acumulado >= HERIDO_CADA:
			_acumulado = 0.0
			_cambiar(Estado.HERIDO)
			_animar("h/Hit_Chest", 0.1)


func _quitar_bata() -> void:
	for m: MeshInstance3D in _modelo.find_children("*", "MeshInstance3D", true, false):
		m.set_instance_shader_parameter("con_bata", 0.0)


func _morir() -> void:
	remove_from_group("lombrices")
	_soltar_zombis()
	_soltar_jugador(false)
	_cambiar(Estado.MUERTA)
	_animar("h/Death01", 0.2)
	if activo == self:
		activo = null
	murio.emit()
	_sonar("muere")


func _esferas() -> Array:
	var lista := []
	for e: Array in ESFERAS:
		if _huesos.has(e[0]):
			lista.append([_hueso(e[0]), float(e[1])])
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


# La velocidad del clip para que el Simi no patine a `rapidez` m/s
func _paso(clip: String, rapidez: float) -> float:
	return rapidez / (float(PASO[clip]) * SimiSerenol.ALTO / ALTO_HUMANO)


func _hueso(nombre: String) -> Vector3:
	return _sk.global_transform * _sk.get_bone_global_pose(_huesos[nombre]).origin


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# El modelo ve hacia +Z
func _girar_a(hacia: Vector3, maximo: float) -> void:
	if Vector2(hacia.x, hacia.z).length() < 0.01:
		return
	var quiere := atan2(hacia.x, hacia.z)
	_yaw += clampf(wrapf(quiere - _yaw, -PI, PI), -maximo, maximo)


func _mirar_al_jugador(maximo: float) -> void:
	if is_instance_valid(_jugador):
		_girar_a(_jugador.global_position - global_position, maximo)


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
# "simi_<evento>". Eventos: musica (la cumbia, al empezar), onda, atrapa, senala, enojo, corre, patada,
# jadea, herido, bata, muere
func _sonar(evento: String, volumen_db := 0.0) -> void:
	var nombre := "simi_" + evento
	if Sonidos.ARCHIVOS.has(nombre):
		Sonidos.tocar(self, nombre, volumen_db)
