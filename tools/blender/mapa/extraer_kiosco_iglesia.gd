extends SceneTree
# Saca del mapa de Blender de Santa Mugre (models/mapa/santa_mugre/santa_mugre.glb, el de Alan) solo el
# kiosco y la parroquia con su atrio, con sus choques "-colonly", a
# models/mapa/santa_mugre/kiosco_iglesia.glb, para scenes/santa_mugre_psm.tscn (el corte con el mapa de
# map_test). Quedan en las mismas coordenadas que en el mapa. Se lee del .glb y no del importado
# porque ese ya trae las mallas juntadas por cuadros; al importar el nuevo, MapaPostImport.gd le
# pone los materiales PS1 como a la colonia:
#
#     godot --path . --headless -s tools/blender/mapa/extraer_kiosco_iglesia.gd
#     godot --path . --headless --import

const ORIGEN := "res://models/mapa/santa_mugre/santa_mugre.glb"
const SALIDA := "res://models/mapa/santa_mugre/kiosco_iglesia.glb"
const PIEZAS := ["Kiosco", "Parroquia", "Atrio"]


func _init() -> void:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(ORIGEN), estado)
	var mapa: Node = doc.generate_scene(estado)
	var raiz := Node3D.new()
	raiz.name = "KioscoIglesia"
	for hijo in mapa.get_children():
		if not _es_pieza(hijo.name):
			continue
		hijo.owner = null
		mapa.remove_child(hijo)
		raiz.add_child(hijo)
		_dueno(hijo, raiz)
		print(hijo.name)
	var salida := GLTFDocument.new()
	var estado_salida := GLTFState.new()
	salida.append_from_scene(raiz, estado_salida)
	var error := salida.write_to_filesystem(estado_salida, ProjectSettings.globalize_path(SALIDA))
	print("guardado ", SALIDA, ": ", raiz.get_child_count(), " nodos, error ", error)
	mapa.free()
	raiz.free()
	quit()


func _es_pieza(nombre: String) -> bool:
	for p in PIEZAS:
		if nombre.begins_with(p):
			return true
	return false


func _dueno(n: Node, raiz: Node) -> void:
	n.owner = raiz
	for h in n.get_children():
		_dueno(h, raiz)
