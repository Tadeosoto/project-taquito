extends SceneTree

# Saca las banquetas de OpenStreetMap para que la gente camine (scripts/map/Gente.gd):
#
#   godot --path . --headless -s tools/map_import/banquetas.gd
#
# Lee data/map/area.osm y tools/map_import/area.env y escribe resources/map/banquetas_mapa.json,
# una linea por cada lado de cada calle. Usa la misma proyeccion y los mismos anchos que
# prepare_osm.py (local_xz, ANCHO_CALLE, BANQUETA). En GDScript para no depender de Python.
# Al final compara contra los postes del alumbrado: la distancia tiene que salir chica.

const OSM := "res://data/map/area.osm"
const ENV := "res://tools/map_import/area.env"
const SALIDA := "res://resources/map/banquetas_mapa.json"
const POSTES := "res://resources/map/alumbrado_mapa.json"
const RADIO_TIERRA := 6378137.0
const ANCHO_CALLE := {"primary": 14.0, "secondary": 12.0, "tertiary": 10.0, "residential": 7.0, "unclassified": 6.0, "living_street": 6.0}
const BANQUETA := {"primary": 2.0, "secondary": 2.0, "tertiary": 2.0, "residential": 1.5, "unclassified": 1.2, "living_street": 1.2}
const LARGO_MIN := 15.0
const ORILLA := 10.0      # m de margen al borde del mapa


func _init() -> void:
	var caja := _leer_caja()
	var lat0: float = (caja["SOUTH"] + caja["NORTH"]) / 2.0
	var lon0: float = (caja["WEST"] + caja["EAST"]) / 2.0
	var esquina := _local(caja["NORTH"], caja["EAST"], lat0, lon0)
	var medio := Vector2(absf(esquina.x), absf(esquina.y)) - Vector2.ONE * ORILLA
	var nodos := {}
	var lineas: Array = []
	var parser := XMLParser.new()
	if parser.open(OSM) != OK:
		push_error("banquetas: no se pudo abrir %s" % OSM)
		quit(1)
		return
	var refs: Array = []
	var via := ""
	var en_way := false
	while parser.read() == OK:
		var tipo := parser.get_node_type()
		if tipo == XMLParser.NODE_ELEMENT:
			match parser.get_node_name():
				"node":
					nodos[parser.get_named_attribute_value("id")] = _local(float(parser.get_named_attribute_value("lat")), float(parser.get_named_attribute_value("lon")), lat0, lon0)
				"way":
					en_way = true
					refs = []
					via = ""
				"nd":
					if en_way:
						refs.append(parser.get_named_attribute_value("ref"))
				"tag":
					if en_way and parser.get_named_attribute_value("k") == "highway":
						via = parser.get_named_attribute_value("v")
		elif tipo == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "way":
			en_way = false
			if BANQUETA.has(via):
				var puntos: Array[Vector2] = []
				for r: String in refs:
					if nodos.has(r):
						puntos.append(nodos[r])
				var lado: float = ANCHO_CALLE[via] / 2.0 + BANQUETA[via] / 2.0
				for signo in [1.0, -1.0]:
					_agregar(lineas, _desplazar(puntos, lado * signo), medio)
	var salida: Array = []
	for linea: Array in lineas:
		var plana: Array = []
		for p: Vector2 in linea:
			plana.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		salida.append(plana)
	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify({"banquetas": salida}))
	f.close()
	print("BANQUETAS lineas=%d" % salida.size())
	_comparar(lineas)
	quit()


# Partida donde se sale del mapa
func _agregar(lineas: Array, puntos: Array[Vector2], medio: Vector2) -> void:
	var tramo: Array[Vector2] = []
	for p in puntos:
		if absf(p.x) <= medio.x and absf(p.y) <= medio.y:
			tramo.append(p)
		else:
			_cerrar(lineas, tramo)
			tramo = []
	_cerrar(lineas, tramo)


func _cerrar(lineas: Array, tramo: Array[Vector2]) -> void:
	var largo := 0.0
	for i in tramo.size() - 1:
		largo += tramo[i].distance_to(tramo[i + 1])
	if largo >= LARGO_MIN:
		lineas.append(tramo)


func _desplazar(puntos: Array[Vector2], lado: float) -> Array[Vector2]:
	var fuera: Array[Vector2] = []
	for i in puntos.size():
		var a := puntos[maxi(i - 1, 0)]
		var b := puntos[mini(i + 1, puntos.size() - 1)]
		var d := (b - a).normalized()
		fuera.append(puntos[i] + Vector2(-d.y, d.x) * lado)
	return fuera


func _local(lat: float, lon: float, lat0: float, lon0: float) -> Vector2:
	var escala := cos(deg_to_rad(lat0))
	var x := RADIO_TIERRA * deg_to_rad(lon - lon0) * escala
	var z := -(_merc(lat) - _merc(lat0)) * escala
	return Vector2(x, z)


func _merc(lat: float) -> float:
	return RADIO_TIERRA * log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0))


func _leer_caja() -> Dictionary:
	var caja := {}
	for linea in FileAccess.get_file_as_string(ENV).split("\n"):
		if linea.contains("=") and not linea.begins_with("#"):
			caja[linea.get_slice("=", 0).strip_edges()] = linea.get_slice("=", 1).to_float()
	return caja


# Los postes estan en la banqueta: la linea mas cercana tiene que quedar a unos metros
func _comparar(lineas: Array) -> void:
	var postes: Array = JSON.parse_string(FileAccess.get_file_as_string(POSTES))["postes"]
	var distancias: Array[float] = []
	for i in range(0, postes.size(), 25):
		var p := Vector2(postes[i]["x"], postes[i]["z"])
		var mejor := INF
		for linea: Array in lineas:
			for j in linea.size() - 1:
				mejor = minf(mejor, p.distance_to(Geometry2D.get_closest_point_to_segment(p, linea[j], linea[j + 1])))
		distancias.append(mejor)
	distancias.sort()
	print("BANQUETAS postes medidos=%d mediana=%.2f m p90=%.2f m" % [distancias.size(), distancias[distancias.size() / 2], distancias[int(distancias.size() * 0.9)]])
