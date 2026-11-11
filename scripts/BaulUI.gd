extends CanvasLayer

# El baul de la casa (Baul.gd): dos columnas, la mochila (Inventory) a la izquierda y el baul a
# la derecha. Arriba/abajo eligen, izquierda/derecha cambian de columna, Enter/Espacio pasa uno
# al otro lado, Esc (o Tab) cierra. Pausa el juego mientras esta abierto (corre en pausa).

signal cerrado

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.6, 0.6, 0.62)

var _columna := 0        # 0 = mochila, 1 = baul
var _fila := [0, 0]
var _listas: Array[VBoxContainer] = []
var _aviso: Label


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.85)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var titulo := _label("EL BAUL", 20, AMARILLO)
	titulo.position = Vector2(24, 16)
	add_child(titulo)
	for i in 2:
		var encabezado := _label(["MOCHILA", "BAUL"][i], 14, BLANCO)
		encabezado.position = Vector2(40 + i * 300, 56)
		add_child(encabezado)
		var lista := VBoxContainer.new()
		lista.position = Vector2(40 + i * 300, 84)
		add_child(lista)
		_listas.append(lista)
	var ayuda := _label("↑↓ elegir · ←→ mochila/baul · Enter pasar uno · Esc salir", 11, GRIS)
	ayuda.position = Vector2(24, 450)
	add_child(ayuda)
	_aviso = _label("", 12, AMARILLO)
	_aviso.position = Vector2(24, 425)
	add_child(_aviso)
	get_tree().paused = true
	_pintar()


func _label(texto: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _datos(columna: int) -> Array:
	var salida := []
	if columna == 0:
		for i in Inventory.items.size():
			salida.append([Inventory.items[i], Inventory.cantidades[i]])
	else:
		for i in Baul.items.size():
			salida.append([Baul.items[i], Baul.cantidades[i]])
	return salida


func _pintar() -> void:
	for c in 2:
		var lista := _listas[c]
		for hijo in lista.get_children():
			hijo.queue_free()
		var datos := _datos(c)
		_fila[c] = clampi(_fila[c], 0, maxi(datos.size() - 1, 0))
		if datos.is_empty():
			lista.add_child(_label("(vacio)", 13, GRIS))
		for i in datos.size():
			var item: InventoryItemData = datos[i][0]
			var texto: String = item.item_name if datos[i][1] == 1 else "%s ×%d" % [item.item_name, datos[i][1]]
			var elegido: bool = c == _columna and i == _fila[c]
			lista.add_child(_label(("> " if elegido else "  ") + texto, 13, AMARILLO if elegido else BLANCO))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory_toggle"):
		_cerrar()
	elif event.is_action_pressed("ui_up"):
		_fila[_columna] -= 1
		_pintar()
	elif event.is_action_pressed("ui_down"):
		_fila[_columna] += 1
		_pintar()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_columna = 1 - _columna
		_pintar()
	elif event.is_action_pressed("ui_accept"):
		_pasar()
	else:
		return
	get_viewport().set_input_as_handled()


func _pasar() -> void:
	var fila: int = _fila[_columna]
	if _columna == 0:
		if fila >= Inventory.items.size():
			return
		var item := Inventory.items[fila]
		if not Baul.cabe(item):
			_aviso.text = "Ya no cabe nada en el baul."
			return
		Inventory.remove_item(fila)
		Baul.guardar(item)
	else:
		if fila >= Baul.items.size():
			return
		var item := Baul.items[fila]
		if not Inventory.cabe(item):
			_aviso.text = "No te cabe en la mochila."
			return
		Baul.sacar(fila)
		Inventory.add_item(item)
	_aviso.text = ""
	Sonidos.tocar(self, "botin", -12.0)
	_pintar()


func _cerrar() -> void:
	get_tree().paused = false
	cerrado.emit()
	queue_free()
