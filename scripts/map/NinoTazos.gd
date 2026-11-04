class_name NinoTazos
extends Node3D

# El nino de los tazos: de dia, junto a los que dan misiones (MisionesMundo lo pone y lo quita
# de noche). Te cambia REPETIDOS_POR_CAMBIO repetidos de una rareza por uno que te falte de esa
# rareza (Tazos.cambiar), que sale con su show (TazoRevelacion) y, como es nuevo, da sus puntos.
# Si no alcanza, te dice cuantos repetidos llevas. Propuesta de AG.

const NPC := preload("res://scenes/npc.tscn")
const MODELO := "res://models/personajes/hombre_psx/hombre_psx.scn"
const ALTO := 1.2             # m: es nino
const LETRERO_ALTO := 1.95
const PLURALES := ["comunes", "raros", "holográficos"]

var _npc: Node3D


func _ready() -> void:
	_npc = NPC.instantiate() as Node3D
	var ninja := _npc.get_node("Model")
	_npc.remove_child(ninja)
	ninja.free()
	add_child(_npc)
	Gente.poner_modelo(_npc, load(MODELO), ALTO)
	_npc.set("al_hablar", _hablar)
	var letrero := Label3D.new()
	letrero.text = "Cambio tazos"
	letrero.font_size = 40
	letrero.pixel_size = 0.008
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.outline_size = 12
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.position.y = LETRERO_ALTO
	add_child(letrero)


# Para quitarlo de noche sin que se quede "adentro" el jugador
func soltar() -> void:
	if _npc:
		_npc.set("_player_inside", false)


func _hablar() -> String:
	var tazos := get_node("/root/Tazos")
	var cual := -1
	for rareza in PLURALES.size():
		if tazos.puede_cambiar(rareza) and (cual < 0 or tazos.repetidos(rareza) > tazos.repetidos(cual)):
			cual = rareza
	if cual < 0:
		var llevas: Array[String] = []
		for rareza in PLURALES.size():
			llevas.append("%d %s" % [tazos.repetidos(rareza), PLURALES[rareza]])
		return "Tráeme %d repetidos de la misma rareza y te cambio uno que no tengas. Llevas %s." % [
			tazos.REPETIDOS_POR_CAMBIO, ", ".join(llevas)]
	var tazo: TazoData = tazos.cambiar(cual)
	_revelar(tazo)
	return "¡Trato! %d %s por este." % [tazos.REPETIDOS_POR_CAMBIO, PLURALES[cual]]


# El show encima del juego, en pausa mientras dura
func _revelar(tazo: TazoData) -> void:
	var arbol := get_tree()
	arbol.paused = true
	var show := TazoRevelacion.abrir(arbol.root, tazo, false, get_node("/root/Tazos").ultima_serie)
	await show.termino
	arbol.paused = false
