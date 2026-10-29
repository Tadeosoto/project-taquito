@tool
class_name Mueble
extends Node3D

# Un modelo puesto dentro de un interior (scenes/interiores/): lo para sobre el piso
# del nodo, centrado, y lo escala parejo para que mida `medida` m en `eje`. Los
# modelos de Sketchfab vienen en cualquier unidad (el mostrador mide 4 km), asi que
# en la escena solo se dice cuanto debe medir. Su frente queda hacia +Z, como en el
# glTF original. El modelo no se guarda en la escena: se arma al cargarla.

@export var modelo: PackedScene:
	set(valor):
		modelo = valor
		_reconstruir()
# Metros que mide en `eje`; 0 = tamano original
@export var medida := 1.0:
	set(valor):
		medida = valor
		_reconstruir()
@export_enum("ancho", "alto", "fondo") var eje := 0:
	set(valor):
		eje = valor
		_reconstruir()
# false: deja el origen del modelo donde esta (la tiendita m3_mart, que es todo el local)
@export var centrar := true:
	set(valor):
		centrar = valor
		_reconstruir()
# Nodos del modelo que se quitan antes de medirlo (el piso con calle del puesto de tacos)
@export var quitar := PackedStringArray():
	set(valor):
		quitar = valor
		_reconstruir()
# caja: una caja del tamano del modelo; malla: su malla exacta (locales completos)
@export_enum("caja", "malla", "ninguna") var colision := 0

var _instancia: Node3D


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _instancia:
		_instancia.queue_free()
		_instancia = null
	if modelo == null:
		return
	_instancia = modelo.instantiate() as Node3D
	for nombre in quitar:
		var sobra := _instancia.find_child(nombre, true, false)
		if sobra:
			sobra.get_parent().remove_child(sobra)
			sobra.free()
	var caja := Mueble.medir(_instancia)
	var escala := 1.0
	if medida > 0.0 and caja.size[[0, 1, 2][eje]] > 0.0:
		escala = medida / caja.size[[0, 1, 2][eje]]
	_instancia.scale = Vector3.ONE * escala
	if centrar:
		var base := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
		_instancia.position = -base * escala
	add_child(_instancia)
	if Engine.is_editor_hint():
		return
	if colision == 0:
		var cuerpo := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caja.size * escala
		forma.shape = box
		forma.position = _instancia.position + caja.get_center() * escala
		cuerpo.add_child(forma)
		add_child(cuerpo)
	elif colision == 1:
		for malla in _instancia.find_children("*", "MeshInstance3D", true, false):
			(malla as MeshInstance3D).create_trimesh_collision()


# Caja de todas las mallas del modelo, en el espacio de su raiz
static func medir(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	var pendientes := [[raiz, Transform3D()]]
	while not pendientes.is_empty():
		var par: Array = pendientes.pop_back()
		var nodo: Node = par[0]
		var xf: Transform3D = par[1]
		if nodo != raiz and nodo is Node3D:
			xf = xf * (nodo as Node3D).transform
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
			var parte: AABB = xf * (nodo as MeshInstance3D).mesh.get_aabb()
			caja = parte if primera else caja.merge(parte)
			primera = false
		for hijo in nodo.get_children():
			pendientes.append([hijo, xf])
	return caja
