extends Comprobacion

# La caja de dialogo (DialogueBox): un NPC la abre, pausa, escribe y se cierra con Espacio


func correr(r: Node) -> void:
	r.ok(await r.ir_a(SAFEHOUSE, 90), "safehouse")
	var chuy: Node = null
	for npc in r.get_tree().get_nodes_in_group("npc"):
		if npc.get("nombre") == "Doña Chuy":
			chuy = npc
	r.ok(chuy != null, "Doña Chuy en el patio")
	if chuy == null:
		return
	chuy.set("_player_inside", true)
	chuy.interact()
	await r.get_tree().process_frame
	var caja := DialogueBox.compartida(chuy)
	r.ok(caja.abierta and r.get_tree().paused, "la caja abre y pausa")
	for i in 30:
		if not caja.abierta:
			break
		await r.segundos(0.15)
		await r.apretar("jump")
	await r.segundos(0.4)
	r.ok(not caja.abierta and not r.get_tree().paused, "Espacio la cierra y quita la pausa")
