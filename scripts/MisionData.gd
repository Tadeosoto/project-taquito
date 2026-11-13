class_name MisionData
extends Resource

# Una mision (docs/especificaciones.md 6.3): casi solo datos. Para agregar una, copiar un .tres
# de resources/misiones/ y agregarlo a Misiones.ARCHIVOS. Los dialogos caben en la burbuja si
# son de menos de unos 80 caracteres.

@export var id := ""
@export var nombre := ""
# Modelo del que la da: una carpeta de models/personajes/ con clip propio
@export var modelo := "psx_man"
# Los dadores importantes (Chava, el padre Chuy...): su inicial sale en el mapa de papel y en el
# minimapa mientras tienen trabajo para ti, como en RDR2. Vacio: el vecino de siempre, sin inicial
@export var inicial := ""
@export_multiline var oferta := ""
@export_multiline var aceptada := ""
@export_multiline var recuerda := ""
@export_multiline var gracias := ""
@export_multiline var despedida := ""
@export var pasos: Array[PasoMision] = []
@export var pesos := 0
@export var premios: Array[InventoryItemData] = []
# Un pedazo de mapa, el primero que falte; si ya estan todos, `pesos_si_sobra`
@export var pieza_de_mapa := false
@export var pesos_si_sobra := 0
# Donde se para el que la da: "marca:<nombre>" una marca "mision" de la colonia del mapa en
# Blender (Colonia.puntos_mision); vacio, o sin esa marca, junto a un poste como siempre
@export var donde := ""
# Una sola vez en toda la partida (la guardia de la reja, el tutorial de la primera horda): ya hecha, no se ofrece mas
@export var una_vez := false
# Solo se ofrece ya cumplida (para siempre) la mision con este id: las entregas de la mafia van en cadena
@export var requiere := ""
# Tambien ofrece de noche y no se va al oscurecer (los puntos de la mafia: el negocio no cierra)
@export var abierto_de_noche := false
# DADOR: te la da alguien de dia y queda en el diario. LUGAR: se acepta al acercarte a un sitio
# (la reja, el tinaco), no entra al diario y se juega en el momento (Misiones.empezar_en_lugar)
enum Inicio { DADOR, LUGAR }
@export var inicio: Inicio = Inicio.DADOR
