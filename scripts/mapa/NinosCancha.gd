class_name NinosCancha
extends Node3D

# Chamacos jugando futbolito en una cancha de la colonia (marca "ninos" de Colonia.gd): civiles
# a ESCALA de los adultos que corren tras una pelota dentro de un rectangulo, solo de dia. La
# pelota va de un punto al azar a otro; el chamaco que la alcanza la patea a otro punto. Sin
# choque ni fisica: es ambiente. De noche se esconden y no piensan (Ciclo.valor()).

const ESCALA := 0.7              # de un adulto (Civiles.ESCALA ya da ~1.8 m)
const CORRE := 3.2               # m/s de un chamaco tras la pelota
const PELOTA_VEL := 6.0          # m/s de la pelota pateada
const PATEA_A := 0.7             # m: a esta distancia la patea
const SEPARA := 1.6              # m: los que no van por ella se quedan a esta distancia, rodeando
const NOCHE_DESDE := 0.4         # Ciclo.valor() desde el que ya no hay nadie
const REVISA_NOCHE := 1.0        # s entre revisiones de la hora

var tam := Vector2(9.0, 16.0)     # ancho (x local) y largo (z local) donde juegan
var cuantos := 6

var _ninos: Array[Node3D] = []
var _animaciones: Array[AnimationPlayer] = []
var _corriendo: Array[bool] = []
var _pelota: MeshInstance3D
var _destino := Vector3.ZERO
var _ciclo: Node
var _revisa := 0.0


func _ready() -> void:
	for i in cuantos:
		var nino := Node3D.new()
		nino.name = "Nino_%d" % i
		nino.scale = Vector3.ONE * ESCALA
		add_child(nino)
		var animacion := Civiles.poner(nino, Civiles.elegir("%s/nino_%d" % [name, i]), "Idle")
		nino.position = _punto()
		_ninos.append(nino)
		_animaciones.append(animacion)
		_corriendo.append(false)
		var correr := animacion.get_animation(Civiles.LIB + "/Jog_Fwd")
		if correr:
			correr.loop_mode = Animation.LOOP_LINEAR
	_pelota = MeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = 0.11
	malla.height = 0.22
	malla.radial_segments = 8
	malla.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.9)
	malla.material = material
	_pelota.mesh = malla
	_pelota.position = Vector3(0.0, 0.11, 0.0)
	add_child(_pelota)
	_destino = _punto()


func _punto() -> Vector3:
	return Vector3(randf_range(-tam.x / 2, tam.x / 2), 0.0, randf_range(-tam.y / 2, tam.y / 2))


func _process(delta: float) -> void:
	_revisa -= delta
	if _revisa <= 0.0:
		_revisa = REVISA_NOCHE
		if _ciclo == null:
			_ciclo = get_tree().get_first_node_in_group("ciclo")
		visible = _ciclo == null or float(_ciclo.valor()) < NOCHE_DESDE
	if not visible:
		return
	# La pelota rueda a su destino
	var piso := Vector3(_pelota.position.x, 0.0, _pelota.position.z)
	piso = piso.move_toward(_destino, PELOTA_VEL * delta)
	_pelota.position = piso + Vector3(0.0, 0.11, 0.0)
	_pelota.rotate_x(delta * 8.0)
	# El mas cercano va por ella; los demas la rodean a SEPARA
	var cerca := 0
	for i in _ninos.size():
		if _ninos[i].position.distance_to(piso) < _ninos[cerca].position.distance_to(piso):
			cerca = i
	for i in _ninos.size():
		var nino := _ninos[i]
		var meta := piso
		if i != cerca:
			meta = piso + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / _ninos.size()) * SEPARA * (2.0 + i % 3)
			meta.x = clampf(meta.x, -tam.x / 2, tam.x / 2)
			meta.z = clampf(meta.z, -tam.y / 2, tam.y / 2)
		var hacia := meta - nino.position
		hacia.y = 0.0
		var corre := hacia.length() > 0.4
		if corre:
			nino.position += hacia.normalized() * minf(CORRE * delta, hacia.length())
			# El civil ve hacia -Z de su padre
			nino.rotation.y = atan2(-hacia.x, -hacia.z)
		elif i != cerca:
			var a_pelota := piso - nino.position
			nino.rotation.y = atan2(-a_pelota.x, -a_pelota.z)
		if corre != _corriendo[i]:
			_corriendo[i] = corre
			_animaciones[i].play(Civiles.LIB + "/" + ("Jog_Fwd" if corre else "Idle"), 0.2)
		if i == cerca and nino.position.distance_to(piso) < PATEA_A and piso.distance_to(_destino) < 0.3:
			_destino = _punto()
