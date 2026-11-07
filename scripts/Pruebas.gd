extends Node

# Autoload `Pruebas`: el modo de la sesion de test, la carrera (noche, dinero, dificultad),
# la carpeta de datos y el arranque de los dos escenarios. La defensa y el refugio leen de
# aqui; no hay copias de la escena.
#
#   Carrera: refugio mini (safehouse en modo carrera) -> tienda/punto -> flecha -> noche.
#   Godmode: la misma defensa directa, todo al maximo e items infinitos.
#
# Los tests se lanzan desde el menu (Inicio -> Pruebas) o con `godot --path . scenes/...`.
# El log se enciende siempre; `--monitor=<carpeta>` solo elige la carpeta.

signal cambio

enum Modo { NINGUNO, CARRERA, GODMODE }

const PESOS_INICIO := 120
const PAGA := 150
const BONO_PERDIDA := 75
const AGUA_A_PESOS := 50
const CARPETA := "user://pruebas/"
const DURACION := 210.0

var modo := Modo.NINGUNO
var activo := false
var noche := 1
var pesos_al_empezar := 0
var dificultad := "medio"
var duracion_noche := DURACION
# Una carpeta por sesion de prueba y una subcarpeta por noche (la carrera encadena noches y
# el monitor no debe sobrescribir la anterior).
var carpeta := ""
var carpeta_noche := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Llamado por el lanzador: deja todo listo para el test que va a cargar la escena.
func preparar_test(nuevo_modo: Modo, nueva_dificultad := "medio", nueva_duracion := DURACION) -> void:
	dificultad = nueva_dificultad
	duracion_noche = nueva_duracion
	_asegurar_carpeta()
	if nuevo_modo == Modo.CARRERA:
		nueva_carrera()
	elif nuevo_modo == Modo.GODMODE:
		iniciar_godmode()
	else:
		modo = Modo.NINGUNO
		activo = false


func preparar_carrera(nueva_dificultad := "medio", nueva_duracion := DURACION) -> void:
	preparar_test(Modo.CARRERA, nueva_dificultad, nueva_duracion)


func preparar_godmode(nueva_dificultad := "medio", nueva_duracion := DURACION) -> void:
	preparar_test(Modo.GODMODE, nueva_dificultad, nueva_duracion)


func carpeta_actual() -> String:
	_asegurar_carpeta()
	return carpeta


func es_carrera() -> bool:
	return modo == Modo.CARRERA and activo


func es_godmode() -> bool:
	return modo == Modo.GODMODE


# Carrera nueva desde cero: dinero, kit base, mejoras y tazos. El personaje se conserva.
func nueva_carrera() -> void:
	_asegurar_carpeta()
	modo = Modo.CARRERA
	activo = true
	noche = 1
	var cartera := get_node_or_null("/root/Cartera")
	if cartera:
		cartera.pesos = PESOS_INICIO
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.infinito = false
		inventario.items.clear()
		inventario.mochila = null
		var machete := load("res://resources/productos/machete.tres")
		if machete:
			inventario.add_item(machete)
		inventario.inventory_changed.emit()
	var mejoras := get_node_or_null("/root/Mejoras")
	if mejoras:
		mejoras.reiniciar()
		mejoras.activo = true
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		tazos.reiniciar()
		tazos.puntos = 0
		tazos.cambio.emit()
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.reiniciar()
	var registro := get_node_or_null("/root/Registro")
	if registro:
		registro.sesion(carpeta, "carrera")
	cambio.emit()


func iniciar_godmode() -> void:
	modo = Modo.GODMODE
	activo = false
	noche = 1
	_asegurar_carpeta()
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		tazos.reiniciar()
		tazos.puntos = 0
		tazos.cambio.emit()
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.infinito = true
	var registro := get_node_or_null("/root/Registro")
	if registro:
		registro.sesion(carpeta, "godmode")
	cambio.emit()


# La noche empieza: guarda el dinero y abre la carpeta de esta noche.
func empezar_noche() -> void:
	if modo == Modo.CARRERA:
		activo = true
		var cartera := get_node_or_null("/root/Cartera")
		pesos_al_empezar = cartera.pesos if cartera else 0
	carpeta_noche = carpeta + ("noche_%d/" % noche)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta_noche))
	var registro := get_node_or_null("/root/Registro")
	if registro:
		registro.sesion(carpeta, _nombre_modo())
		registro.noche_inicio(noche, _nombre_modo(), dificultad, duracion_noche, pesos_al_empezar)
	cambio.emit()


# La noche termino: paga o ayuda (solo carrera) y cierre del registro.
func terminar_noche(gano: bool) -> void:
	if modo == Modo.CARRERA:
		var cartera := get_node_or_null("/root/Cartera")
		if cartera:
			cartera.pesos = pesos_al_empezar + (PAGA if gano else BONO_PERDIDA)
	var mejoras := get_node_or_null("/root/Mejoras")
	if mejoras:
		mejoras.terminar_noche()
	var registro := get_node_or_null("/root/Registro")
	if registro:
		if modo == Modo.CARRERA:
			registro.noche_fin(gano, pesos_al_empezar + (PAGA if gano else BONO_PERDIDA))
		else:
			registro.noche_fin(gano, -1)
	cambio.emit()


func siguiente_noche() -> void:
	noche += 1
	carpeta_noche = ""
	cambio.emit()


# Precio en pesos que cobran las tiendas de la carrera: los productos que hoy cuestan AGUA
# se convierten con AGUA_A_PESOS. Los precios base, sin regateo ni tono de piel.
func precio_pesos(producto: InventoryItemData) -> int:
	if producto == null:
		return 0
	if producto.moneda == 1:
		return roundi(producto.precio * AGUA_A_PESOS)
	return producto.precio


# Salir de los tests: deja los autoloads como estaban para no contaminar map_test/safehouse.
func cerrar() -> void:
	modo = Modo.NINGUNO
	activo = false
	noche = 1
	var mejoras := get_node_or_null("/root/Mejoras")
	if mejoras:
		mejoras.reiniciar()
		mejoras.activo = false
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.infinito = false
		inventario.reiniciar()
	var tazos := get_node_or_null("/root/Tazos")
	if tazos:
		tazos.reiniciar()
	var cartera := get_node_or_null("/root/Cartera")
	if cartera:
		cartera.reiniciar()
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.reiniciar()
	cambio.emit()


func _nombre_modo() -> String:
	return "carrera" if modo == Modo.CARRERA else ("godmode" if modo == Modo.GODMODE else "libre")


func _asegurar_carpeta() -> void:
	if carpeta != "":
		return
	carpeta = _carpeta_arg()
	if carpeta == "":
		var t := Time.get_datetime_dict_from_system()
		carpeta = CARPETA + "%04d-%02d-%02d_%02d-%02d-%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	if not carpeta.ends_with("/"):
		carpeta += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	print("Pruebas: datos en ", ProjectSettings.globalize_path(carpeta))


func _carpeta_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--monitor="):
			return arg.trim_prefix("--monitor=")
	return ""
