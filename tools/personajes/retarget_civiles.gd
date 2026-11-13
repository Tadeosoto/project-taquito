extends SceneTree
# Pone el retarget (como el de el_compa) en los .import de los civiles del pack PSX
# (hombre_*, mujer_* y los policia_* de los cuicos) y en los monstruos de EXTRA, para que queden con un %GeneralSkeleton de SkeletonProfileHumanoid y
# les sirvan las animaciones de Quaternius (resources/personajes/animaciones_humanas.res).
# Los usa scripts/personajes/Civiles.gd. Se puede correr otra vez: los ya puestos no cambian.
#   godot --path . --headless -s tools/personajes/retarget_civiles.gd
#   godot --path . --headless --import

const CARPETA := "res://models/personajes/pack_psx/"
const PREFIJOS := ["hombre_", "mujer_", "policia_"]
# Los zombis normales (scripts/map/Zombie.gd): solo estos monstruos, el 04 y el 05 no
const EXTRA := ["monstruo_00", "monstruo_01", "monstruo_02", "monstruo_03"]
const RETARGET := """_subresources={
"nodes": {
"PATH:Skeleton3D": {
"retarget/bone_map": Resource("res://resources/personajes/huesos_mixamo.tres"),
"retarget/rest_fixer/fix_silhouette/enable": true
}
}
}"""


func _init() -> void:
	var cambiados := 0
	for carpeta in DirAccess.get_directories_at(CARPETA):
		if not carpeta in EXTRA and not PREFIJOS.any(func(p: String) -> bool: return carpeta.begins_with(p)):
			continue
		var ruta := CARPETA + carpeta + "/" + carpeta + ".fbx.import"
		var texto := FileAccess.get_file_as_string(ruta)
		if texto == "":
			push_warning("No se pudo leer " + ruta)
			continue
		if texto.contains("retarget/bone_map"):
			continue
		if not texto.contains("_subresources={}"):
			push_warning("%s: _subresources ya trae otra cosa, no lo toco" % ruta)
			continue
		var archivo := FileAccess.open(ruta, FileAccess.WRITE)
		archivo.store_string(texto.replace("_subresources={}", RETARGET))
		archivo.close()
		cambiados += 1
	print("Civiles con retarget nuevo: ", cambiados)
	quit()
