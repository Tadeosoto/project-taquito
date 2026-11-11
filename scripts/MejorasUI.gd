extends CanvasLayer

# El menu de la tienda de mejoras (el "punto" de la carrera). Lo crea Interior.activar()
# cuando `mejoras = true`; reemplaza a TiendaUI. Recorre el catalogo de Mejoras, asi que una
# mejora nueva aparece sola. La navegacion la reparte con Interior: izquierda/derecha cambia
# categoria (`mover`), arriba/abajo elige renglon (aqui) y saltar compra (`Interior._comprar`).
# No pausa: el interior ya detuvo al jugador y su camara es fija.

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.65, 0.65, 0.68)
const ROJO := Color(1.0, 0.3, 0.25)
const VERDE := Color(0.6, 1.0, 0.6)
const TEMA := preload("res://resources/ui/tema_pixel.tres")

var _categoria := 0
var _elegido := 0
var _entradas: Array = []      # las del catalogo de la categoria actual
var _lista: VBoxContainer
var _dinero: Label
var _titulo: Label
var _detalle: Label
var _precio: Label
var _mensaje: Label
var _mensaje_tween: Tween
var _aviso: Label


var _mejoras = null
var _cartera = null


func _ready() -> void:
	layer = 9
	_mejoras = get_node_or_null("/root/Mejoras")
	_cartera = get_node_or_null("/root/Cartera")
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.02, 0.03, 0.78)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 24)
	margen.add_theme_constant_override("margin_right", 24)
	margen.add_theme_constant_override("margin_top", 14)
	margen.add_theme_constant_override("margin_bottom", 14)
	raiz.add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	margen.add_child(columna)
	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	_titulo = _label("MEJORAS · EL PUNTO", 22, AMARILLO)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_titulo)
	_dinero = _label("$0", 18, VERDE)
	_dinero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cabecera.add_child(_dinero)
	columna.add_child(_label("←/→ categoría    ↑/↓ elegir    Espacio comprar    S/Esc salir", 11, GRIS))
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 18)
	columna.add_child(cuerpo)
	_lista = VBoxContainer.new()
	_lista.custom_minimum_size.x = 330.0
	_lista.add_theme_constant_override("separation", 3)
	cuerpo.add_child(_lista)
	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 6)
	cuerpo.add_child(derecha)
	_detalle = _label("", 14, BLANCO)
	_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.custom_minimum_size.y = 150.0
	derecha.add_child(_detalle)
	_precio = _label("", 16, AMARILLO)
	derecha.add_child(_precio)
	_aviso = _label("", 12, GRIS)
	derecha.add_child(_aviso)
	_mensaje = _label("", 15, VERDE)
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	derecha.add_child(_mensaje)
	if _cartera:
		_cartera.cambio.connect(_actualizar_dinero)
	if _mejoras:
		_mejoras.cambio.connect(_refrescar)
	_actualizar_dinero()
	_refrescar()


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	if TEMA:
		label.add_theme_font_override("font", TEMA.default_font)
	return label


func _actualizar_dinero() -> void:
	_dinero.text = "$%d" % (_cartera.pesos if _cartera else 0)


func _catalogo_categoria() -> Array:
	var salida := []
	if _mejoras == null:
		return salida
	for dato: Dictionary in _mejoras.CATALOGO:
		if dato["categoria"] == _categoria:
			salida.append(dato)
	return salida


func mover(paso: int) -> void:
	_categoria = wrapi(_categoria + paso, 0, _mejoras.CATEGORIAS.size() if _mejoras else 1)
	_elegido = 0
	_refrescar()


func mover_item(paso: int) -> void:
	if _entradas.is_empty():
		return
	_elegido = wrapi(_elegido + paso, 0, _entradas.size())
	_refrescar()


func comprar() -> void:
	if _entradas.is_empty():
		return
	var dato: Dictionary = _entradas[_elegido]
	if _mejoras and _mejoras.comprar(dato["id"]):
		_mensaje.text = "Compraste: %s" % dato["nombre"]
		_mensaje.add_theme_color_override("font_color", VERDE)
		var jugador := get_tree().get_first_node_in_group("jugador")
		if jugador:
			_mejoras.aplicar_en_jugador(jugador)
		_refrescar()
	else:
		_mensaje.text = "No te alcanza o ya lo tienes."
		_mensaje.add_theme_color_override("font_color", ROJO)


func decir(texto: String, segundos := 3.0) -> void:
	_aviso.text = texto
	if _mensaje_tween and _mensaje_tween.is_valid():
		_mensaje_tween.kill()
	_mensaje_tween = create_tween()
	_mensaje_tween.tween_interval(segundos)
	_mensaje_tween.tween_property(_aviso, "modulate:a", 0.0, 0.8)


func _refrescar() -> void:
	if _lista == null:
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	_entradas = _catalogo_categoria()
	_titulo.text = "MEJORAS · %s" % String(_mejoras.CATEGORIAS[_categoria]).to_upper()
	for i in _entradas.size():
		var dato: Dictionary = _entradas[i]
		var texto: String = dato["nombre"]
		var nivel: int = _mejoras.nivel(dato["id"])
		if dato["tipo"] == "buff":
			texto += "  (para la noche)"
		elif dato["niveles"] > 1:
			texto += "  %d/%d" % [nivel, dato["niveles"]]
		elif _mejoras.al_maximo(dato["id"]):
			texto += "  ✓"
		var color := AMARILLO if i == _elegido else BLANCO
		_lista.add_child(_label(("> " if i == _elegido else "  ") + texto, 14, color))
	if _entradas.is_empty():
		_lista.add_child(_label("  (nada)", 14, GRIS))
		_detalle.text = ""
		_precio.text = ""
		return
	var elegido: Dictionary = _entradas[_elegido]
	_detalle.text = "%s\n\n%s" % [elegido["nombre"], elegido["detalle"]]
	var costo: int = _mejoras.costo_siguiente(elegido["id"])
	var nivel: int = _mejoras.nivel(elegido["id"])
	if costo < 0 or _mejoras.al_maximo(elegido["id"]):
		_precio.text = "Al máximo"
		_precio.add_theme_color_override("font_color", GRIS)
	else:
		_precio.text = "$%d" % costo
		_precio.add_theme_color_override("font_color", AMARILLO if (_cartera and _cartera.pesos >= costo) else ROJO)
		if elegido["niveles"] > 1:
			_precio.text += "   (nivel %d → %d)" % [nivel, nivel + 1]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up", true):
		mover_item(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down", true):
		mover_item(1)
		get_viewport().set_input_as_handled()
