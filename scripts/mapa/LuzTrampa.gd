class_name LuzTrampa
extends Node3D

# Un lugar iluminado que de noche atrae a los zombis (marca "trampa" de Colonia.gd; la cancha
# de Santa Mugre, decision de AG): si el jugador esta adentro del rectangulo `tam` con los
# reflectores prendidos, cada CADA s hace Zombie.ruido en un radio de RADIO m, como un balazo.
# La cancha tiene una sola reja: se puede aguantar ahi o quedarse acorralado.

const CADA := 6.0
const NOCHE_DESDE := 0.6          # Ciclo.valor() desde el que estan prendidos los reflectores

var tam := Vector2(12.0, 19.0)
var radio := 35.0

var _ciclo: Node
var _jugador: Node3D
var _espera := 0.0


func _process(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = CADA
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	if _ciclo == null or _jugador == null or float(_ciclo.valor()) < NOCHE_DESDE:
		return
	if adentro(_jugador.global_position):
		Zombie.ruido(global_position, radio)


func adentro(punto: Vector3) -> bool:
	var local := to_local(punto)
	return absf(local.x) <= tam.x / 2 and absf(local.z) <= tam.y / 2
