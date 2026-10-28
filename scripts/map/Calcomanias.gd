class_name Calcomanias
extends RefCounted

# Catalogos de grafitis y propaganda pintada (textures/map/grafitis/ y
# textures/map/propaganda/, ver sus LEEME.md) juntos en un atlas que comparten
# MapBardas, MapCasas y MapBodegas. cargar() se llama en el hilo principal (en
# _ready); despues los hilos que arman celdas solo leen estos datos.

const CASA_SHADER := preload("res://shaders/ps1_casa.gdshader")
const GRAFITIS_DIR := "res://textures/map/grafitis"
const PROPAGANDA_DIR := "res://textures/map/propaganda"
# Lado maximo (px) de un diseño en el atlas: los mas grandes se reducen
const DISENO_PX := 128
const EXTENSIONES := ["png", "webp", "jpg", "jpeg"]

static var disenos := []         # [Rect2 en el atlas, alto / ancho] de cada diseño
static var grafitis := []        # indices en disenos de cada catalogo
static var propagandas := []
static var atlas: ImageTexture
# ps1_casa: descarta lo transparente y no tiene culling
static var material: ShaderMaterial
static var _cargado := false


# Junta los diseños de los dos catalogos en un atlas (rejilla de DISENO_PX), sin
# filtrar para que sigan pixeleados. Ordenados por nombre: siempre salen igual.
# Solo la primera llamada cuenta.
static func cargar(grafitis_dir := GRAFITIS_DIR, propaganda_dir := PROPAGANDA_DIR) -> void:
	if _cargado:
		return
	_cargado = true
	var imagenes: Array[Image] = []
	for catalogo in [[grafitis_dir, grafitis], [propaganda_dir, propagandas]]:
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
	var imagen := Image.create(columnas * DISENO_PX, filas * DISENO_PX, false, Image.FORMAT_RGBA8)
	var tamano := Vector2(imagen.get_size())
	for i in imagenes.size():
		var image := imagenes[i]
		var pos := Vector2i(i % columnas, i / columnas) * DISENO_PX
		imagen.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), pos)
		disenos.append([Rect2(Vector2(pos) / tamano, Vector2(image.get_size()) / tamano),
			float(image.get_height()) / image.get_width()])
	atlas = ImageTexture.create_from_image(imagen)
	material = ShaderMaterial.new()
	material.shader = CASA_SHADER
	material.set_shader_parameter("albedo_texture", atlas)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)


# Ancho y alto (m) de un diseño, sin estirarlo, lo mas ancho posible hasta
# `ancho` sin pasar de `alto`
static func medida(diseno: int, ancho: float, alto: float) -> Vector2:
	var proporcion: float = disenos[diseno][1]
	var w := ancho
	if w * proporcion > alto:
		w = alto / proporcion
	return Vector2(w, w * proporcion)


# Un grafiti al azar pegado en el plano z = 0 de `ejes` (+Z hacia quien lo ve),
# dentro del rectangulo x0..x1, y0..y1. Ancho entre `ancho` (min, max) si cabe.
static func grafiti(st: SurfaceTool, ejes: Transform3D, rng: RandomNumberGenerator,
		x0: float, x1: float, y0: float, y1: float, ancho: Vector2) -> void:
	if grafitis.is_empty() or x1 - x0 < 0.3 or y1 - y0 < 0.3:
		return
	var diseno: int = grafitis[rng.randi() % grafitis.size()]
	var m := medida(diseno, minf(rng.randf_range(ancho.x, ancho.y), x1 - x0), y1 - y0)
	var x := rng.randf_range(x0, x1 - m.x)
	var y := rng.randf_range(y0, y1 - m.y)
	quad(st, ejes, diseno, x, y, m.x, m.y)


# El diseño de (x, y) a (x + w, y + h) en el plano z = 0 de `ejes`, visto desde +Z
static func quad(st: SurfaceTool, ejes: Transform3D, diseno: int, x: float, y: float, w: float, h: float) -> void:
	var uv: Rect2 = disenos[diseno][0]
	var p := [Vector3(x, y + h, 0.0), Vector3(x + w, y + h, 0.0), Vector3(x + w, y, 0.0), Vector3(x, y, 0.0)]
	var uvs := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	var n := (ejes.basis * Vector3.BACK).normalized()
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_color(Color.WHITE)
		st.set_uv(uvs[i])
		st.add_vertex(ejes * (p[i] as Vector3))
