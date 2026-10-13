extends Node3D

@export var foot_bottom_y: float = -1.0

func _ready() -> void:
	_stand_upright()
	var body := _find_node("Taco")
	if body == null:
		body = self
	_place_feet(body)
	_stand_on_floor(body)
	_add_eyes(body)


func _stand_upright() -> void:
	var box := _world_aabb(self)
	if box.size.y < box.size.x and box.size.y < box.size.z:
		rotate_x(deg_to_rad(-90.0))


func _place_feet(body: Node3D) -> void:
	var body_box := _world_aabb(body)
	var ground_y := body_box.position.y
	var front_z := body_box.position.z + body_box.size.z * 0.45
	var left_foot := _find_node("HalfLemon")
	var right_foot := _find_node("Lemon")
	var extra_foot := _find_node("QuarterLemon")
	if left_foot != null:
		left_foot.scale *= 1.6
		_plant_foot(left_foot, Vector3(body_box.position.x + body_box.size.x * 0.3, ground_y, front_z))
	if right_foot != null:
		right_foot.scale *= 1.6
		_plant_foot(right_foot, Vector3(body_box.position.x + body_box.size.x * 0.7, ground_y, front_z))
	if extra_foot != null:
		extra_foot.scale *= 1.3
		_plant_foot(extra_foot, Vector3(body_box.get_center().x, ground_y, front_z + body_box.size.z * 0.15))


func _plant_foot(foot: Node3D, at: Vector3) -> void:
	var box := _world_aabb(foot)
	var bottom_center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var tuck := box.size.y * 0.4
	var desired := Vector3(at.x, at.y - box.size.y + tuck, at.z)
	foot.global_position += desired - bottom_center


func _stand_on_floor(body: Node3D) -> void:
	var parent_node := get_parent() as Node3D
	if parent_node == null:
		return
	var body_box := _world_aabb(body)
	var origin := parent_node.global_position
	global_position += Vector3(
		origin.x - body_box.get_center().x,
		(origin.y + foot_bottom_y) - _lowest_y(self),
		origin.z - body_box.get_center().z
	)


func _add_eyes(body: Node3D) -> void:
	var body_box := _world_aabb(body)
	var center := body_box.get_center()
	var radius := clampf(body_box.size.y * 0.12, 0.1, 0.22)
	var eye_y := body_box.position.y + body_box.size.y * 0.68
	var eye_z := body_box.position.z - radius * 0.45
	var spread := body_box.size.x * 0.16
	var holder := get_parent()
	if holder == null:
		holder = self
	_make_eye(holder, Vector3(center.x - spread, eye_y, eye_z), radius)
	_make_eye(holder, Vector3(center.x + spread, eye_y, eye_z), radius)


func _make_eye(holder: Node, at: Vector3, radius: float) -> void:
	var eye := Node3D.new()
	holder.add_child(eye)
	eye.global_position = at
	eye.add_child(_sphere(radius, Color.WHITE))
	var pupil := _sphere(radius * 0.45, Color(0.08, 0.06, 0.05))
	pupil.position = Vector3(0.0, 0.0, -radius * 0.65)
	eye.add_child(pupil)


func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	return mesh_instance


func _find_node(wanted: String) -> Node3D:
	for node in find_children("*", "Node3D", true, false):
		if node is Node3D and String(node.name) == wanted:
			return node
	return null


func _world_aabb(root: Node) -> AABB:
	var combined := AABB()
	var has_mesh := false
	var mesh_nodes: Array[Node] = []
	if root is MeshInstance3D:
		mesh_nodes.append(root)
	mesh_nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for mesh_node in mesh_nodes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_aabb := mesh_instance.global_transform * mesh_instance.get_aabb()
		if not has_mesh:
			combined = mesh_aabb
			has_mesh = true
		else:
			combined = combined.merge(mesh_aabb)
	return combined


func _lowest_y(root: Node) -> float:
	return _world_aabb(root).position.y
