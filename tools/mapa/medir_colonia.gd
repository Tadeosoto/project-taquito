extends SceneTree

# Que tan pesada esta una colonia del mapa en Blender (scenes/mapa.tscn), siempre en los mismos
# lugares y de dia y de noche, para comparar antes y despues de un cambio. Como tools/medir_mapa
# pero para la escena nueva (que no tiene el Refugio ni los Zombis de map_test). Necesita ventana:
#   godot --path . -s tools/mapa/medir_colonia.gd
# Escribe una linea MEDIR por lugar: fps, ms de cuadro (promedio y peor), llamadas de dibujo,
# objetos y primitivas, viendo a los cuatro lados.

const ESCENA := "res://scenes/mapa.tscn"
const CARGA := 4.0          # s antes de medir (compilar shaders)
const MEDICION := 1.5       # s por cada lado al que se ve
const LUGARES := {
	"plaza": Vector3(-372.0, 1.2, 432.0),
	"tianguis": Vector3(-278.0, 1.2, 400.0),
	"vecindad": Vector3(-215.0, 1.2, 395.0),
	"avenida": Vector3(-300.0, 1.2, 462.0),
	"cancha": Vector3(-392.0, 1.2, 305.5),
}

var _escena: Node
var _jugador: Node3D
var _ciclo: Node


func _initialize() -> void:
	_medir.call_deferred()


func _medir() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_escena = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(_escena)
	_jugador = _escena.get_node("Player")
	_ciclo = _escena.get_node("Ciclo")
	await _esperar(CARGA)
	for noche in [false, true]:
		var hora: float = (_ciclo.get("dia_duracion") + 100.0) if noche else 100.0
		_ciclo.set("_tiempo", hora)
		await _esperar(1.0)
		for lugar: String in LUGARES:
			await _en_lugar(lugar, "noche" if noche else "dia")
	quit()


func _en_lugar(lugar: String, etiqueta: String) -> void:
	_jugador.global_position = LUGARES[lugar]
	(_jugador as CharacterBody3D).velocity = Vector3.ZERO
	var pivote := _jugador.get_node("CameraPivot") as Node3D
	var cuadros := 0
	var tiempo := 0.0
	var peor := 0.0
	var llamadas := 0.0
	var objetos := 0.0
	var primitivas := 0.0
	await _esperar(1.0)
	for lado in 4:
		pivote.rotation.y = lado * PI / 2
		await _esperar(0.3)
		var t0 := Time.get_ticks_usec()
		var antes := t0
		while Time.get_ticks_usec() - t0 < MEDICION * 1e6:
			await process_frame
			var ahora := Time.get_ticks_usec()
			var dt := (ahora - antes) / 1000.0
			antes = ahora
			cuadros += 1
			tiempo += dt
			peor = maxf(peor, dt)
			llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			objetos += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			primitivas += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("MEDIR %s %s fps=%.0f ms=%.2f peor=%.1f llamadas=%.0f objetos=%.0f primitivas=%.0f" % [
		lugar, etiqueta, cuadros / (tiempo / 1000.0), tiempo / cuadros, peor,
		llamadas / cuadros, objetos / cuadros, primitivas / cuadros])


func _esperar(segundos: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < segundos * 1000.0:
		await process_frame
