class_name PreguntaReja
extends CanvasLayer

## Se perdio el evento de la reja (F1): "¿Otra vez?" con los reintentos que quedan. Pausa el juego mientras pregunta;
## Espacio (o X) vuelve a intentarlo, Esc (o B) lo deja y el tinaco de la Virgen se pierde. Avisa con `respondio` y se
## quita sola. La crea MisionesMundo._acabo_evento_reja.

signal respondio(otra_vez: bool)

const TEXTO := "Cayó el tinaco de la Virgen.\n¿Otra vez? (te quedan %d)\n\n[Espacio] Otra vez      [Esc] Dejarlo"
const TEXTO_UNO := "Cayó el tinaco de la Virgen.\n¿Otra vez? (es la última)\n\n[Espacio] Otra vez      [Esc] Dejarlo"
const FONDO := Color(0.0, 0.0, 0.0, 0.6)

var quedan := 1
var _pausaba := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	var texto := Label.new()
	texto.text = TEXTO_UNO if quedan == 1 else TEXTO % quedan
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.add_theme_constant_override("outline_size", 5)
	add_child(texto)
	_pausaba = get_tree().paused
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_responder(true)
	elif event.is_action_pressed("ui_cancel"):
		_responder(false)


## Tambien desde las pruebas
func responder(otra_vez: bool) -> void:
	_responder(otra_vez)


func _responder(otra_vez: bool) -> void:
	get_viewport().set_input_as_handled()
	get_tree().paused = _pausaba
	respondio.emit(otra_vez)
	queue_free()
