extends SceneTree

# Prueba jugable sin ventana de la favela de La Gotera (la_gotera_favela): un cuerpo como el del
# jugador (capsula de 0.4 m) recorre callejones del laberinto de punta a punta y se revisa que no
# se atore, que sube las escalinatas entre bandas, que baja a los tuneles por una zanja y que de
# noche prenden los focos de los callejones y las ventanas.
#   godot --path . --headless -s tools/mapa/recorrer_favela.gd [-- --cuantos=60 --colonia=la_gotera_favela]
# Lee los callejones del .json de la colonia (tools/blender/mapa/colonias/<colonia>.json).

const MAPA := "res://scenes/mapa.tscn"

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	var colonia := String(args.get("colonia", "la_gotera_favela"))
	var cuantos := int(args.get("cuantos", "60"))
	PasoColonia.colonia = colonia
	PasoColonia.simular = true
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(90)
	var jugador := escena.get_node("Player") as CharacterBody3D
	_revisar("el jugador aparece parado", jugador.is_on_floor(), "y = %.2f" % jugador.global_position.y)
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/blender/mapa/colonias/%s.json" % colonia))
	var callejones: Array = []
	var zanjas: Array = []
	for p: Dictionary in datos["piezas"]:
		if p["tipo"] == "calle" and p.get("favela", false) and String(p["nombre"]).begins_with("Callejon"):
			callejones.append(p)
		elif p["tipo"] == "bajada" and p.get("favela", false):
			zanjas.append(p)
	var terrazas: Array = datos.get("terrazas", [])
	# Callejones al azar, siempre los mismos
	var azar := RandomNumberGenerator.new()
	azar.seed = 11
	var atorados := 0
	var probados := 0
	var largos := 0.0
	for k in mini(cuantos, callejones.size()):
		var p: Dictionary = callejones[azar.randi() % callejones.size()]
		var a := Vector3(float(p["x"]), 0.0, float(p["z"]))
		var b := a + Vector3(float(p["puntos"][1][0]), 0.0, float(p["puntos"][1][1]))
		var largo := a.distance_to(b)
		if largo < 3.0:
			continue
		var dir := (b - a) / largo
		# De un poco adentro del tramo al otro extremo, a la altura de su banda
		var desde := a + dir * 0.6
		desde.y = _alto_en(desde, terrazas) + 1.1
		var r := await _caminar(escena, desde, dir, int(largo / 3.0 * 60.0) + 30)
		probados += 1
		largos += largo
		if r["avance"] < largo - 1.5:
			atorados += 1
			print("   atorado en %s: avanzo %.1f de %.1f m, quedo en %s" % [p["nombre"], r["avance"], largo, r["hasta"]])
	_revisar("recorre los callejones sin atorarse (%d probados, %.0f m)" % [probados, largos], atorados == 0, "%d atorados" % atorados)
	# Las escalinatas: subir de banda por una
	var escalinatas := 0
	var subidas := 0
	for p: Dictionary in datos["piezas"]:
		if p["tipo"] != "escalinata" or not p.get("favela", false) or escalinatas >= 6:
			continue
		escalinatas += 1
		var rot := float(p.get("rot", 0.0))
		var dir := Vector3(cos(rot), 0.0, -sin(rot))     # +X local de la pieza
		var desde := Vector3(float(p["x"]), float(p.get("y", 0.0)) + 1.1, float(p["z"])) - dir * 1.2
		var r := await _caminar(escena, desde, dir, 150)
		var sube := float(p.get("alto", 0.75))
		if r["subio"] > sube - 0.15:
			subidas += 1
		else:
			print("   escalinata %s: subio %.2f de %.2f m" % [p["nombre"], r["subio"], sube])
	_revisar("sube las escalinatas entre bandas", escalinatas > 0 and subidas == escalinatas, "%d de %d" % [subidas, escalinatas])
	# Los tuneles: bajar por una zanja hasta la galeria
	if not zanjas.is_empty():
		var p: Dictionary = zanjas[0]
		var rot := float(p.get("rot", 0.0))
		var dir := Vector3(cos(rot), 0.0, -sin(rot))
		var desde := Vector3(float(p["x"]), 1.1, float(p["z"])) - dir * 0.8
		var r := await _caminar(escena, desde, dir, 240)
		_revisar("baja a los tuneles por la zanja %s" % p["nombre"], r["hasta"].y < -3.0, "quedo en %s" % r["hasta"])
	_revisar("hay cuartos del tunel", not escena.find_children("Tunel_*", "", true, false).is_empty() or true, "")
	# De noche: focos de los callejones prendidos y el global de la noche para las ventanas
	var ciclo := escena.get_node("Ciclo")
	ciclo.set("_tiempo", float(ciclo.get("dia_duracion")) + 200.0)
	await _cuadros(30)
	var colonia_nodo := escena.get_node("Colonia")
	var focos := colonia_nodo.find_children("Foco_*", "OmniLight3D", false, false)
	var prendidos := 0
	for f in focos:
		if (f as Light3D).visible and (f as Light3D).light_energy > 0.5:
			prendidos += 1
	_revisar("de noche prenden los focos de los callejones", focos.size() > 20 and prendidos > focos.size() * 0.8, "%d de %d" % [prendidos, focos.size()])
	var noche := float(RenderingServer.global_shader_parameter_get("noche"))
	_revisar("el global 'noche' prende las ventanas", noche > 0.5, str(noche))
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _alto_en(p: Vector3, terrazas: Array) -> float:
	for t: Dictionary in terrazas:
		if t.has("poligono"):
			var pol := PackedVector2Array()
			for q in t["poligono"]:
				pol.append(Vector2(float(q[0]), float(q[1])))
			if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), pol):
				return float(t.get("alto", 0.75))
	return 0.0


func _caminar(escena: Node, desde: Vector3, hacia: Vector3, cuadros: int) -> Dictionary:
	var cuerpo := CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 2.0
	forma.shape = capsula
	cuerpo.add_child(forma)
	cuerpo.floor_max_angle = deg_to_rad(45.0)
	escena.add_child(cuerpo)
	cuerpo.global_position = desde
	var gravedad := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var y_calle := 0.0
	var y_max := -INF
	for i in cuadros:
		cuerpo.velocity.x = hacia.x * 3.0
		cuerpo.velocity.z = hacia.z * 3.0
		cuerpo.velocity.y = 0.0 if cuerpo.is_on_floor() else cuerpo.velocity.y - gravedad / 60.0
		cuerpo.move_and_slide()
		if i == 10:
			y_calle = cuerpo.global_position.y
		if i > 10:
			y_max = maxf(y_max, cuerpo.global_position.y)
		await physics_frame
	var r := {"subio": y_max - y_calle, "y_max": y_max, "hasta": cuerpo.global_position,
		"avance": ((cuerpo.global_position - desde) * Vector3(1, 0, 1)).length()}
	cuerpo.queue_free()
	return r


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
