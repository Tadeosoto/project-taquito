extends SceneTree

# El modelo "Farmica Similares Dr Simi" (models/personajes/dr_simi) trae el
# kiosco de Similares y la botarga del Simi con esqueleto de Mixamo y un baile
# de 15 s. Esto guarda solo la botarga (mallas con skin + Skeleton3D +
# AnimationPlayer) en models/personajes/dr_simi/simi_botarga.scn, con el baile
# en loop como "bailar".
#
#   godot --path . --headless -s tools/map_import/separar_simi.gd
#
# Necesita el original (scene.gltf, en el .gitignore: bajarlo con
# fetch_sketchfab.py). Correrlo otra vez si cambia el import del modelo (TiendaPostImport).

const MODELO := "res://models/personajes/dr_simi/scene.gltf"
const SALIDA := "res://models/personajes/dr_simi/simi_botarga.scn"


func _init() -> void:
	var raiz := (load(MODELO) as PackedScene).instantiate()
	raiz.name = "SimiBotarga"
	var quitadas := _quitar_kiosco(raiz)
	var players := raiz.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		var player := players[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var nombre: StringName = library.get_animation_list()[0]
		library.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
		library.rename_animation(nombre, &"bailar")
		player.autoplay = "bailar"
	var escena := PackedScene.new()
	escena.pack(raiz)
	ResourceSaver.save(escena, SALIDA)
	print("separar_simi: %d mallas del kiosco quitadas, %d de la botarga" % [quitadas, raiz.find_children("*", "MeshInstance3D", true, false).size()])
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
