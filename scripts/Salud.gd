extends Node

# Vida del jugador (docs/especificaciones.md 4.3). Autoload `Salud`. La cura el inventario
# y la quitan los zombis; al llegar a 0 te desmayas (Supervivencia.gd). La partida empieza con
# VIDA_INICIO de 100 (decision del equipo, 2026-11-23): hay que curarse antes de la primera noche.
# Las escenas de prueba (defensa del tinaco, Pruebas) empiezan llenas (`llenar`).

signal cambio

const VIDA_INICIO := 60

var vida_max := 100
var vida := VIDA_INICIO:
	set(valor):
		vida = clampi(valor, 0, vida_max)
		cambio.emit()


func reiniciar() -> void:
	vida = VIDA_INICIO


# Toda la vida (las escenas de prueba)
func llenar() -> void:
	vida = vida_max


func llena() -> bool:
	return vida >= vida_max


func estado() -> String:
	if vida > vida_max * 0.6:
		return "Bien"
	if vida > vida_max * 0.25:
		return "Herido"
	return "Grave"
