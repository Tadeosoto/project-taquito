extends SceneTree
# Capturas de la palomita (scripts/lombrices/Palomita.gd): el modelo solo desde tres lados
# (palomita_modelo.png) y en la mano de el_compa, parado y a punto de aventarla
# (palomita_mano.png). Necesita ventana (no --headless):
#   godot --path . -s tools/armas/palomita_foto.gd -- --salida=/tmp/fotos

const ANCHO := 480
const ALTO := 480
const BIBLIOTECA := "res://resources/personajes/animaciones_humanas.res"
const COMPA := "res://models/personajes/protagonistas/el_compa/el_compa.fbx"

var salida := "user://"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salida="):
			salida = a.get_slice("=", 1).trim_suffix("/") + "/"
	_fotos.call_deferred()


func _vista(fondo: Color) -> SubViewport:
	var vista := SubViewport.new()
	vista.size = Vector2i(ANCHO, ALTO)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.own_world_3d = true
	root.add_child(vista)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fondo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	entorno.environment = env
	vista.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 35, 0)
	sol.light_energy = 1.1
	vista.add_child(sol)
	return vista


func _camara(vista: SubViewport, desde: Vector3, hacia: Vector3, fov := 35.0) -> void:
	var camara := Camera3D.new()
	camara.fov = fov
	vista.add_child(camara)
	camara.look_at_from_position(desde, hacia)


func _guardar(vistas: Array, nombre: String) -> void:
	for i in 3:
		await process_frame
	var hoja := Image.create(ANCHO * vistas.size(), ALTO, false, Image.FORMAT_RGB8)
	for i in vistas.size():
		var imagen: Image = (vistas[i] as SubViewport).get_texture().get_image()
		imagen.convert(Image.FORMAT_RGB8)
		hoja.blit_rect(imagen, Rect2i(Vector2i.ZERO, imagen.get_size()), Vector2i(ANCHO * i, 0))
	hoja.save_png(salida + nombre)
	print("guardada ", salida + nombre)
	for v in vistas:
		v.queue_free()


func _fotos() -> void:
	var palomita: GDScript = load("res://scripts/lombrices/Palomita.gd")
	var malla: ArrayMesh = palomita.malla()
	# El modelo solo: de frente, de tres cuartos y de lado
	var vistas := []
	for desde in [Vector3(0, 0.0, 0.6), Vector3(0.4, 0.24, 0.44), Vector3(0.6, 0.1, 0.0)]:
		var vista := _vista(Color(0.86, 0.85, 0.83))
		var pieza := MeshInstance3D.new()
		pieza.mesh = malla
		vista.add_child(pieza)
		_camara(vista, desde, Vector3(0, -0.01, 0))
		vistas.append(vista)
	await _guardar(vistas, "palomita_modelo.png")

	# En la mano: parado (Idle), echando el brazo atras (OverhandThrow a 0.25 s) y de cerca
	vistas = []
	var poses := [["Idle", 0.5, Vector3(-1.6, 1.4, 1.6), Vector3(0, 0.95, 0), 35.0],
			["OverhandThrow", 0.25, Vector3(-2.2, 1.5, 0.6), Vector3(0, 1.2, 0), 40.0],
			["Idle", 0.5, Vector3(0.0, 0.95, 0.75), Vector3(-0.25, 0.85, 0.0), 30.0]]
	for pose in poses:
		var vista := _vista(Color(0.18, 0.18, 0.2))
		var compa: Node3D = (load(COMPA) as PackedScene).instantiate()
		compa.scale = Vector3.ONE * 0.39
		vista.add_child(compa)
		var reproductor := compa.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if reproductor == null:
			reproductor = AnimationPlayer.new()
			compa.add_child(reproductor)
		if not reproductor.has_animation_library("h"):
			reproductor.add_animation_library("h", load(BIBLIOTECA))
		reproductor.play("h/" + pose[0])
		reproductor.seek(pose[1], true)
		reproductor.pause()
		var esqueleto := compa.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mano := BoneAttachment3D.new()
		esqueleto.add_child(mano)
		mano.bone_name = "RightHand"
		var pieza := MeshInstance3D.new()
		pieza.mesh = malla
		mano.add_child(pieza)
		_camara(vista, pose[2], pose[3], pose[4])
		vistas.append([vista, mano, pieza])
	await process_frame
	await process_frame
	for v in vistas:
		var mano: BoneAttachment3D = v[1]
		var escala := mano.global_transform.basis.get_scale()
		var pieza: MeshInstance3D = v[2]
		pieza.scale = Vector3.ONE / maxf(escala.x, 0.001)
		pieza.rotation_degrees = palomita.GIRO_MANO
		pieza.position = palomita.EN_MANO / maxf(escala.x, 0.001)
	# El acercamiento apunta a donde quedo la mano
	await process_frame
	var cerca: Node3D = vistas[2][2]
	var camara := (vistas[2][0] as SubViewport).find_children("*", "Camera3D", true, false)[0] as Camera3D
	camara.look_at_from_position(cerca.global_position + Vector3(-0.7, 0.15, 0.4), cerca.global_position)
	await _guardar(vistas.map(func(v): return v[0]), "palomita_mano.png")
	quit()
