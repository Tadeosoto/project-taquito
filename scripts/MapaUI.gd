extends Control

# El mapa de papel, adentro del inventario (InventoryUI.gd, tecla inventory_map): cada zona
# de ZonasMapa es un pedazo. Las que ya tienes (PiezasMapa) se ven con el minimapa adentro;
# las demas, papel oscuro con un signo. Mouse o PageUp/PageDown acercan, las flechas mueven.
# Pantalla de 640x480, con el mapa a la izquierda y la lista de zonas a la derecha.

const TEXTURA := preload("res://textures/map/minimapa.png")
const AMARILLO := Color(1.0, 0.85, 0.1)
const PAPEL_FALTA := Color(0.1, 0.09, 0.08)
const ORILLA := Color(0.0, 0.0, 0.0)
const FALTA_TEXTO := Color(0.4, 0.38, 0.33)
const MARCO := Rect2(10.0, 34.0, 432.0, 424.0)
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_PASO := 1.25
const MOVER := 320.0        # pixeles de pantalla por segundo
const LISTA_X := 452.0
const LISTA_Y := 88.0
const LISTA_PASO := 34.0

var zoom := 1.0
var _centro := ZonasMapa.LADO_MAPA / 2.0
var _rasgados: Array[PackedVector2Array] = []
var _uvs: Array[PackedVector2Array] = []
var _fuente: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fuente = get_theme_default_font()
	for i in ZonasMapa.cuantas():
		var poligono := ZonasMapa.rasgado(i)
		var uv := PackedVector2Array()
		for p in poligono:
			uv.append(p / ZonasMapa.LADO_MAPA)
		_rasgados.append(poligono)
		_uvs.append(uv)


# Al abrir: el mapa entero
func mostrar() -> void:
	zoom = ZOOM_MIN
	_centro = ZonasMapa.LADO_MAPA / 2.0
	visible = true
	queue_redraw()


func acercar(pasos: int) -> void:
	zoom = clampf(zoom * pow(ZOOM_PASO, pasos), ZOOM_MIN, ZOOM_MAX)
	_limitar()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	var mover := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if mover != Vector2.ZERO:
		_centro += mover * MOVER * delta / _escala()
		_limitar()
	queue_redraw()


func _limitar() -> void:
	var medio := MARCO.size / 2.0 / _escala()
	_centro.x = clampf(_centro.x, minf(medio.x, ZonasMapa.LADO_MAPA.x / 2.0), maxf(ZonasMapa.LADO_MAPA.x - medio.x, ZonasMapa.LADO_MAPA.x / 2.0))
	_centro.y = clampf(_centro.y, minf(medio.y, ZonasMapa.LADO_MAPA.y / 2.0), maxf(ZonasMapa.LADO_MAPA.y - medio.y, ZonasMapa.LADO_MAPA.y / 2.0))


func _escala() -> float:
	return minf(MARCO.size.x / ZonasMapa.LADO_MAPA.x, MARCO.size.y / ZonasMapa.LADO_MAPA.y) * zoom


func _en_pantalla(punto: Vector2) -> Vector2:
	return MARCO.get_center() + (punto - _centro) * _escala()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var aqui := _zona_del_jugador()
	var transformacion := Transform2D(0.0, Vector2.ONE * _escala(), 0.0, MARCO.get_center() - _centro * _escala())
	draw_set_transform_matrix(transformacion)
	for i in _rasgados.size():
		if PiezasMapa.tiene(i):
			draw_colored_polygon(_rasgados[i], Color.WHITE, _uvs[i], TEXTURA)
		else:
			draw_colored_polygon(_rasgados[i], PAPEL_FALTA)
	var grueso := 1.5 / _escala()
	for i in _rasgados.size():
		var cerrado := _rasgados[i].duplicate()
		cerrado.append(_rasgados[i][0])
		draw_polyline(cerrado, ORILLA, grueso * 2.0)
	if aqui >= 0:
		var cerrado := _rasgados[aqui].duplicate()
		cerrado.append(_rasgados[aqui][0])
		draw_polyline(cerrado, AMARILLO, grueso)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in _rasgados.size():
		_nombre_en_mapa(i)
	_objetivo_en_mapa()
	_tapar_fuera_del_marco()
	_jugador_en_mapa()
	_columna(aqui)


# A donde va la mision: un rombo, aunque ese pedazo todavia no se tenga
func _objetivo_en_mapa() -> void:
	if not Misiones.hay_objetivo:
		return
	var p := _en_pantalla(ZonasMapa.a_mapa(Misiones.objetivo.x, Misiones.objetivo.y))
	if Misiones.objetivo_radio > 0.0:
		draw_arc(p, Misiones.objetivo_radio * _escala(), 0.0, TAU, 32, AMARILLO, 1.5)
	var rombo := PackedVector2Array([p + Vector2(0.0, -7.0), p + Vector2(7.0, 0.0), p + Vector2(0.0, 7.0), p + Vector2(-7.0, 0.0)])
	draw_colored_polygon(rombo, AMARILLO)
	rombo.append(rombo[0])
	draw_polyline(rombo, Color.BLACK, 1.5)


# El dibujo se pasa del marco al acercar: lo que sobra se tapa de negro
func _tapar_fuera_del_marco() -> void:
	var r := MARCO
	draw_rect(Rect2(0.0, 0.0, size.x, r.position.y), Color.BLACK)
	draw_rect(Rect2(0.0, r.end.y, size.x, size.y - r.end.y), Color.BLACK)
	draw_rect(Rect2(0.0, 0.0, r.position.x, size.y), Color.BLACK)
	draw_rect(Rect2(r.end.x, 0.0, size.x - r.end.x, size.y), Color.BLACK)
	draw_rect(r, AMARILLO, false, 1.0)


func _nombre_en_mapa(zona: int) -> void:
	var donde := _en_pantalla(ZonasMapa.centro(zona))
	if not PiezasMapa.tiene(zona):
		_texto("?", donde + Vector2(0.0, 9.0), 26, FALTA_TEXTO, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var nombre := ZonasMapa.nombre(zona)
	var partes := nombre.split(" ")
	var mitad := ceili(partes.size() / 2.0)
	if partes.size() <= 2:
		_texto(nombre, donde, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_texto(" ".join(partes.slice(0, mitad)), donde - Vector2(0.0, 6.0), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_texto(" ".join(partes.slice(mitad)), donde + Vector2(0.0, 7.0), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _texto(texto: String, donde: Vector2, tamano: int, color: Color, alinear: HorizontalAlignment, ancho := 240.0) -> void:
	var origen := donde
	if alinear == HORIZONTAL_ALIGNMENT_CENTER:
		origen.x -= ancho / 2.0
	draw_string_outline(_fuente, origen, texto, alinear, ancho, tamano, 4, Color.BLACK)
	draw_string(_fuente, origen, texto, alinear, ancho, tamano, color)


func _jugador() -> Player:
	return get_tree().get_first_node_in_group("jugador") as Player


func _zona_del_jugador() -> int:
	var jugador := _jugador()
	if jugador == null:
		return -1
	return ZonasMapa.zona_en(jugador.global_position.x, jugador.global_position.z)


# Una flecha hacia donde mira, solo si estas adentro del mapa
func _jugador_en_mapa() -> void:
	var jugador := _jugador()
	if jugador == null or _zona_del_jugador() < 0:
		return
	var p := _en_pantalla(ZonasMapa.a_mapa(jugador.global_position.x, jugador.global_position.z))
	if not MARCO.has_point(p):
		return
	var frente := -jugador.frijol.global_basis.z
	var d := Vector2(frente.x, frente.z).normalized()
	var lado := d.orthogonal()
	var flecha := PackedVector2Array([p + d * 9.0, p - d * 6.0 + lado * 6.0, p - d * 6.0 - lado * 6.0])
	draw_colored_polygon(flecha, AMARILLO)
	flecha.append(flecha[0])
	draw_polyline(flecha, Color.BLACK, 1.5)


func _columna(aqui: int) -> void:
	_texto("MAPA", Vector2(10.0, 24.0), 18, AMARILLO, HORIZONTAL_ALIGNMENT_LEFT)
	_texto("Piezas: %d de %d" % [PiezasMapa.cuantas(), ZonasMapa.cuantas()], Vector2(LISTA_X, 24.0), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 180.0)
	if aqui >= 0 and PiezasMapa.tiene(aqui):
		_texto("Estás en:", Vector2(LISTA_X, 46.0), 11, Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, 180.0)
		_texto(ZonasMapa.nombre(aqui), Vector2(LISTA_X, 62.0), 11, AMARILLO, HORIZONTAL_ALIGNMENT_LEFT, 180.0)
	for i in ZonasMapa.cuantas():
		var nombre := ZonasMapa.nombre(i) if PiezasMapa.tiene(i) else "? ? ?"
		var color := Color.WHITE if PiezasMapa.tiene(i) else FALTA_TEXTO
		if i == aqui and PiezasMapa.tiene(i):
			color = AMARILLO
		_texto(nombre, Vector2(LISTA_X, LISTA_Y + i * LISTA_PASO), 11, color, HORIZONTAL_ALIGNMENT_LEFT, 180.0)
	_texto("Flechas: mover   Rueda: acercar   Esc: regresar", Vector2(10.0, 474.0), 11, Color(0.75, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT, 430.0)
