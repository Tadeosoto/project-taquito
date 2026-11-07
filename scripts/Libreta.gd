extends Node
# La libreta del Nocturno (autoload `Libreta`): lo que sabes de cada bicho. Cada entrada de
# LibretaEntradas tiene un nivel: 0 no lo conoces, 1 lo viste, 2 peleaste con el, 3 lo mataste.
# Subir de nivel avisa con un letrerito y un lapiz (`nueva_nota`) y deja una nota sin leer
# (`sin_leer`) que el inventario marca. Se guarda para siempre en user://libreta.cfg: no se
# borra al reiniciar la partida (como el Personaje).
# Quien llama usa get_node_or_null("/root/Libreta"), porque los scripts de tools/ no ven autoloads.

signal nueva_nota(id: String, nivel: int)

const ARCHIVO := "user://libreta.cfg"
const AVISO_DURA := 3.0

var niveles := {}      # id -> nivel
var matados := {}      # id -> cuantos
var sin_leer := {}     # id -> true

var _capa: CanvasLayer
var _aviso: Label
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar()
	_capa = CanvasLayer.new()
	_capa.layer = 13
	add_child(_capa)
	_aviso = Label.new()
	_aviso.theme = load("res://resources/ui/tema_pixel.tres")
	_aviso.add_theme_font_size_override("font_size", 12)
	_aviso.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var papel := StyleBoxFlat.new()
	papel.bg_color = Color(0.93, 0.89, 0.76)
	papel.border_color = Color(0.55, 0.45, 0.3)
	papel.set_border_width_all(1)
	papel.set_content_margin_all(6.0)
	_aviso.add_theme_stylebox_override("normal", papel)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.position.y = 64.0
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.modulate.a = 0.0
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_aviso)


func nivel(id: String) -> int:
	return niveles.get(id, 0)


func ver(id: String) -> void:
	_subir(id, LibretaEntradas.NIVEL_VISTO)


func pelear(id: String) -> void:
	_subir(id, LibretaEntradas.NIVEL_PELEADO)


func matar(id: String) -> void:
	matados[id] = int(matados.get(id, 0)) + 1
	_subir(id, LibretaEntradas.NIVEL_MATADO)
	_guardar()


func hay_sin_leer() -> bool:
	return not sin_leer.is_empty()


func leer(id: String) -> void:
	if sin_leer.erase(id):
		_guardar()


func _subir(id: String, a: int) -> void:
	var antes := nivel(id)
	if a <= antes:
		return
	# Saltarse niveles (matarlo sin haberlo visto) los cuenta todos
	niveles[id] = a
	sin_leer[id] = true
	_guardar()
	nueva_nota.emit(id, a)
	_avisar(id, antes == 0)


func _avisar(id: String, nueva: bool) -> void:
	var e := LibretaEntradas.entrada(id)
	if e.is_empty():
		return
	_aviso.text = "%s en la libreta: %s  (B en el inventario)" % ["Nueva nota" if nueva else "Más notas", e.titulo]
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_aviso, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(AVISO_DURA)
	_tween.tween_property(_aviso, "modulate:a", 0.0, 0.5)
	Sonidos.tocar(self, "lapiz", -6.0)


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	niveles = cfg.get_value("libreta", "niveles", {})
	matados = cfg.get_value("libreta", "matados", {})
	sin_leer = cfg.get_value("libreta", "sin_leer", {})


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("libreta", "niveles", niveles)
	cfg.set_value("libreta", "matados", matados)
	cfg.set_value("libreta", "sin_leer", sin_leer)
	cfg.save(ARCHIVO)


# Para probar: todas las paginas completas, sin avisos (safehouse, Ctrl+B)
func llenar() -> void:
	for e in LibretaEntradas.ENTRADAS:
		niveles[e.id] = LibretaEntradas.NIVEL_MATADO
		sin_leer[e.id] = true
	_guardar()
	nueva_nota.emit("", LibretaEntradas.NIVEL_MATADO)


# Para probar: olvidar todo (safehouse)
func olvidar() -> void:
	niveles.clear()
	matados.clear()
	sin_leer.clear()
	_guardar()
