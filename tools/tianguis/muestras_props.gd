extends SceneTree

# Hoja de muestras de piezas sueltas (un nodo de una escena) para escoger las del tianguis.
#   godot --path . -s tools/tianguis/muestras_props.gd -- --salida=/x/props.png

const Piezas := preload("res://scripts/map/TianguisPiezas.gd")

const LISTA := [
	["tacos", "Table"], ["tacos", "Chair"], ["tacos", "bucket"], ["tacos", "Soda_Box"], ["tacos", "Soda_Box_01"],
	["tacos", "Soda_Box_02"], ["tacos", "Soda_001"], ["tacos", "Sauce"], ["tacos", "Plates"], ["tacos", "Meat"],
	["tacos", "Onion_Coriander"], ["tacos", "Plate_Limon"], ["tacos", "plastic_bag_P"], ["tacos", "Napkins"],
	["tacos", "Disposable_cups"], ["tacos", "disposable_plates"], ["tacos", "shepherd_spinning"], ["tacos", "gas_tank"],
	["tacos", "Refrigerator"], ["tacos", "trash_can"], ["tacos", "Board"], ["tacos", "Oil"],
	["fruta", "Box"], ["fruta", "Shelve"], ["silla", ""], ["cajas", ""], ["mesa", ""], ["estante", ""],
]


func _initialize() -> void:
	_tomar.call_deferred()


func _tomar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	# SubViewport propio: el proyecto estira todo a 640x480
	var vista := SubViewport.new()
	vista.size = Vector2i(1800, 1200)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.own_world_3d = true
	root.add_child(vista)
	var mundo := Node3D.new()
	vista.add_child(mundo)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	mundo.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	mundo.add_child(sol)
	var cols := 7
	for i in LISTA.size():
		var celda := Vector3((i % cols) * 2.2, 0, (i / cols) * 2.6)
		var pieza: Node3D = Piezas.pieza(LISTA[i][0], LISTA[i][1])
		if pieza == null:
			continue
		var caja := Piezas.caja_de(pieza)
		var s := 1.6 / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
		pieza.scale = Vector3.ONE * minf(s, 1.0) if caja.size.length() > 1.8 else Vector3.ONE
		pieza.position = celda
		mundo.add_child(pieza)
		var l := Label3D.new()
		l.text = "%s %s\n%.2f x %.2f x %.2f" % [LISTA[i][0], LISTA[i][1], caja.size.x, caja.size.y, caja.size.z]
		l.font_size = 40
		l.pixel_size = 0.004
		l.position = celda + Vector3(0, -0.15, 0.9)
		l.rotation_degrees.x = -45
		mundo.add_child(l)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.look_at_from_position(Vector3(6.6, 9.5, 14.5), Vector3(6.6, 0, 4.5), Vector3.UP)
	cam.fov = 60
	cam.make_current()
	for i in 30:
		await process_frame
	vista.get_texture().get_image().save_png(String(args.get("salida", "user://props.png")))
	print("LISTO")
	quit()
