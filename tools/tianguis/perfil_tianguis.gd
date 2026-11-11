extends SceneTree

# Cuanto pesa cada cosa del tianguis en el mapa: triangulos por MultiMesh horneado (malla x
# instancias) y de la gente que esta armada cerca del jugador. Necesita ventana:
#   godot --path . -s tools/tianguis/perfil_tianguis.gd

func _initialize() -> void:
	_medir.call_deferred()


func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _medir() -> void:
	var escena: Node = (load("res://scenes/mapa.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	(escena.get_node("Player") as Node3D).global_position = Vector3(-278.0, 1.2, 400.0)
	for i in 240:
		await process_frame
	var filas := []
	var total := 0
	for t in escena.find_children("Tianguis_*", "Node3D", true, false):
		for c in t.get_children():
			if c is MultiMeshInstance3D:
				var mm := (c as MultiMeshInstance3D).multimesh
				var n := _tris(mm.mesh) * mm.instance_count
				total += n
				filas.append([n, "%s x%d (%d tris) %s" % [mm.mesh.resource_name if mm.mesh.resource_name else str(mm.mesh), mm.instance_count, _tris(mm.mesh), c.material_override.resource_name if c.material_override else ""]])
	filas.sort_custom(func(a, b): return a[0] > b[0])
	print("PERFIL horneado: %d tris en %d multimeshes" % [total, filas.size()])
	for f in filas.slice(0, 25):
		print("PERFIL  ", f[0], "  ", f[1])
	var gente := 0
	var n_gente := 0
	var vistos := {}
	for t in escena.find_children("Tianguis_*", "Node3D", true, false):
		for e in t.get("_gente"):
			if e["nodo"] != null:
				n_gente += 1
				for m in (e["nodo"] as Node).find_children("*", "MeshInstance3D", true, false):
					gente += _tris((m as MeshInstance3D).mesh)
	print("PERFIL gente: %d civiles armados, %d tris" % [n_gente, gente])
	var sueltos := 0
	for t in escena.find_children("Tianguis_*", "Node3D", true, false):
		for n in t.get("_de_dia"):
			if not (n is MultiMeshInstance3D):
				for m in (n as Node).find_children("*", "MeshInstance3D", true, false):
					sueltos += _tris((m as MeshInstance3D).mesh)
	print("PERFIL sueltos (carritos): %d tris" % sueltos)
	quit()
