extends CharacterBody3D
class_name Player

@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 0.0025
@export var rotation_speed: float = 16.0
@export var speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var gravity: float = 40.0
@export var acceleration: float = 15.0
@export var jump_velocity: float = 13.0
# Q / E giran la camara (lo prende map_test.tscn; en world.tscn Q es del inventario)
@export var girar_con_qe: bool = false

# Initial downward pitch. Includes the +10.4 deg that used to be baked into the
# Camera3D node's transform, so removing that offset keeps the same view.
var camera_pitch: float = -4.6

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var frijol: Node3D = $Frijol
@onready var ninja: Node3D = $Frijol/Ninja

# Con que le pega a los zombis (Zombie.gd): el mejor `dano` del inventario, o a puño limpio.
# Inventario y Salud se piden por su ruta: los scripts de tools/ cargan esta clase antes
# de que existan los autoloads
const DANO_PUNO := 5
const ATAQUE_ENFRIAR := 0.6
const ATAQUE_PEGA_EN := 0.22
const ATAQUE_ALCANCE := 2.4
const ATAQUE_ANGULO := 0.35   # coseno: lo que abarca hacia los lados
const INVULNERABLE := 0.7     # s despues de recibir un golpe
const ARMA_TAMANO := 0.95    # m; con 0.6 el machete parecia cuchillo
# El mango va en el puño: crear_modelo centra y deja lo largo en X con el mango en +X
const ARMA_GIRO := Vector3(0.0, 90.0, -90.0)
const ARMA_MANGO := ARMA_TAMANO * 0.4
# Lo que se siente al pegar: `fuerza` es 1 con el machete y cambia con el dano del arma
const DANO_MACHETE := 12.0
const FUERZA_MIN := 0.5
const FUERZA_MAX := 1.5
const SWING_VOLUMEN := -8.0   # dB: para que resalte el whack
# m/s que rebotas hacia atras al pegarle a algo. En 0 a peticion de JJ, como el empujon del
# zombi (Zombie.EMPUJON): ni tu ni el se mueven con el golpe
const RETROCESO := 0.0
const RETROCESO_CAIDA := 14.0 # por segundo
const SACUDE := 0.05          # m de la camara
const SACUDE_MATA := 2.0
const SACUDE_DURA := 0.15
const CONGELA := 0.05         # s de reloj real
const CONGELA_MATA := 0.08
const CONGELA_ESCALA := 0.02
# Cuando le pegan a el. El empujon va frenando: v * v / (2 * freno) = 1.5 m
const GOLPEADO_EMPUJE := 7.0
const GOLPEADO_FRENO := 16.3
const CONGELA_GOLPEADO := 0.06
const SACUDE_GOLPEADO := 0.09
const FLASH_MS := 55
const SANGRE := 12
const SANGRE_RADIO := 0.2
const SANGRE_ABRE := 0.45
const SANGRE_VELOCIDAD := Vector2(4.0, 9.0)
const SANGRE_ALTO := 0.3      # m sobre el centro del modelo
const COLOR_SANGRE := Color(0.62, 0.02, 0.03)

signal golpeado

const CARGA_LUGAR := Vector3(0.0, -0.35, -0.55)
const BARRIDO := preload("res://scripts/Barrido.gd")
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
const POSE_ARMA := preload("res://scripts/PoseArma.gd")
const ESTELA_PUNO := 0.2      # m de la estela mas alla del puno, a mano limpia
# Hacia donde corre el efecto de la barrida: de la derecha a la izquierda del personaje, un poco
# al frente para que de lado a la camara no se voltee al azar
const BARRE_AL_FRENTE := 0.3
const COMBO_VENTANA := 0.5   # s despues del enfriamiento en que el siguiente golpe todavia va al reves
# s desde un golpe en que ya puede salir el siguiente: al terminar de barrer (Barrido.BARRE), sin
# esperar el enfriamiento. Si pegas antes, se guarda y sale entonces
const COMBO_DESDE := 0.3
# s desde que empieza un golpe en que no puedes caminar. Con pelea_a_tiempo, hasta que el golpe
# conecta: despues, moverte suelta el brazo y corta el combo, para quitarte si el zombi ya va a
# pegar. Sin ella, hasta que el brazo termina el barrido (Barrido.SOSTIENE)
const ATAQUE_QUIETO := 0.42
const ATAQUE_QUIETO_A_TIEMPO := ATAQUE_PEGA_EN

# Pelea con golpe a tiempo (Zombie.CORTE) y salirte del combo moviendote. En false, la prueba
# anterior: nunca se aturde y te quedas quieto todo el barrido. La cambia la tecla 9 del safehouse
static var pelea_a_tiempo := true
const BARRE_ALTO := 0.7       # m: la hoja barre a ras de piso; asi pasa por donde va el brazo
# La pistola (Pistola.gd): R cambia entre ella y el arma de golpe. Se ve en la mano en vez del
# machete; no es objeto del inventario por ahora
const PISTOLA := preload("res://scripts/Pistola.gd")
const PISTOLA_MODELO := preload("res://models/armas/pistola_mk23/pistola_mk23.scn")
# En el modelo el canon va hacia -X y la cacha abajo en +X. Con 0.3 m no se distinguia en la
# mano del ninja cabezon (por lo mismo el machete mide 0.95)
const PISTOLA_TAMANO := 0.55
const PISTOLA_GIRO := Vector3(0.0, 90.0, -90.0)
const PISTOLA_ROLL := 180.0   # grados sobre el canon: sin esto la cacha sale hacia arriba
const PISTOLA_MANGO := Vector3(-0.3, -0.1, 0.0) # del largo: la cacha queda en el puno
const PISTOLA_CANON := Vector3(-0.5, 0.12, 0.0) # la boca, del largo, desde el centro del modelo
const ARRIBA_TRAS_TIRO := 0.8 # s que sigue apuntando despues de disparar desde la cadera
const MIRA_LEJOS := 20.0      # m: a donde ven los brazos sobre el rayo de la mira
# Con la pistola, camara al hombro como Fortnite: mas cerca y mas alta, a la derecha (con el
# personaje al centro la mira le caia en la espalda), y el personaje siempre ve hacia donde
# apunta la camara, caminando de lado. Con apuntar (clic derecho, LT) se acerca mas, cierra
# el angulo, caminas mas lento y el raton se mueve mas fino
const HOMBRO := 0.8           # m a la derecha
const HOMBRO_ALTO := 0.85     # m que sube el pivote: arriba de la cabeza del ninja cabezon
const HOMBRO_BRAZO := 2.6     # m del resorte (sin pistola, el de la escena)
const APUNTA_HOMBRO := 1.1
const APUNTA_BRAZO := 2.0
const APUNTA_FOV := 45.0      # grados (sin apuntar, el de la camara)
const APUNTA_VELOCIDAD := 0.5 # de la velocidad al caminar
const APUNTA_RATON := 0.55    # de la sensibilidad
const CAMARA_CAMBIA := 10.0   # que tan rapido llega la camara a su lugar (por segundo)

static var _material_blanco: StandardMaterial3D

var _velocidad_base := Vector2.ZERO
var _factor_dano := 1.0
var _alcance := ATAQUE_ALCANCE
var _enfriar := 0.0
var _pega_en := -1.0
var _invulnerable := 0.0
const SALTO := 3.0   # m entre dos ticks: mas que esto no es caminar
var _pos_antes := Vector3.ZERO
var _pos_ahora := Vector3.ZERO
var _frijol_base := Vector3.ZERO
var _pivote_base := Vector3.ZERO
var _carga: Node3D
var _retroceso := Vector3.ZERO
var _retroceso_freno := 42.0
var _flash_hasta := 0
var _sacude_fuerza := 0.0
var _sacude_hasta := 0
var _congelado_hasta := 0
var _camara: Camera3D
var _voz: AudioStreamPlayer3D
var _mano: BoneAttachment3D
var _barrido: Node
var _lado_golpe := 1.0        # 1: de derecha a izquierda; -1: el de regreso del combo
var _combo_hasta := 0.0       # s de juego en que se acaba la ventana del combo
var _golpe_guardado := false
var _combo_roto := false      # te moviste a medio combo: el siguiente empieza de nuevo
var _arma_visible: InventoryItemData
var _pistola: Node
var _dato_pistola: InventoryItemData
var _hombro := 0.0
var _alzar := 0.0
var _brazo_base := 4.0
var _fov_base := 75.0
var _apuntando := false
var _pose: Node
var _canon: Node3D
var _tiro_hasta := 0


func _ready() -> void:
	add_to_group("jugador")
	_frijol_base = frijol.position
	_pivote_base = camera_pivot.position
	_camara = spring_arm.find_child("Camera3D", true, false) as Camera3D
	_brazo_base = spring_arm.spring_length
	_fov_base = _camara.fov
	var reloj := RelojCongelada.new()
	reloj.jugador = self
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(reloj)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_voz = AudioStreamPlayer3D.new()
	add_child(_voz)
	_armar_mano()
	_armar_barrido()
	_pistola = PISTOLA.new()
	_pistola.name = "Pistola"
	_pistola.jugador = self
	add_child(_pistola)
	_dato_pistola = InventoryItemData.new()
	_dato_pistola.item_name = "Pistola"
	_dato_pistola.inspection_model = PISTOLA_MODELO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.inventory_changed.connect(_mostrar_arma)
	_mostrar_arma()
	aplicar_personaje()
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		tazos.cambio.connect(aplicar_habilidades)


# Tu cuerpo (autoload Personaje): se ve en el modelo y cambia vida, velocidad y golpe. Sobre los
# valores de la escena, que no son iguales en todas. Encima van las habilidades de los tazos
# (Tazos.gd). Te deja con la vida llena
func aplicar_personaje() -> void:
	var personaje := get_node_or_null("/root/Personaje")
	if personaje:
		personaje.vestir(ninja)
	_aplicar_cuerpo(true)


# Cuando gastas o regresas puntos: igual, pero te quedas con la misma fraccion de vida
func aplicar_habilidades() -> void:
	_aplicar_cuerpo(false)


# Por nombre de nodo y no por clase: los scripts de tools/ cargan este archivo sin autoloads
func _aplicar_cuerpo(llenar: bool) -> void:
	if _velocidad_base == Vector2.ZERO:
		_velocidad_base = Vector2(speed, sprint_speed)
	var personaje := get_node_or_null("/root/Personaje")
	var tazos := get_node_or_null("/root/Tazos")
	if personaje == null and tazos == null:
		return
	var velocidad: float = (personaje.factor_velocidad() if personaje else 1.0) * (tazos.factor_velocidad() if tazos else 1.0)
	speed = _velocidad_base.x * velocidad
	sprint_speed = _velocidad_base.y * velocidad
	_factor_dano = (personaje.factor_dano() if personaje else 1.0) * (tazos.factor_dano() if tazos else 1.0)
	_alcance = ATAQUE_ALCANCE * (personaje.factor_alcance() if personaje else 1.0) * (tazos.factor_alcance() if tazos else 1.0)
	var salud := get_node_or_null("/root/Salud")
	if salud == null:
		return
	var fraccion: float = float(salud.vida) / maxf(salud.vida_max, 1.0)
	var base: int = personaje.vida_max() if personaje else salud.vida_max
	salud.vida_max = roundi(base * (tazos.factor_vida() if tazos else 1.0))
	salud.vida = salud.vida_max if llenar else maxi(roundi(fraccion * salud.vida_max), 1)


# Vida, dano del arma que traes, velocidad al caminar y alcance con el personaje pero sin
# tazos: la pagina de habilidades les aplica cada nivel para mostrar numeros de verdad
func valores_sin_tazos() -> Dictionary:
	var personaje := get_node_or_null("/root/Personaje")
	var valores := {}
	var velocidad_base := _velocidad_base.x if _velocidad_base != Vector2.ZERO else speed
	valores["velocidad"] = velocidad_base * (personaje.factor_velocidad() if personaje else 1.0)
	valores["alcance"] = ATAQUE_ALCANCE * (personaje.factor_alcance() if personaje else 1.0)
	var dano := DANO_PUNO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.arma():
		dano = inventario.arma().dano
	valores["dano"] = dano * (personaje.factor_dano() if personaje else 1.0)
	var salud := get_node_or_null("/root/Salud")
	if personaje:
		valores["vida"] = personaje.vida_max()
	elif salud:
		valores["vida"] = salud.vida_max
	return valores


# --- Pelear ---

func _atacar() -> void:
	# El siguiente sale encadenado, sin esperar todo el enfriamiento del anterior
	var encadena := _enfriar > 0.0 and not _combo_roto
	if _enfriar > 0.0 and not encadena:
		return
	if encadena and ATAQUE_ENFRIAR - _enfriar < COMBO_DESDE:
		_golpe_guardado = true
		return
	_golpe_guardado = false
	_combo_roto = false
	_enfriar = ATAQUE_ENFRIAR
	_pega_en = ATAQUE_PEGA_EN
	# Combo: mientras sigas pegando a tiempo, cada golpe va al reves del anterior; si tardas,
	# empieza otra vez de derecha a izquierda
	var ahora := Time.get_ticks_msec() / 1000.0
	_lado_golpe = -_lado_golpe if encadena or ahora <= _combo_hasta else 1.0
	_combo_hasta = ahora + ATAQUE_ENFRIAR + COMBO_VENTANA
	# Encadenado no se repite la estocada del cuerpo: se veia como si rebotara entre golpe y golpe
	if ninja.has_method("accion") and not encadena:
		ninja.accion("Punch")
	if _barrido:
		# Del puno a la punta: el centro del arma queda ARMA_MANGO adelante del puno
		_barrido.largo = ARMA_TAMANO * 0.5 + ARMA_MANGO if _arma_visible else ESTELA_PUNO
		_barrido.golpe(_lado_golpe)
	_sonar("machetazo", SWING_VOLUMEN)


func _golpear() -> void:
	var dano := DANO_PUNO
	var con_arma := false
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		var arma: InventoryItemData = inventario.arma()
		if arma:
			dano = arma.dano
			con_arma = true
	dano = maxi(roundi(dano * _factor_dano), 1)
	var frente := -frijol.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var barre := -frijol.global_basis.x * _lado_golpe + frente * BARRE_AL_FRENTE
	barre.y = 0.0
	efecto("golpe", barre, "" if con_arma else "puno", BARRE_ALTO)
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	# Un zombi muerto en este golpe truena justo al soltar la congelada
	var truena_en := int(CONGELA_MATA * 1000.0)
	var pego := false
	var mato := false
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if hacia.length() <= _alcance and hacia.normalized().dot(frente) >= ATAQUE_ANGULO:
			var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, truena_en)
			pego = pego or resultado != 0
			mato = mato or resultado == 2
	if pego:
		_sentir_golpe(frente, fuerza, mato)


# Una vez por golpe, aunque le pegue a varios: el whack, el rebote, la sacudida y la congelada
func _sentir_golpe(frente: Vector3, fuerza: float, mato: bool) -> void:
	_voz.pitch_scale = randf_range(0.9, 1.12)
	_sonar("whack")
	_retroceso = -frente * RETROCESO * fuerza
	_retroceso_freno = RETROCESO * RETROCESO_CAIDA
	_sacude_fuerza = SACUDE * fuerza * (SACUDE_MATA if mato else 1.0)
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_MATA if mato else CONGELA)


# El juego casi se detiene unos cuadros. Un SceneTreeTimer no servia para soltarlo: con la
# escala de tiempo tan baja se quedaba en camara lenta varios segundos
func _congelar(segundos: float) -> void:
	_congelado_hasta = maxi(_congelado_hasta, Time.get_ticks_msec() + int(segundos * 1000.0))
	Engine.time_scale = CONGELA_ESCALA


func _revisar_congelada() -> void:
	var ahora := Time.get_ticks_msec()
	if _congelado_hasta > 0 and ahora >= _congelado_hasta:
		_congelado_hasta = 0
		Engine.time_scale = 1.0
	if _flash_hasta > 0 and ahora >= _flash_hasta:
		_flash_hasta = 0
		_pintar_blanco(false)


func _exit_tree() -> void:
	if _congelado_hasta > 0:
		_congelado_hasta = 0
		Engine.time_scale = 1.0


# Mira el reloj en cada cuadro aunque el juego este en pausa o el jugador apagado (el
# inventario, una tienda): la congelada siempre se suelta
class RelojCongelada extends Node:
	var jugador: Player

	func _process(_delta: float) -> void:
		jugador._revisar_congelada()


# Un golpe de zombi (Zombie.gd), con todo lo que se siente: congelada, flash, sacudida,
# empujon y sangre hacia donde iba el golpe; Supervivencia.gd hace el cuadro de impacto
func recibir_dano(dano: int, desde: Vector3, empuja := 1.0) -> void:
	if _invulnerable > 0.0:
		return
	_invulnerable = INVULNERABLE
	if ninja.has_method("accion"):
		ninja.accion("RecieveHit")
	_sonar("dolor")
	var hacia := global_position - desde
	hacia.y = 0.0
	hacia = hacia.normalized() if hacia.length_squared() > 0.001 else frijol.global_basis.z
	_flash_hasta = Time.get_ticks_msec() + FLASH_MS
	_pintar_blanco(true)
	_retroceso = hacia * GOLPEADO_EMPUJE * empuja
	_retroceso_freno = GOLPEADO_FRENO
	_sacude_fuerza = SACUDE_GOLPEADO
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_GOLPEADO)
	_sangrar(hacia)
	efecto("herido", hacia)
	golpeado.emit()
	# Piel dura (Tazos.gd): de noche duele menos
	var tazos := get_node_or_null("/root/Tazos")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if tazos and ciclo and ciclo.es_noche():
		dano = maxi(roundi(dano * tazos.factor_dano_noche()), 1)
	get_node("/root/Salud").vida -= dano


# Sale de adentro del modelo, que es lo que se ve (frijol va suavizado). Por grupo y sin el
# tipo: los scripts de tools/ cargan esta clase
func _sangrar(hacia: Vector3) -> void:
	var liquido := get_tree().get_first_node_in_group("liquido")
	if liquido:
		liquido.salpicar(frijol.global_position + Vector3.UP * SANGRE_ALTO, SANGRE_RADIO, global_position.y - 1.0,
			(hacia + Vector3.UP * 0.3).normalized(), SANGRE, COLOR_SANGRE, SANGRE_VELOCIDAD, SANGRE_ABRE)


# Un efecto de pixel (EfectosPixel.gd) a los pies del modelo, que es lo que se ve. Por grupo y
# sin el tipo, como el liquido
func efecto(lugar: String, hacia: Vector3, opcion := "", alto := 0.0) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar(lugar, Vector3(frijol.global_position.x, global_position.y - 1.0 + alto, frijol.global_position.z), hacia, 1.0, opcion)


# Todo el modelo, con el arma que traiga en la mano
func _pintar_blanco(prendido: bool) -> void:
	if _material_blanco == null:
		_material_blanco = StandardMaterial3D.new()
		_material_blanco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_blanco.albedo_color = Color.WHITE
		_material_blanco.disable_fog = true
	for malla: MeshInstance3D in frijol.find_children("*", "MeshInstance3D", true, false):
		malla.material_overlay = _material_blanco if prendido else null


# Algo en las manos, enfrente: una mision (MisionesMundo.gd)
func cargar(cosa: Node3D) -> void:
	soltar_carga()
	_carga = cosa
	frijol.add_child(cosa)
	cosa.position = CARGA_LUGAR
	cosa.rotation = Vector3.ZERO
	ninja.set("cargando", true)


func soltar_carga() -> void:
	if _carga:
		_carga.queue_free()
		_carga = null
	ninja.set("cargando", false)


# Se queda quieto y deja de contestar (al desmayarse, Supervivencia.gd)
func detener() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)


func reanudar() -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
	if ninja.has_method("terminar_accion"):
		ninja.terminar_accion()


func caer() -> void:
	if ninja.has_method("accion"):
		ninja.accion("Defeat")


# La mano derecha del modelo; el arma se ve en ella
func _armar_mano() -> void:
	var esqueleto := ninja.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null:
		return
	for nombre in ["Fist.R", "Hand.R", "Wrist.R", "LowerArm.R"]:
		if esqueleto.find_bone(nombre) >= 0:
			_mano = BoneAttachment3D.new()
			esqueleto.add_child(_mano)
			_mano.bone_name = nombre
			return


# Te moviste a medio combo: el brazo se suelta desde donde va y lo que habias picado se olvida
func _soltar_combo() -> void:
	_combo_roto = true
	_golpe_guardado = false
	_combo_hasta = 0.0
	if _barrido:
		_barrido.soltar()


# El golpe es un barrido de lado hecho con los huesos (Barrido.gd): el modelo solo trae Punch
func _armar_barrido() -> void:
	var esqueleto := ninja.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null:
		return
	_barrido = BARRIDO.new()
	_barrido.name = "Barrido"
	_barrido.frijol = frijol
	_barrido.estela = ESTELA.new()
	add_child(_barrido.estela)
	esqueleto.add_child(_barrido)
	_pose = POSE_ARMA.new()
	_pose.name = "PoseArma"
	_pose.frijol = frijol
	esqueleto.add_child(_pose)


func _mostrar_arma() -> void:
	if _mano == null:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var arma: InventoryItemData = inventario.arma() if inventario else null
	var pistola: bool = _pistola != null and _pistola.activa
	if pistola:
		arma = _dato_pistola
	if arma == _arma_visible:
		return
	_arma_visible = arma
	_canon = null
	for hijo in _mano.get_children():
		hijo.queue_free()
	if arma == null:
		return
	var modelo := arma.crear_modelo(PISTOLA_TAMANO if pistola else ARMA_TAMANO)
	if modelo:
		_mano.add_child(modelo)
		modelo.visible = false
		# Un cuadro despues: antes el hueso todavia no tiene su transformacion. Sin la
		# escala del hueso, y con la hoja hacia adelante del puño
		await get_tree().process_frame
		if not is_instance_valid(modelo):
			return
		var escala := _mano.global_transform.basis.get_scale()
		modelo.scale = Vector3.ONE / maxf(escala.x, 0.001)
		modelo.rotation_degrees = PISTOLA_GIRO if pistola else ARMA_GIRO
		if pistola:
			modelo.basis = modelo.basis * Basis(Vector3.RIGHT, deg_to_rad(PISTOLA_ROLL))
		if pistola:
			(modelo.get_child(0) as Node3D).position += PISTOLA_MANGO * PISTOLA_TAMANO
			_canon = Marker3D.new()
			_canon.position = (PISTOLA_MANGO + PISTOLA_CANON) * PISTOLA_TAMANO
			modelo.add_child(_canon)
		else:
			(modelo.get_child(0) as Node3D).position.x -= ARMA_MANGO
		modelo.visible = true


func _sonar(nombre: String, volumen := 0.0) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.volume_db = volumen
	_voz.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensibilidad := mouse_sensitivity * (APUNTA_RATON if _apuntando else 1.0)
		camera_pivot.rotation.y -= event.relative.x * sensibilidad
		camera_pitch -= event.relative.y * sensibilidad * 100.0
		camera_pitch = clampf(camera_pitch, -60.0, 30.0)
		spring_arm.rotation_degrees.x = camera_pitch
	elif event.is_action_pressed("cambiar_arma") and is_physics_processing():
		_pistola.cambiar()
		_soltar_combo()
		_mostrar_arma()
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _pistola.activa:
			_pistola.disparar()
		else:
			_atacar()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and is_physics_processing() and not get_tree().paused:
		# Con el raton suelto (Esc), un clic en la ventana lo vuelve a agarrar sin pegar
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# El cuerpo se mueve a 60 por segundo y la pantalla mas seguido: sin esto el personaje y la
# camara avanzan a saltitos aunque haya muchos FPS. Solo se suaviza lo que se ve (modelo y
# camara), entre las dos ultimas posiciones del cuerpo; la fisica no cambia.
func _process(_delta: float) -> void:
	var ahora := global_position
	# Lo movieron de golpe (reaparecer, salir de una tienda) o esta congelado: sin suavizar
	if not is_physics_processing() or _pos_ahora.distance_squared_to(ahora) > SALTO * SALTO:
		_pos_antes = ahora
		_pos_ahora = ahora
	var fraccion := Engine.get_physics_interpolation_fraction()
	var desfase := global_basis.inverse() * (_pos_antes.lerp(_pos_ahora, fraccion) - ahora)
	frijol.position = _frijol_base + desfase
	camera_pivot.position = _pivote_base + desfase + Vector3.UP * _alzar
	_camara_al_hombro()
	_sacudir()
	_posar()


# Los brazos con la pistola (PoseArma.gd): sosteniendola, o apuntando a la mira al apuntar o
# recien disparado desde la cadera
func _posar() -> void:
	if _pose == null:
		return
	_pose.sostiene = _pistola.activa and is_physics_processing()
	_pose.apunta = _apuntando or Time.get_ticks_msec() < _tiro_hasta
	var centro := get_viewport().get_visible_rect().size / 2.0
	_pose.blanco = _camara.project_ray_origin(centro) + _camara.project_ray_normal(centro) * MIRA_LEJOS


# Pistola.gd en cada tiro: sube el arma a la mira un rato y patea los brazos
func pose_tiro() -> void:
	_tiro_hasta = Time.get_ticks_msec() + int(ARRIBA_TRAS_TIRO * 1000.0)
	if _pose:
		_pose.tiro()


# De donde sale el tiro: la boca de la pistola, o la mano
func canon() -> Vector3:
	if _canon and is_instance_valid(_canon) and _canon.is_inside_tree():
		return _canon.global_position
	return _mano.global_position if _mano else global_position + Vector3.UP * 1.2


# Con la pistola la camara se va al hombro, y mas cerca al apuntar. En reloj real: la
# congelada del golpe no debe dejarla a medio camino
func _camara_al_hombro() -> void:
	var paso := clampf(CAMARA_CAMBIA * get_process_delta_time() / maxf(Engine.time_scale, 0.001), 0.0, 1.0)
	var pistola: bool = _pistola.activa
	_apuntando = pistola and is_physics_processing() and Input.is_action_pressed("apuntar")
	_hombro = lerpf(_hombro, (APUNTA_HOMBRO if _apuntando else HOMBRO) if pistola else 0.0, paso)
	_alzar = lerpf(_alzar, HOMBRO_ALTO if pistola else 0.0, paso)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, (APUNTA_BRAZO if _apuntando else HOMBRO_BRAZO) if pistola else _brazo_base, paso)
	_camara.fov = lerpf(_camara.fov, APUNTA_FOV if _apuntando else _fov_base, paso)


# Corrimiento de la camara, no de su nodo: el resorte ni se entera. En reloj real, porque el
# golpe tambien congela el juego
func _sacudir() -> void:
	if _sacude_hasta == 0:
		_camara.h_offset = _hombro
		_camara.v_offset = 0.0
		return
	var queda := float(_sacude_hasta - Time.get_ticks_msec()) / (SACUDE_DURA * 1000.0)
	if queda <= 0.0:
		_sacude_hasta = 0
		_camara.h_offset = _hombro
		_camara.v_offset = 0.0
		return
	_camara.h_offset = _hombro + randf_range(-1.0, 1.0) * _sacude_fuerza * queda
	_camara.v_offset = randf_range(-1.0, 1.0) * _sacude_fuerza * queda


func _physics_process(delta: float) -> void:
	_enfriar = maxf(_enfriar - delta, 0.0)
	if _golpe_guardado and ATAQUE_ENFRIAR - _enfriar >= COMBO_DESDE:
		_atacar()
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if _pega_en >= 0.0:
		_pega_en -= delta
		if _pega_en < 0.0:
			_golpear()
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var quieto := ATAQUE_QUIETO_A_TIEMPO if pelea_a_tiempo else ATAQUE_QUIETO
	if _enfriar > 0.0 and ATAQUE_ENFRIAR - _enfriar < quieto:
		input_direction = Vector2.ZERO
	elif pelea_a_tiempo and input_direction != Vector2.ZERO and _enfriar > 0.0 and not _combo_roto:
		_soltar_combo()

	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var right: Vector3 = camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = right * input_direction.x + forward * -input_direction.y

	var is_moving: bool = direction.length_squared() > 0.01
	var is_sprinting: bool = is_moving and Input.is_action_pressed("sprint")
	var move_speed: float = sprint_speed if is_sprinting else speed
	if _apuntando:
		move_speed = speed * APUNTA_VELOCIDAD
	var target_horizontal := Vector3.ZERO
	# Con la pistola ve siempre hacia donde apunta la camara, aunque camine para otro lado
	var apunta: bool = _pistola.activa
	if is_moving or apunta:
		var look_target: Vector3 = frijol.global_position + (forward if apunta else direction)
		var target_transform: Transform3D = frijol.global_transform.looking_at(look_target, Vector3.UP)
		frijol.global_transform = frijol.global_transform.interpolate_with(
			target_transform,
			clampf(rotation_speed * delta, 0.0, 1.0)
		)
		var facing: Vector3 = -frijol.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		if apunta:
			facing = direction.normalized()
		target_horizontal = facing * move_speed if is_moving else Vector3.ZERO

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var braking: bool = not is_moving or horizontal.length() > target_horizontal.length() + 0.05
	if not braking and horizontal.length_squared() > 0.01 and target_horizontal.length_squared() > 0.01:
		braking = horizontal.normalized().dot(target_horizontal.normalized()) < 0.92
	if braking:
		velocity.x = target_horizontal.x
		velocity.z = target_horizontal.z
	else:
		velocity.x = move_toward(velocity.x, target_horizontal.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_horizontal.z, acceleration * delta)

	# Gravity is applied exactly once per frame; on the floor we snap to zero.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	# Keyboard / gamepad camera rotation (mouse-look is handled above).
	var camera_input: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down",
		0.2
	)
	if girar_con_qe:
		var teclas := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		camera_input.x = clampf(camera_input.x + teclas, -1.0, 1.0)
	if camera_input.length() > 0.2:
		camera_pivot.rotation.y -= camera_input.x * camera_sensitivity * delta
		camera_pitch -= camera_input.y * camera_sensitivity * 50.0 * delta
	camera_pitch = clampf(camera_pitch, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch

	if Input.is_action_just_pressed("jump") and is_on_floor():
		var cercano := _nearby_interactable()
		if cercano != null:
			cercano.interact()
		else:
			velocity.y = jump_velocity

	# El rebote va aparte: el frenado de arriba lo borraria
	velocity += _retroceso
	move_and_slide()
	velocity -= _retroceso
	_retroceso = _retroceso.move_toward(Vector3.ZERO, _retroceso_freno * delta)
	_pos_antes = _pos_ahora
	_pos_ahora = global_position

	if ninja.has_method("update_animation"):
		ninja.update_animation(is_moving, not is_on_floor(), is_sprinting)


# El NPC o el objeto para recoger (WorldItem) mas cercano que tenga al jugador en su area
func _nearby_interactable() -> Node:
	var closest: Node = null
	var closest_distance := INF
	for grupo: String in ["npc", "interactuable"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not nodo.has_method("is_player_inside") or not nodo.is_player_inside():
				continue
			var distance := global_position.distance_squared_to(nodo.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = nodo
	return closest
