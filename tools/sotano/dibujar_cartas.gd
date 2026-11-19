extends SceneTree

# Los dibujos de las cartas de EL GORDO, en pixel art de caricatura (AG, 2026-11-19: "2D, mas
# cartoon"): cada uno a mano con figuras simples (bolas con su sombra y su brillo, poligonos,
# lineas), ojos grandes y caritas, y al final un contorno oscuro de 1 px alrededor de todo.
#   godot --path . --headless -s tools/sotano/dibujar_cartas.gd   (luego --import)
# Sale textures/sotano/cartas_dibujos.png: 8 x 3 casillas de 80 x 80, fondo transparente, en el
# orden de scripts/sotano/Cartas.gd. El marco de la carta (cartas.png) y el nombre (OlPleyUI) van
# aparte. Coordenadas: dentro de cada casilla, x a la derecha e y hacia abajo, de 0 a 80.

const SALIDA := "res://textures/sotano/cartas_dibujos.png"
const CASILLA := 80
const COLUMNAS := 8
const CONTORNO := Color(0.1, 0.06, 0.08)

const ROJO := Color(0.86, 0.15, 0.12)
const NARANJA := Color(0.98, 0.55, 0.12)
const AMARILLO := Color(1.0, 0.84, 0.18)
const ORO := Color(0.95, 0.72, 0.2)
const VERDE := Color(0.3, 0.72, 0.25)
const VERDE_OSC := Color(0.12, 0.42, 0.16)
const AZUL := Color(0.2, 0.45, 0.9)
const AZUL_CLARO := Color(0.55, 0.8, 0.98)
const MORADO := Color(0.55, 0.28, 0.75)
const CAFE := Color(0.6, 0.38, 0.18)
const CAFE_OSC := Color(0.35, 0.2, 0.08)
const PIEL := Color(0.96, 0.72, 0.52)
const HUESO := Color(0.97, 0.94, 0.84)
const BLANCO := Color(1, 1, 1)
const NEGRO := Color(0.12, 0.1, 0.12)
const GRIS := Color(0.62, 0.64, 0.68)
const ROSA := Color(1.0, 0.55, 0.7)
const TURQUESA := Color(0.15, 0.72, 0.68)
const ZOMBI := Color(0.55, 0.7, 0.45)

var img: Image
var ox := 0
var oy := 0


func _initialize() -> void:
	img = Image.create(CASILLA * COLUMNAS, CASILLA * 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cartas := [_gallo, _diablito, _sirena, _paraguas, _calavera, _nopal, _luna, _sol, _corazon, _campana,
		_estrella, _venado, _rana, _pescado, _arana, _rosa, _cotorro, _corona, _apagado, _pipa, _machete,
		_garrafa, _camion, _tinaco]
	for k in cartas.size():
		ox = (k % COLUMNAS) * CASILLA
		oy = (k / COLUMNAS) * CASILLA
		(cartas[k] as Callable).call()
		_contorno()
	img.save_png(ProjectSettings.globalize_path(SALIDA))
	print("dibujar_cartas: ", SALIDA)
	quit()


# --- Pinceles (en coordenadas de la casilla) ---

func px(x: int, y: int, c: Color) -> void:
	if x < 1 or y < 1 or x >= CASILLA - 1 or y >= CASILLA - 1:
		return
	if c.a <= 0.0:
		img.set_pixel(ox + x, oy + y, Color(0, 0, 0, 0))
	else:
		img.set_pixel(ox + x, oy + y, c)


func disco(cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				px(x, y, c)


func elipse(cx: float, cy: float, rx: float, ry: float, c: Color, giro := 0.0) -> void:
	var g := deg_to_rad(giro)
	var m := maxf(rx, ry) + 1.0
	for y in range(int(cy - m), int(cy + m + 1)):
		for x in range(int(cx - m), int(cx + m + 1)):
			var dx := x - cx
			var dy := y - cy
			var u := dx * cos(g) + dy * sin(g)
			var v := -dx * sin(g) + dy * cos(g)
			if (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1.0:
				px(x, y, c)


func caja(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	for y in range(int(y0), int(y1) + 1):
		for x in range(int(x0), int(x1) + 1):
			px(x, y, c)


func poli(puntos: Array, c: Color) -> void:
	var p := PackedVector2Array(puntos)
	var r := Rect2(p[0], Vector2.ZERO)
	for q in p:
		r = r.expand(q)
	for y in range(int(r.position.y), int(r.end.y) + 1):
		for x in range(int(r.position.x), int(r.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), p):
				px(x, y, c)


func linea(a: Vector2, b: Vector2, grueso: float, c: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		disco(q.x, q.y, grueso / 2.0, c)


func arco(cx: float, cy: float, r: float, a0: float, a1: float, grueso: float, c: Color) -> void:
	var pasos := int(absf(a1 - a0) / 6.0) + 2
	var antes := Vector2(cx + cos(deg_to_rad(a0)) * r, cy + sin(deg_to_rad(a0)) * r)
	for i in range(1, pasos + 1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / pasos))
		var q := Vector2(cx + cos(a) * r, cy + sin(a) * r)
		linea(antes, q, grueso, c)
		antes = q


# Una bola de caricatura: sombra abajo a la derecha, el color, y un brillo arriba a la izquierda
func bola(cx: float, cy: float, r: float, c: Color, brillo := true) -> void:
	disco(cx, cy, r, c.darkened(0.35))
	disco(cx - r * 0.12, cy - r * 0.12, r * 0.86, c)
	if brillo and r >= 5:
		disco(cx - r * 0.42, cy - r * 0.42, maxf(r * 0.16, 1.2), c.lightened(0.6))


func bola_elipse(cx: float, cy: float, rx: float, ry: float, c: Color, giro := 0.0) -> void:
	elipse(cx, cy, rx, ry, c.darkened(0.35), giro)
	elipse(cx - rx * 0.1, cy - ry * 0.12, rx * 0.86, ry * 0.84, c, giro)
	elipse(cx - rx * 0.4, cy - ry * 0.4, maxf(rx * 0.16, 1.2), maxf(ry * 0.14, 1.2), c.lightened(0.55), giro)


# Un poligono con su sombra (el mismo, corrido) y el color encima
func figura(puntos: Array, c: Color, corre := 2.0) -> void:
	poli(puntos, c.darkened(0.35))
	poli(puntos.map(func(q: Vector2) -> Vector2: return q - Vector2(corre, corre) * 0.6), c)


# Ojo grande de caricatura: blanco, pupila mirando un poco a `ve`, y su brillito
func ojo(cx: float, cy: float, r: float, ve := Vector2(0.25, 0.1)) -> void:
	disco(cx, cy, r, BLANCO)
	disco(cx + ve.x * r, cy + ve.y * r, r * 0.58, NEGRO)
	px(int(cx + ve.x * r - r * 0.2), int(cy + ve.y * r - r * 0.25), BLANCO)


func sonrisa(cx: float, cy: float, r: float, grueso := 1.4) -> void:
	arco(cx, cy, r, 20, 160, grueso, NEGRO)


func cachetes(x0: float, x1: float, y: float, r := 2.5) -> void:
	disco(x0, y, r, ROSA)
	disco(x1, y, r, ROSA)


# 1 px oscuro alrededor de todo lo dibujado en la casilla
func _contorno() -> void:
	var orilla: Array[Vector2i] = []
	for y in range(CASILLA):
		for x in range(CASILLA):
			if img.get_pixel(ox + x, oy + y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < CASILLA and q.y < CASILLA and img.get_pixel(ox + q.x, oy + q.y).a > 0.0:
					orilla.append(Vector2i(x, y))
					break
	for q in orilla:
		img.set_pixel(ox + q.x, oy + q.y, CONTORNO)


# --- Las 24 (mismo orden que Cartas.gd) ---

func _gallo() -> void:
	for k in 3:
		bola_elipse(18 + k * 2, 30 + k * 6, 12, 5, [VERDE_OSC, NEGRO, VERDE][k], -50 + k * 18)
	bola(38, 48, 18, ROJO)
	bola_elipse(34, 50, 10, 7, ROJO.darkened(0.2), -15)
	for k in 3:
		bola(48 + k * 4, 14 - (1 - absi(k - 1)) * 2, 3.5, ROJO)
	bola(52, 26, 10, NARANJA)
	poli([Vector2(60, 24), Vector2(71, 27), Vector2(60, 30)], AMARILLO)
	bola_elipse(59, 34, 2.5, 4, ROJO)
	ojo(54, 24, 3.2)
	for x in [33, 43]:
		linea(Vector2(x, 64), Vector2(x, 73), 2.5, ORO)
		linea(Vector2(x, 73), Vector2(x + 5, 74), 2, ORO)


func _diablito() -> void:
	figura([Vector2(18, 26), Vector2(14, 6), Vector2(28, 20)], HUESO)
	figura([Vector2(62, 26), Vector2(66, 6), Vector2(52, 20)], HUESO)
	bola(40, 42, 24, ROJO)
	linea(Vector2(24, 30), Vector2(36, 34), 2.5, NEGRO)
	linea(Vector2(56, 30), Vector2(44, 34), 2.5, NEGRO)
	ojo(31, 39, 5, Vector2(0.3, 0.2))
	ojo(49, 39, 5, Vector2(-0.3, 0.2))
	elipse(40, 54, 13, 6, NEGRO)
	caja(30, 50, 50, 52, BLANCO)
	for x in [33, 38, 43]:
		poli([Vector2(x, 52), Vector2(x + 2, 52), Vector2(x + 1, 55)], BLANCO)
	figura([Vector2(35, 64), Vector2(45, 64), Vector2(40, 76)], NEGRO.lightened(0.15))


func _sirena() -> void:
	bola_elipse(36, 26, 14, 18, NARANJA, 10)
	figura([Vector2(32, 44), Vector2(46, 44), Vector2(50, 60), Vector2(56, 70), Vector2(44, 66), Vector2(34, 56)], TURQUESA)
	figura([Vector2(54, 66), Vector2(68, 60), Vector2(64, 74), Vector2(70, 78), Vector2(52, 74)], VERDE)
	for k in 4:
		arco(40 + k * 3, 48 + k * 5, 3, 0, 180, 1, TURQUESA.darkened(0.3))
	bola_elipse(39, 38, 9, 9, PIEL)
	disco(35, 39, 2.5, MORADO)
	disco(43, 39, 2.5, MORADO)
	bola(40, 22, 10, PIEL)
	bola_elipse(34, 15, 9, 5, NARANJA, -20)
	ojo(37, 22, 2.6)
	ojo(44, 22, 2.6)
	sonrisa(40, 25, 3, 1.0)
	cachetes(34, 47, 27, 1.8)


func _paraguas() -> void:
	figura([Vector2(8, 40), Vector2(14, 22), Vector2(28, 11), Vector2(40, 8), Vector2(52, 11), Vector2(66, 22), Vector2(72, 40)], MORADO)
	for k in 4:
		disco(15 + k * 17, 40, 8.5, Color(0, 0, 0, 0))
	for x in [26, 40, 54]:
		linea(Vector2(40, 9), Vector2(x, 34), 1.5, MORADO.lightened(0.3))
	disco(40, 7, 2.5, NEGRO)
	linea(Vector2(40, 34), Vector2(40, 66), 3, CAFE_OSC)
	arco(46, 66, 6, 0, 180, 3, CAFE_OSC)
	disco(24, 18, 2, MORADO.lightened(0.6))


func _calavera() -> void:
	bola(40, 34, 24, HUESO)
	caja(28, 52, 52, 64, HUESO.darkened(0.08))
	ojo(30, 36, 7.5, Vector2(0.1, 0.1))
	ojo(50, 36, 7.5, Vector2(-0.1, 0.1))
	disco(30, 36, 7.5, NEGRO)
	disco(50, 36, 7.5, NEGRO)
	disco(28, 34, 2, BLANCO)
	disco(48, 34, 2, BLANCO)
	poli([Vector2(37, 50), Vector2(43, 50), Vector2(40, 44)], NEGRO)
	for x in [32, 37, 42, 47]:
		linea(Vector2(x, 54), Vector2(x, 62), 1.4, NEGRO)
	for k in 5:
		var a := deg_to_rad(k * 72.0)
		bola(58 + cos(a) * 4, 14 + sin(a) * 4, 3.5, ROSA, false)
	disco(58, 14, 2.5, AMARILLO)


func _nopal() -> void:
	bola_elipse(40, 54, 16, 20, VERDE)
	bola_elipse(22, 28, 11, 14, VERDE, -25)
	bola_elipse(58, 26, 11, 14, VERDE, 25)
	for p in [Vector2(30, 46), Vector2(50, 50), Vector2(36, 66), Vector2(18, 24), Vector2(60, 22), Vector2(46, 62)]:
		px(int(p.x), int(p.y), AMARILLO)
		px(int(p.x) + 1, int(p.y), AMARILLO)
	for p in [Vector2(16, 13), Vector2(28, 14), Vector2(54, 11), Vector2(66, 13)]:
		bola(p.x, p.y, 4.5, ROSA.darkened(0.15))
	ojo(34, 52, 3.5)
	ojo(46, 52, 3.5)
	sonrisa(40, 56, 4)


func _luna() -> void:
	bola(36, 40, 26, AMARILLO)
	disco(50, 32, 24, Color(0, 0, 0, 0))
	linea(Vector2(20, 38), Vector2(25, 40), 1.6, NEGRO)
	arco(22, 50, 4, 20, 140, 1.4, NEGRO)
	disco(19, 45, 2.2, ROSA)
	for p in [Vector2(60, 16), Vector2(66, 48), Vector2(52, 64)]:
		poli([p + Vector2(0, -5), p + Vector2(1.5, -1.5), p + Vector2(5, 0), p + Vector2(1.5, 1.5), p + Vector2(0, 5),
			p + Vector2(-1.5, 1.5), p + Vector2(-5, 0), p + Vector2(-1.5, -1.5)], BLANCO)


func _sol() -> void:
	for k in 12:
		var a := deg_to_rad(k * 30.0)
		var b := deg_to_rad(k * 30.0 + 12.0)
		var c := deg_to_rad(k * 30.0 - 12.0)
		poli([Vector2(40 + cos(a) * 36, 40 + sin(a) * 36), Vector2(40 + cos(b) * 20, 40 + sin(b) * 20),
			Vector2(40 + cos(c) * 20, 40 + sin(c) * 20)], NARANJA if k % 2 == 0 else AMARILLO)
	bola(40, 40, 21, AMARILLO)
	ojo(33, 37, 4.5)
	ojo(47, 37, 4.5)
	arco(40, 44, 7, 15, 165, 2, NEGRO)
	cachetes(28, 52, 46, 3)


func _corazon() -> void:
	disco(29, 31, 15, ROJO.darkened(0.35))
	disco(51, 31, 15, ROJO.darkened(0.35))
	poli([Vector2(15, 36), Vector2(65, 36), Vector2(40, 70)], ROJO.darkened(0.35))
	disco(28, 30, 13, ROJO)
	disco(50, 30, 13, ROJO)
	poli([Vector2(16, 34), Vector2(63, 34), Vector2(40, 66)], ROJO)
	disco(23, 24, 3, ROJO.lightened(0.6))
	ojo(33, 38, 4)
	ojo(47, 38, 4)
	sonrisa(40, 43, 5, 1.6)
	linea(Vector2(6, 64), Vector2(74, 14), 2, CAFE)
	poli([Vector2(74, 14), Vector2(64, 14), Vector2(72, 22)], GRIS)


func _campana() -> void:
	linea(Vector2(40, 6), Vector2(40, 14), 3, CAFE_OSC)
	arco(40, 8, 4, 180, 360, 2, CAFE_OSC)
	figura([Vector2(30, 16), Vector2(50, 16), Vector2(56, 30), Vector2(58, 50), Vector2(68, 60), Vector2(12, 60), Vector2(22, 50),
		Vector2(24, 30)], ORO)
	caja(12, 58, 68, 63, ORO.darkened(0.2))
	bola(40, 68, 6, CAFE)
	ojo(34, 38, 3.5)
	ojo(46, 38, 3.5)
	sonrisa(40, 42, 4)
	for k in 3:
		arco(40, 40, 32 + k * 4, -30, -10, 1.4, AMARILLO)


func _estrella() -> void:
	var puntas := []
	for k in 10:
		var r := 34.0 if k % 2 == 0 else 15.0
		var a := deg_to_rad(-90 + k * 36.0)
		puntas.append(Vector2(40 + cos(a) * r, 42 + sin(a) * r))
	figura(puntas, AMARILLO, 3.0)
	ojo(34, 40, 3.5)
	ojo(46, 40, 3.5)
	sonrisa(40, 45, 4)
	cachetes(29, 51, 47, 2)
	disco(30, 26, 2, BLANCO)


func _venado() -> void:
	for x in [24, 32, 48, 56]:
		linea(Vector2(x, 54), Vector2(x, 72), 3, CAFE_OSC)
	bola_elipse(40, 50, 22, 11, CAFE)
	for p in [Vector2(30, 46), Vector2(40, 44), Vector2(48, 48)]:
		disco(p.x, p.y, 1.8, HUESO)
	disco(17, 44, 4, BLANCO)
	linea(Vector2(56, 46), Vector2(60, 30), 7, CAFE)
	bola_elipse(62, 26, 9, 7, CAFE, 15)
	disco(70, 28, 2.5, NEGRO)
	ojo(62, 24, 3)
	bola_elipse(55, 18, 3, 5, CAFE.darkened(0.15), -30)
	linea(Vector2(60, 18), Vector2(56, 6), 2, HUESO.darkened(0.15))
	linea(Vector2(57, 10), Vector2(50, 6), 2, HUESO.darkened(0.15))
	linea(Vector2(64, 18), Vector2(70, 6), 2, HUESO.darkened(0.15))
	linea(Vector2(68, 10), Vector2(74, 8), 2, HUESO.darkened(0.15))


func _rana() -> void:
	bola_elipse(40, 52, 28, 18, VERDE)
	bola_elipse(40, 58, 18, 10, VERDE.lightened(0.35))
	bola(26, 34, 9, VERDE)
	bola(54, 34, 9, VERDE)
	ojo(26, 33, 6, Vector2(0.1, 0.2))
	ojo(54, 33, 6, Vector2(-0.1, 0.2))
	arco(40, 46, 13, 25, 155, 2, NEGRO)
	cachetes(22, 58, 50, 3)
	for x in [18, 62]:
		bola_elipse(x, 68, 8, 4, VERDE.darkened(0.15))


func _pescado() -> void:
	figura([Vector2(58, 40), Vector2(74, 26), Vector2(70, 40), Vector2(74, 54)], AZUL_CLARO)
	figura([Vector2(30, 24), Vector2(44, 16), Vector2(48, 28)], AZUL_CLARO)
	bola_elipse(36, 40, 26, 16, AZUL)
	for k in 3:
		arco(40 + k * 7, 40, 6, -60, 60, 1.2, AZUL.darkened(0.3))
	ojo(22, 36, 5.5)
	arco(14, 46, 3, 300, 420, 1.4, NEGRO)
	for k in 3:
		disco(12 - k * 2, 22 - k * 7, 2 + k, Color(0.8, 0.95, 1.0))


func _arana() -> void:
	linea(Vector2(40, 2), Vector2(40, 30), 1, GRIS)
	for lado in [-1, 1]:
		for k in 4:
			var y := 34 + k * 7
			var rodilla := Vector2(40 + lado * 24, y - 8 + k * 2)
			linea(Vector2(40 + lado * 8, y), rodilla, 2.5, NEGRO)
			linea(rodilla, Vector2(40 + lado * (30 + k), y + 10), 2.5, NEGRO)
	bola(40, 50, 15, NEGRO.lightened(0.15))
	bola(40, 32, 10, NEGRO.lightened(0.15))
	poli([Vector2(36, 46), Vector2(44, 46), Vector2(40, 52)], ROJO)
	poli([Vector2(36, 58), Vector2(44, 58), Vector2(40, 52)], ROJO)
	ojo(35, 31, 4)
	ojo(45, 31, 4)
	sonrisa(40, 35, 3, 1.0)


func _rosa() -> void:
	linea(Vector2(40, 40), Vector2(42, 76), 3, VERDE_OSC)
	bola_elipse(30, 58, 9, 4, VERDE, -30)
	bola_elipse(52, 64, 9, 4, VERDE, 30)
	bola(40, 28, 20, ROJO)
	arco(40, 28, 13, 200, 340, 2, ROJO.darkened(0.3))
	arco(40, 30, 8, 20, 200, 2, ROJO.darkened(0.3))
	arco(42, 27, 4, 180, 400, 1.6, ROJO.darkened(0.3))
	disco(30, 18, 2.5, ROJO.lightened(0.6))


func _cotorro() -> void:
	linea(Vector2(6, 64), Vector2(74, 64), 4, CAFE)
	figura([Vector2(30, 52), Vector2(38, 54), Vector2(22, 78), Vector2(14, 76)], AZUL)
	bola_elipse(38, 44, 15, 19, VERDE)
	bola_elipse(32, 46, 8, 12, VERDE.darkened(0.15), 20)
	bola(46, 22, 12, VERDE.lightened(0.15))
	disco(51, 26, 3.5, ROJO)
	figura([Vector2(55, 18), Vector2(64, 20), Vector2(62, 30), Vector2(56, 26)], AMARILLO)
	ojo(48, 19, 3.5)
	linea(Vector2(36, 64), Vector2(38, 68), 2, ORO)
	linea(Vector2(44, 64), Vector2(46, 68), 2, ORO)


func _corona() -> void:
	figura([Vector2(10, 62), Vector2(10, 26), Vector2(24, 44), Vector2(40, 16), Vector2(56, 44), Vector2(70, 26), Vector2(70, 62)], ORO, 3.0)
	caja(10, 56, 70, 64, ORO.darkened(0.15))
	for p in [Vector2(10, 24), Vector2(40, 14), Vector2(70, 24)]:
		bola(p.x, p.y, 4, BLANCO)
	for k in 3:
		bola(24 + k * 16, 50, 4.5, [ROJO, AZUL, VERDE][k])
	disco(20, 34, 2, ORO.lightened(0.6))


func _apagado() -> void:
	bola(40, 40, 25, ZOMBI)
	for k in 5:
		figura([Vector2(18 + k * 10, 20), Vector2(23 + k * 10, 4 + (k % 2) * 4), Vector2(28 + k * 10, 20)], NEGRO.lightened(0.1))
	disco(30, 38, 7, BLANCO)
	disco(50, 39, 5, BLANCO)
	disco(31, 39, 2, ROJO)
	disco(50, 40, 1.5, ROJO)
	arco(30, 38, 8, 200, 330, 1.6, ZOMBI.darkened(0.4))
	elipse(40, 55, 10, 5, NEGRO)
	for x in [34, 39, 44]:
		caja(x, 51, x + 2, 53, HUESO)
	linea(Vector2(52, 24), Vector2(60, 34), 1.4, ZOMBI.darkened(0.45))
	for k in 3:
		linea(Vector2(53 + k * 3, 27 + k * 3), Vector2(57 + k * 3, 25 + k * 3), 1, ZOMBI.darkened(0.45))


func _pipa() -> void:
	figura([Vector2(6, 26), Vector2(54, 26), Vector2(58, 30), Vector2(58, 52), Vector2(6, 52)], AZUL)
	caja(8, 36, 54, 40, BLANCO)
	disco(16, 30, 2, AZUL.lightened(0.6))
	figura([Vector2(56, 34), Vector2(70, 34), Vector2(76, 44), Vector2(76, 56), Vector2(56, 56)], BLANCO.darkened(0.08))
	caja(62, 38, 70, 45, AZUL_CLARO)
	caja(6, 52, 76, 58, GRIS.darkened(0.3))
	for x in [16, 36, 66]:
		bola(x, 62, 8, NEGRO.lightened(0.1), false)
		disco(x, 62, 3, GRIS)


func _machete() -> void:
	figura([Vector2(14, 66), Vector2(56, 18), Vector2(70, 10), Vector2(66, 24), Vector2(22, 72)], GRIS)
	linea(Vector2(18, 66), Vector2(60, 20), 1.4, BLANCO)
	linea(Vector2(16, 70), Vector2(4, 78), 7, CAFE_OSC)
	for t in [0.3, 0.7]:
		disco(lerpf(15, 5, t), lerpf(71, 77, t), 1.4, ORO)


func _garrafa() -> void:
	figura([Vector2(30, 12), Vector2(50, 12), Vector2(50, 20), Vector2(62, 28), Vector2(64, 72), Vector2(16, 72), Vector2(18, 28),
		Vector2(30, 20)], AZUL_CLARO)
	caja(18, 44, 62, 72, Color(0.35, 0.6, 0.95))
	caja(28, 6, 52, 13, AZUL)
	caja(28, 50, 52, 62, BLANCO)
	linea(Vector2(24, 30), Vector2(24, 66), 2.5, Color(0.9, 0.97, 1.0))
	ojo(35, 55, 3)
	ojo(45, 55, 3)
	sonrisa(40, 58, 3, 1.0)


func _camion() -> void:
	figura([Vector2(4, 24), Vector2(70, 24), Vector2(76, 32), Vector2(76, 60), Vector2(4, 60)], NARANJA)
	caja(4, 50, 76, 54, BLANCO)
	for k in 4:
		caja(8 + k * 15, 30, 19 + k * 15, 42, AZUL_CLARO)
	caja(68, 30, 75, 46, AZUL_CLARO)
	disco(74, 52, 2.5, AMARILLO)
	for x in [18, 60]:
		bola(x, 62, 8, NEGRO.lightened(0.1), false)
		disco(x, 62, 3, GRIS)


func _tinaco() -> void:
	bola_elipse(40, 20, 22, 8, NEGRO.lightened(0.2))
	caja(18, 20, 62, 70, NEGRO.lightened(0.12))
	elipse(40, 70, 22, 6, NEGRO.lightened(0.12))
	for y in [32, 46, 60]:
		arco(40, y - 14, 22, 30, 150, 2, NEGRO.lightened(0.3))
	caja(22, 22, 25, 66, NEGRO.lightened(0.35))
	bola_elipse(40, 14, 10, 4, NEGRO.lightened(0.25))
	caja(32, 40, 48, 48, BLANCO)
	ojo(32, 30, 3.5)
	ojo(48, 30, 3.5)
