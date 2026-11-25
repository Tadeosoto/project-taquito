extends Comprobacion

# Desmayarse como en Dark Souls (Supervivencia, Noches.bolsa, GuardiaBolsa): la bolsa en el piso de
# dia, el lider con la mochila y sus guardias de noche, el trago de agua, soltarla, reemplazarla


func correr(r: Node) -> void:
	var noches = r.autoload("Noches")
	var inv = r.autoload("Inventory")
	var salud = r.autoload("Salud")
	r.ok(await r.ir_a(SAFEHOUSE), "safehouse")
	var jugador := r.nodo("jugador") as Node3D
	inv.add_item(load("res://resources/productos/botella_agua.tres"))
	inv.add_item(load("res://resources/productos/botella_agua.tres"))
	noches.noche = 3
	jugador.global_position = Vector3(-10.0, 1.2, 0.0)
	await r.frames(5)
	var donde := jugador.global_position
	salud.vida = 0
	await r.frames(20)
	r.ok(noches.hay_bolsa() and inv.items.is_empty() and noches.noche == 3, "desmayo: bolsa, inventario vacio, la noche no cambia")
	await r.segundos(4.5)
	r.ok(r.get_tree().get_nodes_in_group("bolsa_muerte").size() == 1, "de dia: la bolsa tirada en el piso")
	await r.saltar_ciclo()
	r.ok(r.get_tree().get_nodes_in_group("bolsa_muerte").is_empty(), "de noche: ya no esta en el piso")
	jugador.global_position = donde + Vector3(30.0, 0.0, 0.0)
	await r.frames(40)
	var lider: Zombie = null
	var guardias := 0
	for z in Zombie.activos:
		if z.guardia and z.estado != Zombie.Estado.MUERTO:
			if z.lider:
				lider = z
			else:
				guardias += 1
	r.ok(lider != null, "sale el lider")
	r.ok(guardias >= 3, "y %d guardias" % guardias)
	if lider == null:
		return
	var mochila := false
	for pegado in lider.find_children("*", "BoneAttachment3D", true, false):
		mochila = mochila or pegado.get_child_count() > 0
	r.ok(mochila, "el lider trae la mochila pegada a un hueso")
	var agua_antes := _agua(noches)
	jugador.global_position = donde + Vector3(42.0, 0.0, 0.0)
	await r.segundos(14.0)
	r.ok(_agua(noches) < agua_antes, "el lider se toma agua de tu bolsa")
	lider.call("_morir", true)
	await r.frames(10)
	r.ok(not noches.bolsa.get("lider_vivo", true) and r.get_tree().get_nodes_in_group("bolsa_muerte").size() == 1, "muerto el lider, la suelta")
	inv.add_item(load("res://resources/productos/cinta.tres"))
	salud.vida = 0
	await r.frames(20)
	r.ok(noches.bolsa["items"].size() == 1, "otro desmayo: la bolsa nueva reemplaza la vieja")
	await r.segundos(4.5)
	await r.saltar_ciclo()
	var bolsas := r.get_tree().get_nodes_in_group("bolsa_muerte")
	if not bolsas.is_empty():
		bolsas[0].interact()
		await r.frames(5)
	r.ok(not noches.hay_bolsa() and inv.items.size() == 1, "de dia se recoge")


func _agua(noches: Node) -> int:
	return noches.bolsa.get("items", []).filter(func(i) -> bool: return i.resource_path.contains("agua")).size()
