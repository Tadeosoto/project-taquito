extends Node
## Prueba de La Gotera sin restricciones: entra directo al tianguis (o a la favela) con las bocas
## abiertas aunque no se hayan hecho las entregas de la mafia (PasoColonia.sin_candados). Se puede
## ir y venir del tianguis a la favela por cualquier boca y salir a map_test por las rejas.
##   godot --path . scenes/prueba_gotera.tscn                  (en el tianguis)
##   godot --path . scenes/prueba_gotera.tscn -- --favela      (en la favela)
##   godot --path . scenes/prueba_gotera.tscn -- --noche       (de noche: tianguis y tiendas abiertos)

const MAPA_COLONIA := "res://scenes/mapa.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	PasoColonia.sin_candados = true
	PasoColonia.colonia = "la_gotera_favela" if "--favela" in args else "la_gotera"
	PasoColonia.lado = ""
	# Ciclo toma la hora de aqui al arrancar (la fraccion del dia; la noche empieza en su segunda parte)
	PasoColonia.fraccion_del_dia = 0.75 if "--noche" in args else 0.2
	get_tree().change_scene_to_file.call_deferred(MAPA_COLONIA)
