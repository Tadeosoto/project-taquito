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
# Con -- --poker=<carpeta> se sienta al poker y guarda un cuadro cada 0.15 s mientras reparte y
# juega (para ver las cartas moverse), y sale.

const SOTANO := preload("res://scenes/casas/sotano.tscn")
const ESCALA := 1.25                 # la de CasaPropia
const ABAJO := Vector3(6.0, -1.4, 3.11)    # el ultimo tramo de la escalera, antes de la cadena
const ARRIBA := Vector3(2.2, 1.2, 3.11)    # donde te deja CasaPropia al entrar
const PUERTA := Vector3(0.35, 0.0, 3.11)
const PESOS := 1000
const TEXTO := """El Sótano (prueba)
. permiso y +50 fichas · P +$500
K quitar permiso (probar la cuota)
H EL GORDO calientes · R al pie de la escalera
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
	"neon_gordo": [Vector3(9.0, -1.4, 3.2), Vector3(13.6, -0.9, 3.0)],
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
		elif arg.begins_with("--poker="):
			await _fotos_poker(arg.trim_prefix("--poker="))
			get_tree().quit()
		elif arg.begins_with("--fotos="):
			await _fotos(arg.trim_prefix("--fotos="))
			get_tree().quit()


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
