extends Node3D
# Ver los aspectos del zombi normal (ZombiSerenol, JJ 2026-11-17): el monstruo_02 con la piel del
# Panzon (shaders/zombi_serenol.gdshader) sin camisa, con las cuatro camisas desgarradas y la mujer
# con pelo largo ralo (PeloZombi), armados con Zombie.modelo_skin como en el juego.
#   godot --path . tools/probar_zombi_serenol.tscn
#   Izquierda/Derecha: cual ver  A/D: girar  W/S: acercar  Espacio: quieto / caminando  F: todos
#   Con "-- --fotos" saca las fotos a user://zombi_fotos y se cierra.

const SALIDA := "user://zombi_fotos"
const SEPARA := 1.5
var VARIANTES: Array = ZombiSerenol.ASPECTOS   # hombres adelante, mujeres en la fila de atras
var _cam: Camera3D
var _ayuda: Label
var _modelos: Array[Node3D] = []
var _anims: Array[AnimationPlayer] = []
var _pelos: Array = []
var _cual := 0
var _giro := 0.4
var _lejos := 2.6
var _todos := false
var _camina := false

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.38, 0.45)
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.6
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 25, 0)
	sol.light_energy = 0.7
	sol.light_color = Color(0.75, 0.8, 1.0)
	add_child(sol)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(60, 60)
	piso.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.16, 0.17, 0.16)
	piso.material_override = mat
	add_child(piso)
	for i in VARIANTES.size():
		var v: Array = VARIANTES[i]
		var m := Zombie.modelo_skin(i, 1.0)
		add_child(m)
		m.position = Vector3((i % 5 - 2) * SEPARA + (i / 5) * SEPARA * 0.5, 0, -(i / 5) * 2.2)
		var anim := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("h/Zombie_Idle")
		anim.seek(randf() * 2.0, true)
		_modelos.append(m)
		_anims.append(anim)
		for pelo in m.find_children("*", "PeloZombi", true, false):
			_pelos.append(pelo)
		var nombre := Label3D.new()
		nombre.text = v[0]
		nombre.pixel_size = 0.003
		nombre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nombre.outline_size = 8
		nombre.position = m.position + Vector3(0, 2.1, 0)
		add_child(nombre)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	var capa := CanvasLayer.new()
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.position = Vector2(8, 8)
	_ayuda.add_theme_font_size_override("font_size", 12)
	capa.add_child(_ayuda)
	if "--fotos" in OS.get_cmdline_user_args():
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_ayuda.visible = false
		DirAccess.make_dir_recursive_absolute(SALIDA)
		_fotos()

func _process(delta: float) -> void:
	if _ayuda.visible == false and "--fotos" in OS.get_cmdline_user_args():
		return
	if Input.is_key_pressed(KEY_A): _giro -= delta * 1.5
	if Input.is_key_pressed(KEY_D): _giro += delta * 1.5
	if Input.is_key_pressed(KEY_W): _lejos = maxf(0.8, _lejos - delta * 2.0)
	if Input.is_key_pressed(KEY_S): _lejos = minf(8.0, _lejos + delta * 2.0)
	if _todos:
		_cam.position = Vector3(0.4, 3.2, 10.0)
		_cam.look_at(Vector3(0, 0.95, 0))
	else:
		var c := _modelos[_cual].position + Vector3(0, 0.95, 0)
		_cam.position = c + Vector3(sin(_giro), 0.12, cos(_giro)) * _lejos
		_cam.look_at(c)
	_ayuda.text = "%s   (Izq/Der: cual  A/D: girar  W/S: acercar  Espacio: %s  F: todos)" % [
			VARIANTES[_cual][0], "caminando" if _camina else "quieto"]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT: _cual = posmod(_cual - 1, _modelos.size()); _todos = false
		KEY_RIGHT: _cual = posmod(_cual + 1, _modelos.size()); _todos = false
		KEY_F: _todos = not _todos
		KEY_SPACE:
			_camina = not _camina
			for a in _anims:
				a.play("h/Zombie_Walk_Fwd" if _camina else "h/Zombie_Idle")

func _foto(archivo: String) -> void:
	for i in 30:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SALIDA + "/" + archivo)

func _fotos() -> void:
	for a in _anims:
		a.seek(0.5, true); a.pause()
	await get_tree().process_frame
	_cam.fov = 32
	_cam.position = Vector3(0.4, 3.2, 10.0)
	_cam.look_at(Vector3(0, 0.95, 0))
	await _foto("00_todos.png")
	_cam.fov = 40
	for i in _modelos.size():
		var c := _modelos[i].position
		_cam.position = c + Vector3(0.5, 1.15, 2.5)
		_cam.look_at(c + Vector3(0, 0.95, 0))
		await _foto("%02d_frente.png" % i)
		_cam.position = c + Vector3(-1.3, 1.3, -2.2)
		_cam.look_at(c + Vector3(0, 0.95, 0))
		await _foto("%02d_atras.png" % i)
	print("Fotos en ", ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()
