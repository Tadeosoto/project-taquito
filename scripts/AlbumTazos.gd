extends Control

# El album de tazos (InventoryUI, estado ALBUM; T o LB de control, tambien desde la pagina de
# habilidades). Una serie por pantalla: sus 12 lugares, con la cara de los que tienes (y cuantos
# repetidos) y la sombra de los que te faltan. Abajo, el elegido girando en 3D con el mismo disco
# del show (TazoRevelacion.crear_disco): los holograficos siguen brillando.
# Flechas: mover (al pasar la orilla cambia de serie); Q/E: otra serie; H: habilidades.

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.55, 0.55, 0.55)
const OSCURO := Color(0.3, 0.3, 0.32)
const COLUMNAS := 6
const CELDA := 72.0
const CARA := 64.0
const REJILLA := Vector2(104.0, 72.0)
const VISTA_LADO := 176
const VISTA_EN := Vector2(44.0, 232.0)
const TEXTO_X := 244.0
const GIRO := 0.9          # rad/s del tazo en 3D

var serie := 0
var elegido := 0
var _celdas: Array[Dictionary] = []    # cara (TextureRect), signo (Label), cuantos (Label)
var _cursor: Panel
var _titulo: Label
var _cuenta: Label
var _pestanas: Label
var _nombre: Label
var _ficha: Label
var _desbloquea: Label
var _total: Label
var _vista: SubViewport
var _pivote: Node3D
var _disco: MeshInstance3D
var _cara: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var encabezado := _label("ÁLBUM DE TAZOS", 22, AMARILLO)
	encabezado.position = Vector2(28.0, 12.0)
	add_child(encabezado)
	_pestanas = _label("", 13, GRIS)
	_pestanas.position = Vector2(380.0, 18.0)
	_pestanas.size = Vector2(236.0, 20.0)
	_pestanas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_pestanas)
	_titulo = _label("", 15, BLANCO)
	_titulo.position = Vector2(REJILLA.x, 44.0)
	add_child(_titulo)
	_cuenta = _label("", 13, GRIS)
	_cuenta.position = Vector2(REJILLA.x + COLUMNAS * CELDA - 160.0, 46.0)
	_cuenta.size = Vector2(152.0, 20.0)
	_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_cuenta)
	for i in 12:
		var en := REJILLA + Vector2((i % COLUMNAS) * CELDA, (i / COLUMNAS) * CELDA)
		var cara := TextureRect.new()
		cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cara.position = en
		cara.size = Vector2.ONE * CARA
		add_child(cara)
		var signo := _label("?", 22, OSCURO.lightened(0.2))
		signo.position = en
		signo.size = Vector2.ONE * CARA
		signo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		signo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(signo)
		var cuantos := _label("", 12, BLANCO)
		cuantos.position = en + Vector2(CARA - 30.0, CARA - 16.0)
		cuantos.size = Vector2(32.0, 16.0)
		cuantos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cuantos.add_theme_color_override("font_outline_color", Color.BLACK)
		cuantos.add_theme_constant_override("outline_size", 4)
		add_child(cuantos)
		_celdas.append({ "cara": cara, "signo": signo, "cuantos": cuantos })
	_cursor = Panel.new()
	var borde := StyleBoxFlat.new()
	borde.bg_color = Color(0, 0, 0, 0)
	borde.border_color = AMARILLO
	borde.set_border_width_all(2)
	_cursor.add_theme_stylebox_override("panel", borde)
	_cursor.size = Vector2.ONE * (CARA + 6.0)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor)
	_armar_vista()
	_nombre = _label("", 18, AMARILLO)
	_nombre.position = Vector2(TEXTO_X, VISTA_EN.y + 18.0)
	add_child(_nombre)
	_ficha = _label("", 13, BLANCO)
	_ficha.position = Vector2(TEXTO_X, VISTA_EN.y + 48.0)
	_ficha.size = Vector2(360.0, 60.0)
	add_child(_ficha)
	_desbloquea = _label("", 13, AMARILLO)
	_desbloquea.position = Vector2(TEXTO_X, VISTA_EN.y + 110.0)
	_desbloquea.size = Vector2(360.0, 40.0)
	_desbloquea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desbloquea)
	_total = _label("", 11, GRIS)
	_total.position = Vector2(28.0, 432.0)
	add_child(_total)
	var ayuda := _label("Flechas: elegir    Q/E: serie    H: habilidades    Esc: regresar", 11, GRIS)
	ayuda.position = Vector2(28.0, 452.0)
	add_child(ayuda)
	visible = false


func _armar_vista() -> void:
	var marco := SubViewportContainer.new()
	marco.stretch = true
	marco.position = VISTA_EN
	marco.size = Vector2.ONE * VISTA_LADO
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)
	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	marco.add_child(_vista)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.85, 0.82, 0.9)
	ambiente.environment.ambient_light_energy = 0.7
	_vista.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	sol.light_energy = 1.1
	_vista.add_child(sol)
	var camara := Camera3D.new()
	camara.position = Vector3(0.0, 0.0, 2.3)
	camara.fov = 38.0
	_vista.add_child(camara)
	camara.current = true
	_pivote = Node3D.new()
	_vista.add_child(_pivote)


func mostrar() -> void:
	visible = true
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_actualizar()


func cerrar() -> void:
	visible = false
	if _vista:
		_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED


func manejar(event: InputEvent) -> bool:
	var series := maxi(Tazos.numero_de_series(), 1)
	# Flechas mueven el cursor; Q/E (solo inventory_*) cambian de serie. Las flechas de lado
	# tambien son inventory_*, por eso se pregunta primero por inspect_*
	if event.is_action_pressed("inspect_right"):
		if elegido % COLUMNAS == COLUMNAS - 1:
			serie = wrapi(serie + 1, 0, series)
			elegido -= COLUMNAS - 1
		else:
			elegido += 1
	elif event.is_action_pressed("inspect_left"):
		if elegido % COLUMNAS == 0:
			serie = wrapi(serie - 1, 0, series)
			elegido += COLUMNAS - 1
		else:
			elegido -= 1
	elif event.is_action_pressed("inspect_up") or event.is_action_pressed("inspect_down"):
		elegido = wrapi(elegido + COLUMNAS, 0, 12)
	elif event.is_action_pressed("inventory_next"):
		serie = wrapi(serie + 1, 0, series)
	elif event.is_action_pressed("inventory_previous"):
		serie = wrapi(serie - 1, 0, series)
	else:
		return false
	Sonidos.tocar(self, "ui_mover", -6.0)
	_actualizar()
	return true


func _actualizar() -> void:
	if not visible:
		return
	var de_esa := Tazos.de_serie(serie)
	var completa := Tazos.completa(serie)
	_titulo.text = "Serie %d · %s%s" % [serie + 1, TazoData.SERIES[serie] if serie < TazoData.SERIES.size() else "", "  ★" if completa else ""]
	_titulo.add_theme_color_override("font_color", AMARILLO if completa else BLANCO)
	_cuenta.text = "%d / %d" % [Tazos.cuantos_de_serie(serie), de_esa.size()]
	var pestanas := ""
	for s in Tazos.numero_de_series():
		var marca := "★" if Tazos.completa(s) else str(s + 1)
		pestanas += ("[%s]" % marca if s == serie else " %s " % marca) + " "
	_pestanas.text = pestanas.strip_edges()
	for i in _celdas.size():
		var celda := _celdas[i]
		var tazo: TazoData = de_esa[i] if i < de_esa.size() else null
		var n := Tazos.cuantos(tazo) if tazo else 0
		(celda["cara"] as TextureRect).texture = (tazo.cara if n > 0 else tazo.silueta) if tazo else null
		(celda["signo"] as Label).visible = tazo != null and n == 0
		(celda["cuantos"] as Label).text = "×%d" % n if n > 1 else ""
	_cursor.position = REJILLA + Vector2((elegido % COLUMNAS) * CELDA, (elegido / COLUMNAS) * CELDA) - Vector2.ONE * 3.0
	var elegido_tazo: TazoData = de_esa[elegido] if elegido < de_esa.size() else null
	_mostrar_tazo(elegido_tazo)
	var total := Tazos.todos.size()
	_total.text = "Total: %d de %d · Series completas: %d de %d · Comunes: %d de %d para el siguiente punto" % [
		Tazos.distintos().size(), total, Tazos.series_premiadas.size(), Tazos.numero_de_series(), Tazos.progreso_comun(), Tazos.COMUNES_POR_PUNTO]


func _mostrar_tazo(tazo: TazoData) -> void:
	if _disco:
		_disco.queue_free()
		_disco = null
	if tazo == null:
		_nombre.text = ""
		_ficha.text = ""
		_desbloquea.text = ""
		return
	var n := Tazos.cuantos(tazo)
	_disco = TazoRevelacion.crear_disco(tazo)
	_cara = _disco.get_surface_override_material(0)
	if n == 0:
		_cara.set_shader_parameter("cara", tazo.silueta)
	_cara.set_shader_parameter("foil", 1.0 if n > 0 and tazo.rareza == TazoData.Rareza.HOLO else 0.0)
	_pivote.add_child(_disco)
	_nombre.text = tazo.nombre if n > 0 else "???"
	_nombre.add_theme_color_override("font_color", AMARILLO if n > 0 else GRIS)
	var lineas := "No. %02d · %s · %s" % [tazo.numero, TazoData.RAREZAS[tazo.rareza], TazoData.texto_puntos(tazo.rareza)]
	if n > 1:
		lineas += " · %d repetido%s" % [n - 1, "" if n == 2 else "s"]
	lineas += "\n" + ("Tienes %d" % n if n > 0 else "Te falta. Sale en las bolsas especiales de Takis.")
	_ficha.text = lineas
	_ficha.add_theme_color_override("font_color", TazoData.COLORES_RAREZA[tazo.rareza] if n > 0 else GRIS)
	_desbloquea.text = ""
	if tazo.desbloquea != "":
		var habilidad: String = Habilidades.dato(tazo.desbloquea).get("nombre", tazo.desbloquea)
		_desbloquea.text = ("Desbloquea: %s" if n > 0 else "Desbloquea una habilidad: %s") % habilidad


func _process(delta: float) -> void:
	if not visible or _disco == null:
		return
	_t += delta
	_pivote.rotation.y = _t * GIRO
	_pivote.rotation.x = sin(_t * 0.7) * 0.15
	if _cara and _cara.get_shader_parameter("foil") > 0.0:
		_cara.set_shader_parameter("barrido", fmod(_t * 0.4, 2.0) - 0.4)


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	return label
