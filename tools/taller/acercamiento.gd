extends SceneTree

# Foto de cerca de un pedazo de un modelo (las capturas de capturas.gd encuadran todo el modelo).
#   godot --path . -s tools/taller/acercamiento.gd -- --escena=res://models/taller/x/x.scn --mira=-0.07,0,0 --dist=0.14 [--dir=0,0,1] --salida=/ruta.png

func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var par := arg.trim_prefix("--").split("=", true, 1)
		args[par[0]] = par[1] if par.size() > 1 else ""
	var raiz := Node3D.new()
	root.add_child(raiz)
	raiz.add_child((load(args["escena"]) as PackedScene).instantiate())
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.9, 0.6, 0.0)
	raiz.add_child(luz)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.48, 0.6, 0.72)
	entorno.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	raiz.add_child(entorno)
	var m := (args.get("mira", "0,0,0") as String).split_floats(",")
	var mira := Vector3(m[0], m[1], m[2])
	var camara := Camera3D.new()
	camara.near = 0.005
	raiz.add_child(camara)
	for i in 2:
		await process_frame
	var d := (args.get("dir", "0.4,0.5,1") as String).split_floats(",")
	camara.look_at_from_position(mira + Vector3(d[0], d[1], d[2]).normalized() * float(args.get("dist", "0.2")), mira)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(args["salida"])
	print("ok ", args["salida"])
	quit()
