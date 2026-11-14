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
## Densidad de niebla de noche. Negativo = la misma del dia. Una colonia cerrada y con niebla
## espesa (la favela de La Gotera) la baja de noche para no quedarse a oscuras (MapaColonia._ambiente)
@export var niebla_densidad := -1.0

var retener_noche := false
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
		_dia["niebla_densidad"] = _env.fog_density
	_tiempo = inicio
	# Si se llego por la reja de Santa Mugre (PasoColonia) sigue la hora de la escena de la que se vino
	var traida := PasoColonia.tomar_hora()
	if traida >= 0.0:
		_tiempo = traida * (dia_duracion + noche_duracion)
	_aplicar(valor())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		saltar()


# Hasta la siguiente orilla: al amanecer si es de noche, al anochecer si es de dia. La N cae al
# principio de la transicion (se ve oscurecer); con `entero` (la cama de la casa del jugador,
# MueblesCasa.gd) cae ya del otro lado: despiertas de dia o de noche cerrada
func saltar(entero := false) -> void:
	_tiempo = dia_duracion + noche_duracion - transicion if _es_noche else dia_duracion - transicion
	if entero:
		_tiempo = fmod(_tiempo + transicion, dia_duracion + noche_duracion)


func _process(delta: float) -> void:
	_tiempo = fmod(_tiempo + delta, dia_duracion + noche_duracion)
	# La ultima noche no amanece hasta matar al jefe; esto tambien le gana a la N
	if retener_noche:
		_tiempo = minf(_tiempo, dia_duracion + noche_duracion - transicion - 1.0)
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


# `de_golpe`: ya de dia, sin aclarar poco a poco (la defensa del tinaco al romperse)
func amanecer_ya(de_golpe := false) -> void:
	retener_noche = false
	_tiempo = 0.0 if de_golpe else dia_duracion + noche_duracion - transicion


# Vuelve al principio de la noche (22:00, `_tiempo = dia_duracion`, que ya vale 1 en
# `valor()`), para empezar otra noche sin recargar la escena: la defensa del tinaco encadena
# noches. La luz cambia de golpe; el que llama lo tapa con un fundido.
# No emite nada aqui: en el primer _process, `valor()` ya es de noche y `_es_noche` se dejo en
# false, asi que emite `anochecio` una vez (Zombis reinicia sus contadores y su Director).
# Se apaga `_es_noche` a mano a proposito: si se rearma desde media noche y se dejara true,
# no habria `anochecio`.
func reiniciar_noche() -> void:
	retener_noche = false
	_tiempo = dia_duracion
	_es_noche = false
	_avisado = false
	_valor = -1.0
	_aplicar(valor())


# La hora del reloj (0-24): corre parejo todo el ciclo, asi que con menos noche que dia
# oscurece tarde. Amanece (la mitad de la transicion, `amanecio`) a las HORA_AMANECER; con
# 8 min de dia y 6 de noche anochece a las 19:43.
const HORA_AMANECER := 6.0


func hora() -> float:
	var total := dia_duracion + noche_duracion
	return fmod(HORA_AMANECER + fmod(_tiempo + transicion / 2.0, total) / total * 24.0, 24.0)


static func texto_hora(h: float) -> String:
	var minutos := int(h * 60.0) % (24 * 60)
	return "%d:%02d" % [minutos / 60, minutos % 60]


# Segundos de juego que faltan para que amanezca (la hora de Hordas llega a las 6:00 a media
# transicion); 0 de dia
func segundos_para_amanecer() -> float:
	if not _es_noche:
		return 0.0
	return maxf(dia_duracion + noche_duracion - transicion / 2.0 - _tiempo, 0.0)


# Segundos desde que empezo el dia (de 0 a dia_duracion + noche_duracion)
func tiempo() -> float:
	return _tiempo


func es_noche() -> bool:
	return _es_noche


# Que tan cerrados estan los negocios (las cortinas de MapPuntos): 0 abiertos, 1 cerrados.
# Bajan en CORTINA_BAJA s y llegan al piso justo al anochecer (cuando Interiores te saca y ya
# dice "cerrado"); al amanecer suben en lo mismo.
const CORTINA_BAJA := 8.0


func cierre_negocios() -> float:
	var anochece := dia_duracion - transicion / 2.0
	var amanece := dia_duracion + noche_duracion - transicion / 2.0
	if _tiempo < anochece:
		return clampf(1.0 - (anochece - _tiempo) / CORTINA_BAJA, 0.0, 1.0)
	if _tiempo < amanece:
		return 1.0
	return clampf(1.0 - (_tiempo - amanece) / CORTINA_BAJA, 0.0, 1.0)


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
		if niebla_densidad >= 0.0:
			_env.fog_density = lerpf(_dia["niebla_densidad"], niebla_densidad, _valor)
		# Con cielo de shader (shaders/cielo_ps1.gdshader, el mapa de Blender) el fondo no es un
		# color: se le pasa la hora y el color de la niebla, que es el de su horizonte
		var cielo := (_env.sky.sky_material as ShaderMaterial) if _env.sky else null
		if cielo:
			cielo.set_shader_parameter("noche", _valor)
			cielo.set_shader_parameter("niebla", _env.fog_light_color)
