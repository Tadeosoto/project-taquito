extends Node

# Autoload `Guardado`: la partida en disco (user://partida.cfg), ahora que el juego no se acaba
# (docs/especificaciones.md 1.2, "Qué se guarda"). Sin class_name: el autoload ya se llama asi.
#
# Guarda lo de todos los autoloads de la partida (inventario, dinero, vida, pedazos de mapa,
# tazos, tiliches, amuletos, baul, fichas, la noche y la bolsa del desmayo, lo de la campana de
# Misiones y los jefes vencidos de PasoJefe), la escena del mapa,
# donde estas y la hora. Lo que ya se guardaba solo (Personaje, Libreta, Taller, la vitrina y el
# record de Noches) sigue en sus archivos. No se guardan: los zombis, lo tirado en el piso, las
# balas en el cargador ni el deterioro.
#
# Cuando: al amanecer (Partida), al volver de una pelea de jefe (PasoJefe), al cruzar
# una reja (PasoColonia) y al cerrar la ventana. Partida nueva (pantalla de inicio) lo borra.
#
# Los objetos se guardan por su ruta (resource_path): nadie modifica los InventoryItemData.

const ARCHIVO := "user://partida.cfg"
const VERSION := 1
# Lo que Partida nueva regresa a como empieza el juego (antes Partida._otra_vez)
const REINICIAR := ["Inventory", "Salud", "Cartera", "PiezasMapa", "Misiones", "Tazos", "Tiliches", "Bonos", "Baul", "Fichas", "Noches"]
const MAPA := "res://scenes/map_test.tscn"

# Lo de la campana (Misiones) que se guarda tal cual: misiones hechas para siempre (las que enseñan
# ataques, los jefes), la guardia de la reja, la antena, el Decreto 47, el desgaste de la reja...
const CAMPANA := ["_hechas_siempre", "puntos_vistos", "guardias_reja", "reja_guardia", "antena_instalada",
	"bodega_gela_abierta", "palacio_abierto", "decreto_47", "reja_desgaste", "reja_enfriamiento", "tinaco_perdido",
	"pagos_especiales"]

var _llegada := Transform3D()
var _hay_llegada := false
# Las escenas de juego: solo en estas se guarda solo (el safehouse y las pruebas no pisan la
# partida de verdad; su tecla de prueba pasa `forzar`)
const ESCENAS := ["res://scenes/map_test.tscn", "res://scenes/mapa.tscn"]


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()


func hay_partida() -> bool:
	return FileAccess.file_exists(ARCHIVO)


# Borra la partida y deja todo como al empezar (el record de noches se queda)
func nueva() -> void:
	if hay_partida():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	for autoload: String in REINICIAR:
		var nodo := get_node_or_null("/root/" + autoload)
		if nodo and nodo.has_method("reiniciar"):
			nodo.reiniciar()


# --- Guardar ---

# Solo desde una escena de juego (ESCENAS, con Partida) o desde la arena a la que se llego del
# mapa; en las de prueba no hace nada salvo con `forzar`. Regresa si guardo
func guardar(forzar := false) -> bool:
	var arbol := get_tree()
	if arbol == null or arbol.current_scene == null:
		return false
	var escena := arbol.current_scene.scene_file_path
	var donde: Transform3D
	var hora := -1.0
	if PasoJefe.desde_juego:
		# En una pelea de jefe: se guarda como si estuvieras en su entrada del mapa
		escena = PasoJefe.escena_origen
		donde = Transform3D(Basis(), PasoJefe.regreso if PasoJefe.regreso != Vector3.INF else Vector3.ZERO)
		hora = PasoJefe.hora_origen
	else:
		if arbol.get_first_node_in_group("partida") == null:
			return false
		if not forzar and not escena in ESCENAS:
			return false
		var jugador := arbol.get_first_node_in_group("jugador") as Node3D
		if jugador == null:
			return false
		donde = jugador.global_transform
		var ciclo := arbol.get_first_node_in_group("ciclo") as Ciclo
		if ciclo:
			hora = ciclo.tiempo() / maxf(ciclo.dia_duracion + ciclo.noche_duracion, 0.001)
	var cfg := ConfigFile.new()
	cfg.set_value("partida", "version", VERSION)
	cfg.set_value("partida", "escena", escena)
	cfg.set_value("partida", "donde", donde)
	cfg.set_value("partida", "hora", hora)
	_guardar_autoloads(cfg)
	var error := cfg.save(ARCHIVO)
	if error != OK:
		push_warning("Guardado: no pude escribir %s (%d)" % [ARCHIVO, error])
		return false
	return true


func _guardar_autoloads(cfg: ConfigFile) -> void:
	var inv := get_node("/root/Inventory")
	cfg.set_value("inventario", "items", rutas(inv.items))
	cfg.set_value("inventario", "cantidades", Array(inv.cantidades))
	cfg.set_value("inventario", "mochila", _ruta(inv.mochila))
	cfg.set_value("inventario", "equipada", _ruta(inv.equipada))
	cfg.set_value("inventario", "cangurera", _ruta(inv.cangurera))
	var cartera := get_node("/root/Cartera")
	cfg.set_value("cartera", "pesos", cartera.pesos)
	cfg.set_value("cartera", "agua", cartera.agua)
	cfg.set_value("salud", "vida", get_node("/root/Salud").vida)
	cfg.set_value("piezas", "zonas", get_node("/root/PiezasMapa")._zonas.keys())
	var tazos := get_node("/root/Tazos")
	cfg.set_value("tazos", "puntos", tazos.puntos)
	cfg.set_value("tazos", "niveles", tazos.niveles)
	cfg.set_value("tazos", "desbloqueadas", tazos.desbloqueadas.keys())
	cfg.set_value("tazos", "coleccion", Array(tazos.coleccion))
	cfg.set_value("tazos", "series_premiadas", tazos.series_premiadas.keys())
	cfg.set_value("tazos", "comunes_nuevos", tazos.comunes_nuevos)
	cfg.set_value("tiliches", "cantidades", get_node("/root/Tiliches").cantidades)
	var bonos := get_node("/root/Bonos")
	cfg.set_value("bonos", "puestos", bonos.puestos.map(func(a) -> String: return _ruta(a)))
	cfg.set_value("bonos", "estampitas", bonos.estampitas)
	var baul := get_node("/root/Baul")
	cfg.set_value("baul", "items", rutas(baul.items))
	cfg.set_value("baul", "cantidades", Array(baul.cantidades))
	cfg.set_value("baul", "saqueadas", baul.saqueadas)
	var fichas := get_node("/root/Fichas")
	cfg.set_value("fichas", "fichas", fichas.fichas)
	cfg.set_value("fichas", "permiso", fichas.permiso)
	cfg.set_value("fichas", "vip", fichas.vip)
	cfg.set_value("fichas", "desaguadora", fichas.desaguadora)
	get_node("/root/Noches").guardar_en(cfg)
	# La campana (Misiones de Juanjo): lo que ya se hizo para siempre y lo que cambio en el mundo. La
	# activa se suelta (reiniciar); las aceptadas del diario si se quedan
	var misiones := get_node("/root/Misiones")
	cfg.set_value("misiones", "aceptadas", misiones.aceptadas.map(func(m) -> String: return m.id))
	for campo: String in CAMPANA:
		cfg.set_value("misiones", campo, misiones.get(campo))
	cfg.set_value("misiones", "jefes_vencidos", PasoJefe.vencidos.keys())


# --- Cargar ---

# Continuar (pantalla de inicio): pone todo en los autoloads y deja listo donde aparecer y la
# hora para la escena (`tomar_llegada`, que lee Partida; Ciclo). Regresa la escena a cargar, o "" si no hay
func cargar() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return ""
	for autoload: String in REINICIAR:
		var nodo := get_node_or_null("/root/" + autoload)
		if nodo and nodo.has_method("reiniciar"):
			nodo.reiniciar()
	_cargar_autoloads(cfg)
	var escena: String = cfg.get_value("partida", "escena", MAPA)
	if not ResourceLoader.exists(escena):
		escena = MAPA
	_llegada = cfg.get_value("partida", "donde", Transform3D())
	_hay_llegada = _llegada != Transform3D()
	PasoColonia.fraccion_del_dia = float(cfg.get_value("partida", "hora", -1.0))
	return escena


# Donde aparecer al Continuar, una sola vez (Partida._ready); null si no hay
func tomar_llegada() -> Variant:
	if not _hay_llegada:
		return null
	_hay_llegada = false
	return _llegada


func _cargar_autoloads(cfg: ConfigFile) -> void:
	var inv := get_node("/root/Inventory")
	inv.items.clear()
	inv.cantidades.clear()
	var cuantos: Array = cfg.get_value("inventario", "cantidades", [])
	var lista: Array = cfg.get_value("inventario", "items", [])
	for i in lista.size():
		var item := _objeto(lista[i])
		if item:
			inv.items.append(item)
			inv.cantidades.append(int(cuantos[i]) if i < cuantos.size() else 1)
	inv.mochila = _objeto(cfg.get_value("inventario", "mochila", ""))
	inv.equipada = _objeto(cfg.get_value("inventario", "equipada", ""))
	inv.cangurera = _objeto(cfg.get_value("inventario", "cangurera", ""))
	inv.inventory_changed.emit()
	var cartera := get_node("/root/Cartera")
	cartera.pesos = int(cfg.get_value("cartera", "pesos", cartera.pesos))
	cartera.agua = int(cfg.get_value("cartera", "agua", cartera.agua))
	var salud := get_node("/root/Salud")
	salud.vida = int(cfg.get_value("salud", "vida", salud.vida))
	var piezas := get_node("/root/PiezasMapa")
	for zona in cfg.get_value("piezas", "zonas", []):
		piezas.dar(int(zona))
	var tazos := get_node("/root/Tazos")
	tazos.puntos = int(cfg.get_value("tazos", "puntos", 0))
	tazos.niveles = (cfg.get_value("tazos", "niveles", {}) as Dictionary).duplicate()
	for id in cfg.get_value("tazos", "desbloqueadas", []):
		tazos.desbloqueadas[id] = true
	for id in cfg.get_value("tazos", "coleccion", []):
		tazos.coleccion.append(String(id))
	for serie in cfg.get_value("tazos", "series_premiadas", []):
		tazos.series_premiadas[int(serie)] = true
	tazos.comunes_nuevos = int(cfg.get_value("tazos", "comunes_nuevos", 0))
	tazos.cambio.emit()
	var tiliches := get_node("/root/Tiliches")
	var materiales: Dictionary = cfg.get_value("tiliches", "cantidades", {})
	for id: String in materiales:
		tiliches.cantidades[id] = int(materiales[id])
	tiliches.cambio.emit()
	var bonos := get_node("/root/Bonos")
	var puestos: Array = cfg.get_value("bonos", "puestos", ["", ""])
	for i in mini(puestos.size(), bonos.puestos.size()):
		bonos.puestos[i] = _objeto(puestos[i])
	var estampitas: Dictionary = cfg.get_value("bonos", "estampitas", {})
	for k: String in estampitas:
		bonos.estampitas[k] = estampitas[k]
	bonos.cambio.emit()
	var baul := get_node("/root/Baul")
	var en_baul: Array = cfg.get_value("baul", "items", [])
	var cuantos_baul: Array = cfg.get_value("baul", "cantidades", [])
	for i in en_baul.size():
		var item := _objeto(en_baul[i])
		if item:
			baul.items.append(item)
			baul.cantidades.append(int(cuantos_baul[i]) if i < cuantos_baul.size() else 1)
	baul.saqueadas = (cfg.get_value("baul", "saqueadas", {}) as Dictionary).duplicate()
	baul.cambio.emit()
	var fichas := get_node("/root/Fichas")
	fichas.fichas = int(cfg.get_value("fichas", "fichas", 0))
	fichas.permiso = int(cfg.get_value("fichas", "permiso", 0))
	fichas.vip = bool(cfg.get_value("fichas", "vip", false))
	fichas.desaguadora = bool(cfg.get_value("fichas", "desaguadora", false))
	get_node("/root/Noches").cargar_de(cfg)
	var misiones := get_node("/root/Misiones")
	for campo: String in CAMPANA:
		if cfg.has_section_key("misiones", campo):
			var valor = cfg.get_value("misiones", campo)
			misiones.set(campo, valor.duplicate() if valor is Dictionary or valor is Array else valor)
	var ids: Array = cfg.get_value("misiones", "aceptadas", [])
	misiones.aceptadas.clear()
	for mision: MisionData in misiones.todas:
		if mision.id in ids:
			misiones.aceptadas.append(mision)
	PasoJefe.vencidos.clear()
	for jefe in cfg.get_value("misiones", "jefes_vencidos", []):
		PasoJefe.vencidos[String(jefe)] = true
	misiones.cambio.emit()


# --- Objetos <-> rutas ---

func rutas(items: Array) -> Array:
	return items.map(func(item) -> String: return _ruta(item))


func objetos(lista: Array) -> Array[InventoryItemData]:
	var salida: Array[InventoryItemData] = []
	for ruta in lista:
		var item := _objeto(ruta)
		if item:
			salida.append(item)
	return salida


func _ruta(item) -> String:
	return item.resource_path if item is Resource else ""


func _objeto(ruta) -> InventoryItemData:
	var texto := String(ruta) if ruta != null else ""
	if texto == "" or not ResourceLoader.exists(texto):
		return null
	return load(texto) as InventoryItemData
