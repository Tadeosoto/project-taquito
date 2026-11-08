extends Node3D

# La losa que avienta el Panzon (Panzon.gd): sale de sus manos, vuela en arco a donde vas a
# estar con su sombra en el piso donde va a caer, y al caer (o al chocar con algo) revienta:
# 25 al jugador, 30 al tinaco de la defensa, y tumba las piezas de la barricada que alcanza
# (Barricada.romper_cerca). No nombra autoloads.

const ROCA := preload("res://models/personajes/panzon/roca.glb")
const GRAVEDAD := 22.0
const VELOCIDAD := 16.0        # m/s de lado
const TIEMPO := Vector2(0.6, 1.5)
const RADIO := 1.6             # m de la explosion
const DANO_JUGADOR := 25
const DANO_TINACO := 30
const GIRO := Vector3(3.0, 1.2, 2.0)   # rad/s
const VIDA_MAX := 4.0          # s: si nunca cae, revienta
const SOMBRA_COLOR := Color(0.0, 0.0, 0.0, 0.45)

var _velocidad := Vector3.ZERO
var _t := 0.0
var _de: Node = null
var _sombra: MeshInstance3D
var _destino := Vector3.ZERO
var _lista := false


func lanzar(desde: Transform3D, adonde: Vector3, de: Node) -> void:
	_de = de
	var modelo := ROCA.instantiate()
	add_child(modelo)
	global_transform = desde
	_destino = adonde
	var lado := adonde - desde.origin
	var alto := lado.y
	lado.y = 0.0
	var tiempo := clampf(lado.length() / VELOCIDAD, TIEMPO.x, TIEMPO.y)
	_velocidad = lado / tiempo
	_velocidad.y = (alto + 0.5 * GRAVEDAD * tiempo * tiempo) / tiempo
	# La sombra donde va a caer: un disco oscuro que crece mientras se acerca
	_sombra = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.7
	disco.bottom_radius = 0.7
	disco.height = 0.02
	disco.radial_segments = 12
	_sombra.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = SOMBRA_COLOR
	_sombra.material_override = mat
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_sombra)
	_sombra.global_position = adonde + Vector3.UP * 0.05
	_sombra.scale = Vector3.ONE * 0.3
	_lista = true


func _physics_process(delta: float) -> void:
	if not _lista:
		return
	_t += delta
	var antes := global_position
	_velocidad.y -= GRAVEDAD * delta
	var despues := antes + _velocidad * delta
	rotation += GIRO * delta
	if _sombra:
		_sombra.scale = Vector3.ONE * clampf(0.3 + _t, 0.3, 1.2)
	# Choca con lo que se atraviese (paredes, barricada, el piso)
	var excluir: Array[RID] = []
	if _de and _de is CollisionObject3D:
		excluir.append(_de.get_rid())
	var rayo := PhysicsRayQueryParameters3D.create(antes, despues, 1, excluir)
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	if pego:
		_reventar(pego.position)
		return
	global_position = despues
	if _t > 0.2 and global_position.y <= _destino.y + 0.2:
		_reventar(global_position)
		return
	if _t > VIDA_MAX:
		_reventar(global_position)


func _reventar(donde: Vector3) -> void:
	_lista = false
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador and jugador.global_position.distance_to(donde) < RADIO and not jugador.esquivando():
		jugador.recibir_dano(DANO_JUGADOR, donde, 1.5, _de)
	var tinaco := get_tree().get_first_node_in_group("tinaco_defensa") as Node3D
	if tinaco:
		var r = tinaco.get("radio")
		var radio: float = r if r != null else 1.2
		var plano := Vector2(tinaco.global_position.x - donde.x, tinaco.global_position.z - donde.z)
		if plano.length() < radio + RADIO:
			tinaco.recibir_golpe(DANO_TINACO)
	var barricada := get_tree().get_first_node_in_group("barricada")
	if barricada and barricada.has_method("romper_cerca"):
		barricada.romper_cerca(donde, RADIO)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("tablas", donde + Vector3.UP * 0.3, Vector3.ZERO, 1.6)
		efectos.lanzar("pisada", donde, Vector3.ZERO, 1.4)
	# En el padre: la losa se borra aqui mismo y se llevaria el sonido
	Sonidos.tocar(get_parent(), "golpe", 2.0, 0.5)
	if jugador and jugador.global_position.distance_to(donde) < 15.0:
		jugador.set("_sacude_fuerza", 0.6)
		jugador.set("_sacude_hasta", Time.get_ticks_msec() + 300)
	if _sombra:
		_sombra.queue_free()
	queue_free()
