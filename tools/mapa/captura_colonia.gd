extends SceneTree

# Foto de scenes/mapa.tscn desde donde se diga, para revisar la colonia sin jugarla (necesita
# ventana: abre una un momento).
#   godot --path . -s tools/mapa/captura_colonia.gd -- --captura=C:/x/foto.png --desde=-380,12,470 --hacia=-345,2,404
# Varias fotos de una vez: --vistas=plaza,tianguis,vecindad,avenida (y --carpeta=C:/x); --vistas=todas
# toma todas. --hora=noche las toma de noche (con --carpeta, el archivo lleva _noche).

const ESCENA := "res://scenes/mapa.tscn"
const ESPERA := 45                  # cuadros para que todo se arme y compile
const VISTAS := {
	"plaza": [Vector3(-352.0, 7.0, 399.0), Vector3(-367.0, 2.0, 418.0)],
	"tianguis": [Vector3(-278.0, 2.0, 452.0), Vector3(-279.0, 2.0, 340.0)],
	"vecindad": [Vector3(-240.0, 2.5, 372.0), Vector3(-212.0, 2.0, 392.0)],
	"avenida": [Vector3(-200.0, 4.0, 466.0), Vector3(-330.0, 2.0, 456.0)],
	"arriba": [Vector3(-420.0, 70.0, 500.0), Vector3(-300.0, 0.0, 380.0)],
	"reja": [Vector3(-390.0, 3.0, 456.0), Vector3(-420.0, 2.0, 455.0)],
	"escuela": [Vector3(-352.0, 3.0, 398.0), Vector3(-348.0, 4.0, 370.0)],
	"templo": [Vector3(-330.0, 3.0, 468.0), Vector3(-308.0, 6.0, 425.0)],
	"cancha": [Vector3(-398.0, 10.0, 318.0), Vector3(-385.0, 0.0, 300.0)],
	"muralla": [Vector3(-300.0, 9.0, 300.0), Vector3(-300.0, 2.0, 258.0)],
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
	# La mira de la pistola, la barra de vida, el reloj y demas capas; la del tramado se queda
	for capa in escena.find_children("*", "CanvasLayer", true, false):
		if capa.name != "PS1_Postprocess":
			(capa as CanvasLayer).visible = false
	var noche := String(args.get("hora", "dia")) == "noche"
	var ciclo := escena.get_node_or_null("Ciclo")
	if ciclo:
		ciclo.set("_tiempo", (float(ciclo.get("dia_duracion")) + 100.0) if noche else 100.0)
	# --niebla=0.004: menos niebla para ver de lejos (la del juego es 0.0196)
	if args.has("niebla"):
		var ambiente := (escena.get_node("WorldEnvironment") as WorldEnvironment).environment
		ambiente.fog_density = float(args["niebla"])
	var camara := Camera3D.new()
	camara.far = 600.0
	escena.add_child(camara)
	var fotos := []
	if args.has("vistas"):
		var pedidas: Array = VISTAS.keys() if args["vistas"] == "todas" else Array(String(args["vistas"]).split(","))
		for v in pedidas:
			if VISTAS.has(v):
				fotos.append([VISTAS[v][0], VISTAS[v][1], String(args.get("carpeta", OS.get_user_data_dir())).path_join(v + ("_noche" if noche else "") + ".png")])
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
