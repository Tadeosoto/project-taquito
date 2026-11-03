extends Control

# La pagina de habilidades del inventario (InventoryUI, estado HABILIDADES; H o Y de control).
# Izquierda: la lista por categoria, con su icono y sus niveles en cuadritos. Derecha: la
# elegida en grande, que hace, con numeros de verdad lo que tienes ahora y lo que tendrias con
# el siguiente nivel, y cuanto cuesta (en rojo si no te alcanza). Si esta bloqueada, la sombra
# del tazo que la desbloquea. Arriba, los puntos en cuadritos: llenos los gastados.
# Arriba/abajo eliges; derecha o Enter sube un nivel, izquierda lo baja y te regresa los puntos.
# T abre el album (InventoryUI). Mismo look que el inventario: negro y amarillo.
#
# Las animaciones van con tweens de este nodo, que corre en pausa como el inventario.

const AMARILLO := Color(1.0, 0.85, 0.1)
const BLANCO := Color(1.0, 1.0, 1.0)
const GRIS := Color(0.55, 0.55, 0.55)
const OSCURO := Color(0.3, 0.3, 0.32)
const ROJO := Color(1.0, 0.3, 0.25)
const VACIO := Color(0.16, 0.16, 0.18)
const ELEGIDA_FONDO := Color(1.0, 0.85, 0.1, 0.12)

const LISTA_X := 24.0
const LISTA_Y := 62.0
const FILA_ALTO := 18.0
const CABEZA_ALTO := 17.0
const FILA_ANCHO := 300.0
const CUADRITO := 7.0          # px de cada nivel en la fila
const DETALLE_X := 344.0
const DETALLE_ANCHO := 272.0
const PUNTOS_Y := 44.0
const PUNTOS_ANCHO := 588.0
const VOLUMEN := -6.0

var elegida := 0
var _ids: Array[String] = []
var _filas: Array[Dictionary] = []   # por habilidad: raiz, fondo, icono, nombre, cuadros (ColorRect)
var _puntos: Label
var _barra: Control                  # los cuadritos de puntos
var _detalle: Dictionary = {}        # icono, nombre, nivel, descripcion, ahora, siguiente, costo, tazo, tazo_texto
var _coleccion: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ids = Habilidades.orden()
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var titulo := _label("HABILIDADES", 22, AMARILLO)
	titulo.position = Vector2(LISTA_X + 4.0, 12.0)
	add_child(titulo)
	_puntos = _label("", 14, BLANCO)
	_puntos.position = Vector2(380.0, 18.0)
	_puntos.size = Vector2(236.0, 20.0)
	_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_puntos)
	_barra = Control.new()
	_barra.position = Vector2(LISTA_X + 4.0, PUNTOS_Y)
	add_child(_barra)
	_armar_lista()
	_armar_detalle()
	_coleccion = _label("", 11, GRIS)
	_coleccion.position = Vector2(LISTA_X + 4.0, 432.0)
	add_child(_coleccion)
	var ayuda := _label("↑↓ elegir    → / Enter subir    ← bajar    T álbum    Esc regresar", 11, GRIS)
	ayuda.position = Vector2(LISTA_X + 4.0, 452.0)
	add_child(ayuda)
	Tazos.cambio.connect(_actualizar)


func _armar_lista() -> void:
	var y := LISTA_Y
	var categoria := -1
	for id in _ids:
		var dato := Habilidades.dato(id)
		if dato["categoria"] != categoria:
			categoria = dato["categoria"]
			var cabeza := _label(Habilidades.CATEGORIAS[categoria].to_upper(), 10, GRIS)
			cabeza.position = Vector2(LISTA_X + 4.0, y + 3.0)
			add_child(cabeza)
			y += CABEZA_ALTO
		var raiz := Control.new()
		raiz.position = Vector2(LISTA_X, y)
		raiz.size = Vector2(FILA_ANCHO, FILA_ALTO)
		raiz.pivot_offset = raiz.size * 0.5
		add_child(raiz)
		var marca := ColorRect.new()
		marca.color = ELEGIDA_FONDO
		marca.size = raiz.size
		raiz.add_child(marca)
		var icono := TextureRect.new()
		icono.texture = Habilidades.icono(id)
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.position = Vector2(4.0, 1.0)
		icono.size = Vector2(16.0, 16.0)
		raiz.add_child(icono)
		var nombre := _label(dato["nombre"], 13, GRIS)
		nombre.position = Vector2(26.0, -1.0)
		raiz.add_child(nombre)
		var cuadros: Array[ColorRect] = []
		for k in dato["niveles"]:
			var cuadro := ColorRect.new()
			cuadro.size = Vector2.ONE * CUADRITO
			cuadro.position = Vector2(FILA_ANCHO - 8.0 - (dato["niveles"] - k) * (CUADRITO + 3.0), (FILA_ALTO - CUADRITO) * 0.5)
			raiz.add_child(cuadro)
			cuadros.append(cuadro)
		_filas.append({ "raiz": raiz, "marca": marca, "icono": icono, "nombre": nombre, "cuadros": cuadros })
		y += FILA_ALTO


func _armar_detalle() -> void:
	var marco := ColorRect.new()
	marco.color = Color(1.0, 1.0, 1.0, 0.04)
	marco.position = Vector2(DETALLE_X - 12.0, LISTA_Y)
	marco.size = Vector2(DETALLE_ANCHO + 24.0, 356.0)
	add_child(marco)
	var icono := TextureRect.new()
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.position = Vector2(DETALLE_X, LISTA_Y + 10.0)
	icono.size = Vector2(48.0, 48.0)
	add_child(icono)
	var nombre := _label("", 18, AMARILLO)
	nombre.position = Vector2(DETALLE_X + 60.0, LISTA_Y + 12.0)
	add_child(nombre)
	var nivel := _label("", 12, GRIS)
	nivel.position = Vector2(DETALLE_X + 60.0, LISTA_Y + 36.0)
	add_child(nivel)
	var descripcion := _label("", 13, BLANCO)
	descripcion.position = Vector2(DETALLE_X, LISTA_Y + 70.0)
	descripcion.size = Vector2(DETALLE_ANCHO, 70.0)
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(descripcion)
	var ahora := _label("", 13, BLANCO)
	ahora.position = Vector2(DETALLE_X, LISTA_Y + 150.0)
	ahora.size = Vector2(DETALLE_ANCHO, 36.0)
	ahora.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ahora)
	var siguiente := _label("", 13, AMARILLO)
	siguiente.position = Vector2(DETALLE_X, LISTA_Y + 188.0)
	siguiente.size = Vector2(DETALLE_ANCHO, 36.0)
	siguiente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(siguiente)
	var costo := _label("", 15, BLANCO)
	costo.position = Vector2(DETALLE_X, LISTA_Y + 232.0)
	add_child(costo)
	# Bloqueada: la sombra del tazo que la abre
	var tazo := TextureRect.new()
	tazo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tazo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tazo.position = Vector2(DETALLE_X, LISTA_Y + 262.0)
	tazo.size = Vector2(64.0, 64.0)
	add_child(tazo)
	var tazo_texto := _label("", 12, GRIS)
	tazo_texto.position = Vector2(DETALLE_X + 74.0, LISTA_Y + 274.0)
	tazo_texto.size = Vector2(DETALLE_ANCHO - 74.0, 48.0)
	tazo_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tazo_texto)
	_detalle = { "icono": icono, "nombre": nombre, "nivel": nivel, "descripcion": descripcion,
		"ahora": ahora, "siguiente": siguiente, "costo": costo, "tazo": tazo, "tazo_texto": tazo_texto }


# Con `id`, abre con esa habilidad elegida (al venir del show de un tazo que la desbloqueo)
func mostrar(id := "") -> void:
	if id != "" and _ids.has(id):
		elegida = _ids.find(id)
	visible = true
	_actualizar()


# Lo que se aprieta en esta pagina; true si lo uso
func manejar(event: InputEvent) -> bool:
	if event.is_action_pressed("inspect_up"):
		elegida = wrapi(elegida - 1, 0, _ids.size())
		_sonar("ui_mover")
	elif event.is_action_pressed("inspect_down"):
		elegida = wrapi(elegida + 1, 0, _ids.size())
		_sonar("ui_mover")
	elif event.is_action_pressed("inventory_confirm") or _es_derecha(event):
		_subir()
	elif _es_izquierda(event):
		_bajar()
	else:
		return false
	_actualizar()
	return true


func _subir() -> void:
	var id := _ids[elegida]
	var antes := Tazos.nivel(id)
	if Tazos.subir(id):
		_sonar("brillo")
		_actualizar()
		_resaltar_cuadro(elegida, antes)
		_brincar(elegida)
		return
	_sonar("ui_error")
	_temblar(_detalle["tazo_texto"] if not Tazos.disponible(id) else _detalle["costo"])


func _bajar() -> void:
	var id := _ids[elegida]
	var antes := Tazos.nivel(id)
	if Tazos.bajar(id):
		_sonar("inv_girar")
		_actualizar()
		_apagar_cuadro(elegida, antes - 1)
	else:
		_sonar("ui_error")


# Derecha/izquierda: flechas (inspect_*) o Q/E (inventory_*), las mismas que en la hilera
func _es_derecha(event: InputEvent) -> bool:
	return event.is_action_pressed("inspect_right") or event.is_action_pressed("inventory_next")


func _es_izquierda(event: InputEvent) -> bool:
	return event.is_action_pressed("inspect_left") or event.is_action_pressed("inventory_previous")


func _actualizar() -> void:
	if not visible:
		return
	_actualizar_puntos()
	for i in _ids.size():
		_actualizar_fila(i)
	_actualizar_detalle()
	var total := Tazos.todos.size()
	_coleccion.text = "Tazos: %d de %d · series completas: %d de %d" % [
		Tazos.distintos().size(), total, Tazos.series_premiadas.size(), Tazos.numero_de_series()]
	# Lo de las estampitas del taller (Bonos.gd), que dura la partida
	var estampitas: String = Bonos.texto_estampitas()
	if estampitas != "":
		_coleccion.text += " · Estampitas: " + estampitas


func _actualizar_puntos() -> void:
	var libres := Tazos.libres()
	_puntos.text = "%d %s de %d" % [libres, "libre" if libres == 1 else "libres", Tazos.puntos]
	_puntos.add_theme_color_override("font_color", AMARILLO if libres > 0 else GRIS)
	# Un cuadrito por punto: amarillo los gastados, hueco los libres. Se encogen si son muchos
	var total := maxi(Tazos.puntos, 1)
	var paso := clampf(PUNTOS_ANCHO / total, 4.0, 12.0)
	var lado := maxf(paso - 3.0, 2.0)
	var gastados := Tazos.gastados()
	while _barra.get_child_count() < total:
		var cuadro := ColorRect.new()
		_barra.add_child(cuadro)
	for i in _barra.get_child_count():
		var cuadro := _barra.get_child(i) as ColorRect
		cuadro.visible = i < Tazos.puntos
		cuadro.position = Vector2(i * paso, 0.0)
		cuadro.size = Vector2(lado, 6.0)
		cuadro.color = AMARILLO if i < gastados else VACIO


func _actualizar_fila(i: int) -> void:
	var id := _ids[i]
	var fila := _filas[i]
	var n := Tazos.nivel(id)
	var disponible := Tazos.disponible(id)
	var al_maximo := Tazos.costo_siguiente(id) < 0
	var color := GRIS
	if not disponible:
		color = OSCURO
	elif i == elegida:
		color = BLANCO
	elif n > 0:
		color = AMARILLO
	(fila["nombre"] as Label).add_theme_color_override("font_color", color)
	(fila["marca"] as ColorRect).visible = i == elegida
	(fila["icono"] as TextureRect).modulate = Color(1, 1, 1, 0.3) if not disponible else Color.WHITE
	var cuadros: Array[ColorRect] = fila["cuadros"]
	for k in cuadros.size():
		cuadros[k].color = (AMARILLO if not al_maximo or i != elegida else BLANCO) if k < n else (VACIO if disponible else Color(0.1, 0.1, 0.11))


func _actualizar_detalle() -> void:
	var id := _ids[elegida]
	var dato := Habilidades.dato(id)
	var n := Tazos.nivel(id)
	var disponible := Tazos.disponible(id)
	var base := _valores_base()
	(_detalle["icono"] as TextureRect).texture = Habilidades.icono(id)
	(_detalle["icono"] as TextureRect).modulate = Color(1, 1, 1, 0.35) if not disponible else Color.WHITE
	(_detalle["nombre"] as Label).text = dato["nombre"]
	(_detalle["nivel"] as Label).text = "Nivel %d de %d" % [n, dato["niveles"]] if disponible else "Bloqueada"
	(_detalle["descripcion"] as Label).text = dato["descripcion"]
	var costo := Tazos.costo_siguiente(id)
	var ahora := _detalle["ahora"] as Label
	var siguiente := _detalle["siguiente"] as Label
	var costo_label := _detalle["costo"] as Label
	ahora.text = "Ahora: " + Habilidades.efecto_texto(id, n, base)
	if costo < 0:
		siguiente.text = "Al máximo"
		costo_label.text = ""
	else:
		siguiente.text = "Siguiente: " + Habilidades.efecto_texto(id, n + 1, base)
		costo_label.text = "Cuesta %d %s" % [costo, "punto" if costo == 1 else "puntos"]
		costo_label.add_theme_color_override("font_color", BLANCO if costo <= Tazos.libres() and disponible else ROJO)
	var tazo_rect := _detalle["tazo"] as TextureRect
	var tazo_texto := _detalle["tazo_texto"] as Label
	tazo_rect.visible = false
	tazo_texto.text = ""
	if not disponible:
		var tazo := Tazos.tazo_que_desbloquea(id)
		if tazo:
			tazo_rect.visible = true
			tazo_rect.texture = tazo.silueta if tazo.silueta else tazo.cara
			tazo_texto.text = "Necesitas el tazo «%s»\nSerie %d · %s · No. %02d" % [
				tazo.nombre, tazo.serie + 1, TazoData.SERIES[tazo.serie], tazo.numero]
			tazo_texto.add_theme_color_override("font_color", GRIS)
	elif n > 0 and dato["bloqueada"]:
		var tazo := Tazos.tazo_que_desbloquea(id)
		if tazo:
			tazo_rect.visible = true
			tazo_rect.texture = tazo.cara
			tazo_texto.text = "La abrió el tazo «%s»" % tazo.nombre
			tazo_texto.add_theme_color_override("font_color", AMARILLO)


# Lo del jugador sin tazos, para que la pagina muestre numeros de verdad. Corrida sola
# (InventoryUI.tscn) no hay jugador: salen en porcentajes
func _valores_base() -> Dictionary:
	var jugador := get_tree().get_first_node_in_group("jugador")
	var base: Dictionary = jugador.valores_sin_tazos() if jugador and jugador.has_method("valores_sin_tazos") else {}
	base["lugares"] = Inventory.capacidad_mochila()
	base["persigue"] = Zombie.PERSIGUE
	return base


# --- Que se sienta ---

# El cuadrito nuevo sale blanco y se vuelve amarillo
func _resaltar_cuadro(fila: int, k: int) -> void:
	var cuadros: Array[ColorRect] = _filas[fila]["cuadros"]
	if k < 0 or k >= cuadros.size():
		return
	var cuadro := cuadros[k]
	var color := cuadro.color
	cuadro.color = BLANCO
	cuadro.scale = Vector2.ONE * 1.8
	cuadro.pivot_offset = cuadro.size * 0.5
	var t := create_tween().set_parallel()
	t.tween_property(cuadro, "color", color, 0.35)
	t.tween_property(cuadro, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# El que se apaga se desvanece de amarillo a hueco
func _apagar_cuadro(fila: int, k: int) -> void:
	var cuadros: Array[ColorRect] = _filas[fila]["cuadros"]
	if k < 0 or k >= cuadros.size():
		return
	var cuadro := cuadros[k]
	var color := cuadro.color
	cuadro.color = AMARILLO
	create_tween().tween_property(cuadro, "color", color, 0.3)


# La fila brinca un poquito
func _brincar(fila: int) -> void:
	var raiz := _filas[fila]["raiz"] as Control
	raiz.scale = Vector2.ONE * 1.06
	create_tween().tween_property(raiz, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# No te alcanza o esta bloqueada: el texto tiembla
func _temblar(nodo: Control) -> void:
	if nodo.has_meta("x0"):
		return
	var x0 := nodo.position.x
	nodo.set_meta("x0", x0)
	var t := create_tween()
	for desvio in [5.0, -4.0, 3.0, -2.0, 0.0]:
		t.tween_property(nodo, "position:x", x0 + desvio, 0.04)
	t.tween_callback(func() -> void: nodo.remove_meta("x0"))


func _label(texto: String, tamano: int, color: Color) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	return label


func _sonar(nombre: String) -> void:
	Sonidos.tocar(self, nombre, VOLUMEN)
