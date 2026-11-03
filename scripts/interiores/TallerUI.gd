class_name TallerUI
extends CanvasLayer

# La pantalla del taller de La Chava (Yonke.gd): a la derecha la lista del juego elegido
# (Recetas.gd), con "???" en los juegos que no se abren todavia; abajo, lo elegido con lo que
# pide (tienes / necesitas, en rojo lo que falta), los pesos y el plano. Lo que dice La Chava
# sale a la izquierda, sobre la escena. Flechas: arriba/abajo eligen, izquierda/derecha cambian
# de juego; Enter o Espacio lo hacen (Taller.hacer). S / Esc salen (Interiores.gd).

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.55, 0.55, 0.55)
const OSCURO := Color(0.32, 0.32, 0.34)
const ROJO := Color(1.0, 0.35, 0.3)
const VERDE := Color(0.5, 0.9, 0.45)
const PANEL_X := 300.0
const PANEL_ANCHO := 328.0
const ARRIBA := 44.0          # debajo del nombre del local, que Interiores pone arriba al centro
const LISTA_Y := ARRIBA + 66.0
const FILA_ALTO := 18.0
const DETALLE_Y := LISTA_Y + 8 * FILA_ALTO + 12.0
const DICE_DURA := 4.0

var yonke: Yonke
var juego := 1
var elegida := 0

var _rango: Label
var _pestanas: Label
var _filas: Array[Label] = []
var _marcas: Array[Label] = []
var _nombre: Label
var _efecto: Label
var _pide: VBoxContainer
var _pesos: Label
var _dice: Label
var _dice_hasta := 0


func _ready() -> void:
	layer = 5
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.82)
	panel.position = Vector2(PANEL_X - 10.0, ARRIBA - 4.0)
	panel.size = Vector2(PANEL_ANCHO + 20.0, 480.0 - ARRIBA)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var titulo := _label("TALLER DE LA CHAVA", 15, AMARILLO)
	titulo.position = Vector2(PANEL_X, ARRIBA)
	add_child(titulo)
	_rango = _label("", 11, GRIS)
	_rango.position = Vector2(PANEL_X, ARRIBA + 20.0)
	add_child(_rango)
	_pestanas = _label("", 13, GRIS)
	_pestanas.position = Vector2(PANEL_X, ARRIBA + 38.0)
	add_child(_pestanas)
	for i in 8:
		var fila := _label("", 13, BLANCO)
		fila.position = Vector2(PANEL_X + 4.0, LISTA_Y + i * FILA_ALTO)
		fila.size = Vector2(PANEL_ANCHO - 40.0, FILA_ALTO)
		fila.clip_text = true
		add_child(fila)
		_filas.append(fila)
		var marca := _label("", 11, VERDE)
		marca.position = Vector2(PANEL_X + PANEL_ANCHO - 30.0, LISTA_Y + i * FILA_ALTO + 2.0)
		add_child(marca)
		_marcas.append(marca)
	_nombre = _label("", 14, AMARILLO)
	_nombre.position = Vector2(PANEL_X, DETALLE_Y)
	add_child(_nombre)
	_efecto = _label("", 11, BLANCO)
	_efecto.position = Vector2(PANEL_X, DETALLE_Y + 20.0)
	_efecto.size = Vector2(PANEL_ANCHO, 30.0)
	_efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_efecto)
	_pide = VBoxContainer.new()
	_pide.position = Vector2(PANEL_X, DETALLE_Y + 48.0)
	_pide.add_theme_constant_override("separation", 0)
	add_child(_pide)
	_pesos = _label("", 12, BLANCO)
	_pesos.position = Vector2(PANEL_X, 430.0)
	add_child(_pesos)
	var ayuda := _label("↑↓ elegir · ←→ juego · Enter hacer · S/Esc salir", 11, GRIS)
	ayuda.position = Vector2(PANEL_X, 452.0)
	add_child(ayuda)
	_dice = _label("", 13, BLANCO)
	_dice.position = Vector2(14.0, 396.0)
	_dice.size = Vector2(PANEL_X - 34.0, 70.0)
	_dice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_dice.add_theme_color_override("font_outline_color", Color.BLACK)
	_dice.add_theme_constant_override("outline_size", 5)
	add_child(_dice)
	juego = maxi(Taller.juegos_abiertos(), 1)
	Taller.cambio.connect(_actualizar)
	Morral.cambio.connect(_actualizar)
	_actualizar()


func decir(texto: String, segundos := DICE_DURA) -> void:
	_dice.text = texto
	_dice.modulate.a = 1.0
	_dice_hasta = Time.get_ticks_msec() + int(segundos * 1000.0)


func _process(_delta: float) -> void:
	if _dice_hasta > 0:
		var falta := (_dice_hasta - Time.get_ticks_msec()) / 1000.0
		_dice.modulate.a = clampf(falta / 0.4, 0.0, 1.0)
		if falta <= 0.0:
			_dice_hasta = 0


func _input(event: InputEvent) -> void:
	if yonke == null or not yonke.activo:
		return
	var lista := Recetas.de_juego(juego)
	if event.is_action_pressed("inspect_up"):
		elegida = wrapi(elegida - 1, 0, lista.size())
		_sonar("ui_mover")
	elif event.is_action_pressed("inspect_down"):
		elegida = wrapi(elegida + 1, 0, lista.size())
		_sonar("ui_mover")
	elif event.is_action_pressed("inspect_left"):
		juego = wrapi(juego - 2, 0, Recetas.JUEGOS) + 1
		elegida = 0
		_sonar("ui_mover")
	elif event.is_action_pressed("inspect_right"):
		juego = wrapi(juego, 0, Recetas.JUEGOS) + 1
		elegida = 0
		_sonar("ui_mover")
	elif event.is_action_pressed("inventory_confirm") or event.is_action_pressed("jump"):
		_hacer(lista[elegida])
	else:
		return
	get_viewport().set_input_as_handled()
	_actualizar()


func _hacer(id: String) -> void:
	var antes := Taller.juegos_abiertos()
	var razon := Taller.hacer(id)
	if razon != "":
		_sonar("ui_error")
		decir(Yonke.LINEAS_NO.get(razon, "No se puede."), 2.5)
		return
	_sonar("whack")
	_sonar("brillo")
	if yonke:
		yonke.chispas()
	if Taller.juegos_abiertos() > antes:
		decir("%s\n%s" % [Yonke.linea_hecho(), Yonke.LINEA_JUEGO])
	else:
		decir("%s  (%s)" % [Yonke.linea_hecho(), Recetas.nombre(id)])


func _actualizar() -> void:
	var abiertos := Taller.juegos_abiertos()
	var faltan := Taller.faltan_para_siguiente()
	_rango.text = "Rango %d · %s" % [Taller.rango(), ("%d más para el juego %d" % [faltan, abiertos + 1]) if faltan >= 0 else "ya te enseñó todo"]
	var pestanas := "Juego "
	for j in range(1, Recetas.JUEGOS + 1):
		var marca := str(j) if Taller.abierto(j) else "·"
		pestanas += ("[%s] " % marca) if j == juego else (" %s  " % marca)
	_pestanas.text = pestanas
	var lista := Recetas.de_juego(juego)
	elegida = clampi(elegida, 0, lista.size() - 1)
	var abierto := Taller.abierto(juego)
	for i in _filas.size():
		var fila := _filas[i]
		var marca := _marcas[i]
		if i >= lista.size():
			fila.text = ""
			marca.text = ""
			continue
		var id := lista[i]
		var se_puede := Taller.por_que_no(id) == ""
		fila.text = ("> " if i == elegida else "  ") + (Recetas.nombre(id) if abierto else "???")
		var color := OSCURO
		if abierto:
			color = BLANCO if se_puede else GRIS
			if i == elegida:
				color = AMARILLO if se_puede else BLANCO
		fila.add_theme_color_override("font_color", color)
		marca.text = "hecho" if Taller.hechos.has(id) else ""
	_detalle(lista[elegida] if not lista.is_empty() else "", abierto)


func _detalle(id: String, abierto: bool) -> void:
	for hijo in _pide.get_children():
		hijo.queue_free()
	if id == "" or not abierto:
		_nombre.text = "???"
		var faltan := Taller.faltan_para_siguiente()
		_efecto.text = "La Chava todavía no te enseña este juego. Haz %d cosas distintas más." % maxi(faltan, 0) if juego <= Recetas.UMBRALES.size() else "Haz todo lo de los juegos 1 a 5 y trae los planos."
		_pesos.text = ""
		if yonke:
			yonke.mostrar("")
		return
	var receta := Recetas.dato(id)
	_nombre.text = Recetas.nombre(id)
	var item := Recetas.objeto(id)
	_efecto.text = item.efecto if item else Materiales.dato(Recetas.material_resultado(id)).get("descripcion", "")
	var materiales: Dictionary = receta["materiales"]
	for m: String in materiales:
		var tiene: int = Morral.cuantos(m)
		var pide: int = materiales[m]
		var fila := HBoxContainer.new()
		var icono := TextureRect.new()
		icono.texture = Materiales.icono(m)
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.custom_minimum_size = Vector2(16.0, 16.0)
		icono.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		fila.add_child(icono)
		var texto := _label("%s  %d / %d" % [Materiales.nombre(m), tiene, pide], 12, BLANCO if tiene >= pide else ROJO)
		fila.add_child(texto)
		_pide.add_child(fila)
	if receta.has("plano"):
		var tiene_plano: bool = Taller.planos.has(receta["plano"])
		_pide.add_child(_label("%s: %s" % [Recetas.PLANOS[receta["plano"]], "lo tienes" if tiene_plano else "te falta"], 12, BLANCO if tiene_plano else ROJO))
	var costo := Taller.costo(id)
	var pesos: int = Cartera.pesos
	_pesos.text = "La Chava cobra $%d · traes $%d" % [costo, pesos]
	_pesos.add_theme_color_override("font_color", BLANCO if pesos >= costo else ROJO)
	if yonke:
		yonke.mostrar(id)


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _sonar(nombre: String) -> void:
	Sonidos.tocar(self, nombre, -6.0)
