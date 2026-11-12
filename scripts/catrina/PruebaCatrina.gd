extends Node3D
# La plaza del desfile (scenes/catrina.tscn): La Mojiganga (Catrina.gd) parada enfrente del
# templete, como estatua, hasta que te acercas. Cuatro jardineras con arbol de cubierta (y de pared
# para el aventon), papel picado de lado a lado, ofrendas con velas que se apagan fase por fase
# hasta que solo brilla el nudo, y dos cajas de molotov que se rellenan cada que cambia de fase.
# Todo armado en codigo, como el carcamo (PruebaLombrices.gd).
#
# Si te desmayas, se reinicia la pelea (tus cosas se quedan). Si la tumbas: el Fémur de la
# Mojiganga y la Corona de cempasúchil.
# Teclas: , vuelve a empezar la pelea.
# Con -- --medir=<s> corre sola esos segundos (flor, molotov mojado y seco, agarron y zafada,
# las tres fases), imprime lo que paso y sale. -- --captura=<archivo.png> guarda una vista de ella
# a los 2 s y sale (para ver el cuerpo provisional o el modelo sin jugar); con -- --fase=2|3 la
# pone antes en esa fase; con -- --agarre te tiene colgado de la mano.
# Con -- --bot=<s> un jugador de prueba pelea solo, por intentos como en el juego (desmayarse
# reinicia la pelea, con 5 tacos cada intento): rodea, rueda antes de cada golpe (BOT_ACIERTA, o
# BOT_BUENO con --bueno), castiga el pie plantado y las flores bajas a machetazos, machaca para
# zafarse, se cura y mata a los zombis que se le acercan. --modo=machete (solo machete) o mixto
# (ademas balazos a las flores cuando esta abierta y al cuerpo de lejos). --intentos=N (8).
# Con -- --cheese el jugador se esconde atras de una jardinera a ~10 m y le dispara: pasa si ella
# revienta la jardinera o llega a el en 6 s.

const PLAZA := 44.0
const FACHADA_ALTO := 10.0
const ENTRADA := Vector3(0.0, 1.1, 16.0)
const CATRINA_EN := Vector3(0.0, 0.0, -11.0)
const MOLOTOV := "res://resources/productos/molotov.tres"
const FEMUR := "res://resources/productos/femur_catrina.tres"
const CORONA := "res://resources/productos/corona_flores.tres"
const MUSICA := "res://audio/musica/pt_tema.mp3"
const MUSICA_VOLUMEN := -10.0
const CAJAS := [Vector3(-14.0, 0.5, 12.0), Vector3(14.0, 0.5, 12.0)]
const ARBOL_JARDINERA := "realista"    # el mas pesado de models/arboles (~7.2k triangulos; roble 3.9k y arce 5.6k no gustaron)
const ARBOL_SEPARA := 1.8      # m: cada uno de los dos arboles, a cada lado del centro del cajon
const ARBOL_ALTO := 4.0        # escala del modelo (ArbolesModelo): hasta ARBOL_ANCHO de copa
const ARBOL_ANCHO := 3.4
const TRONCO_RADIO := 0.2      # m: choque de cada tronco (el del arbol mide ~0.15 de radio)
const TRONCO_ALTO := 3.0
const ARBOL_CAIDO_ALTO := 0.5  # m: donde queda la base del arbol tumbado (el cajon aplastado)
const ARBOL_SUELO := 1.0       # m: la tierra del cajon
const JARDINERAS := [Vector3(-9.0, 0, -3.0), Vector3(9.0, 0, -3.0), Vector3(-9.0, 0, 7.0), Vector3(9.0, 0, 7.0)]
const OFRENDAS := [Vector3(-19.0, 0, -8.0), Vector3(19.0, 0, -8.0), Vector3(-19.0, 0, 6.0), Vector3(19.0, 0, 6.0),
	Vector3(-6.0, 0, -19.0), Vector3(6.0, 0, -19.0)]
# Adornos de pixelfx de la plaza (AG, 2026-11-10): flamas en las velas de las ofrendas, braseros,
# niebla al ras, almas de cempasuchil flotando, murcielagos y calaveras voladoras (fase 2+). En el
# frenesi todo se pone rojo, las almas huyen y los murcielagos vuelan mas rapido
const VELA_OFRENDA := 0.35
const BRASERO_ESCALA := 0.6
# Niebla de verdad (volumetrica) al ras del piso, en vez de hojas planas (AG: no le gusto)
const NIEBLA_ALTO := 1.5
const NIEBLA_DENSIDAD := 0.9
const NIEBLA_COLOR := Color(0.45, 0.38, 0.55)
const ALMAS := 12
const ALMA_ESCALA := 0.22
const MURCIELAGOS := 10
const MURCIELAGO_ESCALA := 0.3
const CALACAS := 3
const CALACA_ESCALA := 0.4
# De donde salen los zombis del goteo de la fase 2: bajo los portales
const GOTEO := [Vector3(-19.5, 0, -12.0), Vector3(-19.5, 0, 12.0), Vector3(19.5, 0, -12.0), Vector3(19.5, 0, 12.0),
	Vector3(-10.0, 0, 19.5), Vector3(10.0, 0, 19.5)]
const COLORES_PAPEL := [Color(0.95, 0.2, 0.5), Color(1.0, 0.55, 0.1), Color(0.55, 0.25, 0.85),
	Color(0.2, 0.75, 0.45), Color(0.25, 0.55, 0.95), Color(1.0, 0.85, 0.2)]

var _catrina: Catrina
var _barra: BarraCatrina
var _jugador: Node3D
var _zombis: Node
var _salud: Node
var _musica: AudioStreamPlayer
var _letrero: Label
var _aviso: Label
var _negro: ColorRect
var _cajas: Array = []
var _velas: Array[OmniLight3D] = []
var _reiniciando := false
var _gano := false
var _medir := -1.0
var _medir_total := 0.0
var _suma_ms := 0.0
var _cuadros := 0
var _pruebas := 0
var _captura := ""
var _captura_fase := 1
var _captura_agarre := false
var _bot := -1.0
var _bot_t := 0.0
var _bot_desmayos := 0
var _bot_dano := {}
var _bot_vida := 0
var _bot_rueda_en := -1.0      # el ataque al que ya le esta rodando (su instancia: estado y _t)
var _bot_ataque := ""
var _bot_golpe := 0.0
var _bot_machaca := 0.0
var _bot_cura := 0.0
var _bot_fin := -1.0
var _bot_lado := 1.0
var _bot_modo := "mixto"
var _bot_acierta := 0.75
var _bot_intentos := 8
var _bot_intento := 1
var _bot_intento_t := 0.0
var _bot_intentos_log: Array[String] = []
var _bot_tiro := 0.0
var _rompibles: Array[Rompible] = []
var _cheese := -1.0
var _velas_fx: Array = []          # por ofrenda, sus flamas
var _braseros: Array = []          # [flama, luz]
var _niebla: FogVolume
var _almas: Array = []             # [nodo, lugar, fase, radio]
var _voladores: Array = []         # [nodo, centro, radio, alto, velocidad, angulo, calaca]
var _plaza_frenesi := false
var _frenesi_t := 0.0
var _captura_frenesi := false
var _captura_jardinera := false
var _romper_jardineras := false


func _ready() -> void:
	_jugador = $Player
	_zombis = $Zombis
	_salud = get_node_or_null("/root/Salud")
	# Siempre de noche y sin amanecer: la pelea no tiene reloj
	var ciclo := $Ciclo as Ciclo
	ciclo.retener_noche = true
	_nivel()
	_musica = AudioStreamPlayer.new()
	_musica.stream = load(MUSICA)
	if _musica.stream is AudioStreamMP3:
		(_musica.stream as AudioStreamMP3).loop = true
	_musica.volume_db = -60.0
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_musica)
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_letrero = Label.new()
	_letrero.position = Vector2(8, 440)
	_letrero.add_theme_font_size_override("font_size", 10)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 4)
	capa.add_child(_letrero)
	_aviso = Label.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.theme = BarraCatrina.TEMA
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 5)
	capa.add_child(_aviso)
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_negro)
	_barra = BarraCatrina.new()
	add_child(_barra)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--medir="):
			_medir = float(arg.trim_prefix("--medir="))
			_medir_total = _medir
		elif arg.begins_with("--captura="):
			_captura = arg.trim_prefix("--captura=")
		elif arg.begins_with("--fase="):
			_captura_fase = int(arg.trim_prefix("--fase="))
		elif arg == "--agarre":
			_captura_agarre = true
		elif arg.begins_with("--bot="):
			_bot = float(arg.trim_prefix("--bot="))
		elif arg.begins_with("--modo="):
			_bot_modo = arg.trim_prefix("--modo=")
		elif arg == "--bueno":
			_bot_acierta = BOT_BUENO
		elif arg.begins_with("--intentos="):
			_bot_intentos = int(arg.trim_prefix("--intentos="))
		elif arg == "--jardinera":
			_captura_jardinera = true
		elif arg == "--frenesi":
			_captura_frenesi = true
		elif arg == "--cheese":
			_cheese = 0.0
		elif arg == "--romper":
			_romper_jardineras = true
	_empezar()
	if _romper_jardineras:
		_ciclo_jardineras()
	if _captura != "":
		_capturar()
	# Pixelify dibuja mal la ligadura "fi" (desfile): mejor sin ella
	_avisar("La plaza de la Mojiganga", 2.5)


# -- --romper: sin pelea, revienta las jardineras una por una (cada ROMPE_CADA s) y las vuelve a armar,
# para verlas romperse. Ella sigue dormida: el jugador esta lejos.
const ROMPE_CADA := 3.0

func _ciclo_jardineras() -> void:
	var jardineras: Array[Rompible] = []
	for r in _rompibles:
		if not r.caidos.is_empty():
			jardineras.append(r)
	while is_inside_tree():
		await get_tree().create_timer(ROMPE_CADA).timeout
		for r in jardineras:
			r.romper(CATRINA_EN)
			await get_tree().create_timer(ROMPE_CADA).timeout
		await get_tree().create_timer(ROMPE_CADA).timeout
		for r in jardineras:
			r.restaurar()


# --- La plaza ---

func _mat(color: Color, brillo := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if brillo > 0.0:
		m.emission_enabled = true
		m.emission = color * brillo
	return m


const PLAZA_GLB := "res://models/escenarios/plaza_catrina/plaza_catrina.glb"


func _nivel() -> void:
	# La plaza de Blender (tools/blender/plaza.py: portales, kiosco, jardineras, ofrendas y sus
	# colisiones "-colonly") si existe; si no, la de cajas de aqui
	if ResourceLoader.exists(PLAZA_GLB):
		var plaza: Node3D = load(PLAZA_GLB).instantiate()
		add_child(plaza)
		# El papel picado ya viene en la plaza de Blender; si no, el de aqui
		if plaza.find_child("PapelPicado", true, false) == null:
			_papel_picado()
		for lugar: Vector3 in OFRENDAS:
			_luz_ofrenda(lugar)
		_adornar_plaza(plaza)
		_armar_rompibles(plaza)
		_rellenar_cajas()
		_luces()
		return
	_nivel_cajas()
	_adornar_cielo()


# Los jardineras y ofrendas de la plaza de Blender que ella revienta (Rompible.gd)
func _armar_rompibles(plaza: Node) -> void:
	for tipo in [["Jardinera", JARDINERAS.size()], ["Ofrenda", OFRENDAS.size()], ["Brasero", _braseros.size()]]:
		for i in tipo[1]:
			var nombre := "%s_%d" % [tipo[0], i]
			var cuerpo := plaza.find_child("Col_" + nombre, true, false) as StaticBody3D
			if cuerpo == null:
				cuerpo = plaza.find_child("Col_%s-colonly" % nombre, true, false) as StaticBody3D
			var entera := plaza.find_child(nombre, true, false) as Node3D
			if cuerpo == null or entera == null:
				push_warning("PruebaCatrina: falta %s en la plaza" % nombre)
				continue
			var caidos: Array[MeshInstance3D] = []
			if tipo[0] == "Jardinera":
				caidos = _poner_arbol(entera, i)
			var luz: OmniLight3D = _velas[i] if tipo[0] == "Ofrenda" and i < _velas.size() else null
			if tipo[0] == "Brasero":
				luz = _braseros[i][1]
			var r := Rompible.armar(self, cuerpo, entera, plaza.find_child(nombre + "_Roto", true, false) as Node3D, luz)
			if tipo[0] == "Jardinera":
				_troncos(cuerpo, i)
				r.caidos = caidos
			if tipo[0] == "Ofrenda" and i < _velas_fx.size():
				for f in _velas_fx[i]:
					r.adornos.append(f)
			elif tipo[0] == "Brasero" and _braseros[i][0]:
				r.adornos.append(_braseros[i][0])
			_rompibles.append(r)


# El arbol de cada jardinera (models/arboles), colgado de la entera para que se rompa con ella
func _poner_arbol(entera: Node3D, i: int) -> Array[MeshInstance3D]:
	var caidos: Array[MeshInstance3D] = []
	for k in 2:
		var arbol := ArbolJardinera.crear(ARBOL_JARDINERA, ARBOL_ALTO, ARBOL_ANCHO, i * 1.7 + k * 2.4)
		if arbol == null:
			return caidos
		# Su copia para cuando se rompa: fuera de la entera (que se esconde), escondida, con la base sobre el cajon aplastado
		var caido := MeshInstance3D.new()
		caido.name = "ArbolCaido_%d_%d" % [i, k]
		caido.mesh = arbol.mesh
		caido.basis = arbol.basis
		caido.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		caido.visible = false
		add_child(caido)
		caido.global_position = JARDINERAS[i] + Vector3(0, ARBOL_CAIDO_ALTO, (k * 2 - 1) * ARBOL_SEPARA)
		caidos.append(caido)
		entera.add_child(arbol)
		arbol.name = "Arbol_%d" % k
		arbol.global_position = JARDINERAS[i] + Vector3(0, ARBOL_SUELO, (k * 2 - 1) * ARBOL_SEPARA)
	return caidos


# Un cilindro de choque por tronco, en el mismo cuerpo que el cajon (Rompible los apaga todos al
# romperse). Va despues de Rompible.armar, que mide el cuerpo con el ultimo CollisionShape3D.
func _troncos(cuerpo: StaticBody3D, i: int) -> void:
	for k in 2:
		var forma := CylinderShape3D.new()
		forma.radius = TRONCO_RADIO
		forma.height = TRONCO_ALTO
		var colision := CollisionShape3D.new()
		colision.name = "Tronco_%d" % k
		colision.shape = forma
		cuerpo.add_child(colision)
		colision.global_position = JARDINERAS[i] + Vector3(0, ARBOL_SUELO + TRONCO_ALTO / 2.0, (k * 2 - 1) * ARBOL_SEPARA)


# --- Adornos de pixelfx ---

func _adornar_plaza(plaza: Node) -> void:
	# Flamas en las velas de las ofrendas (vacios Ofrenda_i_Vela_k de plaza.py)
	for i in OFRENDAS.size():
		var flamas: Array = []
		for k in 5:
			var marca := plaza.find_child("Ofrenda_%d_Vela_%d" % [i, k], true, false) as Node3D
			var flama := EfectosPixel.cuadro_bucle("catrina_vela", VELA_OFRENDA)
			if marca and flama:
				marca.add_child(flama)
				flamas.append(flama)
		_velas_fx.append(flamas)
	# Braseros: fuego de tambo y su luz
	var i := 0
	while true:
		var marca := plaza.find_child("Brasero_%d_Fuego" % i, true, false) as Node3D
		if marca == null:
			break
		var fuego := EfectosPixel.cuadro_bucle("fuego_tambo", BRASERO_ESCALA)
		if fuego:
			marca.add_child(fuego)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.55, 0.2)
		luz.light_energy = 1.6
		luz.omni_range = 8.0
		luz.light_volumetric_fog_energy = 1.5
		luz.position = Vector3.UP * 0.6
		marca.add_child(luz)
		_braseros.append([fuego, luz])
		i += 1
	_adornar_cielo()


# Lo que no depende de la plaza de Blender: niebla, almas, murcielagos, calaveras
func _adornar_cielo() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 31
	for k in ALMAS:
		var alma := EfectosPixel.cuadro_bucle("catrina_almas", ALMA_ESCALA)
		if alma == null:
			break
		var a := rnd.randf() * TAU
		var lugar := Vector3(sin(a), rnd.randf_range(0.3, 1.4), cos(a)) * Vector3(1, 1, 1)
		lugar.x *= rnd.randf_range(5.0, 18.0)
		lugar.z *= rnd.randf_range(5.0, 18.0)
		alma.position = lugar
		add_child(alma)
		_almas.append([alma, lugar, rnd.randf() * TAU, 0.0])
	for k in MURCIELAGOS + CALACAS:
		var calaca := k >= MURCIELAGOS
		var volador := EfectosPixel.cuadro_bucle("catrina_calaca" if calaca else "catrina_murcielago", CALACA_ESCALA if calaca else MURCIELAGO_ESCALA)
		if volador == null:
			continue
		add_child(volador)
		var centro := Vector3(rnd.randf_range(-6, 6), 0, rnd.randf_range(-6, 6))
		_voladores.append([volador, centro, rnd.randf_range(5.0, 15.0), rnd.randf_range(7.0, 9.0) if calaca else rnd.randf_range(11.0, 14.0),
			rnd.randf_range(0.25, 0.5) * (1.0 if rnd.randf() < 0.5 else -1.0), rnd.randf() * TAU, calaca])
		volador.visible = not calaca


func _adornos(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if _plaza_frenesi:
		_frenesi_t += delta
	for a in _almas:
		var nodo: Node3D = a[0]
		if _plaza_frenesi:
			# Huyen hacia afuera y se apagan
			var fuera := Vector3(a[1].x, 0, a[1].z).normalized()
			nodo.position += fuera * delta * 6.0 + Vector3.UP * delta * 1.5
			nodo.visible = _frenesi_t < 2.5
		else:
			nodo.position = a[1] + Vector3(sin(t * 0.4 + a[2]) * 1.2, sin(t * 0.9 + a[2]) * 0.3, cos(t * 0.3 + a[2]) * 1.2)
	var rapidez := 2.0 if _plaza_frenesi else 1.0
	for v in _voladores:
		v[5] += v[4] * rapidez * delta
		v[0].position = v[1] + Vector3(cos(v[5]) * v[2], v[3] + sin(t * 1.3 + v[5]) * 0.6, sin(v[5]) * v[2])


func _plaza_en_frenesi(si: bool) -> void:
	_plaza_frenesi = si
	_frenesi_t = 0.0
	var vela := EfectosPixel.material_bucle("catrina_vela_rojo" if si else "catrina_vela")
	for flamas in _velas_fx:
		for f in flamas:
			f.material_override = vela
	var fuego := EfectosPixel.material_bucle("catrina_brasero_rojo" if si else "fuego_tambo")
	for b in _braseros:
		if b[0]:
			b[0].material_override = fuego
		b[1].light_color = Color(1.0, 0.15, 0.1) if si else Color(1.0, 0.55, 0.2)
	if not si:
		for a in _almas:
			a[0].position = a[1]
			a[0].visible = true


func _nivel_cajas() -> void:
	var piso := _mat(Color(0.33, 0.3, 0.28))
	var muro := _mat(Color(0.45, 0.32, 0.3))
	var cantera := _mat(Color(0.55, 0.5, 0.42))
	var medio := PLAZA / 2.0
	_caja(Vector3(PLAZA + 4.0, 1.0, PLAZA + 4.0), Vector3(0, -0.5, 0), piso)
	# Fachadas alrededor: paredes de verdad (capa 1), asi la Catrina tampoco se sale
	for lado in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var medida := Vector3(PLAZA + 2.0, FACHADA_ALTO, 1.0) if lado.x == 0.0 else Vector3(1.0, FACHADA_ALTO, PLAZA + 2.0)
		_caja(medida, lado * (medio + 0.5) + Vector3.UP * FACHADA_ALTO / 2.0, muro)
		# Portales de cantera: unas columnas pegadas a la fachada
		for k in 7:
			var a := -medio + 3.0 + k * (PLAZA - 6.0) / 6.0
			var donde := Vector3(a, 0, 0) if lado.x == 0.0 else Vector3(0, 0, a)
			donde += lado * (medio - 0.4) + Vector3.UP * FACHADA_ALTO / 2.0
			_caja(Vector3(0.6, FACHADA_ALTO, 0.6), donde, cantera, false)
	# El templete al fondo, detras de ella
	_caja(Vector3(12.0, 1.2, 5.0), Vector3(0, 0.6, -medio + 3.0), cantera)
	_caja(Vector3(12.0, 0.4, 5.0), Vector3(0, 6.2, -medio + 3.0), _mat(Color(0.5, 0.15, 0.5)), false)
	for x in [-5.5, 5.5]:
		_caja(Vector3(0.4, 5.0, 0.4), Vector3(x, 3.7, -medio + 1.0), cantera, false)
	# Jardineras con arbol: cubierta para la trenza y pared para el aventon
	for i in JARDINERAS.size():
		_jardinera(JARDINERAS[i])
	_papel_picado()
	for lugar: Vector3 in OFRENDAS:
		_ofrenda(lugar)
	_rellenar_cajas()
	_luces()


func _luces() -> void:
	# Un foco tibio del templete sobre ella, que se vea desde la entrada
	var foco := SpotLight3D.new()
	foco.light_color = Color(1.0, 0.7, 0.85)
	foco.light_energy = 4.0
	foco.spot_range = 22.0
	foco.spot_angle = 30.0
	foco.position = CATRINA_EN + Vector3(0, 9.0, 8.0)
	add_child(foco)
	foco.look_at(CATRINA_EN + Vector3.UP * 3.0)
	var luna := DirectionalLight3D.new()
	luna.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-30.0), 0)
	luna.light_energy = 0.3
	luna.light_color = Color(0.6, 0.65, 0.95)
	luna.shadow_enabled = true
	add_child(luna)
	var mundo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.06, 0.04, 0.09)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.35, 0.3, 0.45)
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color(0.12, 0.08, 0.14)
	ambiente.fog_density = 0.02
	# Niebla volumetrica solo dentro del FogVolume (al ras del piso); las velas y braseros la alumbran
	ambiente.volumetric_fog_enabled = true
	ambiente.volumetric_fog_density = 0.0
	ambiente.volumetric_fog_albedo = NIEBLA_COLOR
	ambiente.volumetric_fog_length = 40.0
	ambiente.volumetric_fog_anisotropy = 0.3
	mundo.environment = ambiente
	add_child(mundo)
	_niebla = FogVolume.new()
	_niebla.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_niebla.size = Vector3(PLAZA + 2.0, NIEBLA_ALTO, PLAZA + 2.0)
	_niebla.position = Vector3(0, NIEBLA_ALTO * 0.5 - 0.3, 0)
	var fm := FogMaterial.new()
	fm.density = NIEBLA_DENSIDAD
	fm.albedo = NIEBLA_COLOR
	fm.emission = NIEBLA_COLOR * 0.25
	fm.height_falloff = 2.0
	fm.edge_fade = 0.3
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.08
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 16
	tex.depth = 64
	tex.seamless = true
	tex.noise = ruido
	fm.density_texture = tex
	_niebla.material = fm
	add_child(_niebla)


func _caja(medida: Vector3, donde: Vector3, material: Material, solida := true) -> Node3D:
	var nodo: Node3D = StaticBody3D.new() if solida else Node3D.new()
	if solida:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = medida
		forma.shape = caja
		nodo.add_child(forma)
	var malla := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medida
	bm.material = material
	malla.mesh = bm
	nodo.add_child(malla)
	nodo.position = donde
	add_child(nodo)
	return nodo


func _jardinera(donde: Vector3) -> void:
	# Cajon de ladrillo con tierra y una copa verde encima (la version sin modelo de Blender)
	var base := _caja(Vector3(2.4, 1.2, 7.0), donde + Vector3.UP * 0.6, _mat(Color(0.5, 0.2, 0.15)))
	var copa := _caja(Vector3(2.0, 2.0, 5.5), donde + Vector3(0, 3.2, 0), _mat(Color(0.1, 0.28, 0.13)), false)
	copa.reparent(base)
	_rompibles.append(Rompible.armar(self, base as StaticBody3D, base.get_child(1) as Node3D, null))


func _papel_picado() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	var lineas := []
	for z in range(-16, 17, 4):
		lineas.append([Vector3(-PLAZA / 2.0, FACHADA_ALTO - 0.5, z), Vector3(PLAZA / 2.0, FACHADA_ALTO - 0.5, z + 1.0)])
	var cuantos := 0
	var por_linea := 80
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = lineas.size() * por_linea
	for linea in lineas:
		var a: Vector3 = linea[0]
		var b: Vector3 = linea[1]
		for k in por_linea:
			var t := (k + 0.5) / por_linea
			var p := a.lerp(b, t) + Vector3.DOWN * (sin(t * PI) * 1.0 + 0.4)
			var giro := Basis(Vector3.RIGHT, randf_range(-0.2, 0.2))
			mm.set_instance_transform(cuantos, Transform3D(giro, p))
			mm.set_instance_color(cuantos, COLORES_PAPEL[randi() % COLORES_PAPEL.size()])
			cuantos += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ofrenda(donde: Vector3) -> void:
	var base := _caja(Vector3(1.6, 0.9, 1.0), donde + Vector3.UP * 0.45, _mat(Color(0.95, 0.55, 0.1)))
	_caja(Vector3(1.0, 0.5, 0.7), donde + Vector3.UP * 1.15, _mat(Color(0.9, 0.9, 0.85)), false)
	for x in [-0.5, 0.0, 0.5]:
		var vela := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 0.35
		cm.material = _mat(Color(1.0, 0.9, 0.6), 1.5)
		vela.mesh = cm
		vela.position = donde + Vector3(x, 1.1, 0.35)
		add_child(vela)
	_luz_ofrenda(donde)
	_rompibles.append(Rompible.armar(self, base as StaticBody3D, base.get_child(1) as Node3D, null, _velas[-1]))


func _luz_ofrenda(donde: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 1.6
	luz.omni_range = 7.0
	luz.light_volumetric_fog_energy = 1.5
	luz.position = donde + Vector3(0, 1.6, 0.5)
	add_child(luz)
	_velas.append(luz)


# Las velas se apagan fase por fase: en la 3 solo brilla el nudo
func _velas_de(fase: int) -> void:
	for i in _velas.size():
		_velas[i].visible = (fase == 1 or (fase == 2 and i % 2 == 0)) and not _vela_rota(_velas[i])
		if i < _velas_fx.size():
			for f in _velas_fx[i]:
				f.visible = _velas[i].visible
	for v in _voladores:
		if v[6]:
			v[0].visible = fase >= 2


func _vela_rota(luz: OmniLight3D) -> bool:
	for r in _rompibles:
		if r.luz == luz and r.roto:
			return true
	return false


func _rellenar_cajas() -> void:
	for n in CAJAS.size():
		if n < _cajas.size() and is_instance_valid(_cajas[n]):
			continue
		var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
		objeto.set("item_data", load(MOLOTOV))
		objeto.position = CAJAS[n]
		add_child(objeto)
		if n < _cajas.size():
			_cajas[n] = objeto
		else:
			_cajas.append(objeto)


# --- La pelea ---

func _empezar() -> void:
	if is_instance_valid(_catrina):
		_catrina.quitar_cabeza_caida()
		_catrina.queue_free()
	_catrina = Catrina.new()
	_catrina.jugador = _jugador as Player
	_catrina.zombis = _zombis
	_catrina.position = CATRINA_EN
	_catrina.rotation.y = PI
	for g: Vector3 in GOTEO:
		_catrina.goteo_lugares.append(g)
	for r in _rompibles:
		if r.roto:
			r.restaurar()
	add_child(_catrina)
	_catrina.desperto.connect(_desperto)
	_catrina.fase_cambio.connect(func(f: int) -> void:
		_velas_de(f)
		_rellenar_cajas()
		_avisar("Se le rompe el vestido" if f == 2 else "Se le cae la cabeza: ¡el nudo!", 2.0))
	_catrina.murio.connect(_gano_pelea)
	_catrina.frenesi.connect(func() -> void:
		_plaza_en_frenesi(true)
		for i in _velas.size():
			if i < _velas_fx.size():
				for f in _velas_fx[i]:
					f.visible = not _vela_rota(_velas[i])
		for luz in _velas:
			luz.visible = not _vela_rota(luz)
			luz.light_color = Color(1.0, 0.15, 0.1)
			luz.light_energy = 3.0
		_avisar("¡Se enfurece!", 1.5))
	_barra.catrina = _catrina
	_plaza_en_frenesi(false)
	_velas_de(1)
	_gano = false


func _desperto() -> void:
	_avisar("LA MOJIGANGA", 2.5)
	_musica.volume_db = -40.0
	_musica.play()
	create_tween().tween_property(_musica, "volume_db", MUSICA_VOLUMEN, 3.0)


func _reiniciar_pelea() -> void:
	_reiniciando = true
	var tween := create_tween()
	tween.tween_property(_negro, "color:a", 1.0, 0.6)
	tween.tween_callback(func() -> void:
		for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
			if zona.dura > 0.0:
				zona.queue_free()
		if _zombis.has_method("limpiar"):
			_zombis.limpiar()
		if _salud:
			_salud.vida = _salud.vida_max
		_jugador.global_position = ENTRADA
		_jugador.velocity = Vector3.ZERO
		_musica.stop()
		_empezar()
		_rellenar_cajas())
	tween.tween_property(_negro, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_reiniciando = false
		_avisar("Otra vez", 1.5))


func _gano_pelea() -> void:
	_gano = true
	create_tween().tween_property(_musica, "volume_db", -60.0, 4.0)
	var texto := "¡La Mojiganga cayó!"
	var inventario := get_node_or_null("/root/Inventory")
	# Llegaste por tu cuenta (EntradaJefe, sin mision): nadie te paga esto
	var premios: Array = [FEMUR, CORONA] if PasoJefe.hay_premio() else []
	if premios.is_empty():
		texto += "\nNadie te encargó esto: no hay quien te pague."
	for ruta: String in premios:
		var cosa: InventoryItemData = load(ruta)
		if inventario and inventario.add_item(cosa):
			texto += "\n+ %s" % cosa.item_name
		else:
			# Sin lugar: queda en el piso a tus pies
			var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
			objeto.set("item_data", cosa)
			add_child(objeto)
			objeto.global_position = _jugador.global_position + Vector3(randf_range(-1.0, 1.0), -0.6, -1.5)
			texto += "\n%s (en el piso)" % cosa.item_name
	if PasoJefe.desde_juego:
		_avisar(texto, 6.0)
		await get_tree().create_timer(6.0).timeout
		PasoJefe.volver(self, true)
		return
	_avisar(texto + "\n( , otra vez )", 10.0)


func _avisar(texto: String, dura: float) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(dura)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_adornos(delta)
	_letrero.text = "vida %d · %d FPS" % [_salud.vida if _salud else 0, Engine.get_frames_per_second()]
	if _salud and _salud.vida <= 0 and not _reiniciando and not _gano and _medir < 0.0 and _bot < 0.0:
		# Desde una mision (PasoJefe) te saca al mapa; como prueba suelta, reinicia
		if PasoJefe.desde_juego:
			_reiniciando = true
			PasoJefe.volver(self, false)
		else:
			_reiniciar_pelea()
	if _medir > 0.0:
		_seguir_medida(delta)
	if _bot > 0.0:
		_seguir_bot(delta)
	if _cheese >= 0.0:
		_seguir_cheese(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_COMMA and not _reiniciando:
		_reiniciar_pelea()


func _capturar() -> void:
	# Lejos el jugador (que siga dormida) y una camara propia, viendola de tres cuartos
	_jugador.global_position = ENTRADA
	var camara := Camera3D.new()
	add_child(camara)
	camara.global_position = CATRINA_EN + Vector3(5.0, 2.5, 9.0)
	camara.look_at(CATRINA_EN + Vector3.UP * 3.0)
	camara.current = true
	if _captura_jardinera:
		# Tres vistas de la primera jardinera (de tres cuartos, de lado y desde arriba)
		var vistas := [[Vector3(-1.0, 3.6, 4.5), Vector3(-9.0, 3.2, -3.0)], [Vector3(0.5, 2.4, -3.0), Vector3(-9.0, 3.0, -3.0)], [Vector3(-9.0, 8.5, 2.5), Vector3(-9.0, 1.0, -3.0)]]
		for k in vistas.size():
			camara.global_position = vistas[k][0]
			camara.look_at(vistas[k][1])
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png(_captura.replace(".png", "_%d.png" % (k + 1)))
		print("Catrina: jardinera capturada en %s" % _captura)
		get_tree().quit()
		return
	if _captura_agarre:
		_catrina._despertar()
		_jugador.global_position = CATRINA_EN + Vector3(0.0, 1.1, 4.0)
		await get_tree().create_timer(0.3).timeout
		_catrina.forzar_agarre()
		camara.global_position = CATRINA_EN + Vector3(7.0, 3.5, 6.0)
		camara.look_at(CATRINA_EN + Vector3(0, 3.5, 1.5))
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(_captura)
		print("Catrina: captura en %s" % _captura)
		get_tree().quit()
		return
	if _captura_frenesi:
		_catrina._despertar()
		_catrina.forzar_fase(2)
		_catrina.forzar_fase(3)
		await get_tree().create_timer(2.6).timeout
		_catrina._herir(_catrina.vida() - Catrina.FRENESI + 5, _jugador.global_position, true)
		_catrina.set_physics_process(false)
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png(_captura)
		print("Catrina: captura en %s" % _captura)
		get_tree().quit()
		return
	if _captura_fase > 1:
		_catrina._despertar()
		for f in range(2, _captura_fase + 1):
			_catrina.forzar_fase(f)
		# Quieta en su lugar (la animacion de la transicion sigue sola), si no se sale del cuadro
		_catrina.set_physics_process(false)
	await get_tree().create_timer(3.5 if _captura_fase > 1 else 2.0).timeout
	get_viewport().get_texture().get_image().save_png(_captura)
	print("Catrina: captura en %s" % _captura)
	get_tree().quit()


# --- El bot (-- --bot=<s>) ---

# A que tiempo de su clip pega cada ataque (para rodar justo antes)
const BOT_PEGA := {
	Catrina.Estado.PISA: Catrina.PISA_AVISA, Catrina.Estado.AGARRA: Catrina.AGARRA_AVISA + 0.12,
	Catrina.Estado.TRENZA: Catrina.TRENZA_AVISA, Catrina.Estado.BARRIDA: Catrina.BARRIDA_AVISA,
	Catrina.Estado.MANOTAZO: Catrina.MANOTAZO_AVISA, Catrina.Estado.EMBESTIDA: Catrina.EMBESTIDA_AVISA,
}
const BOT_REACCION := 0.3     # s antes del golpe a los que rueda (con un error de +-BOT_ERROR)
const BOT_ERROR := 0.15
const BOT_ACIERTA := 0.75     # chance de reaccionar a cada ataque (no es perfecto)
const BOT_BUENO := 0.9        # --bueno: alguien que juega bien
const BOT_TACOS := 5          # lo que se lleva a cada intento
const BOT_PUNTERIA := 0.6     # mixto: de cada balazo, los que le dan a lo que apunta
const BOT_BALA := 8           # Pistola: dano por tiro
const BOT_CADENCIA := 0.3


func _seguir_bot(delta: float) -> void:
	var c := _catrina
	var j := _jugador as Player
	if not is_instance_valid(c) or _reiniciando:
		return
	_bot_t += delta
	_bot_intento_t += delta
	if int(_bot_t / 30.0) != int((_bot_t - delta) / 30.0):
		print("Bot %3.0f s (intento %d, %.0f s): vida de ella %d, fase %d, estado %s, vida %d, a %.1f m, zombis %d" % [_bot_t, _bot_intento, _bot_intento_t, c.vida(), c.fase,
			Catrina.Estado.keys()[c.estado], _salud.vida, c.global_position.distance_to(j.global_position), c.call("_ayudantes_vivos")])
	if _bot_intento_t < 0.5:
		if _bot_intento_t <= delta:
			_bot_preparar()
		_bot_vida = _salud.vida
		c._despertar()
		return
	# El dano que recibe, por ataque (o de los zombis si ella no esta atacando)
	if _salud.vida < _bot_vida:
		var de: String = Catrina.Estado.keys()[c.estado]
		_bot_dano[de] = _bot_dano.get(de, 0) + (_bot_vida - _salud.vida)
	_bot_vida = _salud.vida
	if _gano or c.estado == Catrina.Estado.MUERTA:
		_bot_fin_intento("GANO")
		_bot_terminar()
		return
	if _salud.vida <= 0:
		_bot_fin_intento("desmayo")
		if _bot_intento >= _bot_intentos or _bot_t >= _bot:
			_bot_terminar()
			return
		_bot_intento += 1
		_bot_intento_t = 0.0
		_reiniciar_ya()
		return
	if _bot_t >= _bot:
		_bot_fin_intento("tiempo")
		_bot_terminar()
		return
	if j.atrapado():
		_bot_machaca -= delta
		if _bot_machaca <= 0.0:
			_bot_machaca = 0.16
			c.forcejear()
		return
	var al := j.global_position - c.global_position
	al.y = 0.0
	var d := al.length()
	# Rodar justo antes del golpe (una vez por ataque, y a veces no)
	var clave := "%s_%d" % [c.estado, c.get("_ataques")]
	if BOT_PEGA.has(c.estado) and clave != _bot_ataque:
		var pega: float = BOT_PEGA[c.estado] + float(c.get("_retraso")) * (1.0 if c.estado in [Catrina.Estado.PISA, Catrina.Estado.MANOTAZO] else 0.0)
		if _bot_rueda_en < 0.0:
			# El bot no sabe del amago: rueda al tiempo normal (los amagos lo castigan)
			_bot_rueda_en = BOT_PEGA[c.estado] - BOT_REACCION + randf_range(-BOT_ERROR, BOT_ERROR) if randf() < _bot_acierta else 99.0
		var tc: float = c.get("_t")
		if tc >= _bot_rueda_en and d < 10.0:
			# Sin teclas rueda para atras de donde mira: a machetazos le da la espalda antes, asi rueda
			# HACIA ella (como en Dark Souls: adentro del pisoton, al lado del pie que va a plantar)
			if _bot_modo == "machete" and d > 0.01 and c.estado == Catrina.Estado.PISA:
				_bot_mirar(j, j.global_position + al.normalized())
			j._pedir_accion("rodar")
			_bot_ataque = clave
			_bot_rueda_en = -1.0
		if tc > pega + 0.2:
			_bot_ataque = clave
			_bot_rueda_en = -1.0
	elif not BOT_PEGA.has(c.estado):
		_bot_rueda_en = -1.0
	# Brincar la onda del pisoton cuando esta por llegar (como lo haria alguien)
	var r_onda: float = c.onda_radio()
	if r_onda >= 0.0 and j.get("_rodada_t") < 0.0 and j.is_on_floor():
		var al_onda := j.global_position - c.onda_centro()
		al_onda.y = 0.0
		var falta := al_onda.length() - r_onda
		if falta > 0.0 and falta < 1.4 and randf() < _bot_acierta:
			j._pedir_accion("brinco")
	# Curarse con poca vida
	_bot_cura -= delta
	if _salud.vida < 40 and _bot_cura <= 0.0:
		_bot_cura = 2.5
		j._curarse()
	_bot_golpe -= delta
	_bot_tiro -= delta
	# Un zombi encima: primero el
	var zombi := _bot_zombi_cerca(j.global_position, 3.0)
	if zombi:
		_bot_mirar(j, zombi.global_position)
		if _bot_golpe <= 0.0:
			_bot_golpe = 0.4
			j._pedir_accion("golpe")
		return
	# A donde va: el pie (o la mano) plantado, o rodeandola
	var plantado: Node3D = c.call("_plantado")
	var agachada: bool = c.call("_agachada")
	var abierta: bool = c.expuesta() or c.estado in [Catrina.Estado.POSE, Catrina.Estado.ARRODILLADA, Catrina.Estado.ZAFADA]
	var objetivo := c.global_position
	var quiere := 2.6 + c.radio_golpe * 0.5 if abierta else 5.0
	if plantado:
		objetivo = plantado.global_position
		quiere = 1.4
	var al_obj := j.global_position - objetivo
	al_obj.y = 0.0
	_bot_mirar(j, objetivo)
	if (abierta or plantado or agachada) and al_obj.length() < (2.2 if plantado else 2.2 + c.radio_golpe) and _bot_golpe <= 0.0:
		_bot_golpe = 0.4
		j._pedir_accion("golpe")
	# Mixto: balazos con la guardia abierta (a las flores) y al cuerpo de lejos
	if _bot_modo == "mixto" and _bot_tiro <= 0.0 and d > 5.0 and c.call("_lo_ve", j.global_position):
		_bot_tiro = BOT_CADENCIA
		if randf() < BOT_PUNTERIA:
			var flor := -1
			if c.expuesta() and c.fase < 3:
				flor = c.call("_flor_cercana", j.global_position)
			if flor >= 0:
				c.golpe_punto("flor_%d" % flor, BOT_BALA, j.global_position, false)
			else:
				c.recibir_golpe(BOT_BALA, j.global_position, 1.0, 80, false)
		_contar_bot("tiros")
	# Moverse: rodearla, mas cerca si esta abierta
	var tangente := Vector3.UP.cross(al_obj.normalized()) * _bot_lado
	if randf() < 0.005:
		_bot_lado = -_bot_lado
	if _bot_modo == "mixto" and not abierta and not plantado:
		quiere = 8.0
	elif _bot_modo == "machete" and not abierta and not plantado:
		# A machetazos se le pega encima: el pisoton se rueda y se castiga el pie
		quiere = 3.4
	var mover := (tangente * (0.2 if plantado else 0.6) + al_obj.normalized() * clampf(quiere - al_obj.length(), -1.0, 1.0)).normalized() * 3.5 * delta
	if j.get("_rodada_t") < 0.0:
		j.global_position += mover


func _bot_mirar(j: Player, punto: Vector3) -> void:
	var hacia := punto - j.global_position
	hacia.y = 0.0
	if hacia.length_squared() > 0.01:
		j.frijol.global_transform = j.frijol.global_transform.looking_at(j.frijol.global_position + hacia.normalized(), Vector3.UP)


func _bot_zombi_cerca(donde: Vector3, radio: float) -> Node3D:
	for z in Zombie.activos:
		if is_instance_valid(z) and z.estado != Zombie.Estado.MUERTO and z.global_position.distance_to(donde) < radio:
			return z
	return null


func _contar_bot(que: String) -> void:
	_bot_dano[que] = _bot_dano.get(que, 0) + 1


# Cada intento empieza igual: vida llena y 5 tacos (los que se llevaria alguien a un jefe)
func _bot_preparar() -> void:
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		var taco: InventoryItemData = load("res://resources/taco_pastor.tres")
		while inventario.cuantos(taco) < BOT_TACOS and inventario.add_item(taco):
			pass
	_salud.vida = _salud.vida_max


func _bot_fin_intento(como: String) -> void:
	var c := _catrina
	_bot_intentos_log.append("intento %d: %s a los %.0f s, fase %d, vida de ella %d" % [_bot_intento, como, _bot_intento_t, c.fase, maxi(c.vida(), 0)])
	print("Bot: " + _bot_intentos_log[-1])


func _bot_terminar() -> void:
	if _bot_fin >= 0.0:
		return
	_bot_fin = _bot_t
	var c := _catrina
	print("Bot (%s, acierta %.2f): %.0f s, gano %s en el intento %d de %d" % [_bot_modo, _bot_acierta, _bot_fin, _gano, _bot_intento, _bot_intentos])
	for linea in _bot_intentos_log:
		print("  " + linea)
	print("  dano recibido por ataque %s" % _bot_dano)
	print("  cuenta %s" % c.cuenta)
	get_tree().quit()


# Reinicio sin fundido (el bot no espera)
func _reiniciar_ya() -> void:
	for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
		if zona.dura > 0.0:
			zona.queue_free()
	if _zombis.has_method("limpiar"):
		_zombis.limpiar()
	_jugador.global_position = ENTRADA
	_jugador.velocity = Vector3.ZERO
	_empezar()
	_rellenar_cajas()


# --- Cheese (-- --cheese): escondido atras de una jardinera, disparandole ---

func _seguir_cheese(delta: float) -> void:
	var c := _catrina
	var j := _jugador as Player
	if _cheese == 0.0:
		# Ella enfrente del jardinera de la derecha, el jugador atras de el (la jardinera en medio)
		c.global_position = Vector3(9.0, 0.0, -9.5)
		c.rotation.y = 0.0
		j.global_position = Vector3(9.5, 1.1, 1.8)
		c._despertar()
	_cheese += delta
	if int(_cheese * 4.0) != int((_cheese - delta) * 4.0):
		c.recibir_golpe(BOT_BALA, j.global_position, 1.0, 80, false)
	if _salud:
		_salud.vida = _salud.vida_max
	var d := c.global_position.distance_to(j.global_position)
	var rotos := _rompibles.filter(func(r: Rompible) -> bool: return r.roto).size()
	if rotos > 0 or d < 4.5 or _cheese > 10.0:
		var paso := (rotos > 0 or d < 4.5) and _cheese <= 6.0
		print("Cheese: %.1f s, jardineras/ofrendas rotos %d, a %.1f m, atorada %d, rodeos -> %s" % [_cheese, rotos, d, c.cuenta.get("atorada", 0), "PASA" if paso else "FALLA"])
		get_tree().quit()


# --- Prueba sola (-- --medir=<s>) ---

func _seguir_medida(delta: float) -> void:
	_suma_ms += delta * 1000.0
	_cuadros += 1
	# Que no se desmaye a media prueba
	if _salud and _salud.vida < 40:
		_salud.vida = _salud.vida_max
	_medir -= delta
	var hecho := 1.0 - _medir / _medir_total
	var pasos := [0.05, 0.12, 0.2, 0.4, 0.5, 0.6, 0.75, 0.88]
	if _pruebas < pasos.size() and hecho > pasos[_pruebas]:
		_probar(_pruebas)
		_pruebas += 1
	if _medir <= 0.0:
		_reporte()
		get_tree().quit()


func _probar(paso: int) -> void:
	match paso:
		0:
			_catrina._despertar()
			print("Catrina: despierta, estado %d" % _catrina.estado)
		1:
			# Las flores solo se revientan con la guardia abierta: la pone a posar
			_catrina._cambiar(Catrina.Estado.POSE)
			var r := _catrina.golpe_punto("flor_0", int(Catrina.FLOR_VIDA), _jugador.global_position, false)
			print("Catrina: flor reventada (%d), de rodillas %s, vida %d, flores %d" % [
				r, _catrina.estado == Catrina.Estado.ARRODILLADA, _catrina.vida(), _catrina.flores_vivas()])
		2:
			ZonaLombrices.crear(self, _catrina.global_position, ZonaLombrices.Tipo.FUEGO, 3.0, 5.0)
			print("Catrina: molotov en la fase 1 (solo debe secar)")
		3:
			print("Catrina: humedad falda %.2f · ardio %d (fase 1: debe ser 0)" % [
				_catrina.humedad[Catrina.Parte.FALDA], _catrina.cuenta.get("arde", 0)])
			_catrina._soltar_jugador()
			_catrina._cambiar(Catrina.Estado.CAMINA)
			var agarro := _catrina.forzar_agarre()
			for i in int(Catrina.ZAFARSE):
				_catrina.forcejear()
			print("Catrina: agarre %s, zafado %s" % [agarro, _catrina.estado == Catrina.Estado.ZAFADA])
		4:
			_catrina.forzar_fase(2)
			print("Catrina: fase %d" % _catrina.fase)
		5:
			# Como si ya la hubieras secado en la fase 1
			_catrina.humedad[Catrina.Parte.FALDA] = 0.1
			ZonaLombrices.crear(self, _catrina.global_position, ZonaLombrices.Tipo.FUEGO, 3.0, 5.0)
			print("Catrina: molotov en la fase 2 con la falda seca (debe arder)")
		6:
			print("Catrina: ardio %d, vida %d" % [_catrina.cuenta.get("arde", 0), _catrina.vida()])
			_catrina.forzar_fase(3)
			print("Catrina: fase %d" % _catrina.fase)
		7:
			var balazo := _catrina.recibir_golpe(50, _jugador.global_position, 1.0, 80, false)
			print("Catrina: bala al carton en la fase 3 -> %d (debe ser 0)" % balazo)
			var r := 0
			while r != 2 and _catrina.vida() > 0:
				r = _catrina.golpe_punto("nudo", 100, _jugador.global_position, true)
				if r == 0:
					_catrina._cambiar(Catrina.Estado.CAMINA)
			print("Catrina: el nudo revento -> %d, gano %s" % [r, _gano])


func _reporte() -> void:
	print("Catrina: %d cuadros, %.2f ms por cuadro, fase %d, vida %d" % [_cuadros, _suma_ms / maxi(_cuadros, 1), _catrina.fase, _catrina.vida()])
	print("  cuenta %s" % _catrina.cuenta)
