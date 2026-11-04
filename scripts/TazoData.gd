class_name TazoData
extends Resource

# Un tazo de las bolsas especiales de Takis (Tazos.gd). Da puntos de habilidad y algunos
# desbloquean una habilidad (Habilidades.gd). Uno por .tres en resources/tazos/, escritos por
# tools/tazos/caras.gd; Tazos.gd lista la carpeta, asi que uno nuevo sale solo en las bolsas.
# Vienen en series de 12 (6 comunes, 4 raros, 2 holo), como un album.

enum Rareza { COMUN, RARO, HOLO }
const RAREZAS := ["Común", "Raro", "Holográfico"]
const COLORES_RAREZA := [Color(0.75, 0.75, 0.72), Color(0.35, 0.65, 1.0), Color(1.0, 0.85, 0.1)]
const SERIES := ["La colonia", "La noche", "Los vecinos", "GelA"]
const TEXTO_PUNTOS := ["1 punto por cada 3 nuevos", "1 punto", "2 puntos"]


static func texto_puntos(rareza: int) -> String:
	return TEXTO_PUNTOS[rareza]

@export var id := ""
@export var nombre := ""
@export var numero := 0
## Indice en SERIES
@export var serie := 0
@export var rareza: Rareza = Rareza.COMUN
## Puntos que da nuevo; los comunes dan 0 aqui y uno por cada Tazos.COMUNES_POR_PUNTO
@export var puntos := 1
## id de la habilidad que desbloquea (Habilidades.LISTA), o vacio
@export var desbloquea := ""
@export var cara: Texture2D
## La cara en sombra, para el album cuando no lo tienes
@export var silueta: Texture2D
