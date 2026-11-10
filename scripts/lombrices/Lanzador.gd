class_name Lanzador
extends Node
# Las cosas que se avientan (la tecla 3, arma_3): sal y molotovs del inventario
# (InventoryItemData.arrojar). Otra vez 3 cambia entre sal y molotov. Hijo de Player, como la Pistola.
# La molotov se carga (JJ, 2026-11-09): mientras dejas apretado el clic, el punto donde va a caer
# avanza hacia donde ves, de CARGA_DESDE a ALCANCE m en CARGA_DURA s, y en el piso se ve el area
# que va a quemar (un circulo de Arrojadizo.FUEGO_RADIO) con la parabola en puntitos. Al soltar,
# Player.aventar_molotov hace el OverhandThrow y a medio tiro (soltar_molotov) sale de la mano
# hacia ese punto. Se quita del inventario al soltar el clic.
# La sal ya no se avienta en bolsa (JJ, 2026-11-09): es un punado hacia donde ves. Player.aventar_sal
# hace la animacion (Sword_Heavy_A) y, cuadro a cuadro mientras la mano pasa por enfrente (hasta
# Player.AVIENTA_ARCO a cada lado), deja un arco de humo blanco como la estela del machete y llama
# salar_tramo con ese pedazo de arco: del cuerpo a PUNADO_ALCANCE, las crias que alcanza mueren
# al instante (EnjambreLombrices.salar_cono). No deja nada en el piso (JJ).

const ALCANCE := 16.0           # m de la mano al punto donde cae
const VUELO_POR_M := 1.0 / 12.0 # s de vuelo por metro (y entre VUELO.x y VUELO.y)
const VUELO := Vector2(0.35, 1.2)
const PUNTOS := 24
const COLOR_MARCA := Color(1.0, 0.95, 0.4)
const NOMBRES := ["", "Sal", "Molotov"]
const ESPERA := 0.5
# La molotov cargada
const CARGA_DESDE := 3.0        # m: un clic sin dejarlo apretado
const CARGA_DURA := 1.2         # s apretado para llegar a ALCANCE
const COLOR_AREA := Color(1.0, 0.45, 0.1)
# El punado de sal
const PUNADO_ALCANCE := 3.3     # m del cuerpo que alcanza (el arco de humo llega a Player.AVIENTA_HUMO.y 3.1)
const PUNADO_HOLGURA := 0.15    # rad de mas a cada lado del pedazo de arco de cada cuadro
const PUNADO_COME := 0          # puntos que se le comen a cada cria alcanzada; 0 = muere entera (JJ)

# Para pruebas (la arena del carcamo, JJ): aventar no gasta la sal ni la molotov
static var infinitos := false

var jugador: CharacterBody3D
var activo := false
var tipo := 1
var _arco: MultiMesh
var _arco_nodo: MultiMeshInstance3D
var _texto: Label
var _espera := 0.0
var _marca: MeshInstance3D
var _marca_mat: StandardMaterial3D
var _salados := {}             # bloques de crias ya salados en esta aventada
var _cargando := false          # la molotov: el clic sigue apretado
var _carga := 0.0
var _destino := Vector3.ZERO     # a donde va la molotov que se esta aventando
var _area: MeshInstance3D


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
	anillo.inner_radius = Arrojadizo.FUEGO_RADIO - 0.08
	anillo.outer_radius = Arrojadizo.FUEGO_RADIO
	anillo.rings = 48
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
	# El area que quema, rellena y transparente
	var disco := CylinderMesh.new()
	disco.top_radius = Arrojadizo.FUEGO_RADIO
	disco.bottom_radius = Arrojadizo.FUEGO_RADIO
	disco.height = 0.01
	disco.radial_segments = 48
	disco.rings = 1
	var relleno := StandardMaterial3D.new()
	relleno.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	relleno.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	relleno.albedo_color = Color(COLOR_AREA, 0.22)
	disco.material = relleno
	_area = MeshInstance3D.new()
	_area.mesh = disco
	_area.visible = false
	_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marca.add_child(_area)
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
	_cargando = false
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
	# La molotov: empieza a cargar; sale al soltar el clic (soltar_clic)
	if tipo == 2:
		_cargando = true
		_carga = 0.0
		return
	# La sal: el personaje avienta el punado (Player.aventar_sal) y pega a media animacion
	if tipo == 1 and not jugador.aventar_sal(_dir_punado()):
		return
	if not infinitos:
		inventario.remove_item(indice)
	_espera = ESPERA
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.ver("remedios")


# Soltaste el clic: la molotov cargada se avienta hacia donde quedo el area
func soltar_clic() -> void:
	if not _cargando:
		return
	_cargando = false
	if not activo or tipo != 2:
		return
	var inventario := get_node_or_null("/root/Inventory")
	var indice := -1
	if inventario:
		for i in inventario.items.size():
			var item: InventoryItemData = inventario.items[i]
			if item and item.arrojar == 2:
				indice = i
				break
	if indice < 0:
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	var dir := _dir_punado()
	_destino = _destino_carga(dir)
	if not jugador.aventar_molotov(dir):
		return
	if not infinitos:
		inventario.remove_item(indice)
	_espera = ESPERA
	var libreta := get_node_or_null("/root/Libreta")
	if libreta:
		libreta.ver("remedios")


# A medio OverhandThrow (Player._seguir_aventada): sale de la mano hacia _destino
func soltar_molotov() -> void:
	var tiro := _tiro(_desde_mano(), _destino)
	Arrojadizo.lanzar(jugador.get_tree().current_scene, tiro.desde, tiro.vel, 2, [jugador.get_rid()])


func _desde_mano() -> Vector3:
	var mano: Node3D = jugador.get("_mano")
	return mano.global_position if mano and mano.is_inside_tree() else jugador.global_position + Vector3.UP * 0.5


# Donde cae con lo cargado: CARGA_DESDE a ALCANCE m hacia `dir`, sin pasar paredes, en el piso
func _destino_carga(dir: Vector3) -> Vector3:
	var lejos := lerpf(CARGA_DESDE, ALCANCE, clampf(_carga / CARGA_DURA, 0.0, 1.0))
	var espacio := jugador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [jugador.get_rid()]
	var pecho := jugador.global_position + Vector3.UP * 0.6
	var destino := pecho + dir * lejos
	var pared := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(pecho, destino, 1, excluir))
	if pared:
		destino = pared.position - dir * 0.3
	var abajo := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(destino + Vector3.UP * 0.5, destino + Vector3.DOWN * 30.0, 1, excluir))
	return abajo.position if abajo else destino


# La parabola de `desde` a `destino`: {desde, destino, vel, vuelo}
func _tiro(desde: Vector3, destino: Vector3) -> Dictionary:
	var vuelo := clampf(desde.distance_to(destino) * VUELO_POR_M, VUELO.x, VUELO.y)
	var vel := (destino - desde) / vuelo + Vector3.UP * 0.5 * Arrojadizo.GRAVEDAD * vuelo
	return {"desde": desde, "destino": destino, "vel": vel, "vuelo": vuelo}


# Hacia donde ves (la camara, en planta)
func _dir_punado() -> Vector3:
	var camara := jugador.get_viewport().get_camera_3d()
	var dir := -camara.global_basis.z if camara else -jugador.global_basis.z
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD


# Empieza una aventada: las crias se pueden volver a salar
func empezar_punado() -> void:
	_salados = {}


# La mano barrio de `antes` a `ahora` (direcciones en planta desde el cuerpo, Player._seguir_aventada):
# sala ese sector, del cuerpo a PUNADO_ALCANCE
func salar_tramo(antes: Vector3, ahora: Vector3) -> void:
	var medio := (antes + ahora).normalized()
	if medio.length_squared() < 0.5:
		medio = ahora
	var abre := cos(minf(antes.angle_to(ahora) * 0.5 + PUNADO_HOLGURA, PI))
	for enjambre in jugador.get_tree().get_nodes_in_group("lombrices"):
		if enjambre.has_method("salar_cono"):
			enjambre.salar_cono(jugador.global_position, medio, PUNADO_ALCANCE, abre, PUNADO_COME, _salados)


# La mano pasa al frente: suena la sal
func sonar_punado() -> void:
	Sonidos.tocar(self, "fizz", -4.0, 1.3)


func _process(delta: float) -> void:
	_espera -= delta
	if not activo or jugador == null:
		return
	_texto.visible = true
	_texto.text = "%s (%d) · 3 cambia" % [NOMBRES[tipo], cuantos(tipo)]
	if tipo == 1:
		# El punado no lleva guia (JJ): sale hacia donde ves
		_arco.visible_instance_count = 0
		_marca.visible = false
		return
	# La molotov: mientras cargas (y hasta que sale) se ve a donde cae y el area que quema
	var aventando: bool = jugador.get("_avienta_molotov") == true and float(jugador.get("_aventando")) >= 0.0
	if _cargando:
		_carga += delta
		_destino = _destino_carga(_dir_punado())
	if not _cargando and not aventando:
		_arco.visible_instance_count = 0
		_marca.visible = false
		return
	var tiro := _tiro(_desde_mano(), _destino)
	var desde: Vector3 = tiro.desde
	var vel: Vector3 = tiro.vel
	var vuelo: float = tiro.vuelo
	for k in PUNTOS:
		var t := vuelo * float(k + 1) / (PUNTOS + 1)
		var p := desde + vel * t + Vector3.DOWN * 0.5 * Arrojadizo.GRAVEDAD * t * t
		_arco.set_instance_transform(k, Transform3D(Basis.IDENTITY, p))
	_arco.visible_instance_count = PUNTOS
	_marca.visible = true
	_area.visible = true
	_marca.global_position = _destino + Vector3.UP * 0.04
	# Ya no avanza mas: amarillo
	_marca_mat.albedo_color = COLOR_MARCA if _carga >= CARGA_DURA else COLOR_AREA
