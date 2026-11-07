extends Control

# La libreta del Nocturno (InventoryUI, estado LIBRETA; L o R3 con el inventario abierto): una
# pagina de cuaderno por bicho (LibretaEntradas), con su dibujo pegado con cinta y lo que sabe
# segun el nivel de la entrada en el autoload Libreta. Dos hojas por entrada: "Que es" y "Por que
# es asi"; luego "Como matarlo" y los datos. Lo que no conoces sale en sombra y con "???".
# Flechas arriba/abajo: otro bicho; izquierda/derecha (o Q/E): voltear la hoja; Esc, L o R3: salir.

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ESCRITORIO := Color(0.16, 0.12, 0.09)
const PAPEL := Color(0.93, 0.89, 0.77)
const PAPEL_SOMBRA := Color(0.0, 0.0, 0.0, 0.35)
const RENGLON := Color(0.55, 0.68, 0.82, 0.45)
const MARGEN := Color(0.82, 0.3, 0.3, 0.6)
const TINTA := Color(0.13, 0.12, 0.16)
const TINTA_CLARA := Color(0.38, 0.36, 0.38)
const PLUMA := Color(0.72, 0.12, 0.1)
const CINTA := Color(0.95, 0.92, 0.7, 0.75)
const HOJA := Rect2(150.0, 18.0, 476.0, 446.0)
const ALTO_RENGLON := 15.0
const DIBUJO := 128.0

var elegido := 0
var hoja := 0
var _pestanas: Array[Label] = []
var _papel: Control
var _titulo: Label
var _apodo: Label
var _dibujo: TextureRect
var _texto: RichTextLabel
var _pie: Label
var _cuenta: Label


class Papel extends Control:
	var manchas: Array = []

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color(0.93, 0.89, 0.77))
		# Renglones y margen rojo
		var y := 58.0
		while y < size.y - 8.0:
			draw_line(Vector2(6, y), Vector2(size.x - 6, y), Color(0.55, 0.68, 0.82, 0.45), 1.0)
			y += 15.0
		draw_line(Vector2(34, 0), Vector2(34, size.y), Color(0.82, 0.3, 0.3, 0.6), 1.0)
		# Hoyos del arillo
		for k in 9:
			draw_circle(Vector2(14, 30 + k * 48), 4.0, Color(0.16, 0.12, 0.09))
		# Manchas de cafe y de lodo, siempre las mismas por pagina
		for m in manchas:
			draw_arc(m[0], m[1], 0.0, TAU, 24, m[2], 2.0)
			draw_circle(m[0], m[1] * 0.85, Color(m[2], m[2].a * 0.25))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	var fondo := ColorRect.new()
	fondo.color = ESCRITORIO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var encabezado := _label("LIBRETA", 16, Color(0.93, 0.89, 0.77))
	encabezado.position = Vector2(16.0, 14.0)
	add_child(encabezado)
	_cuenta = _label("", 10, Color(0.7, 0.66, 0.58))
	_cuenta.position = Vector2(16.0, 34.0)
	add_child(_cuenta)
	for i in LibretaEntradas.ENTRADAS.size():
		var pestana := _label("", 11, TINTA)
		pestana.position = Vector2(12.0, 60.0 + i * 30.0)
		pestana.size = Vector2(134.0, 24.0)
		pestana.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = PAPEL.darkened(0.15)
		estilo.set_content_margin_all(4.0)
		estilo.corner_radius_top_left = 3
		estilo.corner_radius_bottom_left = 3
		pestana.add_theme_stylebox_override("normal", estilo)
		add_child(pestana)
		_pestanas.append(pestana)
	_papel = Papel.new()
	_papel.position = HOJA.position
	_papel.size = HOJA.size
	_papel.rotation = deg_to_rad(-0.6)
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_papel)
	_titulo = _label("", 18, PLUMA)
	_titulo.position = Vector2(44.0, 12.0)
	_papel.add_child(_titulo)
	_apodo = _label("", 11, TINTA_CLARA)
	_apodo.position = Vector2(46.0, 36.0)
	_papel.add_child(_apodo)
	_dibujo = TextureRect.new()
	_dibujo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dibujo.size = Vector2.ONE * DIBUJO
	_dibujo.position = Vector2(HOJA.size.x - DIBUJO - 18.0, 14.0)
	_dibujo.pivot_offset = _dibujo.size / 2.0
	_dibujo.rotation = deg_to_rad(3.0)
	_papel.add_child(_dibujo)
	# Dos tiras de cinta sobre las esquinas del dibujo
	for esquina in [Vector2(-10, -4), Vector2(DIBUJO - 30, DIBUJO - 8)]:
		var cinta := ColorRect.new()
		cinta.color = CINTA
		cinta.size = Vector2(40, 12)
		cinta.position = _dibujo.position + esquina
		cinta.rotation = deg_to_rad(-25.0 if esquina.x < 0 else 20.0)
		cinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_papel.add_child(cinta)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = false
	_texto.scroll_active = false
	_texto.position = Vector2(44.0, 150.0)
	_texto.size = Vector2(HOJA.size.x - 64.0, HOJA.size.y - 186.0)
	_texto.add_theme_color_override("default_color", TINTA)
	_texto.add_theme_font_size_override("normal_font_size", 11)
	_texto.add_theme_font_size_override("bold_font_size", 12)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papel.add_child(_texto)
	_pie = _label("", 10, TINTA_CLARA)
	_pie.position = Vector2(44.0, HOJA.size.y - 26.0)
	_pie.size = Vector2(HOJA.size.x - 64.0, 18.0)
	_pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_papel.add_child(_pie)
	var ayuda := _label("Flechas: elegir · ← →: hoja · Esc: regresar", 10, Color(0.7, 0.66, 0.58))
	ayuda.position = Vector2(12.0, 456.0)
	add_child(ayuda)
	visible = false


func _label(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _libreta() -> Node:
	return get_node_or_null("/root/Libreta")


func mostrar() -> void:
	visible = true
	# Abre en la primera nota sin leer, si hay
	var libreta := _libreta()
	if libreta:
		for i in LibretaEntradas.ENTRADAS.size():
			if libreta.sin_leer.has(LibretaEntradas.ENTRADAS[i].id):
				elegido = i
				break
	hoja = 0
	_actualizar()


func cerrar() -> void:
	visible = false


func manejar(event: InputEvent) -> bool:
	var total := LibretaEntradas.ENTRADAS.size()
	if event.is_action_pressed("inspect_up"):
		elegido = wrapi(elegido - 1, 0, total)
		hoja = 0
	elif event.is_action_pressed("inspect_down"):
		elegido = wrapi(elegido + 1, 0, total)
		hoja = 0
	elif event.is_action_pressed("inspect_left") or event.is_action_pressed("inventory_previous"):
		hoja = 0
	elif event.is_action_pressed("inspect_right") or event.is_action_pressed("inventory_next"):
		hoja = 1
	else:
		return false
	Sonidos.tocar(self, "lapiz", -14.0, 1.4)
	_actualizar()
	return true


func _actualizar() -> void:
	var libreta := _libreta()
	var conocidas := 0
	for i in LibretaEntradas.ENTRADAS.size():
		var e: Dictionary = LibretaEntradas.ENTRADAS[i]
		var n: int = libreta.nivel(e.id) if libreta else 0
		if n > 0:
			conocidas += 1
		var pestana := _pestanas[i]
		var marca := " •" if libreta and libreta.sin_leer.has(e.id) else ""
		pestana.text = (e.titulo if n > 0 else "???") + marca
		var estilo := pestana.get_theme_stylebox("normal") as StyleBoxFlat
		estilo.bg_color = PAPEL if i == elegido else PAPEL.darkened(0.25)
		pestana.position.x = 18.0 if i == elegido else 12.0
		pestana.add_theme_color_override("font_color", PLUMA if marca != "" else TINTA)
	_cuenta.text = "%d de %d" % [conocidas, LibretaEntradas.ENTRADAS.size()]
	var e: Dictionary = LibretaEntradas.ENTRADAS[elegido]
	var nivel: int = libreta.nivel(e.id) if libreta else 0
	if libreta and nivel > 0:
		libreta.leer(e.id)
	_dibujo.texture = LibretaEntradas.dibujo(e.id, nivel > 0)
	(_papel as Papel).manchas = _manchas(elegido)
	_papel.queue_redraw()
	if nivel == 0:
		_titulo.text = "???"
		_apodo.text = ""
		_texto.text = "[color=#5c5a5e]No lo he visto. Mejor así.[/color]"
		_pie.text = ""
		return
	_titulo.text = e.titulo
	_apodo.text = e.apodo
	var t := ""
	if hoja == 0:
		t += _apartado("Qué es", e.que, true, "")
		t += _apartado("Por qué es así", e.por_que, nivel >= LibretaEntradas.NIVEL_PELEADO, e.pista_por_que)
	else:
		t += _apartado("Cómo matarlo", e.como, nivel >= LibretaEntradas.NIVEL_MATADO, e.pista_como)
		if nivel >= LibretaEntradas.NIVEL_MATADO:
			var matados: int = libreta.matados.get(e.id, 0)
			t += _apartado("Datos", LibretaEntradas.datos(e.id) + ("\nLlevo %d." % matados if matados > 0 else ""), true, "")
	_texto.text = t
	_pie.text = "hoja %d de 2  →" % (hoja + 1) if hoja == 0 else "←  hoja 2 de 2"


func _apartado(titulo: String, texto: String, sabido: bool, pista: String) -> String:
	var cabeza := "[color=#b81f1a][b]%s[/b][/color]\n" % titulo
	if sabido:
		return cabeza + texto + "\n\n"
	return cabeza + "[color=#6a676b](todavía no sé... %s)[/color]\n\n" % pista


# Manchas que no cambian entre aperturas: dependen de la pagina
func _manchas(i: int) -> Array:
	var azar := RandomNumberGenerator.new()
	azar.seed = 991 + i * 37
	var lista := []
	for k in azar.randi_range(1, 3):
		var color := Color(0.45, 0.3, 0.16, 0.35) if azar.randf() < 0.6 else Color(0.2, 0.45, 0.38, 0.3)
		lista.append([Vector2(azar.randf_range(60, HOJA.size.x - 40), azar.randf_range(160, HOJA.size.y - 30)),
			azar.randf_range(10.0, 26.0), color])
	return lista
