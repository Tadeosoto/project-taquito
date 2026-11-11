extends SceneTree
## Pasa el tinaco negro de Sketchfab (models/props/tinaco/, solo esta como .scn de Godot) a un .glb
## que Blender puede leer, para el tinaco de la azotea de casa_psm.py:
##   godot --path . --headless -s tools/blender/mapa/exportar_tinaco.gd
## Queda en tools/blender/cache/tinaco.glb (no se versiona).

const SALIDA := "res://tools/blender/cache/tinaco.glb"


func _init() -> void:
	var raiz: Node3D = load("res://models/props/tinaco/tinaco.scn").instantiate()
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var error := doc.append_from_scene(raiz, estado)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA).get_base_dir())
		error = doc.write_to_filesystem(estado, SALIDA)
	print("tinaco.glb: ", error_string(error))
	raiz.free()
	quit(error)
