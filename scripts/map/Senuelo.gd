class_name Senuelo
extends Node3D

# La bocina tirada sonando (JJ, la "monkey bomb"): la deja el Arrojadizo BOCINA/BOCINA_AGUA al caer.
# Mientras suena (DURA s) toca musica saturada (Sonidos bocina_musica, en bucle, desde aqui),
# suelta ondas (Bocina.ondas: aros blancos en el piso y el aire que tiembla), vibra al ritmo y
# jala a los zombis que tiene a `radio`: los despierta (Zombie.ruido, cada AVISA_CADA s, para los
# que van llegando) y Zombie._destino los manda aqui antes que a ti o al tinaco; al llegar la
# rasguñan (recibir_golpe no le hace nada). Luego se apaga (bocina_apaga), se encoge y desaparece.
# La sola (Bocina) apenas jala de cerca (RADIO_SOLA); la encintada con agua (BocinaEncintada),
# de lejos (RADIO_AGUA). Al jefe no lo jala.

const RADIO_SOLA := 6.0       # m: la bocina sola casi no sirve (JJ)
const RADIO_AGUA := 22.0      # m: con la botella de agua ya vale la pena
const DURA_SOLA := 6.0        # s sonando
const DURA_AGUA := 10.0
const AVISA_CADA := 1.0       # s entre llamadas a Zombie.ruido
const PULSO := 2.0            # golpes por segundo de la musica (120 bpm), como las ondas
const VIBRA := 0.12           # cuanto crece la bocina en cada golpe
const ONDAS_AGUA := 1.8       # los aros del piso de la encintada, mas grandes
const VOLUMEN := 4.0          # dB de la musica
const SE_VA := 0.35           # s que tarda en encogerse al apagarse

static var activos: Array[Senuelo] = []

var radio := RADIO_SOLA
var dura := DURA_SOLA
var _modelo: Node3D
var _ondas: Node3D
var _voz: AudioStreamPlayer3D
var _edad := 0.0
var _avisa := 0.0
var _apagada := false


# Una bocina sonando en `donde` (el piso), sola o encintada con agua
static func crear(padre: Node, donde: Vector3, con_agua: bool) -> Senuelo:
	var s := Senuelo.new()
	s.radio = RADIO_AGUA if con_agua else RADIO_SOLA
	s.dura = DURA_AGUA if con_agua else DURA_SOLA
	s._modelo = BocinaEncintada.new() if con_agua else Bocina.new()
	padre.add_child(s)
	s.global_position = donde
	s.rotation.y = randf() * TAU
	return s


# El zombi en `desde` que la oye: la bocina sonando mas cercana que lo tenga a su radio; null
static func la_que_oye(desde: Vector3) -> Senuelo:
	var mejor: Senuelo = null
	var cerca := INF
	for s in activos:
		if not is_instance_valid(s) or s._apagada:
			continue
		var d := desde.distance_to(s.global_position)
		if d <= s.radio and d < cerca:
			cerca = d
			mejor = s
	return mejor


func _ready() -> void:
	add_to_group("senuelos")
	activos.append(self)
	_modelo.position.y = Bocina.RADIO * 1.06
	add_child(_modelo)
	_ondas = Bocina.ondas(randf() * 10.0)
	if radio > RADIO_SOLA:
		_ondas.get_child(0).scale = Vector3.ONE * ONDAS_AGUA
	add_child(_ondas)
	_voz = AudioStreamPlayer3D.new()
	_voz.stream = Sonidos.sonido("bocina_musica")
	_voz.volume_db = VOLUMEN
	_voz.unit_size = 4.0
	_voz.max_distance = radio * 2.0
	add_child(_voz)
	_voz.play()


func _exit_tree() -> void:
	activos.erase(self)


func _process(delta: float) -> void:
	if _apagada:
		return
	_edad += delta
	# Vibra al ritmo, como los aros
	var golpe := pow(1.0 - fmod(_edad * PULSO, 1.0), 3.0)
	_modelo.scale = Vector3.ONE * (1.0 + golpe * VIBRA)
	_avisa -= delta
	if _avisa <= 0.0:
		_avisa = AVISA_CADA
		Zombie.ruido(global_position, radio)
	if _edad >= dura:
		_apagar()


# Los zombis la rasguñan al llegar (Zombie._atacar): no le pasa nada
func recibir_golpe(_dano: int) -> void:
	pass


func _apagar() -> void:
	_apagada = true
	activos.erase(self)
	_voz.stop()
	_ondas.queue_free()
	Sonidos.tocar(get_parent(), "bocina_apaga", -4.0)
	var se_va := create_tween()
	se_va.tween_property(_modelo, "scale", Vector3.ONE * 0.01, SE_VA).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	se_va.tween_callback(queue_free)
