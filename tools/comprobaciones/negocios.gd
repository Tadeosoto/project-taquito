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
		# La grua va por un carro y lo trae con el ciclo de la prensa
		var pluma := yonke.get("_pluma") as Node3D
		r.ok(pluma != null, "la grua de electroiman")
		if pluma:
			yonke.call("_grua", 0.5)
			var en_prensa := pluma.rotation.y
			yonke.call("_grua", 5.2)
			var en_fila := pluma.rotation.y
			var carga := yonke.get("_carga") as Node3D
			r.ok(absf(angle_difference(en_prensa, en_fila)) > 1.0 and carga and carga.visible == false,
				"la grua gira de la prensa a la fila (sin carga todavia)")
			yonke.call("_grua", 8.0)
			r.ok(carga and carga.visible, "y regresa con el carro colgado")
		# De noche: el velador, su lumbre, el perro y los reflectores
		var noche := yonke.get_node_or_null("Noche") as Node3D
		yonke.call("_de_noche", true)
		r.ok(noche != null and noche.visible and noche.get_child_count() >= 5, "de noche el velador, la lumbre, el perro y las luces")
		yonke.call("_de_noche", false)
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
			r.ok(not interior.find_children("Lentes", "", true, false).is_empty() and not interior.find_children("Puro", "", true, false).is_empty(),
				"Don Lalo trae sus lentes y su puro")
		interior.queue_free()
	await _cantina(r, cantina)


# La cantina se camina: la flecha de la puerta (CasaPropia) mete al jugador, adentro esta El del
# colchon con lo que vende y la rocola, y la puerta de atras abre la oficina de Don Lalo a otra
# altura; al salir de la oficina sigues en la cantina, y de la cantina a la calle
func _cantina(r: Node, cantina: Node3D) -> void:
	var entrada := cantina.get_node_or_null("EntradaCantina") if cantina else null
	r.ok(entrada != null, "la cantina tiene su entrada (CasaPropia)")
	r.ok(cantina != null and cantina.get_node_or_null("Noche") != null, "la cantina tiene su gente y luces de noche")
	if entrada == null:
		return
	var jugador := r.get_tree().get_first_node_in_group("jugador") as Node3D
	entrada.call("_entrar")
	await r.segundos(1.2)
	var adentro: Node = entrada.get("_casa")
	r.ok(adentro != null and jugador.global_position.y > 400.0, "entras caminando a la cantina")
	if adentro == null:
		return
	r.ok(adentro.find_child("ElDelColchon", true, false) != null or adentro.find_child("Colchonero", true, false) != null,
		"El del colchon atiende la barra")
	var ventas := 0
	var rocola := false
	var puerta: Area3D = null
	for hijo in adentro.get_children():
		if hijo is MuebleCasa and String(hijo.get("_letrero").text).contains("Comprar"):
			ventas += 1
		if hijo is MuebleCasa and String(hijo.get("_letrero").text).contains("canción"):
			rocola = true
		if hijo.name == "PuertaAtras":
			puerta = hijo
	r.ok(ventas == 3 and rocola, "en la barra se compra caguama, cigarros y tachas, y hay rocola")
	r.ok(puerta != null, "la puerta de atras a la oficina")
	if puerta == null:
		return
	var interiores := r.get_tree().get_first_node_in_group("interiores")
	interiores.call("_entrar", "punto", "punto", "La oficina de Don Lalo", false, puerta)
	await r.segundos(1.2)
	var oficina: Node3D = interiores.get("_interior")
	r.ok(oficina is Punto and oficina.global_position.y > 650.0, "la oficina de Don Lalo, aparte de la cantina")
	interiores.call("_salir")
	await r.segundos(1.2)
	r.ok(interiores.get("_interior") == null and jugador.global_position.y > 400.0 and entrada.get("_casa") != null,
		"de la oficina vuelves a la cantina")
	entrada.call("_salir")
	await r.segundos(1.2)
	r.ok(entrada.get("_casa") == null and jugador.global_position.y < 50.0, "y de la cantina a la calle")
