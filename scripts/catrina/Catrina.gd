class_name Catrina
extends CharacterBody3D
# La Mojiganga (propuesta de AG; docs/lore.md, la catrina de desfile): la catrina gigante de
# carton que iba a salir en el desfile de Dia de Muertos de la colonia. La dejaron parada cuando
# empezo todo; el agua de Serenol empapo el papel mache y los zombis que se metieron adentro se
# quedaron pegados al armazon de carrizo. Un nudo de ellos la camina como titere. ~6 m.
#
# Tres fases (una barra de VIDA con marcas en FASE_2 y FASE_3):
#   1. Vestido entero: pisoton (cerca), agarron y aventon (media), latigo de trenza (lejos, te
#      jala al agarron). Entre ataques posa con la mano en la cadera: ahi duele mas. Las cuatro
#      flores del peinado se revientan a balazos y la tumban de rodillas (cabeza al alcance).
#   2. Se le rompe el vestido y se ve el carrizo: mas rapida, barrida de falda, aretes que
#      ruedan como bolas y un grito de agua sucia que suelta 2-3 zombis de la falda.
#   3. Se le cae la cabeza (queda de estorbo) y se arrastra en cuatro patas: solo le duele el nudo
#      del pecho. Manotazo, embestida y el ultimo agarron.
# Fuego (molotov, ZonaLombrices FUEGO): esta empapada. En la fase 1 el fuego solo la seca (vapor);
# desde la 2, una parte seca que toca el fuego arde, y cada parte quemada la deja recibiendo mas.
#
# Del agarron te zafas machacando golpe o brinco (forcejear, como el Saltabardas); rodar esquiva
# la mano y cubrirte no lo para. Esta en "zombis" (machete) y la pistola la acepta por clase;
# PuntoDebil.gd son las flores y el nudo. `estado` 3 es MUERTA, como en Zombie.

signal cambio(vida: int, maxima: int)
signal fase_cambio(fase: int)
signal desperto
signal murio
signal frenesi

enum Estado { DORMIDA, CAMINA, POSE, MUERTA, PISA, AGARRA, AGARRADA, LANZA, ZAFADA, TRENZA, CARGA,
	BARRIDA, ARETES, GRITO, ARRODILLADA, TRANSICION, MANOTAZO, EMBESTIDA }
enum Parte { FALDA, BLUSA, CABEZA }

const PROVISIONAL := preload("res://scripts/catrina/CatrinaProvisional.gd")
const PUNTO := preload("res://scripts/catrina/PuntoDebil.gd")
const POMPON := preload("res://scripts/catrina/PomponRodante.gd")
const RUTA_MODELO := "res://models/personajes/catrina/catrina.glb"
const RUTA_CRANEO := "res://models/personajes/catrina/craneo_caido.glb"
const BUCLES := ["Idle_Pose", "Walk", "Kneel_Idle", "Crawl", "Grab_Hold"]
const MARCAS := ["Mano_R", "Mano_L", "Pie_R", "Cabeza", "Trenza_Punta", "Arete_L", "Arete_R",
	"Flor_0", "Flor_1", "Flor_2", "Flor_3", "Pecho_Nudo",
	"Vela_0", "Vela_1", "Vela_2", "Vela_3", "Vela_4", "Vela_5", "Vela_6", "Vela_7"]
# Adornos de pixelfx (AG, 2026-11-10): flamas en las velas de la corona que cambian de color por
# fase, petalos que suelta al caminar, gotas de Serenol, miasma, moscas. Hojas en tools/pixelfx
const CORONA := {"naranja": ["catrina_vela", Color(1.0, 0.6, 0.25)], "serenol": ["catrina_vela_serenol", Color(0.2, 1.0, 0.85)],
	"rojo": ["catrina_vela_rojo", Color(1.0, 0.15, 0.1)]}
const VELA_ESCALA := 0.9
const CORONA_LUZ := 1.4        # energia de la luz de la corona (parpadea)
const PETALOS_ESCALA := 0.45
const PETALOS_FUNDE := 0.7     # por segundo: al caerse la cabeza dejan de caer poco a poco
const GOTAS_ESCALA := 0.3
const MIASMA_ESCALA := 0.3
const MOSCAS_ESCALA := 0.16

# Numeros del 2026-11-10 (AG: "muy facil"; meta Dark Souls: 3-5 intentos, 4-6 min, un error
# cuesta un tercio de la vida). Antes: 900 / 600 / 300
const VIDA := 1000
const FASE_2 := 670            # vida donde empieza cada fase (no se la salta: se detiene ahi)
const FASE_3 := 340
const FRENESI := 150           # fase 3, abajo de esto: a gatas mas rapido y sin pausas
const CAPA_ZOMBIS := 2
const GRAVEDAD := 30.0
const PIES := 1.0              # m del origen del jugador a sus pies (media capsula)
const CAMINA := 2.0            # m/s
const CAMINA_FASE_2 := 1.15    # x en la fase 2 (todo va asi de rapido)
const GATEA := 1.8             # m/s en la fase 3
const GIRA := 2.2              # rad/s al voltear caminando
const GIRA_AVISO := 1.0        # rad/s mientras avisa un ataque (te sigue tantito)
const PARA_A := 2.8            # m: mas cerca deja de caminar
const DECIDE_CADA := 0.15
const DESPIERTA_A := 14.0      # m: dormida (estatua) hasta que te acercas
const RADIO_GOLPE := 1.3       # m que se le restan al alcance del machete (Player._radio_de)
const POSE_CADA := Vector2i(4, 5)   # ataques entre pose y pose
const POSE_DURA := 1.2
const ABIERTA_MULT := 1.25      # posando o recien zafado: recibe esto
const RODILLAS_MULT := 1.5     # de rodillas, el machete le da en la cabeza
const QUEMADA_MULT := 1.15     # por cada parte quemada (se acumula)
const NUDO_MULT := 1.5         # fase 3: el nudo al descubierto
const AGUANTE := 200.0         # dano seguido que la tumba de rodillas
const AGUANTE_BAJA := 20.0     # por segundo
const ARRODILLADA_DURA := 2.2
const TRANSICION_DURA := 2.5
# Pisoton
const PISA_DESDE := 3.5
const PISA_AVISA := 0.8
const PISA_DURA := 1.8       # el pie se queda plantado: la ventana del machete
const PISA_RADIO := 2.5
const DANO_PISA := 26
const ONDA_RADIO := 6.0
const ONDA_DURA := 0.5
const ONDA_ANCHO := 0.45
const DANO_ONDA := 8
const ONDA_BRINCO := 0.4       # m: con los pies mas arriba, la onda pasa por debajo
# Agarron
const AGARRA_DE := Vector2(2.5, 9.0)
const AGARRA_AVISA := 1.0
const AGARRA_CIERRA := 1.4     # hasta aqui la mano todavia te puede agarrar
const AGARRA_PASO_BARRE := 4.0 # m/s del lance mientras barre: rodar (4.5 m/s) si te saca
const AGARRA_DURA := 2.5       # fallo: tarda en enderezarse
const AGARRA_MANO := 2.0       # m de la mano de verdad (el hueso Mano_R) a tu pecho
const AGARRA_PASO := 9.0       # m/s como mucho del paso que da al frente (0.6 s hasta que cierra)
const AGARRA_LLEGA := 2.6      # m: el paso busca dejarte a esta distancia (lo que alcanza la mano)
const AGARRA_PASO_DESDE := 0.6
const GIRA_AGARRE := 2.5       # rad/s: te sigue mientras avisa
const COMBO_AGARRE := 0.5      # tras un pisoton que te pega de cerca, chance de agarrarte luego
const SOSTIENE := 2.5
const APRIETA_CADA := 0.5
const DANO_APRIETA := 6
const ZAFARSE := 6.0           # apretones (bajan FORCEJEO_BAJA por segundo)
const FORCEJEO_BAJA := 1.5
const DANO_ZAFA := 5
const ZAFADA_DURA := 1.3
const LANZA_SUELTA := 0.3
const LANZA_DURA := 1.0
const LANZA_VEL := 16.0        # m/s frenando a LANZA_VEL m/s2: unos 8 m
const DANO_LANZA := 8
const DANO_CHOCA := 20         # si te avienta contra una pared o un carro
# Trenza
const TRENZA_DE := Vector2(7.0, 14.0)
const TRENZA_AVISA := 0.7
const TRENZA_PEGA := 0.95
const TRENZA_DURA := 1.15
const TRENZA_LARGO := 15.0
const TRENZA_ANCHO := 1.0
const DANO_TRENZA := 13
const TRENZA_DEJA := 3.5       # m de ella donde te deja el jalon (al alcance del agarron)
const TRENZA_FRENO := 20.0
# Fase 2
const BARRIDA_DESDE := 4.0
const BARRIDA_AVISA := 0.9
const BARRIDA_GIRA := 0.6
const BARRIDA_DURA := 1.6
const DANO_BARRIDA := 24
const ARETES_DE := Vector2(8.0, 16.0)
const ARETES_AVISA := 0.6
const ARETES_DURA := 0.95
const GRITO_AVISA := 0.8
const GRITO_DURA := 1.5
const GRITO_ALCANCE := 9.0
const GRITO_CONO := 0.5
const DANO_GRITO := 10
const AYUDANTES := Vector2i(3, 5)
const AYUDANTES_MAX := 8
const GOTEO_CADA := 10.0       # fase 2: un cazador mas desde los portales cada tanto (AG: "el jugador puede")
# Fase 3
const MANOTAZO_DESDE := 4.0
const MANOTAZO_AVISA := 0.8
const MANOTAZO_DURA := 1.15
const MANOTAZO_RADIO := 2.2
const DANO_MANOTAZO := 26
const EMBESTIDA_DE := Vector2(5.0, 12.0)
const EMBESTIDA_AVISA := 0.6
const EMBESTIDA_VA := 0.5
const EMBESTIDA_DURA := 1.3
const EMBESTIDA_LARGO := 6.0
const DANO_EMBESTIDA := 20
const CABEZA_DANO := 15        # si la cabeza que cae te agarra abajo
# Esperas entre ataques (s)
const ESPERAS := {"pisa": 1.8, "agarra": 5.5, "trenza": 5.0, "barrida": 3.5, "aretes": 6.0,
	"grito": 12.0, "manotazo": 1.8, "embestida": 4.5, "carga": 6.0}
# Amagos (Dark Souls): a veces se queda con el pie o la mano arriba de mas, para castigar al que
# rueda antes de tiempo
const RETRASO_PROB := 0.3
const RETRASO := Vector2(0.4, 0.7)
# De lejos: si te quedas a mas de LEJOS_DESDE m por LEJOS_TIEMPO s, va por ti (trenza, aretes o
# una carga que acaba en agarron); la bala de lejos le hace la mitad al carton
const LEJOS_DESDE := 12.0
const LEJOS_TIEMPO := 3.0
const CARGA_VEL := 6.0
const CARGA_DURA := 3.0
const CARGA_AGARRA := 3.0      # m: a esta distancia la carga se vuelve agarron
const BALA_LEJOS := 15.0
const BALA_LEJOS_MULT := 0.5
const FRENESI_RAPIDEZ := 1.5
# Flores y fuego
# Ventanas para el machete (AG: "solo a machetazos es imposible"): tras el pisoton el pie se queda
# plantado, tras el manotazo la mano; pegarle ahi duele PIE_MULT y la tumba antes. Agachada (de
# rodillas o tras fallar el agarron) las flores quedan al alcance del machete
const MACHETE_MULT := 1.25     # el machete al carton (a balazos le cuesta mas: el cuerpo es puro carton)
const PIE_ALCANCE := 3.2       # m del jugador al pie o la mano plantados
const PIE_MULT := 2.0
const PIE_AGUANTE := 2.0       # x lo que suma al aguante
# Atorada (contra el kiosco o una pared que no rompe): rodea
const ATASCO_TIEMPO := 1.2
const ATASCO_MIN := 0.35       # m que tiene que avanzar en ATASCO_TIEMPO
const RODEO_DURA := 1.4
const ROMPE_PISA := 4.5        # m: el pisoton rompe carros y ofrendas a esta distancia
const ROMPE_BARRIDA := 5.0
# Huesos que rebotan (SpringBoneSimulator3D): raiz, punta, rigidez, freno
const RESORTES := [["Trenza_0", "Trenza_5", 1.4, 0.5], ["Cola_0", "Cola_3", 2.5, 0.7]]
const RESORTE_PESO := 0.8
const FLORES := 4
const FLOR_VIDA := 70.0
const FLOR_DANO := 30          # a la barra al reventar una
const FUEGO_CADA := 0.25
const FUEGO_TOCA := 1.4        # m que se suman al radio del fuego
const SECA := {Parte.FALDA: 0.6, Parte.BLUSA: 0.35, Parte.CABEZA: 0.6}   # por segundo en el fuego (camina: sale pronto)
const SECA_ARDE := 0.2         # con esta humedad o menos arde (fase 2+)
const ARDE_DURA := 6.0
const DANO_ARDE := 4           # cada FUEGO_CADA: 16 por segundo por parte
const GOTEA_CADA := 0.5
const MUERTA_DURA := 2.5
const BOTINES := 3
const COLOR_FLOR := Color(0.95, 0.2, 0.5)
const COLOR_NUDO := Color(0.3, 0.4, 0.15)

var jugador: Player
var zombis: Node
var estado := Estado.DORMIDA
var fase := 1
var dormida := true            # el safehouse la saca despierta
var radio_golpe := RADIO_GOLPE
var es_jefe := true            # Player._dano_recibido
var cazador := false
var humedad := {Parte.FALDA: 1.0, Parte.BLUSA: 1.0, Parte.CABEZA: 1.0}
var cuenta := {}               # lo que paso, para -- --medir

var _vida := VIDA
var _siguiente := ""           # el ataque que sigue sin volver a caminar (combo)
var _retraso := 0.0            # s de amago en el ataque que va
var _recupera := false         # ya paso lo peligroso del ataque: las flores quedan al descubierto
var _lejos_t := 0.0            # s que llevas lejos (LEJOS_DESDE)
var _frenesi := false
var _mano_antes := Vector3.ZERO
var _mano_min := INF
var _ultimo_piso := Vector3.ZERO
var _mascara_jugador := -1     # la capa de choque del jugador mientras lo tiene colgado
var _t := 0.0
var _decide := 0.0
var _modelo: Node3D
var _anim: AnimationPlayer
var _provisional: Node3D
var _clip := ""
var _marcas := {}
var _flores := PackedFloat32Array()
var _puntos: Array = []        # PuntoDebil de las flores
var _nudo: PuntoDebil
var _forma_cuerpo: CollisionShape3D
var _forma_cabeza: CollisionShape3D
var _esperas := {}
var _ataques := 0
var _pose_cada := 2
var _pego := false
var _soltada := false
var _forcejeo := 0.0
var _aprieta := 0.0
var _aguante := 0.0
var _tras_trenza := false
var _trenza_hacia := Vector3.ZERO
var _rumbo := Vector3.FORWARD
var _onda: MeshInstance3D
var _onda_centro := Vector3.ZERO
var _onda_t := -1.0
var _onda_pego := false
var _choque_en := -1.0
var _giro := 0.0
var _fuego := 0.0
var _arde := {}                # Parte -> s que le quedan ardiendo
var _quemadas := 0
var _llamas := {}              # Parte -> MeshInstance3D del fuego
var _vapores := {}             # Parte -> CPUParticles3D
var _gotea := 0.0
var _ayudantes: Array = []
var _cabeza_caida: Node3D
var goteo_lugares: Array[Vector3] = []   # de donde salen los del goteo (PruebaCatrina: los portales)
var _goteo := GOTEO_CADA
var _atasco_t := 0.0
var _atasco_desde := Vector3.ZERO
var _rodeo := Vector3.ZERO
var _rodeo_t := 0.0
var _flamas: Array[MeshInstance3D] = []
var _luz_corona: OmniLight3D
var _petalos: MeshInstance3D
var _petalos_alfa := 1.0
var _gotas: Array[MeshInstance3D] = []
var _miasma: MeshInstance3D
var _moscas: MeshInstance3D


func _ready() -> void:
	add_to_group("zombis")
	add_to_group("catrina")
	collision_layer = CAPA_ZOMBIS
	collision_mask = 1 | CAPA_ZOMBIS
	# Despues del jugador: al tenerlo agarrado, la mano manda sobre su fisica
	process_physics_priority = 5
	_forma_cuerpo = CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 1.2
	capsula.height = 4.8
	_forma_cuerpo.shape = capsula
	_forma_cuerpo.position.y = 2.4
	add_child(_forma_cuerpo)
	_forma_cabeza = CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.75
	_forma_cabeza.shape = esfera
	_forma_cabeza.position.y = 5.45
	add_child(_forma_cabeza)
	_armar_modelo()
	_adornar()
	var mat_flor := StandardMaterial3D.new()
	mat_flor.albedo_color = COLOR_FLOR
	mat_flor.emission_enabled = true
	mat_flor.emission = COLOR_FLOR * 0.4
	_flores.resize(FLORES)
	for i in FLORES:
		_flores[i] = FLOR_VIDA
		var flor: PuntoDebil = PUNTO.new()
		flor.armar(self, "flor_%d" % i, 0.28, mat_flor)
		_marca("Flor_%d" % i).add_child(flor)
		_puntos.append(flor)
	var mat_nudo := StandardMaterial3D.new()
	mat_nudo.albedo_color = COLOR_NUDO
	mat_nudo.emission_enabled = true
	mat_nudo.emission = Color(0.2, 0.9, 0.7) * 0.5
	_nudo = PUNTO.new()
	_nudo.armar(self, "nudo", 0.6, mat_nudo)
	_marca("Pecho_Nudo").add_child(_nudo)
	_nudo.activo(false)
	# Sus propios puntos debiles (capa 2, la de los zombis, que ella choca) no la empujan: el nudo
	# del pecho, a gatas, la hundia en el piso hasta caer del mundo
	for punto: PuntoDebil in _puntos + [_nudo]:
		add_collision_exception_with(punto)
	# Con el modelo de Blender las flores y el nudo ya se ven en la malla: las esferas solo chocan
	if _provisional == null:
		for punto: PuntoDebil in _puntos + [_nudo]:
			punto.malla.visible = false
	for k: String in ESPERAS:
		_esperas[k] = 0.0
	_esperas["agarra"] = 2.0
	_pose_cada = randi_range(POSE_CADA.x, POSE_CADA.y)
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Player
	if zombis == null:
		zombis = get_tree().get_first_node_in_group("zombis_mando")
	if not dormida:
		_despertar()
	else:
		_animar("Idle_Pose")
		_pose({})
	cambio.emit(_vida, VIDA)


# El modelo de Blender si ya existe; si no, el de figuras. Las marcas son huesos del modelo
# (BoneAttachment3D con el nombre del hueso) o los Marker3D del provisional
func _armar_modelo() -> void:
	if ResourceLoader.exists(RUTA_MODELO):
		_modelo = load(RUTA_MODELO).instantiate()
		_modelo.rotation.y = PI
		add_child(_modelo)
		var animadores := _modelo.find_children("*", "AnimationPlayer")
		if not animadores.is_empty():
			_anim = animadores[0]
			for nombre in BUCLES:
				if _anim.has_animation(nombre):
					_anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
		# El vestido roto, el carrizo y el nudo empiezan escondidos
		for nombre in ["Vestido_Roto", "Carrizo", "Nudo"]:
			var malla := _modelo.find_child(nombre, true, false) as Node3D
			if malla:
				malla.visible = false
		var esqueletos := _modelo.find_children("*", "Skeleton3D")
		if not esqueletos.is_empty():
			var esqueleto := esqueletos[0] as Skeleton3D
			_resortes(esqueleto)
			for nombre: String in MARCAS:
				if esqueleto.find_bone(nombre) >= 0:
					var unido := BoneAttachment3D.new()
					unido.name = nombre
					unido.bone_name = nombre
					esqueleto.add_child(unido)
					_marcas[nombre] = unido
	else:
		_provisional = PROVISIONAL.new()
		_modelo = _provisional
		add_child(_modelo)


# --- Adornos de pixelfx ---

func _adornar() -> void:
	# Las flamas de la corona: en los huesos Vela_* del modelo de Blender (el provisional no tiene)
	for i in 8:
		var nombre := "Vela_%d" % i
		if not _marcas.has(nombre):
			continue
		var flama := EfectosPixel.cuadro_bucle(CORONA["naranja"][0], VELA_ESCALA)
		if flama:
			_marcas[nombre].add_child(flama)
			_flamas.append(flama)
	if not _flamas.is_empty():
		_luz_corona = OmniLight3D.new()
		_luz_corona.light_color = CORONA["naranja"][1]
		_luz_corona.omni_range = 7.0
		_luz_corona.light_energy = CORONA_LUZ
		_luz_corona.position = Vector3(0, 0.6, 0.4)
		_marca("Cabeza").add_child(_luz_corona)
	# Petalos de cempasuchil marchito que se le caen al caminar (la base de la hoja en el piso)
	_petalos = EfectosPixel.cuadro_bucle("catrina_petalos", PETALOS_ESCALA)
	if _petalos:
		# Su propio material: se desvanece sin tocar a nadie mas que use la hoja
		_petalos.material_override = _petalos.material_override.duplicate()
		add_child(_petalos)
	# Gotas de Serenol del ruedo mientras este mojada
	for a in [0.6, 2.4, 4.2]:
		var gota := EfectosPixel.cuadro_bucle("catrina_gotas", GOTAS_ESCALA)
		if gota:
			gota.position = Vector3(sin(a) * 1.7, 0.0, cos(a) * 1.7)
			add_child(gota)
			_gotas.append(gota)
	# Miasma al ras del piso (fase 2 en adelante) y moscas alrededor del pecho
	_miasma = EfectosPixel.cuadro_bucle("catrina_miasma", MIASMA_ESCALA)
	if _miasma:
		add_child(_miasma)
		_miasma.visible = false
	_moscas = EfectosPixel.cuadro_bucle("catrina_moscas", MOSCAS_ESCALA)
	if _moscas:
		_moscas.position = Vector3(0, 2.4, 0)
		add_child(_moscas)


func _seguir_adornos() -> void:
	if _petalos:
		# Caen siempre, en cualquier animacion, mientras le queden flores; si no, se desvanecen
		var meta := 1.0 if fase < 3 and flores_vivas() > 0 else 0.0
		_petalos_alfa = move_toward(_petalos_alfa, meta, PETALOS_FUNDE * get_physics_process_delta_time())
		(_petalos.material_override as ShaderMaterial).set_shader_parameter("alfa", _petalos_alfa if EfectosPixel.extras else 0.0)
		_petalos.visible = _petalos_alfa > 0.0
	var mojada: bool = humedad[Parte.FALDA] > SECA_ARDE
	for gota in _gotas:
		gota.visible = mojada
	if _miasma:
		_miasma.visible = fase >= 2
	if _moscas:
		_moscas.position.y = 1.2 if fase == 3 else 2.4
	if _luz_corona:
		var t := Time.get_ticks_msec() * 0.001
		_luz_corona.light_energy = CORONA_LUZ * (0.85 + 0.1 * sin(t * 11.0) + 0.05 * sin(t * 23.0))


# Cambia el color de las flamas de la corona: naranja, serenol (fase 2) o rojo (frenesi)
func _poner_corona(cual: String) -> void:
	var material := EfectosPixel.material_bucle(CORONA[cual][0])
	if material == null:
		return
	for flama in _flamas:
		if is_instance_valid(flama):
			flama.material_override = material
	if _luz_corona and is_instance_valid(_luz_corona):
		_luz_corona.light_color = CORONA[cual][1]


# Fase 3: la cabeza cae y la corona sigue ardiendo alrededor del craneo tirado
func _corona_al_craneo() -> void:
	if not is_instance_valid(_cabeza_caida):
		return
	for i in _flamas.size():
		var flama := _flamas[i]
		if not is_instance_valid(flama):
			continue
		flama.reparent(_cabeza_caida, false)
		var a := TAU * i / _flamas.size()
		flama.position = Vector3(cos(a) * 1.0, 0.45 + 0.3 * sin(a * 2.0), sin(a) * 1.0)
		flama.scale = Vector3.ONE * VELA_ESCALA * 0.8
	if _luz_corona and is_instance_valid(_luz_corona):
		_luz_corona.reparent(_cabeza_caida, false)
		_luz_corona.position = Vector3(0, 0.8, 0)


# La trenza y la cola de la falda rebotan solas encima del clip (los clips ya traen su onda; esto
# le pone el peso cuando ella gira o se frena de golpe)
func _resortes(esqueleto: Skeleton3D) -> void:
	var cadenas := []
	for r in RESORTES:
		if esqueleto.find_bone(r[0]) >= 0 and esqueleto.find_bone(r[1]) >= 0:
			cadenas.append(r)
	if cadenas.is_empty():
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Resortes"
	esqueleto.add_child(sim)
	sim.setting_count = cadenas.size()
	for i in cadenas.size():
		sim.set_root_bone_name(i, cadenas[i][0])
		sim.set_end_bone_name(i, cadenas[i][1])
		sim.set_stiffness(i, cadenas[i][2])
		sim.set_drag(i, cadenas[i][3])
		sim.set_gravity(i, 0.0)
		sim.set_radius(i, 0.05)
	sim.influence = RESORTE_PESO


# Las mallas del modelo de Blender que se prenden o apagan por fase (blender_catrina.md)
func _mostrar(nombre: String, si: bool) -> void:
	var malla := _modelo.find_child(nombre, true, false) as Node3D
	if malla:
		malla.visible = si


func _marca(nombre: String) -> Node3D:
	if not _marcas.has(nombre) or not is_instance_valid(_marcas[nombre]):
		var m := _modelo.find_child(nombre, true, false) as Node3D
		if m == null:
			# Un hueso que el modelo no trae: una marca fija mas o menos donde va
			m = Marker3D.new()
			m.name = nombre
			m.position = {"Cabeza": Vector3(0, 5.5, 0), "Pecho_Nudo": Vector3(0, 3.7, -0.5),
				"Mano_R": Vector3(1.0, 2.3, 0), "Pie_R": Vector3(0.45, 0.15, -0.4)}.get(nombre, Vector3(0, 5.8, -0.3))
			add_child(m)
		_marcas[nombre] = m
	return _marcas[nombre]


func vida() -> int:
	return _vida


func flores_vivas() -> int:
	var n := 0
	for v in _flores:
		if v > 0.0:
			n += 1
	return n


func quemadas() -> int:
	return _quemadas


func _contar(que: String) -> void:
	cuenta[que] = cuenta.get(que, 0) + 1


# --- Animacion ---

func _animar(nombre: String, velocidad := 1.0, reiniciar := false) -> void:
	if _anim == null or not _anim.has_animation(nombre):
		return
	if _clip != nombre or reiniciar:
		_anim.play(nombre, 0.15)
		_clip = nombre
		if reiniciar:
			_anim.seek(0.0, true)
	_anim.speed_scale = velocidad


# Solo el provisional: el modelo de Blender trae los clips
func _pose(valores: Dictionary) -> void:
	if _provisional:
		if fase == 3:
			valores["gatea"] = 1.0
		_provisional.pose(valores)


func _mirar(hacia: Vector3) -> void:
	hacia.y = 0.0
	if hacia.length_squared() > 0.0001:
		rotation.y = atan2(-hacia.x, -hacia.z)


func _girar(hacia: Vector3, rapidez: float, delta: float) -> void:
	hacia.y = 0.0
	if hacia.length_squared() > 0.0001:
		rotation.y = rotate_toward(rotation.y, atan2(-hacia.x, -hacia.z), rapidez * delta)


func _frente() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


func _al_jugador() -> Vector3:
	var d := jugador.global_position - global_position
	d.y = 0.0
	return d


func _pies_jugador() -> float:
	return jugador.global_position.y - PIES - global_position.y


func _rapidez() -> float:
	if _frenesi:
		return FRENESI_RAPIDEZ
	return CAMINA_FASE_2 if fase >= 2 else 1.0


# Donde mira el jugador colgado (Player los voltea a ver esto)
func cara() -> Vector3:
	return _marca("Cabeza").global_position


# Las flores solo se pueden reventar a balazos con la guardia abierta: posando, de rodillas,
# recien zafada o tras el golpe de un ataque (en el ataque las tapa con el brazo y el movimiento)
func expuesta() -> bool:
	return estado in [Estado.POSE, Estado.ARRODILLADA, Estado.ZAFADA] or _recupera


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_t = 0.0
	_pego = false
	_soltada = false
	_recupera = false


func _jugador_libre() -> bool:
	return jugador != null and jugador.can_process() and jugador.is_physics_processing()


# --- Cada cuadro ---

func _physics_process(delta: float) -> void:
	if jugador == null:
		return
	if estado == Estado.MUERTA:
		_t += delta
		if _provisional:
			_provisional.caida(minf(_t / MUERTA_DURA, 1.0))
		return
	if not _jugador_libre():
		return
	# Red de seguridad: si algo la saca del piso, vuelve a donde estaba parada
	if is_on_floor():
		_ultimo_piso = global_position
	elif global_position.y < _ultimo_piso.y - 8.0:
		global_position = _ultimo_piso
		velocity = Vector3.ZERO
		_contar("rescate")
	var dt := delta * (_rapidez() if estado != Estado.AGARRADA else 1.0)
	_t += dt
	for k: String in _esperas:
		_esperas[k] = maxf(_esperas[k] - delta, 0.0)
	_aguante = maxf(_aguante - AGUANTE_BAJA * delta, 0.0)
	_forcejeo = maxf(_forcejeo - FORCEJEO_BAJA * delta, 0.0)
	_seguir_onda(delta)
	_seguir_choque(delta)
	_quemar(delta)
	_gotear(delta)
	_seguir_goteo(delta)
	_seguir_adornos()
	match estado:
		Estado.DORMIDA: _dormir()
		Estado.CAMINA: _caminar(delta)
		Estado.POSE: _posar()
		Estado.PISA: _pisar(delta)
		Estado.AGARRA: _alcanzar(delta)
		Estado.AGARRADA: _sostener(delta)
		Estado.LANZA: _lanzar()
		Estado.ZAFADA: _esperar(ZAFADA_DURA)
		Estado.TRENZA: _trenzar(delta)
		Estado.BARRIDA: _barrer()
		Estado.ARETES: _aretes()
		Estado.GRITO: _gritar()
		Estado.ARRODILLADA: _esperar(ARRODILLADA_DURA)
		Estado.TRANSICION: _transicion()
		Estado.MANOTAZO: _manotazo()
		Estado.EMBESTIDA: _embestir(delta)
		Estado.CARGA: _cargar(delta)
	_caer(delta)


func _caer(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVEDAD * delta
	if estado != Estado.CAMINA and estado != Estado.EMBESTIDA and estado != Estado.CARGA and estado != Estado.AGARRA:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	move_and_slide()
	# Mide seis metros: un carro alegorico o una ofrenda no la detienen, los revienta
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.has_meta("rompible"):
			_romper(c.get_meta("rompible"))


func _romper(r: Node) -> void:
	if is_instance_valid(r) and r.has_method("romper") and not r.roto:
		r.romper(global_position)
		_contar("rompio")
		_sacudir(0.6)


func _romper_cerca(centro: Vector3, radio: float) -> void:
	for r in get_tree().get_nodes_in_group("rompible"):
		if not r.roto and r.distancia(centro) < radio:
			_romper(r)


func _lo_ve(punto: Vector3) -> bool:
	var excluir: Array[RID] = [get_rid(), jugador.get_rid()]
	var rayo := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, punto + Vector3.UP * 0.5, 1, excluir)
	return get_world_3d().direct_space_state.intersect_ray(rayo).is_empty()


func _sacudir(fuerza: float) -> void:
	if jugador and global_position.distance_to(jugador.global_position) < 25.0:
		jugador.set("_sacude_fuerza", fuerza)
		jugador.set("_sacude_hasta", Time.get_ticks_msec() + 300)


func _fx(lugar: String, donde: Vector3, hacia := Vector3.ZERO, escala := 1.0) -> void:
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar(lugar, donde, hacia, escala)


func _liquido() -> Node:
	return get_tree().get_first_node_in_group("liquido")


func _pegar(dano: int, desde: Vector3, empuja := 1.0) -> bool:
	if jugador.esquivando():
		return false
	jugador.recibir_dano(dano, desde, empuja, self)
	_nota("pelear")
	return true


# --- Dormida, caminar y decidir ---

func _dormir() -> void:
	if _al_jugador().length() < DESPIERTA_A:
		_despertar()


func _despertar() -> void:
	dormida = false
	_cambiar(Estado.CAMINA)
	Sonidos.tocar(self, "grito_catrina", 2.0, 0.8)
	_sacudir(0.4)
	_nota("ver")
	desperto.emit()


func _caminar(delta: float) -> void:
	var hacia := _al_jugador()
	var lejos := hacia.length()
	_lejos_t = _lejos_t + delta if lejos > LEJOS_DESDE else 0.0
	_decide -= delta
	if _decide <= 0.0:
		_decide = DECIDE_CADA
		if _decidir(lejos):
			return
	var para := PARA_A if fase < 3 else 2.5
	var vel := 0.0 if lejos < para else (GATEA if fase == 3 else CAMINA * _rapidez())
	_atorada(vel, hacia, delta)
	if _rodeo_t > 0.0:
		hacia = _rodeo
	_girar(hacia, GIRA * (2.0 if _rodeo_t > 0.0 else 1.0), delta)
	var frente := _frente()
	velocity.x = frente.x * vel
	velocity.z = frente.z * vel
	if fase == 3:
		_animar("Crawl" if vel > 0.0 else "Kneel_Idle")
	else:
		_animar("Walk" if vel > 0.0 else "Idle_Pose")
	# El provisional camina meciendose
	var meneo := sin(Time.get_ticks_msec() * 0.006) * 0.08 if vel > 0.0 else 0.0
	_pose({"inclinar": meneo, "brazo_r": -meneo * 2.0})


# Si camina y no avanza (algo que no rompe: el kiosco, una pared), rodea un rato de lado
func _atorada(vel: float, hacia: Vector3, delta: float) -> void:
	_rodeo_t = maxf(_rodeo_t - delta, 0.0)
	if vel <= 0.0:
		_atasco_t = 0.0
		_atasco_desde = global_position
		return
	_atasco_t += delta
	if _atasco_t < ATASCO_TIEMPO:
		return
	_atasco_t = 0.0
	if global_position.distance_to(_atasco_desde) < ATASCO_MIN and _rodeo_t <= 0.0:
		_contar("atorada")
		# Primero, si lo que estorba se rompe, lo rompe
		_romper_cerca(global_position + _frente() * 2.5, 3.0)
		var normal := Vector3.ZERO
		for i in get_slide_collision_count():
			normal += get_slide_collision(i).get_normal()
		normal.y = 0.0
		var lado := hacia.cross(Vector3.UP).normalized()
		if normal.length_squared() > 0.001 and lado.dot(normal) < 0.0:
			lado = -lado
		elif normal.length_squared() <= 0.001 and randf() < 0.5:
			lado = -lado
		_rodeo = (lado + normal.normalized() * 0.5).normalized()
		_rodeo_t = RODEO_DURA
	_atasco_desde = global_position


func _listo(cual: String) -> bool:
	return _esperas[cual] <= 0.0


func _empezar(nuevo: Estado, cual: String, clip: String) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_esperas[cual] = ESPERAS[cual] * (randf_range(0.8, 1.2) if cual == "grito" else 1.0)
	if _frenesi:
		_esperas[cual] = minf(_esperas[cual], 0.3)
	_retraso = randf_range(RETRASO.x, RETRASO.y) if cual in ["pisa", "manotazo"] and randf() < RETRASO_PROB else 0.0
	_lejos_t = 0.0
	_ataques += 1
	_contar(cual)
	_cambiar(nuevo)
	# En la fase 2 todo va CAMINA_FASE_2 mas rapido: el clip tambien
	_animar(clip, _rapidez(), true)


const ATAQUES := {
	"pisa": [Estado.PISA, "Stomp"], "agarra": [Estado.AGARRA, "Grab_Reach"], "trenza": [Estado.TRENZA, "Braid_Whip"],
	"barrida": [Estado.BARRIDA, "Skirt_Spin"], "aretes": [Estado.ARETES, "Earrings_Snap"], "grito": [Estado.GRITO, "Scream"],
	"manotazo": [Estado.MANOTAZO, "Crawl_Slam"], "embestida": [Estado.EMBESTIDA, "Crawl_Lunge"], "carga": [Estado.CARGA, "Walk"],
}


func _atacar(cual: String) -> void:
	if cual == "agarra":
		_tras_trenza = false
	_empezar(ATAQUES[cual][0], cual, ATAQUES[cual][1])
	if cual == "carga":
		_animar("Walk", CARGA_VEL / CAMINA, true)


func _decidir(lejos: float) -> bool:
	if jugador.atrapado():
		return false
	# De lejos (o con la pistola desde atras de un carro): va por ti
	if _lejos_t >= LEJOS_TIEMPO and fase < 3:
		var ve_lejos := _lo_ve(jugador.global_position)
		var opciones: Array[String] = []
		if lejos <= TRENZA_DE.y and ve_lejos:
			opciones.append("trenza")
		if lejos >= ARETES_DE.x and lejos <= ARETES_DE.y and ve_lejos:
			opciones.append("aretes")
		opciones.append("carga")
		_atacar(opciones.pick_random())
		_contar("de_lejos")
		return true
	if _ataques >= _pose_cada:
		_ataques = 0
		_pose_cada = randi_range(POSE_CADA.x, POSE_CADA.y)
		_cambiar(Estado.POSE)
		_animar("Idle_Pose", 1.0, true)
		_contar("pose")
		return true
	var ve := _lo_ve(jugador.global_position)
	if fase == 3:
		if lejos < MANOTAZO_DESDE and _listo("manotazo"):
			_empezar(Estado.MANOTAZO, "manotazo", "Crawl_Slam")
			return true
		if lejos >= AGARRA_DE.x - 0.5 and lejos <= AGARRA_DE.y - 1.0 and _listo("agarra"):
			_empezar(Estado.AGARRA, "agarra", "Grab_Reach")
			return true
		if lejos >= EMBESTIDA_DE.x and lejos <= EMBESTIDA_DE.y and ve and _listo("embestida"):
			_empezar(Estado.EMBESTIDA, "embestida", "Crawl_Lunge")
			return true
		return false
	if _tras_trenza and lejos <= AGARRA_DE.y + 1.0:
		_tras_trenza = false
		_esperas["agarra"] = 0.0
		_empezar(Estado.AGARRA, "agarra", "Grab_Reach")
		return true
	if lejos < BARRIDA_DESDE and fase >= 2 and _listo("barrida") and (randf() < 0.5 or not _listo("pisa")):
		_empezar(Estado.BARRIDA, "barrida", "Skirt_Spin")
		return true
	if lejos < PISA_DESDE and _listo("pisa"):
		_empezar(Estado.PISA, "pisa", "Stomp")
		return true
	if lejos >= AGARRA_DE.x and lejos <= AGARRA_DE.y and _listo("agarra"):
		_empezar(Estado.AGARRA, "agarra", "Grab_Reach")
		return true
	if fase >= 2 and _listo("grito") and _ayudantes_vivos() < AYUDANTES_MAX:
		_empezar(Estado.GRITO, "grito", "Scream")
		return true
	if fase >= 2 and lejos >= ARETES_DE.x and lejos <= ARETES_DE.y and ve and _listo("aretes"):
		_empezar(Estado.ARETES, "aretes", "Earrings_Snap")
		return true
	if lejos >= TRENZA_DE.x and lejos <= TRENZA_DE.y and ve and _listo("trenza"):
		_empezar(Estado.TRENZA, "trenza", "Braid_Whip")
		return true
	return false


func _volver() -> void:
	if _siguiente != "" and not jugador.atrapado():
		var cual := _siguiente
		_siguiente = ""
		_contar("combo")
		_atacar(cual)
		return
	_siguiente = ""
	_cambiar(Estado.CAMINA)


# Despues de un ataque, a veces sigue otro de inmediato (combos de Dark Souls)
func _combo_tras(cual: String, pego: bool) -> void:
	var lejos := _al_jugador().length()
	match cual:
		"pisa":
			if pego and lejos < 4.5 and randf() < COMBO_AGARRE:
				_siguiente = "agarra"
			elif lejos < PISA_DESDE + 1.5:
				_siguiente = "barrida" if fase >= 2 and randf() < 0.6 else ("pisa" if randf() < 0.5 else "")
		"agarra":
			if lejos < PISA_DESDE + 0.5:
				_siguiente = "pisa"
		"barrida":
			if lejos >= AGARRA_DE.x and lejos <= 6.0 and randf() < 0.5:
				_siguiente = "agarra"
		"manotazo":
			if lejos < MANOTAZO_DESDE + 1.0 and randf() < 0.5:
				_siguiente = "manotazo"
	if _frenesi and _siguiente == "" and lejos < 6.0:
		_siguiente = "manotazo" if fase == 3 and lejos < MANOTAZO_DESDE else ("agarra" if lejos >= AGARRA_DE.x else "")


func _esperar(dura: float) -> void:
	if estado == Estado.ARRODILLADA:
		_pose({"arrodillada": 1.0, "inclinar": 0.3 if fase < 3 else 0.4})
		_animar("Kneel_Idle")
	elif estado == Estado.ZAFADA:
		_pose({"brazo_r": 1.0 + sin(_t * 30.0) * 0.3, "inclinar": 0.2})
	if _t >= dura:
		if estado == Estado.ARRODILLADA and fase < 3:
			_animar("Rise", 1.0, true)
		_volver()


func _posar() -> void:
	# La mano en la cadera, como la de la foto: es la ventana para pegarle
	_pose({"brazo_r": -0.15})
	if _t >= POSE_DURA:
		_volver()


# --- Pisoton y su onda ---

func _pisar(delta: float) -> void:
	if _t < PISA_AVISA + _retraso:
		_girar(_al_jugador(), GIRA_AVISO, delta)
		_pose({"pie_r": 1.0, "inclinar": -0.1, "brazo_l": 0.3})
		# El amago: el pie se queda arriba (el clip se detiene en lo alto)
		_clip_quieto(_t > PISA_AVISA * 0.85 and _t < PISA_AVISA + _retraso - 0.05)
		return
	_clip_quieto(false)
	_pose({"inclinar": 0.12})
	if not _pego:
		_pego = true
		var pie := global_position + _frente() * 1.0 + global_basis.x * 0.45
		pie.y = global_position.y
		Sonidos.tocar(self, "pisoton", 2.0, 0.9)
		_sacudir(0.8)
		_fx("catrina_pisada", pie, Vector3.ZERO, 1.0)
		var al := jugador.global_position - pie
		al.y = 0.0
		var pego := al.length() < PISA_RADIO and _pies_jugador() < 1.0 and _pegar(DANO_PISA, pie, 2.0)
		if pego:
			_contar("pisa_pego")
		_soltar_onda(pie)
		_romper_cerca(pie, ROMPE_PISA)
		_recupera = true
		_combo_tras("pisa", pego)
	if _t >= PISA_DURA + _retraso:
		_volver()


# Detiene el clip del modelo de Blender (amagos); el provisional no tiene clips
func _clip_quieto(si: bool) -> void:
	if _anim:
		_anim.speed_scale = 0.0 if si else _rapidez()


func _soltar_onda(centro: Vector3) -> void:
	_onda_centro = centro
	_onda_t = 0.0
	_onda_pego = false
	if _onda == null:
		_onda = MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.92
		toro.outer_radius = 1.0
		toro.rings = 32
		toro.ring_segments = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.75, 0.45, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		toro.material = m
		_onda.mesh = toro
		_onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_onda.top_level = true
		add_child(_onda)
	_onda.visible = true


# Radio de la onda del pisoton ahorita (-1 = no hay): el bot brinca cuando le llega
func onda_radio() -> float:
	return ONDA_RADIO * _onda_t / ONDA_DURA if _onda_t >= 0.0 else -1.0


func onda_centro() -> Vector3:
	return _onda_centro


func _seguir_onda(delta: float) -> void:
	if _onda_t < 0.0:
		return
	_onda_t += delta
	var k := _onda_t / ONDA_DURA
	var r := maxf(ONDA_RADIO * k, 0.05)
	_onda.global_transform = Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), _onda_centro + Vector3.UP * 0.1)
	(_onda.mesh.material as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - k)
	if not _onda_pego:
		var al := jugador.global_position - _onda_centro
		al.y = 0.0
		# Adentro del pisoton se esquiva el pisoton (rodando); la onda es para el que esta a media distancia
		if al.length() > PISA_RADIO and absf(al.length() - r) < ONDA_ANCHO and _pies_jugador() < ONDA_BRINCO:
			_onda_pego = true
			if _pegar(DANO_ONDA, _onda_centro, 1.2):
				_contar("onda_pego")
	if k >= 1.0:
		_onda_t = -1.0
		_onda.visible = false


# --- Agarron, apreton y aventon ---

func _alcanzar(delta: float) -> void:
	var mano := _marca("Mano_R").global_position
	# Apunta la mano derecha, no el cuerpo: se corre lo que la mano va de lado
	var lado := mano - global_position
	lado -= _frente() * lado.dot(_frente())
	lado.y = 0.0
	var al := _al_jugador() - lado
	if _t < AGARRA_AVISA:
		_girar(al, GIRA_AGARRE, delta)
		# Se agacha de la cintura y echa la mano para atras; al final da un paso hacia ti
		_pose({"inclinar": 0.35, "brazo_r": -0.6})
		_paso_agarre(al)
		_mano_antes = mano
		return
	# Sigue el lance mientras barre: el que se aleja no se salva solo por caminar
	if _t <= AGARRA_CIERRA and not _pego:
		_girar(al, GIRA_AGARRE * 0.5, delta)
		_paso_agarre(al)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_pose({"inclinar": 0.9 if fase < 3 else 0.2, "brazo_r": 1.0})
	if _t <= AGARRA_CIERRA and not _pego:
		# La mano de verdad: te agarra si tu pecho queda cerca del camino que hizo este cuadro
		var pecho := jugador.global_position + Vector3.UP * 0.3
		_mano_min = minf(_mano_min, _dist_segmento(pecho, _mano_antes, mano))
		if _dist_segmento(pecho, _mano_antes, mano) < AGARRA_MANO and jugador.atrapar(self, true):
			_pego = true
			_agarrar()
			return
	_mano_antes = mano
	if _t > AGARRA_CIERRA and not _recupera:
		_recupera = true
		_contar("agarre_fallo")
		if OS.get_cmdline_user_args().has("--depurar"):
			print("agarre fallo: mano a %.2f m, jugador a %.2f m, rodando %s" % [_mano_min, al.length(), jugador.esquivando()])
		_mano_min = INF
		_combo_tras("agarra", false)
	if _t >= AGARRA_DURA:
		_volver()


# El paso del agarron: lo justo para que la mano llegue a donde estas al cerrar
func _paso_agarre(al: Vector3) -> void:
	var paso := 0.0
	if _t >= AGARRA_PASO_DESDE:
		var falta := al.length() - AGARRA_LLEGA
		var tope := AGARRA_PASO if _t < AGARRA_AVISA else AGARRA_PASO_BARRE
		paso = clampf(falta / maxf(AGARRA_CIERRA - _t, 0.15), 0.0, tope)
	velocity.x = _frente().x * paso
	velocity.z = _frente().z * paso


static func _dist_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _agarrar() -> void:
	# Que su propia fisica no lo saque de la mano mientras cuelga
	_mascara_jugador = jugador.collision_mask
	jugador.collision_mask = 0
	_forcejeo = 0.0
	_aprieta = APRIETA_CADA
	_contar("agarro")
	_fx("catrina_agarre", _donde_sostiene(), Vector3.ZERO, 1.0)
	_nota("pelear")
	Sonidos.tocar(self, "carrizo", 0.0, 0.8)
	_cambiar(Estado.AGARRADA)
	_animar("Grab_Hold", 1.0, true)


func _donde_sostiene() -> Vector3:
	# El pecho del jugador (su origen va a media capsula) en el puno
	var mano := _marca("Mano_R").global_position
	return Vector3(mano.x, maxf(mano.y - 0.35, global_position.y + PIES), mano.z)


func _sostener(delta: float) -> void:
	if not jugador.atrapado() or jugador.atrapado_por != self:
		_volver()
		return
	# Te alza hasta su cara pintada
	_pose({"brazo_r": 1.8 if fase < 3 else 1.3, "inclinar": 0.0})
	jugador.velocity = Vector3.ZERO
	jugador.global_position = _donde_sostiene()
	_aprieta -= delta
	if _aprieta <= 0.0:
		_aprieta = APRIETA_CADA
		jugador.set("_invulnerable", 0.0)
		jugador.recibir_dano(DANO_APRIETA, global_position, 0.0, self)
		jugador.sacudida_colgado()
		_fx("catrina_agarre", _donde_sostiene(), Vector3.ZERO, 0.7)
		Sonidos.tocar(self, "carrizo", -4.0, randf_range(0.9, 1.2))
		_sacudir(0.25)
	if _t >= SOSTIENE:
		_cambiar(Estado.LANZA)
		_animar("Throw", 1.0, true)


# Player llama esto con cada apreton mientras lo tiene agarrado
func forcejear() -> void:
	if estado != Estado.AGARRADA:
		return
	_forcejeo += 1.0
	if _forcejeo >= ZAFARSE:
		_contar("zafado")
		_soltar_jugador()
		jugador.set("_invulnerable", 0.0)
		jugador.recibir_dano(DANO_ZAFA, global_position, 0.5, self)
		Sonidos.tocar(self, "carton", 0.0, 1.0)
		_cambiar(Estado.ZAFADA)
		_animar("Grab_Escape", 1.0, true)


func _lanzar() -> void:
	_pose({"brazo_r": 0.6, "inclinar": -0.1})
	if not _soltada and _t < LANZA_SUELTA and jugador.atrapado_por == self:
		jugador.velocity = Vector3.ZERO
		jugador.global_position = _donde_sostiene()
	if not _soltada and _t >= LANZA_SUELTA:
		_soltada = true
		_soltar_jugador()
		var dir := (global_basis.x + _frente() * 0.6)
		dir.y = 0.0
		dir = dir.normalized()
		jugador.set("_invulnerable", 0.0)
		jugador.recibir_dano(DANO_LANZA, global_position, 0.0, self)
		jugador.set("_retroceso", dir * LANZA_VEL)
		jugador.set("_retroceso_freno", LANZA_VEL)
		_contar("lanzo")
		Sonidos.tocar(self, "golpe", 0.0, 0.6)
		# Si en el camino hay una pared o un carro, el choque duele (cuando llegue a el)
		var largo := LANZA_VEL * LANZA_VEL / (2.0 * LANZA_VEL)
		var excluir: Array[RID] = [get_rid(), jugador.get_rid()]
		var rayo := PhysicsRayQueryParameters3D.create(jugador.global_position, jugador.global_position + dir * largo, 1, excluir)
		var choque := get_world_3d().direct_space_state.intersect_ray(rayo)
		_choque_en = -1.0
		if not choque.is_empty():
			# s(t) = v t - a t^2 / 2 con a = v: t = (v - sqrt(v^2 - 2 a s)) / a
			var s := jugador.global_position.distance_to(choque.position) - 0.5
			_choque_en = maxf((LANZA_VEL - sqrt(maxf(LANZA_VEL * LANZA_VEL - 2.0 * LANZA_VEL * s, 0.0))) / LANZA_VEL, 0.05)
	if _t >= LANZA_DURA:
		_volver()


func _seguir_choque(delta: float) -> void:
	if _choque_en < 0.0:
		return
	_choque_en -= delta
	if _choque_en <= 0.0:
		_choque_en = -1.0
		jugador.set("_invulnerable", 0.0)
		jugador.recibir_dano(DANO_CHOCA, jugador.global_position + jugador.velocity, 0.0, self)
		Sonidos.tocar(jugador, "golpe", 2.0, 0.7)
		_sacudir(0.7)
		_contar("choco")


func _soltar_jugador() -> void:
	if jugador and jugador.atrapado_por == self:
		jugador.soltar_atrapado()
	if jugador and _mascara_jugador >= 0:
		jugador.collision_mask = _mascara_jugador
		_mascara_jugador = -1


# --- Trenza ---

func _trenzar(delta: float) -> void:
	var cabeza := _marca("Cabeza").global_position
	if _t < TRENZA_AVISA:
		_girar(_al_jugador(), GIRA_AVISO, delta)
		_trenza_hacia = jugador.global_position - Vector3.UP * 0.4
		_pose({"inclinar": -0.15, "trenza": 0.0, "trenza_hacia": _trenza_hacia})
		return
	var ext := clampf((_t - TRENZA_AVISA) / (TRENZA_PEGA - TRENZA_AVISA), 0.0, 1.0)
	_pose({"inclinar": 0.25, "trenza": ext if _t < TRENZA_DURA - 0.3 else 0.0, "trenza_hacia": _trenza_hacia})
	if not _pego and _t <= TRENZA_PEGA + 0.1:
		var a := Vector3(cabeza.x, 0.0, cabeza.z)
		var b := Vector3(_trenza_hacia.x, 0.0, _trenza_hacia.z)
		var dir := (b - a).normalized()
		var p := Vector3(jugador.global_position.x, 0.0, jugador.global_position.z)
		var a_lo_largo := (p - a).dot(dir)
		var lado := (p - a - dir * a_lo_largo).length()
		if a_lo_largo > 0.0 and a_lo_largo < minf(a.distance_to(b) * ext + 0.6, TRENZA_LARGO) and lado < TRENZA_ANCHO:
			_pego = true
			if _pegar(DANO_TRENZA, cabeza, 0.0):
				_contar("trenza_pego")
				# Te jala hasta el alcance del agarron
				var al := _al_jugador()
				var viaje := maxf(al.length() - TRENZA_DEJA, 0.0)
				jugador.set("_retroceso", -al.normalized() * sqrt(2.0 * TRENZA_FRENO * viaje))
				jugador.set("_retroceso_freno", TRENZA_FRENO)
				_tras_trenza = true
				_siguiente = "agarra"
				Sonidos.tocar(self, "machetazo", 0.0, 0.6)
	if _t > TRENZA_PEGA + 0.1:
		_recupera = true
	if _t >= TRENZA_DURA:
		_volver()


# --- Fase 2: barrida, aretes, grito ---

func _barrer() -> void:
	if _t < BARRIDA_AVISA:
		# La falda empieza a mecerse
		_giro = sin(_t * 12.0) * 0.25
		_pose({"inclinar": -0.1, "brazo_r": 0.5, "brazo_l": 0.5})
	elif _t < BARRIDA_AVISA + BARRIDA_GIRA:
		_giro = (_t - BARRIDA_AVISA) / BARRIDA_GIRA * TAU * 2.0
		_pose({"brazo_r": 1.5, "brazo_l": 1.5})
		_romper_cerca(global_position, ROMPE_BARRIDA)
		if not _pego and _al_jugador().length() < BARRIDA_DESDE + 0.5 and _pies_jugador() < 1.5:
			_pego = true
			if _pegar(DANO_BARRIDA, global_position, 2.0):
				_contar("barrida_pego")
	else:
		_giro = 0.0
		_pose({})
		if not _recupera:
			_recupera = true
			_combo_tras("barrida", _pego)
	if _provisional:
		_provisional.giro = _giro
	if _t >= BARRIDA_DURA:
		_giro = 0.0
		if _provisional:
			_provisional.giro = 0.0
		_volver()


func _aretes() -> void:
	_pose({"inclinar": 0.4 if _t < ARETES_AVISA else -0.1})
	if not _soltada and _t >= ARETES_AVISA:
		_soltada = true
		Sonidos.tocar(self, "carton", 0.0, 1.3)
		var al := _al_jugador().normalized()
		for lado in [-1.0, 1.0]:
			var bola: Node3D = POMPON.new()
			bola.jugador = jugador
			bola.catrina = self
			bola.rumbo = al.rotated(Vector3.UP, deg_to_rad(8.0) * lado)
			get_parent().add_child(bola)
			bola.global_position = global_position + global_basis.x * 1.3 * lado + al * 1.6
		_recupera = true
	if _t >= ARETES_DURA:
		_volver()


func _gritar() -> void:
	_pose({"inclinar": -0.3 if _t < GRITO_AVISA else 0.2, "brazo_r": 0.4, "brazo_l": 0.4})
	if not _soltada and _t >= GRITO_AVISA:
		_soltada = true
		Sonidos.tocar(self, "grito_catrina", 4.0, 1.0)
		_sacudir(0.5)
		var cabeza := _marca("Cabeza").global_position
		_fx("catrina_grito", cabeza, Vector3.ZERO, 1.0)
		var al := _al_jugador()
		var liquido := _liquido()
		if liquido:
			liquido.salpicar(cabeza, 0.4, global_position.y, (al.normalized() + Vector3.DOWN * 0.3).normalized(), 40, Zombie.COLOR_AGUA, Vector2(6.0, 11.0), 0.5)
		if al.length() < GRITO_ALCANCE and al.normalized().dot(_frente()) > GRITO_CONO and _pegar(DANO_GRITO, cabeza, 1.0):
			_contar("grito_pego")
		_soltar_ayudantes()
		_recupera = true
	if _t >= GRITO_DURA:
		_volver()


func _ayudantes_vivos() -> int:
	_ayudantes = _ayudantes.filter(func(z) -> bool:
		return is_instance_valid(z) and Zombie.activos.has(z) and z.estado != Zombie.Estado.MUERTO)
	return _ayudantes.size()


# Fase 2: cada GOTEO_CADA entra uno mas por los portales (donde no lo ves), hasta AYUDANTES_MAX
func _seguir_goteo(delta: float) -> void:
	if fase != 2 or dormida or estado == Estado.TRANSICION or zombis == null or not zombis.has_method("sacar"):
		return
	_goteo -= delta
	if _goteo > 0.0:
		return
	_goteo = GOTEO_CADA
	if _ayudantes_vivos() >= AYUDANTES_MAX:
		return
	var lugar := global_position + Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * 6.0
	if not goteo_lugares.is_empty():
		var camara := get_viewport().get_camera_3d()
		var escondidos := goteo_lugares.filter(func(l: Vector3) -> bool: return not Zombis.a_la_vista(camara, l))
		lugar = (escondidos if not escondidos.is_empty() else goteo_lugares).pick_random()
	var z: Zombie = zombis.sacar(lugar, true)
	if z:
		_ayudantes.append(z)
		_contar("goteo")


func _soltar_ayudantes() -> void:
	if zombis == null or not zombis.has_method("sacar"):
		return
	var n := mini(randi_range(AYUDANTES.x, AYUDANTES.y), AYUDANTES_MAX - _ayudantes_vivos())
	for i in n:
		var a := randf() * TAU
		var lugar := global_position + Vector3(sin(a), 0.0, cos(a)) * 2.0
		var z: Zombie = zombis.sacar(lugar, true)
		if z:
			_ayudantes.append(z)
			_contar("ayudante")


# --- Fase 3 ---

func _manotazo() -> void:
	if _t < MANOTAZO_AVISA + _retraso:
		_pose({"brazo_r": 2.4, "inclinar": -0.3})
		_clip_quieto(_t > MANOTAZO_AVISA * 0.85 and _t < MANOTAZO_AVISA + _retraso - 0.05)
		return
	_clip_quieto(false)
	_pose({"brazo_r": 0.6, "inclinar": 0.3})
	if not _pego:
		_pego = true
		var donde := global_position + _frente() * 2.5
		Sonidos.tocar(self, "pisoton", 0.0, 1.1)
		_sacudir(0.6)
		_fx("catrina_pisada", donde, Vector3.ZERO, 0.75)
		var al := jugador.global_position - donde
		al.y = 0.0
		var pego := al.length() < MANOTAZO_RADIO and _pies_jugador() < 1.2 and _pegar(DANO_MANOTAZO, donde, 1.5)
		if pego:
			_contar("manotazo_pego")
		_recupera = true
		_combo_tras("manotazo", pego)
	if _t >= MANOTAZO_DURA + _retraso:
		_volver()


func _embestir(delta: float) -> void:
	if _t < EMBESTIDA_AVISA:
		_girar(_al_jugador(), GIRA_AVISO * 2.0, delta)
		_rumbo = _frente()
		_pose({"inclinar": -0.2})
		return
	if _t < EMBESTIDA_AVISA + EMBESTIDA_VA:
		var v := EMBESTIDA_LARGO / EMBESTIDA_VA
		velocity.x = _rumbo.x * v
		velocity.z = _rumbo.z * v
		_pose({"inclinar": 0.3, "brazo_r": 1.2, "brazo_l": 1.2})
		if not _pego and _al_jugador().length() < 1.8 + RADIO_GOLPE and _pies_jugador() < 1.2:
			_pego = true
			if _pegar(DANO_EMBESTIDA, global_position, 2.0):
				_contar("embestida_pego")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_pose({})
		_recupera = true
	if _t >= EMBESTIDA_DURA:
		_volver()


# --- Carga (de lejos) ---

func _cargar(delta: float) -> void:
	var al := _al_jugador()
	_girar(al, GIRA_AGARRE, delta)
	velocity.x = _frente().x * CARGA_VEL
	velocity.z = _frente().z * CARGA_VEL
	_pose({"inclinar": 0.3, "brazo_r": -0.4})
	if al.length() < CARGA_AGARRA:
		velocity.x = 0.0
		velocity.z = 0.0
		_cambiar(Estado.AGARRA)
		_animar("Grab_Reach", 1.0, true)
		# Entra a media preparacion: la mano ya va hacia atras
		_t = AGARRA_AVISA * 0.6
		if _anim:
			_anim.seek(_t, true)
		_contar("carga_agarra")
		return
	if _t >= CARGA_DURA:
		_recupera = true
		_volver()


# --- Cambios de fase ---

func _entrar_fase(nueva: int) -> void:
	fase = nueva
	_soltar_jugador()
	_giro = 0.0
	_onda_t = -1.0
	if _onda:
		_onda.visible = false
	_cambiar(Estado.TRANSICION)
	_contar("fase_%d" % nueva)
	fase_cambio.emit(nueva)
	Sonidos.tocar(self, "grito_catrina", 5.0, 0.9 if nueva == 2 else 0.7)
	_sacudir(0.9)
	_fx("catrina_grito", global_position + Vector3.UP * 3.0, Vector3.ZERO, 1.2)
	_fx("catrina_fase", _marca("Cabeza").global_position, Vector3.ZERO, 1.2)
	if nueva == 2:
		_poner_corona("serenol")
		_animar("Tear_Roar", 1.0, true)
		if _provisional:
			_provisional.roto(true)
		else:
			_mostrar("Vestido", false)
			_mostrar("Vestido_Roto", true)
			_mostrar("Carrizo", true)
		Sonidos.tocar(self, "carton", 4.0, 0.8)
		var liquido := _liquido()
		if liquido:
			liquido.reventar(global_position + Vector3.UP * 3.5, 1.0, global_position.y, 50, Zombie.COLOR_AGUA, Vector2(3.0, 7.0))
	else:
		_animar("Head_Fall", 1.0, true)
		_tirar_cabeza()
		for flor: PuntoDebil in _puntos:
			flor.activo(false)
		_nudo.activo(true)
		if _provisional:
			_provisional.mostrar_nudo(true)
		else:
			_mostrar("Nudo", true)
		_arde.erase(Parte.CABEZA)
		humedad[Parte.CABEZA] = 1.0
		# Ya va en cuatro patas: el cuerpo bajo, sin cabeza
		(_forma_cuerpo.shape as CapsuleShape3D).height = 2.6
		_forma_cuerpo.position.y = 1.3
		_forma_cabeza.disabled = true
		radio_golpe = RADIO_GOLPE + 0.3


func _transicion() -> void:
	_pose({"inclinar": -0.35, "brazo_r": 2.0, "brazo_l": 2.0} if fase == 2 else {"inclinar": 0.6})
	if _t >= TRANSICION_DURA:
		_volver()


# El craneo de carton cae y se queda en la plaza, de estorbo
func _tirar_cabeza() -> void:
	var desde := _marca("Cabeza").global_position
	if _provisional:
		_provisional.sin_cabeza(true)
	else:
		var craneo := _modelo.find_child("Craneo", true, false) as Node3D
		if craneo:
			craneo.visible = false
	var hasta := global_position + (_frente() + global_basis.x).normalized() * 3.0
	hasta.y = global_position.y + 0.8
	_cabeza_caida = StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.8
	forma.shape = esfera
	_cabeza_caida.add_child(forma)
	# El craneo de Blender (catrina_props.py) si existe; si no, una esfera con ojos
	if ResourceLoader.exists(RUTA_CRANEO):
		var craneo_3d: Node3D = load(RUTA_CRANEO).instantiate()
		craneo_3d.rotation.y = PI
		craneo_3d.scale = Vector3.ONE * 1.3
		_cabeza_caida.add_child(craneo_3d)
	var malla := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.84, 0.74)
	sm.material = m
	malla.mesh = sm
	malla.visible = not ResourceLoader.exists(RUTA_CRANEO)
	_cabeza_caida.add_child(malla)
	for x in ([] if ResourceLoader.exists(RUTA_CRANEO) else [-0.28, 0.28]):
		var ojo := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.2
		om.height = 0.4
		var negro := StandardMaterial3D.new()
		negro.albedo_color = Color(0.05, 0.04, 0.05)
		om.material = negro
		ojo.mesh = om
		ojo.position = Vector3(x, 0.1, -0.65)
		_cabeza_caida.add_child(ojo)
	get_parent().add_child(_cabeza_caida)
	_cabeza_caida.global_position = desde
	_corona_al_craneo()
	var tween := _cabeza_caida.create_tween()
	tween.tween_property(_cabeza_caida, "global_position", hasta, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_cabeza_caida, "rotation", Vector3(0.6, randf() * TAU, 0.3), 0.6)
	tween.tween_callback(func() -> void:
		Sonidos.tocar(_cabeza_caida, "pisoton", 4.0, 0.7)
		_sacudir(0.9)
		_fx("catrina_rompe", hasta - Vector3.UP * 0.8, Vector3.ZERO, 1.0)
		if jugador.global_position.distance_to(hasta) < 1.8:
			jugador.set("_invulnerable", 0.0)
			jugador.recibir_dano(CABEZA_DANO, hasta, 2.0, self))


func quitar_cabeza_caida() -> void:
	if is_instance_valid(_cabeza_caida):
		_cabeza_caida.queue_free()


# --- Fuego y agua ---

func _parte_donde(parte: Parte) -> Vector3:
	match parte:
		Parte.FALDA:
			return global_position + Vector3.UP * 1.0
		Parte.BLUSA:
			return global_position + Vector3.UP * (3.6 if fase < 3 else 1.6)
	return _marca("Cabeza").global_position


func _quemar(delta: float) -> void:
	_fuego -= delta
	if _fuego > 0.0:
		return
	_fuego = FUEGO_CADA
	var toca := false
	for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
		if zona.tipo != ZonaLombrices.Tipo.FUEGO:
			continue
		var d: Vector3 = zona.global_position - global_position
		d.y = 0.0
		if d.length() < zona.radio + FUEGO_TOCA:
			toca = true
			break
	for parte: Parte in humedad:
		var alcanza := parte != Parte.CABEZA or estado == Estado.ARRODILLADA
		if fase == 3 and parte == Parte.CABEZA:
			alcanza = false
		var secando: bool = toca and alcanza and humedad[parte] > 0.0 and not _arde.has(parte)
		if secando:
			humedad[parte] = maxf(humedad[parte] - SECA[parte] * FUEGO_CADA, 0.0)
			_contar("seca")
		_vapor(parte, secando)
		if toca and alcanza and fase >= 2 and humedad[parte] <= SECA_ARDE and not _arde.has(parte) and humedad[parte] >= 0.0:
			_arde[parte] = ARDE_DURA
			humedad[parte] = -1.0    # ya no vuelve a arder
			_contar("arde")
			Sonidos.tocar(self, "fizz", 0.0, 0.7)
	for parte: Parte in _arde.keys():
		_arde[parte] -= FUEGO_CADA
		_herir(DANO_ARDE, _parte_donde(parte), false, true)
		if _arde[parte] <= 0.0:
			_arde.erase(parte)
			_quemadas += 1
			_contar("quemada")
	_llamear()


func _llamear() -> void:
	for parte: Parte in humedad:
		var ardiendo := _arde.has(parte)
		if ardiendo and not _llamas.has(parte):
			var llama := EfectosPixel.cuadro_bucle("catrina_arde", 1.0 if parte == Parte.FALDA else 0.7)
			llama.top_level = true
			add_child(llama)
			_llamas[parte] = llama
		if _llamas.has(parte):
			_llamas[parte].visible = ardiendo
			if ardiendo:
				_llamas[parte].global_position = _parte_donde(parte)


func _vapor(parte: Parte, prendido: bool) -> void:
	if not prendido and not _vapores.has(parte):
		return
	if not _vapores.has(parte):
		var p := CPUParticles3D.new()
		p.amount = 24
		p.lifetime = 1.4
		p.direction = Vector3.UP
		p.spread = 25.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.2
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.4
		p.scale_amount_max = 0.9
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 1.0 if parte == Parte.FALDA else 0.6
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.6
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.85, 0.88, 0.9, 0.35)
		quad.material = m
		p.mesh = quad
		p.top_level = true
		add_child(p)
		_vapores[parte] = p
	_vapores[parte].global_position = _parte_donde(parte)
	_vapores[parte].emitting = prendido


# Esta empapada: gotea agua sucia del ruedo mientras la falda no se seque
func _gotear(delta: float) -> void:
	_gotea -= delta
	if _gotea > 0.0 or humedad[Parte.FALDA] <= SECA_ARDE:
		return
	_gotea = GOTEA_CADA
	var liquido := _liquido()
	if liquido:
		var a := randf() * TAU
		liquido.salpicar(global_position + Vector3(sin(a) * 1.5, 0.3, cos(a) * 1.5), 0.1, global_position.y, Vector3.DOWN, 2, Zombie.COLOR_AGUA, Vector2(0.3, 1.0), 0.6)


# --- Golpes que recibe ---

# Igual que Zombie.recibir_golpe: 0 = nada, 1 = pego, 2 = mato
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, cuerpo_a_cuerpo := true, _cabeza := false) -> int:
	if estado == Estado.MUERTA:
		return 0
	if dormida:
		_despertar()
	# Fase 3: solo le duele el nudo. El machete siempre lo alcanza (va a gatas, pecho a tu altura);
	# la bala tiene que darle a el (PuntoDebil), en el carton no le hace nada
	if fase == 3 and not cuerpo_a_cuerpo:
		_fx("impacto", global_position + Vector3.UP * 1.6, (global_position - desde).normalized())
		Sonidos.tocar(self, "carton", -8.0, 1.3)
		return 0
	var mult := NUDO_MULT if fase == 3 else 1.0
	if estado == Estado.ARRODILLADA and cuerpo_a_cuerpo:
		mult *= RODILLAS_MULT
	if cuerpo_a_cuerpo:
		mult *= MACHETE_MULT
		# El pie (o la mano) que se quedo plantado tras el golpe
		var plantado := _plantado()
		if plantado != null:
			var al := jugador.global_position - plantado.global_position
			al.y = 0.0
			if al.length() < PIE_ALCANCE:
				mult *= PIE_MULT
				_aguante += dano * NUDO_MULT * (PIE_AGUANTE - 1.0) if fase == 3 else dano * (PIE_AGUANTE - 1.0)
				_fx("catrina_golpe", plantado.global_position + Vector3.UP * 0.3, (plantado.global_position - desde).normalized(), 1.0)
				Sonidos.tocar(self, "carrizo", -2.0, 1.4)
				_contar("plantado")
		# Agachada: el machete alcanza las flores
		if _agachada():
			var i := _flor_cercana(desde)
			if i >= 0:
				_contar("flor_machete")
				if golpe_punto("flor_%d" % i, dano, desde, true) == 2:
					return 2
	if not cuerpo_a_cuerpo and jugador and global_position.distance_to(jugador.global_position) > BALA_LEJOS:
		mult *= BALA_LEJOS_MULT
	return _herir(roundi(dano * mult), desde, cuerpo_a_cuerpo)


# El pie (tras el pisoton) o la mano (tras el manotazo) que se queda en el piso: la ventana del machete
func _plantado() -> Node3D:
	if not _recupera:
		return null
	if estado == Estado.PISA:
		return _marca("Pie_R")
	if estado == Estado.MANOTAZO:
		return _marca("Mano_R")
	return null


# De rodillas o doblada tras fallar el agarron: las flores bajan al alcance del machete
func _agachada() -> bool:
	if fase == 3:
		return false
	return estado == Estado.ARRODILLADA or (estado == Estado.AGARRA and _recupera and not _pego)


func _flor_cercana(desde: Vector3) -> int:
	var mejor := -1
	var cerca := INF
	for i in FLORES:
		if _flores[i] <= 0.0:
			continue
		var d := desde.distance_to(_puntos[i].global_position)
		if d < cerca:
			cerca = d
			mejor = i
	return mejor


# Un PuntoDebil (flor o nudo) recibio el golpe
func golpe_punto(id: String, dano: int, desde: Vector3, cuerpo_a_cuerpo: bool) -> int:
	if estado == Estado.MUERTA or estado == Estado.TRANSICION:
		return 0
	if id == "nudo":
		return _herir(roundi(dano * NUDO_MULT), desde, cuerpo_a_cuerpo)
	var i := int(id.trim_prefix("flor_"))
	if i < 0 or i >= FLORES or _flores[i] <= 0.0:
		return 0
	if not cuerpo_a_cuerpo and not expuesta():
		# Tapada: la bala rebota en el carton del brazo
		_fx("impacto", _puntos[i].global_position, (_puntos[i].global_position - desde).normalized(), 0.5)
		Sonidos.tocar(self, "carton", -10.0, 1.6)
		_contar("flor_tapada")
		return 0
	_flores[i] -= dano
	var donde: Vector3 = _puntos[i].global_position
	_fx("catrina_golpe", donde, (donde - desde).normalized(), 0.6)
	Sonidos.tocar(self, "carton", -6.0, 1.5)
	_nota("pelear")
	if _flores[i] > 0.0:
		return 1
	# Revento la flor: se cae de rodillas
	_puntos[i].activo(false)
	_contar("flor")
	_fx("catrina_flor_revienta", donde, Vector3.ZERO, 1.0)
	var liquido := _liquido()
	if liquido:
		liquido.reventar(donde, 0.3, global_position.y, 20, COLOR_FLOR, Vector2(2.0, 5.0))
	var r := _herir(FLOR_DANO, desde, false)
	if r != 2:
		_arrodillar()
	return maxi(r, 1)


func _herir(dano: int, desde: Vector3, cuerpo_a_cuerpo: bool, fuego := false) -> int:
	if estado == Estado.TRANSICION or estado == Estado.MUERTA:
		return 0
	var mult := pow(QUEMADA_MULT, _quemadas)
	if estado == Estado.POSE or estado == Estado.ZAFADA:
		mult *= ABIERTA_MULT
	var total := maxi(roundi(dano * mult), 1)
	_vida -= total
	if not fuego:
		_aguante += total
		_nota("pelear")
		var hacia := (global_position - desde)
		hacia.y = 0.0
		var donde := global_position + Vector3.UP * (1.6 if fase == 3 else 2.2) - hacia.normalized() * radio_golpe
		_fx("catrina_golpe", donde, hacia.normalized())
		Sonidos.tocar(self, "whack", -6.0, 0.7)
		Sonidos.tocar(self, "carton", -10.0, randf_range(0.9, 1.2))
	# No se salta fases: se queda en el borde de la siguiente
	if fase == 1 and _vida <= FASE_2:
		_vida = FASE_2
		cambio.emit(_vida, VIDA)
		_entrar_fase(2)
		return 1
	if fase == 2 and _vida <= FASE_3:
		_vida = FASE_3
		cambio.emit(_vida, VIDA)
		_entrar_fase(3)
		return 1
	cambio.emit(maxi(_vida, 0), VIDA)
	if fase == 3 and not _frenesi and _vida <= FRENESI and _vida > 0:
		_frenesi = true
		_poner_corona("rojo")
		_contar("frenesi")
		Sonidos.tocar(self, "grito_catrina", 6.0, 0.6)
		_sacudir(0.8)
		frenesi.emit()
	if _vida <= 0:
		_morir(true, desde)
		return 2
	if _aguante >= AGUANTE and not fuego:
		_arrodillar()
	return 1


func _arrodillar() -> void:
	if estado in [Estado.TRANSICION, Estado.AGARRADA, Estado.ARRODILLADA, Estado.MUERTA]:
		return
	_aguante = 0.0
	_giro = 0.0
	if _provisional:
		_provisional.giro = 0.0
	velocity = Vector3.ZERO
	_contar("rodillas")
	Sonidos.tocar(self, "carrizo", 2.0, 0.6)
	_sacudir(0.5)
	_cambiar(Estado.ARRODILLADA)
	_animar("Kneel_Stagger", 1.0, true)


func _morir(pagado: bool, desde := Vector3.ZERO) -> void:
	if estado == Estado.MUERTA:
		return
	_soltar_jugador()
	_cambiar(Estado.MUERTA)
	remove_from_group("zombis")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	_nudo.activo(false)
	for flor: PuntoDebil in _puntos:
		flor.activo(false)
	for parte in _llamas:
		_llamas[parte].visible = false
	_animar("Death", 1.0, true)
	Sonidos.tocar(self, "grito_catrina", 2.0, 0.5)
	Sonidos.tocar(self, "reventar", 4.0, 0.6)
	_sacudir(1.0)
	cambio.emit(0, VIDA)
	# Revienta el nudo: agua sucia y pedazos para todos lados
	var nudo := _marca("Pecho_Nudo").global_position
	var hacia := (global_position - desde)
	hacia.y = 0.0
	var liquido := _liquido()
	if liquido:
		liquido.reventar(nudo, 0.8, global_position.y, 120, Zombie.COLOR_AGUA, Vector2(4.0, 9.0))
	if zombis and zombis.has_method("dejar_restos"):
		zombis.dejar_restos(global_position, 2.0, hacia.normalized())
	_fx("catrina_muere", global_position, Vector3.ZERO, 1.2)
	_fx("catrina_flor_revienta", _marca("Cabeza").global_position, Vector3.ZERO, 1.5)
	murio.emit()
	if not pagado:
		return
	_nota("matar")
	var botin := {}
	for i in BOTINES:
		var uno := Materiales.botin(0.6, true, true)
		for id: String in uno:
			botin[id] = botin.get(id, 0) + uno[id]
	CajaBotin.soltar(get_parent(), global_position + Vector3.UP * 2.0, botin, 0, 2.0)


func _nota(cual: String) -> void:
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.call(cual, "catrina")


# --- Pruebas (-- --medir en la plaza) ---

func forzar_fase(nueva: int) -> void:
	if nueva > fase and estado != Estado.MUERTA:
		_vida = FASE_2 if nueva == 2 else FASE_3
		cambio.emit(_vida, VIDA)
		_entrar_fase(nueva)


func forzar_agarre() -> bool:
	if jugador.atrapar(self, true):
		_agarrar()
		return true
	return false


func _quitar() -> void:
	_soltar_jugador()
	quitar_cabeza_caida()
	remove_from_group("zombis")
	remove_from_group("catrina")
	queue_free()


func _exit_tree() -> void:
	_soltar_jugador()
