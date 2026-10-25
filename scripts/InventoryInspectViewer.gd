extends Node3D

@onready var item_pivot: Node3D = $ItemPivot

@export var rotation_speed: float = 120.0

# Que tan rapido se va a la verga el zoom
@export var zoom_speed: float = 0.15

# Esto es pa que no se vaya a la verga el zoom
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5

# Zoom actual (1.0 = normal)
var current_zoom: float = 1.0

var inspection_active: bool = false

# The model currently sitting in the centre slot, assigned explicitly by
# InventoryUI. Kept as a direct reference so inspection always targets the right
# node, regardless of which pivot the carousel happens to parent it under.
var active_model: Node3D = null


func set_active_model(model: Node3D) -> void:
	active_model = model

func _process(delta: float) -> void:
	if not inspection_active:
		return
	
	var model: Node3D = _get_active_model()
	if not is_instance_valid(model):
		return
	
	# === Rotacion ===
	var rotation_input := Input.get_vector(
		"inspect_left",
		"inspect_right",
		"inspect_up",
		"inspect_down"
	)
	
	model.rotation_degrees.y += (
		rotation_input.x
		* rotation_speed
		* delta
	)
	
	model.rotation_degrees.x -= (
		rotation_input.y
		* rotation_speed
		* delta
	)
	
	model.rotation_degrees.x = clamp(
		model.rotation_degrees.x,
		-85,
		85
	)
	
	# === Zoom (teclado + control) ===
	if Input.is_action_pressed("inspect_zoom_in"):
		current_zoom = clamp(current_zoom + zoom_speed * delta * 3.0, min_zoom, max_zoom)
		model.scale = Vector3.ONE * current_zoom

	elif Input.is_action_pressed("inspect_zoom_out"):
		current_zoom = clamp(current_zoom - zoom_speed * delta * 3.0, min_zoom, max_zoom)
		model.scale = Vector3.ONE * current_zoom


func _unhandled_input(event: InputEvent) -> void:
	if not inspection_active:
		return
	
	var model: Node3D = _get_active_model()
	if not is_instance_valid(model):
		return

	# Zoom con el cliptoris del maus (one step at a time)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
			model.scale = Vector3.ONE * current_zoom
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
			model.scale = Vector3.ONE * current_zoom
			get_viewport().set_input_as_handled()

# Explicitly resets tracking bounds when changing items
func reset_for_new_item() -> void:
	current_zoom = 1.0
	var model: Node3D = _get_active_model()
	if is_instance_valid(model):
		model.scale = Vector3.ONE
		model.rotation = Vector3.ZERO

func set_inspection_active(active: bool) -> void:
	inspection_active = active
	
	# FIX: Run a clean reset on whatever item is currently inside the center slot
	reset_for_new_item()
	
func _get_active_model() -> Node3D:
	# Prefer the model InventoryUI told us is centred.
	if is_instance_valid(active_model):
		return active_model
	# Fallback: scan the centre pivot (used only if no model was assigned yet).
	for child in item_pivot.get_children():
		if child is Node3D and not child.is_queued_for_deletion():
			return child as Node3D
	return null
