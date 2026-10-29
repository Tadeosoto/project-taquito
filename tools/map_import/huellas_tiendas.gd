extends SceneTree

# Escribe data/map/huellas_tiendas.json: frente y fondo (m) que ocupa cada modelo
# de negocio de map_test.tscn (nodo Puntos: prefabs, prefab_ancho, prefab_rotacion),
# y el tamano minimo de los locales armados. prepare_osm.py lo usa para quitar las
# casas que quedan debajo de un negocio. Tambien el frente y fondo de cada casa
# modelo (nodo Casas, como la dibuja MapCasas antes de escalarla al lote), con los
# que prepare_osm.py llena las cuadras de casas pegadas. Lo corre build_glb.sh.
# Uso: godot --path . --headless -s tools/map_import/huellas_tiendas.gd

const SALIDA := "res://data/map/huellas_tiendas.json"


func _initialize() -> void:
	var escena := (load("res://scenes/map_test.tscn") as PackedScene).instantiate()
	var puntos := escena.get_node("Puntos")
	var huellas := {}
	for tipo: String in puntos.prefabs:
		var huella: Vector2 = puntos.huella_modelo(tipo)
		if huella != Vector2.ZERO:
			huellas[tipo] = [snappedf(huella.x, 0.01), snappedf(huella.y, 0.01)]
	var casas_node := escena.get_node("Casas")
	var casas := {}
	for modelo: String in casas_node.modelos:
		if casas_node.modelos[modelo] == null:
			continue
		var aabb: AABB = casas_node._preparar_modelo(modelo)["aabb"]
		casas[modelo] = [snappedf(aabb.size.x, 0.01), snappedf(aabb.size.z, 0.01)]
	var local_min: Vector2 = puntos.LOCAL_MIN
	var data := {
		"_nota": "Generado por tools/map_import/huellas_tiendas.gd: [frente, fondo] en metros",
		"_local_min": [local_min.x, local_min.y],
		"_locales": puntos.GIROS_LOCAL.keys() + ["purificadora"],
		"modelos": huellas,
		"casas": casas,
	}
	var file := FileAccess.open(SALIDA, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	escena.free()
	print("huellas_tiendas: %d modelos, %d casas -> %s" % [huellas.size(), casas.size(), SALIDA])
	quit()
