class_name AmbienteZona
extends Node3D

# Un ambiente que suena en un lugar del mapa (el tianguis, la cancha): un loop 3D que se oye
# desde `radio` m y baja con la distancia. Con `solo_dia` calla de noche, igual que los
# chamacos de NinosCancha (que no estan despues de NOCHE_DESDE)

var sonido := ""
var radio := 40.0
var volumen_db := -6.0
var solo_dia := false

var _voz: AudioStreamPlayer3D
var _ciclo: Node
var _revisa := 0.0


func _ready() -> void:
	var stream := Sonidos.sonido(sonido)
	if stream == null:
		set_process(false)
		return
	_voz = AudioStreamPlayer3D.new()
	_voz.stream = stream
	_voz.max_distance = radio * 2.0
	_voz.unit_size = radio * 0.35
	_voz.volume_db = volumen_db
	add_child(_voz)
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if not solo_dia or _ciclo == null or float(_ciclo.valor()) < NinosCancha.NOCHE_DESDE:
		_voz.play(randf() * stream.get_length())   # que dos zonas iguales no suenen sincronizadas


func _process(delta: float) -> void:
	_revisa -= delta
	if _revisa > 0.0 or not solo_dia or _ciclo == null:
		return
	_revisa = 1.0
	var de_dia := float(_ciclo.valor()) < NinosCancha.NOCHE_DESDE
	if de_dia and not _voz.playing:
		_voz.play()
	elif not de_dia and _voz.playing:
		_voz.stop()
