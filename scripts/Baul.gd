extends Node

# El baul de la casa del jugador (scripts/interiores/MueblesCasa.gd, BaulUI.gd): lo que guardas
# fuera del inventario. Se apila todo lo que sea el mismo objeto (sin el tope de MAX_PILA del
# inventario: es un baul) en hasta CAPACIDAD lugares. Es de la partida: Partida._otra_vez lo
# vacia con los demas autoloads (reiniciar) y no se guarda en disco.

signal cambio

const CAPACIDAD := 24

var items: Array[InventoryItemData] = []
var cantidades: Array[int] = []


func reiniciar() -> void:
	items.clear()
	cantidades.clear()
	cambio.emit()


func _lugar_de(item: InventoryItemData) -> int:
	for i in items.size():
		if items[i] == item or (item.resource_path != "" and items[i].resource_path == item.resource_path):
			return i
	return -1


func cabe(item: InventoryItemData) -> bool:
	return _lugar_de(item) >= 0 or items.size() < CAPACIDAD


func guardar(item: InventoryItemData) -> bool:
	if not cabe(item):
		return false
	var i := _lugar_de(item)
	if i >= 0:
		cantidades[i] += 1
	else:
		items.append(item)
		cantidades.append(1)
	cambio.emit()
	return true


# Saca uno del lugar `index` (vacio, se quita el lugar) y lo regresa
func sacar(index: int) -> InventoryItemData:
	if index < 0 or index >= items.size():
		return null
	var item := items[index]
	cantidades[index] -= 1
	if cantidades[index] <= 0:
		items.remove_at(index)
		cantidades.remove_at(index)
	cambio.emit()
	return item
