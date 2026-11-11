extends Node3D

# Raiz de las casas de los vecinos de Santa Mugre (scenes/casas/*.tscn, las arma
# tools/construir_casas_vecinos.gd; docs/mapa/colonias/santa_mugre.md, casas 7-10). Se entran
# caminando como la del jugador (CasaPropia.gd, con su puerta en la pared oeste) y aqui se pone
# quien vive y lo que se hace:
#   guero       el Guero, el empleado del palacio: platica (docs/personajes.md)
#   sofia       Sofia y su radio pirata (solo de noche, CasaPropia.abierto): platica y la radio
#   tono        Tono el tianguista: platica y te vende de lo de su puesto
#   clausurada  la casa que clauso GelA: nadie, el sello y lo que dejaron (una vez por partida,
#               Baul.saqueadas)
# Las misiones de cada uno (El Decreto 47, La verdad...) vienen despues como MisionData.

const NPC := preload("res://scenes/npc.tscn")
const PERSONA_EN := Vector3(4.2, 0.0, 2.5)    # m: frente a la puerta (x = 0), viendo hacia ella

@export_enum("guero", "sofia", "tono", "clausurada") var quien := "guero"

const LINEAS := {
	"guero": [
		"¿Usted que? Aqui no se tramita nada, esta es mi casa.",
		"Yo nomas sello papeles en el palacio. Actas de ausencia nocturna, se llaman. Bonito nombre, ¿no?",
		"Si alguien le pregunta, usted nunca vino. Buenrostro tiene orejas hasta en los tinacos.",
		"Copias hay... de todo hay. Pero cuestan, y no aqui. Luego hablamos.",
	],
	"sofia": [
		"Cierra la cortina. Si GelA ve la luz, se acaba la radio.",
		"Cada noche leo los nombres de los que no regresaron. Alguien tiene que decirlos.",
		"Lo que sale en la tele es lo que el palacio quiere. Lo que sale aqui es lo que pasa.",
		"Si consigues pruebas, traemelas. La gente tiene que oirlo.",
	],
	"tono": [
		"¡Pasele, joven! Aqui en la casa tambien hay fruta, nomas no le diga a mi señora.",
		"¿Quiere saber quien debe y quien paga? Preguntele a Toño. Toño sabe.",
		"El Guero anda raro, ¿eh? Mucho papel y poca platica.",
		"En la noche no le abro ni a mi compadre. Ya ve como se pone la calle.",
	],
}
const RADIO := [
	"\"...aqui Radio Gotera, la que no se compra. Esta noche faltan tres en Parques del Mosco...\"",
	"\"...dicen que el agua de la llave trae algo. Nosotros no decimos: preguntamos...\"",
	"\"...a los blancos de GelA: sabemos donde estan las tomas que ustedes cierran y no...\"",
	"\"...si nos escuchas, no salgas. Y si sales, no vayas solo...\"",
]
const SELLO := "CLAUSURADO POR ADEUDO. GelA - Agua que se paga. Prohibido el paso."
const BOTIN := ["res://resources/productos/tablas.tres", "res://resources/productos/cinta.tres",
		"res://resources/productos/takis_tazo.tres"]
const TONO_VENDE := "res://resources/productos/mazapan.tres"
const TONO_PRECIO := 8

var _texto: Label
var _linea := 0


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 11
	add_child(capa)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_texto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_texto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto.offset_bottom = -40.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	_texto.custom_minimum_size.x = 560.0
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 6)
	_texto.modulate.a = 0.0
	capa.add_child(_texto)
	if LINEAS.has(quien):
		_persona()
	match quien:
		"sofia":
			add_child(MuebleCasa.crear("Escuchar la radio", Vector3(3.0, 0.0, 0.8), _avisar.bind("", true)))
		"tono":
			add_child(MuebleCasa.crear("Comprarle un mazapan ($%d)" % TONO_PRECIO, Vector3(2.4, 0.0, 4.2), _comprar))
		"clausurada":
			add_child(MuebleCasa.crear("Leer el sello", Vector3(1.0, 0.0, 1.0), _avisar.bind(SELLO)))
			_botin()


func _persona() -> void:
	var npc := NPC.instantiate() as Node3D
	npc.name = "Vecino"
	npc.set("modelo", Civiles.elegir(quien))
	npc.set("dialogue", LINEAS[quien][0])
	npc.set("al_hablar", func() -> String:
		var texto: String = LINEAS[quien][_linea % LINEAS[quien].size()]
		_linea += 1
		return texto)
	npc.position = PERSONA_EN
	npc.rotation.y = PI / 2.0       # el npc ve a su -Z: asi ve hacia la puerta (-x)
	add_child(npc)


func _avisar(texto: String, radio := false) -> void:
	if radio:
		texto = RADIO[randi() % RADIO.size()]
	_texto.text = texto
	var tween := create_tween()
	tween.tween_property(_texto, "modulate:a", 1.0, 0.25)
	tween.tween_interval(4.5)
	tween.tween_property(_texto, "modulate:a", 0.0, 0.6)


func _comprar() -> void:
	var cartera := get_node_or_null("/root/Cartera")
	var inventario := get_node_or_null("/root/Inventory")
	var item := load(TONO_VENDE) as InventoryItemData
	if cartera == null or inventario == null:
		return
	if cartera.pesos < TONO_PRECIO:
		_avisar("\"Ahorita no trae, ¿verdad? Luego me paga... no, mejor no.\"")
	elif not inventario.cabe(item):
		_avisar("No te cabe nada mas en la mochila.")
	else:
		cartera.pesos -= TONO_PRECIO
		inventario.add_item(item)
		_avisar("\"¡Ahi le va! Del mero bueno.\" (Mazapan, $%d)" % TONO_PRECIO)


# Lo que dejaron los de la casa clausurada: una vez por partida (si sales sin levantarlo, ya no esta)
func _botin() -> void:
	var baul := get_node_or_null("/root/Baul")
	if baul == null or baul.saqueadas.has(quien):
		return
	baul.saqueadas[quien] = true
	for i in BOTIN.size():
		var cosa := Node3D.new()
		cosa.set_script(load("res://scripts/WorldItem.gd"))
		cosa.set("item_data", load(BOTIN[i]))
		cosa.position = Vector3(2.5 + i * 1.1, 0.0, 3.6)
		add_child(cosa)
