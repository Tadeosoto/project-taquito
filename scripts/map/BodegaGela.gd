class_name BodegaGela
extends Node3D

## La bodega de GelA cerca de la reja poniente (M6, "El Decreto 47", Sofia): la oficina de GelA de fuera, donde
## estan el expediente del Decreto 47 y la hoja de conteo. Es una de las bodegas huecas de MapBodegas
## (bodegas_mapa.json), pero toda cerrada: sin vanos abiertos ni hoyos. Uno de sus vanos es esta cortina, que
## se FUERZA de noche (JJ: no hay llave) manteniendo Espacio FORZAR s: el ruido trae zombis de la calle y al
## abrirse salen los de adentro. Ya forzada se queda abierta (Misiones.bodega_gela_abierta). Los papeles
## (MisionesMundo, `papeles_decreto`) estan al fondo; `punto` da donde, en metros del juego.

## La bodega en bodegas_mapa.json: centro de su frente, giro (+Z hacia la calle), ancho y fondo
const CENTRO := Vector2(-333.17, 644.6)
const GIRO := -0.1396
const ANCHO := 58.67
const FONDO := 32.26
const FORZAR := 5.0            # s con Espacio apretado
const ALCANCE := 3.0           # m del centro de la cortina para poder forzarla
const RUIDO_CADA := 0.6        # s entre golpe y golpe de la palanca
const RUIDO_ZOMBIS := 3        # los que llegan de la calle al empezar a forzar
const RUIDO_A := 35.0          # m de la cortina a los que salen
const ADENTRO_ZOMBIS := 4      # los que salen de adentro al abrirla
## Los papeles, en el marco de la bodega (x a lo ancho, z hacia adentro negativa): al fondo, detras de los racks
const PAPELES := [Vector3(-14.0, 0.0, -FONDO + 0.8), Vector3(14.0, 0.0, -FONDO + 0.8)]
const TEXTO_DIA := "De día hay blancos cuidando la bodega. Vuelve de noche."

## Donde quedo la cortina (al armarse la celda; Vector3.INF si aun no): a donde apunta la flecha de la mision
static var frente_cortina := Vector3.INF

var _cerrada: Array[Node3D] = []
var _abierta: Array[Node3D] = []
var _frente := Vector3.ZERO    # centro de la cortina, en el piso
var _progreso := 0.0
var _forzando := false
var _hizo_ruido := false
var _golpe_en := 0.0
var _letrero: Label3D


static func es(bodega: Dictionary) -> bool:
	return Vector2(bodega["x"], bodega["z"]).distance_to(CENTRO) < 1.0


static func punto(local: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP, GIRO), Vector3(CENTRO.x, 0.0, CENTRO.y)) * local


## La arma MapBodegas al poner la celda: las mallas y la colision del vano cerrado y del abierto, y su centro
static func armar(cerrada: Array[Node3D], abierta: Array[Node3D], frente: Vector3) -> BodegaGela:
	var b := BodegaGela.new()
	b.name = "BodegaGela"
	b._frente = frente
	frente_cortina = frente
	b._cerrada = cerrada
	b._abierta = abierta
	for n in cerrada + abierta:
		b.add_child(n)
	return b


func _ready() -> void:
	add_to_group("interactuable")
	_letrero = Label3D.new()
	_letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_letrero.font_size = 48
	_letrero.pixel_size = 0.01
	_letrero.outline_size = 12
	_letrero.no_depth_test = true
	_letrero.visible = false
	add_child(_letrero)
	_letrero.global_position = _frente + Vector3.UP * 2.2
	_mostrar(Misiones.bodega_gela_abierta)


func _mostrar(abierta: bool) -> void:
	for n in _cerrada:
		n.visible = not abierta
		if n is CollisionObject3D:
			n.process_mode = Node.PROCESS_MODE_DISABLED if abierta else Node.PROCESS_MODE_INHERIT
	for n in _abierta:
		n.visible = abierta
		if n is CollisionObject3D:
			n.process_mode = Node.PROCESS_MODE_INHERIT if abierta else Node.PROCESS_MODE_DISABLED


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


func _de_la_mision() -> bool:
	return Misiones.activa != null and Misiones.activa.id == "decreto_47" and Misiones.paso() != null \
			and Misiones.paso().lugar == "papeles_decreto"


func _cerca() -> bool:
	var j := _jugador()
	return j != null and Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(_frente.x, _frente.z)) <= ALCANCE


## Para el Espacio del jugador (Player._nearby_interactable): solo en la mision y mientras siga cerrada
func is_player_inside() -> bool:
	return not Misiones.bodega_gela_abierta and _de_la_mision() and _cerca()


func interact() -> void:
	if Misiones.bodega_gela_abierta or not _de_la_mision():
		return
	if Misiones.hora_que_falta(Misiones.paso()) != "":
		var supervivencia := get_tree().current_scene.get_node_or_null("Supervivencia")
		if supervivencia and supervivencia.has_method("avisar"):
			supervivencia.avisar(TEXTO_DIA)
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	_forzando = true
	if not _hizo_ruido:
		_hizo_ruido = true
		_sacar(RUIDO_ZOMBIS, func() -> Vector3:
			var lado := Vector2.from_angle(randf() * TAU) * RUIDO_A
			return _frente + Vector3(lado.x, 0.0, lado.y))


func _process(delta: float) -> void:
	if not _forzando:
		return
	if not Input.is_action_pressed("jump") or not _cerca():
		_forzando = false
		_letrero.visible = false
		return
	_progreso += delta
	_letrero.visible = true
	_letrero.text = "Forzando la cortina... %d%%" % mini(roundi(100.0 * _progreso / FORZAR), 100)
	_golpe_en -= delta
	if _golpe_en <= 0.0:
		_golpe_en = RUIDO_CADA
		Sonidos.tocar(self, "whack", -4.0)
	if _progreso >= FORZAR:
		_abrir()


func _abrir() -> void:
	_forzando = false
	_letrero.visible = false
	Misiones.bodega_gela_abierta = true
	_mostrar(true)
	Sonidos.tocar(self, "bloqueo", 0.0)
	var i := [0]
	_sacar(ADENTRO_ZOMBIS, func() -> Vector3:
		i[0] += 1
		return punto(Vector3(-ANCHO / 3.0 + (i[0] % 4) * ANCHO / 4.5, 0.0, -3.0 - randf() * 1.5)))


func _sacar(cuantos: int, donde: Callable) -> void:
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando == null:
		return
	for k in cuantos:
		mando.sacar(donde.call(), false)
