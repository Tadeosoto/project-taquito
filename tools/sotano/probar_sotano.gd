extends Node
# Prueba del Sotano (docs/sistemas/sotano.md) en la safehouse, con el jugador de verdad:
#   godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<carpeta>
# Necesita ventana (las capturas; sin --capturas igual corre). Entra por la flecha de la safehouse,
# revisa la cadena del de la puerta, paga la cuota, compra fichas, juega OL PLEY, la loteria y las
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
	# OL PLEY: 20 tiros de 1 ficha
	var gabinetes := sotano.find_children("OlPley_*", "StaticBody3D", false, false)
	_ver(gabinetes.size() == 10, "hay diez OL PLEY", str(gabinetes.size()))
	jugador.global_position = sotano.to_global(Vector3(13.4, -2.0, 0.2))
	sotano._abrir_olpley(gabinetes[2])
	await _esperar(0.3)
	ui = arbol.get_first_node_in_group("juego_sotano")
	var antes: int = fichas.fichas
	var tiros := 0
	for k in 20:
		ui.jalar()
		await _esperar(1.6)
		tiros += 1
		if k == 0:
			await _foto("3_olpley")
	_ver(tiros == 20 and fichas.fichas != antes - 0, "20 tiros en OL PLEY", "fichas %d -> %d, caja %d" % [antes, fichas.fichas, gabinetes[2].placa.caja])
	ui.cerrar()
	await _esperar(0.3)
	# Carreras: al rojo, 2 fichas
	jugador.global_position = sotano.to_global(Vector3(25.8, -2.0, 4.9))
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
	# Caguama
	var cuantos: int = inventario.items.size()
	sotano._caguama()
	_ver(inventario.items.size() == cuantos + 1, "compras una caguama en el congelador")
	# Las de frutas: en fichas y abiertas aunque sea de noche
	var frutas := sotano.find_children("Frutas_*", "", false, false)
	_ver(frutas.size() == 2 and frutas[0].moneda == "fichas" and not frutas[0]._cerrada(), "dos de frutas en fichas, abiertas de noche")
	# Fotos de adentro
	if _carpeta != "":
		# yaw 0 = al norte (las OL PLEY), PI/2 = al oeste (ventanilla), -PI/2 = al este (pista)
		for vista: Array in [[Vector3(14.0, -2.0, 6.0), 0.0, "6_maquinitas"], [Vector3(12.0, -2.0, 2.0), PI / 2.0, "7_ventanilla"],
				[Vector3(23.0, -2.0, 4.6), -PI / 2.0, "8_salon2"], [Vector3(14.0, -2.0, 1.0), PI, "9_altar"],
				[Vector3(26.0, -2.0, 5.2), 0.0, "10_barra"], [Vector3(9.0, -2.0, 3.0), -PI / 2.0, "11_arco"]]:
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
