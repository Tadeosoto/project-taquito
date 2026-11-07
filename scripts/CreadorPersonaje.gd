extends Control

# La pantalla de crear personaje (Personaje.gd). Sale despues de Jugar y en el safehouse (tecla
# C). A la izquierda el protagonista dando vueltas con luz pareja, para que se vea bien el color; a la
# derecha los renglones. Se mueve con flechas, control o mouse; el nombre solo recibe teclas
# despues de Enter, para que WASD no escriba. Pantalla de 640x480.

signal listo
signal volver

const MODELO := preload("res://scenes/protagonista.tscn")
const AMARILLO := Color(1.0, 0.85, 0.1)
const TITULO := "¿Quién eres?"
const TEXTO_PIEL := "Tranquilo, los zombis no discriminan. Los demás, sí."
const TEXTO_AYUDA := "Flechas: elegir y mover · Enter: aceptar · Esc: volver"
const PASO := 0.05
const GIRO := 0.5   # rad/s
const ANCHO_VISTA := 230.0
const VISTA_CAMARA := Vector3(0.0, 1.05, 3.9)
const VISTA_MIRA := Vector3(0.0, 1.0, 0.0)
const VOLUMEN_SONIDOS := -6.0  # dB; Empezar y Esc suenan en Inicio.gd

enum Tipo { NOMBRE, DESLIZADOR, ROPA, AZAR, EMPEZAR, PROTAGONISTA }

var _renglones: Array[Dictionary] = []
var _elegido := 0
var _nombre: LineEdit
var _resumen: Label
var _giro: Node3D
var _modelo: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_armar()
	_leer()
	_marcar()


func _process(delta: float) -> void:
	_giro.rotation.y += GIRO * delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up", true):
		_elegir(_elegido - 1)
	elif event.is_action_pressed("ui_down", true):
		_elegir(_elegido + 1)
	elif event.is_action_pressed("ui_left", true):
		_cambiar(-1)
	elif event.is_action_pressed("ui_right", true):
		_cambiar(1)
	elif event.is_action_pressed("ui_accept"):
		_aceptar()
	elif event.is_action_pressed("ui_cancel"):
		_terminar(volver)
	else:
		return
	get_viewport().set_input_as_handled()


func _elegir(i: int) -> void:
	var antes := _elegido
	_elegido = wrapi(i, 0, _renglones.size())
	# El mouse, el foco y arrastrar una barra tambien eligen: solo suena si cambia
	if _elegido != antes:
		_sonar("ui_mover")
	_marcar()


func _sonar(nombre: String) -> void:
	Sonidos.tocar(self, nombre, VOLUMEN_SONIDOS)


func _cambiar(paso: int) -> void:
	var renglon := _renglones[_elegido]
	match renglon["tipo"]:
		Tipo.DESLIZADOR:
			var barra: HSlider = renglon["barra"]
			barra.value += paso * PASO
		Tipo.ROPA:
			Personaje.ropa = wrapi(Personaje.ropa + paso, 0, Personaje.ROPA.size())
			_actualizar()
		Tipo.PROTAGONISTA:
			Personaje.protagonista = wrapi(Personaje.protagonista + paso, 0, Personaje.PROTAGONISTAS.size())
			_sonar("ui_mover")
			_actualizar()


func _aceptar() -> void:
	match _renglones[_elegido]["tipo"]:
		Tipo.NOMBRE:
			_nombre.grab_focus()
			_nombre.edit()
			_nombre.caret_column = _nombre.text.length()
		Tipo.AZAR:
			_sonar("ui_azar")
			Personaje.al_azar()
			_leer()
		Tipo.EMPEZAR:
			_terminar(listo)
		_:
			_elegir(_elegido + 1)


func _terminar(senal: Signal) -> void:
	Personaje.nombre = _nombre.text
	Personaje.guardar()
	_nombre.text = Personaje.nombre
	senal.emit()


# Pasa los valores de Personaje a la pantalla
func _leer() -> void:
	_nombre.text = Personaje.nombre
	for renglon: Dictionary in _renglones:
		if renglon["tipo"] == Tipo.DESLIZADOR:
			(renglon["barra"] as HSlider).set_value_no_signal(Personaje.get(renglon["propiedad"]))
	_actualizar()


func _actualizar() -> void:
	Personaje.vestir(_modelo)
	_resumen.text = Personaje.resumen_cuerpo()
	for renglon: Dictionary in _renglones:
		if renglon["tipo"] == Tipo.ROPA:
			(renglon["valor"] as Label).text = "< %s >" % Personaje.ROPA_NOMBRES[Personaje.ropa]
		elif renglon["tipo"] == Tipo.PROTAGONISTA:
			(renglon["valor"] as Label).text = "< %s >" % Personaje.PROTAGONISTAS[Personaje.protagonista]


func _marcar() -> void:
	for i in _renglones.size():
		var etiqueta: Label = _renglones[i]["etiqueta"]
		etiqueta.add_theme_color_override("font_color", AMARILLO if i == _elegido else Color.WHITE)


# --- Armar la pantalla ---

func _armar() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.03, 0.05, 0.94)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_vista()
	var columna := VBoxContainer.new()
	columna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columna.offset_left = ANCHO_VISTA + 22.0
	columna.offset_right = -14.0
	columna.offset_top = 14.0
	columna.offset_bottom = -10.0
	columna.add_theme_constant_override("separation", 5)
	add_child(columna)
	columna.add_child(_texto(TITULO, 24, AMARILLO))
	_renglon_eleccion(columna, "Personaje", Tipo.PROTAGONISTA)
	_renglon_nombre(columna)
	_deslizador(columna, "Tono de piel", "tono")
	var piel := _texto(TEXTO_PIEL, 12, Color(0.85, 0.85, 0.8))
	piel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(piel)
	_deslizador(columna, "Flaco - Gordo", "complexion")
	_deslizador(columna, "Chaparro - Alto", "talla")
	_deslizador(columna, "Cabeza", "cabeza")
	# La ropa queda para despues: el protagonista trae la suya pintada en la textura
	# _renglon_ropa(columna)
	_resumen = _texto("", 12, Color(0.75, 1.0, 0.6))
	_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_resumen)
	_boton(columna, "Al azar", Tipo.AZAR)
	_boton(columna, "Empezar", Tipo.EMPEZAR)
	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(hueco)
	columna.add_child(_texto(TEXTO_AYUDA, 11, Color(0.75, 0.75, 0.75)))


func _vista() -> void:
	var marco := SubViewportContainer.new()
	marco.stretch = true
	marco.position = Vector2(8.0, 14.0)
	marco.size = Vector2(ANCHO_VISTA, 452.0)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_DISABLED
	marco.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.2, 0.22, 0.26)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.WHITE
	entorno.ambient_light_energy = 0.55
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40.0, 25.0, 0.0)
	sol.light_energy = 0.9
	vista.add_child(sol)
	var camara := Camera3D.new()
	camara.fov = 45.0
	vista.add_child(camara)
	camara.position = VISTA_CAMARA
	camara.look_at(VISTA_MIRA)
	_giro = Node3D.new()
	vista.add_child(_giro)
	_modelo = MODELO.instantiate() as Node3D
	# Del mismo tamaño que en el juego (player.tscn)
	_modelo.scale = Vector3.ONE * 0.39
	_giro.add_child(_modelo)


func _renglon_nombre(padre: Control) -> void:
	var fila := _fila(padre, "Nombre", Tipo.NOMBRE)
	_nombre = LineEdit.new()
	_nombre.max_length = Personaje.NOMBRE_MAX
	_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nombre.placeholder_text = "Sin nombre"
	_nombre.add_theme_font_size_override("font_size", 15)
	fila.add_child(_nombre)
	_nombre.text_submitted.connect(func(_texto_nuevo: String) -> void: _soltar_nombre())
	_nombre.gui_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			_nombre.accept_event()
			_soltar_nombre())
	_nombre.focus_entered.connect(func() -> void: _elegir(_indice(Tipo.NOMBRE)))


func _soltar_nombre() -> void:
	Personaje.nombre = _nombre.text
	_nombre.release_focus()


func _deslizador(padre: Control, texto: String, propiedad: String) -> void:
	var fila := _fila(padre, texto, Tipo.DESLIZADOR)
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.01
	barra.focus_mode = Control.FOCUS_NONE
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(barra)
	var i := _renglones.size() - 1
	_renglones[i]["barra"] = barra
	_renglones[i]["propiedad"] = propiedad
	barra.value_changed.connect(func(valor: float) -> void:
		Personaje.set(propiedad, valor)
		_actualizar())
	barra.drag_started.connect(func() -> void: _elegir(i))


func _renglon_ropa(padre: Control) -> void:
	_renglon_eleccion(padre, "Ropa", Tipo.ROPA)


# Un renglon de < valor > que cambia con izquierda/derecha o con clic
func _renglon_eleccion(padre: Control, texto: String, tipo: Tipo) -> void:
	var fila := _fila(padre, texto, tipo)
	var valor := _texto("", 15, Color.WHITE)
	valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	valor.mouse_filter = Control.MOUSE_FILTER_STOP
	valor.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_elegir(_indice(tipo))
			_cambiar(1))
	fila.add_child(valor)
	_renglones[_renglones.size() - 1]["valor"] = valor


func _indice(tipo: Tipo) -> int:
	for i in _renglones.size():
		if _renglones[i]["tipo"] == tipo:
			return i
	return 0


func _boton(padre: Control, texto: String, tipo: Tipo) -> void:
	var etiqueta := _texto(texto, 18, Color.WHITE)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_STOP
	padre.add_child(etiqueta)
	var i := _renglones.size()
	_renglones.append({"tipo": tipo, "etiqueta": etiqueta})
	etiqueta.mouse_entered.connect(func() -> void: _elegir(i))
	etiqueta.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_elegir(i)
			_aceptar())


func _fila(padre: Control, texto: String, tipo: Tipo) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	padre.add_child(fila)
	var etiqueta := _texto(texto, 14, Color.WHITE)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.custom_minimum_size.x = 118.0
	fila.add_child(etiqueta)
	_renglones.append({"tipo": tipo, "etiqueta": etiqueta})
	return fila


func _texto(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label
