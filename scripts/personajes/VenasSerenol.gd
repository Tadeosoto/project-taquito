class_name VenasSerenol
extends RefCounted

# La gente de afuera de las fortalezas toma Serenol y se le ve en la piel: venas azules
# (JJ, 2026-11-21; lore §6 "Lo que sí se ve: las venas"). Adentro de una fortaleza se ve tal cual.
# poner(modelo, true) cambia cada superficie con textura por shaders/venas_serenol.gdshader con esa
# misma textura (surface_override_material), y poner(modelo, false) lo regresa. Sirve para los
# civiles del pack PSX (StandardMaterial3D) y para los modelos con ps1_combined (los que platican).
# Un material por material original, guardado: los caminantes de Gente se reusan y cambian de
# afuera a adentro sin recompilar nada.

const SHADER := preload("res://shaders/venas_serenol.gdshader")
const META := "venas_serenol"

# material original -> su copia con venas
static var _copias := {}


# Si en `punto` la gente toma Serenol: afuera de toda fortaleza. Las colonias de Blender (grupo
# "colonia": Santa Mugre, La Gotera...) son por dentro; en map_test y el safehouse cuenta la barda
static func de_afuera(arbol: SceneTree, punto: Vector3) -> bool:
	if arbol == null or arbol.get_first_node_in_group("colonia") != null:
		return false
	return not MuroColonia.adentro(arbol, punto)


# Pone (o quita) las venas segun donde esta `modelo`. Ya debe estar en el arbol
static func segun_lugar(modelo: Node3D) -> void:
	poner(modelo, de_afuera(modelo.get_tree(), modelo.global_position))


static func poner(modelo: Node, si: bool) -> void:
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if malla.mesh == null:
			continue
		for s in malla.mesh.get_surface_count():
			var actual := malla.get_surface_override_material(s)
			var puesto := actual != null and actual.has_meta(META)
			if si and not puesto:
				# Solo si nadie mas le puso su material (ese se respeta)
				if actual != null:
					continue
				var copia := _copia(malla.mesh.surface_get_material(s))
				if copia:
					malla.set_surface_override_material(s, copia)
			elif not si and puesto:
				malla.set_surface_override_material(s, null)


static func _copia(original: Material) -> ShaderMaterial:
	if original == null:
		return null
	if _copias.has(original):
		return _copias[original]
	var textura: Texture2D = null
	var tinte := Color.WHITE
	var brinca := false
	if original is BaseMaterial3D:
		textura = original.albedo_texture
		tinte = original.albedo_color
	elif original is ShaderMaterial and (original as ShaderMaterial).shader and original.shader.resource_path.ends_with("ps1_combined.gdshader"):
		textura = original.get_shader_parameter("albedo_texture")
		var t: Variant = original.get_shader_parameter("tint")
		if t is Color:
			tinte = t
		# Los de ps1_combined brincan (jitter y wobble prendidos por omision); los civiles no
		brinca = original.get_shader_parameter("jitter_enabled") != false
	var copia: ShaderMaterial = null
	if textura != null:
		copia = ShaderMaterial.new()
		copia.shader = SHADER
		copia.set_meta(META, true)
		copia.set_shader_parameter("albedo_texture", textura)
		copia.set_shader_parameter("tint", tinte)
		copia.set_shader_parameter("jitter_enabled", brinca)
		copia.set_shader_parameter("wobble_enabled", brinca)
		copia.set_shader_parameter("affine_enabled", false)
	_copias[original] = copia
	return copia
