extends SceneTree

# Parte el mapa importado (models/zona_mapa.glb, ya juntado en cuadros por
# scripts/map/MapPostImport.gd) en una escena por cuadro, para que
# scripts/map/MapStreamer.gd cargue solo los cercanos al jugador.
#
# Uso (despues de importar el .glb):
#   godot --path . --headless -s tools/map_import/split_cuadros.gd
# Salida: resources/map/cuadros/*.scn, materiales/*.res e indice.json

const MAP_SCENE := "res://models/zona_mapa.glb"
const OUT_DIR := "res://resources/map/cuadros"


func _initialize() -> void:
	var map := (load(MAP_SCENE) as PackedScene).instantiate()
	_clean_dir(OUT_DIR)
	_clean_dir(OUT_DIR + "/materiales")

	# Los materiales se guardan aparte para que todos los cuadros compartan el mismo
	var saved := {}
	for mesh_instance in map.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			if material == null or saved.has(material):
				continue
			var path := "%s/materiales/material_%02d.res" % [OUT_DIR, saved.size()]
			_check(ResourceSaver.save(material, path), path)
			material.take_over_path(path)
			saved[material] = path

	var index := []
	for chunk in map.get_children():
		var name := String(chunk.name)  # Cuadro_<x>_<z>[_vegetacion]
		# Lo que ocupa de verdad: una calle larga cae en el cuadro de su centro
		# pero se puede salir mucho de el
		var box: AABB = (chunk as MeshInstance3D).mesh.get_aabb()
		map.remove_child(chunk)
		_own(chunk, chunk)
		var scene := PackedScene.new()
		_check(scene.pack(chunk), name)
		var path := "%s/%s.scn" % [OUT_DIR, name.to_lower()]
		_check(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS), path)
		index.append({
			"archivo": path,
			"min_x": box.position.x, "max_x": box.end.x,
			"min_z": box.position.z, "max_z": box.end.z,
		})
		chunk.free()

	var file := FileAccess.open(OUT_DIR + "/indice.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"cuadros": index}, "\t"))
	file.close()
	map.free()
	print("split_cuadros: %d cuadros y %d materiales en %s" % [index.size(), saved.size(), OUT_DIR])
	quit()


# Los hijos necesitan owner para que PackedScene.pack los guarde
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)


func _clean_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["scn", "res", "tres", "json"]:
			DirAccess.remove_absolute(path + "/" + file)


func _check(error: Error, what: String) -> void:
	if error != OK:
		push_error("split_cuadros: fallo %s (%s)" % [what, error_string(error)])
		quit(1)
