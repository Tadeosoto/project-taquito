extends SceneTree
# Mapa de islas UV de una textura de personaje, para saber qué pedazo es qué
# antes de repintarla. Necesita ventana:
#   godot --path . -s tools/personajes/islas.gd -- --carpeta=res://models/personajes/protagonistas/el_compa --textura=Character_04_original.png --modelo=el_compa.fbx
# Escribe en la carpeta islas.png (textura con número por isla), islas_modelo.png
# (el modelo con cada isla de un color y su número, 4 lados) e islas.json.

const MIN_PIXELES := 12

var carpeta := "res://models/personajes/protagonistas/el_compa"
var textura := "Character_04_original.png"
var modelo_archivo := "el_compa.fbx"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--carpeta="): carpeta = a.get_slice("=", 1)
		elif a.begins_with("--textura="): textura = a.get_slice("=", 1)
		elif a.begins_with("--modelo="): modelo_archivo = a.get_slice("=", 1)
	_correr.call_deferred()


func _correr() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(carpeta + "/" + textura))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var r := etiquetar(img)
	var etiqueta: PackedInt32Array = r.etiqueta
	var islas: Array = r.islas
	# Islas diminutas se quedan con su número, pero se marcan.
	var colores: Array[Color] = []
	for i in islas.size():
		colores.append(Color.from_hsv(fmod(i * 0.618034, 1.0), 0.75, 0.95))
	var pintada := Image.create(w, h, false, Image.FORMAT_RGBA8)
	pintada.fill(Color.BLACK)
	for y in h:
		for x in w:
			var e := etiqueta[y * w + x]
			if e >= 0:
				pintada.set_pixel(x, y, colores[e])
	var f := FileAccess.open(carpeta + "/islas.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(islas, "\t"))
	f.close()
	print("islas: ", islas.size())

	# 1) Textura original y pintada lado a lado con números, a 2x.
	var vista := SubViewport.new()
	vista.size = Vector2i(w * 4, h * 2)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var t1 := TextureRect.new()
	t1.texture = ImageTexture.create_from_image(img)
	t1.size = Vector2(w * 2, h * 2)
	t1.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vista.add_child(t1)
	var t2 := TextureRect.new()
	t2.texture = ImageTexture.create_from_image(pintada)
	t2.position = Vector2(w * 2, 0)
	t2.size = Vector2(w * 2, h * 2)
	t2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vista.add_child(t2)
	for isla in islas:
		if isla.pixeles < MIN_PIXELES: continue
		var c: Array = isla.caja
		for lado in 2:
			var l := _numero(str(isla.id))
			l.position = Vector2(c[0] + c[2] * 0.5, c[1] + c[3] * 0.5) * 2 + Vector2(lado * w * 2 - 8, -10)
			vista.add_child(l)
	await _esperar()
	vista.get_texture().get_image().save_png(ProjectSettings.globalize_path(carpeta + "/islas.png"))
	vista.queue_free()

	# 2) El modelo con la textura pintada, 4 lados.
	await _modelo(pintada, islas, etiqueta, w, h)
	quit()


# Separa las islas (píxeles conectados que no son fondo). Devuelve
# {etiqueta: número de isla por píxel o -1, islas: [{id, caja, pixeles, color}]}.
# Los números salen en orden de barrido (renglón por renglón), así que son
# estables mientras la textura original no cambie. Lo usa el_compa.gd.
static func etiquetar(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var etiqueta := PackedInt32Array()
	etiqueta.resize(w * h)
	etiqueta.fill(-1)
	var islas: Array = []
	for y in h:
		for x in w:
			if etiqueta[y * w + x] != -1 or not _lleno(img.get_pixel(x, y)):
				continue
			var id := islas.size()
			var pila := [Vector2i(x, y)]
			etiqueta[y * w + x] = id
			var caja := Rect2i(x, y, 1, 1)
			var suma := Color(0, 0, 0, 0)
			var n := 0
			while not pila.is_empty():
				var p: Vector2i = pila.pop_back()
				caja = caja.expand(p)
				suma += img.get_pixelv(p)
				n += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h: continue
					if etiqueta[q.y * w + q.x] != -1 or not _lleno(img.get_pixelv(q)): continue
					etiqueta[q.y * w + q.x] = id
					pila.append(q)
			islas.append({"id": id, "caja": [caja.position.x, caja.position.y, caja.size.x + 1, caja.size.y + 1], "pixeles": n, "color": (suma / n).to_html(false)})
	return {"etiqueta": etiqueta, "islas": islas}


static func _lleno(c: Color) -> bool:
	return c.a > 0.5 and maxf(c.r, maxf(c.g, c.b)) > 0.03


func _numero(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", 18)
	return l


func _esperar() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _modelo(pintada: Image, islas: Array, etiqueta: PackedInt32Array, w: int, h: int) -> void:
	const LADO := 512
	var vista := SubViewport.new()
	vista.size = Vector2i(LADO, LADO * 3 / 2)
	vista.own_world_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vista.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vista.add_child(cam)
	var m: Node3D = load(carpeta + "/" + modelo_archivo).instantiate()
	vista.add_child(m)
	var tex := ImageTexture.create_from_image(pintada)
	var mallas: Array[MeshInstance3D] = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		(mi as MeshInstance3D).material_override = mat
		mallas.append(mi)
	await process_frame
	var esq := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var caja := AABB(esq.global_transform * esq.get_bone_global_pose(0).origin, Vector3.ZERO)
	for i in esq.get_bone_count():
		caja = caja.expand(esq.global_transform * esq.get_bone_global_pose(i).origin)
	caja = caja.grow(caja.size.y * 0.08)
	var centro := caja.get_center()
	cam.size = caja.size.y * 1.05
	# Centro aproximado de cada isla en el modelo: promedio de los vértices cuya UV cae en ella.
	var puntos := _centros_3d(mallas[0], etiqueta, w, h, islas.size())
	var final := Image.create(LADO * 4, LADO * 3 / 2, false, Image.FORMAT_RGB8)
	var dirs := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
	for k in 4:
		cam.position = centro + dirs[k] * 20.0
		cam.look_at(centro, Vector3.UP)
		var etiquetas: Array[Label] = []
		await process_frame
		for id in puntos:
			var p: Vector3 = puntos[id].p
			# solo si la normal promedio mira a la cámara
			if puntos[id].n.dot(dirs[k]) < 0.3: continue
			var l := _numero(str(id))
			l.add_theme_font_size_override("font_size", 14)
			l.position = cam.unproject_position(p) - Vector2(6, 8)
			vista.add_child(l)
			etiquetas.append(l)
		await _esperar()
		var img := vista.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		final.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(k * LADO, 0))
		for l in etiquetas: l.queue_free()
	final.save_png(ProjectSettings.globalize_path(carpeta + "/islas_modelo.png"))
	vista.queue_free()


# Usa la malla deformada por la pose actual (piel aplicada a mano no hace falta:
# el modelo está en pose T y su malla en reposo coincide con la pose).
func _centros_3d(mi: MeshInstance3D, etiqueta: PackedInt32Array, w: int, h: int, total: int) -> Dictionary:
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var suma := {}
	for i in pos.size():
		var px := clampi(int(uv[i].x * w), 0, w - 1)
		var py := clampi(int(uv[i].y * h), 0, h - 1)
		var e := etiqueta[py * w + px]
		if e < 0: continue
		if not suma.has(e): suma[e] = {"p": Vector3.ZERO, "n": Vector3.ZERO, "c": 0}
		suma[e].p += pos[i]
		suma[e].n += nor[i]
		suma[e].c += 1
	var res := {}
	var xf := mi.global_transform
	for e in suma:
		res[e] = {"p": xf * (suma[e].p / suma[e].c), "n": (xf.basis * suma[e].n).normalized()}
	return res
