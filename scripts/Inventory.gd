extends Node

# Senal emitida siempre que el inventario cambia.
# UI escucha esta senal, actualiza en automatico.
signal inventory_changed

# Lista de items que el jugador tiene.
# Empieza limpia.
var items: Array[InventoryItemData] = []


# Nos dice cuantos items hay en inventario.
func get_item_count() -> int:
	return items.size()


func _ready() -> void:
	# Agrega los items a "Starting Items"
# === TEMPORARY TEST ITEMS ===
	# Replace the paths with the real paths of your item resources.
	# You can find the path by right-clicking the .tres file → Copy Path.
	
	var item1 = load("res://resources/agua_mala.tres") as InventoryItemData
	var item2 = load("res://resources/taco_pastor.tres") as InventoryItemData
	
	if item1:
		add_item(item1)
	if item2:
		add_item(item2)
	# ============================


# Nos dice los items en su posicion.
# Si el index ta mal, vale vrg el pedo.
func get_item(index: int) -> InventoryItemData:
	if index < 0 or index >= items.size():
		return null
	return items[index]


# Agrega nuevos items al final de la lista.
# Despues de agregar, llama a invetory_changed para actualizar.
func add_item(item: InventoryItemData) -> void:
	if item == null:
		return
	items.append(item)
	inventory_changed.emit()


# Remueve items al final de la lista.
# Despues de quitar, llama a invetory_changed para actualizar.
func remove_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	items.remove_at(index)
	inventory_changed.emit()
