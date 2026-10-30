class_name RecetaData

extends Resource

# Una receta de "Combinar" en el inventario (docs/especificaciones.md 4.5): `a` + `b`,
# en cualquier orden, se gastan y dan `resultado`. Se registran en Inventory.RECETAS.

@export var a : InventoryItemData

@export var b : InventoryItemData

@export var resultado : InventoryItemData


func usa(uno: InventoryItemData, otro: InventoryItemData) -> bool:
	return (uno == a and otro == b) or (uno == b and otro == a)
