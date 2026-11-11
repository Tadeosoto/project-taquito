class_name ConfigZombis
extends Resource

# Los mandos de diseno de los enemigos, en un solo lugar. Lo usan Zombis/Zombie en los dos
# tests y en el mapa; el log guarda una copia efectiva para comparar corridas A/B.
# Los valores por omision son los que ya tenia Zombie.gd.

@export var vida := 30
@export var dano := 12
@export var velocidad := Vector2(3.0, 5.0)
@export var ataque_dura := 1.5
@export var ataque_alcance := 1.5
@export var cazador_velocidad := 1.4
@export var corre_desde := 5.5
@export var gordo_vida := 30
@export var gordo_dano := 12
@export var gordo_velocidad := Vector2(3.0, 5.0)
@export var jefe_vida := 400
@export var jefe_dano := 25
@export var jefe_velocidad := 3.0


func texto() -> String:
	return "vida %d · daño %d · ataque %.1f s · velocidad %.1f-%.1f" % [vida, dano, ataque_dura, velocidad.x, velocidad.y]
