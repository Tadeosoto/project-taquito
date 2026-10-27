extends SceneTree

# Guarda cada modelo de Sketchfab ya importado (reducido y con el shader PS1 de
# TiendaPostImport) como models/<grupo>/<modelo>/<modelo>.scn, con las mallas,
# esqueletos y animaciones adentro. El juego usa esa .scn; los originales
# (scene.gltf + scene.bin) van en el .gitignore y se vuelven a bajar con
# fetch_sketchfab.py solo si hay que cambiar la reduccion o los materiales.
# Las texturas (textures/, 256 px) se quedan como archivos aparte.
#
#   godot --path . --headless --import
#   godot --path . --headless -s tools/map_import/hornear_modelos.gd
#
# Solo hornea los modelos cuyo scene.gltf existe (los demas se saltan). Las
# mallas se guardan sin los LOD que genera el import (son modelos chicos y
# triplicaban el tamano) y el archivo va comprimido.

const GRUPOS := ["tiendas", "casas", "props", "objetos", "personajes", "armas", "interiores"]


func _init() -> void:
	var hechos := 0
	for grupo in GRUPOS:
		var base := "res://models/%s/" % grupo
		for modelo in DirAccess.get_directories_at(base):
			var origen := base + modelo + "/scene.gltf"
			if not FileAccess.file_exists(origen):
				continue
			var escena := load(origen) as PackedScene
			if escena == null:
				push_error("hornear_modelos: no se pudo cargar " + origen)
				continue
			var raiz := escena.instantiate()
			raiz.name = modelo
			_quitar_lods(raiz)
			var horneada := PackedScene.new()
			horneada.pack(raiz)
			var salida := base + modelo + "/" + modelo + ".scn"
			# Las .scn binarias se guardan sin uid: se le pone uno (el mismo si ya
			# existia, para no romper las escenas que la usan)
			var uid := ResourceLoader.get_resource_uid(salida) if FileAccess.file_exists(salida) else ResourceUID.INVALID_ID
			if uid == ResourceUID.INVALID_ID:
				uid = ResourceUID.create_id()
			var error := ResourceSaver.save(horneada, salida, ResourceSaver.FLAG_COMPRESS)
			raiz.free()
			if error != OK:
				push_error("hornear_modelos: error %d al guardar %s" % [error, salida])
				continue
			ResourceSaver.set_uid(salida, uid)
			hechos += 1
			print("%s %s" % [ResourceUID.id_to_text(ResourceLoader.get_resource_uid(salida)), salida])
	print("hornear_modelos: %d modelos" % hechos)
	quit()


# Rehace cada ArrayMesh con sus superficies, materiales y blend shapes, sin LODs
func _quitar_lods(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
		var origen := (node as MeshInstance3D).mesh as ArrayMesh
		var limpia := ArrayMesh.new()
		limpia.blend_shape_mode = origen.blend_shape_mode
		for forma in origen.get_blend_shape_count():
			limpia.add_blend_shape(origen.get_blend_shape_name(forma))
		for surface in origen.get_surface_count():
			limpia.add_surface_from_arrays(origen.surface_get_primitive_type(surface),
				origen.surface_get_arrays(surface), origen.surface_get_blend_shape_arrays(surface), {},
				origen.surface_get_format(surface) & ~Mesh.ARRAY_FORMAT_VERTEX & ~Mesh.ARRAY_FORMAT_INDEX)
			limpia.surface_set_material(surface, origen.surface_get_material(surface))
			limpia.surface_set_name(surface, origen.surface_get_name(surface))
		(node as MeshInstance3D).mesh = limpia
	for child in node.get_children():
		_quitar_lods(child)
