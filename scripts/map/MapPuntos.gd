@tool
class_name MapPuntos
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
	"ferreteria": Color(0.9, 0.45, 0.1),
	"purificadora": Color(0.2, 0.6, 0.9),
}

# Locales de colonia armados con cajas (no hay modelos de taquerias ni abarrotes
# genericos en Sketchfab), pintados como las tienditas de barrio: muro blanco con
# rodapie y franja de un color (rojo o azul, segun el nombre; verde las farmacias).
# letrero generico (si el nombre no cabe o es "Sin Nombre"), si lleva lona (del
# color del rodapie) y el adorno de un pilar (refresco, cruz, gota o nada)
const LOCALES := {
	"taqueria": {"letrero": "TAQUERÍA", "lona": true, "adorno": ""},
	"tortilleria": {"letrero": "TORTILLERÍA", "lona": false, "adorno": ""},
	"abarrotes": {"letrero": "ABARROTES", "lona": false, "adorno": "refresco"},
	"farmacia_local": {"letrero": "FARMACIA", "lona": false, "adorno": "cruz", "acento": Color(0.1, 0.5, 0.25)},
	"ferreteria": {"letrero": "FERRETERÍA", "lona": false, "adorno": ""},
	"purificadora": {"letrero": "AGUA PURIFICADA", "lona": true, "adorno": "gota", "acento": Color(0.1, 0.4, 0.8)},
}
const LOCAL_BLANCO := Color(0.93, 0.92, 0.88)
const ACENTOS := [Color(0.78, 0.1, 0.1), Color(0.1, 0.28, 0.68)]
const RODAPIE := 0.9
const LETRAS := Color(0.12, 0.12, 0.12)
const LOCAL_HEIGHT := 3.2
const LOCAL_FONDO_CORTINA := 1.0  # lo que se mete la entrada (m)
# Tamano minimo de un local (m): en lotes angostos se sale a los lados y hacia atras
const LOCAL_MIN := Vector2(4.5, 6.0)
# Purificadora (foto del usuario): anuncio sobre postes en la banqueta
const PURIFICADORA_LONA := preload("res://textures/map/purificadora_lona.png")
const PURIFICADORA_POSTES := 1.5   # de la fachada a los postes (orilla de la banqueta)
const PURIFICADORA_ANUNCIO := Vector2(2.9, 1.7)   # altura de abajo y alto del anuncio
# Taqueria (como scenes/interiores/taqueria.tscn vista desde la calle): local blanco con
# rojo abierto, mesas y refris rojos adentro y el puesto con el taquero en la banqueta
const TAQUERIA_ROJO := Color(0.62, 0.12, 0.1)
const TAQUERIA_MESA := Color(0.88, 0.07, 0.05)
const TAQUERIA_PUESTO := 1.3   # de la fachada al centro del puesto (m)
const TAQUERIA_CUARTO := 4.5   # fondo maximo del cuarto que se ve desde la calle
const TAQUERIA_DETALLE := 80.0 # mas alla no se dibujan muebles ni puesto

# Marcador de los negocios interactivos (docs/especificaciones.md 4.6): flecha
# amarilla frente a la puerta; al pisarla se entra al interior (scripts/interiores/Interiores.gd)
const MARCADOR_COLOR := Color(1.0, 0.85, 0.1)
const MARCADOR_RADIO := 0.8
const MARCADOR_FRENTE := 0.8   # que tanto sale de la fachada (m)
# Solo aparece de cerca: se desvanece entre estas distancias (m)
const MARCADOR_VISTA := 18.0
const MARCADOR_VISTA_FADE := 6.0
# Y con la camara encima tampoco (al salir de un interior queda pegada a la flecha)
const MARCADOR_CERCA := 2.0
# Lo que dice el que atiende un puesto al aire libre, por giro
const VENDEDOR_DIALOGO := {
	"puesto_tacos": "¿De qué van a ser, joven? (Menú: próximamente)",
	"tejuino": "¿Un tejuino bien frío? (Menú: próximamente)",
}
const MARCADOR_ALFA := 0.6

# `marcador`: el Area3D de la flecha (su +Z apunta a la calle), para volver a ponerte
# ahi; en los puestos al aire libre trae de hijo al `Vendedor` que atiende
signal entrar_negocio(tipo: String, giro: String, nombre: String, aire_libre: bool, marcador: Node3D)

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

# tipo -> {nodo del modelo: corrimiento en m (x a la derecha, z hacia la calle)},
# aplicado despues de medir y escalar el modelo (ej. el Simi que bailaba sobre la flecha)
@export var prefab_mover: Dictionary[String, Dictionary] = {}

# tipo -> corrimiento (m) de la puerta a la derecha del centro de la fachada
@export var prefab_puerta: Dictionary[String, float] = {}

# El que atiende en los puestos al aire libre (puesto de tacos, tejuino), parado
# detras del puesto viendo a la calle; por ahora scenes/npc.tscn
@export var vendedor_escena: PackedScene
# tipo -> que tanto atras de la flecha se para (m): detras del carrito, dentro del
# puesto de tacos. Solo los tipos que estan aqui llevan vendedor (el punto te mete a
# su cuarto, scenes/interiores/punto.tscn)
@export var vendedor_atras: Dictionary[String, float] = {}

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
var _aviso: Label
var _aviso_tween: Tween


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
	var node: Node3D
	if tipo == "punto":
		# La casa ya la dibuja MapCasas; aqui solo va su marcador
		node = Node3D.new()
		node.name = "punto_%s" % punto.get("origen", "")
	elif prefabs.has(tipo) and prefabs[tipo] != null:
		node = _make_prefab(punto)
	elif tipo == "purificadora":
		node = _make_purificadora(punto)
	elif tipo == "taqueria":
		node = _make_taqueria(punto)
	elif LOCALES.has(tipo):
		node = _make_local(punto)
	else:
		node = _make_placeholder(punto)
	if punto.get("interactivo", false) and not Engine.is_editor_hint():
		node.add_child(_marcador(punto))
	return node


# Flecha amarilla semitransparente que gira y flota frente a la puerta (solo se ve de
# cerca), y un Area3D que avisa al pisarla
func _marcador(punto: Dictionary) -> Node3D:
	var area := Area3D.new()
	area.name = "Marcador"
	# `puerta_x`: el local armado dice donde esta su puerta (la ventanilla de la purificadora)
	area.position = Vector3(punto.get("puerta_x", prefab_puerta.get(punto["tipo"], 0.0)), 0.0, punto["fondo"] / 2.0 + MARCADOR_FRENTE)
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MARCADOR_RADIO
	cilindro.height = 2.0
	shape.shape = cilindro
	shape.position.y = 1.0
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_entrar(punto, area))
	if punto.get("aire_libre", false) and vendedor_escena and vendedor_atras.has(punto["tipo"]):
		area.add_child(_vendedor(punto))
	area.add_child(flecha())
	return area


static var _flecha_cache: Mesh

# Flecha que flota y gira
static func flecha() -> MeshInstance3D:
	if _flecha_cache == null:
		_flecha_cache = _flecha_mesh()
	var malla := MeshInstance3D.new()
	malla.mesh = _flecha_cache
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	malla.visibility_range_end = MARCADOR_VISTA
	malla.visibility_range_end_margin = MARCADOR_VISTA_FADE
	malla.visibility_range_begin = MARCADOR_CERCA
	malla.visibility_range_begin_margin = 0.5
	malla.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# El tween se crea ya en el arbol (se libera con la flecha)
	malla.ready.connect(func() -> void:
		var tween := malla.create_tween().set_loops()
		tween.tween_property(malla, "position:y", 0.25, 0.8).from(0.0).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(malla, "rotation:y", PI, 0.8).from(0.0)
		tween.tween_property(malla, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(malla, "rotation:y", TAU, 0.8), CONNECT_ONE_SHOT)
	return malla


# Flecha hacia abajo (cono y palo) a ~1.3 m del piso, amarilla y sin sombra para que
# se vea igual de noche
static func _flecha_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(MARCADOR_COLOR, MARCADOR_ALFA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var punta := CylinderMesh.new()
	punta.top_radius = 0.35
	punta.bottom_radius = 0.0
	punta.height = 0.5
	punta.radial_segments = 6
	punta.rings = 1
	var palo := CylinderMesh.new()
	palo.top_radius = 0.13
	palo.bottom_radius = 0.13
	palo.height = 0.5
	palo.radial_segments = 6
	palo.rings = 1
	var tools := SurfaceTool.new()
	tools.begin(Mesh.PRIMITIVE_TRIANGLES)
	tools.append_from(punta, 0, Transform3D(Basis(), Vector3(0.0, 1.3, 0.0)))
	tools.append_from(palo, 0, Transform3D(Basis(), Vector3(0.0, 1.8, 0.0)))
	var mesh := tools.commit()
	mesh.surface_set_material(0, material)
	return mesh


# Viendo a la calle (+Z del marcador; el npc ve a su -Z), sin su area de platica: se le
# habla pisando la flecha, no con el boton de saltar
func _vendedor(punto: Dictionary) -> Node3D:
	var vendedor := vendedor_escena.instantiate() as Node3D
	vendedor.name = "Vendedor"
	vendedor.position = Vector3(0.0, 0.0, -vendedor_atras.get(punto["tipo"], 1.5))
	vendedor.rotation.y = PI
	vendedor.set("dialogue", VENDEDOR_DIALOGO.get(punto.get("giro", ""), ""))
	vendedor.ready.connect(func() -> void:
		(vendedor.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
	return vendedor


func _entrar(punto: Dictionary, marcador: Node3D) -> void:
	var nombre: String = punto.get("nombre", "")
	if nombre == "" or nombre.to_upper().contains("SIN NOMBRE"):
		nombre = LOCALES.get(punto["tipo"], {}).get("letrero", String(punto.get("giro", "")).capitalize())
	entrar_negocio.emit(punto["tipo"], punto.get("giro", ""), nombre, punto.get("aire_libre", false), marcador)
	# Sin nadie que lo atienda (Interiores) no hay a donde entrar
	if not entrar_negocio.has_connections():
		avisar("%s: Próximamente" % nombre)


# Texto abajo al centro que se desvanece solo
func avisar(texto: String) -> void:
	if _aviso == null:
		var capa := CanvasLayer.new()
		capa.layer = 3
		add_child(capa)
		_aviso = Label.new()
		_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_aviso.offset_bottom = -60.0
		_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_aviso.add_theme_color_override("font_color", MARCADOR_COLOR)
		_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
		_aviso.add_theme_constant_override("outline_size", 6)
		capa.add_child(_aviso)
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _aviso_tween:
		_aviso_tween.kill()
	_aviso_tween = create_tween()
	_aviso_tween.tween_interval(1.5)
	_aviso_tween.tween_property(_aviso, "modulate:a", 0.0, 1.0)


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
		for nombre in prefab_mover.get(tipo, {}):
			var nodo := model.find_child(nombre, true, false) as Node3D
			if nodo:
				# Del espacio del negocio al del padre del nodo
				var xform := Transform3D()
				var n: Node = nodo.get_parent()
				while n != holder:
					if n is Node3D:
						xform = (n as Node3D).transform * xform
					n = n.get_parent()
				nodo.position += xform.basis.inverse() * Vector3(prefab_mover[tipo][nombre])
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
			"gota":
				# Gota de agua: un rombo azul con la punta hacia arriba
				var gota := _local_box(body, Vector3(0.36, 0.36, 0.03), centro + Vector3(0.0, -0.05, 0.0), acento, false)
				gota.rotation.z = PI / 4.0
				_local_box(body, Vector3(0.1, 0.25, 0.03), centro + Vector3(0.0, 0.25, 0.0), acento, false)

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


# Purificadora como la foto de referencia: de izquierda a derecha puerta de barrotes
# metida, el despachador automatico azul en el muro y el ventanal de aluminio con los
# garrafones adentro; muro blanco con rodapie y franja azules como los demas locales y
# el anuncio grande (purificadora_lona.png + letreros) sobre postes en la orilla de la
# banqueta, sin tejado. Guarda en `punto["puerta_x"]` el centro del ventanal, donde
# va la flecha. La fachada ve a +Z, en la orilla del lote.
# Con `solo_fachada` (la escena de compra, Interior.fachada_mapa) no arma el cuerpo ni
# lo de adentro del ventanal, y el ventanal queda abierto: sin vidrios ni travesano,
# solo su marco, para ver al que atiende.
func _make_purificadora(punto: Dictionary, solo_fachada := false) -> Node3D:
	var nombre: String = punto.get("nombre", "")
	var w: float = maxf(punto["ancho"], LOCAL_MIN.x)
	var d: float = maxf(punto["fondo"], LOCAL_MIN.y)
	var h := LOCAL_HEIGHT
	var front: float = punto["fondo"] / 2.0
	var muro := 0.3   # grueso de la fachada; atras, el cuerpo
	var body := StaticBody3D.new()
	body.name = "purificadora_%s" % nombre
	if not solo_fachada:
		_local_box(body, Vector3(w, h, d - muro), Vector3(0.0, h / 2.0, front - muro - (d - muro) / 2.0), LOCAL_BLANCO, true)
	# Tramos de la fachada de izquierda a derecha
	var x := -w / 2.0
	var puerta := Vector2(x + 0.25, x + 1.45)
	var despachador := Vector2(puerta.y, puerta.y + 0.8)
	var ventana := Vector2(despachador.y + 0.3, minf(w / 2.0 - 0.3, despachador.y + 0.3 + 3.2))
	var oscuro := Color(0.08, 0.08, 0.09)
	var acento: Color = LOCALES["purificadora"]["acento"]
	var z := front - muro / 2.0
	# Muro: macizos a los lados de los huecos, dintel de la puerta y antepecho y dintel
	# del ventanal
	var macizos := [Vector2(-w / 2.0, puerta.x), Vector2(despachador.x, ventana.x), Vector2(ventana.y, w / 2.0)]
	for tramo: Vector2 in macizos:
		if tramo.y - tramo.x > 0.01:
			_fachada_tramo(body, tramo, 0.0, h, z, muro, acento)
	_fachada_tramo(body, puerta, 2.3, h, z, muro, acento)
	_fachada_tramo(body, ventana, 0.0, 1.15, z, muro, acento)
	_fachada_tramo(body, ventana, 2.35, h, z, muro, acento)
	# Puerta: fondo oscuro y barrotes negros
	_local_box(body, Vector3(puerta.y - puerta.x, 2.3, 0.05), Vector3((puerta.x + puerta.y) / 2.0, 1.15, front - muro + 0.03), oscuro, false)
	var barrotes := 9
	for i in barrotes + 1:
		var bx := puerta.x + 0.04 + (puerta.y - puerta.x - 0.08) * i / barrotes
		_local_box(body, Vector3(0.025, 2.26, 0.025), Vector3(bx, 1.13, front - 0.08), Color(0.1, 0.1, 0.1), false)
	for y in [0.15, 1.15, 2.2]:
		_local_box(body, Vector3(puerta.y - puerta.x, 0.04, 0.03), Vector3((puerta.x + puerta.y) / 2.0, y, front - 0.08), Color(0.1, 0.1, 0.1), false)
	# Despachador automatico en el muro: marco gris, maquina azul, pantallita y ranura
	var cx := (despachador.x + despachador.y) / 2.0
	_local_box(body, Vector3(0.58, 0.78, 0.03), Vector3(cx, 1.35, front + 0.015), Color(0.62, 0.63, 0.64), false)
	_local_box(body, Vector3(0.46, 0.64, 0.04), Vector3(cx, 1.35, front + 0.02), Color(0.15, 0.4, 0.75), false)
	_local_box(body, Vector3(0.18, 0.1, 0.01), Vector3(cx - 0.08, 1.52, front + 0.045), Color(0.2, 0.75, 0.9), false)
	_local_box(body, Vector3(0.05, 0.12, 0.01), Vector3(cx + 0.13, 1.45, front + 0.045), oscuro, false)
	_local_box(body, Vector3(0.3, 0.2, 0.01), Vector3(cx, 1.15, front + 0.045), oscuro, false)
	# Ventanal: adentro oscuro, repisa con garrafones, marco de aluminio y vidrios
	var vx := (ventana.x + ventana.y) / 2.0
	var vw := ventana.y - ventana.x
	punto["puerta_x"] = vx
	var aluminio := Color(0.78, 0.79, 0.8)
	if solo_fachada:
		for y in [1.17, 2.33]:
			_local_box(body, Vector3(vw, 0.05, 0.06), Vector3(vx, y, front - 0.03), aluminio, false)
		for lado in [ventana.x + 0.025, ventana.y - 0.025]:
			_local_box(body, Vector3(0.05, 1.18, 0.06), Vector3(lado, 1.75, front - 0.03), aluminio, false)
		_anuncio(body, punto, w, front, (despachador.y + ventana.x) / 2.0)
		return body
	_local_box(body, Vector3(vw, 1.2, 0.05), Vector3(vx, 1.75, front - muro + 0.03), Color(0.14, 0.16, 0.18), false)
	var garrafones := int(vw / 0.42)
	for i in garrafones:
		var g := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.1
		cilindro.bottom_radius = 0.13
		cilindro.height = 0.42
		cilindro.radial_segments = 8
		cilindro.rings = 1
		cilindro.material = _color_material(Color(0.35, 0.6, 0.9), false)
		g.mesh = cilindro
		g.position = Vector3(ventana.x + 0.21 + i * 0.42, 1.38, front - muro + 0.16)
		g.visibility_range_end = 60.0
		body.add_child(g)
	for y in [1.17, 1.72, 2.33]:
		_local_box(body, Vector3(vw, 0.05, 0.06), Vector3(vx, y, front - 0.03), aluminio, false)
	var hojas := 3 if vw > 2.4 else 2
	for i in hojas + 1:
		_local_box(body, Vector3(0.05, 1.18, 0.06), Vector3(ventana.x + 0.025 + (vw - 0.05) * i / hojas, 1.75, front - 0.03), aluminio, false)
	var vidrio := MeshInstance3D.new()
	var plano := QuadMesh.new()
	plano.size = Vector2(vw, 1.16)
	var material_vidrio := StandardMaterial3D.new()
	material_vidrio.albedo_color = Color(0.7, 0.85, 0.95, 0.18)
	material_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_vidrio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plano.material = material_vidrio
	vidrio.mesh = plano
	vidrio.position = Vector3(vx, 1.75, front - 0.05)
	vidrio.visibility_range_end = 80.0
	body.add_child(vidrio)
	_anuncio(body, punto, w, front, (despachador.y + ventana.x) / 2.0)
	return body


# Taqueria como la escena de adentro (scenes/interiores/taqueria.tscn) vista desde la
# calle: muro blanco con rodapie y franja rojos, sin letrero, la cortina enrollada sobre un vano
# ancho y adentro el cuarto con mesas rojas con sus sillas y refris rojos; en la
# banqueta, frente al vano y un poco a la derecha, el puesto de tacos (Mostrador estilo
# puesto, con su trompo y su humo) y el taquero de espaldas al local. La flecha va en
# el lado libre del vano (`punto["puerta_x"]`).
func _make_taqueria(punto: Dictionary) -> Node3D:
	var nombre: String = punto.get("nombre", "")
	var w: float = maxf(punto["ancho"], LOCAL_MIN.x)
	var d: float = maxf(punto["fondo"], LOCAL_MIN.y)
	var h := LOCAL_HEIGHT
	var front: float = punto["fondo"] / 2.0
	var vano := minf(w - 1.2, 4.0)
	var vano_alto := 2.3
	var cuarto := minf(d - 0.5, TAQUERIA_CUARTO)
	var pilar := (w - vano) / 2.0
	var body := StaticBody3D.new()
	body.name = "taqueria_%s" % nombre
	# Lo de atras del cuarto, macizo, con el rodapie hacia adentro
	var atras := d - cuarto
	_fachada_tramo(body, Vector2(-w / 2.0, w / 2.0), 0.0, h, front - cuarto - atras / 2.0, atras, TAQUERIA_ROJO)
	# Muros de los lados (pilares de la fachada a todo el fondo del cuarto), dintel y techo
	for lado in [-1.0, 1.0]:
		var x: float = lado * (vano + pilar) / 2.0
		_fachada_tramo(body, Vector2(x - pilar / 2.0, x + pilar / 2.0), 0.0, h, front - cuarto / 2.0, cuarto, TAQUERIA_ROJO)
	_local_box(body, Vector3(vano, h - vano_alto, 0.3), Vector3(0.0, (h + vano_alto) / 2.0, front - 0.15), LOCAL_BLANCO, false)
	_local_box(body, Vector3(vano, 0.2, cuarto), Vector3(0.0, h - 0.1, front - cuarto / 2.0), Color(0.85, 0.85, 0.82), false)
	_local_box(body, Vector3(vano, 0.02, cuarto), Vector3(0.0, 0.01, front - cuarto / 2.0), Color(0.6, 0.55, 0.5), false)
	# Tubo de luz en el techo (sin luz de verdad) y la cortina enrollada
	var tubo := _local_box(body, Vector3(1.2, 0.05, 0.15), Vector3(0.0, h - 0.23, front - cuarto * 0.5), Color(1.0, 1.0, 0.95), false)
	var material_tubo := StandardMaterial3D.new()
	material_tubo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_tubo.albedo_color = Color(0.95, 0.97, 1.0)
	tubo.material_override = material_tubo
	_local_box(body, Vector3(vano, 0.25, 0.25), Vector3(0.0, vano_alto + 0.07, front + 0.12), Color(0.55, 0.57, 0.6), false)

	var muebles := Node3D.new()
	muebles.name = "Muebles"
	body.add_child(muebles)
	var semilla := absi(nombre.hash())
	# Refris rojos contra el muro izquierdo y mesas en lo que queda
	var refris := 2 if cuarto > 3.2 else 1
	for i in refris:
		var refri := Refrigerador.new()
		refri.ancho = 0.8
		refri.fondo = 0.65
		refri.color = Color(0.6, 0.13, 0.11)
		refri.repisas = 5
		refri.luz = 0.0
		refri.semilla = semilla + i
		refri.position = Vector3(-vano / 2.0 + 0.36, 0.0, front - cuarto + 0.6 + i * 0.82)
		refri.rotation.y = PI / 2.0
		muebles.add_child(refri)
	var mesas := [Vector3(0.45, 0.0, front - 1.0), Vector3(-0.35, 0.0, front - 2.4), Vector3(0.9, 0.0, front - 3.4)]
	for i in mesas.size():
		var pos: Vector3 = mesas[i]
		if pos.z < front - cuarto + 0.7:
			break
		var mesa := Mesa.new()
		mesa.color = TAQUERIA_MESA
		mesa.semilla = semilla + i
		mesa.position = pos
		mesa.rotation.y = deg_to_rad(float((semilla + i * 7) % 11) - 5.0)
		muebles.add_child(mesa)
	# El puesto en la banqueta, con los clientes del lado de la calle (+Z), y el taquero
	# entre el puesto y el local, viendo a la calle
	var puesto := Mostrador.new()
	puesto.estilo = 5
	puesto.ancho = minf(2.1, vano - 1.4)
	puesto.alto = 0.92
	puesto.fondo = 0.7
	puesto.color = Color(0.7, 0.1, 0.08)
	puesto.semilla = semilla
	var puesto_x := vano / 2.0 - puesto.ancho / 2.0 - 0.1
	puesto.position = Vector3(puesto_x, 0.0, front + TAQUERIA_PUESTO)
	muebles.add_child(puesto)
	var caja := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(puesto.ancho, 1.0, puesto.fondo)
	caja.shape = forma
	caja.position = puesto.position + Vector3(0.0, 0.5, 0.0)
	body.add_child(caja)
	if vendedor_escena:
		var taquero := vendedor_escena.instantiate() as Node3D
		taquero.name = "Taquero"
		taquero.position = Vector3(puesto_x + 0.1, 0.0, front + TAQUERIA_PUESTO - 0.7)
		taquero.rotation.y = PI
		taquero.set("tint", Color(0.85, 0.8, 0.7))
		taquero.ready.connect(func() -> void:
			(taquero.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
		muebles.add_child(taquero)
	punto["puerta_x"] = (-vano / 2.0 + puesto_x - puesto.ancho / 2.0) / 2.0
	# Los muebles se arman al entrar al arbol: hasta entonces no tienen mallas
	muebles.ready.connect(_detalle_lejos.bind(muebles), CONNECT_ONE_SHOT)
	return body


# Los muebles y el puesto de la taqueria solo de cerca (sus piezas son hijos internos)
func _detalle_lejos(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = TAQUERIA_DETALLE
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif node is Light3D:
		var luz := node as Light3D
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = TAQUERIA_DETALLE * 0.5
		luz.distance_fade_length = TAQUERIA_DETALLE * 0.25
	for child in node.get_children(true):
		_detalle_lejos(child)


# Un tramo de la fachada entre x.x y x.y, de y0 a y1: muro blanco y, donde le toquen,
# el rodapie y la franja de `acento` (cascara apenas mas grande, como en _make_local)
func _fachada_tramo(body: StaticBody3D, x: Vector2, y0: float, y1: float, z: float, grueso: float, acento: Color) -> void:
	var ancho := x.y - x.x
	var centro := (x.x + x.y) / 2.0
	_local_box(body, Vector3(ancho, y1 - y0, grueso), Vector3(centro, (y0 + y1) / 2.0, z), LOCAL_BLANCO, true)
	for banda: Vector2 in [Vector2(0.0, RODAPIE), Vector2(RODAPIE + 0.2, RODAPIE + 0.3)]:
		var abajo := maxf(banda.x, y0)
		var arriba := minf(banda.y, y1)
		if arriba > abajo:
			_local_box(body, Vector3(ancho + 0.03, arriba - abajo, grueso + 0.03), Vector3(centro, (abajo + arriba) / 2.0, z), acento, false)


# Anuncio de la purificadora en la orilla de la banqueta: lona, letreros, lamparas,
# los postes que lo cargan y dos largueros hasta la fachada (sin techo). El poste de
# en medio va en `poste_x`, entre el despachador y el ventanal, para no tapar la ventanilla
func _anuncio(body: StaticBody3D, punto: Dictionary, w: float, front: float, poste_x: float) -> void:
	var z := front + PURIFICADORA_POSTES
	var abajo := PURIFICADORA_ANUNCIO.x
	var alto := PURIFICADORA_ANUNCIO.y
	var largo := w + 0.3
	var centro := Vector3(0.0, abajo + alto / 2.0, z)
	var blanco := Color(0.92, 0.92, 0.9)
	_local_box(body, Vector3(largo + 0.08, alto + 0.08, 0.08), centro + Vector3(0, 0, -0.05), Color(0.3, 0.3, 0.32), false)
	var lona := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(largo, alto)
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("albedo_texture", PURIFICADORA_LONA)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("deterioro_modo", 1)
	quad.material = material
	lona.mesh = quad
	lona.position = centro
	lona.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(lona)
	# Letreros: arriba "Agua purificada", la marca grande y el lema, entre el garrafon
	# (izquierda) y el vaso (derecha) de la lona
	# En DENUE casi todas se llaman "Purificadora de Agua X": en el anuncio va solo X
	var marca: String = punto.get("nombre", "").to_upper()
	for prefijo in ["PURIFICADORA DE AGUA ", "AGUA PURIFICADA ", "PURIFICADORA "]:
		if marca.begins_with(prefijo):
			marca = marca.substr(prefijo.length())
			break
	if marca == "" or marca.length() > 18 or marca.contains("SIN NOMBRE"):
		marca = "AGUA PURA"
	var x_texto := largo * 0.04
	var ancho_texto := largo * 0.55
	for renglon in [["Agua purificada", 0.33, Color(0.15, 0.55, 0.85), 0.55], [marca, 0.08, Color(0.2, 0.25, 0.65), 1.0],
			["Salud y pureza en cada gota", -0.17, Color(0.1, 0.2, 0.45), 0.6]]:
		var label := Label3D.new()
		label.text = renglon[0]
		label.font_size = 64
		label.outline_size = 0
		label.modulate = renglon[2]
		# ~0.7 del font_size por letra (mayusculas)
		label.pixel_size = minf(alto * 0.3 * renglon[3] / 64.0, ancho_texto / (label.text.length() * 45.0))
		label.position = Vector3(x_texto, centro.y + alto * renglon[1], z + 0.01)
		label.visibility_range_end = 80.0
		body.add_child(label)
	# Lamparas arriba, viendo al anuncio
	for i in 3:
		var lx := -largo * 0.35 + largo * 0.35 * i
		_local_box(body, Vector3(0.03, 0.03, 0.35), Vector3(lx, abajo + alto + 0.06, z + 0.15), Color(0.15, 0.15, 0.15), false)
		_local_box(body, Vector3(0.2, 0.08, 0.12), Vector3(lx, abajo + alto + 0.08, z + 0.35), Color(0.15, 0.15, 0.15), false)
	# Postes en la orilla de la banqueta y largueros hasta la fachada
	for px in [-w / 2.0 + 0.1, poste_x, w / 2.0 - 0.1]:
		_local_box(body, Vector3(0.1, abajo, 0.1), Vector3(px, abajo / 2.0, z), blanco, true)
	for px in [-w / 2.0 + 0.1, w / 2.0 - 0.1]:
		_local_box(body, Vector3(0.08, 0.08, PURIFICADORA_POSTES), Vector3(px, abajo - 0.04, front + PURIFICADORA_POSTES / 2.0), blanco, false)


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
