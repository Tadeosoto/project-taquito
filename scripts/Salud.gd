extends Node

# Vida del jugador (docs/especificaciones.md 4.3). Autoload `Salud`. Por ahora solo la
# cura el inventario; nada hace dano todavia.

signal cambio

var vida_max := 100
# Vida de prueba, abajo del maximo para que se note lo que cura un objeto
var vida := 60:
	set(valor):
		vida = clampi(valor, 0, vida_max)
		cambio.emit()


func llena() -> bool:
	return vida >= vida_max


func estado() -> String:
	if vida > vida_max * 0.6:
		return "Bien"
	if vida > vida_max * 0.25:
		return "Herido"
	return "Grave"
