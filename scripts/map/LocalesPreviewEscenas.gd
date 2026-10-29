extends Node

# En scenes/locales_preview.tscn hace de nodo Interiores (sin jugador ni entrada):
# solo carga las escenas de interior por giro para que MapPuntos las meta en los locales
@export var escenas: Dictionary[String, PackedScene] = {}
