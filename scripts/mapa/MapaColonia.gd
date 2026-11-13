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
## Colonia abierta las 24 horas y sin zombis ("abierto_24h" en su .json, exportar.py lo copia a
## marcas.json): de noche no cierran las tiendas ni bajan las cortinas (Interiores, MapPuntos), el
## tianguis y la gente se quedan (Tianguis, Gente), no salen zombis sueltos (Zombis) ni los avisos
## de la noche (Supervivencia). La Gotera: los Gotera cuidan su muralla. Vuelve a false al salir
## de la escena, para que map_test y las otras colonias no lo hereden.
static var abierto_24h := false


func _enter_tree() -> void:
	var cual := colonia
	if PasoColonia.colonia != "":
		cual = PasoColonia.colonia
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--colonia="):
			cual = arg.trim_prefix("--colonia=")
	actual = cual
	var marcas = JSON.parse_string(FileAccess.get_file_as_string(DATOS % [cual, "marcas.json"]))
	abierto_24h = marcas is Dictionary and bool(marcas.get("abierto_24h", false))
	if marcas is Dictionary and marcas.get("ambiente") is Dictionary:
		_ambiente(marcas["ambiente"])
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
	if marcas is Dictionary and marcas.has("recorte"):
		var r: Array = marcas["recorte"]
		_poner("Horizonte", "rect", Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))


## El "ambiente" de una colonia cerrada (la favela de La Gotera; exportar.py lo copia del .json):
##   niebla  fog_density del WorldEnvironment (la escena trae 0.0196: el 5 % se ve a 150 m)
##   lejos   m hasta donde dibuja la camara del jugador (el dron no cambia); con niebla espesa lo de
##           mas alla ya no se ve y no se gasta en dibujarlo
##   gente   {caminantes, anillo [cerca, lejos], quitar_a, alto_libre, rayo_desde} para Gente.gd
## El Environment se duplica: es un sub_resource de mapa.tscn y cambiarlo se quedaba para la
## siguiente colonia que cargara la escena.
func _ambiente(datos: Dictionary) -> void:
	var entorno := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if entorno and datos.has("niebla"):
		entorno.environment = entorno.environment.duplicate()
		entorno.environment.fog_density = float(datos["niebla"])
	var camara := get_node_or_null("Player/CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if camara and datos.has("lejos"):
		camara.far = float(datos["lejos"])
	var gente := get_node_or_null("Gente")
	if gente and datos.get("gente") is Dictionary:
		var g: Dictionary = datos["gente"]
		for clave: String in g:
			var valor = g[clave]
			if valor is Array:
				valor = Vector2(float(valor[0]), float(valor[1]))
			elif clave == "caminantes":
				valor = int(valor)
			else:
				valor = float(valor)
			gente.set(clave, valor)


func _exit_tree() -> void:
	abierto_24h = false


func _poner(nodo: String, propiedad: String, valor: Variant) -> void:
	var n := get_node_or_null(nodo)
	if n:
		n.set(propiedad, valor)
	else:
		push_warning("MapaColonia: no esta el nodo %s" % nodo)
