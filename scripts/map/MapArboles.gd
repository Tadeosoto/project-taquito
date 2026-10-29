extends Node3D

# Arboles del mapa, donde el satelite ve copas (Meta/WRI Canopy Height, ver
# tools/map_import/fetch_satelite.py y make_vegetacion.py). Cada arbol de
# resources/map/arboles_mapa.json trae [x, z, altura, radio de copa, variante].
# Como MapCasas: celdas de CELDA m, un MultiMesh por variante en cada celda (verde
# por instancia, ver shaders/ps1_arbol.gdshader) y un cuerpo con un cilindro por
# tronco. Las celdas se crean y se quitan segun la distancia a target_path.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const ARBOL_SHADER := preload("res://shaders/ps1_arbol.gdshader")
const ARBOL_TEXTURA := preload("res://textures/map/arbol.png")

const CELDA := 64.0
# Grueso del tronco respecto al radio de la copa, y sus limites (m)
const TRONCO_RADIO := 0.09
const TRONCO_MIN := 0.12
const TRONCO_MAX := 0.45

# Copas por variante: [centro (x, y, z), radios (x, y, z)] en un arbol de 1 m de
# alto y 1 m de radio de copa (cada instancia se escala a su altura y radio)
const COPAS := [
	# 0 frondoso (fresno, ficus, mezquite): tres bolas anchas
	[[Vector3(0.0, 0.62, 0.0), Vector3(1.0, 0.3, 1.0)],
	 [Vector3(0.35, 0.74, 0.2), Vector3(0.62, 0.24, 0.62)],
	 [Vector3(-0.3, 0.76, -0.25), Vector3(0.6, 0.22, 0.6)]],
	# 1 alto (eucalipto, pino): una copa larga y angosta
	[[Vector3(0.0, 0.66, 0.0), Vector3(1.0, 0.34, 1.0)],
	 [Vector3(0.1, 0.9, 0.05), Vector3(0.6, 0.12, 0.6)]],
]
# Hasta donde (fraccion de la altura) sube el tronco en cada variante
const TRONCO_ALTO := [0.5, 0.6]
# Verdes de las copas por variante (se mezclan dos al azar por arbol)
const VERDES := [
	[Color(0.62, 0.78, 0.42), Color(0.45, 0.66, 0.34), Color(0.74, 0.8, 0.46), Color(0.52, 0.72, 0.5)],
	[Color(0.6, 0.72, 0.58), Color(0.5, 0.64, 0.5), Color(0.68, 0.74, 0.6)],
]

@export_file("*.json") var arboles_path := "res://resources/map/arboles_mapa.json"
@export var target_path: NodePath
@export var load_radius := 260.0
@export var unload_radius := 330.0
@export var visible_hasta := 260.0
@export var sombras := true

var _celdas := {}          # Vector2i -> Array de arboles
var _nodos := {}           # Vector2i -> Node3D
var _por_crear := []       # celdas que faltan armar, la mas cercana primero
var _mallas: Array[ArrayMesh] = []
var _target: Node3D
var _timer := 0.0


func _ready() -> void:
	if not FileAccess.file_exists(arboles_path):
		push_warning("MapArboles: no existe %s (corre make_vegetacion.py)" % arboles_path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(arboles_path))
	if not data is Dictionary:
		push_warning("MapArboles: no se pudo leer %s" % arboles_path)
		return
	for arbol: Array in data["arboles"]:
		var key := Vector2i(floori(arbol[0] / CELDA), floori(arbol[1] / CELDA))
		if not _celdas.has(key):
			_celdas[key] = []
		_celdas[key].append(arbol)

	var material := ShaderMaterial.new()
	material.shader = ARBOL_SHADER
	material.set_shader_parameter("albedo_texture", ARBOL_TEXTURA)
	material.set_shader_parameter("affine_enabled", false)
	for variante in COPAS.size():
		var mesh := _malla_arbol(variante)
		mesh.surface_set_material(0, material)
		_mallas.append(mesh)

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
		if distance < load_radius and not _nodos.has(key):
			nuevas.append([distance, key])
		elif distance > unload_radius and _nodos.has(key):
			_nodos[key].queue_free()
			_nodos.erase(key)
	nuevas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_por_crear = nuevas.map(func(n: Array) -> Vector2i: return n[1])


func _crear_celda(arboles: Array) -> Node3D:
	var celda := Node3D.new()
	var por_variante := {}     # variante -> [[Transform3D, Color]]
	var body := StaticBody3D.new()
	celda.add_child(body)
	for arbol: Array in arboles:
		var x: float = arbol[0]
		var z: float = arbol[1]
		var altura: float = arbol[2]
		var radio: float = arbol[3]
		var variante := clampi(int(arbol[4]), 0, COPAS.size() - 1)
		# Siempre igual para el mismo arbol: semilla con su posicion
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(x * 10.0), roundi(z * 10.0)))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radio, altura, radio) * rng.randf_range(0.92, 1.08))
		var verdes: Array = VERDES[variante]
		var color: Color = (verdes[rng.randi() % verdes.size()] as Color).lerp(verdes[rng.randi() % verdes.size()], rng.randf())
		if not por_variante.has(variante):
			por_variante[variante] = []
		por_variante[variante].append([Transform3D(basis, Vector3(x, 0.0, z)), color])

		var tronco := CylinderShape3D.new()
		tronco.radius = clampf(radio * TRONCO_RADIO, TRONCO_MIN, TRONCO_MAX)
		tronco.height = altura * TRONCO_ALTO[variante]
		var shape := CollisionShape3D.new()
		shape.shape = tronco
		shape.position = Vector3(x, tronco.height / 2.0, z)
		body.add_child(shape)

	for variante: int in por_variante:
		var instancias: Array = por_variante[variante]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _mallas[variante]
		multimesh.instance_count = instancias.size()
		for i in instancias.size():
			multimesh.set_instance_transform(i, instancias[i][0])
			multimesh.set_instance_color(i, instancias[i][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Godot mide la distancia al centro de la celda: se le suma media diagonal
		instance.visibility_range_end = visible_hasta + CELDA * 0.71
		celda.add_child(instance)
	return celda


# Tronco de 6 caras y copas de pocas caras, con caras planas (look PS1). Los UV
# van al atlas de arbol.png: u 0..0.5 corteza, 0.5..1 hojas.
func _malla_arbol(variante: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var lados := 6
	var r := TRONCO_RADIO
	var alto: float = TRONCO_ALTO[variante]
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		var p0 := Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		var u0 := 0.5 * i / lados
		var u1 := 0.5 * (i + 1) / lados
		# Mas delgado arriba
		var q0 := p0 * 0.6 + Vector3(0.0, alto, 0.0)
		var q1 := p1 * 0.6 + Vector3(0.0, alto, 0.0)
		_tri(st, [p0, q0, q1], [Vector2(u0, 1.0), Vector2(u0, 0.0), Vector2(u1, 0.0)])
		_tri(st, [p0, q1, p1], [Vector2(u0, 1.0), Vector2(u1, 0.0), Vector2(u1, 1.0)])
	for copa: Array in COPAS[variante]:
		_esfera(st, copa[0], copa[1], 7, 4)
	st.generate_normals()
	return st.commit()


func _esfera(st: SurfaceTool, centro: Vector3, radios: Vector3, segmentos: int, anillos: int) -> void:
	for j in anillos:
		var t0 := PI * j / anillos
		var t1 := PI * (j + 1) / anillos
		for i in segmentos:
			var f0 := TAU * i / segmentos
			var f1 := TAU * (i + 1) / segmentos
			var a := centro + _punto(t0, f0) * radios
			var b := centro + _punto(t1, f0) * radios
			var c := centro + _punto(t1, f1) * radios
			var d := centro + _punto(t0, f1) * radios
			var ua := Vector2(0.5 + 0.5 * i / segmentos, float(j) / anillos)
			var ub := Vector2(ua.x, float(j + 1) / anillos)
			var uc := Vector2(0.5 + 0.5 * (i + 1) / segmentos, ub.y)
			var ud := Vector2(uc.x, ua.y)
			if j > 0:
				_tri(st, [a, d, c], [ua, ud, uc])
			if j < anillos - 1:
				_tri(st, [a, c, b], [ua, uc, ub])


func _punto(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


# Godot usa caras en sentido horario vistas desde afuera
func _tri(st: SurfaceTool, puntos: Array, uvs: Array) -> void:
	for k in [0, 2, 1]:
		st.set_uv(uvs[k])
		st.add_vertex(puntos[k])
