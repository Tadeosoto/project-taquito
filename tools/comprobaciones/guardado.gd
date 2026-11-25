extends Comprobacion

# La partida en disco (Guardado): autoloads, la noche, la campana de Misiones, los jefes vencidos,
# la llegada al Continuar y Partida nueva. En el safehouse solo se guarda forzado


func correr(r: Node) -> void:
	var guardado = r.autoload("Guardado")
	var noches = r.autoload("Noches")
	var tazos = r.autoload("Tazos")
	var inv = r.autoload("Inventory")
	var mis = r.autoload("Misiones")
	r.ok(await r.ir_a(SAFEHOUSE), "safehouse")
	noches.noche = 7
	tazos.dar_puntos(3)
	inv.vaciar()
	inv.add_item(load("res://resources/productos/cinta.tres"))
	mis.antena_instalada = true
	PasoJefe.vencidos["catrina"] = true
	r.ok(not guardado.guardar(), "el safehouse no guarda solo")
	r.ok(guardado.guardar(true), "guardar forzado")
	r.ok(guardado.hay_partida(), "hay partida guardada")
	var puntos: int = tazos.puntos
	noches.noche = 0
	tazos.reiniciar()
	inv.vaciar()
	mis.antena_instalada = false
	PasoJefe.vencidos.clear()
	var escena: String = guardado.cargar()
	r.ok(escena == SAFEHOUSE, "cargar: la escena (%s)" % escena)
	r.ok(noches.noche == 7, "cargar: la noche")
	r.ok(tazos.puntos == puntos, "cargar: los tazos")
	r.ok(inv.items.size() == 1, "cargar: el inventario")
	r.ok(mis.antena_instalada, "cargar: la campana de Misiones")
	r.ok(PasoJefe.vencido("catrina"), "cargar: los jefes vencidos")
	r.ok(guardado.tomar_llegada() is Transform3D and guardado.tomar_llegada() == null, "la llegada sale una vez")
	guardado.nueva()
	r.ok(not guardado.hay_partida() and noches.noche == 0, "Partida nueva borra todo")
