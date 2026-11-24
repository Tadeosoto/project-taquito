extends Node3D
# El Simi gigante con Serenol (SimiSerenol) en un baldio, bailando, con el protagonista al lado para
# ver el tamano.
#   godot --path . tools/probar_simi.tscn                      verlo (la camara gira sola)
#   godot --path . tools/probar_simi.tscn -- --fotos=<dir>     capturas de dia y de noche
#   ... -- --original                                        con la textura de antes, para comparar

var _cam: Camera3D
var _sol: DirectionalLight3D
var _env: Environment
var _simi: Node3D
var _t := 0.0
var _girar := true


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_hdr_threshold = 0.9
	_env.fog_enabled = true
	_env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	_sol.rotation_degrees = Vector3(-40, 35, 0)
	add_child(_sol)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	piso.mesh = plano
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.36, 0.32, 0.24)
	piso.material_override = mp
	add_child(piso)
	_simi = SimiSerenol.modelo()
	add_child(_simi)
	var compa := (load("res://scenes/protagonista.tscn") as PackedScene).instantiate() as Node3D
	compa.position = Vector3(3.2, 0, 2.5)
	compa.scale = Vector3.ONE * 0.39   # como en player.tscn
	add_child(compa)
	_cam = Camera3D.new()
	_cam.fov = 55
	add_child(_cam)
	_dia(true)
	_mirar(Vector3(0, 4.2, 15), Vector3(0, 3.4, 0))
	var fotos := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			fotos = a.get_slice("=", 1)
		elif a == "--original":
			for parte in 3:
				SimiSerenol.material(parte).set_shader_parameter("original", true)
	if fotos != "":
		_girar = false
		await _fotos(fotos)
		get_tree().quit()


func _process(delta: float) -> void:
	if not _girar:
		return
	_t += delta * 0.25
	_mirar(Vector3(sin(_t) * 15.0, 4.2, cos(_t) * 15.0), Vector3(0, 3.4, 0))


func _dia(si: bool) -> void:
	if si:
		_env.background_color = Color(0.55, 0.65, 0.75)
		_env.ambient_light_color = Color(0.5, 0.52, 0.55)
		_env.ambient_light_energy = 0.7
		_env.fog_light_color = Color(0.6, 0.66, 0.72)
		_sol.light_energy = 1.2
		_sol.light_color = Color(1.0, 0.95, 0.85)
	else:
		_env.background_color = Color(0.02, 0.025, 0.05)
		_env.ambient_light_color = Color(0.15, 0.18, 0.3)
		_env.ambient_light_energy = 0.5
		_env.fog_light_color = Color(0.03, 0.04, 0.07)
		_sol.light_energy = 0.12
		_sol.light_color = Color(0.6, 0.7, 1.0)


func _mirar(desde: Vector3, a: Vector3) -> void:
	_cam.global_position = desde
	_cam.look_at(a)


func _foto(dir: String, nombre: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(dir.path_join(nombre + ".png"))
	print("foto ", nombre)


func _fotos(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(2.0).timeout
	var tomas := [
		["frente", Vector3(0, 4.0, 16), Vector3(0, 3.4, 0)],
		["tres_cuartos", Vector3(11, 2.0, 11), Vector3(0, 3.6, 0)],
		["cara", Vector3(1.5, 6.0, 5.0), Vector3(0, 5.7, 0)],
		["espalda", Vector3(-6, 3.5, -13), Vector3(0, 3.4, 0)],
	]
	for dia in [true, false]:
		_dia(dia)
		for t in tomas:
			_mirar(t[1], t[2])
			await _foto(dir, ("dia_" if dia else "noche_") + t[0])
	# Varios momentos del baile, de noche
	for i in 4:
		await get_tree().create_timer(2.5).timeout
		_mirar(Vector3(0, 4.0, 16), Vector3(0, 3.4, 0))
		await _foto(dir, "baile_%d" % i)
