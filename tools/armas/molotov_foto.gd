extends SceneTree
# Capturas de la botella de la molotov (scripts/lombrices/BotellaMolotov.gd): las etapas y sabores (vacia,
# gasolina de limon o cereza, molotov de cada una) de lado y desde arriba (molotov_modelo.png), y la molotov en la mano de
# el_compa (molotov_mano.png) y volando de noche con el trapo prendido, en tres momentos
# (molotov_vuela.png). Necesita ventana (no --headless):
#   godot --path . -s tools/armas/molotov_foto.gd -- --salida=/tmp/fotos

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


func _camara(vista: SubViewport, desde: Vector3, hacia: Vector3, fov := 35.0) -> Camera3D:
	var camara := Camera3D.new()
	camara.fov = fov
	vista.add_child(camara)
	camara.look_at_from_position(desde, hacia)
	return camara


func _captura(vista: SubViewport) -> Image:
	var imagen := vista.get_texture().get_image()
	imagen.convert(Image.FORMAT_RGB8)
	return imagen


func _hoja(imagenes: Array, nombre: String) -> void:
	var hoja := Image.create(ANCHO * imagenes.size(), ALTO, false, Image.FORMAT_RGB8)
	for i in imagenes.size():
		hoja.blit_rect(imagenes[i], Rect2i(0, 0, ANCHO, ALTO), Vector2i(ANCHO * i, 0))
	hoja.save_png(salida + nombre)
	print("guardada ", salida + nombre)


func _fotos() -> void:
	var botella: GDScript = load("res://scripts/lombrices/BotellaMolotov.gd")
	# Las cinco juntas (vacia, gasolina de limon y de cereza, molotov de limon y de cereza), de lado y
	# de tres cuartos desde arriba, y las dos molotovs de cerca
	var botellas := [[0, 0], [1, 0], [1, 1], [2, 0], [2, 1]]
	var vistas := []
	for desde in [Vector3(0, 0.2, 1.05), Vector3(0.55, 0.6, 0.65), Vector3(0.3, 0.28, 0.4)]:
		var vista := _vista(Color(0.86, 0.85, 0.83))
		# Un fondo oscuro detras, para que se note el vidrio
		var fondo := MeshInstance3D.new()
		var plano := QuadMesh.new()
		plano.size = Vector2(0.8, 0.5)
		fondo.mesh = plano
		var negro := StandardMaterial3D.new()
		negro.albedo_color = Color(0.12, 0.12, 0.14)
		fondo.material_override = negro
		vista.add_child(fondo)
		var cerca: bool = desde.length() < 0.6
		for k in botellas.size():
			if cerca and k < 3:
				continue
			var b: Node3D = botella.new()
			b.etapa = botellas[k][0]
			b.sabor = botellas[k][1]
			b.position.x = (k - 2) * 0.1 if not cerca else (k - 3.5) * 0.12
			b.rotation_degrees.y = -30.0
			vista.add_child(b)
		var mira := Vector3(0, 0.17, 0)
		var camara := _camara(vista, desde, mira)
		fondo.global_transform = Transform3D(camara.global_basis, mira - camara.global_basis.z * 0.25)
		vistas.append(vista)
	for i in 3:
		await process_frame
	_hoja(vistas.map(_captura), "molotov_modelo.png")
	for v in vistas:
		v.queue_free()

	# En la mano de el_compa: parado, echando el brazo atras (OverhandThrow a 0.25 s) y de cerca
	var poses := [["Idle", 0.5, Vector3(-1.6, 1.4, 1.6), Vector3(0, 0.95, 0), 35.0],
			["OverhandThrow", 0.25, Vector3(-2.2, 1.5, 0.6), Vector3(0, 1.2, 0), 40.0],
			["Idle", 0.5, Vector3(0, 1, 1), Vector3.ZERO, 30.0]]  # su camara se apunta a la mano despues
	var vistas_mano := []
	for pose in poses:
		var v := _vista(Color(0.18, 0.18, 0.2))
		var compa: Node3D = (load(COMPA) as PackedScene).instantiate()
		compa.scale = Vector3.ONE * 0.39
		v.add_child(compa)
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
		var en_mano: Node3D = botella.new()
		en_mano.etapa = 2
		mano.add_child(en_mano)
		_camara(v, pose[2], pose[3], pose[4])
		vistas_mano.append([v, mano, en_mano])
	await process_frame
	await process_frame
	for par in vistas_mano:
		var mano: BoneAttachment3D = par[1]
		var escala := maxf(mano.global_transform.basis.get_scale().x, 0.001)
		var en_mano: Node3D = par[2]
		en_mano.scale = Vector3.ONE / escala
		en_mano.rotation_degrees = botella.GIRO_MANO
		en_mano.position = botella.EN_MANO / escala
	await process_frame
	var cerca: Node3D = vistas_mano[2][1]
	var camara := (vistas_mano[2][0] as SubViewport).find_children("*", "Camera3D", true, false)[0] as Camera3D
	camara.look_at_from_position(cerca.global_position + Vector3(-0.6, 0.15, 0.35), cerca.global_position)
	for i in 3:
		await process_frame
	_hoja(vistas_mano.map(func(par): return _captura(par[0])), "molotov_mano.png")
	for par in vistas_mano:
		par[0].queue_free()

	# Volando de noche (Arrojadizo tipo 2, quieto en el aire): el fuego del trapo y su luz en el piso
	var noche := _vista(Color(0.04, 0.05, 0.08))
	(noche.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment.ambient_light_energy = 0.12
	(noche.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D).light_energy = 0.1
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(8, 8)
	piso.mesh = plano
	noche.add_child(piso)
	var vuela: Node3D = load("res://scripts/lombrices/Arrojadizo.gd").new()
	vuela.tipo = 2
	noche.add_child(vuela)
	vuela.set_physics_process(false)
	vuela.position = Vector3(0, 0.9, 0)
	_camara(noche, Vector3(0.3, 1.1, 1.3), Vector3(0, 0.85, 0), 40.0)
	var cuadros := []
	for giro in [Vector3(0.3, 0.0, 0.5), Vector3(1.6, 0.8, 0.2), Vector3(2.9, 1.5, -0.4)]:
		vuela.rotation = giro
		for i in 6:
			await process_frame
		cuadros.append(_captura(noche))
	_hoja(cuadros, "molotov_vuela.png")
	quit()
