class_name MapaColonia
extends Node3D
## La raiz de scenes/mapa.tscn: la misma escena sirve para cualquier colonia del mapa de Blender
## (tools/blender/mapa/colonias/<colonia>.json). Antes de que los hijos entren al arbol, apunta sus
## datos a resources/mapa/<colonia>/ y models/mapa/<colonia>/<colonia>.glb. La colonia es, en orden:
## `--colonia=<nombre>` en la linea de comandos (las pruebas y las capturas), lo que traiga
## PasoColonia.colonia (se llego por una reja o una boca) o `colonia` (Santa Mugre, la de la escena).

@export var colonia := "santa_mugre"

const DATOS := "res://resources/mapa/%s/%s"
const MODELO := "res://models/mapa/%s/%s.glb"

## La colonia cargada (para quien pregunte: Colonia.gd, las pruebas)
static var actual := ""


func _enter_tree() -> void:
	var cual := colonia
	if PasoColonia.colonia != "":
		cual = PasoColonia.colonia
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--colonia="):
			cual = arg.trim_prefix("--colonia=")
	actual = cual
	if cual == colonia:
		return   # la escena ya apunta a ella
	var puntos := DATOS % [cual, "puntos.json"]
	_poner("Puntos", "puntos_path", puntos)
	_poner("Minimapa", "puntos_path", puntos)
	_poner("Alumbrado", "alumbrado_path", DATOS % [cual, "alumbrado.json"])
	_poner("Colonia", "marcas_path", DATOS % [cual, "marcas.json"])
	_poner("Colonia", "modelo", load(MODELO % [cual, cual]))
	_poner("Partida", "casas_json", DATOS % [cual, "casas.json"])
	_poner("Partida", "puntos_json", puntos)
	_poner("Partida", "postes_json", DATOS % [cual, "alumbrado.json"])
	_poner("Gente", "banquetas_path", DATOS % [cual, "banquetas.json"])
	_poner("Gente", "puntos_path", puntos)
	_poner("ArbolesModelo", "arboles_path", DATOS % [cual, "arboles_modelo.json"])
	_poner("CarrosColonia", "carros_path", DATOS % [cual, "carros_modelo.json"])
	# El horizonte rodea el recorte de la colonia (exportar.py lo escribe en marcas.json)
	var marcas = JSON.parse_string(FileAccess.get_file_as_string(DATOS % [cual, "marcas.json"]))
	if marcas is Dictionary and marcas.has("recorte"):
		var r: Array = marcas["recorte"]
		_poner("Horizonte", "rect", Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))


func _poner(nodo: String, propiedad: String, valor: Variant) -> void:
	var n := get_node_or_null(nodo)
	if n:
		n.set(propiedad, valor)
	else:
		push_warning("MapaColonia: no esta el nodo %s" % nodo)
