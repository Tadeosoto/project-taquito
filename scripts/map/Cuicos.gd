class_name Cuicos
extends Node3D

# Los cuicos de dia (M7b, docs/plan-noche.md): unos cuantos policias (Cuico.gd, modelos policia_* del
# pack PSX) caminan por las mismas banquetas que la gente (resources/map/banquetas_mapa.json) cerca
# del jugador. Si te ven con la caja de la mafia o con el agua del reparto (si te amanece en camino
# sigue de dia: Misiones.sigue_de_dia, S3) te persiguen y te disparan.
# Se les puede tumbar, pero eso sube la busqueda: por cada tumbado llegan REFUERZOS mas, ya
# avisados de donde estas. La busqueda se olvida si nadie te ve en OLVIDA s. No entran a las fortalezas (el muro de Santa Mugre,
# La Gotera y los Reservorios) ni te ven ahi. Al avisar que va a oscurecer ya no salen y al
# anochecer se van todos (la policia es de dia, lore §5). El minimapa los dibuja (MapMinimapa).

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const MODELOS := [
	"policia_17", "policia_18", "policia_19", "policia_20", "policia_21", "policia_22",
	"policia_mujer_17", "policia_mujer_18", "policia_mujer_19", "policia_mujer_20",
	"policia_mujer_25", "policia_mujer_26",
]
const PATRULLAN := 4           # los que caminan sin buscarte
const MAXIMO := 10             # con los refuerzos
const REFUERZOS := 2           # por cada tumbado
const ANILLO := Vector2(30.0, 70.0)
const REFUERZO_ANILLO := Vector2(40.0, 60.0)
const QUITAR_A := 90.0
const LLAMA := 35.0            # al pegarle a uno, los que estan asi de cerca vienen
const OLVIDA := 30.0           # s sin que nadie te vea para que dejen de buscarte
const CADA := 0.5
const INTENTOS := 8
const CELDA := 32.0
const PRUEBA_CADA := 1.5       # como Gente: cada tanto se mira si adelante sigue la banqueta
const PRUEBA_ADELANTE := 1.2
const UNE_A := 14.0
const ALTO_LIBRE := 0.6
const REGRESO_BUSCA := 40.0    # m: banqueta a la que vuelve despues de buscarte
# El minimapa (MapMinimapa._dibujar_cuicos)
const VISTA := Cuico.VISTA
const VISTA_ANGULO := Cuico.VISTA_ANGULO

@export_file("*.json") var banquetas_path := "res://resources/map/banquetas_mapa.json"

## El nivel de busqueda: pegarle a uno lo pone en 1 y cada tumbado le suma otro. Con 1 o mas
## te disparan aunque no traigas la caja; se olvida en OLVIDA s sin que nadie te vea
var busqueda := 0

var _lineas: Array = []
var _celdas := {}
var _finales := {}
var _libres: Array[Cuico] = []
var _fuera: Array[Cuico] = []
var _jugador: Node3D
var _ciclo: Node
var _saliendo := false
var _espera := 0.0
var _sin_verte := 0.0
var _rayo: PhysicsRayQueryParameters3D


func _ready() -> void:
	_rayo = PhysicsRayQueryParameters3D.new()
	_rayo.collision_mask = 1
	_jugador = get_tree().get_first_node_in_group("jugador")
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo:
		_ciclo.aviso_atardecer.connect(func() -> void: _saliendo = true)
		_ciclo.anochecio.connect(_quitar_a_todos)
		_ciclo.amanecio.connect(func() -> void: _saliendo = false)
	_cargar_banquetas()


func _process(delta: float) -> void:
	if _jugador == null:
		return
	if busqueda > 0:
		_sin_verte += delta
		if _sin_verte >= OLVIDA:
			busqueda = 0
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = CADA
	_armar_reserva()
	for c: Cuico in _fuera.duplicate():
		if not c.activo() and c.global_position.distance_to(_jugador.global_position) > QUITAR_A:
			guardar(c)
	if hay_cuicos() and _patrullando() < PATRULLAN:
		_sacar(ANILLO, false)


func hay_cuicos() -> bool:
	return not _saliendo and not (_ciclo and _ciclo.es_noche())


func te_buscan() -> bool:
	return busqueda > 0


# Lo que hay en el mundo, para el minimapa
func fuera() -> Array[Cuico]:
	return _fuera


# --- Lo que avisan los cuicos ---

func te_vieron() -> void:
	_sin_verte = 0.0


func lo_atacaron(quien: Cuico) -> void:
	busqueda = maxi(busqueda, 1)
	_sin_verte = 0.0
	for c: Cuico in _fuera:
		if c != quien and c.vivo() and c.global_position.distance_to(quien.global_position) <= LLAMA:
			c.alertar(_jugador.global_position)


func tumbado(_quien: Cuico) -> void:
	busqueda += 1
	_sin_verte = 0.0
	for n in REFUERZOS:
		if _vivos() >= MAXIMO or not hay_cuicos():
			return
		_sacar(REFUERZO_ANILLO, true)


func guardar(c: Cuico) -> void:
	_fuera.erase(c)
	c.visible = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	if c.vivo():
		_libres.append(c)
	else:
		c.queue_free()   # tumbado: el siguiente sale nuevo, con su vida y en su grupo


# Ya no te encontro: a la banqueta mas cercana. Sin banqueta cerca se queda quieto hasta que lo quiten
func volver_a_patrullar(c: Cuico) -> void:
	var mejor: Array = []
	var cerca := REGRESO_BUSCA
	var p := Vector2(c.global_position.x, c.global_position.z)
	for clave in [_celda(p)] + _vecinas(_celda(p)):
		for opcion: Array in _celdas.get(clave, []):
			var punto: Vector2 = _lineas[opcion[0]][opcion[1]]
			if p.distance_to(punto) < cerca:
				cerca = p.distance_to(punto)
				mejor = opcion
	if mejor.is_empty():
		guardar(c)
		return
	c.linea = _lineas[mejor[0]]
	c.i = mejor[1]
	c.sentido = 1 if c.i + 1 < c.linea.size() else -1
	c.avance = 0.0
	c.set_meta("regresa", true)
	c.a_patrullar()


# Adentro de una fortaleza: ahi no entra la policia
func adentro(punto: Vector3) -> bool:
	return FortalezasMapa.adentro(get_tree(), punto)


# --- Patrulla: avanza `paso` m por su banqueta (como Gente._caminar, de uno en uno) ---

func patrullar(c: Cuico, paso: float) -> void:
	# Recien salido de buscarte: primero camina al vertice de su banqueta
	if c.has_meta("regresa"):
		var meta: Vector2 = c.linea[c.i]
		var hacia := Vector2(meta.x - c.global_position.x, meta.y - c.global_position.z)
		if hacia.length() <= paso:
			c.remove_meta("regresa")
			var y := _altura(meta)
			c.global_position = Vector3(meta.x, c.global_position.y if y == INF else y, meta.y)
		else:
			hacia = hacia.normalized() * paso
			c.global_position += Vector3(hacia.x, 0.0, hacia.y)
			c.rotation.y = atan2(-hacia.x, -hacia.y)
		return
	var linea: Array = c.linea
	var siguiente := c.i + c.sentido
	if siguiente < 0 or siguiente >= linea.size():
		_fin_de_linea(c)
		return
	var a: Vector2 = linea[c.i]
	var b: Vector2 = linea[siguiente]
	var largo := a.distance_to(b)
	c.avance += paso
	if c.avance >= largo:
		var y := _altura(b)
		if y == INF:
			c.sentido = -c.sentido
			c.avance = 0.0
			return
		c.i = siguiente
		c.avance -= largo
		c.global_position.y = y
		return
	var p := a.lerp(b, c.avance / maxf(largo, 0.01))
	var prueba: float = c.get_meta("prueba", 0.0) - paso
	if prueba <= 0.0:
		prueba = PRUEBA_CADA
		if _altura(p + (b - a).normalized() * PRUEBA_ADELANTE) == INF:
			c.sentido = -c.sentido
			c.i = siguiente
			c.avance = largo - c.avance
	c.set_meta("prueba", prueba)
	c.global_position = Vector3(p.x, c.global_position.y, p.y)
	c.rotation.y = atan2(-(b.x - a.x), -(b.y - a.y))


func _fin_de_linea(c: Cuico) -> void:
	var fin: Vector2 = c.linea[c.i]
	var mejor: Array = []
	var cerca := UNE_A
	for clave in [_celda(fin)] + _vecinas(_celda(fin)):
		for otro: Array in _finales.get(clave, []):
			var punto: Vector2 = _lineas[otro[0]][otro[1]]
			var d := fin.distance_to(punto)
			if _lineas[otro[0]] != c.linea and d < cerca and _altura(punto) != INF:
				cerca = d
				mejor = otro
	if mejor.is_empty():
		c.sentido = -c.sentido
		c.avance = 0.0
		return
	c.linea = _lineas[mejor[0]]
	c.i = mejor[1]
	c.sentido = 1 if mejor[1] == 0 else -1
	c.avance = 0.0


# --- Reserva ---

func _armar_reserva() -> void:
	if _libres.size() + _fuera.size() < MAXIMO and CargaCuadro.hay():
		var inicio := Time.get_ticks_usec()
		var c := Cuico.new()
		c.name = "Cuico"
		c.cuicos = self
		c.armar(MODELOS.pick_random())
		c.visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(c)
		_libres.append(c)
		CargaCuadro.gastar(inicio)


# Uno de la reserva en una banqueta del anillo, fuera de la camara. `avisado`: refuerzo que ya
# viene por ti
func _sacar(anillo: Vector2, avisado: bool) -> void:
	if _libres.is_empty() or adentro(_jugador.global_position) and not avisado:
		return
	var camara := get_viewport().get_camera_3d()
	var centro := _jugador.global_position
	for intento in INTENTOS:
		var giro := randf() * TAU
		var radio := randf_range(anillo.x, anillo.y)
		var punto := centro + Vector3(cos(giro) * radio, 0.0, sin(giro) * radio)
		var opciones: Array = _celdas.get(_celda(Vector2(punto.x, punto.z)), [])
		if opciones.is_empty():
			continue
		var opcion: Array = opciones.pick_random()
		var linea: Array = _lineas[opcion[0]]
		var donde: Vector2 = linea[opcion[1]]
		var en_mundo := Vector3(donde.x, 1.0, donde.y)
		if centro.distance_to(en_mundo) < anillo.x or adentro(en_mundo):
			continue
		if camara and not camara.is_position_behind(en_mundo) and camara.is_position_in_frustum(en_mundo):
			continue
		var y := _altura(donde)
		if y == INF:
			continue
		var c: Cuico = _libres.pop_back()
		c.linea = linea
		c.i = opcion[1]
		c.sentido = 1 if randf() < 0.5 or c.i == 0 else -1
		if c.i + c.sentido >= linea.size():
			c.sentido = -1
		c.avance = 0.0
		c.visible = true
		c.process_mode = Node.PROCESS_MODE_INHERIT
		c.poner_en(Vector3(donde.x, y, donde.y))
		_fuera.append(c)
		if avisado:
			c.alertar(centro)
		return


func _patrullando() -> int:
	return _fuera.filter(func(c: Cuico) -> bool: return not c.activo() and c.vivo()).size()


func _vivos() -> int:
	return _fuera.filter(func(c: Cuico) -> bool: return c.vivo()).size()


func _quitar_a_todos() -> void:
	_saliendo = true
	busqueda = 0
	for c: Cuico in _fuera.duplicate():
		guardar(c)


# --- Datos (como Gente) ---

func _cargar_banquetas() -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(banquetas_path))
	if not datos is Dictionary:
		push_warning("Cuicos: no se pudo leer %s" % banquetas_path)
		return
	for plana: Array in datos["banquetas"]:
		var linea: Array = []
		for p: Array in plana:
			linea.append(Vector2(p[0], p[1]))
		var indice := _lineas.size()
		_lineas.append(linea)
		for i in linea.size():
			var clave := _celda(linea[i])
			if not _celdas.has(clave):
				_celdas[clave] = []
			_celdas[clave].append([indice, i])
		for i in [0, linea.size() - 1]:
			var clave := _celda(linea[i])
			if not _finales.has(clave):
				_finales[clave] = []
			_finales[clave].append([indice, i])


func _altura(punto: Vector2) -> float:
	_rayo.from = Vector3(punto.x, 12.0, punto.y)
	_rayo.to = Vector3(punto.x, -2.0, punto.y)
	var pego := get_world_3d().direct_space_state.intersect_ray(_rayo)
	if pego.is_empty() or pego.position.y > ALTO_LIBRE:
		return INF
	return pego.position.y


func _celda(punto: Vector2) -> Vector2i:
	return Vector2i(floori(punto.x / CELDA), floori(punto.y / CELDA))


func _vecinas(celda: Vector2i) -> Array:
	var todas := []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:
				todas.append(celda + Vector2i(x, y))
	return todas
