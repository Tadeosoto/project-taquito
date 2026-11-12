class_name PasoMision
extends Resource

# Un paso de una mision (MisionData.gd). Se escribe en el .tres de la mision, sin programar.
# TENER_OBJETOS: traer `objetos` en el inventario; `lugar` dice donde conseguirlos.
# ENTREGAR: volver con el que dio la mision; si hay `objetos`, se los queda.
# VISITAR: pasar por `cuantos` lugares (`lugar`), en `segundos` si no es 0.
# RECOGER: buscar la cosa `lugar` en un area y levantarla con Espacio: "perro", o
# "marca:<nombre>" (una marca "mision" de la colonia: ahi esta la cosa, con flecha; `objetos`[0]
# da su modelo y su nombre, o una pelota si no hay).
# ESCOLTAR: alguien (`acompanante`, un civil de Civiles.gd; vacio, uno al azar) sale de donde el
# que dio la mision y te sigue, mas lento que tu, hasta `lugar` ("casas", "giro:<giro>" o
# "marca:<nombre>"). Los zombis lo atacan; si cae, o si se acaba la hora con el en camino,
# la mision falla.
# DEFENDER: aguantar `segundos` cerca de `lugar` ("casas", "giro:<giro>" o "marca:<nombre>"; a
# 20 m, fuera de ahi el tiempo no corre) mientras llegan turbas de `cuantos` zombis cada
# `ola_cada` s (Zombis.aparecer_turba). Si `acompanante` no esta vacio, ese alguien se queda en
# el lugar (quien sube la torre, quien baja el agua): los zombis lo atraen y, si cae, falla. Si
# la hora se acaba antes o te desmayas, tambien.
# LLEVAR_CARGA: lo de VISITAR (`lugar`, `cuantos` entregas) con la `carga` en brazos, y cada
# entrega paga `pesos_por_entrega`. Es de una hora: si se acaba con la carga encima (amanecer =
# los cuicos) o te desmayas, se pierde y la mision falla.

# `cuando`: a que hora se puede cumplir este paso. Fuera de su hora la mision espera (no falla
# y su tiempo no corre): una entrega de noche con un ENTREGAR de dia se acaba con el que te la
# dio a la mañana siguiente.

enum Tipo { TENER_OBJETOS, ENTREGAR, VISITAR, RECOGER, ESCOLTAR, LLEVAR_CARGA, DEFENDER }
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
# ESCOLTAR: quien te sigue, su vida (los zombis le pegan 3 por golpe) y que tan rapido camina
@export var acompanante := ""
@export var vida_acompanante := 60
# DEFENDER: cada cuantos segundos llega otra turba
@export var ola_cada := 14.0
# LLEVAR_CARGA: lo que paga cada entrega, aparte de los `pesos` de la mision
@export var pesos_por_entrega := 0
