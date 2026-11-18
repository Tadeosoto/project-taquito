class_name CriaCucarrata
extends Node3D
# Las crias que la cucarrata suelta por la cola (Cucarrata.parir): ratas grises y cucarachas cafes
# voladoras, las dos del tamano de un chihuahua (~0.45 m de largo), con la piel de la cucarrata
# (shaders/cucarrata.gdshader). No son la cucarrata escalada: con su escala las grietas quedarian
# de milimetros, asi que cada una lleva sus propias celdas, grandes y en pixeles gruesos, y brilla
# mas. Mismos modelos que la cucarrata (rata.glb entera y cucaracha.glb con su cabeza).
# Lo que hacen (JJ, 2026-11-17; numeros de primera, para el balance):
# - Cucaracha: bomba kamikaze. Vuela horizontal, de frente, como mosca alrededor del jugador (y
#   atacan de una en una, tras ENJAMBRE_ESPERA s de turba); cuando le toca se frena, se para en
#   vertical mostrando la panza y acelera a estrellarse con la panza, y truena en azul Serenol (dana a EXPLOTA_RADIO; rodando se
#   esquiva, como cualquier golpe). GOLPES machetazos o balazos la revientan sin dano.
# - Rata: corre como mosca en el piso alrededor del jugador, brinca de una en una y muerde, y se queda pegada (frena y chupa vida) hasta que
#   la matas a machetazos (GOLPES): cada golpe le da a una pegada, sin importar hacia donde mires. Rodar
#   no la suelta. Bloqueando de frente rebota.
# Estan en el grupo "lombrices": asi el machete (Player._golpear, la estocada, el azote) y la
# pistola (EnjambreLombrices.rayo) les pegan sin tocar player.gd, con las mismas funciones que el
# enjambre (golpe_cuerpo, query_ray_hit, bullet_hit, apply_explosion_impulse).

enum Tipo { RATA, CUCARACHA }

# Rata: la del glb mide 1.52 m de alto y 3.5 m sin la cola; a 0.145 queda de ~0.22 m de alto y
# ~0.5 m de largo, mas la cola
const RATA_ESCALA := 0.145
# El punto de la rata del glb que queda en el origen: entre las patas, a media panza
const RATA_ORIGEN := Vector3(0.01, -0.95, -1.15)
const RATA_COLOR := Color(0.8, 0.8, 0.82)   # mas claro que la cabeza de la cucarrata: chica se veia negra
# Cucaracha: ~1.5 m de cuerpo en el glb; a 0.45 queda de ~0.7 m (JJ: primero el triple del
# chihuahua para darle con la pistola, luego la mitad de eso pero el doble de cucarachas)
const CUCARACHA_ESCALA := 0.45
const CUCARACHA_COLOR := Color(0.66, 0.44, 0.28)
# Celdas de la piel de las crias: pocas y grandes (la cucarrata lleva 12 en el cuerpo y 18 en la
# cabeza), y pixeles mas gruesos, para que las grietas se lean a su tamano
const CELDAS_RATA := Vector2(6.0, 6.0)
const CELDAS_CUCARACHA := Vector2(7.0, 7.0)   # mas grande, mas celdas (a 0.3 eran 5, a 0.9 10)
const PIXELES := Vector2(64.0, 64.0)
const BRILLO := 1.5
const OJO_RADIO := 0.05   # en metros de la rata del glb, antes de escalar

enum Estado { QUIETA, AIRE, SUELO, VUELA, APUNTA, PICADA, SALTA, PEGADA, MUERTA }
const GRAVEDAD := 9.8
const RATA_CORRE := 0.9          # segundos que corre al caer, antes de ir por el jugador
const ALTURA_VUELO := Vector2(1.5, 2.6)   # metros sobre el piso donde revolotean las cucarachas
const RADIO := 0.25              # para el machete y las balas (la rata)
const RADIO_CUCARACHA := 0.35
# Golpes (machetazo o balazo, cuentan igual) para matar a una cria (JJ, 2026-11-17: de un
# toque no eran amenaza). Una rata pegada tambien: cada machetazo le quita uno
const GOLPES := 3
# El centro del cuerpo de la cucaracha en el glb (pose de vuelo, antes de escalar y pararla)
const CENTRO_CUCARACHA := Vector3(0.0, 0.7, 0.0)
# El origen del jugador es el centro de su capsula, ~1 m sobre el piso: el pecho queda poco arriba
const PECHO := 0.35              # pecho del jugador sobre su origen
const PIES := 1.0                # piso bajo el origen del jugador
# Cucaracha kamikaze
# Vuelan como moscas alrededor del jugador (JJ: lo que da miedo es verlas venir hacia ti): cada una
# va a un punto MOSCA_RADIO del otro lado del jugador, con giro limitado (hace curvas), y al
# llegar escoge otro, asi pasan por enfrente, cruzandose en tu camino y viniendo hacia ti. Atacan de
# una en una: a lo mas ATACAN_JUNTAS a la vez y ATAQUE_CADA s desde que truena (o muere) una hasta
# que sale la siguiente
const MOSCA_RADIO := Vector2(2.5, 6.5)
const MOSCA_ALTO := Vector2(0.9, 3.0)   # m sobre los pies del jugador
const MOSCA_ABRE := 1.3          # rad que se desvia del punto justo enfrente (del otro lado)
const MOSCA_VEL := Vector2(5.5, 8.0)
const MOSCA_GIRA := 4.0          # rad/s que puede torcer el rumbo
const MOSCA_LLEGA := 1.2         # m: ya llego, escoge otro punto
const MOSCA_CAMBIA := 2.5        # s: si no llega, escoge otro igual
# s que vuelan alrededor tuyo, desde que nace cada una, antes de poder lanzarse (JJ: que se vea la
# turba volando un rato antes del kamikaze)
const ENJAMBRE_ESPERA := 4.0
const TURNO_DESDE := Vector2(3.5, 8.0)   # m del jugador entre los que puede tomar su turno
const ATACAN_JUNTAS := 1
const ATAQUE_CADA := 1.6
const APUNTA_DURA := 0.8         # s quieta en el aire acomodandose en vertical (el aviso para rodar)
const PICADA_VEL := 11.0         # m/s al final de la picada
const PICADA_ACELERA := 18.0     # m/s2
const PICADA_GIRA := 2.5         # que tanto corrige el rumbo en la picada (rad/s): rodar la esquiva
const PICADA_MAX := 1.8          # s: si no pego, truena igual
const EXPLOTA_TOCA := 0.8        # m del pecho (al centro de la cucaracha) para tronar
const EXPLOTA_RADIO := 2.2       # m: hasta donde dana
const EXPLOTA_DANO := 15
const AZUL := Color(0.18, 0.77, 1.0)   # #2EC4FF, el de las grietas
# Rata
const RATA_VEL := 4.2            # m/s corriendo hacia el jugador
const SALTO_DURA := 0.42         # s en el aire
const SALTO_ALTO := 0.7
const MORDIDA := 5               # dano al pegarse
const CHUPA := 1.5               # vida por segundo, cada rata pegada
const FRENA := 0.12              # cada pegada te frena esto (minimo FRENA_MIN)
const FRENA_MIN := 0.5
const RATA_ENFRIA := 0.9         # s despues de fallar el salto
# Corren como moscas en el piso (JJ): cada una va a un punto del otro lado del jugador, con giro
# limitado, y al llegar escoge otro, asi se te cruzan entre los pies. Brincan a morder de una en
# una: tras RATA_ESPERA s de vida, desde RATA_TURNO m, con RATA_CADA s entre una y otra
const RATA_RADIO := Vector2(1.5, 4.5)
const RATA_RAPIDEZ := Vector2(4.0, 6.5)
const RATA_GIRA := 6.0           # rad/s
const RATA_LLEGA := 0.6
const RATA_CAMBIA := 1.5
const RATA_ESPERA := 2.5
const RATA_TURNO := Vector2(1.2, 3.4)
const RATA_CADA := 0.9
const LASTRE := "cucarrata_ratas"

@export var tipo := Tipo.RATA
@export var animacion_inicial := "vuela"   # solo la cucaracha
@export var persigue := true     # false: solo el vistazo (fotos)

static var _malla_rata: ArrayMesh
static var _malla_cucaracha: ArrayMesh
static var _mat_rata: ShaderMaterial
static var _mat_cucaracha: ShaderMaterial
static var _quito_en := -1       # cuadro del ultimo machetazo que ya quito una rata pegada
static var pegadas: Array[CriaCucarrata] = []
static var _atacando := 0        # cucarachas apuntando o en picada
static var _ultimo_ataque := -100000
static var _ratas_atacando := 0  # ratas brincando (una a la vez)
static var _rata_ultima := -100000
static var _ruido_ultimo := -100000   # el chillido o zumbido de fondo, uno para todo el enjambre
const RUIDO_CADA_MS := 700

var anim: AnimationPlayer   # la cucaracha
var _modelo: Node3D
var _t := randf() * 10.0
var _estado := Estado.QUIETA
var _vel := Vector3.ZERO
var _piso := 0.0
var _altura := 0.0
var _corre := 0.0
var _reloj := 0.0
var _salto_desde := Vector3.ZERO
var _salto_hasta := Vector3.ZERO
var _en_jugador := Vector3.ZERO   # donde va pegada, en el espacio del cuerpo del jugador
var _chupa := 0.0
var _jugador: Node3D
var _meta := Vector3.ZERO        # el punto al que vuela, alrededor del jugador
var _meta_reloj := 0.0
var _golpes := 0
var _rapidez := 6.0
var _turno := false              # esta cucaracha tiene uno de los ATACAN_JUNTAS


func _ready() -> void:
	add_to_group("lombrices")
	if tipo == Tipo.RATA:
		_armar_rata()
	else:
		_armar_cucaracha()


func _exit_tree() -> void:
	_despegar()
	_soltar_turno()


func _soltar_turno() -> void:
	if not _turno:
		return
	_turno = false
	if tipo == Tipo.RATA:
		_ratas_atacando = maxi(_ratas_atacando - 1, 0)
		_rata_ultima = Time.get_ticks_msec()
	else:
		_atacando = maxi(_atacando - 1, 0)
		_ultimo_ataque = Time.get_ticks_msec()   # la pausa cuenta desde que acaba


func animar(corto: String, mezcla := 0.15) -> void:
	if anim:
		var n: String = "giant_cockroach_armature|" + Cucarrata.ANIMS.get(corto, corto)
		if anim.has_animation(n):
			anim.play(n, mezcla)


# Sale de la cola de la cucarrata (Cucarrata._soltar): vuela en arco hasta el piso (piso_y). La
# rata cae y corre un rato hacia donde cayo y luego va por el jugador; la cucaracha abre las alas
# en el aire, sube y sale a buscarlo
func lanzar(velocidad: Vector3, piso_y: float) -> void:
	_vel = velocidad
	_piso = piso_y
	_estado = Estado.AIRE
	if tipo == Tipo.CUCARACHA:
		animar("vuela", 0.1)
		_altura = piso_y + randf_range(ALTURA_VUELO.x, ALTURA_VUELO.y)
		_meta_reloj = 0.0   # escoge su primer punto al volar


func _process(delta: float) -> void:
	_t += delta
	_reloj += delta
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D if persigue else null
	match _estado:
		Estado.AIRE:
			_vel.y -= GRAVEDAD * delta
			global_position += _vel * delta
			if tipo == Tipo.RATA:
				rotation.x -= delta * 9.0   # da vueltas en el aire
				if global_position.y <= _piso and _vel.y < 0.0:
					_caer_de_pie(Vector3(_vel.x, 0, _vel.z))
					_corre = RATA_CORRE
			elif _vel.y < 0.0:
				_estado = Estado.VUELA
		Estado.SUELO:
			_rata_suelo(delta)
		Estado.VUELA:
			_cucaracha_vuela(delta)
		Estado.APUNTA:
			_cucaracha_apunta(delta)
		Estado.PICADA:
			_cucaracha_picada(delta)
		Estado.SALTA:
			_rata_salta()
		Estado.PEGADA:
			_rata_pegada(delta)
	if tipo == Tipo.RATA and _estado != Estado.AIRE and _estado != Estado.SALTA:
		# La rata no tiene esqueleto: olfatea quieta, rebota rapido al correr y roe pegada
		var corriendo := _corre > 0.0 or (_estado == Estado.SUELO and _jugador != null)
		var rapido := 30.0 if _estado == Estado.PEGADA else (22.0 if corriendo else 9.0)
		var cuanto := 0.15 if _estado == Estado.PEGADA else (0.08 if corriendo else 0.04 * maxf(0.0, sin(_t * 1.3)))
		_modelo.rotation.x = sin(_t * rapido) * cuanto
		_modelo.position.y = absf(sin(_t * rapido)) * (0.02 if corriendo else 0.006)


# El centro del cuerpo, para pegarle y para que truene: la cucaracha vuela acostada o parada
func centro() -> Vector3:
	if tipo == Tipo.RATA or _modelo == null:
		return global_position + Vector3.UP * 0.12
	return _modelo.global_transform * CENTRO_CUCARACHA


func _radio() -> float:
	return RADIO if tipo == Tipo.RATA else RADIO_CUCARACHA


func _pecho() -> Vector3:
	return _jugador.global_position + Vector3.UP * PECHO


func _mirar_plano(hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length_squared() > 0.0001:
		look_at(global_position + hacia, Vector3.UP)   # la nariz es -Z


# --- Rata ---

func _caer_de_pie(rumbo: Vector3) -> void:
	global_position.y = _piso
	rotation = Vector3(0, rotation.y, 0)
	_mirar_plano(rumbo)
	_estado = Estado.SUELO
	_reloj = 0.0


func _rata_suelo(delta: float) -> void:
	if _corre > 0.0:
		_corre -= delta
		global_position += -global_transform.basis.z * RATA_VEL * 0.6 * delta
		return
	if _jugador == null or _reloj < 0.0:
		return
	_ruido("rata_corretea", -14.0)   # S-128
	var hacia := _jugador.global_position - global_position
	hacia.y = 0.0
	var lejos := hacia.length()
	if _t > RATA_ESPERA and lejos > RATA_TURNO.x and lejos < RATA_TURNO.y \
			and _ratas_atacando == 0 and Time.get_ticks_msec() - _rata_ultima > int(RATA_CADA * 1000.0):
		_ratas_atacando += 1
		_turno = true
		_mirar_plano(hacia)
		_estado = Estado.SALTA
		_reloj = 0.0
		_salto_desde = global_position
		# Adelanta un poco a donde va el jugador
		var va: Vector3 = _jugador.get("velocity") if _jugador.get("velocity") != null else Vector3.ZERO
		_salto_hasta = _pecho() + Vector3(va.x, 0, va.z) * SALTO_DURA * 0.5
		Sonidos.tocar(self, "rata_brinca", -8.0, randf_range(0.95, 1.15))   # S-129
		return
	# Como mosca en el piso: a su punto del otro lado del jugador, torciendo el rumbo
	_meta_reloj -= delta
	var plano := _meta - global_position
	plano.y = 0.0
	if _meta_reloj <= 0.0 or plano.length() < RATA_LLEGA:
		var angulo := atan2(-hacia.z, -hacia.x) + PI + randf_range(-MOSCA_ABRE, MOSCA_ABRE)
		_meta = _jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * randf_range(RATA_RADIO.x, RATA_RADIO.y)
		_meta_reloj = RATA_CAMBIA
		_rapidez = randf_range(RATA_RAPIDEZ.x, RATA_RAPIDEZ.y)
		plano = _meta - global_position
		plano.y = 0.0
	var rumbo := -global_transform.basis.z
	rumbo.y = 0.0
	rumbo = rumbo.normalized()
	var quiere := plano.normalized()
	var giro := clampf(rumbo.signed_angle_to(quiere, Vector3.UP), -RATA_GIRA * delta, RATA_GIRA * delta)
	rumbo = rumbo.rotated(Vector3.UP, giro)
	_mirar_plano(rumbo)
	global_position += rumbo * _rapidez * delta
	global_position.y = _piso


func _rata_salta() -> void:
	var f := clampf(_reloj / SALTO_DURA, 0.0, 1.0)
	var p := _salto_desde.lerp(_salto_hasta, f)
	p.y += sin(f * PI) * SALTO_ALTO
	global_position = p
	if _jugador and global_position.distance_to(_pecho()) < 0.6:
		_morder()
		return
	if f >= 1.0:
		# Fallo (rodaste o te moviste): cae y espera tantito
		_piso = _jugador.global_position.y - PIES if _jugador else _piso
		_caer_de_pie(_salto_hasta - _salto_desde)
		_reloj = -RATA_ENFRIA
		_soltar_turno()


func _morder() -> void:
	var esquiva: bool = _jugador.has_method("esquivando") and _jugador.esquivando()
	if esquiva:
		return   # sigue de largo; al acabar el salto cae
	var bloquea: bool = _jugador.get("_bloqueando") == true
	if _jugador.has_method("recibir_dano"):
		_jugador.recibir_dano(MORDIDA, global_position, 0.3, self)
	if bloquea:
		# Rebota en el machete
		_piso = _jugador.global_position.y - PIES
		_caer_de_pie(global_position - _jugador.global_position)
		global_position += (global_position - _jugador.global_position).normalized() * 0.8
		_reloj = -RATA_ENFRIA
		_soltar_turno()
		return
	_soltar_turno()   # ya se pego: le toca a la siguiente
	_estado = Estado.PEGADA
	var a := randf() * TAU
	_en_jugador = Vector3(cos(a) * 0.32, randf_range(-0.45, 0.5), sin(a) * 0.32)
	pegadas.append(self)
	_fx("pegada_mordida", global_position)
	Sonidos.tocar(self, "rata_mordida", -8.0, randf_range(0.95, 1.1))   # S-130


func _cuerpo_jugador() -> Node3D:
	var f = _jugador.get("frijol")
	return f if f is Node3D else _jugador


func _rata_pegada(delta: float) -> void:
	if _jugador == null:
		_despegar()
		return
	var cuerpo := _cuerpo_jugador()
	var base := cuerpo.global_basis.orthonormalized()
	global_position = _jugador.global_position + base * _en_jugador
	# Con la cabeza hacia el jugador
	var centro := _jugador.global_position + Vector3.UP * _en_jugador.y
	_mirar_plano(centro - global_position)
	if _jugador.get("lastres") != null:
		_jugador.lastres[LASTRE] = maxf(1.0 - FRENA * pegadas.size(), FRENA_MIN)
	_chupa += CHUPA * delta
	if _chupa >= 1.0:
		var salud := get_node_or_null("/root/Salud")
		if salud:
			salud.vida -= int(_chupa)
		_chupa -= int(_chupa)


func _despegar() -> void:
	pegadas.erase(self)
	if pegadas.is_empty() and _jugador and is_instance_valid(_jugador) and _jugador.get("lastres") != null:
		_jugador.lastres.erase(LASTRE)


# --- Cucaracha ---

# Revolotea a su altura; con jugador, vuela horizontal a su lugar alrededor de el y, cuando le
# toca el turno, apunta
func _cucaracha_vuela(delta: float) -> void:
	var meneo := Vector3(sin(_t * 7.3), sin(_t * 9.1) * 0.6, cos(_t * 6.7)) * 0.35
	if _jugador == null:
		_vel = _vel.lerp(Vector3.ZERO, delta * 2.0)
		_vel.y = (_altura - global_position.y) * 2.0
		global_position += (_vel + meneo) * delta
		return
	_ruido("cucaracha_zumbido", -16.0)   # S-132
	# Como mosca: a su punto del otro lado del jugador, torciendo el rumbo poco a poco
	_meta_reloj -= delta
	if _meta_reloj <= 0.0 or global_position.distance_to(_meta) < MOSCA_LLEGA:
		_nueva_meta()
	var rumbo := _vel.normalized() if _vel.length_squared() > 0.01 else -global_transform.basis.z
	var quiere := (_meta - global_position).normalized()
	var giro := minf(rumbo.angle_to(quiere), MOSCA_GIRA * delta)
	var eje := rumbo.cross(quiere)
	if eje.length_squared() > 0.000001:
		rumbo = rumbo.rotated(eje.normalized(), giro)
	_vel = rumbo * lerpf(_vel.length(), _rapidez, minf(delta * 3.0, 1.0))
	global_position += (_vel + meneo) * delta
	# La cabeza a donde va
	_mirar_plano(_vel)
	# Horizontal: la pose de vuelo del glb ya va acostada, la cabeza al frente y la panza abajo
	_modelo.rotation.x = lerp_angle(_modelo.rotation.x, 0.0, delta * 6.0)
	# Ni encima ni lejos: desde ahi se acomoda y se lanza
	var lejos := global_position.distance_to(_jugador.global_position)
	var en_turba := lejos > TURNO_DESDE.x and lejos < TURNO_DESDE.y
	if en_turba and _reloj > ENJAMBRE_ESPERA and _atacando < ATACAN_JUNTAS \
			and Time.get_ticks_msec() - _ultimo_ataque > int(ATAQUE_CADA * 1000.0):
		_atacando += 1
		_turno = true
		_ultimo_ataque = Time.get_ticks_msec()
		_estado = Estado.APUNTA
		_reloj = 0.0
		Sonidos.tocar(self, "cucaracha_aviso", -8.0, randf_range(1.0, 1.2))   # S-133


# Un punto del otro lado del jugador (desviado hasta MOSCA_ABRE), a su distancia y altura: para
# llegar pasa por enfrente de el
func _nueva_meta() -> void:
	var desde := global_position - _jugador.global_position
	var angulo := atan2(desde.z, desde.x) + PI + randf_range(-MOSCA_ABRE, MOSCA_ABRE)
	var r := randf_range(MOSCA_RADIO.x, MOSCA_RADIO.y)
	_meta = _jugador.global_position + Vector3(cos(angulo), 0, sin(angulo)) * r
	_meta.y = _jugador.global_position.y - PIES + randf_range(MOSCA_ALTO.x, MOSCA_ALTO.y)
	_meta_reloj = MOSCA_CAMBIA
	_rapidez = randf_range(MOSCA_VEL.x, MOSCA_VEL.y)


# Se frena y se queda fija en el aire mientras se para en vertical, mostrandote la panza (la
# cabeza arriba); despues se lanza y se estrella con la panza
func _cucaracha_apunta(delta: float) -> void:
	_vel = _vel.lerp(Vector3.ZERO, minf(delta * 8.0, 1.0))
	global_position += _vel * delta + Vector3(0, sin(_t * 18.0) * 0.15, 0) * delta
	# +90 en X: la cabeza (-Z) sube y la panza (-Y) queda al frente; -90 la ponia de cabeza, de lomo
	_modelo.rotation.x = lerp_angle(_modelo.rotation.x, PI * 0.5, minf(delta * 6.0, 1.0))
	if _jugador:
		_mirar_plano(_pecho() - global_position)
	if _reloj >= APUNTA_DURA:
		_modelo.rotation.x = PI * 0.5
		_estado = Estado.PICADA
		_reloj = 0.0
		var hacia := (_pecho() - global_position) if _jugador else -global_transform.basis.z
		_vel = hacia.normalized() * 2.0
		Sonidos.tocar(self, "cucaracha_picada", -8.0, randf_range(1.1, 1.3))   # S-134


# Acelera en vertical hacia ti; corrige poco el rumbo, asi rodando la esquivas
func _cucaracha_picada(delta: float) -> void:
	var rapidez := minf(_vel.length() + PICADA_ACELERA * delta, PICADA_VEL)
	var rumbo := _vel.normalized()
	if _jugador:
		var quiere := (_pecho() - global_position).normalized()
		var giro := minf(rumbo.angle_to(quiere), PICADA_GIRA * delta)
		var eje := rumbo.cross(quiere)
		if eje.length_squared() > 0.000001:
			rumbo = rumbo.rotated(eje.normalized(), giro)
	_vel = rumbo * rapidez
	global_position += _vel * delta
	_mirar_plano(_vel)
	var toca := _jugador != null and centro().distance_to(_pecho()) < EXPLOTA_TOCA
	if toca or global_position.y <= _piso + 0.05 or _reloj > PICADA_MAX:
		explotar()


# Truena en azul Serenol: dana al jugador si esta cerca (rodando se esquiva en recibir_dano)
func explotar(con_dano := true) -> void:
	if _estado == Estado.MUERTA:
		return
	_estado = Estado.MUERTA
	_soltar_turno()
	var donde := global_position
	if con_dano and _jugador and _jugador.global_position.distance_to(donde) < EXPLOTA_RADIO + 0.5 \
			and _pecho().distance_to(donde) < EXPLOTA_RADIO and _jugador.has_method("recibir_dano"):
		_jugador.recibir_dano(EXPLOTA_DANO, donde, 1.6, self)
	_estallido(get_parent(), donde, EXPLOTA_RADIO if con_dano else 0.8)
	_fx("saco_revienta", donde)
	Sonidos.tocar_suelto(self, "cucaracha_explota", -2.0, randf_range(0.95, 1.1))   # S-135
	queue_free()


# Estallido azul Serenol brillante (JJ): un nucleo celeste que revienta, una onda azul que
# crece y se apaga, chispas azules que salen volando y una luz fuerte. Todo con emision por encima
# de 1 para que el glow lo agarre. Se ve aunque no haya EfectosPixel en la escena
static func _estallido(padre: Node, donde: Vector3, radio: float) -> void:
	if padre == null:
		return
	var nodo := Node3D.new()
	padre.add_child(nodo)
	nodo.global_position = donde
	var nucleo := _bola_brillante(Color(0.45, 0.88, 1.0), 6.0, 0.9)
	var onda := _bola_brillante(Color(0.05, 0.45, 1.0), 4.0, 0.8)
	nodo.add_child(nucleo)
	nodo.add_child(onda)
	nucleo.scale = Vector3.ONE * 0.2
	onda.scale = Vector3.ONE * 0.3
	var chispas := CPUParticles3D.new()
	chispas.one_shot = true
	chispas.explosiveness = 1.0
	chispas.amount = int(18 + radio * 10)
	chispas.lifetime = 0.6
	chispas.direction = Vector3.UP
	chispas.spread = 180.0
	chispas.initial_velocity_min = radio * 2.5
	chispas.initial_velocity_max = radio * 5.0
	chispas.gravity = Vector3(0, -6, 0)
	chispas.scale_amount_min = 0.6
	chispas.scale_amount_max = 1.4
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE * 0.09
	caja.material = _brillo_material(AZUL, 7.0, 1.0)
	chispas.mesh = caja
	nodo.add_child(chispas)
	chispas.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = AZUL
	luz.light_energy = 14.0
	luz.omni_range = radio * 4.0
	luz.shadow_enabled = false
	nodo.add_child(luz)
	var mn: StandardMaterial3D = nucleo.material_override
	var mo: StandardMaterial3D = onda.material_override
	var t := nodo.create_tween().set_parallel()
	t.tween_property(nucleo, "scale", Vector3.ONE * radio * 0.8, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(mn, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	t.tween_property(onda, "scale", Vector3.ONE * radio * 1.5, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(mo, "albedo_color:a", 0.0, 0.4).set_delay(0.08)
	t.tween_property(luz, "light_energy", 0.0, 0.55).set_ease(Tween.EASE_IN)
	t.chain().tween_interval(0.3)
	t.chain().tween_callback(nodo.queue_free)


static func _brillo_material(color: Color, energia: float, alfa: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alfa)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energia
	return mat


static func _bola_brillante(color: Color, energia: float, alfa: float) -> MeshInstance3D:
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radial_segments = 10
	esfera.rings = 5
	bola.mesh = esfera
	bola.material_override = _brillo_material(color, energia, alfa)
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bola


# Un ruido de fondo del enjambre (chillido corriendo, zumbido volando): sale de una cria al azar y
# no mas de uno cada RUIDO_CADA_MS entre todas, si no con 12 crias era un solo ruido parejo
func _ruido(nombre: String, volumen_db: float) -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - _ruido_ultimo < RUIDO_CADA_MS or randf() > 0.05:
		return
	_ruido_ultimo = ahora
	Sonidos.tocar(self, nombre, volumen_db, randf_range(0.9, 1.2))


func _fx(lugar: String, donde: Vector3) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, Vector3.ZERO, 0.5)


func _morir() -> void:
	if tipo == Tipo.CUCARACHA:
		explotar(false)   # reventada a machetazo o balazo: truena chico, sin dano
		return
	if _estado == Estado.MUERTA:
		return
	_estado = Estado.MUERTA
	_despegar()
	_fx("cria_corte", global_position)
	_estallido(get_parent(), global_position, 0.35)
	if tipo == Tipo.RATA:
		Sonidos.tocar_suelto(self, "rata_muere", -6.0, randf_range(0.95, 1.15))   # S-131
	else:
		Sonidos.tocar_suelto(self, "cucaracha_muere", -6.0, randf_range(0.95, 1.15))   # S-136
	queue_free()


# --- Lo que el machete y la pistola le preguntan al grupo "lombrices" ---

# Un machetazo (Player._golpear, la estocada). A una rata pegada le da cualquier golpe, pero
# solo a una por golpe (las demas esperan al siguiente)
func golpe_cuerpo(origen: Vector3, frente: Vector3, alcance: float, cono: float, _dano: int, giro := false, _todas := false) -> bool:
	if _estado == Estado.MUERTA:
		return false
	if _estado == Estado.PEGADA:
		var cuadro := Engine.get_process_frames()
		if _quito_en == cuadro:
			return false
		_quito_en = cuadro
		_golpe(centro())
		return true
	var hacia := centro() - origen
	if absf(hacia.y) > 2.2 + _radio():
		return false
	hacia.y = 0.0
	if hacia.length() - _radio() > alcance:
		return false
	if not giro and hacia.length() > 0.3 and hacia.normalized().dot(frente) < cono:
		return false
	_golpe(centro())
	return true


func query_ray_hit(origen: Vector3, dir: Vector3, max_dist: float, radio: float) -> Dictionary:
	if _estado == Estado.MUERTA or _estado == Estado.PEGADA:
		return {}   # pegada no: el tiro le daria al jugador
	var c := centro()
	var t := (c - origen).dot(dir)
	if t < 0.0 or t > max_dist:
		return {}
	if (origen + dir * t).distance_to(c) > _radio() + radio:
		return {}
	return {"dot_index": 0, "position": origen + dir * t, "distance": t}


func bullet_hit(_i: int, punto: Vector3, _dir: Vector3) -> void:
	_golpe(punto)


# Un machetazo o un balazo: al GOLPES muere; antes solo el corte y el squelch
func _golpe(punto: Vector3) -> void:
	_golpes += 1
	if _golpes < GOLPES:
		_fx("cria_corte", punto)
		Sonidos.tocar(self, "squelch", -10.0, 1.5)
		return
	_morir()


# El azote del giro en el piso y las explosiones: las avienta (y suelta a las pegadas)
func apply_explosion_impulse(punto: Vector3, radio: float, fuerza: float, _algo = null) -> void:
	if _estado == Estado.MUERTA or global_position.distance_to(punto) > radio:
		return
	if tipo == Tipo.CUCARACHA:
		_morir()
		return
	_despegar()
	_piso = _jugador.global_position.y - PIES if _jugador else _piso
	var fuera := global_position - punto
	fuera.y = 0.0
	_vel = fuera.normalized() * fuerza * 0.4 + Vector3.UP * 3.0
	_estado = Estado.AIRE
	_reloj = 0.0


func _armar_rata() -> void:
	if _malla_rata == null:
		_malla_rata = _rata_entera()
	if _mat_rata == null:
		_mat_rata = Cucarrata.material_piel(_malla_rata.surface_get_material(0), 0.5, 1.0)
		_mat_rata.set_shader_parameter("hundido", 0.6)
		_mat_rata.set_shader_parameter("color_piel", RATA_COLOR)
		_mat_rata.set_shader_parameter("escala_celdas", CELDAS_RATA)
		_mat_rata.set_shader_parameter("pixeles", PIXELES)
		_mat_rata.set_shader_parameter("brillo", BRILLO)
		# Sin el degradado hacia la cola de la cucarrata: parejo en todo el cuerpo
		_mat_rata.set_shader_parameter("cola_desde", -100.0)
		_mat_rata.set_shader_parameter("cola_hasta", 50.0)
	_modelo = Node3D.new()
	add_child(_modelo)
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = _malla_rata
	cuerpo.material_override = _mat_rata
	_modelo.add_child(cuerpo)
	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = OJO_RADIO * RATA_ESCALA
		esfera.height = esfera.radius * 2.0
		esfera.radial_segments = 6
		esfera.rings = 3
		ojo.mesh = esfera
		ojo.material_override = Cucarrata.material_ojo()
		var o := Cucarrata.OJO
		ojo.position = _de_rata(Vector3(0.01 + (o.x - 0.01) * lado, o.y, o.z))
		_modelo.add_child(ojo)


# De la rata del glb (nariz +Z) a la cria: nariz hacia -Z como la cucarrata, escalada y con
# RATA_ORIGEN en el origen
static func _de_rata(p: Vector3) -> Vector3:
	var q := (p - RATA_ORIGEN) * RATA_ESCALA
	return Vector3(-q.x, q.y, -q.z)


static func _rata_entera() -> ArrayMesh:
	var rata: Node3D = Cucarrata.RATA.instantiate()
	var mi: MeshInstance3D = rata.find_children("*", "MeshInstance3D", true, false)[0]
	var t := Transform3D()
	var n: Node = mi
	while n != rata:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		var d := t.basis * normales[i]
		st.set_normal(Vector3(-d.x, d.y, -d.z).normalized())
		st.set_uv(uv[i])
		st.add_vertex(_de_rata(t * v[i]))
	var malla := st.commit()
	malla.surface_set_material(0, mi.mesh.surface_get_material(0))
	rata.free()
	return malla


func _armar_cucaracha() -> void:
	_modelo = Cucarrata.CUCARACHA.instantiate()
	_modelo.scale = Vector3.ONE * CUCARACHA_ESCALA
	add_child(_modelo)
	var esq: Skeleton3D = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	anim = _modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var cuerpo: MeshInstance3D = _modelo.find_children("*", "MeshInstance3D", true, false)[0]
	if _malla_cucaracha == null:
		_malla_cucaracha = Cucarrata.preparar_cucaracha(cuerpo.mesh, cuerpo.skin, esq, false)
	cuerpo.mesh = _malla_cucaracha
	if _mat_cucaracha == null:
		_mat_cucaracha = Cucarrata.material_piel(cuerpo.mesh.surface_get_material(0), 0.6, 1.0)
		_mat_cucaracha.set_shader_parameter("color_piel", CUCARACHA_COLOR)
		_mat_cucaracha.set_shader_parameter("escala_celdas", CELDAS_CUCARACHA)
		_mat_cucaracha.set_shader_parameter("pixeles", PIXELES)
		_mat_cucaracha.set_shader_parameter("brillo", BRILLO)
		_mat_cucaracha.set_shader_parameter("antenas", true)
		_mat_cucaracha.set_shader_parameter("antena_tramos", 7.0)
		_mat_cucaracha.set_shader_parameter("cola_desde", -100.0)
		_mat_cucaracha.set_shader_parameter("cola_hasta", 50.0)
	cuerpo.material_override = _mat_cucaracha
	for corto in Cucarrata.EN_CICLO:
		var a := anim.get_animation("giant_cockroach_armature|" + Cucarrata.ANIMS[corto])
		if a: a.loop_mode = Animation.LOOP_LINEAR
	animar(animacion_inicial)
