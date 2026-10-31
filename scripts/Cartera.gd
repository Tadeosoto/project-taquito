extends Node

# Dinero del jugador (docs/especificaciones.md 4.5): pesos para las tiendas normales y
# agua limpia, la moneda fuerte. Autoload `Cartera`.

signal cambio

# Saldo de prueba mientras no hay misiones que den dinero
const PESOS_INICIO := 120
const AGUA_INICIO := 3

var pesos := PESOS_INICIO:
	set(valor):
		pesos = valor
		cambio.emit()
var agua := AGUA_INICIO:
	set(valor):
		agua = valor
		cambio.emit()


func reiniciar() -> void:
	pesos = PESOS_INICIO
	agua = AGUA_INICIO
