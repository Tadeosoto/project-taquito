@tool
class_name PuntoMapa
extends Node3D

# El edificio de El Punto en el mundo: la Cantina El Olvido de dos pisos (models/negocios/punto/
# punto_fuera.glb, de tools/blender/negocios/punto.py), con el anexo del mural al oeste, el lote
# enrejado con un carro viejo al este y sillas de plastico y motos en la banqueta. MapPuntos lo
# pone en cada punto (tipo "punto"); la flecha la sigue poniendo MapPuntos frente a la puerta
# (PUERTA_X) y el interior es scenes/interiores/punto.tscn.
#
# El origen es el centro de la fachada de la cantina, +Z a la calle. La cantina mide CANTINA_ANCHO;
# en un lote mas angosto todo se encoge (hasta ESCALA_MIN), y el anexo y el lote solo se quedan si
# el terreno alcanza (`ancho` del lote; con 0 se quedan, como en el safehouse).

const MODELO := preload("res://models/negocios/punto/punto_fuera.glb")
const CANTINA_ANCHO := 6.0
const ANEXO_ANCHO := 6.0          # cada ala (el anexo al oeste, el lote al este)
const ESCALA_MIN := 0.75
const PUERTA_X := 1.7             # x de la puerta de la cantina (punto.py PUERTA)
const LEJOS := 160.0              # m hasta donde se dibuja

@export var ancho := 0.0          # del lote; 0 = sin limite
@export var con_banqueta := true


func _ready() -> void:
	var edificio := MODELO.instantiate() as Node3D
	edificio.name = "Edificio"
	add_child(edificio)
	var esc := escala(ancho)
	edificio.scale = Vector3.ONE * esc
	var alas := ancho <= 0.0 or ancho >= (CANTINA_ANCHO + 2.0 * ANEXO_ANCHO) * esc
	for nodo in edificio.find_children("*", "", true, false):
		var n := String(nodo.name)
		if (not alas and (n.begins_with("Anexo_") or n.begins_with("Lote_"))) or (not con_banqueta and n.begins_with("Banqueta_")):
			nodo.queue_free()
	for malla in edificio.find_children("*", "GeometryInstance3D", true, false):
		(malla as GeometryInstance3D).visibility_range_end = LEJOS


# Que tanto se encoge el edificio en un lote de `ancho` m (0: nada)
static func escala(ancho_lote: float) -> float:
	if ancho_lote <= 0.0:
		return 1.0
	return clampf(ancho_lote / CANTINA_ANCHO, ESCALA_MIN, 1.0)
