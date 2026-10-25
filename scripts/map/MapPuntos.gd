@tool
extends Node3D

# Coloca las tiendas y puestos del mapa (OXXO, farmacias, taquerias...).
# Las posiciones vienen de resources/map/puntos_mapa.json, que genera
# tools/map_import/prepare_osm.py a partir de data/map/puntos.json.
# Si un tipo tiene modelo en `prefabs` se usa ese, escalado al lote (girado con
# `prefab_rotacion` si su fachada no ve a +Z; modelos: tools/map_import/fetch_sketchfab.py);
# si no, sale una caja de color del tamano del lote con un letrero.
# En el editor se ven todas; en el juego solo existen las que estan a menos de
# load_radius del jugador (target_path), igual que los cuadros de MapStreamer.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

const PLACEHOLDER_HEIGHT := 3.5

# Mas alla de esto (m) los modelos de tiendas no se dibujan (el mapa usa ~340 m)
const PREFAB_VISIBILITY_RANGE := 250.0

# Colores de las cajas mientras no hay modelo
const TIPO_COLORS := {
	"oxxo": Color(0.85, 0.15, 0.12),
	"tienda": Color(0.95, 0.9, 0.75),
	"farmacia": Color(0.2, 0.45, 0.85),
	"taqueria": Color(0.95, 0.55, 0.15),
	"puesto_tacos": Color(0.98, 0.8, 0.2),
	"gasolinera": Color(0.15, 0.6, 0.3),
	"tortilleria": Color(0.85, 0.75, 0.45),
	"puesto": Color(0.75, 0.35, 0.6),
}

@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"

# tipo -> escena del modelo (ej. "oxxo" -> res://models/oxxo.glb)
@export var prefabs: Dictionary[String, PackedScene] = {}

# tipo -> grados extra para que la fachada del modelo vea a +Z
@export var prefab_rotacion: Dictionary[String, float] = {}

# El jugador; sin el se crean todas las tiendas de una vez
@export var target_path: NodePath
@export var load_radius := 250.0
@export var unload_radius := 320.0

var _puntos := []
var _nodes := {}           # indice en _puntos -> Node3D
var _box_materials := {}   # tipo -> ShaderMaterial de las cajas
var _target: Node3D
var _timer := 0.0


func _ready() -> void:
	# Los hijos se generan cada vez y no se guardan en la escena (no tienen owner)
	for child in get_children():
		child.queue_free()

	var text := FileAccess.get_file_as_string(puntos_path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_warning("MapPuntos: no se pudo leer %s" % puntos_path)
		return
	_puntos = data.get("puntos", [])

	if not Engine.is_editor_hint():
		_target = get_node_or_null(target_path) as Node3D
	_update_nearby()


func _process(delta: float) -> void:
	if _target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_nearby()


func _update_nearby() -> void:
	for i in _puntos.size():
		var punto: Dictionary = _puntos[i]
		var distance := 0.0
		if _target:
			distance = Vector2(_target.global_position.x - punto["x"], _target.global_position.z - punto["z"]).length()
		if distance < load_radius and not _nodes.has(i):
			var node := _make_punto(punto)
			node.position = Vector3(punto["x"], 0.0, punto["z"])
			node.rotation.y = punto["rotacion_y"]
			add_child(node)
			_nodes[i] = node
		elif distance > unload_radius and _nodes.has(i):
			_nodes[i].queue_free()
			_nodes.erase(i)


func _make_punto(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	if prefabs.has(tipo) and prefabs[tipo] != null:
		return _make_prefab(punto)
	return _make_placeholder(punto)


# El modelo se gira prefab_rotacion[tipo] grados (para que su fachada vea a +Z)
# y se escala parejo para caber en el lote (ancho x fondo), apoyado en el piso.
func _make_prefab(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var holder := Node3D.new()
	holder.name = "%s_%s" % [tipo, punto.get("nombre", "")]

	var model := prefabs[tipo].instantiate() as Node3D
	model.rotation.y = deg_to_rad(prefab_rotacion.get(tipo, 0.0))
	holder.add_child(model)

	var aabb := _mesh_aabb(model, model.transform)
	if aabb.size.x > 0.01 and aabb.size.z > 0.01:
		# Ancho y fondo del lote; la altura sigue a la escala mayor de las dos para
		# que un lote angosto no deje la tienda chaparra
		var fit_x: float = punto["ancho"] / aabb.size.x
		var fit_z: float = punto["fondo"] / aabb.size.z
		var fit := Vector3(fit_x, maxf(fit_x, fit_z), fit_z)
		model.scale = model.scale * Vector3(
				fit.x, fit.y, fit.z).rotated(Vector3.UP, model.rotation.y).abs()
		var center := aabb.get_center() * fit
		model.position = Vector3(-center.x, -aabb.position.y * fit.y, -center.z)
		_set_far_mesh_options(model)

		# Colision de caja del tamano del modelo (las mallas de Sketchfab no traen)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = aabb.size * fit
		shape.shape = box_shape
		shape.position.y = box_shape.size.y / 2.0
		body.add_child(shape)
		holder.add_child(body)
	return holder


# Igual que los cuadros del mapa (MapPostImport): sin sombras y ocultos de lejos
func _set_far_mesh_options(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = PREFAB_VISIBILITY_RANGE
	for child in node.get_children():
		_set_far_mesh_options(child)


# AABB de todas las mallas de `node`, en el espacio de su padre
func _mesh_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and node.mesh:
		result = xform * node.mesh.get_aabb()
		first = false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_aabb := _mesh_aabb(child, xform * (child as Node3D).transform)
		if child_aabb.size == Vector3.ZERO:
			continue
		result = child_aabb if first else result.merge(child_aabb)
		first = false
	return result


func _make_placeholder(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var size := Vector3(punto["ancho"], PLACEHOLDER_HEIGHT, punto["fondo"])
	if tipo.begins_with("puesto"):
		size.y = 2.2

	var body := StaticBody3D.new()
	body.name = "%s_%s" % [tipo, punto.get("nombre", "")]

	var box := BoxMesh.new()
	box.size = size
	if not _box_materials.has(tipo):
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter("tint", TIPO_COLORS.get(tipo, Color(0.6, 0.6, 0.6)))
		material.set_shader_parameter("affine_enabled", false)
		_box_materials[tipo] = material
	box.material = _box_materials[tipo]

	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	mesh.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position.y = size.y / 2.0
	body.add_child(shape)

	# Letrero sobre la fachada (+Z)
	var label := Label3D.new()
	label.text = punto.get("nombre", "") if punto.get("nombre", "") != "" else tipo
	label.position = Vector3(0.0, size.y + 0.6, size.z / 2.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# De lejos los letreros nomas ensucian (y cuestan)
	label.visibility_range_end = 80.0
	label.pixel_size = 0.01
	label.font_size = 64
	label.outline_size = 12
	body.add_child(label)
	return body
