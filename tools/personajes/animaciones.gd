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
	# El baile del Simi jefe (tools/simi/separar_simi_jefe.gd): lo bailan el, los zombis y tu
	"res://models/personajes/simi_jefe/simi_jefe.scn",
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
	# El punado de sal (Player.aventar_sal), de UAL2 Source; tambien el primer golpe del marro
	"Sword_Heavy_A",
	# El combo del marro y las armas pesadas (Fase T, JJ 2026-11-25), de UAL2 Source: A, B y C con
	# sus regresos (el giro y el dash siguen siendo los del machete)
	"Sword_Heavy_B", "Sword_Heavy_C", "Sword_Heavy_A_Rec", "Sword_Heavy_B_Rec", "Sword_Heavy_C_Rec",
	# La molotov (Player.aventar_molotov)
	"OverhandThrow",
	# Curarse (Q), de UAL1 Source
	"Drink",
	# Zombi aturdido por la palomita (Zombie.aturdir): se tapa la cara, de UAL1 Source
	"Crying",
	# El Simi jefe (scripts/simi/): su baile y su patada (UAL1 Source)
	"Simi_Baile", "Kick",
	# Salir volando por un golpe fuerte (Player._salir_volando), de UAL2 Source: te avienta, vuelas,
	# azotas de espaldas y te levantas
	"LiftAir", "LiftAir_Fall_Air", "LiftAir_Fall_Impact", "LayToIdle",
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
	var baile := biblioteca.get_animation("Simi_Baile")
	biblioteca.add_animation(BAILE_HUMANO, _baile_humano(baile, biblioteca.get_animation("Idle")))
	_al_piso(baile, SIMI)
	print(SALIDA, ": ", error_string(ResourceSaver.save(biblioteca, SALIDA)))
	quit()


# El baile del Simi (Sketchfab, otro esqueleto) no pisa el piso al pasarlo a la libreria.
# - En el esqueleto del Simi la cadera esta a 0.06 del origen y los pies 0.37 abajo, asi que su
#   pista de posicion de Hips (normalizada por motion_scale = altura de la cadera sobre el origen)
#   trae cada movimiento multiplicado por ~7 para un cuerpo con el origen en el piso: el
#   protagonista y los zombis se hundian hasta la cintura. Simi_Baile_H lo mide contra la altura
#   cadera-pies de cada esqueleto.
# - Aun asi, al doblar las piernas los pies se despegaban (hasta 19 cm en el compa, 50 cm en el
#   Simi de 7 m). `_al_piso` sube o baja la cadera en cada cuadro para que el pie mas bajo quede
#   donde pisa parado (el Idle para los humanos: Quaternius baja la cadera 5 % del reposo; el
#   reposo para el Simi), calculando la pose de las piernas en el esqueleto de quien lo baila.
const BAILE_HUMANO := &"Simi_Baile_H"
const SIMI := "res://models/personajes/simi_jefe/simi_jefe.scn"
const PIES := ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]


func _baile_humano(original: Animation, parado: Animation) -> Animation:
	var simi := _medir(SIMI)
	var humano := _medir(MODELO)
	var factor: float = (simi.escala / simi.alto) / (humano.escala / humano.alto)
	var reposo: Vector3 = simi.reposo / simi.escala
	var animacion := original.duplicate(true) as Animation
	var pista := _pista(animacion, "Hips", Animation.TYPE_POSITION_3D)
	for k in animacion.track_get_key_count(pista):
		var v: Vector3 = animacion.track_get_key_value(pista, k)
		animacion.track_set_key_value(pista, k, Vector3.UP + (v - reposo) * factor)
	print("  %-20s cadera x%.3f" % [BAILE_HUMANO, factor])
	_al_piso(animacion, MODELO, parado)
	return animacion


# motion_scale, reposo de Hips y altura de la cadera sobre el pie mas bajo, en reposo
func _medir(ruta: String) -> Dictionary:
	var escena := (load(ruta) as PackedScene).instantiate()
	var sk := escena.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var cadera := sk.get_bone_global_rest(sk.find_bone("Hips")).origin
	var medida := {"escala": sk.motion_scale, "reposo": cadera, "alto": cadera.y - _pie_mas_bajo(sk, {})}
	escena.free()
	return medida


func _pista(animacion: Animation, hueso: String, tipo: int) -> int:
	for p in animacion.get_track_count():
		if animacion.track_get_type(p) == tipo and animacion.track_get_path(p).get_concatenated_subnames() == hueso:
			return p
	return -1


# Pone la pose del clip en `t` (rotaciones y posiciones; la de Hips es `cadera`, normalizada)
func _pose(animacion: Animation, sk: Skeleton3D, t: float, cadera: Vector3) -> Dictionary:
	var poses := {}
	for i in sk.get_bone_count():
		var nombre := sk.get_bone_name(i)
		var local := sk.get_bone_rest(i)
		var r := _pista(animacion, nombre, Animation.TYPE_ROTATION_3D)
		if r >= 0:
			local.basis = Basis(animacion.rotation_track_interpolate(r, t))
		var p := _pista(animacion, nombre, Animation.TYPE_POSITION_3D)
		if nombre == "Hips":
			local.origin = cadera * sk.motion_scale
		elif p >= 0:
			local.origin = animacion.position_track_interpolate(p, t) * sk.motion_scale
		poses[i] = local
	return poses


# Altura del pie mas bajo en el esqueleto; `poses` (hueso -> local) vacio es el reposo
func _pie_mas_bajo(sk: Skeleton3D, poses: Dictionary) -> float:
	var pie := INF
	for nombre in PIES:
		var i := sk.find_bone(nombre)
		if i < 0:
			continue
		var global := Transform3D.IDENTITY
		var b := i
		while b >= 0:
			global = (poses[b] if poses.has(b) else sk.get_bone_rest(b)) * global
			b = sk.get_bone_parent(b)
		pie = minf(pie, global.origin.y)
	return pie


func _al_piso(animacion: Animation, ruta: String, parado: Animation = null) -> void:
	var escena := (load(ruta) as PackedScene).instantiate()
	var sk := escena.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var reposo := _pie_mas_bajo(sk, {})
	if parado:
		var cadera_parado := parado.position_track_interpolate(_pista(parado, "Hips", Animation.TYPE_POSITION_3D), 0.0)
		reposo = _pie_mas_bajo(sk, _pose(parado, sk, 0.0, cadera_parado))
	var pista := _pista(animacion, "Hips", Animation.TYPE_POSITION_3D)
	var peor := 0.0
	for k in animacion.track_get_key_count(pista):
		var cadera: Vector3 = animacion.track_get_key_value(pista, k)
		var t := animacion.track_get_key_time(pista, k)
		var pie := _pie_mas_bajo(sk, _pose(animacion, sk, t, cadera))
		var corrige := (reposo - pie) / sk.motion_scale
		peor = maxf(peor, absf(reposo - pie) / (sk.get_bone_global_rest(sk.find_bone("Hips")).origin.y - reposo))
		animacion.track_set_key_value(pista, k, cadera + Vector3.UP * corrige)
	print("  al piso en %s: se despegaba hasta %d%% de la altura de la cadera" % [ruta.get_file(), roundi(peor * 100.0)])
	escena.free()
