extends Node

# Deterioro propio de una escena (los shaders y Deterioro.zona: casas en obra negra, grafitis,
# bodegas, zombis), en lugar del de project.godot. Va antes que los constructores del mapa:
# se aplica al entrar al arbol, antes de sus _ready. Al salir deja el de project.godot.

@export_range(0.0, 1.0) var maximo := 0.35
@export var escala := 150.0


func _enter_tree() -> void:
	Deterioro.configurar(maximo, escala)


func _exit_tree() -> void:
	Deterioro.configurar(Deterioro._setting("deterioro", 0.8), Deterioro._setting("deterioro_escala", 150.0))
