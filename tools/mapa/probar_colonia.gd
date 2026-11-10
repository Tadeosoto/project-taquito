extends SceneTree

# Prueba sin ventana de una colonia de Blender (scenes/mapa.tscn): que el jugador aparezca en
# la marca Spawn parado en el piso del .glb, que la puerta meta al interior y que al salir te
# deje frente a ella.
#   godot --path . --headless -s tools/mapa/probar_colonia.gd

const ESCENA := "res://scenes/mapa.tscn"

var _fallas := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var escena: Node = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(1)
	var jugador := escena.get_node("Player") as CharacterBody3D
	var al_aparecer := Vector2(jugador.global_position.x, jugador.global_position.z)
	await _cuadros(90)
	var marcas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		(escena.get_node("Colonia") as Colonia).marcas_path))
	var spawn: Dictionary = {}
	var puerta: Dictionary = {}
	var interiores := escena.get_node("Interiores")
	var escenas: Dictionary = interiores.get("escenas")
	for m: Dictionary in marcas["marcas"]:
		if m["tipo"] == "spawn":
			spawn = m
		# La primera puerta que si tiene interior (las demas dicen "Proximamente")
		elif m["tipo"] == "puerta" and puerta.is_empty() and escenas.has(m.get("giro", "")):
			puerta = m
	_revisar("aparece en Spawn", al_aparecer.distance_to(Vector2(spawn["x"], spawn["z"])) < 0.05,
		"jugador en %s" % al_aparecer)
	_revisar("parado en el piso", jugador.is_on_floor() and absf(jugador.global_position.y - 1.0) < 0.3,
		"y = %.2f, en el piso: %s" % [jugador.global_position.y, jugador.is_on_floor()])

	if puerta.is_empty():
		_revisar("hay una puerta con interior", false, "")
		quit(_fallas)
		return
	jugador.global_position = Vector3(puerta["x"], 1.2, puerta["z"])
	await _cuadros(120)
	_revisar("la puerta mete al interior", interiores.get("_interior") != null, "")
	var yonkes := root.get_tree().get_nodes_in_group("yonke")
	var hay_yonke := false
	for m: Dictionary in marcas["marcas"]:
		hay_yonke = hay_yonke or m["tipo"] == "yonke"
	if hay_yonke:
		_revisar("esta el yonke", yonkes.size() == 1, "%d en el grupo yonke" % yonkes.size())
	if interiores.get("_interior") != null:
		interiores.call("_salir")
		await _cuadros(90)
		var afuera := Colonia.lugar(puerta).basis.z
		var esperado := Vector3(puerta["x"], 0.0, puerta["z"]) + afuera * 2.2
		var d := Vector2(jugador.global_position.x - esperado.x, jugador.global_position.z - esperado.z).length()
		_revisar("sale frente a la puerta", interiores.get("_interior") == null and d < 0.6,
			"jugador en %s, esperado %s" % [jugador.global_position, esperado])
	print("RESULTADO: %s" % ("BIEN" if _fallas == 0 else "%d FALLAS" % _fallas))
	quit(_fallas)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])
	if not bien:
		_fallas += 1


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
