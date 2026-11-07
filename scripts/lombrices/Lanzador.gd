class_name Lanzador
extends Node
# Las cosas que se avientan (la tecla 3, arma_3): sal y molotovs del inventario
# (InventoryItemData.arrojar). Con el lanzador en la mano se ve la parabola en puntitos de
# pixel y una marca donde va a caer: cae justo donde apunta la mira (hasta ALCANCE m; mas lejos,
# la marca se pone roja y cae al limite). Sale de la mano derecha. Clic (attack) avienta uno y lo
# quita del inventario. Otra vez 3 cambia entre sal y molotov. Hijo de Player, como la Pistola.

const ALCANCE := 16.0           # m de la mano al punto donde cae
const VUELO_POR_M := 1.0 / 12.0 # s de vuelo por metro (y entre VUELO.x y VUELO.y)
const VUELO := Vector2(0.35, 1.2)
const PUNTOS := 24
const COLOR_MARCA := Color(1.0, 0.95, 0.4)
const COLOR_LEJOS := Color(1.0, 0.25, 0.2)
const NOMBRES := ["", "Sal", "Molotov"]
const ESPERA := 0.5

var jugador: CharacterBody3D
var activo := false
var tipo := 1
var _arco: MultiMesh
var _arco_nodo: MultiMeshInstance3D
var _texto: Label
var _espera := 0.0
var _marca: MeshInstance3D
var _marca_mat: StandardMaterial3D


func _ready() -> void:
	_arco = MultiMesh.new()
	_arco.transform_format = MultiMesh.TRANSFORM_3D
	var punto := BoxMesh.new()
	punto.size = Vector3.ONE * 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.4)
	punto.material = material
	_arco.mesh = punto
	_arco.instance_count = PUNTOS
	_arco.visible_instance_count = 0
	_arco_nodo = MultiMeshInstance3D.new()
	_arco_nodo.multimesh = _arco
	_arco_nodo.top_level = true
	_arco_nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arco_nodo.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 200, 1000))
	add_child(_arco_nodo)
	var anillo := TorusMesh.new()
	anillo.inner_radius = 0.22
	anillo.outer_radius = 0.3
	anillo.rings = 8
	anillo.ring_segments = 3
	_marca_mat = StandardMaterial3D.new()
	_marca_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marca_mat.albedo_color = COLOR_MARCA
	anillo.material = _marca_mat
	_marca = MeshInstance3D.new()
	_marca.mesh = anillo
	_marca.top_level = true
	_marca.visible = false
	_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marca)
	var capa := CanvasLayer.new()
	capa.layer = 4
	add_child(capa)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_texto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_texto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto.offset_right = -10.0
	_texto.offset_bottom = -48.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 4)
	_texto.visible = false
	capa.add_child(_texto)


# 3: lo toma; si ya lo traes, cambia de cosa
func tomar() -> void:
	if activo:
		tipo = 2 if tipo == 1 else 1
	activo = true


func soltar() -> void:
	activo = false
	_arco.visible_instance_count = 0
	_texto.visible = false
	_marca.visible = false


func cuantos(cual: int) -> int:
	var inventario := get_node_or_null("/root/Inventory")
	if inventario == null:
		return 0
	var n := 0
	for item: InventoryItemData in inventario.items:
		if item and item.arrojar == cual:
			n += 1
	return n


func lanzar() -> void:
	if not activo or _espera > 0.0:
		return
	var inventario := get_node_or_null("/root/Inventory")
	if inventario == null:
		return
	var indice := -1
	for i in inventario.items.size():
		var item: InventoryItemData = inventario.items[i]
		if item and item.arrojar == tipo:
			indice = i
			break
	if indice < 0:
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	inventario.remove_item(indice)
	_espera = ESPERA
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.ver("remedios")
	var tiro := _apuntar()
	Arrojadizo.lanzar(jugador.get_tree().current_scene, tiro.desde, tiro.vel, tipo, [jugador.get_rid()])


# De la mano al punto de la mira: {desde, destino, vel, vuelo, alcanza}
func _apuntar() -> Dictionary:
	var mano: Node3D = jugador.get("_mano")
	var desde := mano.global_position if mano and mano.is_inside_tree() else jugador.global_position + Vector3.UP * 0.5
	var espacio := jugador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [jugador.get_rid()]
	var camara := jugador.get_viewport().get_camera_3d()
	var destino := desde - jugador.global_basis.z * ALCANCE
	if camara:
		var centro := jugador.get_viewport().get_visible_rect().size / 2.0
		var origen := camara.project_ray_origin(centro)
		var dir := camara.project_ray_normal(centro)
		var lejos := origen.distance_to(desde) + ALCANCE
		var pego := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(origen, origen + dir * lejos, 1, excluir))
		destino = pego.position if pego else origen + dir * lejos
	var alcanza := desde.distance_to(destino) <= ALCANCE
	if not alcanza:
		destino = desde + (destino - desde).normalized() * ALCANCE
	# Si quedo en el aire (mas alla de todo), al piso de abajo
	var abajo := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(destino + Vector3.UP * 0.1, destino + Vector3.DOWN * 30.0, 1, excluir))
	if abajo and destino.y - abajo.position.y > 0.2:
		destino = abajo.position
	var vuelo := clampf(desde.distance_to(destino) * VUELO_POR_M, VUELO.x, VUELO.y)
	var vel := (destino - desde) / vuelo + Vector3.UP * 0.5 * Arrojadizo.GRAVEDAD * vuelo
	return {"desde": desde, "destino": destino, "vel": vel, "vuelo": vuelo, "alcanza": alcanza}


func _process(delta: float) -> void:
	_espera -= delta
	if not activo or jugador == null:
		return
	_texto.visible = true
	_texto.text = "%s (%d) · 3 cambia" % [NOMBRES[tipo], cuantos(tipo)]
	# La misma parabola con la que sale: de la mano a la marca
	var tiro := _apuntar()
	var desde: Vector3 = tiro.desde
	var vel: Vector3 = tiro.vel
	var vuelo: float = tiro.vuelo
	for k in PUNTOS:
		var t := vuelo * float(k + 1) / (PUNTOS + 1)
		var p := desde + vel * t + Vector3.DOWN * 0.5 * Arrojadizo.GRAVEDAD * t * t
		_arco.set_instance_transform(k, Transform3D(Basis.IDENTITY, p))
	_arco.visible_instance_count = PUNTOS
	_marca.visible = true
	_marca.global_position = tiro.destino + Vector3.UP * 0.04
	_marca_mat.albedo_color = COLOR_MARCA if tiro.alcanza else COLOR_LEJOS
