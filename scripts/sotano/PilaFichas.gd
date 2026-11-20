class_name PilaFichas
extends Node3D

# Una pila de fichas sobre el pano de una mesa del Sotano (la de tu apuesta en el baccarat y la
# ruleta): una ficha por cada una que juegas (hasta MAXIMO), de colores, un poco chuecas. Se mueve
# de casilla en casilla (ir_a) y al final se va con la casa o regresa a ti (llevar). En metros de la
# escena del Sotano (la pila es hija de Sotano.gd).

# Las fichas son el modelo de models/sotano/ficha.glb (sotano.py ficha_piezas: canto redondeado de
# 24 lados, seis franjas blancas y el centro de otro tono), Ficha_0..3, una por color
const FICHA := preload("res://models/sotano/ficha.glb")
const ALTO := 0.012
const MAXIMO := 24
const MAXIMO_MONTON := 70
# AG 2026-11-19 (la ruleta): fichas mas grandes en esa mesa (tamano), ganando un monton chueco como
# cerro (monton) y ganando de mas, en llamas (fuego)
var tamano := 1.0
var monton := false
var fuego := false
var _luz: OmniLight3D

static var _mallas: Array[Mesh] = []

var cantidad := 0


static func _preparar() -> void:
	if not _mallas.is_empty():
		return
	var escena := FICHA.instantiate()
	for k in 4:
		var m := escena.find_child("Ficha_%d" % k, true, false) as MeshInstance3D
		if m:
			_mallas.append(m.mesh)
	escena.free()


# Pone `n` fichas (las que sobren de MAXIMO no se ven); la primera de un color al azar
func poner(n: int) -> void:
	_preparar()
	cantidad = n
	for hijo in get_children():
		hijo.queue_free()
	_luz = null
	scale = Vector3.ONE * tamano
	if _mallas.is_empty():
		return
	if fuego:
		_prender()
	if monton:
		_monton(n)
		return
	var color := randi() % _mallas.size()
	for k in mini(n, MAXIMO):
		var ficha := MeshInstance3D.new()
		ficha.mesh = _mallas[(color + k / 5) % _mallas.size()]
		ficha.position = Vector3(randf_range(-0.002, 0.002), ALTO * k, randf_range(-0.002, 0.002))
		ficha.rotation.y = randf() * TAU
		ficha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ficha)


# Un cerro: fichas tiradas en un cono, chuecas, mas anchas abajo
func _monton(n: int) -> void:
	var total := clampi(n, 6, MAXIMO_MONTON)
	var radio := 0.03 + 0.011 * sqrt(total)
	var alto := ALTO * total * 0.16
	for k in total:
		var f := float(k) / total
		var r := radio * (1.0 - f * 0.9) * sqrt(randf())
		var a := randf() * TAU
		var ficha := MeshInstance3D.new()
		ficha.mesh = _mallas[randi() % _mallas.size()]
		ficha.position = Vector3(cos(a) * r, alto * f + ALTO * 0.5, sin(a) * r)
		ficha.rotation = Vector3(randf_range(-0.6, 0.6) * (1.0 - f * 0.5), randf() * TAU, randf_range(-0.6, 0.6) * (1.0 - f * 0.5))
		ficha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ficha)


# Llamas pixel (resources/fx fuego_tambo) encima y una luz naranja que tiembla
func _prender() -> void:
	var llama := EfectosPixel.cuadro_bucle("fuego_tambo", 0.1, 1.0, 0.0, false, true)
	if llama:
		add_child(llama)
		llama.position = Vector3(0, 0.04, 0)
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.55, 0.15)
	_luz.light_energy = 1.2
	_luz.omni_range = 0.8
	add_child(_luz)
	_luz.position = Vector3(0, 0.12, 0)


func _process(_delta: float) -> void:
	if _luz:
		_luz.light_energy = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.3 + randf() * 0.3


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
