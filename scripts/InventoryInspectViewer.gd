extends Node3D

@onready var item_pivot: Node3D = $ItemPivot

@export var rotation_speed: float = 120.0

var inspection_active: bool = false

func _process(delta: float) -> void:
	
	if not inspection_active:
			return
	
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

func set_inspection_active(active: bool) -> void:
	inspection_active = active
