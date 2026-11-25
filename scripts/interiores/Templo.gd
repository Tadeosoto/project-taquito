extends Node3D

# Raiz del interior de la parroquia de Santa Mugre (scenes/casas/templo.tscn, la arma
# tools/construir_templo.gd). Se entra caminando como las casas de los vecinos (CasaPropia.gd, marca
# "casa_vecino" en el atrio): la nave con sus bancas, el altar con la Virgen del Tinaco y, detras de
# la cortina del retablo, la bajada al cuarto del pozo donde el padre Chuy filtra el agua
# (docs/personajes.md, "Padre Jesus 'Chuy' Arreola"; docs/lore.md, el templo).
# Aqui se pone al padre y lo que se puede mirar. El padre nunca dice lo que sospecha (decision de
# JJ): sus lineas esquivan.
# La capilla (F3, "trae la tuya", docs/lore.md "Cómo se usa en el juego"): de dia el padre recibe tus
# envases con agua sucia (ENVASES), hasta lo que da el filtro (Misiones.capilla_cupo), y al
# amanecer te la tiene limpia: cada uno es +1 de agua (Cartera.agua). El pozo no se toca: nadie lo
# menciona y ninguna mision baja (misiones.md, regla L9).

const NPC := preload("res://scenes/npc.tscn")
const PADRE_EN := Vector3(10.6, 0.2, 3.11)      # sobre la tarima del presbiterio, viendo a la puerta
const LINEAS := [
	"Pásale, hijo. Aquí nadie te pregunta de dónde vienes.",
	"El agua es de todos. Nomás no me pidas que te explique el milagro: los milagros no se explican.",
	"Yo no hago nada. Yo nomás la reparto.",
	"Hay cosas que es mejor no andar diciendo. La gente necesita en qué creer, y dormir tranquila.",
	"Detrás del altar no hay nada que ver. Ándale, ve con Dios.",
]
# Lo que cuenta como "tu agua": los envases con agua sucia o vacios (los .tres de productos)
const ENVASES := ["res://resources/agua_mala.tres", "res://resources/productos/botella_vacia.tres"]
const TEXTO_TOMA := "Déjamela. Mañana temprano te la devuelvo limpia."
const TEXTO_TOMA_VARIAS := "Déjamelas, hijo. Mañana temprano te las devuelvo limpias."
const TEXTO_LISTA := "Aquí está la tuya, limpiecita. (+%d de agua)"
const TEXTO_MANANA := "Todavía no, hijo. Mañana temprano."
const TEXTO_LLENO := "Hoy ya no alcanza. El agua se limpia despacio; vuelve mañana."
const TEXTO_TRAE := "Aquí no se regala el agua, mijo. Se devuelve. La que traes sucia, te la llevas limpia."
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
	padre.set("al_hablar", _hablar_padre)
	padre.position = PADRE_EN
	padre.rotation.y = PI / 2.0        # el npc ve a su -Z: asi ve hacia la puerta (-x)
	add_child(padre)
	# Lo que se puede mirar (los lugares son los de tools/construir_templo.gd)
	add_child(MuebleCasa.crear("Mirar a la Virgen", Vector3(12.6, 0.2, 3.11), _avisar.bind(TEXTO_VIRGEN), 1.5))
	add_child(MuebleCasa.crear("Tocar el agua bendita", Vector3(1.4, 0.0, 1.2), func() -> void:
		_avisar(TEXTO_PILA + "
" + TEXTO_TRAE)))
	add_child(MuebleCasa.crear("Asomarse al pozo", Vector3(18.6, -2.8, 2.2), _avisar.bind(TEXTO_POZO), 1.7))
	add_child(MuebleCasa.crear("Ver el filtro", Vector3(21.0, -2.8, 1.2), _avisar.bind(TEXTO_FILTRO)))
	add_child(MuebleCasa.crear("Leer el cuaderno", Vector3(20.5, -2.8, 5.2), _avisar.bind(TEXTO_CUADERNO)))


# Primero el agua (lo que esta lista, luego lo que traes) y si no, sus lineas de siempre, que
# esquivan. Una de cada tantas recuerda como funciona la capilla
func _hablar_padre() -> String:
	var misiones := get_node("/root/Misiones")
	if misiones.capilla_listas > 0:
		var listas: int = misiones.capilla_listas
		misiones.capilla_listas = 0
		get_node("/root/Cartera").agua += listas
		return TEXTO_LISTA % listas
	var envases := _contar_envases()
	if envases > 0:
		var cabe: int = misiones.capilla_cupo - misiones.capilla_dejadas
		if cabe <= 0:
			return TEXTO_LLENO
		var deja := mini(envases, cabe)
		_quitar_envases(deja)
		misiones.capilla_dejadas += deja
		return TEXTO_TOMA if deja == 1 else TEXTO_TOMA_VARIAS
	if misiones.capilla_dejadas > 0:
		return TEXTO_MANANA
	var linea: String = LINEAS[_linea % LINEAS.size()]
	_linea += 1
	return TEXTO_TRAE if _linea % 3 == 0 else linea


# Por unidades (Inventory.unidades): las botellas no se apilan, y `cuantos` solo ve el primer lugar
func _contar_envases() -> int:
	var total := 0
	for item: InventoryItemData in get_node("/root/Inventory").unidades():
		if item.resource_path in ENVASES:
			total += 1
	return total


func _quitar_envases(cuantos: int) -> void:
	var inventario := get_node("/root/Inventory")
	while cuantos > 0:
		var i := -1
		for k in inventario.items.size():
			if inventario.items[k] and inventario.items[k].resource_path in ENVASES:
				i = k
				break
		if i < 0:
			return
		inventario.remove_item(i)
		cuantos -= 1


func _avisar(texto: String) -> void:
	_texto.text = texto
	var tween := create_tween()
	tween.tween_property(_texto, "modulate:a", 1.0, 0.25)
	tween.tween_interval(5.0)
	tween.tween_property(_texto, "modulate:a", 0.0, 0.6)
