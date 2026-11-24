extends Node3D

# Un pedazo del panteon (Panteon.gd, JJ 2026-11-22) para ver las tumbas: filas espalda con espalda,
# corredores, criptas, fosas recientes y ofrendas.
#   godot --path . tools/probar_panteon.tscn
#   godot --path . tools/probar_panteon.tscn -- --fotos=<carpeta>   (capturas y sale)
# 1: desde arriba; 2: en un corredor, a la altura del jugador; 3: de cerca; 4: de noche. Flechas: girar.

var _cam: Camera3D
var _sol: DirectionalLight3D
var _env: Environment
var _panteon: Panteon


func _ready() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	add_child(_sol)
	_sol.rotation_degrees = Vector3(-38, 40, 0)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(120, 120)
	piso.mesh = plano
	var mp := ShaderMaterial.new()
	mp.shader = preload("res://shaders/ps1_combined.gdshader")
	mp.set_shader_parameter("albedo_texture", load("res://textures/map/pasto_seco.png"))
	mp.set_shader_parameter("jitter_enabled", false)
	mp.set_shader_parameter("wobble_enabled", false)
	mp.set_shader_parameter("affine_enabled", false)
	piso.material_override = mp
	plano.material = mp
	add_child(piso)
	# El shader repite la textura con UV: el plano trae 0..1, se escala a 2 m por cuadro
	var arr := plano.get_mesh_arrays()
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	for i in uv.size():
		uv[i] *= 60.0
	arr[Mesh.ARRAY_TEX_UV] = uv
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mp)
	piso.mesh = am
	_panteon = Panteon.new()
	add_child(_panteon)
	_panteon.armar(Rect2(-24, -18, 48, 36), 7)
	_cam = Camera3D.new()
	_cam.fov = 60
	add_child(_cam)
	_cam.current = true
	_toma(0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_fotos(a.trim_prefix("--fotos="))


func _toma(n: int) -> void:
	var noche := n == 3
	_env.background_color = Color(0.05, 0.06, 0.09) if noche else Color(0.62, 0.64, 0.66)
	_env.ambient_light_color = Color(0.25, 0.28, 0.4) if noche else Color(0.55, 0.55, 0.55)
	_env.ambient_light_energy = 0.5 if noche else 1.0
	_env.fog_light_color = _env.background_color
	_env.fog_density = 0.03 if noche else 0.008
	_sol.light_energy = 0.05 if noche else 1.0
	# El primer corredor: z = -18 + CORREDOR / 2
	var corredor := -18.0 + Panteon.CORREDOR + 2.0 * Panteon.LARGO + Panteon.CORREDOR / 2.0
	match n:
		0:
			_cam.position = Vector3(-30, 22, 30)
			_cam.look_at(Vector3(0, 0, 0))
		1, 3:
			_cam.position = Vector3(-20, 1.6, corredor)
			_cam.look_at(Vector3(0, 0.9, corredor))
		2:
			_cam.position = Vector3(-14, 1.4, corredor + 0.2)
			_cam.look_at(Vector3(-11.5, 0.5, corredor - 1.2))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode >= KEY_1 and e.keycode <= KEY_4:
			_toma(e.keycode - KEY_1)
		elif e.keycode == KEY_LEFT:
			_cam.rotate_y(0.2)
		elif e.keycode == KEY_RIGHT:
			_cam.rotate_y(-0.2)


func _fotos(dir: String) -> void:
	for n in 4:
		_toma(n)
		for f in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("panteon_%d.png" % n))
		print("toma %d: %d fps" % [n, Engine.get_frames_per_second()])
	get_tree().quit()
