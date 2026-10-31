extends Node3D

# Otro jugador, visto desde esta computadora: va suave hacia lo ultimo que mando.

const SUAVIZADO := 14.0
# Mas lejos que esto no se suaviza: aparecio o se teletransporto
const SALTO := 8.0

var _destino := Vector3.ZERO
var _giro := 0.0
var _recibido := false

@onready var _cuerpo: Node3D = $Frijol
@onready var _ninja: Node3D = $Frijol/Ninja
@onready var _nombre: Label3D = $Nombre


func _ready() -> void:
	# No se ve hasta que mande donde esta
	visible = false


func poner_nombre(texto: String) -> void:
	_nombre.text = texto


func actualizar(posicion: Vector3, giro: float, moviendose: bool, en_aire: bool, corriendo: bool, se_ve: bool) -> void:
	if not _recibido or position.distance_to(posicion) > SALTO:
		position = posicion
	_recibido = true
	_destino = posicion
	_giro = giro
	visible = se_ve
	_ninja.update_animation(moviendose, en_aire, corriendo)


func _process(delta: float) -> void:
	var paso := clampf(SUAVIZADO * delta, 0.0, 1.0)
	position = position.lerp(_destino, paso)
	_cuerpo.rotation.y = lerp_angle(_cuerpo.rotation.y, _giro, paso)
