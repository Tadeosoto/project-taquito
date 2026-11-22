extends Node
# Prueba del pterodactilo de Juarez donde vive: el claro del centro-oeste de map_test (PteroClaro).
#   godot --path . tools/probar_ptero.tscn                 jugarlo (el jugador a 60 m del claro)
#   godot --path . --headless tools/probar_ptero.tscn -- --prueba   revisiones y sale
#   godot --path . tools/probar_ptero.tscn -- --fotos=<dir>       capturas de la pelea
#   godot --path . --write-movie x.avi --fixed-fps 30 --resolution 640x480 tools/probar_ptero.tscn -- --video
#       la pelea entera con letreros y despues los 26 clips (sin dano al jugador)
# En la prueba el jugador no recibe dano de verdad (godmode de Salud) pero se cuenta cada golpe.

var _jugador: Player
var _claro: PteroClaro
var _bien := 0
var _total := 0
var _golpes := 0


func _ready() -> void:
	var mapa: Node = load("res://scenes/map_test.tscn").instantiate()
	add_child(mapa)
	_jugador = mapa.get_node("Player")
	_claro = mapa.get_node("Pterodactilo")
	_jugador.global_position = PteroClaro.CENTRO + Vector3(60.0, 1.2, 0.0)
	var prueba := "--prueba" in OS.get_cmdline_user_args()
	var fotos := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			fotos = a.get_slice("=", 1)
	if prueba:
		await _prueba()
		get_tree().quit()
	elif "--video" in OS.get_cmdline_user_args():
		await _video()
		get_tree().quit()
	elif fotos != "":
		await _fotos(fotos)
		get_tree().quit()


func _revisar(que: String, ok: bool, nota := "") -> void:
	_total += 1
	_bien += 1 if ok else 0
	print("%s %s %s" % ["ok   " if ok else "FALLA", que, nota])


func _esperar(s: float) -> void:
	var hasta := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < hasta:
		await get_tree().process_frame


func _prueba() -> void:
	await _esperar(2.0)
	var jefe := _claro.jefe
	_revisar("aparece en el claro, dormido", jefe != null and not jefe.despierto()
		and Vector2(jefe.global_position.x, jefe.global_position.z).distance_to(Vector2(PteroClaro.CENTRO.x, PteroClaro.CENTRO.z)) < 1.0)
	if jefe == null:
		return
	# Que no te haga dano de verdad, pero contar los golpes: un blanco que sigue al jugador
	var blanco := Blanco.new()
	blanco.prueba = self
	add_child(blanco)
	jefe.set("_jugador", blanco)
	_jugador.global_position = PteroClaro.CENTRO + Vector3(20.0, 1.2, 0.0)
	await _esperar(0.5)
	_revisar("despierta al acercarte", jefe.despierto())
	await _esperar(4.0)
	_revisar("despega y da vueltas en el aire", jefe.en_aire(), JefePtero.Estado.keys()[jefe.estado])
	var ala := jefe._hueso("l_finger_011").distance_to(jefe._hueso("r_finger_015"))
	_revisar("en vuelo mide unos 8 m de ala a ala", absf(ala - 8.0) < 1.5, "%.1f m" % ala)
	# Esperar una picada y que pegue (el jugador quieto)
	var hasta := Time.get_ticks_msec() + 20000
	while _golpes == 0 and Time.get_ticks_msec() < hasta:
		await get_tree().process_frame
	_revisar("se avienta en picada y te pega", _golpes > 0, "%d golpes" % _golpes)
	jefe._herir(JefePtero.VIDA * 0.55)
	await _esperar(0.2)
	_revisar("con la mitad de la vida se cae", jefe.fase == 2 and jefe.estado in [JefePtero.Estado.CAE, JefePtero.Estado.HERIDO], JefePtero.Estado.keys()[jefe.estado])
	await _esperar(4.0)
	_revisar("pelea en el piso", jefe.estado in [JefePtero.Estado.CAMINA, JefePtero.Estado.ATACA, JefePtero.Estado.HERIDO, JefePtero.Estado.RUGE, JefePtero.Estado.CARGA]
		and absf(jefe.global_position.y - jefe.piso) < 0.05, JefePtero.Estado.keys()[jefe.estado])
	_revisar("le pega la pistola (rayo)", not jefe.query_ray_hit(_jugador.global_position + Vector3.UP, (jefe._hueso("back002_03") - _jugador.global_position - Vector3.UP).normalized(), 200.0, 0.1).is_empty())
	jefe._herir(JefePtero.VIDA)
	await _esperar(2.5)
	_revisar("muere", jefe.estado == JefePtero.Estado.MUERTA)
	_revisar("y no vuelve", get_node("/root/Misiones").jefe_muerto("ptero"))
	print("RESULTADO %d/%d" % [_bien, _total])


# El jefe le pega a esto en vez de al jugador (en la prueba): va donde el jugador y cuenta los golpes
class Blanco extends Node3D:
	var prueba: Node

	func _process(_delta: float) -> void:
		global_position = prueba._jugador.global_position

	func recibir_dano(_dano: int, _desde: Vector3, _empuja := 1.0, _de: Node = null) -> void:
		prueba._golpes += 1


func _fotos(dir: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _esperar(6.0)
	var jefe := _claro.jefe
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var tomas := [["dormido", 0.0], ["despierta", 0.4], ["vuela", 5.0], ["picada", 0.0], ["piso", 0.0], ["muere", 0.0]]
	for toma: Array in tomas:
		match toma[0]:
			"despierta":
				jefe.despertar()
			"picada":
				var hasta := Time.get_ticks_msec() + 15000
				while jefe.estado != JefePtero.Estado.PICADA and Time.get_ticks_msec() < hasta:
					await get_tree().process_frame
				await _esperar(0.3)
			"piso":
				jefe._herir(JefePtero.VIDA * 0.55)
				await _esperar(5.0)
			"muere":
				jefe._herir(JefePtero.VIDA)
				await _esperar(2.5)
		await _esperar(toma[1])
		var c := jefe._hueso("back002_03")
		cam.look_at_from_position(c + Vector3(9.0, 3.0, 12.0), c, Vector3.UP)
		await _esperar(0.3)
		get_viewport().get_texture().get_image().save_png("%s/ptero_%s.png" % [dir, toma[0]])
		print("FOTO ", toma[0])


# --- Video (Movie Maker: el tiempo es del juego, se espera con timers) ---

var _cam: Camera3D
var _letrero: Label
var _jefe_video: JefePtero
var _modo_cam := "pelea"


func _seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _decir(texto: String) -> void:
	_letrero.text = texto


func _process(delta: float) -> void:
	if _cam == null or not is_instance_valid(_jefe_video):
		return
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.vida = salud.vida_max
	var c := _jefe_video._hueso("back002_03")
	var j := _jugador.global_position
	var desde: Vector3
	var mira: Vector3
	if _modo_cam == "clips":
		desde = c + Vector3(7.0, 2.5, 9.0)
		mira = c
	else:
		var atras := j - c
		atras.y = 0.0
		atras = atras.normalized() if atras.length() > 0.1 else Vector3.BACK
		desde = j + atras * 8.0 + atras.cross(Vector3.UP) * 3.0 + Vector3.UP * 3.5
		mira = c.lerp(j, 0.3)
	_cam.global_position = _cam.global_position.lerp(desde, minf(delta * 3.0, 1.0))
	_cam.look_at(mira, Vector3.UP)


func _video() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_cam.global_position = PteroClaro.CENTRO + Vector3(40.0, 6.0, 20.0)
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_letrero = Label.new()
	_letrero.theme = preload("res://resources/ui/tema_pixel.tres")
	_letrero.position = Vector2(12, 440)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 5)
	capa.add_child(_letrero)
	_jugador.global_position = PteroClaro.CENTRO + Vector3(30.0, 1.2, 0.0)
	await _seg(3.0)
	_jefe_video = _claro.jefe
	var jefe := _jefe_video
	_decir("El pterodáctilo de Juárez, echado en el claro")
	await _seg(5.0)
	_decir("Te acercas: ruge y despega")
	jefe.despertar()
	await _seg(5.0)
	_decir("Fase 1: da vueltas en el aire")
	await _seg(3.0)
	for k in 2:
		jefe._picada_reloj = 0.0
		_decir("Chilla (el aviso para rodar)...")
		while jefe.estado != JefePtero.Estado.PICADA:
			await get_tree().process_frame
		_decir("...y se avienta en picada con las garras")
		while jefe.estado == JefePtero.Estado.PICADA:
			await get_tree().process_frame
		_decir("Pasa rozando el piso: ahí lo alcanza el machete")
		await _seg(3.5)
	_decir("A la mitad de la vida se cae")
	jefe._herir(JefePtero.VIDA * 0.52)
	await _seg(3.5)
	_decir("Fase 2: camina, picotea y aletea")
	await _seg(9.0)
	_decir("Ruge y embiste")
	_jugador.global_position = jefe.global_position + jefe._frente() * 16.0 + Vector3.UP * 1.2
	jefe._cambiar(JefePtero.Estado.RUGE)
	jefe._animar("Ground_Roar 2", 0.2, JefePtero.RUGE_VEL)
	await _seg(4.0)
	_decir("Mucho daño junto lo tambalea")
	jefe._acumulado = JefePtero.HERIDO_CADA
	jefe._cambiar(JefePtero.Estado.CAMINA)
	jefe._herir(1.0)
	await _seg(2.5)
	_decir("Cada tanto vuelve a volar, da dos picadas y aterriza")
	jefe._vuelo_reloj = 0.0
	var hasta := 0
	while jefe.estado != JefePtero.Estado.ATERRIZA and hasta < 30 * 40:
		if jefe.estado == JefePtero.Estado.RONDA:
			jefe._picada_reloj = minf(jefe._picada_reloj, 1.0)
		hasta += 1
		await get_tree().process_frame
	_decir("Aterriza")
	await _seg(3.0)
	_decir("Muere")
	jefe._herir(JefePtero.VIDA)
	await _seg(4.0)
	# Los 26 clips uno por uno, en un pterodactilo quieto junto
	_decir("")
	var muestra := JefePtero.new()
	muestra.centro = PteroClaro.CENTRO
	muestra.piso = jefe.piso
	muestra.set_process(false)
	add_child(muestra)
	muestra.global_position = Vector3(PteroClaro.CENTRO.x - 30.0, jefe.piso, PteroClaro.CENTRO.z)
	_jugador.global_position = muestra.global_position + Vector3(0.0, 1.2, 60.0)
	_jefe_video = muestra
	_modo_cam = "clips"
	muestra.remove_from_group("lombrices")
	var ap: AnimationPlayer = muestra._ap
	for clip in ap.get_animation_list():
		_decir("Clip: " + clip)
		ap.play(clip, 0.15)
		ap.speed_scale = 1.0
		await _seg(maxf(ap.get_animation(clip).length, 1.2) + 0.3)
