class_name AmbienteMundo
extends Node

# El ambiente de fondo del mapa, siguiendo `Ciclo.valor()`. Lo crea Partida.
#  - De dia (S-079): pajaros, calle tranquila y un perro a lo lejos, en loop. Entra con el
#    amanecer y se va con el atardecer.
#  - De noche (S-078): grillos en loop, al reves, y de vez en cuando un sonido que da miedo
#    (`susto_noche`).
#  - Cerca de varios zombis, a cualquier hora, un sonido de vez en cuando para dar misterio
#    (`misterio_zombis`).

const DIA_DB := -14.0
const NOCHE_DB := -15.0
const SILENCIO_DB := -60.0
const SUSTO_DB := -12.0
const SUSTO_CADA := Vector2(45.0, 100.0)   # s entre un susto y otro, de noche
const SUSTO_DESDE := 0.7   # Ciclo.valor() desde el que ya es noche cerrada
const ZOMBIS_DB := -12.0
const YA_SALIERON_DB := -22.0   # bajito
const MISTERIO_DB := -11.0
const MISTERIO_CADA := Vector2(40.0, 90.0)
const MISTERIO_REVISA := 8.0   # s para volver a ver si hay zombis cerca, si no los habia
const MISTERIO_ZOMBIS := 4
const MISTERIO_RADIO := 40.0

var _voz_dia: AudioStreamPlayer
var _voz_noche: AudioStreamPlayer
var _voz_zombis: AudioStreamPlayer   # viento lejano: de noche y con zombis cerca
var _cerca := 0.0   # 0 a 1, suavizado
var _revisa := 0.0
var _objetivo := 0.0
var _salieron := false
var _ciclo: Node
var _jugador: Node3D
var _susto := randf_range(20.0, 50.0)
var _misterio := randf_range(25.0, 50.0)


func _ready() -> void:
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	_voz_dia = _loop("ambiente_dia")
	_voz_noche = _loop("ambiente_noche")
	_voz_zombis = _loop("noche_zombis")
	_ciclo.anochecio.connect(func() -> void:
		if not _salieron:
			_salieron = true
			Sonidos.tocar(self, "ya_salieron", YA_SALIERON_DB))
	_ciclo.amanecio.connect(func() -> void: _salieron = false)
	if _ciclo == null:
		set_process(false)


func _loop(nombre: String) -> AudioStreamPlayer:
	var stream := Sonidos.sonido(nombre)
	if stream == null:
		return null
	var voz := AudioStreamPlayer.new()
	voz.stream = stream
	voz.volume_db = SILENCIO_DB
	add_child(voz)
	voz.play(randf() * stream.get_length())
	return voz


func _process(delta: float) -> void:
	var noche := clampf(float(_ciclo.valor()), 0.0, 1.0)
	_mezclar(_voz_dia, 1.0 - noche, DIA_DB)
	_mezclar(_voz_noche, noche, NOCHE_DB)
	_revisa -= delta
	if _revisa <= 0.0:
		_revisa = 1.0
		_objetivo = 1.0 if _zombis_cerca() >= MISTERIO_ZOMBIS else 0.0
	_cerca = move_toward(_cerca, _objetivo, delta * 0.3)
	_mezclar(_voz_zombis, noche * _cerca, ZOMBIS_DB)
	if noche >= SUSTO_DESDE:
		_susto -= delta
		if _susto <= 0.0:
			_susto = randf_range(SUSTO_CADA.x, SUSTO_CADA.y)
			Sonidos.tocar(self, "susto_noche", SUSTO_DB, randf_range(0.9, 1.1))
	_misterio -= delta
	if _misterio <= 0.0:
		if _zombis_cerca() >= MISTERIO_ZOMBIS:
			_misterio = randf_range(MISTERIO_CADA.x, MISTERIO_CADA.y)
			Sonidos.tocar(self, "misterio_zombis", MISTERIO_DB, randf_range(0.9, 1.1))
		else:
			_misterio = MISTERIO_REVISA


# `peso` de 0 a 1: la voz sube con el cuadrado (como la luz) y se pausa cuando no se oye
func _mezclar(voz: AudioStreamPlayer, peso: float, db: float) -> void:
	if voz == null:
		return
	voz.volume_db = lerpf(SILENCIO_DB, db, peso * peso)
	var callar := peso <= 0.0
	if voz.stream_paused != callar:
		voz.stream_paused = callar


# Cuantos zombis vivos hay a menos de MISTERIO_RADIO m del jugador
func _zombis_cerca() -> int:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			return 0
	var cuantos := 0
	for zombi in get_tree().get_nodes_in_group("zombis"):
		if zombi is Zombie and zombi.estado == Zombie.Estado.MUERTO:
			continue
		if zombi is Node3D and (zombi as Node3D).global_position.distance_squared_to(_jugador.global_position) < MISTERIO_RADIO * MISTERIO_RADIO:
			cuantos += 1
	return cuantos
