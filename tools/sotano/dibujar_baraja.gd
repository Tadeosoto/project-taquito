extends SceneTree

# La baraja del Sotano (poker, blackjack y baccarat) en pixel art nitido, dibujada pixel por pixel
# (AG, 2026-11-19: la de Blender se veia "pintada a mano con lapiz"):
#   godot --path . --headless -s tools/sotano/dibujar_baraja.gd   (luego --import)
# Sale textures/sotano/baraja.png: 14 columnas x 4 filas de CARTA (128 x 192). Columnas 2..10, J, Q,
# K, A; filas picas, corazones, diamantes, treboles (el orden de Holdem.gd: carta = palo * 13 +
# rango - 2); la columna 14 de la primera fila es el reverso (El Tinaco sobre rojo vino).
# Numeros con su letra de pixeles (LETRAS), palos de 9 x 9 (PALOS) agrandados, los pips en el
# acomodo de siempre (los de abajo de cabeza) y las figuras como retratos de caricatura.

const SALIDA := "res://textures/sotano/baraja.png"
const CARTA := Vector2i(128, 192)
const CREMA := Color(0.98, 0.96, 0.9)
const ORILLA := Color(0.55, 0.5, 0.45)
const TINTA := Color(0.1, 0.09, 0.1)
const ROJO := Color(0.82, 0.1, 0.12)
const ORO := Color(0.95, 0.75, 0.2)
const PIEL := Color(0.97, 0.8, 0.62)

const PALOS := [
	["....#....", "...###...", "..#####..", ".#######.", "#########", "#########", ".##.#.##.", "....#....", "...###..."],
	[".##...##.", "####.####", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........."],
	["....#....", "...###...", "..#####..", ".#######.", "#########", ".#######.", "..#####..", "...###...", "....#...."],
	["...###...", "..#####..", "..#####..", "##.###.##", "#########", "##.###.##", "....#....", "...###...", "..#####.."],
]
const LETRAS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
}
const RANGOS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
# Pips por numero (centros en px de la carta); los de y > 96 van de cabeza
const PIPS := {
	2: [Vector2(64, 46), Vector2(64, 146)],
	3: [Vector2(64, 46), Vector2(64, 96), Vector2(64, 146)],
	4: [Vector2(46, 46), Vector2(82, 46), Vector2(46, 146), Vector2(82, 146)],
	5: [Vector2(46, 46), Vector2(82, 46), Vector2(64, 96), Vector2(46, 146), Vector2(82, 146)],
	6: [Vector2(46, 46), Vector2(82, 46), Vector2(46, 96), Vector2(82, 96), Vector2(46, 146), Vector2(82, 146)],
	7: [Vector2(46, 46), Vector2(82, 46), Vector2(64, 71), Vector2(46, 96), Vector2(82, 96), Vector2(46, 146), Vector2(82, 146)],
	8: [Vector2(46, 46), Vector2(82, 46), Vector2(64, 71), Vector2(46, 96), Vector2(82, 96), Vector2(64, 121), Vector2(46, 146), Vector2(82, 146)],
	9: [Vector2(46, 44), Vector2(82, 44), Vector2(46, 78), Vector2(82, 78), Vector2(64, 96), Vector2(46, 114), Vector2(82, 114),
		Vector2(46, 148), Vector2(82, 148)],
	10: [Vector2(46, 44), Vector2(82, 44), Vector2(64, 62), Vector2(46, 78), Vector2(82, 78), Vector2(46, 114), Vector2(82, 114),
		Vector2(64, 130), Vector2(46, 148), Vector2(82, 148)],
}

var img: Image
var ox := 0
var oy := 0


func _initialize() -> void:
	img = Image.create(CARTA.x * 14, CARTA.y * 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for palo in 4:
		for r in 13:
			ox = r * CARTA.x
			oy = palo * CARTA.y
			_carta(palo, r)
	ox = 13 * CARTA.x
	oy = 0
	_reverso()
	img.save_png(ProjectSettings.globalize_path(SALIDA))
	print("dibujar_baraja: ", SALIDA)
	quit()


# --- Pinceles (en px de la carta) ---

func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < CARTA.x and y < CARTA.y:
		img.set_pixel(ox + x, oy + y, c)


func caja(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(x, y, c)


func disco(cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			if (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy) <= r * r:
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


# Un dibujo de pixeles (filas de "#"/"1") agrandado `escala`, con su esquina en (x, y); de cabeza si `volteado`
func mapa(filas: Array, x: int, y: int, escala: int, c: Color, volteado := false) -> void:
	var alto := filas.size()
	var ancho: int = (filas[0] as String).length()
	for fy in alto:
		for fx in ancho:
			var ch := (filas[fy] as String)[fx]
			if ch != "#" and ch != "1":
				continue
			var gx := (ancho - 1 - fx) if volteado else fx
			var gy := (alto - 1 - fy) if volteado else fy
			caja(x + gx * escala, y + gy * escala, x + gx * escala + escala - 1, y + gy * escala + escala - 1, c)


func palo_en(palo: int, cx: int, cy: int, escala: int, volteado := false) -> void:
	var c := ROJO if palo == 1 or palo == 2 else TINTA
	mapa(PALOS[palo], cx - (9 * escala) / 2, cy - (9 * escala) / 2, escala, c, volteado)


func texto(t: String, x: int, y: int, escala: int, c: Color, volteado := false) -> void:
	# El "10" va con las cifras pegadas para que quepa
	var avance := 6 * escala if t.length() == 1 else 5 * escala
	var total := avance * (t.length() - 1) + 5 * escala
	for i in t.length():
		var ch := t[i]
		var dx := i * avance
		if volteado:
			dx = total - 5 * escala - i * avance
		mapa(LETRAS[ch], x + dx, y, escala, c, volteado)


# --- La carta ---

func _fondo() -> void:
	# Esquinas redondas (6 px), orilla gris y la cara crema
	for y in CARTA.y:
		for x in CARTA.x:
			var dx := maxi(maxi(6 - x, x - (CARTA.x - 7)), 0)
			var dy := maxi(maxi(6 - y, y - (CARTA.y - 7)), 0)
			var d := sqrt(dx * dx + dy * dy)
			if d > 6.5:
				continue
			px(x, y, ORILLA if d > 5.0 or x == 0 or y == 0 or x == CARTA.x - 1 or y == CARTA.y - 1 else CREMA)


func _carta(palo: int, r: int) -> void:
	_fondo()
	var rango: String = RANGOS[r]
	var c := ROJO if palo == 1 or palo == 2 else TINTA
	# Las esquinas: el numero y su palito, arriba a la izquierda y de cabeza abajo a la derecha
	texto(rango, 8, 8, 3, c)
	palo_en(palo, 16, 42, 2)
	var ancho := (6 * 3 * (rango.length() - 1) + 15) if rango.length() == 1 else (5 * 3 + 15)
	texto(rango, CARTA.x - 8 - ancho, CARTA.y - 8 - 21, 3, c, true)
	palo_en(palo, CARTA.x - 16, CARTA.y - 42, 2, true)
	if r <= 8:
		for p: Vector2 in PIPS[r + 2]:
			# Del 7 en adelante, mas chicos: a 3 se enciman
			palo_en(palo, int(p.x), int(p.y), 3 if r + 2 <= 6 else 2, p.y > 100)
	elif r == 12:
		# El as: un palo grande al centro, con un brillito
		palo_en(palo, 64, 96, 7)
	else:
		_figura(palo, rango)


# Las figuras: un retrato de caricatura en su marco, con el palo arriba de la corona
func _figura(palo: int, rango: String) -> void:
	var traje := ROJO if palo == 1 or palo == 2 else Color(0.18, 0.3, 0.7)
	caja(30, 34, 98, 158, ORO)
	caja(32, 36, 96, 156, Color(0.96, 0.92, 0.8))
	# Cuerpo y traje
	poli([Vector2(38, 156), Vector2(44, 118), Vector2(64, 110), Vector2(84, 118), Vector2(90, 156)], traje)
	poli([Vector2(58, 112), Vector2(70, 112), Vector2(66, 156), Vector2(62, 156)], ORO)
	# Cabeza
	disco(64, 92, 15, PIEL.darkened(0.2))
	disco(63, 91, 14, PIEL)
	disco(58, 89, 2.2, TINTA)
	disco(70, 89, 2.2, TINTA)
	px(57, 88, Color.WHITE)
	px(69, 88, Color.WHITE)
	disco(54, 96, 2.5, Color(1.0, 0.6, 0.6))
	disco(74, 96, 2.5, Color(1.0, 0.6, 0.6))
	match rango:
		"K":
			# Barba y corona grande
			poli([Vector2(50, 96), Vector2(78, 96), Vector2(74, 112), Vector2(64, 116), Vector2(54, 112)], Color(0.45, 0.28, 0.12))
			caja(58, 100, 70, 102, Color(0.6, 0.25, 0.2))
			poli([Vector2(48, 78), Vector2(48, 64), Vector2(55, 72), Vector2(64, 58), Vector2(73, 72), Vector2(80, 64), Vector2(80, 78)], ORO)
			for x in [48, 64, 80]:
				disco(x, 62 if x == 64 else 66, 2, ROJO)
		"Q":
			# Pelo largo y una corona chica
			poli([Vector2(46, 80), Vector2(50, 70), Vector2(64, 74), Vector2(78, 70), Vector2(82, 80), Vector2(84, 112), Vector2(76, 104),
				Vector2(76, 86), Vector2(52, 86), Vector2(52, 104), Vector2(44, 112)], Color(0.35, 0.18, 0.08))
			poli([Vector2(54, 76), Vector2(54, 66), Vector2(59, 71), Vector2(64, 63), Vector2(69, 71), Vector2(74, 66), Vector2(74, 76)], ORO)
			caja(59, 99, 69, 101, ROJO)
		"J":
			# Gorro con pluma y bigotito
			poli([Vector2(46, 80), Vector2(50, 70), Vector2(78, 70), Vector2(82, 80)], traje.darkened(0.2))
			poli([Vector2(78, 72), Vector2(92, 56), Vector2(82, 74)], ROJO.lightened(0.2))
			caja(58, 98, 70, 100, Color(0.35, 0.18, 0.08))


func _reverso() -> void:
	_fondo()
	var vino := Color(0.5, 0.06, 0.1)
	caja(6, 6, CARTA.x - 7, CARTA.y - 7, vino)
	# Reja de rombos
	for y in range(6, CARTA.y - 6):
		for x in range(6, CARTA.x - 6):
			if (x + y) % 12 == 0 or (x - y + 1200) % 12 == 0:
				px(x, y, vino.lightened(0.18))
	caja(10, 10, CARTA.x - 11, 11, ORO)
	caja(10, CARTA.y - 12, CARTA.x - 11, CARTA.y - 11, ORO)
	caja(10, 10, 11, CARTA.y - 11, ORO)
	caja(CARTA.x - 12, 10, CARTA.x - 11, CARTA.y - 11, ORO)
	# El Tinaco en un ovalo crema
	for y in range(56, 137):
		for x in range(28, 101):
			if pow((x - 64) / 36.0, 2) + pow((y - 96) / 40.0, 2) <= 1.0:
				px(x, y, CREMA)
	var negro := Color(0.12, 0.12, 0.13)
	caja(48, 78, 80, 120, negro)
	disco(64, 78, 16, negro)
	disco(64, 120, 16, negro)
	caja(48, 78, 80, 120, negro)
	for yy in [88, 100, 112]:
		caja(48, yy, 80, yy + 1, negro.lightened(0.18))
	caja(52, 82, 54, 116, negro.lightened(0.3))
	caja(57, 66, 71, 70, negro.lightened(0.12))
	caja(58, 96, 70, 104, CREMA)
