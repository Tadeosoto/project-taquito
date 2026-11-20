extends SceneTree

# Prueba de "El Decreto 47" en el palacio (JJ, 2026-11-20): los papeles estan en las oficinas de GelA del palacio.
#   godot --path . --headless -s tools/mapa/probar_decreto.gd
#
# Que revisa (en map_test, con la mision aceptada):
#   - la flecha va a la puerta del palacio (al fondo del portal);
#   - de dia no se fuerza; de noche, manteniendo Espacio 5 s, se abre, salen zombis de la calle y queda abierta;
#   - pisar la flecha te sube a las oficinas: adentro, sin zombis espontaneos, sin campo de flujo y con zombis
#     en el archivo; la flecha va al papel mas cercano;
#   - un zombi del archivo camina hacia ti por el pasillo (no se atora);
#   - los dos papeles estan sobre las mesas del fondo, y recogerlos pasa a "llevaselos a Sofia";
#   - la flecha de salida te baja frente al portal y todo vuelve como estaba;
#   - la bodega de GelA ya no se fuerza con esta mision.

const MAPA := "res://scenes/map_test.tscn"
var O: GDScript

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	O = load("res://scripts/map/PalacioOficinas.gd")
	var misiones: Node = root.get_node("Misiones")
	misiones.reiniciar()
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(2)
	var jugador := escena.get_node("Player") as CharacterBody3D
	var oficinas := escena.find_child("PalacioOficinas", true, false) as Node3D
	_revisar("hay oficinas en el palacio", oficinas != null and O.listo, "")
	if oficinas == null:
		return _fin()
	var frente: Vector3 = O.frente_puerta()
	jugador.global_position = frente + Vector3(0.0, 1.0, 0.0)
	await _cuadros(200)
	var mundo := _mundo(escena)
	var decreto: Resource = null
	for m: Resource in misiones.todas:
		if m.get("id") == "decreto_47":
			decreto = m
	misiones.aceptar(decreto)
	misiones.elegir(decreto)
	await _cuadros(3)
	_revisar("la flecha va a la puerta del palacio", misiones.hay_objetivo and misiones.objetivo.distance_to(Vector2(frente.x, frente.z)) < 0.5, str(misiones.objetivo))
	_revisar("los papeles estan puestos (arriba, en el archivo)", mundo._piezas.size() == 2 and mundo._piezas[0].global_position.y > 400.0, "%d" % mundo._piezas.size())

	# De dia no
	misiones.es_noche = false
	jugador.global_position = oficinas.global_transform * Vector3(0.0, 1.0, 1.0)
	await _cuadros(3)
	_revisar("junto a la puerta se puede interactuar", oficinas.is_player_inside(), "")
	oficinas.interact()
	await _cuadros(3)
	_revisar("de dia no se fuerza", not oficinas.get("_forzando") and not misiones.palacio_abierto, "")

	# De noche si
	misiones.anochecer()
	var mando: Node = escena.find_children("*", "Node", true, false).filter(func(n: Node) -> bool: return n.is_in_group("zombis_mando"))[0]
	mando.limpiar()
	Input.action_press("jump")
	oficinas.interact()
	await create_timer(5.6).timeout
	Input.action_release("jump")
	_revisar("de noche, 5 s con Espacio, se abre", misiones.palacio_abierto, "%.1f" % oficinas.get("_progreso"))
	_revisar("y el ruido trajo zombis de la calle", mando.vivos() >= 3, "%d" % mando.vivos())
	mando.limpiar()
	oficinas.set("_armada", false)

	# Abierta con el jugador encima de la flecha: no lo sube hasta que se baje y la vuelva a pisar
	jugador.global_position = oficinas.global_transform * (O.ENTRAR_EN + Vector3.UP * 0.5)
	await _cuadros(5)
	_revisar("forzarla parado en la flecha no te sube de golpe", not O.adentro, "")
	jugador.global_position = oficinas.global_transform * Vector3(0.0, 1.0, 5.0)
	await _cuadros(5)
	# Entrar
	jugador.global_position = oficinas.global_transform * (O.ENTRAR_EN + Vector3.UP * 0.5)
	await create_timer(1.2).timeout
	_revisar("la flecha te sube a las oficinas", O.adentro and jugador.global_position.y > 400.0, str(jugador.global_position))
	_revisar("adentro: sin espontaneos y sin campo", not mando.espontaneos and mando.sin_campo, "")
	var arriba := 0
	for z: Node3D in get_nodes_in_group("zombis"):
		arriba += 1 if z.global_position.y > 400.0 and z.process_mode != Node.PROCESS_MODE_DISABLED else 0
	_revisar("hay zombis en las oficinas", arriba >= 4, "%d" % arriba)
	await _cuadros(3)
	var cerca: Vector3 = mundo._piezas[0].global_position
	for p: Node3D in mundo._piezas:
		if p.global_position.distance_to(jugador.global_position) < cerca.distance_to(jugador.global_position):
			cerca = p.global_position
	_revisar("adentro la flecha va al papel mas cercano", misiones.objetivo.distance_to(Vector2(cerca.x, cerca.z)) < 0.5, "")

	# Un zombi del archivo camina hacia ti por el pasillo
	mando.limpiar()
	var zombi: Node3D = mando.sacar(oficinas.global_transform * Vector3(0.0, O.ALTURA + 0.1, -27.0), false)
	zombi.alertar(false)
	var antes := zombi.global_position.distance_to(jugador.global_position)
	await create_timer(4.0).timeout
	var despues := zombi.global_position.distance_to(jugador.global_position)
	_revisar("un zombi del archivo camina hacia ti (no se atora)", despues < antes - 4.0 and zombi.global_position.y > 400.0, "%.1f -> %.1f m" % [antes, despues])
	mando.limpiar()

	# Los papeles sobre las mesas
	for p: Node3D in mundo._piezas:
		var local: Vector3 = oficinas.global_transform.affine_inverse() * p.global_position
		_revisar("un papel sobre su mesa del fondo", local.z < -30.0 and absf(local.y - O.ALTURA - 0.76) < 0.05, str(local))
	for p: Node3D in mundo._piezas.duplicate():
		mundo._pieza_recogida(p)
	await _cuadros(3)
	_revisar("con los dos papeles: a llevarselos a Sofia", misiones.activa == decreto and misiones.paso().tipo == 1, str(misiones.paso().texto if misiones.paso() else ""))

	# Salir
	jugador.global_position = oficinas.global_transform * (O.SALIR_EN + Vector3.UP * (O.ALTURA + 0.5))
	await create_timer(1.2).timeout
	var local_j: Vector3 = oficinas.global_transform.affine_inverse() * jugador.global_position
	_revisar("la flecha de salida te baja frente al portal", not O.adentro and jugador.global_position.y < 10.0 and local_j.z > 2.0, str(local_j))
	_revisar("y todo vuelve como estaba", mando.espontaneos and not mando.sin_campo, "")

	# La bodega de GelA ya no es de esta mision
	var bodega := load("res://scripts/map/BodegaGela.gd").new() as Node
	_revisar("la bodega de GelA ya no se fuerza con el Decreto", not bodega._de_la_mision(), "")
	bodega.free()
	_fin()


func _mundo(escena: Node) -> Node:
	for nodo: Node in escena.find_children("*", "Node", true, false):
		if nodo.get_script() and (nodo.get_script() as Script).resource_path.ends_with("MisionesMundo.gd"):
			return nodo
	return null


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
