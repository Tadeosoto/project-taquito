extends SceneTree
# Junta en una AnimationLibrary las animaciones de Quaternius (UAL1 y UAL2, CC0) que usa el
# protagonista, ya con los huesos de SkeletonProfileHumanoid (tools/personajes/mapas_huesos.gd).
# Quita las pistas de huesos que el protagonista no tiene (Root, casi todos los dedos), que
# llenaban la consola de avisos. scripts/character_animation.gd la carga.
#   godot --path . --headless -s tools/personajes/animaciones.gd
#   godot --path . --headless --import

const SALIDA := "res://resources/personajes/animaciones_humanas.res"
const MODELO := "res://models/personajes/protagonistas/el_compa/el_compa.fbx"
const FUENTES := [
	"res://models/animaciones/quaternius_ual1/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb",
	"res://models/animaciones/quaternius_ual2/Universal Animation Library 2 [Standard]/Unreal-Godot/UAL2_Standard.glb",
	# La version Source de UAL2 (CC0), al final: solo aporta lo que las Standard no traen
	"res://models/animaciones/quaternius_ual2_source/UAL2_Source.glb",
	# La Source de UAL1 (CC0, de nooneisreal): trae Drink, que usa Player._curarse
	"res://models/animaciones/quaternius_ual1_source/UAL1_Source.glb",
]
const CLIPS := [
	# Andar
	"Idle", "Walk", "Jog_Fwd", "Sprint", "Walk_Carry", "Jump", "Jump_Start", "Jump_Land",
	# Machete
	"Sword_Idle", "Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Sword_Attack", "Sword_Dash_RM",
	"Sword_Block", "Sword_Regular_A_Rec", "Sword_Regular_B_Rec",
	# A mano limpia
	"Punch_Jab", "Punch_Cross", "Punch_Enter", "Melee_Hook", "Melee_Hook_Rec",
	# Pistola
	"Pistol_Idle", "Pistol_Aim_Up", "Pistol_Aim_Neutral", "Pistol_Aim_Down", "Pistol_Shoot", "Pistol_Reload",
	# Zombis normales (scripts/map/Zombie.gd)
	"Zombie_Idle", "Zombie_Walk_Fwd", "Zombie_Scratch",
	# Lo demas
	"Punch_Jab", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01", "PickUp_Table", "Consume",
	"Interact", "Sitting_Enter", "Sitting_Idle", "Sitting_Exit", "Idle_Talking", "Roll",
	# El punado de sal (Player.aventar_sal), de UAL2 Source
	"Sword_Heavy_A",
	# La molotov (Player.aventar_molotov)
	"OverhandThrow",
	# Curarse (Q), de UAL1 Source
	"Drink",
	# Zombi aturdido por la palomita (Zombie.aturdir): se tapa la cara, de UAL1 Source
	"Crying",
]


func _init() -> void:
	var modelo := (load(MODELO) as PackedScene).instantiate()
	var esqueleto := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var tiene := {}
	for i in esqueleto.get_bone_count():
		tiene[esqueleto.get_bone_name(i)] = true
	modelo.free()
	var biblioteca := AnimationLibrary.new()
	for ruta: String in FUENTES:
		var escena := (load(ruta) as PackedScene).instantiate()
		var reproductor := escena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for nombre: StringName in reproductor.get_animation_list():
			if not nombre in CLIPS or biblioteca.has_animation(nombre):
				continue
			var animacion := reproductor.get_animation(nombre).duplicate(true) as Animation
			var quitadas := 0
			for pista in range(animacion.get_track_count() - 1, -1, -1):
				var hueso := animacion.track_get_path(pista).get_concatenated_subnames()
				if not tiene.has(hueso):
					animacion.remove_track(pista)
					quitadas += 1
			biblioteca.add_animation(nombre, animacion)
			print("  %-20s %.2f s, %d pistas (%d quitadas)" % [nombre, animacion.length, animacion.get_track_count(), quitadas])
		escena.free()
	for nombre in CLIPS:
		if not biblioteca.has_animation(nombre):
			push_warning("No se encontro " + nombre)
	print(SALIDA, ": ", error_string(ResourceSaver.save(biblioteca, SALIDA)))
	quit()
