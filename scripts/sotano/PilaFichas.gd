class_name PilaFichas
extends Node3D

# Una pila de fichas sobre el pano de una mesa del Sotano (la de tu apuesta en el baccarat y la
# ruleta): una ficha por cada una que juegas (hasta MAXIMO), de colores, un poco chuecas. Se mueve
# de casilla en casilla (ir_a) y al final se va con la casa o regresa a ti (llevar). En metros de la
# escena del Sotano (la pila es hija de Sotano.gd).

const RADIO := 0.028
const ALTO := 0.012
const MAXIMO := 24
const COLORES := [Color(0.85, 0.1, 0.1), Color(0.1, 0.3, 0.85), Color(0.95, 0.95, 0.9), Color(0.1, 0.55, 0.2)]

static var _malla: CylinderMesh
static var _materiales: Array[StandardMaterial3D] = []

var cantidad := 0


static func _preparar() -> void:
	if _malla:
		return
	_malla = CylinderMesh.new()
	_malla.top_radius = RADIO
	_malla.bottom_radius = RADIO
	_malla.height = ALTO
	_malla.radial_segments = 10
	for c: Color in COLORES:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		_materiales.append(m)


# Pone `n` fichas (las que sobren de MAXIMO no se ven); la primera de un color al azar
func poner(n: int) -> void:
	_preparar()
	cantidad = n
	for hijo in get_children():
		hijo.queue_free()
	var color := randi() % COLORES.size()
	for k in mini(n, MAXIMO):
		var ficha := MeshInstance3D.new()
		ficha.mesh = _malla
		ficha.material_override = _materiales[(color + k / 5) % _materiales.size()]
		ficha.position = Vector3(randf_range(-0.002, 0.002), ALTO * (k + 0.5), randf_range(-0.002, 0.002))
		ficha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ficha)


func ir_a(destino: Vector3, tiempo := 0.22) -> Tween:
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", destino, tiempo)
	return t


# Se desliza a `destino` (con la casa o hacia ti) en un arquito y desaparece
func llevar(destino: Vector3, tiempo := 0.45) -> void:
	var desde := position
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		position = desde.lerp(destino, f) + Vector3.UP * sin(f * PI) * 0.05, 0.0, 1.0, tiempo).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
