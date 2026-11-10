extends Node3D
# Un arete de pompones de La Mojiganga (Catrina.gd, fase 2): se le revienta del lobulo y sale
# rodando por el piso hacia ti como bola de boliche. Brincalo, hazte a un lado o ruedate; contra
# una pared o un carro alegorico se deshace.

const RADIO := 0.45
const VELOCIDAD := 9.0
const DANO := 12
const DURA := 4.0
const ALCANZA := 0.8           # m del centro al jugador
const SALTADO := 0.7           # m: con los pies mas arriba del piso que esto, lo brincaste
const PIES := 1.0              # m del origen del jugador a sus pies (media capsula)

var jugador: Node3D
var catrina: Node
var rumbo := Vector3.FORWARD
var _t := 0.0
var _bola: Node3D
var _pego := false


const RUTA_MODELO := "res://models/personajes/catrina/pompon.glb"


func _ready() -> void:
	# El pompon de Blender (catrina_props.py) si existe; si no, una esfera de color
	if ResourceLoader.exists(RUTA_MODELO):
		_bola = Node3D.new()
		_bola.add_child(load(RUTA_MODELO).instantiate())
		_bola.position.y = RADIO
		add_child(_bola)
		return
	var esfera := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIO
	sm.height = RADIO * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.95, 0.2, 0.5), Color(1.0, 0.45, 0.1), Color(0.3, 0.75, 0.4)].pick_random()
	sm.material = m
	esfera.mesh = sm
	esfera.position.y = RADIO
	_bola = esfera
	add_child(_bola)


func _physics_process(delta: float) -> void:
	_t += delta
	var paso := rumbo * VELOCIDAD * delta
	var espacio := get_world_3d().direct_space_state
	var excluir: Array[RID] = []
	if jugador is CollisionObject3D:
		excluir.append((jugador as CollisionObject3D).get_rid())
	var rayo := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * RADIO, global_position + Vector3.UP * RADIO + rumbo * (RADIO + paso.length()), 1, excluir)
	if not espacio.intersect_ray(rayo).is_empty() or _t >= DURA:
		_deshacer()
		return
	global_position += paso
	_bola.rotate(rumbo.cross(Vector3.UP).normalized(), -paso.length() / RADIO)
	if _pego or jugador == null:
		return
	var al := jugador.global_position - global_position
	var alto := al.y
	al.y = 0.0
	if al.length() < ALCANZA and alto - PIES < SALTADO and not jugador.esquivando():
		_pego = true
		jugador.recibir_dano(DANO, global_position, 1.5, catrina)
		_deshacer()


func _deshacer() -> void:
	var liquido := get_tree().get_first_node_in_group("liquido")
	if liquido:
		liquido.reventar(global_position + Vector3.UP * RADIO, RADIO, global_position.y, 10, Color(0.95, 0.4, 0.6), Vector2(2.0, 4.0))
	Sonidos.tocar(self, "golpe", -6.0, 1.4)
	queue_free()
