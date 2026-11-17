extends Node3D
# Visor de la cucarrata: gira la camara alrededor y cambia de animacion.
# godot --path . tools/ver_cucarrata.tscn            (1-6 animaciones, flechas giran, rueda acerca)
# godot --path . tools/ver_cucarrata.tscn -- --fotos <carpeta>   (guarda las vistas y sale)

var cuca: Cucarrata
var cam: Camera3D
var angulo := 0.6
var alto := 0.8
var distancia := 3.2
var cerca := false   # la camara mira al cuello (fotos de la juntura)
const CORTOS := ["quieta", "camina", "ataca", "muere", "vuela", "agarra"]


func _ready() -> void:
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.08, 0.09, 0.12)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.3, 0.35, 0.45)
	entorno.environment.glow_enabled = true   # como de noche: que se vean las grietas
	add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.light_energy = 0.6
	add_child(sol)
	var piso := MeshInstance3D.new()
	piso.mesh = PlaneMesh.new()
	piso.mesh.size = Vector2(12, 12)
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.3, 0.3, 0.32)
	piso.material_override = concreto
	add_child(piso)
	cuca = Cucarrata.new()
	add_child(cuca)
	cam = Camera3D.new()
	add_child(cam)
	var args := OS.get_cmdline_user_args()
	var i := args.find("--fotos")
	if i >= 0:
		_fotos(args[i + 1])
	if args.has("--video"):
		_video()


# Recorre las 6 animaciones con la camara girando y el nombre en pantalla. Se graba con el
# Movie Maker de Godot: godot --path . tools/ver_cucarrata.tscn --write-movie x.avi --fixed-fps 30 -- --video
func _video() -> void:
	var letrero := Label.new()
	letrero.position = Vector2(16, 12)
	letrero.add_theme_font_size_override("font_size", 28)
	var capa := CanvasLayer.new()
	capa.add_child(letrero)
	add_child(capa)
	var tomas := [["quieta", 3.0], ["camina", 4.0], ["ataca", 3.0], ["vuela", 3.0], ["agarra", 3.0], ["muere", 2.5]]
	for toma in tomas:
		letrero.text = "%s  (%s)" % [toma[0], Cucarrata.ANIMS[toma[0]]]
		cuca.animar(toma[0], 0.2)
		var t := 0.0
		while t < toma[1]:
			t += get_process_delta_time()
			angulo += get_process_delta_time() * 0.6
			await get_tree().process_frame
	get_tree().quit()


func _fotos(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	cuca.animar("quieta", 0.0)
	var vistas := [[0.6, 0.5, 4.5], [PI, 0.4, 4.0], [PI * 0.5, 0.3, 4.0], [PI + 0.5, 0.25, 1.8], [PI - 0.9, 0.1, 2.2], [PI * 0.5, 0.05, 1.0, 1], [PI * 0.75, 0.35, 1.0, 1], [0.3, 0.6, 1.1, 1]]
	for k in vistas.size():
		angulo = vistas[k][0]; alto = vistas[k][1]; distancia = vistas[k][2]; cerca = vistas[k].size() > 3
		for f in 20: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/vista_%d.png" % [carpeta, k])
	cuca.animar("ataca", 0.0)
	angulo = PI + 0.6; alto = 0.5; distancia = 4.0
	for f in 15: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/ataca.png" % carpeta)
	get_tree().quit()


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT): angulo -= delta * 1.5
	if Input.is_key_pressed(KEY_RIGHT): angulo += delta * 1.5
	if Input.is_key_pressed(KEY_UP): alto += delta
	if Input.is_key_pressed(KEY_DOWN): alto -= delta
	var centro := (Vector3(0, 0.3, -0.5) if cerca else Vector3(0, 0.4, -0.3)) * cuca.tamano
	cam.position = centro + Vector3(sin(angulo), 0, cos(angulo)) * distancia + Vector3(0, alto, 0)
	cam.look_at(centro)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_6:
		cuca.animar(CORTOS[e.keycode - KEY_1])
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: distancia = max(1.0, distancia - 0.3)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: distancia += 0.3
