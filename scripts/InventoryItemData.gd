class_name InventoryItemData

extends Resource

@export var item_name : String

@export_multiline var description : String

@export var icon : Texture2D

@export var inspection_model : PackedScene

# Lo que hace al usarlo (se ve en la tienda, debajo del nombre)
@export_multiline var efecto : String

# Precio en las tiendas (docs/especificaciones.md 4.5): en pesos o en agua limpia
@export var precio : int = 0

@export_enum("Pesos", "Agua") var moneda : int = 0
