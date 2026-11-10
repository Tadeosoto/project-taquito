extends Node3D
# La plaza del desfile (scenes/catrina.tscn): La Mojiganga (Catrina.gd) parada enfrente del
# templete, como estatua, hasta que te acercas. Cuatro carros alegoricos de cubierta (y de pared
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
# Con -- --bot=<s> un jugador de prueba pelea solo (rodea, pega cuando esta abierta, rueda cuando
# va a pegar, machaca para zafarse, se cura): al final dice cuanto duro ella, cuantas veces se
# habria desmayado, el dano por ataque y la cuenta de ella.

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
const CARROS := [Vector3(-9.0, 0, -3.0), Vector3(9.0, 0, -3.0), Vector3(-9.0, 0, 7.0), Vector3(9.0, 0, 7.0)]
const OFRENDAS := [Vector3(-19.0, 0, -8.0), Vector3(19.0, 0, -8.0), Vector3(-19.0, 0, 6.0), Vector3(19.0, 0, 6.0),
	Vector3(-6.0, 0, -19.0), Vector3(6.0, 0, -19.0)]
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
	_empezar()
	if _captura != "":
		_capturar()
	# Pixelify dibuja mal la ligadura "fi" (desfile): mejor sin ella
	_avisar("La plaza de la Mojiganga", 2.5)


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
	# La plaza de Blender (tools/blender/plaza.py: portales, kiosco, carros, ofrendas y sus
	# colisiones "-colonly") si existe; si no, la de cajas de aqui
	if ResourceLoader.exists(PLAZA_GLB):
		var plaza: Node3D = load(PLAZA_GLB).instantiate()
		add_child(plaza)
		# El papel picado ya viene en la plaza de Blender; si no, el de aqui
		if plaza.find_child("PapelPicado", true, false) == null:
			_papel_picado()
		for lugar: Vector3 in OFRENDAS:
			_luz_ofrenda(lugar)
		_rellenar_cajas()
		_luces()
		return
	_nivel_cajas()


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
	# Carros alegoricos: cubierta para la trenza y pared para el aventon
	for i in CARROS.size():
		_carro(CARROS[i], COLORES_PAPEL[i % COLORES_PAPEL.size()])
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
	mundo.environment = ambiente
	add_child(mundo)


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


func _carro(donde: Vector3, color: Color) -> void:
	_caja(Vector3(3.2, 1.6, 5.5), donde + Vector3.UP * 0.8, _mat(color.darkened(0.3)))
	# Lo de arriba: una calaverita de carton y flores
	_caja(Vector3(2.4, 1.2, 2.0), donde + Vector3(0, 2.2, 1.2), _mat(Color(0.9, 0.86, 0.76)), false)
	for k in 6:
		var flor := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		sm.material = _mat(COLORES_PAPEL[k % COLORES_PAPEL.size()], 0.2)
		flor.mesh = sm
		flor.position = donde + Vector3(randf_range(-1.3, 1.3), 1.75, randf_range(-2.4, 0.0))
		add_child(flor)


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
	_caja(Vector3(1.6, 0.9, 1.0), donde + Vector3.UP * 0.45, _mat(Color(0.95, 0.55, 0.1)))
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


func _luz_ofrenda(donde: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 1.6
	luz.omni_range = 7.0
	luz.position = donde + Vector3(0, 1.6, 0.5)
	add_child(luz)
	_velas.append(luz)


# Las velas se apagan fase por fase: en la 3 solo brilla el nudo
func _velas_de(fase: int) -> void:
	for i in _velas.size():
		_velas[i].visible = fase == 1 or (fase == 2 and i % 2 == 0)


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
	add_child(_catrina)
	_catrina.desperto.connect(_desperto)
	_catrina.fase_cambio.connect(func(f: int) -> void:
		_velas_de(f)
		_rellenar_cajas()
		_avisar("Se le rompe el vestido" if f == 2 else "Se le cae la cabeza: ¡el nudo!", 2.0))
	_catrina.murio.connect(_gano_pelea)
	_catrina.frenesi.connect(func() -> void:
		for luz in _velas:
			luz.visible = true
			luz.light_color = Color(1.0, 0.15, 0.1)
			luz.light_energy = 3.0
		_avisar("¡Se enfurece!", 1.5))
	_barra.catrina = _catrina
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
	for ruta: String in [FEMUR, CORONA]:
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
	_avisar(texto + "\n( , otra vez )", 10.0)


func _avisar(texto: String, dura: float) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(dura)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_letrero.text = "vida %d · %d FPS" % [_salud.vida if _salud else 0, Engine.get_frames_per_second()]
	if _salud and _salud.vida <= 0 and not _reiniciando and not _gano and _medir < 0.0 and _bot < 0.0:
		_reiniciar_pelea()
	if _medir > 0.0:
		_seguir_medida(delta)
	if _bot > 0.0:
		_seguir_bot(delta)


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


func _seguir_bot(delta: float) -> void:
	var c := _catrina
	var j := _jugador as Player
	if not is_instance_valid(c):
		return
	_bot_t += delta
	if int(_bot_t / 30.0) != int((_bot_t - delta) / 30.0):
		print("Bot %3.0f s: vida de ella %d, fase %d, estado %s, desmayos %d, a %.1f m, ella en %s, jugador en %s" % [_bot_t, c.vida(), c.fase,
			Catrina.Estado.keys()[c.estado], _bot_desmayos, c.global_position.distance_to(j.global_position), c.global_position.snapped(Vector3.ONE * 0.1),
			j.global_position.snapped(Vector3.ONE * 0.1)])
	if _bot_t < 0.5:
		_bot_vida = _salud.vida
		c._despertar()
		return
	# El dano que recibe, por ataque
	if _salud.vida < _bot_vida:
		var de: String = Catrina.Estado.keys()[c.estado]
		_bot_dano[de] = _bot_dano.get(de, 0) + (_bot_vida - _salud.vida)
	if _salud.vida <= 0:
		_bot_desmayos += 1
		_salud.vida = _salud.vida_max
	_bot_vida = _salud.vida
	if _gano or c.estado == Catrina.Estado.MUERTA or _bot_t >= _bot:
		if _bot_fin < 0.0:
			_bot_fin = _bot_t
			_reporte_bot()
			get_tree().quit()
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
	var hacia_ella := -al.normalized() if d > 0.01 else Vector3.FORWARD
	j.frijol.global_transform = j.frijol.global_transform.looking_at(j.frijol.global_position + hacia_ella, Vector3.UP)
	# Rodar justo antes del golpe (una vez por ataque, y a veces no)
	var clave := "%s_%d" % [c.estado, c.get("_ataques")]
	if BOT_PEGA.has(c.estado) and clave != _bot_ataque:
		var pega: float = BOT_PEGA[c.estado] + float(c.get("_retraso")) * (1.0 if c.estado in [Catrina.Estado.PISA, Catrina.Estado.MANOTAZO] else 0.0)
		if _bot_rueda_en < 0.0:
			# El bot no sabe del amago: rueda al tiempo normal (los amagos lo castigan)
			_bot_rueda_en = BOT_PEGA[c.estado] - BOT_REACCION + randf_range(-BOT_ERROR, BOT_ERROR) if randf() < BOT_ACIERTA else 99.0
		var tc: float = c.get("_t")
		if tc >= _bot_rueda_en and d < 10.0:
			j._pedir_accion("rodar")
			_bot_ataque = clave
			_bot_rueda_en = -1.0
		if tc > pega + 0.2:
			_bot_ataque = clave
			_bot_rueda_en = -1.0
	elif not BOT_PEGA.has(c.estado):
		_bot_rueda_en = -1.0
	# Curarse con poca vida
	_bot_cura -= delta
	if _salud.vida < 35 and _bot_cura <= 0.0:
		_bot_cura = 3.0
		j._curarse()
	# Pegar si esta cerca y abierta (o caminando)
	var abierta: bool = c.expuesta() or c.estado in [Catrina.Estado.CAMINA, Catrina.Estado.POSE, Catrina.Estado.ARRODILLADA, Catrina.Estado.ZAFADA]
	_bot_golpe -= delta
	if abierta and d < 2.2 + c.radio_golpe and _bot_golpe <= 0.0:
		_bot_golpe = 0.4
		j._pedir_accion("golpe")
	# Moverse: rodearla, mas cerca si esta abierta
	var quiere := 2.6 + c.radio_golpe * 0.5 if abierta else 5.0
	var tangente := Vector3.UP.cross(al.normalized()) * _bot_lado
	if randf() < 0.005:
		_bot_lado = -_bot_lado
	var mover := (tangente * 0.6 + al.normalized() * clampf(quiere - d, -1.0, 1.0)).normalized() * 3.5 * delta
	if j.get("_rodada_t") < 0.0:
		j.global_position += mover


func _reporte_bot() -> void:
	var c := _catrina
	print("Bot: %.0f s, gano %s, vida de ella %d de %d, fase %d, desmayos %d" % [
		_bot_fin, _gano, maxi(c.vida(), 0), Catrina.VIDA, c.fase, _bot_desmayos])
	print("  dano recibido por ataque %s" % _bot_dano)
	print("  cuenta %s" % c.cuenta)


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
