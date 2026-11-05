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
# Initial downward pitch. Includes the +10.4 deg that used to be baked into the
# Camera3D node's transform, so removing that offset keeps the same view.
var camera_pitch: float = -4.6

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var frijol: Node3D = $Frijol
@onready var figura: Node3D = $Frijol/Modelo

# Con que le pega a los zombis (Zombie.gd): el mejor `dano` del inventario, o a puño limpio.
# Inventario y Salud se piden por su ruta: los scripts de tools/ cargan esta clase antes
# de que existan los autoloads
const DANO_PUNO := 5
const ATAQUE_ENFRIAR := 0.6
const ATAQUE_PEGA_EN := 0.22
const ATAQUE_ALCANCE := 2.4
const ATAQUE_ANGULO := 0.35   # coseno: lo que abarca hacia los lados
const ATAQUE_MAXIMO := 1       # zombis a los que le pega un mismo golpe: el mas cercano
const INVULNERABLE := 0.7     # s despues de recibir un golpe
# Q (accion curarse) se come la curacion que mejor llene lo que falta, sin abrir el
# inventario (pausar rompia la tension). Mientras, no caminas ni pegas
const CURAR_DURA := 0.8
const ARMA_TAMANO := 0.95    # m; con 0.6 el machete parecia cuchillo
# El mango va en el puño: crear_modelo centra y deja lo largo en X con el mango en +X. En la mano
# (RightHand del retarget) X es hacia el pulgar, Y hacia los dedos y Z la palma: la hoja sale del
# lado del pulgar con el filo hacia los dedos, como la agarran los clips de espada de Quaternius
const ARMA_GIRO := Vector3(-90.0, 180.0, 0.0)
const ARMA_MANGO := ARMA_TAMANO * 0.4
# Lo que se siente al pegar: `fuerza` es 1 con el machete y cambia con el dano del arma
const DANO_MACHETE := 12.0
const FUERZA_MIN := 0.5
const FUERZA_MAX := 1.5
const SWING_VOLUMEN := -14.0  # dB: para que resalte el whack (JJ lo bajo a la mitad: -6 dB)
const WHACK_VOLUMEN := -6.0   # dB: a la mitad, como el swing
# m/s que rebotas hacia atras al pegarle a algo. En 0 a peticion de JJ: tu no te mueves con
# el golpe (el zombi si retrocede un poco, Zombie.EMPUJON)
const RETROCESO := 0.0
const RETROCESO_CAIDA := 14.0 # por segundo
const RETROCESO_TIRO := 0.6   # m/s para atras por balazo (0 = nada)
const RETROCESO_TIRO_FRENO := 8.0 # se va en 1/8 s
const ARMAS_TECLAS := 5       # arma_1..arma_5
const PATADA_VUELVE := 0.2    # s en que la camara regresa de la patada de un balazo
# Sangre (pixelfx sangre_arma) que gotea de la punta del arma un rato tras pegarle a un zombi
const SANGRE_DURA_MS := 2500
const SANGRE_ESCALA := 0.4
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
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
const ESTELA_PUNO := 0.2      # m de la estela mas alla del puno, a mano limpia
# La estela del machetazo sigue la punta del arma mientras barre (s del clip, desde-hasta): no
# al llevar el brazo atras ni al regresarlo
const ESTELA_GOLPE := {"Sword_Regular_A": Vector2(0.10, 0.30), "Sword_Regular_B": Vector2(0.10, 0.32),
	"Sword_Regular_C": Vector2(0.05, 0.75), "Sword_Dash_RM": Vector2(0.10, 0.60)}
const ESTELA_PASO := 6.0      # grados entre pedazos: con pocos cuadros salia en tiras rectas
# Hacia donde corre el efecto de la barrida: de la derecha a la izquierda del personaje, un poco
# al frente para que de lado a la camara no se voltee al azar
const BARRE_AL_FRENTE := 0.3
const COMBO_VENTANA := 0.5   # s despues del enfriamiento en que el siguiente golpe todavia va al reves
# s desde un golpe en que ya puede salir el siguiente: al terminar de barrer, sin
# esperar el enfriamiento. Si pegas antes, se guarda y sale entonces
const COMBO_DESDE := 0.3
# s desde que empieza un golpe en que caminas lento (GOLPE_VELOCIDAD), sin correr y viendo hacia
# la camara, con el barrido solo en la parte de arriba del cuerpo. Antes (JJ) no se podia caminar
# y con pelea_a_tiempo moverte cortaba el combo; AG lo cambio el 2026-11-04
const ATAQUE_LENTO := 0.42
const ATAQUE_LENTO_A_TIEMPO := ATAQUE_PEGA_EN
const GOLPE_VELOCIDAD := 0.6  # de la velocidad al caminar

# Pelea con golpe a tiempo (Zombie.CORTE) y salirte del combo moviendote. En false, la prueba
# anterior: nunca se aturde y te quedas quieto todo el barrido. La cambia la tecla 9 del safehouse
static var pelea_a_tiempo := true
# PRUEBA (JJ): ataque cargado. Con el machete, deja apretado atacar: el primer golpe sale como
# siempre y a los CARGA_DURA s el arma brilla azul; al soltar, un espadazo giratorio
# (Sword_Regular_C, la cadera da la vuelta entre 0 y 0.7 s) que le pega a los que esten
# alrededor, con la estela de agua. Pegar en el aire lo saca de una vez, sin cargar.
# Solo lo prende el safehouse (tecla 7)
static var golpe_cargado := false
# El giro con la estela de agua: pensada como mejora que se gana (JJ). false = la estela normal
static var giro_agua := true
const CARGA_DURA := 0.7       # s con el boton apretado
const CARGA_COLOR := Color(0.35, 0.65, 1.0)
const CARGA_LUZ := 2.5        # energia de la luz al estar cargado
const GIRO_PEGA_EN := 0.35    # s del clip: a media vuelta
const GIRO_DURA := 0.95       # s: ahi se suelta el clip (lo demas es enderezarse) y ya puedes moverte
const GIRO_ALCANCE := 1.3     # x el alcance normal, en redondo
const GIRO_DANO := 1.5        # x el dano del arma
const GIRO_MAXIMO := 6        # zombis a los que le pega
# En el aire: el clip arranca lento (38 grados en 0.1 s), asi que empieza ya en GIRO_AIRE_DESDE s,
# girando, y un poco mas rapido; el salto sigue igual. El golpe pega al caer al piso
const GIRO_AIRE_DESDE := 0.12
const GIRO_AIRE_VELOCIDAD := 1.5
# PRUEBA (JJ): estocada con avance. Pegar mientras corres (sprint y moviendote) con el machete:
# Sword_Dash_RM, te lanza ESTOCADA_AVANCE m hacia donde ve la camara (el clip avanza 3.7 m con
# su hueso Root, que la biblioteca quita; aqui lo hace el cuerpo, asi choca con las paredes) y
# atraviesa: le pega a cada zombi que tengas enfrente mientras avanzas, hasta ESTOCADA_MAXIMO.
# Solo la prende el safehouse (tecla 6; Shift+6 su estela de agua)
static var estocada := false
static var estocada_agua := true
const ESTOCADA_AVANCE := 3.5   # m
const ESTOCADA_DESDE := 0.12   # s del clip en que arranca el avance (el amago antes)
const ESTOCADA_HASTA := 0.55   # s en que ya llegaste
const ESTOCADA_PEGA := Vector2(0.15, 0.6)  # s del clip en que la punta hace dano
const ESTOCADA_RADIO := 1.4    # m enfrente de ti en que le pega a un zombi
const ESTOCADA_DURA := 0.8     # s: ahi se suelta el clip y ya puedes moverte
const ESTOCADA_DANO := 1.5     # x el dano del arma
const ESTOCADA_MAXIMO := 4
const BARRE_ALTO := 0.7       # m: la hoja barre a ras de piso; asi pasa por donde va el brazo
# La pistola (Pistola.gd): R cambia entre ella y el arma de golpe. Se ve en la mano en vez del
# machete; no es objeto del inventario por ahora
const PISTOLA := preload("res://scripts/Pistola.gd")
const PISTOLA_MODELO := preload("res://models/armas/pistola_mk23/pistola_mk23.scn")
# En el modelo el canon va hacia -X y la cacha abajo en +X. Con el ninja cabezon median 0.55 m
# para distinguirse en su puno enorme; el protagonista tiene manos de tamano normal
const PISTOLA_TAMANO := 0.4
# En la mano: lo de arriba de la pistola hacia el pulgar (X) y el canon hacia los dedos (Y)
const PISTOLA_GIRO := Vector3(0.0, 0.0, -90.0)
const PISTOLA_ROLL := 0.0     # grados sobre el canon, si la cacha saliera hacia arriba
const PISTOLA_MANGO := Vector3(-0.3, -0.1, 0.0) # del largo: la cacha queda en el puno
const PISTOLA_CANON := Vector3(-0.5, 0.12, 0.0) # la boca, del largo, desde el centro del modelo
const ARRIBA_TRAS_TIRO := 0.8 # s que sigue apuntando despues de disparar desde la cadera
const MIRA_LEJOS := 20.0      # m: a donde apuntan los brazos sobre el rayo de la mira
const PECHO := 0.5            # m sobre el centro del cuerpo: de ahi se mide a que altura apunta
# Con la pistola, camara al hombro como Fortnite: mas cerca y mas alta, a la derecha (con el
# personaje al centro la mira le caia en la espalda), y el personaje siempre ve hacia donde
# apunta la camara, caminando de lado. Con apuntar (clic derecho, LT) se acerca mas, cierra
# el angulo, caminas mas lento y el raton se mueve mas fino
const HOMBRO := 0.8           # m a la derecha
const HOMBRO_ALTO := 0.85     # m que sube el pivote: a la altura de la cabeza
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
var _apretado := -1.0           # s que llevas apretando atacar; -1 = no estas cargando
var _cargado := false
var _giro := -1.0            # s desde que salio el giro; -1 = no hay
var _giro_pego := false
var _giro_vel := 1.0         # GIRO_AIRE_VELOCIDAD si salio en el aire
var _giro_aire := false      # salio en el aire: pega al caer (_revisar_carga)
var _luz_carga: OmniLight3D
var _estocada_t := -1.0      # s desde que salio la estocada; -1 = no hay
var _estocada_dir := Vector3.ZERO
var _estocada_pegados: Array = []
var _invulnerable := 0.0
var _curando := 0.0
var golpes := 0           # para medir el balance (MonitorDefensa)
var golpes_pegaron := 0
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
var _patada := 0.0            # grados de patada que la camara aun debe regresar
var _patada_vel := 0.0
var _sangre_arma: MeshInstance3D
var _sangre_hasta := 0        # ms de reloj real
var _congelado_hasta := 0
var _escala_antes := 1.0
var _camara: Camera3D
var _voz: AudioStreamPlayer3D
var _mano: BoneAttachment3D
var _estela: Node            # EstelaBarrido.gd
var _punta: Node3D           # la punta de lo que traes en la mano, para la estela
var _estela_antes := []      # [mano, de la mano a la punta] del cuadro anterior
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
	_armar_estela()
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
		personaje.vestir(figura)
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
	# Encadenado, el clip nuevo sale de donde va el brazo (character_animation.gd)
	if figura.has_method("golpe"):
		figura.golpe(_lado_golpe)
	_estela_antes = []
	_sonar("machetazo", SWING_VOLUMEN)


func _golpear(giro := false) -> void:
	var dano := DANO_PUNO
	var con_arma := false
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		var arma: InventoryItemData = inventario.arma()
		if arma:
			dano = arma.dano
			con_arma = true
	dano = maxi(roundi(dano * _factor_dano * (GIRO_DANO if giro else 1.0)), 1)
	var frente := -frijol.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var barre := -frijol.global_basis.x * _lado_golpe + frente * BARRE_AL_FRENTE
	barre.y = 0.0
	if not giro:
		efecto("golpe", barre, "" if con_arma else "puno", BARRE_ALTO)
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	# Un zombi muerto en este golpe truena justo al soltar la congelada
	var truena_en := int(CONGELA_MATA * 1000.0)
	var pego := false
	var mato := false
	var alcanzados: Array[Node3D] = []
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		if zombi is Zombie and zombi.estado == Zombie.Estado.MUERTO:
			continue
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if giro:
			if hacia.length() <= _alcance * GIRO_ALCANCE:
				alcanzados.append(zombi)
		elif hacia.length() <= _alcance and hacia.normalized().dot(frente) >= ATAQUE_ANGULO:
			alcanzados.append(zombi)
	# Solo a los ATAQUE_MAXIMO mas cercanos: amontonados, un combo mataba hasta 5
	alcanzados.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	for zombi in alcanzados.slice(0, GIRO_MAXIMO if giro else ATAQUE_MAXIMO):
		var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, truena_en)
		pego = pego or resultado != 0
		mato = mato or resultado == 2
	golpes += 1
	if pego:
		golpes_pegaron += 1
		_sentir_golpe(frente, fuerza, mato)
		_sangre_hasta = Time.get_ticks_msec() + SANGRE_DURA_MS


# Ataque cargado: cada cuadro de fisica mientras cargas o giras
func _revisar_carga(delta: float) -> void:
	if _apretado >= 0.0:
		if _pistola.activa or not is_physics_processing():
			_cancelar_carga()
		elif not Input.is_action_pressed("attack"):
			var girar := _cargado
			_cancelar_carga()
			if girar:
				_girar()
		else:
			_apretado += delta
			if not _cargado and _apretado >= CARGA_DURA:
				_cargado = true
				Sonidos.tocar(self, "machetazo", SWING_VOLUMEN - 4.0, 1.6)
			_brillo_carga()
	if _giro >= 0.0:
		_giro += delta * _giro_vel
		# El de aire pega al tocar el piso, y ahi se suelta lo que falte del clip
		if _giro_aire and (is_on_floor() or _giro >= GIRO_DURA * 2.0):
			_giro_aire = false
			if not _giro_pego:
				_giro_pego = true
				_golpear(true)
			if _giro < GIRO_DURA:
				_giro = GIRO_DURA
		if not _giro_pego and _giro >= GIRO_PEGA_EN and not _giro_aire:
			_giro_pego = true
			_golpear(true)
		if _giro >= GIRO_DURA and not _giro_aire:
			_giro = -1.0
			if _estela:
				_estela.especial = -1
			_soltar_combo()


func _cancelar_carga() -> void:
	_apretado = -1.0
	_cargado = false
	if _luz_carga:
		_luz_carga.visible = false


# Una luz azul en la punta del arma: crece mientras cargas y late ya cargado
func _brillo_carga() -> void:
	if _luz_carga == null:
		_luz_carga = OmniLight3D.new()
		_luz_carga.light_color = CARGA_COLOR
		_luz_carga.omni_range = 2.5
		_luz_carga.shadow_enabled = false
		_luz_carga.top_level = true
		add_child(_luz_carga)
	var punta: Vector3 = _punta.global_position if _punta and is_instance_valid(_punta) and _punta.is_inside_tree() \
		else frijol.global_position + Vector3.UP
	_luz_carga.global_position = punta
	_luz_carga.visible = true
	if _cargado:
		_luz_carga.light_energy = CARGA_LUZ * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.025))
	else:
		_luz_carga.light_energy = CARGA_LUZ * 0.4 * _apretado / CARGA_DURA


func _girar(aire := false) -> void:
	if not figura.has_method("golpe_giro"):
		return
	var velocidad := GIRO_AIRE_VELOCIDAD if aire else 1.0
	_giro_aire = aire
	_giro = GIRO_AIRE_DESDE if aire else 0.0
	_giro_vel = velocidad
	_giro_pego = false
	_pega_en = -1.0
	_golpe_guardado = false
	_combo_roto = true
	_combo_hasta = 0.0
	_enfriar = (GIRO_DURA - _giro) / velocidad
	figura.golpe_giro(velocidad, _giro)
	_estela_antes = []
	if _estela:
		_estela.especial = 1 if giro_agua else 0
	Sonidos.tocar(self, "machetazo", SWING_VOLUMEN, 0.8)


func _estocar() -> void:
	if not figura.has_method("golpe_estocada"):
		return
	_estocada_t = 0.0
	_estocada_pegados.clear()
	_pega_en = -1.0
	_golpe_guardado = false
	_combo_roto = true
	_combo_hasta = 0.0
	_enfriar = ESTOCADA_DURA
	_estocada_dir = -camera_pivot.global_transform.basis.z
	_estocada_dir.y = 0.0
	_estocada_dir = _estocada_dir.normalized()
	frijol.global_transform = frijol.global_transform.looking_at(frijol.global_position + _estocada_dir, Vector3.UP)
	figura.golpe_estocada()
	_estela_antes = []
	if _estela:
		_estela.especial = 1 if estocada_agua else 0
	Sonidos.tocar(self, "machetazo", SWING_VOLUMEN, 0.7)


# Cada cuadro de fisica de la estocada: la punta pega a los que tengas enfrente, una vez a cada uno
func _revisar_estocada(delta: float) -> void:
	if _estocada_t < 0.0:
		return
	_estocada_t += delta
	if _estocada_t >= ESTOCADA_PEGA.x and _estocada_t <= ESTOCADA_PEGA.y \
			and _estocada_pegados.size() < ESTOCADA_MAXIMO:
		_pegar_estocada()
	if _estocada_t >= ESTOCADA_DURA:
		_estocada_t = -1.0
		if _estela:
			_estela.especial = -1
		_soltar_combo()


func _pegar_estocada() -> void:
	var dano := DANO_PUNO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.arma():
		dano = inventario.arma().dano
	dano = maxi(roundi(dano * _factor_dano * ESTOCADA_DANO), 1)
	var fuerza := clampf(float(dano) / DANO_MACHETE, FUERZA_MIN, FUERZA_MAX)
	var pego := false
	var mato := false
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		if _estocada_pegados.size() >= ESTOCADA_MAXIMO:
			break
		if zombi in _estocada_pegados or (zombi is Zombie and zombi.estado == Zombie.Estado.MUERTO):
			continue
		var hacia := zombi.global_position - global_position
		hacia.y = 0.0
		if hacia.length() <= ESTOCADA_RADIO and hacia.normalized().dot(_estocada_dir) >= 0.3:
			_estocada_pegados.append(zombi)
			var resultado: int = zombi.recibir_golpe(dano, global_position, fuerza, int(CONGELA_MATA * 1000.0))
			pego = pego or resultado != 0
			mato = mato or resultado == 2
	if pego:
		golpes_pegaron += 1
		_sentir_golpe(_estocada_dir, fuerza, mato)
		_sangre_hasta = Time.get_ticks_msec() + SANGRE_DURA_MS


# Lo que avanza la estocada en este cuadro, como el hueso Root del clip: arranca de golpe y frena
func _velocidad_estocada(delta: float) -> Vector3:
	var antes := ESTOCADA_AVANCE * smoothstep(ESTOCADA_DESDE, ESTOCADA_HASTA, _estocada_t - delta)
	var ahora := ESTOCADA_AVANCE * smoothstep(ESTOCADA_DESDE, ESTOCADA_HASTA, _estocada_t)
	return _estocada_dir * ((ahora - antes) / maxf(delta, 0.0001))


# Una vez por golpe, aunque le pegue a varios: el whack, el rebote, la sacudida y la congelada
func _sentir_golpe(frente: Vector3, fuerza: float, mato: bool) -> void:
	_voz.pitch_scale = randf_range(0.9, 1.12)
	_sonar("whack", WHACK_VOLUMEN)
	_retroceso = -frente * RETROCESO * fuerza
	_retroceso_freno = RETROCESO * RETROCESO_CAIDA
	_sacude_fuerza = SACUDE * fuerza * (SACUDE_MATA if mato else 1.0)
	_sacude_hasta = Time.get_ticks_msec() + int(SACUDE_DURA * 1000.0)
	_congelar(CONGELA_MATA if mato else CONGELA)


# El juego casi se detiene unos cuadros. Un SceneTreeTimer no servia para soltarlo: con la
# escala de tiempo tan baja se quedaba en camara lenta varios segundos
# Al soltar regresa a la escala que habia (una noche acelerada para probar), no a 1
func _congelar(segundos: float) -> void:
	if _congelado_hasta == 0:
		_escala_antes = Engine.time_scale
	_congelado_hasta = maxi(_congelado_hasta, Time.get_ticks_msec() + int(segundos * 1000.0))
	Engine.time_scale = CONGELA_ESCALA * _escala_antes


func _revisar_congelada() -> void:
	var ahora := Time.get_ticks_msec()
	if _congelado_hasta > 0 and ahora >= _congelado_hasta:
		_congelado_hasta = 0
		Engine.time_scale = _escala_antes
	if _flash_hasta > 0 and ahora >= _flash_hasta:
		_flash_hasta = 0
		_pintar_blanco(false)


func _exit_tree() -> void:
	if _congelado_hasta > 0:
		_congelado_hasta = 0
		Engine.time_scale = _escala_antes


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
	if figura.has_method("accion"):
		figura.accion("RecieveHit")
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
	figura.set("cargando", true)


func soltar_carga() -> void:
	if _carga:
		_carga.queue_free()
		_carga = null
	figura.set("cargando", false)


# La tecla de curarse: lo que mejor llene la vida que falta (Inventory.mejor_curacion)
func _curarse() -> void:
	if _curando > 0.0:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var salud := get_node_or_null("/root/Salud")
	if inventario == null or salud == null:
		return
	var cual: int = inventario.mejor_curacion(salud.vida_max - salud.vida)
	if salud.llena() or cual < 0:
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	inventario.usar_curacion(cual)
	Sonidos.tocar(self, "inv_usar", -4.0)
	efecto("curar", Vector3.ZERO)
	_soltar_combo()
	_curando = CURAR_DURA


# Se queda quieto y deja de contestar (al desmayarse, Supervivencia.gd)
func detener() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)


func reanudar() -> void:
	set_physics_process(true)
	set_process_unhandled_input(true)
	if figura.has_method("terminar_accion"):
		figura.terminar_accion()


func caer() -> void:
	if figura.has_method("accion"):
		figura.accion("Defeat")


# La mano derecha del modelo; el arma se ve en ella
func _armar_mano() -> void:
	var esqueleto := _esqueleto()
	if esqueleto == null:
		return
	for nombre in ["RightHand", "Fist.R", "Hand.R", "Wrist.R", "LowerArm.R"]:
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
	if figura.has_method("soltar_golpe"):
		figura.soltar_golpe()


# El esqueleto del modelo: con el retarget se llama GeneralSkeleton, no Skeleton3D
func _esqueleto() -> Skeleton3D:
	var esqueletos := figura.find_children("*", "Skeleton3D", true, false)
	return esqueletos[0] as Skeleton3D if not esqueletos.is_empty() else null


func _armar_estela() -> void:
	_estela = ESTELA.new()
	_estela.name = "Estela"
	add_child(_estela)


# La estela sigue la punta del arma mientras el machetazo barre (character_animation.gd dice
# cuanto lleva). Entre un cuadro y otro se rellena el arco en pedazos de ESTELA_PASO grados
func _estela_golpe() -> void:
	if _estela == null or _mano == null or not figura.has_method("tiempo_golpe"):
		return
	var t: float = figura.tiempo_golpe()
	var ventana: Vector2 = ESTELA_GOLPE.get(figura.clip_golpe(), Vector2.ZERO)
	if t < 0.0 or t < ventana.x or t > ventana.y:
		_estela_antes = []
		return
	var mano := _mano.global_position
	var punta: Vector3 = _punta.global_position if _punta and is_instance_valid(_punta) and _punta.is_inside_tree() \
		else mano + _mano.global_basis.y.normalized() * ESTELA_PUNO
	var hacia := punta - mano
	if _estela_antes.is_empty():
		_estela_antes = [mano, hacia]
		return
	var mano_antes: Vector3 = _estela_antes[0]
	var hacia_antes: Vector3 = _estela_antes[1]
	var pasos := maxi(ceili(rad_to_deg(hacia_antes.angle_to(hacia)) / ESTELA_PASO), 1)
	for i in range(1, pasos + 1):
		var f := float(i) / pasos
		var donde := mano_antes.lerp(mano, f)
		_estela.agregar(donde, donde + hacia_antes.slerp(hacia, f))
	_estela_antes = [mano, hacia]


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
	_punta = null
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
			# El mango queda en el puno y la hoja hacia -X
			_punta = Marker3D.new()
			_punta.position = Vector3(-(ARMA_TAMANO * 0.5 + ARMA_MANGO), 0.0, 0.0)
			modelo.add_child(_punta)
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
	elif event.is_action_pressed("recargar") and is_physics_processing():
		if _pistola.activa:
			_pistola.recargar()
	elif _tecla_arma(event) >= 0 and is_physics_processing():
		cambiar_arma(_tecla_arma(event))
	elif event.is_action_pressed("curarse") and is_physics_processing():
		_curarse()
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _curando > 0.0:
			pass
		elif _pistola.activa:
			_pistola.disparar()
		elif _giro >= 0.0 or _estocada_t >= 0.0:
			pass
		elif golpe_cargado and not is_on_floor():
			# En el aire sale de una vez el espadazo giratorio, sin cargar
			_girar(true)
		elif estocada and Input.is_action_pressed("sprint") \
				and Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length() > 0.2:
			_estocar()
		else:
			_atacar()
			if golpe_cargado:
				_apretado = 0.0
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
	_regresar_patada(_delta)
	_gotear_sangre()
	_estela_golpe()


# Los brazos con la pistola (clips Pistol_* de Quaternius, character_animation.gd): sosteniendola,
# o apuntando a la mira al apuntar o recien disparado desde la cadera, a la altura de la mira
func _posar() -> void:
	if not figura.has_method("pistola"):
		return
	var centro := get_viewport().get_visible_rect().size / 2.0
	var blanco := _camara.project_ray_origin(centro) + _camara.project_ray_normal(centro) * MIRA_LEJOS
	var hacia := blanco - (frijol.global_position + Vector3.UP * PECHO)
	var inclinacion := rad_to_deg(atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))
	figura.pistola(_pistola.activa and is_physics_processing(),
		_apuntando or Time.get_ticks_msec() < _tiro_hasta, inclinacion)


# Pistola.gd en cada tiro: sube el arma a la mira un rato y la patea
func pose_tiro() -> void:
	_tiro_hasta = Time.get_ticks_msec() + int(ARRIBA_TRAS_TIRO * 1000.0)
	if figura.has_method("tiro"):
		figura.tiro()


# Pistola.gd al empezar a recargar
func pose_recarga() -> void:
	if figura.has_method("recarga"):
		figura.recarga()


# De donde sale el tiro: la boca de la pistola, o la mano
# Retroceso de la pistola: la camara sube `grados` (la mira apunta de veras mas arriba) y
# regresa sola en PATADA_VUELVE; solo regresa lo que subio, sin pelearse con el raton
func patear_mira(grados: float) -> void:
	camera_pitch = clampf(camera_pitch + grados, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch
	_patada += grados
	_patada_vel = _patada / PATADA_VUELVE


func _regresar_patada(delta: float) -> void:
	if _patada <= 0.0:
		return
	var vuelve := minf(_patada, _patada_vel * delta)
	_patada -= vuelve
	camera_pitch = clampf(camera_pitch - vuelve, -60.0, 30.0)
	spring_arm.rotation_degrees.x = camera_pitch


# Tras pegarle a un zombi, la punta del arma gotea sangre un rato (con la pistola, nada)
func _gotear_sangre() -> void:
	var gotea: bool = Time.get_ticks_msec() < _sangre_hasta and not (_pistola and _pistola.activa) and _mano != null
	if not gotea:
		if _sangre_arma:
			_sangre_arma.visible = false
		return
	if _sangre_arma == null:
		_sangre_arma = EfectosPixel.cuadro_bucle("sangre_arma", SANGRE_ESCALA)
		if _sangre_arma == null:
			return
		_sangre_arma.top_level = true
		add_child(_sangre_arma)
	var punta: Vector3 = _punta.global_position if _punta and is_instance_valid(_punta) and _punta.is_inside_tree() 		else _mano.global_position + _mano.global_basis.y.normalized() * ESTELA_PUNO
	_sangre_arma.global_position = punta
	_sangre_arma.visible = true


# 1-5 (arma_1..arma_5) sin Shift: en el safehouse Shift+1/2/3 son de las maquinitas
func _tecla_arma(event: InputEvent) -> int:
	for i in ARMAS_TECLAS:
		if event.is_action_pressed("arma_%d" % (i + 1), false, true):
			return i
	return -1


# 0 = el arma de golpe (machete o puño), 1 = la pistola; 2-4 aun no hay nada
func cambiar_arma(indice: int) -> void:
	if indice > 1 or (indice == 1) == _pistola.activa:
		return
	_pistola.cambiar()
	_soltar_combo()
	_mostrar_arma()


# Cada tiro te recorre tantito para atras de a donde apuntas
func empujar_tiro(hacia: Vector3) -> void:
	hacia.y = 0.0
	if RETROCESO_TIRO <= 0.0 or hacia.length_squared() < 0.0001:
		return
	_retroceso = -hacia.normalized() * RETROCESO_TIRO
	_retroceso_freno = RETROCESO_TIRO * RETROCESO_TIRO_FRENO


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
	_revisar_carga(delta)
	_revisar_estocada(delta)
	if _golpe_guardado and ATAQUE_ENFRIAR - _enfriar >= COMBO_DESDE:
		_atacar()
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_curando = maxf(_curando - delta, 0.0)
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
	var lento := ATAQUE_LENTO_A_TIEMPO if pelea_a_tiempo else ATAQUE_LENTO
	var golpeando := _enfriar > 0.0 and ATAQUE_ENFRIAR - _enfriar < lento
	# Girando en el aire sigues tu salto (y lo puedes dirigir); en el suelo te quedas en tu lugar
	if _curando > 0.0 or (_giro >= 0.0 and is_on_floor()) or _estocada_t >= 0.0:
		input_direction = Vector2.ZERO

	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var right: Vector3 = camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = right * input_direction.x + forward * -input_direction.y

	var is_moving: bool = direction.length_squared() > 0.01
	var is_sprinting: bool = is_moving and Input.is_action_pressed("sprint") and not golpeando
	var move_speed: float = sprint_speed if is_sprinting else speed
	if _apuntando:
		move_speed = speed * APUNTA_VELOCIDAD
	elif golpeando:
		move_speed = speed * GOLPE_VELOCIDAD
	# Caminando, el barrido va solo arriba: las piernas siguen trotando
	if figura.has_method("golpe_caminando"):
		figura.golpe_caminando(is_moving and golpeando)
	var target_horizontal := Vector3.ZERO
	# Con la pistola, o a medio machetazo, ve siempre hacia donde apunta la camara, aunque camine
	# para otro lado: el golpe sale hacia donde ves
	var apunta: bool = (_pistola.activa or golpeando) and _estocada_t < 0.0
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
	if _estocada_t >= 0.0:
		var avance := _velocidad_estocada(delta)
		velocity.x = avance.x
		velocity.z = avance.z

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

	if figura.has_method("update_animation"):
		figura.update_animation(is_moving, not is_on_floor(), is_sprinting, Vector2(velocity.x, velocity.z).length())


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
