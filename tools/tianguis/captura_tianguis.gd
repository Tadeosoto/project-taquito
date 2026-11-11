extends SceneTree

# Fotos del borrador del tianguis (scenes/tianguis_borrador.tscn) sin jugarlo; necesita ventana.
#   godot --path . -s tools/tianguis/captura_tianguis.gd -- --carpeta=/ruta [--semilla=7]

const ESCENA := "res://scenes/tianguis_borrador.tscn"
const ESPERA := 40
const VISTAS := {
	"pasillo": [Vector3(-17.0, 1.65, 0.1), Vector3(0.0, 1.5, 0.0)],
	"pasillo_vuelta": [Vector3(12.0, 1.65, -0.3), Vector3(-5.0, 1.4, 0.4)],
	"banqueta": [Vector3(-14.0, 1.7, 4.7), Vector3(2.0, 1.5, 3.2)],
	"puestos_a": [Vector3(-8.0, 1.6, -0.6), Vector3(-6.0, 1.0, 3.5)],
	"puestos_b": [Vector3(4.0, 1.6, 0.6), Vector3(6.0, 1.0, -3.5)],
	"puestos_c": [Vector3(-2.0, 1.6, -0.6), Vector3(0.0, 1.0, 3.5)],
	"puestos_d": [Vector3(12.0, 1.6, 0.6), Vector3(14.0, 1.0, -3.5)],
	"arriba": [Vector3(0.0, 30.0, 0.01), Vector3(0.0, 0.0, 0.0)],
	"aerea": [Vector3(-27.0, 9.0, 3.0), Vector3(0.0, 1.0, 0.0)],
}


func _initialize() -> void:
	_tomar.call_deferred()


func _tomar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	var escena: Node = (load(ESCENA) as PackedScene).instantiate()
	if args.has("semilla"):
		escena.get_node("Tianguis").semilla = int(args["semilla"])
	if args.has("sin_gente"):
		escena.get_node("Tianguis").gente = false
	root.add_child(escena)
	var jugador := escena.get_node_or_null("Player")
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_DISABLED
		jugador.visible = false
		for capa in jugador.find_children("*", "CanvasLayer", true, false):
			(capa as CanvasLayer).visible = false
	var camara := Camera3D.new()
	camara.fov = 70.0
	escena.add_child(camara)
	# Una foto de frente a cada giro que se pida (--giros=tacos,tejuino): el primer puesto de ese giro
	var vistas := VISTAS.duplicate()
	for g in String(args.get("giros", "")).split(",", false):
		for p in escena.find_children("Puesto_*", "Node3D", true, false):
			if p.get_meta("giro", "") == g:
				var frente: Vector3 = p.global_transform * Vector3(0.6, 1.5, -4.2)
				vistas["giro_" + g] = [frente, p.global_transform * Vector3(0, 0.9, -1.2)]
				break
	var carpeta := String(args.get("carpeta", OS.get_user_data_dir()))
	DirAccess.make_dir_recursive_absolute(carpeta)
	var solo := String(args.get("solo", ""))
	for v in vistas:
		if solo != "" and not v.begins_with(solo):
			continue
		camara.look_at_from_position(vistas[v][0], vistas[v][1], Vector3.UP if v != "arriba" else Vector3.FORWARD)
		camara.make_current()
		for i in ESPERA:
			await process_frame
		var ruta := carpeta.path_join(v + ".png")
		root.get_viewport().get_texture().get_image().save_png(ruta)
		print("CAPTURA ", ruta)
	quit()
