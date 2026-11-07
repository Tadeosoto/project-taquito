extends CanvasLayer

# Inventario inspirado en Silent Hill 2, con los colores del juego: en Estado el juego
# pausado (donde estas ahorita) y como andas de vida, la mochila puesta en Equipo, una
# hilera de objetos que se pierde en lo oscuro y solo los comandos que aplican.

# Track whether the player is browsing items, inspecting one closely, or choosing
# the second item of a combination
enum InventoryState {
	NAVIGATING,
	INSPECTING,
	COMBINING,
	MAPA,
	HABILIDADES,   # la pagina de habilidades (HabilidadesUI.gd), con H / Y
	REVELANDO,     # abriendo una bolsa especial (TazoRevelacion.gd): sus teclas son de ella
	ALBUM,         # el album de tazos (AlbumTazos.gd), con T / LB
	TILICHES,        # los materiales del taller (TilichesUI.gd), con B / RB
	LIBRETA          # la libreta del Nocturno (LibretaUI.gd), con L / R3
}

enum Comando { EXAMINAR, UTILIZAR, COMBINAR }

const COMANDOS := ["Examinar", "Utilizar", "Combinar"]
const COLOR_ELEGIDO := Color(1, 1, 1)
const COLOR_NORMAL := Color(0.45, 0.45, 0.45)
# Tamano de cada modelo en el marco central y de la mochila en Equipo (m, crear_modelo)
const TAMANO_MODELO := 1.25
const TAMANO_MOCHILA := 0.8
# Lugares de la hilera, del centro hacia un lado: hacia atras se pierden en la niebla negra
const RANURAS := [Vector3(0, 0, 0), Vector3(1.44, 0, -0.6), Vector3(2.9, 0, -1.4), Vector3(4.65, 0, -2.4)]
const ESCALAS := [1.0, 0.55, 0.5, 0.45]
const DESLIZAR := 0.25 # Slide speed curve duration in seconds
const VOLUMEN_SONIDOS := -6.0 # dB de los sonidos del inventario
const SONIDOS := ["inv_abrir", "inv_cerrar", "inv_girar", "inv_examinar", "inv_usar", "inv_combinar",
	"mapa_abrir", "mapa_cerrar", "ui_mover", "ui_aceptar", "ui_cancelar", "ui_error"]
# El numero de una pila (×3)
const AMARILLO_PILA := Color(1.0, 0.85, 0.1)
# Equipo: donde va cada cosa (pantalla de 640 x 480) y que dice si falta
const EQUIPO_CAJAS := {
	"arma": Rect2(232.0, 46.0, 80.0, 54.0),
	"mochila": Rect2(322.0, 46.0, 80.0, 54.0),
	"amuleto0": Rect2(230.0, 130.0, 24.0, 24.0),
	"amuleto1": Rect2(256.0, 130.0, 24.0, 24.0),
	"cangurera": Rect2(380.0, 130.0, 24.0, 24.0),
}
const EQUIPO_VACIO := {"arma": "A puño limpio", "mochila": "Sin mochila"}
const TAMANO_EQUIPO := 0.42       # m de los modelos grandes de Equipo (crear_modelo)
const TAMANO_EQUIPO_CHICO := 0.17 # amuletos y cangurera
const GIRO_ARMA := 0.8            # rad/s que gira el arma en Equipo
const COLOR_EQUIPO := Color(0.85, 0.85, 0.85)
const COLOR_VACIO := Color(0.4, 0.4, 0.42)
const COLOR_MARCO := Color(0.75, 0.62, 0.12)
# Pestanas de abajo: nombre, tecla, boton del control
const PESTANAS := [["Objetos", "Tab", "Start"], ["Tiliches", "B", "RB"], ["Habilidades", "H", "Y"], ["Álbum", "T", "LB"], ["Libreta", "L", "R3"], ["Mapa", "M", "Select"]]
const PESTANAS_Y := 452.0
const MENSAJE_Y := 430.0
# Tinte de la foto de Estado segun la vida (como en Silent Hill 2): color y fuerza en Bien,
# Herido y Grave; entre uno y otro se mezcla. En Grave late
const TINTE_BIEN := Color(0.55, 1.0, 0.5)
const TINTE_HERIDO := Color(1.0, 0.68, 0.15)
const TINTE_GRAVE := Color(1.0, 0.15, 0.1)
const FUERZA_TINTE := [0.18, 0.4, 0.55]   # bien, herido, grave
const LATIDO := 0.15              # cuanto sube y baja la fuerza en Grave
const LATIDO_VEL := 3.0           # rad/s del latido
const SHADER_TINTE := """shader_type canvas_item;
uniform vec4 tinte : source_color = vec4(1.0);
uniform float fuerza = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luz = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(c.rgb, tinte.rgb * (0.3 + luz * 1.4), fuerza), c.a);
}
"""
# Color de la vida en Estado segun Salud.estado()
const COLORES_ESTADO := {
	"Bien": Color(0.75, 1.0, 0.6),
	"Herido": Color(1.0, 0.85, 0.1),
	"Grave": Color(1.0, 0.3, 0.25)
}

# UI elements for text labels and buttons
@onready var item_name_label: Label = $MainPanel/ItemName
@onready var item_description_label: RichTextLabel = $MainPanel/ItemDescription
@onready var inspect_hint_label: Label = $MainPanel/InspecHint
@onready var capacidad_label: Label = $MainPanel/Capacidad
@onready var sin_mochila_label: Label = $MainPanel/SinMochila
@onready var estado_label: Label = $MainPanel/Estado
@onready var foto_estado: TextureRect = $MainPanel/FotoEstado
@onready var mensaje_label: Label = $MainPanel/Mensaje
@onready var comando_labels: Array[Label] = [$MainPanel/ComandoExaminar as Label, $MainPanel/ComandoUtilizar as Label, $MainPanel/ComandoCombinar as Label]
@onready var flechas: Array[Label] = [$MainPanel/FlechaIzquierda as Label, $MainPanel/FlechaDerecha as Label]
@onready var preview_viewport: SubViewport = $MainPanel/PreviewContainer/PreviewViewport
@onready var inspect_viewer: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld
@onready var inventory = Inventory

# --- 3D Position Pivot Points ---
@onready var item_pivot: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/ItemPivot
@onready var preview_camera: Camera3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/PreviewCamera
@onready var equipo_pivot: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/EquipoPivot

# Current navigation parameters
var current_state: InventoryState = InventoryState.NAVIGATING
var current_item_index: int = 0
var comando_actual: int = Comando.EXAMINAR
# Primer objeto de la combinacion, mientras se elige el segundo
var combinar_desde: int = -1
var _mensaje_tween: Tween = null
# Corriendo la escena sola: siempre abierto
var _solo: bool = false
# Sin mapa de papel: M (inventory_map) no lo abre y le queda libre a la escena (en la defensa
# del tinaco prende y apaga la musica)
@export var con_mapa := true

# Un modelo por objeto del inventario, en el mismo orden (null si no tiene modelo)
var modelos: Array[Node3D] = []
var current_model: Node3D = null
var active_tween: Tween = null
# El mapa de papel (MapaUI.gd), encima del panel y abajo del dither
var mapa_ui: Control
# El mapa se abrio con M desde el juego: al cerrarlo se cierra todo el inventario
var _mapa_directo := false
# La pagina de habilidades (Tazos.gd), encima del panel como el mapa
var habilidades_ui: Control
# El album de tazos; `_album_desde` es el estado al que regresa (la lista o las habilidades)
var album_ui: Control
var libreta_ui: Control
var _album_desde := InventoryState.NAVIGATING
# Los tiliches (Tiliches.gd): los materiales del taller
var tiliches_ui: Control
# Equipo y pestanas (_armar_equipo, _armar_pestanas)
var _equipo_cajas := {}           # nombre -> Panel
var _arma_label: Label
var _pips: Control
var _cupo_label: Label
var _pestanas: Control
var _tinte_fuerza := 0.0          # la fuerza sin latido; _process le suma el latido en Grave
var _tinte_t := 0.0

func _ready() -> void:
	mapa_ui = load("res://scripts/MapaUI.gd").new()
	mapa_ui.visible = false
	$MainPanel.add_child(mapa_ui)
	habilidades_ui = load("res://scripts/HabilidadesUI.gd").new()
	habilidades_ui.visible = false
	$MainPanel.add_child(habilidades_ui)
	album_ui = load("res://scripts/AlbumTazos.gd").new()
	album_ui.visible = false
	$MainPanel.add_child(album_ui)
	tiliches_ui = load("res://scripts/TilichesUI.gd").new()
	$MainPanel.add_child(tiliches_ui)
	_armar_equipo()
	_armar_pestanas()
	mensaje_label.position.y = MENSAJE_Y
	var tinte := ShaderMaterial.new()
	tinte.shader = Shader.new()
	tinte.shader.code = SHADER_TINTE
	foto_estado.material = tinte
	libreta_ui = load("res://scripts/LibretaUI.gd").new()
	libreta_ui.visible = false
	$MainPanel.add_child(libreta_ui)
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.nueva_nota.connect(func(_id: String, _n: int) -> void: update_hint())
	# Automatically refresh if items are added or removed globally
	inventory.inventory_changed.connect(refresh_carousel)
	# Mochilero cambia la capacidad, y los puntos el aviso de abajo
	Tazos.cambio.connect(_al_cambiar_tazos)
	Salud.cambio.connect(_actualizar_estado)
	# Se arman al cargar (unos 200 ms) para que abrir la primera vez no se trabe
	for nombre in SONIDOS:
		Sonidos.sonido(nombre)

	_solo = get_parent() == get_tree().root
	visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mensaje_label.modulate.a = 0.0
	_actualizar_estado()
	if _solo:
		abrir()

	# === RETRO HIGHLIGHT FLASH TWEEN ===
	if has_node("MainPanel/HighlightBox"):
		var box = $MainPanel/HighlightBox

		# Create an infinite looping pulse animation
		var pulse_tween = create_tween().set_loops()
		pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Fade the border color alpha channel out and back in smoothly
		pulse_tween.tween_property(box, "modulate:a", 0.3, 0.6)
		pulse_tween.tween_property(box, "modulate:a", 1.0, 0.6)

func _process(delta: float) -> void:
	if not visible:
		return
	var arma := equipo_pivot.get_node_or_null("arma")
	if arma:
		arma.rotation.y += GIRO_ARMA * delta
	# En Grave la foto late
	var fuerza := _tinte_fuerza
	if Salud.estado() == "Grave":
		_tinte_t += delta
		fuerza += LATIDO * (0.5 + 0.5 * sin(_tinte_t * LATIDO_VEL))
	(foto_estado.material as ShaderMaterial).set_shader_parameter("fuerza", fuerza)

func _al_cambiar_tazos() -> void:
	if visible:
		update_hint()

# Abre el inventario y pausa el juego. Esta escena sigue corriendo en pausa
# (process_mode = Always) y el jugador deja de leer las teclas que comparte con el menu.
func abrir(sonar := true) -> void:
	if visible or not _jugador_libre():
		return
	_capturar_foto()
	get_tree().paused = true
	visible = true
	if sonar:
		_sonar("inv_abrir")
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	current_state = InventoryState.NAVIGATING
	comando_actual = Comando.EXAMINAR
	combinar_desde = -1
	inspect_viewer.set_inspection_active(false)
	refresh_carousel()

func cerrar(sonido := "inv_cerrar") -> void:
	if visible:
		_sonar(sonido)
	_mapa_directo = false
	mapa_ui.visible = false
	habilidades_ui.visible = false
	album_ui.cerrar()
	tiliches_ui.cerrar()
	inspect_viewer.set_inspection_active(false)
	current_state = InventoryState.NAVIGATING
	clear_all_models()
	visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_tree().paused = false

# No se abre en una tienda, de cerca con un vendedor ni volando: ahi el jugador esta
# apagado (Interiores.gd, MapDron.gd)
func _jugador_libre() -> bool:
	var jugador := get_tree().get_first_node_in_group("jugador") as Player
	return jugador == null or (jugador.can_process() and jugador.is_physics_processing())

# Estado muestra el juego pausado: lo que se veia al abrir, de ancho para que se note
# donde estas. Se corta abajo del minimapa, que va en la esquina de arriba.
func _capturar_foto() -> void:
	if _solo:
		return
	var imagen := get_viewport().get_texture().get_image()
	if imagen == null or imagen.is_empty():
		return
	var ancho := imagen.get_width()
	var alto := imagen.get_height()
	var recorte := imagen.get_region(Rect2i(ancho / 8, int(alto * 0.31), ancho * 3 / 4, int(alto * 0.66)))
	foto_estado.texture = ImageTexture.create_from_image(recorte)

func _unhandled_input(event: InputEvent) -> void:
	# Abriendo una bolsa: ni Tab cierra; TazoRevelacion avisa al terminar
	if visible and current_state == InventoryState.REVELANDO:
		get_viewport().set_input_as_handled()
		return
	if not con_mapa and event.is_action("inventory_map"):
		return
	if event.is_action_pressed("inventory_toggle"):
		if not visible:
			abrir()
		elif not _solo:
			cerrar()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		# M (o Select) desde el juego abre directo el mapa, aunque no tengas piezas
		if event.is_action_pressed("inventory_map") and _jugador_libre():
			abrir(false)
			if visible:
				_abrir_mapa()
				_mapa_directo = true
			get_viewport().set_input_as_handled()
		return

	if current_state == InventoryState.MAPA:
		if event.is_action_pressed("inventory_back") or event.is_action_pressed("inventory_map"):
			# Abierto desde el juego, cerrarlo regresa al juego y no a la lista
			if _mapa_directo:
				cerrar("mapa_cerrar")
			else:
				_cerrar_mapa()
		elif event.is_action_pressed("inspect_zoom_in"):
			mapa_ui.acercar(1)
		elif event.is_action_pressed("inspect_zoom_out"):
			mapa_ui.acercar(-1)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.NAVIGATING and event.is_action_pressed("inventory_map"):
		_abrir_mapa()
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.TILICHES:
		if event.is_action_pressed("inventory_back") or event.is_action_pressed("inventory_tiliches"):
			tiliches_ui.cerrar()
			_cerrar_habilidades()
		else:
			tiliches_ui.manejar(event)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.NAVIGATING and event.is_action_pressed("inventory_tiliches"):
		get_viewport().set_input_as_handled()
		# Los tiliches van en la cangurera (Tiliches.gd)
		if inventory.cangurera == null:
			_sonar("ui_error")
			_mostrar_mensaje("Sin cangurera no traes tiliches. Te dan una por una misión.")
			return
		_sonar("ui_aceptar")
		current_state = InventoryState.TILICHES
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tiliches_ui.mostrar()
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.ALBUM:
		if event.is_action_pressed("inventory_back") or event.is_action_pressed("inventory_album"):
			_cerrar_album()
		elif event.is_action_pressed("inventory_skills"):
			_cerrar_album(false)
			_abrir_habilidades()
		else:
			album_ui.manejar(event)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.HABILIDADES:
		if event.is_action_pressed("inventory_back") or event.is_action_pressed("inventory_skills"):
			_cerrar_habilidades()
		elif event.is_action_pressed("inventory_album"):
			habilidades_ui.visible = false
			_abrir_album(InventoryState.HABILIDADES)
		else:
			habilidades_ui.manejar(event)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.NAVIGATING and event.is_action_pressed("inventory_skills"):
		_abrir_habilidades()
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.NAVIGATING and event.is_action_pressed("inventory_album"):
		_abrir_album(InventoryState.NAVIGATING)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.LIBRETA:
		if event.is_action_pressed("inventory_back") or event.is_action_pressed("inventory_guide"):
			_cerrar_libreta()
		else:
			libreta_ui.manejar(event)
		get_viewport().set_input_as_handled()
		return
	if current_state == InventoryState.NAVIGATING and event.is_action_pressed("inventory_guide"):
		_abrir_libreta()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("inventory_back"):
		_regresar()
		get_viewport().set_input_as_handled()
		return
	# Ignore navigation controls if we are currently inspecting an object
	if current_state == InventoryState.INSPECTING:
		return

	var item_count: int = inventory.get_item_count()

	# Go to next item (wrap around using modulo %). Disabled with a single item.
	if item_count > 1 and event.is_action_pressed("inventory_next"):
		_cambiar_objeto(1)
		get_viewport().set_input_as_handled()

	# Go to previous item
	elif item_count > 1 and event.is_action_pressed("inventory_previous"):
		_cambiar_objeto(-1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("inventory_confirm"):
		if current_state == InventoryState.COMBINING:
			_terminar_combinacion()
		else:
			_ejecutar_comando()
		get_viewport().set_input_as_handled()

	# Elegir comando
	elif current_state == InventoryState.NAVIGATING:
		if event.is_action_pressed("inspect_up"):
			_mover_comando(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("inspect_down"):
			_mover_comando(1)
			get_viewport().set_input_as_handled()

func _abrir_mapa() -> void:
	_sonar("mapa_abrir")
	current_state = InventoryState.MAPA
	# Lo de atras no se ve: no se dibuja el 3D mientras
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mapa_ui.mostrar()

# Con `id`, la pagina abre con esa habilidad elegida (al venir del show de un tazo)
func _abrir_habilidades(id := "") -> void:
	_sonar("ui_aceptar")
	current_state = InventoryState.HABILIDADES
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	habilidades_ui.mostrar(id)

func _abrir_album(desde: InventoryState) -> void:
	_sonar("ui_aceptar")
	_album_desde = desde
	current_state = InventoryState.ALBUM
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	album_ui.mostrar()

# De regreso a donde se abrio (o a nada, si `regresar` es false: otra pagina toma su lugar)
func _cerrar_album(regresar := true) -> void:
	album_ui.cerrar()
	if not regresar:
		return
	if _album_desde == InventoryState.HABILIDADES:
		current_state = InventoryState.HABILIDADES
		_sonar("ui_cancelar")
		habilidades_ui.mostrar()
	else:
		_cerrar_habilidades()

func _cerrar_habilidades() -> void:
	_sonar("ui_cancelar")
	current_state = InventoryState.NAVIGATING
	habilidades_ui.visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update_hint()

func _abrir_libreta() -> void:
	Sonidos.tocar(self, "lapiz", -8.0)
	current_state = InventoryState.LIBRETA
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	libreta_ui.mostrar()

func _cerrar_libreta() -> void:
	_sonar("ui_cancelar")
	libreta_ui.cerrar()
	current_state = InventoryState.NAVIGATING
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update_hint()

func _cerrar_mapa() -> void:
	_sonar("mapa_cerrar")
	_mapa_directo = false
	current_state = InventoryState.NAVIGATING
	mapa_ui.visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update_hint()

# Un paso atras: de inspeccionar o combinar a la lista; de la lista, cierra
func _regresar() -> void:
	match current_state:
		InventoryState.INSPECTING:
			_sonar("ui_cancelar")
			set_inspection_mode(false)
		InventoryState.COMBINING:
			_sonar("ui_cancelar")
			current_state = InventoryState.NAVIGATING
			combinar_desde = -1
			update_hint()
		_:
			if not _solo:
				cerrar()

# Los comandos que aplican al objeto elegido, en el orden en que se ven
func _comandos_visibles() -> Array[int]:
	var lista: Array[int] = []
	var item: InventoryItemData = inventory.get_item(current_item_index)
	if item == null:
		return lista
	if is_instance_valid(current_model):
		lista.append(Comando.EXAMINAR)
	# Utilizar tambien es Abrir (bolsa), Equipar (arma), Ponerse (amuleto) y Usar (estampita)
	if item.curacion > 0 or item.bolsa_tazo or item.dano > 0 or item.es_amuleto() or item.estampita != "":
		lista.append(Comando.UTILIZAR)
	if inventory.get_item_count() > 1:
		lista.append(Comando.COMBINAR)
	return lista

func _mover_comando(paso: int) -> void:
	var lista := _comandos_visibles()
	if lista.is_empty():
		return
	var antes := comando_actual
	comando_actual = lista[wrapi(lista.find(comando_actual) + paso, 0, lista.size())]
	if comando_actual != antes:
		_sonar("ui_mover")
	update_hint()

func _ejecutar_comando() -> void:
	if not comando_actual in _comandos_visibles():
		_sonar("ui_error")
		_mostrar_mensaje("No se puede.")
		return
	match comando_actual:
		Comando.EXAMINAR:
			_sonar("inv_examinar")
			set_inspection_mode(true)
		Comando.UTILIZAR:
			_utilizar()
		Comando.COMBINAR:
			_sonar("ui_aceptar")
			current_state = InventoryState.COMBINING
			combinar_desde = current_item_index
			update_hint()

# Como se llama "Utilizar" para cada cosa
func _nombre_utilizar(item: InventoryItemData) -> String:
	if item.bolsa_tazo:
		return "Abrir"
	if item.dano > 0:
		return "Quitar" if item == inventory.equipada else "Equipar"
	if item.es_amuleto():
		return "Ponerse"
	if item.estampita != "":
		return "Usar"
	return COMANDOS[Comando.UTILIZAR]


func _utilizar() -> void:
	var item: InventoryItemData = inventory.get_item(current_item_index)
	if item.bolsa_tazo:
		_abrir_bolsa()
		return
	if item.dano > 0:
		_sonar("inv_usar")
		inventory.equipar_arma(item)
		_mostrar_mensaje(("Peleas con: %s." % item.item_name) if inventory.equipada == item else "Peleas con lo mejor que traes.")
		return
	if item.es_amuleto():
		_sonar("inv_usar")
		var antes: Array = Bonos.puestos.duplicate()
		inventory.poner_amuleto(current_item_index)
		var quitado: InventoryItemData = antes[0] if not antes.has(null) else null
		_mostrar_mensaje("Te pusiste: %s.%s" % [item.item_name, ("  Te quitaste: %s." % quitado.item_name) if quitado else ""])
		return
	if item.estampita != "":
		_sonar("inv_usar")
		Bonos.usar_estampita(item.estampita)
		inventory.remove_item(current_item_index)
		_mostrar_mensaje("%s: %s." % [item.item_name, item.efecto])
		return
	# El Milagro del tinaco tambien sirve con la vida llena si ya usaste Segundo aire
	var recarga := item.recarga_segundo_aire and Tazos.segundo_aire_usado
	if Salud.llena() and not recarga:
		_sonar("ui_error")
		_mostrar_mensaje("No lo necesitas ahorita.")
		return
	_sonar("inv_usar")
	var subio: int = inventory.usar_curacion(current_item_index)
	if item.recarga_segundo_aire:
		Tazos.segundo_aire_usado = false
	# La flor de curar a los pies: el juego esta en pausa, se ve al cerrar (EfectosPixel)
	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.has_method("efecto"):
		jugador.efecto("curar", Vector3.ZERO)
	_mostrar_mensaje("%s: +%d de vida." % [item.item_name, subio])

# Una bolsa especial de Takis: se gasta, sale un tazo (Tazos.abrir_bolsa) y su show encima
# del inventario (TazoRevelacion). Al cerrarlo regresas a la lista
func _abrir_bolsa() -> void:
	inventory.remove_item(current_item_index)
	var tazo: TazoData = Tazos.abrir_bolsa()
	if tazo == null:
		return
	current_state = InventoryState.REVELANDO
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var show := TazoRevelacion.abrir(self, tazo, Tazos.es_repetido(tazo), Tazos.ultima_serie)
	await show.termino
	current_state = InventoryState.NAVIGATING
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	refresh_carousel()
	# Cerrado con H: directo a la pagina, con lo que desbloqueo elegido
	if show.ir_a_habilidades:
		_abrir_habilidades(tazo.desbloquea if not Tazos.es_repetido(tazo) else "")
		return
	_mostrar_mensaje(TazoRevelacion.texto_puntos(tazo, Tazos.es_repetido(tazo)) + (": H para gastarlos." if Tazos.ultimos_puntos > 0 else "."))

func _terminar_combinacion() -> void:
	if current_item_index == combinar_desde:
		_sonar("ui_error")
		_mostrar_mensaje("Elige otro objeto.")
		return
	var desde := combinar_desde
	current_state = InventoryState.NAVIGATING
	combinar_desde = -1
	var resultado: InventoryItemData = inventory.combinar(desde, current_item_index)
	if resultado == null:
		_sonar("ui_error")
		update_hint()
		_mostrar_mensaje("Eso no se puede combinar.")
		return
	_sonar("inv_combinar")
	current_item_index = inventory.get_item_count() - 1
	refresh_carousel()
	_mostrar_mensaje("Hiciste: %s." % resultado.item_name)

# Sonidos del inventario (Sonidos.gd): suenan con el juego en pausa
func _sonar(nombre: String) -> void:
	Sonidos.tocar(self, nombre, VOLUMEN_SONIDOS)

func _actualizar_estado() -> void:
	var estado: String = Salud.estado()
	estado_label.text = "%s: %s" % [Personaje.nombre, estado]
	estado_label.add_theme_color_override("font_color", COLORES_ESTADO[estado])
	# El tinte de la foto: verde leve sano, ambar herido, rojo grave, mezclado por la vida
	# (los cortes son los de Salud.estado: 60 % y 25 %)
	var f := clampf(float(Salud.vida) / maxf(Salud.vida_max, 1.0), 0.0, 1.0)
	var color: Color
	if f >= 0.6:
		color = TINTE_BIEN
		_tinte_fuerza = FUERZA_TINTE[0]
	elif f >= 0.25:
		var k := (f - 0.25) / 0.35
		color = TINTE_HERIDO.lerp(TINTE_BIEN, k * k)
		_tinte_fuerza = lerpf(FUERZA_TINTE[1], FUERZA_TINTE[0], k * k)
	else:
		var k := f / 0.25
		color = TINTE_GRAVE.lerp(TINTE_HERIDO, k)
		_tinte_fuerza = lerpf(FUERZA_TINTE[2], FUERZA_TINTE[1], k)
	if foto_estado.material:
		(foto_estado.material as ShaderMaterial).set_shader_parameter("tinte", color)
		(foto_estado.material as ShaderMaterial).set_shader_parameter("fuerza", _tinte_fuerza)

func _mostrar_mensaje(texto: String) -> void:
	if _mensaje_tween and _mensaje_tween.is_valid():
		_mensaje_tween.kill()
	mensaje_label.text = texto
	mensaje_label.modulate.a = 1.0
	_mensaje_tween = create_tween()
	_mensaje_tween.tween_interval(2.0)
	_mensaje_tween.tween_property(mensaje_label, "modulate:a", 0.0, 0.5)

func set_inspection_mode(active: bool) -> void:
	if active:
		current_state = InventoryState.INSPECTING
	else:
		current_state = InventoryState.NAVIGATING
	# Point the inspector at the item currently in the centre slot, then forward
	# the state toggle to the 3D inspection script.
	inspect_viewer.set_active_model(current_model)
	inspect_viewer.set_inspection_active(active)
	# Examinando solo se ve ese objeto
	_colocar_modelos()
	update_hint()

# Rearma todo (al abrir o si cambia lo que traes); para cambiar de objeto, _cambiar_objeto
func refresh_carousel() -> void:
	# Cerrado no se arma nada (recoger cosas no carga modelos); abrir() lo refresca
	if not visible:
		return
	clear_all_models()
	_actualizar_equipo()
	var total: int = inventory.get_item_count()
	if total == 0:
		item_name_label.text = "Sin objetos"
		item_description_label.text = "No hay nada en el inventario."
		inspect_viewer.set_active_model(null)
		update_hint()
		return
	if current_item_index >= total:
		current_item_index = total - 1
	for i in total:
		modelos.append(spawn_item(i))
	_colocar_modelos()
	_elegir_centro()

func _cambiar_objeto(paso: int) -> void:
	_sonar("inv_girar")
	var total: int = inventory.get_item_count()
	var anterior := current_item_index
	current_item_index = wrapi(current_item_index + paso, 0, total)
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in total:
		var modelo := modelos[i]
		if not is_instance_valid(modelo):
			continue
		var antes := _lugar(i, anterior)
		var ahora := _lugar(i, current_item_index)
		# Dio la vuelta: en vez de cruzar la pantalla, entra por el otro lado
		if absi(ahora - antes) > 1:
			modelo.position = _posicion(ahora + paso)
			modelo.scale = Vector3.ONE * 0.01
		modelo.visible = absi(antes) < RANURAS.size() or absi(ahora) < RANURAS.size()
		active_tween.tween_property(modelo, "position", _posicion(ahora), DESLIZAR)
		active_tween.tween_property(modelo, "scale", Vector3.ONE * _escala(ahora), DESLIZAR)
		if absi(ahora) >= RANURAS.size():
			active_tween.tween_callback(modelo.hide).set_delay(DESLIZAR)
	_elegir_centro()

# Pone cada modelo en su lugar de una vez
func _colocar_modelos() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	for i in modelos.size():
		var modelo := modelos[i]
		if not is_instance_valid(modelo):
			continue
		var lugar := _lugar(i, current_item_index)
		modelo.position = _posicion(lugar)
		modelo.scale = Vector3.ONE * _escala(lugar)
		modelo.visible = absi(lugar) < RANURAS.size() and (lugar == 0 or current_state != InventoryState.INSPECTING)

# Cuantos lugares a la derecha (+) o izquierda (-) del centro va el objeto i
func _lugar(i: int, centro: int) -> int:
	var total := modelos.size()
	var lugar := wrapi(i - centro, 0, total)
	return lugar - total if lugar > total / 2 else lugar

func _posicion(lugar: int) -> Vector3:
	var ranura: Vector3 = RANURAS[mini(absi(lugar), RANURAS.size() - 1)]
	return Vector3(ranura.x * signi(lugar), ranura.y, ranura.z)

func _escala(lugar: int) -> float:
	return ESCALAS[mini(absi(lugar), ESCALAS.size() - 1)]

# Actualiza textos y comandos para el objeto del centro
func _elegir_centro() -> void:
	var selected_item: InventoryItemData = inventory.get_item(current_item_index)
	if selected_item == null:
		return
	# Update label text fields instantly
	var n: int = inventory.cantidad(current_item_index)
	item_name_label.text = selected_item.item_name + (" ×%d" % n if n > 1 else "")
	item_description_label.text = ("[Equipada] " if selected_item == inventory.equipada else "") + selected_item.description
	# Lo del taller dice que hace (armas, amuletos, estampitas)
	if selected_item.efecto != "" and (selected_item.dano > 0 or selected_item.es_amuleto() or selected_item.estampita != ""):
		item_description_label.text += "\n" + selected_item.efecto
	current_model = modelos[current_item_index]
	# The centre model may have changed; keep the inspector in sync.
	inspect_viewer.set_active_model(current_model)
	if current_state == InventoryState.NAVIGATING and not comando_actual in _comandos_visibles():
		var lista := _comandos_visibles()
		comando_actual = lista[0] if not lista.is_empty() else Comando.EXAMINAR
	update_hint()

# Equipo: el arma con que peleas (gira), la mochila con sus lugares en cuadritos, los dos
# amuletos puestos (Bonos.gd) y la cangurera (los tiliches). Cada cosa es su modelo en el
# mundo del preview, dentro de un marco 2D; vacio, el marco se apaga y dice que falta
func _actualizar_equipo() -> void:
	for hijo in equipo_pivot.get_children():
		hijo.queue_free()
	var arma: InventoryItemData = inventory.arma()
	_poner_equipo("arma", arma, TAMANO_EQUIPO)
	_poner_equipo("mochila", inventory.mochila, TAMANO_EQUIPO)
	for i in Bonos.puestos.size():
		_poner_equipo("amuleto%d" % i, Bonos.puestos[i], TAMANO_EQUIPO_CHICO)
	_poner_equipo("cangurera", inventory.cangurera, TAMANO_EQUIPO_CHICO)
	_arma_label.text = "%s · %d" % [arma.item_name, arma.dano] if arma else "Sin arma"
	_arma_label.add_theme_color_override("font_color", COLOR_EQUIPO if arma else COLOR_VACIO)
	# Un cuadrito por lugar: llenos los que ocupas
	var cupo: int = inventory.capacidad()
	var usados: int = inventory.get_item_count()
	for hijo in _pips.get_children():
		hijo.queue_free()
	var caja: Rect2 = EQUIPO_CAJAS["mochila"]
	var ancho := minf(8.0, (caja.size.x - (cupo - 1)) / maxf(cupo, 1))
	for i in cupo:
		var pip := ColorRect.new()
		pip.color = COLOR_EQUIPO if i < usados else COLOR_VACIO.darkened(0.4)
		pip.position = Vector2(i * (ancho + 1.0), 0.0)
		pip.size = Vector2(ancho, 5.0)
		_pips.add_child(pip)
	_pips.position = Vector2(caja.position.x + (caja.size.x - cupo * (ancho + 1.0) + 1.0) / 2.0, caja.end.y + 4.0)
	_cupo_label.text = "%d / %d" % [usados, cupo]
	_cupo_label.add_theme_color_override("font_color", AMARILLO_PILA if usados >= cupo else COLOR_EQUIPO)


func _poner_equipo(nombre: String, item: InventoryItemData, tamano: float) -> void:
	var caja: Panel = _equipo_cajas[nombre]
	var estilo := caja.get_theme_stylebox("panel") as StyleBoxFlat
	estilo.border_color = COLOR_MARCO if item else COLOR_VACIO.darkened(0.5)
	var vacio: Label = caja.get_meta("vacio") if caja.has_meta("vacio") else null
	if vacio:
		vacio.visible = item == null
	if item == null:
		return
	var modelo := item.crear_modelo(tamano)
	if modelo == null:
		return
	var lugar := Node3D.new()
	lugar.name = nombre
	var rect: Rect2 = EQUIPO_CAJAS[nombre]
	lugar.position = preview_camera.project_position(rect.get_center(), preview_camera.position.z)
	lugar.rotation.y = deg_to_rad(25.0)
	lugar.add_child(modelo)
	equipo_pivot.add_child(lugar)


# Los marcos de Equipo y sus letreros (una vez, en _ready)
func _armar_equipo() -> void:
	equipo_pivot.transform = Transform3D.IDENTITY
	# Todo en una capa debajo de las paginas (mapa, habilidades, album, tiliches), que la tapan
	var capa := Control.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MainPanel.add_child(capa)
	$MainPanel.move_child(capa, mapa_ui.get_index())
	sin_mochila_label.visible = false
	capacidad_label.visible = false
	for nombre: String in EQUIPO_CAJAS:
		var rect: Rect2 = EQUIPO_CAJAS[nombre]
		var caja := Panel.new()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0, 0, 0, 0)
		estilo.set_border_width_all(1)
		caja.add_theme_stylebox_override("panel", estilo)
		caja.position = rect.position
		caja.size = rect.size
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if EQUIPO_VACIO.has(nombre):
			var vacio := _label_equipo(EQUIPO_VACIO[nombre], 10, COLOR_VACIO)
			vacio.size = rect.size
			vacio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caja.add_child(vacio)
			caja.set_meta("vacio", vacio)
		capa.add_child(caja)
		_equipo_cajas[nombre] = caja
	var arma: Rect2 = EQUIPO_CAJAS["arma"]
	_arma_label = _label_equipo("", 10, COLOR_EQUIPO)
	_arma_label.position = Vector2(arma.position.x - 6.0, arma.end.y + 1.0)
	_arma_label.size = Vector2(arma.size.x + 12.0, 14.0)
	_arma_label.clip_text = true
	capa.add_child(_arma_label)
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_pips)
	var mochila: Rect2 = EQUIPO_CAJAS["mochila"]
	_cupo_label = _label_equipo("", 10, COLOR_EQUIPO)
	_cupo_label.position = Vector2(mochila.position.x, mochila.end.y + 10.0)
	_cupo_label.size = Vector2(mochila.size.x, 14.0)
	capa.add_child(_cupo_label)
	var amuletos := _label_equipo("Amuletos", 9, COLOR_VACIO)
	amuletos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amuletos.position = Vector2(EQUIPO_CAJAS["amuleto1"].end.x + 3.0, EQUIPO_CAJAS["amuleto1"].position.y + 6.0)
	capa.add_child(amuletos)
	var cangurera := _label_equipo("Cangurera", 9, COLOR_VACIO)
	cangurera.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Pegado a su marco por la izquierda, midiendo el texto
	var ancho_texto := cangurera.get_theme_font("font").get_string_size(cangurera.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	cangurera.position = Vector2(EQUIPO_CAJAS["cangurera"].position.x - 4.0 - ancho_texto, EQUIPO_CAJAS["cangurera"].position.y + 6.0)
	capa.add_child(cangurera)


func _label_equipo(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Pestanas de abajo: a que otras paginas llegas y con que tecla ---

func _armar_pestanas() -> void:
	_pestanas = Control.new()
	_pestanas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pestanas.position = Vector2(30.0, PESTANAS_Y)
	$MainPanel.add_child(_pestanas)
	# Debajo de las paginas (mapa, habilidades, album, tiliches): ellas la tapan al abrirse
	$MainPanel.move_child(_pestanas, mapa_ui.get_index())
	var ancho := 580.0 / PESTANAS.size()
	for i in PESTANAS.size():
		var nombre := _label_equipo(PESTANAS[i][0], 12, COLOR_NORMAL)
		nombre.position = Vector2(i * ancho, 0.0)
		nombre.size = Vector2(ancho, 14.0)
		_pestanas.add_child(nombre)
		var tecla := _label_equipo("", 9, COLOR_VACIO)
		tecla.position = Vector2(i * ancho, 14.0)
		tecla.size = Vector2(ancho, 12.0)
		_pestanas.add_child(tecla)
	var raya := ColorRect.new()
	raya.color = AMARILLO_PILA
	raya.size = Vector2(ancho * 0.5, 1.0)
	raya.position = Vector2(ancho * 0.25, -2.0)
	_pestanas.add_child(raya)


func _actualizar_pestanas() -> void:
	if _pestanas == null:
		return
	var control := not Input.get_connected_joypads().is_empty()
	var libres: int = Tazos.libres()
	for i in PESTANAS.size():
		var nombre := _pestanas.get_child(i * 2) as Label
		var tecla := _pestanas.get_child(i * 2 + 1) as Label
		tecla.text = PESTANAS[i][2] if control else PESTANAS[i][1]
		var color := COLOR_NORMAL
		nombre.text = PESTANAS[i][0]
		match i:
			0:
				color = AMARILLO_PILA
			1:
				if inventory.cangurera == null:
					color = COLOR_VACIO.darkened(0.4)
					tecla.text = "sin cangurera"
			2:
				if libres > 0:
					nombre.text += " ¡%d!" % libres
					color = AMARILLO_PILA
			4:
				# Notas sin leer en la libreta del Nocturno (Libreta.gd)
				var libreta := get_node_or_null("/root/Libreta")
				if libreta and libreta.hay_sin_leer():
					nombre.text += " !"
					color = AMARILLO_PILA
		nombre.add_theme_color_override("font_color", color)


# Factory utility to instantiate and mount item scene resources cleanly
func spawn_item(index: int) -> Node3D:
	var item_data: InventoryItemData = inventory.get_item(index)
	if item_data == null:
		return null
	var model_node := item_data.crear_modelo(TAMANO_MODELO)
	if model_node:
		item_pivot.add_child(model_node)
		# Una pila lleva su cuantos abajo a la derecha, tambien en la hilera
		var n: int = inventory.cantidad(index)
		if n > 1:
			var cuenta := Label3D.new()
			cuenta.text = "×%d" % n
			cuenta.font_size = 48
			cuenta.pixel_size = 0.006
			cuenta.outline_size = 12
			cuenta.modulate = AMARILLO_PILA
			cuenta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			cuenta.no_depth_test = true
			cuenta.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			cuenta.position = Vector3(TAMANO_MODELO * 0.42, -TAMANO_MODELO * 0.42, 0.2)
			model_node.add_child(cuenta)
	return model_node

# Deletes all currently loaded carousel model assets out of engine view completely
func clear_all_models() -> void:
	# Stop any in-flight slide so its callbacks cannot touch freed nodes.
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	for child in item_pivot.get_children():
		child.queue_free()
	for child in equipo_pivot.get_children():
		child.queue_free()
	modelos.clear()
	current_model = null

# Modifies instructional footer texts based on what menu state is active
func update_hint() -> void:
	_actualizar_comandos()
	_actualizar_pestanas()
	var se_navega: bool = inventory.get_item_count() > 1 and current_state != InventoryState.INSPECTING
	for flecha in flechas:
		flecha.visible = se_navega
	match current_state:
		InventoryState.INSPECTING:
			inspect_hint_label.text = "Flechas: Rotar  Esc: Regresar"
		InventoryState.COMBINING:
			var primero: InventoryItemData = inventory.get_item(combinar_desde)
			inspect_hint_label.text = "%s con... (Enter / Esc)" % primero.item_name
		_:
			# Las otras paginas y los puntos sin gastar van en las pestanas de abajo
			inspect_hint_label.text = ""

# Solo se ven los comandos que aplican; el elegido en blanco
func _actualizar_comandos() -> void:
	var lista := _comandos_visibles()
	for i in comando_labels.size():
		var label := comando_labels[i]
		label.visible = i < lista.size()
		if label.visible:
			label.text = COMANDOS[lista[i]]
			# Una bolsa especial no se "utiliza": se abre
			var item: InventoryItemData = inventory.get_item(current_item_index)
			if lista[i] == Comando.UTILIZAR and item:
				label.text = _nombre_utilizar(item)
			var elegido: bool = lista[i] == comando_actual and current_state == InventoryState.NAVIGATING
			label.add_theme_color_override("font_color", COLOR_ELEGIDO if elegido else COLOR_NORMAL)
