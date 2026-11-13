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
	# De noche se entra a la tienda del tunel y abre su interior propio
	PasoColonia.lado = ""
	await _anochecer(escena)
	var puerta := colonia.get_node_or_null("Puerta_Tunel_Tienda_2") as Area3D
	_revisar("favela: esta la puerta de la Fayuca del Tunel", puerta != null, "")
	if puerta:
		jugador.global_position = puerta.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(90)
		var interior = escena.get_node("Interiores").get("_interior")
		_revisar("favela: de noche se entra a la Fayuca del Tunel", interior != null and interior.giro == "fayuca_tunel",
			"interior %s" % (interior.giro if interior else "ninguno"))
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
