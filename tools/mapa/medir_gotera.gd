extends SceneTree

# Cuanto cuesta dibujar La Gotera contra Santa Mugre (scenes/mapa.tscn con cada colonia): la mediana
# del tiempo de GPU y de CPU del render y las llamadas de dibujo, de dia y de noche, parado en lugares
# fijos. Como tools/tianguis/medir_tianguis.gd, pero por colonia. Necesita ventana:
#   godot --path . -s tools/mapa/medir_gotera.gd -- --colonia=la_gotera_favela
# Colonias: santa_mugre (el tianguis de referencia), la_gotera (su tianguis) y la_gotera_favela.
# El presupuesto (docs/mapa/colonias/la_gotera.md): no mas de ~5 ms de GPU sobre el tramo equivalente
# de Santa Mugre.

const MAPA := "res://scenes/mapa.tscn"
const MUESTRAS := 120
# colonia -> lugar -> [posicion del jugador, giro de la camara]
const LUGARES := {
	"santa_mugre": {
		"tianguis_largo": [Vector3(-277.3, 1.2, 440.0), PI],
		"tianguis_lado": [Vector3(-277.6, 1.2, 420.0), -PI / 2],
		"fuera": [Vector3(-262.0, 1.2, 400.0), PI / 2],
	},
	"la_gotera": {
		"tianguis_largo": [Vector3(727.0, 1.2, -325.0), PI],
		"tianguis_agua": [Vector3(724.0, 1.2, -290.0), 0.0],
		"tianguis_comida": [Vector3(711.5, 1.2, -130.0), PI],
		"boca": [Vector3(731.0, 1.2, -271.9), -PI / 2],
	},
	"la_gotera_favela": {
		"boca": [Vector3(735.0, 1.2, -271.9), -PI / 2],
		"callejon": [Vector3(760.0, 1.2, -300.0), 0.0],
		"plaza": [Vector3(800.0, 2.0, -230.0), -PI / 2],
		"fondo": [Vector3(880.0, 2.7, -200.0), PI / 2],
		"tunel": [Vector3(770.0, -3.0, -239.2), -PI / 2],
	},
}


func _initialize() -> void:
	_medir.call_deferred()


func _medir() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var colonia := "la_gotera"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--colonia="):
			colonia = arg.trim_prefix("--colonia=")
	PasoColonia.colonia = colonia
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	var jugador := escena.get_node("Player") as CharacterBody3D
	var pivote := jugador.get_node("CameraPivot") as Node3D
	var ciclo := escena.get_node("Ciclo")
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 240:
		await process_frame
	var lugares: Dictionary = LUGARES.get(colonia, {})
	for noche in [false, true]:
		ciclo.set("_tiempo", (float(ciclo.get("dia_duracion")) + 100.0) if noche else 100.0)
		for i in 60:
			await process_frame
		for lugar: String in lugares:
			jugador.global_position = lugares[lugar][0]
			jugador.velocity = Vector3.ZERO
			pivote.rotation.y = lugares[lugar][1]
			for i in 90:
				await process_frame
			var gpu := []
			var cpu := []
			var llamadas := 0.0
			var primitivas := 0.0
			for i in MUESTRAS:
				await process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
				llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				primitivas += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			gpu.sort()
			cpu.sort()
			print("MEDIR_G %s %s %s gpu=%.2f ms cpu=%.2f ms llamadas=%.0f primitivas=%.0fk" % [colonia, lugar, "noche" if noche else "dia",
				gpu[MUESTRAS / 2], cpu[MUESTRAS / 2], llamadas / MUESTRAS, primitivas / MUESTRAS / 1000.0])
	quit()
