extends Node3D

# Alumbrado publico: postes de luz de resources/map/alumbrado_mapa.json
# (tools/map_import/prepare_osm.py place_alumbrado), por celdas de CELDA m alrededor
# de target_path. Cada celda es un MultiMesh de postes y otro de micas por tipo de
# poste (sencillo, avenida, doble en camellon), un MultiMesh de halos y un StaticBody.
# El deterioro de la zona (Alumbrado.estado) decide postes inclinados o caidos y
# lamparas apagadas o que parpadean. De noche (Alumbrado.noche) las micas y los
# halos brillan, y solo las lamparas prendidas mas cercanas al jugador tienen una
# luz real (un grupo fijo de OmniLight3D sin sombras que se van reasignando). Volando
# en dron no hay luces reales.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const SHADER := preload("res://shaders/ps1_lampara.gdshader")
const HALO_SHADER := preload("res://shaders/ps1_lampara_halo.gdshader")

const CELDA := 64.0
const GRUESO := 0.2
# Altura de la mica bajo la punta del poste (m)
const MICA_BAJO := 0.35
const CONCRETO := Color(0.62, 0.62, 0.6)
const FIERRO := Color(0.34, 0.35, 0.36)

@export_file("*.json") var alumbrado_path := "res://resources/map/alumbrado_mapa.json"
@export var target_path: NodePath
@export var jugador_path: NodePath
@export var load_radius := 300.0
@export var unload_radius := 360.0
@export var poste_end := 300.0
@export var halo_end := 360.0
@export_group("Luces reales")
@export var luces := 16
@export var luz_radio := 60.0
@export var luz_alcance := 22.0
@export var luz_energia := 7.0

var _celdas := {}          # Vector2i -> [poste, ...]
var _nodos := {}           # Vector2i -> Node3D
var _por_crear := []       # celdas que faltan armar, la mas cercana primero
var _lamparas := {}        # Vector2i -> [{pos, color, semilla, umbral, parpadea}]
var _mallas := {}          # "alto/brazo/doble" -> [malla del poste, malla de las micas]
var _material: ShaderMaterial
var _material_mica: ShaderMaterial
var _material_halo: ShaderMaterial
var _halo_mesh: QuadMesh
var _target: Node3D
var _jugador: Node3D
var _timer := 0.0
var _timer_luces := 0.0
var _pool: Array[OmniLight3D] = []
var _asignadas := []       # lampara de cada luz del pool (o null)


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(alumbrado_path)) \
			if FileAccess.file_exists(alumbrado_path) else null
	if not data is Dictionary:
		push_warning("MapAlumbrado: no se pudo leer %s" % alumbrado_path)
		return
	for poste: Dictionary in data["postes"]:
		var key := Vector2i(floori(poste["x"] / CELDA), floori(poste["z"] / CELDA))
		if not _celdas.has(key):
			_celdas[key] = []
		_celdas[key].append(poste)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("wobble_enabled", false)
	_material.set_shader_parameter("affine_enabled", false)
	_material_mica = _material.duplicate()
	_material_mica.set_shader_parameter("modo", 1)
	_material_halo = ShaderMaterial.new()
	_material_halo.shader = HALO_SHADER
	_halo_mesh = QuadMesh.new()
	for i in luces:
		var luz := OmniLight3D.new()
		luz.shadow_enabled = false
		luz.omni_range = luz_alcance
		luz.light_specular = 0.0
		luz.visible = false
		add_child(luz)
		_pool.append(luz)
		_asignadas.append(null)
	_target = get_node_or_null(target_path) as Node3D
	_jugador = get_node_or_null(jugador_path) as Node3D
	_update_nearby()
	_crear_pendientes(true)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	RenderingServer.global_shader_parameter_set("alumbrado_tiempo", t)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_nearby()
	_crear_pendientes()
	_timer_luces -= delta
	if _timer_luces <= 0.0:
		_timer_luces = 0.25
		_asignar_luces()
	for i in _pool.size():
		var lampara = _asignadas[i]
		if lampara == null:
			continue
		var energia: float = luz_energia * Alumbrado.encendida(lampara["umbral"])
		if lampara["parpadea"]:
			energia *= Alumbrado.parpadeo(lampara["semilla"], t)
		_pool[i].light_energy = energia
		_pool[i].visible = energia > 0.01


# Arma celdas encoladas hasta gastar el presupuesto del cuadro (CargaCuadro; todas con `de_una`)
func _crear_pendientes(de_una := false) -> void:
	while not _por_crear.is_empty() and (de_una or CargaCuadro.hay()):
		var inicio := Time.get_ticks_usec()
		var key: Vector2i = _por_crear.pop_front()
		if _nodos.has(key):
			continue
		_crear_celda(key)
		CargaCuadro.gastar(inicio)


func _update_nearby() -> void:
	var p := _target.global_position if _target else Vector3.ZERO
	var nuevas := []
	for key: Vector2i in _celdas:
		var dx := maxf(maxf(key.x * CELDA - p.x, p.x - (key.x + 1) * CELDA), 0.0)
		var dz := maxf(maxf(key.y * CELDA - p.z, p.z - (key.y + 1) * CELDA), 0.0)
		var distance := Vector2(dx, dz).length()
		if distance < load_radius and not _nodos.has(key):
			nuevas.append([distance, key])
		elif distance > unload_radius and _nodos.has(key):
			_nodos[key].queue_free()
			_nodos.erase(key)
			_lamparas.erase(key)
	nuevas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_por_crear = nuevas.map(func(n: Array) -> Vector2i: return n[1])


# Las lamparas prendidas mas cercanas al jugador se quedan con las luces del grupo;
# una lampara que ya tenia luz la conserva (no brinca de luz en luz)
func _asignar_luces() -> void:
	var volando: bool = _target != null and _target.has_method("volando") and _target.volando()
	var cerca := []
	if _jugador and not volando and Alumbrado.noche() > 0.01:
		var p := _jugador.global_position
		for lista: Array in _lamparas.values():
			for lampara: Dictionary in lista:
				var d := p.distance_to(lampara["pos"])
				if d < luz_radio and Alumbrado.encendida(lampara["umbral"]) > 0.0:
					cerca.append([d, lampara])
		cerca.sort_custom(func(a, b): return a[0] < b[0])
	var elegidas := []
	for par: Array in cerca.slice(0, _pool.size()):
		elegidas.append(par[1])
	var libres := []
	for i in _pool.size():
		if _asignadas[i] != null and _asignadas[i] in elegidas:
			elegidas.erase(_asignadas[i])
		else:
			_asignadas[i] = null
			_pool[i].visible = false
			libres.append(i)
	for lampara: Dictionary in elegidas:
		var i: int = libres.pop_front()
		_asignadas[i] = lampara
		_pool[i].global_position = lampara["pos"]
		_pool[i].light_color = lampara["color"]


func _crear_celda(key: Vector2i) -> void:
	var celda := Node3D.new()
	celda.name = "celda_%d_%d" % [key.x, key.y]
	var cuerpo := StaticBody3D.new()
	celda.add_child(cuerpo)
	var por_tipo := {}         # tipo -> [[Transform3D, custom], ...]
	var halos := []            # [Transform3D, color, custom]
	var lamparas := []
	for poste: Dictionary in _celdas[key]:
		var alto: float = poste["alto"]
		var brazo: float = poste["brazo"]
		var doble: bool = poste["doble"]
		var semilla := int(poste["semilla"])
		var estado := Alumbrado.estado(semilla, Deterioro.zona(poste["x"], poste["z"]), poste["avenida"])
		var xform := Transform3D(Basis(Vector3.UP, float(poste["rotacion_y"])), Vector3(poste["x"], 0.0, poste["z"]))
		if estado["caido"]:
			# Tirado a lo largo de la banqueta, con el brazo hacia la calle
			var lado := 1.0 if Deterioro._hash(semilla, 9) < 0.5 else -1.0
			xform = xform * Transform3D(Basis(Vector3.BACK, lado * PI / 2.0), Vector3(0.0, GRUESO / 2.0, 0.0))
		elif estado["inclinacion"] > 0.0:
			var eje := Vector3(cos(estado["inclinacion_eje"]), 0.0, sin(estado["inclinacion_eje"]))
			xform.basis = Basis(eje, estado["inclinacion"]) * xform.basis
		var tipo := "%s/%s/%s" % [alto, brazo, doble]
		if not por_tipo.has(tipo):
			por_tipo[tipo] = [alto, brazo, doble, []]
		var prendida := 0.0 if estado["apagada"] else 1.0
		var custom := Color(prendida, 1.0 if estado["parpadea"] else 0.0, semilla, estado["umbral"])
		por_tipo[tipo][3].append([xform, estado["color"], custom])
		# Colision: el poste completo (inclinado o tirado)
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(GRUESO + 0.1, alto, GRUESO + 0.1)
		forma.shape = caja
		forma.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0.0, alto / 2.0, 0.0))
		cuerpo.add_child(forma)
		if estado["apagada"]:
			continue
		for signo: float in ([1.0, -1.0] if doble else [1.0]):
			var mica := xform * Vector3(0.0, alto - MICA_BAJO - 0.05, signo * (brazo - 0.1))
			halos.append([Transform3D(Basis.IDENTITY, mica), estado["color"], custom])
			lamparas.append({"pos": mica + Vector3.DOWN * 0.3, "color": estado["color"], "semilla": semilla,
				"umbral": estado["umbral"], "parpadea": estado["parpadea"]})
	for tipo: String in por_tipo:
		var datos: Array = por_tipo[tipo]
		var mallas := _mallas_de(datos[0], datos[1], datos[2])
		celda.add_child(_multimesh(mallas[0], _material, datos[3], false, poste_end))
		celda.add_child(_multimesh(mallas[1], _material_mica, datos[3], true, poste_end))
	if not halos.is_empty():
		celda.add_child(_multimesh(_halo_mesh, _material_halo, halos, true, halo_end))
	add_child(celda)
	_nodos[key] = celda
	_lamparas[key] = lamparas


func _multimesh(mesh: Mesh, material: Material, instancias: Array, con_datos: bool, fin: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = con_datos
	mm.use_custom_data = con_datos
	mm.mesh = mesh
	mm.instance_count = instancias.size()
	for i in instancias.size():
		mm.set_instance_transform(i, instancias[i][0])
		if con_datos:
			mm.set_instance_color(i, instancias[i][1])
			mm.set_instance_custom_data(i, instancias[i][2])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = fin
	return instance


# [poste con brazo(s) y caja de la lampara, micas] de un tipo de poste. Ejes: el
# poste sube en Y desde el origen y el brazo sale hacia +Z (y -Z si es doble)
func _mallas_de(alto: float, brazo: float, doble: bool) -> Array:
	var tipo := "%s/%s/%s" % [alto, brazo, doble]
	if _mallas.has(tipo):
		return _mallas[tipo]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_mica := SurfaceTool.new()
	st_mica.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caja(st, Vector3(0.0, 0.3, 0.0), Vector3(0.36, 0.6, 0.36), CONCRETO.darkened(0.1))
	_caja(st, Vector3(0.0, alto / 2.0, 0.0), Vector3(GRUESO, alto, GRUESO), CONCRETO)
	for signo: float in ([1.0, -1.0] if doble else [1.0]):
		_caja(st, Vector3(0.0, alto - 0.2, signo * brazo / 2.0), Vector3(0.08, 0.08, brazo), FIERRO)
		# Tirante del brazo
		_caja(st, Vector3(0.0, alto - 0.6, signo * 0.3), Vector3(0.06, 0.06, 0.6), FIERRO)
		_caja(st, Vector3(0.0, alto - MICA_BAJO + 0.06, signo * (brazo - 0.1)), Vector3(0.34, 0.12, 0.66), FIERRO.darkened(0.2))
		_caja(st_mica, Vector3(0.0, alto - MICA_BAJO - 0.02, signo * (brazo - 0.1)), Vector3(0.28, 0.04, 0.56), Color.WHITE)
	_mallas[tipo] = [st.commit(), st_mica.commit()]
	return _mallas[tipo]


func _caja(st: SurfaceTool, centro: Vector3, tamano: Vector3, color: Color) -> void:
	var h := tamano / 2.0
	for eje in 3:
		for signo: float in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[eje] = signo
			var u := Vector3.ZERO
			u[(eje + 1) % 3] = h[(eje + 1) % 3]
			var v := Vector3.ZERO
			v[(eje + 2) % 3] = h[(eje + 2) % 3]
			var c := centro + n * h[eje]
			var esquinas := [c - u - v, c + u - v, c + u + v, c - u + v]
			if signo < 0.0:
				esquinas.reverse()
			for i: int in [0, 2, 1, 0, 3, 2]:
				st.set_color(color)
				st.set_normal(n)
				st.add_vertex(esquinas[i])
