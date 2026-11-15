extends SceneTree

# Prueba sin ventana de las fortalezas amuralladas de map_test leidas de datos (S9: MuroColonia con
# resources/map/fortalezas.json).
#   godot --path . --headless -s tools/mapa/probar_fortalezas.gd
#
# Que revisa:
#   - fortalezas.json y santa_mugre.json dicen lo mismo del recorte y las rejas de Santa Mugre;
#   - en map_test hay tres muros (santa_mugre, la_gotera, gela) que se encuentran con MuroColonia.de;
#   - Santa Mugre: dos rejas cerradas con flecha, la lamina encima del block, hacia afuera al poniente y
#     al oriente; La Gotera: dos rejas abiertas con flecha; GelA: caseta, sin rejas ni flechas;
#   - MuroColonia.adentro con los tres poligonos (y fuera del poligono de GelA aunque dentro de su caja);
#   - las dos zonas cerradas a los carros (CallesRuta) se abren al salir de la escena;
#   - volver de la colonia de Santa Mugre por la reja oriente te deja afuera de ella, y pisar la flecha
#     poniente manda a santa_mugre por ese lado.

const MAPA_GRANDE := "res://scenes/map_test.tscn"
const COLONIA_SANTA_MUGRE := "res://tools/blender/mapa/colonias/santa_mugre.json"

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	PasoColonia.simular = true
	_datos()
	await _mapa_grande()
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _datos() -> void:
	var sm: Dictionary = MuroColonia.todas().get("santa_mugre", {})
	var blender: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COLONIA_SANTA_MUGRE))
	var r: Array = blender["recorte"]
	var esquinas := [[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]]
	var iguales := true
	for i in 4:
		iguales = iguales and Vector2(sm["poligono"][i][0], sm["poligono"][i][1]).is_equal_approx(Vector2(esquinas[i][0], esquinas[i][1]))
	_revisar("el poligono de Santa Mugre es el recorte de santa_mugre.json", iguales, str(sm.get("poligono")))
	for reja: Dictionary in blender["rejas"]:
		var nuestra: Dictionary = {}
		for otra: Dictionary in sm["rejas"]:
			if otra["lado"] == reja["lado"]:
				nuestra = otra
		var x: float = r[0] if reja["lado"] == "poniente" else r[2]
		var bien := not nuestra.is_empty() and absf(nuestra["centro"][0] - x) < 0.01 \
				and absf(nuestra["centro"][1] - (reja["z0"] + reja["z1"]) / 2.0) < 0.01 \
				and absf(nuestra["largo"] - (reja["z1"] - reja["z0"])) < 0.01
		_revisar("la reja %s coincide con santa_mugre.json" % reja["lado"], bien, str(nuestra))


func _mapa_grande() -> void:
	# Se llega de la colonia de Santa Mugre por la reja oriente
	PasoColonia.colonia = "santa_mugre"
	PasoColonia.lado = "oriente"
	var escena: Node = (load(MAPA_GRANDE) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(1)
	var jugador := escena.get_node("Player") as CharacterBody3D
	var donde := Vector2(jugador.global_position.x, jugador.global_position.z)
	var sm := MuroColonia.de(self, "santa_mugre")
	var gotera := MuroColonia.de(self, "la_gotera")
	var gela := MuroColonia.de(self, "gela")
	_revisar("tres muros en map_test", sm != null and gotera != null and gela != null and get_nodes_in_group("muro_colonia").size() == 3, "")
	if sm == null or gotera == null or gela == null:
		return
	var oriente: Vector2 = sm.rejas[1]["centro"]
	_revisar("vuelve de Santa Mugre afuera de la reja oriente", donde.distance_to(oriente + Vector2(MuroColonia.LLEGADA_FUERA, 0.0)) < 0.1,
		"jugador en %s, reja en %s" % [donde, oriente])
	_revisar("el lado se consumio", PasoColonia.lado == "", PasoColonia.lado)
	await _cuadros(10)

	_revisar("Santa Mugre: hacia afuera al poniente y al oriente",
		sm.hacia_afuera("poniente").is_equal_approx(Vector3.LEFT) and sm.hacia_afuera("oriente").is_equal_approx(Vector3.RIGHT), "")
	_revisar("Santa Mugre: dos flechas de entrada", sm.find_children("Entrada_*", "Area3D", false, false).size() == 2, "")
	_revisar("Santa Mugre: dos rejas cerradas", _rejas(sm) == Vector2i(2, 0), str(_rejas(sm)))
	var lamina := sm.find_children("*", "MeshInstance3D", true, false).filter(
		func(m: MeshInstance3D) -> bool: return m.position.y > 3.0)
	_revisar("Santa Mugre: lamina encima del block", lamina.size() > 4, str(lamina.size()))
	_revisar("La Gotera: dos flechas de entrada", gotera.find_children("Entrada_*", "Area3D", false, false).size() == 2, "")
	_revisar("La Gotera: dos rejas abiertas", _rejas(gotera) == Vector2i(0, 2), str(_rejas(gotera)))
	_revisar("GelA: caseta, sin rejas ni flechas", gela.get_node_or_null("Caseta") != null and gela.rejas.is_empty()
		and gela.find_children("Entrada_*", "Area3D", false, false).is_empty(), "")

	for prueba: Array in [[Vector2(-300, 370), true, "Santa Mugre"], [Vector2(850, -200), true, "La Gotera"],
			[Vector2(100, -800), true, "GelA"], [Vector2(250, -655), false, "caja de GelA, fuera de la barda"],
			[Vector2(0, 0), false, "afuera"]]:
		var p: Vector2 = prueba[0]
		_revisar("adentro: %s" % prueba[2], MuroColonia.adentro(self, Vector3(p.x, 0.0, p.y)) == prueba[1], str(p))
	_revisar("a 10 m de la barda de Santa Mugre cuenta con margen", sm.contiene(Vector2(-430, 370), 15.0) and not sm.contiene(Vector2(-430, 370)), "")

	var cerradas: Array = CallesRuta._cerradas
	_revisar("dos zonas cerradas a los carros", cerradas.size() == 2, str(cerradas))

	# Pisar la flecha poniente de Santa Mugre entra a santa_mugre por ese lado
	var entrada := sm.get_node_or_null("Entrada_poniente") as Area3D
	if entrada:
		jugador.global_position = entrada.global_position + Vector3(0.0, 1.0, 0.0)
		jugador.velocity = Vector3.ZERO
		await _cuadros(3)
	_revisar("la flecha poniente entra a santa_mugre", PasoColonia.colonia == "santa_mugre" and PasoColonia.lado == "poniente",
		"colonia %s lado '%s'" % [PasoColonia.colonia, PasoColonia.lado])
	PasoColonia.lado = ""
	escena.queue_free()
	await _cuadros(2)
	_revisar("al salir se abren las calles", (CallesRuta._cerradas).is_empty(), "")


# (cerradas, abiertas): la reja cerrada tiene el poste de en medio como primera caja de sus hojas
func _rejas(muro: MuroColonia) -> Vector2i:
	var cuenta := Vector2i.ZERO
	for r in muro.find_children("Reja_*", "Node3D", false, false):
		var hojas := r.get_node_or_null("Hojas")
		if hojas == null:
			continue
		if hojas.get_child(0) is MeshInstance3D:
			cuenta.x += 1
		else:
			cuenta.y += 1
	return cuenta


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
