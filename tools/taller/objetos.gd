extends SceneTree

# Escribe resources/taller/<id>.tres: lo que se hace en el taller de La Chava (Recetas.gd),
# desde la tabla de abajo. Los materiales que salen de una receta (varilla armada, varilla
# del 84) no van aqui: son de los Tiliches (Materiales.gd). Correr despues de tools/taller/modelos.gd.
#
#   godot --path . --headless -s tools/taller/objetos.gd

const SALIDA := "res://resources/taller/"
const ARMAS := "res://models/armas/melee_psx/piezas/%s.scn"
const FORMAS := "res://models/taller/%s.scn"
const OBJETOS := "res://models/objetos/%s/%s.scn"

# id -> datos. modelo: ["arma"|"forma"|"objeto", nombre]. Lo que no se pone usa el default
const TABLA := {
	# --- Consumibles ---
	"caldo_pollo": { "nombre": "Caldo de pollo", "descripcion": "Caliente, con su limón. Como el de tu abuela.",
		"efecto": "+60 de vida", "modelo": ["objeto", "tejuino"], "tinte": Color(0.85, 0.6, 0.25), "curacion": 60 },
	"remedio_abuela": { "nombre": "Remedio de la abuela", "descripcion": "Vaporub, té y un trapito en la frente. Te deja como nuevo.",
		"efecto": "Cura toda la vida", "modelo": ["objeto", "vaporub"], "curacion": 999 },
	"suero_oral": { "nombre": "Suero oral", "descripcion": "Del de sobre, preparado con agua de la llave. Sabe a lágrima.",
		"efecto": "+40 de vida", "modelo": ["objeto", "botella"], "tinte": Color(0.6, 0.85, 1.0), "curacion": 40 },
	"te_virgen": { "nombre": "Té de la Virgen", "descripcion": "Té de hierbas con agua bendita. Dicen que cura lo que sea.",
		"efecto": "Cura toda la vida", "modelo": ["objeto", "tejuino"], "tinte": Color(0.4, 0.8, 0.4), "curacion": 999 },
	"milagro_tinaco": { "nombre": "Milagro del tinaco", "descripcion": "Agua del tinaco que no se vacía. No preguntes.",
		"efecto": "Cura toda la vida y vuelve a dejar usar Segundo aire esta noche", "modelo": ["objeto", "galon_agua"],
		"tinte": Color(0.4, 0.9, 1.0), "curacion": 999, "recarga_segundo_aire": true },
	# --- Estampitas: se usan una vez y duran la partida ---
	"estampita_san_expedito": { "nombre": "Estampita de San Expedito", "descripcion": "El de las causas urgentes. Para ya.",
		"efecto": "+1 punto de habilidad", "modelo": ["forma", "placa"], "tinte": Color(0.9, 0.3, 0.3), "estampita": "punto" },
	"estampita_santo_nino": { "nombre": "Estampita del Santo Niño", "descripcion": "El Santo Niño de Atocha, con su canastita.",
		"efecto": "-5 % de daño toda la partida", "modelo": ["forma", "placa"], "tinte": Color(0.95, 0.85, 0.5), "estampita": "defensa" },
	"estampita_san_miguel": { "nombre": "Estampita de San Miguel", "descripcion": "San Miguel Arcángel pisando al chamuco.",
		"efecto": "+5 % de fuerza toda la partida", "modelo": ["forma", "placa"], "tinte": Color(0.4, 0.5, 0.9), "estampita": "fuerza" },
	# --- Amuletos (Bonos.gd): dos puestos a la vez ---
	"pulsera_hilo_rojo": { "nombre": "Pulsera de hilo rojo", "descripcion": "Contra el mal de ojo. Y contra los zombis, quién sabe.",
		"efecto": "Amuleto: +10 de vida máxima", "modelo": ["forma", "aro"], "tinte": Color(0.85, 0.1, 0.1), "amuleto": { "vida": 10 } },
	"cadena_fantasia": { "nombre": "Cadena de fantasía", "descripcion": "Parece de oro. No es de oro.",
		"efecto": "Amuleto: +5 % de fuerza", "modelo": ["forma", "aro"], "tinte": Color(0.8, 0.7, 0.3), "amuleto": { "fuerza": 0.05 } },
	"rodilleras": { "nombre": "Rodilleras", "descripcion": "De albañil, con espuma vieja.",
		"efecto": "Amuleto: -5 % de daño", "modelo": ["forma", "rodillera"], "tinte": Color(0.25, 0.25, 0.28), "amuleto": { "defensa": 0.05 } },
	"medalla_san_judas": { "nombre": "Medalla de San Judas", "descripcion": "San Judas Tadeo, el de los casos difíciles.",
		"efecto": "Amuleto: +20 % de pesos", "modelo": ["forma", "medalla"], "tinte": Color(0.9, 0.8, 0.4), "amuleto": { "pesos": 0.2 } },
	"lampara": { "nombre": "Lámpara de pilas", "descripcion": "Una lámpara con cable y pilas de las chinas. Alumbra.",
		"efecto": "Amuleto: alumbra de noche", "modelo": ["forma", "lampara"], "tinte": Color(0.9, 0.75, 0.2), "amuleto": { "luz": true } },
	"escapulario": { "nombre": "Escapulario", "descripcion": "De tela café, con su virgencita.",
		"efecto": "Amuleto: -10 % de daño", "modelo": ["forma", "placa"], "tinte": Color(0.5, 0.3, 0.15), "amuleto": { "defensa": 0.1 } },
	"pulsera_san_benito": { "nombre": "Pulsera de San Benito", "descripcion": "Con la medallita que espanta lo malo.",
		"efecto": "Amuleto: +25 de vida máxima", "modelo": ["forma", "aro"], "tinte": Color(0.2, 0.2, 0.2), "amuleto": { "vida": 25 } },
	"cadena_gruesa": { "nombre": "Cadena gruesa", "descripcion": "De las que pesan. Sirve de todo.",
		"efecto": "Amuleto: +10 % de fuerza, -5 % de daño", "modelo": ["forma", "aro"], "tinte": Color(0.7, 0.7, 0.75), "amuleto": { "fuerza": 0.1, "defensa": 0.05 } },
	"coderas": { "nombre": "Coderas", "descripcion": "Coderas de patineta con cinta canela.",
		"efecto": "Amuleto: -10 % de daño, +5 % de alcance", "modelo": ["forma", "rodillera"], "tinte": Color(0.4, 0.3, 0.2), "amuleto": { "defensa": 0.1, "alcance": 0.05 } },
	"rosario": { "nombre": "Rosario de semillas", "descripcion": "Semillas de ojo de venado ensartadas a mano.",
		"efecto": "Amuleto: -20 % de daño de noche", "modelo": ["forma", "aro"], "tinte": Color(0.45, 0.25, 0.12), "amuleto": { "noche": 0.2 } },
	"medalla_virgen": { "nombre": "Medalla de la Virgen", "descripcion": "La Virgen del Tinaco, en lámina azul.",
		"efecto": "Amuleto: salen más tazos raros y holo", "modelo": ["forma", "medalla"], "tinte": Color(0.4, 0.7, 0.95), "amuleto": { "suerte": 0.5 } },
	"faja_cargador": { "nombre": "Faja de cargador", "descripcion": "La del cargador del mercado. Aprieta.",
		"efecto": "Amuleto: +40 de vida máxima", "modelo": ["forma", "faja"], "tinte": Color(0.3, 0.25, 0.2), "amuleto": { "vida": 40 } },
	"cadena_oro": { "nombre": "Cadena de oro", "descripcion": "Esta sí es de oro. De quién era, mejor no.",
		"efecto": "Amuleto: +20 % de fuerza", "modelo": ["forma", "aro"], "tinte": Color(1.0, 0.8, 0.2), "amuleto": { "fuerza": 0.2 } },
	"ojo_venado": { "nombre": "Ojo de venado", "descripcion": "Semilla con su hilo rojo, contra la envidia y los fuertes.",
		"efecto": "Amuleto: -20 % de daño de cazadores y del jefe, +15 de vida", "modelo": ["forma", "medalla"], "tinte": Color(0.75, 0.15, 0.15),
		"amuleto": { "fuertes": 0.2, "vida": 15 } },
	"herradura": { "nombre": "Herradura", "descripcion": "Con las puntas para arriba, para que no se salga la suerte.",
		"efecto": "Amuleto: -20 % de daño de las turbas", "modelo": ["forma", "aro"], "tinte": Color(0.55, 0.55, 0.6), "amuleto": { "turba": 0.2 } },
	"brazalete_cobre": { "nombre": "Brazalete de cobre", "descripcion": "Para las reumas. Y para aventar más fuerte.",
		"efecto": "Amuleto: lo que avientas pega más y más lejos", "modelo": ["forma", "aro"], "tinte": Color(0.85, 0.45, 0.2), "amuleto": { "arrojable": 0.3 } },
	"corona_lata": { "nombre": "Corona de lata", "descripcion": "Hecha con latas de cerveza. Rey del yonke.",
		"efecto": "Amuleto: +15 de vida, +10 % de fuerza, -5 % de daño, +10 % de pesos", "modelo": ["forma", "corona"], "tinte": Color(0.75, 0.75, 0.8),
		"amuleto": { "vida": 15, "fuerza": 0.1, "defensa": 0.05, "pesos": 0.1 } },
	"chamarra_nocturno": { "nombre": "Chamarra del Nocturno", "descripcion": "Negra, con forro de cobre. Para trabajar de noche.",
		"efecto": "Amuleto: +30 de vida, -10 % de daño, +10 % de pesos", "modelo": ["forma", "chamarra"], "tinte": Color(0.12, 0.12, 0.15),
		"amuleto": { "vida": 30, "defensa": 0.1, "pesos": 0.1 } },
	"medalla_gela": { "nombre": "Medalla de GelA", "descripcion": "De empleado del mes. Alguien ya no la va a necesitar.",
		"efecto": "Amuleto: +30 % de pesos, -5 % de daño", "modelo": ["forma", "medalla"], "tinte": Color(0.2, 0.45, 0.85), "amuleto": { "pesos": 0.3, "defensa": 0.05 } },
	"liston_virgen": { "nombre": "Listón de la Virgen", "descripcion": "Listón azul bendito, amarrado a la muñeca.",
		"efecto": "Amuleto: -20 % de todo el daño", "modelo": ["forma", "liston"], "tinte": Color(0.3, 0.6, 1.0), "amuleto": { "defensa": 0.2 } },
	# --- Armas: cada una con lo suyo (Player._golpear) ---
	"tubo": { "nombre": "Tubo de fierro", "descripcion": "Un tubo de agua. Ya no lleva agua.",
		"efecto": "14 de daño, empuja más", "modelo": ["arma", "bat"], "tinte": Color(0.45, 0.45, 0.5), "dano": 14, "empujon": 1.3 },
	"antorcha": { "nombre": "Antorcha de thinner", "descripcion": "Un palo con trapo y thinner. Los prende.",
		"efecto": "10 de daño y los quema", "modelo": ["arma", "bat"], "tinte": Color(0.35, 0.2, 0.08), "dano": 10, "quema": true },
	"bate_puas": { "nombre": "Bate con alambre de púas", "descripcion": "Un bate forrado de alambre de púas. Pica.",
		"efecto": "17 de daño, empuja más", "modelo": ["arma", "bat_bloody"], "dano": 17, "empujon": 1.5 },
	"coa": { "nombre": "Coa afilada", "descripcion": "La coa del jardín, afilada en el esmeril.",
		"efecto": "20 de daño, llega más lejos", "modelo": ["arma", "axe"], "dano": 20, "alcance": 1.25 },
	"machete_canero": { "nombre": "Machete de cañero", "descripcion": "Largo y ligero, de zafra.",
		"efecto": "24 de daño, golpe más rápido", "modelo": ["arma", "machete"], "dano": 24, "velocidad": 1.25 },
	"marro": { "nombre": "Marro", "descripcion": "Un marro de albañil. Pesa, pero tumba de un golpe.",
		"efecto": "30 de daño, empuja mucho, golpe lento", "modelo": ["arma", "hammer"], "dano": 30, "empujon": 2.5, "velocidad": 0.8 },
	"macheton_84": { "nombre": "Machetón del 84", "descripcion": "Forjado con la varilla que brilla. La Chava no lo quiere ni tocar.",
		"efecto": "40 de daño, golpe rápido", "modelo": ["arma", "machete_bloody"], "tinte": Color(0.4, 0.9, 1.0), "dano": 40, "velocidad": 1.25 },
	"lanza_varilla": { "nombre": "Lanza de varilla", "descripcion": "Varilla del 84 con punta soldada. Llega lejos.",
		"efecto": "30 de daño, llega mucho más lejos", "modelo": ["arma", "axe_bloody"], "tinte": Color(0.35, 0.75, 0.85), "dano": 30, "alcance": 1.6 },
	"bate_cobalto": { "nombre": "Bate con clavos de cobalto", "descripcion": "Los clavos brillan en lo oscuro. Los avienta lejísimos.",
		"efecto": "32 de daño, empuja muchísimo", "modelo": ["arma", "bat_bloody"], "tinte": Color(0.3, 0.85, 0.95), "dano": 32, "empujon": 3.0 },
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	for id: String in TABLA:
		var d: Dictionary = TABLA[id]
		var modelo := _modelo(d["modelo"])
		if not ResourceLoader.exists(modelo):
			push_error("%s: no existe el modelo %s" % [id, modelo])
		var t := "[gd_resource type=\"Resource\" script_class=\"InventoryItemData\" load_steps=3 format=3]\n\n"
		t += "[ext_resource type=\"Script\" path=\"res://scripts/InventoryItemData.gd\" id=\"1_item\"]\n"
		t += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2_modelo\"]\n\n" % modelo
		t += "[resource]\nscript = ExtResource(\"1_item\")\n"
		t += "item_name = %s\n" % var_to_str(d["nombre"])
		t += "description = %s\n" % var_to_str(d["descripcion"])
		t += "inspection_model = ExtResource(\"2_modelo\")\n"
		t += "efecto = %s\n" % var_to_str(d["efecto"])
		for campo in ["curacion", "dano", "alcance", "empujon", "velocidad", "quema", "amuleto", "estampita", "recarga_segundo_aire", "tinte"]:
			if d.has(campo):
				t += "%s = %s\n" % [campo, var_to_str(d[campo])]
		var archivo := FileAccess.open(SALIDA + id + ".tres", FileAccess.WRITE)
		archivo.store_string(t)
		print("objeto ", id)
	quit()


func _modelo(m: Array) -> String:
	match m[0]:
		"arma":
			return ARMAS % m[1]
		"forma":
			return FORMAS % m[1]
	return OBJETOS % [m[1], m[1]]
