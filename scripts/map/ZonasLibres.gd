class_name ZonasLibres
extends RefCounted

# Terrenos que algo grande se aparta en el mapa de OSM (map_test), para que los constructores no
# pongan casas encima. El Yonke (YonkeMapa) mide 28 x 40 m y su baldio de map_test era de 12 m: al
# entrar al arbol registra su patio y MapCasas se salta las casas modelo que lo pisan.
# Se registra en _enter_tree (antes de cualquier _ready, asi MapCasas ya lo ve al cargar) y se quita
# en _exit_tree. Estatico: sin autoload (lo cargan herramientas con -s).

static var _zonas: Array[Dictionary] = []    # {"quien": Node, "inversa": Transform3D, "rect": Rect2}


# `rect` en coordenadas del nodo, en el plano x/z (x, z, ancho, largo)
static func agregar(quien: Node3D, rect: Rect2) -> void:
	quitar(quien)
	_zonas.append({"quien": quien, "inversa": quien.global_transform.affine_inverse(), "rect": rect})
	# Lo recortado antes ya no vale, y los cuadros que ya estaban cargados se recortan ahora
	_recortadas.clear()
	for c: Dictionary in _cuadros:
		if is_instance_valid(c["nodo"]) and cruza(c["x0"], c["x1"], c["z0"], c["z1"]):
			recortar(c["nodo"])


static func quitar(quien: Node) -> void:
	for i in range(_zonas.size() - 1, -1, -1):
		if _zonas[i]["quien"] == quien or not is_instance_valid(_zonas[i]["quien"]):
			_zonas.remove_at(i)


static func ocupado(punto: Vector3) -> bool:
	for zona: Dictionary in _zonas:
		var p: Vector3 = (zona["inversa"] as Transform3D) * punto
		if (zona["rect"] as Rect2).has_point(Vector2(p.x, p.z)):
			return true
	return false


# Si alguna esquina o el centro del lote de una casa (origen en el centro de la fachada, se mete
# `fondo` hacia su -Z) cae en una zona
static func pisa_lote(x: float, z: float, rotacion_y: float, ancho: float, fondo: float) -> bool:
	if _zonas.is_empty():
		return false
	var lote := Transform3D(Basis(Vector3.UP, rotacion_y), Vector3(x, 0.0, z))
	for local in [Vector3(-ancho / 2.0, 0, 0), Vector3(ancho / 2.0, 0, 0), Vector3(-ancho / 2.0, 0, -fondo),
			Vector3(ancho / 2.0, 0, -fondo), Vector3(0, 0, -fondo / 2.0)]:
		if ocupado(lote * local):
			return true
	return false


# Si la caja en el mundo de alguna zona se encima con el rectangulo x0..x1, z0..z1
static func cruza(x0: float, x1: float, z0: float, z1: float) -> bool:
	var otro := Rect2(x0, z0, x1 - x0, z1 - z0)
	for zona: Dictionary in _zonas:
		var mundo := (zona["inversa"] as Transform3D).affine_inverse()
		var r: Rect2 = zona["rect"]
		var caja := Rect2()
		var primera := true
		for esquina in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var p := mundo * Vector3(esquina.x, 0.0, esquina.y)
			if primera:
				caja = Rect2(p.x, p.z, 0.0, 0.0)
				primera = false
			else:
				caja = caja.expand(Vector2(p.x, p.z))
		if caja.intersects(otro, true):
			return true
	return false


# Los cuadros horneados del mapa de OSM (MapStreamer) traen edificios de OSM pegados en mallas
# grandes: aqui se les quitan los triangulos que estan en una zona y arriba de `piso` (las calles,
# banquetas y el suelo se quedan). La malla recortada se guarda por malla original, asi cada cuadro
# se recorta una vez aunque se cargue y descargue. Tambien recorta su choque (ConcavePolygonShape3D).
static var _recortadas := {}    # malla original -> recortada (null: no tenia nada que quitar)
static var _cuadros: Array[Dictionary] = []   # los cuadros cargados: {nodo, x0, x1, z0, z1}


# MapStreamer avisa de cada cuadro que carga: se recorta si pisa una zona, y se recuerda por si
# una zona llega despues
static func cuadro_cargado(nodo: Node3D, x0: float, x1: float, z0: float, z1: float) -> void:
	for i in range(_cuadros.size() - 1, -1, -1):
		if not is_instance_valid(_cuadros[i]["nodo"]):
			_cuadros.remove_at(i)
	_cuadros.append({"nodo": nodo, "x0": x0, "x1": x1, "z0": z0, "z1": z1})
	if cruza(x0, x1, z0, z1):
		recortar(nodo)


static func recortar(nodo: Node3D, piso := 0.4) -> void:
	var mallas: Array[Node] = nodo.find_children("*", "MeshInstance3D", true, false)
	if nodo is MeshInstance3D:
		mallas.append(nodo)
	for malla_nodo in mallas:
		var mi := malla_nodo as MeshInstance3D
		if mi.mesh == null or _recortadas.values().has(mi.mesh):
			continue
		if not _recortadas.has(mi.mesh):
			_recortadas[mi.mesh] = _recortar_malla(mi.mesh as ArrayMesh, mi.global_transform, piso)
		if _recortadas[mi.mesh] != null:
			mi.mesh = _recortadas[mi.mesh]
	for forma_nodo in nodo.find_children("*", "CollisionShape3D", true, false):
		var cs := forma_nodo as CollisionShape3D
		var forma := cs.shape as ConcavePolygonShape3D
		if forma == null:
			continue
		if not _recortadas.has(forma):
			var caras := forma.get_faces()
			var quedan := PackedVector3Array()
			var xf := cs.global_transform
			for i in range(0, caras.size(), 3):
				if not _fuera(xf * caras[i], xf * caras[i + 1], xf * caras[i + 2], piso):
					quedan.append_array([caras[i], caras[i + 1], caras[i + 2]])
			var nueva: ConcavePolygonShape3D = null
			if quedan.size() != caras.size():
				nueva = ConcavePolygonShape3D.new()
				nueva.set_faces(quedan)
			_recortadas[forma] = nueva
		if _recortadas[forma] != null:
			cs.shape = _recortadas[forma]


# Un triangulo que hay que quitar: su centro en una zona y algun vertice arriba del piso
static func _fuera(a: Vector3, b: Vector3, c: Vector3, piso: float) -> bool:
	return maxf(a.y, maxf(b.y, c.y)) > piso and ocupado((a + b + c) / 3.0)


# null si no cambio nada
static func _recortar_malla(malla: ArrayMesh, xf: Transform3D, piso: float) -> ArrayMesh:
	if malla == null:
		return null
	var nueva := ArrayMesh.new()
	var cambio := false
	for s in malla.get_surface_count():
		var arrays := malla.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size():
				indices[i] = i
		var quedan := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if _fuera(xf * vertices[indices[i]], xf * vertices[indices[i + 1]], xf * vertices[indices[i + 2]], piso):
				cambio = true
			else:
				quedan.append_array([indices[i], indices[i + 1], indices[i + 2]])
		arrays[Mesh.ARRAY_INDEX] = quedan
		# Las LOD de la malla original ya no sirven: sin ellas
		nueva.add_surface_from_arrays(malla.surface_get_primitive_type(s), arrays)
		nueva.surface_set_material(s, malla.surface_get_material(s))
	return nueva if cambio else null
