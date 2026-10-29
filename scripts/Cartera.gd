extends Node

# Dinero del jugador (docs/especificaciones.md 4.5): pesos para las tiendas normales y
# agua limpia, la moneda fuerte. Autoload `Cartera`.

signal cambio

# Saldo de prueba mientras no hay misiones ni maquinas que den dinero
var pesos := 120:
	set(valor):
		pesos = valor
		cambio.emit()
var agua := 3:
	set(valor):
		agua = valor
		cambio.emit()
