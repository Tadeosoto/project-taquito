extends SceneTree

# Prueba del evento de la reja (F1): una noche al azar la reja de Santa Mugre falla y hay que defender el tinaco.
#   godot --path . --headless -s tools/mapa/probar_evento_reja.gd
#
# Que revisa:
#   - el sorteo (Misiones.cae_la_noche): antes de la guardia nada; forzado, sale; nunca dos noches seguidas (3 de
#     enfriamiento); en 2000 noches sale de vez en cuando, no cada noche;
#   - en la colonia de Santa Mugre: la escena que empieza de noche no lo dispara; caer la noche (Ciclo) si;
#   - el evento: mision de LUGAR, reja poniente u oriente, el tinaco con vida donde esta el tinaco, la flecha junto a
#     el, y un zombi cerca va por el tinaco (no por ti, que estas lejos);
#   - perder: pregunta "¿otra vez?"; otra vez: vuelve con el tinaco entero, junto a el y un reintento usado;
#     tras los tres reintentos se pierde solo y el tinaco se queda sin la Virgen (para siempre);
#   - ganar: paga ($200 con el factor de paga) y la reja deja de fallar.

var P: GDScript

var _fallas := 0
var _total := 0
var misiones: Node


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	P = load("res://scripts/mapa/PasoColonia.gd")
	misiones = root.get_node("Misiones")
	misiones.reiniciar()
	_sorteo()

	misiones.reiniciar()
	misiones.guardias_reja = 1
	misiones.reja_forzar = true
	P.colonia = "santa_mugre"
	var escena: Node = (load("res://scenes/mapa.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	var mundo := _mundo(escena)
	# El anochecio del primer cuadro (la escena empieza de noche) no cuenta
	mundo._anochecio()
	await _cuadros(3)
	_revisar("la escena que empieza de noche no dispara el evento", not misiones.en_evento_reja() and misiones.reja_forzar, "")
	await _cuadros(30)
	var ciclo := escena.find_children("*", "Node", true, false).filter(func(n: Node) -> bool: return n.is_in_group("ciclo"))
	var jugador: CharacterBody3D = escena.find_children("*", "CharacterBody3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("jugador"))[0]
	var tinaco := escena.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("tinaco_comunitario"))
	_revisar("hay ciclo y tinaco en Santa Mugre", not ciclo.is_empty() and tinaco.size() == 1, "")
	if ciclo.is_empty() or tinaco.is_empty():
		return _fin()
	var t := tinaco[0] as Node3D
	misiones.amanecer()
	await create_timer(1.7).timeout
	ciclo[0].saltar(true)
	await _cuadros(10)
	_revisar("al caer la noche empieza el evento", misiones.en_evento_reja() and misiones.en_lugar(), str(misiones.activa))
	_revisar("por la reja poniente u oriente", misiones.reja_falla in ["poniente", "oriente"], misiones.reja_falla)
	var vida := _tinaco_vida(mundo)
	_revisar("el tinaco tiene vida y esta en el tinaco", vida != null and vida.global_position.distance_to(t.global_position) < 0.1 and vida.vida == 300, "")
	_revisar("la flecha va junto al tinaco", Vector2(t.global_position.x, t.global_position.z).distance_to(misiones.objetivo) < 6.0, str(misiones.objetivo))

	# Un zombi a 10 m del tinaco y tu a 40: va por el tinaco y le pega desde su orilla
	jugador.global_position = t.global_position + Vector3(0.0, 0.5, 40.0)
	var mando: Node = escena.find_children("*", "Node", true, false).filter(func(n: Node) -> bool: return n.is_in_group("zombis_mando"))[0]
	mando.limpiar()
	var zombi: Node3D = mando.sacar(t.global_position + Vector3(10.0, 0.2, 0.0), false)
	zombi.alertar(false)
	await _cuadros(2)
	var destino: Vector3 = zombi._destino()
	_revisar("un zombi cerca va por el tinaco", zombi._blanco == vida and destino.distance_to(t.global_position) < 0.1, str(zombi._blanco))
	mando.limpiar()

	# Perder: cae el tinaco, pregunta; otra vez
	jugador.global_position = t.global_position + Vector3(0.0, 0.5, 40.0)
	vida.recibir_golpe(1000)
	await create_timer(3.2).timeout
	var pregunta := _pregunta(mundo)
	_revisar("al caer el tinaco pregunta si otra vez", pregunta != null and paused, "")
	if pregunta == null:
		return _fin()
	pregunta.responder(true)
	await _cuadros(5)
	vida = _tinaco_vida(mundo)
	_revisar("otra vez: el evento vuelve, con el tinaco entero y un reintento usado", misiones.en_evento_reja() and vida != null
		and vida.vida == 300 and misiones.evento_reintentos == 1 and not paused, "reintentos %d" % misiones.evento_reintentos)
	_revisar("y te pone junto al tinaco", Vector2(jugador.global_position.x, jugador.global_position.z).distance_to(Vector2(t.global_position.x, t.global_position.z)) < 10.0, "")
	for i in 2:
		_tinaco_vida(mundo).recibir_golpe(1000)
		await create_timer(3.2).timeout
		_pregunta(mundo).responder(true)
		await _cuadros(5)
	_revisar("tres reintentos usados", misiones.evento_reintentos == 3 and misiones.en_evento_reja(), "%d" % misiones.evento_reintentos)
	_tinaco_vida(mundo).recibir_golpe(1000)
	await create_timer(3.2).timeout
	_revisar("tras el ultimo ya no pregunta: el tinaco se pierde", _pregunta(mundo) == null and misiones.tinaco_perdido and not misiones.en_evento_reja(), "")
	_revisar("y se queda sin la Virgen", (t.get("_de_virgen") as Array).is_empty() and t.get_node_or_null("LuzVeladoras") == null, "")

	# Ganar
	misiones.amanecer()
	misiones.reja_forzar = true
	misiones.reja_enfriamiento = 0
	ciclo[0].saltar(true)   # a amanecer
	await _cuadros(10)
	ciclo[0].saltar(true)   # a anochecer
	await _cuadros(10)
	_revisar("otra noche, otro evento (forzado)", misiones.en_evento_reja(), "")
	var antes: int = root.get_node("Cartera").pesos
	jugador.global_position = t.global_position + Vector3(0.0, 0.5, 4.0)
	misiones.tiempo_queda = 0.3
	await create_timer(0.8).timeout
	var pago: int = root.get_node("Cartera").pesos - antes
	var esperado := roundi(200 * root.get_node("Personaje").factor_paga())
	_revisar("ganar paga lo del padre Chuy", pago == esperado and not misiones.en_evento_reja() and misiones.reja_falla == "", "$%d de $%d" % [pago, esperado])
	_fin()


func _sorteo() -> void:
	_revisar("antes de la guardia la reja ni se gasta", not misiones.cae_la_noche(true) and misiones.reja_desgaste == 0.0, "")
	misiones.guardias_reja = 1
	misiones.reja_forzar = true
	_revisar("forzada, falla", misiones.cae_la_noche(true) and misiones.reja_enfriamiento == 3 and misiones.reja_desgaste == 0.0, "")
	var eventos := 0
	var seguidos := false
	var antes := false
	for i in 2000:
		var hubo: bool = misiones.cae_la_noche(true)
		eventos += 1 if hubo else 0
		seguidos = seguidos or (hubo and antes)
		antes = hubo
	_revisar("nunca dos noches seguidas", not seguidos, "")
	_revisar("de vez en cuando (entre 1 de cada 25 y 1 de cada 5 noches)", eventos > 80 and eventos < 400, "%d de 2000" % eventos)
	misiones.guardias_reja = 1
	misiones.reja_enfriamiento = 0
	var fuera := 0
	for i in 300:
		fuera += 1 if misiones.cae_la_noche(false) else 0
	_revisar("si pasas la noche fuera no hay evento", fuera == 0, "")


func _tinaco_vida(mundo: Node) -> Node3D:
	for n: Node in mundo.get_children():
		if n.get_script() and (n.get_script() as Script).resource_path.ends_with("TinacoVida.gd") and not n.is_queued_for_deletion():
			return n
	return null


func _pregunta(mundo: Node) -> Node:
	for n: Node in mundo.get_children():
		if n.get_script() and (n.get_script() as Script).resource_path.ends_with("PreguntaReja.gd") and not n.is_queued_for_deletion():
			return n
	return null


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
