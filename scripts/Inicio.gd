extends Node3D

# La pantalla de inicio: lo primero que se ve. Una escenita de noche (poste, tinaco y un
# zombi en la niebla) con el menu encima. Jugar carga el mapa en otro hilo con "Cargando..."
# en pantalla; Controles y Creditos son pantallas aqui mismo. Se mueve con flechas, control
# o mouse. Pantalla de 640x480.

const MAPA := "res://scenes/map_test.tscn"
const CREDITOS := "res://CREDITS.md"
const ZOMBI := preload("res://models/personajes/zombie_gordo/zombie_gordo.scn")
const PS1 := preload("res://shaders/ps1_combined.gdshader")
const DITHER := preload("res://shaders/dittershader.gdshader")

const AMARILLO := Color(1.0, 0.85, 0.1)
const TITULO := "GUADALAJAJA"
const SUBTITULO := "No te tomes el agua."
const FIRMA := "Vibe coded with love"
const OPCIONES := ["Jugar", "Controles", "Créditos", "Salir"]
const TEXTO_CARGANDO := "Cargando..."
const TEXTO_VOLVER := "Esc: volver"
const TEXTO_CONTROLES := """Moverse:  WASD o flechas  ·  stick izquierdo
Cámara:  mouse  ·  stick derecho
Correr:  Shift  ·  apretar el stick izquierdo
Saltar y usar:  Espacio  ·  A (Cruz)
Pegar:  clic o F  ·  X (Cuadrado)
Inventario:  Tab  ·  Start

Sobrevive 3 noches y cuida el tinaco del refugio.
De día compra tablas y atranca las entradas."""
# Lo que la licencia de los datos del mapa pide que se vea, por si falta CREDITS.md
const CREDITOS_MINIMOS := """Datos de mapa © colaboradores de OpenStreetMap, licencia ODbL.
Huellas de edificios de Google Open Buildings v3, licencia CC BY 4.0.
Tiendas, puestos y farmacias: INEGI, DENUE 05/2026."""
const CAMARA_CENTRO := Vector3(0.0, 1.7, 8.5)
const CAMARA_VAIVEN := 1.2     # m de lado a lado
const CAMARA_RITMO := 0.15     # rad/s
const MIRA := Vector3(0.0, 1.4, 0.0)
const SCROLL_PASO := 30
const GEMIDO_CADA := Vector2(6.0, 14.0)

enum Pantalla { MENU, CONTROLES, CREDITOS, CARGANDO }

var _pantalla := Pantalla.MENU
var _elegida := 0
var _opciones: Array[Label] = []
var _menu: Control
var _subpantalla: Control
var _controles: Control
var _creditos: ScrollContainer
var _creditos_texto: Label
var _cargando: Label
var _camara: Camera3D
var _tiempo := 0.0
var _gemido := 3.0
var _voz: AudioStreamPlayer
var _voz_zombi: AudioStreamPlayer3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_escena()
	_dither()
	_interfaz()
	_marcar()


func _process(delta: float) -> void:
	_tiempo += delta
	_camara.position = CAMARA_CENTRO + Vector3(sin(_tiempo * CAMARA_RITMO) * CAMARA_VAIVEN, 0.0, 0.0)
	_camara.look_at(MIRA)
	_gemido -= delta
	if _gemido <= 0.0:
		_gemido = randf_range(GEMIDO_CADA.x, GEMIDO_CADA.y)
		_voz_zombi.stream = Sonidos.sonido("gemido")
		_voz_zombi.play()
	if _pantalla == Pantalla.CARGANDO:
		_seguir_cargando()


func _unhandled_input(event: InputEvent) -> void:
	match _pantalla:
		Pantalla.MENU:
			if event.is_action_pressed("ui_up"):
				_mover(-1)
			elif event.is_action_pressed("ui_down"):
				_mover(1)
			elif event.is_action_pressed("ui_accept"):
				_activar(_elegida)
		Pantalla.CONTROLES:
			if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
				_volver()
		Pantalla.CREDITOS:
			if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
				_volver()
			elif event.is_action_pressed("ui_up", true):
				_creditos.scroll_vertical -= SCROLL_PASO
			elif event.is_action_pressed("ui_down", true):
				_creditos.scroll_vertical += SCROLL_PASO


func _mover(paso: int) -> void:
	_elegida = wrapi(_elegida + paso, 0, OPCIONES.size())
	_marcar()


func _marcar() -> void:
	for i in _opciones.size():
		var elegida := i == _elegida
		_opciones[i].text = ("> %s" if elegida else "%s") % OPCIONES[i]
		_opciones[i].add_theme_color_override("font_color", AMARILLO if elegida else Color.WHITE)


func _activar(opcion: int) -> void:
	_elegida = opcion
	_marcar()
	_voz.play()
	match opcion:
		0:
			_jugar()
		1:
			_abrir(Pantalla.CONTROLES)
		2:
			_abrir(Pantalla.CREDITOS)
		3:
			get_tree().quit()


func _abrir(pantalla: Pantalla) -> void:
	_pantalla = pantalla
	_menu.visible = false
	_subpantalla.visible = true
	_controles.visible = pantalla == Pantalla.CONTROLES
	_creditos.visible = pantalla == Pantalla.CREDITOS
	if pantalla == Pantalla.CREDITOS:
		if _creditos_texto.text == "":
			_creditos_texto.text = _leer_creditos()
		_creditos.scroll_vertical = 0


func _volver() -> void:
	_pantalla = Pantalla.MENU
	_menu.visible = true
	_subpantalla.visible = false


func _jugar() -> void:
	_pantalla = Pantalla.CARGANDO
	_menu.visible = false
	_cargando.visible = true
	ResourceLoader.load_threaded_request(MAPA)


# Armar el mapa al entrar traba unos segundos: "Cargando..." ya se dibujo para entonces
func _seguir_cargando() -> void:
	match ResourceLoader.load_threaded_get_status(MAPA):
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			var escena := ResourceLoader.load_threaded_get(MAPA) as PackedScene
			await get_tree().process_frame
			get_tree().change_scene_to_packed(escena)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Inicio: no se pudo cargar %s" % MAPA)
			_cargando.visible = false
			_volver()


# Quita lo de Markdown; en un juego exportado hay que incluir CREDITS.md en el filtro
func _leer_creditos() -> String:
	var texto := FileAccess.get_file_as_string(CREDITOS)
	if texto == "":
		return CREDITOS_MINIMOS
	var enlaces := RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
	texto = enlaces.sub(texto, "$1", true).replace("`", "").replace("**", "").replace("*", "")
	var lineas := PackedStringArray()
	for linea in texto.split("\n"):
		if linea.begins_with("#"):
			lineas.append(linea.lstrip("# ").to_upper())
		elif linea.begins_with("- "):
			lineas.append("· " + linea.substr(2))
		else:
			lineas.append(linea)
	return "\n".join(lineas)


# --- La escenita ---

func _escena() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.09, 0.1, 0.16)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.42, 0.48, 0.66)
	entorno.ambient_light_energy = 0.55
	entorno.fog_enabled = true
	entorno.fog_light_color = Color(0.13, 0.15, 0.22)
	entorno.fog_density = 0.05
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)

	_camara = Camera3D.new()
	_camara.fov = 55.0
	add_child(_camara)
	_camara.position = CAMARA_CENTRO
	_camara.look_at(MIRA)
	_camara.make_current()

	_caja(Vector3(60.0, 0.2, 60.0), Vector3(0.0, -0.1, 0.0), Color(0.3, 0.3, 0.33))
	_caja(Vector3(60.0, 0.22, 2.6), Vector3(0.0, -0.09, -4.0), Color(0.48, 0.46, 0.42))
	_caja(Vector3(60.0, 2.6, 0.4), Vector3(0.0, 1.3, -5.5), Color(0.55, 0.52, 0.47))
	# Poste con su lampara, y la luz sobre el zombi
	_caja(Vector3(0.18, 6.0, 0.18), Vector3(-6.2, 3.0, -3.0), Color(0.5, 0.5, 0.5))
	_caja(Vector3(1.6, 0.12, 0.14), Vector3(-5.5, 6.0, -3.0), Color(0.5, 0.5, 0.5))
	_caja(Vector3(0.5, 0.1, 0.25), Vector3(-4.8, 5.92, -3.0), Color(1.0, 0.85, 0.5))
	var luz := OmniLight3D.new()
	luz.position = Vector3(-2.6, 5.4, -2.0)
	luz.omni_range = 14.0
	luz.light_energy = 2.2
	luz.light_color = Color(1.0, 0.82, 0.55)
	luz.shadow_enabled = false
	add_child(luz)
	# El tinaco, igual al del refugio
	var malla := CylinderMesh.new()
	malla.top_radius = 0.68
	malla.bottom_radius = 0.8
	malla.height = 1.8
	malla.radial_segments = 10
	malla.rings = 1
	var tinaco := MeshInstance3D.new()
	tinaco.mesh = malla
	tinaco.material_override = _material(Color(0.1, 0.1, 0.12))
	tinaco.position = Vector3(3.4, 0.9, -2.6)
	add_child(tinaco)

	var zombi := ZOMBI.instantiate() as Node3D
	zombi.position = Vector3(-0.8, 0.0, -0.6)
	zombi.rotation.y = 0.3
	add_child(zombi)
	for pieza: MeshInstance3D in zombi.find_children("*", "MeshInstance3D", true, false):
		pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# El tubo que el modelo trae flotando
		if String(pieza.name).contains("Tube"):
			pieza.visible = false
	var animacion := zombi.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animacion.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	animacion.play("idle")
	_voz_zombi = AudioStreamPlayer3D.new()
	_voz_zombi.position = zombi.position + Vector3.UP * 1.5
	add_child(_voz_zombi)
	_voz = AudioStreamPlayer.new()
	_voz.stream = Sonidos.sonido("golpe")
	add_child(_voz)


func _caja(medida: Vector3, donde: Vector3, color: Color) -> void:
	var cubo := BoxMesh.new()
	cubo.size = medida
	var caja := MeshInstance3D.new()
	caja.mesh = cubo
	caja.material_override = _material(color)
	caja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caja.position = donde
	add_child(caja)


func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	return material


# Los mismos valores que PS1_Postprocess de map_test.tscn
func _dither() -> void:
	var material := ShaderMaterial.new()
	material.shader = DITHER
	material.set_shader_parameter("color_levels", 32.0)
	material.set_shader_parameter("dither_strenght", 0.35)
	material.set_shader_parameter("desaturacion", 0.4)
	material.set_shader_parameter("tinte", Color(1.0, 0.97, 0.84))
	material.set_shader_parameter("contraste", 1.1)
	material.set_shader_parameter("vineta", 0.3)
	var rect := ColorRect.new()
	rect.material = material
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var capa := CanvasLayer.new()
	capa.layer = 1
	capa.add_child(rect)
	add_child(capa)


# --- El menu ---

func _interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 2
	add_child(capa)
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_menu)
	var titulo := _texto(TITULO, 44, AMARILLO)
	titulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	titulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titulo.offset_top = 36.0
	_menu.add_child(titulo)
	var subtitulo := _texto(SUBTITULO, 18, Color.WHITE)
	subtitulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitulo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitulo.offset_top = 96.0
	_menu.add_child(subtitulo)
	var columna := VBoxContainer.new()
	columna.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	columna.grow_horizontal = Control.GROW_DIRECTION_BOTH
	columna.grow_vertical = Control.GROW_DIRECTION_BEGIN
	columna.offset_bottom = -44.0
	columna.add_theme_constant_override("separation", 4)
	_menu.add_child(columna)
	for i in OPCIONES.size():
		var opcion := _texto(OPCIONES[i], 22, Color.WHITE)
		opcion.custom_minimum_size.x = 200.0
		opcion.mouse_filter = Control.MOUSE_FILTER_STOP
		opcion.mouse_entered.connect(func() -> void:
			_elegida = i
			_marcar())
		opcion.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_activar(i))
		columna.add_child(opcion)
		_opciones.append(opcion)
	var firma := _texto(FIRMA, 11, Color(0.8, 0.8, 0.8))
	firma.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	firma.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	firma.grow_vertical = Control.GROW_DIRECTION_BEGIN
	firma.offset_right = -8.0
	firma.offset_bottom = -6.0
	_menu.add_child(firma)

	_subpantalla = ColorRect.new()
	(_subpantalla as ColorRect).color = Color(0.0, 0.0, 0.0, 0.82)
	_subpantalla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subpantalla.visible = false
	capa.add_child(_subpantalla)
	var volver := _texto(TEXTO_VOLVER, 14, AMARILLO)
	volver.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	volver.grow_horizontal = Control.GROW_DIRECTION_BOTH
	volver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	volver.offset_bottom = -10.0
	volver.mouse_filter = Control.MOUSE_FILTER_STOP
	volver.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_volver())
	_subpantalla.add_child(volver)
	var controles := _texto(TEXTO_CONTROLES, 15, Color.WHITE)
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	controles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controles.offset_left = 40.0
	controles.offset_right = -40.0
	controles.offset_top = 40.0
	controles.offset_bottom = -40.0
	_controles = controles
	_subpantalla.add_child(_controles)
	_creditos = ScrollContainer.new()
	_creditos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_creditos.offset_left = 20.0
	_creditos.offset_right = -20.0
	_creditos.offset_top = 16.0
	_creditos.offset_bottom = -36.0
	_creditos.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_subpantalla.add_child(_creditos)
	_creditos_texto = _texto("", 12, Color.WHITE)
	_creditos_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_creditos_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creditos_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creditos.add_child(_creditos_texto)

	_cargando = _texto(TEXTO_CARGANDO, 24, AMARILLO)
	_cargando.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cargando.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cargando.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cargando.visible = false
	capa.add_child(_cargando)


func _texto(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label
