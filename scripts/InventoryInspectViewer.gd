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

func _process(delta: float) -> void:
	
	if not inspection_active:
			return
	
	# === Rotacion
	
	var rotation_input := Input.get_vector(
		"inspect_left",
		"inspect_right",
		"inspect_up",
		"inspect_down"
	)
	
	item_pivot.rotation_degrees.y += (
		rotation_input.x
		* rotation_speed
		* delta
	)
	
	item_pivot.rotation_degrees.x -= (
		rotation_input.y
		* rotation_speed
		* delta
	)
	
	item_pivot.rotation_degrees.x = clamp(
		item_pivot.rotation_degrees.x,
		-85,
		85
	)
	
	# === Zoom (teclado + control) ===
	# esta mamada es para el zoom
	if Input.is_action_pressed("inspect_zoom_in"):
		current_zoom = clamp(current_zoom + zoom_speed * delta * 3.0, min_zoom, max_zoom)
		item_pivot.scale = Vector3.ONE * current_zoom

	elif Input.is_action_pressed("inspect_zoom_out"):
		current_zoom = clamp(current_zoom - zoom_speed * delta * 3.0, min_zoom, max_zoom)
		item_pivot.scale = Vector3.ONE * current_zoom


func _unhandled_input(event: InputEvent) -> void:
	if not inspection_active:
		return

	# Zoom con el cliptoris del maus (one step at a time)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
			item_pivot.scale = Vector3.ONE * current_zoom
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
			item_pivot.scale = Vector3.ONE * current_zoom
			get_viewport().set_input_as_handled()

func set_inspection_active(active: bool) -> void:
	inspection_active = active
	
	# Reset zoom every time you start inspecting a new item
	if active:
		current_zoom = 1.0
		item_pivot.scale = Vector3.ONE
