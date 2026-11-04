extends Node

# Autoload `Tiliches`: los materiales del taller (Materiales.gd), aparte del inventario y sin
# limite, como la lista de materiales de Kingdom Hearts. Los comunes y especiales duran lo que
# la partida (reiniciar); los TROFEOS se quedan en la vitrina de La Chava entre partidas
# (user://taller.cfg, seccion "vitrina"). Propuesta de AG (docs/especificaciones.md 4.13).
#
# Lo que entra sale abajo a la derecha unos segundos ("+2 Rebaba"), sin tener que abrir nada.
#
# Los tiliches van en la cangurera (Inventory.cangurera, premio de una mision): sin ella no
# puedes guardar ninguno (dar regresa false y avisa). Los trofeos no: esos se quedan en la
# vitrina de La Chava (TallerUI, tecla V), no los cargas tu.

signal cambio
signal recibido(id: String, cuantos: int)

const ARCHIVO := "user://taller.cfg"
const SECCION := "vitrina"
const AVISO_DURA := 2.6       # s en pantalla
const AVISO_JUNTA := 1.2      # s: lo mismo que llega antes de esto se suma al aviso que ya esta
const AVISOS_MAX := 5
const AMARILLO := Color(1.0, 0.85, 0.1)
const SIN_CANGURERA := "Sin cangurera no tienes dónde guardar tiliches"
const SIN_CANGURERA_CADA := 20.0   # s entre un aviso y otro

var cantidades := {}          # id -> cuantos

var _capa: CanvasLayer
var _lista: VBoxContainer
var _avisos := {}             # id -> {label, cuantos, desde}
var _ultimo_sin_cangurera := -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_vitrina()
	_capa = CanvasLayer.new()
	_capa.layer = 10
	add_child(_capa)
	_lista = VBoxContainer.new()
	_lista.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_lista.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lista.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lista.offset_right = -12.0
	_lista.offset_bottom = -34.0
	_lista.alignment = BoxContainer.ALIGNMENT_END
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_lista)


# Partida nueva: se vacia todo menos la vitrina
func reiniciar() -> void:
	for id: String in cantidades.keys():
		if not Materiales.es_trofeo(id):
			cantidades.erase(id)
	cambio.emit()


func cuantos(id: String) -> int:
	return cantidades.get(id, 0)


# Si traes donde guardarlos (la cangurera); los trofeos siempre entran
func puede_guardar(id := "") -> bool:
	if id != "" and Materiales.es_trofeo(id):
		return true
	var inventario := get_node_or_null("/root/Inventory")
	return inventario != null and inventario.cangurera != null


# Avisa que no traes cangurera, pero no a cada rato
func avisar_sin_cangurera() -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_sin_cangurera >= SIN_CANGURERA_CADA * 1000.0:
		_ultimo_sin_cangurera = ahora
		avisar(SIN_CANGURERA)


# Regresa false si no entro (sin cangurera)
func dar(id: String, n := 1, avisar := true) -> bool:
	if n <= 0 or Materiales.dato(id).is_empty():
		return false
	if not puede_guardar(id):
		avisar_sin_cangurera()
		return false
	cantidades[id] = cuantos(id) + n
	if Materiales.es_trofeo(id):
		_guardar_vitrina()
	recibido.emit(id, n)
	if avisar:
		_avisar(id, n)
	cambio.emit()
	return true


# Varios de un jalon (Materiales.botin, chatarra): id -> cuantos
func dar_varios(que: Dictionary) -> void:
	for id: String in que:
		dar(id, que[id])


# Si alcanza para todo lo de `que` (id -> cuantos)
func alcanza(que: Dictionary) -> bool:
	for id: String in que:
		if cuantos(id) < que[id]:
			return false
	return true


func gastar(que: Dictionary) -> bool:
	if not alcanza(que):
		return false
	var trofeo := false
	for id: String in que:
		cantidades[id] = cuantos(id) - que[id]
		if cantidades[id] <= 0:
			cantidades.erase(id)
		trofeo = trofeo or Materiales.es_trofeo(id)
	if trofeo:
		_guardar_vitrina()
	cambio.emit()
	return true


# --- La vitrina: los trofeos se guardan ---

func _cargar_vitrina() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK or not cfg.has_section(SECCION):
		return
	for id in cfg.get_section_keys(SECCION):
		if Materiales.es_trofeo(id):
			cantidades[id] = int(cfg.get_value(SECCION, id, 0))


func _guardar_vitrina() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO)   # lo demas del archivo (el rango del taller) se queda
	if cfg.has_section(SECCION):
		cfg.erase_section(SECCION)
	for id: String in cantidades:
		if Materiales.es_trofeo(id) and cantidades[id] > 0:
			cfg.set_value(SECCION, id, cantidades[id])
	cfg.save(ARCHIVO)


# Vaciar la vitrina (tecla de prueba del safehouse)
func vaciar_vitrina() -> void:
	for id: String in cantidades.keys():
		if Materiales.es_trofeo(id):
			cantidades.erase(id)
	_guardar_vitrina()
	cambio.emit()


# --- Avisos ---

# Un renglon cualquiera con los avisos de materiales (un plano, una hazana)
func avisar(texto: String) -> void:
	_avisar("", 0, texto)


func _avisar(id: String, n: int, texto_libre := "") -> void:
	if texto_libre != "":
		id = "_" + texto_libre
	var ahora := Time.get_ticks_msec()
	var aviso: Dictionary = _avisos.get(id, {})
	if not aviso.is_empty() and is_instance_valid(aviso["label"]) and ahora - aviso["desde"] < AVISO_JUNTA * 1000.0:
		aviso["cuantos"] += n
	else:
		# Fuera de la lista ya: con queue_free solo, varios en el mismo cuadro pasaban del tope
		while _lista.get_child_count() >= AVISOS_MAX:
			var viejo := _lista.get_child(0)
			_lista.remove_child(viejo)
			viejo.queue_free()
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_END
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icono := TextureRect.new()
		icono.texture = Materiales.icono(id)
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.custom_minimum_size = Vector2(16.0, 16.0)
		icono.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		fila.add_child(icono)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", AMARILLO if Materiales.es_trofeo(id) else Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		fila.add_child(label)
		_lista.add_child(fila)
		aviso = { "label": label, "fila": fila, "cuantos": n }
		_avisos[id] = aviso
	aviso["desde"] = ahora
	var texto := "+%d %s" % [aviso["cuantos"], Materiales.nombre(id)]
	if Materiales.es_trofeo(id):
		texto = "¡Trofeo! " + Materiales.nombre(id)
	if texto_libre != "":
		texto = texto_libre
	(aviso["label"] as Label).text = texto
	(aviso["fila"] as Control).modulate.a = 1.0


func _process(_delta: float) -> void:
	var ahora := Time.get_ticks_msec()
	for id: String in _avisos.keys():
		var aviso: Dictionary = _avisos[id]
		if not is_instance_valid(aviso["fila"]):
			_avisos.erase(id)
			continue
		var pasado: float = (ahora - aviso["desde"]) / 1000.0
		var fila := aviso["fila"] as Control
		fila.modulate.a = clampf((AVISO_DURA - pasado) / 0.4, 0.0, 1.0)
		if pasado >= AVISO_DURA:
			fila.queue_free()
			_avisos.erase(id)
