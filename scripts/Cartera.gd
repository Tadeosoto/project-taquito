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


# Al cerrar el juego (los autoloads salen del arbol solo entonces): suelta lo que guardan los
# static var con objetos y los pedidos de carga en hilo sin recoger, para que Godot no los cuente
# como fuga ("ObjectDB instances were leaked at exit")
func _exit_tree() -> void:
	Tragamonedas.olvidar_placas()
	Civiles.soltar()
	# Las escenas plantilla de los puestos y props: Tianguis las suelta al irse el ultimo, pero los
	# props de una colonia sin tianguis (la favela) tambien las usan
	preload("res://scripts/map/TianguisPiezas.gd").vaciar()
