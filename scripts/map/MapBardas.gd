extends Node3D

# Bardas de block y mallas ciclonicas del mapa, con colision. Las lineas vienen de
# resources/map/bardas_mapa.json (tools/map_import/prepare_osm.py place_bardas):
# contorno de los cotos que da a la calle (coto_calle), frente de los baldios,
# alrededor de las bodegas y las barrier=wall de OSM. Cada linea se parte en
# paneles de PANEL m:
# - coto_calle es malla con probabilidad Deterioro.zona y si no barda; osm es
#   barda; baldio y bodega son malla.
# - Las bardas llevan grafiti (mas entre mas deterioro) y boquetes; las mallas,
#   agujeros y un porton abierto. Cada linea tiene al menos un paso.
# - Grafitis y propaganda pintada salen de dos catalogos, `grafitis_dir` y
#   `propaganda_dir`: cualquier imagen que se ponga en esas carpetas entra sola
#   (los grafitis con transparencia). Se juntan en un atlas al iniciar y se pegan
#   como calcomanias encima del aplanado, de un lado o de los dos: la propaganda
#   grande y a media barda, y los grafitis encima de ella.
# Tambien las plumas de los cotos: poste, brazo caido o roto y caseta.
# Como MapBodegas, se arman por celdas en un hilo segun la distancia a target_path.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const CASA_SHADER := preload("res://shaders/ps1_casa.gdshader")

const CELDA := 64.0
const PANEL := 2.5
const BARDA_ALTO := 2.5
const BARDA_GRUESO := 0.2
const CASTILLO := 0.28
const MALLA_ALTO := 2.0
const POSTE := 0.06
# Lineas mas largas que esto (m) siempre tienen un paso
const PASO_MIN := 8.0
# Atlas de barda.png: 3 mosaicos (liso, aplanado caido, block aparente)
const ATLAS := Vector2(3, 1)
# Lado maximo (px) de un diseño en el atlas de calcomanias: los mas grandes se reducen
const DISENO_PX := 128
const EXTENSIONES := ["png", "webp", "jpg", "jpeg"]
# Probabilidad de propaganda en cada lado de un panel
const PROPAGANDA_PROB := 0.18
const COLORES := [Color("#e8e2d0"), Color("#d9cdb0"), Color("#e6d3c3"), Color("#cfd6d0"),
	Color("#e9dfb8"), Color("#d7d2cc"), Color("#c9b9a6")]

@export_file("*.json") var bardas_path := "res://resources/map/bardas_mapa.json"
@export var barda_textura: Texture2D
@export var malla_textura: Texture2D
@export_dir var grafitis_dir := "res://textures/map/grafitis"
@export_dir var propaganda_dir := "res://textures/map/propaganda"
@export var target_path: NodePath
@export var load_radius := 260.0
@export var unload_radius := 330.0
@export var barda_end := 250.0
@export var malla_end := 160.0

var _celdas := {}          # Vector2i -> {"paneles": [...], "plumas": [...]}
var _nodos := {}           # Vector2i -> Node3D
var _materiales := {}
var _disenos := []         # [Rect2 en el atlas, alto / ancho] de cada diseño
var _grafitis := []        # indices en _disenos de cada catalogo
var _propagandas := []
var _calcomanias_atlas: ImageTexture
var _target: Node3D
var _timer := 0.0
# Celdas por armar (la mas cercana primero) y la que se esta armando en un hilo
var _pendientes: Array[Vector2i] = []
var _tarea := -1
var _tarea_key: Vector2i
var _tarea_res := []


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(bardas_path)) \
			if FileAccess.file_exists(bardas_path) else null
	if not data is Dictionary:
		push_warning("MapBardas: no se pudo leer %s" % bardas_path)
		return
	_cargar_calcomanias()
	for barda: Dictionary in data["bardas"]:
		for panel: Dictionary in _paneles(barda):
			_celda((panel["a"] + panel["b"]) / 2.0)["paneles"].append(panel)
	for pluma: Dictionary in data["plumas"]:
		_celda(Vector2(pluma["x"], pluma["z"]))["plumas"].append(pluma)
	# Los materiales se preparan aqui para que el hilo solo los lea
	_material("barda")
	_material("malla")
	_material("fierro")
	if _calcomanias_atlas:
		_material("calcomania")
	_target = get_node_or_null(target_path) as Node3D
	_update_nearby(true)


func _celda(p: Vector2) -> Dictionary:
	var key := Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))
	if not _celdas.has(key):
		_celdas[key] = {"paneles": [], "plumas": []}
	return _celdas[key]


# Parte una linea en paneles y decide de una vez (con su semilla) que es cada uno:
# {a, b, malla, estado (0 entero, 1 boquete o agujero, 2 porton), mosaico, alto, color,
# calcomanias: [[diseño, lado (+-1), ancho, x, y (fracciones), es_grafiti], ...]}
func _paneles(barda: Dictionary) -> Array:
	var puntos: Array = barda["puntos"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(barda["semilla"])
	var mitad: Array = puntos[puntos.size() / 2]
	var zona := Deterioro.zona(mitad[0], mitad[1])
	var tipo: String = barda["tipo"]
	var malla := tipo in ["baldio", "bodega"] or (tipo == "coto_calle" and rng.randf() < zona)
	var alto := MALLA_ALTO if malla else BARDA_ALTO + rng.randf_range(-0.3, 0.3)
	var color: Color = Color(0.85, 0.86, 0.86) if malla else COLORES[rng.randi() % COLORES.size()]
	var paneles := []
	var largo := 0.0
	for i in puntos.size() - 1:
		var a := Vector2(puntos[i][0], puntos[i][1])
		var b := Vector2(puntos[i + 1][0], puntos[i + 1][1])
		var n := maxi(1, roundi(a.distance_to(b) / PANEL))
		largo += a.distance_to(b)
		for j in n:
			var panel := {"a": a.lerp(b, float(j) / n), "b": a.lerp(b, float(j + 1) / n),
				"malla": malla, "estado": 0, "alto": alto, "color": color, "primero": j == 0}
			if malla:
				panel["estado"] = 1 if rng.randf() < 0.05 + zona * 0.3 else 0
			else:
				panel["estado"] = 1 if rng.randf() < zona * 0.12 else 0
				# Casi siempre liso
				panel["mosaico"] = Vector2([0, 0, 0, 1, 2][rng.randi() % 5], 0)
				# Propaganda y grafiti (segun el deterioro) de cada lado. Con su propia
				# semilla: agregar diseños a los catalogos no cambia lo demas de la barda.
				var rng_p := RandomNumberGenerator.new()
				rng_p.seed = int(barda["semilla"]) * 2003 + paneles.size()
				var rng_g := RandomNumberGenerator.new()
				rng_g.seed = int(barda["semilla"]) * 1009 + paneles.size()
				panel["calcomanias"] = []
				for lado in [1.0, -1.0]:
					if not _propagandas.is_empty() and rng_p.randf() < PROPAGANDA_PROB:
						panel["calcomanias"].append([_propagandas[rng_p.randi() % _propagandas.size()], lado,
							rng_p.randf_range(0.8, 0.95), rng_p.randf(), rng_p.randf(), false])
				for lado in [1.0, -1.0]:
					if not _grafitis.is_empty() and rng_g.randf() < 0.35 + zona * 0.6:
						panel["calcomanias"].append([_grafitis[rng_g.randi() % _grafitis.size()], lado,
							rng_g.randf_range(0.55, 0.95), rng_g.randf(), rng_g.randf(), true])
			paneles.append(panel)
	if largo >= PASO_MIN and not paneles.is_empty():
		# Las mallas tienen un porton abierto; las bardas, al menos un boquete
		var k := rng.randi() % paneles.size()
		if malla:
			paneles[k]["estado"] = 2
		elif not paneles.any(func(p): return p["estado"] == 1):
			paneles[k]["estado"] = 1
	if not paneles.is_empty():
		paneles[-1]["ultimo"] = true
	return paneles


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
func _crear_celda(celda_data: Dictionary) -> Array:
	var celda := Node3D.new()
	var cajas := []            # [Transform3D del centro, tamano]
	var tools := {}            # nombre del material -> SurfaceTool
	for panel: Dictionary in celda_data["paneles"]:
		if panel["malla"]:
			_malla(panel, tools, cajas)
		else:
			_barda(panel, tools, cajas)
	for pluma: Dictionary in celda_data["plumas"]:
		_pluma(pluma, tools, cajas)
	for nombre: String in tools:
		var mesh := ArrayMesh.new()
		(tools[nombre] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(0, _materiales[nombre])
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = malla_end if nombre == "malla" else barda_end
		celda.add_child(instance)
	return [celda, cajas]


# Ejes de un panel: X a lo largo (de a a b), Y arriba, Z de un lado; origen en a
func _ejes(panel: Dictionary) -> Transform3D:
	var a: Vector2 = panel["a"]
	var b: Vector2 = panel["b"]
	var x := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	return Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(a.x, 0.0, a.y))


func _barda(panel: Dictionary, tools: Dictionary, cajas: Array) -> void:
	var ejes := _ejes(panel)
	var largo: float = (panel["a"] as Vector2).distance_to(panel["b"])
	var alto: float = panel["alto"]
	var color: Color = panel["color"]
	var st := _st(tools, "barda")
	var mosaico: Vector2 = panel["mosaico"]
	var uv := Rect2(mosaico / ATLAS, Vector2.ONE / ATLAS)
	var castillo := color.darkened(0.12)
	if panel["primero"]:
		_castillo(st, cajas, ejes, 0.0, alto, castillo)
	_castillo(st, cajas, ejes, largo, alto, castillo)
	var x0 := CASTILLO / 2.0
	var x1 := largo - CASTILLO / 2.0
	if panel["estado"] == 1:
		# Boquete: queda un pedazo de un lado y el escombro en el piso
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(panel["a"])
		var queda := rng.randf_range(0.1, 0.35) * largo
		# Lo de abajo queda a ras (sin colision: por ahi se pasa)
		var resto := alto * rng.randf_range(0.04, 0.12)
		uv.size.x *= queda / largo
		_bloque(st, cajas, ejes, x0, x0 + queda, alto, color, uv)
		_bloque(st, cajas, ejes, x0 + queda, x1, resto, color, Rect2(uv.position, Vector2(uv.size.x, uv.size.y * resto / alto)), false)
		for k in 4:
			var p := Vector3(rng.randf_range(x0 + queda, x1), 0.1, rng.randf_range(-0.8, 0.8))
			_caja(st, ejes * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(0.4, 0.2, 0.2), castillo)
		return
	_bloque(st, cajas, ejes, x0, x1, alto, color, uv)
	if not panel["calcomanias"].is_empty():
		var st_c := _st(tools, "calcomania")
		for g: Array in panel["calcomanias"]:
			_calcomania(st_c, ejes, x0, x1, alto, g)


# Un diseño de un catalogo pegado a un lado del muro (entre x0 y x1), sin estirarlo.
# La propaganda va a media barda; los grafitis en cualquier altura y mas afuera,
# para quedar encima.
func _calcomania(st: SurfaceTool, ejes: Transform3D, x0: float, x1: float, alto: float, g: Array) -> void:
	var diseno: Array = _disenos[g[0]]
	var uv: Rect2 = diseno[0]
	var proporcion: float = diseno[1]
	var lado: float = g[1]
	var w: float = (x1 - x0) * g[2]
	var h := w * proporcion
	if h > alto * 0.85:
		h = alto * 0.85
		w = h / proporcion
	var cx: float = x0 + w / 2.0 + (x1 - x0 - w) * g[3]
	var es_grafiti: bool = g[5]
	var y0: float = 0.15 + maxf(alto - 0.25 - h, 0.0) * g[4] if es_grafiti \
		else 0.5 + maxf(alto - 0.9 - h, 0.0) * g[4]
	var z := lado * (BARDA_GRUESO / 2.0 + (0.014 if es_grafiti else 0.008))
	# Visto desde su lado, u crece hacia la derecha y v hacia abajo
	var izq := cx - lado * w / 2.0
	var der := cx + lado * w / 2.0
	var p := [Vector3(izq, y0 + h, z), Vector3(der, y0 + h, z), Vector3(der, y0, z), Vector3(izq, y0, z)]
	var uvs := [uv.position, uv.position + Vector2(uv.size.x, 0.0), uv.end, uv.position + Vector2(0.0, uv.size.y)]
	var n := (ejes.basis * Vector3(0.0, 0.0, lado)).normalized()
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_color(Color.WHITE)
		st.set_uv(uvs[i])
		st.add_vertex(ejes * (p[i] as Vector3))


# Junta los diseños de los dos catalogos en un atlas (rejilla de DISENO_PX), sin
# filtrar para que sigan pixeleados. Ordenados por nombre: siempre salen igual.
func _cargar_calcomanias() -> void:
	var imagenes: Array[Image] = []
	for catalogo in [[grafitis_dir, _grafitis], [propaganda_dir, _propagandas]]:
		var carpeta: String = catalogo[0]
		if not DirAccess.dir_exists_absolute(carpeta):
			continue
		var archivos := Array(ResourceLoader.list_directory(carpeta))
		archivos.sort()
		for archivo: String in archivos:
			if archivo.get_extension().to_lower() not in EXTENSIONES:
				continue
			var textura := load(carpeta.path_join(archivo)) as Texture2D
			if textura == null:
				continue
			var image := textura.get_image()
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			var lado_max := maxi(image.get_width(), image.get_height())
			if lado_max > DISENO_PX:
				var f := float(DISENO_PX) / lado_max
				image.resize(maxi(1, roundi(image.get_width() * f)), maxi(1, roundi(image.get_height() * f)), Image.INTERPOLATE_NEAREST)
			(catalogo[1] as Array).append(imagenes.size())
			imagenes.append(image)
	if imagenes.is_empty():
		return
	var columnas := ceili(sqrt(imagenes.size()))
	var filas := ceili(float(imagenes.size()) / columnas)
	var atlas := Image.create(columnas * DISENO_PX, filas * DISENO_PX, false, Image.FORMAT_RGBA8)
	var tamano := Vector2(atlas.get_size())
	for i in imagenes.size():
		var image := imagenes[i]
		var pos := Vector2i(i % columnas, i / columnas) * DISENO_PX
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), pos)
		_disenos.append([Rect2(Vector2(pos) / tamano, Vector2(image.get_size()) / tamano),
			float(image.get_height()) / image.get_width()])
	_calcomanias_atlas = ImageTexture.create_from_image(atlas)


# Un muro de x0 a x1 en los ejes del panel; sus dos caras con `uv` del atlas
func _bloque(st: SurfaceTool, cajas: Array, ejes: Transform3D, x0: float, x1: float, alto: float,
		color: Color, uv: Rect2, colision := true) -> void:
	if x1 - x0 < 0.05:
		return
	var centro := ejes * Transform3D(Basis.IDENTITY, Vector3((x0 + x1) / 2.0, alto / 2.0, 0.0))
	var size := Vector3(x1 - x0, alto, BARDA_GRUESO)
	_caja(st, centro, size, color, uv)
	if colision:
		cajas.append([centro, size])


func _castillo(st: SurfaceTool, cajas: Array, ejes: Transform3D, x: float, alto: float, color: Color) -> void:
	var centro := ejes * Transform3D(Basis.IDENTITY, Vector3(x, (alto + 0.08) / 2.0, 0.0))
	var size := Vector3(CASTILLO, alto + 0.08, CASTILLO)
	_caja(st, centro, size, color)
	cajas.append([centro, size])


func _malla(panel: Dictionary, tools: Dictionary, cajas: Array) -> void:
	var ejes := _ejes(panel)
	var largo: float = (panel["a"] as Vector2).distance_to(panel["b"])
	var alto: float = panel["alto"]
	var fierro := _st(tools, "fierro")
	var gris := Color(0.55, 0.57, 0.58)
	if panel["primero"]:
		_caja(fierro, ejes * Transform3D(Basis.IDENTITY, Vector3(0.0, alto / 2.0, 0.0)), Vector3(POSTE, alto, POSTE), gris)
	_caja(fierro, ejes * Transform3D(Basis.IDENTITY, Vector3(largo, alto / 2.0, 0.0)), Vector3(POSTE, alto, POSTE), gris)
	var st := _st(tools, "malla")
	var estado: int = panel["estado"]
	if estado == 2:
		# Porton abierto: la hoja girada en el poste de un lado
		var giro := Transform3D(Basis(Vector3.UP, deg_to_rad(70.0)), Vector3.ZERO)
		_lienzo(st, ejes * giro, largo * 0.95, alto * 0.95, Rect2(0.0, 0.0, 0.5, 1.0), 0.05)
		_caja(fierro, ejes * giro * Transform3D(Basis.IDENTITY, Vector3(largo * 0.475, alto * 0.95, 0.0)), Vector3(largo * 0.95, POSTE, POSTE), gris)
		return
	# Tubo de arriba
	_caja(fierro, ejes * Transform3D(Basis.IDENTITY, Vector3(largo / 2.0, alto, 0.0)), Vector3(largo, POSTE * 0.8, POSTE * 0.8), gris)
	# La rota (mosaico 1) tiene un agujero abajo por donde se pasa: sin colision
	_lienzo(st, ejes, largo, alto, Rect2(0.5 if estado == 1 else 0.0, 0.0, 0.5, 1.0), 0.0)
	if estado == 0:
		cajas.append([ejes * Transform3D(Basis.IDENTITY, Vector3(largo / 2.0, alto / 2.0, 0.0)), Vector3(largo, alto, 0.1)])


# La malla: un rectangulo de las dos caras, de x 0 a `largo` en `ejes`
func _lienzo(st: SurfaceTool, ejes: Transform3D, largo: float, alto: float, uv: Rect2, y0: float) -> void:
	var p := [Vector3(0.0, y0 + alto, 0.0), Vector3(largo, y0 + alto, 0.0), Vector3(largo, y0, 0.0), Vector3(0.0, y0, 0.0)]
	# El mosaico se repite cada PANEL m a lo largo
	var u := largo / PANEL * uv.size.x
	var uvs := [uv.position, uv.position + Vector2(u, 0.0), uv.position + Vector2(u, uv.size.y), uv.position + Vector2(0.0, uv.size.y)]
	for lado in [1.0, -1.0]:
		var n := (ejes.basis * Vector3(0.0, 0.0, lado)).normalized()
		var orden := [0, 1, 2, 0, 2, 3] if lado > 0.0 else [0, 2, 1, 0, 3, 2]
		for i in orden:
			st.set_normal(n)
			st.set_color(Color.WHITE)
			st.set_uv(uvs[i])
			st.add_vertex(ejes * (p[i] as Vector3))


# Pluma de un coto en (x, z), a lo largo de la calle: poste a un lado, el brazo
# caido o roto, y la caseta de vigilancia
func _pluma(pluma: Dictionary, tools: Dictionary, cajas: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pluma["semilla"])
	var medio := maxf(float(pluma["ancho"]) / 2.0, 2.0)
	# Ejes: Z a lo largo de la calle, X a traves
	var ejes := Transform3D(Basis(Vector3.UP, float(pluma["rotacion_y"])), Vector3(pluma["x"], 0.0, pluma["z"]))
	var lado := -1.0 if rng.randf() < 0.5 else 1.0
	var st := _st(tools, "fierro")
	var amarillo := Color(0.85, 0.7, 0.2)
	var poste := Vector3(lado * (medio + 0.3), 0.55, 0.0)
	_caja(st, ejes * Transform3D(Basis.IDENTITY, poste), Vector3(0.3, 1.1, 0.3), amarillo)
	cajas.append([ejes * Transform3D(Basis.IDENTITY, poste), Vector3(0.3, 1.1, 0.3)])
	var brazo := 2.0 * medio * 0.9
	if rng.randf() < 0.5:
		# Caido: tirado en el piso, chueco
		var giro := Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
		_brazo(st, ejes * Transform3D(giro, Vector3(lado * (medio - brazo / 2.0), 0.08, rng.randf_range(-0.8, 0.8))), brazo)
	else:
		# Roto: un pedazo sigue arriba y el resto colgando hasta el piso
		var pedazo := rng.randf_range(0.8, 1.6)
		_brazo(st, ejes * Transform3D(Basis.IDENTITY, Vector3(lado * (medio - pedazo / 2.0), 1.05, 0.0)), pedazo)
		var x := lado * (medio - pedazo)
		var resto := minf(brazo - pedazo, 3.0)
		var caida := lado * atan2(1.05, resto)
		_brazo(st, ejes * Transform3D(Basis(Vector3(0, 0, 1), caida), Vector3(x - lado * resto / 2.0, 0.525, 0.0)),
			sqrt(resto * resto + 1.05 * 1.05))
	# Caseta: cuarto de block con ventana corrida y losa
	var blanco := Color(0.82, 0.8, 0.74)
	var centro := Vector3(lado * (medio + 1.9), 0.0, rng.randf_range(-1.5, 1.5))
	var muros := ejes * Transform3D(Basis.IDENTITY, centro + Vector3(0.0, 1.2, 0.0))
	_caja(st, muros, Vector3(2.2, 2.4, 2.2), blanco)
	cajas.append([muros, Vector3(2.2, 2.4, 2.2)])
	_caja(st, ejes * Transform3D(Basis.IDENTITY, centro + Vector3(0.0, 1.5, 0.0)), Vector3(2.24, 0.7, 2.24), Color(0.1, 0.12, 0.14))
	_caja(st, ejes * Transform3D(Basis.IDENTITY, centro + Vector3(0.0, 2.48, 0.0)), Vector3(2.6, 0.16, 2.6), blanco.darkened(0.2))


# Brazo de pluma de `largo` m centrado en `xform` (a lo largo de X), con franjas
# rojas y blancas
func _brazo(st: SurfaceTool, xform: Transform3D, largo: float) -> void:
	var n := maxi(1, roundi(largo / 0.5))
	for i in n:
		var x := -largo / 2.0 + (i + 0.5) * largo / n
		_caja(st, xform * Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)), Vector3(largo / n, 0.14, 0.14),
			Color(0.75, 0.12, 0.1) if i % 2 else Color(0.92, 0.92, 0.9))


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

func _st(tools: Dictionary, nombre: String) -> SurfaceTool:
	if not tools.has(nombre):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[nombre] = st
	return tools[nombre]


# Caja de `size` centrada en `xform`. Las caras de frente y atras (+-Z) llevan `uv`
# (estirado a toda la cara); las demas un pedazo liso del atlas.
func _caja(st: SurfaceTool, xform: Transform3D, size: Vector3, color: Color, uv := Rect2(0.02, 0.05, 0.03, 0.03)) -> void:
	var h := size / 2.0
	var liso := Rect2(0.02, 0.05, 0.03, 0.03)
	for eje in 3:
		for signo in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[eje] = signo
			var u := Vector3.ZERO
			var w := Vector3.ZERO
			u[(eje + 1) % 3] = h[(eje + 1) % 3]
			w[(eje + 2) % 3] = h[(eje + 2) % 3]
			var c := n * h[eje]
			var p := [c - u - w, c + u - w, c + u + w, c - u + w]
			var r := uv if eje == 2 else liso
			var uvs := [r.position, r.position, r.position, r.position]
			if eje == 2:
				# u a lo largo (X), v hacia abajo (Y): p0 = (-x, -y), p1 = (-x, +y) en esta cara
				for i in 4:
					var q: Vector3 = p[i]
					var fx := (q.x / size.x + 0.5) if signo > 0.0 else (0.5 - q.x / size.x)
					uvs[i] = r.position + Vector2(fx * r.size.x, (0.5 - q.y / size.y) * r.size.y)
			var wn := (xform.basis * n).normalized()
			# Godot dibuja de frente los triangulos en sentido horario
			var horario: bool = ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(n) < 0.0
			var orden := [0, 1, 2, 0, 2, 3] if horario else [0, 2, 1, 0, 3, 2]
			for i in orden:
				st.set_normal(wn)
				st.set_color(color)
				st.set_uv(uvs[i])
				st.add_vertex(xform * (p[i] as Vector3))


# --- Materiales ---

func _material(nombre: String) -> Material:
	if not _materiales.has(nombre):
		var material := ShaderMaterial.new()
		if nombre == "malla" or nombre == "calcomania":
			# ps1_casa: descarta lo transparente y no tiene culling
			material.shader = CASA_SHADER
			material.set_shader_parameter("albedo_texture", malla_textura if nombre == "malla" else _calcomanias_atlas)
		else:
			material.shader = PS1_SHADER
			material.set_shader_parameter("albedo_texture", barda_textura if nombre == "barda" else _blanco())
			material.set_shader_parameter("use_vertex_color", true)
			# Barda: pintura caida y escurrimientos; fierros: mugre
			material.set_shader_parameter("deterioro_modo", 2 if nombre == "barda" else 1)
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("wobble_enabled", false)
		_materiales[nombre] = material
	return _materiales[nombre]


var _textura_blanca: ImageTexture

func _blanco() -> ImageTexture:
	if _textura_blanca == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
		image.fill(Color.WHITE)
		_textura_blanca = ImageTexture.create_from_image(image)
	return _textura_blanca
