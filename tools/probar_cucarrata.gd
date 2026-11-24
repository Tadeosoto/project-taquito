extends Node
# Prueba de la pelea contra la cucarrata donde ocurre: map_test, de noche (no amanece), frente a
# su bodega de La Gigantera (CucarrataCalle). Con la mision "Lo peor que he visto" aceptada,
# asi los mapas la marcan y al matarla avanza el paso. El jugador juega de verdad (1 machete, 2 pistola),
# con solo el giro de los especiales, como en la campana.
# godot --path . tools/probar_cucarrata.tscn
#   F2 empezar de nuevo (cucarrata viva y a vida llena, tu otra vez en la boca del callejon)
#   F3 / F4 saltar a la fase 2 / 3 (la despierta si estaba rondando)
#   F5 vida llena
#   F6 llevarte a la puerta de la bodega, adentro
#   F7 esconder o mostrar esta ayuda

const MISION := "res://resources/misiones/cucarrata.tres"
# En el callejon (6 m) entre su frente y la espalda de la bodega de junto, a 3 m de los vanos y hacia
# la punta norte: afuera (no la despierta: CucarrataCalle.PUERTA) y a unos pasos de entrar
const SALIDA := Vector3(20.0, 1.0, 3.0)

var _jugador: Player
var _ayuda: Label
var _listo := false


func _ready() -> void:
	Misiones.reiniciar()
	add_child(load("res://scenes/map_test.tscn").instantiate())
	var capa := CanvasLayer.new()
	capa.layer = 40
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.position = Vector2(10, 150)
	_ayuda.add_theme_font_size_override("font_size", 13)
	_ayuda.add_theme_color_override("font_outline_color", Color.BLACK)
	_ayuda.add_theme_constant_override("outline_size", 5)
	capa.add_child(_ayuda)


func _process(_delta: float) -> void:
	if not _listo:
		_jugador = get_tree().get_first_node_in_group("jugador") as Player
		if _jugador and get_tree().get_first_node_in_group("ciclo") and CucarrataCalle.instancia:
			_listo = true
			_armar()
			_empezar()
		return
	var jefe := CucarrataCalle.instancia.jefe if CucarrataCalle.instancia else null
	var estado := "no ha salido (acercate a la bodega)"
	if is_instance_valid(jefe):
		if jefe.vida <= 0.0:
			estado = "muerta"
		elif jefe.estado == JefeCucarrata.Estado.DEAMBULA:
			estado = "rondando, a %d m" % roundi(jefe.global_position.distance_to(_jugador.global_position))
		else:
			estado = "fase %d, vida %d/%d" % [jefe.fase, roundi(jefe.vida), roundi(JefeCucarrata.VIDA)]
	elif Misiones.jefe_muerto(CucarrataCalle.ID):
		estado = "muerta (F2 para otra vez)"
	if _ayuda.visible:
		_ayuda.text = "PRUEBA CUCARRATA · %s\n1 machete · 2 pistola · R recargar · brinca y pega: giro\nF2 de nuevo · F3/F4 fase 2/3 · F5 vida · F6 a la bodega · F7 ayuda" % estado


# Machete y todo el catalogo infinito, como el modo godmode de la defensa del tinaco
func _armar() -> void:
	var inventario := get_node("/root/Inventory")
	inventario.infinito = true
	inventario.items.clear()
	inventario.mochila = null
	inventario.dar_todos_los_productos()
	var machete := load("res://resources/productos/machete.tres") as InventoryItemData
	if machete and inventario.items.has(machete):
		inventario.equipada = machete
	inventario.inventory_changed.emit()


func _empezar() -> void:
	if CucarrataCalle.instancia:
		CucarrataCalle.instancia._quitar()
	Misiones.reiniciar()
	Misiones._hechas_siempre["guardia_reja"] = true   # la cucarrata se ofrece tras la guardia
	# Como en la campana: de los especiales solo el giro, que enseña la guardia (JJ, 2026-11-18)
	Misiones.ataques_de_campana()
	var mision := load(MISION) as MisionData
	Misiones.aceptar(mision)
	Misiones.elegir(mision)
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	ciclo.reiniciar_noche()
	ciclo.retener_noche = true
	_jugador.global_position = CucarrataCalle.en_bodega(SALIDA)
	_jugador.velocity = Vector3.ZERO
	get_node("/root/Salud").reiniciar()


func _unhandled_input(e: InputEvent) -> void:
	if not _listo or not (e is InputEventKey and e.pressed and not e.echo):
		return
	var jefe := CucarrataCalle.instancia.jefe if CucarrataCalle.instancia else null
	var vivo := is_instance_valid(jefe) and jefe.vida > 0.0
	match e.keycode:
		KEY_F2:
			_empezar()
		KEY_F3, KEY_F4:
			if vivo:
				jefe._despertar()
				var meta := JefeCucarrata.VIDA * (2.0 if e.keycode == KEY_F3 else 1.0) / 3.0
				if jefe.vida > meta:
					jefe._herir(jefe.vida - meta + 0.5)
		KEY_F5:
			get_node("/root/Salud").reiniciar()
		KEY_F6:
			_jugador.global_position = CucarrataCalle.frente(-3.0) + Vector3.UP
			_jugador.velocity = Vector3.ZERO
		KEY_F7:
			_ayuda.visible = not _ayuda.visible
		_:
			return
	get_viewport().set_input_as_handled()
