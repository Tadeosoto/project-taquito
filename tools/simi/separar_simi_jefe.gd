extends SceneTree
# El cuerpo del Simi jefe (JJ 2026-11-22): de la copia con retarget (simi_jefe.gltf, esqueleto
# %GeneralSkeleton con los huesos del perfil humanoide) guarda solo la botarga (mallas con skin,
# esqueleto y AnimationPlayer) en simi_jefe.scn, con su baile como "Simi_Baile" en loop.
# tools/personajes/animaciones.gd lo mete a la libreria humana, asi que el jugador y los zombis
# bailan exactamente lo mismo que el Simi.
#
#   python3 -I tools/simi/simi_jefe_gltf.py
#   godot --path . --headless --import
#   godot --path . --headless -s tools/simi/separar_simi_jefe.gd
#   godot --path . --headless -s tools/personajes/animaciones.gd

const MODELO := "res://models/personajes/simi_jefe/simi_jefe.gltf"
const SALIDA := "res://models/personajes/simi_jefe/simi_jefe.scn"
const CLIP := &"Simi_Baile"


func _init() -> void:
	var raiz := (load(MODELO) as PackedScene).instantiate()
	raiz.name = "SimiJefe"
	var quitadas := _quitar_kiosco(raiz)
	var player := raiz.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	var nombre: StringName = library.get_animation_list()[0]
	library.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	library.rename_animation(nombre, CLIP)
	player.autoplay = ""
	for n in raiz.find_children("*", "", true, false):
		n.owner = raiz
	var escena := PackedScene.new()
	escena.pack(raiz)
	var error := ResourceSaver.save(escena, SALIDA)
	print("separar_simi_jefe: %d mallas del kiosco quitadas, %d de la botarga: %s" % [quitadas, raiz.find_children("*", "MeshInstance3D", true, false).size(), error_string(error)])
	raiz.free()
	quit()


# Las mallas sin skin son el kiosco (piso, asiento, letreros)
func _quitar_kiosco(node: Node) -> int:
	var quitadas := 0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).skin == null:
			node.remove_child(child)
			child.free()
			quitadas += 1
			continue
		quitadas += _quitar_kiosco(child)
	return quitadas
