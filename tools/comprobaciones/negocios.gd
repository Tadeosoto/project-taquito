extends Comprobacion

# El Yonke y El Punto hechos en Blender (tools/blender/negocios/): en el safehouse el patio del yonke
# y la cantina estan armados con sus piezas, los interiores cargan el modelo con sus marcas, La Chava
# y el patron quedan puestos, y El Punto vende las armas de fuego

const ARMAS := ["La Tinaquera", "La Chicharra", "La Matraca"]


func correr(r: Node) -> void:
	r.ok(await r.ir_a(SAFEHOUSE, 90), "safehouse")
	var yonke := r.get_tree().get_first_node_in_group("yonke") as Node3D
	r.ok(yonke != null and yonke.get_node_or_null("Patio") != null, "el patio del yonke (yonke_fuera.glb)")
	if yonke:
		r.ok(yonke.find_children("*", "Chatarra", true, false).size() == 3, "tres montones de chatarra en sus marcas")
		r.ok(yonke.get_node_or_null("Marcador") != null, "la flecha del yonke")
		r.ok(not yonke.find_children("Barda_*", "", true, false).is_empty(), "con barda en el safehouse")
		# La prensa trabaja: a media aplastada la placa esta abajo y el carro chaparro
		var placa := yonke.get("_placa") as Node3D
		var carro := yonke.get("_carro_prensa") as Node3D
		r.ok(placa != null and carro != null, "la prensa tiene su placa y su carro")
		if placa and carro:
			yonke.call("_prensa", 6.5)
			var abajo := placa.position.y < -0.3 and carro.scale.y < 0.8
			yonke.call("_prensa", 0.5)
			r.ok(abajo and is_equal_approx(carro.scale.y, 1.0) and is_zero_approx(placa.position.y), "la prensa baja, aplasta y vuelve")
		var chalanes := yonke.get_node_or_null("Chalanes")
		r.ok(chalanes != null and chalanes.get_child_count() >= 8, "los chalanes trabajando (de dia)")
	var cantina := r.get_tree().current_scene.get_node_or_null("CantinaPunto") as Node3D
	r.ok(cantina != null and cantina.get_node_or_null("Edificio") != null, "la cantina de El Punto (punto_fuera.glb)")
	if cantina:
		r.ok(not cantina.find_children("Anexo_*", "", true, false).is_empty(), "con su anexo del mural (lote sin limite)")
	# Un lote angosto se queda sin alas
	var angosta := PuntoMapa.new()
	angosta.ancho = 5.0
	r.get_tree().current_scene.add_child(angosta)
	await r.frames(2)
	r.ok(angosta.find_children("Anexo_*", "", true, false).is_empty() and angosta.find_children("Lote_*", "", true, false).is_empty(),
		"en un lote de 5 m no van el anexo ni el lote")
	r.ok(is_equal_approx(angosta.get_node("Edificio").scale.x, 5.0 / PuntoMapa.CANTINA_ANCHO), "y la cantina se encoge al lote")
	angosta.queue_free()
	# Los interiores
	for ruta: String in ["res://scenes/interiores/yonke.tscn", "res://scenes/interiores/punto.tscn"]:
		var interior := (load(ruta) as PackedScene).instantiate() as Interior
		r.get_tree().current_scene.add_child(interior)
		await r.frames(3)
		r.ok(interior.get_node_or_null("Cuarto") != null, ruta.get_file() + ": el cuarto de Blender")
		var vendedor := interior.get_node("Vendedor") as Node3D
		r.ok(not vendedor.find_children("*", "Skeleton3D", true, false).is_empty(), ruta.get_file() + ": quien atiende esta puesto")
		if interior is Punto:
			var nombres := []
			for p in interior.productos:
				nombres.append(p.item_name)
			var todas := true
			for arma: String in ARMAS:
				todas = todas and arma in nombres
			r.ok(todas, "El Punto vende las tres armas de fuego")
			r.ok(interior.get_node_or_null("Lampara") != null, "la lampara del escritorio alumbra")
		interior.queue_free()
