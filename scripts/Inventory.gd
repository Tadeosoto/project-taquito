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
# Godmode de los tests: no se gasta lo que se usa y no hay tope de capacidad
static var infinito := false

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


# Como al empezar el juego (Partida.gd, el safehouse)
func reiniciar() -> void:
	items.clear()
	mochila = null
	_ready()
	inventory_changed.emit()


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


# Lo que mejor llena `falta` de vida: la curacion mas chica que la llene; si ninguna
# alcanza, la mas grande. -1 si no traes nada que cure (Player._curarse, tecla Q)
func mejor_curacion(falta: int) -> int:
	var mejor := -1
	for i in items.size():
		var item := items[i]
		if item.curacion <= 0:
			continue
		if mejor < 0:
			mejor = i
			continue
		var otra := items[mejor].curacion
		if item.curacion >= falta:
			if otra < falta or item.curacion < otra:
				mejor = i
		elif otra < falta and item.curacion > otra:
			mejor = i
	return mejor


func curaciones() -> int:
	var cuantas := 0
	for item in items:
		if item.curacion > 0:
			cuantas += 1
	return cuantas


# Se come el de `index` y regresa cuanta vida subio. Buen diente (Habilidades.gd) hace que
# la comida cure mas. Lo usan Utilizar (InventoryUI) y la tecla Q
func usar_curacion(index: int) -> int:
	var item := get_item(index)
	if item == null or item.curacion <= 0:
		return 0
	var salud := get_node("/root/Salud")
	var tazos := get_node_or_null("/root/Tazos")
	var mejoras := get_node_or_null("/root/Mejoras")
	var antes: int = salud.vida
	var factor: float = (tazos.factor_curacion() if tazos else 1.0) * (mejoras.factor_curacion() if mejoras and mejoras.activo else 1.0)
	salud.vida += roundi(item.curacion * factor)
	var curado: int = salud.vida - antes
	var registro = get_node_or_null("/root/Registro")
	if registro:
		registro.item(item.item_name, curado, antes, salud.vida_max)
	if not infinito:
		remove_item(index)
	return curado


# Godmode: todos los productos del catalogo, infinitos (el tope de `lleno` esta apagado)
func dar_todos_los_productos() -> void:
	for archivo in ResourceLoader.list_directory("res://resources/productos/"):
		if archivo.ends_with(".tres"):
			var item := load("res://resources/productos/" + archivo) as InventoryItemData
			if item:
				add_item(item)
	inventory_changed.emit()


# Lo que cabe: la mochila (o CAPACIDAD_BASE) mas los lugares de la habilidad Mochilero
func capacidad() -> int:
	var tazos := get_node_or_null("/root/Tazos")
	return capacidad_mochila() + (tazos.espacio_extra() if tazos else 0)


# Solo la mochila, para comparar mochilas
func capacidad_mochila() -> int:
	return mochila.capacidad if mochila else CAPACIDAD_BASE


# Si bajas Mochilero con todo lleno no se tira nada: solo no cabe nada nuevo hasta que hagas lugar
func esta_lleno() -> bool:
	return not infinito and items.size() >= capacidad()


# Una mochila solo sirve si es mas grande que la que traes; la vieja se tira.
func equipar_mochila(nueva: InventoryItemData) -> bool:
	if nueva == null or nueva.capacidad <= capacidad_mochila():
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
