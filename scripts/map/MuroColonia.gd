class_name MuroColonia
extends Node3D
## El muro que encierra Parques de Santa Mugre en el mapa completo: ahi se entra por la flecha
## amarilla a la escena con mas detalle (el mapa de Blender), no caminando. Coincide con las cuatro
## bardas de tools/blender/mapa/colonias/santa_mugre.json (Barda_norte/sur/poniente/oriente): el
## rectangulo `recorte`, 2.6 m de alto y 0.3 m de grueso, centradas sobre cada borde.
## Si cambia el recorte en el JSON, cambia `rect` aqui.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

## x0, z0, x1, z1 del recorte (el mismo de santa_mugre.json y recorte_santa_mugre.py)
@export var rect := Rect2(-420.0, 258.0, 235.0, 224.0)
@export var alto := 2.6
@export var grueso := 0.3
@export var color := Color(0.62, 0.6, 0.57)

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("deterioro_modo", 2)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)

	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var ancho := x1 - x0
	var fondo := z1 - z0
	# Lados centrados sobre el borde; los de oriente y poniente se alargan para cerrar las esquinas
	_pared(Vector3((x0 + x1) / 2.0, 0.0, z0), Vector3(ancho + grueso, alto, grueso), material)
	_pared(Vector3((x0 + x1) / 2.0, 0.0, z1), Vector3(ancho + grueso, alto, grueso), material)
	_pared(Vector3(x0, 0.0, (z0 + z1) / 2.0), Vector3(grueso, alto, fondo + grueso), material)
	_pared(Vector3(x1, 0.0, (z0 + z1) / 2.0), Vector3(grueso, alto, fondo + grueso), material)


func _pared(centro: Vector3, tam: Vector3, material: Material) -> void:
	# Del piso (y 0) hacia arriba; colisiona en la capa 1, como las casas: jugador, zombis y
	# CampoFlujo la ven sin cambios. Baja 1 m bajo el piso por si el terreno sube.
	var cuerpo := StaticBody3D.new()
	cuerpo.position = centro + Vector3(0.0, tam.y / 2.0 - 0.5, 0.0)
	var alto_total := tam.y + 1.0
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(tam.x, alto_total, tam.z)
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(tam.x, alto_total, tam.z)
	malla.mesh = box
	malla.material_override = material
	cuerpo.add_child(malla)
	add_child(cuerpo)
