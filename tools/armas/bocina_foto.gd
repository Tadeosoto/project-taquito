extends SceneTree
# Capturas de la bocina (scripts/lombrices/Bocina.gd): el modelo solo desde tres lados
# (bocina_modelo.png) y tirada en el piso de noche soltando ondas, con un zombi que viene,
# en tres momentos (bocina_ondas.png), y en la mano de el_compa (bocina_mano.png). Necesita ventana (no --headless):
#   godot --path . -s tools/armas/bocina_foto.gd -- --salida=/tmp/fotos
# Con --encintada, la bocina encintada a la botella de agua (BocinaEncintada) en lugar de la sola

const ANCHO := 480
const ALTO := 480
const CUADROS_ONDAS := 3
const ENTRE := 0.27           # s entre cuadro y cuadro de las ondas
const BIBLIOTECA := "res://resources/personajes/animaciones_humanas.res"
const COMPA := "res://models/personajes/protagonistas/el_compa/el_compa.fbx"

var salida := "user://"
var encintada := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salida="):
			salida = a.get_slice("=", 1).trim_suffix("/") + "/"
		elif a == "--encintada":
			encintada = true
	_fotos.call_deferred()


func _vista(fondo: Color, ambiente: float) -> SubViewport:
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
	env.ambient_light_energy = ambiente
	entorno.environment = env
	vista.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 35, 0)
	sol.light_energy = 1.1 if ambiente > 0.4 else 0.25
	vista.add_child(sol)
	return vista


func _camara(vista: SubViewport, desde: Vector3, hacia: Vector3, fov := 35.0) -> void:
	var camara := Camera3D.new()
	camara.fov = fov
	vista.add_child(camara)
	camara.look_at_from_position(desde, hacia)


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
	var bocina: GDScript = load("res://scripts/lombrices/Bocina.gd")
	var modelo: GDScript = load("res://scripts/lombrices/BocinaEncintada.gd") if encintada else bocina
	var prefijo := "encintada_" if encintada else "bocina_"
	# El modelo solo: de frente, de tres cuartos desde arriba y de punta
	var vistas := []
	var lados := [Vector3(0, 0.08, 0.6), Vector3(0.38, 0.3, 0.42), Vector3(0.55, 0.1, 0.12)]
	# La encintada trae la botella atras (-Z): se ve de ese lado
	if encintada:
		lados = [Vector3(0, 0.12, -0.65), Vector3(0.42, 0.4, -0.45), Vector3(0.0, 0.7, -0.05)]
	for desde in lados:
		var vista := _vista(Color(0.86, 0.85, 0.83), 0.55)
		vista.add_child(modelo.new())
		_camara(vista, desde, Vector3.ZERO)
		vistas.append(vista)
	for i in 3:
		await process_frame
	_hoja(vistas.map(_captura), prefijo + "modelo.png")
	for v in vistas:
		v.queue_free()

	# En el piso de noche, soltando ondas, con un zombi que viene hacia ella. Piso de cuadros para
	# que se note el aire que tiembla
	var vista := _vista(Color(0.05, 0.06, 0.1), 0.35)
	var tablero := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			tablero.set_pixel(x, y, Color(0.38, 0.38, 0.4) if (x / 8 + y / 8) % 2 == 0 else Color(0.3, 0.3, 0.32))
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(20, 20)
	piso.mesh = plano
	var cuadros := StandardMaterial3D.new()
	cuadros.albedo_texture = ImageTexture.create_from_image(tablero)
	cuadros.uv1_scale = Vector3(40, 40, 1)
	cuadros.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	piso.material_override = cuadros
	vista.add_child(piso)
	var pieza: Node3D = modelo.new()
	pieza.position.y = bocina.RADIO * 1.06
	pieza.rotation_degrees.y = 25.0
	vista.add_child(pieza)
	vista.add_child(bocina.ondas())
	var zombi: Node3D = load("res://scripts/map/Zombie.gd").modelo_skin(0)
	zombi.scale = Vector3.ONE * 0.61
	zombi.position = Vector3(-0.9, 0.0, -2.2)
	zombi.rotation.y = 0.4
	vista.add_child(zombi)
	(zombi.find_child("AnimationPlayer", true, false) as AnimationPlayer).play("h/Zombie_Walk_Fwd")
	_camara(vista, Vector3(0.6, 1.0, 2.4), Vector3(-0.1, 0.4, -0.4), 45.0)
	var imagenes := []
	for i in 6:
		await process_frame
	for k in CUADROS_ONDAS:
		await create_timer(ENTRE).timeout
		imagenes.append(_captura(vista))
	_hoja(imagenes, prefijo + "ondas.png")
	vista.queue_free()

	# En la mano de el_compa: parado, echando el brazo atras (OverhandThrow a 0.25 s) y de cerca
	var poses := [["Idle", 0.5, Vector3(-1.6, 1.4, 1.6), Vector3(0, 0.95, 0), 35.0],
			["OverhandThrow", 0.25, Vector3(-2.2, 1.5, 0.6), Vector3(0, 1.2, 0), 40.0],
			["OverhandThrow", 0.25, Vector3(0, 1, 1), Vector3.ZERO, 30.0]]  # su camara se apunta a la mano despues
	var vistas_mano := []
	for pose in poses:
		var v := _vista(Color(0.18, 0.18, 0.2), 0.55)
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
		var en_mano: Node3D = modelo.new()
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
		en_mano.rotation_degrees = bocina.GIRO_MANO
		en_mano.position = bocina.EN_MANO / escala
	# El acercamiento apunta a donde quedo la mano
	await process_frame
	var cerca: Node3D = vistas_mano[2][2]
	var camara := (vistas_mano[2][0] as SubViewport).find_children("*", "Camera3D", true, false)[0] as Camera3D
	camara.look_at_from_position(cerca.global_position + Vector3(-0.8, 0.1, 0.35), cerca.global_position)
	for i in 3:
		await process_frame
	_hoja(vistas_mano.map(func(par): return _captura(par[0])), prefijo + "mano.png")
	quit()
