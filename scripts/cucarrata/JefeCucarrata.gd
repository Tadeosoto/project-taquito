class_name JefeCucarrata
extends Cucarrata
# La pelea contra la cucarrata (JJ, 2026-11-17). Tres fases por la vida que le queda:
# 1. Camina alrededor del jugador. Si le disparas (o te le acercas) grune: alza la cabeza de rata
#    y chilla, brinca y te da un mordidon, y se va corriendo. No pare.
# 2. Con 2/3 de vida: lo mismo, y cada PARE_CADA s se para a parir (ratas o cucarachas, alterna).
# 3. Con 1/3: vuela como mosca, mas lenta que las cucarachas. Cada AGUIJON_CADA s se acomoda en
#    vertical (cabeza arriba, la cola con el aguijon abajo), hace una pausa y se lanza: aguijonazo.
#    Sigue pariendo, ahora en el aire.
# Esta en el grupo "lombrices": la pistola y el machete le preguntan como a las crias. Todos los
# numeros son de primera, para docs/pruebas-balance.md.

signal murio
signal cambio_fase(fase: int)

const VIDA := 400.0
const DANO_BALA := 10.0
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
const CRIAS_MAX := 6              # si quedan mas vivas, espera
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

enum Estado { CAMINA, GRITA, SALTA, CORRE, PARE, DESPEGA, VUELA, APUNTA, PICADA, SUBE, CAE, MUERTA }

var vida := VIDA
var fase := 1
var estado := Estado.CAMINA
var _jugador: Node3D
var _listo := false
var _piso := 0.0
var _yaw := 0.0
var _pitch := 0.0
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
	var frente := -global_transform.basis.z
	_yaw = atan2(-frente.x, -frente.z)
	_meta_reloj = 0.0


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
	_mover_cabeza(delta)
	transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).scaled(Vector3.ONE * escala())


# --- Fases 1 y 2: en el piso ---

func _camina(delta: float) -> void:
	if _jugador == null:
		return
	_caminar(delta)
	if _boca().distance_to(_pecho()) < CERCA:
		_enojar()
		return
	if fase >= 2:
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
		_meta = _jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(CAMINA_RADIO.x, CAMINA_RADIO.y)
		_meta_reloj = META_CAMBIA
		_rapidez = randf_range(CAMINA_VEL.x, CAMINA_VEL.y)
		plano = _meta - global_position
		plano.y = 0.0
	_girar_a(plano, CAMINA_GIRA * delta)
	global_position += _frente() * _rapidez * delta
	global_position.y = _piso
	anim.speed_scale = _rapidez / 3.5


func _enojar() -> void:
	if fase >= 3 or estado != Estado.CAMINA:
		return
	if Time.get_ticks_msec() - _ultimo_enojo < int(ENOJO_ENFRIA * 1000.0):
		return
	_ultimo_enojo = Time.get_ticks_msec()
	estado = Estado.GRITA
	_reloj = 0.0
	anim.speed_scale = 1.0
	animar("ataca", 0.15)
	Sonidos.tocar(self, "rugido", 0.0, 0.7)
	Sonidos.tocar(self, "chillido", -4.0, 0.55)


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
			_salto_hasta = global_position + hacia.normalized() * brinco
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
			Sonidos.tocar(self, "squelch", -2.0, 0.6)
	if f >= 1.0:
		Sonidos.tocar(self, "retumbo", -6.0, 0.8)
		estado = Estado.CORRE
		_reloj = 0.0
		# Se va corriendo, de lado
		var fuera := global_position - (_jugador.global_position if _jugador else global_position)
		fuera.y = 0.0
		fuera = fuera.normalized().rotated(Vector3.UP, _sentido * 1.2) if fuera.length_squared() > 0.01 else _frente()
		_meta = global_position + fuera * 14.0
		_meta_reloj = CORRE_DURA


func _corre(delta: float) -> void:
	var plano := _meta - global_position
	plano.y = 0.0
	_girar_a(plano, 3.0 * delta)
	global_position += _frente() * CORRE_VEL * delta
	global_position.y = _piso
	anim.speed_scale = 2.0
	if _reloj >= CORRE_DURA:
		estado = Estado.CAMINA
		_meta_reloj = 0.0
		animar("camina", 0.2)


func _parir_quieta() -> void:
	estado = Estado.PARE
	_pare_reloj = PARE_CADA
	anim.speed_scale = 1.0
	await parir()
	if is_inside_tree() and estado == Estado.PARE:
		estado = Estado.CAMINA
		_meta_reloj = 0.0
		animar("camina", 0.3)


# --- Fase 3: vuela ---

func _despega(delta: float) -> void:
	var f := clampf(_reloj / DESPEGA_DURA, 0.0, 1.0)
	global_position.y = lerpf(global_position.y, _piso + VUELO_ALTO.x, minf(delta * 2.0, 1.0))
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 4.0, 1.0))
	if f >= 1.0:
		estado = Estado.VUELA
		_vel = _frente() * VUELO_VEL.x
		_meta_reloj = 0.0
		_aguijon_reloj = AGUIJON_CADA * 0.6
		_pare_reloj = PARE_CADA * 0.5


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
		_meta_reloj = 5.0
		_rapidez = randf_range(VUELO_VEL.x, VUELO_VEL.y)
	_volar_a(_meta, _rapidez, VUELO_GIRA, delta)
	_pitch = lerp_angle(_pitch, 0.0, minf(delta * 3.0, 1.0))
	_pare_reloj -= delta
	if _pare_reloj <= 0.0 and _crias_vivas() < CRIAS_MAX:
		_pare_reloj = PARE_CADA
		parir([], false)   # en el aire, sin dejar de aletear
	_aguijon_reloj -= delta
	var plano := global_position - _jugador.global_position
	plano.y = 0.0
	if _aguijon_reloj <= 0.0 and plano.length() > 4.0 and plano.length() < 18.0:
		estado = Estado.APUNTA
		_reloj = 0.0
		var lado := plano.normalized()
		_apunta_en = _jugador.global_position + lado * APUNTA_DIST
		_apunta_en.y = _piso + APUNTA_ALTO + PUNTA_COLA.z * escala()   # parada, la cola cuelga su largo
		Sonidos.tocar(self, "chillido", -6.0, 0.7)


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
		Sonidos.tocar(self, "rugido", -2.0, 0.9)


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
			Sonidos.tocar(self, "squelch", -2.0, 0.7)
	if pego or _aguijon.global_position.y <= _piso + 0.1 or _reloj > PICADA_MAX:
		if _aguijon.global_position.y <= _piso + 0.3:
			Sonidos.tocar(self, "retumbo", -4.0, 0.9)
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
	global_position += _vel * delta
	global_position.y = maxf(global_position.y, _piso + 2.0)
	_girar_a(_vel, gira * 2.0 * delta)


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
	anim.speed_scale = 1.0
	Sonidos.tocar(self, "chillido_muerte", 0.0, 0.6)
	Sonidos.tocar(self, "rugido", 0.0, 0.5)
	for cria in get_tree().get_nodes_in_group("lombrices"):
		if cria is CriaCucarrata:
			cria._morir()
	murio.emit()
	if global_position.y > _piso + 0.3:
		estado = Estado.CAE
		_vel = Vector3.ZERO
	else:
		_quedar_muerta()


func _quedar_muerta() -> void:
	estado = Estado.MUERTA
	animar("muere", 0.2)
	Sonidos.tocar(self, "retumbo", 0.0, 0.7)


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
		return
	fase = nueva
	cambio_fase.emit(fase)
	Sonidos.tocar(self, "rugido", 0.0, 0.6)
	if fase == 2:
		_pare_reloj = 2.0   # en cuanto entra a la fase 2, pare
	elif fase == 3:
		estado = Estado.DESPEGA
		_reloj = 0.0
		anim.speed_scale = 1.0
		animar("vuela", 0.3)


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
	_fx("cria_corte", punto)
	Sonidos.tocar(self, "squelch", -8.0, 0.8)
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
		_fx("cria_corte", e[0] - hacia.normalized() * e[1])
		_herir(float(dano))
		return true
	return false


func apply_explosion_impulse(punto: Vector3, radio: float, _fuerza: float, _algo = null) -> void:
	for e in _esferas():
		if punto.distance_to(e[0]) < radio + e[1]:
			_herir(DANO_EXPLOSION)
			return


# --- Ayudas ---

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
