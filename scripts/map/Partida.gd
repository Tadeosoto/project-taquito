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
const TEXTO_PIEZA := "Pedazo de mapa: %s"
const TEXTO_ZONA := "Entrando a: %s"
const ZONA_CADA := 0.5
const PIEZA_FRENTE := 3.0    # m frente a la fachada
const PIEZA_POSTE := 1.5     # m junto al poste
const PUNTOS_JSON := "res://resources/map/puntos_mapa.json"
const POSTES_JSON := "res://resources/map/alumbrado_mapa.json"

# Las zonas y los pedazos son del mapa real; el safehouse tiene los suyos
@export var piezas_en_el_mapa := true
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
var _zona_actual := -1
var _espera_zona := 0.0
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
	PiezasMapa.recogida.connect(func(zona: int) -> void:
		_supervivencia.avisar(TEXTO_PIEZA % ZonasMapa.nombre(zona)))
	if piezas_en_el_mapa:
		_poner_piezas()


# Un pedazo por zona; el de donde empiezas ya lo traes
func _poner_piezas() -> void:
	var inicio := ZonasMapa.zona_en(_jugador.global_position.x, _jugador.global_position.z)
	_zona_actual = inicio
	PiezasMapa.dar(inicio)
	var lugares := _lugares_de_piezas()
	for zona in ZonasMapa.cuantas():
		if PiezasMapa.tiene(zona) or not lugares.has(zona):
			continue
		var pieza := PiezaMapa.new()
		pieza.zona = zona
		add_child(pieza)
		pieza.global_position = Vector3(lugares[zona].x, 0.0, lugares[zona].y)


# Frente a la tienda mas cerca del centro de cada zona; si no hay, junto al poste mas
# cercano (siempre estan en la banqueta). Siempre los mismos: dependen solo de los datos.
func _lugares_de_piezas() -> Dictionary:
	var lugares := {}
	var distancias := {}
	var centros := []
	for zona in ZonasMapa.cuantas():
		centros.append(ZonasMapa.a_mundo(ZonasMapa.centro(zona)))
	var puntos: Variant = JSON.parse_string(FileAccess.get_file_as_string(PUNTOS_JSON))
	for p: Dictionary in puntos["puntos"]:
		if not p.get("interactivo", false) or p["tipo"] == "punto" or p.get("aire_libre", false):
			continue
		var zona := ZonasMapa.zona_en(p["x"], p["z"])
		if zona < 0:
			continue
		var d: float = centros[zona].distance_to(Vector2(p["x"], p["z"]))
		if d < distancias.get(zona, INF):
			distancias[zona] = d
			var frente := Vector2(sin(float(p["rotacion_y"])), cos(float(p["rotacion_y"])))
			lugares[zona] = Vector2(p["x"], p["z"]) + frente * (float(p.get("fondo", 8.0)) / 2.0 + PIEZA_FRENTE)
	var postes: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSTES_JSON))
	var con_tienda := lugares.keys()
	for poste: Dictionary in postes["postes"]:
		var zona := ZonasMapa.zona_en(poste["x"], poste["z"])
		if zona < 0 or zona in con_tienda:
			continue
		var d: float = centros[zona].distance_to(Vector2(poste["x"], poste["z"]))
		if d < distancias.get(zona, INF):
			distancias[zona] = d
			lugares[zona] = Vector2(poste["x"], poste["z"]) + Vector2(PIEZA_POSTE, 0.0)
	return lugares


func _anochecio() -> void:
	noche += 1
	_refugio.noche = noche
	if noche >= NOCHES:
		_ciclo.retener_noche = true
		_jefe_pendiente = true


func _process(delta: float) -> void:
	_estado.text = "Noche %d/%d · Tinaco %d/%d" % [maxi(noche, 1), NOCHES, _refugio.vida, Refugio.TINACO_VIDA]
	_revisar_zona(delta)
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


# Al cruzar a otra zona se dice su nombre
func _revisar_zona(delta: float) -> void:
	if not piezas_en_el_mapa or get_tree().paused or not _jugador.is_physics_processing():
		return
	_espera_zona -= delta
	if _espera_zona > 0.0:
		return
	_espera_zona = ZONA_CADA
	var zona := ZonasMapa.zona_en(_jugador.global_position.x, _jugador.global_position.z)
	if zona >= 0 and zona != _zona_actual:
		_zona_actual = zona
		_supervivencia.avisar(TEXTO_ZONA % ZonasMapa.nombre(zona))


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
	for autoload in ["Inventory", "Salud", "Cartera", "PiezasMapa"]:
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
