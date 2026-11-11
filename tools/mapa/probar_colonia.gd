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
	await _subir_banqueta(escena)
	print("RESULTADO: %s" % ("BIEN" if _fallas == 0 else "%d FALLAS" % _fallas))
	quit(_fallas)


# Un cuerpo como el del jugador (capsula de 0.4 x 2 m) camina del arroyo a la banqueta: la
# guarnicion mide 15 cm y su caja de choque es rampa, asi que tiene que subirse y no atorarse.
# SUBIDA_DESDE/HACIA: de en medio de la calle Pipilingue (Santa Mugre) a la banqueta del norte.
const SUBIDA_DESDE := Vector3(-250.0, 1.1, 328.5)
const SUBIDA_HACIA := Vector3(0.0, 0.0, -1.0)


func _subir_banqueta(escena: Node) -> void:
	var cuerpo := CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 2.0
	forma.shape = capsula
	cuerpo.add_child(forma)
	escena.add_child(cuerpo)
	cuerpo.global_position = SUBIDA_DESDE
	var gravedad := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var y_calle := 0.0
	var y_max := -INF
	for i in 150:
		cuerpo.velocity.x = SUBIDA_HACIA.x * 3.0
		cuerpo.velocity.z = SUBIDA_HACIA.z * 3.0
		cuerpo.velocity.y = 0.0 if cuerpo.is_on_floor() else cuerpo.velocity.y - gravedad / 60.0
		cuerpo.move_and_slide()
		if i == 20:
			y_calle = cuerpo.global_position.y
		if i > 20:
			y_max = maxf(y_max, cuerpo.global_position.y)
		await physics_frame
	var avance := (cuerpo.global_position - SUBIDA_DESDE) * Vector3(1, 0, 1)
	# Lo mas alto: despues de la banqueta puede volver a bajar por el otro bisel
	var subio := y_max - y_calle
	_revisar("sube la banqueta", subio > 0.1 and avance.length() > 4.0,
		"subio %.2f m, avanzo %.1f m (hasta %s)" % [subio, avance.length(), cuerpo.global_position])
	cuerpo.queue_free()


func _revisar(que: String, bien: bool, detalle: String) -> void:
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])
	if not bien:
		_fallas += 1


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
