extends Node

# Vida del jugador (docs/especificaciones.md 4.3). Autoload `Salud`. La cura el inventario
# y la quitan los zombis; al llegar a 0 te desmayas (Supervivencia.gd).

signal cambio

var vida_max := 100
var vida := 100:
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
