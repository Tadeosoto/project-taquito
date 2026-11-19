extends Node
# Prueba del Sotano (docs/sistemas/sotano.md) en la safehouse, con el jugador de verdad:
#   godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<carpeta>
# Necesita ventana (las capturas; sin --capturas igual corre). Entra por la flecha de la safehouse,
# revisa la cadena del de la puerta, paga la cuota, compra fichas, juega EL GORDO, el poker y las
# carreras (a tiempo acelerado), compra una caguama, cobra y sale. Imprime "ok"/"MAL" por paso y
# al final RESULTADO.

const SAFEHOUSE := "res://scenes/safehouse.tscn"
const ESPERA := 2.5        # s para que la safehouse acabe de armarse

var _carpeta := ""
var _bien := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_carpeta = arg.trim_prefix("--capturas=")
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		var yo := Node.new()
		yo.set_script(get_script())
		yo.name = "ProbarSotano"
		get_tree().root.add_child.call_deferred(yo)
		get_tree().change_scene_to_file.call_deferred(SAFEHOUSE)
		set_process(false)
		return
	_probar.call_deferred()


func _ver(cond: bool, que: String, detalle := "") -> void:
	print(("ok    " if cond else "MAL   ") + que + ("  " + detalle if detalle != "" else ""))
	if not cond:
		_bien = false


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _foto(nombre: String) -> void:
	if _carpeta == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_carpeta.path_join("sotano_%s.png" % nombre))


func _probar() -> void:
	await _esperar(ESPERA)
	var arbol := get_tree()
	var jugador := arbol.get_first_node_in_group("jugador") as Node3D
	var cartera := get_node("/root/Cartera")
	var fichas := get_node("/root/Fichas")
	var inventario := get_node("/root/Inventory")
	fichas.reiniciar()
	cartera.pesos = 1000
	while inventario.items.size() > 2:
		inventario.remove_item(inventario.items.size() - 1)
	var entrada := arbol.current_scene.get_node_or_null("Sotano")
	_ver(entrada != null, "esta la flecha del Sotano en la safehouse")
	if entrada == null:
		_fin()
		return
	entrada._entrar()
	# Hasta que la casa exista y el fundido acabe (la primera vez tras importar compila shaders)
	var espera := 0.0
	while (entrada.get("_casa") == null or entrada.get("_ocupado")) and espera < 10.0:
		await _esperar(0.2)
		espera += 0.2
	await _esperar(0.3)
	var sotano: Node3D = entrada.get("_casa")
	_ver(sotano != null and jugador.global_position.y > 400.0, "se entra al Sotano", "jugador en %s" % jugador.global_position)
	if sotano == null:
		_fin()
		return
	await _foto("1_entrada")
	# La cadena: sin permiso, el jugador no pasa del pie de la escalera
	var cadena := sotano.get_node("Cuarto").find_children("Cadena*", "StaticBody3D", true, false)
	_ver(not cadena.is_empty(), "sin permiso la cadena del de la puerta tapa el paso")
	_ver(sotano.get_node_or_null("Guardia") != null and sotano.get_node_or_null("Primo") != null and sotano.get_node_or_null("Cantinero") != null 		and sotano.get_node_or_null("Crupier") != null, "estan el de la puerta, el Primo, el cantinero y el crupier")
	cartera.pesos = 100
	sotano._pagar_cuota()
	_ver(fichas.permiso == 0 and cartera.pesos == 100, "sin los $%d de la cuota no te deja pasar" % fichas.CUOTA)
	cartera.pesos = 1000
	sotano._pagar_cuota()
	await _esperar(0.2)
	cadena = sotano.get_node("Cuarto").find_children("Cadena*", "StaticBody3D", true, false)
	_ver(fichas.permiso == 1 and cartera.pesos == 1000 - fichas.CUOTA and cadena.is_empty(), "pagas la cuota y quita la cadena",
		"permiso %d, pesos %d" % [fichas.permiso, cartera.pesos])
	# Bajar caminando: del descanso al pie de la escalera
	jugador.global_position = sotano.to_global(Vector3(7.2, -2.0, 3.1))
	await _esperar(0.6)
	var abajo := sotano.to_local(jugador.global_position)
	_ver(abajo.y > -3.0 and abajo.y < -1.5, "el pie de la escalera tiene piso", "y local %.2f" % abajo.y)
	# Ventanilla: 50 fichas
	var pesos_antes: int = cartera.pesos
	sotano._abrir("res://scripts/sotano/VentanillaUI.gd", {})
	await _esperar(0.3)
	var ui: Node = arbol.get_first_node_in_group("juego_sotano")
	_ver(ui != null, "se abre la ventanilla")
	ui.tecla(KEY_2)
	_ver(fichas.fichas == 50 and cartera.pesos == pesos_antes - 50 * fichas.PRECIO, "compras 50 fichas", "fichas %d, pesos %d" % [fichas.fichas, cartera.pesos])
	await _foto("2_ventanilla")
	ui.cerrar()
	await _esperar(0.3)
	# EL GORDO: 20 tiros de 1 ficha
	var gabinetes := sotano.find_children("OlPley_*", "StaticBody3D", false, false)
	_ver(gabinetes.size() == 10, "hay diez EL GORDO", str(gabinetes.size()))
	jugador.global_position = sotano.to_global(Vector3(13.4, -2.0, 0.2))
	sotano._abrir_olpley(gabinetes[2])
	await _esperar(0.3)
	ui = arbol.get_first_node_in_group("juego_sotano")
	var antes: int = fichas.fichas
	var tiros := 0
	await _esperar(0.7)
	for k in 20:
		ui.jalar()
		await _esperar(2.2)
		tiros += 1
		if k == 0:
			await _foto("3_olpley")
	_ver(tiros == 20 and fichas.fichas != antes - 0, "20 tiros en EL GORDO", "fichas %d -> %d, caja %d" % [antes, fichas.fichas, gabinetes[2].placa.caja])
	ui.cerrar()
	await _esperar(0.3)
	# Poker: una mano entera, siempre pasar o ir
	fichas.fichas = maxi(fichas.fichas, 30)
	jugador.global_position = sotano.to_global(Vector3(27.5, -2.0, 5.4))
	sotano._abrir_poker()
	await _esperar(1.0)
	ui = arbol.get_first_node_in_group("juego_sotano")
	_ver(ui != null and ui.get("_h") != null, "se sienta al poker")
	var limite := Time.get_ticks_msec()
	var foto_poker := false
	while ui.get("_h").fase != Holdem.Fase.FIN and Time.get_ticks_msec() - limite < 60000:
		await _esperar(0.2)
		if ui.get("_esperando"):
			if not foto_poker and ui.get("_h").mesa.size() >= 3:
				foto_poker = true
				await _foto("4_poker")
			ui.jugar("pasar")
	var h: Holdem = ui.get("_h")
	_ver(h.fase == Holdem.Fase.FIN and not h.ganadores.is_empty(), "se juega una mano de poker", "%s, mesa %d cartas, la casa %d" % [h.mano_ganadora, h.mesa.size(), h.rake])
	await _esperar(0.3)
	if not foto_poker:
		await _foto("4_poker")
	_ver(fichas.fichas == h.jugadores[0].fichas, "tus fichas son las de la mesa", str(fichas.fichas))
	ui.cerrar()
	await _esperar(0.8)
	# Blackjack: una mano, plantado
	fichas.fichas = maxi(fichas.fichas, 20)
	sotano._abrir("res://scripts/sotano/BlackjackUI.gd", {"sotano": sotano})
	await _esperar(0.8)
	ui = arbol.get_first_node_in_group("juego_sotano")
	var antes_bj: int = fichas.fichas
	ui.repartir()
	await _esperar(1.6)
	if ui.get("_bj").fase == Blackjack.Fase.JUGANDO:
		ui.plantarte()
		await _esperar(2.0)
	_ver(ui.get("_bj").fase == Blackjack.Fase.FIN and ui.get("_bj").resultado != "", "se juega una mano de blackjack",
		"%s, fichas %d -> %d" % [ui.get("_bj").resultado, antes_bj, fichas.fichas])
	ui.cerrar()
	await _esperar(0.5)
	# Ruleta: al rojo; si gana, dobletea
	sotano._abrir("res://scripts/sotano/RuletaUI.gd", {"sotano": sotano})
	await _esperar(0.8)
	ui = arbol.get_first_node_in_group("juego_sotano")
	ui.girar()
	await _esperar(5.0)
	var tras_giro: int = ui.get("_estado")
	if tras_giro == 2:    # GANASTE
		ui.dobletear()
		await _esperar(5.0)
	_ver(ui.get("_estado") == 3 or ui.get("_estado") == 2, "gira la ruleta (y el doblete)", "sale %s" % ui.get("_sale").text)
	ui.cerrar()
	await _esperar(0.5)
	# Carreras: al rojo, 2 fichas
	jugador.global_position = sotano.to_global(Vector3(14.25, -2.0, 4.0))
	sotano._abrir("res://scripts/sotano/CarrerasUI.gd", {"sotano": sotano})
	await _esperar(0.3)
	ui = arbol.get_first_node_in_group("juego_sotano")
	ui.tecla(KEY_RIGHT)
	antes = fichas.fichas
	var caballo := sotano.get("_caballos")[0] as Node3D
	var x0 := caballo.position.x
	ui.arrancar()
	await _esperar(2.5)
	await _foto("5_carrera")
	var corrio := absf(caballo.position.x - x0) > 0.5
	while ui.get("_ocupado"):
		await _esperar(0.2)
	_ver(corrio and caballo.position.x == x0, "corren los caballitos y regresan", "fichas %d -> %d" % [antes, fichas.fichas])
	ui.cerrar()
	await _esperar(0.3)
	# Caguama en el congelador, Tecatl en la barra y con la mesera
	var cuantos: int = inventario.items.size()
	sotano._caguama()
	_ver(inventario.items.size() == cuantos + 1, "compras una caguama en el congelador")
	fichas.fichas = maxi(fichas.fichas, 10)
	sotano._caguama(2, "barra")
	var gente := sotano.get_node_or_null("Gente")
	_ver(gente != null and sotano.get_node_or_null("Mesera") != null and sotano.find_children("Caminante_*", "", false, false).size() == 5,
		"camina la gente: cinco y la mesera")
	# Nadie flota: los pies de los que caminan (su origen) a menos de 5 cm del piso que se ve.
	# Antes las cajas del cuarto salian al reves y el piso visible quedaba medio metro abajo
	var piso_bien := true
	var detalle_piso := ""
	var espacio := sotano.get_world_3d().direct_space_state
	for c: Node3D in sotano.find_children("Caminante_*", "", false, false):
		var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP, c.global_position + Vector3.DOWN * 2.0)
		var hit := espacio.intersect_ray(q)
		var dif: float = absf(c.global_position.y - hit.position.y) if hit else 99.0
		if dif > 0.05:
			piso_bien = false
			detalle_piso += "%s %.2f m " % [c.name, dif]
	# ...y el choque no basta (siempre estuvo bien): la cara de arriba del piso que se ve debe
	# apuntar hacia arriba (si sale al reves no se dibuja y se ve la de abajo)
	var piso := sotano.find_child("Piso", true, false) as MeshInstance3D
	if piso == null:
		piso = sotano.find_child("Piso-convcol", true, false) as MeshInstance3D
	if piso and piso.mesh:
		var arr := piso.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var arriba := -INF
		for v in verts:
			arriba = maxf(arriba, v.y)
		# Las esquinas de arriba son de la tapa y de los lados (vertices separados por cara): basta
		# con que alguna vea hacia arriba
		var ve_arriba := false
		for i in verts.size():
			if absf(verts[i].y - arriba) < 0.001 and normales[i].y > 0.5:
				ve_arriba = true
		if not ve_arriba:
			piso_bien = false
			detalle_piso += "la cara de arriba del piso ve hacia abajo "
	else:
		piso_bien = false
		detalle_piso += "no hay malla Piso "
	_ver(piso_bien, "la gente pisa el piso que se ve", detalle_piso)
	if gente:
		var antes_m: int = fichas.fichas
		gente._vender()
		_ver(fichas.fichas == antes_m - 2, "la mesera te vende una Tecatl")
	# Las de frutas: en fichas y abiertas aunque sea de noche
	var frutas := sotano.find_children("Frutas_*", "", false, false)
	_ver(frutas.size() == 2 and frutas[0].moneda == "fichas" and not frutas[0]._cerrada(), "dos de frutas en fichas, abiertas de noche")
	# La de frutas simple: una fruta, sus monedas, y la apuesta se va con la fruta
	fichas.fichas = maxi(fichas.fichas, 10)
	frutas[0].interact()
	await _esperar(1.0)
	var tui: Node = null
	for n in arbol.current_scene.get_children():
		if n is TragamonedasUI:
			tui = n
	_ver(tui != null, "se juega la de frutas")
	if tui:
		var antes_f: int = fichas.fichas
		tui._apostar(1)
		tui._apostar(1)
		tui._elegir(1)
		var ap: Dictionary = tui.get("_apuestas")
		_ver(ap.size() == 1 and ap.values()[0] == 2 and fichas.fichas == antes_f - 2, "una sola fruta: 2 monedas que se pasan de fruta", str(ap))
		await _foto("5b_frutas")
		tui._tirar()
		var desde_f := Time.get_ticks_msec()
		while tui.get("_ocupado") and Time.get_ticks_msec() - desde_f < 20000:
			await _esperar(0.2)
		_ver(tui.get("_apuestas").is_empty(), "tira y cobra", "fichas %d -> %d" % [antes_f, fichas.fichas])
		tui._salir()
		await _esperar(1.0)
	# Fotos de adentro
	if _carpeta != "":
		# yaw 0 = al norte (las EL GORDO), PI/2 = al oeste (ventanilla), -PI/2 = al este (pista)
		for vista: Array in [[Vector3(14.0, -2.0, 6.0), 0.0, "6_maquinitas"], [Vector3(12.0, -2.0, 2.0), PI / 2.0, "7_ventanilla"],
				[Vector3(23.0, -2.0, 4.6), -PI / 2.0, "8_salon2"], [Vector3(14.0, -2.0, 1.0), PI, "9_altar"],
				[Vector3(26.0, -2.0, 5.2), 0.0, "10_barra"], [Vector3(9.0, -2.0, 3.0), -PI / 2.0, "11_arco"],
				[Vector3(8.2, -2.0, 2.4), 0.0, "12_primo"]]:
			jugador.global_position = sotano.to_global(vista[0])
			jugador.camera_pivot.global_rotation.y = vista[1]
			jugador.frijol.global_rotation.y = vista[1]
			await _esperar(0.5)
			await _foto(vista[2])
	# Cobrar y salir
	pesos_antes = cartera.pesos
	var tenia: int = fichas.fichas
	sotano._abrir("res://scripts/sotano/VentanillaUI.gd", {})
	await _esperar(0.3)
	ui = arbol.get_first_node_in_group("juego_sotano")
	ui.tecla(KEY_C)
	_ver(fichas.fichas == 0 and cartera.pesos == pesos_antes + int(floor(tenia * fichas.PRECIO * 0.9)), "cobras tus fichas menos la comision",
		"%d fichas -> $%d" % [tenia, cartera.pesos - pesos_antes])
	ui.cerrar()
	await _esperar(0.3)
	entrada._salir()
	espera = 0.0
	while entrada.get("_casa") != null and espera < 10.0:
		await _esperar(0.2)
		espera += 0.2
	await _esperar(0.5)
	_ver(jugador.global_position.y < 50.0 and entrada.get("_casa") == null, "se sale por la puerta", "jugador en %s" % jugador.global_position)
	_fin()


func _fin() -> void:
	print("RESULTADO: " + ("BIEN" if _bien else "MAL"))
	get_tree().quit()
