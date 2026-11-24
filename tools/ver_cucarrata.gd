extends Node3D
# Visor de la cucarrata: gira la camara alrededor y cambia de animacion.
# godot --path . tools/ver_cucarrata.tscn            (1-6 animaciones, 7 pare crias, flechas giran, rueda acerca)
# godot --path . tools/ver_cucarrata.tscn -- --fotos <carpeta>   (guarda las vistas y sale)
# godot --path . tools/ver_cucarrata.tscn -- --crias <carpeta>   (fotos de las crias y sale)
# Movie Maker (--write-movie x.avi --fixed-fps 30) con -- --video [--solo-pare [--cucarachas]]
# Movie Maker con -- --sonidos: cada sonido de la cucarrata y sus crias con su letrero (S-106 a S-136)

var cuca: Cucarrata
var cam: Camera3D
var angulo := 0.6
var alto := 0.8
var distancia := 3.2
var cerca := false   # la camara mira al cuello (fotos de la juntura)
const CORTOS := ["quieta", "camina", "ataca", "muere", "vuela", "agarra"]


func _ready() -> void:
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.08, 0.09, 0.12)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.3, 0.35, 0.45)
	entorno.environment.glow_enabled = true   # como de noche: que se vean las grietas
	add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.light_energy = 0.6
	add_child(sol)
	var piso := MeshInstance3D.new()
	piso.mesh = PlaneMesh.new()
	piso.mesh.size = Vector2(80, 80)
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.3, 0.3, 0.32)
	piso.material_override = concreto
	add_child(piso)
	cuca = Cucarrata.new()
	add_child(cuca)
	cam = Camera3D.new()
	add_child(cam)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--fotos")
	if i >= 0:
		_fotos(args[i + 1])
	if args.has("--video"):
		_video()
	if args.has("--sonidos"):
		_sonidos()
	var ic := args.find("--crias")
	if ic >= 0:
		_fotos_crias(args[ic + 1])


# Movie Maker con -- --sonidos: cada sonido de docs/sonidos.csv (S-106 a S-136) con la animacion que
# le toca y el volumen y tono de su Sonidos.tocar en el juego. Las crias no salen: sus sonidos van
# sobre la cucarrata quieta. [letrero, animacion, segundos, [[s, sonido, dB, tono], ...], loop]
# (loop = [sonido, dB, tono], como JefeCucarrata._sonar_loop)
const SONIDOS_VIDEO := [
	["S-106  Patas rondando (loop)", "camina", 4.5, [], ["cucarrata_ronda", -5.0, 0.6]],
	["S-107  Despierta: te vio", "ataca", 3.5, [[0.3, "cucarrata_despierta", 0.0, 0.8]], []],
	["S-108  Grita antes de saltarte", "quieta", 3.0, [[0.3, "cucarrata_grita", 0.0, 0.85]], []],
	["S-109 / S-110  Mordida y aterriza", "ataca", 3.0, [[0.4, "cucarrata_mordida", -2.0, 0.8], [0.9, "cucarrata_aterriza", -4.0, 0.7]], []],
	["S-111 / S-112  Pare y salen las crías", "pare", 5.5, [], []],
	["S-113  Despega (fase 2)", "vuela", 3.0, [[0.2, "cucarrata_despega", -2.0, 0.6]], []],
	["S-114  Alas volando (loop)", "vuela", 4.5, [], ["cucarrata_alas", -8.0, 0.55]],
	["S-115  Chillido en el aire", "vuela", 3.0, [[0.3, "cucarrata_vuela_grito", -8.0, 0.78]], ["cucarrata_alas", -8.0, 0.55]],
	["S-116  Apunta el aguijón (aviso para rodar)", "agarra", 3.0, [[0.3, "cucarrata_aguijon_aviso", 0.0, 0.8]], ["cucarrata_alas", -8.0, 0.55]],
	["S-117 / S-118  Picada y aguijonazo", "agarra", 3.0, [[0.2, "cucarrata_picada", -2.0, 0.6], [1.2, "cucarrata_aguijonazo", 0.0, 0.9]], []],
	["S-119  Herida (tomas al azar)", "quieta", 4.5, [[0.3, "cucarrata_herida", -4.0, 0.8], [1.7, "cucarrata_herida", -4.0, 0.85], [3.1, "cucarrata_herida", -4.0, 0.75]], []],
	["S-120  Balazos al caparazón (en vuelo)", "vuela", 3.0, [[0.3, "cucarrata_bala_caparazon", -6.0, 1.0], [0.9, "cucarrata_bala_caparazon", -6.0, 0.95], [1.5, "cucarrata_bala_caparazon", -6.0, 1.1]], ["cucarrata_alas", -8.0, 0.55]],
	["S-121  Cambio de fase", "quieta", 3.5, [[0.3, "cucarrata_cambio_fase", 0.0, 0.8]], []],
	["S-122  La tumbas: chilla y cae", "muere", 3.0, [[0.2, "cucarrata_herida", 0.0, 0.7], [1.0, "cucarrata_cae_muerta", 0.0, 0.8]], []],
	["S-123  Patalea boca arriba (loop)", "muere", 4.0, [], ["cucarrata_patalea", -4.0, 0.8]],
	["S-124  Machetazos en la panza", "muere", 3.0, [[0.4, "cucarrata_machete_panza", -2.0, 0.95], [1.4, "cucarrata_machete_panza", -2.0, 0.88]], ["cucarrata_patalea", -4.0, 0.8]],
	["S-125  Se voltea y cae de pie", "quieta", 3.0, [[0.2, "cucarrata_grita", -2.0, 0.75], [0.9, "cucarrata_aterriza", -2.0, 0.8]], []],
	["S-126 / S-127  Muere y cae", "muere", 4.0, [[0.2, "cucarrata_muere", 0.0, 0.75], [1.6, "cucarrata_cae_muerta", 0.0, 0.7]], []],
	["S-128  Crías: ratas correteando", "quieta", 4.0, [[0.2, "rata_corretea", -14.0, 1.0], [1.4, "rata_corretea", -14.0, 1.15], [2.6, "rata_corretea", -14.0, 0.92]], []],
	["S-129  Una rata te brinca", "quieta", 2.5, [[0.3, "rata_brinca", -8.0, 1.05]], []],
	["S-130  La rata te muerde", "quieta", 2.5, [[0.3, "rata_mordida", -8.0, 1.0]], []],
	["S-131  Muere una rata", "quieta", 2.5, [[0.3, "rata_muere", -6.0, 1.05]], []],
	["S-132  Crías: cucarachas zumbando", "quieta", 4.0, [[0.2, "cucaracha_zumbido", -16.0, 1.0], [1.4, "cucaracha_zumbido", -16.0, 1.15], [2.6, "cucaracha_zumbido", -16.0, 0.92]], []],
	["S-133  La cucaracha avisa (enseña la panza)", "quieta", 2.5, [[0.3, "cucaracha_aviso", -8.0, 1.1]], []],
	["S-134  Se lanza de panza", "quieta", 2.5, [[0.3, "cucaracha_picada", -8.0, 1.2]], []],
	["S-135  Revienta en Serenol", "quieta", 3.0, [[0.3, "cucaracha_explota", -2.0, 1.0]], []],
	["S-136  Muere a balazos", "quieta", 2.5, [[0.3, "cucaracha_muere", -6.0, 1.05]], []],
]


func _sonidos() -> void:
	var letrero := Label.new()
	letrero.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	letrero.offset_top = 12.0
	letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letrero.add_theme_font_size_override("font_size", 22)
	letrero.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	letrero.add_theme_constant_override("outline_size", 8)
	var capa := CanvasLayer.new()
	capa.add_child(letrero)
	add_child(capa)
	await get_tree().create_timer(0.5).timeout
	for toma: Array in SONIDOS_VIDEO:
		letrero.text = toma[0]
		if toma[1] == "pare":
			cuca.parir()
		else:
			cuca.animar(toma[1], 0.2)
		var loop: Node = null
		var l: Array = toma[4]
		if not l.is_empty():
			loop = Sonidos.ambiente(self, l[0], l[1])
			if loop:
				loop.set("pitch_scale", l[2])
		for s: Array in toma[3]:
			_sonar_en(s[0], s[1], s[2], s[3])
		var t := 0.0
		while t < toma[2]:
			t += get_process_delta_time()
			angulo += get_process_delta_time() * 0.4
			await get_tree().process_frame
		if is_instance_valid(loop):
			loop.queue_free()
		# Las crias que salieron del parto se van, para que no se oigan en lo que sigue
		for n in find_children("*", "Node3D", true, false):
			if n is CriaCucarrata:
				n.queue_free()
	get_tree().quit()


func _sonar_en(segundos: float, nombre: String, volumen_db: float, tono: float) -> void:
	await get_tree().create_timer(segundos).timeout
	Sonidos.tocar(self, nombre, volumen_db, tono)


# Las crias junto a la cucarrata (para ver el tamano) y de cerca. Fotos y sale
func _fotos_crias(carpeta: String) -> void:
	set_process(false)
	# Las tomas son de cuando media 0.58 m: asi se ven las crias junto a la vieja; la de 3 m las tapa
	cuca.alto = Cucarrata.ALTO_MODELO
	cuca.scale = Vector3.ONE
	DirAccess.make_dir_recursive_absolute(carpeta)
	cuca.animar("quieta", 0.0)
	var rata := CriaCucarrata.new()
	rata.position = Vector3(2.2, 0, 1.5)
	rata.rotation.y = 0.6
	add_child(rata)
	var cuc := CriaCucarrata.new()
	cuc.tipo = CriaCucarrata.Tipo.CUCARACHA
	cuc.position = Vector3(-2.2, 0.8, 1.5)
	cuc.rotation.y = -0.5
	add_child(cuc)
	var cuc2 := CriaCucarrata.new()
	cuc2.tipo = CriaCucarrata.Tipo.CUCARACHA
	cuc2.animacion_inicial = "quieta"
	cuc2.position = Vector3(-1.2, 0, 2.4)
	cuc2.rotation.y = 2.4
	add_child(cuc2)
	# [posicion de la camara, a donde mira]
	var tomas := [
		[Vector3(0.5, 2.2, 6.5), Vector3(0, 0.3, 1.0)],
		[Vector3(2.95, 0.3, 1.0), Vector3(2.2, 0.1, 1.5)],
		[Vector3(1.6, 0.35, 1.0), Vector3(2.2, 0.1, 1.5)],
		[Vector3(-1.5, 1.0, 2.4), Vector3(-2.2, 0.8, 1.5)],
		[Vector3(-2.9, 0.9, 2.2), Vector3(-2.2, 0.8, 1.5)],
		[Vector3(-0.6, 0.45, 3.1), Vector3(-1.2, 0.05, 2.4)],
	]
	for k in tomas.size():
		cam.position = tomas[k][0]
		cam.look_at(tomas[k][1])
		for f in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/cria_%d.png" % [carpeta, k])
	get_tree().quit()


# Recorre las 6 animaciones con la camara girando y el nombre en pantalla. Se graba con el
# Movie Maker de Godot: godot --path . tools/ver_cucarrata.tscn --write-movie x.avi --fixed-fps 30 -- --video
func _video() -> void:
	var letrero := Label.new()
	letrero.position = Vector2(16, 12)
	letrero.add_theme_font_size_override("font_size", 28)
	var capa := CanvasLayer.new()
	capa.add_child(letrero)
	add_child(capa)
	var tomas := [["quieta", 3.0], ["camina", 4.0], ["ataca", 3.0], ["vuela", 3.0], ["agarra", 3.0],
			["pare", 5.5], ["muere", 2.5]]
	var girar := true
	if OS.get_cmdline_user_args().has("--solo-pare"):
		# Camara quieta de tres cuartos por detras, para ver la cola y a donde caen las crias
		tomas = [["quieta", 1.0], ["pare", 7.0]]
		girar = false
		if OS.get_cmdline_user_args().has("--cucarachas"):
			cuca.siguiente_tipo = CriaCucarrata.Tipo.CUCARACHA
		angulo = 1.3
		alto = 0.75
		distancia = 2.6
	for toma in tomas:
		if toma[0] == "pare":
			letrero.text = "pare  (suelta crias por la cola)"
			cuca.parir()
		else:
			letrero.text = "%s  (%s)" % [toma[0], Cucarrata.ANIMS[toma[0]]]
			cuca.animar(toma[0], 0.2)
		var t := 0.0
		while t < toma[1]:
			t += get_process_delta_time()
			if girar:
				angulo += get_process_delta_time() * 0.6
			await get_tree().process_frame
	get_tree().quit()


func _fotos(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	cuca.animar("quieta", 0.0)
	var vistas := [[0.6, 0.5, 4.5], [PI, 0.4, 4.0], [PI * 0.5, 0.3, 4.0], [PI + 0.5, 0.25, 1.8], [PI - 0.9, 0.1, 2.2], [PI * 0.5, 0.05, 1.0, 1], [PI * 0.75, 0.35, 1.0, 1], [0.3, 0.6, 1.1, 1]]
	for k in vistas.size():
		angulo = vistas[k][0]; alto = vistas[k][1]; distancia = vistas[k][2]; cerca = vistas[k].size() > 3
		for f in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/vista_%d.png" % [carpeta, k])
	cuca.animar("ataca", 0.0)
	angulo = PI + 0.6; alto = 0.5; distancia = 4.0
	for f in 15: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/ataca.png" % carpeta)
	get_tree().quit()


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT): angulo -= delta * 1.5
	if Input.is_key_pressed(KEY_RIGHT): angulo += delta * 1.5
	if Input.is_key_pressed(KEY_UP): alto += delta
	if Input.is_key_pressed(KEY_DOWN): alto -= delta
	# Las distancias de las tomas son para la cucarrata de 0.58 m: crecen con su escala
	var k := cuca.escala()
	var centro := (Vector3(0, 0.3, -0.5) if cerca else Vector3(0, 0.4, -0.3)) * k
	cam.position = centro + (Vector3(sin(angulo), 0, cos(angulo)) * distancia + Vector3(0, alto, 0)) * k
	cam.look_at(centro)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_6:
		cuca.animar(CORTOS[e.keycode - KEY_1])
	elif e is InputEventKey and e.pressed and e.keycode == KEY_7:
		cuca.parir()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: distancia = max(1.0, distancia - 0.3)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: distancia += 0.3
