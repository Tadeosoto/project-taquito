extends Comprobacion

# La noche sin fin (Noches, Partida): la cuenta, el garrafonero de la noche 3, el record, el tazo
# del hito, el crecimiento y los jefes que se repiten


func correr(r: Node) -> void:
	var noches = r.autoload("Noches")
	var tazos = r.autoload("Tazos")
	r.ok(r.autoload("Salud").vida == Salud.VIDA_INICIO, "vida inicial %d" % Salud.VIDA_INICIO)
	r.ok(await r.ir_a(SAFEHOUSE), "safehouse")
	var ciclo := r.nodo("ciclo") as Ciclo
	var jugador := r.nodo("jugador") as Node3D
	for n in 3:
		await r.saltar_ciclo()
		r.ok(ciclo.es_noche() and noches.noche == n + 1, "anochecio la noche %d" % (n + 1))
		if n < 2:
			await r.saltar_ciclo()
	jugador.global_position = Vector3(30.0, 1.2, -4.0)
	await r.frames(120)
	var jefe := false
	for z in Zombie.activos:
		if z.es_jefe:
			jefe = true
	r.ok(jefe, "noche 3: sale el garrafonero")
	r.ok(not ciclo.retener_noche, "la noche 3 no se retiene")
	await r.saltar_ciclo()
	var vivos := 0
	for z in Zombie.activos:
		if z.es_jefe and z.estado != Zombie.Estado.MUERTO:
			vivos += 1
	r.ok(not ciclo.es_noche() and vivos == 0, "amanece y el garrafonero cae")
	r.ok(noches.record >= 3 and noches.hitos_dados.has(3), "record y hito de la noche 3")
	r.ok(await r.cerrar_tazo(), "sale el show del tazo del hito")
	r.ok(tazos.coleccion.has("jefe") and tazos.desbloqueadas.has("tajo_cargado"), "premio: El Jefe abre el tajo")
	r.ok(absf(noches.factor_turba() - pow(1.15, 2)) < 0.01, "las turbas crecen 15 % por noche")
	r.ok(noches.jefe_de(18) == HitoNoche.Tipo.GARRAFONERO and noches.jefe_de(21) == HitoNoche.Tipo.MADRE_CARCAMO \
		and noches.jefe_de(24) == HitoNoche.Tipo.MOJIGANGA and noches.jefe_de(19) == -1, "jefes que se repiten: 18, 21, 24")
	r.ok(is_equal_approx(noches.fuerza_jefe(15), 1.0) and is_equal_approx(noches.fuerza_jefe(18), 1.25), "mas aguante por vuelta")
	# Llegar a otra escena a media noche (Continuar, una reja, un jefe) no cuenta otra noche
	await r.saltar_ciclo()
	var antes: int = noches.noche
	var hora: float = ciclo.tiempo() / (ciclo.dia_duracion + ciclo.noche_duracion)
	PasoColonia.fraccion_del_dia = hora
	r.ok(await r.ir_a(SAFEHOUSE, 30), "otra vez al safehouse a media noche")
	r.ok((r.nodo("ciclo") as Ciclo).es_noche() and noches.noche == antes, "sigue la misma noche (%d)" % noches.noche)
