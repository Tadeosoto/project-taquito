class_name ArbolesModelo
extends Node3D

# Los arboles de Sketchfab del mapa hecho en Blender (arce, realista y roble: models/arboles/, que
# saca tools/blender/mapa/extraer_arboles.gd a resources/mapa/arboles_modelos.json). Cada arbol del
# mapa es [x, z, altura, ancho de copa, nombre] en resources/mapa/<colonia>/arboles_modelo.json (lo
# escribe exportar.py): una malla por nombre con su corteza y sus hojas, un MultiMesh por malla y un
# cilindro de choque por tronco. No van en el .glb de la colonia: repetidos pesaban 44 MB.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
# Hojas recortadas por alfa y sin culling, como los murales
const HOJAS_SHADER := preload("res://shaders/ps1_casa.gdshader")
# La textura de hojas del roble viene casi negra: se aclara (tint de ps1_casa)
const TINTE_HOJAS := {"roble": Color(1.9, 2.0, 1.7)}

# Lo que sube el arbol sobre el piso: el borde del cajete de cantera (tools/blender/mapa/piezas.py)
const BASE_Y := 0.3
const TRONCO_RADIO := 0.035        # del alto, y sus limites (m)
const TRONCO_MIN := 0.15
const TRONCO_MAX := 0.4
const TRONCO_ALTO := 2.0
# Lo que se estira a lo alto un arbol: el roble es muy ancho y salia chaparro junto a los demas
const ESTIRAR := {"roble": 1.4}

@export_file("*.json") var modelos_path := "res://resources/mapa/arboles_modelos.json"
@export_file("*.json") var arboles_path := "res://resources/mapa/santa_mugre/arboles_modelo.json"
@export var visible_hasta := 150.0
# Cada tipo de arbol va en un MultiMesh por celda de CELDA m: con uno solo para toda la colonia su caja
# abarcaba todo y nunca se recortaba (ni los de atras de la camara) ni bajaba de detalle
@export var celda := 24.0
@export var sombras := false


func _ready() -> void:
	var modelos = JSON.parse_string(FileAccess.get_file_as_string(modelos_path))
	var datos = JSON.parse_string(FileAccess.get_file_as_string(arboles_path))
	if not modelos is Dictionary or not datos is Dictionary:
		push_warning("ArbolesModelo: no se pudo leer %s o %s" % [modelos_path, arboles_path])
		return
	var por_nombre := {}
	for arbol: Array in datos["arboles"]:
		if not por_nombre.has(arbol[4]):
			por_nombre[arbol[4]] = []
		por_nombre[arbol[4]].append(arbol)
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Troncos"
	cuerpo.collision_layer = 1
	add_child(cuerpo)
	for nombre: String in por_nombre:
		var modelo: Dictionary = modelos[nombre]
		var malla := _malla(nombre, modelo)
		var celdas := {}
		for arbol: Array in por_nombre[nombre]:
			var altura: float = arbol[2]
			# Uniforme: la altura que pide, sin pasarse del ancho de copa
			var escala := minf(altura, float(arbol[3]) / float(modelo["ancho"]))
			var giro := fposmod(absf(arbol[0] * 12.9898 + arbol[1] * 78.233), 1.0) * TAU
			var posicion := Vector3(arbol[0], BASE_Y, arbol[1])
			var estira: float = ESTIRAR.get(nombre, 1.0)
			var clave := Vector2i(floori(posicion.x / celda), floori(posicion.z / celda))
			if not celdas.has(clave):
				celdas[clave] = []
			celdas[clave].append(Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(escala, escala * estira, escala)), posicion))
			var forma := CylinderShape3D.new()
			forma.radius = clampf(escala * TRONCO_RADIO, TRONCO_MIN, TRONCO_MAX)
			forma.height = TRONCO_ALTO
			var colision := CollisionShape3D.new()
			colision.shape = forma
			colision.position = posicion + Vector3(0.0, TRONCO_ALTO / 2.0, 0.0)
			cuerpo.add_child(colision)
		for clave: Vector2i in celdas:
			var lista: Array = celdas[clave]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = malla
			multi.instance_count = lista.size()
			for i in lista.size():
				multi.set_instance_transform(i, lista[i])
			var instancia := MultiMeshInstance3D.new()
			instancia.name = "%s_%d_%d" % [nombre.capitalize(), clave.x, clave.y]
			instancia.multimesh = multi
			instancia.visibility_range_end = visible_hasta
			instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instancia)


# La corteza y las hojas del arbol `nombre` como un ArrayMesh de dos superficies
# con sus LOD (ImporterMesh.generate_lods: de lejos, menos triangulos)
func _malla(nombre: String, modelo: Dictionary) -> ArrayMesh:
	var malla := ImporterMesh.new()
	for rol in ["corteza", "hojas"]:
		if not modelo.has(rol):
			continue
		var datos: Dictionary = modelo[rol]
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		for v: Array in datos["v"]:
			vertices.append(Vector3(v[0], v[1], v[2]))
		for t: Array in datos["uv"]:
			uvs.append(Vector2(t[0], t[1]))
		var indices := PackedInt32Array()
		for i: float in datos["i"]:
			indices.append(int(i))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		if rol == "hojas":
			# Sin normales las hojas quedaban sin luz y de cerca (desde una azotea o un mirador, con
			# la camara entre la copa) eran bloques negros. Todas hacia arriba: la copa recibe el
			# sol pareja, sin caras oscuras segun hacia donde vea cada tarjeta
			var normales := PackedVector3Array()
			normales.resize(vertices.size())
			normales.fill(Vector3.UP)
			arrays[Mesh.ARRAY_NORMAL] = normales
		var material := ShaderMaterial.new()
		material.shader = HOJAS_SHADER if rol == "hojas" else PS1_SHADER
		material.set_shader_parameter("albedo_texture", load("res://textures/mapa/arbol_%s_%s.png" % [nombre, rol]))
		if rol == "hojas" and TINTE_HOJAS.has(nombre):
			material.set_shader_parameter("tint", TINTE_HOJAS[nombre])
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("jitter_enabled", false)
		malla.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, rol)
	malla.generate_lods(25.0, 60.0, [])
	return malla.get_mesh()
