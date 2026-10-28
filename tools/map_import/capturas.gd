extends SceneTree

# Guarda una captura de cada modelo horneado (.scn) de Sketchfab: preview.png en la
# carpeta del modelo (models/<grupo>/<modelo>/) y <nombre>_preview.png junto a
# cada .scn suelta (piezas del starter pack, la botarga del Simi). Sirve para
# ver que hay sin abrir el editor y de icono provisional del inventario.
#
#   godot --path . -s tools/map_import/capturas.gd             # solo las que faltan
#   godot --path . -s tools/map_import/capturas.gd -- --todas  # todas otra vez
#
# Necesita ventana (no --headless: el renderer dummy no dibuja).

const GRUPOS := ["tiendas", "casas", "props", "objetos", "personajes", "armas", "interiores"]
const FONDO := Color(0.5, 0.6, 0.7)
const FOV := 40.0
# Vista de 3/4 desde el frente (los glTF de Sketchfab miran a +Z)
const DIRECCION := Vector3(0.6, 0.35, 1.0)

var _mundo: Node3D
var _camara: Camera3D


func _initialize() -> void:
	var todas := "--todas" in OS.get_cmdline_user_args()
	_preparar_mundo()
	var trabajos := _buscar_trabajos(todas)
	print("capturas: %d por hacer" % trabajos.size())
	for trabajo in trabajos:
		await _capturar(trabajo[0], trabajo[1])
	quit()


func _preparar_mundo() -> void:
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = FONDO
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color.WHITE
	entorno.environment.ambient_light_energy = 0.7
	_mundo.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 30, 0)
	_mundo.add_child(sol)
	_camara = Camera3D.new()
	_camara.fov = FOV
	_mundo.add_child(_camara)


# [escena, png] de cada modelo
func _buscar_trabajos(todas: bool) -> Array:
	var trabajos := []
	for grupo in GRUPOS:
		var base := "res://models/%s/" % grupo
		for modelo in DirAccess.get_directories_at(base):
			var carpeta := base + modelo + "/"
			# <modelo>.scn es el modelo horneado (hornear_modelos.gd); las demas
			# .scn son piezas sueltas (starter pack, botarga del Simi)
			for archivo in DirAccess.get_files_at(carpeta):
				if archivo.get_extension() != "scn":
					continue
				var png := "preview.png" if archivo == modelo + ".scn" else archivo.get_basename() + "_preview.png"
				trabajos.append([carpeta + archivo, carpeta + png])
	if not todas:
		trabajos = trabajos.filter(func(t): return not FileAccess.file_exists(t[1]))
	return trabajos


func _capturar(escena_path: String, png_path: String) -> void:
	var escena := load(escena_path) as PackedScene
	if escena == null:
		push_error("capturas: no se pudo cargar " + escena_path)
		return
	var modelo := escena.instantiate() as Node3D
	_mundo.add_child(modelo)
	var players := modelo.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		var player := players[0] as AnimationPlayer
		var clips := Array(player.get_animation_list()).filter(func(c): return not String(c).contains("TPose"))
		if clips.size() > 0:
			player.play(clips[0])
			player.seek(0.5, true)
	for i in 3:
		await process_frame
	var caja := _caja(modelo)
	var radio: float = max(caja.size.length() * 0.5, 0.05)
	var distancia := radio / sin(deg_to_rad(FOV * 0.5))
	_camara.near = distancia * 0.01
	_camara.far = distancia * 10.0
	_camara.position = caja.get_center() + DIRECCION.normalized() * distancia
	_camara.look_at(caja.get_center())
	for i in 3:
		await process_frame
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(png_path))
	print("  %s %s" % ["ok" if error == OK else "ERROR", png_path])
	modelo.free()


# Las mallas con skin dan un AABB que no sigue la pose (a veces enorme o
# diminuto): en ese caso se encuadra por los huesos del esqueleto.
func _caja(modelo: Node3D) -> AABB:
	var mallas := modelo.find_children("*", "MeshInstance3D", true, false)
	var con_skin := mallas.any(func(m): return m.skin != null)
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	var caja := AABB()
	var primera := true
	if con_skin and esqueletos.size() > 0:
		for esqueleto: Skeleton3D in esqueletos:
			for hueso in esqueleto.get_bone_count():
				var punto := esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso).origin
				caja = AABB(punto, Vector3.ZERO) if primera else caja.expand(punto)
				primera = false
		# Los huesos no llegan a la orilla de la malla
		return caja.grow(caja.size.length() * 0.12)
	for malla: MeshInstance3D in mallas:
		var aabb := malla.global_transform * malla.get_aabb()
		caja = aabb if primera else caja.merge(aabb)
		primera = false
	return caja
