extends SceneTree
# Saca preview.png (frente y espalda, con su nombre) de cada personaje en
# models/personajes/pack_psx/<nombre>/<nombre>.fbx, y una hoja con todos en
# models/personajes/pack_psx/hoja.png. Necesita ventana (no --headless):
#   godot --path . -s tools/personajes/previews.gd
# Otra carpeta (la hoja solo sale con más de un personaje):
#   godot --path . -s tools/personajes/previews.gd -- --carpeta=res://models/personajes/protagonistas/
# Después: godot --path . --headless --import

var CARPETA := "res://models/personajes/pack_psx/"
const ANCHO := 256           # por vista; el preview es 2 vistas de ancho
const ALTO := 384
const COLUMNAS := 10         # de la hoja

var vista: SubViewport
var camara: Camera3D
var etiqueta: Label


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--carpeta="):
			CARPETA = a.get_slice("=", 1).trim_suffix("/") + "/"
	vista = SubViewport.new()
	vista.size = Vector2i(ANCHO, ALTO)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vista.transparent_bg = false
	vista.own_world_3d = true
	root.add_child(vista)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.18, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	entorno.environment = env
	vista.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 30, 0)
	sol.light_energy = 0.9
	vista.add_child(sol)
	camara = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	vista.add_child(camara)
	etiqueta = Label.new()
	etiqueta.position = Vector2(6, 4)
	etiqueta.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 4)
	vista.add_child(etiqueta)
	_correr.call_deferred()


func _correr() -> void:
	var nombres: Array[String] = []
	for d in DirAccess.get_directories_at(CARPETA):
		if FileAccess.file_exists(CARPETA + d + "/" + d + ".fbx"):
			nombres.append(d)
	nombres.sort()
	var previews: Array[Image] = []
	for n in nombres:
		var img := await _preview(n)
		img.save_png(ProjectSettings.globalize_path(CARPETA + n + "/preview.png"))
		previews.append(img)
		print("listo ", n)
	if nombres.size() < 2:
		quit()
		return
	# Hoja con todos, a media escala.
	var w := ANCHO          # 2 vistas a la mitad = ANCHO
	var h := ALTO / 2
	var filas := ceili(nombres.size() / float(COLUMNAS))
	var hoja := Image.create(w * COLUMNAS, h * filas, false, Image.FORMAT_RGB8)
	for i in previews.size():
		var p := previews[i]
		p.resize(w, h, Image.INTERPOLATE_NEAREST)
		hoja.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i((i % COLUMNAS) * w, (i / COLUMNAS) * h))
	hoja.save_png(ProjectSettings.globalize_path(CARPETA + "hoja.png"))
	print("hoja: %d personajes" % nombres.size())
	quit()


func _preview(n: String) -> Image:
	var modelo: Node3D = load(CARPETA + n + "/" + n + ".fbx").instantiate()
	vista.add_child(modelo)
	for a in modelo.find_children("*", "AnimationPlayer", true, false):
		(a as AnimationPlayer).stop()
	await process_frame
	var caja := _caja(modelo)
	var centro := caja.get_center()
	camara.size = maxf(caja.size.y, caja.size.x * ALTO / float(ANCHO)) * 1.12
	var final := Image.create(ANCHO * 2, ALTO, false, Image.FORMAT_RGB8)
	for lado in 2:
		var dir := Vector3(0, 0, 1) if lado == 0 else Vector3(0, 0, -1)
		camara.position = centro + dir * (caja.size.length() + 2.0)
		camara.look_at(centro, Vector3.UP)
		etiqueta.text = n if lado == 0 else ""
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vista.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		final.blit_rect(img, Rect2i(0, 0, ANCHO, ALTO), Vector2i(lado * ANCHO, 0))
	modelo.queue_free()
	await process_frame
	return final


# Caja de la malla ya deformada por el esqueleto (pose actual), en mundo.
func _caja(modelo: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var c := mi.global_transform * mi.get_aabb()
		var esq := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if esq and mi.skin:
			c = _caja_hueso(esq)
		caja = c if primera else caja.merge(c)
		primera = false
	return caja


# Con piel, get_aabb() es la de la malla en reposo y puede no coincidir con la
# pose: se usa la nube de huesos, con margen para cabeza, manos y pies.
func _caja_hueso(esq: Skeleton3D) -> AABB:
	var caja := AABB(esq.global_transform * esq.get_bone_global_pose(0).origin, Vector3.ZERO)
	for i in esq.get_bone_count():
		caja = caja.expand(esq.global_transform * esq.get_bone_global_pose(i).origin)
	return caja.grow(caja.size.y * 0.08)
