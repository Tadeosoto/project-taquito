class_name SueloPasto
extends RefCounted

# Configura un material de shaders/ps1_suelo.gdshader para que lleve pasto.
# Lo usan MapPostImport (pisos de OSM2World) y MapPasto (el plano Suelo de
# map_test): misma mascara y texturas, asi donde se enciman se ven igual.
# modo: 0 = solo su textura, 1 = pasto donde la mascara satelital dice
# (textures/map/pasto_mascara.png, tools/map_import/make_vegetacion.py), 2 = todo pasto.

const MASCARA := "res://textures/map/pasto_mascara.png"
const MASCARA_JSON := "res://resources/map/pasto_mascara.json"


# Que piso queda encima donde OSM2World los deja a la misma altura (6,800 m2 en el mapa):
# el asfalto sobre el empedrado, la banqueta, el pasto y la tierra. Ver ps1_suelo.
static func capa(material: ShaderMaterial) -> void:
	var modo = material.get_shader_parameter("modo")
	var piso = material.get_shader_parameter("piso_tipo")
	var valor := 0.0
	if modo == 2:
		valor = 1.0
	elif piso == 2:
		valor = 2.0
	elif piso == 3:
		valor = 3.0
	elif piso == 1:
		valor = 4.0
	material.set_shader_parameter("capa", valor)


# Los otros pastos (tools/map_import/make_pastos.gd). Los materiales de los cuadros ya estan
# horneados: esos los pasa MapStreamer por aqui al cargar.
static func variedades(material: ShaderMaterial) -> void:
	material.set_shader_parameter("variedad", true)
	material.set_shader_parameter("pasto_cuidado_texture", load("res://textures/map/pasto_cuidado.png"))
	material.set_shader_parameter("pasto_crecido_texture", load("res://textures/map/pasto_crecido.png"))
	material.set_shader_parameter("pasto_podrido_texture", load("res://textures/map/pasto_podrido.png"))


static func configurar(material: ShaderMaterial, modo: int) -> void:
	material.set_shader_parameter("modo", modo)
	if modo == 0:
		return
	material.set_shader_parameter("pasto_texture", load("res://textures/map/pasto.png"))
	material.set_shader_parameter("pasto_seco_texture", load("res://textures/map/pasto_seco.png"))
	variedades(material)
	if modo != 1:
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(MASCARA_JSON)) \
			if FileAccess.file_exists(MASCARA_JSON) else null
	if not info is Dictionary or not ResourceLoader.exists(MASCARA):
		push_warning("SueloPasto: falta la mascara de pasto (corre make_vegetacion.py); la tierra queda sin pasto")
		material.set_shader_parameter("modo", 0)
		return
	material.set_shader_parameter("mascara_pasto", load(MASCARA))
	material.set_shader_parameter("mascara_origen", Vector2(info["x0"], info["z0"]))
	material.set_shader_parameter("mascara_tamano", Vector2(info["ancho"], info["alto"]) * float(info["metros_por_pixel"]))
