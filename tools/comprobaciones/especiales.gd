extends Comprobacion

# El tajo cargado y el giro: los abre la campana (misiones que enseñan) o los tazos
# (Misiones.ataques_de_campana, la noche sin fin 2026-11-23)


func correr(r: Node) -> void:
	var misiones = r.autoload("Misiones")
	var tazos = r.autoload("Tazos")
	misiones.ataques_de_campana()
	r.ok(not Player.golpe_cargado and not Player.giro_aereo, "sin campana ni tazos: sin especiales")
	tazos.desbloqueadas["tajo_cargado"] = true
	tazos.dar_puntos(2)
	r.ok(tazos.subir("tajo_cargado"), "se sube Tajo cargado con su tazo")
	misiones.ataques_de_campana()
	r.ok(Player.golpe_cargado and not Player.giro_aereo, "el tazo prende el tajo")
	tazos.desbloqueadas["giro_aereo"] = true
	tazos.dar_puntos(2)
	tazos.subir("giro_aereo")
	misiones.ataques_de_campana()
	r.ok(Player.giro_aereo and Player.estocada_aerea, "el tazo del giro trae giro y estocada")
	r.ok(tazos.puntos_coleccion() == Habilidades.costo_total(), "el album completo paga todo el arbol (%d)" % Habilidades.costo_total())
