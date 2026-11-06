class_name Partida
extends CanvasLayer

# Una partida (docs/especificaciones.md 1.2): aguantar NOCHES noches. La ultima sale el
# garrafonero y no amanece hasta matarlo. Con Refugio (el safehouse) se defiende su tinaco y
# se pierde si lo tumban; sin el (map_test, mientras la defensa del tinaco llega al mapa) no
# hay derrota y el jefe sale cerca de ti. Morir no la termina (Supervivencia.gd). En coop la
# lleva el servidor.

const NOCHES := 3
const JEFE_CERCA := 70.0     # Zombis.LEJOS: mas lejos puede no estar cargado el mapa ahi
const JEFE_REINTENTO := 1.0
const TEXTO_PERDISTE := "Tumbaron el tinaco.\nSe acabó el agua."
const TEXTO_GANASTE := "%s mató al garrafonero.\nAmaneció y sigue habiendo agua."
const TEXTO_OTRA := "Espacio: otra vez"
const TEXTO_JEFE := "¡Ahí viene el garrafonero!"
const TEXTO_PIEZA := "Pedazo de mapa: %s"
const TEXTO_ZONA := "Entrando a: %s"
const ZONA_CADA := 0.5
const GANAR_ESPERA := 1.3    # s de reloj real entre matar al jefe y la pantalla final
const PIEZA_FRENTE := 3.0    # m frente a la fachada
const PIEZA_POSTE := 1.5     # m junto al poste
# Bolsas especiales de Takis escondidas (Tazos.gd): en estas zonas, junto a donde va su pieza
const BOLSAS_ZONAS := [1, 3, 5, 7]
const BOLSA_LADO := Vector2(4.0, 0.0)  # m de la pieza, para que no se encimen
const BOLSA := "res://resources/productos/takis_tazo.tres"
const TEXTO_PUNTO := "+1 punto de habilidad por sobrevivir la noche"
# Para ajustar RitmoNoche jugando
const TEXTO_NOCHE := "Noche %d: salieron %d zombis, mataste %d (turbas: %d)"
const PUNTOS_JSON := "res://resources/map/puntos_mapa.json"
const POSTES_JSON := "res://resources/map/alumbrado_mapa.json"

# Las zonas y los pedazos son del mapa real; el safehouse tiene los suyos
@export var piezas_en_el_mapa := true
var misiones_config := {}
@export var zombis_path: NodePath
@export var supervivencia_path: NodePath
# Vacio: sin refugio (ver arriba)
@export var refugio_path: NodePath

var noche := 0

var _zombis: Zombis
var _supervivencia: Node
var _refugio: Refugio
var _ciclo: Node
var _jugador: Player
var _jefe_pendiente := false
var _espera_jefe := 0.0
var _ganando := false
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
	_refugio = get_node_or_null(refugio_path) as Refugio if not refugio_path.is_empty() else null
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	_jugador = get_tree().get_first_node_in_group("jugador") as Player
	# Sin refugio regresas a donde empezaste (Supervivencia ya lo tiene)
	if _refugio:
		_supervivencia.punto_regreso = _refugio.punto_regreso()
		_refugio.cayo.connect(_perder)
		_refugio.aviso.connect(_supervivencia.avisar)
	_ciclo.anochecio.connect(_anochecio)
	_ciclo.amanecio.connect(_amanecio)
	_armar_pantalla()
	PiezasMapa.recogida.connect(func(zona: int) -> void:
		_supervivencia.avisar(TEXTO_PIEZA % ZonasMapa.nombre(zona)))
	if piezas_en_el_mapa:
		_poner_piezas()
		_poner_bolsas()
	_poner_misiones()


# Sobreviviste la noche: un punto de habilidad (Tazos.gd)
func _amanecio() -> void:
	if noche <= 0:
		return
	get_node("/root/Tazos").dar_puntos(Tazos.PUNTOS_POR_NOCHE)
	_supervivencia.avisar("%s\n%s" % [TEXTO_NOCHE % [noche, _zombis.salieron_noche, _zombis.muertos_noche, _zombis.turbas_noche], TEXTO_PUNTO])


# Unas bolsas especiales tiradas, con su haz (WorldItem): junto a donde va la pieza de su
# zona. Siempre en los mismos lugares
func _poner_bolsas() -> void:
	var lugares := _lugares_de_piezas()
	var bolsa := load(BOLSA) as InventoryItemData
	for zona: int in BOLSAS_ZONAS:
		if not lugares.has(zona):
			continue
		var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
		objeto.set("item_data", bolsa)
		var donde: Vector2 = lugares[zona] + BOLSA_LADO
		objeto.position = Vector3(donde.x, 0.5, donde.y)
		add_child(objeto)


# Los del mapa real, o los que le dieron (el safehouse)
func _poner_misiones() -> void:
	var mundo := MisionesMundo.new()
	mundo.name = "MisionesMundo"
	# Partida corre siempre, por su pantalla final; esto no debe seguir en la pausa
	mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	for propiedad: String in misiones_config:
		mundo.set(propiedad, misiones_config[propiedad])
	add_child(mundo)
	mundo.avisos_por(_supervivencia)


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
	get_node("/root/Tazos").nueva_noche()
	if _refugio:
		_refugio.noche = noche
	if noche >= NOCHES:
		_ciclo.retener_noche = true
		_jefe_pendiente = true


func _process(delta: float) -> void:
	# El reloj (Ciclo.hora) y en que dia o noche vas
	var cual := "Noche %d/%d" % [noche, NOCHES] if _ciclo.es_noche() else "Día %d" % (noche + 1)
	_estado.text = "%s · %s" % [Ciclo.texto_hora(_ciclo.hora()), cual]
	if _refugio:
		_estado.text += " · Tinaco %d/%d" % [_refugio.vida, Refugio.TINACO_VIDA]
	_revisar_zona(delta)
	if not _jefe_pendiente or _terminada or get_tree().paused:
		return
	_espera_jefe -= delta
	if _espera_jefe > 0.0:
		return
	_espera_jefe = JEFE_REINTENTO
	var centro := _refugio.global_position if _refugio else _jugador.global_position
	if _jugador.global_position.distance_to(centro) > JEFE_CERCA:
		return
	var jefe := _zombis.aparecer_jefe(centro)
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
	# Que se vea tronar al garrafonero antes de pausar. Nada lo puede cambiar en este rato
	_ganando = true
	await get_tree().create_timer(GANAR_ESPERA, true, false, true).timeout
	_terminar(TEXTO_GANASTE % Personaje.nombre)


func _perder() -> void:
	if not _terminada and not _ganando:
		_terminar(TEXTO_PERDISTE)


func _terminar(texto: String) -> void:
	_terminada = true
	_jugador.detener()
	_final_texto.text = "%s\n\n%s" % [texto, TEXTO_OTRA]
	_final.visible = true
	get_tree().paused = true


# Todo desde cero: los autoloads no se recargan con la escena
func _otra_vez() -> void:
	Engine.time_scale = 1.0
	for autoload in ["Inventory", "Salud", "Cartera", "PiezasMapa", "Misiones", "Tazos"]:
		get_node("/root/" + autoload).reiniciar()
	get_tree().paused = false
	get_tree().reload_current_scene()


# Las teclas de prueba del safehouse
func reiniciar() -> void:
	_ganando = false
	noche = 0
	_jefe_pendiente = false
	_terminada = false
	_ciclo.retener_noche = false
	if _refugio:
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
