extends CanvasLayer

# Inventario inspirado en Silent Hill 2, con los colores del juego: en Estado el juego
# pausado (donde estas ahorita) y como andas de vida, la mochila puesta en Equipo, una
# hilera de objetos que se pierde en lo oscuro y solo los comandos que aplican.

# Track whether the player is browsing items, inspecting one closely, or choosing
# the second item of a combination
enum InventoryState {
	NAVIGATING,
	INSPECTING,
	COMBINING
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

# Un modelo por objeto del inventario, en el mismo orden (null si no tiene modelo)
var modelos: Array[Node3D] = []
var current_model: Node3D = null
var active_tween: Tween = null

func _ready() -> void:
	# Automatically refresh if items are added or removed globally
	inventory.inventory_changed.connect(refresh_carousel)
	Salud.cambio.connect(_actualizar_estado)

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

# Abre el inventario y pausa el juego. Esta escena sigue corriendo en pausa
# (process_mode = Always) y el jugador deja de leer las teclas que comparte con el menu.
func abrir() -> void:
	if visible or not _jugador_libre():
		return
	_capturar_foto()
	get_tree().paused = true
	visible = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	current_state = InventoryState.NAVIGATING
	comando_actual = Comando.EXAMINAR
	combinar_desde = -1
	inspect_viewer.set_inspection_active(false)
	refresh_carousel()

func cerrar() -> void:
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
	if event.is_action_pressed("inventory_toggle"):
		if not visible:
			abrir()
		elif not _solo:
			cerrar()
		get_viewport().set_input_as_handled()
		return
	if not visible:
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

# Un paso atras: de inspeccionar o combinar a la lista; de la lista, cierra
func _regresar() -> void:
	match current_state:
		InventoryState.INSPECTING:
			set_inspection_mode(false)
		InventoryState.COMBINING:
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
	if item.curacion > 0:
		lista.append(Comando.UTILIZAR)
	if inventory.get_item_count() > 1:
		lista.append(Comando.COMBINAR)
	return lista

func _mover_comando(paso: int) -> void:
	var lista := _comandos_visibles()
	if lista.is_empty():
		return
	comando_actual = lista[wrapi(lista.find(comando_actual) + paso, 0, lista.size())]
	update_hint()

func _ejecutar_comando() -> void:
	if not comando_actual in _comandos_visibles():
		_mostrar_mensaje("No se puede.")
		return
	match comando_actual:
		Comando.EXAMINAR:
			set_inspection_mode(true)
		Comando.UTILIZAR:
			_utilizar()
		Comando.COMBINAR:
			current_state = InventoryState.COMBINING
			combinar_desde = current_item_index
			update_hint()

func _utilizar() -> void:
	if Salud.llena():
		_mostrar_mensaje("No lo necesitas ahorita.")
		return
	var item: InventoryItemData = inventory.get_item(current_item_index)
	var antes: int = Salud.vida
	Salud.vida += item.curacion
	inventory.remove_item(current_item_index)
	_mostrar_mensaje("%s: +%d de vida." % [item.item_name, Salud.vida - antes])

func _terminar_combinacion() -> void:
	if current_item_index == combinar_desde:
		_mostrar_mensaje("Elige otro objeto.")
		return
	var desde := combinar_desde
	current_state = InventoryState.NAVIGATING
	combinar_desde = -1
	var resultado: InventoryItemData = inventory.combinar(desde, current_item_index)
	if resultado == null:
		update_hint()
		_mostrar_mensaje("Eso no se puede combinar.")
		return
	current_item_index = inventory.get_item_count() - 1
	refresh_carousel()
	_mostrar_mensaje("Hiciste: %s." % resultado.item_name)

func _actualizar_estado() -> void:
	var estado: String = Salud.estado()
	estado_label.text = estado
	estado_label.add_theme_color_override("font_color", COLORES_ESTADO[estado])

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
	item_name_label.text = selected_item.item_name
	item_description_label.text = selected_item.description
	current_model = modelos[current_item_index]
	# The centre model may have changed; keep the inspector in sync.
	inspect_viewer.set_active_model(current_model)
	if current_state == InventoryState.NAVIGATING and not comando_actual in _comandos_visibles():
		var lista := _comandos_visibles()
		comando_actual = lista[0] if not lista.is_empty() else Comando.EXAMINAR
	update_hint()

func _actualizar_equipo() -> void:
	for hijo in equipo_pivot.get_children():
		hijo.queue_free()
	var mochila: InventoryItemData = inventory.mochila
	var modelo: Node3D = mochila.crear_modelo(TAMANO_MOCHILA) if mochila else null
	if modelo:
		equipo_pivot.add_child(modelo)
	sin_mochila_label.visible = modelo == null

# Factory utility to instantiate and mount item scene resources cleanly
func spawn_item(index: int) -> Node3D:
	var item_data: InventoryItemData = inventory.get_item(index)
	if item_data == null:
		return null
	var model_node := item_data.crear_modelo(TAMANO_MODELO)
	if model_node:
		item_pivot.add_child(model_node)
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
	capacidad_label.text = "- %d / %d -" % [inventory.get_item_count(), inventory.capacidad()]
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
			inspect_hint_label.text = ""

# Solo se ven los comandos que aplican; el elegido en blanco
func _actualizar_comandos() -> void:
	var lista := _comandos_visibles()
	for i in comando_labels.size():
		var label := comando_labels[i]
		label.visible = i < lista.size()
		if label.visible:
			label.text = COMANDOS[lista[i]]
			var elegido: bool = lista[i] == comando_actual and current_state == InventoryState.NAVIGATING
			label.add_theme_color_override("font_color", COLOR_ELEGIDO if elegido else COLOR_NORMAL)
