extends SceneTree

# Prueba de las casas del reparto a pie (P4): ninguna adentro de una fortaleza.
#   godot --path . --headless -s tools/mapa/probar_reparto.gd
#
# Que revisa:
#   - en map_test, desde las rejas de Santa Mugre y desde su centro, las casas que salen estan afuera de los muros y no
#     dan la cara a la barda (su frente tambien afuera);
#   - en la colonia de Blender de Santa Mugre, aceptado "Agua de noche", la flecha va a una salida de la colonia
#     (las casas se escogen ya afuera) y la cuenta sigue en 0 de 2; con la reja cerrada no se ofrece (si su dador
#     salio en la colonia).

const DESDE := [Vector3(-425.0, 0.0, 454.5), Vector3(-180.0, 0.0, 472.6), Vector3(-300.0, 0.0, 370.0)]
# Por load() al correr, no por su class_name: con -s este script se compila antes que los autoloads
var P: GDScript
var M: GDScript

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	P = load("res://scripts/mapa/PasoColonia.gd")
	M = load("res://scripts/map/MuroColonia.gd")
	var misiones: Node = root.get_node("Misiones")

	var mapa: Node = (load("res://scenes/map_test.tscn") as PackedScene).instantiate()
	root.add_child(mapa)
	await _cuadros(30)
	var mundo := _mundo(mapa)
	_revisar("hay MisionesMundo en map_test", mundo != null, "")
	if mundo:
		var adentro := 0
		var cuantas := 0
		for desde: Vector3 in DESDE:
			for i in 10:
				for casa: Vector3 in mundo._lugares_de_casas(desde, 5):
					cuantas += 1
					adentro += 1 if M.adentro(self, casa) else 0
		_revisar("en map_test ninguna casa del reparto adentro de una fortaleza", adentro == 0 and cuantas > 0, "%d de %d" % [adentro, cuantas])
	mapa.queue_free()
	await _cuadros(5)

	P.colonia = "santa_mugre"
	var colonia: Node = (load("res://scenes/mapa.tscn") as PackedScene).instantiate()
	root.add_child(colonia)
	await _cuadros(30)
	mundo = _mundo(colonia)
	var reparto: Resource = null
	for m: Resource in misiones.todas:
		if m.get("id") == "reparto_noche":
			reparto = m
	_revisar("hay MisionesMundo en Santa Mugre y la mision", mundo != null and reparto != null, "")
	if mundo and reparto:
		# Con la reja cerrada (sin la guardia) no la ofrece, como Al medico
		var i := -1
		for k in mundo.vecinos.size():
			if mundo.vecinos[k]["mision"] == reparto:
				i = k
		if i >= 0:
			misiones.guardias_reja = 0
			_revisar("con la reja cerrada no la ofrece", mundo._hablar(i) == mundo.TEXTO_REJA_REPARTO, "")
			misiones.guardias_reja = 1
		misiones.aceptar(reparto)
		misiones.elegir(reparto)
		await _cuadros(2)
		var salidas: Dictionary = load("res://scripts/mapa/Colonia.gd").salidas
		var objetivo: Vector2 = misiones.objetivo
		var a_salida := false
		for lado: String in salidas:
			var s: Vector3 = salidas[lado]
			a_salida = a_salida or objetivo.distance_to(Vector2(s.x, s.z)) < 0.5
		_revisar("en la colonia la flecha va a una salida", misiones.hay_objetivo and a_salida, "%s %s" % [objetivo, salidas])
		_revisar("y no hay puntos de entrega adentro", mundo._puntos.is_empty() and misiones.meta_visitas == 2, "%d puntos, meta %d" % [mundo._puntos.size(), misiones.meta_visitas])
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _mundo(escena: Node) -> Node:
	for nodo: Node in escena.find_children("*", "Node", true, false):
		if nodo.get_script() and (nodo.get_script() as Script).resource_path.ends_with("MisionesMundo.gd"):
			return nodo
	return null


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["OK  " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await process_frame
