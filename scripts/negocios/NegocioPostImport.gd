@tool
extends EditorScenePostImport

# Al importar los .glb de los negocios hechos en Blender (models/negocios/yonke/*.glb de
# tools/blender/negocios/yonke.py, models/negocios/punto/*.glb de punto.py) cada material de
# Blender se cambia por el del juego por su nombre, como en el Sotano (SotanoPostImport.gd): los
# .glb salen sin imagenes y aqui se ponen las texturas del proyecto con filtro nearest. Los UV ya
# vienen en metros: el tercer valor es cuantas veces se repite por metro (el mismo que usa
# mat_tex() en Blender). Un material por nombre para todo el archivo, hecho al importar (no en
# cada instancia). Lo que no esta en ninguna tabla se queda con el color que traia de Blender.

const TEXTURAS := {
	# nombre: [textura, tinte, repeticiones por metro]
	"tierra": ["res://textures/mapa/tierra.png", Color(0.8, 0.72, 0.62), 0.35],
	"lamina": ["res://textures/map/lamina.png", Color(0.85, 0.85, 0.85), 0.5],
	"lamina_oxido": ["res://textures/map/lamina.png", Color(0.7, 0.45, 0.3), 0.5],
	"lamina_techo": ["res://textures/map/lamina_techo.png", Color(0.75, 0.6, 0.5), 0.4],
	"oxido": ["res://textures/sotano/oxido.png", Color.WHITE, 0.6],
	"contenedor": ["res://textures/map/lamina.png", Color(0.78, 0.36, 0.22), 0.6],
	"block": ["res://textures/mapa/block.png", Color(0.7, 0.68, 0.64), 0.7],
	"madera": ["res://textures/mapa/madera.png", Color(0.7, 0.55, 0.4), 1.0],
	"pintura_dentro": ["res://textures/map/lamina.png", Color(0.72, 0.7, 0.6), 0.8],
	"triplay": ["res://textures/mapa/madera.png", Color(0.75, 0.62, 0.45), 1.2],
	"estampa_virgen": ["res://textures/map/virgen/virgen_nos_cuida.png", Color.WHITE, 0.0],
	"concreto": ["res://textures/mapa/casa_psm_concreto.png", Color(0.62, 0.6, 0.56), 0.5],
	"carton": ["res://textures/mapa/carton.png", Color(0.85, 0.75, 0.6), 1.0],
	"carteles_yonke": ["res://textures/negocios/yonke_carteles.png", Color.WHITE, 0.0],
	# El Punto (punto.py; el mural y el rotulo los pinta arte_punto.py)
	"aplanado": ["res://textures/mapa/aplanado_blanco.png", Color(0.86, 0.84, 0.78), 0.5],
	"aplanado_sucio": ["res://textures/mapa/aplanado_blanco.png", Color(0.62, 0.6, 0.56), 0.5],
	"zoclo": ["res://textures/mapa/block.png", Color(0.5, 0.5, 0.5), 0.7],
	"mural_punto": ["res://textures/negocios/mural_punto.png", Color.WHITE, 0.0],
	"cantina_punto": ["res://textures/negocios/cantina_punto.png", Color.WHITE, 0.0],
	"lambrin": ["res://textures/mapa/madera.png", Color(0.42, 0.26, 0.16), 1.0],
	"lambrin_oscuro": ["res://textures/mapa/madera.png", Color(0.25, 0.15, 0.1), 1.2],
	# La cantina de adentro (punto.py cantina_dentro)
	"piso_cantina": ["res://textures/mapa/azulejo_amarillo.png", Color(0.7, 0.62, 0.5), 1.0],
	"muro_cantina": ["res://textures/mapa/aplanado_rojo.png", Color(0.75, 0.55, 0.45), 0.5],
	"zoclo_cantina": ["res://textures/mapa/azulejo_amarillo.png", Color(0.35, 0.5, 0.45), 2.0],
	"techo_cantina": ["res://textures/mapa/aplanado_blanco.png", Color(0.5, 0.48, 0.45), 0.5],
}
# Lo que viene de las piezas del Sotano que se reusan (botellas, banco, refri, silla plegable):
# sus texturas y brillos son los de SotanoPostImport
const SOTANO := preload("res://scripts/sotano/SotanoPostImport.gd")
# Grafitis (tags negros sobre blanco con alfa): "grafiti_NN" -> textures/map/grafitis/grafiti_firma_NN.png
const GRAFITIS := "res://textures/map/grafitis/grafiti_firma_%s.png"
# Brillan solos, sin luz (focos, la luz del dia en la ventana, pantallas)
const BRILLAN := {
	"foco_yonke": Color(1.0, 0.88, 0.6),
	"ventana_luz": Color(0.95, 0.92, 0.8),
	"pantalla_tele": Color(0.45, 0.65, 0.75),
	"foco_luz_dia": Color(1.0, 0.92, 0.75),
	"foco_lampara": Color(1.0, 0.85, 0.5),
	"rocola_luz": Color(1.0, 0.6, 0.2),
	"foco_billar": Color(1.0, 0.92, 0.65),
	"pantalla_futbol": Color(0.3, 0.7, 0.35),
	"agua_pecera": Color(0.3, 0.6, 0.9),
	"foco_serie": Color(1.0, 0.88, 0.5),
	"refri_luz": Color(0.85, 0.95, 1.0),
}

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
	if BRILLAN.has(nombre) or nombre.begins_with("foco_") or nombre.begins_with("neon_"):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = BRILLAN.get(nombre, _color(original))
	elif TEXTURAS.has(nombre) or SOTANO.TEXTURAS.has(nombre):
		var t: Array = TEXTURAS[nombre] if TEXTURAS.has(nombre) else SOTANO.TEXTURAS[nombre]
		m.albedo_texture = load(t[0])
		m.albedo_color = t[1]
		if float(t[2]) > 0.0:
			m.uv1_scale = Vector3.ONE * float(t[2])
		if nombre in SOTANO.BRILLAN_TEXTURA:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif nombre.begins_with("grafiti_"):
		m.albedo_texture = load(GRAFITIS % nombre.trim_prefix("grafiti_"))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	else:
		m.albedo_color = _color(original)
	if nombre.begins_with("vidrio_"):
		m.roughness = 0.2
		m.metallic_specular = 0.9
		if nombre == "vidrio_refri":
			m.albedo_color = Color(0.75, 0.9, 1.0, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if nombre == "charco":
		m.roughness = 0.1
		m.metallic_specular = 1.0
	if nombre in ["rin", "oro", "cromo"]:
		m.metallic = 0.8
		m.roughness = 0.35
	if nombre == "oro":
		m.albedo_color = Color(0.95, 0.72, 0.2)
	_hechos[nombre] = m
	return m


func _color(original: Material) -> Color:
	return (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE
