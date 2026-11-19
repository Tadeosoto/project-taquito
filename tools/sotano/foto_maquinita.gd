extends Node3D
# Fotos de una maquinita de frutas (scripts/map/Maquinita.gd) sola, para revisar su modelo:
#   godot --path . tools/sotano/foto_maquinita.tscn -- --carpeta=<dir>
# Necesita ventana. Saca frente, tres cuartos y lado, y sale.

var _carpeta := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--carpeta="):
			_carpeta = arg.trim_prefix("--carpeta=")
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.2, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	ambiente.environment = env
	add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sol)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(6, 6)
	piso.mesh = plano
	add_child(piso)
	var m := Maquinita.new()
	m.id = "foto"
	add_child(m)
	var camara := Camera3D.new()
	camara.fov = 45
	add_child(camara)
	camara.make_current()
	await get_tree().create_timer(0.5).timeout
	for vista: Array in [["frente", Vector3(0, 1.5, 3.2)], ["tres_cuartos", Vector3(2.0, 1.7, 2.3)], ["lado", Vector3(3.0, 1.4, 0.3)]]:
		camara.position = vista[1]
		camara.look_at(Vector3(0, 1.25, 0), Vector3.UP)
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		if _carpeta != "":
			get_viewport().get_texture().get_image().save_png(_carpeta.path_join("maquinita_%s.png" % vista[0]))
	get_tree().quit()
