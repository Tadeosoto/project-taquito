extends Node

# Senal emitida siempre que el inventario cambia.
# UI escucha esta senal, actualiza en automatico.
signal inventory_changed

# Lo que se puede hacer con "Combinar" (docs/especificaciones.md 4.5)
const RECETAS := [preload("res://resources/recetas/machete_reforzado.tres")]

# Cuantos objetos caben sin mochila (docs/especificaciones.md 4.4)
const CAPACIDAD_BASE := 6
# Lo que se gasta (comida, medicinas, bolsas de Takis, estampitas) se apila en un solo lugar,
# hasta MAX_PILA; ese es el maximo que puedes traer de cada uno (no abre otro lugar)
const MAX_PILA := 5

# La mochila que traes puesta; no ocupa lugar. null = sin mochila
var mochila: InventoryItemData = null

# El arma que elegiste con "Equipar" (sigue en `items`); null = la de mas dano
var equipada: InventoryItemData = null

# La cangurera puesta (no ocupa lugar): sin ella no puedes guardar tiliches (Tiliches.gd)
var cangurera: InventoryItemData = null

# Lista de items que el jugador tiene.
# Empieza limpia.
var items: Array[InventoryItemData] = []
# Cuantos hay en cada lugar de `items` (1 salvo en lo que se apila)
var cantidades: Array[int] = []


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
	cantidades.clear()
	mochila = null
	equipada = null
	cangurera = null
	_ready()
	inventory_changed.emit()


# Nos dice los items en su posicion.
# Si el index ta mal, vale vrg el pedo.
func get_item(index: int) -> InventoryItemData:
	if index < 0 or index >= items.size():
		return null
	return items[index]


# Cuantos hay en ese lugar
func cantidad(index: int) -> int:
	return cantidades[index] if index >= 0 and index < cantidades.size() else 0


# Cuantos traes de ese objeto, sumando su pila
func cuantos(item: InventoryItemData) -> int:
	var i := _lugar_de(item)
	return cantidades[i] if i >= 0 else 0


# Uno por unidad, con repetidos (para la bolsa al desmayarte y las misiones)
func unidades() -> Array[InventoryItemData]:
	var todas: Array[InventoryItemData] = []
	for i in items.size():
		for n in cantidades[i]:
			todas.append(items[i])
	return todas


# Saca todo (al desmayarte, el safehouse); la mochila y la cangurera se quedan
func vaciar() -> void:
	items.clear()
	cantidades.clear()
	equipada = null
	inventory_changed.emit()


# Si te cabe uno mas: en su pila si se apila y ya traes, si no en un lugar libre
func cabe(item: InventoryItemData) -> bool:
	if item == null:
		return false
	if item.cangurera:
		return cangurera == null
	var i := _lugar_de(item) if item.apilable() else -1
	if i >= 0:
		return cantidades[i] < MAX_PILA
	return not esta_lleno()


# La pila de ese objeto, o -1. Los .tres cargados son la misma instancia, pero por si acaso
# tambien cuenta el mismo archivo
func _lugar_de(item: InventoryItemData) -> int:
	for i in items.size():
		if items[i] == item or (item.resource_path != "" and items[i].resource_path == item.resource_path):
			return i
	return -1


func _quitar_lugar(index: int) -> void:
	items.remove_at(index)
	cantidades.remove_at(index)


# El arma con que peleas: la equipada ("Equipar" en el inventario) si la traes; si no, la de
# mas dano, como antes. null = a puño limpio
func arma() -> InventoryItemData:
	if equipada and items.has(equipada):
		return equipada
	var mejor: InventoryItemData = null
	for item in items:
		if item.dano > 0 and (mejor == null or item.dano > mejor.dano):
			mejor = item
	return mejor


# Lo que cabe: la mochila (o CAPACIDAD_BASE) mas los lugares de la habilidad Mochilero
func capacidad() -> int:
	var tazos := get_node_or_null("/root/Tazos")
	return capacidad_mochila() + (tazos.espacio_extra() if tazos else 0)


# Solo la mochila, para comparar mochilas
func capacidad_mochila() -> int:
	return mochila.capacidad if mochila else CAPACIDAD_BASE


# Si bajas Mochilero con todo lleno no se tira nada: solo no cabe nada nuevo hasta que hagas lugar
func esta_lleno() -> bool:
	return items.size() >= capacidad()


# Una mochila solo sirve si es mas grande que la que traes; la vieja se tira.
func equipar_mochila(nueva: InventoryItemData) -> bool:
	if nueva == null or nueva.capacidad <= capacidad_mochila():
		return false
	mochila = nueva
	inventory_changed.emit()
	return true


# Agrega uno: a su pila si se apila y ya traes, si no al final en un lugar nuevo. La cangurera
# se pone sola (de la mision o del piso). Regresa false si no cabe (cabe()).
# Despues de agregar, llama a invetory_changed para actualizar.
func add_item(item: InventoryItemData) -> bool:
	if not cabe(item):
		return false
	if item.cangurera:
		cangurera = item
	elif item.apilable() and _lugar_de(item) >= 0:
		cantidades[_lugar_de(item)] += 1
	else:
		items.append(item)
		cantidades.append(1)
	inventory_changed.emit()
	return true


# Quita uno del lugar `index` (de una pila quita solo uno; vacia, quita el lugar).
# Despues de quitar, llama a invetory_changed para actualizar.
func remove_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	if cantidades[index] > 1:
		cantidades[index] -= 1
	else:
		_quitar_lugar(index)
	if equipada and not items.has(equipada):
		equipada = null
	inventory_changed.emit()


# "Equipar" un arma: peleas con esa aunque tengas otra con mas dano. Otra vez la suelta
func equipar_arma(item: InventoryItemData) -> void:
	equipada = null if equipada == item else item
	inventory_changed.emit()


# "Ponerse" un amuleto (Bonos.gd): sale del inventario a uno de los dos lugares. Si estaban
# llenos, el mas viejo regresa al inventario (cabe: el nuevo dejo su lugar)
func poner_amuleto(index: int) -> void:
	var item := get_item(index)
	var bonos := get_node_or_null("/root/Bonos")
	if item == null or not item.es_amuleto() or bonos == null:
		return
	_quitar_lugar(index)
	var quitado: InventoryItemData = bonos.poner(item)
	if quitado:
		items.append(quitado)
		cantidades.append(1)
	inventory_changed.emit()


# Combina los items de dos posiciones. Si hay receta gasta uno de cada uno, agrega el
# resultado al final (aunque se pase de lo que cabe, como al quitarte un amuleto) y lo regresa;
# si no, regresa null y no gasta nada.
func combinar(index_a: int, index_b: int) -> InventoryItemData:
	if index_a == index_b:
		return null
	var uno := get_item(index_a)
	var otro := get_item(index_b)
	if uno == null or otro == null:
		return null
	for receta: RecetaData in RECETAS:
		if receta.usa(uno, otro):
			# El de atras primero: si se queda sin pila no recorre al otro
			_gastar_uno(maxi(index_a, index_b))
			_gastar_uno(mini(index_a, index_b))
			var i := _lugar_de(receta.resultado) if receta.resultado.apilable() else -1
			if i >= 0 and cantidades[i] < MAX_PILA:
				cantidades[i] += 1
			else:
				items.append(receta.resultado)
				cantidades.append(1)
			inventory_changed.emit()
			return receta.resultado
	return null


func _gastar_uno(index: int) -> void:
	if cantidades[index] > 1:
		cantidades[index] -= 1
	else:
		_quitar_lugar(index)
	if equipada and not items.has(equipada):
		equipada = null
