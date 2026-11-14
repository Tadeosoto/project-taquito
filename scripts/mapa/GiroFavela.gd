extends Node
## El "timon" del laberinto de La Gotera: mientras el jugador esta en la favela y en el piso del
## callejon (no en una azotea), Player.giro_con_wasd hace que W + A/D gire la camara. En las
## azoteas (y tablones) se apaga y la camara se gira con el raton; en el tianguis y demas colonias
## tambien queda apagado. El umbral sale de la geometria: el origen del jugador va 1 m sobre el
## piso, las terrazas llegan a 1.5 + 1 = 2.5 y la azotea de un piso a 3.2 + 1 = 4.2.

@export var player_path: NodePath
const AZOTEA_Y := 3.2

var _jugador: Player
var _en_azotea := false


func _ready() -> void:
	_jugador = get_node(player_path) as Player


func _physics_process(_delta: float) -> void:
	if _jugador == null or not _jugador.is_physics_processing():
		return
	# Solo se decide en el piso: en un salto se conserva el modo para no cambiar a media caida.
	if _jugador.is_on_floor():
		_en_azotea = _jugador.global_position.y > AZOTEA_Y
	_jugador.giro_con_wasd = MapaColonia.actual == "la_gotera_favela" and not _en_azotea
