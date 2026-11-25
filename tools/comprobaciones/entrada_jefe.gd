extends Comprobacion

# Las peleas de jefe de Juanjo (EntradaJefe, PasoJefe) con lo de la noche sin fin: sin mision se
# entra desde la noche del hito, el jefe trae mas aguante y desmayarte deja la bolsa en la entrada


func correr(r: Node) -> void:
	var noches = r.autoload("Noches")
	var inv = r.autoload("Inventory")
	r.ok(await r.ir_a(SAFEHOUSE), "safehouse")
	var jugador := r.nodo("jugador") as Node3D
	var entrada: EntradaJefe = load("res://scripts/mapa/EntradaJefe.gd").new()
	entrada.escena = "res://scenes/catrina.tscn"
	entrada.nombre = "la Mojiganga"
	entrada.id = "comprobacion"
	r.get_tree().current_scene.add_child(entrada)
	entrada.global_position = jugador.global_position + Vector3(0.0, -1.0, -10.0)
	await r.frames(3)
	noches.noche = 4
	entrada._entro(jugador)
	await r.frames(30)
	r.ok(not PasoJefe.desde_juego, "noche 4: la Mojiganga todavia no deja entrar")
	r.ok(String(entrada.get("_leyenda").text).contains("15"), "la leyenda dice la noche 15")
	noches.noche = 15
	inv.add_item(load("res://resources/productos/cinta.tres"))
	entrada._entro(jugador)
	r.ok(await r.escena_es("res://scenes/catrina.tscn"), "noche 15: entra a la plaza")
	await r.frames(60)
	var catrina = r.get_tree().current_scene.get("_catrina")
	r.ok(PasoJefe.desde_juego and catrina != null and is_equal_approx(catrina.aguante, noches.fuerza_jefe()), "pelea de verdad con aguante")
	r.autoload("Salud").vida = 0
	r.ok(await r.escena_es(SAFEHOUSE), "desmayado: regresa al mapa")
	await r.frames(20)
	r.ok(noches.hay_bolsa() and inv.items.is_empty(), "la bolsa se queda en la entrada")
	r.ok(noches.noche == 15, "la noche sigue")
