class_name Ciclo
extends Node

# El dia y la noche (docs/especificaciones.md 3.1): avanza solo, oscurece el sol, la luz
# ambiente, el fondo y la niebla, y mueve Alumbrado.configurar_noche() para prender las
# lamparas. Avisa antes de oscurecer. La tecla N salta al siguiente atardecer o amanecer,
# para probar. En coop el reloj lo lleva el servidor y este nodo solo lo sigue.

signal aviso_atardecer
signal anochecio
signal amanecio

@export var sol_path: NodePath
@export var environment_path: NodePath
@export var dia_duracion := 720.0
@export var noche_duracion := 480.0
# Lo que tarda en oscurecer o aclarar (va dentro del dia y de la noche)
@export var transicion := 30.0
@export var aviso_antes := 60.0
# Segundos de dia que ya pasaron al empezar la partida
@export var inicio := 60.0
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
var _tiempo := 0.0
var _valor := -1.0
var _es_noche := false
var _avisado := false


func _ready() -> void:
	add_to_group("ciclo")
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
	_tiempo = inicio
	_aplicar(valor())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		_tiempo = dia_duracion + noche_duracion - transicion if _es_noche else dia_duracion - transicion


func _process(delta: float) -> void:
	_tiempo = fmod(_tiempo + delta, dia_duracion + noche_duracion)
	_aplicar(valor())
	if not _es_noche and not _avisado and _tiempo >= dia_duracion - aviso_antes and _tiempo < dia_duracion:
		_avisado = true
		aviso_atardecer.emit()
	var ahora := _valor >= 0.5
	if ahora != _es_noche:
		_es_noche = ahora
		if ahora:
			anochecio.emit()
		else:
			_avisado = false
			amanecio.emit()


func es_noche() -> bool:
	return _es_noche


# 0 de dia, 1 de noche, y lo de en medio al oscurecer y al aclarar
func valor() -> float:
	if _tiempo < dia_duracion:
		return clampf((_tiempo - (dia_duracion - transicion)) / transicion, 0.0, 1.0)
	return 1.0 - clampf((_tiempo - (dia_duracion + noche_duracion - transicion)) / transicion, 0.0, 1.0)


func _aplicar(nuevo: float) -> void:
	if is_equal_approx(nuevo, _valor):
		return
	_valor = nuevo
	Alumbrado.configurar_noche(_valor)
	if _sol:
		_sol.light_energy = lerpf(_dia["sol"], sol_energia, _valor)
		_sol.light_color = _dia["sol_color"].lerp(sol_color, _valor)
	if _env:
		_env.ambient_light_color = _dia["ambiente_color"].lerp(ambiente_color, _valor)
		_env.ambient_light_energy = lerpf(_dia["ambiente_energia"], ambiente_energia, _valor)
		_env.fog_light_color = _dia["niebla"].lerp(niebla_color, _valor)
		_env.background_color = _dia["fondo"].lerp(fondo_color, _valor)
