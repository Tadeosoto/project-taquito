class_name PasoMision
extends Resource

# Un paso de una mision (MisionData.gd). Se escribe en el .tres de la mision, sin programar.
# TENER_OBJETOS: traer `objetos` en el inventario; `lugar` dice donde conseguirlos.
# ENTREGAR: volver con el que dio la mision; si hay `objetos`, se los queda.
# VISITAR: pasar por `cuantos` lugares (`lugar`), en `segundos` si no es 0.
# RECOGER: buscar la cosa `lugar` en un area y levantarla con Espacio: "perro", o
# "marca:<nombre>" (una marca "mision" de la colonia: ahi esta la cosa, con flecha; `objetos`[0]
# da su modelo y su nombre, o una pelota si no hay).

# `cuando`: a que hora se puede cumplir este paso. Fuera de su hora la mision espera (no falla
# y su tiempo no corre): una entrega de noche con un ENTREGAR de dia se acaba con el que te la
# dio a la mañana siguiente.

enum Tipo { TENER_OBJETOS, ENTREGAR, VISITAR, RECOGER }
enum Cuando { DIA, NOCHE, CUALQUIERA }

@export var tipo: Tipo = Tipo.ENTREGAR
@export var cuando: Cuando = Cuando.DIA
# Lo que se lee en pantalla mientras dura este paso
@export var texto := ""
@export var objetos: Array[InventoryItemData] = []
# "giro:farmacia" la tienda mas cercana de ese giro, "casas" casas cerca, "perro" el perro.
# Los resuelve scripts/map/MisionesMundo.gd
@export var lugar := ""
@export var cuantos := 1
@export var segundos := 0.0
# Lo que trae en las manos durante este paso
@export var carga: InventoryItemData
