extends SceneTree

# Lista las mallas de las escenas dadas con su tamano, para escoger piezas para el tianguis.
#   godot --path . --headless -s tools/tianguis/inventario_props.gd -- res://a.scn res://b.scn

func _initialize() -> void:
	_listar.call_deferred()


func _listar() -> void:
	await process_frame
	for ruta in OS.get_cmdline_user_args():
		var raiz: Node3D = (load(ruta) as PackedScene).instantiate()
		root.add_child(raiz)
		print("== ", ruta)
		var n := 0
		for m in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b := (raiz.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			n += 1
			if n <= 200:
				print("  %-60s tam %s  en %s" % [str(raiz.get_path_to(mi)).right(60), b.size.snappedf(0.01), b.get_center().snappedf(0.01)])
		print("  (", n, " mallas)")
		raiz.queue_free()
	quit()
