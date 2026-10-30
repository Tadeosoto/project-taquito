@tool
extends Node2D

@export var corner_color: Color = Color.WHITE
@export var line_thickness: float = 3.0
@export var corner_length: float = 12.0

# Adjust these in the inspector to match the blue box exactly
@export var box_width: float = 200.0
@export var box_height: float = 250.0

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	var w: float = box_width
	var h: float = box_height
	
	# === TOP-RIGHT CORNER ===
	draw_line(Vector2(w, 0), Vector2(w - corner_length, 0), corner_color, line_thickness)
	draw_line(Vector2(w, 0), Vector2(w, corner_length), corner_color, line_thickness)
	
	# === BOTTOM-LEFT CORNER ===
	draw_line(Vector2(0, h), Vector2(corner_length, h), corner_color, line_thickness)
	draw_line(Vector2(0, h), Vector2(0, h - corner_length), corner_color, line_thickness)
