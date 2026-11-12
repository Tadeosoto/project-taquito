extends Node3D

# Raiz del interior de la parroquia de Santa Mugre (scenes/casas/templo.tscn, la arma
# tools/construir_templo.gd). Se entra caminando como las casas de los vecinos (CasaPropia.gd, marca
# "casa_vecino" en el atrio): la nave con sus bancas, el altar con la Virgen del Tinaco y, detras de
# la cortina del retablo, la bajada al cuarto del pozo donde el padre Chuy filtra el agua
# (docs/personajes.md, "Padre Jesus 'Chuy' Arreola"; docs/lore.md, el templo).
# Aqui se pone al padre y lo que se puede mirar. El padre nunca dice lo que sospecha (decision de
# JJ): sus lineas esquivan. Todavia no hay misiones ni se reparte agua (eso es economia: bloque F3
# y el balance de docs/plan-noche.md).

const NPC := preload("res://scenes/npc.tscn")
const PADRE_EN := Vector3(10.6, 0.2, 3.11)      # sobre la tarima del presbiterio, viendo a la puerta
const LINEAS := [
	"Pásale, hijo. Aquí nadie te pregunta de dónde vienes.",
	"El agua es de todos. Nomás no me pidas que te explique el milagro: los milagros no se explican.",
	"Yo no hago nada. Yo nomás la reparto.",
	"Hay cosas que es mejor no andar diciendo. La gente necesita en qué creer, y dormir tranquila.",
	"Detrás del altar no hay nada que ver. Ándale, ve con Dios.",
]
const TEXTO_VIRGEN := "La Virgen del Tinaco. Dicen que la mancha amaneció sola, y que desde entonces aquí nadie se apaga."
const TEXTO_PILA := "Agua bendita. Está fría y no sabe a nada. A nada de lo que sabe la de la llave."
const TEXTO_POZO := "Un pozo. El agua está muy abajo y se oye correr. Nadie más que el padre baja aquí."
const TEXTO_FILTRO := "Un filtro con la etiqueta raspada. Todavía se lee: \"Puri-G...\". De aquí sale lo bendito."
const TEXTO_CUADERNO := "Un cuaderno con fechas y garrafones. Al margen, la letra del padre: \"los que toman de aquí no se apagan. No decir.\""

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
	var padre := NPC.instantiate() as Node3D
	padre.name = "PadreChuy"
	padre.set("modelo", "hombre_29")        # canoso, de camisa clara: "una camisa que fue blanca" (personajes.md)
	padre.set("dialogue", LINEAS[0])
	padre.set("al_hablar", func() -> String:
		var linea: String = LINEAS[_linea % LINEAS.size()]
		_linea += 1
		return linea)
	padre.position = PADRE_EN
	padre.rotation.y = PI / 2.0        # el npc ve a su -Z: asi ve hacia la puerta (-x)
	add_child(padre)
	# Lo que se puede mirar (los lugares son los de tools/construir_templo.gd)
	add_child(MuebleCasa.crear("Mirar a la Virgen", Vector3(12.6, 0.2, 3.11), _avisar.bind(TEXTO_VIRGEN), 1.5))
	add_child(MuebleCasa.crear("Tocar el agua bendita", Vector3(1.4, 0.0, 1.2), _avisar.bind(TEXTO_PILA)))
	add_child(MuebleCasa.crear("Asomarse al pozo", Vector3(18.6, -2.8, 2.2), _avisar.bind(TEXTO_POZO), 1.7))
	add_child(MuebleCasa.crear("Ver el filtro", Vector3(21.0, -2.8, 1.2), _avisar.bind(TEXTO_FILTRO)))
	add_child(MuebleCasa.crear("Leer el cuaderno", Vector3(20.5, -2.8, 5.2), _avisar.bind(TEXTO_CUADERNO)))


func _avisar(texto: String) -> void:
	_texto.text = texto
	var tween := create_tween()
	tween.tween_property(_texto, "modulate:a", 1.0, 0.25)
	tween.tween_interval(5.0)
	tween.tween_property(_texto, "modulate:a", 0.0, 0.6)
