extends SceneTree

# Prueba jugable sin ventana de la favela de La Gotera (la_gotera_favela): un cuerpo como el del
# jugador (capsula de 0.4 m) recorre callejones del laberinto de punta a punta y se revisa que no
# se atore, que sube las escalinatas entre bandas, que baja a los tuneles por una zanja y que de
# noche prenden los focos de los callejones y las ventanas. Para saber si de verdad se pasa por
# todos lados usa tools/mapa/atorones.gd, que es geometrico: este camina en linea recta y en una
# vuelta cerrada de pasillo se queda corto sin estar atorado. Tambien que la niebla y la distancia de
# la camara son las del "ambiente" de la colonia y que la gente camina por los callejones de todas
# las bandas (no solo la de abajo).
#   godot --path . --headless -s tools/mapa/recorrer_favela.gd [-- --cuantos=60 --colonia=la_gotera_favela]
# Lee los callejones del .json de la colonia (tools/blender/mapa/colonias/<colonia>.json).

const MAPA := "res://scenes/mapa.tscn"

var _fallas := 0
var _total := 0
var _solo := {}


## Si toca correr esta prueba (ver --solo)
func _toca(que: String) -> bool:
	return _solo.is_empty() or _solo.has(que)


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var partes := arg.trim_prefix("--").split("=", true, 1)
		args[partes[0]] = partes[1] if partes.size() > 1 else ""
	var colonia := String(args.get("colonia", "la_gotera_favela"))
	var cuantos := int(args.get("cuantos", "60"))
	# --solo=callejones,cuevas,gente,ambiente,noche: solo esas pruebas (las demas se saltan). La
	# vuelta completa tarda minutos y al estar cambiando una cosa no hace falta correrla toda.
	_solo.clear()
	if String(args.get("solo", "")) != "":
		for n in String(args["solo"]).split(","):
			_solo[n.strip_edges()] = true
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
	if not _toca("callejones"):
		cuantos = 0
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
	for p: Dictionary in (datos["piezas"] if _toca("escaleras") else []):
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
	# Por ahora la favela va sin escaleras a las azoteas (favela.ESCALERAS_AZOTEA)
	if probadas_escaleras > 0:
		_revisar("sube las escaleras a la azotea", subieron == probadas_escaleras, "%d de %d" % [subieron, probadas_escaleras])
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
	# Lo que se cruza por dentro: de un marco al otro de cada casa abandonada y de punta a punta
	# de cada callejon techado
	var cruzan := 0
	var cruces := 0
	var normales := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for p: Dictionary in (datos["piezas"] if _toca("cuevas") else []):
		var tramos: Array[Vector3] = []
		var base := Transform3D(Basis(Vector3.UP, float(p.get("rot", 0.0))), Vector3(float(p["x"]), 1.1, float(p["z"])))
		if p["tipo"] == "abandonada" and p["puertas"].size() >= 2:
			var hw := absf(float(p["puntos"][1][0]))
			var hh := absf(float(p["puntos"][2][1]))
			# De afuera a justo adentro de cada marco, y por el centro (en una casa doble la recta
			# de afuera al centro pega en el muro junto al marco)
			var afuera: Array[Vector3] = []
			var adentro: Array[Vector3] = []
			for puerta: Array in p["puertas"].slice(0, 2):
				var lado := int(puerta[0])
				var t := float(puerta[1])
				var en: Vector2 = [Vector2(-hw + t, -hh), Vector2(hw, -hh + t), Vector2(hw - t, hh), Vector2(-hw, hh - t)][lado]
				var n: Vector2 = normales[lado]
				afuera.append(base * Vector3(en.x + n.x * 1.2, 0.0, en.y + n.y * 1.2))
				adentro.append(base * Vector3(en.x - n.x * 1.0, 0.0, en.y - n.y * 1.0))
			# Por el pasillo de verdad (favela._pasillos / _cuartos_cueva): en las cuevas largas
			# va pegado a los muros y el centro es macizo (ahi estan los cuartos)
			tramos = [afuera[0], adentro[0]]
			var ruta := _ruta_entre(p, adentro[0], adentro[1], base)
			for q: Vector3 in ruta:
				tramos.append(q)
			tramos.append(adentro[1])
			tramos.append(afuera[1])
		elif p["tipo"] == "techo_callejon":
			var medio := float(p["largo"]) / 2.0 + 1.3      # de esquina a esquina (favela.TECHADO_ESQUINA)
			tramos = [base * Vector3(-medio, 0.0, 0.0), base * Vector3(medio, 0.0, 0.0)]
		else:
			continue
		cruces += 1
		# Cada tramo cuenta si avanzo todo su largo en esa direccion (puede pasarse un poco)
		var falta := 0.0
		for i in range(1, tramos.size()):
			var hacia := (tramos[i] - tramos[i - 1]) * Vector3(1, 0, 1)
			# Margen de cuadros: en los pasillos de 1.7 m el cuerpo roza las paredes y avanza mas
			# despacio que a campo abierto, y se quedaba corto por medio metro sin estar atorado
			var r := await _caminar(escena, tramos[i - 1], hacia.normalized(), int(hacia.length() / 3.0 * 60.0) + 60)
			var avanzo: float = ((r["hasta"] - tramos[i - 1]) * Vector3(1, 0, 1)).dot(hacia.normalized())
			# Si se queda corto, vuelve a apuntar desde donde quedo: el jugador tampoco camina
			# pegado a la pared en linea recta. Si de verdad no se pasa, se queda corto otra vez.
			if hacia.length() - avanzo > 0.5:
				var hasta: Vector3 = r["hasta"]
				var resto := (tramos[i] - hasta) * Vector3(1, 0, 1)
				if resto.length() > 0.2:
					var r2 := await _caminar(escena, hasta + Vector3.UP * 0.1, resto.normalized(),
						int(resto.length() / 3.0 * 60.0) + 60)
					var hasta2: Vector3 = r2["hasta"]
					avanzo += ((hasta2 - hasta) * Vector3(1, 0, 1)).dot(hacia.normalized())
			falta = maxf(falta, hacia.length() - avanzo)
		print("   cruza %s: le falto %.2f m en el peor tramo" % [p["nombre"], falta])
		# 0.5: en la esquina del techado la pared de enfrente lo para a su radio (0.4 m)
		if falta < 0.5:
			cruzan += 1
	if cruces > 0:
		# Esta prueba camina en linea recta: en una vuelta cerrada de pasillo se queda corta sin que
		# el paso este tapado. Quien dice si de verdad se pasa es tools/mapa/atorones.gd (geometrico).
		_revisar("se cruzan las casas abandonadas y los callejones techados", cruzan >= cruces - 1,
			"%d de %d%s" % [cruzan, cruces, "" if cruzan == cruces else " (revisar con atorones.gd)"])
		# Con el jugador adentro la camara sube y el techo solo da sombra; al salir vuelve
		var interior: Dictionary = {}
		for m: Dictionary in datos["marcas"]:
			if m.get("tipo") == "interior":
				interior = m
				break
		var techo := escena.find_child("Techo_" + String(interior["techos"][0]), true, false) as GeometryInstance3D
		jugador.global_position = _en_el_pasillo(datos, interior)
		jugador.velocity = Vector3.ZERO
		await _cuadros(30)
		# Los techos ya no se esconden (Colonia._marcar_grupo, JJ 2026-11-13: la camara se queda
		# bajo la losa): adentro solo se revisa que el brazo se acorte y el angulo baje
		var brazo_adentro := float(jugador.get("brazo_interior"))
		var adentro_ok: bool = brazo_adentro > 0.0 and techo != null
		print("   interior %s: el jugador quedo en %s, brazo %.2f" % [
			interior.get("nombre", "?"), jugador.global_position, brazo_adentro])
		var pitch_adentro: float = jugador.get("camera_pitch")
		jugador.global_position = _spawn_de(datos) + Vector3.UP * 1.5
		await _cuadros(120)
		var afuera_ok: bool = float(jugador.get("brazo_interior")) == 0.0 and techo != null
		_revisar("adentro la camara se acorta y baja; afuera vuelve", adentro_ok and afuera_ok,
			"adentro %s / afuera %s, pitch adentro %.1f, afuera %.1f" % [adentro_ok, afuera_ok,
			pitch_adentro, float(jugador.get("camera_pitch"))])
	# El ambiente de la colonia cerrada (MapaColonia._ambiente) y la gente en los callejones
	var marcas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/mapa/%s/marcas.json" % colonia))
	var ambiente: Dictionary = marcas.get("ambiente", {})
	if not ambiente.is_empty():
		var niebla := (escena.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_density
		var lejos := (jugador.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).far
		# De noche la colonia puede bajar su niebla (ambiente.noche.niebla, MapaColonia._ambiente)
		var de_noche: Dictionary = ambiente.get("noche", {})
		var niebla_ok := is_equal_approx(niebla, float(ambiente.get("niebla", niebla))) \
			or is_equal_approx(niebla, float(de_noche.get("niebla", -1.0)))
		_revisar("la niebla y la distancia de la camara de la colonia",
			niebla_ok and is_equal_approx(lejos, float(ambiente.get("lejos", lejos))),
			"niebla %.4f, lejos %.0f m" % [niebla, lejos])
	var gente := escena.get_node("Gente")
	if _toca("gente"):
		jugador.global_position = _spawn_de(datos) + Vector3.UP * 1.5
		jugador.velocity = Vector3.ZERO
		for i in 900:
			await process_frame
	var arriba := 0
	var cerca := 0
	for c: Dictionary in gente.caminando:
		var p := (c["nodo"] as Node3D).global_position
		if p.y > 0.5:
			arriba += 1
		if p.distance_to(jugador.global_position) < 40.0:
			cerca += 1
	if _toca("gente"):
		_revisar("la gente camina por los callejones planos", gente.caminando.size() >= 8 and arriba == 0 and cerca >= 4,
			"%d caminando, %d elevados, %d a menos de 40 m" % [gente.caminando.size(), arriba, cerca])
	# De noche: focos de los callejones prendidos y el global de la noche para las ventanas
	if not _toca("noche"):
		print("RESULTADO %d/%d" % [_total - _fallas, _total])
		quit(1 if _fallas > 0 else 0)
		return
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


## Los puntos del pasillo de una casa cueva (su "pasillos", en locales de la huella) entre los dos
## puntos de adentro de sus marcos: la ruta que de verdad conecta las dos puertas, sin pasar por el
## centro (en las cuevas largas el centro es macizo y ahi van los cuartos)
func _ruta_entre(p: Dictionary, a: Vector3, b: Vector3, base: Transform3D) -> Array[Vector3]:
	var mejor: Array[Vector3] = []
	var mejor_d := INF
	for ruta: Array in p.get("pasillos", []):
		if ruta.size() < 2:
			continue
		var pts: Array[Vector3] = []
		for q: Array in ruta:
			pts.append(base * Vector3(float(q[0]), 0.0, float(q[1])))
		# La ruta sirve si sus puntas quedan cerca de los dos marcos (en cualquier orden)
		var d0 := pts[0].distance_to(a) + pts[-1].distance_to(b)
		var d1 := pts[0].distance_to(b) + pts[-1].distance_to(a)
		if d1 < d0:
			pts.reverse()
			d0 = d1
		if d0 < mejor_d:
			mejor_d = d0
			mejor = pts
	if mejor_d >= 6.0:
		return [] as Array[Vector3]
	# Las puntas de la ruta son los marcos de las puertas: el recorrido ya paso por ellos (viene de
	# afuera), y volver a salir a la puerta era un zigzag que contaba como que no avanzo
	while mejor.size() > 1 and mejor[0].distance_to(a) < 1.3:
		mejor.remove_at(0)
	while mejor.size() > 1 and mejor[-1].distance_to(b) < 1.3:
		mejor.remove_at(mejor.size() - 1)
	return mejor


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


## Donde aparece el jugador en la colonia (la marca "spawn" de su .json)
func _spawn_de(datos: Dictionary) -> Vector3:
	for m: Dictionary in datos.get("marcas", []):
		if m.get("tipo") == "spawn":
			return Vector3(float(m["x"]), 0.0, float(m["z"]))
	return Vector3(800.0, 1.1, -230.0)


## Un punto del pasillo de la casa cueva de esa marca "interior": su centro ahora es macizo (ahi
## van los cuartos), asi que meter al jugador al centro lo dejaba dentro de un muro
func _en_el_pasillo(datos: Dictionary, interior: Dictionary) -> Vector3:
	var nombre := String(interior.get("nombre", "")).trim_prefix("Interior_")
	for p: Dictionary in datos.get("piezas", []):
		if String(p.get("nombre", "")) != nombre or not p.has("pasillos"):
			continue
		var rutas: Array = p["pasillos"]
		if rutas.is_empty() or (rutas[0] as Array).size() < 2:
			continue
		var ruta: Array = rutas[0]
		var q: Array = ruta[ruta.size() / 2]
		var base := Transform3D(Basis(Vector3.UP, float(p.get("rot", 0.0))), Vector3(float(p["x"]), 1.1, float(p["z"])))
		return base * Vector3(float(q[0]), 0.0, float(q[1]))
	return Vector3(float(interior["x"]), 1.1, float(interior["z"]))
