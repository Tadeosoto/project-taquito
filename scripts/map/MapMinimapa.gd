extends CanvasLayer

# Radar redondo estilo GTA en la esquina superior derecha. El mapa es un PNG que
# dibuja tools/map_import/make_minimapa.py (calles, casas, parques, agua) y el
# shader minimapa.gdshader lo gira para que lo que ve la camara quede arriba.
# Encima van la flecha del jugador, la N del norte y un cuadrito por tienda
# (resources/map/puntos_mapa.json). Volando en dron se aleja para ver mas.

const DATOS := "res://resources/map/minimapa.json"
const PUNTOS := "res://resources/map/puntos_mapa.json"
const COLORES := {
	"oxxo": Color(0.9, 0.15, 0.1),
	"tienda": Color(1.0, 0.85, 0.2),
	"abarrotes": Color(1.0, 0.85, 0.2),
	"taqueria": Color(1.0, 0.5, 0.1),
	"puesto_tacos": Color(1.0, 0.5, 0.1),
	"tortilleria": Color(0.95, 0.85, 0.6),
	"farmacia": Color(0.2, 0.85, 0.75),
	"farmacia_local": Color(0.2, 0.85, 0.75),
	"farmacia_similares": Color(0.2, 0.85, 0.75),
	"gasolinera": Color(0.2, 0.75, 0.25),
	"puesto": Color(1.0, 0.55, 0.75),
}
const NEGRO := Color(0.05, 0.05, 0.05)

@export var mapa: Texture2D
@export var player_path: NodePath
@export var dron_path: NodePath
@export var tamano := 104.0          # diametro en pixeles (la pantalla es de 640x480)
@export var margen := 8.0
@export var radio_metros := 90.0     # cuanto se ve a pie, del centro a la orilla
@export var radio_dron := 220.0

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
var _adelante := Vector2(0.0, -1.0)
var _derecha := Vector2(1.0, 0.0)
var _rumbo := Vector2(0.0, -1.0)
var _radio := 90.0


func _ready() -> void:
	_player = get_node(player_path) as Node3D
	_frijol = _player.get_node_or_null("Frijol") as Node3D
	_dron = get_node_or_null(dron_path) as Node3D

	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	_origen = Vector2(datos["x0"], datos["z0"])
	_tam_metros = Vector2(datos["ancho"], datos["alto"]) * float(datos["metros_por_pixel"])
	var puntos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PUNTOS))
	for punto in puntos["puntos"]:
		if COLORES.has(punto["tipo"]):
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


func _process(_delta: float) -> void:
	var volando: bool = _dron != null and _dron.volando()
	var objetivo: Node3D = _dron if volando else _player
	_pos = Vector2(objetivo.global_position.x, objetivo.global_position.z)

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


func _dibujar_marcas() -> void:
	var centro := Vector2(tamano, tamano) / 2.0
	var limite := tamano / 2.0 - 6.0
	for punto in _puntos:
		var p := _a_pantalla(punto[0])
		if p.length() < limite:
			_marcas.draw_rect(Rect2(centro + p - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), NEGRO)
			_marcas.draw_rect(Rect2(centro + p - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), punto[1])

	# Flecha del jugador
	var dir := Vector2(_rumbo.dot(_derecha), -_rumbo.dot(_adelante)).normalized()
	var lado := Vector2(-dir.y, dir.x)
	var flecha := [dir * 6.0, lado * 4.5 - dir * 4.5, -dir * 2.0, -lado * 4.5 - dir * 4.5]
	var borde := PackedVector2Array()
	var cuerpo := PackedVector2Array()
	for v in flecha:
		borde.append(centro + v * 1.35)
		cuerpo.append(centro + v)
	_marcas.draw_colored_polygon(borde, NEGRO)
	_marcas.draw_colored_polygon(cuerpo, Color.WHITE)

	# Norte en la orilla
	var norte := Vector2(Vector2(0.0, -1.0).dot(_derecha), -Vector2(0.0, -1.0).dot(_adelante)) * (tamano / 2.0 - 3.0)
	_marcas.draw_circle(centro + norte, 5.5, NEGRO)
	_marcas.draw_string(ThemeDB.fallback_font, centro + norte + Vector2(-3.5, 4.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
