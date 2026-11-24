class_name ZonasMapa
extends RefCounted

# Las zonas del mapa de papel (scripts/MapaUI.gd, docs/especificaciones.md 4.9), dibujadas a
# mano sobre textures/map/minimapa.png siguiendo las avenidas, el rio y la autopista. Los
# nombres son parodia de la colonia que les toca o inventados sobre el agua. Los poligonos
# comparten vertices (PUNTOS), asi que cubren todo el mapa sin huecos ni encimarse.

const LADO_MAPA := Vector2(1827.0, 1796.0)
const ORIGEN := Vector2(-913.0136883173468, -897.5349688244506)   # resources/map/minimapa.json
const ORILLA_PASO := 40.0     # m de cada tramo de la orilla rasgada
const ORILLA_RUIDO := 7.0     # m que se sale

const PUNTOS := {
	"no": Vector2(0, 0), "n": Vector2(480, 0), "ne": Vector2(1827, 0), "se": Vector2(1827, 1796), "so": Vector2(0, 1796),
	"o1": Vector2(0, 720), "o2": Vector2(0, 1310),
	# La avenida del poniente
	"a1": Vector2(482, 122), "a2": Vector2(370, 700), "a3": Vector2(355, 800), "a4": Vector2(378, 1350), "a5": Vector2(380, 1796),
	# La avenida de arriba
	"t1": Vector2(600, 78), "t2": Vector2(1200, 250), "t3": Vector2(1600, 385), "t4": Vector2(1780, 450), "t5": Vector2(1827, 470),
	# El rio
	"r1": Vector2(600, 290), "r2": Vector2(720, 510), "r3": Vector2(810, 730), "r4": Vector2(860, 850),
	"r5": Vector2(790, 1030), "r6": Vector2(830, 1110), "r7": Vector2(1100, 1290),
	# La avenida ancha de abajo
	"b1": Vector2(700, 1362), "b2": Vector2(1100, 1420),
	# La autopista
	"f0": Vector2(905, 1796), "f1": Vector2(1000, 1680), "f2": Vector2(1170, 1505), "f3": Vector2(1340, 1385),
	"f4": Vector2(1450, 1325), "f5": Vector2(1600, 1240), "f6": Vector2(1827, 1060),
	# La calle que separa los Parques de las Haciendas
	"e1": Vector2(1480, 345), "e2": Vector2(1490, 640), "e3": Vector2(1480, 1100),
}

const ZONAS := [
	{"nombre": "El Mante Tieso", "borde": ["no", "n", "a1", "a2", "o1"]},
	{"nombre": "Los Garrafones", "borde": ["n", "ne", "t5", "t4", "t3", "e1", "t2", "t1", "a1"]},
	{"nombre": "La Florida Marchita", "borde": ["o1", "a2", "a3", "a4", "o2"]},
	{"nombre": "La Palmada", "borde": ["o2", "a4", "a5", "so"]},
	{"nombre": "Parques de Santa Mugre", "borde": ["a1", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "f3", "f2", "b2", "b1", "a4", "a3", "a2"]},
	{"nombre": "Parques del Mosco", "borde": ["a1", "t1", "t2", "e1", "e2", "e3", "f4", "f3", "r7", "r6", "r5", "r4", "r3", "r2", "r1"]},
	{"nombre": "Haciendas de San Jodido", "borde": ["e1", "t3", "t4", "t5", "f6", "f5", "f4", "e3", "e2"]},
	{"nombre": "El Último Trago", "borde": ["a4", "b1", "b2", "f2", "f1", "f0", "a5"]},
	{"nombre": "", "borde": ["f0", "f1", "f2", "f3", "f4", "f5", "f6", "se"]},   # el sureste: sin nombre ni lore (JJ, 2026-11-12), la fortaleza La Gotera esta en Haciendas
]

static var _poligonos: Array[PackedVector2Array] = []
static var _rasgados: Array[PackedVector2Array] = []


static func cuantas() -> int:
	return ZONAS.size()


static func nombre(zona: int) -> String:
	return ZONAS[zona]["nombre"]


# Para listas y avisos: las zonas sin nombre (el sureste) salen como "Sin nombre"
static func etiqueta(zona: int) -> String:
	var n: String = ZONAS[zona]["nombre"]
	return n if n != "" else "Sin nombre"


# En pixeles del minimapa (1 px = 1 m)
static func poligono(zona: int) -> PackedVector2Array:
	_preparar()
	return _poligonos[zona]


# El mismo, con la orilla rasgada: dos zonas vecinas la rasgan igual y siguen embonando
static func rasgado(zona: int) -> PackedVector2Array:
	_preparar()
	return _rasgados[zona]


static func centro(zona: int) -> Vector2:
	var suma := Vector2.ZERO
	var area := 0.0
	var p := poligono(zona)
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		var c := a.cross(b)
		area += c
		suma += (a + b) * c
	return suma / (3.0 * area)


static func a_mapa(x: float, z: float) -> Vector2:
	return Vector2(x, z) - ORIGEN


static func a_mundo(punto: Vector2) -> Vector2:
	return punto + ORIGEN


# La zona de un punto del mundo; -1 afuera del mapa
static func zona_en(x: float, z: float) -> int:
	var p := a_mapa(x, z)
	for i in ZONAS.size():
		if Geometry2D.is_point_in_polygon(p, poligono(i)):
			return i
	return -1


static func _preparar() -> void:
	if not _poligonos.is_empty():
		return
	for zona: Dictionary in ZONAS:
		var limpio := PackedVector2Array()
		var roto := PackedVector2Array()
		var borde: Array = zona["borde"]
		for i in borde.size():
			var a: Vector2 = PUNTOS[borde[i]]
			var b: Vector2 = PUNTOS[borde[(i + 1) % borde.size()]]
			limpio.append(a)
			roto.append_array(_tramo(a, b))
		_poligonos.append(limpio)
		_rasgados.append(roto)


# De `a` hacia `b` sin incluir `b`; el mismo tramo sale igual en cualquier sentido
static func _tramo(a: Vector2, b: Vector2) -> PackedVector2Array:
	var fuera := PackedVector2Array([a])
	# La orilla del mapa va derecha
	if (a.x == b.x and (a.x == 0.0 or a.x == LADO_MAPA.x)) or (a.y == b.y and (a.y == 0.0 or a.y == LADO_MAPA.y)):
		return fuera
	var pasos := maxi(roundi(a.distance_to(b) / ORILLA_PASO), 1)
	var primero := a if a < b else b
	var ultimo := b if a < b else a
	var normal := (ultimo - primero).orthogonal().normalized()
	for k in range(1, pasos):
		var t := float(k) / pasos
		var base := primero.lerp(ultimo, t)
		var sorteo := float(hash(Vector2i(base)) & 1023) / 1023.0 - 0.5
		var punto := base + normal * sorteo * ORILLA_RUIDO * 2.0
		# Siempre desde `a`, sea cual sea el orden en que se calculo
		if a < b:
			fuera.append(punto)
		else:
			fuera.insert(1, punto)
	return fuera
