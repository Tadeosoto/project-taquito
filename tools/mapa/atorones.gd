extends SceneTree

# Busca por donde no se pasa en una colonia del mapa de Blender, sin caminarla: planta el cuerpo
# del jugador (una capsula de radio RADIO) cada PASO m sobre el eje de cada callejon y de cada
# pasillo de casa cueva, y dice que le estorba (el nombre del choque).
#   godot --path . --headless -s tools/mapa/atorones.gd [-- --colonia=la_gotera_favela --radio=0.4]
# Es mucho mas rapido que recorrer_favela.gd y encuentra lo que ese se salta (los tramos que no
# recorre). Lo que reporta hay que arreglarlo en el generador y volver a exportar.

const MAPA := "res://scenes/mapa.tscn"
const RADIO := 0.4          # el del jugador (CharacterBody3D de scenes/player.tscn)
const ALTO := 1.7
const PASO := 0.35          # m entre pruebas a lo largo del eje


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	var colonia := String(args.get("colonia", "la_gotera_favela"))
	var radio := float(args.get("radio", str(RADIO)))
	PasoColonia.colonia = colonia
	PasoColonia.sin_candados = true
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	for i in 90:
		await process_frame
	var jugador := escena.get_node_or_null("Player") as Node3D
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_DISABLED
		jugador.global_position = Vector3(0.0, -500.0, 0.0)
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/blender/mapa/colonias/%s.json" % colonia))
	var forma := CapsuleShape3D.new()
	forma.radius = radio
	forma.height = ALTO
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	var espacio := escena.get_viewport().world_3d.direct_space_state

	var topes := {}        # "pieza -> choque" -> cuantas veces
	var sitios := []       # [nombre, Vector3, choque]

	# En cada estacion no basta con que el eje este libre: se busca si HAY por donde pasar, o sea
	# algun corrimiento de lado (hasta medio ancho) donde el cuerpo quepa. Solo si no cabe en
	# ninguno es un atoron de verdad; si no, se reportaba cada esquina de casa junto al eje.
	var probar := func(nombre: String, a0: Vector3, b0: Vector3, ancho: float) -> void:
		# Las puntas no cuentan: un callejon sin salida termina contra la pared de una casa, y el
		# eje llega hasta la esquina de la cuadricula. Se prueba solo el tramo de en medio.
		var recorte := ancho / 2.0 + RADIO + 0.1
		var largo0 := a0.distance_to(b0)
		if largo0 < 2.0 * recorte + 0.3:
			return
		var u := (b0 - a0).normalized()
		var a := a0 + u * recorte
		var b := b0 - u * recorte
		var largo := a.distance_to(b)
		if largo < 0.05:
			return
		var lado := ((b - a) * Vector3(1, 0, 1)).normalized().cross(Vector3.UP)
		var n := maxi(1, int(largo / PASO))
		for i in range(n + 1):
			var p := a.lerp(b, float(i) / n)
			var pasa := false
			var estorba := ""
			var corrimientos: Array[float] = [0.0]
			var d := 0.1
			while d <= ancho / 2.0 - RADIO * 0.5 + 0.001:
				corrimientos.append(d)
				corrimientos.append(-d)
				d += 0.1
			for c: float in corrimientos:
				consulta.transform = Transform3D(Basis.IDENTITY, p + lado * c + Vector3.UP * (ALTO / 2.0 + 0.1))
				var choques := espacio.intersect_shape(consulta, 1)
				if choques.is_empty():
					pasa = true
					break
				estorba = String((choques[0]["collider"] as Node).name)
			if pasa:
				continue
			var clave := "%s | %s" % [nombre, estorba]
			if not topes.has(clave):
				topes[clave] = 0
				sitios.append([nombre, p, estorba])
			topes[clave] += 1

	# Callejones: por el eje
	var tramos := 0
	for p: Dictionary in datos["piezas"]:
		if p.get("tipo") != "calle" or not String(p.get("nombre", "")).begins_with("Callejon"):
			continue
		var pts: Array = p["puntos"]
		for i in range(1, pts.size()):
			tramos += 1
			probar.call(String(p["nombre"]),
				Vector3(float(p["x"]) + float(pts[i - 1][0]), 0.0, float(p["z"]) + float(pts[i - 1][1])),
				Vector3(float(p["x"]) + float(pts[i][0]), 0.0, float(p["z"]) + float(pts[i][1])),
				float(p.get("ancho", 2.0)))
	# Pasillos de las casas cueva: en locales de la huella
	var cuevas := 0
	for p: Dictionary in datos["piezas"]:
		if p.get("tipo") != "abandonada" or not p.has("pasillos"):
			continue
		cuevas += 1
		var base := Transform3D(Basis(Vector3.UP, float(p.get("rot", 0.0))), Vector3(float(p["x"]), 0.0, float(p["z"])))
		for ruta: Array in p["pasillos"]:
			for i in range(1, ruta.size()):
				probar.call(String(p["nombre"]),
					base * Vector3(float(ruta[i - 1][0]), 0.0, float(ruta[i - 1][1])),
					base * Vector3(float(ruta[i][0]), 0.0, float(ruta[i][1])),
					float(p.get("pasillo_ancho", 1.7)))
	# Los marcos de las casas cueva: de afuera a adentro del hueco (es por donde se entra, y el
	# recorrido de los pasillos no lo cubre)
	var marcos := 0
	var normales := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for p: Dictionary in datos["piezas"]:
		if p.get("tipo") != "abandonada" or not p.has("puertas"):
			continue
		var hw := absf(float(p["puntos"][1][0]))
		var hh := absf(float(p["puntos"][2][1]))
		var base := Transform3D(Basis(Vector3.UP, float(p.get("rot", 0.0))), Vector3(float(p["x"]), 0.0, float(p["z"])))
		for puerta: Array in p["puertas"]:
			marcos += 1
			var lado := int(puerta[0])
			var tt := float(puerta[1])
			var en: Vector2 = [Vector2(-hw + tt, -hh), Vector2(hw, -hh + tt), Vector2(hw - tt, hh), Vector2(-hw, hh - tt)][lado]
			var nn: Vector2 = normales[lado]
			probar.call("%s:marco%d" % [p["nombre"], lado],
				base * Vector3(en.x + nn.x * 1.4, 0.0, en.y + nn.y * 1.4),
				base * Vector3(en.x - nn.x * 1.2, 0.0, en.y - nn.y * 1.2),
				float(puerta[2]) if puerta.size() > 2 else 1.5)

	# Las flechas de las tiendas: delante de cada puerta tiene que haber por donde pararse
	var puertas := 0
	for m: Dictionary in datos.get("marcas", []):
		if m.get("tipo") != "puerta":
			continue
		puertas += 1
		var r := float(m.get("rot", 0.0))
		var frente := Vector3(sin(r), 0.0, cos(r))
		var en := Vector3(float(m["x"]), float(m.get("y", 0.0)), float(m["z"]))
		probar.call("Puerta:" + String(m.get("nombre", "")), en + frente * 0.6, en + frente * 2.6, 1.6)

	print("--- %s: %d tramos de callejon, %d cuevas, %d marcos, %d puertas, capsula r=%.2f" % [colonia, tramos, cuevas, marcos, puertas, radio])
	if sitios.is_empty():
		print("sin atorones")
	for s in sitios:
		print("ATORON %-26s en (%.1f, %.1f) lo para: %s" % [s[0], (s[1] as Vector3).x, (s[1] as Vector3).z, s[2]])
	print("TOTAL %d atorones" % sitios.size())
	quit(1 if not sitios.is_empty() else 0)
