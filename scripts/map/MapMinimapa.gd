extends CanvasLayer

# Radar redondo estilo GTA en la esquina superior derecha. El mapa es un PNG que
# dibuja tools/map_import/make_minimapa.py (calles, casas, parques, agua) y el
# shader minimapa.gdshader lo gira para que lo que ve la camara quede arriba.
# Encima van la flecha del jugador, la N del norte y un cuadrito por tienda
# (resources/map/puntos_mapa.json). Volando en dron se aleja para ver mas.
# Con datos_path vacio no lee el mapa real: otra escena le da el suyo con usar_mapa
# (la defensa del tinaco dibuja su barricada).

const DATOS := "res://resources/map/minimapa.json"
const PUNTOS := "res://resources/map/puntos_mapa.json"
const COLORES := {
	"oxxo": Color(0.9, 0.15, 0.1),
	"abarrotes": Color(1.0, 0.85, 0.2),
	"licoreria": Color(0.25, 0.4, 0.95),
	"taqueria": Color(1.0, 0.5, 0.1),
	"puesto_tacos": Color(1.0, 0.5, 0.1),
	"farmacia": Color(0.2, 0.85, 0.75),
	"gasolinera": Color(0.2, 0.75, 0.25),
	"puesto": Color(1.0, 0.55, 0.75),
	"ferreteria": Color(0.75, 0.45, 0.2),
	"purificadora": Color(0.35, 0.6, 1.0),
}
const NEGRO := Color(0.05, 0.05, 0.05)
const OBJETIVO_COLOR := Color(1.0, 0.85, 0.1)
const ZOMBI_COLOR := Color(0.95, 0.15, 0.1)
const OBJETIVO_PARPADEA_MS := 350

@export var mapa: Texture2D
@export var player_path: NodePath
@export var dron_path: NodePath
@export var tamano := 104.0          # diametro en pixeles (la pantalla es de 640x480)
@export var margen := 8.0
@export var radio_metros := 90.0     # cuanto se ve a pie, del centro a la orilla
@export var radio_dron := 220.0
@export var datos_path := DATOS
@export var puntos_path := PUNTOS
# Los zombis como puntos rojos siempre, no solo con Ojo de halcon
@export var zombis_siempre := false
# Centrado en un punto fijo del mundo (x, z) en vez del jugador: sigue girando con
# la camara y la flecha va donde esta el jugador
@export var centro_fijo := false
@export var centro_mundo := Vector2.ZERO

var _player: Node3D
var _frijol: Node3D
var _dron: Node3D
var _radar: ColorRect
var _marcas: Control
var _material: ShaderMaterial
var _origen := Vector2.ZERO
var _tam_metros := Vector2.ONE
var _puntos: Array = []              # [[Vector2 xz, Color], ...]

# Lo que se calcula cada cuadro y usa _dibujar_marcas
var _pos := Vector2.ZERO
var _jugador_pos := Vector2.ZERO
var _adelante := Vector2(0.0, -1.0)
var _derecha := Vector2(1.0, 0.0)
var _rumbo := Vector2(0.0, -1.0)
var _radio := 90.0


func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_frijol = _player.get_node_or_null("Frijol") as Node3D
	_dron = get_node_or_null(dron_path) as Node3D

	if datos_path != "":
		var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(datos_path))
		_origen = Vector2(datos["x0"], datos["z0"])
		_tam_metros = Vector2(datos["ancho"], datos["alto"]) * float(datos["metros_por_pixel"])
	if puntos_path != "":
		var puntos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(puntos_path))
		for punto in puntos["puntos"]:
			# Solo los negocios interactivos (con marcador); el punto no tiene color: es clandestino
			if COLORES.has(punto["tipo"]) and punto.get("interactivo", true):
				_puntos.append([Vector2(punto["x"], punto["z"]), COLORES[punto["tipo"]]])

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/minimapa.gdshader")
	_material.set_shader_parameter("mapa", mapa)
	_radar = ColorRect.new()
	_radar.material = _material
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_radar.size = Vector2(tamano, tamano)
	_radar.position = Vector2(-tamano - margen, margen)
	add_child(_radar)
	_marcas = Control.new()
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marcas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marcas.draw.connect(_dibujar_marcas)
	_radar.add_child(_marcas)


# Un mapa que no es el real: `origen` es la esquina (x, z) de menor valor de la
# textura y `tam_metros` lo que mide
func usar_mapa(textura: Texture2D, origen: Vector2, tam_metros: Vector2) -> void:
	mapa = textura
	_origen = origen
	_tam_metros = tam_metros
	if _material:
		_material.set_shader_parameter("mapa", mapa)


func _process(_delta: float) -> void:
	var volando: bool = _dron != null and _dron.volando()
	var objetivo: Node3D = _dron if volando else _player
	_pos = Vector2(objetivo.global_position.x, objetivo.global_position.z)
	_jugador_pos = _pos
	if centro_fijo:
		_pos = centro_mundo

	var camara := get_viewport().get_camera_3d()
	if camara:
		var f := -camara.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			_adelante = Vector2(f.x, f.z).normalized()
			_derecha = Vector2(-_adelante.y, _adelante.x)
	_rumbo = _adelante
	if not volando and _frijol:
		var h := -_frijol.global_basis.z
		if Vector2(h.x, h.z).length() > 0.01:
			_rumbo = Vector2(h.x, h.z).normalized()
	_radio = radio_dron if volando else radio_metros

	_material.set_shader_parameter("centro", (_pos - _origen) / _tam_metros)
	_material.set_shader_parameter("adelante", _adelante)
	_material.set_shader_parameter("derecha", _derecha)
	_material.set_shader_parameter("radio_uv", Vector2(_radio, _radio) / _tam_metros)
	_marcas.queue_redraw()


# Punto del mundo (XZ) -> pixel dentro del radar
func _a_pantalla(xz: Vector2) -> Vector2:
	var d := (xz - _pos) / _radio * (tamano / 2.0)
	return Vector2(d.dot(_derecha), -d.dot(_adelante))


# A donde va la mision: parpadea, y si esta lejos se queda en la orilla apuntando hacia alla.
# Por su ruta: los scripts de tools/ pueden cargar esta clase
func _dibujar_objetivo(centro: Vector2, limite: float) -> void:
	var misiones := get_node_or_null("/root/Misiones")
	if misiones == null or not misiones.hay_objetivo:
		return
	var p := _a_pantalla(misiones.objetivo)
	var radio: float = misiones.objetivo_radio / _radio * (tamano / 2.0)
	if radio > 0.0 and p.length() - radio < limite:
		_marcas.draw_arc(centro + p, radio, 0.0, TAU, 24, OBJETIVO_COLOR, 1.5)
	if p.length() > limite:
		p = p.normalized() * limite
	if int(Time.get_ticks_msec() / OBJETIVO_PARPADEA_MS) % 2 == 0:
		var rombo := PackedVector2Array([centro + p + Vector2(0.0, -5.0), centro + p + Vector2(5.0, 0.0), centro + p + Vector2(0.0, 5.0), centro + p + Vector2(-5.0, 0.0)])
		_marcas.draw_colored_polygon(rombo, OBJETIVO_COLOR)
		rombo.append(rombo[0])
		_marcas.draw_polyline(rombo, NEGRO, 1.0)


# Los negocios "punto" de la mafia que ya conoces (Misiones.puntos_vistos): una P en un cuadro negro
func _dibujar_puntos_mafia(centro: Vector2, limite: float) -> void:
	var misiones := get_node_or_null("/root/Misiones")
	if misiones == null:
		return
	for punto: Array in misiones.puntos_vistos:
		var p := _a_pantalla(punto[0])
		if p.length() < limite:
			_marcas.draw_rect(Rect2(centro + p - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), Color.WHITE)
			_marcas.draw_rect(Rect2(centro + p - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), NEGRO)
			_marcas.draw_string(ThemeDB.fallback_font, centro + p + Vector2(-3.5, 3.5), "P",
				HORIZONTAL_ALIGNMENT_CENTER, 7.0, 9, Color.WHITE)


# Los dadores importantes con trabajo (Misiones.dadores): su inicial, solo si cae adentro
func _dibujar_dadores(centro: Vector2, limite: float) -> void:
	var misiones := get_node_or_null("/root/Misiones")
	if misiones == null:
		return
	for dador: Array in misiones.dadores:
		var p := _a_pantalla(dador[0])
		if p.length() < limite:
			_marcas.draw_circle(centro + p, 5.5, NEGRO)
			_marcas.draw_circle(centro + p, 4.5, Color.WHITE)
			_marcas.draw_string(ThemeDB.fallback_font, centro + p + Vector2(-3.5, 3.5), dador[1],
				HORIZONTAL_ALIGNMENT_CENTER, 7.0, 9, NEGRO)


# Ojo de halcon (Tazos.gd): los zombis vivos como puntos rojos. Por ruta, como Misiones
func _dibujar_zombis(centro: Vector2, limite: float) -> void:
	var tazos := get_node_or_null("/root/Tazos")
	if not zombis_siempre and (tazos == null or not tazos.tiene("ojo_halcon")):
		return
	for zombi: Node3D in get_tree().get_nodes_in_group("zombis"):
		if zombi.get("estado") == 3:   # Zombie.Estado.MUERTO
			continue
		var p := _a_pantalla(Vector2(zombi.global_position.x, zombi.global_position.z))
		if p.length() < limite:
			_marcas.draw_circle(centro + p, 2.5, NEGRO)
			_marcas.draw_circle(centro + p, 1.6, ZOMBI_COLOR)


func _dibujar_marcas() -> void:
	var centro := Vector2(tamano, tamano) / 2.0
	var limite := tamano / 2.0 - 6.0
	for punto in _puntos:
		var p := _a_pantalla(punto[0])
		if p.length() < limite:
			_marcas.draw_rect(Rect2(centro + p - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), NEGRO)
			_marcas.draw_rect(Rect2(centro + p - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), punto[1])

	_dibujar_puntos_mafia(centro, limite)
	_dibujar_dadores(centro, limite)
	_dibujar_objetivo(centro, limite)
	_dibujar_zombis(centro, limite)
	# Flecha del jugador (al centro, salvo con centro_fijo)
	var donde := centro
	if centro_fijo:
		var p := _a_pantalla(_jugador_pos)
		donde = centro + (p.normalized() * limite if p.length() > limite else p)
	var dir := Vector2(_rumbo.dot(_derecha), -_rumbo.dot(_adelante)).normalized()
	var lado := Vector2(-dir.y, dir.x)
	var flecha := [dir * 6.0, lado * 4.5 - dir * 4.5, -dir * 2.0, -lado * 4.5 - dir * 4.5]
	var borde := PackedVector2Array()
	var cuerpo := PackedVector2Array()
	for v in flecha:
		borde.append(donde + v * 1.35)
		cuerpo.append(donde + v)
	_marcas.draw_colored_polygon(borde, NEGRO)
	_marcas.draw_colored_polygon(cuerpo, Color.WHITE)

	# Norte en la orilla
	var norte := Vector2(Vector2(0.0, -1.0).dot(_derecha), -Vector2(0.0, -1.0).dot(_adelante)) * (tamano / 2.0 - 3.0)
	_marcas.draw_circle(centro + norte, 5.5, NEGRO)
	_marcas.draw_string(ThemeDB.fallback_font, centro + norte + Vector2(-3.5, 4.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
