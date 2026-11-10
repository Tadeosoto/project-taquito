extends Node3D
# El carcamo de la Madre (scenes/lombrices.tscn): el cuarto de bombeo de CarcamoNivel, con la
# alberca de Serenol en medio (donde vive la Madre: MadreCarcamo.gd) y el mezzanine alrededor
# por donde entras; tambos prendidos que alejan a las crias (patealos para regar fuego) y una
# caja de sal y una de molotov abajo, que se rellenan cada que sube la fase (cada 2 sacos).
# Desde el mezzanine no le haces dano a la Madre (MadreCarcamo.arriba): hay que bajar.
#
# La pelea empieza en cuanto se hornea el campo. Si te desmayas, se reinicia toda (tus cosas se
# quedan). Si la matas: $PAGA, un tazo holo y el Diente de la Madre.
# Teclas: , vuelve a empezar la pelea; Shift+, explosion donde apuntas; F3 imprime cada 2 s cuanto
# tarda cada parte del paso (tambien con -- --perfil). -- --lento=<ms> hace el paso lento a
# proposito, para ver que el juego no se traba aunque el hilo no alcance.
# Con -- --medir=<s> corre sola esos segundos (prueba balazo, machetazo, sal, molotov y sacos),
# imprime lo que paso y sale. Con -- --fotos=<dir> guarda las VISTAS del cuarto en <dir> y sale.

const ENTRADA := CarcamoNivel.ENTRADA
const PAGA := 400
# [desde, hacia] de cada foto de -- --fotos
const VISTAS := [
	[Vector3(0, 5.9, -13.6), Vector3(0, 0.5, 3)],          # la entrada, arriba
	[Vector3(-12.6, 6.4, -12.6), Vector3(0, -0.5, 1)],     # todo el cuarto desde la esquina
	[Vector3(-6.5, 1.7, -7.5), Vector3(5, 2.2, 11)],       # desde abajo: alberca, escaleras
	[Vector3(2.5, 1.6, -7.2), Vector3(0, -0.9, -0.5)],     # la alberca de cerca
	[Vector3(-6.5, 2.6, -1.0), Vector3(-11, 1.8, -10)],    # la rampa oeste
	[Vector3(6, 1.7, 2), Vector3(14, 2.2, -6)],            # muro este: letreros y manchas
	[Vector3(9, 5.0, 12.5), Vector3(-4, 1, -4)],           # desde el mezzanine sur
]
const SAL := "res://resources/productos/sal.tres"
const MOLOTOV := "res://resources/productos/molotov.tres"
const DIENTE := "res://resources/productos/diente_madre.tres"
const ALUMBRADO := preload("res://scripts/map/MapAlumbrado.gd")
# Entre el barandal de la alberca y el mezzanine, fuera del camino de rampas y escaleras
const TAMBOS := [Vector3(-8.3, 0, 2.5), Vector3(8.3, 0, -2.5), Vector3(-2.5, 0, -8.3), Vector3(2.5, 0, 8.3)]
# En las esquinas del sur, abajo del mezzanine
const CAJAS := [[Vector3(-12.8, 0.5, 12.8), SAL], [Vector3(12.8, 0.5, 12.8), MOLOTOV]]

var _enjambre: EnjambreLombrices
var _madre: MadreCarcamo
var _barra: BarraMadre
var _jugador: Node3D
var _salud: Node
var _letrero: Label
var _aviso: Label
var _negro: ColorRect
var _cajas: Array = []
var _reiniciando := false
var _gano := false
var _medir := -1.0
var _medir_total := 0.0
var _suma := 0.0
var _suma_pensar := 0.0
var _cuadros := 0
var _pruebas := 0
var _perfil := false
var _perfil_t := 0.0
var _fotos := ""
var _retratando := false


func _ready() -> void:
	# Lo que en el mapa crea Zombis: las hojas de pixel y las gotas/manchas
	if get_tree().get_first_node_in_group("liquido") == null:
		add_child(Liquido.new())
	if get_tree().get_first_node_in_group("efectos_pixel") == null:
		add_child(EfectosPixel.new())
	var nivel := CarcamoNivel.new()
	add_child(nivel)
	_nivel()
	_enjambre = $EnjambreLombrices
	_enjambre.horneado.connect(_empezar)
	# Por donde suben las crias si te subes al mezzanine: [pie, punta] de cada rampa y escalera;
	# ya arriba te siguen por el anillo
	_enjambre.rampas = nivel.rampas
	_enjambre.anillo = CarcamoNivel.EJE_MEZZ
	_jugador = $Player
	# El barandal de la alberca esta en la capa 2: solo te detiene a ti
	(_jugador as CollisionObject3D).collision_mask |= 2
	_salud = get_node_or_null("/root/Salud")
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
	_aviso.theme = BarraMadre.TEMA
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 5)
	capa.add_child(_aviso)
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_negro)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--medir="):
			_medir = float(arg.trim_prefix("--medir="))
			_medir_total = _medir
		elif arg.begins_with("--fotos="):
			_fotos = arg.trim_prefix("--fotos=")
		elif arg == "--perfil":
			_perfil = true
		elif arg.begins_with("--lento="):
			_enjambre.lento_ms = int(arg.trim_prefix("--lento="))


# --- El carcamo ---

# El cuarto lo arma CarcamoNivel; aqui va lo de la pelea: la alberca que frena y los tambos
func _nivel() -> void:
	# Meterse a la alberca te frena (el Serenol se ve claro pero es espeso)
	var zona := ZonaLombrices.new()
	zona.tipo = ZonaLombrices.Tipo.LODO
	zona.radio = CarcamoNivel.ALBERCA
	zona.dura = 0.0
	zona.frena = 0.7
	zona.ver = false
	zona.position = Vector3(0, -CarcamoNivel.HONDO, 0)
	add_child(zona)
	# Tambos prendidos
	for lugar: Vector3 in TAMBOS:
		var tambo := ZonaLombrices.new()
		tambo.tipo = ZonaLombrices.Tipo.REPELE
		tambo.radio = 2.5
		tambo.dura = 0.0
		tambo.position = lugar
		add_child(tambo)
		var cuerpo := StaticBody3D.new()
		cuerpo.add_child(ALUMBRADO.colision_tambo(Transform3D()))
		tambo.add_child(cuerpo)
		var lugares: Array[Transform3D] = [Transform3D()]
		for nodo in ALUMBRADO.armar_tambos(lugares, 0.0):
			tambo.add_child(nodo)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.55, 0.2)
		luz.light_energy = 1.5
		luz.omni_range = 5.0
		luz.position.y = 1.4
		tambo.add_child(luz)
	_rellenar_cajas()


# Las cajas de sal y molotov que se tomaron vuelven a salir
func _rellenar_cajas() -> void:
	for n in CAJAS.size():
		if n < _cajas.size() and is_instance_valid(_cajas[n]):
			continue
		var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
		objeto.set("item_data", load(CAJAS[n][1]))
		objeto.position = CAJAS[n][0]
		add_child(objeto)
		if n < _cajas.size():
			_cajas[n] = objeto
		else:
			_cajas.append(objeto)


# --- La pelea ---

func _empezar() -> void:
	if _madre == null:
		_madre = MadreCarcamo.new()
		_madre.enjambre = _enjambre
		_madre.charco = Vector3.ZERO
		add_child(_madre)
		_madre.muerta.connect(_gano_pelea)
		_madre.saco_reventado.connect(func(q: int) -> void:
			if (MadreCarcamo.SACOS - q) % 2 == 0:
				_rellenar_cajas())
		_barra = BarraMadre.new()
		_barra.madre = _madre
		_barra.enjambre = _enjambre
		add_child(_barra)
	_madre.reiniciar()
	_madre.set_physics_process(true)
	_gano = false
	_avisar("LA MADRE DEL CÁRCAMO", 2.5)
	if not _fotos.is_empty():
		_tomar_fotos()


func _reiniciar_pelea() -> void:
	_reiniciando = true
	var tween := create_tween()
	tween.tween_property(_negro, "color:a", 1.0, 0.6)
	tween.tween_callback(func() -> void:
		for zona in get_tree().get_nodes_in_group("zonas_lombriz"):
			if zona.dura > 0.0:
				zona.queue_free()
		if _salud:
			_salud.vida = _salud.vida_max
		_jugador.global_position = ENTRADA
		_jugador.velocity = Vector3.ZERO
		_enjambre.rearmar()
		_empezar()
		_rellenar_cajas())
	tween.tween_property(_negro, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_reiniciando = false
		_avisar("Otra vez", 1.5))


func _gano_pelea() -> void:
	_gano = true
	_enjambre.disolver()
	var cartera := get_node_or_null("/root/Cartera")
	if cartera:
		cartera.pesos += PAGA
	var texto := "¡La Madre del Cárcamo cayó!\n+$%d" % PAGA
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		var tazo: TazoData = tazos.abrir_bolsa(TazoData.Rareza.HOLO)
		if tazo:
			texto += " · tazo holo: %s" % tazo.nombre
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.add_item(load(DIENTE)):
		texto += " · Diente de la Madre"
	_avisar(texto + "\n( , otra vez )", 10.0)


func _avisar(texto: String, dura: float) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(dura)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	if _enjambre.horneando:
		_letrero.text = "Horneando el cárcamo..."
		return
	_letrero.text = "paso %.1f ms (hilo, %d/s) · pensar %.1f · dibujar %.1f ms · %d FPS · %d pegadas%s" % [
		_enjambre.ms_solver, _enjambre.hz, _enjambre.ms_pensar, _enjambre.ms_pintar,
		Engine.get_frames_per_second(), _enjambre.pegadas(),
		" · calidad: -%d lombrices" % _enjambre.quitadas if _enjambre.quitadas > 0 else ""]
	if _perfil:
		_perfil_t -= delta
		if _perfil_t <= 0.0:
			_perfil_t = 2.0
			var f: PackedInt64Array = _enjambre.solver.perfil
			print("Perfil (us): integrar %d · parejas %d · hilos %d · separar %d · campo %d · limites %d | pensar %d · dibujar %d | %d FPS" % [
				f[0], f[1], f[2], f[3], f[4], f[5], int(_enjambre.ms_pensar * 1000.0), int(_enjambre.ms_pintar * 1000.0), Engine.get_frames_per_second()])
	# Que no se desmaye mientras saca las fotos (si no, se reinicia y las crias vuelven al piso)
	if _retratando and _salud and _salud.vida < 30:
		_salud.vida = _salud.vida_max
	if _salud and _salud.vida <= 0 and not _reiniciando and not _gano and _medir < 0.0:
		_reiniciar_pelea()
	if _medir > 0.0:
		_seguir_medida(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_perfil = not _perfil
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_COMMA:
		if event.shift_pressed:
			EnjambreLombrices.explotar_en_mira(get_tree(), get_viewport())
		elif not _reiniciando:
			_reiniciar_pelea()


# --- Fotos (-- --fotos=<dir>) ---

func _tomar_fotos() -> void:
	var dir := _fotos
	_fotos = ""
	_retratando = true
	DirAccess.make_dir_recursive_absolute(dir)
	_letrero.visible = false
	# Que se vaya el letrero de la pelea y la Madre empiece a moverse
	await get_tree().create_timer(3.5).timeout
	var camara := Camera3D.new()
	camara.fov = 70.0
	add_child(camara)
	camara.current = true
	for n in VISTAS.size():
		camara.look_at_from_position(VISTAS[n][0], VISTAS[n][1])
		for i in 15:
			await get_tree().process_frame
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png(dir.path_join("carcamo_%d.png" % (n + 1)))
	print("Fotos: %d en %s" % [VISTAS.size(), dir])
	# Lo que cuesta la rejilla del mezzanine: GPU y llamadas de dibujo con y sin ella, desde arriba
	camara.look_at_from_position(VISTAS[6][0], VISTAS[6][1])
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for con: bool in [true, false, true, false]:
		for nodo in get_tree().get_nodes_in_group("carcamo_rejilla"):
			(nodo as Node3D).visible = con
		var gpu := 0.0
		var llamadas := 0
		for i in 120:
			await get_tree().process_frame
			if i >= 60:
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				llamadas = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("  %s rejilla: gpu %.2f ms · %d llamadas · %d piezas" % ["con" if con else "sin", gpu / 60.0, llamadas,
			get_tree().get_nodes_in_group("carcamo_rejilla").size()])
	# Cuantas crias ya llegaron contigo al mezzanine (entras arriba)
	await get_tree().create_timer(15.0).timeout
	var arriba := 0
	var total := 0
	for i in _enjambre.vista.size():
		if _enjambre.vivos[i] == 1 and i % _enjambre.puntos == 0:
			total += 1
			if _enjambre.vista[i].y > CarcamoNivel.MEZZ_ALTO - 0.5:
				arriba += 1
	# Por cual rampa o escalera subio cada una (0 rampa oeste, 1 rampa este, 2-3 escaleras)
	var por := [0, 0, 0, 0]
	for h in _enjambre._cabezas:
		var k: int = _enjambre._por_rampa[h]
		if k >= 0 and k < por.size():
			por[k] += 1
	print("  crias arriba %d de %d · por rampa %s · madre %s" % [arriba, total, por, _madre.cuenta])
	camara.look_at_from_position(Vector3(-6.5, 2.6, -1.0), Vector3(-11, 1.8, -10))
	for i in 15:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("carcamo_rampa_despues.png"))
	# Un escupitajo de la Madre pasando de lado frente a la camara
	camara.look_at_from_position(Vector3(-4.0, 2.0, 3.0), Vector3(-4.0, 2.2, -3.0))
	Arrojadizo.lanzar(self, Vector3(-8.0, 2.0, -1.5), Vector3(9.0, 3.0, 0.0), 3, [])
	for i in 24:
		await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("carcamo_escupitajo.png"))
	get_tree().quit()


# --- Prueba sola (-- --medir=<s>) ---

func _seguir_medida(delta: float) -> void:
	_suma += _enjambre.ms_solver
	_suma_pensar += _enjambre.ms_pensar
	_cuadros += 1
	# Que no se desmaye a media prueba
	if _salud and _salud.vida < 30:
		_salud.vida = _salud.vida_max
	_medir -= delta
	var hecho := 1.0 - _medir / _medir_total
	if _pruebas == 0 and hecho > 0.3:
		_pruebas = 1
		_probar_armas()
	if _pruebas == 1 and hecho > 0.5:
		_pruebas = 2
		_probar_zonas()
	if _pruebas == 2 and hecho > 0.6 and _madre:
		_pruebas = 3
		# Revienta 4 sacos para ver las fases 2 y 3
		for n in 4:
			_madre._herir(n, MadreCarcamo.SACO_VIDA)
	if _medir <= 0.0:
		_reporte()
		get_tree().quit()


func _probar_armas() -> void:
	var antes := _enjambre.vivos_total
	var origen := _jugador.global_position + Vector3.UP * 0.5
	var blanco := _enjambre.vista[randi() % _enjambre.vista.size()]
	var pego := EnjambreLombrices.rayo(get_tree(), origen, (blanco - origen).normalized(), 50.0, 0.12)
	if not pego.is_empty():
		pego.enjambre.bullet_hit(pego.dot_index, pego.position, (blanco - origen).normalized())
	var corto := _enjambre.golpe_cuerpo(_jugador.global_position, Vector3.FORWARD, 2.4, 0.35, 12)
	print("Lombrices: balazo %s (%d -> %d vivos), machetazo %s" % [not pego.is_empty(), antes, _enjambre.vivos_total, corto])


func _probar_zonas() -> void:
	var centro := Vector3.ZERO
	var n := 0
	for i in _enjambre.vista.size():
		if _enjambre.vivos[i] == 1:
			centro += _enjambre.vista[i]
			n += 1
	centro = Vector3(centro.x, 0.0, centro.z) / maxi(n, 1)
	ZonaLombrices.crear(self, centro, ZonaLombrices.Tipo.SAL, 2.0, 5.0)
	ZonaLombrices.crear(self, centro + Vector3(3, 0, 0), ZonaLombrices.Tipo.FUEGO, 3.0, 5.0)


func _reporte() -> void:
	var adentro := 0
	for i in _enjambre.vista.size():
		if _enjambre.vivos[i] == 1 and _enjambre.modo[i] & SolverLombrices.BAJO_TIERRA == 0 \
				and _enjambre.campo.muestra(_enjambre.vista[i]) < -0.05:
			adentro += 1
	print("Lombrices: paso %.2f ms (hilo, %d/s), pensar %.2f ms + dibujar %.2f ms (principal), %d cuadros (%.0f por s), %d vivos de %d, quito %d" % [
		_suma / _cuadros, _enjambre.hz, _suma_pensar / _cuadros, _enjambre.ms_pintar, _cuadros, _cuadros / _medir_total,
		_enjambre.vivos_total, _enjambre.vivos.size(), _enjambre.quitadas])
	print("  adentro de algo %d · fase %d · sacos %d · madre %s" % [adentro, _enjambre.fase, _madre.quedan() if _madre else -1, _madre.cuenta if _madre else {}])
	print("  crias %s" % _enjambre.cuenta)
