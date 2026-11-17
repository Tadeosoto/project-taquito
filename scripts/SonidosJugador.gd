class_name SonidosJugador
extends Node

# Los sonidos del cuerpo del jugador que dependen de como va: los pasos (S-051) y el latido
# con poca vida (S-054). Lo crea Partida; no toca player.gd: solo lee su velocidad y el suelo.

# Un paso cada tanto de camino recorrido, no cada tanto de tiempo: asi corriendo suenan mas
# seguidos y parado no suena. Corres cuando pasas de la mitad entre caminar y sprint
const ZANCADA_CAMINA := 1.3   # m entre paso y paso
const ZANCADA_CORRE := 2.1
const PASO_DB := Vector2(-21.0, -16.0)   # caminando, corriendo (JJ 2026-11-16: -15 dB, sonaban muy fuerte)
# Los samples vienen normalizados distinto (tierra suena 4 dB mas que asfalto): esto los empata
const PASO_AJUSTE := {"paso_asfalto": 0.0, "paso_interior": -2.0, "paso_tierra": -4.0}
const PASO_TONO := Vector2(0.93, 1.07)
const VELOCIDAD_MIN := 0.6   # m/s: abajo de esto no suena

# El latido arranca con esta fraccion de vida y va de LATIDO_LENTO a LATIDO_RAPIDO s entre
# latidos conforme baja, hasta el 5 % de vida
const LATIDO_DESDE := 0.35
const LATIDO_HASTA := 0.05
const LATIDO_LENTO := 1.15
const LATIDO_RAPIDO := 0.5
const LATIDO_TONO_MAX := 1.15
const LATIDO_DB := Vector2(-14.0, -10.0)   # al arrancar, y casi muerto (antes -8 a -1: casi muerto tapaba todo)

# La respiracion cansada (S-053): un loop que entra con poca vida o despues de correr mucho sin
# parar, y se va suave cuando te recuperas
const ALIENTO_VIDA := 0.35        # fraccion de vida desde la que jadeas
const ALIENTO_CORRE_S := 7.0      # s corriendo seguidos para quedar sin aire
const ALIENTO_SALE_S := 2.0       # el cansancio baja a esto y se te quita
const ALIENTO_DB := Vector2(-22.0, -9.0)   # al entrar y con casi nada de vida
const ALIENTO_SUBE := 18.0        # dB por segundo al entrar y al salir
const ALIENTO_APAGADO := -45.0

var _jugador: Player
var _cansancio := 0.0
var _sin_aire := false
var _voz_aliento: AudioStreamPlayer
var _recorrido := 0.0
var _lado := 0
var _estaba_en_suelo := true
var _pasto: Node   # MapPasto del mapa grande, si hay
var _latido := 0.0
var _voz_paso: Array[AudioStreamPlayer] = []
var _voz_latido: AudioStreamPlayer


func _ready() -> void:
	for i in 2:   # dos voces para que un paso no corte la cola del anterior
		var voz := AudioStreamPlayer.new()
		add_child(voz)
		_voz_paso.append(voz)
	_voz_latido = AudioStreamPlayer.new()
	add_child(_voz_latido)
	_voz_aliento = AudioStreamPlayer.new()
	_voz_aliento.volume_db = ALIENTO_APAGADO
	add_child(_voz_aliento)


func _process(delta: float) -> void:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Player
		if _jugador == null:
			return
	_salto()
	_pasos(delta)
	_latidos(delta)
	_aliento(delta)


# Brinco: suena al despegar (la velocidad vertical sube de golpe estando en el suelo)
func _salto() -> void:
	var en_suelo := _jugador.is_on_floor()
	if _estaba_en_suelo and not en_suelo and _jugador.velocity.y > 4.0:
		Sonidos.tocar(self, "salto", -9.0, randf_range(0.95, 1.05))
	_estaba_en_suelo = en_suelo


# Que sample de paso toca:
#  - adentro de una casa (la propia o la de un vecino: CasaPropia te pone sin combate), el de
#    interior. En las tiendas no se camina (escena fija con el jugador apagado)
#  - en el mapa grande donde la mascara de pasto dice pasto (MapPasto.hay_pasto, donde salen las
#    matas), o sobre un piso en el grupo "tierra" o "pasto", el de tierra
#  - si no, asfalto
# Los parches de pasto del mapa de Blender (piezas "suelo" del .json) no llegan al juego todavia
func _suelo() -> String:
	if _jugador.sin_combate:
		return "paso_interior"
	if _pasto == null or not is_instance_valid(_pasto):
		_pasto = get_tree().get_first_node_in_group("mapa_pasto")
	if _pasto and _pasto.hay_pasto(_jugador.global_position):
		return "paso_tierra"
	for i in _jugador.get_slide_collision_count():
		var c := _jugador.get_slide_collision(i).get_collider()
		if c is Node and (c.is_in_group("tierra") or c.is_in_group("pasto")):
			return "paso_tierra"
	return "paso_asfalto"


func _pasos(_delta: float) -> void:
	var v := Vector2(_jugador.velocity.x, _jugador.velocity.z).length()
	if not _jugador.is_on_floor() or v < VELOCIDAD_MIN:
		_recorrido = ZANCADA_CAMINA * 0.5   # el primer paso suena casi al arrancar
		return
	var corre := v > (_jugador.speed + _jugador.sprint_speed) * 0.5
	_recorrido += v * get_process_delta_time()
	if _recorrido < (ZANCADA_CORRE if corre else ZANCADA_CAMINA):
		return
	_recorrido = 0.0
	var suelo := _suelo()
	var stream := Sonidos.sonido(suelo)
	if stream == null:
		return
	var voz := _voz_paso[_lado]
	_lado = 1 - _lado
	voz.stream = stream
	voz.volume_db = (PASO_DB.y if corre else PASO_DB.x) + PASO_AJUSTE.get(suelo, 0.0)
	voz.pitch_scale = randf_range(PASO_TONO.x, PASO_TONO.y) * (1.05 if corre else 1.0)
	voz.play()


func _latidos(delta: float) -> void:
	var salud := get_node_or_null("/root/Salud")
	if salud == null or salud.vida <= 0:
		_latido = 0.0
		return
	var fraccion := float(salud.vida) / float(salud.vida_max)
	if fraccion > LATIDO_DESDE:
		_latido = 0.0
		return
	# 0 al arrancar, 1 casi muerto
	var grave := clampf((LATIDO_DESDE - fraccion) / (LATIDO_DESDE - LATIDO_HASTA), 0.0, 1.0)
	_latido -= delta
	if _latido > 0.0:
		return
	_latido = lerpf(LATIDO_LENTO, LATIDO_RAPIDO, grave)
	var stream := Sonidos.sonido("latido")
	if stream == null:
		return
	_voz_latido.stream = stream
	_voz_latido.volume_db = lerpf(LATIDO_DB.x, LATIDO_DB.y, grave)
	_voz_latido.pitch_scale = lerpf(1.0, LATIDO_TONO_MAX, grave)
	_voz_latido.play()


func _aliento(delta: float) -> void:
	var v := Vector2(_jugador.velocity.x, _jugador.velocity.z).length()
	var corre := _jugador.is_on_floor() and v > (_jugador.speed + _jugador.sprint_speed) * 0.5
	_cansancio = _cansancio + delta if corre else maxf(_cansancio - delta * 1.5, 0.0)
	if _cansancio >= ALIENTO_CORRE_S:
		_sin_aire = true
	elif _cansancio <= ALIENTO_SALE_S:
		_sin_aire = false
	var salud := get_node_or_null("/root/Salud")
	var fraccion := float(salud.vida) / float(salud.vida_max) if salud and salud.vida > 0 else 1.0
	var poca_vida := fraccion <= ALIENTO_VIDA
	var quiere := _sin_aire or poca_vida
	# Con mas vida perdida, mas fuerte (de ALIENTO_DB.x a .y)
	var grave := clampf((ALIENTO_VIDA - fraccion) / ALIENTO_VIDA, 0.0, 1.0) if poca_vida else 0.0
	var meta := lerpf(ALIENTO_DB.x, ALIENTO_DB.y, grave) if quiere else ALIENTO_APAGADO
	_voz_aliento.volume_db = move_toward(_voz_aliento.volume_db, meta, ALIENTO_SUBE * delta)
	if quiere and not _voz_aliento.playing:
		_voz_aliento.stream = Sonidos.sonido("respiracion_cansada")
		if _voz_aliento.stream:
			_voz_aliento.play()
	elif not quiere and _voz_aliento.playing and _voz_aliento.volume_db <= ALIENTO_APAGADO + 0.5:
		_voz_aliento.stop()
