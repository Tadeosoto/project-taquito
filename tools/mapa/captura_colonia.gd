extends SceneTree

# Foto de scenes/mapa.tscn desde donde se diga, para revisar la colonia sin jugarla (necesita
# ventana: abre una un momento).
#   godot --path . -s tools/mapa/captura_colonia.gd -- --captura=C:/x/foto.png --desde=-380,12,470 --hacia=-345,2,404
# Varias fotos de una vez: --vistas=plaza,tianguis,vecindad,avenida (y --carpeta=C:/x)

const ESCENA := "res://scenes/mapa.tscn"
const ESPERA := 45                  # cuadros para que todo se arme y compile
const VISTAS := {
	"plaza": [Vector3(-392.0, 5.0, 446.0), Vector3(-345.0, 3.0, 404.0)],
	"tianguis": [Vector3(-278.0, 2.0, 452.0), Vector3(-279.0, 2.0, 340.0)],
	"vecindad": [Vector3(-229.0, 2.0, 400.0), Vector3(-205.0, 2.0, 400.0)],
	"avenida": [Vector3(-200.0, 4.0, 466.0), Vector3(-330.0, 2.0, 456.0)],
	"arriba": [Vector3(-420.0, 70.0, 500.0), Vector3(-300.0, 0.0, 380.0)],
}


func _initialize() -> void:
	_tomar.call_deferred()


func _tomar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	var escena: Node = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(escena)
	# Sin jugador ni interfaz encima: solo el mundo
	for nombre in ["Player", "Minimapa", "InventoryUI"]:
		var nodo := escena.get_node_or_null(nombre)
		if nodo:
			nodo.process_mode = Node.PROCESS_MODE_DISABLED
			if nodo is Node3D or nodo is CanvasLayer:
				nodo.visible = false
	# La mira de la pistola y demas capas del jugador
	for capa in escena.get_node("Player").find_children("*", "CanvasLayer", true, false):
		(capa as CanvasLayer).visible = false
	# --niebla=0.004: menos niebla para ver de lejos (la del juego es 0.0196)
	if args.has("niebla"):
		var ambiente := (escena.get_node("WorldEnvironment") as WorldEnvironment).environment
		ambiente.fog_density = float(args["niebla"])
	var camara := Camera3D.new()
	camara.far = 600.0
	escena.add_child(camara)
	var fotos := []
	if args.has("vistas"):
		for v in String(args["vistas"]).split(","):
			if VISTAS.has(v):
				fotos.append([VISTAS[v][0], VISTAS[v][1], String(args.get("carpeta", OS.get_user_data_dir())).path_join(v + ".png")])
	else:
		fotos.append([_vec(args.get("desde", "-392,5,446")), _vec(args.get("hacia", "-345,3,404")),
			String(args.get("captura", OS.get_user_data_dir().path_join("colonia.png")))])
	for foto in fotos:
		camara.look_at_from_position(foto[0], foto[1], Vector3.UP)
		camara.make_current()
		for i in ESPERA:
			await process_frame
		var imagen := root.get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(String(foto[2]).get_base_dir())
		imagen.save_png(foto[2])
		print("CAPTURA ", foto[2])
	quit()


func _vec(texto: String) -> Vector3:
	var n := texto.split_floats(",")
	return Vector3(n[0], n[1], n[2])
