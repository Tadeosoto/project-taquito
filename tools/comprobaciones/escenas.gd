extends Comprobacion

# Que las escenas principales carguen y aguanten unos segundos. Los SCRIPT ERROR de la consola los
# cuenta correr.sh (desde aqui no se ven)

const ESCENAS := ["res://scenes/inicio.tscn", "res://scenes/safehouse.tscn", "res://scenes/map_test.tscn",
	"res://scenes/mapa.tscn", "res://scenes/defensa_tinaco.tscn", "res://scenes/lombrices.tscn",
	"res://scenes/catrina.tscn", "res://scenes/tuneles.tscn"]


func correr(r: Node) -> void:
	for ruta: String in ESCENAS:
		var cargo: bool = await r.ir_a(ruta, 120)
		r.ok(cargo and r.get_tree().current_scene != null, "carga %s" % ruta.get_file())
