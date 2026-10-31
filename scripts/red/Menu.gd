extends Control

# El menu de inicio: jugar solo o en coop. Con Steam, el que hospeda crea la partida y
# desde ahi invita (Shift+Tab abre Steam); el amigo acepta la invitacion en Steam.
# ENet es para probar: varias ventanas en la misma PC, o la misma red.

const MAPA := "res://scenes/map_test.tscn"
const SAFEHOUSE := "res://scenes/safehouse.tscn"

var _estado: Label
var _direccion: LineEdit
var _escena: OptionButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var columna := VBoxContainer.new()
	columna.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	columna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	columna.grow_vertical = Control.GROW_DIRECTION_BOTH
	columna.custom_minimum_size.x = 320.0
	columna.add_theme_constant_override("separation", 6)
	add_child(columna)
	var titulo := Label.new()
	titulo.text = "GUADALAJAJA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	columna.add_child(titulo)
	_boton(columna, "Jugar solo", func() -> void: Red.cambiar_escena(MAPA))
	_boton(columna, "Dev safehouse", func() -> void: Red.cambiar_escena(SAFEHOUSE))
	columna.add_child(HSeparator.new())
	_escena = OptionButton.new()
	_escena.add_item("Coop en el dev safehouse")
	_escena.add_item("Coop en el mapa")
	columna.add_child(_escena)
	var steam := _boton(columna, "Crear partida (Steam)", func() -> void: Red.hospedar_steam(_escena_elegida()))
	steam.disabled = not Red.steam_disponible()
	columna.add_child(HSeparator.new())
	_boton(columna, "Crear partida de prueba (sin Steam)", func() -> void: Red.hospedar_enet(_escena_elegida()))
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	_direccion = LineEdit.new()
	_direccion.text = "127.0.0.1"
	_direccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_direccion)
	_boton(fila, "Unirse", func() -> void:
		_decir("Entrando...")
		Red.unirse_enet(_direccion.text.strip_edges()))
	_boton(columna, "World (escena vieja)", func() -> void: Red.cambiar_escena("res://scenes/world.tscn"))
	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado)
	Red.aviso.connect(_decir)
	if Red.ultimo_aviso != "":
		_decir(Red.ultimo_aviso)
		Red.ultimo_aviso = ""


func _exit_tree() -> void:
	if Red.aviso.is_connected(_decir):
		Red.aviso.disconnect(_decir)


func _escena_elegida() -> String:
	return SAFEHOUSE if _escena.selected == 0 else MAPA


func _boton(padre: Control, texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.pressed.connect(accion)
	padre.add_child(boton)
	return boton


func _decir(texto: String) -> void:
	_estado.text = texto
