class_name Hordas
extends Node

# Las hordas de la defensa del tinaco (docs/misiones.md §0): a ciertas horas de la noche
# sale un grupo desde la orilla de la escena, de un lado al azar, y corre hacia el tinaco
# (Zombie._destino). Los sueltos y las turbas del Director estan apagados ahi
# (Zombis.espontaneos). La hora va de 22:00 a 6:00 repartida en la noche de Ciclo.

const HORA_EMPIEZA := 22.0
const HORAS := 8.0
const LADOS := ["norte", "oriente", "sur", "poniente"]   # 0 = norte (-Z), horario
# [hora (24 = medianoche), cuantos, corredores, de cuantos lados]. Nada en la ultima
# media hora: lo que quede se cae al amanecer
const OLEADAS := [
	[22.0, 5, false, 1],
	[22.75, 7, false, 1],
	[23.5, 9, false, 1],
	[24.0, 20, false, 2],    # la grande, de medianoche
	[25.0, 10, false, 1],
	[25.75, 12, false, 1],
	[26.5, 12, false, 2],
	[27.0, 14, true, 1],     # los corredores de las 3
	[27.75, 14, false, 2],
	[28.5, 16, true, 2],
	[29.25, 18, false, 2],
]
const DISTANCIA := Vector2(41.0, 46.0)  # m del centro donde salen (el campo de flujo cubre 47)
const ABRE := 0.5          # rad de ancho de cada lado
const CADA := 0.2          # s entre uno y otro
const SEPARADO := 1.2      # m entre zombis al salir
const ALTO_CALLE := 0.6    # m sobre el centro: mas alto es una azotea
const INTENTOS := 6

var centro := Vector3.ZERO
var zombis: Zombis
var ciclo: Ciclo
var supervivencia: Node
var siguiente := 0          # la oleada que sigue

var _pendientes: Array = []   # [angulo, corredor]
var _espera := 0.0


# 22.0 a 30.0: llega a las 6 justo al amanecer (Ciclo.amanecio, a media transicion)
func hora() -> float:
	var t := ciclo.tiempo() - ciclo.dia_duracion
	if t < 0.0:
		return HORA_EMPIEZA + HORAS
	return HORA_EMPIEZA + HORAS * clampf(t / (ciclo.noche_duracion - ciclo.transicion / 2.0), 0.0, 1.0)


static func texto_hora(h: float) -> String:
	var minutos := int(h * 60.0) % (24 * 60)
	return "%d:%02d" % [minutos / 60, minutos % 60]


func reiniciar() -> void:
	siguiente = 0
	_pendientes.clear()


func _physics_process(delta: float) -> void:
	if ciclo == null or not ciclo.es_noche():
		return
	while siguiente < OLEADAS.size() and hora() >= OLEADAS[siguiente][0]:
		_soltar(OLEADAS[siguiente])
		siguiente += 1
	if _pendientes.is_empty():
		return
	_espera -= delta
	if _espera > 0.0 or _vivos() >= Zombis.MAX_TOTAL:
		return
	_espera = CADA
	var uno: Array = _pendientes[0]
	var lugar := _lugar(uno[0])
	if lugar == Vector3.INF:
		# Ese lado esta tapado (casas): que salga de otro
		uno[0] = randf() * TAU
		return
	_pendientes.pop_front()
	zombis.sacar(lugar, uno[1])


func _soltar(oleada: Array) -> void:
	var lados: int = oleada[3]
	var primero := randf() * TAU
	var nombres: Array[String] = []
	for l in lados:
		var angulo := primero + l * TAU / lados + randf_range(-0.3, 0.3)
		nombres.append(LADOS[posmod(roundi(angulo / (PI / 2.0)), 4)])
		for i in int(oleada[1]) / lados:
			_pendientes.append([angulo, oleada[2]])
	if supervivencia:
		var donde := nombres[0] if nombres[0] == nombres[-1] else "%s y el %s" % [nombres[0], nombres[-1]]
		supervivencia.avisar(("¡Corredores por el %s!" if oleada[2] else "¡Ahí vienen por el %s!") % donde)


# En el suelo, a DISTANCIA del centro de ese lado; INF si no hubo lugar
func _lugar(angulo: float) -> Vector3:
	var espacio := zombis.get_world_3d().direct_space_state
	for i in INTENTOS:
		var a := angulo + randf_range(-ABRE, ABRE)
		var punto := centro + Vector3(sin(a), 0.0, -cos(a)) * randf_range(DISTANCIA.x, DISTANCIA.y)
		if _encima_de_otro(punto):
			continue
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, centro.y + 30.0, punto.z), Vector3(punto.x, centro.y - 2.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and pego.position.y < centro.y + ALTO_CALLE:
			return pego.position + Vector3.UP * 0.05
	return Vector3.INF


func _encima_de_otro(punto: Vector3) -> bool:
	for z in Zombie.activos:
		if Vector2(z.global_position.x - punto.x, z.global_position.z - punto.z).length_squared() < SEPARADO * SEPARADO:
			return true
	return false


func _vivos() -> int:
	var cuantos := 0
	for z in Zombie.activos:
		if z.estado != Zombie.Estado.MUERTO:
			cuantos += 1
	return cuantos
