extends Node
# Video del marro (combo pesado, Player.PESADO) en el safehouse, con letreros: el combo contra un
# zombi duro, el golpe en area contra una bola y el machete contra la misma bola para comparar.
#   godot --path . --write-movie dir/c.png --fixed-fps 30 --resolution 640x480 tools/taller/video_marro.tscn
# El jugador no recibe dano; los zombis los saca el video (Zombis.sacar), los que salen solos no.

const MARRO := "res://resources/taller/marro.tres"
const MACHETE := "res://resources/productos/machete.tres"

var _jugador: Player
var _zombis: Zombis
var _inventario: Node
var _letrero: Label
var _frente := Vector3.FORWARD


func _ready() -> void:
	var casa: Node = load("res://scenes/safehouse.tscn").instantiate()
	add_child(casa)
	_jugador = casa.get_node("Player") if casa.has_node("Player") else get_tree().get_first_node_in_group("jugador")
	_zombis = casa.get_node("Zombis")
	_inventario = get_node("/root/Inventory")
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	_letrero = Label.new()
	_letrero.theme = preload("res://resources/ui/tema_pixel.tres")
	_letrero.position = Vector2(12, 425)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 5)
	capa.add_child(_letrero)
	await _video()
	get_tree().quit()


func _process(_delta: float) -> void:
	if _jugador:
		_jugador._invulnerable = 999.0


func _seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _decir(texto: String) -> void:
	_letrero.text = texto


func _sacar(distancia: float, grados: float, vida := Zombie.VIDA) -> Zombie:
	var z := _zombis.sacar(_jugador.global_position + _frente.rotated(Vector3.UP, deg_to_rad(grados)) * distancia, true)
	z._vida = vida
	return z


func _armar(ruta: String) -> void:
	_inventario.vaciar()
	_inventario.add_item(load(ruta))


# Golpes seguidos del combo, cada `cada` s
func _combo(golpes: int, cada: float) -> void:
	for i in golpes:
		_jugador._atacar()
		await _seg(cada)


func _bola() -> Array[Zombie]:
	var bola: Array[Zombie] = []
	for grados: float in [-45.0, -20.0, 0.0, 20.0, 45.0]:
		bola.append(_sacar(1.6, grados))
	return bola


func _vivos(bola: Array[Zombie]) -> int:
	return bola.filter(func(z: Zombie) -> bool: return z.estado != Zombie.Estado.MUERTO).size()


func _limpiar(bola: Array) -> void:
	for z: Zombie in bola:
		if is_instance_valid(z):
			z.queue_free()


func _video() -> void:
	_zombis.set_physics_process(false)
	await _seg(1.5)
	_frente = -_jugador.frijol.global_transform.basis.z
	_frente.y = 0.0
	_frente = _frente.normalized()
	_armar(MARRO)
	_decir("El marro: 20 de daño, golpe lento")
	await _seg(2.0)
	var duro := _sacar(1.6, 0.0, 90)
	_decir("Un zombi duro (90 de vida): el combo de 3")
	await _seg(1.0)
	_decir("Golpes 1 y 2: lo aturden y lo recorren poquito")
	await _combo(2, 0.9)
	_decir("El 3 remata (x1.5) y lo avienta")
	await _combo(1, 2.0)
	_decir("Le quedan %d de 90" % maxi(duro._vida, 0))
	await _seg(1.5)
	_limpiar([duro])
	await _seg(1.0)
	_decir("Una bola de 5 (30 de vida cada uno)")
	var bola := _bola()
	await _seg(1.2)
	_decir("Le pega a los 4 más cercanos a la vez")
	await _combo(1, 1.0)
	_decir("Ninguno muere de un golpe (quedan en 10)")
	await _combo(1, 1.0)
	_decir("El segundo golpe: quedan %d de 5" % _vivos(bola))
	await _combo(1, 1.4)
	_decir("Con el tercero: quedan %d de 5" % _vivos(bola))
	await _seg(2.0)
	_limpiar(bola)
	await _seg(1.0)
	_armar(MACHETE)
	_decir("Para comparar: el machete contra la misma bola")
	bola = _bola()
	await _seg(1.5)
	_decir("12 de daño, a uno por golpe, rápido")
	await _combo(6, 0.4)
	_decir("En el mismo rato: quedan %d de 5" % _vivos(bola))
	await _seg(2.5)
	_limpiar(bola)
