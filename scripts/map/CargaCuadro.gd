extends RefCounted

# Presupuesto de tiempo por cuadro compartido por los sistemas que arman el mapa
# alrededor del jugador (MapStreamer, MapCasas, MapArboles, MapAlumbrado,
# MapPuntos, MapPasto). Cada uno arma lo suyo poco a poco; si cada quien tuviera
# su propio presupuesto, al volar coincidian todos en el mismo cuadro (40-60 ms).
# Uso: `while CargaCuadro.hay(): ...arma una pieza...; CargaCuadro.gastar(inicio)`.
# El primero que pide en un cuadro siempre puede armar al menos una pieza.

const PRESUPUESTO_US := 3000

static var _cuadro := -1
static var _usado := 0


static func hay() -> bool:
	var cuadro := Engine.get_process_frames()
	if cuadro != _cuadro:
		_cuadro = cuadro
		_usado = 0
	return _usado < PRESUPUESTO_US


# `inicio` = Time.get_ticks_usec() de antes de armar la pieza
static func gastar(inicio: int) -> void:
	_usado += Time.get_ticks_usec() - inicio
