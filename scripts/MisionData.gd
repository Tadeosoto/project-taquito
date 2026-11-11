class_name MisionData
extends Resource

# Una mision (docs/especificaciones.md 6.3): casi solo datos. Para agregar una, copiar un .tres
# de resources/misiones/ y agregarlo a Misiones.ARCHIVOS. Los dialogos caben en la burbuja si
# son de menos de unos 80 caracteres.

@export var id := ""
@export var nombre := ""
# Modelo del que la da: una carpeta de models/personajes/ con clip propio
@export var modelo := "psx_man"
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
