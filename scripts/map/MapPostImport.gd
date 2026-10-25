@tool
extends EditorScenePostImport

# Se corre cada que Godot importa models/zona_mapa.glb (el mapa de OSM2World).
# Cambia los materiales al shader PS1, junta las ~18 mil mallas sueltas en
# cuadros de CHUNK_SIZE metros (una malla por material en cada cuadro) y le pone
# una colision por cuadro.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const FACADE_SHADER := preload("res://shaders/ps1_facade.gdshader")

# Materiales de OSM2World que en las casas se cambian por fachada/azotea PS1
# (Concrete034 tambien es la banqueta, por eso solo se cambia dentro de un Building)
const BUILDING_ROLES := {"Plaster002": "fachada", "Concrete034": "azotea"}

# Mallas que no llevan colision (los arboles nomas estorban)
const NO_COLLISION_WORDS := ["tree", "forest", "wood", "vegetation"]

# Tamano (metros) de cada cuadro en que se junta el mapa
const CHUNK_SIZE := 128.0

# A partir de esta distancia (metros) ya no se dibuja un cuadro; la niebla lo tapa.
# Se mide al centro del cuadro, por eso se le suma media diagonal.
const VISIBILITY_RANGE := 250.0 + CHUNK_SIZE * 0.71

# Bits del formato que tienen que coincidir para poder juntar dos superficies
const MERGE_FORMAT_MASK := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT \
		| Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2

var _materials := {}
var _white: ImageTexture


func _post_import(scene: Node) -> Object:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(image)

	# chunk (Vector2i) -> { solid: bool -> { [material, formato] -> SurfaceTool } }
	var chunks := {}
	var mesh_count := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_count += 1
		var xform := _scene_transform(scene, mesh_instance)
		var center := xform * mesh_instance.mesh.get_aabb().get_center()
		var chunk := Vector2i(floori(center.x / CHUNK_SIZE), floori(center.z / CHUNK_SIZE))
		var solid := _wants_collision(scene, mesh_instance)
		var building := _is_building(scene, mesh_instance)
		var tools: Dictionary = chunks.get_or_add(chunk, {}).get_or_add(solid, {})
		var mesh := mesh_instance.mesh
		for surface_idx in mesh.get_surface_count():
			var material: Variant = mesh.surface_get_material(surface_idx)
			if building and material != null and BUILDING_ROLES.has(material.resource_name):
				material = BUILDING_ROLES[material.resource_name]
			var key := [material, mesh.surface_get_format(surface_idx) & MERGE_FORMAT_MASK]
			if not tools.has(key):
				tools[key] = SurfaceTool.new()
			(tools[key] as SurfaceTool).append_from(mesh, surface_idx, xform)

	# Las mallas originales ya se copiaron a los SurfaceTool; se tiran y en su
	# lugar quedan los cuadros colgando de la misma raiz.
	for child in scene.get_children():
		scene.remove_child(child)
		child.free()
	for chunk: Vector2i in chunks:
		for solid: bool in chunks[chunk]:
			_build_chunk(scene, chunk, solid, chunks[chunk][solid])

	print("MapPostImport: %d mallas -> %d cuadros de %d m, %d materiales PS1" % [
			mesh_count, scene.get_child_count(), CHUNK_SIZE, _materials.size()])
	return scene


func _build_chunk(root: Node, chunk: Vector2i, solid: bool, tools: Dictionary) -> void:
	var array_mesh := ArrayMesh.new()
	for key in tools:
		var surface_tool := tools[key] as SurfaceTool
		surface_tool.commit(array_mesh)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _ps1_material(key[0]))

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Cuadro_%d_%d%s" % [chunk.x, chunk.y, "" if solid else "_vegetacion"]
	mesh_instance.mesh = array_mesh
	mesh_instance.visibility_range_end = VISIBILITY_RANGE
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh_instance)
	# El owner es lo que hace que se guarden en la escena importada
	mesh_instance.owner = root

	if solid:
		var body := StaticBody3D.new()
		body.name = "Colision"
		var shape := CollisionShape3D.new()
		shape.shape = array_mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh_instance.add_child(body)
		body.owner = root
		shape.owner = root


# La escena importada todavia no esta en el arbol, asi que no hay global_transform:
# se arma multiplicando los transforms de los padres.
func _scene_transform(scene: Node, node: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current := node
	while current != scene and current != null:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


# Un ShaderMaterial por cada material original, compartido entre cuadros.
# `source` es el material de OSM2World, o "fachada"/"azotea" en las casas.
func _ps1_material(source: Variant) -> Material:
	if _materials.has(source):
		return _materials[source]
	if source is String:
		_materials[source] = _facade_material(source == "azotea")
		return _materials[source]

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
	# OSM2World pone el building:colour de cada casa como color de vertice
	material.set_shader_parameter("use_vertex_color", true)
	material.set_shader_parameter("jitter_enabled", true)
	material.set_shader_parameter("snap_resolution", 160.0)
	material.set_shader_parameter("wobble_enabled", true)
	material.set_shader_parameter("wobble_resolution", 40.0)
	# El warp afin se ve exagerado en paredes de 20 m
	material.set_shader_parameter("affine_enabled", false)

	_materials[source] = material
	return material


func _facade_material(azotea: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FACADE_SHADER
	material.set_shader_parameter("fachadas", load("res://textures/map/fachadas.png"))
	material.set_shader_parameter("fachadas_mascara", load("res://textures/map/fachadas_mascara.png"))
	material.set_shader_parameter("azoteas", load("res://textures/map/azoteas.png"))
	material.set_shader_parameter("azotea", azotea)
	material.set_shader_parameter("affine_enabled", false)
	return material


# OSM2World cuelga las mallas de cada casa de un nodo "Building w<id>"
func _is_building(scene: Node, node: Node) -> bool:
	var current := node
	while current != scene and current != null:
		if String(current.name).begins_with("Building"):
			return true
		current = current.get_parent()
	return false


func _wants_collision(scene: Node, mesh_instance: MeshInstance3D) -> bool:
	# get_path_to y no get_path, porque la escena todavia no esta en el arbol
	var path := String(scene.get_path_to(mesh_instance)).to_lower()
	for word in NO_COLLISION_WORDS:
		if word in path:
			return false
	return true
