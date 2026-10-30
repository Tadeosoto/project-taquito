extends CanvasLayer

# Track whether the player is browsing items or inspecting one closely
enum InventoryState {
	NAVIGATING,
	INSPECTING
}

# UI elements for text labels and buttons
@onready var item_name_label: Label = $MainPanel/ItemName
@onready var item_description_label: RichTextLabel = $MainPanel/ItemDescription
@onready var inspect_hint_label: Label = $MainPanel/InspecHint
@onready var item_count_label: Label = $MainPanel/ItemCount
@onready var inspect_button: Button = $MainPanel/InspectButton
@onready var inspect_viewer: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld
@onready var inventory = Inventory

# --- 3D Position Pivot Points ---
@onready var item_pivot: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/ItemPivot
@onready var left_pivot: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/LeftPivot
@onready var right_pivot: Node3D = $MainPanel/PreviewContainer/PreviewViewport/PreviewWorld/RightPivot

# Current navigation parameters
var current_state: InventoryState = InventoryState.NAVIGATING
var current_item_index: int = 0

# References to hold the spawned 3D meshes
var left_model: Node3D = null
var current_model: Node3D = null
var right_model: Node3D = null
var active_tween: Tween = null
# Nodes animating out; freed when their slide finishes or is interrupted.
var _pending_free: Array[Node3D] = []

func _ready() -> void:
	inspect_button.pressed.connect(_on_inspect_button_pressed)
	inspect_button.focus_mode = Control.FOCUS_NONE
	
	# Automatically refresh if items are added or removed globally
	inventory.inventory_changed.connect(refresh_carousel)
	
	set_inspection_mode(false)
	refresh_carousel()
	
	# === RETRO HIGHLIGHT FLASH TWEEN ===
	if has_node("MainPanel/HighlightBox"):
		var box = $MainPanel/HighlightBox
		
		# Create an infinite looping pulse animation
		var pulse_tween = create_tween().set_loops()
		pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Fade the border color alpha channel out and back in smoothly
		pulse_tween.tween_property(box, "modulate:a", 0.3, 0.6)
		pulse_tween.tween_property(box, "modulate:a", 1.0, 0.6)
	
func _on_inspect_button_pressed() -> void:
	if current_state == InventoryState.INSPECTING:
		set_inspection_mode(false)
	elif is_instance_valid(current_model):
		set_inspection_mode(true)
	
func _unhandled_input(event: InputEvent) -> void:
	# Ignore navigation controls if we are currently inspecting an object
	if current_state == InventoryState.INSPECTING:
		if event.is_action_pressed("inventory_back"):
			set_inspection_mode(false)
			get_viewport().set_input_as_handled()
		return
	
	var item_count := inventory.get_item_count()
	if item_count == 0:
		return
		
	# Go to next item (wrap around using modulo %). Disabled with a single item
	# so navigation can never spawn duplicate meshes.
	if item_count > 1 and event.is_action_pressed("inventory_next"):
		current_item_index = (current_item_index + 1) % item_count
		refresh_carousel(true)
		get_viewport().set_input_as_handled()
			
	# Go to previous item
	elif item_count > 1 and event.is_action_pressed("inventory_previous"):
		current_item_index = (current_item_index - 1 + item_count) % item_count
		refresh_carousel(false)
		get_viewport().set_input_as_handled()
			
	# Press confirm key to look closely at an item
	elif event.is_action_pressed("inventory_confirm"):
		if is_instance_valid(current_model):
			set_inspection_mode(true)
		get_viewport().set_input_as_handled()
	
func set_inspection_mode(active: bool) -> void:
	if active:
		current_state = InventoryState.INSPECTING
	else:
		current_state = InventoryState.NAVIGATING
	# Point the inspector at the item currently in the centre slot, then forward
	# the state toggle to the 3D inspection script.
	inspect_viewer.set_active_model(current_model)
	inspect_viewer.set_inspection_active(active)
	update_hint()

# Refreshes the text fields and coordinates animations or layout initializations
func refresh_carousel(sliding_forward: Variant = null) -> void:
	if inventory.get_item_count() == 0:
		clear_all_models()
		item_name_label.text = "No Items"
		item_description_label.text = "There is nothing in the inventory."
		inspect_viewer.set_active_model(null)
		update_hint()
		return
		
	if current_item_index >= inventory.get_item_count():
		current_item_index = inventory.get_item_count() - 1
		
	var selected_item := inventory.get_item(current_item_index)
	if selected_item == null: 
		return
		
	# Update label text fields instantly
	item_name_label.text = selected_item.item_name
	item_description_label.text = selected_item.description
	
	# CHANGED: Only run the static setup if we are opening the menu for the first time.
	# Otherwise, let the dedicated slide function handle the offsets cleanly.
	if sliding_forward == null:
		setup_static_carousel()
	else:
		animate_carousel_slide(sliding_forward)
	
	# The centre model may have changed; keep the inspector in sync.
	inspect_viewer.set_active_model(current_model)
	update_hint()

# Builds the layout instantly without animations (Used strictly on inventory menu startup)
func setup_static_carousel() -> void:
	clear_all_models()
	if active_tween: 
		active_tween.kill()
		
	var total := inventory.get_item_count()
	var left_idx := (current_item_index - 1 + total) % total
	var right_idx := (current_item_index + 1) % total
	
	if total > 1:
		left_model = spawn_item_at(left_idx, left_pivot, Vector3(0.5, 0.5, 0.5))
	current_model = spawn_item_at(current_item_index, item_pivot, Vector3.ONE)
	if total > 2:
		right_model = spawn_item_at(right_idx, right_pivot, Vector3(0.5, 0.5, 0.5))

# Completely handles model lifecycle, offscreen offsets, and clean sliding transitions.
# Interruption-safe: if a slide is still playing it is finalized instantly first, so
# rapid next/previous presses can never leak or duplicate nodes.
func animate_carousel_slide(forward: bool) -> void:
	_finalize_active_slide()

	var total := inventory.get_item_count()
	var duration := 0.25 # Slide speed curve duration in seconds

	var left_idx := (current_item_index - 1 + total) % total
	var right_idx := (current_item_index + 1) % total

	# Snapshot the logical slots before we reassign them.
	var old_left := left_model
	var old_center := current_model
	var old_right := right_model

	var new_left: Node3D = null
	var new_center: Node3D = null
	var new_right: Node3D = null
	var outgoing: Array[Node3D] = []

	if forward: # Moving Right / Next Item (Items move Leftward)
		new_left = old_center
		outgoing.append(old_left)
		# Old right item takes centre focus (or a fresh one enters from the right).
		if is_instance_valid(old_right):
			new_center = old_right
		else:
			new_center = spawn_item_at(current_item_index, item_pivot, Vector3(0.5, 0.5, 0.5))
			if is_instance_valid(new_center):
				new_center.global_position = right_pivot.global_position
		# New right item slides in from offscreen right.
		if total > 2:
			new_right = spawn_item_at(right_idx, right_pivot, Vector3(0.5, 0.5, 0.5))
			if is_instance_valid(new_right):
				new_right.global_position = right_pivot.global_position + Vector3(2.0, 0, 0)

	else: # Moving Left / Previous Item (Items move Rightward)
		new_right = old_center
		outgoing.append(old_right)
		# Old left item takes centre focus (or a fresh one enters from the left).
		if is_instance_valid(old_left):
			new_center = old_left
		else:
			new_center = spawn_item_at(current_item_index, item_pivot, Vector3(0.5, 0.5, 0.5))
			if is_instance_valid(new_center):
				new_center.global_position = left_pivot.global_position
		# New left item slides in from offscreen left.
		if total > 1:
			new_left = spawn_item_at(left_idx, left_pivot, Vector3(0.5, 0.5, 0.5))
			if is_instance_valid(new_left):
				new_left.global_position = left_pivot.global_position - Vector3(2.0, 0, 0)

	# Commit the new logical state NOW. Inspection and any follow-up slide always
	# reference the correct nodes, even if this tween gets interrupted.
	left_model = new_left
	current_model = new_center
	right_model = new_right
	_pending_free = outgoing

	# Build the animation from the current (possibly mid-flight) transforms.
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_instance_valid(new_left):
		active_tween.tween_property(new_left, "global_position", left_pivot.global_position, duration)
		active_tween.tween_property(new_left, "scale", Vector3(0.5, 0.5, 0.5), duration)
	if is_instance_valid(new_center):
		active_tween.tween_property(new_center, "global_position", item_pivot.global_position, duration)
		active_tween.tween_property(new_center, "scale", Vector3.ONE, duration)
	if is_instance_valid(new_right):
		active_tween.tween_property(new_right, "global_position", right_pivot.global_position, duration)
		active_tween.tween_property(new_right, "scale", Vector3(0.5, 0.5, 0.5), duration)

	# Outgoing item(s) slide off-screen, shrink, then are freed.
	var exit_dir := -1.0 if forward else 1.0
	for node in outgoing:
		if is_instance_valid(node):
			active_tween.tween_property(node, "global_position", node.global_position + Vector3(exit_dir * 2.0, 0, 0), duration)
			active_tween.tween_property(node, "scale", Vector3.ZERO, duration)
			active_tween.tween_callback(
				func(): if is_instance_valid(node): node.queue_free()
			)

	# Tell the inspector which node is now in focus.
	inspect_viewer.set_active_model(current_model)

# Kills any running slide, frees its outgoing nodes, and snaps the logical slots
# back to their rest transforms. Safe to call at any time.
func _finalize_active_slide() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = null

	for node in _pending_free:
		if is_instance_valid(node):
			node.queue_free()
	_pending_free.clear()

	_snap_model_to_slot(left_model, left_pivot, Vector3(0.5, 0.5, 0.5))
	_snap_model_to_slot(current_model, item_pivot, Vector3.ONE)
	_snap_model_to_slot(right_model, right_pivot, Vector3(0.5, 0.5, 0.5))

# Places a model exactly at a slot and resets its scale.
func _snap_model_to_slot(model: Node3D, pivot: Node3D, slot_scale: Vector3) -> void:
	if is_instance_valid(model) and is_instance_valid(pivot):
		model.global_position = pivot.global_position
		model.scale = slot_scale

# Factory utility to instantiate and mount item scene resources cleanly
func spawn_item_at(index: int, target_pivot: Node3D, target_scale: Vector3) -> Node3D:
	var item_data := inventory.get_item(index)
	if item_data == null or item_data.inspection_model == null: 
		return null
	var instance: Node = item_data.inspection_model.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null
	var model_node := instance as Node3D
	target_pivot.add_child(model_node)
	model_node.global_position = target_pivot.global_position
	model_node.scale = target_scale
	return model_node

# Deletes all currently loaded carousel model assets out of engine view completely
func clear_all_models() -> void:
	# Stop any in-flight slide so its callbacks cannot resurrect freed nodes.
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = null
	_pending_free.clear()
	# Bulletproof check: clear every single node child inside the pivots directly
	if is_instance_valid(left_pivot):
		for child in left_pivot.get_children():
			child.queue_free()
			
	if is_instance_valid(item_pivot):
		for child in item_pivot.get_children():
			child.queue_free()
			
	if is_instance_valid(right_pivot):
		for child in right_pivot.get_children():
			child.queue_free()
			
	# Clear our script tracking references cleanly
	left_model = null
	current_model = null
	right_model = null

# Modifies instructional footer texts based on what menu state is active
func update_hint() -> void:
	if inventory.get_item_count() == 0:
		inspect_hint_label.text = ""
		item_count_label.text = "Objeto 0 de 0"
		inspect_button.text = "Examinar [Enter]"
		inspect_button.disabled = true
		return
	item_count_label.text = "Objeto %d de %d" % [current_item_index + 1, inventory.get_item_count()]
	if current_state == InventoryState.INSPECTING:
		inspect_hint_label.text = "Flechas: Rotar"
		inspect_button.text = "Regresar: [Esc]"
		inspect_button.disabled = false
	else:
		inspect_hint_label.text = "◀                                                         ▶"
		inspect_button.text = "Examinar [Enter]"
		inspect_button.disabled = not is_instance_valid(current_model)
