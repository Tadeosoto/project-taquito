extends Node3D
# Ver el rediseno del zombi normal (JJ, 2026-11-17): el monstruo_02 con la piel del Panzon
# (shaders/zombi_serenol.gdshader) en sus variantes: sin camisa, las cuatro camisas desgarradas y la
# femenina con pelo largo ralo. Aun no sale en el juego: aqui se arma cada uno como lo haria Zombie.
#   godot --path . tools/probar_zombi_serenol.tscn
#   Izquierda/Derecha: cual ver  A/D: girar  W/S: acercar  Espacio: quieto / caminando  F: todos
#   Con "-- --fotos" saca las fotos a user://zombi_fotos y se cierra.
# El shader necesita la pose de reposo de cada vertice en CUSTOM0 (centrada y en metros): sin ella
# no sirve en el modelo tal cual. _vestir la calcula con los huesos (el fbx trae la malla girada).

const SALIDA := "user://zombi_fotos"
const RUTA := "res://models/personajes/pack_psx/monstruo_02/monstruo_02.fbx"
const OX := -0.238255   # el esqueleto viene corrido en x
const SEPARA := 1.5
const VARIANTES := [
	["Sin camisa", {}],
	["Chivas", {"camisa": true, "diseno": 0, "color_base": Color(0.86, 0.84, 0.78), "color_raya": Color(0.82, 0.1, 0.13)}],
	["America", {"camisa": true, "diseno": 1, "color_base": Color(0.98, 0.8, 0.1), "color_detalle": Color(0.06, 0.12, 0.38)}],
	["Seleccion", {"camisa": true, "diseno": 2, "color_base": Color(0.0, 0.42, 0.22), "color_raya": Color(0.0, 0.33, 0.17), "color_detalle": Color(0.9, 0.9, 0.86)}],
	["Conalep", {"camisa": true, "diseno": 3, "color_base": Color(0.88, 0.88, 0.84), "color_detalle": Color(0.0, 0.45, 0.25)}],
	["Femenina", {}, true],
]
var _cam: Camera3D
var _ayuda: Label
var _modelos: Array[Node3D] = []
var _anims: Array[AnimationPlayer] = []
var _pelos: Array = []
var _cual := 0
var _giro := 0.4
var _lejos := 2.6
var _todos := false
var _camina := false

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.38, 0.45)
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.6
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 25, 0)
	sol.light_energy = 0.7
	sol.light_color = Color(0.75, 0.8, 1.0)
	add_child(sol)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(60, 60)
	piso.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.16, 0.17, 0.16)
	piso.material_override = mat
	add_child(piso)
	for i in VARIANTES.size():
		var v: Array = VARIANTES[i]
		var m := Zombie.modelo_skin(Zombie.SKINS.keys().find(RUTA), 1.0)
		add_child(m)
		m.position = Vector3((i - (VARIANTES.size() - 1) / 2.0) * SEPARA, 0, 0)
		var material := _vestir(m)
		for k in (v[1] as Dictionary):
			material.set_shader_parameter(k, v[1][k])
		var anim := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("h/Zombie_Idle")
		anim.seek(randf() * 2.0, true)
		_modelos.append(m)
		_anims.append(anim)
		if v.size() > 2:
			var pelo := PeloZombi.new()
			m.add_child(pelo)
			pelo.armar(m)
			_pelos.append(pelo)
		var nombre := Label3D.new()
		nombre.text = v[0]
		nombre.pixel_size = 0.003
		nombre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nombre.outline_size = 8
		nombre.position = m.position + Vector3(0, 2.1, 0)
		add_child(nombre)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	var capa := CanvasLayer.new()
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.position = Vector2(8, 8)
	_ayuda.add_theme_font_size_override("font_size", 12)
	capa.add_child(_ayuda)
	if "--fotos" in OS.get_cmdline_user_args():
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_ayuda.visible = false
		DirAccess.make_dir_recursive_absolute(SALIDA)
		_fotos()

func _process(delta: float) -> void:
	if _ayuda.visible == false and "--fotos" in OS.get_cmdline_user_args():
		return
	if Input.is_key_pressed(KEY_A): _giro -= delta * 1.5
	if Input.is_key_pressed(KEY_D): _giro += delta * 1.5
	if Input.is_key_pressed(KEY_W): _lejos = maxf(0.8, _lejos - delta * 2.0)
	if Input.is_key_pressed(KEY_S): _lejos = minf(8.0, _lejos + delta * 2.0)
	if _todos:
		_cam.position = Vector3(0, 1.3, 13.5)
		_cam.look_at(Vector3(0, 0.95, 0))
	else:
		var c := _modelos[_cual].position + Vector3(0, 0.95, 0)
		_cam.position = c + Vector3(sin(_giro), 0.12, cos(_giro)) * _lejos
		_cam.look_at(c)
	_ayuda.text = "%s   (Izq/Der: cual  A/D: girar  W/S: acercar  Espacio: %s  F: todos)" % [
			VARIANTES[_cual][0], "caminando" if _camina else "quieto"]

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT: _cual = posmod(_cual - 1, _modelos.size()); _todos = false
		KEY_RIGHT: _cual = posmod(_cual + 1, _modelos.size()); _todos = false
		KEY_F: _todos = not _todos
		KEY_SPACE:
			_camina = not _camina
			for a in _anims:
				a.play("h/Zombie_Walk_Fwd" if _camina else "h/Zombie_Idle")

func _vestir(m: Node3D) -> ShaderMaterial:
	var piel := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var malla := piel.mesh
	var k := float(Zombie.SKINS[RUTA])   # el modelo a escala 1 (la altura del zombi va aparte)
	var arr := malla.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var rep := PeloZombi.reposo(m)
	var reposo := PackedFloat32Array()
	reposo.resize(pos.size() * 4)
	for i in pos.size():
		reposo[i * 4] = (rep[i].x - OX) * k
		reposo[i * 4 + 1] = rep[i].y * k
		reposo[i * 4 + 2] = rep[i].z * k
		reposo[i * 4 + 3] = 1.0
	arr[Mesh.ARRAY_CUSTOM0] = reposo
	var formato: int = (malla.surface_get_format(0) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(malla.surface_get_primitive_type(0), arr, [], {}, formato)
	piel.mesh = nueva
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/zombi_serenol.gdshader")
	mat.set_shader_parameter("textura", (malla.surface_get_material(0) as BaseMaterial3D).albedo_texture)
	mat.set_shader_parameter("aliento_fijo", 0.85)
	piel.material_override = mat
	return mat

func _foto(archivo: String) -> void:
	for p in _pelos:
		p.asentar(1500)
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SALIDA + "/" + archivo)

func _fotos() -> void:
	for a in _anims:
		a.seek(0.5, true); a.pause()
	await get_tree().process_frame
	_cam.fov = 32
	_cam.position = Vector3(0, 1.3, 13.5)
	_cam.look_at(Vector3(0, 0.95, 0))
	await _foto("00_todos.png")
	_cam.fov = 40
	for i in _modelos.size():
		var c := _modelos[i].position
		_cam.position = c + Vector3(0.5, 1.15, 2.5)
		_cam.look_at(c + Vector3(0, 0.95, 0))
		await _foto("%02d_frente.png" % i)
		_cam.position = c + Vector3(-1.3, 1.3, -2.2)
		_cam.look_at(c + Vector3(0, 0.95, 0))
		await _foto("%02d_atras.png" % i)
	print("Fotos en ", ProjectSettings.globalize_path(SALIDA))
	get_tree().quit()


# Pelo largo ralo: mechones sueltos colgando de la cabeza, con verlet (gravedad y choque con la
# cabeza y el pecho). Se dibujan como tiras planas hacia la camara
class PeloZombi extends MeshInstance3D:
	const PUNTOS := 9
	const MECHONES := 50
	var _sk: Skeleton3D
	var _cabeza := -1
	var _pecho := -1
	var _anclas: Array[Vector3] = []      # en el espacio del hueso de la cabeza (reposo)
	var _largos: PackedFloat32Array
	var _anchos: PackedFloat32Array
	var _p: Array[PackedVector3Array] = []
	var _antes: Array[PackedVector3Array] = []
	var _centro_cabeza := Vector3.ZERO    # local de la cabeza
	var _radio_cabeza := 0.1              # m
	var _mesh := ImmediateMesh.new()

	# Reposo de cada vertice en el espacio del esqueleto (sus huesos en reposo por su bind)
	static func reposo(m: Node3D) -> PackedVector3Array:
		var piel := m.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var arr := piel.mesh.surface_get_arrays(0)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var por := huesos.size() / pos.size()
		var skin := piel.skin
		var mats: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var nombre := skin.get_bind_name(b)
			var hueso := sk.find_bone(nombre) if nombre != &"" else skin.get_bind_bone(b)
			mats.append(sk.get_bone_global_rest(hueso) * skin.get_bind_pose(b))
		var out := PackedVector3Array()
		out.resize(pos.size())
		for i in pos.size():
			var r := Vector3.ZERO
			for j in por:
				var w := pesos[i * por + j]
				if w > 0.0:
					r += (mats[huesos[i * por + j]] * pos[i]) * w
			out[i] = r
		return out

	func armar(m: Node3D) -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY
		_sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		_cabeza = _sk.find_bone("Head")
		_pecho = _sk.find_bone("UpperChest")
		var cab_rest := _sk.get_bone_global_rest(_cabeza)
		var rep := reposo(m)
		# El casco: vertices arriba de la cabeza, menos la frente y la cara
		var alto := -INF
		for r in rep:
			alto = maxf(alto, r.y)
		var hh := alto - cab_rest.origin.y
		var casco: Array[Vector3] = []
		var suma := Vector3.ZERO
		var n := 0
		for r in rep:
			var d := r - cab_rest.origin
			if d.y > 0.0 and absf(d.x) < hh and absf(d.z) < hh:
				suma += r; n += 1
			if d.y > hh * 0.45 and not (d.z > hh * 0.2 and d.y < hh * 0.85):
				casco.append(r)
		var centro := suma / maxf(n, 1)
		_centro_cabeza = cab_rest.affine_inverse() * centro
		var escala := m.scale.x
		var rmax := 0.0
		for r in casco:
			rmax = maxf(rmax, r.distance_to(centro))
		_radio_cabeza = rmax * escala * 0.95
		# Mechones ralos: por manchones (unos lados pelones), puntos al azar entre vertices vecinos
		var semilla := RandomNumberGenerator.new()
		semilla.seed = 7
		var intentos := 0
		while _anclas.size() < MECHONES and intentos < 5000:
			intentos += 1
			var a: Vector3 = casco[semilla.randi() % casco.size()]
			var b: Vector3 = casco[semilla.randi() % casco.size()]
			if a.distance_to(b) > hh * 0.35:
				continue
			var p := a.lerp(b, semilla.randf())
			var d := (p - centro).normalized()
			var manchon := sin(d.x * 5.0 + 1.3) * sin(d.z * 4.0 + 0.4) + sin(d.y * 7.0)
			if manchon < -0.2:
				continue   # pelon
			# mechones de 1 a 3 hebras delgadas que salen casi del mismo lugar
			var largo := semilla.randf_range(0.3, 0.75)
			for h in semilla.randi_range(1, 3):
				var off := Vector3(semilla.randf_range(-1, 1), 0, semilla.randf_range(-1, 1)) * hh * 0.04
				_anclas.append(cab_rest.affine_inverse() * (p + off))
				_largos.append(largo * semilla.randf_range(0.75, 1.1))
				_anchos.append(semilla.randf_range(0.003, 0.008))
		for i in _anclas.size():
			var pts := PackedVector3Array()
			pts.resize(PUNTOS)
			_p.append(pts)
			_antes.append(pts.duplicate())
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.045, 0.045)
		mat.roughness = 0.55
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		material_override = mat
		mesh = _mesh
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_reiniciar()

	func _cabeza_global() -> Transform3D:
		return _sk.global_transform * _sk.get_bone_global_pose(_cabeza)

	func _reiniciar() -> void:
		var t := _cabeza_global()
		for i in _anclas.size():
			var a := t * _anclas[i]
			for k in PUNTOS:
				_p[i][k] = a + Vector3.DOWN * _largos[i] * k / (PUNTOS - 1)
			_antes[i] = _p[i].duplicate()

	func asentar(pasos: int) -> void:
		for s in pasos:
			_paso(1.0 / 60.0)
		_dibujar()
		if OS.get_cmdline_user_args().has("--sonda"):
			var t := _cabeza_global()
			print("centro ", t * _centro_cabeza, " r ", _radio_cabeza)
			for i in range(0, _p.size(), 10):
				print(i, " ", _p[i][0], " -> ", _p[i][PUNTOS - 2], " ", _p[i][PUNTOS - 1])

	func _process(delta: float) -> void:
		_paso(minf(delta, 1.0 / 30.0))
		_dibujar()

	func _paso(dt: float) -> void:
		var t := _cabeza_global()
		var centro := t * _centro_cabeza
		var pecho := (_sk.global_transform * _sk.get_bone_global_pose(_pecho)).origin
		var radio_pecho := _radio_cabeza * 0.9
		for i in _anclas.size():
			var p := _p[i]
			var q := _antes[i]
			var seg := _largos[i] / (PUNTOS - 1)
			p[0] = t * _anclas[i]
			for k in range(1, PUNTOS):
				var v := (p[k] - q[k]) * 0.96
				q[k] = p[k]
				p[k] += v + Vector3.DOWN * 9.8 * dt * dt
			for it in 3:
				for k in range(1, PUNTOS):
					var d := p[k] - p[k - 1]
					var l := d.length()
					if l > 0.0001:
						p[k] = p[k - 1] + d / l * seg
					for esfera in [[centro, _radio_cabeza]]:
						var e := p[k] - (esfera[0] as Vector3)
						var r: float = esfera[1]
						if e.length() < r:
							p[k] = (esfera[0] as Vector3) + e.normalized() * r
			_p[i] = p
			_antes[i] = q

	func _dibujar() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		_mesh.clear_surfaces()
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in _anclas.size():
			var p := _p[i]
			var tono := 0.6 + 0.8 * float(i % 5) / 4.0
			for k in range(PUNTOS - 1):
				var a := p[k]
				var b := p[k + 1]
				var lado := (b - a).cross(cam.global_position - a).normalized()
				var wa := _anchos[i] * (1.0 - float(k) / PUNTOS * 0.8)
				var wb := _anchos[i] * (1.0 - float(k + 1) / PUNTOS * 0.8)
				var col := Color(tono, tono, tono)
				for v in [a - lado * wa, a + lado * wa, b + lado * wb, a - lado * wa, b + lado * wb, b - lado * wb]:
					_mesh.surface_set_color(col)
					_mesh.surface_add_vertex(v)
		_mesh.surface_end()
