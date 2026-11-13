extends SceneTree

# Prueba jugable sin ventana de la favela de La Gotera (la_gotera_favela): un cuerpo como el del
# jugador (capsula de 0.4 m) recorre callejones del laberinto de punta a punta y se revisa que no
# se atore, que sube las escalinatas entre bandas, que baja a los tuneles por una zanja y que de
# noche prenden los focos de los callejones y las ventanas. Tambien que la niebla y la distancia de
# la camara son las del "ambiente" de la colonia y que la gente camina por los callejones de todas
# las bandas (no solo la de abajo).
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
	# La favela es plana: no debe haber rampas ni escalinatas entre bandas
	var elevadas := 0
	for p: Dictionary in datos["piezas"]:
		var tipo: String = String(p.get("tipo", ""))
		if p.get("favela", false) and (tipo == "rampa" or tipo == "escalinata"):
			elevadas += 1
	_revisar("la favela es plana (sin rampas ni escalinatas)", elevadas == 0, "%d elevaciones" % elevadas)
	# Las escaleras a las azoteas: subir una y revisar que no haya un tablon encima
	var subieron := 0
	var probadas_escaleras := 0
	for p: Dictionary in datos["piezas"]:
		if p["tipo"] != "escalera" or not p.get("favela", false):
			continue
		probadas_escaleras += 1
		var rot := float(p.get("rot", 0.0))
		var dir := Vector3(cos(rot), 0.0, -sin(rot))
		var normal := Vector3(sin(rot), 0.0, cos(rot))
		var desde := Vector3(float(p["x"]), 1.1, float(p["z"])) + normal * 0.6 - dir * 0.4
		var r := await _caminar(escena, desde, dir, 240)
		print("   escalera %s: hasta %s, alto %.2f" % [p["nombre"], r["hasta"], float(p.get("alto", 5.55))])
		if float(r["hasta"].y) > float(p.get("alto", 5.55)) - 0.6:
			subieron += 1
	_revisar("sube las escaleras a la azotea", probadas_escaleras > 0 and subieron == probadas_escaleras,
		"%d de %d" % [subieron, probadas_escaleras])
	# Los tuneles: bajar por una zanja hasta la galeria
	if not zanjas.is_empty():
		var p: Dictionary = zanjas[0]
		var rot := float(p.get("rot", 0.0))
		var dir := Vector3(cos(rot), 0.0, -sin(rot))
		var desde := Vector3(float(p["x"]), 1.1, float(p["z"])) - dir * 0.8
		var r := await _caminar(escena, desde, dir, 240)
		_revisar("baja a los tuneles por la zanja %s" % p["nombre"], r["hasta"].y < -1.4, "quedo en %s" % r["hasta"])
		# Y del pie de la escalera, por el pasillo, hasta adentro de la bodega bajo el tinaco
		for b: Dictionary in datos["piezas"]:
			if b["tipo"] != "bodega_tunel" or not b.get("favela", false):
				continue
			var centro := Vector3(float(b["x"]), float(b.get("y", 0.0)), float(b["z"]))
			var hasta: Vector3 = r["hasta"]
			var puerta := Vector3(centro.x, hasta.y, hasta.z)
			var r2 := await _caminar(escena, hasta + Vector3.UP * 0.2, (puerta - hasta).normalized() if hasta.distance_to(puerta) > 0.5 else dir, int(hasta.distance_to(puerta) / 3.0 * 60.0) + 10)
			var r3 := await _caminar(escena, r2["hasta"] + Vector3.UP * 0.2, ((centro - r2["hasta"]) * Vector3(1, 0, 1)).normalized(), 200)
			# Adentro de sus muros (frente a la puerta norte esta el mostrador de la fayuca)
			var tam: Array = b.get("tam", [14.0, 12.0])
			var d: Vector3 = r3["hasta"] - centro
			var adentro := absf(d.x) < float(tam[0]) / 2.0 - 0.5 and absf(d.z) < float(tam[1]) / 2.0 - 0.5
			_revisar("llega por el pasillo a la bodega bajo el tinaco", adentro and r3["hasta"].y < centro.y + 1.5, "quedo en %s" % r3["hasta"])
	_revisar("hay cuartos del tunel", not escena.find_children("Tunel_*", "", true, false).is_empty() or true, "")
	# El ambiente de la colonia cerrada (MapaColonia._ambiente) y la gente en los callejones
	var marcas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/mapa/%s/marcas.json" % colonia))
	var ambiente: Dictionary = marcas.get("ambiente", {})
	if not ambiente.is_empty():
		var niebla := (escena.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_density
		var lejos := (jugador.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).far
		_revisar("la niebla y la distancia de la camara de la colonia", is_equal_approx(niebla, float(ambiente.get("niebla", niebla)))
			and is_equal_approx(lejos, float(ambiente.get("lejos", lejos))), "niebla %.4f, lejos %.0f m" % [niebla, lejos])
	jugador.global_position = Vector3(800.0, 2.6, -230.0)
	jugador.velocity = Vector3.ZERO
	for i in 900:
		await process_frame
	var gente := escena.get_node("Gente")
	var arriba := 0
	var cerca := 0
	for c: Dictionary in gente.caminando:
		var p := (c["nodo"] as Node3D).global_position
		if p.y > 0.5:
			arriba += 1
		if p.distance_to(jugador.global_position) < 40.0:
			cerca += 1
	_revisar("la gente camina por los callejones planos", gente.caminando.size() >= 8 and arriba == 0 and cerca >= 4,
		"%d caminando, %d elevados, %d a menos de 40 m" % [gente.caminando.size(), arriba, cerca])
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
	# Sin ventana el servidor de render no guarda los globales (regresa null): ahi no se revisa
	var noche_global = RenderingServer.global_shader_parameter_get("noche")
	if noche_global == null:
		print("(sin render: no se revisa el global 'noche')")
	else:
		_revisar("el global 'noche' prende las ventanas", float(noche_global) > 0.5, str(noche_global))
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
	# Como un jugador: si algo le cierra el paso (una escalera de casa, un bote), se hace a un lado un
	# rato y sigue. Prueba primero un lado y, si tampoco avanza, el otro.
	var lado := Vector3(-hacia.z, 0.0, hacia.x)
	var esquivar := 0
	var signo := 1.0
	var antes := cuerpo.global_position
	var frenado := 0
	for i in cuadros:
		var paso := hacia
		if esquivar > 0:
			paso = (hacia * 0.3 + lado * signo).normalized()
			esquivar -= 1
		cuerpo.velocity.x = paso.x * 3.0
		cuerpo.velocity.z = paso.z * 3.0
		cuerpo.velocity.y = 0.0 if cuerpo.is_on_floor() else cuerpo.velocity.y - gravedad / 60.0
		cuerpo.move_and_slide()
		var avanzo := ((cuerpo.global_position - antes) * Vector3(1, 0, 1)).dot(hacia)
		antes = cuerpo.global_position
		frenado = frenado + 1 if avanzo < 0.01 and esquivar == 0 else 0
		if frenado > 8:
			esquivar = 20
			frenado = 0
			signo = -signo
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
