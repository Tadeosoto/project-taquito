extends Node

# Autoload `Taller`: el rango del yonke de La Chava y sus planos, que se quedan entre partidas
# (user://taller.cfg, seccion "taller"; la vitrina de trofeos la guarda Tiliches.gd en el mismo
# archivo). El rango es cuantas cosas distintas has hecho (Recetas.UMBRALES abre los juegos,
# como en Kingdom Hearts 1). Hacer algo gasta materiales de los Tiliches y pesos de la Cartera.
# Propuesta de AG (docs/especificaciones.md 4.13).

signal cambio
signal juego_nuevo(juego: int)

const ARCHIVO := "user://taller.cfg"
const SECCION := "taller"

var hechos := {}     # id de receta -> veces que la hiciste (cuenta para el rango la primera)
var planos := {}     # id de plano -> true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	hechos = cfg.get_value(SECCION, "hechos", {})
	for id in cfg.get_value(SECCION, "planos", []):
		planos[id] = true


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO)   # la vitrina se queda
	cfg.set_value(SECCION, "hechos", hechos)
	cfg.set_value(SECCION, "planos", planos.keys())
	cfg.save(ARCHIVO)


func rango() -> int:
	return hechos.size()


func abierto(juego: int) -> bool:
	if juego <= Recetas.UMBRALES.size():
		return rango() >= Recetas.UMBRALES[juego - 1]
	# El sexto: todas las de los primeros cinco
	for id in Recetas.orden():
		if Recetas.dato(id)["juego"] < juego and not hechos.has(id):
			return false
	return true


func juegos_abiertos() -> int:
	var n := 0
	for j in range(1, Recetas.JUEGOS + 1):
		if abierto(j):
			n = j
	return n


# Cuantas faltan para el siguiente juego, o -1 si ya estan todos
func faltan_para_siguiente() -> int:
	var siguiente := juegos_abiertos() + 1
	if siguiente > Recetas.JUEGOS:
		return -1
	if siguiente <= Recetas.UMBRALES.size():
		return Recetas.UMBRALES[siguiente - 1] - rango()
	var faltan := 0
	for id in Recetas.orden():
		if Recetas.dato(id)["juego"] < siguiente and not hechos.has(id):
			faltan += 1
	return faltan


# Lo que cobra La Chava por hacerla. Regateo (Tazos.gd) le baja como a todo lo que se paga
# en pesos; el tono de piel no entra aqui (eso es de las tiendas, Interior._factor)
func costo(id: String) -> int:
	var tazos := get_node_or_null("/root/Tazos")
	return roundi(Recetas.dato(id).get("pesos", 0) * (tazos.factor_precio() if tazos else 1.0))


# Por que no se puede hacer, o "" si se puede: "cerrado", "plano", "materiales", "pesos", "lleno"
func por_que_no(id: String) -> String:
	var receta := Recetas.dato(id)
	if receta.is_empty() or not abierto(receta["juego"]):
		return "cerrado"
	if receta.has("plano") and not planos.has(receta["plano"]):
		return "plano"
	if not get_node("/root/Tiliches").alcanza(receta["materiales"]):
		return "materiales"
	if get_node("/root/Cartera").pesos < costo(id):
		return "pesos"
	if Recetas.material_resultado(id) == "" and not get_node("/root/Inventory").cabe(Recetas.objeto(id)):
		return "lleno"
	if Recetas.material_resultado(id) != "" and not get_node("/root/Tiliches").puede_guardar(Recetas.material_resultado(id)):
		return "cangurera"
	return ""


# La hace: gasta, la da (al inventario o a los Tiliches) y sube el rango si es nueva. Regresa lo
# mismo que por_que_no
func hacer(id: String) -> String:
	var razon := por_que_no(id)
	if razon != "":
		return razon
	var receta := Recetas.dato(id)
	var antes := juegos_abiertos()
	get_node("/root/Tiliches").gastar(receta["materiales"])
	get_node("/root/Cartera").pesos -= costo(id)
	var material := Recetas.material_resultado(id)
	if material != "":
		get_node("/root/Tiliches").dar(material, 1, false)
	else:
		get_node("/root/Inventory").add_item(Recetas.objeto(id))
	hechos[id] = hechos.get(id, 0) + 1
	_guardar()
	var despues := juegos_abiertos()
	for j in range(antes + 1, despues + 1):
		juego_nuevo.emit(j)
	cambio.emit()
	return ""


func dar_plano(id: String) -> void:
	if planos.has(id) or not Recetas.PLANOS.has(id):
		return
	planos[id] = true
	_guardar()
	cambio.emit()


# Borra el rango y los planos (tecla de prueba del safehouse). Al reiniciar la partida NO se
# llama: el taller se acuerda de ti
func olvidar() -> void:
	hechos.clear()
	planos.clear()
	_guardar()
	cambio.emit()


# Sube el rango sin gastar nada (tecla de prueba del safehouse): marca como hechas las del
# juego abierto mas alto hasta abrir el siguiente
func subir_rango() -> void:
	var siguiente := juegos_abiertos() + 1
	for id in Recetas.orden():
		if abierto(siguiente):
			break
		if Recetas.dato(id)["juego"] < siguiente and not hechos.has(id):
			hechos[id] = 1
	_guardar()
	juego_nuevo.emit(juegos_abiertos())
	cambio.emit()
