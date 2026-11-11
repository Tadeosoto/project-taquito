@tool
extends EditorScenePostImport

# Se corre al importar el .glb de una colonia del mapa hecho en Blender
# (models/mapa/<colonia>/<colonia>.glb, tools/blender/mapa/exportar.py). Como MapPostImport con
# el mapa de OSM2World: cambia los materiales por los shaders PS1 del juego segun su nombre
# (los pone tools/blender/mapa/kit.py) y junta las mallas en cuadros de CUADRO m, una malla por
# material en cada cuadro, para que sean pocas llamadas de dibujo. Las cajas "-colonly" ya
# llegan como StaticBody3D (Godot las arma antes de este script) y se quedan como estan.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const FACHADA_SHADER := preload("res://shaders/ps1_fachada_kit.gdshader")
const FACADE_SHADER := preload("res://shaders/ps1_facade.gdshader")
const GROUND_SHADER := preload("res://shaders/ps1_suelo.gdshader")
const SUELO_PASTO := preload("res://scripts/map/SueloPasto.gd")

const CUADRO := 64.0

# Pisos: material de kit.PISOS -> [textura, metros por repeticion, modo de ps1_suelo, piso_tipo
# (deterioro: 1 asfalto con baches, 2 banqueta, 3 empedrado)], como MapPostImport.GROUND_TEXTURES
const PISOS := {
	"asfalto": ["res://textures/map/asfalto.png", 4.0, 0, 1],
	"banqueta": ["res://textures/map/banqueta.png", 3.0, 0, 2],
	"empedrado": ["res://textures/map/empedrado.png", 2.5, 0, 3],
	"pasto_seco": ["res://textures/map/pasto_seco.png", 2.5, 2, 0],
	"tierra": ["res://textures/map/suelo.png", 3.0, 0, 0],
	# La plaza empedrada (foto del kit, tools/blender/mapa/kit.py "piedra_plaza")
	"adoquin": ["res://textures/mapa/piedra_plaza.png", 2.0, 0, 3],
	# Andadores de cantera y jardines de la plaza (pasto parejo, modo 0: con el 2 salia casi todo seco)
	"cantera_piso": ["res://textures/mapa/cantera_rosa.png", 1.5, 0, 3],
	"pasto": ["res://textures/map/pasto.png", 2.5, 0, 0],
}
# Capa de profundidad de cada piso (ps1_suelo `capa`: la mas alta queda encima). Las calles van
# pintadas 1-2 cm sobre el piso de banqueta, y a lo lejos el piso las tapaba
# En la plaza: adoquin abajo, el pasto de los jardines encima y los andadores arriba de todo
const CAPAS := {"tierra": 0.0, "banqueta": 1.0, "pasto_seco": 2.0, "adoquin": 2.5, "pasto": 2.7, "empedrado": 3.0,
		"cantera_piso": 3.5, "asfalto": 4.0}

const MERGE_FORMAT_MASK := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT \
		| Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2

var _materiales := {}
var _blanca: ImageTexture


func _post_import(scene: Node) -> Object:
	var imagen := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.WHITE)
	_blanca = ImageTexture.create_from_image(imagen)

	# cuadro (Vector2i) -> { [nombre de material, material original, formato] -> SurfaceTool }
	var cuadros := {}
	var mallas: Array[MeshInstance3D] = []
	for nodo in scene.find_children("*", "MeshInstance3D", true, false):
		var instancia := nodo as MeshInstance3D
		if instancia.mesh == null:
			continue
		mallas.append(instancia)
		var xform := _transform_en_escena(scene, instancia)
		var centro := xform * instancia.mesh.get_aabb().get_center()
		var cuadro := Vector2i(floori(centro.x / CUADRO), floori(centro.z / CUADRO))
		var herramientas: Dictionary = cuadros.get_or_add(cuadro, {})
		var malla := instancia.mesh
		for i in malla.get_surface_count():
			var original: Material = malla.surface_get_material(i)
			if original == null:
				original = instancia.get_active_material(i)
			var nombre := String(original.resource_name) if original else ""
			var clave := [nombre, original if not _por_nombre(nombre) else null, malla.surface_get_format(i) & MERGE_FORMAT_MASK]
			if not herramientas.has(clave):
				herramientas[clave] = SurfaceTool.new()
			(herramientas[clave] as SurfaceTool).append_from(malla, i, xform)

	for instancia in mallas:
		instancia.get_parent().remove_child(instancia)
		instancia.free()
	for cuadro: Vector2i in cuadros:
		var array_mesh := ArrayMesh.new()
		for clave: Array in cuadros[cuadro]:
			(cuadros[cuadro][clave] as SurfaceTool).commit(array_mesh)
			array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, _material(clave[0], clave[1]))
		var nodo := MeshInstance3D.new()
		nodo.name = "Cuadro_%d_%d" % [cuadro.x, cuadro.y]
		nodo.mesh = array_mesh
		scene.add_child(nodo)
		nodo.owner = scene
	print("MapaPostImport: %d mallas -> %d cuadros de %d m, %d materiales" % [
			mallas.size(), cuadros.size(), CUADRO, _materiales.size()])
	return scene


func _por_nombre(nombre: String) -> bool:
	return nombre == "fachada_kit" or nombre == "azotea" or PISOS.has(nombre)


# La escena importada todavia no esta en el arbol: el transform se arma con los de los padres
func _transform_en_escena(scene: Node, nodo: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var actual := nodo
	while actual != scene and actual != null:
		if actual is Node3D:
			xform = (actual as Node3D).transform * xform
		actual = actual.get_parent()
	return xform


func _material(nombre: String, original: Material) -> Material:
	var clave: Variant = nombre if _por_nombre(nombre) else original
	if _materiales.has(clave):
		return _materiales[clave]
	var material: ShaderMaterial
	if nombre == "fachada_kit":
		material = ShaderMaterial.new()
		material.shader = FACHADA_SHADER
		material.set_shader_parameter("fachadas", load("res://textures/mapa/fachadas_kit.png"))
		material.set_shader_parameter("fachadas_mascara", load("res://textures/mapa/fachadas_kit_mascara.png"))
		material.set_shader_parameter("affine_enabled", false)
	elif nombre == "azotea":
		material = ShaderMaterial.new()
		material.shader = FACADE_SHADER
		material.set_shader_parameter("azoteas", load("res://textures/map/azoteas.png"))
		material.set_shader_parameter("azotea", true)
		material.set_shader_parameter("affine_enabled", false)
	elif PISOS.has(nombre):
		var piso: Array = PISOS[nombre]
		material = ShaderMaterial.new()
		material.shader = GROUND_SHADER
		material.set_shader_parameter("albedo_texture", load(piso[0]))
		material.set_shader_parameter("tile_size", piso[1])
		SUELO_PASTO.configurar(material, piso[2])
		material.set_shader_parameter("piso_tipo", piso[3])
		material.set_shader_parameter("capa", CAPAS[nombre])
		material.set_shader_parameter("jitter_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("affine_enabled", false)
	else:
		# Color liso, o una foto del kit ("foto_<n>": textures/mapa/<n>.png, que el .glb no
		# lleva): ps1_combined sin temblor, como todo el mundo
		material = ShaderMaterial.new()
		material.shader = PS1_SHADER
		var textura: Texture2D = _blanca
		var color := Color.WHITE
		var ruta := "res://textures/mapa/%s.png" % nombre.trim_prefix("foto_")
		if nombre.begins_with("foto_") and ResourceLoader.exists(ruta):
			textura = load(ruta)
		elif original is BaseMaterial3D:
			color = (original as BaseMaterial3D).albedo_color
			if (original as BaseMaterial3D).albedo_texture:
				textura = (original as BaseMaterial3D).albedo_texture
		material.set_shader_parameter("albedo_texture", textura)
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("jitter_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("affine_enabled", false)
	_materiales[clave] = material
	return material
