extends Node
# Prueba del Simi bailador donde vive: la planicie del sureste de map_test (SimiPlanicie), de noche.
#   godot --path . tools/probar_simi_jefe.tscn                 jugarlo (de noche, a 90 m del Simi)
#   godot --path . --headless tools/probar_simi_jefe.tscn -- --prueba   revisiones y sale
#   godot --path . --write-movie x.avi --fixed-fps 30 --resolution 640x480 tools/probar_simi_jefe.tscn -- --video
#       la pelea con letreros (sin dano al jugador)
# Los zombis los saca la prueba (Zombis.sacar), con los que salen solos apagados.

var _jugador: Player
var _planicie: SimiPlanicie
var _zombis: Zombis
var _misiones: Node
var _bien := 0
var _total := 0


func _ready() -> void:
	var mapa: Node = load("res://scenes/map_test.tscn").instantiate()
	add_child(mapa)
	_jugador = mapa.get_node("Player")
	_planicie = mapa.get_node("SimiBailador")
	_zombis = mapa.get_node("Zombis")
	_misiones = get_node("/root/Misiones")
	_misiones.es_noche = true
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(90.0, 1.2, 0.0)
	var args := OS.get_cmdline_user_args()
	if "--prueba" in args:
		_zombis.set_physics_process(false)
		await _prueba()
		get_tree().quit()
	elif "--video" in args:
		_zombis.set_physics_process(false)
		await _video()
		get_tree().quit()


func _process(_delta: float) -> void:
	# Que siga de noche aunque el Ciclo diga otra cosa
	if _misiones and not _forzar_dia:
		_misiones.es_noche = true
	if _sin_dano:
		var salud := get_node_or_null("/root/Salud")
		if salud:
			salud.vida = salud.vida_max
	_mover_camara(_delta)


var _forzar_dia := false
var _sin_dano := true


func _revisar(que: String, ok: bool, nota := "") -> void:
	_total += 1
	_bien += 1 if ok else 0
	print("%s %s %s" % ["ok   " if ok else "FALLA", que, nota])


func _esperar(s: float) -> void:
	var hasta := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < hasta:
		await get_tree().process_frame


func _esperar_que(cond: Callable, maximo: float) -> bool:
	var hasta := Time.get_ticks_msec() + int(maximo * 1000.0)
	while Time.get_ticks_msec() < hasta:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


# `cuantos` zombis en un anillo de `r` m alrededor del Simi
func _sacar(cuantos: int, r: float) -> Array[Zombie]:
	var lista: Array[Zombie] = []
	var c := SimiPlanicie.CENTRO
	for i in cuantos:
		var a := TAU * i / cuantos + randf() * 0.2
		var lugar := Vector3(c.x + cos(a) * r, _planicie.jefe.piso + 0.5, c.z + sin(a) * r)
		lista.append(_zombis.sacar(lugar, false))
	return lista


func _prueba() -> void:
	await _esperar(2.0)
	var jefe := _planicie.jefe
	_revisar("de noche aparece bailando en la planicie", jefe != null and jefe.estado == JefeSimi.Estado.BAILA and not jefe.activa
		and Vector2(jefe.global_position.x, jefe.global_position.z).distance_to(Vector2(SimiPlanicie.CENTRO.x, SimiPlanicie.CENTRO.z)) < 1.0)
	if jefe == null:
		print("RESULTADO %d/%d" % [_bien, _total])
		return
	# El hueso Head esta en la base de la cabezota (1.6 m de alto), y bailando va agachado
	var alto := jefe._hueso("Head").y - jefe.piso
	_revisar("mide unos 7 m", alto > 4.0 and alto < 6.5, "base de la cabeza a %.1f m" % alto)
	# De dia se va; de noche otra vez esta
	_forzar_dia = true
	_misiones.es_noche = false
	await _esperar(0.3)
	_revisar("de dia se va", _planicie.jefe == null or not is_instance_valid(_planicie.jefe))
	_forzar_dia = false
	await _esperar(0.5)
	jefe = _planicie.jefe
	_revisar("de noche regresa", jefe != null and is_instance_valid(jefe))
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(50.0, 1.2, 0.0)
	await _esperar(0.3)
	_revisar("al acercarte empieza la pelea", jefe.activa and JefeSimi.activo == jefe)
	# Los zombis van a bailar con el, al compas
	var lista := _sacar(JefeSimi.JUNTA - 1, 35.0)
	# (alguno se puede atorar en el camino: con casi todos basta)
	await _esperar_que(func(): return jefe.bailando_cuantos() >= JefeSimi.JUNTA - 1, 25.0)
	_revisar("los zombis no van por ti: van a bailar con el", jefe.bailando_cuantos() >= JefeSimi.JUNTA - 3, "%d bailando" % jefe.bailando_cuantos())
	var desfase := 0.0
	for z in lista:
		if z.bailando:
			var ap: AnimationPlayer = z._animacion
			var d := absf(ap.current_animation_position - jefe.baile_desde())
			desfase = maxf(desfase, minf(d, jefe._largo_baile - d))
	_revisar("bailan al compas del Simi", desfase < 0.15, "desfase %.2f s" % desfase)
	_revisar("con menos de 12 todavia no te señala", jefe.estado == JefeSimi.Estado.BAILA, "%d" % jefe.bailando_cuantos())
	_sacar(JefeSimi.JUNTA - jefe.bailando_cuantos() + 1, 30.0)
	var señalo := await _esperar_que(func(): return jefe.estado == JefeSimi.Estado.SENALA, 15.0)
	_revisar("al juntar 12 deja de bailar y te señala", señalo)
	await _esperar(JefeSimi.SENALA_DURA + 0.3)
	var sueltos := 0
	for z in lista:
		if is_instance_valid(z) and z.despierto and not z.bailando and z.alerta and z._suelto_hasta > Time.get_ticks_msec():
			sueltos += 1
	_revisar("los suelta a todos contra ti", sueltos >= JefeSimi.JUNTA - 4 and jefe.bailando_cuantos() == 0, "%d sueltos" % sueltos)
	_zombis.limpiar()
	await _esperar_que(func(): return jefe.estado == JefeSimi.Estado.BAILA, 8.0)
	# La ola te pone a bailar
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(20.0, 1.2, 0.0)
	jefe._inmune_hasta = 0
	jefe._onda_reloj = 0.0
	var atrapo := await _esperar_que(func(): return jefe.jugador_bailando(), 4.0)
	_revisar("la ola sonica te pone a bailar de lejos", atrapo)
	if atrapo:
		var fig: Node = _jugador.figura
		var t: Variant = fig._arbol.get("parameters/estado/current_state") if fig.get("_arbol") else ""
		_revisar("bailas su mismo baile", str(t) == "baila", str(t))
		for i in 40:
			jefe.forcejear()
		_revisar("machacando sin que te peguen no sales (tope)", jefe.jugador_bailando() and absf(jefe.zafarse - JefeSimi.ZAFARSE_TOPE) < 0.01, "%.2f" % jefe.zafarse)
		var pateo := await _esperar_que(func(): return not jefe.jugador_bailando(), 12.0)
		_revisar("sin zombis cerca corre y te patea: te saca del baile", pateo and jefe.estado in [JefeSimi.Estado.PATEA, JefeSimi.Estado.JADEA], JefeSimi.Estado.keys()[jefe.estado])
	await _esperar_que(func(): return jefe.estado == JefeSimi.Estado.BAILA, 15.0)
	# Pegado a el bailas; con un golpe ya puedes zafarte
	_jugador.global_position = jefe.global_position + Vector3(5.0, 1.2, 0.0)
	jefe._inmune_hasta = 0
	await _esperar_que(func(): return jefe.jugador_bailando(), 2.0)
	_revisar("muy cerca bailas tu tambien", jefe.jugador_bailando())
	if jefe.jugador_bailando():
		jefe._te_pegaron()
		for i in 40:
			jefe.forcejear()
		_revisar("ya con un golpe, machacando sales", not jefe.jugador_bailando())
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(45.0, 1.2, 0.0)
	await _esperar_que(func(): return jefe.estado == JefeSimi.Estado.BAILA, 15.0)
	# Matar a la mitad de los que bailan lo enoja
	var otros := _sacar(8, 30.0)
	await _esperar_que(func(): return jefe.bailando_cuantos() >= 7, 25.0)
	var matados := 0
	for z in otros:
		if matados < JefeSimi.JUNTA / 2 and z.bailando:
			z.recibir_golpe(9999, z.global_position + Vector3.FORWARD, 1.0, 0, false)
			matados += 1
	await _esperar(0.2)
	_revisar("matas a la mitad de los que bailan: se enoja y te suelta a los demas", jefe.estado in [JefeSimi.Estado.SENALA, JefeSimi.Estado.JADEA], "%d matados, %s" % [matados, JefeSimi.Estado.keys()[jefe.estado]])
	_zombis.limpiar()
	await _esperar_que(func(): return jefe.estado == JefeSimi.Estado.BAILA, 10.0)
	# Dano: bailando le entra la mitad
	var antes := jefe.vida
	jefe._herir(100.0)
	_revisar("bailando le entra la mitad", absf(antes - jefe.vida - 50.0) < 0.1, "%.0f" % (antes - jefe.vida))
	_revisar("le pega la pistola (rayo)", not jefe.query_ray_hit(_jugador.global_position + Vector3.UP, (jefe._hueso("Chest") - _jugador.global_position - Vector3.UP).normalized(), 200.0, 0.1).is_empty())
	jefe.vida = JefeSimi.VIDA * 0.55
	jefe._herir(JefeSimi.VIDA * 0.2)
	_revisar("a media vida se le cae la bata (fase 2: junta 8)", jefe.fase == 2 and jefe.junta() == JefeSimi.JUNTA_2)
	jefe._herir(JefeSimi.VIDA * 4.0)
	await _esperar(1.0)
	_revisar("muere", jefe.estado == JefeSimi.Estado.MUERTA and JefeSimi.activo == null)
	_revisar("y no vuelve", _misiones.jefe_muerto("simi"))
	print("RESULTADO %d/%d" % [_bien, _total])


# --- Video (Movie Maker: el tiempo es del juego, se espera con timers) ---

var _cam: Camera3D
var _letrero: Label
var _jefe_video: JefeSimi
var _cam_lejos := 26.0


func _seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _decir(texto: String) -> void:
	_letrero.text = texto


func _mover_camara(delta: float) -> void:
	if _cam == null or not is_instance_valid(_jefe_video):
		return
	var c := _jefe_video.global_position + Vector3.UP * 3.0
	var j := _jugador.global_position
	var atras := j - c
	atras.y = 0.0
	atras = atras.normalized() if atras.length() > 0.1 else Vector3.BACK
	var desde := j + atras * _cam_lejos * 0.45 + atras.cross(Vector3.UP) * _cam_lejos * 0.3 + Vector3.UP * _cam_lejos * 0.32
	_cam.global_position = _cam.global_position.lerp(desde, minf(delta * 2.5, 1.0))
	_cam.look_at(c.lerp(j, 0.35), Vector3.UP)


# Espera (en tiempo del juego) a que `cond` se cumpla, `maximo` s a lo mas
func _hasta(cond: Callable, maximo: float) -> void:
	var t := 0.0
	while t < maximo and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


# Hasta que el Simi junte los suyos y señale: si el contador se estanca saca otro zombi
func _hasta_que_senale(maximo: float) -> void:
	var t := 0.0
	var antes := -1
	var quieto := 0.0
	var jefe := _jefe_video
	while t < maximo and jefe.estado != JefeSimi.Estado.SENALA:
		_decir("Bailando con él: %d de %d" % [jefe.bailando_cuantos(), jefe.junta()])
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		quieto = quieto + d if jefe.bailando_cuantos() == antes else 0.0
		antes = jefe.bailando_cuantos()
		if quieto > 4.0:
			quieto = 0.0
			_sacar(1, 25.0)


func _video() -> void:
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.saltar(true)
		ciclo.retener_noche = true
	_cam_lejos = 15.0
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_cam.global_position = SimiPlanicie.CENTRO + Vector3(40.0, 10.0, 25.0)
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_letrero = Label.new()
	_letrero.theme = preload("res://resources/ui/tema_pixel.tres")
	_letrero.position = Vector2(12, 425)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 5)
	capa.add_child(_letrero)
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(26.0, 1.2, 8.0)
	await _seg(3.0)
	_jefe_video = _planicie.jefe
	var jefe := _jefe_video
	jefe._inmune_hasta = Time.get_ticks_msec() + 25000
	_decir("De noche, el Simi baila en la planicie del sureste")
	await _seg(5.0)
	_decir("Los zombis no van por ti: van a bailar con él, al compás")
	_sacar(7, 30.0)
	await _seg(9.0)
	_sacar(5, 28.0)
	await _hasta_que_senale(30.0)
	_decir("Juntó %d: deja de bailar y te señala..." % jefe.junta())
	await _seg(JefeSimi.SENALA_DURA)
	_decir("...y te suelta a todos a la vez")
	await _seg(3.5)
	_zombis.limpiar()
	await _hasta(func(): return jefe.estado == JefeSimi.Estado.BAILA, 10.0)
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(18.0, 1.2, 6.0)
	_decir("La ola sónica: si te alcanza parado, bailas (se brinca o se rueda)")
	jefe._inmune_hasta = 0
	jefe._onda_reloj = 0.3
	await _hasta(func(): return jefe.jugador_bailando(), 6.0)
	_decir("Te agarró el baile: bailas lo mismo que él")
	await _seg(2.0)
	_decir("Machacas, pero sin que te peguen no pasas del tope...")
	for i in 25:
		jefe.forcejear()
		await _seg(0.06)
	_decir("...y si ningún zombi viene, corre a patearte")
	await _hasta(func(): return not jefe.jugador_bailando(), 10.0)
	_decir("La patada te saca del baile; jadeando le entra el doble")
	await _seg(4.0)
	await _hasta(func(): return jefe.estado == JefeSimi.Estado.BAILA, 12.0)
	_decir("Con zombis: te agarra el baile y sus bailarines te caen encima")
	_jugador.global_position = SimiPlanicie.CENTRO + Vector3(18.0, 1.2, 6.0)
	_sacar(10, 28.0)
	await _seg(6.0)
	jefe._inmune_hasta = 0
	jefe._onda_reloj = 0.0
	await _hasta(func(): return jefe.jugador_bailando(), 6.0)
	_sacar(4, 26.0)
	await _hasta_que_senale(25.0)
	await _seg(JefeSimi.SENALA_DURA + 3.0)
	_decir("Ya te pegaron: machacando te zafas")
	for i in 30:
		jefe.forcejear()
		await _seg(0.06)
	await _seg(2.0)
	_zombis.limpiar()
	_decir("A media vida se le cae la bata")
	jefe._inmune_hasta = Time.get_ticks_msec() + 600000
	jefe.vida = JefeSimi.VIDA * 0.52
	jefe._herir(JefeSimi.VIDA * 0.1)
	await _seg(4.0)
	_decir("Fase 2: olas dobles y suelta con 8")
	jefe._onda_reloj = 0.0
	await _seg(4.0)
	_decir("Muere")
	jefe._herir(JefeSimi.VIDA * 4.0)
	await _seg(4.0)
	_decir("")
