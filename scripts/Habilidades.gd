class_name Habilidades

# Las habilidades en las que se gastan los puntos que dan los tazos (Tazos.gd), como en
# Kingdom Hearts: subes de nivel una habilidad pagando su costo y lo puedes regresar. Las
# `bloqueada` solo se pueden subir con el tazo que las desbloquea (TazoData.desbloquea).
# Propuesta de AG; todos los numeros aqui arriba para afinarlos jugando.
#
# Ninguna lee al Personaje: el tono de piel no cambia nada del combate (CLAUDE.md).

enum Categoria { CUERPO, SOBREVIVIR, NEGOCIO }
const CATEGORIAS := ["Cuerpo", "Sobrevivir", "Negocio"]

# Lo que da cada nivel
const VIDA_POR_NIVEL := 0.1          # +10 % de vida maxima
const FUERZA_POR_NIVEL := 0.1        # +10 % de dano
const VELOCIDAD_POR_NIVEL := 0.1     # +10 % al caminar y correr
const ALCANCE_POR_NIVEL := 0.1       # +10 % de alcance del golpe
const SEGUNDO_AIRE_VIDA := 0.3       # fraccion de vida con la que te levantas
const BUEN_DIENTE_POR_NIVEL := 0.25  # +25 % de lo que cura la comida
const PIEL_DURA_POR_NIVEL := 0.15    # -15 % del dano de noche
const MAS_PESOS_POR_NIVEL := 1       # pesos de mas por zombi
const REGATEO_POR_NIVEL := 0.1       # -10 % en precios en pesos
const IMAN_RADIO := 2.5              # m a los que lo tirado se te junta solo
const MOCHILERO_POR_NIVEL := 1       # lugares de mas en el inventario
const PIES_DE_GATO_PERSIGUE := 0.85  # por nivel, multiplica Zombie.PERSIGUE (te notan desde mas cerca)
const PIES_DE_GATO_LEJOS := 3.0      # m por nivel que los sueltos aparecen mas lejos (Zombis)
const BUENA_RACHA_BOLSA := [1.0 / 8.0, 1.0 / 6.0, 1.0 / 4.0]   # bolsa especial al comprar Takis, por nivel

const ICONOS := "res://textures/habilidades/%s.png"   # 16 x 16, de tools/tazos/caras.gd

# id -> nombre, descripcion, categoria, niveles, costo de cada nivel, bloqueada
const LISTA := {
	"vida": { "nombre": "Aguante", "descripcion": "Más vida máxima: +10 % por nivel.",
		"categoria": Categoria.CUERPO, "niveles": 3, "costo": [1, 1, 2], "bloqueada": false },
	"fuerza": { "nombre": "Fuerza", "descripcion": "Pegas más fuerte: +10 % de daño por nivel, con arma o sin ella.",
		"categoria": Categoria.CUERPO, "niveles": 3, "costo": [1, 1, 2], "bloqueada": false },
	"velocidad": { "nombre": "Patas", "descripcion": "Caminas y corres más rápido: +10 % por nivel.",
		"categoria": Categoria.CUERPO, "niveles": 3, "costo": [1, 1, 2], "bloqueada": false },
	"alcance": { "nombre": "Brazo largo", "descripcion": "Tu golpe llega más lejos: +10 % por nivel.",
		"categoria": Categoria.CUERPO, "niveles": 3, "costo": [1, 1, 1], "bloqueada": false },
	"segundo_aire": { "nombre": "Segundo aire", "descripcion": "Una vez por noche, en vez de desmayarte te levantas con 30 % de vida.",
		"categoria": Categoria.SOBREVIVIR, "niveles": 1, "costo": [3], "bloqueada": true },
	"buen_diente": { "nombre": "Buen diente", "descripcion": "La comida y las medicinas te curan más: +25 % por nivel.",
		"categoria": Categoria.SOBREVIVIR, "niveles": 2, "costo": [1, 1], "bloqueada": false },
	"piel_dura": { "nombre": "Piel dura", "descripcion": "De noche los zombis te hacen menos daño: -15 % por nivel.",
		"categoria": Categoria.SOBREVIVIR, "niveles": 2, "costo": [1, 2], "bloqueada": false },
	"pies_de_gato": { "nombre": "Pies de gato", "descripcion": "Los zombis te notan más tarde: aparecen más lejos y, cerca del refugio, se van por ti desde más cerca. Los cazadores y el jefe no se dejan.",
		"categoria": Categoria.SOBREVIVIR, "niveles": 2, "costo": [1, 2], "bloqueada": true },
	"mas_pesos": { "nombre": "Bolsillos", "descripcion": "Cada zombi que revientas suelta un peso más por nivel.",
		"categoria": Categoria.NEGOCIO, "niveles": 2, "costo": [1, 1], "bloqueada": false },
	"regateo": { "nombre": "Regateo", "descripcion": "Lo que se paga en pesos te sale 10 % más barato por nivel.",
		"categoria": Categoria.NEGOCIO, "niveles": 2, "costo": [1, 2], "bloqueada": false },
	"mochilero": { "nombre": "Mochilero", "descripcion": "Te cabe una cosa más por nivel, con mochila o sin ella.",
		"categoria": Categoria.NEGOCIO, "niveles": 2, "costo": [1, 2], "bloqueada": false },
	"buena_racha": { "nombre": "Buena racha", "descripcion": "Te salen más bolsas especiales al comprar Takis.",
		"categoria": Categoria.NEGOCIO, "niveles": 2, "costo": [1, 1], "bloqueada": false },
	"iman": { "nombre": "Imán", "descripcion": "Lo que está tirado cerca se te junta solo, sin agacharte.",
		"categoria": Categoria.NEGOCIO, "niveles": 1, "costo": [2], "bloqueada": true },
	"ojo_halcon": { "nombre": "Ojo de halcón", "descripcion": "Ves a los zombis en el minimapa como puntos rojos.",
		"categoria": Categoria.NEGOCIO, "niveles": 1, "costo": [2], "bloqueada": true },
}


# En el orden del menu: por categoria y como estan arriba
static func orden() -> Array[String]:
	var ids: Array[String] = []
	for categoria in Categoria.values():
		for id: String in LISTA:
			if LISTA[id]["categoria"] == categoria:
				ids.append(id)
	return ids


static func dato(id: String) -> Dictionary:
	return LISTA.get(id, {})


# Lo que cuesta subir todo al maximo; debe ser lo que da el album completo (Tazos.puntos_coleccion)
static func costo_total() -> int:
	var total := 0
	for id: String in LISTA:
		for costo: int in LISTA[id]["costo"]:
			total += costo
	return total


static func icono(id: String) -> Texture2D:
	var ruta := ICONOS % id
	return load(ruta) if ResourceLoader.exists(ruta) else null


# Lo que hace la habilidad a ese nivel, con numeros de verdad cuando hay `base` (lo que da
# Player.valores_sin_tazos: vida, dano, velocidad, alcance, lugares, persigue). Sin base,
# en porcentajes.
static func efecto_texto(id: String, nivel: int, base: Dictionary) -> String:
	match id:
		"vida":
			if base.has("vida"):
				return "Vida máxima: %d" % roundi(base["vida"] * (1.0 + nivel * VIDA_POR_NIVEL))
			return "Vida máxima: +%d %%" % roundi(nivel * VIDA_POR_NIVEL * 100.0)
		"fuerza":
			if base.has("dano"):
				return "Daño por golpe: %d" % maxi(roundi(base["dano"] * (1.0 + nivel * FUERZA_POR_NIVEL)), 1)
			return "Daño: +%d %%" % roundi(nivel * FUERZA_POR_NIVEL * 100.0)
		"velocidad":
			if base.has("velocidad"):
				return "Al caminar: %.1f m/s" % (base["velocidad"] * (1.0 + nivel * VELOCIDAD_POR_NIVEL))
			return "Velocidad: +%d %%" % roundi(nivel * VELOCIDAD_POR_NIVEL * 100.0)
		"alcance":
			if base.has("alcance"):
				return "Alcance: %.2f m" % (base["alcance"] * (1.0 + nivel * ALCANCE_POR_NIVEL))
			return "Alcance: +%d %%" % roundi(nivel * ALCANCE_POR_NIVEL * 100.0)
		"segundo_aire":
			return "Te levantas con %d %% de vida" % roundi(SEGUNDO_AIRE_VIDA * 100.0) if nivel > 0 else "Apagada"
		"buen_diente":
			return "La comida cura: %d %%" % roundi((1.0 + nivel * BUEN_DIENTE_POR_NIVEL) * 100.0)
		"piel_dura":
			return "Daño de noche: %d %%" % roundi((1.0 - nivel * PIEL_DURA_POR_NIVEL) * 100.0)
		"pies_de_gato":
			var cerca := "Te notan desde: %.1f m" % (base["persigue"] * pow(PIES_DE_GATO_PERSIGUE, nivel)) if base.has("persigue") else ""
			var lejos := "aparecen %d m más lejos" % roundi(nivel * PIES_DE_GATO_LEJOS)
			return lejos if cerca == "" else cerca + ", " + lejos
		"mas_pesos":
			return "Pesos por zombi: +%d" % (nivel * MAS_PESOS_POR_NIVEL)
		"regateo":
			return "Precios: %d %%" % roundi((1.0 - nivel * REGATEO_POR_NIVEL) * 100.0)
		"mochilero":
			if base.has("lugares"):
				return "Lugares: %d" % (base["lugares"] + nivel * MOCHILERO_POR_NIVEL)
			return "Lugares: +%d" % (nivel * MOCHILERO_POR_NIVEL)
		"buena_racha":
			return "Bolsa especial: 1 de cada %d Takis" % roundi(1.0 / BUENA_RACHA_BOLSA[nivel])
		"iman":
			return "Junta lo que está a %.1f m" % IMAN_RADIO if nivel > 0 else "Apagada"
		"ojo_halcon":
			return "Zombis en el minimapa" if nivel > 0 else "Apagada"
	return ""
