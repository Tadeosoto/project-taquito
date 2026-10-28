@tool
extends Node3D

# Coloca las tiendas y puestos del mapa (OXXO, farmacias, taquerias...).
# Las posiciones vienen de resources/map/puntos_mapa.json, que genera
# tools/map_import/prepare_osm.py a partir de data/map/puntos.json.
# Si un tipo tiene modelo en `prefabs` se usa ese, con sus proporciones y el frente
# de `prefab_ancho` (girado con `prefab_rotacion` si su fachada no ve a +Z; modelos:
# tools/map_import/fetch_sketchfab.py); puede encimarse en las casas vecinas;
# los tipos de LOCALES salen como un local de colonia (cortina abierta, mostrador
# y letrero pintado); lo demas, como una caja de color del tamano del lote.
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
	"abarrotes": Color(0.95, 0.9, 0.75),
	"farmacia": Color(0.2, 0.45, 0.85),
	"farmacia_local": Color(0.2, 0.6, 0.35),
	"farmacia_similares": Color(0.2, 0.45, 0.85),
	"taqueria": Color(0.95, 0.55, 0.15),
	"puesto_tacos": Color(0.98, 0.8, 0.2),
	"gasolinera": Color(0.15, 0.6, 0.3),
	"tortilleria": Color(0.85, 0.75, 0.45),
	"puesto": Color(0.75, 0.35, 0.6),
}

# Locales de colonia armados con cajas (no hay modelos de taquerias ni abarrotes
# genericos en Sketchfab), pintados como las tienditas de barrio: muro blanco con
# rodapie y franja de un color (rojo o azul, segun el nombre; verde las farmacias).
# letrero generico (si el nombre no cabe o es "Sin Nombre"), si lleva lona (del
# color del rodapie) y el adorno de un pilar (refresco, cruz o nada)
const LOCALES := {
	"taqueria": {"letrero": "TAQUERÍA", "lona": true, "adorno": ""},
	"tortilleria": {"letrero": "TORTILLERÍA", "lona": false, "adorno": ""},
	"abarrotes": {"letrero": "ABARROTES", "lona": false, "adorno": "refresco"},
	"farmacia_local": {"letrero": "FARMACIA", "lona": false, "adorno": "cruz", "acento": Color(0.1, 0.5, 0.25)},
}
const LOCAL_BLANCO := Color(0.93, 0.92, 0.88)
const ACENTOS := [Color(0.78, 0.1, 0.1), Color(0.1, 0.28, 0.68)]
const RODAPIE := 0.9
const LETRAS := Color(0.12, 0.12, 0.12)
const LOCAL_HEIGHT := 3.2
const LOCAL_FONDO_CORTINA := 1.0  # lo que se mete la entrada (m)
# Tamano minimo de un local (m): en lotes angostos se sale a los lados y hacia atras
const LOCAL_MIN := Vector2(4.5, 6.0)

@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"

# tipo -> escena del modelo (ej. "oxxo" -> res://models/oxxo.glb)
@export var prefabs: Dictionary[String, PackedScene] = {}

# tipo -> grados extra para que la fachada del modelo vea a +Z
@export var prefab_rotacion: Dictionary[String, float] = {}

# tipo -> metros de frente del modelo. Se escala parejo, sin deformarlo, aunque
# se salga del lote (los lotes de Google a veces son tiras angostas y apachurraban
# los modelos). Sin valor, el frente es el ancho del lote.
@export var prefab_ancho: Dictionary[String, float] = {}

# tipo -> nombres de nodos del modelo que se quitan antes de medirlo y ponerlo (ej. la
# losa de concreto del kiosco de Similares, que lo hacia ver chico y hundido)
@export var prefab_quitar: Dictionary[String, PackedStringArray] = {}

# El jugador; sin el se crean todas las tiendas de una vez
@export var target_path: NodePath
@export var load_radius := 250.0
@export var unload_radius := 320.0

var _puntos := []
var _nodes := {}           # indice en _puntos -> Node3D
var _box_materials := {}   # tipo -> ShaderMaterial de las cajas
var _sucios := {}          # material de un prefab -> copia con deterioro
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
	if LOCALES.has(tipo):
		return _make_local(punto)
	return _make_placeholder(punto)


# Frente y fondo (m) que ocupa el modelo de `tipo` ya escalado (Vector2.ZERO si no
# tiene modelo). Lo usa tools/map_import/huellas_tiendas.gd para que prepare_osm.py
# quite las casas que quedan debajo del negocio.
func huella_modelo(tipo: String) -> Vector2:
	if not prefabs.has(tipo) or prefabs[tipo] == null or not prefab_ancho.has(tipo):
		return Vector2.ZERO
	var model := _instanciar(tipo)
	var aabb := _mesh_aabb(model, model.transform)
	model.free()
	if aabb.size.x <= 0.01:
		return Vector2.ZERO
	var fit: float = prefab_ancho[tipo] / aabb.size.x
	return Vector2(aabb.size.x, aabb.size.z) * fit


# El modelo de `tipo` girado prefab_rotacion[tipo] grados y sin los nodos de prefab_quitar
func _instanciar(tipo: String) -> Node3D:
	var model := prefabs[tipo].instantiate() as Node3D
	model.rotation.y = deg_to_rad(prefab_rotacion.get(tipo, 0.0))
	for nombre in prefab_quitar.get(tipo, PackedStringArray()):
		var nodo := model.find_child(nombre, true, false)
		if nodo:
			nodo.get_parent().remove_child(nodo)
			nodo.free()
	return model


# El modelo se gira prefab_rotacion[tipo] grados (para que su fachada vea a +Z),
# se escala parejo a prefab_ancho[tipo] metros de frente y se apoya en el piso con
# la fachada en la orilla del lote que da a la calle; crece hacia atras.
func _make_prefab(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var holder := Node3D.new()
	holder.name = "%s_%s" % [tipo, punto.get("nombre", "")]

	var model := _instanciar(tipo)
	holder.add_child(model)
	if not Engine.is_editor_hint():
		_animar(model)

	var aabb := _mesh_aabb(model, model.transform)
	if aabb.size.x > 0.01 and aabb.size.z > 0.01:
		var fit: float = prefab_ancho.get(tipo, punto["ancho"]) / aabb.size.x
		var front: float = punto["fondo"] / 2.0
		model.scale *= fit
		model.position = Vector3(-aabb.get_center().x * fit, -aabb.position.y * fit, front - aabb.end.z * fit)
		_set_far_mesh_options(model)

		# Colision de caja del tamano del modelo (las mallas de Sketchfab no traen)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = aabb.size * fit
		shape.shape = box_shape
		shape.position = Vector3(0.0, box_shape.size.y / 2.0, front - box_shape.size.z / 2.0)
		body.add_child(shape)
		holder.add_child(body)
	return holder


# Los modelos animados (el Simi del kiosco de Similares) bailan en loop
func _animar(node: Node) -> void:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		var lista := player.get_animation_list()
		if not lista.is_empty():
			player.get_animation(lista[0]).loop_mode = Animation.LOOP_LINEAR
			player.play.call_deferred(lista[0])
		return
	for child in node.get_children():
		_animar(child)


# Igual que los cuadros del mapa (MapPostImport): sin sombras y ocultos de lejos.
# Tambien les pone la mugre de la zona (ps1_deterioro) a sus materiales PS1.
func _set_far_mesh_options(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = PREFAB_VISIBILITY_RANGE
		var instance := node as MeshInstance3D
		if instance.mesh:
			for surface in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface) as ShaderMaterial
				if material == null or material.shader != PS1_SHADER:
					continue
				if not _sucios.has(material):
					var sucio := material.duplicate() as ShaderMaterial
					sucio.set_shader_parameter("deterioro_modo", 1)
					_sucios[material] = sucio
				instance.set_surface_override_material(surface, _sucios[material])
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
		material.set_shader_parameter("deterioro_modo", 2)
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


# Local de colonia del tamano del lote (minimo LOCAL_MIN): fachada con la entrada
# metida, cortina enrollada arriba, mostrador, nombre pintado en el muro blanco con
# rodapie y franja de color, y segun el giro lona, refresco pintado o cruz verde.
# La fachada ve a +Z, como los prefabs, en la orilla del lote.
func _make_local(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var nombre: String = punto.get("nombre", "")
	var info: Dictionary = LOCALES[tipo]
	var w: float = maxf(punto["ancho"], LOCAL_MIN.x)
	var d: float = maxf(punto["fondo"], LOCAL_MIN.y)
	var h := LOCAL_HEIGHT
	var front: float = punto["fondo"] / 2.0
	var hondo := LOCAL_FONDO_CORTINA
	var entrada := clampf(w * 0.6, 2.4, 5.0)
	entrada = minf(entrada, w - 0.6)
	var pilar := (w - entrada) / 2.0
	var acento: Color = info.get("acento", ACENTOS[absi(nombre.hash() / 7) % ACENTOS.size()])

	var body := StaticBody3D.new()
	body.name = "%s_%s" % [tipo, nombre]
	# Cuerpo, pilares a los lados de la entrada y dintel encima
	var cuerpo := [Vector3(w, h, d - hondo), Vector3(0.0, h / 2.0, front - hondo - (d - hondo) / 2.0)]
	_local_box(body, cuerpo[0], cuerpo[1], LOCAL_BLANCO, true)
	var piezas := [cuerpo]
	for side in [-1.0, 1.0]:
		var p := [Vector3(pilar, h, hondo), Vector3(side * (entrada + pilar) / 2.0, h / 2.0, front - hondo / 2.0)]
		_local_box(body, p[0], p[1], LOCAL_BLANCO, true)
		piezas.append(p)
	_local_box(body, Vector3(entrada, h - 2.5, hondo),
		Vector3(0.0, 2.5 + (h - 2.5) / 2.0, front - hondo / 2.0), LOCAL_BLANCO, false)
	# Rodapie y franja: una cascara de color apenas mas grande que el muro
	for p: Array in piezas:
		var size: Vector3 = p[0]
		var pos: Vector3 = p[1]
		_local_box(body, Vector3(size.x + 0.03, RODAPIE, size.z + 0.03), Vector3(pos.x, RODAPIE / 2.0, pos.z), acento, false)
		_local_box(body, Vector3(size.x + 0.03, 0.1, size.z + 0.03), Vector3(pos.x, RODAPIE + 0.25, pos.z), acento, false)
	# Adentro oscuro, cortina enrollada y mostrador
	_local_box(body, Vector3(entrada, 2.5, 0.05), Vector3(0.0, 1.25, front - hondo + 0.03), Color(0.1, 0.08, 0.07), false)
	_local_box(body, Vector3(entrada, 0.25, 0.25), Vector3(0.0, 2.37, front - 0.15), Color(0.55, 0.57, 0.6), false)
	_local_box(body, Vector3(minf(entrada - 0.6, 2.4), 1.0, 0.5), Vector3(0.0, 0.5, front - 0.4), Color(0.85, 0.85, 0.82), true)

	if info["lona"]:
		var awning := _local_box(body, Vector3(entrada + 0.6, 0.06, 1.3), Vector3(0.0, 2.45, front + 0.6), acento, false)
		awning.rotation.x = deg_to_rad(15.0)

	# Adorno pintado en el pilar derecho, si cabe
	if pilar >= 0.9:
		var centro := Vector3((entrada + pilar) / 2.0, 1.85, front + 0.02)
		match info["adorno"]:
			"refresco":
				# Un circulo rojo de refresco (sin marca) con su letrero
				var radio := minf(0.42, pilar * 0.4)
				var disco := MeshInstance3D.new()
				var cilindro := CylinderMesh.new()
				cilindro.top_radius = radio
				cilindro.bottom_radius = radio
				cilindro.height = 0.02
				cilindro.radial_segments = 12
				cilindro.rings = 1
				cilindro.material = _color_material(Color(0.82, 0.08, 0.1), false)
				disco.mesh = cilindro
				disco.rotation.x = PI / 2.0
				disco.position = centro
				disco.visibility_range_end = PREFAB_VISIBILITY_RANGE
				body.add_child(disco)
				var marca := Label3D.new()
				marca.text = "REFRESCOS"
				marca.font_size = 32
				marca.outline_size = 0
				marca.pixel_size = radio * 1.6 / (9 * 19.0)
				marca.position = centro + Vector3(0.0, 0.0, 0.02)
				marca.visibility_range_end = 60.0
				body.add_child(marca)
			"cruz":
				_local_box(body, Vector3(0.6, 0.2, 0.03), centro, acento, false)
				_local_box(body, Vector3(0.2, 0.6, 0.03), centro, acento, false)

	# Nombre pintado sobre el dintel (como en la foto: letras oscuras en el muro)
	var texto: String = nombre.to_upper()
	if texto == "" or texto.length() > 22 or texto.contains("SIN NOMBRE"):
		texto = info["letrero"]
	var label := Label3D.new()
	label.text = texto
	label.font_size = 64
	label.outline_size = 0
	label.modulate = LETRAS
	# Que el texto quepa en el letrero (~0.6 del font_size por letra)
	label.pixel_size = minf(0.008, (entrada + pilar - 0.3) / (texto.length() * 38.0))
	label.position = Vector3(0.0, h - 0.4, front + 0.02)
	label.visibility_range_end = 80.0
	body.add_child(label)
	return body


# Una caja del local; con `solid` tambien lleva colision
func _local_box(body: StaticBody3D, size: Vector3, pos: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _color_material(color, solid)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		body.add_child(shape)
	return mesh


# `muro`: paredes del local, con pintura caida y escurrimientos; lo demas, solo mugre
func _color_material(color: Color, muro: bool) -> ShaderMaterial:
	var key := [color, muro]
	if not _box_materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("deterioro_modo", 2 if muro else 1)
		_box_materials[key] = material
	return _box_materials[key]
