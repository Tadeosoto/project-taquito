extends Node3D

# Entrada de la carrera: el refugio mini es el safehouse en modo carrera, con todas las
# tiendas fisicas y el punto de mejoras. El safehouse de desarrollo queda intacto: aqui se
# instancia con `modo_carrera = true` antes de agregarlo.

const CASA := preload("res://scenes/safehouse.tscn")


func _ready() -> void:
	var pruebas := get_node_or_null("/root/Pruebas")
	if pruebas == null:
		push_error("RefugioCarrera: falta el autoload Pruebas")
		return
	if not pruebas.es_carrera():
		pruebas.preparar_carrera(pruebas.dificultad, pruebas.duracion_noche)
	var casa := CASA.instantiate()
	casa.modo_carrera = true
	add_child(casa)
