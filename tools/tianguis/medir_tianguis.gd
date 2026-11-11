extends SceneTree

# Cuanto cuesta dibujar el tianguis en el mapa (scenes/mapa.tscn): tiempo de GPU y de CPU del
# render (menos ruidoso que los fps cuando la PC esta ocupada) y llamadas de dibujo, parado en el
# pasillo viendo a lo largo y de lado, con y sin los tramos (--sin_tianguis los quita). Necesita
# ventana:
#   godot --path . -s tools/tianguis/medir_tianguis.gd [-- --sin_tianguis]
# Para ver que pesa: --sin_gente, --sin_sombras (ni las lonas), --sin_chico (la mercancia),
# --sin_grande (lo horneado que no es chico)

const LUGARES := {
	"sur_largo": [Vector3(-277.3, 1.2, 440.0), PI],
	"sur_lado": [Vector3(-277.6, 1.2, 420.0), -PI / 2],
	"norte_largo": [Vector3(-279.7, 1.2, 362.0), PI],
	"fuera": [Vector3(-262.0, 1.2, 400.0), PI / 2],
}
const MUESTRAS := 120


func _initialize() -> void:
	_medir.call_deferred()


func _medir() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var escena: Node = (load("res://scenes/mapa.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	if "--sin_tianguis" in OS.get_cmdline_user_args():
		for t in escena.find_children("Tianguis_*", "Node3D", true, false):
			t.queue_free()
	var args := OS.get_cmdline_user_args()
	for t in escena.find_children("Tianguis_*", "Node3D", true, false):
		if "--sin_gente" in args:
			t.set("gente", false)
			for e in t.get("_gente"):
				if e["nodo"]:
					e["nodo"].queue_free()
			t.get("_gente").clear()
		for c in t.get_children():
			if c is MultiMeshInstance3D:
				var mmi := c as MultiMeshInstance3D
				if "--sin_sombras" in args:
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var chico := mmi.visibility_range_end > 0.0
				if ("--sin_chico" in args and chico) or ("--sin_grande" in args and not chico):
					mmi.queue_free()
	var jugador := escena.get_node("Player") as Node3D
	var pivote := jugador.get_node("CameraPivot") as Node3D
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 240:
		await process_frame
	for lugar: String in LUGARES:
		jugador.global_position = LUGARES[lugar][0]
		(jugador as CharacterBody3D).velocity = Vector3.ZERO
		pivote.rotation.y = LUGARES[lugar][1]
		for i in 90:
			await process_frame
		var gpu := []
		var cpu := []
		var llamadas := 0.0
		for i in MUESTRAS:
			await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		gpu.sort()
		cpu.sort()
		# La mediana: no la mueven los cuadros en que la PC se ocupo en otra cosa
		print("MEDIR_T %s gpu=%.2f ms cpu=%.2f ms llamadas=%.0f" % [lugar, gpu[MUESTRAS / 2], cpu[MUESTRAS / 2], llamadas / MUESTRAS])
	quit()
