class_name CartasLoteria
extends RefCounted

# Las cartas de la loteria del Sotano (textures/sotano/cartas.png, las renderiza
# tools/blender/sotano/arte.py en este mismo orden: 8 columnas de 96 x 144 px, sin el nombre: lo
# escribe OlPleyUI con letra de pixel, que si se lee). Las ultimas son de este mundo: El Apagado
# (el zombi), La Pipa (la de GelA), La Garrafa, El Camion y El Tinaco, el comodin de EL GORDO.

const ATLAS := preload("res://textures/sotano/cartas.png")
const COLUMNAS := 8
const TAMANO := Vector2(96, 144)
# Los dibujos (pixel art de caricatura de tools/sotano/dibujar_cartas.gd, fondo transparente): 8 x 3 de 80 x 80
const DIBUJOS := preload("res://textures/sotano/cartas_dibujos.png")
const DIBUJO := Vector2(80, 80)

const NOMBRES := ["El Gallo", "El Diablito", "La Sirena", "El Paraguas", "La Calavera", "El Nopal",
	"La Luna", "El Sol", "El Corazón", "La Campana", "La Estrella", "El Venado", "La Rana",
	"El Pescado", "La Araña", "La Rosa", "El Cotorro", "La Corona", "El Apagado", "La Pipa",
	"El Machete", "La Garrafa", "El Camión", "El Tinaco"]

const TINACO := 23

static var _texturas := {}
static var _dibujos := {}


# El dibujo 3D de la carta `i` (va encima del campo de color de su carta)
static func dibujo(i: int) -> AtlasTexture:
	if not _dibujos.has(i):
		var t := AtlasTexture.new()
		t.atlas = DIBUJOS
		t.region = Rect2(Vector2(i % COLUMNAS, i / COLUMNAS) * DIBUJO, DIBUJO)
		_dibujos[i] = t
	return _dibujos[i]


static func cuantas() -> int:
	return NOMBRES.size()


# La carta `i` como textura (una AtlasTexture por carta, compartida)
static func textura(i: int) -> AtlasTexture:
	if not _texturas.has(i):
		var t := AtlasTexture.new()
		t.atlas = ATLAS
		t.region = Rect2(Vector2(i % COLUMNAS, i / COLUMNAS) * TAMANO, TAMANO)
		_texturas[i] = t
	return _texturas[i]
