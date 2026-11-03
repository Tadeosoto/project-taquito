class_name Materiales

# Los materiales del taller (El Yonke de La Chava; docs/especificaciones.md 4.13), como los
# fragmentos, gemas y cristales de Kingdom Hearts pero de este mundo. Van al Morral (Morral.gd),
# no al inventario. Propuesta de AG; los numeros de abajo son para afinarse jugando.
#   - COMUN: seis familias en tres niveles (suelto, bueno, fino). Los sueltan los zombis.
#   - ESPECIAL: los raros que no son de una familia (varilla, plata, baba...).
#   - TROFEO: los de las hazanas y de los zombis raros. Se quedan entre partidas (la vitrina).
#
# No nombra autoloads: Zombie.gd, que lo usa, lo cargan scripts de tools/.

enum Clase { COMUN, ESPECIAL, TROFEO }
const FAMILIAS := ["Fierro", "Trapo", "Cable", "Lumbre", "Agua", "Vela"]
const NIVELES := ["Suelto", "Bueno", "Fino"]
const ICONOS := "res://textures/materiales/%s.png"   # 16 x 16, de tools/taller/iconos.gd

# Lo que suelta un zombi que matas (botin). Probabilidades de 0 a 1
const SUELTO := 0.7            # uno de nivel suelto
const BUENO_BASE := 0.08       # uno bueno...
const BUENO_NOCHE := 0.12      # ...mas de noche
const BUENO_ZONA := 0.2        # ...y mas en zonas feas (por Deterioro.zona, de 0 a 1)
const FINO_BASE := 0.02        # uno fino
const CAZADOR_BUENO := 0.5     # los cazadores sueltan mejor
const CAZADOR_FINO := 0.08
const VARILLA := 0.1           # una varilla corta
const CHATARRA := Vector2i(2, 4)    # sueltos en un monton de chatarra
const CHATARRA_VARILLA := 0.4

# id -> nombre, descripcion, clase, familia (-1 si no es comun), nivel (0-2; -1)
const LISTA := {
	"rebaba": { "nombre": "Rebaba", "descripcion": "Virutas de fierro de cualquier lado.", "clase": Clase.COMUN, "familia": 0, "nivel": 0 },
	"tuerca": { "nombre": "Tuerca", "descripcion": "Una tuerca buena, de las que ya no hacen.", "clase": Clase.COMUN, "familia": 0, "nivel": 1 },
	"engrane": { "nombre": "Engrane", "descripcion": "Un engrane de acero sin un diente roto.", "clase": Clase.COMUN, "familia": 0, "nivel": 2 },
	"hilacha": { "nombre": "Hilacha", "descripcion": "Hilos sueltos de alguna camisa.", "clase": Clase.COMUN, "familia": 1, "nivel": 0 },
	"trapo": { "nombre": "Trapo", "descripcion": "Un trapo entero. Casi limpio.", "clase": Clase.COMUN, "familia": 1, "nivel": 1 },
	"cuero": { "nombre": "Cuero", "descripcion": "Un pedazo de cuero de verdad, de chamarra o de cinto.", "clase": Clase.COMUN, "familia": 1, "nivel": 2 },
	"alambrito": { "nombre": "Alambrito", "descripcion": "Alambre delgado, de amarrar.", "clase": Clase.COMUN, "familia": 2, "nivel": 0 },
	"cable": { "nombre": "Cable", "descripcion": "Cable con su forro. Alguien se lo robó de un poste.", "clase": Clase.COMUN, "familia": 2, "nivel": 1 },
	"cobre": { "nombre": "Cobre", "descripcion": "Cobre pelado. En el yonke lo pagan bien.", "clase": Clase.COMUN, "familia": 2, "nivel": 2 },
	"cerillo": { "nombre": "Cerillo", "descripcion": "Unos cerillos que todavía prenden.", "clase": Clase.COMUN, "familia": 3, "nivel": 0 },
	"thinner": { "nombre": "Thinner", "descripcion": "Medio bote de thinner. Huele desde lejos.", "clase": Clase.COMUN, "familia": 3, "nivel": 1 },
	"polvora": { "nombre": "Pólvora", "descripcion": "Pólvora de cohetes de feria.", "clase": Clase.COMUN, "familia": 3, "nivel": 2 },
	"agua_sucia": { "nombre": "Agua sucia", "descripcion": "Agua de charco. Para algo sirve.", "clase": Clase.COMUN, "familia": 4, "nivel": 0 },
	"agua_llave": { "nombre": "Agua de la llave", "descripcion": "Agua de la llave, de cuando salía.", "clase": Clase.COMUN, "familia": 4, "nivel": 1 },
	"agua_destilada": { "nombre": "Agua destilada", "descripcion": "Agua destilada de verdad. Vale oro.", "clase": Clase.COMUN, "familia": 4, "nivel": 2 },
	"pabilo": { "nombre": "Pabilo", "descripcion": "La mecha de una vela que ya se acabó.", "clase": Clase.COMUN, "familia": 5, "nivel": 0 },
	"veladora": { "nombre": "Veladora", "descripcion": "Una veladora con su santo pegado.", "clase": Clase.COMUN, "familia": 5, "nivel": 1 },
	"agua_bendita": { "nombre": "Agua bendita", "descripcion": "Bendita por el padre Chuy. Eso dicen.", "clase": Clase.COMUN, "familia": 5, "nivel": 2 },
	"varilla_corta": { "nombre": "Varilla corta", "descripcion": "Un pedazo de varilla de construcción.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"alambron": { "nombre": "Alambrón", "descripcion": "Alambrón de obra negra. Sale de las casas a medio hacer.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"varilla_armada": { "nombre": "Varilla armada", "descripcion": "Varillas soldadas por La Chava. Para lo bueno.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"plata_taxco": { "nombre": "Plata de Taxco", "descripcion": "Plata de verdad. Solo la venden en el punto.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"baba_verde": { "nombre": "Baba verde", "descripcion": "Lo que suelta un zombi cuando se quema.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"polvo_serenol": { "nombre": "Polvo de Serenol", "descripcion": "Polvo blanco de los zombis con uniforme de GelA. No te lo tomes.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"varilla_84": { "nombre": "Varilla del 84", "descripcion": "La varilla que brilla. La familia de La Chava sabe de dónde salió.", "clase": Clase.ESPECIAL, "familia": -1, "nivel": -1 },
	"marca_cazador": { "nombre": "Marca de cazador", "descripcion": "Trofeo: mataste a un cazador.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"ojo_turba": { "nombre": "Ojo de turba", "descripcion": "Trofeo: mataste a cinco de una turba en diez segundos.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"ceniza": { "nombre": "Ceniza", "descripcion": "Trofeo: mataste a uno con fuego.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"tapa_tinaco": { "nombre": "Tapa del tinaco", "descripcion": "Trofeo: pasaste una noche sin que le pegaran al tinaco.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"diente_jefe": { "nombre": "Diente del jefe", "descripcion": "Trofeo: mataste al garrafonero.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"chancla_oro": { "nombre": "Chancla de oro", "descripcion": "Trofeo: mataste a uno sin arma, a puro chanclazo y puño.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"casco_gela": { "nombre": "Casco de GelA", "descripcion": "Trofeo: el casco de un zombi con uniforme de GelA.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
	"cobalto": { "nombre": "Cobalto", "descripcion": "Trofeo: un pedazo del zombi que brilla en las obras negras.", "clase": Clase.TROFEO, "familia": -1, "nivel": -1 },
}


static func dato(id: String) -> Dictionary:
	return LISTA.get(id, {})


static func nombre(id: String) -> String:
	return dato(id).get("nombre", id)


static func es_trofeo(id: String) -> bool:
	return dato(id).get("clase", -1) == Clase.TROFEO


static func icono(id: String) -> Texture2D:
	var ruta := ICONOS % id
	return load(ruta) if ResourceLoader.exists(ruta) else null


# El comun de esa familia y nivel
static func comun(familia: int, nivel: int) -> String:
	for id: String in LISTA:
		if LISTA[id]["familia"] == familia and LISTA[id]["nivel"] == nivel:
			return id
	return ""


static func de_clase(clase: Clase) -> Array[String]:
	var ids: Array[String] = []
	for id: String in LISTA:
		if LISTA[id]["clase"] == clase:
			ids.append(id)
	return ids


# Lo que suelta un zombi: id -> cuantos. `zona` es Deterioro.zona donde murio (0 a 1)
static func botin(zona: float, de_noche: bool, cazador: bool) -> Dictionary:
	var sale := {}
	if randf() < SUELTO:
		_sumar(sale, comun(randi() % FAMILIAS.size(), 0))
	var bueno := CAZADOR_BUENO if cazador else BUENO_BASE + (BUENO_NOCHE if de_noche else 0.0) + BUENO_ZONA * zona
	if randf() < bueno:
		_sumar(sale, comun(randi() % FAMILIAS.size(), 1))
	if randf() < (CAZADOR_FINO if cazador else FINO_BASE):
		_sumar(sale, comun(randi() % FAMILIAS.size(), 2))
	if randf() < VARILLA:
		_sumar(sale, "varilla_corta")
	return sale


# Un monton de chatarra en la calle: unos sueltos y a veces varilla
static func chatarra() -> Dictionary:
	var sale := {}
	for i in randi_range(CHATARRA.x, CHATARRA.y):
		_sumar(sale, comun(randi() % FAMILIAS.size(), 0))
	if randf() < CHATARRA_VARILLA:
		_sumar(sale, "varilla_corta")
	return sale


static func _sumar(sale: Dictionary, id: String) -> void:
	if id != "":
		sale[id] = sale.get(id, 0) + 1
