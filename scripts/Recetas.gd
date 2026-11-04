class_name Recetas

# Lo que hace La Chava en su yonke (Taller.gd), como la sintesis de Kingdom Hearts 1: seis
# juegos que se abren segun cuantas cosas distintas has hecho (UMBRALES; el sexto pide todas
# las de los cinco primeros). Cada receta pide materiales de los Tiliches (Materiales.gd) y unos
# pesos; las del sexto ademas su plano. Propuesta de AG; los numeros son para afinarse jugando.
#
# `resultado`: el .tres de resources/taller/ (lo escribe tools/taller/objetos.gd), o
# "material:<id>" para lo que va a los Tiliches.

const UMBRALES := [0, 3, 9, 15, 21]   # cosas distintas hechas para abrir los juegos 1-5
const JUEGOS := 6
const OBJETOS := "res://resources/taller/%s.tres"

const LISTA := {
	# --- Juego 1 ---
	"caldo_pollo": { "juego": 1, "pesos": 20, "materiales": { "agua_sucia": 2, "pabilo": 1, "cerillo": 1 } },
	"remedio_abuela": { "juego": 1, "pesos": 30, "materiales": { "pabilo": 2, "agua_sucia": 1 } },
	"pulsera_hilo_rojo": { "juego": 1, "pesos": 25, "materiales": { "hilacha": 2, "pabilo": 1 } },
	"cadena_fantasia": { "juego": 1, "pesos": 25, "materiales": { "rebaba": 2, "hilacha": 1 } },
	"rodilleras": { "juego": 1, "pesos": 40, "materiales": { "cerillo": 3, "agua_sucia": 3, "alambrito": 3 } },
	"tubo": { "juego": 1, "pesos": 30, "materiales": { "rebaba": 3, "varilla_corta": 1 } },
	"medalla_san_judas": { "juego": 1, "pesos": 150, "materiales": { "marca_cazador": 1, "ojo_turba": 1, "ceniza": 1, "tapa_tinaco": 1, "varilla_84": 3 } },
	# --- Juego 2 ---
	"suero_oral": { "juego": 2, "pesos": 35, "materiales": { "agua_llave": 2, "pabilo": 1 } },
	"lampara": { "juego": 2, "pesos": 45, "materiales": { "alambrito": 2, "cable": 1, "varilla_corta": 1 } },
	"escapulario": { "juego": 2, "pesos": 40, "materiales": { "pabilo": 3, "hilacha": 1, "varilla_corta": 1 } },
	"pulsera_san_benito": { "juego": 2, "pesos": 50, "materiales": { "alambrito": 3, "tuerca": 1, "trapo": 4 } },
	"cadena_gruesa": { "juego": 2, "pesos": 50, "materiales": { "rebaba": 3, "tuerca": 1, "trapo": 1 } },
	"coderas": { "juego": 2, "pesos": 60, "materiales": { "thinner": 3, "agua_llave": 3, "cable": 3 } },
	"antorcha": { "juego": 2, "pesos": 45, "materiales": { "thinner": 2, "trapo": 2, "varilla_corta": 1 } },
	"bate_puas": { "juego": 2, "pesos": 55, "materiales": { "tuerca": 3, "alambrito": 3 } },
	# --- Juego 3 ---
	"estampita_san_expedito": { "juego": 3, "pesos": 80, "materiales": { "thinner": 2, "agua_llave": 2, "cable": 2, "varilla_armada": 4 } },
	"rosario": { "juego": 3, "pesos": 60, "materiales": { "trapo": 2, "veladora": 2, "varilla_corta": 2 } },
	"medalla_virgen": { "juego": 3, "pesos": 90, "materiales": { "veladora": 5, "tuerca": 3, "alambron": 1 } },
	"faja_cargador": { "juego": 3, "pesos": 90, "materiales": { "trapo": 5, "tuerca": 3, "ceniza": 1 } },
	"cadena_oro": { "juego": 3, "pesos": 100, "materiales": { "tuerca": 5, "thinner": 3, "chancla_oro": 1 } },
	"varilla_armada": { "juego": 3, "pesos": 30, "resultado": "material:varilla_armada", "materiales": { "varilla_corta": 5, "alambron": 1, "baba_verde": 1 } },
	"coa": { "juego": 3, "pesos": 90, "materiales": { "tuerca": 5, "trapo": 3, "varilla_armada": 1 } },
	# --- Juego 4 ---
	"te_virgen": { "juego": 4, "pesos": 120, "materiales": { "agua_destilada": 2, "agua_bendita": 1, "plata_taxco": 1 } },
	"estampita_santo_nino": { "juego": 4, "pesos": 150, "materiales": { "cuero": 3, "agua_bendita": 3, "tapa_tinaco": 2, "plata_taxco": 1 } },
	"ojo_venado": { "juego": 4, "pesos": 150, "materiales": { "cuero": 3, "marca_cazador": 1, "varilla_84": 1 } },
	"herradura": { "juego": 4, "pesos": 160, "materiales": { "thinner": 5, "agua_llave": 5, "cable": 5, "cobre": 1, "plata_taxco": 1 } },
	"brazalete_cobre": { "juego": 4, "pesos": 140, "materiales": { "cerillo": 5, "agua_sucia": 5, "alambrito": 5, "cobre": 1, "baba_verde": 1 } },
	"corona_lata": { "juego": 4, "pesos": 180, "materiales": { "cuero": 5, "engrane": 1, "cobre": 1, "ceniza": 3 } },
	"machete_canero": { "juego": 4, "pesos": 150, "materiales": { "engrane": 3, "cuero": 3, "varilla_armada": 1, "marca_cazador": 1 } },
	# --- Juego 5 ---
	"varilla_84": { "juego": 5, "pesos": 60, "resultado": "material:varilla_84", "materiales": { "rebaba": 9, "polvo_serenol": 1, "varilla_armada": 2 } },
	"milagro_tinaco": { "juego": 5, "pesos": 200, "materiales": { "agua_destilada": 5, "agua_bendita": 3, "polvo_serenol": 2, "plata_taxco": 1 } },
	"estampita_san_miguel": { "juego": 5, "pesos": 200, "materiales": { "engrane": 5, "cuero": 3, "casco_gela": 2, "plata_taxco": 1 } },
	"chamarra_nocturno": { "juego": 5, "pesos": 220, "materiales": { "hilacha": 5, "cuero": 3, "casco_gela": 1, "varilla_corta": 5 } },
	"medalla_gela": { "juego": 5, "pesos": 250, "materiales": { "casco_gela": 1, "cobalto": 1, "diente_jefe": 1, "plata_taxco": 1, "varilla_84": 3 } },
	"liston_virgen": { "juego": 5, "pesos": 250, "materiales": { "thinner": 5, "agua_llave": 5, "cable": 5, "polvo_serenol": 1, "cobalto": 3 } },
	"marro": { "juego": 5, "pesos": 230, "materiales": { "engrane": 5, "varilla_84": 1, "ojo_turba": 2, "plata_taxco": 1 } },
	# --- Juego 6: las ultimas, cada una con su plano ---
	"macheton_84": { "juego": 6, "pesos": 500, "plano": "macheton_84", "materiales": { "engrane": 5, "baba_verde": 5, "cobalto": 3, "diente_jefe": 3, "varilla_84": 3 } },
	"lanza_varilla": { "juego": 6, "pesos": 400, "plano": "lanza_varilla", "materiales": { "varilla_84": 3, "ojo_turba": 3, "marca_cazador": 3, "alambron": 5 } },
	"bate_cobalto": { "juego": 6, "pesos": 400, "plano": "bate_cobalto", "materiales": { "ceniza": 3, "tapa_tinaco": 3, "cobalto": 3, "chancla_oro": 5 } },
}

# Los planos (Taller.planos): nombre de cada uno
const PLANOS := {
	"macheton_84": "Plano del Machetón del 84",
	"lanza_varilla": "Plano de la Lanza de varilla",
	"bate_cobalto": "Plano del Bate con clavos de cobalto",
}


static func dato(id: String) -> Dictionary:
	return LISTA.get(id, {})


# Todas, por juego y como estan arriba
static func orden() -> Array[String]:
	var ids: Array[String] = []
	for juego in range(1, JUEGOS + 1):
		for id: String in LISTA:
			if LISTA[id]["juego"] == juego:
				ids.append(id)
	return ids


static func de_juego(juego: int) -> Array[String]:
	var ids: Array[String] = []
	for id: String in LISTA:
		if LISTA[id]["juego"] == juego:
			ids.append(id)
	return ids


# "material:<id>" -> el id del material; si no, ""
static func material_resultado(id: String) -> String:
	var r: String = dato(id).get("resultado", "")
	return r.trim_prefix("material:") if r.begins_with("material:") else ""


static func objeto(id: String) -> InventoryItemData:
	if material_resultado(id) != "":
		return null
	var ruta := OBJETOS % id
	return load(ruta) if ResourceLoader.exists(ruta) else null


static func nombre(id: String) -> String:
	var m := material_resultado(id)
	if m != "":
		return Materiales.nombre(m)
	var o := objeto(id)
	return o.item_name if o else id
