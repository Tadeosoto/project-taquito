extends SceneTree

# Prueba sin ventana de La Gotera (docs/mapa/colonias/la_gotera.md): la colonia de Blender del
# tianguis (la_gotera) con sus bocas a la favela, y las rejas abiertas del muro en map_test.
#   godot --path . --headless -s tools/mapa/probar_gotera.gd [-- --favela]
# Con --favela tambien carga la_gotera_favela (si ya esta exportada) y revuelve sus callejones.
#
# Que revisa:
#   - la colonia la_gotera carga con MapaColonia (--colonia= no hace falta: se fuerza aqui), el
#     jugador aparece en su Spawn parado en el piso, hay seis tramos de tianguis y cinco bocas;
#   - sin las entregas de la mafia, pisar una boca te regresa un paso atras y avisa (no cambia de
#     escena); con cinco entregas (Misiones.favela_abierta) la boca manda a la_gotera_favela por
#     ese lado (PasoColonia.colonia y lado), igual que la reja de la muralla manda a map_test;
#   - llegar por la reja norte te deja en su "llegada";
#   - en map_test, FortalezasMapa tiene las dos rejas de La Gotera abiertas (sin poste de en medio)
#     con flecha de entrada, y volver de la colonia por la reja sur te deja afuera de ella;
#   - La Gotera abre las 24 horas sin zombis (MapaColonia.abierto_24h): de noche el tianguis sigue
#     con gente y prende sus luces, las cortinas no bajan, no hay sueltos ni avisos, y en map_test
#     la bandera ya no sigue puesta;
#   - con --favela: de noche se entra a la tienda "Fayuca del Tunel" (su interior propio).

const MAPA := "res://scenes/mapa.tscn"
const MAPA_GRANDE := "res://scenes/map_test.tscn"

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	# Los pasos solo se anotan (no se cambia de escena): se revisan PasoColonia.colonia y lado
	PasoColonia.simular = true
	await _colonia()
	await _noche()
	await _mapa_grande()
	if "--favela" in OS.get_cmdline_user_args():
		await _favela()
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _cargar(ruta: String, colonia: String, lado := "") -> Node:
	PasoColonia.colonia = colonia
	PasoColonia.lado = lado
	var escena: Node = (load(ruta) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(1)
	return escena


func _colonia() -> void:
	var escena := await _cargar(MAPA, "la_gotera", "norte")
	var jugador := escena.get_node("Player") as CharacterBody3D
	var al_llegar := Vector2(jugador.global_position.x, jugador.global_position.z)
	await _cuadros(60)
	_revisar("MapaColonia cargo la_gotera", MapaColonia.actual == "la_gotera", MapaColonia.actual)
	var marcas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((escena.get_node("Colonia") as Colonia).marcas_path))
	var salida_norte: Dictionary = {}
	var bocas := 0
	var tianguis := 0
	for m: Dictionary in marcas["marcas"]:
		if m["tipo"] == "salida_colonia" and m.get("lado") == "norte":
			salida_norte = m
		elif m["tipo"] == "paso":
			bocas += 1
		elif m["tipo"] == "tianguis":
			tianguis += 1
	_revisar("llega por la reja norte a su llegada", not salida_norte.is_empty() and al_llegar.distance_to(Vector2(salida_norte["llegada"][0], salida_norte["llegada"][1])) < 0.1,
		"jugador en %s" % al_llegar)
	_revisar("parado en el piso", jugador.is_on_floor() and absf(jugador.global_position.y - 1.0) < 0.3,
		"y = %.2f, en el piso: %s" % [jugador.global_position.y, jugador.is_on_floor()])
	_revisar("seis tramos de tianguis", tianguis == 6, str(tianguis))
	_revisar("cinco bocas a la favela", bocas == 5, str(bocas))
	var colonia := escena.get_node("Colonia")
	_revisar("los tramos se armaron", colonia.find_children("Tianguis_*", "Node3D", false, false).size() == 6, "")
	var boca := colonia.get_node_or_null("Boca_privada_fuga") as Area3D
	_revisar("esta la boca de la Privada de la Fuga", boca != null, "")
	var guardias := 0
	for v in colonia.find_children("Guardia_*", "Node3D", false, false):
		guardias += 1
	_revisar("un guardia por boca", guardias == 5, str(guardias))
	if boca == null:
		escena.queue_free()
		await _cuadros(2)
		return
	# Sin entregas: la boca te regresa y no cambia de escena
	var misiones := root.get_node("/root/Misiones")
	misiones._hechas_siempre.clear()
	var antes := boca.global_position
	jugador.global_position = antes + Vector3(0.0, 1.0, 0.0)
	jugador.velocity = Vector3.ZERO
	await _cuadros(6)
	var d := Vector2(jugador.global_position.x - antes.x, jugador.global_position.z - antes.z).length()
	_revisar("sin entregas el guardia te regresa", d > 1.5 and PasoColonia.lado == "" and PasoColonia.colonia == "la_gotera",
		"a %.2f m de la flecha; colonia %s lado '%s'" % [d, PasoColonia.colonia, PasoColonia.lado])
	# Sin candados (scenes/prueba_gotera.tscn): pasa aunque falten las entregas
	PasoColonia.sin_candados = true
	jugador.global_position = antes + Vector3(0.0, 1.0, 0.0)
	jugador.velocity = Vector3.ZERO
	await _cuadros(3)
	_revisar("sin candados la boca deja pasar sin entregas", PasoColonia.colonia == "la_gotera_favela" and PasoColonia.lado == "privada_fuga",
		"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	PasoColonia.sin_candados = false
	PasoColonia.colonia = "la_gotera"
	PasoColonia.lado = ""
	jugador.global_position = antes + Vector3(0.0, 1.0, 3.0)
	await _cuadros(3)
	# Con cinco entregas: pasa a la favela por ese lado
	for i in range(1, 6):
		misiones._hechas_siempre["mafia_%d" % i] = true
	_revisar("favela_abierta con cinco entregas", misiones.favela_abierta(), str(misiones.entregas_mafia()))
	jugador.global_position = antes + Vector3(0.0, 1.0, 0.0)
	jugador.velocity = Vector3.ZERO
	await _cuadros(3)
	_revisar("con entregas la boca manda a la favela", PasoColonia.colonia == "la_gotera_favela" and PasoColonia.lado == "privada_fuga",
		"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	PasoColonia.lado = ""
	escena.queue_free()
	await _cuadros(2)
	# Y la reja: con "libre" manda a map_test sin pedir la guardia de Chuy
	escena = await _cargar(MAPA, "la_gotera")
	jugador = escena.get_node("Player")
	await _cuadros(30)
	var salida := escena.get_node("Colonia").get_node_or_null("Salida_norte") as Area3D
	_revisar("esta la salida norte", salida != null, "")
	if salida:
		jugador.global_position = salida.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(3)
		_revisar("la reja norte sale a map_test sin pedir la guardia", PasoColonia.lado == "norte" and PasoColonia.colonia == "la_gotera",
			"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	PasoColonia.lado = ""
	escena.queue_free()
	await _cuadros(2)


func _anochecer(escena: Node) -> void:
	var ciclo := escena.get_node("Ciclo")
	ciclo.set("_tiempo", float(ciclo.get("dia_duracion")) + 200.0)
	await _cuadros(40)


func _noche() -> void:
	var escena := await _cargar(MAPA, "la_gotera")
	await _cuadros(30)
	_revisar("La Gotera abre las 24 horas", MapaColonia.abierto_24h, "")
	await _anochecer(escena)
	_revisar("ya es de noche", escena.get_node("Ciclo").es_noche(), "")
	var zombis := escena.get_node("Zombis")
	_revisar("sin zombis sueltos ni Saltabardas", not zombis.espontaneos and not zombis.saltabardas, "")
	var luces := 0
	var prendidas := 0
	var de_dia := 0
	var tramos := escena.get_node("Colonia").find_children("Tianguis_*", "Node3D", false, false)
	for t in tramos:
		if t.get("_es_de_dia"):
			de_dia += 1
		for l in t.find_children("Luz_*", "OmniLight3D", false, false):
			luces += 1
			if (l as Light3D).visible:
				prendidas += 1
	_revisar("de noche el tianguis sigue puesto", de_dia == tramos.size() and tramos.size() == 6, "%d de %d" % [de_dia, tramos.size()])
	_revisar("de noche prenden las luces del tianguis", luces >= tramos.size() and prendidas == luces, "%d de %d" % [prendidas, luces])
	_revisar("de noche sigue la gente", escena.get_node("Gente").hay_gente(), "")
	_revisar("las cortinas no bajan", float(escena.get_node("Puntos").get("_cierre")) <= 0.0, str(escena.get_node("Puntos").get("_cierre")))
	escena.queue_free()
	await _cuadros(2)


func _mapa_grande() -> void:
	# Se llega de la colonia por la reja sur: el jugador aparece afuera de ella
	var escena := await _cargar(MAPA_GRANDE, "la_gotera", "sur")
	_revisar("en map_test ya no sigue abierto las 24 horas", not MapaColonia.abierto_24h, "")
	var jugador := escena.get_node("Player") as Node3D
	var donde := Vector2(jugador.global_position.x, jugador.global_position.z)
	var reja: Vector2 = FortalezasMapa.GOTERA_REJAS[1][0]
	await _cuadros(20)
	_revisar("vuelve de la colonia afuera de la reja sur", donde.distance_to(reja) > 4.0 and donde.distance_to(reja) < 7.0 and donde.y > reja.y,
		"jugador en %s, reja en %s" % [donde, reja])
	var fortalezas := escena.get_node("Fortalezas") as FortalezasMapa
	var entradas := fortalezas.find_children("Entrada_*", "Area3D", false, false)
	_revisar("las dos rejas de La Gotera tienen flecha de entrada", entradas.size() == 2, str(entradas.size()))
	var rejas := fortalezas.find_children("Reja*", "Node3D", false, false)
	var abiertas := 0
	for r in rejas:
		var hojas := r.get_node_or_null("Hojas")
		# Abierta: sin el poste de en medio (la primera caja de las hojas cerradas) y con dos raices giradas
		if hojas and hojas.get_child_count() >= 2 and hojas.get_child(0) is Node3D and not (hojas.get_child(0) is MeshInstance3D):
			abiertas += 1
	_revisar("las rejas de La Gotera estan abiertas", abiertas == 2, "%d de %d" % [abiertas, rejas.size()])
	_revisar("ya no hay letrero de solo gente de la casa en la muralla", fortalezas.find_children("*", "Label3D", true, false).filter(
		func(l: Label3D) -> bool: return l.text.to_lower().contains("gente de la casa")).is_empty(), "")
	# Pisar la flecha de entrada manda a la colonia la_gotera por ese lado
	var entrada: Area3D = null
	for e in entradas:
		if e.name == "Entrada_norte":
			entrada = e
	if entrada and jugador is CharacterBody3D:
		jugador.global_position = entrada.global_position + Vector3(0.0, 1.0, 0.0)
		(jugador as CharacterBody3D).velocity = Vector3.ZERO
		await _cuadros(3)
		_revisar("la flecha de la reja norte entra a la_gotera", PasoColonia.colonia == "la_gotera" and PasoColonia.lado == "norte",
			"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	PasoColonia.lado = ""
	escena.queue_free()
	await _cuadros(2)


func _favela() -> void:
	var escena := await _cargar(MAPA, "la_gotera_favela", "privada_fuga")
	var jugador := escena.get_node("Player") as CharacterBody3D
	await _cuadros(60)
	_revisar("favela: parado en el piso", jugador.is_on_floor(), "y = %.2f" % jugador.global_position.y)
	var colonia := escena.get_node("Colonia")
	_revisar("favela: cinco bocas de regreso", colonia.find_children("Boca_*", "Area3D", false, false).size() == 5, "")
	var boca := colonia.get_node_or_null("Boca_privada_fuga") as Area3D
	if boca:
		jugador.global_position = boca.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(3)
		_revisar("favela: la boca regresa al tianguis por el mismo lado", PasoColonia.colonia == "la_gotera" and PasoColonia.lado == "privada_fuga",
			"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	# Las tiendas de favela, el minimapa propio, el tinaco sin Virgen y el giro con WASD
	var puntos := escena.get_node("Puntos")
	var giros := {}
	for p: Dictionary in puntos._puntos:
		giros[String(p.get("tipo", ""))] = true
	_revisar("favela: seis tiendas, una por giro, sin purificadora",
			["abarrotes", "licoreria", "farmacia", "ferreteria", "oxxo", "taqueria"].all(func(g: String) -> bool: return giros.has(g))
			and not giros.has("purificadora") and puntos._puntos.size() == 6, str(giros.keys()))
	jugador.global_position = Vector3(822.0, 3.0, -220.0)
	jugador.velocity = Vector3.ZERO
	await _cuadros(90)
	_revisar("favela: las tiendas se armaron", puntos._nodes.size() >= 6, str(puntos._nodes.size()))
	var puertas_ok := true
	for p: Dictionary in puntos._puntos:
		if not p.get("puerta_transitable", false):
			puertas_ok = false
	_revisar("favela: las puertas son transitables", puertas_ok, "")
	var miniatura := escena.get_node("Minimapa")
	var tipos_icono := {}
	for ic: Dictionary in miniatura._iconos:
		tipos_icono[String(ic.get("tipo", ""))] = true
	_revisar("favela: minimapa propio (sin OSM)",
			miniatura.mapa != null and miniatura.mapa.resource_path.ends_with("minimapa_la_gotera_favela.png")
			and miniatura.datos_path.ends_with("la_gotera_favela/minimapa.json")
			and miniatura._iconos.size() >= 6
			# Por ahora sin tunel subterraneo ni escaleras a las azoteas: solo el tinaco y las salidas
			and tipos_icono.has("tinaco") and tipos_icono.has("salida"),
			"%s / %s / %d iconos %s" % [miniatura.mapa.resource_path if miniatura.mapa else "sin mapa", miniatura.datos_path, miniatura._iconos.size(), str(tipos_icono.keys())])
	var tinacos := colonia.find_children("*", "TinacoComunitario", true, false)
	var tinaco: Node = tinacos[0] if not tinacos.is_empty() else null
	_revisar("favela: hay un tinaco comunitario", tinaco != null, str(tinacos.size()))
	if tinaco:
		_revisar("favela: el tinaco no tiene Virgen ni ofrenda",
				tinaco.find_child("ManchaVirgen", true, false) == null
				and tinaco.find_child("Ofrenda", true, false) == null
				and tinaco.find_child("Petalos", true, false) == null
				and tinaco.find_child("LuzVeladoras", true, false) == null,
				"hijos: %s" % [tinaco.get_children().map(func(n: Node) -> String: return n.name)])
		_revisar("favela: tinaco de 50 mil litros, sin defensa",
				absf(float(tinaco.get("alto")) - 4.79) < 0.1 and absf(float(tinaco.get("radio")) - 1.87) < 0.1
				and not tinaco.is_in_group("tinaco_comunitario"),
				"alto %.2f, radio %.2f" % [float(tinaco.get("alto")), float(tinaco.get("radio"))])
	_revisar("favela: el callejon gira con WASD", jugador.giro_con_wasd, str(jugador.giro_con_wasd))
	var colonia_datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/blender/mapa/colonias/la_gotera_favela.json"))
	var lotes_claros: Array = []
	for p: Dictionary in colonia_datos["piezas"]:
		if p.get("tipo") == "lote" and p.get("claro"):
			lotes_claros.append(p)
	var grandes := lotes_claros.filter(func(p: Dictionary) -> bool: return float(p["tam"][0]) > 18.0)
	var chicos := lotes_claros.filter(func(p: Dictionary) -> bool: return float(p["tam"][0]) <= 18.0)
	var dist_min := INF
	for i in grandes.size():
		for j in range(i + 1, grandes.size()):
			dist_min = minf(dist_min, Vector2(float(grandes[i]["x"]), float(grandes[i]["z"])).distance_to(
				Vector2(float(grandes[j]["x"]), float(grandes[j]["z"]))))
	_revisar("favela: 4 claros grandes (tinaco + 3) y 4 pequenos", lotes_claros.size() == 8 and grandes.size() == 4 and chicos.size() == 4,
		"%d total, %d grandes, %d pequenos" % [lotes_claros.size(), grandes.size(), chicos.size()])
	_revisar("favela: los claros grandes estan repartidos", dist_min >= 40.0, "separacion minima %.1f m" % dist_min)
	var casa_azotea: Dictionary = {}
	var techo := INF
	var espacio: PhysicsDirectSpaceState3D = escena.get_world_3d().direct_space_state
	for p: Dictionary in colonia_datos["piezas"]:
		if p.get("tipo") != "casa" or p.get("local") or int(p.get("pisos", 1)) < 1:
			continue
		var rayo := PhysicsRayQueryParameters3D.create(
			Vector3(float(p["x"]), 20.0, float(p["z"])), Vector3(float(p["x"]), -1.0, float(p["z"])), 1)
		var pego: Dictionary = espacio.intersect_ray(rayo)
		if not pego.is_empty() and float(pego.position.y) > 3.2:
			casa_azotea = p
			techo = float(pego.position.y)
			break
	if not casa_azotea.is_empty():
		jugador.global_position = Vector3(float(casa_azotea["x"]), techo + 1.1, float(casa_azotea["z"]))
		jugador.velocity = Vector3.ZERO
		await _cuadros(40)
		_revisar("favela: en la azotea no gira con WASD", not jugador.giro_con_wasd,
				"techo %.2f, y %.2f, en piso %s" % [techo, jugador.global_position.y, jugador.is_on_floor()])
	else:
		_revisar("favela: hay azoteas caminables", false, "ninguna casa con choque arriba de 3.2 m")
	# Las tiendas de la favela dan a un patio: se entra, se sale y quedas parado en el patio, no
	# metido en la casa de enfrente
	var interiores := escena.get_node("Interiores")
	var salen := 0
	var tiendas_favela := 0
	var flechas: Array = []
	for n in puntos.find_children("Flecha", "MeshInstance3D", true, false):
		if n.get_parent() is Area3D:
			flechas.append(n.get_parent())
	for flecha: Node3D in flechas:
		var m := {"giro": String(flecha.get_parent().name)}
		tiendas_favela += 1
		jugador.global_position = flecha.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(90)
		if interiores.get("_interior") == null:
			print("   %s: no entro" % m["giro"])
			continue
		interiores.call("_salir")
		await _cuadros(90)
		var forma := PhysicsShapeQueryParameters3D.new()
		var capsula := CapsuleShape3D.new()
		capsula.radius = 0.38
		capsula.height = 1.6
		forma.shape = capsula
		forma.transform = Transform3D(Basis(), jugador.global_position + Vector3.UP * 0.15)
		forma.exclude = [jugador.get_rid()]
		var encima: Array = espacio.intersect_shape(forma, 4)
		var bien := interiores.get("_interior") == null and jugador.is_on_floor() and jugador.global_position.y < 1.6 and encima.is_empty()
		print("   %s: salio en %s, en piso %s, choca con %d" % [m["giro"], jugador.global_position, jugador.is_on_floor(), encima.size()])
		if bien:
			salen += 1
	_revisar("favela: se entra y se sale de cada tienda a su patio", tiendas_favela == 6 and salen == tiendas_favela,
		"%d de %d" % [salen, tiendas_favela])
	# De noche se entran las tiendas del tunel (dentro de las casas abandonadas de la cueva) y
	# abren su interior propio; al salir quedas parado adentro de la casa
	PasoColonia.lado = ""
	await _anochecer(escena)
	for giro in ["fayuca_tunel", "armas_tunel"]:
		var puerta: Area3D = null
		for m: Dictionary in colonia_datos.get("marcas", []):
			if m.get("tipo") == "puerta" and m.get("giro") == giro:
				puerta = colonia.get_node_or_null(String(m["nombre"])) as Area3D
		_revisar("favela: esta la puerta de %s" % giro, puerta != null, "")
		if puerta == null:
			continue
		jugador.global_position = puerta.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(90)
		var interior = interiores.get("_interior")
		_revisar("favela: de noche se entra a %s" % giro, interior != null and interior.giro == giro,
			"interior %s" % (interior.giro if interior else "ninguno"))
		if interior != null:
			interiores.call("_salir")
			await _cuadros(90)
			_revisar("favela: se sale de %s parado en la casa" % giro, jugador.is_on_floor() and jugador.global_position.y < 1.6,
				"quedo en %s" % jugador.global_position)
	PasoColonia.lado = ""
	escena.queue_free()
	await _cuadros(2)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
