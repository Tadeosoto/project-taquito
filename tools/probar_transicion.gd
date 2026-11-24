extends Node3D

# Los de en medio de las cañerías (Transicion.gd, JJ 2026-11-21): los cinco, cada uno en una de sus
# tres cosas (parado en pose de zombi, caminando despacio o sentado en posicion fetal).
#   godot --path . tools/probar_transicion.tscn
#   godot --path . tools/probar_transicion.tscn -- --fotos=<carpeta>   (capturas y sale)
# 1: todos; 2-6: la cara de cada uno (parados, para verla); 7: de espaldas. Flechas: girar.

# modelo, que hace, rasgado, grietas
const CINCO := [
	["hombre_03", "Zombie_Idle", 0.5, 0.65],
	["mujer_05", "Zombie_Walk_Fwd", 0.6, 0.6],
	["policia_17", "Zombie_Idle", 0.45, 0.7],
	["mujer_30", "Fetal", 0.5, 0.55],
	["hombre_12", "Zombie_Walk_Fwd", 0.65, 0.75],
]

var _cam: Camera3D
var _ellos: Array[Node3D] = []      # como estan (cada uno en lo suyo)
var _caras: Array[Node3D] = []      # los mismos, parados, para la foto de la cara


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 0.9
	luz.light_color = Color(1.0, 0.92, 0.82)
	add_child(luz)
	luz.rotation_degrees = Vector3(-30, 160, 0)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(14, 10)
	piso.mesh = plano
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.22, 0.21, 0.2)
	piso.material_override = mp
	add_child(piso)
	for i in CINCO.size():
		var d: Array = CINCO[i]
		var h := Transicion.humano(d[0], float(i) * 3.1, d[2], d[3], d[1])
		add_child(h)
		h.position = Vector3((i - 2) * 1.0, 0, 0)
		_ellos.append(h)
		var c := Transicion.humano(d[0], float(i) * 3.1, d[2], d[3], "Zombie_Idle")
		add_child(c)
		c.position = Vector3((i - 2) * 1.0, 0, 4.0)
		_caras.append(c)
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_cam.current = true
	_toma(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			_fotos(arg.trim_prefix("--fotos="))


func _toma(n: int) -> void:
	for h in _ellos:
		h.visible = n == 0 or n == 6
	for i in _caras.size():
		_caras[i].visible = n == i + 1
	_cam.fov = 45
	match n:
		0:
			_cam.position = Vector3(0, 1.3, -4.2)
			_cam.rotation_degrees = Vector3(-8, 180, 0)
		6:
			_cam.position = Vector3(0, 1.3, 4.2)
			_cam.rotation_degrees = Vector3(-8, 0, 0)
		_:
			# Apunta a los ojos (el BoneAttachment3D de Transicion.poner_ojos), desde enfrente y abajo
			var pegado := _caras[n - 1].find_children("*", "BoneAttachment3D", true, false)[0] as Node3D
			var ojos := pegado.global_position
			_cam.position = ojos + Vector3(0, -0.2, -0.65)
			_cam.look_at(ojos, Vector3.UP)
			_cam.fov = 35


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode >= KEY_1 and e.keycode <= KEY_7:
			_toma(e.keycode - KEY_1)
		elif e.keycode == KEY_LEFT:
			rotation_degrees.y -= 20
		elif e.keycode == KEY_RIGHT:
			rotation_degrees.y += 20


func _fotos(dir: String) -> void:
	for n in 7:
		_toma(n)
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("enmedio_%d.png" % n))
		print("toma %d: %d fps" % [n, Engine.get_frames_per_second()])
	get_tree().quit()
