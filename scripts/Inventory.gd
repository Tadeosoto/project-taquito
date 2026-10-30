extends Node

# Senal emitida siempre que el inventario cambia.
# UI escucha esta senal, actualiza en automatico.
signal inventory_changed

# Lo que se puede hacer con "Combinar" (docs/especificaciones.md 4.5)
const RECETAS := [preload("res://resources/recetas/machete_reforzado.tres")]

# Cuantos objetos caben sin mochila (docs/especificaciones.md 4.4)
const CAPACIDAD_BASE := 6

# La mochila que traes puesta; no ocupa lugar. null = sin mochila
var mochila: InventoryItemData = null

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
	# Pa probar Combinar
	var item3 = load("res://resources/productos/machete.tres") as InventoryItemData
	var item4 = load("res://resources/productos/cinta.tres") as InventoryItemData

	if item1:
		add_item(item1)
	if item2:
		add_item(item2)
	if item3:
		add_item(item3)
	if item4:
		add_item(item4)
	# ============================


# Nos dice los items en su posicion.
# Si el index ta mal, vale vrg el pedo.
func get_item(index: int) -> InventoryItemData:
	if index < 0 or index >= items.size():
		return null
	return items[index]


# La mejor arma que traes, o null. No hay que equiparla: se pelea con la mejor
func arma() -> InventoryItemData:
	var mejor: InventoryItemData = null
	for item in items:
		if item.dano > 0 and (mejor == null or item.dano > mejor.dano):
			mejor = item
	return mejor


func capacidad() -> int:
	return mochila.capacidad if mochila else CAPACIDAD_BASE


func esta_lleno() -> bool:
	return items.size() >= capacidad()


# Una mochila solo sirve si es mas grande que la que traes; la vieja se tira.
func equipar_mochila(nueva: InventoryItemData) -> bool:
	if nueva == null or nueva.capacidad <= capacidad():
		return false
	mochila = nueva
	inventory_changed.emit()
	return true


# Agrega nuevos items al final de la lista; regresa false si ya no caben.
# Despues de agregar, llama a invetory_changed para actualizar.
func add_item(item: InventoryItemData) -> bool:
	if item == null or esta_lleno():
		return false
	items.append(item)
	inventory_changed.emit()
	return true


# Remueve items al final de la lista.
# Despues de quitar, llama a invetory_changed para actualizar.
func remove_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	items.remove_at(index)
	inventory_changed.emit()


# Combina los items de dos posiciones. Si hay receta los gasta, agrega el resultado al
# final y lo regresa; si no, regresa null y no gasta nada.
func combinar(index_a: int, index_b: int) -> InventoryItemData:
	if index_a == index_b:
		return null
	var uno := get_item(index_a)
	var otro := get_item(index_b)
	if uno == null or otro == null:
		return null
	for receta: RecetaData in RECETAS:
		if receta.usa(uno, otro):
			items.remove_at(maxi(index_a, index_b))
			items.remove_at(mini(index_a, index_b))
			items.append(receta.resultado)
			inventory_changed.emit()
			return receta.resultado
	return null
