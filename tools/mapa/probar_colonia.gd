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
	# La tortilleria (giro nuevo, sin negocio en puntos.json): su flecha mete y vende tortillas
	for m: Dictionary in marcas["marcas"]:
		if m.get("giro", "") == "tortilleria":
			jugador.global_position = Vector3(m["x"], 1.2, m["z"])
			await _cuadros(120)
			var adentro: Node = interiores.get("_interior")
			var vende := false
			if adentro:
				for item: InventoryItemData in adentro.get("productos"):
					vende = vende or item.item_name == "Kilo de tortillas"
			_revisar("la tortilleria vende tortillas", vende, "%s" % adentro)
			if adentro:
				interiores.call("_salir")
				await _cuadros(90)
	await _subir_banqueta(escena)
	await _pelota(escena)
	await _vida(escena)
	await _casa(escena)
	await _vecinos(escena)
	print("RESULTADO: %s" % ("BIEN" if _fallas == 0 else "%d FALLAS" % _fallas))
	quit(_fallas)


# Un cuerpo como el del jugador (capsula de 0.4 x 2 m) camina en linea recta: la guarnicion de
# la banqueta (15 cm) y la escalera de una ruta de azoteas son rampas de choque, porque el
# CharacterBody3D no sube escalones, asi que tiene que subirse y no atorarse.
# Banqueta: de en medio de la calle Pipilingue (Santa Mugre) a la banqueta del norte.
const SUBIDA_DESDE := Vector3(-250.0, 1.1, 328.5)
const SUBIDA_HACIA := Vector3(0.0, 0.0, -1.0)
# Escalera: la de la ruta de azoteas de Pipilingue (rutas del .json), de la banqueta hacia arriba
const ESCALERA := "Ruta_Pipilingue_Escalera"
const AZOTEA := 5.5         # m: dos pisos (bloqueo.ALTO_AZOTEA)
const CANCHA_DESDE := Vector3(-406.0, 1.2, 305.5)


func _subir_banqueta(escena: Node) -> void:
	var r := await _caminar(escena, SUBIDA_DESDE, SUBIDA_HACIA, 150)
	_revisar("sube la banqueta", r["subio"] > 0.1 and r["avance"] > 4.0,
		"subio %.2f m, avanzo %.1f m (hasta %s)" % [r["subio"], r["avance"], r["hasta"]])
	var colonia: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/blender/mapa/colonias/santa_mugre.json"))
	for p: Dictionary in colonia["piezas"]:
		if p["nombre"] != ESCALERA:
			continue
		# Su +X local (con su sentido) es hacia donde sube y su +Z da a la calle; se arranca medio
		# metro antes del primer escalon, a media escalera de ancho
		var base := Basis(Vector3.UP, float(p["rot"]))
		var sube := base.x * float(p.get("sentido", 1))
		var desde := Vector3(p["x"], 1.2, p["z"]) + base.z * 0.5 - sube * 0.8
		var e := await _caminar(escena, desde, sube, 300)
		_revisar("sube la escalera a la azotea", e["y_max"] - 1.0 > AZOTEA - 0.4,
			"llego a %.2f m (azotea a %.2f)" % [e["y_max"] - 1.0, AZOTEA])
	# La cancha encajonada: del callejon que sale de Pelagatos se entra por la reja hasta la
	# media cancha (el muro de la entrada esta en x -398.3)
	var c := await _caminar(escena, CANCHA_DESDE, Vector3(1.0, 0.0, 0.0), 300)
	_revisar("entra a la cancha", c["hasta"].x > -394.0, "hasta %s" % c["hasta"])
	# Un tope de la avenida (colonia.topes: Tope_Calle_1_0_1) se pasa por encima sin atorarse
	var t := await _caminar(escena, Vector3(-238.98, 1.2, 463.98), Vector3(-1.0, 0.0, -0.04).normalized(), 200)
	_revisar("pasa el tope de la avenida", t["hasta"].x < -247.0 and t["subio"] > 0.03 and t["subio"] < 0.4,
		"subio %.2f m, hasta %s" % [t["subio"], t["hasta"]])
	# El pasillo de 1.1 m entre Bahia de Sin Agua y la calle de la vecindad se cruza caminando
	var p := await _caminar(escena, Vector3(-273.5, 1.2, 418.0), Vector3(1.0, 0.0, 0.0), 760)
	_revisar("se cruza el pasillo del tianguis", p["hasta"].x > -237.0, "hasta %s" % p["hasta"])
	# y la escalera del mirador (Cancha_Mirador_Escalera) sube a su azotea, que ve a la cancha
	var m := await _caminar(escena, Vector3(-406.4, 1.2, 306.6), Vector3(1.0, 0.0, 0.0), 300)
	_revisar("sube al mirador de la cancha", m["y_max"] - 1.0 > AZOTEA - 0.4,
		"llego a %.2f m (azotea a %.2f)" % [m["y_max"] - 1.0, AZOTEA])


func _caminar(escena: Node, desde: Vector3, hacia: Vector3, cuadros: int) -> Dictionary:
	var cuerpo := CharacterBody3D.new()
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.4
	capsula.height = 2.0
	forma.shape = capsula
	cuerpo.add_child(forma)
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
		if i == 20:
			y_calle = cuerpo.global_position.y
		if i > 20:
			y_max = maxf(y_max, cuerpo.global_position.y)
		await physics_frame
	var r := {"subio": y_max - y_calle, "y_max": y_max, "hasta": cuerpo.global_position,
		"avance": ((cuerpo.global_position - desde) * Vector3(1, 0, 1)).length()}
	cuerpo.queue_free()
	return r


# La casa del jugador (la de JJ, CasaPropia.gd): pisar su flecha te mete (500 m arriba), adentro
# no hay pelea ni dano, y su flecha de adentro te saca frente a la de la calle
func _casa(escena: Node) -> void:
	var casa := escena.get_node_or_null("Colonia/CasaPropia")
	_revisar("esta la casa propia", casa != null, "")
	if casa == null:
		return
	var jugador := escena.get_node("Player") as Player
	jugador.global_position = (casa.get("flecha_en") as Vector3) + Vector3.UP * 1.2
	await _cuadros(120)
	_revisar("la flecha mete a la casa", jugador.global_position.y > 400.0 and jugador.sin_combate,
		"jugador en %s, sin combate: %s" % [jugador.global_position, jugador.sin_combate])
	var vida: int = root.get_node("Salud").vida
	jugador.recibir_dano(30, jugador.global_position + Vector3.FORWARD)
	_revisar("adentro no hay dano", root.get_node("Salud").vida == vida, "")
	# Los muebles (MueblesCasa.gd): la cama salta a la siguiente orilla y cura; el baul guarda
	var muebles := casa.find_child("MueblesCasa*", true, false)
	if muebles == null:
		for n in casa.find_children("*", "Node3D", true, false):
			if n.get_script() == load("res://scripts/interiores/MueblesCasa.gd"):
				muebles = n
	var usar := muebles.find_children("Usar*", "Area3D", true, false) if muebles else []
	_revisar("los muebles se usan", usar.size() >= 8, "%d muebles" % usar.size())
	if muebles:
		var ciclo := escena.get_node("Ciclo")
		var salud := root.get_node("Salud")
		salud.vida = 10
		var noche_antes: bool = ciclo.es_noche()
		muebles.call("_dormir")
		await _cuadros(150)
		_revisar("la cama cura y cambia la hora", salud.vida == salud.vida_max and ciclo.es_noche() != noche_antes,
			"vida %d/%d, noche antes %s ahora %s" % [salud.vida, salud.vida_max, noche_antes, ciclo.es_noche()])
		var inventario := root.get_node("Inventory")
		var baul := root.get_node("Baul")
		var item: InventoryItemData = inventario.items[0] if inventario.items.size() > 0 else null
		if item:
			inventario.remove_item(0)
			baul.guardar(item)
			var regresa: InventoryItemData = baul.sacar(baul.items.size() - 1)
			inventario.add_item(regresa)
			_revisar("el baul guarda y regresa", regresa == item, item.item_name)
	casa.call("_salir")
	await _cuadros(90)
	_revisar("sale de la casa", jugador.global_position.y < 10.0 and not jugador.sin_combate,
		"jugador en %s" % jugador.global_position)


# Las casas de los vecinos (CasaVecino.gd): cada una con quien vive; el taller de Sofia no abre
# de dia; lo de la clausurada sale una vez por partida
func _vecinos(escena: Node) -> void:
	var jugador := escena.get_node("Player") as Player
	var ciclo := escena.get_node("Ciclo")
	for nombre: String in ["Casa_guero", "Casa_tono", "Casa_clausurada", "Casa_sofia"]:
		var casa := escena.get_node_or_null("Colonia/" + nombre)
		if casa == null:
			_revisar("esta " + nombre, false, "")
			continue
		var noche := nombre == "Casa_sofia"
		if noche:
			ciclo.set("_tiempo", 100.0)
			await _cuadros(20)
			jugador.global_position = (casa.get("flecha_en") as Vector3) + Vector3.UP * 1.2
			await _cuadros(60)
			_revisar("el taller de Sofia no abre de dia", casa.get("_casa") == null, "")
			jugador.global_position += Vector3(0, 0, 4)
			ciclo.set("_tiempo", float(ciclo.get("dia_duracion")) + 30.0)
			await _cuadros(30)
		jugador.global_position = (casa.get("flecha_en") as Vector3) + Vector3.UP * 1.2
		await _cuadros(120)
		var adentro: Node = casa.get("_casa")
		var detalle := ""
		var bien := adentro != null and jugador.global_position.y > 400.0
		if adentro and nombre != "Casa_clausurada":
			bien = bien and adentro.get_node_or_null("Vecino") != null
		if adentro and nombre == "Casa_clausurada":
			var botin := adentro.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n.has_method("interact") and not n is Area3D).size()
			detalle = "%d cosas tiradas" % botin
			bien = bien and botin > 0
		_revisar("se entra a " + nombre, bien, detalle)
		if adentro:
			casa.call("_salir")
			await _cuadros(90)
	var clausurada := escena.get_node_or_null("Colonia/Casa_clausurada")
	if clausurada:
		jugador.global_position = (clausurada.get("flecha_en") as Vector3) + Vector3.UP * 1.2
		await _cuadros(120)
		var otra_vez: Node = clausurada.get("_casa")
		var quedan := otra_vez.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n.has_method("interact") and not n is Area3D).size() if otra_vez else -1
		_revisar("la clausurada ya no tiene nada la segunda vez", quedan == 0, "%d" % quedan)
		if otra_vez:
			clausurada.call("_salir")
			await _cuadros(90)


# Lo de juego de la colonia (paso 5): una pieza del mapa, gente en las banquetas, quien da
# misiones y zombis de noche (despues de la calma del principio, RitmoNoche.calma_inicial)
const NOCHE_ESPERA := 90.0     # s de noche (cuadros de fisica) para que salga el primero


func _vida(escena: Node) -> void:
	# De lejos (mas de NinosCancha.LEJOS) no se dibujan: se para al jugador junto a la cancha
	var jugador := root.get_tree().get_first_node_in_group("jugador") as Node3D
	var antes := jugador.global_position
	jugador.global_position = Vector3(-401.0, 1.2, 304.0)
	await _cuadros(90)
	var chamacos := escena.find_child("Ninos_Cancha", true, false) as Node3D
	_revisar("de dia juegan chamacos en la cancha", chamacos != null and chamacos.visible and chamacos.get_child_count() > 3,
		"%s" % chamacos)
	jugador.global_position = antes
	await _cuadros(5)
	var piezas := root.get_tree().get_nodes_in_group("piezas_mapa").size()
	var botin := 0
	for n in escena.find_children("Botin_*", "", true, false):
		if (n as Node3D).global_position.y > 4.0:
			botin += 1
	_revisar("hay botin en las azoteas", botin >= 3, "%d" % botin)
	_revisar("hay pieza del mapa", piezas > 0, "%d" % piezas)
	var gente := escena.get_node("Gente").get_child_count()
	_revisar("hay gente en la calle", gente > 0, "%d" % gente)
	var npcs := root.get_tree().get_nodes_in_group("npc").size()
	_revisar("hay quien da misiones", npcs > 0, "%d npc" % npcs)
	var reflector := escena.find_child("Reflector_Cancha_0", true, false) as Light3D
	_revisar("reflector de la cancha apagado de dia", reflector != null and not reflector.visible, "%s" % reflector)
	var ciclo := escena.get_node("Ciclo")
	ciclo.set("_tiempo", float(ciclo.get("dia_duracion")) + 30.0)
	var zombis := 0
	for i in int(NOCHE_ESPERA * 60):
		await physics_frame
		if i % 60 == 0:
			zombis = root.get_tree().get_nodes_in_group("zombis").filter(func(z: Node) -> bool: return z.is_inside_tree() and (z as Node3D).visible).size()
			if zombis > 0:
				break
	_revisar("salen zombis de noche", zombis > 0, "%d" % zombis)
	_revisar("reflector de la cancha prendido de noche", reflector != null and reflector.visible and reflector.light_energy > 1.0,
		"energia %.2f" % (reflector.light_energy if reflector else -1.0))
	var ninos := escena.find_child("Ninos_Cancha", true, false) as Node3D
	var guardia := escena.find_child("Guardia_GelA_0", true, false) as Node3D
	_revisar("de noche no hay chamacos ni guardias", ninos != null and not ninos.visible and guardia != null and not guardia.visible,
		"%s %s" % [ninos, guardia])
	var trampa := escena.find_child("Trampa_Cancha", true, false)
	_revisar("la cancha atrapa de noche", trampa != null and trampa.call("adentro", Vector3(-392.0, 1.0, 305.5))
		and not trampa.call("adentro", Vector3(-372.0, 1.0, 432.0)), "%s" % trampa)
	var foco := escena.find_child("Foco_0", true, false) as Light3D
	_revisar("foco del callejon prendido de noche", foco != null and foco.visible, "%s" % foco)


# La mision de la cancha: el profe esta en su marca, la pelota en la azotea del mirador y al
# levantarla toca regresarsela (MisionData.donde y RECOGER con "marca:")
func _pelota(escena: Node) -> void:
	var misiones := root.get_node("/root/Misiones")
	var mision: MisionData = null
	for m: MisionData in misiones.get("todas"):
		if m.id == "pelota":
			mision = m
	var mundo := escena.find_children("*", "MisionesMundo", true, false)
	if mision == null or mundo.is_empty():
		_revisar("hay mision de la pelota", false, "mision %s, MisionesMundo %d" % [mision, mundo.size()])
		return
	var profe: Transform3D = Colonia.puntos_mision.get("Profe_Cancha", Transform3D())
	var lugar := Vector3.INF
	for v: Dictionary in mundo[0].get("vecinos"):
		if v["mision"] == mision:
			lugar = v["lugar"]
	_revisar("el profe esta en la cancha", lugar.distance_to(profe.origin) < 0.5, "%s" % lugar)
	misiones.call("aceptar", mision)
	await _cuadros(5)
	var cosa: Node3D = mundo[0].get("_perro")
	var pelota: Transform3D = Colonia.puntos_mision.get("Pelota", Transform3D())
	_revisar("la pelota esta en la azotea", cosa != null and cosa.global_position.distance_to(pelota.origin) < 0.5,
		"%s" % (cosa.global_position if cosa else Vector3.INF))
	if cosa:
		cosa.call("interact")
		await _cuadros(5)
	var paso: PasoMision = misiones.call("paso")
	_revisar("con la pelota toca regresarla", paso != null and paso.tipo == PasoMision.Tipo.ENTREGAR, "%s" % paso)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])
	if not bien:
		_fallas += 1


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
