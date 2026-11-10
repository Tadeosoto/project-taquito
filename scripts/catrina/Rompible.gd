extends Node3D
class_name Rompible
# Un carro alegorico o una ofrenda de la plaza que La Mojiganga revienta al pasar (AG: se atoraba
# en un carro y la mataba a balazos desde atras). Lo arma PruebaCatrina sobre la caja de choque
# (StaticBody3D) y las mallas: la entera, la reventada (Carro_0_Roto de plaza.py, o la entera
# aplastada si no hay) y la luz de sus velas. Catrina.gd lo encuentra por la meta "rompible" del
# cuerpo con que choca, o en el grupo "rompible" para el pisoton y la barrida.

const PEDAZOS := 10
const PEDAZO_DURA := 5.0       # s en el piso antes de hundirse
const PEDAZO_SE_VA := 1.5

var roto := false
var cuerpo: StaticBody3D
var entera: Node3D
var reventada: Node3D
var luz: OmniLight3D
var adornos: Array[Node3D] = []     # flamas de pixelfx de sus velas o su fuego: se apagan al romperse
var _medida := Vector3(3.0, 2.0, 3.0)
var _centro := Vector3.ZERO
var _material: Material
var _pedazos: Array[RigidBody3D] = []


static func armar(padre: Node, cuerpo_: StaticBody3D, entera_: Node3D, reventada_: Node3D, luz_: OmniLight3D = null) -> Rompible:
	var r := Rompible.new()
	r.cuerpo = cuerpo_
	r.entera = entera_
	r.reventada = reventada_
	r.luz = luz_
	padre.add_child(r)
	r.add_to_group("rompible")
	cuerpo_.set_meta("rompible", r)
	# El tamano y el centro, de su caja de choque
	for forma in cuerpo_.find_children("*", "CollisionShape3D", true, false):
		var cs := forma as CollisionShape3D
		if cs.shape is BoxShape3D:
			r._medida = (cs.shape as BoxShape3D).size
			r._centro = cs.global_position
		elif cs.shape:
			var aabb := cs.shape.get_debug_mesh().get_aabb()
			r._medida = aabb.size
			r._centro = cs.global_transform * aabb.get_center()
	r.global_position = r._centro
	if reventada_:
		reventada_.visible = false
	r._material = r._buscar_material(entera_)
	return r


func _buscar_material(nodo: Node) -> Material:
	if nodo == null:
		return null
	for m in nodo.find_children("*", "MeshInstance3D", true, false) + ([nodo] if nodo is MeshInstance3D else []):
		var mi := m as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat := mi.get_active_material(0)
			if mat:
				return mat
	return null


# Distancia en el piso de un punto a la orilla de su caja
func distancia(punto: Vector3) -> float:
	var d := punto - _centro
	var fuera := Vector2(maxf(absf(d.x) - _medida.x * 0.5, 0.0), maxf(absf(d.z) - _medida.z * 0.5, 0.0))
	return fuera.length()


func romper(desde: Vector3) -> void:
	if roto:
		return
	roto = true
	for forma in cuerpo.find_children("*", "CollisionShape3D", true, false):
		(forma as CollisionShape3D).set_deferred("disabled", true)
	if reventada:
		entera.visible = false
		reventada.visible = true
	elif entera:
		# Sin malla reventada: la entera aplastada y chueca
		entera.set_meta("escala", entera.scale)
		entera.scale = Vector3(1.15, 0.25, 1.15)
		entera.rotation.z = randf_range(-0.1, 0.1)
	if luz:
		luz.visible = false
	for a in adornos:
		if is_instance_valid(a):
			a.visible = false
	var hacia := _centro - desde
	hacia.y = 0.0
	hacia = hacia.normalized() if hacia.length_squared() > 0.01 else Vector3.FORWARD
	_tirar_pedazos(hacia)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		efectos.lanzar("catrina_rompe", Vector3(_centro.x, _centro.y - _medida.y * 0.5, _centro.z), Vector3.ZERO, 1.0)
	Sonidos.tocar(self, "carton", 4.0, 0.7)
	Sonidos.tocar(self, "pisoton", 0.0, 1.2)


# Tablas y carton volando, empujados para el lado contrario de ella
func _tirar_pedazos(hacia: Vector3) -> void:
	for i in PEDAZOS:
		var p := RigidBody3D.new()
		p.collision_layer = 0
		p.collision_mask = 1
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		var tam := Vector3(randf_range(0.2, 0.9), randf_range(0.05, 0.25), randf_range(0.2, 0.7))
		caja.size = tam
		forma.shape = caja
		p.add_child(forma)
		var malla := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = tam
		if _material:
			bm.material = _material
		malla.mesh = bm
		p.add_child(malla)
		get_parent().add_child(p)
		p.global_position = _centro + Vector3(randf_range(-0.4, 0.4) * _medida.x, randf_range(0.0, 0.4) * _medida.y, randf_range(-0.4, 0.4) * _medida.z)
		p.linear_velocity = (hacia * randf_range(2.0, 6.0) + Vector3(randf_range(-2, 2), randf_range(3.0, 7.0), randf_range(-2, 2)))
		p.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_pedazos.append(p)
		var tween := p.create_tween()
		tween.tween_interval(PEDAZO_DURA)
		tween.tween_callback(func() -> void: p.freeze = true)
		tween.tween_property(p, "scale", Vector3.ONE * 0.01, PEDAZO_SE_VA)
		tween.tween_callback(p.queue_free)


func restaurar() -> void:
	roto = false
	for forma in cuerpo.find_children("*", "CollisionShape3D", true, false):
		(forma as CollisionShape3D).set_deferred("disabled", false)
	if entera:
		entera.visible = true
		if entera.has_meta("escala"):
			entera.scale = entera.get_meta("escala")
			entera.rotation.z = 0.0
	if reventada:
		reventada.visible = false
	if luz:
		luz.visible = true
	for a in adornos:
		if is_instance_valid(a):
			a.visible = true
	for p in _pedazos:
		if is_instance_valid(p):
			p.queue_free()
	_pedazos.clear()
