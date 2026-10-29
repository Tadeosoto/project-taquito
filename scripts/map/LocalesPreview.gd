extends Node3D

# Vista previa de las casas-local (MapPuntos._make_local_giro) sin regenerar el mapa:
# una calle con una hilera de casas Urbi de 1 piso de un lado y de 2 pisos del otro,
# con un local de cada giro intercalado, armados con el mismo codigo del mapa
# (MapCasas y MapPuntos leen los JSON que esto escribe en user:// al entrar).
#
#   godot --path . scenes/locales_preview.tscn
#   godot --path . scenes/locales_preview.tscn -- --capturas[=CARPETA] [--solo=TEXTO]
#
# WASD/flechas mueven la camara (Shift corre), boton derecho del mouse + mover para
# mirar, Q/E bajan y suben, Tab salta de local en local, 1/2/3 deterioro bajo, medio y
# alto, N noche (MapNocheDebug) y C guarda una captura en user://capturas.
# Con --capturas recorre todos los locales de dia y de noche, guarda las capturas
# en CARPETA (o user://capturas) y se cierra.

const CASAS_JSON := "user://casas_preview.json"
const PUNTOS_JSON := "user://puntos_preview.json"
const ASFALTO := preload("res://textures/map/asfalto.png")
const BANQUETA := preload("res://textures/map/banqueta.png")
const SUELO := preload("res://textures/map/suelo.png")
const SUELO_SHADER := preload("res://shaders/ps1_suelo.gdshader")

const FACHADA := 7.0      # distancia del eje de la calle a las fachadas
const ARROYO := 4.0       # medio arroyo
const FONDO_LOCAL := 10.0
# Frente y fondo de las casas Urbi (huellas_tiendas.json)
const CASAS_1P := {"urbi_1p_a": Vector2(6.79, 7.37), "urbi_1p_b": Vector2(6.8, 7.37), "urbi_1p_c": Vector2(7.59, 7.37)}
const CASAS_2P := {"urbi_2p_a": Vector2(7.5, 6.94), "urbi_2p_b": Vector2(8.42, 6.94), "urbi_2p_c": Vector2(8.58, 6.94)}
const COLORES := ["#e05a47", "#f2994a", "#f2c94c", "#7cc06a", "#4aa3df", "#b07cc6", "#e8e2d0"]
# [tipo, nombre, frente del lote] de cada hilera
const HILERA_1P := [
	["abarrotes", "Abarrotes Lupita", 5.5], ["licoreria", "Depósito El Güero", 6.0],
	["farmacia", "Farmacia San José", 7.0], ["ferreteria", "Ferretería Az", 5.0],
	["oxxo", "Oxo", 8.0], ["taqueria", "Tacos El Primo", 6.5],
	["purificadora", "Purificadora de Agua Cristal", 7.0],
]
const HILERA_2P := [
	["abarrotes", "Mini Super Mary", 6.0], ["licoreria", "Six La Esquina", 7.5],
	["farmacia", "Farmacias Dr Simio", 5.0], ["ferreteria", "Tlapalería Juárez", 7.0],
	["oxxo", "Oxo", 7.0], ["taqueria", "Taquería Los Compas", 5.5],
]
const VELOCIDAD := 6.0

var _locales := []   # [x, z de la fachada, lado (+1 norte / -1 sur / 0 puesto), nombre]
var _solo := ""      # --solo=TEXTO: solo captura los que tengan TEXTO en el nombre
var _casas_1p := []   # x del centro de cada casa de la hilera de 1 piso
# El puesto de tacos viejo (modelo de Sketchfab) para compararlo con el nuevo
var _puesto_viejo := {}
var _camara: Camera3D
var _actual := -1
var _mirada := Vector2.ZERO   # yaw, pitch (grados)


func _enter_tree() -> void:
	# Antes del _ready de Casas y Puntos
	var casas := []
	var puntos := []
	_hilera(HILERA_1P, 1, CASAS_1P, casas, puntos)
	_hilera(HILERA_2P, 2, CASAS_2P, casas, puntos)
	_puestos(puntos)
	_guardar(CASAS_JSON, {"casas": casas})
	_guardar(PUNTOS_JSON, {"puntos": puntos})


# Casa, local, casa, local... con las fachadas a FACHADA m del eje. La hilera de 1 piso
# va al norte (fachada a +Z), la de 2 al sur (fachada a -Z)
func _hilera(hilera: Array, pisos: int, modelos: Dictionary, casas: Array, puntos: Array) -> void:
	var lado := 1.0 if pisos == 1 else -1.0
	var rot := 0.0 if pisos == 1 else PI
	var z := -FACHADA * lado
	var x := -60.0
	var nombres := modelos.keys()
	for i in hilera.size() + 1:
		var modelo: String = nombres[i % nombres.size()]
		var casa: Vector2 = modelos[modelo]
		casas.append({"modelo": modelo, "x": x + casa.x / 2.0, "z": z, "rotacion_y": rot,
			"ancho": casa.x, "fondo": casa.y, "pisos": pisos, "color": COLORES[(i * 3 + pisos) % COLORES.size()], "colonia": ""})
		if pisos == 1:
			_casas_1p.append(x + casa.x / 2.0)
		x += casa.x
		if i == hilera.size():
			break
		var local: Array = hilera[i]
		var ancho: float = local[2]
		puntos.append({"tipo": local[0], "nombre": local[1], "x": x + ancho / 2.0, "z": z - lado * FONDO_LOCAL / 2.0,
			"rotacion_y": rot, "ancho": ancho, "fondo": FONDO_LOCAL, "pisos": pisos,
			"giro": local[0], "interactivo": true, "aire_libre": false, "origen": "preview/%d/%d" % [pisos, i]})
		_locales.append([x + ancho / 2.0, z, lado, "%s (%d piso%s)" % [local[1], pisos, "" if pisos == 1 else "s"]])
		x += ancho


# Puestos de tacos en la banqueta de la hilera de 1 piso, frente a las casas: el viejo
# (modelo Cara1, se arma en _ready) y el nuevo con y sin flecha
func _puestos(puntos: Array) -> void:
	var orilla := ARROYO + 0.3   # su frente detras de la guarnicion
	_puesto_viejo = {"tipo": "puesto_tacos", "nombre": "Tacos viejo", "x": _casas_1p[1], "z": -(orilla + 2.0),
		"rotacion_y": 0.0, "ancho": 4.0, "fondo": 4.0, "giro": "puesto_tacos", "interactivo": true, "aire_libre": true}
	_locales.append([_casas_1p[1], -orilla, 0.0, "Puesto de tacos VIEJO"])
	for j in 2:
		var x: float = _casas_1p[3 + 2 * j]
		puntos.append({"tipo": "puesto_tacos", "nombre": "Tacos nuevo %d" % j, "x": x, "z": -(orilla + 1.0),
			"rotacion_y": 0.0, "ancho": 2.5, "fondo": 2.0, "giro": "puesto_tacos", "interactivo": j == 0, "aire_libre": true,
			"origen": "preview/puesto/%d" % j})
		_locales.append([x, -orilla, 0.0, "Puesto de tacos NUEVO" + (" (con flecha)" if j == 0 else " (sin flecha)")])


func _guardar(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _ready() -> void:
	_calle()
	var puntos := get_node("Puntos") as MapPuntos
	var viejo := puntos._make_prefab(_puesto_viejo)
	viejo.add_child(puntos._marcador(_puesto_viejo))
	viejo.position = Vector3(_puesto_viejo["x"], 0.0, _puesto_viejo["z"])
	puntos.add_child(viejo)
	_camara = Camera3D.new()
	_camara.fov = 62.0
	add_child(_camara)
	_camara.make_current()
	_vista_general()
	Deterioro.configurar(0.6, 400.0)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--solo="):
			_solo = arg.get_slice("=", 1)
	for arg in args:
		if arg.begins_with("--capturas"):
			var carpeta := arg.get_slice("=", 1) if arg.contains("=") else "user://capturas"
			_capturas.call_deferred(carpeta)


# Piso, arroyo y banquetas con los mismos shaders que el mapa
func _calle() -> void:
	_plano(Vector3(400.0, 0.0, 400.0), Vector3(0.0, -0.02, 0.0), SUELO, 3.0, 0)
	_plano(Vector3(400.0, 0.0, ARROYO * 2.0), Vector3(0.0, 0.0, 0.0), ASFALTO, 4.0, 1)
	for lado in [-1.0, 1.0]:
		var ancho := FACHADA - ARROYO + 12.0
		_plano(Vector3(400.0, 0.15, ancho), Vector3(0.0, 0.0, lado * (ARROYO + ancho / 2.0)), BANQUETA, 1.0, 2)


func _plano(size: Vector3, pos: Vector3, textura: Texture2D, tile: float, piso_tipo: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = SUELO_SHADER
	material.set_shader_parameter("albedo_texture", textura)
	material.set_shader_parameter("tile_size", tile)
	material.set_shader_parameter("piso_tipo", piso_tipo)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, maxf(size.y, 0.02), size.z)
	box.material = material
	malla.mesh = box
	malla.position = pos + Vector3(0.0, maxf(size.y, 0.02) / 2.0 - 0.01, 0.0)
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla)


func _vista_general() -> void:
	_poner(Vector3(-30.0, 14.0, 26.0), Vector3(-10.0, 2.0, 0.0))


func _poner(desde: Vector3, hacia: Vector3) -> void:
	_camara.global_position = desde
	_camara.look_at(hacia)
	_mirada = Vector2(_camara.rotation_degrees.y, _camara.rotation_degrees.x)


# Del otro lado de la calle viendo el local `i`; `cerca`: desde la orilla de su banqueta
func _ver_local(i: int, cerca := false) -> void:
	var local: Array = _locales[i]
	var x: float = local[0]
	var z: float = local[1]
	var lado: float = local[2]
	if lado == 0.0:
		# Puesto en la banqueta de enfrente (z = orilla de la banqueta)
		if cerca:
			_poner(Vector3(x + 1.0, 1.6, z + 3.2), Vector3(x, 1.1, z - 1.0))
		else:
			_poner(Vector3(x + 3.5, 1.7, -z), Vector3(x, 1.2, z - 1.0))
	elif cerca:
		_poner(Vector3(x + 0.6, 1.6, z + lado * 4.0), Vector3(x, 1.3, z - lado * 3.0))
	else:
		_poner(Vector3(x + 2.5, 1.7, -z * 0.75), Vector3(x, 2.4, z))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_mirada -= Vector2((event as InputEventMouseMotion).relative.x, (event as InputEventMouseMotion).relative.y) * 0.2
		_mirada.y = clampf(_mirada.y, -85.0, 85.0)
		_camara.rotation_degrees = Vector3(_mirada.y, _mirada.x, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_TAB:
				_actual = (_actual + 1) % _locales.size()
				_ver_local(_actual)
				print(_locales[_actual][3])
			KEY_1:
				Deterioro.configurar(0.25, 400.0)
			KEY_2:
				Deterioro.configurar(0.6, 400.0)
			KEY_3:
				Deterioro.configurar(1.0, 400.0)
			KEY_C:
				DirAccess.make_dir_recursive_absolute("user://capturas")
				_captura("user://capturas/captura_%d.png" % Time.get_ticks_msec())


func _process(delta: float) -> void:
	var mover := Vector3(
		Input.get_axis("move_left", "move_right"),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		Input.get_axis("move_forward", "move_backward"))
	if mover != Vector3.ZERO:
		var rapido := 3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		_camara.global_position += _camara.global_basis * mover * VELOCIDAD * rapido * delta


func _captura(path: String) -> void:
	_camara.get_viewport().get_texture().get_image().save_png(path)
	print("Captura: ", ProjectSettings.globalize_path(path))


func _esperar(cuadros := 6) -> void:
	for i in cuadros:
		await get_tree().process_frame


func _capturas(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	# Que se armen los muebles y las casas
	await _esperar(30)
	var noche := get_node("NocheDebug")
	print("Locales: ", get_node("Puntos").get_child_count(), ", celdas de casas: ", get_node("Casas").get_child_count())
	_poner(Vector3(-10.0, 90.0, 0.1), Vector3(-10.0, 0.0, 0.0))
	await _esperar()
	_captura("%s/00_arriba.png" % carpeta)
	for de_noche in [false, true]:
		var sufijo := "noche" if de_noche else "dia"
		if de_noche:
			noche.set("duracion", 0.01)
			noche.set("_meta", 1.0)
			await _esperar(10)
		_vista_general()
		await _esperar()
		_captura("%s/00_general_%s.png" % [carpeta, sufijo])
		_poner(Vector3(-30.0, 14.0, -26.0), Vector3(-10.0, 2.0, 0.0))
		await _esperar()
		_captura("%s/00_general_sur_%s.png" % [carpeta, sufijo])
		for i in _locales.size():
			if _solo != "" and not String(_locales[i][3]).contains(_solo):
				continue
			_ver_local(i)
			await _esperar()
			_captura("%s/%02d_%s_%s.png" % [carpeta, i + 1, String(_locales[i][3]).validate_filename().replace(" ", "_"), sufijo])
			if not de_noche:
				_ver_local(i, true)
				await _esperar()
				_captura("%s/%02d_%s_cerca.png" % [carpeta, i + 1, String(_locales[i][3]).validate_filename().replace(" ", "_")])
	get_tree().quit()
