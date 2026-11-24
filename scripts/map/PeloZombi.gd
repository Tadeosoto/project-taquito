class_name PeloZombi
extends MeshInstance3D
# El pelo largo ralo de las zombis (ZombiSerenol, JJ 2026-11-17): mechones delgados de una a tres
# hebras que cuelgan del casco con manchones pelones, como si hubiera tenido el pelo largo. Cada hebra
# es una cadena verlet (gravedad, largo fijo, choca con la cabeza) dibujada como tira plana hacia la
# camara. Vive en coordenadas del mundo (top_level) y sigue al hueso Head.
# Cuesta: solo se mueve a la vista y a menos de SIMULA_HASTA de la camara, a PASO_SEG; mas lejos de
# VE_HASTA ni se dibuja (de lejos no se distingue). Sin cabeza (tiro a la cabeza) se esconde.

const PUNTOS := 9
const MECHONES := 40           # puntos del casco de donde salen (cada uno con 1 a 3 hebras)
const LARGO := Vector2(0.3, 0.75)   # m
const ANCHO := Vector2(0.003, 0.008) # m
const AMORTIGUA := 0.96
const GRAVEDAD := 9.8
const PASO_SEG := 1.0 / 30.0
const ASENTAR := 60            # pasos al aparecer o al brincar lejos
const BRINCO := 1.0            # m: si la cabeza se movio mas que esto de un paso a otro, se reacomoda
const SIMULA_HASTA := 30.0     # m a la camara
const VE_HASTA := 45.0
const COLOR := Color(0.05, 0.045, 0.045)

# Lo que comparten todas (la misma malla): el casco en el espacio del esqueleto, y el centro y radio
# de la cabeza en el del hueso Head
static var _casco: PackedVector3Array
static var _centro_local := Vector3.ZERO
static var _radio := 0.1       # en unidades del esqueleto
static var _alto_cabeza := 0.1
static var _material: StandardMaterial3D

var _sk: Skeleton3D
var _cabeza := -1
var _anclas: Array[Vector3] = []      # en el espacio del hueso Head (reposo)
var _largos := PackedFloat32Array()
var _anchos := PackedFloat32Array()
var _p: Array[PackedVector3Array] = []
var _antes: Array[PackedVector3Array] = []
var _malla := ImmediateMesh.new()
var _reloj := 0.0
var _ultima := Vector3.INF
var _asentado := false


func armar(sk: Skeleton3D) -> void:
	_sk = sk
	_cabeza = sk.find_bone("Head")
	if _cabeza < 0:
		queue_free()
		return
	if _casco.is_empty():
		_medir_casco()
	var cab_rest := sk.get_bone_global_rest(_cabeza)
	var inversa := cab_rest.affine_inverse()
	var centro := cab_rest * _centro_local
	# Mechones ralos: puntos entre vertices vecinos del casco, menos en los manchones pelones (cada
	# zombi los tiene en otro lado)
	var giro := Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var intentos := 0
	var puestos := 0
	while puestos < MECHONES and intentos < 3000:
		intentos += 1
		var a := _casco[randi() % _casco.size()]
		var b := _casco[randi() % _casco.size()]
		if a.distance_to(b) > _alto_cabeza * 0.35:
			continue
		var p := a.lerp(b, randf())
		var d := (p - centro).normalized()
		if sin(d.x * 5.0 + giro.x) * sin(d.z * 4.0 + giro.y) + sin(d.y * 7.0 + giro.z) < -0.2:
			continue
		puestos += 1
		var largo := randf_range(LARGO.x, LARGO.y)
		for h in randi_range(1, 3):
			var lado := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _alto_cabeza * 0.04
			_anclas.append(inversa * (p + lado))
			_largos.append(largo * randf_range(0.75, 1.1))
			_anchos.append(randf_range(ANCHO.x, ANCHO.y))
	for i in _anclas.size():
		var pts := PackedVector3Array()
		pts.resize(PUNTOS)
		_p.append(pts)
		_antes.append(pts.duplicate())
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = COLOR
		_material.roughness = 0.55
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
	material_override = _material
	mesh = _malla
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	transform = Transform3D.IDENTITY   # top_level: el local es el del mundo (aun fuera del arbol)


# El casco: los vertices de arriba de la cabeza, menos la frente y la cara (mira a +Z)
func _medir_casco() -> void:
	var piel := _sk.get_parent().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var rep := ZombiSerenol.reposo(piel, _sk)
	var cab_rest := _sk.get_bone_global_rest(_cabeza)
	var alto := -INF
	for r in rep:
		alto = maxf(alto, r.y)
	var hh := alto - cab_rest.origin.y
	var suma := Vector3.ZERO
	var n := 0
	var casco := PackedVector3Array()
	for r in rep:
		var d := r - cab_rest.origin
		if d.y > 0.0 and absf(d.x) < hh and absf(d.z) < hh:
			suma += r
			n += 1
		if d.y > hh * 0.45 and not (d.z > hh * 0.2 and d.y < hh * 0.85):
			casco.append(r)
	var centro := suma / maxf(n, 1)
	var rmax := 0.0
	for r in casco:
		rmax = maxf(rmax, r.distance_to(centro))
	_casco = casco
	_centro_local = cab_rest.affine_inverse() * centro
	_radio = rmax * 0.95
	_alto_cabeza = hh


func _cabeza_global() -> Transform3D:
	return _sk.global_transform * _sk.get_bone_global_pose(_cabeza)


func _process(delta: float) -> void:
	if _sk == null or not _sk.is_visible_in_tree():
		_asentado = false
		return
	var t := _cabeza_global()
	# Sin cabeza (Zombie._escalar_hueso a casi 0) no hay de donde cuelgue
	if t.basis.get_scale().x < 0.01 * _sk.global_transform.basis.get_scale().x:
		visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lejos := cam.global_position.distance_to(t.origin)
	visible = lejos < VE_HASTA
	if lejos > SIMULA_HASTA:
		_asentado = false
		return
	if not _asentado or _ultima.distance_to(t.origin) > BRINCO:
		_reiniciar(t)
		for i in ASENTAR:
			_paso(t, PASO_SEG)
		_asentado = true
	_reloj += delta
	if _reloj < PASO_SEG:
		return
	_reloj = 0.0
	_paso(t, PASO_SEG)
	_dibujar(cam)


func _reiniciar(t: Transform3D) -> void:
	for i in _anclas.size():
		var a := t * _anclas[i]
		for k in PUNTOS:
			_p[i][k] = a + Vector3.DOWN * _largos[i] * k / (PUNTOS - 1)
		_antes[i] = _p[i].duplicate()


func _paso(t: Transform3D, dt: float) -> void:
	_ultima = t.origin
	var centro := t * _centro_local
	var radio := _radio * _sk.global_transform.basis.get_scale().x
	var caida := Vector3.DOWN * GRAVEDAD * dt * dt
	for i in _anclas.size():
		var p := _p[i]
		var q := _antes[i]
		var seg := _largos[i] / (PUNTOS - 1)
		p[0] = t * _anclas[i]
		for k in range(1, PUNTOS):
			var v := (p[k] - q[k]) * AMORTIGUA
			q[k] = p[k]
			p[k] += v + caida
		for it in 2:
			for k in range(1, PUNTOS):
				var d := p[k] - p[k - 1]
				var l := d.length()
				if l > 0.0001:
					p[k] = p[k - 1] + d / l * seg
				var e := p[k] - centro
				if e.length_squared() < radio * radio:
					p[k] = centro + e.normalized() * radio
		_p[i] = p
		_antes[i] = q


func _dibujar(cam: Camera3D) -> void:
	_malla.clear_surfaces()
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var ojo := cam.global_position
	for i in _anclas.size():
		var p := _p[i]
		var tono := 0.6 + 0.8 * float(i % 5) / 4.0
		var col := Color(tono, tono, tono)
		for k in range(PUNTOS - 1):
			var a := p[k]
			var b := p[k + 1]
			var lado := (b - a).cross(ojo - a).normalized()
			var wa := _anchos[i] * (1.0 - float(k) / PUNTOS * 0.8)
			var wb := _anchos[i] * (1.0 - float(k + 1) / PUNTOS * 0.8)
			for v in [a - lado * wa, a + lado * wa, b + lado * wb, a - lado * wa, b + lado * wb, b - lado * wb]:
				_malla.surface_set_color(col)
				_malla.surface_add_vertex(v)
	_malla.surface_end()
