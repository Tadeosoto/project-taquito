extends Node

# Mide que tan pesado esta el mapa, siempre en los mismos lugares, para comparar antes y
# despues de un cambio. Necesita ventana (sin ella no hay tiempos de GPU):
#
#   godot --path . tools/medir_mapa.tscn
#   godot --path . tools/medir_mapa.tscn -- --far=180 --capturas=C:/carpeta
#
# Corre 2-3 min y escribe una linea MEDIR por prueba. --far cambia el alcance de la camara
# del jugador solo para esta corrida; --capturas guarda una imagen por lugar; --rapido mide
# solo dos lugares de dia; --apagar=Nodo,Nodo quita nodos del mapa para ver cuanto pesan.

const CARGA := 8.0       # s para que el mapa termine de armarse al llegar a un lugar
const MEDICION := 5.0    # s de medicion
const CAMINATA := 20.0   # s de caminata
const SPRINT := 18.0     # m/s: lo mas rapido que va en map_test.tscn
const DESDE := Vector3(203.0, 1.2, 650.0)
const HACIA := Vector3(12.0, 1.2, -104.0)
const LUGARES := {
	"inicio": Vector3(203.0, 1.2, 650.0),
	"refugio": Vector3(206.0, 1.2, 665.0),
	"parques": Vector3(12.0, 1.2, -104.0),
}

var _capturas := ""
var _mapa: Node
var _jugador: Player
var _ciclo: Ciclo
var _refugio: Refugio
var _zombis: Zombis
var _salud: Node
var _hora := 0.0
var _rid: RID


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_mapa = load("res://scenes/map_test.tscn").instantiate()
	# `--poner=Puntos.load_radius=150,Casas.lod_end=200`: antes de entrar al arbol
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--poner="):
			for par in arg.trim_prefix("--poner=").split(","):
				var partes := par.split("=")
				var ruta := partes[0].split(".")
				_mapa.get_node(ruta[0]).set(ruta[1], partes[1].to_float())
				print("MEDIR %s" % par)
	add_child(_mapa)
	_jugador = _mapa.get_node("Player")
	_ciclo = _mapa.get_node("Ciclo")
	_refugio = _mapa.get_node("Refugio")
	_zombis = _mapa.get_node("Zombis")
	_salud = get_node("/root/Salud")
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	var rapido := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--rapido":
			rapido = true
		elif arg.begins_with("--apagar="):
			for nombre in arg.get_slice("=", 1).split(","):
				_apagar(nombre)
		elif arg.begins_with("--far="):
			(_jugador.find_child("Camera3D", true, false) as Camera3D).far = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--capturas="):
			_capturas = arg.get_slice("=", 1)
	print("MEDIR camara far=%.0f" % (_jugador.find_child("Camera3D", true, false) as Camera3D).far)
	_hora = _ciclo.inicio
	await get_tree().create_timer(CARGA).timeout
	if rapido:
		_hora = 100.0
		await _en_lugar("inicio", "dia")
		await _en_lugar("parques", "dia")
		get_tree().quit()
		return

	for noche in [false, true]:
		_hora = _ciclo.dia_duracion + 100.0 if noche else 100.0
		var etiqueta := "noche" if noche else "dia"
		for lugar: String in LUGARES:
			await _en_lugar(lugar, etiqueta)
		await _caminar(etiqueta)

	# Sin lo del refugio: para saber cuanto pesa
	get_tree().quit()


# Quita un nodo del mapa o sus hijos: `--apagar=Refugio,Partida,Arboles`
func _apagar(nombre: String) -> void:
	var nodo := _mapa.get_node_or_null(nombre)
	if nodo == null:
		push_warning("medir_mapa: no hay %s" % nombre)
		return
	if nodo == _refugio:
		_refugio = null
	nodo.free()
	print("MEDIR sin %s" % nombre)


# Que no se acabe la prueba: ni desmayo, ni tinaco tumbado, ni cambia la hora
func _process(_delta: float) -> void:
	if _ciclo:
		_ciclo._tiempo = _hora
		_salud.vida = _salud.vida_max
		if _refugio:
			_refugio.vida = Refugio.TINACO_VIDA


func _en_lugar(lugar: String, etiqueta: String) -> void:
	_poner_jugador(LUGARES[lugar])
	await get_tree().create_timer(CARGA).timeout
	await _medir("%s/%s" % [lugar, etiqueta], MEDICION, Vector3.ZERO)
	if _capturas != "":
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png("%s/%s_%s.png" % [_capturas, lugar, etiqueta])


func _caminar(etiqueta: String) -> void:
	_poner_jugador(DESDE)
	await get_tree().create_timer(CARGA).timeout
	await _medir("caminata/%s" % etiqueta, CAMINATA, (HACIA - DESDE).normalized() * SPRINT)


func _poner_jugador(donde: Vector3) -> void:
	_zombis.limpiar()
	_jugador.global_position = donde
	_jugador.velocity = Vector3.ZERO


func _medir(nombre: String, segundos: float, velocidad: Vector3) -> void:
	var cuadros: Array[float] = []
	var proceso := 0.0
	var fisica := 0.0
	var gpu := 0.0
	var llamadas := 0.0
	var primitivas := 0.0
	var objetos := 0.0
	var antes := Time.get_ticks_usec()
	var fin := antes + int(segundos * 1000000.0)
	while antes < fin:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append((ahora - antes) / 1000.0)
		antes = ahora
		if velocidad != Vector3.ZERO:
			_jugador.global_position += velocidad * get_process_delta_time()
		proceso += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		fisica += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_rid)
		llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitivas += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		objetos += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var n := float(cuadros.size())
	var total := 0.0
	for c in cuadros:
		total += c
	cuadros.sort()
	print("MEDIR %-24s fps=%4.0f peor1%%=%5.1fms max=%5.1fms cpu=%4.1fms fisica=%4.1fms gpu=%4.1fms llamadas=%5.0f prim=%4.0fk objetos=%5.0f" % [
		nombre, n / (total / 1000.0), cuadros[int(n * 0.99)], cuadros[-1], proceso / n, fisica / n, gpu / n, llamadas / n, primitivas / n / 1000.0, objetos / n])
