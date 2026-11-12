class_name Campana
extends Node3D

# Una campana que suena sola (marca "campana" de Colonia.gd). `de`:
#   "templo"   la de la parroquia de Santa Mugre: repica al amanecer y cuando Ciclo avisa que va a
#              oscurecer (aviso_atardecer): es la senal de que hay que guardarse
#   "escuela"  la del recreo y la de la salida de la primaria, a media manana y a mediodia
# El sonido se arma en Sonidos ("campana", "campana_escuela") y sale de aqui (3D): de lejos se
# oye bajito y se sabe de donde viene.

const HORAS_ESCUELA := [10.5, 13.0]     # horas del reloj del juego (Ciclo.hora())
const TOQUES := {"templo": 7, "escuela": 4}
const ENTRE := {"templo": 1.35, "escuela": 0.5}      # s entre toques
const SONIDO := {"templo": "campana", "escuela": "campana_escuela"}
const ALCANCE := {"templo": 140.0, "escuela": 70.0}  # m

var de := "templo"

var _voz: AudioStreamPlayer3D
var _ciclo: Node
var _faltan := 0
var _espera := 0.0
var _hora_antes := -1.0


func _ready() -> void:
	if not TOQUES.has(de):
		de = "templo"
	_voz = AudioStreamPlayer3D.new()
	_voz.stream = Sonidos.sonido(SONIDO[de])
	_voz.max_distance = ALCANCE[de]
	_voz.unit_size = 22.0 if de == "templo" else 9.0
	_voz.max_polyphony = 3
	add_child(_voz)
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo and de == "templo":
		_ciclo.amanecio.connect(repicar)
		_ciclo.aviso_atardecer.connect(repicar)


func repicar() -> void:
	_faltan = TOQUES[de]
	_espera = 0.0


func _process(delta: float) -> void:
	if de == "escuela" and _ciclo:
		var hora := float(_ciclo.hora())
		if _hora_antes >= 0.0:
			for h: float in HORAS_ESCUELA:
				if _hora_antes < h and hora >= h:
					repicar()
		_hora_antes = hora
	if _faltan <= 0:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = ENTRE[de]
	_faltan -= 1
	if _voz.stream:
		_voz.pitch_scale = 1.0 if de == "escuela" else randf_range(0.985, 1.015)
		_voz.play()
