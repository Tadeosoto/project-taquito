extends SceneTree

# Mide donde queda la cadera de un civil con Sitting_Idle respecto a su origen (para poner los
# asientos del Sotano debajo): godot --path . -s tools/sotano/medir_sentado.gd

func _initialize() -> void:
	var padre := Node3D.new()
	root.add_child(padre)
	var civiles = load("res://scripts/personajes/Civiles.gd")
	civiles.poner(padre, "hombre_15", "Sitting_Idle")
	await process_frame
	await process_frame
	await process_frame
	var esq: Skeleton3D = padre.find_children("*", "Skeleton3D", true, false)[0]
	for hueso in ["Hips", "LeftFoot", "LeftUpperLeg", "LeftLowerLeg"]:
		var i := esq.find_bone(hueso)
		if i >= 0:
			var p := padre.to_local(esq.to_global(esq.get_bone_global_pose(i).origin))
			print(hueso, " ", p)
	quit()
