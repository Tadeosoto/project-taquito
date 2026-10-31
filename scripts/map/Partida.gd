class_name Partida
extends CanvasLayer

# Una partida (docs/especificaciones.md 1.2): aguantar NOCHES noches defendiendo el tinaco
# del Refugio. La ultima sale el garrafonero y no amanece hasta matarlo. Se pierde si tumban
# el tinaco; morir no la termina (Supervivencia.gd). En coop la lleva el servidor.

const NOCHES := 3
const JEFE_CERCA := 70.0     # Zombis.LEJOS: mas lejos puede no estar cargado el mapa ahi
const JEFE_REINTENTO := 1.0
const TEXTO_PERDISTE := "Tumbaron el tinaco.\nSe acabó el agua."
const TEXTO_GANASTE := "Mataste al garrafonero.\nAmaneció y sigue habiendo agua."
const TEXTO_OTRA := "Espacio: otra vez"
const TEXTO_JEFE := "¡Ahí viene el garrafonero!"

@export var zombis_path: NodePath
@export var supervivencia_path: NodePath
@export var refugio_path: NodePath

var noche := 0

var _zombis: Zombis
var _supervivencia: Node
var _refugio: Refugio
var _ciclo: Node
var _jugador: Player
var _jefe_pendiente := false
var _espera_jefe := 0.0
var _terminada := false
var _estado: Label
var _final: Control
var _final_texto: Label


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zombis = get_node(zombis_path) as Zombis
	_supervivencia = get_node(supervivencia_path)
	_refugio = get_node(refugio_path) as Refugio
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	_jugador = get_tree().get_first_node_in_group("jugador") as Player
	_supervivencia.punto_regreso = _refugio.punto_regreso()
	_refugio.cayo.connect(_perder)
	_refugio.aviso.connect(_supervivencia.avisar)
	_ciclo.anochecio.connect(_anochecio)
	_armar_pantalla()


func _anochecio() -> void:
	noche += 1
	_refugio.noche = noche
	if noche >= NOCHES:
		_ciclo.retener_noche = true
		_jefe_pendiente = true


func _process(delta: float) -> void:
	_estado.text = "Noche %d/%d · Tinaco %d/%d" % [maxi(noche, 1), NOCHES, _refugio.vida, Refugio.TINACO_VIDA]
	if not _jefe_pendiente or _terminada or get_tree().paused:
		return
	_espera_jefe -= delta
	if _espera_jefe > 0.0:
		return
	_espera_jefe = JEFE_REINTENTO
	if _jugador.global_position.distance_to(_refugio.global_position) > JEFE_CERCA:
		return
	var jefe := _zombis.aparecer_jefe(_refugio.global_position)
	if jefe:
		_jefe_pendiente = false
		jefe.murio.connect(_ganar)
		_supervivencia.avisar(TEXTO_JEFE)


func _unhandled_input(event: InputEvent) -> void:
	if _terminada and event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		_otra_vez()


func _ganar() -> void:
	if _terminada:
		return
	_ciclo.amanecer_ya()
	_terminar(TEXTO_GANASTE)


func _perder() -> void:
	if not _terminada:
		_terminar(TEXTO_PERDISTE)


func _terminar(texto: String) -> void:
	_terminada = true
	_jugador.detener()
	_final_texto.text = "%s\n\n%s" % [texto, TEXTO_OTRA]
	_final.visible = true
	get_tree().paused = true


# Todo desde cero: los autoloads no se recargan con la escena
func _otra_vez() -> void:
	for autoload in ["Inventory", "Salud", "Cartera"]:
		get_node("/root/" + autoload).reiniciar()
	get_tree().paused = false
	get_tree().reload_current_scene()


# Las teclas de prueba del safehouse
func reiniciar() -> void:
	noche = 0
	_jefe_pendiente = false
	_terminada = false
	_ciclo.retener_noche = false
	_refugio.reiniciar()


func _armar_pantalla() -> void:
	_estado = Label.new()
	_estado.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_estado.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_estado.offset_left = 8.0
	_estado.offset_bottom = -6.0
	_estado.add_theme_font_size_override("font_size", 14)
	_estado.add_theme_color_override("font_outline_color", Color.BLACK)
	_estado.add_theme_constant_override("outline_size", 4)
	add_child(_estado)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.85)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.visible = false
	add_child(fondo)
	_final = fondo
	_final_texto = Label.new()
	_final_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_final_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_final_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_final_texto.add_theme_font_size_override("font_size", 22)
	fondo.add_child(_final_texto)
