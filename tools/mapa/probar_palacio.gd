extends SceneTree

# Prueba del palacio de gobierno y la plaza de la Catrina en map_test (P0, F._palacio y _plaza).
#   godot --path . --headless -s tools/mapa/probar_palacio.gd
#   godot --path . -s tools/mapa/probar_palacio.gd -- --capturas   # ademas guarda capturas de dia y de noche
#
# Que revisa:
#   - el palacio esta, con colision, y su fachada queda donde se espera (un rayo desde enfrente le pega);
#   - la bodega que estaba en su terreno ya no esta (ni sus bardas);
#   - bajo el portal se puede pasar (un rayo a 1 m de alto entra entre los arcos);
#   - el piso de la plaza queda apenas arriba del suelo del mapa;
#   - en la plaza no hay arboles ni matas, y los pasos no suenan a pasto (MapPasto.hay_pasto); afuera si;
#   - la entrada a la pelea de la Mojiganga (EntradaJefe "mojiganga", catrina.tscn) esta en la plaza.

const MAPA := "res://scenes/map_test.tscn"
const CAPTURAS := "user://palacio_"
const LEJOS_PASTO := [Vector2(215.0, 605.0), Vector2(225.0, 620.0), Vector2(320.0, 600.0)]   # jardines de alrededor
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
	jugador.global_position = Vector3(plaza.x, 1.0, plaza.y)
	# Que carguen los cuadros, los arboles y el pasto de alrededor
	await _cuadros(240)
	var espacio := jugador.get_world_3d().direct_space_state

	var palacio := escena.find_child("Palacio", true, false) as StaticBody3D
	_revisar("hay palacio", palacio != null, "")
	if palacio:
		var formas := palacio.find_children("*", "CollisionShape3D", false, false).size()
		_revisar("el palacio choca", formas > 0, "%d formas" % formas)
		# En los ejes del palacio: su origen esta al pie del portal y el frente mira a su +Z
		var xf := palacio.global_transform
		var pega := _rayo(espacio, xf * Vector3(-6.0, 3.0, 30.0), xf * Vector3(-6.0, 3.0, -50.0))
		var z_pega: float = (xf.affine_inverse() * pega["position"]).z if not pega.is_empty() else 99.0
		_revisar("la fachada (o el muro detras del portal) queda a +15..-5 m del origen", z_pega < 15.0 and z_pega > -5.0
			and pega["collider"] == palacio, "%.1f" % z_pega)
		var pasa := _rayo(espacio, xf * Vector3(-4.5, 1.0, 20.0), xf * Vector3(-4.5, 1.0, 4.0))
		var z_pasa: float = (xf.affine_inverse() * pasa["position"]).z if not pasa.is_empty() else -99.0
		_revisar("bajo el portal se pasa (1 m de alto)", z_pasa < 7.0, "%.1f" % z_pasa)
		var centro: Vector2 = F.PALACIO_CENTRO
		var arriba := _rayo(espacio, Vector3(centro.x, 40.0, centro.y), Vector3(centro.x, -5.0, centro.y))
		_revisar("el palacio queda centrado en su terreno", not arriba.is_empty() and arriba["collider"] == palacio, str(arriba.get("position")))
	var bodegas := 0
	var bardas := 0
	for nodo: Node3D in escena.find_children("*", "Node3D", true, false):
		var guion: Script = nodo.get_script()
		if guion == null or not guion.resource_path.ends_with("MapBodegas.gd") and not guion.resource_path.ends_with("MapBardas.gd"):
			continue
		for malla: MeshInstance3D in nodo.find_children("*", "MeshInstance3D", true, false):
			var caja := malla.global_transform * malla.get_aabb()
			var c := caja.get_center()
			if F.en_lote(c.x, c.z) and caja.size.x < 60.0 and caja.size.z < 60.0:
				if guion.resource_path.ends_with("MapBodegas.gd"):
					bodegas += 1
				else:
					bardas += 1
	_revisar("ya no esta la bodega del terreno (ni sus bardas)", bodegas == 0 and bardas == 0, "%d mallas de bodega, %d de barda" % [bodegas, bardas])

	var suelo := _rayo(espacio, Vector3(plaza.x + 8.0, 30.0, plaza.y), Vector3(plaza.x + 8.0, -30.0, plaza.y))
	var piso := escena.find_child("PlazaCatrina", true, false)
	_revisar("el piso de la plaza queda encima del suelo y la banqueta (0..0.17 m)", not suelo.is_empty() and suelo["position"].y > -0.05 and suelo["position"].y < 0.15, str(suelo.get("position")))
	_revisar("hay piso de plaza", piso != null and piso.get_node_or_null("Piso") != null, "")

	var arboles := 0
	for mmi: MultiMeshInstance3D in escena.find_children("*", "MultiMeshInstance3D", true, false):
		if not (mmi.get_parent() and mmi.get_parent().get_parent() and mmi.get_parent().get_parent().get_script() == load("res://scripts/map/MapArboles.gd")) \
				and not (mmi.get_parent() and mmi.get_parent().get_script() == load("res://scripts/map/MapPasto.gd")):
			continue
		for i in mmi.multimesh.instance_count:
			var p := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
			if F.sin_vegetacion(p.x, p.z):
				arboles += 1
	_revisar("ningun arbol ni mata en el palacio y la plaza", arboles == 0, "%d" % arboles)
	var pasto := escena.find_child("Pasto*", true, false)
	for nodo: Node in escena.find_children("*", "Node3D", true, false):
		if nodo.get_script() == load("res://scripts/map/MapPasto.gd"):
			pasto = nodo
	if pasto:
		_revisar("en la plaza los pasos no suenan a pasto", not pasto.hay_pasto(Vector3(plaza.x, 0.0, plaza.y)), "")
		var afuera := 0
		for punto: Vector2 in LEJOS_PASTO:
			afuera += 1 if pasto.hay_pasto(Vector3(punto.x, 0.0, punto.y)) else 0
		_revisar("en los jardines de alrededor si", afuera > 0, "%d de %d" % [afuera, LEJOS_PASTO.size()])

	var entrada: Node3D = null
	for e: Node3D in get_nodes_in_group("entradas_jefe"):
		if e.get("id") == "mojiganga":
			entrada = e
	_revisar("la entrada de la Mojiganga esta en la plaza", entrada != null and entrada.get("escena") == "res://scenes/catrina.tscn"
		and F.sin_vegetacion(entrada.global_position.x, entrada.global_position.z), "")

	if _capturas:
		await _fotos(escena, jugador)
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _fotos(escena: Node, jugador: CharacterBody3D) -> void:
	var camara := Camera3D.new()
	camara.far = 600.0
	escena.add_child(camara)
	camara.make_current()
	var palacio := escena.find_child("Palacio", true, false) as Node3D
	var plaza := escena.find_child("PlazaCatrina", true, false) as Node3D
	var p := palacio.global_transform
	var q := plaza.global_transform
	var tomas := [
		["frente", q * Vector3(14.0, 2.0, 4.0), p * Vector3(0.0, 7.0, 0.0)],
		["avenida", q * Vector3(-4.0, 2.5, 26.0), q * Vector3(0.0, 5.0, -25.0)],
		["arriba", q * Vector3(30.0, 55.0, 70.0), p * Vector3(0.0, 0.0, 0.0)],
		["portal", p * Vector3(4.0, 1.7, 14.0), p * Vector3(-1.0, 3.0, 0.0)],
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
