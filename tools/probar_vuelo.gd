extends Node
# Video de salir volando (Player._salir_volando) con los jefes que pegan fuerte, en el safehouse:
# uno por uno sale enfrente, el jugador se queda quieto (godmode) y cuando un golpe lo avienta se ve
# en camara lenta. Si un jefe no te avienta en ESPERA s, pasa al siguiente.
#   godot --path . --write-movie x.avi --fixed-fps 30 --resolution 640x480 tools/probar_vuelo.tscn
#   godot --path . --headless tools/probar_vuelo.tscn -- --prueba   solo dice quien te avento y sale

const ESPERA := 90.0            # s de juego esperando el golpe fuerte de cada jefe
const LENTO := 0.3
const ADELANTA := 2.0          # esperando el golpe, el video va al doble (letrero "x2")

var _casa: Node
var _jugador: Player
var _cam: Camera3D
var _letrero: Label
var _jefe: Node3D
var _prueba := false


func _ready() -> void:
	_prueba = "--prueba" in OS.get_cmdline_user_args()
	_casa = load("res://scenes/safehouse.tscn").instantiate()
	add_child(_casa)
	_jugador = _casa.get_node("Player")
	# Sin lo que estorba en el video: gente, letreros, objetos tirados, maquinitas, palomas
	await get_tree().process_frame
	for h in _casa.get_children():
		var guion: Script = h.get_script()
		var archivo := guion.resource_path.get_file() if guion else ""
		if h is Label3D or h.name in ["Objetos", "Npc"] or archivo in ["Gente.gd", "Cuicos.gd", "DropsRaros.gd",
				"PiezaMapa.gd", "Chatarra.gd", "Maquinita.gd", "Palomas.gd"]:
			h.queue_free()
	for n in get_tree().get_nodes_in_group("npc"):
		if n is Node3D:
			n.visible = false
	for n in _casa.find_children("*", "Label3D", true, false):
		n.visible = false
	if not _prueba:
		_cam = Camera3D.new()
		add_child(_cam)
		_cam.current = true
		var capa := CanvasLayer.new()
		capa.layer = 20
		add_child(capa)
		_letrero = Label.new()
		_letrero.theme = preload("res://resources/ui/tema_pixel.tres")
		_letrero.position = Vector2(12, 425)
		_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
		_letrero.add_theme_constant_override("outline_size", 5)
		capa.add_child(_letrero)
	await _seg(2.0)
	var jefes := [
		["La cucarrata: su mordida", _cucarrata],
		["El pterodáctilo: garras y carga", _ptero],
		["El Panzón: su martillo", _panzon],
		["La Mojiganga: te agarra y te lanza", _catrina],
		["El Simi: su patada", _simi],
	]
	for jefe: Array in jefes:
		await _uno(jefe[0], jefe[1])
	_decir("")
	await _seg(1.0)
	get_tree().quit()


func _uno(nombre: String, sacar: Callable) -> void:
	_jugador.global_position = Vector3(5.0, 1.2, 25.0)
	_jugador.frijol.global_transform = Transform3D(Basis.IDENTITY, _jugador.frijol.global_position)
	_jugador.velocity = Vector3.ZERO
	await _seg(0.5)
	_jefe = sacar.call()
	_decir(nombre + ("" if _prueba else "  (x2)"))
	var t := 0.0
	var visto := ""
	if not _prueba:
		Engine.time_scale = ADELANTA
	while t < ESPERA and not _jugador.volando():
		await get_tree().process_frame
		t += get_process_delta_time()
		if _prueba and _jefe is Catrina:
			var e: String = Catrina.Estado.keys()[_jefe.estado] + (" atrapado" if _jugador.atrapado() else "")
			if e != visto:
				visto = e
				print("   %.1f %s" % [t, e])
	Engine.time_scale = 1.0
	if not _jugador.volando():
		print("%-45s no te avento en %d s" % [nombre, ESPERA])
	else:
		print("%-45s te avento a los %.1f s (cuadro %d del video)" % [nombre, t, Engine.get_frames_drawn()])
		var desde := _jugador.global_position
		Engine.time_scale = LENTO
		_decir(nombre + " (cámara lenta)")
		await _hasta(func(): return _jugador.get("_vuelo") in ["impacto", "levanta", ""], 3.0)
		await _seg(0.25)
		Engine.time_scale = 1.0
		_decir(nombre)
		await _hasta(func(): return not _jugador.volando(), 5.0)
		var d := Vector2(_jugador.global_position.x - desde.x, _jugador.global_position.z - desde.z).length()
		print("    volaste %.1f m" % d)
		await _seg(1.0)
	_quitar()
	await _seg(0.5)


func _quitar() -> void:
	if _jefe != null and is_instance_valid(_jefe):
		if _jefe.has_method("_quitar"):
			_jefe._quitar()
		else:
			_jefe.queue_free()
	_jefe = null
	for cria in get_tree().get_nodes_in_group("lombrices"):
		if cria is CriaCucarrata:
			cria.queue_free()
	_casa.get_node("Zombis").limpiar()
	if _jugador.atrapado():
		_jugador.soltar_atrapado()


func _cucarrata() -> Node3D:
	_casa._cucarrata_pare()
	return _casa._cucarrata


func _ptero() -> Node3D:
	_casa._pterodactilo()
	return _casa._ptero


func _panzon() -> Node3D:
	return _casa.get_node("Zombis").aparecer_panzon(_jugador.global_position + Vector3(0.0, 0.0, -14.0))


func _catrina() -> Node3D:
	_casa._soltar_catrina(_jugador.global_position + Vector3(0.0, 0.0, -16.0))
	return get_tree().get_first_node_in_group("catrina")


func _simi() -> Node3D:
	_casa._simi_bailador()
	_casa._simi.castigo = "patada"
	return _casa._simi


func _process(delta: float) -> void:
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.vida = salud.vida_max
	# El Simi: que siempre escoja la patada (no hay zombis para la horda de todos modos)
	if _jefe is JefeSimi and not _jugador.volando():
		_jefe.castigo = "patada"
	if _cam == null:
		return
	var j := _jugador.global_position
	var c := j + Vector3(0.0, 0.0, -8.0)
	if _jefe != null and is_instance_valid(_jefe):
		c = _jefe.global_position
	var hacia := Vector3(j.x - c.x, 0.0, j.z - c.z)
	var sep := minf(hacia.length(), 30.0)
	hacia = hacia.normalized() if hacia.length() > 0.1 else Vector3.BACK
	var lado := hacia.cross(Vector3.UP)
	var medio := j - hacia * sep * 0.5
	var lejos := maxf(8.0, (sep + 7.0) * 0.6)
	var mira := medio + Vector3.UP * 2.0
	# Del lado con mas espacio (el patio tiene casas y bardas), y sin atravesar paredes
	var a := _hasta_pared(mira, medio + lado * lejos + hacia * sep * 0.3 + Vector3.UP * 3.5)
	var b := _hasta_pared(mira, medio - lado * lejos + hacia * sep * 0.3 + Vector3.UP * 3.5)
	var sigue_a := lado.dot(_cam.global_position - medio) >= 0.0
	var desde := a if (a.distance_to(mira) >= b.distance_to(mira) * (0.7 if sigue_a else 1.4)) else b
	_cam.global_position = _cam.global_position.lerp(desde, minf(delta * 2.0 / maxf(Engine.time_scale, 0.1), 1.0))
	_cam.look_at(medio + Vector3.UP * 2.0, Vector3.UP)


# Hasta donde llega la camara de `desde` a `hasta` antes de una pared (como un SpringArm3D)
func _hasta_pared(desde: Vector3, hasta: Vector3) -> Vector3:
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta, 1, [_jugador.get_rid()])
	var choque := get_viewport().world_3d.direct_space_state.intersect_ray(rayo)
	if choque.is_empty():
		return hasta
	return choque.position + (desde - hasta).normalized() * 0.6


func _decir(texto: String) -> void:
	if _letrero:
		_letrero.text = texto


func _seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _hasta(cond: Callable, maximo: float) -> void:
	var t := 0.0
	while t < maximo and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
