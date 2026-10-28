extends Node

# Noche de prueba mientras no hay ciclo dia/noche: la tecla N pasa de dia a noche
# (o al reves) en `duracion` s. Oscurece el sol, la luz ambiente, el fondo y la
# niebla, y mueve Alumbrado.configurar_noche() para prender las lamparas. El ciclo
# de verdad (docs/especificaciones.md §3.1) reemplaza este nodo.

@export var sol_path: NodePath
@export var environment_path: NodePath
@export var duracion := 2.0
@export_group("Noche")
@export var sol_energia := 0.35
# Luz de luna: azulada, para que sin alumbrado se siga viendo el juego
@export var sol_color := Color(0.55, 0.65, 0.9)
@export var ambiente_color := Color(0.42, 0.48, 0.66)
@export var ambiente_energia := 0.75
@export var niebla_color := Color(0.13, 0.15, 0.22)
@export var fondo_color := Color(0.09, 0.1, 0.16)

var _sol: DirectionalLight3D
var _env: Environment
var _dia := {}
var _valor := 0.0
var _meta := 0.0


func _ready() -> void:
	_sol = get_node_or_null(sol_path) as DirectionalLight3D
	var world := get_node_or_null(environment_path) as WorldEnvironment
	_env = world.environment if world else null
	if _sol:
		_dia["sol"] = _sol.light_energy
		_dia["sol_color"] = _sol.light_color
	if _env:
		_dia["ambiente_color"] = _env.ambient_light_color
		_dia["ambiente_energia"] = _env.ambient_light_energy
		_dia["niebla"] = _env.fog_light_color
		_dia["fondo"] = _env.background_color
	Alumbrado.configurar_noche(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		_meta = 1.0 - _meta


func _process(delta: float) -> void:
	if is_equal_approx(_valor, _meta):
		return
	_valor = move_toward(_valor, _meta, delta / maxf(duracion, 0.01))
	Alumbrado.configurar_noche(_valor)
	if _sol:
		_sol.light_energy = lerpf(_dia["sol"], sol_energia, _valor)
		_sol.light_color = _dia["sol_color"].lerp(sol_color, _valor)
	if _env:
		_env.ambient_light_color = _dia["ambiente_color"].lerp(ambiente_color, _valor)
		_env.ambient_light_energy = lerpf(_dia["ambiente_energia"], ambiente_energia, _valor)
		_env.fog_light_color = _dia["niebla"].lerp(niebla_color, _valor)
		_env.background_color = _dia["fondo"].lerp(fondo_color, _valor)
