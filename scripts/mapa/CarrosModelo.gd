class_name CarrosModelo
extends RefCounted

# Los carros de Sketchfab del mapa (models/vehiculos/: Grand Vitara, Tsuru, vocho y la van blanca, que
# baja fetch_sketchfab.py). Cada modelo viene con la escala y los giros de su FBX, asi que `malla()` lo
# aplana a una sola ArrayMesh limpia: largo a lo largo de Z, centrado en X y Z, con las llantas en
# y = 0 y del largo que pide LARGOS. Sin pintar: cada carro conserva su color y su textura de
# Sketchfab (pintarlos con el tint del shader no quedaba bien, JJ).

const MODELOS := ["grand_vitara", "tsuru", "vocho", "van_blanca"]
# Largo en metros de cada uno (los de Sketchfab traen medidas inventadas)
const LARGOS := {"grand_vitara": 4.0, "tsuru": 4.3, "vocho": 4.0, "van_blanca": 5.0}
# Modelos cuyo material no trae textura de color (el import deja un color liso): su foto
const FOTOS := {"tsuru": "res://models/vehiculos/tsuru/textures/Material.001_emissive.jpeg"}

static var _base: Dictionary = {}      # nombre -> {malla, ancho, alto, largo}
static var _sin: Dictionary = {}       # nombre -> {malla, ruedas, suelo}
static var _quemados: Dictionary = {}  # nombre -> ArrayMesh


# La carroceria limpia de `nombre` (sin pintar): {malla, ancho, alto, largo}
static func base(nombre: String) -> Dictionary:
	if _base.has(nombre):
		return _base[nombre]
	var raiz := (load("res://models/vehiculos/%s/%s.scn" % [nombre, nombre]) as PackedScene).instantiate() as Node3D
	var piezas: Array = []     # [{arrays, material}]
	var caja := AABB()
	var primero := true
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		var xf := _relativa(mi, raiz)
		var normal := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var arrays := _limpias(mi.mesh.surface_get_arrays(s))
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for i in v.size():
				v[i] = xf * v[i]
				if i < n.size():
					n[i] = (normal * n[i]).normalized()
				caja = AABB(v[i], Vector3.ZERO) if primero else caja.expand(v[i])
				primero = false
			arrays[Mesh.ARRAY_VERTEX] = v
			if n.size() > 0:
				arrays[Mesh.ARRAY_NORMAL] = n
			var material := mi.mesh.surface_get_material(s)
			# El Tsuru solo trae su foto como textura emisiva: sin esto sale gris liso
			if material is ShaderMaterial and FOTOS.has(nombre):
				material = material.duplicate()
				material.set_shader_parameter("albedo_texture", load(FOTOS[nombre]))
			piezas.append({"arrays": arrays, "material": material})
	raiz.free()
	# El largo a lo largo de Z (si no, un cuarto de vuelta), y a la escala que pide
	var giro := Basis.IDENTITY
	if caja.size.x > caja.size.z:
		giro = Basis(Vector3.UP, PI / 2.0)
	var largo := maxf(caja.size.x, caja.size.z)
	var escala: float = LARGOS[nombre] / largo
	var centro := caja.get_center()
	var cuerpo := ArrayMesh.new()
	var limite := AABB()
	primero = true
	for p in piezas:
		var arrays: Array = p["arrays"]
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in v.size():
			v[i] = giro * ((v[i] - Vector3(centro.x, caja.position.y, centro.z)) * escala)
			if i < n.size():
				n[i] = giro * n[i]
			limite = AABB(v[i], Vector3.ZERO) if primero else limite.expand(v[i])
			primero = false
		arrays[Mesh.ARRAY_VERTEX] = v
		if n.size() > 0:
			arrays[Mesh.ARRAY_NORMAL] = n
		cuerpo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		cuerpo.surface_set_material(cuerpo.get_surface_count() - 1, p["material"])
	var datos := {"malla": cuerpo, "ancho": limite.size.x, "alto": limite.size.y, "largo": limite.size.z}
	_base[nombre] = datos
	return datos


# La malla de `nombre`, la misma (compartida) para todos los carros de ese modelo
static func malla(nombre: String) -> ArrayMesh:
	return base(nombre)["malla"]


# La carroceria de `nombre` sin llantas (las piezas sueltas de ~0.3 x 0.65 x 0.65 m que tocan el piso;
# la de refaccion del Vitara se queda): {malla, ruedas (centros en el marco de la malla), suelo (lo
# que sube la parte mas baja del cuerpo sobre el piso)}. Para el carro "sobre ladrillos".
static func sin_ruedas(nombre: String) -> Dictionary:
	if _sin.has(nombre):
		return _sin[nombre]
	var origen := malla(nombre)
	var nueva := ArrayMesh.new()
	var ruedas: Array[Vector3] = []
	var suelo := INF
	for s in origen.get_surface_count():
		var arrays := _limpias(origen.surface_get_arrays(s))
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var padre := {}
		for p in v:
			padre[_llave(p)] = _llave(p)
		for t in idx.size() / 3:
			var raiz = _raiz(padre, _llave(v[idx[t * 3]]))
			for j in [1, 2]:
				var otra = _raiz(padre, _llave(v[idx[t * 3 + j]]))
				if otra != raiz:
					padre[otra] = raiz
		var cajas := {}      # raiz -> AABB
		for t in idx.size() / 3:
			var r = _raiz(padre, _llave(v[idx[t * 3]]))
			for j in 3:
				var p := v[idx[t * 3 + j]]
				cajas[r] = AABB(p, Vector3.ZERO) if not cajas.has(r) else (cajas[r] as AABB).expand(p)
		var son_rueda := {}
		for r in cajas:
			var c: AABB = cajas[r]
			if c.position.y < 0.05 and c.size.y > 0.5 and c.size.y < 0.85 and c.size.x < 0.45:
				son_rueda[r] = true
				ruedas.append(c.get_center())
		var nuevos := PackedInt32Array()
		for t in idx.size() / 3:
			var r = _raiz(padre, _llave(v[idx[t * 3]]))
			if son_rueda.has(r):
				continue
			for j in 3:
				nuevos.append(idx[t * 3 + j])
				suelo = minf(suelo, v[idx[t * 3 + j]].y)
		if nuevos.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = nuevos
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		nueva.surface_set_material(nueva.get_surface_count() - 1, origen.surface_get_material(s))
	var datos := {"malla": nueva, "ruedas": ruedas, "suelo": suelo}
	_sin[nombre] = datos
	return datos


# La malla de `nombre` quemada: su textura con el shader de hollin y sin vidrios (ps1_quemado)
static func quemado(nombre: String) -> ArrayMesh:
	if _quemados.has(nombre):
		return _quemados[nombre]
	var origen := malla(nombre)
	var quemada := ArrayMesh.new()
	var shader := load("res://shaders/ps1_quemado.gdshader") as Shader
	for s in origen.get_surface_count():
		quemada.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _limpias(origen.surface_get_arrays(s)))
		var material := ShaderMaterial.new()
		material.shader = shader
		var anterior := origen.surface_get_material(s)
		if anterior is ShaderMaterial:
			material.set_shader_parameter("albedo_texture", anterior.get_shader_parameter("albedo_texture"))
		material.set_shader_parameter("affine_enabled", false)
		quemada.surface_set_material(s, material)
	_quemados[nombre] = quemada
	return quemada


static func _llave(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))


static func _raiz(padre: Dictionary, k: Vector3i) -> Vector3i:
	while padre[k] != k:
		padre[k] = padre[padre[k]]
		k = padre[k]
	return k


# Un MeshInstance3D con el carro `nombre`
static func crear(nombre: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla(nombre)
	return mi


static func _limpias(arrays: Array) -> Array:
	var limpias := []
	limpias.resize(Mesh.ARRAY_MAX)
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		limpias[k] = arrays[k]
	return limpias


static func _relativa(nodo: Node3D, raiz: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != raiz and actual is Node3D:
		xf = (actual as Node3D).transform * xf
		actual = actual.get_parent()
	return xf
