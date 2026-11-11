extends SceneTree

# Saca versiones ligeras de las mallas muy pesadas que usa el tianguis (la mesa de patas
# torneadas trae 24 mil triangulos, el cloralex casi 2 mil) y escribe models/tianguis/ligeras/
# ligeras.json, que Tianguis.gd lee al hornear. Se corre otra vez si se agregan piezas a GIROS:
#   godot --path . --headless -s tools/tianguis/aligerar_piezas.gd

const CARPETA := "res://models/tianguis/ligeras/"
const PESADA := 600         # triangulos desde los que se aligera una superficie
const META := 400           # triangulos a los que se quiere llegar (o lo mas cerca)


func _initialize() -> void:
	_aligerar.call_deferred()


func _tris(arr: Array) -> int:
	var idx = arr[Mesh.ARRAY_INDEX]
	return (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3


func _aligerar() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	# Un tramo largo sin hornear, con varias semillas para que salga de todo
	var pesadas := {}
	for semilla in [1, 2, 3]:
		var t := Tianguis.new()
		t.semilla = semilla
		t.largo = 200.0
		t.gente = false
		t.hornear = false
		root.add_child(t)
		for m in t.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or mi.mesh is PrimitiveMesh:
				continue
			for s in mi.mesh.get_surface_count():
				if _tris(mi.mesh.surface_get_arrays(s)) > PESADA:
					pesadas[Tianguis.clave_malla(mi.mesh, s)] = [mi.mesh, s]
		t.free()
	var mapa := {}
	for clave: String in pesadas:
		var malla: Mesh = pesadas[clave][0]
		var s: int = pesadas[clave][1]
		var arr := malla.surface_get_arrays(s)
		if arr[Mesh.ARRAY_INDEX] == null:
			continue
		var im := ImporterMesh.new()
		im.add_surface(malla.surface_get_primitive_type(s), arr, [], {}, malla.surface_get_material(s))
		im.generate_lods(25.0, 60.0, [])
		var mejor: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for l in im.get_surface_lod_count(0):
			var indices := im.get_surface_lod_indices(0, l)
			mejor = indices
			if indices.size() / 3 <= META:
				break
		var nueva := arr.duplicate()
		nueva[Mesh.ARRAY_INDEX] = mejor
		var ligera := ArrayMesh.new()
		ligera.add_surface_from_arrays(malla.surface_get_primitive_type(s), nueva)
		ligera.surface_set_material(0, malla.surface_get_material(s))
		var nombre := clave.get_file().validate_filename().replace("#", "_").replace("::", "_") + ".res"
		ResourceSaver.save(ligera, CARPETA + nombre, ResourceSaver.FLAG_COMPRESS)
		mapa[clave] = CARPETA + nombre
		print("LIGERA %s: %d -> %d triangulos" % [clave, _tris(arr), mejor.size() / 3])
	var f := FileAccess.open(CARPETA + "ligeras.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(mapa, "\t") + "\n")
	quit()
