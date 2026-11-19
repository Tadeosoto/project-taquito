class_name CartasLoteria
extends RefCounted

# Las cartas de la loteria del Sotano (textures/sotano/cartas.png, las renderiza
# tools/blender/sotano/arte.py en este mismo orden: 8 columnas de 128 x 192 px). Las ultimas son
# de este mundo: El Apagado (el zombi), La Pipa (la de GelA), La Garrafa, El Camion y El Tinaco,
# el comodin de la maquinita OL PLEY.
# VERSOS: lo que canta el griton (scripts/sotano/LoteriaUI.gd). Escritos para el juego, en el tono
# de los de siempre, sin copiarlos.

const ATLAS := preload("res://textures/sotano/cartas.png")
const COLUMNAS := 8
const TAMANO := Vector2(128, 192)

const NOMBRES := ["El Gallo", "El Diablito", "La Sirena", "El Paraguas", "La Calavera", "El Nopal",
	"La Luna", "El Sol", "El Corazón", "La Campana", "La Estrella", "El Venado", "La Rana",
	"El Pescado", "La Araña", "La Rosa", "El Cotorro", "La Corona", "El Apagado", "La Pipa",
	"El Machete", "La Garrafa", "El Camión", "El Tinaco"]

const VERSOS := [
	"El que canta antes que el sol... ¡el gallo!",
	"Pórtate bien, que te lleva... ¡el diablito!",
	"Con los cantos de ella se perdió el marinero... ¡la sirena!",
	"Para el agua que cae y para la que no se debe... ¡el paraguas!",
	"Flaca, pelona y sin prisa... ¡la calavera!",
	"Con tuna y con espina, el de la bandera... ¡el nopal!",
	"La farola de los que salen de noche... ¡la luna!",
	"El que seca la ropa y espanta a los muertos... ¡el sol!",
	"No me extrañes, corazón, que regreso en el camión... ¡el corazón!",
	"Pa' la misa y pa' la reja... ¡la campana!",
	"La que guía a los que andan perdidos... ¡la estrella!",
	"Saltando la barda de un brinco... ¡el venado!",
	"Salta y salta en el charco del drenaje... ¡la rana!",
	"El que por la boca muere... ¡el pescado!",
	"Teje que teje en el rincón del Sótano... ¡la araña!",
	"Bonita y con espinas, como la del patrón... ¡la rosa!",
	"Repite y repite lo que no debe... ¡el cotorro!",
	"La que nunca se pone el que la paga... ¡la corona!",
	"No contesta, no se cansa, nomás camina... ¡el apagado!",
	"Agua que viene con dueño... ¡la pipa!",
	"Pa' la caña y pa' lo que salga de noche... ¡el machete!",
	"Llena o vacía, siempre pesa... ¡la garrafa!",
	"Súbase, que hay lugar atrás... ¡el camión!",
	"El que guarda el agua buena... ¡el tinaco!",
]

const TINACO := 23

static var _texturas := {}


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
