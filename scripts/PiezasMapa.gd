extends Node

# Los pedazos del mapa de papel que ya encontraste (docs/especificaciones.md 4.9). Autoload
# `PiezasMapa`. No son objetos del inventario: no ocupan lugar y no se pierden al desmayarte.
# Duran lo que la partida.

signal cambio
signal recogida(zona: int)

var _zonas := {}


func tiene(zona: int) -> bool:
	return _zonas.has(zona)


func cuantas() -> int:
	return _zonas.size()


# Sin avisar: la del lugar donde empiezas
func dar(zona: int) -> void:
	if zona >= 0 and not _zonas.has(zona):
		_zonas[zona] = true
		cambio.emit()


func recoger(zona: int) -> void:
	if zona >= 0 and not _zonas.has(zona):
		dar(zona)
		recogida.emit(zona)


# La primera que falte; -1 si ya estan todas
func siguiente_faltante() -> int:
	for i in ZonasMapa.cuantas():
		if not tiene(i):
			return i
	return -1


func reiniciar() -> void:
	_zonas.clear()
	cambio.emit()
