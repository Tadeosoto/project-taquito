extends Node3D

# Bodegas huecas del mapa, a las que se puede entrar caminando. Los lotes vienen de
# resources/map/bodegas_mapa.json (tools/map_import/prepare_osm.py place_bodegas):
# centro del frente (x, z), giro (+Z hacia la calle), ancho, fondo, alto, color.
# Cada bodega es un cascaron a la medida (muros y techo de arco de lamina, cerchas,
# piso de concreto) y su frente son vanos sacados de un modelo de Sketchfab
# (`modulo`: la Industrial Warehouse; de su muro de cortinas se recorta un vano y se
# repite). Algunos vanos estan abiertos (sin cortina) y por ahi se entra; entre mas
# deterioro en la zona (Deterioro.zona) mas abiertos, hoyos en los muros y en el techo.
# Adentro: racks, estantes y cajas de Sketchfab, con colision.
# Como MapCasas, se crean y se quitan por celdas segun la distancia a target_path.

const CASA_SHADER := preload("res://shaders/ps1_casa.gdshader")
const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const SUELO_SHADER := preload("res://shaders/ps1_suelo.gdshader")

const CELDA := 64.0
const GRUESO := 0.2
# Frente aproximado de cada vano (m); se ajusta para que quepan enteros
const VANO := 6.0
const ARCO_SEGMENTOS := 8
# Alto del arco del techo como fraccion del ancho
const ARCO_FLECHA := 0.1
const CERCHA_CADA := 6.0
# Largo (m) de cada panel del techo: con deterioro faltan algunos
const PANEL := 6.0
# Lo que queda libre (m) detras del frente, para entrar; y el pasillo entre racks
const FRENTE_LIBRE := 5.0
const PASILLO := 3.2
# Solo va una de cada HILERAS_CADA hileras de racks (el resto queda de pasillo):
# con todas eran demasiados estantes
const HILERAS_CADA := 2
# Cada cuantos metros se repite la textura de lamina
const TEXTURA_M := 2.4

@export_file("*.json") var bodegas_path := "res://resources/map/bodegas_mapa.json"

# Modelo del que se recorta un vano del frente, y donde esta el vano en la escena:
# el muro que ve a +X, el rango de Z de un vano (puerta y medio pilar a cada lado),
# la puerta (z0, y0, z1, y1), el piso y lo alto del muro
@export var modulo: PackedScene
@export var modulo_vano := Vector2(-0.21, 1.075)
@export var modulo_puerta := Vector4(0.0, 0.03, 0.87, 1.13)
@export var modulo_piso := 0.03
@export var modulo_alto := 1.71
# Grueso (unidades del modelo) de la franja del muro que se toma
@export var modulo_hondo := 0.25

@export var lamina: Texture2D
@export var lamina_techo: Texture2D
@export var piso_textura: Texture2D

# Adentro: rack (se usa su primera malla), estante oxidado y cajas
@export var rack: PackedScene
@export var estante: PackedScene
@export var cajas: PackedScene

@export var target_path: NodePath
@export var load_radius := 260.0
@export var unload_radius := 330.0
@export var muros_end := 250.0
@export var adentro_end := 80.0

var _celdas := {}          # Vector2i -> Array de bodegas (Dictionary)
var _nodos := {}           # Vector2i -> Node3D
var _vanos := {}           # "cerrado"/"abierto" -> ArrayMesh (vano de 1 x 1 x 1)
var _props := {}           # nombre -> {mesh, aabb}
var _materiales := {}
var _target: Node3D
var _timer := 0.0
# Celdas por armar (la mas cercana primero) y la que se esta armando en un hilo
var _pendientes: Array[Vector2i] = []
var _tarea := -1
var _tarea_key: Vector2i
var _tarea_res := []


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(bodegas_path)) \
			if FileAccess.file_exists(bodegas_path) else null
	if not data is Dictionary:
		push_warning("MapBodegas: no se pudo leer %s" % bodegas_path)
		return
	for bodega: Dictionary in data["bodegas"]:
		var key := Vector2i(floori(bodega["x"] / CELDA), floori(bodega["z"] / CELDA))
		if not _celdas.has(key):
			_celdas[key] = []
		_celdas[key].append(bodega)
	if modulo:
		_preparar_vanos()
	for nombre in ["rack", "estante", "cajas"]:
		var escena: PackedScene = get(nombre)
		if escena:
			_props[nombre] = _hornear_prop(escena, nombre == "rack")
	# Los materiales y el deterioro se preparan aqui para que el hilo solo los lea
	for textura in [lamina, lamina_techo, null]:
		_material_lamina(textura)
	_material_piso()
	Deterioro.zona(0.0, 0.0)
	_target = get_node_or_null(target_path) as Node3D
	_update_nearby(true)


func _exit_tree() -> void:
	if _tarea >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarea)
		_tarea = -1
		(_tarea_res[0] as Node).free()


func _process(delta: float) -> void:
	# Una celda a la vez: se arma en un hilo y aqui solo se agrega con su colision
	if _tarea >= 0 and WorkerThreadPool.is_task_completed(_tarea):
		WorkerThreadPool.wait_for_task_completion(_tarea)
		_tarea = -1
		_agregar(_tarea_key, _tarea_res)
	if _tarea < 0 and not _pendientes.is_empty():
		_tarea_key = _pendientes.pop_front()
		_tarea = WorkerThreadPool.add_task(func(): _tarea_res = _crear_celda(_celdas[_tarea_key]))
	if _target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_nearby()


# `ahora`: armar en el momento (al inicio, para que haya colision desde el primer frame)
func _update_nearby(ahora := false) -> void:
	var distancias := {}
	for key: Vector2i in _celdas:
		var distance := 0.0
		if _target:
			var p := _target.global_position
			var dx := maxf(maxf(key.x * CELDA - p.x, p.x - (key.x + 1) * CELDA), 0.0)
			var dz := maxf(maxf(key.y * CELDA - p.z, p.z - (key.y + 1) * CELDA), 0.0)
			distance = Vector2(dx, dz).length()
		distancias[key] = distance
		var armada := _nodos.has(key) or key in _pendientes or (_tarea >= 0 and key == _tarea_key)
		if distance < load_radius and not armada:
			if ahora:
				_agregar(key, _crear_celda(_celdas[key]))
			else:
				_pendientes.append(key)
		elif distance > unload_radius:
			_pendientes.erase(key)
			if _nodos.has(key):
				_nodos[key].queue_free()
				_nodos.erase(key)
	_pendientes.sort_custom(func(a, b): return distancias[a] < distancias[b])


func _agregar(key: Vector2i, res: Array) -> void:
	var node: Node3D = res[0]
	node.name = "celda_%d_%d" % [key.x, key.y]
	node.add_child(_cuerpo(res[1]))
	add_child(node)
	_nodos[key] = node


# Arma las mallas de una celda sin tocar el arbol ni la fisica, asi que puede correr
# en un hilo. Devuelve [Node3D, cajas de colision para _cuerpo].
func _crear_celda(bodegas: Array) -> Array:
	var celda := Node3D.new()
	var cajas := []            # [Transform3D del centro, tamano]
	var tools := {}            # material -> SurfaceTool del cascaron
	var vanos := {"cerrado": [], "abierto": []}
	var props := {}            # nombre -> [Transform3D]
	for bodega: Dictionary in bodegas:
		_armar_bodega(bodega, tools, vanos, props, cajas)

	var mesh := ArrayMesh.new()
	for material: Material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var cascaron := MeshInstance3D.new()
	cascaron.mesh = mesh
	cascaron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cascaron.visibility_range_end = muros_end
	celda.add_child(cascaron)
	for tipo: String in vanos:
		if _vanos.has(tipo) and not vanos[tipo].is_empty():
			celda.add_child(_multimesh(_vanos[tipo], vanos[tipo], muros_end))
	for nombre: String in props:
		celda.add_child(_multimesh(_props[nombre]["mesh"], props[nombre], adentro_end))
	return [celda, cajas]


# Origen de la bodega en el centro de su frente, +Z hacia la calle: adentro es
# x en [-ancho/2, ancho/2], z en [-fondo, 0]
func _armar_bodega(b: Dictionary, tools: Dictionary, vanos: Dictionary, props: Dictionary, cajas: Array) -> void:
	var lote := Transform3D(Basis(Vector3.UP, b["rotacion_y"]), Vector3(b["x"], 0.0, b["z"]))
	var ancho: float = b["ancho"]
	var fondo: float = b["fondo"]
	var alto: float = b["alto"]
	var color := Color.html(b["color"])
	var fierro := Color(0.32, 0.31, 0.3)
	var zona := Deterioro.zona(b["x"], b["z"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["semilla"])
	var muro := _material_lamina(lamina)
	var techo := _material_lamina(lamina_techo)
	var fierros := _material_lamina(null)

	# Frente: vanos del modelo, todos del mismo ancho
	var natural := alto * (modulo_vano.y - modulo_vano.x) / (modulo_alto - modulo_piso)
	var n := maxi(1, roundi(ancho / natural))
	var vano := ancho / n
	var siempre := rng.randi_range(0, n - 1)
	var puerta := _puerta_local()   # x0, x1 (fraccion del vano), alto (fraccion)
	for i in n:
		var cx := -ancho / 2.0 + (i + 0.5) * vano
		var abierto := i == siempre or rng.randf() < 0.15 + zona * 0.5
		var xform := lote * Transform3D(Basis.from_scale(Vector3(vano, alto, alto)), Vector3(cx, 0.0, 0.0))
		vanos["abierto" if abierto else "cerrado"].append([xform, Color.WHITE])
		if abierto:
			var x0 := cx + puerta.x * vano
			var x1 := cx + puerta.y * vano
			var y1 := puerta.z * alto
			_colision(cajas, lote, Vector3((x0 + cx - vano / 2.0) / 2.0, alto / 2.0, -0.2), Vector3(x0 - cx + vano / 2.0, alto, 0.4))
			_colision(cajas, lote, Vector3((x1 + cx + vano / 2.0) / 2.0, alto / 2.0, -0.2), Vector3(cx + vano / 2.0 - x1, alto, 0.4))
			_colision(cajas, lote, Vector3((x0 + x1) / 2.0, (y1 + alto) / 2.0, -0.2), Vector3(x1 - x0, alto - y1, 0.4))
			# La cortina enrollada arriba del hueco
			_caja(_st(tools, fierros), lote, Vector3((x0 + x1) / 2.0, y1 - 0.25, -0.7), Vector3(x1 - x0, 0.5, 0.5), fierro)
		else:
			_colision(cajas, lote, Vector3(cx, alto / 2.0, -0.2), Vector3(vano, alto, 0.4))

	# Muros de los lados (con un hoyo si hay deterioro) y de atras
	var st := _st(tools, muro)
	var hoyo_lado := -1.0 if rng.randf() < 0.5 else 1.0
	for lado in [-1.0, 1.0]:
		var x: float = lado * (ancho / 2.0 - GRUESO / 2.0)
		var tramos := [Vector2(-fondo, 0.0)]
		if lado == hoyo_lado and zona > 0.4 and rng.randf() < zona and fondo > 12.0:
			var z := rng.randf_range(-fondo + 4.0, -6.0)
			tramos = [Vector2(-fondo, z - 1.5), Vector2(z + 1.5, 0.0)]
			# Lo que queda arriba del hoyo
			_muro(st, cajas, lote, Vector3(x, (2.6 + alto) / 2.0, z), Vector3(GRUESO, alto - 2.6, 3.0), color)
		for t: Vector2 in tramos:
			_muro(st, cajas, lote, Vector3(x, alto / 2.0, (t.x + t.y) / 2.0), Vector3(GRUESO, alto, t.y - t.x), color)
	_muro(st, cajas, lote, Vector3(0.0, alto / 2.0, -fondo + GRUESO / 2.0), Vector3(ancho, alto, GRUESO), color)

	# Techo de arco: hastiales al frente y atras, paneles (faltan algunos) y cerchas
	var arco := []
	for k in ARCO_SEGMENTOS + 1:
		var x := -ancho / 2.0 + k * ancho / ARCO_SEGMENTOS
		var t := 2.0 * x / ancho
		arco.append(Vector2(x, alto + ARCO_FLECHA * ancho * (1.0 - t * t)))
	for z in [0.0, -fondo]:
		for k in ARCO_SEGMENTOS:
			var a: Vector2 = arco[k]
			var c: Vector2 = arco[k + 1]
			_tri(st, lote, [Vector3(a.x, alto, z), Vector3(a.x, a.y, z), Vector3(c.x, c.y, z)], Vector3(0, 0, 1), color, true)
			_tri(st, lote, [Vector3(a.x, alto, z), Vector3(c.x, c.y, z), Vector3(c.x, alto, z)], Vector3(0, 0, 1), color, true)
	var st_techo := _st(tools, techo)
	var paneles := maxi(1, ceili((fondo + 0.6) / PANEL))
	var largo := (fondo + 0.6) / paneles
	for k in ARCO_SEGMENTOS:
		var a: Vector2 = arco[k]
		var c: Vector2 = arco[k + 1]
		var normal := Vector3(-(c.y - a.y), c.x - a.x, 0.0).normalized()
		for j in paneles:
			if rng.randf() < zona * 0.2:
				continue
			var z0 := 0.3 - j * largo
			var z1 := z0 - largo
			_quad(st_techo, lote, [Vector3(a.x, a.y, z0), Vector3(c.x, c.y, z0), Vector3(c.x, c.y, z1), Vector3(a.x, a.y, z1)],
				normal, color, true)
		# Colision del techo por segmento (para aterrizar en el con el dron)
		var mitad := (a + c) / 2.0
		cajas.append([lote * Transform3D(Basis(Vector3.BACK, atan2(c.y - a.y, c.x - a.x)), Vector3(mitad.x, mitad.y, -fondo / 2.0)),
			Vector3(a.distance_to(c), 0.1, fondo)])
	var st_fierro := _st(tools, fierros)
	var z_cercha := -CERCHA_CADA
	while z_cercha > -fondo + 1.0:
		_caja(st_fierro, lote, Vector3(0.0, alto - 0.15, z_cercha), Vector3(ancho - 2.0 * GRUESO, 0.25, 0.2), fierro)
		for lado in [-1.0, 1.0]:
			_caja(st_fierro, lote, Vector3(lado * (ancho / 2.0 - GRUESO - 0.15), alto / 2.0, z_cercha), Vector3(0.3, alto, 0.3), fierro)
		z_cercha -= CERCHA_CADA

	# Piso de concreto (tapa el pasto del terreno)
	var st_piso := _st(tools, _material_piso())
	_quad(st_piso, lote, [Vector3(-ancho / 2.0, 0.04, 0.0), Vector3(ancho / 2.0, 0.04, 0.0),
		Vector3(ancho / 2.0, 0.04, -fondo), Vector3(-ancho / 2.0, 0.04, -fondo)], Vector3.UP, Color.WHITE, false)

	_acomodar_adentro(lote, ancho, fondo, alto, zona, rng, props, cajas)


# Hileras de racks (o estantes oxidados) a lo largo del fondo, con pasillos; huecos
# donde ya saquearon; cajas tiradas
func _acomodar_adentro(lote: Transform3D, ancho: float, fondo: float, alto: float,
		zona: float, rng: RandomNumberGenerator, props: Dictionary, cajas: Array) -> void:
	if not _props.has("rack"):
		return
	var rack_aabb: AABB = _props["rack"]["aabb"]
	# El rack se gira 90 grados: su largo (x) queda a lo largo del fondo
	var hondo := rack_aabb.size.z
	var largo := rack_aabb.size.x
	# Centro de la caja del rack ya girado
	var centro_rack := Basis(Vector3.UP, PI / 2.0) * rack_aabb.get_center()
	var x := -ancho / 2.0 + GRUESO + 0.8 + hondo / 2.0
	while x + hondo / 2.0 < ancho / 2.0 - GRUESO - 0.8:
		var z := -FRENTE_LIBRE - largo / 2.0
		# z del primero y del ultimo de unos racks seguidos: llevan una sola caja de colision
		var tramo := Vector2(INF, INF)
		while z - largo / 2.0 > -fondo + 1.2:
			var r := rng.randf()
			var es_rack := false
			if r < 0.12 + zona * 0.25:
				pass
			elif r < 0.3 + zona * 0.25 and _props.has("estante"):
				_poner(props, cajas, lote, "estante", Vector3(x, 0.0, z), rng.randf_range(-0.2, 0.2) + PI / 2.0)
			elif rack_aabb.size.y < alto - 0.5:
				_poner(props, [], lote, "rack", Vector3(x, 0.0, z), PI / 2.0)
				es_rack = true
				tramo = Vector2(z if tramo.x == INF else tramo.x, z)
			if not es_rack and tramo.x != INF:
				_tramo_racks(cajas, lote, x, tramo, largo, centro_rack, rack_aabb.size)
				tramo = Vector2(INF, INF)
			if rng.randf() < 0.25:
				var lado := hondo / 2.0 + PASILLO * 0.35
				_poner(props, cajas, lote, "cajas", Vector3(x + lado, 0.0, z + rng.randf_range(-1.0, 1.0)), rng.randf() * TAU)
			z -= largo + 0.1
		if tramo.x != INF:
			_tramo_racks(cajas, lote, x, tramo, largo, centro_rack, rack_aabb.size)
		x += (hondo + PASILLO) * HILERAS_CADA
	# Pilas junto a los muros, en la zona libre de enfrente
	for i in 1 + int(zona * 3.0):
		var lado := -1.0 if rng.randf() < 0.5 else 1.0
		_poner(props, cajas, lote, "cajas", Vector3(lado * (ancho / 2.0 - 1.5), 0.0, rng.randf_range(-FRENTE_LIBRE + 0.5, -1.8)), rng.randf() * TAU)


# Una caja para los racks seguidos de una hilera (girados 90 grados), de `tramo.x`
# (z del primero) a `tramo.y` (z del ultimo)
func _tramo_racks(cajas: Array, lote: Transform3D, x: float, tramo: Vector2, largo: float, centro: Vector3, size: Vector3) -> void:
	_colision(cajas, lote, Vector3(x + centro.x, centro.y, (tramo.x + tramo.y) / 2.0 + centro.z),
		Vector3(size.z, size.y, tramo.x - tramo.y + largo))


# Pone un prop con su caja de colision en `cajas` (los racks pasan [] y la ponen por tramo)
func _poner(props: Dictionary, cajas: Array, lote: Transform3D, nombre: String, pos: Vector3, giro: float) -> void:
	if not _props.has(nombre):
		return
	var aabb: AABB = _props[nombre]["aabb"]
	var xform := lote * Transform3D(Basis(Vector3.UP, giro), pos)
	if not props.has(nombre):
		props[nombre] = []
	props[nombre].append([xform, Color.WHITE])
	cajas.append([xform * Transform3D(Basis.IDENTITY, aabb.get_center()), aabb.size])


func _muro(st: SurfaceTool, cajas: Array, lote: Transform3D, centro: Vector3, size: Vector3, color: Color) -> void:
	_caja(st, lote, centro, size, color)
	_colision(cajas, lote, centro, size)


func _colision(cajas: Array, lote: Transform3D, centro: Vector3, size: Vector3) -> void:
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
		return
	cajas.append([lote * Transform3D(Basis.IDENTITY, centro), size])


# Las cajas de colision de una celda en un solo StaticBody3D. Va en el hilo
# principal: el servidor de fisica no se toca desde el hilo que arma las mallas.
func _cuerpo(cajas: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	for caja: Array in cajas:
		var box := BoxShape3D.new()
		box.size = caja[1]
		var owner_id := body.create_shape_owner(body)
		body.shape_owner_set_transform(owner_id, caja[0])
		body.shape_owner_add_shape(owner_id, box)
	return body


# --- Geometria ---

func _st(tools: Dictionary, material: Material) -> SurfaceTool:
	if not tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[material] = st
	return tools[material]


# Un triangulo con su cara de frente hacia `normal` (en ejes de la bodega); UV en
# metros / TEXTURA_M sobre el plano de la cara. `doble`: tambien por detras.
func _tri(st: SurfaceTool, lote: Transform3D, p: Array, normal: Vector3, color: Color, doble: bool) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	for lado in ([1.0, -1.0] if doble else [1.0]):
		var n: Vector3 = normal * lado
		# Godot dibuja de frente los triangulos en sentido horario
		var orden := [a, b, c] if (b - a).cross(c - a).dot(n) < 0.0 else [a, c, b]
		var wn := (lote.basis * n).normalized()
		for v: Vector3 in orden:
			st.set_normal(wn)
			st.set_color(color)
			st.set_uv(_uv(v, normal))
			st.add_vertex(lote * v)


func _quad(st: SurfaceTool, lote: Transform3D, p: Array, normal: Vector3, color: Color, doble: bool) -> void:
	_tri(st, lote, [p[0], p[1], p[2]], normal, color, doble)
	_tri(st, lote, [p[0], p[2], p[3]], normal, color, doble)


func _uv(v: Vector3, normal: Vector3) -> Vector2:
	if absf(normal.y) > 0.7:
		return Vector2(v.x, v.z) / TEXTURA_M
	# Canales de la lamina verticales: u a lo largo del muro, v hacia abajo
	var u := v.z if absf(normal.x) > absf(normal.z) else v.x
	return Vector2(u, -v.y) / TEXTURA_M


func _caja(st: SurfaceTool, lote: Transform3D, centro: Vector3, size: Vector3, color: Color) -> void:
	var h := size / 2.0
	for eje in 3:
		for signo in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[eje] = signo
			var u := Vector3.ZERO
			var w := Vector3.ZERO
			u[(eje + 1) % 3] = h[(eje + 1) % 3]
			w[(eje + 2) % 3] = h[(eje + 2) % 3]
			var c := centro + n * h[eje]
			_quad(st, lote, [c - u - w, c + u - w, c + u + w, c - u + w], n, color, false)


# --- Materiales ---

func _material_lamina(textura: Texture2D) -> ShaderMaterial:
	var key := ["lamina", textura]
	if not _materiales.has(key):
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter("albedo_texture", textura if textura else _blanco())
		material.set_shader_parameter("use_vertex_color", true)
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("deterioro_modo", 3 if textura else 1)
		_materiales[key] = material
	return _materiales[key]


func _material_piso() -> ShaderMaterial:
	if not _materiales.has("piso"):
		var material := ShaderMaterial.new()
		material.shader = SUELO_SHADER
		material.set_shader_parameter("albedo_texture", piso_textura)
		material.set_shader_parameter("tile_size", 3.0)
		material.set_shader_parameter("piso_tipo", 2)
		material.set_shader_parameter("jitter_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		material.set_shader_parameter("affine_enabled", false)
		_materiales["piso"] = material
	return _materiales["piso"]


var _textura_blanca: ImageTexture

func _blanco() -> ImageTexture:
	if _textura_blanca == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
		image.fill(Color.WHITE)
		_textura_blanca = ImageTexture.create_from_image(image)
	return _textura_blanca


func _multimesh(mesh: Mesh, instancias: Array, end: float) -> MultiMeshInstance3D:
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
	instance.visibility_range_end = end
	return instance


# --- Vano del modelo ---

# La puerta en ejes del vano: (x0, x1) como fraccion del ancho y su alto como
# fraccion del alto del muro
func _puerta_local() -> Vector3:
	var largo := modulo_vano.y - modulo_vano.x
	var zc := (modulo_vano.x + modulo_vano.y) / 2.0
	return Vector3(-(modulo_puerta.z - zc) / largo, -(modulo_puerta.x - zc) / largo,
		(modulo_puerta.w - modulo_piso) / (modulo_alto - modulo_piso))


# Recorta del modelo un vano del muro que ve a +X y lo deja en ejes de 1 x 1 x 1:
# x en [-0.5, 0.5] a lo largo del frente, y en [0, 1] del piso a lo alto del muro,
# z <= 0 hacia adentro (en unidades del alto). Los triangulos que cruzan la orilla
# del vano se cortan. El "abierto" no lleva la cortina.
func _preparar_vanos() -> void:
	var root := modulo.instantiate() as Node3D
	var tris := []         # [[pos, normal, uv] x 3, material]
	_juntar_tris(root, Transform3D.IDENTITY, tris)
	root.free()
	var max_x := -INF
	for tri in tris:
		for v in tri[0]:
			max_x = maxf(max_x, v[0].x)
	var largo := modulo_vano.y - modulo_vano.x
	var zc := (modulo_vano.x + modulo_vano.y) / 2.0
	var alto_u := modulo_alto - modulo_piso
	for tipo in ["cerrado", "abierto"]:
		var tools := {}
		for tri in tris:
			var vs: Array = tri[0]
			var n: Vector3 = (vs[1][0] - vs[0][0]).cross(vs[2][0] - vs[0][0]).normalized()
			var dentro := true
			var arriba := -INF
			for v in vs:
				dentro = dentro and v[0].x > max_x - modulo_hondo
				arriba = maxf(arriba, v[0].y)
			# El muro (ve a +X) y lo que esta metido en el (marcos de las puertas); no el techo
			if not dentro or arriba > modulo_alto + 0.01 or (absf(n.x) <= 0.9 and arriba > modulo_puerta.w + 0.1):
				continue
			if tipo == "abierto" and absf(n.x) > 0.9:
				var c: Vector3 = (vs[0][0] + vs[1][0] + vs[2][0]) / 3.0
				if c.x < max_x - 0.05 and c.z > modulo_puerta.x and c.z < modulo_puerta.z and c.y < modulo_puerta.w:
					continue
			var poly := _recortar(_recortar(vs, modulo_vano.x, 1.0), modulo_vano.y, -1.0)
			if poly.size() < 3:
				continue
			if not tools.has(tri[1]):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[tri[1]] = st
			var st: SurfaceTool = tools[tri[1]]
			for k in range(1, poly.size() - 1):
				for v in [poly[0], poly[k], poly[k + 1]]:
					var p: Vector3 = v[0]
					var vn: Vector3 = v[1]
					# Modelo -> vano: z del modelo a -x, x del modelo hacia adentro
					st.set_normal(Vector3(-vn.z, vn.y, vn.x))
					st.set_uv(v[2])
					st.add_vertex(Vector3(-(p.z - zc) / largo, (p.y - modulo_piso) / alto_u, (p.x - max_x) / alto_u))
		var mesh := ArrayMesh.new()
		for material: Material in tools:
			(tools[material] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material_vano(material))
		_vanos[tipo] = mesh


# Sutherland-Hodgman contra el plano z = limite (signo 1: se queda z >= limite)
func _recortar(poly: Array, limite: float, signo: float) -> Array:
	var out := []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da: float = (a[0].z - limite) * signo
		var db: float = (b[0].z - limite) * signo
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var t := da / (da - db)
			out.append([a[0].lerp(b[0], t), a[1].lerp(b[1], t).normalized(), a[2].lerp(b[2], t)])
	return out


func _juntar_tris(node: Node, xform: Transform3D, tris: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh := (node as MeshInstance3D).mesh
		var normal_xform := xform.basis.inverse().transposed()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices == null:
				indices = PackedInt32Array(range(vertices.size()))
			var material := (node as MeshInstance3D).get_active_material(surface)
			for t in range(0, indices.size(), 3):
				var tri := []
				for k in 3:
					var i: int = indices[t + k]
					tri.append([xform * vertices[i],
						(normal_xform * normals[i]).normalized() if normals != null and not normals.is_empty() else Vector3.UP,
						uvs[i] if uvs != null and not uvs.is_empty() else Vector2.ZERO])
				tris.append([tri, material])
	for child in node.get_children():
		_juntar_tris(child, xform * (child as Node3D).transform if child is Node3D else xform, tris)


# ps1_casa: sin culling (el vano se ve igual desde adentro) y con la mugre de la zona
func _material_vano(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CASA_SHADER
	var texture: Texture2D = _blanco()
	if source is ShaderMaterial and (source as ShaderMaterial).get_shader_parameter("albedo_texture") is Texture2D:
		texture = (source as ShaderMaterial).get_shader_parameter("albedo_texture")
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


# --- Props de adentro ---

# Todas las mallas del prop (o solo la primera) en un ArrayMesh, con el centro de
# su base en el origen; su material PS1 con mugre
func _hornear_prop(escena: PackedScene, solo_primera: bool) -> Dictionary:
	var root := escena.instantiate() as Node3D
	var tools := {}
	_juntar_prop(root, Transform3D.IDENTITY, tools, solo_primera)
	root.free()
	var mesh := ArrayMesh.new()
	for material: Material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_sucio(material))
	var aabb := mesh.get_aabb()
	var centrado := ArrayMesh.new()
	var mover := Transform3D(Basis.IDENTITY, -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
	for surface in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(mesh, surface, mover)
		st.commit(centrado)
		centrado.surface_set_material(surface, mesh.surface_get_material(surface))
	return {"mesh": centrado, "aabb": centrado.get_aabb()}


func _juntar_prop(node: Node, xform: Transform3D, tools: Dictionary, solo_primera: bool) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := (node as MeshInstance3D).get_active_material(surface)
			if not tools.has(material):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = st
			(tools[material] as SurfaceTool).append_from(mesh, surface, xform)
		if solo_primera:
			return true
	for child in node.get_children():
		var child_xform := xform * (child as Node3D).transform if child is Node3D else xform
		if _juntar_prop(child, child_xform, tools, solo_primera):
			return true
	return false


func _material_sucio(source: Material) -> Material:
	if source is ShaderMaterial and (source as ShaderMaterial).shader == PS1_SHADER:
		var sucio := (source as ShaderMaterial).duplicate() as ShaderMaterial
		sucio.set_shader_parameter("deterioro_modo", 1)
		return sucio
	return source
