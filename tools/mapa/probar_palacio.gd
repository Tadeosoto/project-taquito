extends SceneTree

# Prueba del palacio de gobierno y la plaza de la Catrina en map_test (P0, F._palacio y _plaza).
#   godot --path . --headless -s tools/mapa/probar_palacio.gd
#   godot --path . -s tools/mapa/probar_palacio.gd -- --capturas   # ademas guarda capturas de dia y de noche
#
# Que revisa:
#   - el palacio esta, con colision, y su fachada queda donde se espera (un rayo desde la plaza le pega);
#   - bajo el portal se puede pasar (un rayo a 1 m de alto entra entre los arcos);
#   - el piso de la plaza queda apenas arriba del suelo del mapa;
#   - en la plaza no hay arboles ni matas, y los pasos no suenan a pasto (MapPasto.hay_pasto); afuera si;
#   - la entrada a la pelea de la Mojiganga (EntradaJefe "mojiganga", catrina.tscn) esta en la plaza.

const MAPA := "res://scenes/map_test.tscn"
const CAPTURAS := "user://palacio_"
# Por load() al correr, no por su class_name: con -s este script se compila antes que los autoloads, y nombrar
# FortalezasMapa o EntradaJefe (que usan Misiones) dejaba esas clases rotas para todo el mapa
var F: GDScript

var _fallas := 0
var _total := 0
var _capturas := "--capturas" in OS.get_cmdline_user_args()


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	F = load("res://scripts/map/FortalezasMapa.gd")
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(2)
	var jugador := escena.get_node("Player") as CharacterBody3D
	var plaza: Vector2 = F.PLAZA_CENTRO
	jugador.global_position = Vector3(plaza.x, 1.0, plaza.y + 30.0)
	# Que carguen los cuadros, los arboles y el pasto de alrededor
	await _cuadros(240)
	var espacio := jugador.get_world_3d().direct_space_state

	var palacio := escena.find_child("Palacio", true, false) as StaticBody3D
	_revisar("hay palacio", palacio != null, "")
	if palacio:
		var formas := palacio.find_children("*", "CollisionShape3D", false, false).size()
		_revisar("el palacio choca", formas > 0, "%d formas" % formas)
		var pega := _rayo(espacio, Vector3(-606.0, 3.0, -90.0), Vector3(-606.0, 3.0, -170.0))
		_revisar("la fachada (o el muro detras del portal) queda en z -105 a -125", not pega.is_empty() and pega["position"].z < -105.0 and pega["position"].z > -125.0
			and pega["collider"] == palacio, str(pega.get("position")))
		var pasa := _rayo(espacio, Vector3(-604.5, 1.0, -100.0), Vector3(-604.5, 1.0, -116.0))
		_revisar("bajo el portal se pasa (1 m de alto)", pasa.is_empty() or pasa["position"].z < -113.0, str(pasa.get("position")))

	var suelo := _rayo(espacio, Vector3(plaza.x, 30.0, plaza.y + 10.0), Vector3(plaza.x, -30.0, plaza.y + 10.0))
	var piso := escena.find_child("PlazaCatrina", true, false)
	_revisar("el suelo del mapa bajo la plaza esta a ~0 m", not suelo.is_empty() and absf(suelo["position"].y) < 0.05, str(suelo.get("position")))
	_revisar("hay piso de plaza", piso != null and piso.get_node_or_null("Piso") != null, "")

	var arboles := 0
	for mmi: MultiMeshInstance3D in escena.find_children("*", "MultiMeshInstance3D", true, false):
		if not (mmi.get_parent() and mmi.get_parent().get_parent() and mmi.get_parent().get_parent().get_script() == load("res://scripts/map/MapArboles.gd")) \
				and not (mmi.get_parent() and mmi.get_parent().get_script() == load("res://scripts/map/MapPasto.gd")):
			continue
		for i in mmi.multimesh.instance_count:
			var p := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
			if (F.SIN_VEGETACION as Rect2).grow(-1.0).has_point(Vector2(p.x, p.z)):
				arboles += 1
	_revisar("ningun arbol ni mata en el palacio y la plaza", arboles == 0, "%d" % arboles)
	var pasto := escena.find_child("Pasto*", true, false)
	for nodo: Node in escena.find_children("*", "Node3D", true, false):
		if nodo.get_script() == load("res://scripts/map/MapPasto.gd"):
			pasto = nodo
	if pasto:
		_revisar("en la plaza los pasos no suenan a pasto", not pasto.hay_pasto(Vector3(plaza.x, 0.0, plaza.y)), "")
		_revisar("en el llano de junto si", pasto.hay_pasto(Vector3(-680.0, 0.0, -110.0)), "")

	var entrada: Node3D = null
	for e: Node3D in get_nodes_in_group("entradas_jefe"):
		if e.get("id") == "mojiganga":
			entrada = e
	_revisar("la entrada de la Mojiganga esta en la plaza", entrada != null and entrada.get("escena") == "res://scenes/catrina.tscn"
		and F.SIN_VEGETACION.has_point(Vector2(entrada.global_position.x, entrada.global_position.z)), "")

	if _capturas:
		await _fotos(escena, jugador)
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _fotos(escena: Node, jugador: CharacterBody3D) -> void:
	var camara := Camera3D.new()
	camara.far = 600.0
	escena.add_child(camara)
	camara.make_current()
	var plaza: Vector2 = F.PLAZA_CENTRO
	var tomas := [
		["frente", Vector3(plaza.x + 6.0, 2.0, plaza.y + 34.0), Vector3(-600.0, 7.0, -125.0)],
		["avenida", Vector3(-548.0, 3.0, -40.0), Vector3(-600.0, 6.0, -115.0)],
		["arriba", Vector3(-520.0, 70.0, -20.0), Vector3(-600.0, 0.0, -110.0)],
		["portal", Vector3(-596.0, 1.7, -100.0), Vector3(-601.0, 3.0, -118.0)],
	]
	for noche in [false, true]:
		if noche:
			var ciclo := escena.find_children("Ciclo*", "Node", true, false)
			if ciclo.size() > 0:
				ciclo[0].saltar(true)
			await _cuadros(90)
		for toma: Array in tomas:
			camara.look_at_from_position(toma[1], toma[2])
			jugador.global_position = Vector3(toma[1].x, 1.0, toma[1].z) if toma[0] != "arriba" else jugador.global_position
			await _cuadros(25)
			var nombre := "%s%s_%s.png" % [CAPTURAS, toma[0], "noche" if noche else "dia"]
			root.get_viewport().get_texture().get_image().save_png(nombre)
			print("captura ", ProjectSettings.globalize_path(nombre))


func _rayo(espacio: PhysicsDirectSpaceState3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(desde, hasta)
	q.collision_mask = 1
	return espacio.intersect_ray(q)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["OK  " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await process_frame
