class_name Comprobacion
extends RefCounted

# Una comprobacion (Correr.gd): un archivo de esta carpeta que extiende esta clase y pone su
# prueba en `correr`. `r` es el corredor: r.ok(cond, texto), r.ir_a(escena), r.frames(n),
# r.segundos(s), r.saltar_ciclo(), r.cerrar_tazo(), r.apretar(accion), r.nodo(grupo),
# r.autoload(nombre). Cada una empieza con partida nueva (Guardado.nueva) y deja la suya armada.

const SAFEHOUSE := "res://scenes/safehouse.tscn"


func correr(_r: Node) -> void:
	pass
