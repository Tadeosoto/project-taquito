extends Node
# Prueba de las armas de fuego (Pistola.ARMAS) en la safehouse: te da las tres, saca cada una con
# la tecla 2 (Player.cambiar_arma), dispara una rafaga y guarda una captura de cada una.
#   godot --path . tools/armas/prueba_armas.tscn -- --capturas=<carpeta>
# Necesita ventana. Imprime las balas que quedan y sale.

const SAFEHOUSE := "res://scenes/safehouse.tscn"
const OBJETOS := ["la_tinaquera", "la_matraca", "la_chicharra"]
const ESPERA := 150       # cuadros antes de empezar: que la safehouse acabe de armarse
const POR_ARMA := 110     # cuadros con cada arma

var _carpeta := ""
var _cuadro := -1
var _jugador: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_carpeta = arg.trim_prefix("--capturas=")
	# La safehouse tiene que ser la escena actual (Player._en_safehouse): este nodo se cuelga de la raiz
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		var yo := Node.new()
		yo.set_script(get_script())
		yo.name = "PruebaArmas"
		get_tree().root.add_child.call_deferred(yo)
		get_tree().change_scene_to_file.call_deferred(SAFEHOUSE)
		set_process(false)
		return
	_cuadro = 0


func _process(_delta: float) -> void:
	if _cuadro < 0:
		return
	_cuadro += 1
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Player
		if _jugador == null or _cuadro < ESPERA:
			_jugador = null if _cuadro < ESPERA else _jugador
			return
		var inventario := get_node("/root/Inventory")
		# Lugar para las tres: la mochila de la safehouse viene llena
		while inventario.items.size() > 2:
			inventario.remove_item(inventario.items.size() - 1)
		for nombre: String in OBJETOS:
			var ok: bool = inventario.add_item(load("res://resources/productos/%s.tres" % nombre))
			print("objeto ", nombre, ": ", "en el inventario" if ok else "NO CUPO")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_jugador.cambiar_arma(1)      # la pistola
		_cuadro = ESPERA
		return
	var pistola: Node = _jugador.get_node("Pistola")
	var t := _cuadro - ESPERA
	var paso := t % POR_ARMA
	var cual := t / POR_ARMA
	if cual > OBJETOS.size():
		print("armas que traes: ", pistola.armas())
		get_tree().quit()
		return
	if paso == 1 and cual > 0:
		_jugador.cambiar_arma(1)      # 2 otra vez: la siguiente
		print("en la mano: ", pistola.arma, " (", pistola.ARMAS[pistola.arma].nombre, "), balas ", pistola.balas)
	if paso >= 40 and paso < 70 and paso % 3 == 0:
		pistola.disparar()
	if paso == 62 and _carpeta != "":
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png(_carpeta.path_join("arma_%d_%s.png" % [cual, pistola.arma]))
	if paso == 100:
		print("  tras la rafaga: balas ", pistola.balas, ", tiros ", pistola.tiros, ", recargando ", pistola.recargando())
