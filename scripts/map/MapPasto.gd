extends Node3D

# Matas de pasto en 3D alrededor del jugador, donde la mascara de pasto
# (textures/map/pasto_mascara.png, tools/map_import/make_vegetacion.py) dice que
# hay pasto. Son muchas y solo se ven de cerca: se crean por celdas de CELDA m
# hasta `radio` m del jugador y se quitan al alejarse. Cada celda siempre sale
# igual (la semilla es la celda). Volando en dron no se dibujan.

const PASTO_SHADER := preload("res://shaders/ps1_pasto.gdshader")
const MATA_TEXTURA := preload("res://textures/map/mata_pasto.png")

const CELDA := 16.0
# Mascara minima para poner matas (la orilla del pasto en el shader del suelo
# anda por 0.5; mas arriba las matas no se salen a la tierra)
const MASCARA_MIN := 0.6

@export var target_path: NodePath
@export var dron_path: NodePath
# El plano de relleno (ps1_suelo): se le pone la misma mascara que a la tierra de OSM2World
@export var suelo_path: NodePath
@export var mascara_path := "res://textures/map/pasto_mascara.png"
@export_file("*.json") var mascara_json := "res://resources/map/pasto_mascara.json"
@export var radio := 40.0
# Matas por m2 donde la mascara vale 1
@export var densidad := 1.6
@export var alto := Vector2(0.25, 0.6)

var _mascara: Image
var _origen := Vector2.ZERO
var _metros_por_pixel := 1.0
var _nodos := {}           # Vector2i -> MultiMeshInstance3D
var _mata: ArrayMesh
var _target: Node3D
var _dron: Node
var _timer := 0.0


func _ready() -> void:
	var textura := load(mascara_path) as Texture2D
	var info = JSON.parse_string(FileAccess.get_file_as_string(mascara_json)) if FileAccess.file_exists(mascara_json) else null
	if textura == null or not info is Dictionary:
		push_warning("MapPasto: falta %s o %s (corre make_vegetacion.py)" % [mascara_path, mascara_json])
		return
	_mascara = textura.get_image()
	if _mascara.is_compressed():
		_mascara.decompress()
	_origen = Vector2(info["x0"], info["z0"])
	_metros_por_pixel = info["metros_por_pixel"]
	_mata = _malla_mata()
	var suelo := get_node_or_null(suelo_path) as GeometryInstance3D
	if suelo and suelo.material_override is ShaderMaterial:
		SueloPasto.configurar(suelo.material_override, 1)
	elif suelo is MeshInstance3D and (suelo as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial:
		SueloPasto.configurar((suelo as MeshInstance3D).get_surface_override_material(0), 1)
	_target = get_node_or_null(target_path) as Node3D
	_dron = get_node_or_null(dron_path)


func _process(delta: float) -> void:
	if _target == null or _mascara == null:
		return
	var volando: bool = _dron != null and _dron.has_method("volando") and _dron.volando()
	visible = not volando
	if volando:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var p := _target.global_position
	var centro := Vector2i(floori(p.x / CELDA), floori(p.z / CELDA))
	var n := ceili(radio / CELDA)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var key := centro + Vector2i(dx, dz)
			if not _nodos.has(key) and _distancia(key, p) < radio:
				var node := _crear_celda(key)
				if node:
					add_child(node)
				_nodos[key] = node
	for key: Vector2i in _nodos.keys():
		if _distancia(key, p) > radio + CELDA:
			if _nodos[key]:
				_nodos[key].queue_free()
			_nodos.erase(key)


func _distancia(key: Vector2i, p: Vector3) -> float:
	var dx := maxf(maxf(key.x * CELDA - p.x, p.x - (key.x + 1) * CELDA), 0.0)
	var dz := maxf(maxf(key.y * CELDA - p.z, p.z - (key.y + 1) * CELDA), 0.0)
	return Vector2(dx, dz).length()


func _valor(x: float, z: float) -> float:
	var px := floori((x - _origen.x) / _metros_por_pixel)
	var pz := floori((z - _origen.y) / _metros_por_pixel)
	if px < 0 or pz < 0 or px >= _mascara.get_width() or pz >= _mascara.get_height():
		return 0.0
	return _mascara.get_pixel(px, pz).r


func _crear_celda(key: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var transforms: Array[Transform3D] = []
	var colores: Array[Color] = []
	for i in roundi(densidad * CELDA * CELDA):
		var x := (key.x + rng.randf()) * CELDA
		var z := (key.y + rng.randf()) * CELDA
		var giro := rng.randf() * TAU
		var h := rng.randf_range(alto.x, alto.y)
		var sorteo := rng.randf()
		var m := _valor(x, z)
		if m < MASCARA_MIN or sorteo > m:
			continue
		var basis := Basis(Vector3.UP, giro).scaled(Vector3(h * 1.4, h, h * 1.4))
		transforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
		# Mas seco o mas verde, como las manchas del piso
		colores.append(Color(0.85, 0.9, 0.75).lerp(Color(1.15, 1.05, 0.8), rng.randf() * 0.6))
	if transforms.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _mata
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colores[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "pasto_%d_%d" % [key.x, key.y]
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# Dos cuadros de 1 x 1 m cruzados, con la base en y = 0
func _malla_mata() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angulo in [0.0, PI / 2.0]:
		var d := Vector3(cos(angulo), 0.0, sin(angulo)) * 0.5
		var esquinas := [-d, -d + Vector3.UP, d + Vector3.UP, d]
		var uvs := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(esquinas[k])
	var mesh := st.commit()
	var material := ShaderMaterial.new()
	material.shader = PASTO_SHADER
	material.set_shader_parameter("albedo_texture", MATA_TEXTURA)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("distancia_inicio", radio - 12.0)
	material.set_shader_parameter("distancia_fin", radio - 2.0)
	mesh.surface_set_material(0, material)
	return mesh
