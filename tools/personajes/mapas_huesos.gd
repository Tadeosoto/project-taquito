extends SceneTree
# Los mapas de huesos para el retarget: cada esqueleto (Mixamo del pack PSX, Rigify de la
# Quaternius UAL1, Unreal de la UAL2) a los nombres de SkeletonProfileHumanoid de Godot. Los
# .import de esos modelos los usan (retarget/bone_map), asi que al importar todos quedan con
# los mismos huesos (Hips, Chest, RightUpperArm, RightHand...) en un %GeneralSkeleton y las
# animaciones de Quaternius sirven en los personajes del pack.
#   godot --path . --headless -s tools/personajes/mapas_huesos.gd
#   godot --path . --headless --import

const CARPETA := "res://resources/personajes/"

# Lo que cambia entre esqueletos: [perfil, mixamo, rigify (UAL1), unreal (UAL2)]. "" = no lo tiene
const LADOS := [
	["Shoulder", "mixamorig_%sShoulder", "DEF-shoulder.%s", "clavicle_%s"],
	["UpperArm", "mixamorig_%sArm", "DEF-upper_arm.%s", "upperarm_%s"],
	["LowerArm", "mixamorig_%sForeArm", "DEF-forearm.%s", "lowerarm_%s"],
	["Hand", "mixamorig_%sHand", "DEF-hand.%s", "hand_%s"],
	["ThumbMetacarpal", "", "DEF-thumb.01.%s", "thumb_01_%s"],
	["ThumbProximal", "", "DEF-thumb.02.%s", "thumb_02_%s"],
	["ThumbDistal", "", "DEF-thumb.03.%s", "thumb_03_%s"],
	["IndexProximal", "mixamorig_%sHandIndex1", "DEF-f_index.01.%s", "index_01_%s"],
	["IndexIntermediate", "mixamorig_%sHandIndex2", "DEF-f_index.02.%s", "index_02_%s"],
	["IndexDistal", "mixamorig_%sHandIndex3", "DEF-f_index.03.%s", "index_03_%s"],
	["MiddleProximal", "", "DEF-f_middle.01.%s", "middle_01_%s"],
	["MiddleIntermediate", "", "DEF-f_middle.02.%s", "middle_02_%s"],
	["MiddleDistal", "", "DEF-f_middle.03.%s", "middle_03_%s"],
	["RingProximal", "", "DEF-f_ring.01.%s", "ring_01_%s"],
	["RingIntermediate", "", "DEF-f_ring.02.%s", "ring_02_%s"],
	["RingDistal", "", "DEF-f_ring.03.%s", "ring_03_%s"],
	["LittleProximal", "", "DEF-f_pinky.01.%s", "pinky_01_%s"],
	["LittleIntermediate", "", "DEF-f_pinky.02.%s", "pinky_02_%s"],
	["LittleDistal", "", "DEF-f_pinky.03.%s", "pinky_03_%s"],
	["UpperLeg", "mixamorig_%sUpLeg", "DEF-thigh.%s", "thigh_%s"],
	["LowerLeg", "mixamorig_%sLeg", "DEF-shin.%s", "calf_%s"],
	["Foot", "mixamorig_%sFoot", "DEF-foot.%s", "foot_%s"],
	["Toes", "mixamorig_%sToeBase", "DEF-toe.%s", "ball_%s"],
]
const CENTRO := [
	["Root", "", "root", "root"],
	["Hips", "mixamorig_Hips", "DEF-hips", "pelvis"],
	["Spine", "mixamorig_Spine", "DEF-spine.001", "spine_01"],
	["Chest", "mixamorig_Spine1", "DEF-spine.002", "spine_02"],
	["UpperChest", "mixamorig_Spine2", "DEF-spine.003", "spine_03"],
	["Neck", "mixamorig_Neck", "DEF-neck", "neck_01"],
	["Head", "mixamorig_Head", "DEF-head", "Head"],
]
# [archivo, columna, como se escribe el lado izquierdo y el derecho]
const MAPAS := [
	["huesos_mixamo.tres", 1, ["Left", "Right"]],
	["huesos_rigify.tres", 2, ["L", "R"]],
	["huesos_unreal.tres", 3, ["l", "r"]],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	for mapa: Array in MAPAS:
		var huesos := BoneMap.new()
		huesos.profile = SkeletonProfileHumanoid.new()
		var columna: int = mapa[1]
		for fila: Array in CENTRO:
			if fila[columna] != "":
				huesos.set_skeleton_bone_name(fila[0], fila[columna])
		for i in 2:
			var perfil_lado: String = ["Left", "Right"][i]
			var lado: String = mapa[2][i]
			for fila: Array in LADOS:
				if fila[columna] != "":
					huesos.set_skeleton_bone_name(perfil_lado + fila[0], (fila[columna] as String) % lado)
		var ruta: String = CARPETA + mapa[0]
		var error := ResourceSaver.save(huesos, ruta)
		print(ruta, ": ", error_string(error))
	quit()
