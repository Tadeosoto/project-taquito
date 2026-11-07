extends Node

# Autoload `Mejoras`: el contenido que se compra en la tienda tipo "punto" de la carrera y
# que el godmode pone al maximo. Es la unica fuente: una mejora nueva aqui aparece sola en
# el menu y en `maximo()`. Los factores los leen Player/Inventory; `activo` los apaga fuera
# de los tests.

signal cambio
signal compra(id: String, costo: int, nivel: int)

const ESTELA := preload("res://scripts/EstelaBarrido.gd")

enum Cat { MOVIMIENTOS, CUERPO, BUFFS }
const CATEGORIAS := ["Movimientos", "Cuerpo", "Buffs"]

# id, nombre, categoria, tipo (movimiento/stat/buff), niveles, costos, detalle
const CATALOGO := [
	{"id": "cargado", "nombre": "Golpe cargado", "categoria": Cat.MOVIMIENTOS, "tipo": "movimiento",
		"niveles": 1, "costos": [250], "detalle": "Deja apretado el ataque y suelta: tajo de arriba abajo."},
	{"id": "giro", "nombre": "Golpe giratorio", "categoria": Cat.MOVIMIENTOS, "tipo": "movimiento",
		"niveles": 1, "costos": [300], "detalle": "Pegar en el aire: espadazo giratorio que cae al piso."},
	{"id": "estela", "nombre": "Estela del protagonista", "categoria": Cat.MOVIMIENTOS, "tipo": "movimiento",
		"niveles": 1, "costos": [400], "detalle": "Estela del personaje y +10 % de daño."},
	{"id": "vida", "nombre": "Aguante", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 3, "costos": [100, 180, 280], "detalle": "+10 % de vida máxima por nivel."},
	{"id": "fuerza", "nombre": "Fuerza", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 3, "costos": [120, 200, 300], "detalle": "+10 % de daño por nivel."},
	{"id": "velocidad", "nombre": "Patas", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 3, "costos": [100, 180, 280], "detalle": "+10 % de velocidad por nivel."},
	{"id": "alcance", "nombre": "Brazo largo", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 3, "costos": [90, 160, 240], "detalle": "+10 % de alcance del golpe por nivel."},
	{"id": "piel_dura", "nombre": "Piel dura", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 2, "costos": [150, 260], "detalle": "−15 % del daño recibido por nivel."},
	{"id": "buen_diente", "nombre": "Buen diente", "categoria": Cat.CUERPO, "tipo": "stat",
		"niveles": 2, "costos": [80, 150], "detalle": "+25 % a lo que curan las curas por nivel."},
	{"id": "buff_dano", "nombre": "Taco de pastor especial", "categoria": Cat.BUFFS, "tipo": "buff",
		"niveles": 1, "costos": [90], "detalle": "+20 % de daño durante la noche que va."},
	{"id": "buff_velocidad", "nombre": "Café de olla", "categoria": Cat.BUFFS, "tipo": "buff",
		"niveles": 1, "costos": [70], "detalle": "+20 % de velocidad durante la noche que va."},
	{"id": "buff_defensa", "nombre": "Té de tejuino", "categoria": Cat.BUFFS, "tipo": "buff",
		"niveles": 1, "costos": [110], "detalle": "−20 % del daño recibido durante la noche que va."},
]

var activo := false
var niveles := {}       # id -> nivel
var buffs := {}         # id -> true (para la noche que va)


func reiniciar() -> void:
	niveles.clear()
	buffs.clear()
	cambio.emit()


# El godmode: todo el catalogo al maximo, buffs incluidos, para medir el kit completo.
func maximo() -> void:
	for dato: Dictionary in CATALOGO:
		if dato["tipo"] == "buff":
			buffs[dato["id"]] = true
		else:
			niveles[dato["id"]] = dato["niveles"]
	cambio.emit()


# Al terminar la noche se consumen los buffs (gane o pierda).
func terminar_noche() -> void:
	buffs.clear()
	cambio.emit()


func dato(id: String) -> Dictionary:
	for entrada: Dictionary in CATALOGO:
		if entrada["id"] == id:
			return entrada
	return {}


func nivel(id: String) -> int:
	return niveles.get(id, 0)


func tiene(id: String) -> bool:
	return nivel(id) > 0 or buffs.has(id)


func al_maximo(id: String) -> bool:
	var d := dato(id)
	return not d.is_empty() and (nivel(id) >= d["niveles"] or (d["tipo"] == "buff" and buffs.has(id)))


func costo_siguiente(id: String) -> int:
	var d := dato(id)
	if d.is_empty() or al_maximo(id):
		return -1
	return d["costos"][nivel(id)]


# Compra con pesos. Regresa true si aplico.
func comprar(id: String) -> bool:
	var d := dato(id)
	if d.is_empty() or al_maximo(id):
		return false
	var costo := costo_siguiente(id)
	if costo < 0:
		return false
	var cartera := get_node_or_null("/root/Cartera")
	if cartera == null or cartera.pesos < costo:
		return false
	cartera.pesos -= costo
	if d["tipo"] == "buff":
		buffs[id] = true
	else:
		niveles[id] = nivel(id) + 1
	var registro := get_node_or_null("/root/Registro")
	if registro:
		registro.mejora(id, costo, nivel(id))
	compra.emit(id, costo, nivel(id))
	cambio.emit()
	return true


# --- Efectos que lee el resto del juego ---

func factor_vida() -> float:
	return 1.0 + nivel("vida") * 0.10


func factor_dano() -> float:
	var f := 1.0 + nivel("fuerza") * 0.10
	if tiene("estela"):
		f += 0.10
	if buffs.has("buff_dano"):
		f += 0.20
	return f


func factor_velocidad() -> float:
	return 1.0 + nivel("velocidad") * 0.10 + (0.20 if buffs.has("buff_velocidad") else 0.0)


func factor_alcance() -> float:
	return 1.0 + nivel("alcance") * 0.10


func factor_dano_recibido() -> float:
	return (1.0 - nivel("piel_dura") * 0.15) * (0.80 if buffs.has("buff_defensa") else 1.0)


func factor_curacion() -> float:
	return 1.0 + nivel("buen_diente") * 0.25


# Aplica movimientos, estela y stats al jugador (los factores los toma `aplicar_habilidades`).
func aplicar_en_jugador(jugador: Node) -> void:
	if jugador == null:
		return
	var personaje := get_node_or_null("/root/Personaje")
	if personaje:
		personaje.mejora_estela = tiene("estela")
	ESTELA.estilo = personaje.estela() if (personaje and personaje.mejora_estela) else ESTELA.Estilo.NORMAL
	Player.golpe_cargado = tiene("cargado")
	Player.giro_aereo = tiene("giro")
	if jugador.has_method("aplicar_habilidades"):
		jugador.aplicar_habilidades()
