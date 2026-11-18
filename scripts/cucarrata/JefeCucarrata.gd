class_name JefeCucarrata
extends Cucarrata
# La pelea contra la cucarrata (JJ, 2026-11-17). Tres fases por la vida que le queda:
# 1. En el piso: camina alrededor del jugador. Si le disparas (o te le acercas) grune: alza la
#    cabeza de rata y chilla, brinca y te da un mordidon, y se va corriendo. Cada PARE_CADA s se
#    para a parir ratas (JJ: las cucarachas voladoras solo salen cuando ella vuela).
# 2. Con 2/3 de vida despega y vuela como mosca, mas lenta que las cucarachas. En el aire bombea
#    cucarachas voladoras casi sin parar (AIRE_PARE_CADA) y las balas le bajan muy poco
#    (DANO_BALA_AIRE), pero con TUMBAR_BALAS se cae boca arriba pataleando, como cucaracha. Asi
#    tumbada el machete le baja vida de a de veras (hasta TUMBADA_VIDA por tumbada: dos por fase).
#    Al rato se voltea, suelta ratas y vuelve a volar.
# 3. Con 1/3: lo mismo, y ademas aguijonazos: cada AGUIJON_CADA s se acomoda en vertical (cabeza
#    arriba, la cola con el aguijon abajo), hace una pausa y se lanza.
# Esta en el grupo "lombrices": la pistola y el machete le preguntan como a las crias. Todos los
# numeros son de primera, para docs/pruebas-balance.md.

signal murio
signal desperto   # deambulando, te vio (o le pegaste): empieza la pelea
signal cambio_fase(fase: int)

const VIDA := 1200.0   # era 400: la fase 1 se acababa antes de verla (JJ, 2026-11-17)
const DANO_BALA := 10.0
const DANO_BALA_AIRE := 2.0       # volando las balas casi no le hacen (JJ): sirven para tumbarla
const DANO_EXPLOSION := 25.0
# Esferas para pegarle, de la cabeza a la cola (x, y, z del modelo en reposo; w = radio). Escalan
# con el nodo
const CUERPO := [Vector4(0, 0.3, -0.85, 0.2), Vector4(0, 0.3, -0.4, 0.26), Vector4(0, 0.3, 0.1, 0.3),
	Vector4(0, 0.32, 0.6, 0.3), Vector4(0, 0.32, 0.95, 0.2)]
const BOCA := Vector3(0.0, 0.25, -1.0)
const PIES := 1.0                 # el piso bajo el origen del jugador (capsula)
const PECHO := 0.35
# Caminando: da vueltas alrededor del jugador, a su distancia, cambiando de sentido a veces
const CAMINA_RADIO := Vector2(8.0, 13.0)
const CAMINA_VEL := Vector2(3.0, 4.5)
const CAMINA_GIRA := 1.2          # rad/s
const META_LLEGA := 2.5
const META_CAMBIA := 4.0
const MURO_GIRA := 4.0           # rad/s al topar con un muro de su bodega (encerrar)
# Gruñido y mordidon
const GRITA_DURA := 0.9
const SALTO_DURA := 0.9
const SALTO_ALTO := 2.5
const SALTO_MAX := 16.0           # m que puede brincar
const MORDIDA := 20
const MORDIDA_ALCANCE := 2.4      # m de la boca al pecho
const MORDIDA_EMPUJA := 3.0
const CORRE_DURA := 1.6
const CORRE_VEL := 7.0
const ENOJO_ENFRIA := 3.5         # s entre un mordidon y el siguiente
const CERCA := 6.0                # m de la boca: si te le acercas tambien brinca
# Parir (fases 2 y 3)
const PARE_CADA := 14.0
const PARE_PRIMERO := 6.0         # el primer parto en el piso, al empezar la pelea
const CRIAS_MAX := 6              # si quedan mas vivas, espera
const AIRE_PARE_CADA := 4.0       # volando: un pujo de cucarachas cada tanto, casi sin parar
const AIRE_CRIAS_MAX := 10
# Vuelo (fase 3)
const VUELO_ALTO := Vector2(4.0, 6.0)
const VUELO_RADIO := Vector2(7.0, 14.0)
const VUELO_VEL := Vector2(4.0, 5.5)
const VUELO_GIRA := 1.4
const VUELO_ABRE := 1.2
const DESPEGA_DURA := 1.6
const AGUIJON_CADA := 5.0
const APUNTA_DURA := 1.3          # la pausa en vertical antes de lanzarse (el aviso para rodar)
const APUNTA_DIST := 9.0
const APUNTA_ALTO := 2.8          # m del piso a la punta de la cola ya parada (el origen sube su largo)
const PICADA_VEL := 16.0
const PICADA_ACELERA := 22.0
const PICADA_GIRA := 1.2
const PICADA_MAX := 1.8
const AGUIJON := 25
const AGUIJON_ALCANCE := 1.8
const AGUIJON_EMPUJA := 3.5
const SUBE_DURA := 1.4
const GRAVEDAD := 14.0
# Tumbada (fase 3, JJ): a balazos se cae boca arriba y patalea; ahi el machete le baja vida
const TUMBAR_BALAS := 6
const TUMBAR_EXPLOSION := 3       # una explosion cuenta como tantas balas
const TUMBADA_DURA := 7.0         # s pataleando antes de voltearse
const TUMBADA_VIDA := VIDA / 6.0 + 0.5   # lo que le baja una tumbada: la fase 3 (1/3) son dos
const TUMBADA_ALTO := 0.62        # m del modelo del piso al lomo: boca arriba, el origen sube eso
const PATALEA := 3.0              # velocidad de "camina" con las patas al aire
const VOLTEA_DURA := 0.9
const VOLTEA_BRINCO := 1.2
# Sonidos (S-106 a S-127, audio/cucarrata/): el dolor no en cada golpe; un chillido cada tanto volando;
# los loops (patas rondando, alas, pataleo) segun el estado, en _sonar_loop
const DOLOR_CADA_MS := 450
const GRITO_VUELO := Vector2(4.0, 8.0)
const RONDA_OIDO := 70.0          # m: rondando, de ahi para alla ya no se oyen sus patas

enum Estado { CAMINA, GRITA, SALTA, CORRE, PARE, DESPEGA, VUELA, APUNTA, PICADA, SUBE, CAE, MUERTA,
		TUMBA, PATAS, VOLTEA, DEAMBULA }
const EN_VUELO := [Estado.DESPEGA, Estado.VUELA, Estado.APUNTA, Estado.PICADA, Estado.SUBE]

# Suelta en la calle (CucarrataCalle): deambula por `pedir_ruta` (de donde esta a otra calle) sin
# hacerte caso hasta que te le acercas (DESPIERTA) o le pegas
const DEAMBULA_VEL := 2.2
const DEAMBULA_ANIM := 0.7        # velocidad de "camina" al deambular
const DESPIERTA := 22.0           # m de la boca al jugador
const DEAMBULA_LLEGA := 2.0
var deambulando := false
var pedir_ruta: Callable
# Donde la encierran (CucarrataCalle.encerrar, la bodega): recibe su posicion y la devuelve adentro
var encerrar: Callable
# Si te ve (CucarrataCalle.adentro: entraste a la bodega, a cualquier distancia); sin esto, DESPIERTA
# aunque haya un muro
var te_ve: Callable
var _ruta := PackedVector3Array()
var _ruta_i := 0

var vida := VIDA
var fase := 1
var estado := Estado.CAMINA
var _jugador: Node3D
var _listo := false
var _piso := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0                  # PI = boca arriba
var _balazos_vuelo := 0
var _tumbada_queda := 0.0
var _reloj := 0.0
var _t := 0.0
var _meta := Vector3.ZERO
var _meta_reloj := 0.0
var _rapidez := 3.0
var _sentido := 1.0
var _vel := Vector3.ZERO
var _ultimo_enojo := -100000
var _pare_reloj := 0.0
var _aguijon_reloj := 0.0
var _salto_desde := Vector3.ZERO
var _salto_hasta := Vector3.ZERO
var _mordio := false
var _apunta_en := Vector3.ZERO
var _cabeza: Node3D
var _cabeza_base := Transform3D()
var _cabeza_angulo := 0.0
var _aguijon: Node3D              # la punta del aguijon
var _ultimo_dolor := -100000
var _grito_reloj := 3.0
var _voz_loop: AudioStreamPlayer
var _loop_nombre := ""


func _ready() -> void:
	animacion_inicial = "camina"
	super._ready()
	add_to_group("lombrices")
	_cabeza = find_children("CabezaRata", "MeshInstance3D", true, false)[0]
	_cabeza_base = _cabeza.transform
	_poner_aguijon()


# El primer cuadro: quien la puso ya la acomodo (posicion y hacia donde ve)
func _empezar() -> void:
	_listo = true
	_piso = global_position.y
	_pare_reloj = PARE_PRIMERO
	var frente := -global_transform.basis.z
	_yaw = atan2(-frente.x, -frente.z)
	_meta_reloj = 0.0
	if deambulando:
		estado = Estado.DEAMBULA
		anim.speed_scale = DEAMBULA_ANIM


func _process(delta: float) -> void:
	if not _listo:
		_empezar()
	_t += delta
	_reloj += delta
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	match estado:
		Estado.CAMINA:
			_camina(delta)
		Estado.GRITA:
			_grita(delta)
		Estado.SALTA:
			_salta()
		Estado.CORRE:
			_corre(delta)
		Estado.DESPEGA:
			_despega(delta)
		Estado.VUELA:
			_vuela(delta)
		Estado.APUNTA:
			_apunta(delta)
		Estado.PICADA:
			_picada(delta)
		Estado.SUBE:
			_sube(delta)
		Estado.CAE:
			_cae(delta)
		Estado.TUMBA:
			_tumba(delta)
		Estado.PATAS:
			_patas(delta)
		Estado.VOLTEA:
			_voltea(delta)
		Estado.DEAMBULA:
			_deambula(delta)
	if encerrar.is_valid():
		global_position = encerrar.call(global_position)
	_sonar_loop()
	_mover_cabeza(delta)
	transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, _roll)).scaled(Vector3.ONE * escala())


# --- Fases 1 y 2: en el piso ---

func _camina(delta: float) -> void:
	if _jugador == null:
		return
	_caminar(delta)
	if _boca().distance_to(_pecho()) < CERCA:
		_enojar()
		return
	_pare_reloj -= delta
	if _pare_reloj <= 0.0 and _crias_vivas() < CRIAS_MAX:
		_parir_quieta()


# Da vueltas alrededor del jugador: cada punto un poco mas alla en su sentido, a su distancia
func _caminar(delta: float) -> void:
	_meta_reloj -= delta
	var plano := _meta - global_position
	plano.y = 0.0
	if _meta_reloj <= 0.0 or plano.length() < META_LLEGA:
		if randf() < 0.2:
			_sentido = -_sentido
		var desde := global_position - _jugador.global_position
		var angulo := atan2(desde.z, desde.x) + _sentido * randf_range(0.6, 1.3)
		_meta = _dentro(_jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(CAMINA_RADIO.x, CAMINA_RADIO.y))
		_meta_reloj = META_CAMBIA
		_rapidez = randf_range(CAMINA_VEL.x, CAMINA_VEL.y)
		plano = _meta - global_position
		plano.y = 0.0
	var avanza := _avanzar(_rapidez, delta)
	# Topo con el muro: voltea rapido hacia su meta (que esta adentro) y busca otra pronto
	_girar_a(plano, (CAMINA_GIRA if avanza > 0.6 else MURO_GIRA) * delta)
	if avanza < 0.6:
		_meta_reloj = minf(_meta_reloj, 0.4)
	anim.speed_scale = maxf(_rapidez * avanza / 3.5, 0.35)


func _enojar() -> void:
	if fase >= 2 or estado != Estado.CAMINA:
		return
	if Time.get_ticks_msec() - _ultimo_enojo < int(ENOJO_ENFRIA * 1000.0):
		return
	_ultimo_enojo = Time.get_ticks_msec()
	estado = Estado.GRITA
	_reloj = 0.0
	anim.speed_scale = 1.0
	animar("ataca", 0.15)
	Sonidos.tocar(self, "cucarrata_grita", 0.0, 0.85)   # S-108: el aviso para rodar


# Alza la cabeza de rata y chilla, volteando hacia ti
func _grita(delta: float) -> void:
	if _jugador:
		_girar_a(_jugador.global_position - global_position, 4.0 * delta)
	if _reloj >= GRITA_DURA:
		estado = Estado.SALTA
		_reloj = 0.0
		_mordio = false
		_salto_desde = global_position
		_salto_hasta = global_position
		if _jugador:
			var hacia := _jugador.global_position - global_position
			hacia.y = 0.0
			# Cae con la boca donde estas: el origen queda atras de la boca
			var atras := -BOCA.z * escala() - 1.0
			var brinco := clampf(hacia.length() - atras, 0.0, SALTO_MAX)
			_salto_hasta = _dentro(global_position + hacia.normalized() * brinco)
			_salto_hasta.y = _piso
		animar("camina", 0.1)
		anim.speed_scale = 2.0


func _salta() -> void:
	var f := clampf(_reloj / SALTO_DURA, 0.0, 1.0)
	var p := _salto_desde.lerp(_salto_hasta, f)
	p.y = _piso + sin(f * PI) * SALTO_ALTO
	global_position = p
	if not _mordio and _jugador and _boca().distance_to(_pecho()) < MORDIDA_ALCANCE:
		_mordio = true
		if not (_jugador.has_method("esquivando") and _jugador.esquivando()) and _jugador.has_method("recibir_dano"):
			_jugador.recibir_dano(MORDIDA, global_position, MORDIDA_EMPUJA, self)
			Sonidos.tocar(self, "cucarrata_mordida", -2.0, 0.8)   # S-109
	if f >= 1.0:
		Sonidos.tocar(self, "cucarrata_aterriza", -4.0, 0.7)   # S-110
		estado = Estado.CORRE
		_reloj = 0.0
		# Se va corriendo, de lado
		var fuera := global_position - (_jugador.global_position if _jugador else global_position)
		fuera.y = 0.0
		fuera = fuera.normalized() if fuera.length_squared() > 0.01 else _frente()
		# De lado, hacia donde quede mas lugar (en la bodega, no contra el muro)
		_meta = global_position
		for giro in [_sentido * 1.2, -_sentido * 1.2, _sentido * 0.6, -_sentido * 0.6, PI]:
			var meta := _dentro(global_position + fuera.rotated(Vector3.UP, giro) * 14.0)
			meta.y = _piso
			if meta.distance_to(global_position) > _meta.distance_to(global_position) + 1.0:
				_meta = meta
		_meta_reloj = CORRE_DURA


func _corre(delta: float) -> void:
	var plano := _meta - global_position
	plano.y = 0.0
	_girar_a(plano, 3.0 * delta)
	var avanza := _avanzar(CORRE_VEL, delta)
	anim.speed_scale = 2.0
	# Llego o topo con el muro: deja de correr (no se queda corriendo contra la pared)
	if _reloj >= CORRE_DURA or plano.length() < META_LLEGA or (_reloj > 0.3 and avanza < 0.5):
		estado = Estado.CAMINA
		_meta_reloj = 0.0
		animar("camina", 0.2)


func _parir_quieta() -> void:
	estado = Estado.PARE
	_pare_reloj = PARE_CADA
	anim.speed_scale = 1.0
	await parir([CriaCucarrata.Tipo.RATA, CriaCucarrata.Tipo.RATA, CriaCucarrata.Tipo.RATA])   # 15 ratas
	if is_inside_tree() and estado == Estado.PARE:
		estado = Estado.CAMINA
		_meta_reloj = 0.0
		animar("camina", 0.3)


# --- Fases 2 y 3: vuela ---

func _despega(delta: float) -> void:
	var f := clampf(_reloj / DESPEGA_DURA, 0.0, 1.0)
	global_position.y = lerpf(global_position.y, _piso + VUELO_ALTO.x, minf(delta * 2.0, 1.0))
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 4.0, 1.0))
	if f >= 1.0:
		estado = Estado.VUELA
		_vel = _frente() * VUELO_VEL.x
		_meta_reloj = 0.0
		_aguijon_reloj = AGUIJON_CADA * 0.6
		_pare_reloj = 1.0


# Como mosca, mas lenta que las cucarachas: a un punto del otro lado del jugador, alto, con giro
# limitado; pasa por encima de ti
func _vuela(delta: float) -> void:
	if _jugador == null:
		return
	_meta_reloj -= delta
	if _meta_reloj <= 0.0 or global_position.distance_to(_meta) < META_LLEGA:
		var desde := global_position - _jugador.global_position
		var angulo := atan2(desde.z, desde.x) + PI + randf_range(-VUELO_ABRE, VUELO_ABRE)
		_meta = _jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(VUELO_RADIO.x, VUELO_RADIO.y)
		_meta.y = _piso + randf_range(VUELO_ALTO.x, VUELO_ALTO.y)
		_meta = _dentro(_meta)
		_meta_reloj = 5.0
		_rapidez = randf_range(VUELO_VEL.x, VUELO_VEL.y)
	_volar_a(_meta, _rapidez, VUELO_GIRA, delta)
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 3.0, 1.0))
	_grito_reloj -= delta
	if _grito_reloj <= 0.0:
		_grito_reloj = randf_range(GRITO_VUELO.x, GRITO_VUELO.y)
		Sonidos.tocar(self, "cucarrata_vuela_grito", -8.0, randf_range(0.7, 0.85))   # S-115
	_pare_reloj -= delta
	if _pare_reloj <= 0.0 and _crias_vivas() < AIRE_CRIAS_MAX:
		_pare_reloj = AIRE_PARE_CADA
		# En el aire, sin dejar de aletear: solo cucarachas voladoras (las ratas, al voltearse)
		parir([CriaCucarrata.Tipo.CUCARACHA], false)
	_aguijon_reloj -= delta
	var plano := global_position - _jugador.global_position
	plano.y = 0.0
	if fase >= 3 and _aguijon_reloj <= 0.0 and plano.length() > 4.0 and plano.length() < 18.0:
		estado = Estado.APUNTA
		_reloj = 0.0
		var lado := plano.normalized()
		_apunta_en = _jugador.global_position + lado * APUNTA_DIST
		_apunta_en.y = _piso + APUNTA_ALTO + PUNTA_COLA.z * escala()   # parada, la cola cuelga su largo
		_apunta_en = _dentro(_apunta_en)
		Sonidos.tocar(self, "cucarrata_aguijon_aviso", 0.0, 0.8)   # S-116: el aviso para rodar


# Se va a su lugar, se frena y se para en vertical (cabeza arriba, aguijon abajo), mirandote
func _apunta(delta: float) -> void:
	global_position = global_position.lerp(_apunta_en, minf(delta * 2.0, 1.0))
	if _jugador:
		_girar_a(_jugador.global_position - global_position, 3.0 * delta)
	_pitch = lerp_angle(_pitch, PI * 0.5, minf(delta * 3.0, 1.0))
	if _reloj >= APUNTA_DURA:
		_pitch = PI * 0.5
		estado = Estado.PICADA
		_reloj = 0.0
		var hacia := (_pecho() - _aguijon.global_position) if _jugador else Vector3.DOWN
		_vel = hacia.normalized() * 3.0
		Sonidos.tocar(self, "cucarrata_picada", -2.0, 0.6)   # S-117


# Se lanza con el aguijon por delante; corrige poco el rumbo, asi rodando la esquivas
func _picada(delta: float) -> void:
	var rapidez := minf(_vel.length() + PICADA_ACELERA * delta, PICADA_VEL)
	var rumbo := _vel.normalized()
	if _jugador:
		var quiere := (_pecho() - _aguijon.global_position).normalized()
		var giro := minf(rumbo.angle_to(quiere), PICADA_GIRA * delta)
		var eje := rumbo.cross(quiere)
		if eje.length_squared() > 0.000001:
			rumbo = rumbo.rotated(eje.normalized(), giro)
	_vel = rumbo * rapidez
	global_position += _vel * delta
	var pego := false
	if _jugador and _aguijon.global_position.distance_to(_pecho()) < AGUIJON_ALCANCE:
		pego = true
		if not (_jugador.has_method("esquivando") and _jugador.esquivando()) and _jugador.has_method("recibir_dano"):
			_jugador.recibir_dano(AGUIJON, _aguijon.global_position, AGUIJON_EMPUJA, self)
			Sonidos.tocar(self, "cucarrata_aguijonazo", 0.0, 0.9)   # S-118
	if pego or _aguijon.global_position.y <= _piso + 0.1 or _reloj > PICADA_MAX:
		if _aguijon.global_position.y <= _piso + 0.3:
			Sonidos.tocar(self, "cucarrata_aterriza", -6.0, 0.9)
		estado = Estado.SUBE
		_reloj = 0.0
		_vel = -_vel.normalized() * 2.0 + Vector3.UP * 4.0


func _sube(delta: float) -> void:
	_vel = _vel.lerp(Vector3.UP * 3.0, minf(delta * 2.0, 1.0))
	global_position += _vel * delta
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 3.0, 1.0))
	if _reloj >= SUBE_DURA:
		estado = Estado.VUELA
		_vel = _frente() * VUELO_VEL.x
		_meta_reloj = 0.0
		_aguijon_reloj = AGUIJON_CADA


func _volar_a(meta: Vector3, rapidez: float, gira: float, delta: float) -> void:
	var rumbo := _vel.normalized() if _vel.length_squared() > 0.01 else _frente()
	var quiere := (meta - global_position).normalized()
	var giro := minf(rumbo.angle_to(quiere), gira * delta)
	var eje := rumbo.cross(quiere)
	if eje.length_squared() > 0.000001:
		rumbo = rumbo.rotated(eje.normalized(), giro)
	_vel = rumbo * lerpf(_vel.length(), rapidez, minf(delta * 2.0, 1.0))
	var antes := global_position
	var p := global_position + _vel * delta
	p.y = maxf(p.y, _piso + 2.0)
	global_position = _dentro(p)
	# Contra el muro o el techo: resbala por el (su rumbo pasa a ser lo que de veras avanzo)
	if delta > 0.0 and global_position.distance_to(p) > 0.001:
		var real := (global_position - antes) / delta
		_vel = real.normalized() * _vel.length() if real.length_squared() > 0.01 else -_vel * 0.5
	_girar_a(_vel, gira * 2.0 * delta)


# --- Suelta en la calle ---

# Camina despacio por su ruta, sin hacerte caso; al acabarla pide otra
func _deambula(delta: float) -> void:
	if _jugador and (te_ve.call(_jugador.global_position) if te_ve.is_valid() \
			else _boca().distance_to(_pecho()) < DESPIERTA):
		_despertar()
		return
	if _ruta_i >= _ruta.size():
		_ruta = pedir_ruta.call(global_position) if pedir_ruta.is_valid() else PackedVector3Array()
		_ruta_i = 0
		if _ruta.is_empty():
			return
	var meta := _ruta[_ruta_i]
	var plano := meta - global_position
	plano.y = 0.0
	if plano.length() < DEAMBULA_LLEGA:
		_ruta_i += 1
		return
	_girar_a(plano, CAMINA_GIRA * delta)
	global_position += _frente() * DEAMBULA_VEL * delta
	global_position.y = _piso
	anim.speed_scale = DEAMBULA_ANIM


# Te vio o le pegaste: empieza la pelea (fase 1, en el piso)
func _despertar() -> void:
	if estado != Estado.DEAMBULA:
		return
	estado = Estado.CAMINA
	_meta_reloj = 0.0
	_pare_reloj = PARE_PRIMERO
	anim.speed_scale = 1.0
	Sonidos.tocar(self, "cucarrata_despierta", 0.0, 0.8)   # S-107
	desperto.emit()


# --- Tumbada (fases 2 y 3) ---

func _tumbar() -> void:
	estado = Estado.TUMBA
	_reloj = 0.0
	_balazos_vuelo = 0
	_tumbada_queda = TUMBADA_VIDA
	cancelar_parto()   # boca arriba no pare nada (JJ): solo patalea
	_vel = Vector3(_vel.x, 0.0, _vel.z) * 0.3
	animar("camina", 0.2)
	anim.speed_scale = PATALEA
	Sonidos.tocar(self, "cucarrata_herida", 0.0, 0.7)   # S-122: chilla al caer...


# Cae dandose la vuelta en el aire
func _tumba(delta: float) -> void:
	_vel.y -= GRAVEDAD * delta
	global_position += _vel * delta
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 5.0, 1.0))
	_roll = lerpf(_roll, PI, minf(delta * 4.0, 1.0))
	var suelo := _piso + TUMBADA_ALTO * escala()
	if global_position.y <= suelo:
		global_position.y = suelo
		_pitch = 0.0
		_roll = PI
		estado = Estado.PATAS
		_reloj = 0.0
		Sonidos.tocar(self, "cucarrata_cae_muerta", 0.0, 0.8)   # ...y el caparazon pega en el piso


# Boca arriba, pataleando y meciendose; el machete le baja vida
func _patas(_delta: float) -> void:
	_roll = PI + sin(_t * 7.0) * 0.07
	anim.speed_scale = PATALEA
	if _reloj >= TUMBADA_DURA:
		_voltear()


func _voltear() -> void:
	estado = Estado.VOLTEA
	_reloj = 0.0
	anim.speed_scale = 1.0
	Sonidos.tocar(self, "cucarrata_grita", -2.0, 0.75)   # S-125


# Un brinquito dandose la vuelta (sigue girando para el mismo lado) y cae parada
func _voltea(_delta: float) -> void:
	var f := clampf(_reloj / VOLTEA_DURA, 0.0, 1.0)
	_roll = lerpf(PI, TAU, f)
	global_position.y = lerpf(_piso + TUMBADA_ALTO * escala(), _piso, f) + sin(f * PI) * VOLTEA_BRINCO
	if f >= 1.0:
		_roll = 0.0
		global_position.y = _piso
		Sonidos.tocar(self, "cucarrata_aterriza", -2.0, 0.8)
		_parir_y_despegar()


# Ya parada suelta su camada de ratas y vuelve a subir
func _parir_y_despegar() -> void:
	estado = Estado.PARE
	await parir([CriaCucarrata.Tipo.RATA, CriaCucarrata.Tipo.RATA, CriaCucarrata.Tipo.RATA])
	if is_inside_tree() and estado == Estado.PARE:
		_despegar()


func _despegar() -> void:
	cancelar_parto()   # si estaba pariendo en el piso, ya no
	estado = Estado.DESPEGA
	_reloj = 0.0
	_balazos_vuelo = 0
	anim.speed_scale = 1.0
	animar("vuela", 0.3)
	Sonidos.tocar(self, "cucarrata_despega", -2.0, 0.6)   # S-113


# Lo que le baja el machete (o una explosion) tumbada, hasta TUMBADA_VIDA; acabandosela se voltea
func _herir_tumbada(dano: float) -> void:
	var d := minf(dano, _tumbada_queda)
	if d <= 0.0:
		return
	_tumbada_queda -= d
	_herir(d)
	if _tumbada_queda <= 0.0 and estado == Estado.PATAS:
		_voltear()


# Un golpe en las fases 2 y 3: en el aire suma para tumbarla (y le baja poquito), tumbada baja vida, si no, nada
func _golpe_aire(balas: int, dano: float) -> void:
	if estado in EN_VUELO:
		_balazos_vuelo += balas
		if balas > 0:
			_herir(DANO_BALA_AIRE * balas)
		if estado in EN_VUELO and _balazos_vuelo >= TUMBAR_BALAS:
			_tumbar()
	elif estado == Estado.PATAS and dano > 0.0:
		_herir_tumbada(dano)


# --- Muerte ---

func _cae(delta: float) -> void:
	_vel.y -= GRAVEDAD * delta
	global_position += _vel * delta
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 4.0, 1.0))
	if global_position.y <= _piso:
		global_position.y = _piso
		_pitch = 0.0
		_quedar_muerta()


func _morir() -> void:
	if estado == Estado.CAE or estado == Estado.MUERTA:
		return
	remove_from_group("lombrices")
	cancelar_parto()
	anim.speed_scale = 1.0
	Sonidos.tocar(self, "cucarrata_muere", 0.0, 0.75)   # S-126
	for cria in get_tree().get_nodes_in_group("lombrices"):
		if cria is CriaCucarrata:
			cria._morir()
	murio.emit()
	if estado in [Estado.TUMBA, Estado.PATAS, Estado.VOLTEA]:
		# Ya esta boca arriba: se queda asi, y deja de patalear
		estado = Estado.MUERTA
		_roll = PI
		global_position.y = _piso + TUMBADA_ALTO * escala()
		anim.speed_scale = 1.0
		animar("quieta", 0.6)
		Sonidos.tocar(self, "cucarrata_cae_muerta", 0.0, 0.7)   # S-127
	elif global_position.y > _piso + 0.3:
		estado = Estado.CAE
		_vel = Vector3.ZERO
	else:
		_quedar_muerta()


func _quedar_muerta() -> void:
	estado = Estado.MUERTA
	animar("muere", 0.2)
	Sonidos.tocar(self, "cucarrata_cae_muerta", 0.0, 0.7)   # S-127


# --- Vida y armas ---

func _herir(dano: float) -> void:
	if estado == Estado.CAE or estado == Estado.MUERTA:
		return
	vida = maxf(vida - dano, 0.0)
	if vida <= 0.0:
		_morir()
		return
	var nueva := 1 if vida > VIDA * 2.0 / 3.0 else (2 if vida > VIDA / 3.0 else 3)
	if nueva == fase:
		# S-119: chillido de dolor, no en cada golpe (tres tomas al azar en Sonidos.VARIANTES)
		if Time.get_ticks_msec() - _ultimo_dolor > DOLOR_CADA_MS:
			_ultimo_dolor = Time.get_ticks_msec()
			Sonidos.tocar(self, "cucarrata_herida", -4.0, randf_range(0.75, 0.9))
		return
	fase = nueva
	cambio_fase.emit(fase)
	Sonidos.tocar(self, "cucarrata_cambio_fase", 0.0, 0.8)   # S-121
	if fase == 2:
		_despegar()
	elif fase == 3:
		_aguijon_reloj = 2.5   # ya vuela (o esta tumbada): ahora tambien pica


func _esferas() -> Array:
	var lista := []
	var k := escala()
	for e: Vector4 in CUERPO:
		lista.append([global_transform * Vector3(e.x, e.y, e.z), e.w * k])
	return lista


func query_ray_hit(origen: Vector3, dir: Vector3, max_dist: float, radio: float) -> Dictionary:
	if estado == Estado.CAE or estado == Estado.MUERTA:
		return {}
	var d := dir.normalized()
	var mejor := max_dist
	var pego := false
	for e in _esferas():
		var t := _esfera(origen, d, e[0], e[1] + radio)
		if t >= 0.0 and t < mejor:
			mejor = t
			pego = true
	if not pego:
		return {}
	return {"dot_index": 0, "position": origen + d * mejor, "distance": mejor}


# Distancia por el rayo hasta la esfera, -1 si no la toca (la de MadreCarcamo)
static func _esfera(origen: Vector3, dir: Vector3, centro: Vector3, r: float) -> float:
	var oc := centro - origen
	var t := oc.dot(dir)
	var d2 := oc.length_squared() - t * t
	if t < 0.0 or d2 > r * r:
		return -1.0
	return maxf(t - sqrt(r * r - d2), 0.0)


func bullet_hit(_i: int, punto: Vector3, _dir: Vector3) -> void:
	_despertar()
	_fx("cria_corte", punto)
	if fase >= 2 and estado in EN_VUELO:
		Sonidos.tocar(self, "cucarrata_bala_caparazon", -6.0, randf_range(0.9, 1.1))   # S-120: no le entran
	else:
		Sonidos.tocar(self, "squelch", -8.0, 0.8)
	if fase >= 2:
		_golpe_aire(1, 0.0)   # en el aire casi no le bajan vida: la tumban
		return
	_herir(DANO_BALA)
	_enojar()


func golpe_cuerpo(origen: Vector3, frente: Vector3, alcance: float, cono: float, dano: int, giro := false, _todas := false) -> bool:
	if estado == Estado.CAE or estado == Estado.MUERTA:
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
		_despertar()
		_fx("cria_corte", e[0] - hacia.normalized() * e[1])
		if estado == Estado.PATAS:
			Sonidos.tocar(self, "cucarrata_machete_panza", -2.0, randf_range(0.85, 1.0))   # S-124
		if fase >= 2:
			_golpe_aire(0, float(dano))   # solo tumbada le baja vida
		else:
			_herir(float(dano))
		return true
	return false


func apply_explosion_impulse(punto: Vector3, radio: float, _fuerza: float, _algo = null) -> void:
	for e in _esferas():
		if punto.distance_to(e[0]) < radio + e[1]:
			_despertar()
			if fase >= 2:
				_golpe_aire(TUMBAR_EXPLOSION, DANO_EXPLOSION)
			else:
				_herir(DANO_EXPLOSION)
			return


# --- Sonido ---

# El loop que va con su estado: rondando sus patas (S-106, mas fuerte entre mas cerca; despierta
# caminando o corriendo, las mismas), volando las
# alas (S-114), boca arriba el pataleo (S-123); en lo demas, nada
func _sonar_loop() -> void:
	var nombre := ""
	var volumen := -6.0
	var tono := 1.0
	match estado:
		Estado.DEAMBULA:
			nombre = "cucarrata_ronda"
			tono = 0.6
			var d := global_position.distance_to(_jugador.global_position) if _jugador else RONDA_OIDO
			volumen = lerpf(-4.0, -40.0, clampf(d / RONDA_OIDO, 0.0, 1.0))
		Estado.CAMINA, Estado.CORRE:
			nombre = "cucarrata_ronda"   # despierta, las mismas patas; corriendo mas agudas
			tono = 0.85 if estado == Estado.CORRE else 0.6
			volumen = -2.0 if estado == Estado.CORRE else -5.0
		Estado.DESPEGA, Estado.VUELA, Estado.APUNTA, Estado.PICADA, Estado.SUBE:
			nombre = "cucarrata_alas"
			tono = 0.55
			volumen = -8.0
		Estado.PATAS:
			nombre = "cucarrata_patalea"
			tono = 0.8
			volumen = -4.0
	if nombre != _loop_nombre:
		_loop_nombre = nombre
		if is_instance_valid(_voz_loop):
			_voz_loop.queue_free()
		_voz_loop = Sonidos.ambiente(self, nombre, volumen) if nombre != "" else null
	if is_instance_valid(_voz_loop):
		_voz_loop.volume_db = volumen
		_voz_loop.pitch_scale = tono


# --- Ayudas ---

# Donde la encierran (encerrar), o p tal cual si anda suelta sin limites
func _dentro(p: Vector3) -> Vector3:
	return encerrar.call(p) if encerrar.is_valid() else p


# Camina hacia el frente lo que le toque, sin meterse al muro: devuelve que parte de eso avanzo (0..1)
func _avanzar(rapidez: float, delta: float) -> float:
	var quiere := _frente() * rapidez * delta
	quiere.y = 0.0
	var p := _dentro(global_position + quiere)
	p.y = _piso
	var real := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	global_position = p
	return real / maxf(quiere.length(), 0.0001)


func piso_y() -> float:
	return _piso if _listo else global_position.y


func _frente() -> Vector3:
	return Vector3(-sin(_yaw), 0.0, -cos(_yaw))


func _girar_a(hacia: Vector3, maximo: float) -> void:
	if Vector2(hacia.x, hacia.z).length_squared() < 0.0001:
		return
	_yaw = rotate_toward(_yaw, atan2(-hacia.x, -hacia.z), maximo)


func _boca() -> Vector3:
	return global_transform * BOCA


func _pecho() -> Vector3:
	return _jugador.global_position + Vector3.UP * PECHO


func _crias_vivas() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("lombrices"):
		if c is CriaCucarrata:
			n += 1
	return n


func _fx(lugar: String, donde: Vector3) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, Vector3.ZERO, 1.0)


# La cabeza de rata se alza y tiembla al gruñir (gira en el cuello, sobre su eje de lado)
func _mover_cabeza(delta: float) -> void:
	var quiere := 0.0
	if estado == Estado.GRITA:
		quiere = 0.6 + sin(_t * 45.0) * 0.08
	elif estado == Estado.SALTA:
		quiere = -0.15   # la boca por delante
	_cabeza_angulo = lerpf(_cabeza_angulo, quiere, minf(delta * 12.0, 1.0))
	_cabeza.transform = _cabeza_base * Transform3D(Basis(Vector3.RIGHT, _cabeza_angulo), Vector3.ZERO)


# Un aguijon en la punta de la cola: un cono de quitina oscura con la punta azul Serenol. Va en el
# hueso del abdomen, asi se mueve con el
func _poner_aguijon() -> void:
	var abdomen := esqueleto.find_bone(HUESO_ABDOMEN)
	var pegado := BoneAttachment3D.new()
	pegado.bone_name = HUESO_ABDOMEN
	esqueleto.add_child(pegado)
	var esqueleto_modelo := _modelo.global_transform.affine_inverse() * esqueleto.global_transform
	var hueso_modelo := esqueleto_modelo * esqueleto.get_bone_global_rest(abdomen)
	var largo := 0.34
	var eje_y := Vector3(0.0, -0.3, 1.0).normalized()   # hacia atras y un poco abajo
	var eje_x := Vector3.RIGHT
	var eje_z := eje_x.cross(eje_y).normalized()
	var base := Node3D.new()
	base.name = "Aguijon"
	base.transform = hueso_modelo.affine_inverse() * Transform3D(Basis(eje_x, eje_y, eje_z), PUNTA_COLA + Vector3(0, -0.04, -0.06))
	pegado.add_child(base)
	var cono := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = 0.0
	malla.bottom_radius = 0.05
	malla.height = largo
	malla.radial_segments = 6
	malla.rings = 2
	cono.mesh = malla
	cono.position = Vector3(0.0, largo * 0.5, 0.0)
	var quitina := StandardMaterial3D.new()
	quitina.albedo_color = Color(0.16, 0.1, 0.07)
	quitina.roughness = 0.35
	quitina.emission_enabled = true
	quitina.emission = Color(0.05, 0.25, 0.4)
	quitina.emission_energy_multiplier = 0.6
	cono.material_override = quitina
	base.add_child(cono)
	_aguijon = Node3D.new()
	_aguijon.position = Vector3(0.0, largo, 0.0)
	base.add_child(_aguijon)
	var punta := MeshInstance3D.new()
	var bolita := SphereMesh.new()
	bolita.radius = 0.018
	bolita.height = 0.036
	bolita.radial_segments = 6
	bolita.rings = 3
	punta.mesh = bolita
	punta.material_override = material_ojo()
	_aguijon.add_child(punta)
	var luz := OmniLight3D.new()
	luz.light_color = OJO_COLOR
	luz.light_energy = 1.2
	luz.omni_range = 0.5 * escala()
	_aguijon.add_child(luz)
