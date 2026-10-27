@tool
extends EditorScenePostImport

# Post-import de los modelos de tiendas (models/tiendas/*/scene.gltf, ver
# tools/map_import/fetch_sketchfab.py): cambia sus materiales por el shader PS1
# del proyecto para que combinen con el mapa. Solo se usa el color base; normal,
# roughness y emission de Sketchfab se ignoran (y el vidrio sale opaco).
# Tambien lo usan models/casas, models/props, models/objetos,
# models/personajes, models/armas y models/interiores.
# Los modelos pesados (escaneos) se reducen aqui con meshoptimizer (el mismo
# simplificador de los LOD de Godot, respeta las costuras de UV), y los que
# traen una escena entera se pueden recortar a la parte que se usa (RECORTES).

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

# Carpeta del modelo -> maximo de triangulos de todo el modelo
const MAX_TRIANGULOS := {
	"takis": 4000,
	"jarritos": 3000,
	"mexican_starter_pack": 7000,
	"soldado": 3000,
	"dr_simi": 10000,
	"indian_gangster": 3000,
	"gangster_dealer": 3000,
	"gang_member": 3000,
	"cuerno_de_chivo": 2000,
	"balas": 3000,
	"galon_agua": 1500,
	"resortera": 1500,
	"mostrador": 1500,
	"m3_mart": 4000,
	"gansito": 1500,
	"chancla": 1000,
	"garrafonero": 4000,
}

# Carpeta -> caja (coordenadas del glTF) de lo que se queda: mallas con centro
# dentro y de menos de RECORTE_MAX m. Hoy ningun modelo lo usa.
const RECORTES := {}
const RECORTE_MAX := 5.0

# Carpetas sin wobble: el wobble acomoda los vertices en una reticula de
# 1/wobble_resolution (2.5 cm) y los objetos de 1-2 cm quedan hechos un triangulo
const SIN_WOBBLE := ["tachas"]

# Carpeta -> {parte del nombre del material: color liso} para repintar piezas
# (se ignora la textura de ese material)
const TINTES := {
	# Vaso de Iced Coffee: el plastico es transparente y aqui saldria blanco
	# opaco, asi que el vaso y la bebida se pintan cafe de tejuino
	"tejuino": {"color_-1023739142": Color(0.62, 0.42, 0.24), "color_14860437": Color(0.5, 0.32, 0.17)},
	# Toalla blanca -> trapo sucio de la molotov
	"trapo": {"Scene_-_Root": Color(0.58, 0.5, 0.38)},
}

var _materials := {}
var _tintes := {}
var _convertidas := {}
var _sin_wobble := false
var _white: ImageTexture


func _post_import(scene: Node) -> Object:
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(image)
	var carpeta := get_source_file().get_base_dir().get_file()
	_tintes = TINTES.get(carpeta, {})
	if RECORTES.has(carpeta):
		_recortar(scene, scene, Transform3D.IDENTITY, RECORTES[carpeta])
	if MAX_TRIANGULOS.has(carpeta):
		var total := _contar_triangulos(scene)
		if total > MAX_TRIANGULOS[carpeta]:
			_reducir(scene, float(MAX_TRIANGULOS[carpeta]) / total)
			print("TiendaPostImport: %s de %d a %d triangulos" % [carpeta, total, _contar_triangulos(scene)])
	_sin_wobble = carpeta in SIN_WOBBLE
	_convert(scene)
	return scene


# Borra las mallas fuera de `caja` (las demas se quedan donde estan)
func _recortar(node: Node, owner_node: Node, xform: Transform3D, caja: AABB) -> void:
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			var aabb := child_xform * (child as MeshInstance3D).mesh.get_aabb()
			if not caja.has_point(aabb.get_center()) or aabb.size[aabb.get_longest_axis_index()] > RECORTE_MAX:
				node.remove_child(child)
				child.free()
				continue
		_recortar(child, owner_node, child_xform, caja)


func _contar_triangulos(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			total += (indices.size() if indices else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	for child in node.get_children():
		total += _contar_triangulos(child)
	return total


# Cada superficie se queda con ~`ratio` de sus triangulos: se generan los LOD de
# Godot (ImporterMesh, meshoptimizer: cuida UV y normales) y se toma el primero
# que cabe. Si el error crece demasiado meshoptimizer se detiene antes (los
# escaneos llenos de costuras no bajan mas de ~1/8).
func _reducir(node: Node, ratio: float) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
		var source := (node as MeshInstance3D).mesh as ArrayMesh
		var importer := ImporterMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_INDEX] == null:
				var indices := PackedInt32Array()
				for i in arrays[Mesh.ARRAY_VERTEX].size():
					indices.append(i)
				arrays[Mesh.ARRAY_INDEX] = indices
			importer.add_surface(source.surface_get_primitive_type(surface), arrays, [], {},
				source.surface_get_material(surface), source.surface_get_name(surface))
		importer.generate_lods(25.0, 60.0, [])
		var result := ArrayMesh.new()
		for surface in importer.get_surface_count():
			var arrays := importer.get_surface_arrays(surface)
			# Los canales custom vienen sin su formato y truenan add_surface_from_arrays
			for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[custom] = null
			var target := int(arrays[Mesh.ARRAY_INDEX].size() * ratio)
			for lod in importer.get_surface_lod_count(surface):
				var indices := importer.get_surface_lod_indices(surface, lod)
				arrays[Mesh.ARRAY_INDEX] = indices
				if indices.size() <= target:
					break
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			result.surface_set_material(surface, importer.get_surface_material(surface))
		(node as MeshInstance3D).mesh = result
	for child in node.get_children():
		_reducir(child, ratio)


# El material PS1 reemplaza al original dentro de la malla (no como override):
# asi el original, con sus mapas normal/roughness que no van en git, no queda
# guardado en las .scn horneadas. Varias instancias pueden compartir malla.
func _convert(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and not _convertidas.has(node.mesh):
		var mesh_instance := node as MeshInstance3D
		_convertidas[mesh_instance.mesh] = true
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface)
			var has_colors: bool = mesh_instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR != 0
			mesh_instance.mesh.surface_set_material(surface, _ps1_material(source, has_colors))
			mesh_instance.set_surface_override_material(surface, null)
	for child in node.get_children():
		_convert(child)


func _ps1_material(source: Material, has_colors: bool) -> Material:
	var key := [source, has_colors, _sin_wobble]
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
	for parte in _tintes:
		if source != null and source.resource_name.contains(parte):
			color = _tintes[parte]
			texture = _white
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("use_vertex_color", has_colors)
	# El warp afin deforma mucho las fachadas grandes
	material.set_shader_parameter("affine_enabled", false)
	if _sin_wobble:
		material.set_shader_parameter("wobble_enabled", false)

	_materials[key] = material
	return material

