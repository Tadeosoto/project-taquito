extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var tail_height := 32.0
	var margin := 4.0
	var body := Rect2(margin, margin, size.x - margin * 2.0, size.y - tail_height - margin)
	var mid_x := size.x * 0.5
	var box_bottom := body.position.y + body.size.y

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(mid_x - 22.0, box_bottom - 2.0),
			Vector2(mid_x + 22.0, box_bottom - 2.0),
			Vector2(mid_x, size.y - 2.0),
		]),
		Color.BLACK
	)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.border_color = Color.BLACK
	fill.set_border_width_all(7)
	fill.set_corner_radius_all(18)
	fill.corner_detail = 8
	fill.draw(get_canvas_item(), body)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(mid_x - 12.0, box_bottom - 12.0),
			Vector2(mid_x + 12.0, box_bottom - 12.0),
			Vector2(mid_x, size.y - 16.0),
		]),
		Color.WHITE
	)
