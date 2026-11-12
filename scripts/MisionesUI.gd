extends Control

# El diario de misiones (InventoryUI, estado DIARIO; J con el inventario abierto): las que traes
# aceptadas (Misiones.aceptadas) y lo que falta de cada una. Solo una esta activa; al elegir otra
# con Enter se vuelve la activa y se abre el mapa de papel con su puntero. Si su paso no es de
# esta hora, lo dice ("Esto es de noche"). Las de LUGAR (la reja, el tinaco) no salen aqui.
# Flechas arriba/abajo: otra mision; Enter: seguir esta; Esc o J: salir.

signal ver_en_mapa

const TEMA := preload("res://resources/ui/tema_pixel.tres")
const ESCRITORIO := Color(0.16, 0.12, 0.09)
const PAPEL := Color(0.93, 0.89, 0.77)
const TINTA := Color(0.13, 0.12, 0.16)
const TINTA_CLARA := Color(0.38, 0.36, 0.38)
const PLUMA := Color(0.72, 0.12, 0.1)
const AMARILLO := Color(1.0, 0.85, 0.1)
const HOJA := Rect2(214.0, 18.0, 412.0, 430.0)
const LISTA_X := 12.0
const LISTA_Y := 60.0
const LISTA_ALTO := 34.0
const LISTA_ANCHO := 196.0
# Renglones que caben; si traes mas, la lista se recorre con la elegida
const RENGLONES := 10

var elegido := 0
# La primera que se ve en la lista
var _desde := 0
var _renglones: Array[Label] = []
var _papel: Control
var _titulo: Label
var _texto: RichTextLabel
var _cuenta: Label
var _vacio: Label
var _aviso: Label


class Papel extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color(0.93, 0.89, 0.77))
		var y := 58.0
		while y < size.y - 8.0:
			draw_line(Vector2(6, y), Vector2(size.x - 6, y), Color(0.55, 0.68, 0.82, 0.45), 1.0)
			y += 15.0
		draw_line(Vector2(34, 0), Vector2(34, size.y), Color(0.82, 0.3, 0.3, 0.6), 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = TEMA
	var fondo := ColorRect.new()
	fondo.color = ESCRITORIO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var encabezado := _label("DIARIO", 16, PAPEL)
	encabezado.position = Vector2(16.0, 14.0)
	add_child(encabezado)
	_cuenta = _label("", 10, Color(0.7, 0.66, 0.58))
	_cuenta.position = Vector2(16.0, 34.0)
	add_child(_cuenta)
	for i in RENGLONES:
		var renglon := _label("", 11, TINTA)
		renglon.position = Vector2(LISTA_X, LISTA_Y + i * LISTA_ALTO)
		renglon.size = Vector2(LISTA_ANCHO, LISTA_ALTO - 6.0)
		renglon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		renglon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		renglon.clip_text = true
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = PAPEL.darkened(0.25)
		estilo.set_content_margin_all(4.0)
		estilo.corner_radius_top_left = 3
		estilo.corner_radius_bottom_left = 3
		renglon.add_theme_stylebox_override("normal", estilo)
		add_child(renglon)
		_renglones.append(renglon)
	_papel = Papel.new()
	_papel.position = HOJA.position
	_papel.size = HOJA.size
	_papel.rotation = deg_to_rad(0.5)
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_papel)
	_titulo = _label("", 18, PLUMA)
	_titulo.position = Vector2(44.0, 14.0)
	_papel.add_child(_titulo)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.scroll_active = false
	_texto.position = Vector2(44.0, 62.0)
	_texto.size = Vector2(HOJA.size.x - 64.0, HOJA.size.y - 80.0)
	_texto.add_theme_color_override("default_color", TINTA)
	_texto.add_theme_font_size_override("normal_font_size", 11)
	_texto.add_theme_font_size_override("bold_font_size", 12)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papel.add_child(_texto)
	_vacio = _label("No traes pendientes.\nLa gente da trabajo de día.", 12, TINTA_CLARA)
	_vacio.position = Vector2(44.0, 62.0)
	_papel.add_child(_vacio)
	_aviso = _label("", 11, AMARILLO)
	_aviso.position = Vector2(LISTA_X, 420.0)
	_aviso.size = Vector2(LISTA_ANCHO, 30.0)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)
	var ayuda := _label("Flechas: elegir · Enter: seguir esta · Esc: regresar", 10, Color(0.7, 0.66, 0.58))
	ayuda.position = Vector2(12.0, 456.0)
	add_child(ayuda)
	visible = false


func _label(texto: String, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func mostrar() -> void:
	visible = true
	_aviso.text = ""
	# Abre en la activa
	elegido = maxi(0, Misiones.aceptadas.find(Misiones.activa))
	_actualizar()


func cerrar() -> void:
	visible = false


# Falso si la tecla no es suya
func manejar(event: InputEvent) -> bool:
	var total := Misiones.aceptadas.size()
	if event.is_action_pressed("inspect_up") and total > 0:
		elegido = wrapi(elegido - 1, 0, total)
	elif event.is_action_pressed("inspect_down") and total > 0:
		elegido = wrapi(elegido + 1, 0, total)
	elif event.is_action_pressed("inventory_confirm") and total > 0:
		_seguir()
		return true
	else:
		return false
	_aviso.text = ""
	Sonidos.tocar(self, "lapiz", -14.0, 1.4)
	_actualizar()
	return true


func _seguir() -> void:
	var mision: MisionData = Misiones.aceptadas[elegido]
	if not Misiones.elegir(mision):
		Sonidos.tocar(self, "ui_error", -6.0)
		_aviso.text = "Ahorita estás en otra cosa: acábala primero." if Misiones.en_lugar() \
				else "Traes las manos ocupadas: acaba esta primero."
		return
	Sonidos.tocar(self, "ui_aceptar", -6.0)
	ver_en_mapa.emit()


func _actualizar() -> void:
	var lista := Misiones.aceptadas
	elegido = clampi(elegido, 0, maxi(0, lista.size() - 1))
	_desde = clampi(_desde, elegido - RENGLONES + 1, elegido)
	_desde = clampi(_desde, 0, maxi(0, lista.size() - RENGLONES))
	_cuenta.text = "%d pendiente%s" % [lista.size(), "" if lista.size() == 1 else "s"]
	if lista.size() > RENGLONES:
		_cuenta.text += "  %s%s" % ["▲" if _desde > 0 else " ", "▼" if _desde + RENGLONES < lista.size() else ""]
	for r in _renglones.size():
		var renglon := _renglones[r]
		var i := _desde + r
		renglon.visible = i < lista.size()
		if not renglon.visible:
			continue
		var mision: MisionData = lista[i]
		var activa := mision == Misiones.activa
		renglon.text = ("▶ " if activa else "") + mision.nombre
		var estilo := renglon.get_theme_stylebox("normal") as StyleBoxFlat
		estilo.bg_color = PAPEL if i == elegido else PAPEL.darkened(0.25)
		renglon.position.x = LISTA_X + (6.0 if i == elegido else 0.0)
		renglon.add_theme_color_override("font_color", PLUMA if activa else TINTA)
	_vacio.visible = lista.is_empty()
	_texto.visible = not lista.is_empty()
	if lista.is_empty():
		_titulo.text = ""
		return
	var mision: MisionData = lista[elegido]
	_titulo.text = mision.nombre
	_texto.text = _hoja(mision)


func _hoja(mision: MisionData) -> String:
	var activa := mision == Misiones.activa
	var avance := Misiones.avance(mision)
	var i: int = avance["paso"]
	var t := ""
	if activa:
		t += "[color=#b81f1a][b]La que sigues[/b][/color]\n\n"
	t += "[color=#5c5a5e]\"%s\"[/color]\n\n" % mision.oferta
	t += "[color=#b81f1a][b]Lo que falta[/b][/color]\n"
	for k in mision.pasos.size():
		var p: PasoMision = mision.pasos[k]
		if k < i:
			t += "[s]%s[/s]\n" % p.texto
			continue
		var linea := p.texto
		if k == i:
			if p.tipo == PasoMision.Tipo.VISITAR and p.cuantos > 1:
				linea += " (%d/%d)" % [avance["visitados"], p.cuantos]
			if p.segundos > 0.0:
				linea += " · %d s" % ceili(avance["tiempo"])
			t += "[b]• %s[/b]\n" % linea
		else:
			t += "[color=#6a676b]• %s[/color]\n" % linea
		var falta := Misiones.hora_que_falta(p)
		if falta != "" and k == i:
			t += "[color=#b81f1a]   Esto es %s.[/color]\n" % falta
	if mision.pesos > 0:
		t += "\n[color=#6a676b]Paga: $%d[/color]" % mision.pesos
	return t
