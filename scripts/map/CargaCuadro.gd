extends RefCounted

# Presupuesto de tiempo por cuadro compartido por los sistemas que arman el mapa
# alrededor del jugador (MapStreamer, MapCasas, MapArboles, MapAlumbrado,
# MapPuntos, MapPasto). Cada uno arma lo suyo poco a poco; si cada quien tuviera
# su propio presupuesto, al volar coincidian todos en el mismo cuadro (40-60 ms).
# Uso: `while CargaCuadro.hay(): ...arma una pieza...; CargaCuadro.gastar(inicio)`.
# El primero que pide en un cuadro siempre puede armar al menos una pieza.

const PRESUPUESTO_US := 3000
# A pie la niebla casi lo tapa todo a 150-200 m (fog_density 0.0196: se ve el 5 % a 150 m,
# el 2 % a 200 m), asi que no se carga mas; el dron ve mas lejos y usa los radios largos de
# cada sistema. Lo pone MapDron. Se midio con tools/medir_mapa.tscn.
const CARGA_A_PIE := 200.0
const DESCARGA_A_PIE := 260.0

static var volando := false
static var _cuadro := -1
static var _usado := 0


static func carga(largo: float, a_pie := CARGA_A_PIE) -> float:
	return largo if volando else minf(largo, a_pie)


static func descarga(largo: float, a_pie := DESCARGA_A_PIE) -> float:
	return largo if volando else minf(largo, a_pie)


static func hay() -> bool:
	var cuadro := Engine.get_process_frames()
	if cuadro != _cuadro:
		_cuadro = cuadro
		_usado = 0
	return _usado < PRESUPUESTO_US


# `inicio` = Time.get_ticks_usec() de antes de armar la pieza
static func gastar(inicio: int) -> void:
	_usado += Time.get_ticks_usec() - inicio
