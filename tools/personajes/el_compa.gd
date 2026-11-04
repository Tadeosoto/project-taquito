extends SceneTree
# Repinta la textura de hombre_04 (pack PSX) para el primer protagonista:
# camisa mostaza con hojas abierta al pecho, cadena con cruz, pantalón negro,
# cinturón con hebilla dorada, botas beige, piel morena, pelo negro con canas
# y bigote. Lee Character_04_original.png y escribe Character_04.png (el
# nombre que busca el FBX). Las islas son las de tools/personajes/islas.gd
# (islas.png en la carpeta para verlas con su número).
#   godot --path . --headless -s tools/personajes/el_compa.gd
#   godot --path . --headless --import

const CARPETA := "res://models/personajes/protagonistas/el_compa/"
const SEMILLA := 7

# --- Colores ---
const MOSTAZA := Color(0.74, 0.52, 0.17)
const HOJA := Color(0.30, 0.17, 0.06)
const HOJA_VENA := Color(0.55, 0.36, 0.12)
const PIEL := Color(0.50, 0.33, 0.24)
const PELO := Color(0.07, 0.06, 0.06)
const CANA := Color(0.42, 0.41, 0.40)
const NEGRO := Color(0.075, 0.075, 0.085)
const CINTO := Color(0.06, 0.045, 0.035)
const ORO := Color(0.86, 0.68, 0.26)
const ORO_OSCURO := Color(0.50, 0.36, 0.10)
const BOTA := Color(0.80, 0.67, 0.46)
const SUELA := Color(0.30, 0.21, 0.13)

# --- Islas (números de islas.png) ---
const CHAMARRA := [3, 8, 14, 15]
const ANTEBRAZOS := [5, 30]                  # manga corta: los antebrazos son piel
const PECHO_ISLA := 15
const CABEZA := [1, 9, 10, 27, 28, 29, 31]   # piel y pelo se separan por color
const SOLO_PELO := [27, 31]                   # canas solo aquí: en 10/28 lo oscuro también son ojos y cejas
const MANOS := [4, 13, 17, 20]
const PANTALON := [11, 16, 18, 19, 21, 22]
const HEBILLA_ISLA := 21
const ZAPATOS := [0, 2, 6, 7, 12, 23, 25, 26]
const SUELAS := [24, 32]

# --- Pecho abierto: la playera interior es una franja horizontal en la isla 15
# (x 204-325, centro y 203.5); el cuello está del lado de x grande. Se pinta
# de piel y se abre en V hacia el cuello.
const PECHO_CENTRO_Y := 203.5
const PECHO_X := Vector2(200, 334)      # de la cintura al cuello
const PECHO_ANCHO := Vector2(5.0, 15.0) # medio ancho en la cintura y en el cuello
# Cadena: de los lados del cuello a un punto del pecho, con cruz colgando.
# El cuello de la playera original: un triángulo de piel junto a la franja.
const CUELLO := Rect2(322, 189, 32, 34)
const CADENA_ARRIBA_X := 326.0
const CADENA_ABAJO_X := 270.0
const CRUZ := Rect2(257, 202.5, 12, 2.2)       # palo largo (hacia la cintura = -x)
const CRUZ_BRAZO := Rect2(263.5, 199.5, 2, 8)

# --- Hebilla: frente del pantalón, isla 21, alrededor del botón original.
const HEBILLA := Rect2i(4, 389, 22, 22)

# --- Bigote: caja en el espacio del modelo (X al frente, Y arriba, Z a los
# lados, cara centrada en z = 0). Cada píxel de piel de la cabeza se ubica en
# 3D con las UV de la malla, así sale recto y parejo aunque las dos mitades de
# la cara estén giradas distinto en la textura. Nariz ~4.23, boca ~4.12.
const BIGOTE_Y := Vector2(4.152, 4.188)   # de abajo a arriba
const BIGOTE_MEDIO := 0.08                # medio ancho (z)
const BIGOTE_FRENTE := 0.03               # x mínima: solo la cara de enfrente

const CANAS_PELO := 0.06
const CANAS_BIGOTE := 0.025
const VETA := 0.55        # cuánto de la sombra original queda en la camisa (la veta de la chamarra se notaba)

var img: Image
var etiqueta: PackedInt32Array
var w: int
var h: int
var rng := RandomNumberGenerator.new()
var posiciones := {}   # Vector2i (píxel) -> Vector3 (punto de la malla en reposo)


func _init() -> void:
	rng.seed = SEMILLA
	img = Image.load_from_file(ProjectSettings.globalize_path(CARPETA + "Character_04_original.png"))
	img.convert(Image.FORMAT_RGBA8)
	w = img.get_width()
	h = img.get_height()
	etiqueta = load("res://tools/personajes/islas.gd").etiquetar(img).etiqueta
	var orig := img.duplicate() as Image
	posiciones = _posiciones()
	var hojas := _hojas()

	# Promedio de luz por isla (y por piel/pelo en la cabeza) para conservar
	# la sombra original sin importar qué tan claro era el color de antes.
	var prom := {}
	for y in h:
		for x in w:
			var e := etiqueta[y * w + x]
			if e < 0: continue
			var k := _clave(e, orig.get_pixel(x, y))
			if not prom.has(k): prom[k] = Vector2.ZERO
			prom[k] += Vector2(_luz(orig.get_pixel(x, y)), 1)

	for y in h:
		for x in w:
			var e := etiqueta[y * w + x]
			if e < 0: continue
			var c := orig.get_pixel(x, y)
			var k := _clave(e, c)
			var f := clampf(_luz(c) / (prom[k].x / prom[k].y), 0.45, 1.6)
			var p := Vector2(x + 0.5, y + 0.5)
			var nuevo := c
			if e in CHAMARRA:
				var fc := clampf(lerpf(1.0, f, VETA), 0.6, 1.2)
				nuevo = MOSTAZA * fc
				var hv: float = hojas[y * w + x]
				if hv > 1.5: nuevo = HOJA_VENA * fc
				elif hv > 0.5: nuevo = HOJA * fc
				if e == PECHO_ISLA:
					var pecho := _pecho(p)
					# el cuello de la playera original (clarito y rojizo) también es piel
					if pecho < 0.0 and CUELLO.has_point(p) and c.r - c.b > 0.12 and c.s > 0.3 and c.v > 0.45:
						pecho = 0.9
					if pecho >= 0.0: nuevo = PIEL * pecho
					var joya := _joya(p)
					if joya > 0.0: nuevo = ORO if joya > 1.5 else ORO_OSCURO
			elif e in ANTEBRAZOS:
				nuevo = PIEL * clampf(lerpf(1.0, f, 0.5), 0.7, 1.2)
			elif k.ends_with("piel") or e in MANOS:
				nuevo = PIEL * f
				if e in CABEZA and _bigote(Vector2i(x, y)):
					nuevo = (CANA if rng.randf() < CANAS_BIGOTE else PELO) * clampf(f, 0.7, 1.3)
			elif k.ends_with("pelo"):
				var cana := e in SOLO_PELO and rng.randf() < CANAS_PELO
				nuevo = (CANA if cana else PELO) * clampf(f, 0.6, 1.5)
			elif e in PANTALON:
				var cinto := c.s > 0.15 and c.r - c.b > 0.05
				nuevo = (CINTO if cinto else NEGRO) * clampf(f, 0.6, 1.9)
				if e == HEBILLA_ISLA and HEBILLA.has_point(Vector2i(x, y)):
					nuevo = _hebilla(x - HEBILLA.position.x, y - HEBILLA.position.y)
			elif e in ZAPATOS:
				nuevo = BOTA * lerpf(1.0, f, 0.45)   # aplana las agujetas
			elif e in SUELAS:
				nuevo = SUELA * f
			nuevo.a = c.a
			img.set_pixel(x, y, nuevo)
	img.save_png(ProjectSettings.globalize_path(CARPETA + "Character_04.png"))
	print("listo: ", CARPETA + "Character_04.png")
	quit()


func _luz(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


# En la cabeza separa piel de pelo por color: la piel es clara y rojiza.
func _clave(e: int, c: Color) -> String:
	if e in CABEZA:
		return "%d_%s" % [e, "piel" if _luz(c) > 0.30 and c.r - c.b > 0.10 else "pelo"]
	return str(e)


# Hojas alargadas repartidas en rejilla con desorden. 0 fuera, 1 hoja, 2 vena.
func _hojas() -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(w * h)
	const PASO := 17
	for gy in range(-PASO, h + PASO, PASO):
		for gx in range(-PASO, w + PASO, PASO):
			var c := Vector2(gx + rng.randf_range(-5, 5), gy + rng.randf_range(-5, 5))
			var ang := rng.randf_range(0, TAU)
			var largo := rng.randf_range(6.0, 9.0)     # medio largo
			var ancho := rng.randf_range(2.2, 3.2)     # medio ancho
			var eje := Vector2.from_angle(ang)
			var r := int(largo) + 1
			for y in range(int(c.y) - r, int(c.y) + r + 1):
				for x in range(int(c.x) - r, int(c.x) + r + 1):
					if x < 0 or y < 0 or x >= w or y >= h: continue
					var d := Vector2(x + 0.5, y + 0.5) - c
					var u := d.dot(eje) / largo
					var v := d.dot(eje.orthogonal())
					if absf(u) >= 1.0: continue
					var borde := ancho * (1.0 - u * u)
					if absf(v) <= borde:
						m[y * w + x] = 2.0 if absf(v) < 0.5 and absf(u) < 0.8 else 1.0
	return m


# Factor de luz de la piel del pecho, o -1 si p queda fuera de la V.
func _pecho(p: Vector2) -> float:
	if p.x < PECHO_X.x or p.x > PECHO_X.y: return -1.0
	var t := (p.x - PECHO_X.x) / (PECHO_X.y - PECHO_X.x)
	var medio := lerpf(PECHO_ANCHO.x, PECHO_ANCHO.y, t)
	var dy := absf(p.y - PECHO_CENTRO_Y)
	if dy > medio: return -1.0
	var luz := 1.0
	if dy < 0.8: luz = 0.85                  # esternón
	if medio - dy < 1.5: luz = 0.65          # sombra de la camisa
	return luz


# 2 = oro claro, 1 = oro oscuro, 0 = nada.
func _joya(p: Vector2) -> float:
	if CRUZ.has_point(p) or CRUZ_BRAZO.has_point(p):
		return 2.0 if int(p.x + p.y) % 3 != 0 else 1.0
	for lado in [-1.0, 1.0]:
		var a := Vector2(CADENA_ARRIBA_X, PECHO_CENTRO_Y + lado * (PECHO_ANCHO.y - 3.0))
		var b := Vector2(CADENA_ABAJO_X, PECHO_CENTRO_Y)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(q) < 0.75:
			return 2.0 if int(p.x) % 2 == 0 else 1.0
	return 0.0


# Hebilla grande: marco oscuro, oro con un rombo grabado.
func _hebilla(x: int, y: int) -> Color:
	var s := HEBILLA.size
	if x == 0 or y == 0 or x == s.x - 1 or y == s.y - 1: return ORO_OSCURO
	var d := absf(x - s.x * 0.5 + 0.5) + absf(y - s.y * 0.5 + 0.5)
	if absi(int(d) - 6) == 0: return ORO_OSCURO
	return ORO * (1.1 if (x + y) % 5 == 0 else 1.0)


func _bigote(px: Vector2i) -> bool:
	if not posiciones.has(px): return false
	var q: Vector3 = posiciones[px]
	return q.x > BIGOTE_FRENTE and absf(q.z) < BIGOTE_MEDIO and q.y > BIGOTE_Y.x and q.y < BIGOTE_Y.y


# Rasteriza los triángulos de la malla en el espacio UV: para cada píxel, el
# punto 3D que le corresponde (interpolado con baricéntricas).
func _posiciones() -> Dictionary:
	var modelo: Node3D = load(CARPETA + "el_compa.fbx").instantiate()
	var mi := modelo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tam := Vector2(w, h)
	var res := {}
	for t in range(0, idx.size(), 3):
		var a := uv[idx[t]] * tam
		var b := uv[idx[t + 1]] * tam
		var c := uv[idx[t + 2]] * tam
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-6: continue
		var lo := a.min(b).min(c).floor()
		var hi := a.max(b).max(c).ceil()
		for y in range(maxi(int(lo.y), 0), mini(int(hi.y), h - 1) + 1):
			for x in range(maxi(int(lo.x), 0), mini(int(hi.x), w - 1) + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				var l1 := (p - a).cross(c - a) / area
				var l2 := (b - a).cross(p - a) / area
				var l0 := 1.0 - l1 - l2
				if l0 < -0.01 or l1 < -0.01 or l2 < -0.01: continue
				res[Vector2i(x, y)] = pos[idx[t]] * l0 + pos[idx[t + 1]] * l1 + pos[idx[t + 2]] * l2
	modelo.free()
	return res
