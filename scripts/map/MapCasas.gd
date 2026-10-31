extends Node3D

# Casas modelo del mapa (Casa Urbi, semi residencial...) en las colonias de
# data/map/casas.json. Los lotes vienen de resources/map/casas_mapa.json, que
# genera tools/map_import/prepare_osm.py: cada lote trae la orilla de su fachada
# (x, z), su giro, su frente, su fondo y su color.
# Son miles, asi que no hay un nodo por casa: las casas se agrupan en celdas de
# CELDA m y cada celda es un MultiMesh por modelo (color por instancia, ver
# shaders/ps1_casa.gdshader) mas un cuerpo con una caja de colision por casa.
# Las celdas se crean y se quitan segun la distancia a target_path, como MapPuntos.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const CASA_SHADER := preload("res://shaders/ps1_casa.gdshader")

const CELDA := 64.0
# Escala permitida para que el modelo llene el frente del lote sin deformarse
const ESCALA_MIN := 0.8
const ESCALA_MAX := 1.25
# Si el modelo no llena el lote, el hueco se tapa con una barda de este alto (m)
const BARDA_ALTO := 2.2
const BARDA_GRUESO := 0.15
# Lo que esta a menos de esto (m) del piso no cuenta para ubicar la fachada:
# algunos modelos traen su pedazo de banqueta o jardin enfrente
const PISO_ALTO := 0.4
# Lo que el nucleo se mete respecto al modelo (m), para no tapar sus muros; al
# frente mas, porque las fachadas tienen cocheras y ventanas metidas
const NUCLEO_MARGEN := 0.12
const NUCLEO_FRENTE := 1.5
# Grafitis en la fachada: la probabilidad por casa es la zona de deterioro (el
# punto, siempre); un segundo con zona - GRAFITI_SEGUNDO. Solo en tramos planos
# del muro de enfrente (ver _paredes), a la altura de la gente.
const GRAFITI_SEGUNDO := 0.4
const GRAFITI_ANCHO := Vector2(0.9, 1.8)
const GRAFITI_ALTO := Vector2(0.35, 2.1)

@export_file("*.json") var casas_path := "res://resources/map/casas_mapa.json"

# modelo (el nombre de casas.json) -> escena
@export var modelos: Dictionary[String, PackedScene] = {}
# modelo -> rango de X (coordenadas de la escena, antes de modelo_rotacion) de
# los triangulos que se usan. Sirve para modelos que traen varias casas en una
# sola malla, como la Urbi (3 de dos pisos y 3 de un piso en hilera).
@export var modelo_rango_x: Dictionary[String, Vector2] = {}
# modelo -> escala del modelo (algunos de Sketchfab vienen en otra unidad: una
# casa de 4 m de frente). Se aplica antes de ajustar al lote con ESCALA_MIN/MAX.
@export var modelo_escala: Dictionary[String, float] = {}
# modelo -> grados extra para que la fachada vea a +Z
@export var modelo_rotacion: Dictionary[String, float] = {}
# modelo -> color del muro en su textura (lo que se pinta del color de cada casa);
# sin valor, la casa sale con sus colores originales
@export var muro_key: Dictionary[String, Color] = {}
@export var muro_tol: Dictionary[String, float] = {}
# modelo -> rectangulos de UV (x0, y0, x1, y1) de sus vidrios, que se rompen
# segun el deterioro de la zona (shaders/ps1_deterioro.gdshaderinc); maximo 8
@export var ventanas_uv: Dictionary[String, PackedVector4Array] = {}
# Modelos que traen piso (banqueta, jardin, calle): se quitan los triangulos
# pegados al piso para que no se salgan del lote
@export var quitar_piso: Array[String] = []
# modelo -> alto (fraccion del modelo) de un nucleo: caja del color de la casa,
# un poco mas chica que el modelo, que tapa los muros que le faltan. La Urbi trae
# 6 casas pegadas sin muros entre ellas: al separarlas quedaban huecas.
@export var nucleo: Dictionary[String, float] = {}
# modelo -> distancia maxima (m) a la que se dibuja, para los modelos pesados
# (escaneos); sin valor, detalle_end o lod_end
@export var modelo_distancia: Dictionary[String, float] = {}
# modelo -> version de pocas caras para lejos (opcional)
@export var modelos_lod: Dictionary[String, PackedScene] = {}
# Modelos a los que Godot les calcula versiones de menos caras (mesh LOD) al
# prepararlos: se dibujan con menos detalle segun lo que miden en pantalla
@export var generar_lods: Array[String] = []
# modelo -> error maximo (fraccion del tamano del modelo) con el que se simplifica
# de una vez la malla completa (meshoptimizer): para modelos con demasiadas caras
@export var modelo_reducir: Dictionary[String, float] = {}

@export var target_path: NodePath
@export var load_radius := 260.0
@export var unload_radius := 330.0
# Hasta aqui (m) se ve el modelo completo; despues el LOD (si hay) hasta lod_end
@export var detalle_end := 120.0
@export var lod_end := 250.0

var _celdas := {}          # Vector2i -> Array de casas (Dictionary)
var _nodos := {}           # Vector2i -> Node3D
var _por_crear := []       # celdas que faltan armar, la mas cercana primero
var _mallas := {}          # modelo -> {mesh, aabb, lod}
var _barda_mesh: BoxMesh
var _target: Node3D
var _timer := 0.0


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(casas_path))
	if not data is Dictionary:
		push_warning("MapCasas: no se pudo leer %s" % casas_path)
		return
	var faltan := {}
	for casa: Dictionary in data["casas"]:
		var modelo: String = casa["modelo"]
		if not _mallas.has(modelo):
			if not modelos.has(modelo) or modelos[modelo] == null:
				faltan[modelo] = faltan.get(modelo, 0) + 1
				continue
			_mallas[modelo] = _preparar_modelo(modelo)
		var key := Vector2i(floori(casa["x"] / CELDA), floori(casa["z"] / CELDA))
		if not _celdas.has(key):
			_celdas[key] = []
		_celdas[key].append(casa)
	for modelo in faltan:
		push_warning("MapCasas: falta el modelo '%s' (%d casas sin dibujar)" % [modelo, faltan[modelo]])

	_barda_mesh = BoxMesh.new()
	var barda_material := ShaderMaterial.new()
	barda_material.shader = CASA_SHADER
	barda_material.set_shader_parameter("albedo_texture", _blanco())
	barda_material.set_shader_parameter("recolor", true)
	barda_material.set_shader_parameter("muro_key", Color.WHITE)
	barda_material.set_shader_parameter("muro_tol", 1.0)
	barda_material.set_shader_parameter("muro_brillo", Vector2(0.0, 10.0))
	barda_material.set_shader_parameter("affine_enabled", false)
	_barda_mesh.material = barda_material

	Calcomanias.cargar()
	_target = get_node_or_null(target_path) as Node3D
	_update_nearby()
	_crear_pendientes(true)


func _process(delta: float) -> void:
	if _target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_nearby()
	_crear_pendientes()


# Arma celdas encoladas hasta gastar el presupuesto del cuadro (CargaCuadro; todas con `de_una`)
func _crear_pendientes(de_una := false) -> void:
	while not _por_crear.is_empty() and (de_una or CargaCuadro.hay()):
		var inicio := Time.get_ticks_usec()
		var key: Vector2i = _por_crear.pop_front()
		if _nodos.has(key):
			continue
		var node := _crear_celda(_celdas[key])
		node.name = "celda_%d_%d" % [key.x, key.y]
		add_child(node)
		_nodos[key] = node
		CargaCuadro.gastar(inicio)


func _update_nearby() -> void:
	var nuevas := []
	for key: Vector2i in _celdas:
		var distance := 0.0
		if _target:
			var p := _target.global_position
			var dx := maxf(maxf(key.x * CELDA - p.x, p.x - (key.x + 1) * CELDA), 0.0)
			var dz := maxf(maxf(key.y * CELDA - p.z, p.z - (key.y + 1) * CELDA), 0.0)
			distance = Vector2(dx, dz).length()
		if distance < CargaCuadro.carga(load_radius) and not _nodos.has(key):
			nuevas.append([distance, key])
		elif distance > CargaCuadro.descarga(unload_radius) and _nodos.has(key):
			_nodos[key].queue_free()
			_nodos.erase(key)
	nuevas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_por_crear = nuevas.map(func(n: Array) -> Vector2i: return n[1])


func _crear_celda(casas: Array) -> Node3D:
	var celda := Node3D.new()
	var por_modelo := {}       # modelo -> [[Transform3D, Color]]
	var bardas := []           # [[Transform3D, Color]] (tambien los nucleos)
	var st_grafitis := SurfaceTool.new()
	st_grafitis.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hay_grafitis := false
	var body := StaticBody3D.new()
	celda.add_child(body)

	for casa: Dictionary in casas:
		var modelo: String = casa["modelo"]
		if not _mallas.has(modelo):
			continue
		var info: Dictionary = _mallas[modelo]
		var aabb: AABB = info["aabb"]
		var ancho: float = casa["ancho"]
		var escala := clampf(ancho / aabb.size.x, ESCALA_MIN, ESCALA_MAX)
		var color := Color.html(casa["color"])
		# Alfa del color -> ps1_casa: 0.5 obra negra, 0 el punto (obra negra y deterioro al maximo)
		if casa.get("punto", false):
			color.a = 0.0
		elif _obra_negra(casa["x"], casa["z"]):
			color.a = 0.5
		# Lote: origen en el centro de la fachada, +Z hacia la calle
		var lote := Transform3D(Basis(Vector3.UP, casa["rotacion_y"]), Vector3(casa["x"], 0.0, casa["z"]))
		var offset := Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.end.z) * escala
		var xform := lote * Transform3D(Basis.from_scale(Vector3.ONE * escala), offset)
		if not por_modelo.has(modelo):
			por_modelo[modelo] = []
		por_modelo[modelo].append([xform, color])

		var size := aabb.size * escala
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.transform = lote * Transform3D(Basis.IDENTITY, Vector3(0.0, size.y / 2.0, -size.z / 2.0))
		body.add_child(shape)

		hay_grafitis = _grafitis(st_grafitis, casa, lote, info, escala) or hay_grafitis

		if nucleo.has(modelo):
			var core := Vector3(size.x - 2.0 * NUCLEO_MARGEN, size.y * nucleo[modelo], size.z - NUCLEO_MARGEN - NUCLEO_FRENTE)
			var center := Vector3(0.0, core.y / 2.0, -NUCLEO_FRENTE - core.z / 2.0)
			bardas.append([lote * Transform3D(Basis.from_scale(core), center), color])

		# Bardas a los lados si el modelo no llena el frente
		var hueco := (ancho - size.x) / 2.0
		if hueco > 0.2:
			for side in [-1.0, 1.0]:
				var center := Vector3(side * (size.x + hueco) / 2.0, BARDA_ALTO / 2.0, -BARDA_GRUESO / 2.0)
				bardas.append([lote * Transform3D(Basis.from_scale(Vector3(hueco, BARDA_ALTO, BARDA_GRUESO)), center), color])

	for modelo: String in por_modelo:
		var info: Dictionary = _mallas[modelo]
		var lod: Mesh = info["lod"]
		var end: float = modelo_distancia.get(modelo, detalle_end if lod else lod_end)
		var detalle := _multimesh(info["mesh"], por_modelo[modelo], 0.0, end)
		celda.add_child(detalle)
		if lod:
			celda.add_child(_multimesh(lod, por_modelo[modelo], end, lod_end))
	if not bardas.is_empty():
		celda.add_child(_multimesh(_barda_mesh, bardas, 0.0, detalle_end))
	if hay_grafitis:
		var grafitis := MeshInstance3D.new()
		grafitis.mesh = st_grafitis.commit()
		grafitis.material_override = Calcomanias.material
		grafitis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grafitis.visibility_range_end = detalle_end
		celda.add_child(grafitis)
	return celda


# Grafitis en la fachada de una casa, en tramos planos de su muro de enfrente.
# Devuelve si puso alguno.
func _grafitis(st: SurfaceTool, casa: Dictionary, lote: Transform3D, info: Dictionary, escala: float) -> bool:
	var paredes: Array = info["paredes"]
	if paredes.is_empty() or Calcomanias.grafitis.is_empty():
		return false
	var zona := 1.0 if casa.get("punto", false) else Deterioro.zona(casa["x"], casa["z"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(casa["x"] * 10.0), roundi(casa["z"] * 10.0))) * 7 + 3
	var aabb: AABB = info["aabb"]
	var puso := false
	for umbral in [zona, zona - GRAFITI_SEGUNDO]:
		if rng.randf() >= umbral:
			break
		# Pared de lote (x0, x1, z en la malla -> metros del lote, fachada en z = 0)
		var pared: Vector3 = paredes[rng.randi() % paredes.size()]
		var x0 := (pared.x - aabb.get_center().x) * escala
		var x1 := (pared.y - aabb.get_center().x) * escala
		var z := (pared.z - aabb.end.z) * escala + 0.015
		var ejes := lote * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z))
		Calcomanias.grafiti(st, ejes, rng, x0 + 0.1, x1 - 0.1, GRAFITI_ALTO.x * escala, GRAFITI_ALTO.y * escala, GRAFITI_ANCHO)
		puso = true
	return puso


func _multimesh(mesh: Mesh, instancias: Array, begin: float, end: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = instancias.size()
	for i in instancias.size():
		multimesh.set_instance_transform(i, instancias[i][0])
		multimesh.set_instance_color(i, instancias[i][1])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_begin = begin
	instance.visibility_range_end = end
	return instance


# Junta todas las mallas del modelo (o su rango de X) en un ArrayMesh, una
# superficie por material, ya girado para que la fachada vea a +Z
func _preparar_modelo(modelo: String) -> Dictionary:
	var giro := Transform3D(Basis(Vector3.UP, deg_to_rad(modelo_rotacion.get(modelo, 0.0))).scaled(
		Vector3.ONE * modelo_escala.get(modelo, 1.0)), Vector3.ZERO)
	var rango: Vector2 = modelo_rango_x.get(modelo, Vector2(-INF, INF))
	var mesh := _hornear(modelos[modelo], giro, rango, modelo)
	var lod: ArrayMesh = null
	if modelos_lod.has(modelo) and modelos_lod[modelo] != null:
		lod = _hornear(modelos_lod[modelo], giro, rango, modelo)
	if modelo in quitar_piso:
		var piso := mesh.get_aabb().position.y + PISO_ALTO
		mesh = _sin_piso(mesh, piso)
		if lod:
			lod = _sin_piso(lod, piso)
	if modelo_reducir.has(modelo):
		mesh = _reducida(mesh, modelo_reducir[modelo])
	var aabb := _aabb_fachada(mesh)
	var paredes := _paredes(mesh, aabb)
	if modelo in generar_lods:
		mesh = _con_lods(mesh)
	return {"mesh": mesh, "aabb": aabb, "lod": lod, "paredes": paredes}


# Tramos planos del muro de enfrente donde cabe un grafiti: [x0, x1, z] (Vector3,
# en la malla). Cada PARED_PASO m de ancho se busca la cara (casi vertical, viendo
# a +-Z) mas adelante en varias alturas de GRAFITI_ALTO; la columna sirve si en
# todas es la misma cara plana. Tramos de columnas seguidas a la misma z.
const PARED_PASO := 0.2
const PARED_MIN := 1.0

func _paredes(mesh: ArrayMesh, aabb: AABB) -> Array:
	var caras := []   # [a, b, c] en xy y z de la cara
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))
		for t in range(0, idx.size(), 3):
			var a := v[idx[t]]
			var b := v[idx[t + 1]]
			var c := v[idx[t + 2]]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-8 or absf(n.normalized().z) < 0.95:
				continue
			caras.append([Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y), (a.z + b.z + c.z) / 3.0])
	var alturas := []
	for k in 4:
		alturas.append(aabb.position.y + lerpf(GRAFITI_ALTO.x, GRAFITI_ALTO.y, k / 3.0))
	var tramos := []
	var actual := Vector3(NAN, NAN, NAN)
	var x := aabb.position.x + PARED_PASO / 2.0
	while x < aabb.end.x:
		var z := NAN
		for y: float in alturas:
			var frente := -INF
			for cara: Array in caras:
				if cara[3] > frente and Geometry2D.point_is_inside_triangle(Vector2(x, y), cara[0], cara[1], cara[2]):
					frente = cara[3]
			if frente < aabb.end.z - 3.0 or (not is_nan(z) and absf(frente - z) > 0.04):
				z = NAN
				break
			z = frente if is_nan(z) else z
		if not is_nan(z) and not is_nan(actual.z) and absf(z - actual.z) <= 0.04:
			actual.y = x + PARED_PASO / 2.0
		else:
			if not is_nan(actual.z) and actual.y - actual.x >= PARED_MIN:
				tramos.append(actual)
			actual = Vector3(x - PARED_PASO / 2.0, x + PARED_PASO / 2.0, z) if not is_nan(z) else Vector3(NAN, NAN, NAN)
		x += PARED_PASO
	if not is_nan(actual.z) and actual.y - actual.x >= PARED_MIN:
		tramos.append(actual)
	return tramos


# La malla con cada superficie en su nivel de detalle mas simple cuyo error no pasa
# de `error` (fraccion del tamano)
func _reducida(mesh: ArrayMesh, error: float) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface), [], {},
			mesh.surface_get_material(surface))
	importer.generate_lods(60.0, 0.0, [])
	var result := ArrayMesh.new()
	for surface in importer.get_surface_count():
		var arrays := importer.get_surface_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for lod in importer.get_surface_lod_count(surface):
			if importer.get_surface_lod_size(surface, lod) <= error:
				indices = importer.get_surface_lod_indices(surface, lod)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compactar(arrays, indices))
		result.surface_set_material(surface, importer.get_surface_material(surface))
	return result


# La misma malla con niveles de detalle (meshoptimizer, como el importador)
func _con_lods(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface), [], {},
			mesh.surface_get_material(surface))
	importer.generate_lods(60.0, 0.0, [])
	return importer.get_mesh()


func _hornear(scene: PackedScene, giro: Transform3D, rango: Vector2, modelo: String) -> ArrayMesh:
	var root := scene.instantiate() as Node3D
	var tools := {}   # Material -> SurfaceTool
	_juntar(root, Transform3D.IDENTITY, giro, rango, tools, modelo)
	var result := ArrayMesh.new()
	for material: Material in tools:
		var st: SurfaceTool = tools[material]
		st.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, material)
	root.free()
	return result


func _juntar(node: Node, xform: Transform3D, giro: Transform3D, rango: Vector2, tools: Dictionary, modelo: String) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var material := _material_casa(instance.get_active_material(surface), modelo)
			var piece := _recortar_x(instance.mesh, surface, xform, rango)
			if piece == null:
				continue
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
			(tools[material] as SurfaceTool).append_from(piece, 0, giro * xform)
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * (child as Node3D).transform
		_juntar(child, child_xform, giro, rango, tools, modelo)


# La superficie con solo los triangulos cuyo centro (en `xform`) cae en `rango`
# de X; null si no queda ninguno
func _recortar_x(mesh: Mesh, surface: int, xform: Transform3D, rango: Vector2) -> Mesh:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null:
		indices = PackedInt32Array(range(vertices.size()))
	if rango.x == -INF and rango.y == INF:
		var whole := ArrayMesh.new()
		whole.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return whole
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		var x := (xform * ((vertices[indices[t]] + vertices[indices[t + 1]] + vertices[indices[t + 2]]) / 3.0)).x
		if x >= rango.x and x <= rango.y:
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	if kept.is_empty():
		return null
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compactar(arrays, kept))
	return result


# Arrays de superficie con solo los vertices que usan `indices` (si no, el AABB
# de la malla sigue contando los triangulos que se quitaron)
func _compactar(arrays: Array, indices: PackedInt32Array) -> Array:
	var remap := {}
	var nuevos := PackedInt32Array()
	for i in indices:
		if not remap.has(i):
			remap[i] = remap.size()
		nuevos.append(remap[i])
	var orden: Array = remap.keys()
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for canal in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var source = arrays[canal]
		if source == null or source.is_empty():
			continue
		var copia = source.duplicate()
		copia.resize(orden.size())
		for j in orden.size():
			copia[j] = source[orden[j]]
		result[canal] = copia
	if arrays[Mesh.ARRAY_TANGENT] != null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
		var source: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var copia := PackedFloat32Array()
		copia.resize(orden.size() * 4)
		for j in orden.size():
			for c in 4:
				copia[j * 4 + c] = source[orden[j] * 4 + c]
		result[Mesh.ARRAY_TANGENT] = copia
	result[Mesh.ARRAY_INDEX] = nuevos
	return result


func _sin_piso(mesh: ArrayMesh, piso: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null:
			indices = PackedInt32Array(range(vertices.size()))
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			if vertices[indices[t]].y < piso and vertices[indices[t + 1]].y < piso and vertices[indices[t + 2]].y < piso:
				continue
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
		if kept.is_empty():
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compactar(arrays, kept))
		result.surface_set_material(result.get_surface_count() - 1, mesh.surface_get_material(surface))
	return result


# AABB del modelo sin lo que esta pegado al piso (banqueta, jardin): asi la
# fachada, y no la banqueta, queda en la orilla del lote. La altura es la de todo.
func _aabb_fachada(mesh: ArrayMesh) -> AABB:
	var full := mesh.get_aabb()
	var result := AABB()
	var first := true
	for surface in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if v.y < full.position.y + PISO_ALTO:
				continue
			if first:
				result = AABB(v, Vector3.ZERO)
				first = false
			else:
				result = result.expand(v)
	if first:
		return full
	result.position.y = full.position.y
	result.size.y = full.size.y
	return result


var _materiales := {}   # [material original, modelo] -> ShaderMaterial

# El material PS1 del import (TiendaPostImport) pasado a ps1_casa
func _material_casa(source: Material, modelo: String) -> Material:
	var key := [source, modelo]
	if _materiales.has(key):
		return _materiales[key]
	var material := ShaderMaterial.new()
	material.shader = CASA_SHADER
	var texture: Texture2D = _blanco()
	var tint := Color.WHITE
	if source is ShaderMaterial:
		var albedo = (source as ShaderMaterial).get_shader_parameter("albedo_texture")
		if albedo is Texture2D:
			texture = albedo
		var source_tint = (source as ShaderMaterial).get_shader_parameter("tint")
		if source_tint is Color:
			tint = source_tint
	elif source is BaseMaterial3D:
		tint = (source as BaseMaterial3D).albedo_color
		if (source as BaseMaterial3D).albedo_texture:
			texture = (source as BaseMaterial3D).albedo_texture
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("affine_enabled", false)
	# El wobble mueve distinto dos capas pegadas (muro y aplanado) y se pelean a cuadros
	material.set_shader_parameter("wobble_enabled", false)
	if muro_key.has(modelo):
		material.set_shader_parameter("recolor", true)
		material.set_shader_parameter("muro_key", muro_key[modelo])
		material.set_shader_parameter("muro_tol", muro_tol.get(modelo, 0.12))
	if ventanas_uv.has(modelo):
		material.set_shader_parameter("ventanas", ventanas_uv[modelo])
		material.set_shader_parameter("n_ventanas", mini(ventanas_uv[modelo].size(), 8))
	_materiales[key] = material
	return material


var _textura_blanca: ImageTexture

func _blanco() -> ImageTexture:
	if _textura_blanca == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
		image.fill(Color.WHITE)
		_textura_blanca = ImageTexture.create_from_image(image)
	return _textura_blanca


# Casas en obra negra segun el deterioro de su zona (fraccion de las casas en
# OBRA_NEGRA_ZONAS, interpolada; el usuario: 5 % en media, 15 % en la maxima)
const OBRA_NEGRA_ZONAS := [0.2, 0.5, 0.8]
const OBRA_NEGRA := [0.0, 0.05, 0.15]


func _obra_negra(x: float, z: float) -> bool:
	var zona := Deterioro.zona(x, z)
	var fraccion: float = OBRA_NEGRA[-1]
	if zona <= OBRA_NEGRA_ZONAS[0]:
		fraccion = OBRA_NEGRA[0]
	else:
		for i in range(1, OBRA_NEGRA_ZONAS.size()):
			if zona <= OBRA_NEGRA_ZONAS[i]:
				fraccion = lerpf(OBRA_NEGRA[i - 1], OBRA_NEGRA[i], inverse_lerp(OBRA_NEGRA_ZONAS[i - 1], OBRA_NEGRA_ZONAS[i], zona))
				break
	# Semilla fija por lote, para que la misma casa siempre salga igual
	var s := absi(hash(Vector2i(roundi(x * 10.0), roundi(z * 10.0)))) % 10000
	return s / 10000.0 < fraccion
