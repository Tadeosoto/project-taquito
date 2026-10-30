class_name Alumbrado
extends RefCounted

# Estado de cada poste de luz (MapAlumbrado.gd) y la noche. `noche` (0 dia, 1 noche)
# es un global shader uniform: lo mueve el ciclo dia/noche (Ciclo.gd; MapNocheDebug en
# locales_preview) con configurar_noche(). Cada lampara se prende cuando la noche pasa su
# `umbral`, asi no se prenden todas a la vez. El parpadeo usa el mismo hash entero
# que shaders/ps1_lampara.gdshader y el tiempo `alumbrado_tiempo` que pone
# MapAlumbrado, para que la cabeza, el halo y la luz real parpadeen juntos: si cambia
# parpadeo() aqui, cambiarlo alla.

const SODIO := Color(1.0, 0.6, 0.24)
const LED := Color(0.86, 0.92, 1.0)

static var _noche := 0.0


static func configurar_noche(valor: float) -> void:
	_noche = clampf(valor, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("noche", _noche)


static func noche() -> float:
	return _noche


# Que tan prendida esta una lampara con ese umbral (0..1)
static func encendida(umbral: float) -> float:
	return smoothstep(umbral, umbral + 0.05, _noche)


# Fraccion de postes apagados y que parpadean segun la zona (Deterioro.zona va de 0.2
# a 0.8): poco deteriorada 15 % y 15 %, media 20 % y 40 %, muy deteriorada 30 % y 50 %.
# Entre esos puntos se interpola. Siempre hay al menos tantas parpadeando como apagadas.
const ZONAS := [0.2, 0.5, 0.8]
const APAGADAS := [0.15, 0.2, 0.3]
const PARPADEAN := [0.15, 0.4, 0.5]


# Lo que le paso a un poste segun el deterioro de su zona: mas apagadas y mas que
# parpadean donde esta mas destruido; inclinados solo en zonas deterioradas, y
# algunas de las apagadas de las zonas muy deterioradas estan tiradas.
static func estado(semilla: int, zona: float, avenida: bool) -> Dictionary:
	# Un solo numero al azar reparte: apagada, parpadea o prendida
	var r := _h(semilla, 5)
	var apagadas := _por_zona(APAGADAS, zona)
	var apagada := r < apagadas
	var caido := apagada and zona > 0.55 and _h(semilla, 1) < (zona - 0.55) * 0.6
	var inclinado := not caido and zona > 0.35 and _h(semilla, 2) < (zona - 0.35) * 0.8
	return {
		"caido": caido,
		"inclinacion": deg_to_rad(3.0 + 9.0 * _h(semilla, 3)) if inclinado else 0.0,
		"inclinacion_eje": _h(semilla, 4) * TAU,
		"apagada": apagada,
		"parpadea": not apagada and r < apagadas + _por_zona(PARPADEAN, zona),
		"color": LED if _h(semilla, 7) < (0.4 if avenida else 0.2) else SODIO,
		"umbral": 0.35 + 0.3 * _h(semilla, 8),
	}


static func _por_zona(valores: Array, zona: float) -> float:
	if zona <= ZONAS[0]:
		return valores[0]
	for i in range(1, ZONAS.size()):
		if zona <= ZONAS[i]:
			return lerpf(valores[i - 1], valores[i], (zona - ZONAS[i - 1]) / (ZONAS[i] - ZONAS[i - 1]))
	return valores[-1]


# Brillo de una lampara que parpadea en el tiempo t (s): ratos estable y ratos con
# apagones rapidos al azar
static func parpadeo(semilla: int, t: float) -> float:
	if _h(semilla + 101, floori(t / 1.5)) < 0.4:
		return 1.0
	var h := _h(semilla + 202, floori(t * 14.0))
	return 0.0 if h < 0.45 else (0.35 if h < 0.6 else 1.0)


static func _h(a: int, b: int) -> float:
	return Deterioro._hash(a, b)
