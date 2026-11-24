class_name HitoNoche
extends Resource

# Un hito de la noche sin fin (docs/especificaciones.md 1.2): a partir de la noche `noche`
# pasa algo y, la primera vez que llegas, te da un tazo holografico. La tabla es
# resources/noches/hitos.tres (TablaHitos.gd); la lee el autoload Noches.

enum Tipo { GARRAFONERO, SALTABARDAS_SEGUIDO, PANZON_EN_TURBAS, MADRE_CARCAMO, MOJIGANGA }

@export var noche := 1
@export var tipo: Tipo = Tipo.GARRAFONERO
## id del tazo de premio (resources/tazos/); vacio = un holografico que no tengas, al azar
@export var tazo_id := ""
## Lo que se avisa al anochecer de esa noche
@export var texto := ""
