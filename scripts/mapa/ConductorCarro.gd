class_name ConductorCarro
extends Node

# Maneja un vehiculo (cualquier Node3D con su frente en +Z) por una ruta de CallesRuta como lo
# haria un carro: arranca acelerando, frena un poco antes de las curvas, el rumbo se corrige
# poco a poco (nunca gira de golpe) y nunca va de lado. Mueve el nodo, no usa fisica: sirve para
# el vehiculo de adorno de la defensa y para la camioneta de las misiones de reparto y escolta.
#
#   var c := ConductorCarro.new()
#   add_child(c)
#   c.llego.connect(...)
#   c.iniciar(camioneta, ruta)        # la ruta de CallesRuta.entre o CallesRuta.seguir
#
# `vel_max` m/s, `aceleracion` y `frenado` m/s2. Con `parar_al_final` frena para detenerse en el
# ultimo punto; si no, lo cruza a toda velocidad. `llego` se emite al terminar la ruta.
# `pausa` detiene el vehiculo (frenando) sin tirar la ruta: escolta que espera al jugador.

signal llego

@export var vel_max := 9.0
@export var aceleracion := 2.5
@export var frenado := 6.0
@export var parar_al_final := false

const ADELANTE_RUMBO := 2.0        # m al frente a donde mira para tomar el rumbo (suaviza el cuadro a cuadro)
const GIRO_SUAVE := 7.0            # 1/s: que tan rapido el rumbo alcanza al de la ruta
const CURVA_MIRA := 14.0           # m al frente a donde busca curvas para frenar
const CURVA_LENTO := 0.45          # fraccion de vel_max en una esquina de 90 grados o mas
const CURVA_GRADOS := 90.0

var pausa := false
var velocidad := 0.0               # m/s
var recorrido := 0.0               # m desde el inicio de la ruta

var _nodo: Node3D
var _ruta := PackedVector3Array()
var _acumulado: Array[float] = []   # m desde el inicio hasta cada punto
var _total := 0.0
var _activo := false


func iniciar(nodo: Node3D, ruta: PackedVector3Array, desde_cero := true) -> void:
	_nodo = nodo
	_ruta = ruta
	_acumulado = [0.0]
	for i in range(1, ruta.size()):
		_acumulado.append(_acumulado[i - 1] + ruta[i].distance_to(ruta[i - 1]))
	_total = _acumulado[_acumulado.size() - 1] if ruta.size() > 1 else 0.0
	recorrido = 0.0
	if desde_cero:
		velocidad = 0.0
	_activo = ruta.size() > 1
	if _activo:
		_poner(0.0, true)


func _process(delta: float) -> void:
	if not _activo or not is_instance_valid(_nodo):
		return
	var objetivo := 0.0 if pausa else vel_max * _factor_curva()
	if parar_al_final:
		# Frena para llegar justo al final: v^2 = 2 * frenado * distancia que falta
		objetivo = minf(objetivo, sqrt(2.0 * frenado * maxf(_total - recorrido, 0.0)) + 0.5)
	if velocidad < objetivo:
		velocidad = minf(velocidad + aceleracion * delta, objetivo)
	else:
		velocidad = maxf(velocidad - frenado * delta, objetivo)
	recorrido = minf(recorrido + velocidad * delta, _total)
	_poner(recorrido, false, delta)
	if recorrido >= _total - 0.01:
		_activo = false
		llego.emit()


# 1 en recta y hasta CURVA_LENTO si adelante hay una esquina cerrada
func _factor_curva() -> float:
	var ahora := _rumbo(recorrido)
	var adelante := _rumbo(minf(recorrido + CURVA_MIRA, _total))
	var giro := rad_to_deg(absf(angle_difference(atan2(ahora.x, ahora.z), atan2(adelante.x, adelante.z))))
	return lerpf(1.0, CURVA_LENTO, clampf(giro / CURVA_GRADOS, 0.0, 1.0))


# El punto de la ruta a `metros` del inicio
func _punto(metros: float) -> Vector3:
	var i := 1
	while i < _acumulado.size() - 1 and _acumulado[i] < metros:
		i += 1
	var tramo := _acumulado[i] - _acumulado[i - 1]
	var t := 0.0 if tramo <= 0.0 else clampf((metros - _acumulado[i - 1]) / tramo, 0.0, 1.0)
	return _ruta[i - 1].lerp(_ruta[i], t)


# Hacia donde apunta la ruta a `metros` del inicio
func _rumbo(metros: float) -> Vector3:
	var a := _punto(maxf(metros - 0.01, 0.0))
	var b := _punto(minf(metros + 0.01 + ADELANTE_RUMBO, _total))
	var rumbo := b - a
	rumbo.y = 0.0
	return rumbo.normalized() if rumbo.length() > 0.001 else Vector3.FORWARD


func _poner(metros: float, de_golpe: bool, delta := 0.0) -> void:
	_nodo.global_position = _punto(metros)
	var rumbo := _rumbo(metros)
	var yaw := atan2(rumbo.x, rumbo.z)   # su frente esta en +Z
	_nodo.rotation.y = yaw if de_golpe else lerp_angle(_nodo.rotation.y, yaw, minf(GIRO_SUAVE * delta, 1.0))
