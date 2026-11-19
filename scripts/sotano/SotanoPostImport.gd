@tool
extends EditorScenePostImport

# Al importar los .glb del Sotano (models/sotano/sotano.glb y gabinete_olpley.glb, de
# tools/blender/sotano/sotano.py) cada material de Blender se cambia por el del juego por su
# nombre: texturas del proyecto con filtro nearest, como el templo (tools/construir_templo.gd).
# Los UV de las cajas ya vienen en metros, asi que "escala" es cuantas veces se repite por metro.
# Un material por nombre para todo el archivo. Lo que no esta en TEXTURAS ni en COLORES se queda
# con el color que traia de Blender.

const TEXTURAS := {
	# nombre: [textura, tinte, repeticiones por metro]
	"concreto_piso": ["res://textures/mapa/casa_psm_concreto.png", Color(0.62, 0.6, 0.56), 0.5],
	"concreto_escalon": ["res://textures/mapa/casa_psm_concreto.png", Color(0.72, 0.7, 0.66), 1.0],
	"concreto_techo": ["res://textures/mapa/casa_psm_concreto.png", Color(0.45, 0.44, 0.43), 0.5],
	"concreto_columna": ["res://textures/mapa/casa_psm_concreto.png", Color(0.65, 0.63, 0.6), 1.0],
	"block": ["res://textures/mapa/block.png", Color(0.78, 0.76, 0.72), 0.7],
	"madera": ["res://textures/mapa/madera.png", Color(0.8, 0.65, 0.5), 1.0],
	"metal": ["res://textures/mapa/casa_psm_metal.png", Color(0.7, 0.72, 0.75), 2.0],
	"antiderrapante": ["res://textures/mapa/casa_psm_metal.png", Color(0.95, 0.96, 1.0), 6.0],
	"lamina_puerta": ["res://textures/mapa/lamina_verde.png", Color(0.8, 0.85, 0.8), 1.0],
	"estampa_virgen": ["res://textures/map/virgen/virgen_nos_cuida.png", Color.WHITE, 0.0],
	"calcomanias": ["res://textures/sotano/calcomanias.png", Color.WHITE, 0.0],
}
# Los que brillan solos (sin luz): tubos, neon, veladoras, la pantalla y los botones
const BRILLAN := {
	"tubo": Color(0.95, 0.98, 1.0),
	"neon_rosa": Color(1.0, 0.25, 0.75),
	"neon_verde": Color(0.3, 1.0, 0.45),
	"veladora": Color(1.0, 0.75, 0.35),
	"boton_grande": Color(1.0, 0.85, 0.15),
}
const PANTALLA := "res://textures/sotano/pantalla.png"

var _hechos := {}


func _post_import(scene: Node) -> Object:
	for nodo in scene.find_children("*", "MeshInstance3D", true, false):
		var malla := (nodo as MeshInstance3D).mesh
		if malla == null:
			continue
		for i in malla.get_surface_count():
			var original := malla.surface_get_material(i)
			if original == null:
				continue
			malla.surface_set_material(i, _material(original))
	return scene


func _material(original: Material) -> Material:
	var nombre := original.resource_name
	if _hechos.has(nombre):
		return _hechos[nombre]
	var m := StandardMaterial3D.new()
	m.resource_name = nombre
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if TEXTURAS.has(nombre):
		var t: Array = TEXTURAS[nombre]
		m.albedo_texture = load(t[0])
		m.albedo_color = t[1]
		if float(t[2]) > 0.0:
			m.uv1_scale = Vector3.ONE * float(t[2])
	elif BRILLAN.has(nombre) or nombre.begins_with("boton_"):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = BRILLAN.get(nombre, (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE)
	elif nombre == "pantalla":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(PANTALLA)
	elif original is BaseMaterial3D:
		m.albedo_color = (original as BaseMaterial3D).albedo_color
	if nombre == "humedad":
		m.albedo_color = Color(0.12, 0.14, 0.11, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hechos[nombre] = m
	return m
