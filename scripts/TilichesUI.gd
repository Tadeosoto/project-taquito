extends Control

# Los tiliches del inventario (InventoryUI, estado TILICHES; B o RB): los materiales del taller
# (Tiliches.gd, Materiales.gd), arriba las seis familias en sus tres niveles y luego los
# especiales. Con `vitrina = true` (antes de add_child) es la vitrina de La Chava (TallerUI, V):
# solo los trofeos, que se quedan entre partidas. Las flechas mueven un cursor (va a la casilla
# mas cercana en esa direccion) y abajo sale que es cada uno.

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.55, 0.55, 0.55)
const OSCURO := Color(0.3, 0.3, 0.32)
const FAMILIA_X := 28.0
const COLUMNA_X := 104.0
const COLUMNA_ANCHO := 172.0
const FILA_Y := 74.0
const FILA_ALTO := 24.0
const CAJITA := 64.0         # ancho de cada especial y trofeo

var elegido := 0
var vitrina := false
var _casillas: Array[Dictionary] = []   # id, centro, icono (TextureRect), cuantos (Label), nombre (Label o null)
var _cursor: Panel
var _detalle: Label
var _descripcion: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	if vitrina:
		_armar_vitrina()
	else:
		_armar_materiales()
	_cursor = Panel.new()
	var borde := StyleBoxFlat.new()
	borde.bg_color = Color(1.0, 0.85, 0.1, 0.1)
	borde.border_color = AMARILLO
	borde.set_border_width_all(1)
	_cursor.add_theme_stylebox_override("panel", borde)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor)
	_detalle = _label("", 14, AMARILLO)
	_detalle.position = Vector2(FAMILIA_X, 404.0)
	add_child(_detalle)
	_descripcion = _label("", 12, BLANCO)
	_descripcion.position = Vector2(FAMILIA_X, 424.0)
	_descripcion.size = Vector2(584.0, 20.0)
	add_child(_descripcion)
	var ayuda := _label("Flechas: elegir    Esc / V: regresar" if vitrina else "Flechas: elegir    Esc / B: regresar", 11, GRIS)
	ayuda.position = Vector2(FAMILIA_X, 452.0)
	add_child(ayuda)
	Tiliches.cambio.connect(_actualizar)
	visible = false


func _armar_materiales() -> void:
	var titulo := _label("TILICHES", 22, AMARILLO)
	titulo.position = Vector2(FAMILIA_X, 12.0)
	add_child(titulo)
	var sub := _label("Materiales para el taller de La Chava. Van en tu cangurera: no ocupan lugar.", 11, GRIS)
	sub.position = Vector2(FAMILIA_X, 40.0)
	add_child(sub)
	for n in Materiales.NIVELES.size():
		var cabeza := _label(Materiales.NIVELES[n].to_upper(), 10, GRIS)
		cabeza.position = Vector2(COLUMNA_X + n * COLUMNA_ANCHO + 22.0, FILA_Y - 16.0)
		add_child(cabeza)
	for f in Materiales.FAMILIAS.size():
		var y := FILA_Y + f * FILA_ALTO
		var familia := _label(Materiales.FAMILIAS[f], 12, GRIS)
		familia.position = Vector2(FAMILIA_X, y)
		add_child(familia)
		for n in Materiales.NIVELES.size():
			_casilla(Materiales.comun(f, n), Vector2(COLUMNA_X + n * COLUMNA_ANCHO, y), true)
	var y_especiales := FILA_Y + Materiales.FAMILIAS.size() * FILA_ALTO + 24.0
	var cabeza_esp := _label("ESPECIALES", 10, GRIS)
	cabeza_esp.position = Vector2(FAMILIA_X, y_especiales)
	add_child(cabeza_esp)
	var x := FAMILIA_X
	for id in Materiales.de_clase(Materiales.Clase.ESPECIAL):
		_casilla(id, Vector2(x, y_especiales + 16.0), false)
		x += CAJITA + 12.0


# La vitrina de La Chava: los trofeos en renglones
func _armar_vitrina() -> void:
	var titulo := _label("VITRINA DE LA CHAVA", 22, AMARILLO)
	titulo.position = Vector2(FAMILIA_X, 12.0)
	add_child(titulo)
	var sub := _label("Los trofeos se quedan aquí aunque empieces otra partida.", 11, GRIS)
	sub.position = Vector2(FAMILIA_X, 40.0)
	add_child(sub)
	var por_renglon := 7
	var trofeos := Materiales.de_clase(Materiales.Clase.TROFEO)
	for i in trofeos.size():
		_casilla(trofeos[i], Vector2(FAMILIA_X + (i % por_renglon) * (CAJITA + 18.0), FILA_Y + 10.0 + (i / por_renglon) * 80.0), false)


# Una casilla: icono y cuantos; las comunes tambien su nombre (las demas lo dicen abajo)
func _casilla(id: String, en: Vector2, con_nombre: bool) -> void:
	var icono := TextureRect.new()
	icono.texture = Materiales.icono(id)
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.position = en + (Vector2(2.0, 2.0) if con_nombre else Vector2((CAJITA - 32.0) / 2.0, 0.0))
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.size = Vector2.ONE * (16.0 if con_nombre else 32.0)
	add_child(icono)
	var nombre: Label = null
	var cuantos: Label
	var tamano: Vector2
	if con_nombre:
		nombre = _label(Materiales.nombre(id), 12, BLANCO)
		nombre.position = en + Vector2(22.0, 0.0)
		add_child(nombre)
		cuantos = _label("", 12, BLANCO)
		cuantos.position = en + Vector2(COLUMNA_ANCHO - 52.0, 0.0)
		cuantos.size = Vector2(36.0, 18.0)
		cuantos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tamano = Vector2(COLUMNA_ANCHO - 10.0, 20.0)
	else:
		cuantos = _label("", 12, BLANCO)
		cuantos.position = en + Vector2(0.0, 33.0)
		cuantos.size = Vector2(CAJITA, 16.0)
		cuantos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tamano = Vector2(CAJITA, 50.0)
	add_child(cuantos)
	_casillas.append({ "id": id, "en": en - Vector2(2.0, 1.0), "tamano": tamano + Vector2(4.0, 2.0),
		"centro": en + tamano * 0.5, "icono": icono, "cuantos": cuantos, "nombre": nombre })


func mostrar() -> void:
	visible = true
	_actualizar()


func cerrar() -> void:
	visible = false


func manejar(event: InputEvent) -> bool:
	var hacia := Vector2.ZERO
	if event.is_action_pressed("inspect_right"):
		hacia = Vector2.RIGHT
	elif event.is_action_pressed("inspect_left"):
		hacia = Vector2.LEFT
	elif event.is_action_pressed("inspect_up"):
		hacia = Vector2.UP
	elif event.is_action_pressed("inspect_down"):
		hacia = Vector2.DOWN
	else:
		return false
	var siguiente := _mas_cercana(hacia)
	if siguiente >= 0:
		elegido = siguiente
		Sonidos.tocar(self, "ui_mover", -6.0)
		_actualizar()
	return true


# La casilla mas cercana hacia `hacia` (que quede mas o menos en esa direccion)
func _mas_cercana(hacia: Vector2) -> int:
	var desde: Vector2 = _casillas[elegido]["centro"]
	var mejor := -1
	var mejor_d := INF
	for i in _casillas.size():
		if i == elegido:
			continue
		var d: Vector2 = _casillas[i]["centro"] - desde
		var adelante := d.dot(hacia)
		if adelante <= 4.0:
			continue
		# Lo de lado cuenta el doble: que se mueva en linea y no en diagonal
		var costo := adelante + absf(d.dot(hacia.orthogonal())) * 2.0
		if costo < mejor_d:
			mejor_d = costo
			mejor = i
	return mejor


func _actualizar() -> void:
	if not visible:
		return
	for i in _casillas.size():
		var c := _casillas[i]
		var id: String = c["id"]
		var n: int = Tiliches.cuantos(id)
		var trofeo := Materiales.es_trofeo(id)
		(c["cuantos"] as Label).text = ("×%d" % n) if n > 0 else ("?" if trofeo else "0")
		(c["cuantos"] as Label).add_theme_color_override("font_color", (AMARILLO if trofeo else BLANCO) if n > 0 else OSCURO)
		# Los trofeos que no tienes, en sombra; los demas solo apagados
		(c["icono"] as TextureRect).modulate = Color.WHITE if n > 0 else (Color(0.16, 0.16, 0.19) if trofeo else Color(1, 1, 1, 0.3))
		if c["nombre"]:
			(c["nombre"] as Label).add_theme_color_override("font_color", BLANCO if n > 0 else OSCURO)
	var actual := _casillas[elegido]
	_cursor.position = actual["en"]
	_cursor.size = actual["tamano"]
	var id: String = actual["id"]
	var tiene: int = Tiliches.cuantos(id)
	var dato := Materiales.dato(id)
	if Materiales.es_trofeo(id) and tiene == 0:
		_detalle.text = "???"
		_descripcion.text = dato["descripcion"]
	else:
		var nivel := ""
		if dato["clase"] == Materiales.Clase.COMUN:
			nivel = " · %s, %s" % [Materiales.FAMILIAS[dato["familia"]], Materiales.NIVELES[dato["nivel"]].to_lower()]
		_detalle.text = "%s%s · tienes %d" % [dato["nombre"], nivel, tiene]
		_descripcion.text = dato["descripcion"]


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	return label
