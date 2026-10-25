@tool
extends EditorScenePostImport

# Post-import de los modelos de tiendas (models/tiendas/*/scene.gltf, ver
# tools/map_import/fetch_sketchfab.py): cambia sus materiales por el shader PS1
# del proyecto para que combinen con el mapa. Solo se usa el color base; normal,
# roughness y emission de Sketchfab se ignoran (y el vidrio sale opaco).

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

var _materials := {}
var _white: ImageTexture


func _post_import(scene: Node) -> Object:
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(image)
	_convert(scene)
	return scene


func _convert(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			var has_colors: bool = mesh_instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR != 0
			mesh_instance.set_surface_override_material(surface, _ps1_material(source, has_colors))
	for child in node.get_children():
		_convert(child)


func _ps1_material(source: Material, has_colors: bool) -> Material:
	var key := [source, has_colors]
	if _materials.has(key):
		return _materials[key]

	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	var texture: Texture2D = _white
	var color := Color.WHITE
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		color = base.albedo_color
		if base.albedo_texture != null:
			texture = base.albedo_texture
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("use_vertex_color", has_colors)
	# El warp afin deforma mucho las fachadas grandes
	material.set_shader_parameter("affine_enabled", false)

	_materials[key] = material
	return material
