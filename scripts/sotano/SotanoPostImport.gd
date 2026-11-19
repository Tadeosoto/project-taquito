@tool
extends EditorScenePostImport

# Al importar los .glb del Sotano (models/sotano/sotano.glb, gabinete_olpley.glb, botellas.glb y
# neones.glb, de
# tools/blender/sotano/sotano.py) y el adorno de la maquinita de frutas
# (models/maquinita/adorno_frutas.glb, de tools/blender/sotano/maquinita.py) cada material de Blender se cambia por el del juego por su
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
	"adorno_frutas": ["res://textures/maquinita/adorno_frutas.png", Color.WHITE, 0.0],
	"anuncios": ["res://textures/sotano/anuncios.png", Color.WHITE, 0.0],
	"refri_marca": ["res://textures/sotano/refri.png", Color.WHITE, 0.0],
	"refri_letrero": ["res://textures/sotano/refri.png", Color.WHITE, 0.0],
	# El bano (sotano.py banho(), arte.py banho())
	"azulejo": ["res://textures/sotano/azulejo.png", Color(0.85, 0.85, 0.8), 2.0],
	"azulejo_piso": ["res://textures/sotano/azulejo_piso.png", Color(0.8, 0.8, 0.8), 1.5],
	"banho": ["res://textures/sotano/banho.png", Color.WHITE, 0.0],
	"banho_mancha": ["res://textures/sotano/banho.png", Color.WHITE, 0.0],
	# Los panos de las mesas de blackjack y ruleta (arte.py mesas())
	"blackjack": ["res://textures/sotano/blackjack.png", Color.WHITE, 0.0],
	"ruleta": ["res://textures/sotano/ruleta.png", Color.WHITE, 0.0],
	"baccarat": ["res://textures/sotano/baccarat.png", Color.WHITE, 0.0],
	"blackjack_vip": ["res://textures/sotano/blackjack_vip.png", Color.WHITE, 0.0],
}
# Con textura pero brillan solos (la marquesina luminosa del refri)
const BRILLAN_TEXTURA := ["refri_letrero"]
# Los que brillan solos (sin luz): tubos, neon, veladoras, la pantalla y los botones
const BRILLAN := {
	"tubo": Color(0.95, 0.98, 1.0),
	"neon_rosa": Color(1.0, 0.25, 0.75),
	"neon_verde": Color(0.3, 1.0, 0.45),
	"veladora": Color(1.0, 0.75, 0.35),
	"boton_grande": Color(1.0, 0.85, 0.15),
	"foco_frutas": Color(1.0, 0.92, 0.6),
	"foco_bano": Color(1.0, 0.85, 0.55),
}
const PANTALLA := "res://textures/sotano/pantalla.png"
# Los neones de tubo (neones.py): el tubo brilla casi blanco al centro de su color; el halo es una
# funda gruesa que suma luz (blend add), asi se ve el resplandor sin glow en el ambiente
const NEON := {
	"rosa": Color(1.0, 0.25, 0.75), "amarillo": Color(1.0, 0.85, 0.2), "morado": Color(0.6, 0.3, 1.0),
	"cian": Color(0.3, 0.9, 1.0), "rojo": Color(1.0, 0.2, 0.15), "verde": Color(0.3, 1.0, 0.45),
	"blanco": Color(1.0, 0.95, 0.9), "azul": Color(0.3, 0.4, 1.0),
}
const HALO_ALFA := 0.28

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
	var color_neon := nombre.trim_prefix("neon_").trim_suffix("_halo")
	if nombre.begins_with("neon_") and NEON.has(color_neon):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c: Color = NEON[color_neon]
		if nombre.ends_with("_halo"):
			m.albedo_color = Color(c.r, c.g, c.b, HALO_ALFA)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.no_depth_test = false
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		else:
			m.albedo_color = c.lerp(Color.WHITE, 0.35)
	elif nombre.begins_with("foco_"):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.92, 0.6)
	elif TEXTURAS.has(nombre):
		var t: Array = TEXTURAS[nombre]
		m.albedo_texture = load(t[0])
		m.albedo_color = t[1]
		if float(t[2]) > 0.0:
			m.uv1_scale = Vector3.ONE * float(t[2])
		if nombre in BRILLAN_TEXTURA:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif BRILLAN.has(nombre) or nombre.begins_with("boton_"):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = BRILLAN.get(nombre, (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color.WHITE)
	elif nombre == "pantalla":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = load(PANTALLA)
	elif original is BaseMaterial3D:
		m.albedo_color = (original as BaseMaterial3D).albedo_color
	# Vidrio de las botellas: liso y con brillo; el del mezcal deja ver el gusano. Cromo de los bancos
	if nombre.begins_with("vidrio_"):
		m.roughness = 0.15
		m.metallic_specular = 0.9
		if nombre == "vidrio_refri":
			m.albedo_color = Color(0.75, 0.9, 1.0, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 1.0
		if nombre == "vidrio_mezcal":
			m.albedo_color.a = 0.45
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif nombre == "cromo" or nombre.begins_with("tapa_dorada") or nombre == "oro" or nombre == "ficha_4":
		if nombre == "oro" or nombre == "ficha_4":
			m.albedo_color = Color(0.95, 0.72, 0.2)
			m.metallic_specular = 1.0
	if nombre == "marmol_negro":
		m.roughness = 0.12
		m.metallic_specular = 0.9
	if nombre == "terciopelo":
		m.roughness = 1.0
	if nombre == "cromo" or nombre.begins_with("tapa_dorada") or nombre == "oro" or nombre == "ficha_4":
		m.metallic = 0.85
		m.roughness = 0.3
	# La mancha del bano oscurece lo de abajo (fondo blanco = no cambia nada)
	if nombre == "banho_mancha":
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if nombre == "humedad":
		m.albedo_color = Color(0.12, 0.14, 0.11, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hechos[nombre] = m
	return m
