extends Node
# Prueba de las armas de fuego (Pistola.ARMAS) en la safehouse: te da las tres, saca cada una con
# la tecla 2 (Player.cambiar_arma), dispara una rafaga y guarda una captura de cada una.
#   godot --path . tools/armas/prueba_armas.tscn -- --capturas=<carpeta>
# Necesita ventana. Imprime las balas que quedan y sale. Las automaticas se disparan sosteniendo
# el clic (Input.action_press), para probar el giro y el calor de la Matraca; al final de cada
# una recarga y dice como quedo (la Tinaquera, cartucho por cartucho).

const SAFEHOUSE := "res://scenes/safehouse.tscn"
const OBJETOS := ["la_tinaquera", "la_matraca", "la_chicharra"]
const ESPERA := 150       # cuadros antes de empezar: que la safehouse acabe de armarse
const POR_ARMA := 420     # cuadros con cada arma

var _carpeta := ""
var _cuadro := -1
var _jugador: Player
var _zombi: Zombie
var _medir_mano := Callable()
var _mano_dist := -1.0
var _mano_info := ""
# El centro de abajo del guardamanos de cada larga, en el modelo de la mano (Player._modelo_arma),
# medido en models/armas/fuente/armas_caricatura.blend
const GUARDAMANOS := {"escopeta": Vector3(-0.392, 0.025, 0.028), "ametralladora": Vector3(-0.437, 0.044, 0.028), "subfusil": Vector3(-0.339, 0.062, 0.029)}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):
			_carpeta = arg.trim_prefix("--capturas=")
	# La safehouse tiene que ser la escena actual (Player._en_safehouse): este nodo se cuelga de la raiz
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		var yo := Node.new()
		yo.set_script(get_script())
		yo.name = "PruebaArmas"
		get_tree().root.add_child.call_deferred(yo)
		get_tree().change_scene_to_file.call_deferred(SAFEHOUSE)
		set_physics_process(false)
		return
	_cuadro = 0


func _physics_process(_delta: float) -> void:
	if _cuadro < 0:
		return
	_cuadro += 1
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Player
		if _jugador == null or _cuadro < ESPERA:
			_jugador = null if _cuadro < ESPERA else _jugador
			return
		var inventario := get_node("/root/Inventory")
		# Lugar para las tres: la mochila de la safehouse viene llena
		while inventario.items.size() > 2:
			inventario.remove_item(inventario.items.size() - 1)
		for nombre: String in OBJETOS:
			var ok: bool = inventario.add_item(load("res://resources/productos/%s.tres" % nombre))
			print("objeto ", nombre, ": ", "en el inventario" if ok else "NO CUPO")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_jugador.cambiar_arma(1)      # la pistola
		_cuadro = ESPERA
		return
	var pistola: Node = _jugador.get_node("Pistola")
	var t := _cuadro - ESPERA
	var paso := t % POR_ARMA
	var cual := t / POR_ARMA
	if cual > OBJETOS.size():
		print("armas que traes: ", pistola.armas())
		get_tree().quit()
		return
	if paso == 1 and cual > 0:
		_jugador.cambiar_arma(1)      # 2 otra vez: la siguiente
		print("en la mano: ", pistola.arma, " (", pistola.ARMAS[pistola.arma].nombre, "), balas ", pistola.balas)
	# Un zombi enfrente, en la mira, para ver el empujon (Tinaquera) y el frenado (automaticas)
	if paso == 30:
		var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
		# La camara casi derecha, y el zombi donde el rayo de la mira pasa a 1 m del piso (su pecho)
		_jugador.camera_pitch = -6.0
		_jugador.spring_arm.rotation_degrees.x = -6.0
		var camara := get_viewport().get_camera_3d()
		camara.force_update_transform()
		var centro := get_viewport().get_visible_rect().size / 2.0
		var origen := camara.project_ray_origin(centro)
		var dir := camara.project_ray_normal(centro)
		var piso := _jugador.global_position.y
		var largo := clampf((origen.y - piso - 1.0) / -dir.y, 6.0, 12.0) if dir.y < -0.01 else 8.0
		var donde := origen + dir * largo
		if mando:
			if _zombi and is_instance_valid(_zombi) and _zombi.estado != Zombie.Estado.MUERTO:
				_zombi.global_position = Vector3(donde.x, piso, donde.z)
			else:
				_zombi = mando.sacar(Vector3(donde.x, piso, donde.z), false)
	# Con la Tinaquera, uno aguantador: de cerca mata de un tiro y no se veria el empujon
	if paso == 31 and pistola.arma == "escopeta" and _zombi:
		_zombi._vida = 400
	if (paso == 52 or paso == 90) and _zombi and is_instance_valid(_zombi):
		print("  zombi a %.1f m: aciertos %d, dano_pistola %d, activos %d, empujon %.2f m/s, estado %d, frenado %s, vida %d" % [_zombi.global_position.distance_to(_jugador.global_position), pistola.aciertos, _zombi.dano_pistola, Zombie.activos.size(),
			_zombi._retroceso.length(), _zombi.estado, Time.get_ticks_msec() < _zombi._lento_hasta, _zombi._vida])
	var auto: bool = pistola.ARMAS[pistola.arma].auto
	if auto:
		if paso == 40:
			Input.action_press("attack")
		elif paso == 330:
			Input.action_release("attack")
	elif paso >= 40 and paso < 140 and paso % 25 == 0:
		pistola.disparar()
	if (paso == 51 or paso == 66) and _carpeta != "":
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png(_carpeta.path_join("arma_%d_%s_%d.png" % [cual, pistola.arma, paso]))
		if paso == 66:
			_guardar_cerca(imagen, "arma_%d_%s_manos.png" % [cual, pistola.arma])
	# La mano izquierda en el guardamanos: la muneca (hueso LeftHand, ya con el IK de AgarrePistola,
	# por eso se lee en skeleton_updated) contra el punto de abajo del guardamanos medido en el .blend
	if paso == 60 and GUARDAMANOS.has(pistola.arma):
		var esqueleto := _jugador.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		_medir_mano = func() -> void:
			var modelo: Node3D = _jugador._modelo_arma
			if modelo == null or not is_instance_valid(modelo):
				return
			var muneca := esqueleto.global_transform * esqueleto.get_bone_global_pose(esqueleto.find_bone("LeftHand")).origin
			var guarda: Vector3 = modelo.global_transform * GUARDAMANOS[pistola.arma]
			_mano_dist = muneca.distance_to(guarda)
			var g := esqueleto.global_transform
			var der: Vector3 = g * esqueleto.get_bone_global_pose(esqueleto.find_bone("RightHand")).origin
			if _jugador._guardamanos and is_instance_valid(_jugador._guardamanos):
				guarda = _jugador._guardamanos.global_position
			var hombro: Vector3 = g * esqueleto.get_bone_global_pose(esqueleto.find_bone("LeftUpperArm")).origin
			var codo: Vector3 = g * esqueleto.get_bone_global_pose(esqueleto.find_bone("LeftLowerArm")).origin
			var frente := (modelo.global_basis * Vector3.LEFT).normalized()
			var derecha := frente.cross(Vector3.UP).normalized()
			var arriba := derecha.cross(frente).normalized()
			var rel := guarda - der
			_mano_info = "guardamanos desde la muneca derecha (der, arr, frente) %s; brazo %.2f m, hombro a meta %.2f m; muneca desde la derecha %s; escala modelo %s" % [
				Vector3(rel.dot(derecha), rel.dot(arriba), rel.dot(frente)).snapped(Vector3.ONE * 0.001),
				hombro.distance_to(codo) + codo.distance_to(muneca), hombro.distance_to(guarda),
				Vector3((muneca - der).dot(derecha), (muneca - der).dot(arriba), (muneca - der).dot(frente)).snapped(Vector3.ONE * 0.001),
				modelo.global_basis.get_scale().snapped(Vector3.ONE * 0.01)]
		esqueleto.skeleton_updated.connect(_medir_mano)
	if paso == 66 and _medir_mano.is_valid() and _mano_dist >= 0.0:
		print("  mano izquierda a %.3f m del guardamanos (la muneca va ~0.07 m de la palma)" % _mano_dist)
		print("    ", _mano_info)
		var esqueleto := _jugador.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		esqueleto.skeleton_updated.disconnect(_medir_mano)
		_medir_mano = Callable()
		_mano_dist = -1.0
	# Que el zombi no tumbe al jugador antes de acabar (se lleva el inventario): lejos tras la rafaga
	if paso == 335 and _zombi and is_instance_valid(_zombi):
		_zombi.global_position = _jugador.global_position + Vector3(40.0, 0.0, 40.0)
	if paso == 150 or paso == 330:
		print("  cuadro %d: balas %d, tiros %d, recargando %s, calor %.2f, caliente %s" % [paso, pistola.balas, pistola.tiros,
			pistola.recargando(), pistola.calor(), pistola._sobrecalentada])
	if paso == 340:
		pistola.balas = mini(pistola.balas, 2)
		pistola.recargar()
	if paso == 380 and _carpeta != "":
		var imagen := get_viewport().get_texture().get_image()
		_guardar_cerca(imagen, "arma_%d_%s_suelta.png" % [cual, pistola.arma])
		imagen.save_png(_carpeta.path_join("arma_%d_%s_recarga.png" % [cual, pistola.arma]))
	if paso == 410:
		print("  tras recargar: balas ", pistola.balas, ", recargando ", pistola.recargando())


# El jugador de cerca (las manos, el arma, lo que cae): un recorte de la captura al triple
func _guardar_cerca(imagen: Image, archivo: String, centro := false) -> void:
	var tam := imagen.get_size()
	var x0 := 0.3 if centro else 0.25
	var recorte := imagen.get_region(Rect2i(int(tam.x * x0), int(tam.y * 0.4), int(tam.x * 0.4), int(tam.y * 0.45)))
	recorte.resize(recorte.get_width() * 3, recorte.get_height() * 3, Image.INTERPOLATE_NEAREST)
	recorte.save_png(_carpeta.path_join(archivo))
