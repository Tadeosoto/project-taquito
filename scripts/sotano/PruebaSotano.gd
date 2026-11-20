extends Node3D

# El Sotano solo, para probarlo sin la safehouse ni el mapa (scenes/sotano_prueba.tscn):
#   godot --path . scenes/sotano_prueba.tscn
# Te pone dentro, al pie de la escalera, con el jugador de verdad sin pelea (como CasaPropia al
# entrar) y la misma escala x1.25. Teclas (en pantalla, F1 las esconde):
#   .  permiso de los Gotera y +50 fichas      P  +$500
#   K  quitar el permiso (para probar la cuota del de la puerta; vuelve a poner la cadena)
#   H  todas las EL GORDO "calientes" (la sena: el foco de la marquesina parpadea)
#   R  de vuelta al pie de la escalera          F12 empezar de cero
# La flecha de arriba de la escalera (la de salir) aqui te regresa abajo.
# Con -- --foto=<archivo.png> guarda una captura a los 2 s y sale (para revisarla sin jugar).
# Con -- --fotos=<carpeta> guarda una captura desde cada camara de FOTOS (bajas y de lado, para
# ver si algo flota o se ve hueco) y sale.
# Con -- --gordo=<carpeta> abre una EL GORDO, jala la palanca y guarda cuadros, y sale.
# Con -- --poker=<carpeta> se sienta al poker y guarda un cuadro cada 0.15 s mientras reparte y
# juega (para ver las cartas moverse), y sale.
# Con -- --video una camara recorre cada sonido del ambiente con su letrero, y sale. Para grabarlo:
#   godot --path . scenes/sotano_prueba.tscn --write-movie sonidos.avi --fixed-fps 30 -- --video

const SOTANO := preload("res://scenes/casas/sotano.tscn")
const ESCALA := 1.25                 # la de CasaPropia
const ABAJO := Vector3(6.0, -1.4, 3.11)    # el ultimo tramo de la escalera, antes de la cadena
const ARRIBA := Vector3(2.2, 1.2, 3.11)    # donde te deja CasaPropia al entrar
const PUERTA := Vector3(0.35, 0.0, 3.11)
const PESOS := 1000
const TEXTO := """El Sótano (prueba)
. permiso y +50 fichas · P +$500
K quitar permiso (probar la cuota)
H EL GORDO calientes · R al pie de la escalera · V pase VIP
F12 de cero · F1 esconder"""

# Camaras para --fotos: nombre -> [desde, hacia], en metros del cuarto (antes de la escala)
const FOTOS := {
	"escalera": [Vector3(9.0, -1.2, 3.1), Vector3(5.0, -1.6, 3.1)],
	"maquinitas": [Vector3(14.5, -1.2, 4.6), Vector3(12.5, -2.0, -1.5)],
	"gabinete_lado": [Vector3(12.2, -2.2, 1.2), Vector3(11.0, -2.0, -1.6)],
	"ventanilla_baja": [Vector3(8.4, -2.35, 2.6), Vector3(8.2, -2.2, -0.4)],
	"salon1_sur": [Vector3(12.0, -1.2, 1.0), Vector3(15.0, -2.2, 7.5)],
	"barra": [Vector3(26.0, -1.3, 5.0), Vector3(25.0, -1.8, -1.8)],
	"salon2": [Vector3(21.5, -0.8, 6.5), Vector3(30.0, -2.4, 0.0)],
	"poker": [Vector3(30.0, -1.0, 7.0), Vector3(27.5, -2.0, 3.6)],
	"mesera": [Vector3.ZERO, Vector3.FORWARD],
	"vip_puerta": [Vector3(31.8, -1.2, 2.6), Vector3(35.2, -1.4, 1.9)],
	"vip": [Vector3(36.0, -0.9, 2.3), Vector3(40.0, -2.0, -0.4)],
	"vip_tubo": [Vector3(39.4, -1.5, 1.2), Vector3(41.0, -1.6, -0.6)],
	"vip_sillones": [Vector3(38.0, -1.2, 0.0), Vector3(40.2, -2.0, 2.4)],
	"dulcero": [Vector3(37.4, -1.4, 5.0), Vector3(36.0, -1.95, 6.0)],
	"rocola_diana": [Vector3(25.5, -1.4, 5.2), Vector3(25.6, -1.4, 8.0)],
	"barriles": [Vector3(31.6, -1.3, 5.6), Vector3(34.3, -2.0, 7.3)],
	"poker_redonda": [Vector3(30.2, -0.9, 6.0), Vector3(27.5, -1.9, 3.6)],
	"fichas_cerca": [Vector3(28.2, -1.55, 4.4), Vector3(27.7, -1.85, 3.6)],
	"barra_neon": [Vector3(26.0, -1.5, 2.8), Vector3(26.0, -1.6, -2.0)],
	"dados_ruleta": [Vector3(31.0, -1.3, 2.0), Vector3(33.2, -1.5, -1.8)],
	"baccarat": [Vector3(25.6, -1.3, 7.4), Vector3(23.4, -1.9, 5.0)],
	"blackjack": [Vector3(30.6, -1.2, 5.4), Vector3(32.4, -1.9, 2.9)],
	"turbios_trato": [Vector3(31.8, -1.3, 0.9), Vector3(33.7, -1.6, -0.6)],
	"turbios_borracho": [Vector3(27.0, -1.4, 2.2), Vector3(28.1, -1.6, 0.7)],
	"vicio_cerca": [Vector3(26.4, -1.6, 4.3), Vector3(25.9, -1.95, 3.6)],
	"borracho_cerca": [Vector3(28.6, -1.3, 1.6), Vector3(28.1, -1.35, 0.75)],
	"poker_vicios": [Vector3(27.5, -1.2, 5.6), Vector3(27.5, -1.9, 3.0)],
	"bano_puerta": [Vector3(31.5, -1.3, 5.6), Vector3(35.5, -1.7, 5.0)],
	"bano": [Vector3(35.7, -1.15, 4.4), Vector3(38.6, -2.1, 4.9)],
	"bano_espejo": [Vector3(36.6, -1.2, 5.6), Vector3(36.3, -1.4, 7.4)],
	"refri": [Vector3(28.6, -1.5, 1.4), Vector3(30.7, -1.6, -1.6)],
	"palanca": [Vector3(12.0, -1.3, 0.1), Vector3(11.2, -1.45, -1.6)],
	"neon_gordo": [Vector3(8.6, -1.3, 3.6), Vector3(12.9, -0.8, 3.0)],
	"neon_sur": [Vector3(13.0, -1.4, 1.6), Vector3(13.0, -1.1, 8.0)],
	"neon_poker_bano": [Vector3(29.5, -1.4, 3.0), Vector3(35.0, -1.1, 4.2)],
	"neon_barra": [Vector3(26.0, -1.6, 3.6), Vector3(26.0, -2.0, -0.3)],
}

var _sotano: Node3D
var _player: Player
var _ayuda: Label
var _estado: Label


func _ready() -> void:
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.22, 0.26)
	env.ambient_light_energy = 0.6
	ambiente.environment = env
	add_child(ambiente)
	_player = get_node("Player") as Player
	var cartera := get_node("/root/Cartera")
	cartera.pesos = PESOS
	_armar(false)
	_armar_pantalla()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--foto="):
			await get_tree().create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--foto="))
			get_tree().quit()
		elif arg.begins_with("--desague="):
			await _fotos_desague(arg.trim_prefix("--desague="))
			get_tree().quit()
		elif arg.begins_with("--mesas="):
			await _fotos_mesas(arg.trim_prefix("--mesas="))
			get_tree().quit()
		elif arg.begins_with("--gordo="):
			await _fotos_gordo(arg.trim_prefix("--gordo="))
			get_tree().quit()
		elif arg.begins_with("--poker="):
			await _fotos_poker(arg.trim_prefix("--poker="))
			get_tree().quit()
		elif arg.begins_with("--fotos="):
			await _fotos(arg.trim_prefix("--fotos="))
			get_tree().quit()
		elif arg == "--video":
			await _video()
			get_tree().quit()


# El recorrido de --video: la camara va de un sonido a otro (la camara activa es la que oye)
func _video() -> void:
	if _ayuda:
		_ayuda.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)
	var letrero := Label.new()
	letrero.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	letrero.offset_top = 14.0
	letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letrero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letrero.add_theme_font_size_override("font_size", 20)
	letrero.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	letrero.add_theme_constant_override("outline_size", 8)
	capa.add_child(letrero)
	var s := _sotano
	var neon: Transform3D = s.call("marca", "Neon")
	var bocina: Vector3 = (s.call("marca", "Bocina") as Transform3D).origin
	# [letrero, desde, hasta, hacia, segundos] en metros del cuarto
	var tomas := [
		["Murmullo de casino\n(salón de EL GORDO)", FOTOS.escalera[0], FOTOS.salon1_sur[0], FOTOS.salon1_sur[1], 7.0],
		["Zumbido del neón\n(solo se oye de cerca)", neon.origin + neon.basis.z * 4.0, neon.origin + neon.basis.z * 0.8, neon.origin, 7.0],
		["Cumbia de la bocina\n(el stack de Splice)", bocina + Vector3(0.0, 0.3, -6.0), bocina + Vector3(0.0, 0.1, -1.4), bocina, 10.0],
		["Murmullo del salón del póker", FOTOS.salon2[0], FOTOS.poker[0], FOTOS.poker[1], 7.0],
		["Plática de la barra\ny botellas que chocan", FOTOS.barra[0], FOTOS.barra_neon[0], FOTOS.barra_neon[1], 9.0],
		["Porras al ganar en una mesa\n(tres variantes)", FOTOS.poker_vicios[0], FOTOS.fichas_cerca[0], FOTOS.fichas_cerca[1], 10.0],
		["Goteo del baño", FOTOS.bano_puerta[0], FOTOS.bano[0], FOTOS.bano[1], 9.0],
	]
	if s.has_method("_puerta_bano"):
		s.call("_puerta_bano")
	for i in tomas.size():
		var t: Array = tomas[i]
		letrero.text = t[0]
		var hacia: Vector3 = s.to_global(t[3])
		var tw := create_tween()
		tw.tween_method(func(f: float) -> void:
			cam.global_position = s.to_global((t[1] as Vector3).lerp(t[2], f))
			cam.look_at(hacia, Vector3.UP), 0.0, 1.0, t[4]).set_trans(Tween.TRANS_SINE)
		if i == 4:   # dos choques de botellas seguros
			_botellas_en(1.5)
			_botellas_en(5.5)
		if i == 5:
			for k in 3:
				_festejo_en(0.5 + k * 3.2, k + 1)
		await tw.finished


func _botellas_en(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
	_sotano.set("_botellas_t", 0.0)


func _festejo_en(segundos: float, cual: int) -> void:
	await get_tree().create_timer(segundos).timeout
	Sonidos.tocar(self, "festejo_%d" % cual, -10.0)


# La puerta secreta y La Desaguadora: toca tres veces la caseta, baja y guarda cuadros desde una
# camara arriba (ella sale, ataca, se hunde), y luego una de cerca
func _fotos_desague(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	await get_tree().create_timer(1.0).timeout
	for k in 3:
		_sotano.call("_tocar_caseta")
	await get_tree().create_timer(1.6).timeout
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	cam.global_position = _sotano.to_global(Vector3(37.3, -1.2, 5.0))
	cam.look_at(_sotano.to_global(Vector3(38.4, -2.5, 3.6)), Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(carpeta.path_join("caseta_abierta.png"))
	_sotano.call("_bajar_al_desague")
	var des := _sotano.get_node_or_null("Desague") as Node3D
	for k in 30:
		await get_tree().create_timer(0.3).timeout
		var jefa := des.find_child("*", false, false) if des else null
		if des:
			cam.global_position = des.to_global(Vector3(-5.0, 2.6, 6.5))
			cam.look_at(des.to_global(Vector3(0, 1.0, 0)), Vector3.UP)
		await RenderingServer.frame_post_draw
		if k % 3 == 0:
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("desague_%02d.png" % k))
	# Cerca de ella un rato, para ver que pega (la vida del jugador baja o el agua lo escupe)
	if des:
		var salud := get_node("/root/Salud")
		salud.vida = 100
		_player.global_position = des.to_global(Vector3(0.0, 0.1, 2.2))
		for k in 20:
			await get_tree().create_timer(0.5).timeout
			if not is_instance_valid(des):
				print("desague: el agua te escupio al bano (vida %d)" % salud.vida)
				des = null
				break
		if des:
			print("desague: vida del jugador tras 10 s junto a ella: %d" % salud.vida)
	if des:
		cam.global_position = des.to_global(Vector3(0.0, 1.6, 3.4))
		cam.look_at(des.to_global(Vector3(0, 1.9, 0)), Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("desaguadora_cerca.png"))


# Una mano de blackjack y una tirada de ruleta, con cuadros de cada una
func _fotos_mesas(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	get_node("/root/Fichas").permiso = 1
	get_node("/root/Fichas").fichas = 60
	await get_tree().create_timer(1.0).timeout
	_sotano.call("_abrir", "res://scripts/sotano/BlackjackUI.gd", {"sotano": _sotano})
	await get_tree().create_timer(0.9).timeout
	var ui := get_tree().get_first_node_in_group("juego_sotano")
	ui.call("repartir")
	for k in 12:
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("bj_%02d.png" % k))
	ui.call("plantarte")
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(carpeta.path_join("bj_final.png"))
	ui.call("cerrar")
	await get_tree().create_timer(0.5).timeout
	_sotano.call("_abrir", "res://scripts/sotano/BaccaratUI.gd", {"sotano": _sotano})
	await get_tree().create_timer(0.9).timeout
	ui = get_tree().get_first_node_in_group("juego_sotano")
	ui.call("repartir")
	for k in 8:
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("baccarat_%02d.png" % k))
	ui.call("cerrar")
	await get_tree().create_timer(0.5).timeout
	_sotano.call("_abrir", "res://scripts/sotano/RuletaUI.gd", {"sotano": _sotano})
	await get_tree().create_timer(0.9).timeout
	ui = get_tree().get_first_node_in_group("juego_sotano")
	ui.call("girar")
	for k in 36:
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		if k % 6 == 0:
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("ruleta_%02d.png" % k))


# Abre la primera EL GORDO, jala la palanca unas veces y guarda cuadros (la palanca, los carretes,
# el letrero del premio)
func _fotos_gordo(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	get_node("/root/Fichas").permiso = 1
	get_node("/root/Fichas").fichas = 40
	var g := _sotano.get_node_or_null("OlPley_0") as GabineteOlPley
	if g == null:
		return
	g.placa.estado = Carretes.Estado.CALIENTE
	await get_tree().create_timer(1.0).timeout
	_sotano.call("_abrir_olpley", g)
	await get_tree().create_timer(0.9).timeout
	var ui := get_tree().get_first_node_in_group("juego_sotano")
	for k in 36:
		if k % 12 == 0 and ui and not ui.get("_ocupado"):
			ui.call("jalar")
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("gordo_%02d.png" % k))


func _fotos_poker(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	get_node("/root/Fichas").permiso = 1
	get_node("/root/Fichas").fichas = 40
	await get_tree().create_timer(1.0).timeout
	_sotano.call("_abrir_poker")
	for k in 40:
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("poker_%02d.png" % k))
		var ui := get_tree().get_first_node_in_group("juego_sotano")
		if ui and ui.get("_esperando"):
			ui.call("jugar", "pasar")


func _fotos(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	# La puerta del bano abierta y el pase VIP, para ver adentro
	if _sotano.has_method("_puerta_bano"):
		_sotano.call("_puerta_bano")
	get_node("/root/Fichas").vip = true
	_sotano.call("_quitar_cordon")
	await get_tree().create_timer(1.5).timeout
	for nombre: String in FOTOS:
		var v: Array = FOTOS[nombre]
		cam.global_position = _sotano.to_global(v[0])
		cam.look_at(_sotano.to_global(v[1]), Vector3.UP)
		# "mesera": la camara la sigue (va caminando), de frente y un poco de lado
		var mesera := _sotano.get_node_or_null("Mesera") as Node3D
		if nombre == "mesera" and mesera:
			var frente := -mesera.global_basis.z.normalized()
			cam.global_position = mesera.global_position + frente * 2.2 + mesera.global_basis.x.normalized() * 0.8 + Vector3.UP * 1.9
			cam.look_at(mesera.global_position + Vector3.UP * 1.4, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))


# El Sotano ya viene en la escena (para verlo en el editor); K y F12 lo arman otra vez
func _armar(con_permiso_quitado: bool) -> void:
	if con_permiso_quitado:
		get_node("/root/Fichas").permiso = 0
	if _sotano == null:
		_sotano = get_node_or_null("Sotano") as Node3D
	else:
		_sotano.free()
		_sotano = null
	if _sotano == null:
		_sotano = SOTANO.instantiate() as Node3D
		_sotano.name = "Sotano"
		_sotano.scale = Vector3.ONE * ESCALA
		add_child(_sotano)
	var salida := MuebleCasa.crear("Subir (aquí te regresa abajo)", PUERTA + Vector3(0.6, 0.0, 0.0), _al_pie, 0.8)
	_sotano.add_child(salida)
	_player.poner_sin_combate(true)
	_al_pie()


func _al_pie() -> void:
	_player.global_position = _sotano.to_global(ABAJO)
	_player.velocity = Vector3.ZERO
	_player.camera_pivot.global_rotation.y = -PI / 2.0
	_player.frijol.global_rotation.y = -PI / 2.0


func _process(_delta: float) -> void:
	var f := get_node("/root/Fichas")
	_estado.text = "Fichas %d · $%d · permiso %d" % [f.fichas, get_node("/root/Cartera").pesos, f.permiso]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if get_tree().get_first_node_in_group("juego_sotano"):
		return
	var f := get_node("/root/Fichas")
	match event.physical_keycode:
		KEY_PERIOD:
			f.permiso = 1
			f.fichas += 50
			_sotano.call("_quitar_cadena")
		KEY_P:
			get_node("/root/Cartera").pesos += 500
		KEY_V:
			f.vip = true
			_sotano.call("_quitar_cordon")
		KEY_K:
			_armar(true)
		KEY_H:
			for g in _sotano.find_children("OlPley_*", "StaticBody3D", false, false):
				g.placa.estado = Carretes.Estado.CALIENTE
				g.mostrar_estado(Carretes.Estado.CALIENTE)
		KEY_R:
			_al_pie()
		KEY_F1:
			_ayuda.visible = not _ayuda.visible
		KEY_F12:
			f.reiniciar()
			get_node("/root/Cartera").pesos = PESOS
			_armar(false)


func _armar_pantalla() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_ayuda = Label.new()
	_ayuda.text = TEXTO
	_ayuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ayuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ayuda.offset_left = 8.0
	_ayuda.offset_bottom = -8.0
	_ayuda.add_theme_font_size_override("font_size", 12)
	_ayuda.add_theme_color_override("font_outline_color", Color.BLACK)
	_ayuda.add_theme_constant_override("outline_size", 4)
	capa.add_child(_ayuda)
	_estado = Label.new()
	_estado.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_estado.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_estado.offset_right = -8.0
	_estado.offset_top = 6.0
	_estado.add_theme_font_size_override("font_size", 13)
	_estado.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_estado.add_theme_color_override("font_outline_color", Color.BLACK)
	_estado.add_theme_constant_override("outline_size", 4)
	capa.add_child(_estado)
