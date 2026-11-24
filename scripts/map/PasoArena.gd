class_name PasoArena
extends RefCounted
## Ir del mapa a la arena de un jefe (La Madre del Carcamo, lombrices.tscn; La Mojiganga,
## catrina.tscn) y regresar, como PasoColonia con las rejas. La flecha amarilla del mapa
## (EntradaJefe.gd) llama `ir`; la arena, al ganar o al desmayarte, llama `volver`. Antes las
## arenas solo eran escenas de prueba: al ganar se quedaban ahi ("otra vez").
##
## Al volver apareces en la flecha (`regreso`) con la hora a la que te fuiste mas lo que tardaste.
## Si te desmayaste en la arena, tus cosas se quedan en una bolsa junto a la flecha (Noches.bolsa)
## y despiertas donde empieza el mapa, como cualquier desmayo. La noche no se reinicia.
##
## Tambien guarda donde aparecer al Continuar una partida (Guardado.cargar -> llegar_a); Partida
## lo toma en su _ready (`tomar_llegada`).

const FUNDIDO := 0.35
const ESPERA_FRAMES := 12
const ARENA_MADRE := "res://scenes/lombrices.tscn"
const ARENA_MOJIGANGA := "res://scenes/catrina.tscn"
const VIDA_AL_DESPERTAR := 50   # la de Supervivencia

## Se llego a la arena desde el mapa (si no, es la escena de prueba de siempre)
static var desde_mapa := false
## La escena del mapa y donde regresar (la flecha), la hora (fraccion del ciclo) y cuanto
## dura el ciclo de ese mapa, para sumarle lo que tardaste
static var mapa := ""
static var regreso := Transform3D()
static var hora := -1.0
static var ciclo_dura := 1200.0
## La vida del jefe se multiplica por esto (Noches.fuerza_jefe)
static var fuerza := 1.0

static var _salio_ms := 0
static var _llegada_pendiente := false
static var _llegada := Transform3D()
static var _yendo := false


## Del mapa a la arena `escena`. `desde` es cualquier nodo del arbol (la flecha)
static func ir(desde: Node, escena: String, regreso_en: Transform3D, fuerza_jefe: float) -> void:
	if _yendo:
		return
	var arbol := desde.get_tree()
	var guardado := arbol.root.get_node_or_null("Guardado")
	if guardado:
		guardado.guardar()
	mapa = arbol.current_scene.scene_file_path
	regreso = regreso_en
	fuerza = fuerza_jefe
	var ciclo := arbol.get_first_node_in_group("ciclo") as Ciclo
	hora = -1.0
	if ciclo:
		ciclo_dura = maxf(ciclo.dia_duracion + ciclo.noche_duracion, 0.001)
		hora = ciclo.tiempo() / ciclo_dura
	_salio_ms = Time.get_ticks_msec()
	desde_mapa = true
	await _cambiar(arbol, escena)


## De la arena al mapa. Con `desmayo`, lo que traes se queda en una bolsa junto a la flecha
static func volver(arbol: SceneTree, desmayo: bool) -> void:
	if _yendo or not desde_mapa:
		return
	var hora_vuelta := hora
	if hora >= 0.0:
		hora_vuelta = fmod(hora + (Time.get_ticks_msec() - _salio_ms) / 1000.0 / ciclo_dura, 1.0)
	desde_mapa = false
	fuerza = 1.0
	if desmayo:
		var inventario := arbol.root.get_node("Inventory")
		var noches := arbol.root.get_node("Noches")
		if not inventario.items.is_empty():
			noches.nueva_bolsa(inventario.unidades(), regreso.origin + Vector3.DOWN, mapa)
			inventario.vaciar()
		arbol.root.get_node("Salud").vida = VIDA_AL_DESPERTAR
		# Despiertas donde empieza el mapa; solo la hora viene de aqui
		PasoColonia.fraccion_del_dia = hora_vuelta
	else:
		llegar_a(regreso, hora_vuelta)
	await _cambiar(arbol, mapa)
	var guardado := arbol.root.get_node_or_null("Guardado")
	if guardado:
		guardado.guardar()


## La escena que se cargue despues pone al jugador aqui (Partida) con esta hora (Ciclo)
static func llegar_a(donde: Transform3D, hora_dia: float) -> void:
	_llegada = donde
	_llegada_pendiente = donde != Transform3D()
	PasoColonia.fraccion_del_dia = hora_dia


## Una sola vez: donde aparecer, o null
static func tomar_llegada() -> Variant:
	if not _llegada_pendiente:
		return null
	_llegada_pendiente = false
	return _llegada


static func _cambiar(arbol: SceneTree, escena: String) -> void:
	_yendo = true
	arbol.paused = false
	var jugador := arbol.get_first_node_in_group("jugador")
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_DISABLED
	var capa := CanvasLayer.new()
	capa.layer = 100
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.modulate.a = 0.0
	capa.add_child(negro)
	arbol.root.add_child(capa)
	var entra := capa.create_tween()
	entra.tween_property(negro, "modulate:a", 1.0, FUNDIDO)
	await entra.finished
	Engine.time_scale = 1.0
	arbol.change_scene_to_file(escena)
	for i in ESPERA_FRAMES:
		await arbol.process_frame
	var sale := capa.create_tween()
	sale.tween_property(negro, "modulate:a", 0.0, FUNDIDO)
	await sale.finished
	capa.queue_free()
	_yendo = false
