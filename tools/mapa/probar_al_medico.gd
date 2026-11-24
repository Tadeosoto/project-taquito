extends SceneTree

# Prueba de "Al medico" en las dos fortalezas (P3): una enfermeria al azar de las dos de la fortaleza donde se acepta.
#   godot --path . --headless -s tools/mapa/probar_al_medico.gd
#
# Que revisa (en la colonia de Blender de La Gotera):
#   - la de la farmacia del tianguis da "al_medico_gotera" parada en su marca (Farmacia_Tianguis);
#   - al aceptarla, la reja es de La Gotera (norte o sur) y la enfermeria una de las dos de La Gotera;
#   - la escolta termina frente a esa enfermeria (FortalezasMapa.llegada_clinica con Misiones.clinica);
#   - aceptada en Santa Mugre (Karla), la reja y la enfermeria son de Santa Mugre;
#   - en 40 sorteos salen las dos enfermerias de cada fortaleza;
#   - Karla (la de Santa Mugre) no sale en La Gotera.

const MARCA := Vector3(713.5, 0.0, -213.0)
# Por load() al correr, no por su class_name: con -s este script se compila antes que los autoloads
var F: GDScript
var P: GDScript

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	F = load("res://scripts/map/FortalezasMapa.gd")
	P = load("res://scripts/mapa/PasoColonia.gd")
	var misiones: Node = root.get_node("Misiones")
	P.colonia = "la_gotera"
	var escena: Node = (load("res://scenes/mapa.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(30)
	var mundo: Node = null
	for nodo: Node in escena.find_children("*", "Node", true, false):
		if nodo.get_script() and (nodo.get_script() as Script).resource_path.ends_with("MisionesMundo.gd"):
			mundo = nodo
	_revisar("hay MisionesMundo en La Gotera", mundo != null, "")
	if mundo == null:
		return _fin()
	var dador: Dictionary = {}
	for v: Dictionary in mundo.vecinos:
		if (v["mision"] as Resource).get("id") == "al_medico_gotera":
			dador = v
	var lugar: Vector3 = dador.get("lugar", Vector3.INF)
	var karla := false
	for v: Dictionary in mundo.vecinos:
		karla = karla or (v["mision"] as Resource).get("id") == "al_medico"
	_revisar("Karla no da su Al medico en La Gotera", not karla, "")
	_revisar("la de la farmacia esta en su marca", not dador.is_empty() and Vector2(lugar.x, lugar.z).distance_to(Vector2(MARCA.x, MARCA.z)) < 0.5, str(lugar))

	P.simular = true
	var gotera: Resource = dador.get("mision")
	if gotera:
		misiones.aceptar(gotera)
		await mundo._ir_a_la_reja(gotera)
		_revisar("la reja es de La Gotera", misiones.reja_guardia in ["norte", "sur"], misiones.reja_guardia)
		_revisar("la enfermeria es de La Gotera", (misiones.clinica as String).begins_with("la_gotera/"), misiones.clinica)
		var llegada: Vector3 = F.llegada_clinica(Vector3.ZERO, misiones.clinica)
		var esperada := _llegada_de(misiones.clinica)
		_revisar("la escolta termina frente a esa enfermeria", llegada.distance_to(esperada) < 0.1, str(llegada))

	var vistas := {}
	for i in 40:
		P.colonia = "la_gotera" if i % 2 == 0 else "santa_mugre"
		misiones.clinica = ""
		misiones.activa = null
		var mision: Resource = gotera if i % 2 == 0 else _mision(misiones, "al_medico")
		misiones.aceptar(mision)
		await mundo._ir_a_la_reja(mision)
		var de := "la_gotera" if i % 2 == 0 else "santa_mugre"
		if not (misiones.clinica as String).begins_with(de + "/") or not misiones.reja_guardia in mundo.REJAS_DE[de]:
			vistas["mal"] = "%s: %s %s" % [de, misiones.clinica, misiones.reja_guardia]
		vistas[misiones.clinica] = true
	_revisar("Karla (Santa Mugre) da reja y enfermeria de Santa Mugre", not vistas.has("mal"), str(vistas.get("mal", "")))
	_revisar("salen las cuatro enfermerias (dos por fortaleza)", vistas.has("la_gotera/norte") and vistas.has("la_gotera/sur")
		and vistas.has("santa_mugre/poniente") and vistas.has("santa_mugre/oriente"), str(vistas.keys()))
	P.simular = false
	_fin()


func _mision(misiones: Node, id: String) -> Resource:
	for m: Resource in misiones.todas:
		if m.get("id") == id:
			return m
	return null


func _llegada_de(reja: String) -> Vector3:
	for c: Dictionary in F.CLINICAS:
		if c["reja"] == reja:
			var g: float = c["giro"]
			var p: Vector2 = c["casa"] + Vector2(sin(g), cos(g)) * (c["fondo"] / 2.0 + F.CLINICA_BANQUETA)
			return Vector3(p.x, 0.0, p.y)
	return Vector3.INF


func _fin() -> void:
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["OK  " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await process_frame
