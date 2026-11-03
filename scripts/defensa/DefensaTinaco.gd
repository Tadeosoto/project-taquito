extends Node3D

# Escena de prueba de la defensa del tinaco ("Vela del tinaco", docs/misiones.md §0):
# una noche de 6 min (22:00 a 6:00) en el Parque Jardin Imperial (Parques del Mosco)
# del mapa real. Las hordas (Hordas.gd) salen de las orillas y corren al tinaco; al
# amanecer se cobra. Si lo rompen se corta a negro, amanece y no se paga nada: con
# media paga convenia entrar y dejarse perder. Por ahora es una escena sola: la flecha
# amarilla en el mapa, la zona al azar por colonia y el regreso van despues.
#
#   godot --path . scenes/defensa_tinaco.tscn [-- --semilla=N]
#   godot --path . scenes/defensa_tinaco.tscn -- --capturas=<carpeta> [--semilla=N]
#
# El mapa se arma con los mismos sistemas de map_test alrededor del nodo Centro, con
# radios chicos; los negocios salen cerrados (sin flecha). La barricada se genera hasta
# que cargo lo de alrededor, porque se brinca lo que choca con casas y bardas. La noche
# no corre mientras. G arma otra barricada (para probar); la semilla sale en la consola.
# Con --capturas pone la camara en VISTAS, guarda un PNG de cada una y se sale.

const MapAlumbrado := preload("res://scripts/map/MapAlumbrado.gd")
const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")

const CENTRO := Vector3(163.0, 0.0, -515.0)
const LADO := 50.0                     # medio lado de donde se puede andar
const JUGADOR_SALE := Vector3(2.5, 1.2, 2.5)   # junto al tinaco (Barricada.JUGADOR_SALE)
const PARED_CAPA := 16                 # capa 5: solo la tiene el jugador en su mascara
const PARED_ALTO := 20.0
# Los negocios de alrededor, cerrados: MapPuntos lee este archivo (antes de su _ready)
const PUNTOS_JSON := "user://puntos_defensa.json"
const PUNTOS_RADIO := 150.0
# Esperar al mapa: hasta que CargaCuadro pase MAPA_QUIETO cuadros seguidos sin armar nada
const MAPA_QUIETO := 20
const MAPA_MAXIMO := 10.0              # s
# La paga (docs/misiones.md: 150, 200 o 250 segun la zona; aqui la baja)
const PAGA := 150
const GALON := preload("res://resources/productos/galon_agua.tres")
const FIN_ESPERA := 2.5                # s de amanecer antes de la pantalla final
const FUNDIDO := 0.8                   # s a negro y de regreso cuando rompen el tinaco

# [nombre, desde, hacia], respecto al tinaco
const VISTAS := [
	["cenital", Vector3(0.0, 60.0, 0.1), Vector3.ZERO],
	["sureste", Vector3(21.0, 8.0, 21.0), Vector3(0.0, 0.5, 0.0)],
	["ras_norte", Vector3(0.0, 2.0, -24.0), Vector3(0.0, 0.8, 0.0)],
	["ras_este", Vector3(24.0, 2.0, 0.0), Vector3(0.0, 0.8, 0.0)],
	["ras_sur", Vector3(0.0, 2.0, 24.0), Vector3(0.0, 0.8, 0.0)],
	["ras_oeste", Vector3(-24.0, 2.0, 0.0), Vector3(0.0, 0.8, 0.0)],
	["desde_tinaco", Vector3(1.5, 2.2, 1.5), Vector3(9.0, 1.0, 12.0)],
	["noche", Vector3(21.0, 8.0, 21.0), Vector3(0.0, 0.5, 0.0)],
]
const LUZ_REVISION := 1.5   # luz sin niebla para revisar el acomodo (todas menos "noche")

# Minimapa: el PNG del mapa real (tools/map_import/make_minimapa.py) recortado alrededor,
# al doble, con la barricada, los tambos y el tinaco encima y oscuro fuera de las paredes
const MINIMAPA := "res://textures/map/minimapa.png"
const MINIMAPA_DATOS := "res://resources/map/minimapa.json"
const MAPA_LADO := 60.0
const MAPA_M_POR_PIXEL := 0.5
const MAPA_BARRICADA := Color(0.8, 0.76, 0.64)
const MAPA_TINACO := Color(0.35, 0.6, 1.0)
const MAPA_TAMBO := Color(1.0, 0.55, 0.15)
const MAPA_AFUERA := 0.45

const AMARILLO := Color(1.0, 0.85, 0.1)
const AGUA := Color(0.35, 0.6, 1.0)

@onready var _barricada := $Barricada as Barricada
@onready var _minimapa := $Minimapa
@onready var _ciclo := $Ciclo as Ciclo
@onready var _zombis := $Zombis as Zombis
@onready var _supervivencia := $Supervivencia
@onready var _jugador := $Player as Player
var _tinaco: TinacoDefensa
var _hordas: Hordas
var _hora: Label
var _amanecer: ColorRect
var _vida_tinaco: ColorRect
var _listo := false
var _terminado := false


func _enter_tree() -> void:
	# Antes del _ready de Puntos
	var todos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/map/puntos_mapa.json"))
	var cerca := []
	for punto: Dictionary in todos["puntos"]:
		if Vector2(punto["x"] - CENTRO.x, punto["z"] - CENTRO.z).length() <= PUNTOS_RADIO:
			punto["interactivo"] = false
			cerca.append(punto)
	var archivo := FileAccess.open(PUNTOS_JSON, FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"puntos": cerca}))
	archivo.close()


func _ready() -> void:
	_tinaco = _barricada.get_node("Tinaco") as TinacoDefensa
	# La noche no corre hasta que este la barricada
	_ciclo.process_mode = Node.PROCESS_MODE_DISABLED
	_jugador.collision_mask |= PARED_CAPA
	_armar_paredes()
	_armar_hud()
	_hordas = Hordas.new()
	_hordas.name = "Hordas"
	_hordas.centro = CENTRO
	_hordas.zombis = _zombis
	_hordas.ciclo = _ciclo
	_hordas.supervivencia = _supervivencia
	add_child(_hordas)
	_tinaco.aviso.connect(_supervivencia.avisar)
	_tinaco.cayo.connect(_tinaco_roto)
	_ciclo.amanecio.connect(_fin)
	var semilla := 0
	var capturas := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--semilla="):
			semilla = int(arg.trim_prefix("--semilla="))
		elif arg.begins_with("--capturas="):
			capturas = arg.trim_prefix("--capturas=")
	await _esperar_mapa()
	_al_suelo()
	_generar(semilla)
	_listo = true
	if capturas != "":
		_capturas(capturas)
		return
	_ciclo.process_mode = Node.PROCESS_MODE_INHERIT


func _unhandled_input(event: InputEvent) -> void:
	if _listo and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		_generar(0)


func _process(_delta: float) -> void:
	if not _listo:
		_hora.text = "Cargando..."
		return
	var hora := _hordas.hora() if _ciclo.es_noche() or _terminado else Hordas.HORA_EMPIEZA
	_hora.text = Hordas.texto_hora(hora)
	_amanecer.scale.x = (hora - Hordas.HORA_EMPIEZA) / Hordas.HORAS
	_vida_tinaco.scale.x = _tinaco.fraccion()


# Lo de alrededor ya cargo: CargaCuadro lleva un rato sin que nadie arme nada
func _esperar_mapa() -> void:
	var quieto := 0
	var desde := Time.get_ticks_msec()
	await get_tree().physics_frame
	while quieto < MAPA_QUIETO and Time.get_ticks_msec() - desde < MAPA_MAXIMO * 1000.0:
		await get_tree().process_frame
		var armo := CargaCuadro._cuadro == Engine.get_process_frames() - 1 and CargaCuadro._usado > 0
		quieto = 0 if armo else quieto + 1
	await get_tree().physics_frame


# El tinaco y el jugador a la altura del suelo del parque
func _al_suelo() -> void:
	var rayo := PhysicsRayQueryParameters3D.create(CENTRO + Vector3.UP * 5.0, CENTRO + Vector3.DOWN * 5.0, 1, [_jugador.get_rid(), _tinaco.get_rid()])
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	if pego:
		_barricada.global_position = pego.position
	_jugador.global_position = _barricada.global_position + JUGADOR_SALE
	_supervivencia.punto_regreso = _jugador.global_transform


func _generar(semilla: int) -> void:
	_barricada.generar(semilla)
	_zombis.olvidar_paredes()
	_minimapa.usar_mapa(_dibujar_mapa(), Vector2(CENTRO.x - MAPA_LADO, CENTRO.z - MAPA_LADO), Vector2.ONE * MAPA_LADO * 2.0)
	print("Barricada: semilla %d, %d piezas no cupieron" % [_barricada.semilla_usada, _barricada.quitadas])


# --- Al amanecer: la paga ---

# Se acabo: a negro y ya es de dia (los zombis se caen y sale la pantalla final)
func _tinaco_roto() -> void:
	_supervivencia.avisar("¡Rompieron el tinaco!")
	var capa := CanvasLayer.new()
	capa.layer = 19
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color(0.0, 0.0, 0.0, 0.0)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(negro)
	var tween := create_tween()
	tween.tween_property(negro, "color:a", 1.0, FUNDIDO)
	await tween.finished
	_ciclo.amanecer_ya(true)
	tween = create_tween()
	tween.tween_interval(FUNDIDO)
	tween.tween_property(negro, "color:a", 0.0, FUNDIDO)
	tween.tween_callback(capa.queue_free)

func _fin() -> void:
	if _terminado:
		return
	_terminado = true
	var entero := _tinaco.vida > 0
	var premio := "$%d" % PAGA
	if entero:
		get_node("/root/Cartera").pesos += PAGA
		if get_node("/root/Inventory").add_item(GALON):
			premio += " y un galón de agua"
		else:
			premio += " (el galón no te cupo)"
	await get_tree().create_timer(FIN_ESPERA).timeout
	_pantalla_final("Aguantaste la noche" if entero else "Rompieron el tinaco",
		"El tinaco amaneció con agua.\nTe pagan %s." % premio if entero else "La colonia se quedó sin agua.\nNo te pagan nada.")


func _pantalla_final(titulo: String, texto: String) -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.75)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 12)
	capa.add_child(caja)
	caja.add_child(_etiqueta(titulo, 28, AMARILLO))
	caja.add_child(_etiqueta(texto, 14, Color.WHITE))
	var otra := Button.new()
	otra.text = "Otra noche"
	otra.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	caja.add_child(otra)
	var salir := Button.new()
	salir.text = "Salir"
	salir.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/inicio.tscn"))
	caja.add_child(salir)
	otra.grab_focus()


# --- Lo de la pantalla ---

func _armar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 3
	add_child(capa)
	_hora = _etiqueta("", 20, Color.WHITE)
	_hora.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hora.position = Vector2(10.0, 6.0)
	capa.add_child(_hora)
	_amanecer = _barra(capa, Vector2(10.0, 34.0), AMARILLO, "amanecer")
	_vida_tinaco = _barra(capa, Vector2(10.0, 52.0), AGUA, "tinaco")


# Una barra de 110 px que se llena con scale.x, con su nombre al lado
func _barra(capa: CanvasLayer, donde: Vector2, color: Color, nombre: String) -> ColorRect:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.position = donde - Vector2.ONE
	fondo.size = Vector2(112.0, 8.0)
	capa.add_child(fondo)
	var barra := ColorRect.new()
	barra.color = color
	barra.position = donde
	barra.size = Vector2(110.0, 6.0)
	capa.add_child(barra)
	var etiqueta := _etiqueta(nombre, 10, color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.position = donde + Vector2(118.0, -6.0)
	capa.add_child(etiqueta)
	return barra


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_shadow_color", Color.BLACK)
	return etiqueta


# Paredes invisibles en la orilla, solo para el jugador: los zombis salen adentro
func _armar_paredes() -> void:
	var paredes := StaticBody3D.new()
	paredes.name = "Paredes"
	paredes.collision_layer = PARED_CAPA
	paredes.collision_mask = 0
	add_child(paredes)
	for i in 4:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(LADO * 2.0 + 2.0, PARED_ALTO, 1.0)
		forma.shape = caja
		var hacia := Vector3(sin(i * PI / 2.0), 0.0, -cos(i * PI / 2.0))
		forma.transform = Transform3D(Basis(Vector3.UP, i * PI / 2.0), CENTRO + hacia * (LADO + 0.5) + Vector3.UP * PARED_ALTO / 4.0)
		paredes.add_child(forma)


# --- Minimapa ---

func _dibujar_mapa() -> ImageTexture:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MINIMAPA_DATOS))
	var por_pixel: float = datos["metros_por_pixel"]
	var completo := (load(MINIMAPA) as Texture2D).get_image()
	completo.decompress()
	var lado := int(MAPA_LADO * 2.0 / por_pixel)
	var desde := Vector2i(int((CENTRO.x - MAPA_LADO - datos["x0"]) / por_pixel), int((CENTRO.z - MAPA_LADO - datos["z0"]) / por_pixel))
	var imagen := completo.get_region(Rect2i(desde, Vector2i(lado, lado)))
	imagen.convert(Image.FORMAT_RGB8)
	var final := int(MAPA_LADO * 2.0 / MAPA_M_POR_PIXEL)
	imagen.resize(final, final, Image.INTERPOLATE_NEAREST)
	# Fuera de las paredes, oscuro
	var adentro := _pixel(Vector3(CENTRO.x - LADO, 0.0, CENTRO.z - LADO))
	var hasta := _pixel(Vector3(CENTRO.x + LADO, 0.0, CENTRO.z + LADO))
	for px in final:
		for pz in final:
			if px < adentro.x or pz < adentro.y or px >= hasta.x or pz >= hasta.y:
				imagen.set_pixel(px, pz, imagen.get_pixel(px, pz).darkened(MAPA_AFUERA))
	var base := _barricada.global_transform
	for huella: Array in _barricada.huellas:
		_pintar_caja(imagen, base * huella[0], huella[1], MAPA_BARRICADA)
	for tambo in _barricada.tambos:
		_pintar_circulo(imagen, base * tambo.origin, MapAlumbrado.TAMBO_RADIO + 0.2, MAPA_TAMBO)
	_pintar_circulo(imagen, _tinaco.global_position, _tinaco.radio, MAPA_TINACO)
	return ImageTexture.create_from_image(imagen)


# Del mundo al pixel del minimapa: columna = x, fila = z, desde la esquina de menor valor
func _pixel(mundo: Vector3) -> Vector2i:
	return Vector2i(int((mundo.x - CENTRO.x + MAPA_LADO) / MAPA_M_POR_PIXEL), int((mundo.z - CENTRO.z + MAPA_LADO) / MAPA_M_POR_PIXEL))


func _mundo(px: int, pz: int) -> Vector3:
	return Vector3(CENTRO.x - MAPA_LADO + (px + 0.5) * MAPA_M_POR_PIXEL, 0.0, CENTRO.z - MAPA_LADO + (pz + 0.5) * MAPA_M_POR_PIXEL)


# Solo recorre los pixeles de la caja que la encierra
func _pintar_caja(imagen: Image, lugar: Transform3D, medida: Vector2, color: Color) -> void:
	var inversa := lugar.affine_inverse()
	var alcance := Vector3.ONE * medida.length() / 2.0
	var lado := imagen.get_width()
	var desde := _pixel(lugar.origin - alcance)
	var hasta := _pixel(lugar.origin + alcance)
	for px in range(maxi(0, desde.x), mini(lado, hasta.x + 1)):
		for pz in range(maxi(0, desde.y), mini(lado, hasta.y + 1)):
			var local := inversa * (_mundo(px, pz) + Vector3.UP * lugar.origin.y)
			if absf(local.x) <= medida.x / 2.0 and absf(local.z) <= medida.y / 2.0:
				imagen.set_pixel(px, pz, color)


func _pintar_circulo(imagen: Image, centro: Vector3, radio: float, color: Color) -> void:
	var lado := imagen.get_width()
	var alcance := Vector3.ONE * radio
	var desde := _pixel(centro - alcance)
	var hasta := _pixel(centro + alcance)
	for px in range(maxi(0, desde.x), mini(lado, hasta.x + 1)):
		for pz in range(maxi(0, desde.y), mini(lado, hasta.y + 1)):
			var mundo := _mundo(px, pz)
			if Vector2(mundo.x - centro.x, mundo.z - centro.z).length() <= maxf(radio, MAPA_M_POR_PIXEL):
				imagen.set_pixel(px, pz, color)


# --- Capturas para revisar ---

func _capturas(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	var centro := _barricada.global_position
	var camara := Camera3D.new()
	camara.fov = 60.0
	add_child(camara)
	camara.make_current()
	# Dejar que carguen los modelos y los shaders
	for i in 30:
		await get_tree().process_frame
	var ambiente := (get_node("WorldEnvironment") as WorldEnvironment).environment
	var noche := ambiente.ambient_light_energy
	for vista: Array in VISTAS:
		camara.look_at_from_position(centro + vista[1], centro + vista[2], Vector3.FORWARD if vista[0] == "cenital" else Vector3.UP)
		ambiente.ambient_light_energy = noche if vista[0] == "noche" else LUZ_REVISION
		ambiente.fog_enabled = vista[0] == "noche"
		_jugador.visible = vista[0] != "desde_tinaco"
		for i in 8:
			await get_tree().process_frame
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png(carpeta.path_join("%s.png" % vista[0]))
	# Y el minimapa solo, para ver la barricada sobre las calles
	var minimapa := _minimapa.mapa as Texture2D
	minimapa.get_image().save_png(carpeta.path_join("minimapa.png"))
	get_tree().quit()
