extends Node

# Las comprobaciones del juego (docs/sistemas/comprobaciones.md): pruebas que corren solas, sin
# ventana, sobre las escenas de verdad (el safehouse, map_test, las arenas) y dicen OK o FALLA.
# Antes de mezclar a main-testing:
#   godot --path . --headless res://tools/comprobaciones/correr.tscn
#   godot --path . --headless res://tools/comprobaciones/correr.tscn -- --solo=bolsa
# o tools/comprobaciones/correr.sh, que ademas cuenta los SCRIPT ERROR de la consola.
# Sale con el numero de fallas (0 = todo bien).
#
# No pisa lo del jugador: respalda los .cfg de user:// antes de empezar y los regresa al final
# (si una corrida anterior se cayo a medias, primero regresa ese respaldo).
#
# Cada comprobacion es un archivo de esta carpeta (extends Comprobacion) con `correr(r)`; `r` es
# este nodo, con los ayudantes de abajo. Para agregar una: el archivo y su nombre en LISTA.

const LISTA := ["especiales", "noches", "bolsa", "guardado", "capilla", "entrada_jefe", "dialogo", "negocios", "escenas"]
const CARPETA := "res://tools/comprobaciones/"
const RESPALDO := "user://_respaldo_comprobaciones/"
const ARCHIVOS := ["partida.cfg", "noches.cfg", "libreta.cfg", "taller.cfg", "personaje.cfg"]
const FALTABAN := "faltaban.txt"

var fallas := 0
var _total := 0
var _actual := ""
var _vigilando := ""
const TOPE_S := 420   # s que puede tardar una comprobacion antes de darla por atorada


func _ready() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var solo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--solo="):
			solo = arg.trim_prefix("--solo=")
	_regresar_respaldo()
	_respaldar()
	# El corredor deja de ser la escena actual: asi cada ir_a borra la anterior y no a el (si no, las
	# escenas se iban quedando encimadas: dos Ciclos, dos jugadores)
	get_tree().current_scene = null
	var inicio := Time.get_ticks_msec()
	for nombre: String in LISTA:
		if solo != "" and nombre != solo:
			continue
		_actual = nombre
		var script := load(CARPETA + nombre + ".gd") as GDScript
		# Con un error de sintaxis el script carga pero no se puede instanciar: falla y sigue
		if script == null or not script.can_instantiate():
			ok(false, "compila %s.gd" % nombre)
			continue
		print("== %s" % nombre)
		var antes := fallas
		await _limpiar()
		_vigilar(nombre)
		var prueba = script.new()
		await prueba.correr(self)
		_vigilando = ""
		print("   %s: %s" % [nombre, "bien" if fallas == antes else "%d falla(s)" % (fallas - antes)])
	await _limpiar()
	_regresar_respaldo()
	print("COMPROBACIONES: %d de %d bien, %d falla(s), %.0f s" % [_total - fallas, _total, fallas, (Time.get_ticks_msec() - inicio) / 1000.0])
	get_tree().quit(fallas)


# Si una comprobacion se atora (un error a media corrutina la deja esperando para siempre), a los
# TOPE_S segundos cuenta como falla, regresa el respaldo y sale: nunca se queda colgado
func _vigilar(nombre: String) -> void:
	_vigilando = nombre
	var empezo := Time.get_ticks_msec()
	while _vigilando == nombre:
		await get_tree().create_timer(1.0, true, false, true).timeout
		if _vigilando == nombre and Time.get_ticks_msec() - empezo > TOPE_S * 1000:
			_falla("se atoro mas de %d s" % TOPE_S)
			_regresar_respaldo()
			print("COMPROBACIONES: cortadas en %s, %d falla(s)" % [nombre, fallas])
			get_tree().quit(maxi(fallas, 1))
			return


# --- Ayudantes para las comprobaciones ---

func ok(cond: bool, texto: String) -> void:
	_total += 1
	if cond:
		print("OK    %s" % texto)
	else:
		_falla(texto)


func _falla(texto: String) -> void:
	fallas += 1
	print("FALLA %s: %s" % [_actual, texto])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


# Cambia de escena y espera a que este lista. El corredor dejo de ser la escena actual al empezar
# (_correr), asi que change_scene borra la escena anterior y no a el
func ir_a(ruta: String, espera := 60) -> bool:
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)
	var llego: bool = await escena_es(ruta)
	await frames(espera)
	return llego


# Espera a que la escena actual sea `ruta` (otra la puede cambiar: PasoJefe, PasoColonia)
func escena_es(ruta: String, tope := 1500) -> bool:
	for i in tope:
		await get_tree().process_frame
		var c := get_tree().current_scene
		if c and c.scene_file_path == ruta and c.is_node_ready():
			return true
	return false


func nodo(grupo: String) -> Node:
	return get_tree().get_first_node_in_group(grupo)


func autoload(nombre: String) -> Node:
	return get_node("/root/" + nombre)


# Aprieta y suelta una accion (como si fuera el jugador)
func apretar(accion: String) -> void:
	var e := InputEventAction.new()
	e.action = accion
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var s := InputEventAction.new()
	s.action = accion
	s.pressed = false
	Input.parse_input_event(s)
	await get_tree().process_frame


# Cierra el show de un tazo (TazoRevelacion) si salio, y quita la pausa. Sale a los 2 s del amanecer
func cerrar_tazo(espera := 3.0) -> bool:
	await segundos(espera)
	var visto := false
	for n in get_tree().root.get_children():
		if n is TazoRevelacion:
			visto = true
			n.termino.emit()
			n.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	return visto


# Pasa al otro lado del ciclo (de dia a noche o al reves) y espera a que se note
func saltar_ciclo() -> void:
	var ciclo := nodo("ciclo") as Ciclo
	ciclo.saltar(true)
	await frames(12)


# Todo como al empezar: partida nueva, sin pausa, nada de jefes ni flechas a medias
func _limpiar() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	PasoJefe.reiniciar()
	autoload("Guardado").nueva()
	for n in get_tree().root.get_children():
		if n is TazoRevelacion or n is DialogueBox:
			n.queue_free()
	await get_tree().process_frame


# --- El respaldo de user:// ---

func _respaldar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESPALDO))
	var faltaban: PackedStringArray = []
	for archivo: String in ARCHIVOS:
		var de := "user://" + archivo
		if FileAccess.file_exists(de):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(de), ProjectSettings.globalize_path(RESPALDO + archivo))
		else:
			faltaban.append(archivo)
	var f := FileAccess.open(RESPALDO + FALTABAN, FileAccess.WRITE)
	f.store_string("\n".join(faltaban))
	f.close()


func _regresar_respaldo() -> void:
	if not FileAccess.file_exists(RESPALDO + FALTABAN):
		return
	var faltaban := FileAccess.get_file_as_string(RESPALDO + FALTABAN).split("\n", false)
	for archivo: String in ARCHIVOS:
		var a := ProjectSettings.globalize_path("user://" + archivo)
		var r := ProjectSettings.globalize_path(RESPALDO + archivo)
		if archivo in faltaban:
			if FileAccess.file_exists("user://" + archivo):
				DirAccess.remove_absolute(a)
		elif FileAccess.file_exists(RESPALDO + archivo):
			DirAccess.copy_absolute(r, a)
			DirAccess.remove_absolute(r)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO + FALTABAN))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESPALDO))
