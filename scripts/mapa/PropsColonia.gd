class_name PropsColonia
extends Node3D

# Props de la libreria de modelos que el generador de una colonia pone a mano (la favela de La
# Gotera: dentro de las casas abandonadas y los callejones techados, la basura de los callejones,
# las llantas, garrafones y cubetas de las piezas). Cada uno es
# [x, z, giro, pack, nodo, y, choca, medida, tumbada] en resources/mapa/<colonia>/props_modelo.json
# (lo escribe exportar.py desde datos["props"] y colonia.PROPS_PIEZA); `pack` y `nodo` son los de
# TianguisPiezas (o `pack` es la ruta de una escena), que da la pieza asentada en el piso. `medida`
# (opcional) [largo, alto]: se escala para caber en lo mas largo en planta y en el alto, en metros.
# `choca`: una caja de choque del tamano de la pieza; el generador la apaga donde estorbaria el paso
# (los callejones techados) y los pone lejos de las puertas de las casas. `tumbada` (opcional,
# radianes): se acuesta sobre su X antes de medirla y se vuelve a asentar en el piso (las llantas
# apiladas).
#
# Son miles (1700 bolsas de basura en la favela), asi que no van como nodos sueltos: cada malla se
# junta en un MultiMesh por cuadro de CELDA m, con su alcance de dibujo (que Godot mide al centro
# de la caja del MultiMesh, por eso se le suma media diagonal del cuadro).
#
# Sin wobble y con el jitter fino (JJ, 2026-11-14: "algunos props tienen demasiado jitter"): los
# modelos de objetos traen snap 80 (4 px a 640) y el wobble de 2.5 cm deshacia los chicos. Cada
# malla se copia una vez con sus materiales cambiados por copias hechas una vez por material de
# origen (_suaves), nunca por instancia (recompilar materiales por instancia daba tirones).

const Piezas := preload("res://scripts/map/TianguisPiezas.gd")
const SNAP := 320.0    # un pixel a 640 de ancho
const CELDA := 24.0    # m: lado de los cuadros en que se juntan los MultiMesh

static var _suaves := {}    # material de origen -> su copia sin wobble
static var _mallas := {}    # [malla, materiales] -> copia de la malla con los materiales suaves

@export_file("*.json") var props_path := ""
# Lo que queda mas lejos que esto del jugador no se dibuja
@export var visible_hasta := 60.0


func _ready() -> void:
	if props_path == "" or not FileAccess.file_exists(props_path):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(props_path))
	if not datos is Dictionary:
		push_warning("PropsColonia: no se pudo leer %s" % props_path)
		return
	var moldes := {}     # [pack, nodo, medida, tumbada] -> {"partes": [[malla, xform]], "caja": AABB}
	var cuadros := {}    # Vector2i -> {malla: Array[Transform3D]}
	var cuerpo: StaticBody3D = null
	for p: Array in datos.get("props", []):
		var medida = p[7] if p.size() > 7 else null
		var tumbada := float(p[8]) if p.size() > 8 else 0.0
		var clave := [String(p[3]), String(p[4]), medida, tumbada]
		if not moldes.has(clave):
			moldes[clave] = _molde(String(p[3]), String(p[4]), medida, tumbada)
		var molde: Dictionary = moldes[clave]
		if molde.is_empty():
			continue
		var lugar := Transform3D(Basis(Vector3.UP, float(p[2])), Vector3(float(p[0]), float(p[5]), float(p[1])))
		var cuadro := Vector2i(floori(lugar.origin.x / CELDA), floori(lugar.origin.z / CELDA))
		if not cuadros.has(cuadro):
			cuadros[cuadro] = {}
		var de_cuadro: Dictionary = cuadros[cuadro]
		for parte: Array in molde["partes"]:
			if not de_cuadro.has(parte[0]):
				de_cuadro[parte[0]] = [] as Array[Transform3D]
			(de_cuadro[parte[0]] as Array[Transform3D]).append(lugar * (parte[1] as Transform3D))
		if bool(p[6]):
			if cuerpo == null:
				cuerpo = StaticBody3D.new()
				cuerpo.name = "Choques"
				add_child(cuerpo)
			var caja: AABB = molde["caja"]
			var forma := CollisionShape3D.new()
			forma.shape = molde["cubo"]
			forma.transform = lugar * Transform3D(Basis.IDENTITY, caja.get_center())
			cuerpo.add_child(forma)
	var alcance := visible_hasta + CELDA * 0.71
	for cuadro: Vector2i in cuadros:
		for malla: Mesh in cuadros[cuadro]:
			var lugares: Array[Transform3D] = cuadros[cuadro][malla]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = malla
			multi.instance_count = lugares.size()
			for i in lugares.size():
				multi.set_instance_transform(i, lugares[i])
			var instancia := MultiMeshInstance3D.new()
			instancia.multimesh = multi
			instancia.visibility_range_end = alcance
			add_child(instancia)


# La pieza una vez: acostada, escalada a su medida y con sus mallas (ya con materiales suaves)
# respecto a su base. Vacio si no hay modelo.
func _molde(pack: String, nodo: String, medida, tumbada: float) -> Dictionary:
	var pieza: Node3D = Piezas.pieza(pack, nodo)
	if pieza == null:
		return {}
	if absf(tumbada) > 0.001:
		var giro := Transform3D(Basis(Vector3.RIGHT, tumbada), Vector3.ZERO)
		for m: Node3D in pieza.get_children():
			m.transform = giro * m.transform
		var acostada: AABB = Piezas.caja_de(pieza)
		var al_piso := Transform3D(Basis.IDENTITY, -Vector3(acostada.get_center().x, acostada.position.y, acostada.get_center().z))
		for m: Node3D in pieza.get_children():
			m.transform = al_piso * m.transform
	if medida is Array and (medida as Array).size() == 2:
		# Que quepa en [largo en planta, alto] (los modelos sueltos vienen en otras escalas)
		var tam: Vector3 = Piezas.caja_de(pieza).size
		if tam.x > 0.0 and tam.y > 0.0 and tam.z > 0.0:
			var s := minf(float(medida[0]) / maxf(tam.x, tam.z), float(medida[1]) / tam.y)
			var escala := Transform3D().scaled(Vector3.ONE * s)
			for m: Node3D in pieza.get_children():
				m.transform = escala * m.transform
	var partes := []
	for m: MeshInstance3D in pieza.find_children("*", "MeshInstance3D", true, false):
		partes.append([_malla_suave(m), m.transform])
	var caja: AABB = Piezas.caja_de(pieza)
	pieza.free()
	var cubo := BoxShape3D.new()
	cubo.size = caja.size
	return {"partes": partes, "caja": caja, "cubo": cubo}


# La malla de `m` con los materiales que lleva puestos (los override de TianguisPiezas o los suyos)
# cambiados por los suaves; una copia por combinacion, compartida por todos los props
static func _malla_suave(m: MeshInstance3D) -> Mesh:
	var materiales := []
	for i in m.mesh.get_surface_count():
		materiales.append(m.get_active_material(i))
	var clave := [m.mesh, materiales]
	if not _mallas.has(clave):
		var copia := m.mesh.duplicate() as Mesh
		for i in materiales.size():
			var suave := _suave(materiales[i])
			copia.surface_set_material(i, suave if suave else materiales[i])
		_mallas[clave] = copia
	return _mallas[clave]


static func _suave(origen: Material) -> Material:
	if not origen is ShaderMaterial:
		return null
	if not _suaves.has(origen):
		var copia := (origen as ShaderMaterial).duplicate() as ShaderMaterial
		copia.set_shader_parameter("wobble_enabled", false)
		copia.set_shader_parameter("snap_resolution", SNAP)
		_suaves[origen] = copia
	return _suaves[origen]
