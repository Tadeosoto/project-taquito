class_name PanteonMapa
extends Node3D
## El panteon del Club Deportivo Bancario (JJ, 2026-11-22), en map_test: sin barda (la orilla es donde
## se acaban las tumbas), una plaza central de cantera con el Palacio de Gobierno del Estado de Mexico
## en medio (Sketchfab, CC-BY, models/props/palacio_edomex/) viendo al sur, cuatro andadores de tierra
## de la plaza a las orillas y, alrededor, las filas de tumbas de Panteon.gd. En la plaza, frente al
## portal, la flecha amarilla de la pelea de la Mojiganga (el nodo EntradaMojiganga de map_test, un
## EntradaJefe que ve al sur).
## La bodega hueca que habia adentro (y su barda de OSM) se quitan: MapBodegas pregunta
## `bodega_quitada` (via FortalezasMapa) y MapBardas `en_panteon`.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const MODELO_PALACIO := "res://models/props/palacio_edomex/palacio_edomex.scn"
## La orilla del panteon (x, z): la parte verde del club, sin las casas del oriente ni las tiendas de
## Independencia
const POLIGONO := [Vector2(310, -858), Vector2(765, -744), Vector2(765, -600), Vector2(640, -565), Vector2(310, -662)]
const CENTRO := Vector2(530.0, -715.0)          # de aqui se mide el palacio (su planta: x 500-560, z -747 a -699)
## La plaza de cantera (JJ, 2026-11-22: la de 90 x 80 se veia muy amplia y vacia): el palacio con 4-6 m
## de banqueta a los lados y atras, y enfrente un atrio de 18 m con jardineras, cipreses, bancas y faroles
const PLAZA_RECT := Rect2(494.0, -753.0, 72.0, 73.0)
const ATRIO_Z := Vector2(-697.0, -681.0)         # de la fachada a la orilla sur de la plaza
const FAROL_COLOR := Color(1.0, 0.82, 0.55)
const FAROL_CADA := 28.0                         # m entre faroles de los andadores
const ANDADOR := 3.0
const PALACIO_ESCALA := 60.0                    # viene en miniatura: ~55 m de frente, ~14 m de alto
const PALACIO_ATRAS := 8.0                      # m que el palacio se corre al norte del centro de la plaza
const BODEGA_QUITADA := Vector2(511.84, -632.45)
## Las construcciones que ya estan en el suelo horneado dentro del panteon (el edificio de OSM y las
## huellas de Google, data/map/google_buildings.csv, menos la de la bodega hueca que se quito): ahi no
## van tumbas. Quedan como capillas y casitas
const EDIFICIOS := [
	Rect2(496, -628, 28, 31), Rect2(447, -813, 6, 6), Rect2(549, -597, 9, 10), Rect2(727, -648, 13, 13), Rect2(629, -576, 13, 12),
	Rect2(746, -668, 9, 9), Rect2(632, -587, 9, 5), Rect2(488, -631, 34, 35), Rect2(747, -645, 8, 9), Rect2(748, -638, 6, 5),
	Rect2(581, -607, 4, 6), Rect2(749, -626, 14, 16), Rect2(745, -634, 13, 12), Rect2(314, -832, 6, 8), Rect2(579, -787, 8, 7),
	Rect2(738, -644, 12, 12), Rect2(687, -598, 9, 12), Rect2(574, -603, 16, 11), Rect2(559, -608, 12, 15), Rect2(620, -587, 12, 21),
	Rect2(431, -696, 10, 9), Rect2(330, -829, 11, 8), Rect2(605, -593, 13, 10), Rect2(589, -599, 10, 9), Rect2(690, -589, 10, 14),
	Rect2(520, -733, 4, 7), Rect2(667, -587, 4, 5), Rect2(730, -635, 13, 13), Rect2(625, -776, 7, 6), Rect2(630, -585, 13, 12),
	Rect2(419, -749, 11, 22), Rect2(606, -606, 4, 5), Rect2(680, -717, 11, 14), Rect2(554, -794, 8, 7), Rect2(541, -604, 11, 15),
	Rect2(733, -626, 19, 21), Rect2(652, -769, 8, 6), Rect2(562, -604, 15, 37), Rect2(633, -592, 12, 8),
	Rect2(702, -603, 9, 10), Rect2(669, -587, 4, 4), Rect2(447, -769, 5, 5), Rect2(550, -635, 7, 7), Rect2(615, -589, 8, 7),
	Rect2(708, -604, 7, 8), Rect2(595, -595, 12, 10), Rect2(586, -713, 5, 7), Rect2(738, -649, 8, 6), Rect2(482, -813, 8, 7),
	Rect2(756, -639, 12, 14), Rect2(609, -605, 11, 14), Rect2(734, -611, 21, 16), Rect2(553, -606, 5, 5),
]
const TEX_PLAZA := "res://textures/mapa/cantera_rosa.png"
const TEX_ANDADOR := "res://textures/mapa/tierra.png"
const TEX_PASTO := "res://textures/map/pasto_seco.png"
## El pasto seco va 12 cm arriba del suelo: las canchas del club (horneadas, con la capa de profundidad
## de ps1_suelo) se asomaban encima con menos; las tumbas se paran sobre el
const PASTO_ALTO := 0.12
const SEMILLA := 1918

static var _en_escena := false


func _enter_tree() -> void:
	_en_escena = true


func _exit_tree() -> void:
	_en_escena = false


## Dentro del poligono del panteon (para MapBardas: ahi no van bardas de OSM)
static func en_panteon(x: float, z: float) -> bool:
	return _en_escena and Geometry2D.is_point_in_polygon(Vector2(x, z), PackedVector2Array(POLIGONO))


## Sin bardas de OSM adentro ni pegadas a la orilla (la del lote del oriente parecia barda del panteon)
static func sin_barda(x: float, z: float) -> bool:
	if not _en_escena:
		return false
	var p := Vector2(x, z)
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(POLIGONO)):
		return true
	for i in POLIGONO.size():
		var a: Vector2 = POLIGONO[i]
		var b: Vector2 = POLIGONO[(i + 1) % POLIGONO.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 6.0:
			return true
	return false


## Sin matas de pasto en todo el panteon (tapaban las tumbas): el piso es el pasto seco
static func en_plaza(x: float, z: float) -> bool:
	if not _en_escena:
		return false
	if en_panteon(x, z):
		return true
	var p := Vector2(x, z)
	for r: Rect2 in libres():
		if r.has_point(p):
			return true
	return false


static func bodega_quitada(bodega: Dictionary) -> bool:
	return _en_escena and Vector2(bodega["x"], bodega["z"]).distance_to(BODEGA_QUITADA) < 1.0


## La plaza y los cuatro andadores (hasta afuera del poligono)
static func libres() -> Array[Rect2]:
	var p := PLAZA_RECT
	var a := ANDADOR / 2.0
	var cx := p.get_center().x
	var cz := p.get_center().y
	return [
		p,
		Rect2(cx - a, p.position.y - 200.0, ANDADOR, 200.0),                  # al norte
		Rect2(cx - a, p.end.y, ANDADOR, 200.0),                                # al sur, a Independencia
		Rect2(p.position.x - 300.0, cz - a, 300.0, ANDADOR),                  # al poniente
		Rect2(p.end.x, cz - a, 300.0, ANDADOR),                                # al oriente
	]


func _ready() -> void:
	add_to_group("panteon")
	var poligono := PackedVector2Array(POLIGONO)
	_pisos(poligono)
	_palacio()
	_atrio()
	_luces_palacio()
	_faroles_andadores(poligono)
	var tumbas := Panteon.new()
	tumbas.name = "Tumbas"
	tumbas.poligono = Geometry2D.offset_polygon(poligono, -1.5)[0]
	var margen: Array[Rect2] = []
	for r: Rect2 in libres():
		margen.append(r.grow(1.6))
	for r: Rect2 in EDIFICIOS:
		margen.append(r.grow(1.5))
	tumbas.libres = margen
	tumbas.poco_a_poco = true
	tumbas.position.y = PASTO_ALTO - 0.02
	add_child(tumbas)
	var caja := Rect2(poligono[0], Vector2.ZERO)
	for p in poligono:
		caja = caja.expand(p)
	tumbas.armar(caja, SEMILLA)


# La plaza de cantera y los andadores de tierra, recortados al poligono, apenas arriba del pasto
func _pisos(poligono: PackedVector2Array) -> void:
	var rects := libres()
	# Pasto seco en todo el panteon: tapa las canchas del club (sus rayas vienen en el suelo horneado)
	_piso_poligono(poligono, TEX_PASTO, 2.5, PASTO_ALTO, "PastoSeco")
	_piso(rects[0], TEX_PLAZA, 3.0, PASTO_ALTO + 0.04, "Plaza")
	for i in range(1, rects.size()):
		var r: Rect2 = rects[i]
		# Recorta el andador a lo que cae en el poligono
		var dentro := Geometry2D.intersect_polygons(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), poligono)
		if dentro.is_empty():
			continue
		var b := Rect2(dentro[0][0], Vector2.ZERO)
		for p in dentro[0]:
			b = b.expand(p)
		_piso(b, TEX_ANDADOR, 2.0, PASTO_ALTO + 0.03, "Andador_%d" % i)


func _piso(r: Rect2, textura: String, losa: float, alto: float, nombre: String) -> void:
	_piso_poligono(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			textura, losa, alto, nombre)


func _piso_poligono(poligono: PackedVector2Array, textura: String, losa: float, alto: float, nombre: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var tri := Geometry2D.triangulate_polygon(poligono)
	for k in range(0, tri.size(), 3):
		var a := poligono[tri[k]]
		var b := poligono[tri[k + 1]]
		var c := poligono[tri[k + 2]]
		# Que se vea desde arriba
		if (b - a).cross(c - a) < 0.0:
			var t := b
			b = c
			c = t
		for e in [a, b, c]:
			st.set_uv(e / losa)
			st.add_vertex(Vector3(e.x, 0.0, e.y))
	var piso := MeshInstance3D.new()
	piso.name = nombre
	piso.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("albedo_texture", load(textura))
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	piso.material_override = material
	piso.position.y = alto
	piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piso)


# El palacio: sin su base de arena, sus 600 piezas juntas en una malla por material (con su textura),
# chocando con su forma real
func _palacio() -> void:
	if not ResourceLoader.exists(MODELO_PALACIO):
		push_warning("PanteonMapa: falta %s (fetch_sketchfab.py props/palacio_edomex y hornear_modelos.gd)" % MODELO_PALACIO)
		return
	var modelo := (load(MODELO_PALACIO) as PackedScene).instantiate() as Node3D
	var mallas := modelo.find_children("*", "MeshInstance3D", true, false)
	# La base de arena: la pieza mas ancha y casi plana
	var base: MeshInstance3D = null
	var mayor := 0.0
	for m: MeshInstance3D in mallas:
		var a := _relativo(modelo, m) * m.get_aabb()
		if a.size.y < 0.01 and a.size.x * a.size.z > mayor:
			mayor = a.size.x * a.size.z
			base = m
	var grupos := {}      # material -> [vertices, normales, uv, indices]
	var caja := AABB()
	var primero := true
	for m: MeshInstance3D in mallas:
		if m == base:
			continue
		var xf := Transform3D(Basis().scaled(Vector3.ONE * PALACIO_ESCALA), Vector3.ZERO) * _relativo(modelo, m)
		var giro := xf.basis.orthonormalized()
		for s in m.mesh.get_surface_count():
			var material := m.get_active_material(s)
			if not grupos.has(material):
				grupos[material] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
			var g: Array = grupos[material]
			var arr := m.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var idx = arr[Mesh.ARRAY_INDEX]
			var desde: int = g[0].size()
			for v in vs.size():
				var p := xf * vs[v]
				g[0].append(p)
				g[1].append((giro * ns[v]).normalized() if v < ns.size() else Vector3.UP)
				g[2].append(uvs[v] if uvs is PackedVector2Array and v < uvs.size() else Vector2.ZERO)
				if primero:
					caja = AABB(p, Vector3.ZERO)
					primero = false
				else:
					caja = caja.expand(p)
			if idx is PackedInt32Array and not idx.is_empty():
				for k: int in idx:
					g[3].append(desde + k)
			else:
				for k in vs.size():
					g[3].append(desde + k)
	modelo.free()
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Palacio"
	# El centro de su planta en la plaza, corrido al norte; el pie en el piso. Su portal (+Z) ve al sur
	cuerpo.position = Vector3(CENTRO.x - caja.get_center().x, -caja.position.y, CENTRO.y - PALACIO_ATRAS - caja.get_center().z)
	add_child(cuerpo)
	for material: Material in grupos:
		var g: Array = grupos[material]
		var arreglos := []
		arreglos.resize(Mesh.ARRAY_MAX)
		arreglos[Mesh.ARRAY_VERTEX] = g[0]
		arreglos[Mesh.ARRAY_NORMAL] = g[1]
		arreglos[Mesh.ARRAY_TEX_UV] = g[2]
		arreglos[Mesh.ARRAY_INDEX] = g[3]
		var malla := ArrayMesh.new()
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
		var mat := material
		if mat is ShaderMaterial:
			# Es mundo: sin el brinco de vertices de los personajes
			mat = (mat as ShaderMaterial).duplicate()
			mat.set_shader_parameter("jitter_enabled", false)
			mat.set_shader_parameter("wobble_enabled", false)
		malla.surface_set_material(0, mat)
		var nodo := MeshInstance3D.new()
		nodo.mesh = malla
		cuerpo.add_child(nodo)
		var forma := CollisionShape3D.new()
		forma.shape = malla.create_trimesh_shape()
		cuerpo.add_child(forma)


# --- El atrio, los faroles y la luz del palacio ---

static var _mat_cantera: ShaderMaterial
static var _mat_tierra: ShaderMaterial
static var _mat_fierro: ShaderMaterial
static var _mat_madera: ShaderMaterial
static var _mat_cipres: ShaderMaterial
static var _mat_foco: StandardMaterial3D


func _materiales() -> void:
	if _mat_cantera != null:
		return
	_mat_cantera = _ps1("res://textures/mapa/cantera_rosa.png", Color(0.85, 0.8, 0.76))
	_mat_tierra = _ps1(TEX_ANDADOR, Color(0.7, 0.62, 0.55))
	_mat_fierro = _ps1("", Color(0.1, 0.1, 0.11))
	_mat_madera = _ps1("", Color(0.35, 0.22, 0.12))
	_mat_cipres = _ps1("res://textures/map/arbol.png", Color(0.32, 0.45, 0.3))
	_mat_foco = StandardMaterial3D.new()
	_mat_foco.albedo_color = FAROL_COLOR
	_mat_foco.emission_enabled = true
	_mat_foco.emission = FAROL_COLOR
	_mat_foco.emission_energy_multiplier = 2.0
	_mat_foco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _ps1(textura: String, tinte: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1_SHADER
	if textura != "":
		m.set_shader_parameter("albedo_texture", load(textura))
	m.set_shader_parameter("tint", tinte)
	m.set_shader_parameter("deterioro_modo", 1)
	m.set_shader_parameter("jitter_enabled", false)
	m.set_shader_parameter("wobble_enabled", false)
	return m


func _bloque(padre: Node3D, centro: Vector3, tam: Vector3, material: Material, choca := true) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = material
	m.position = centro
	padre.add_child(m)
	if choca:
		_choque(padre, centro, tam)


func _choque(padre: Node3D, centro: Vector3, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = centro
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


# Enfrente del palacio: cuatro jardineras de cantera con un cipres en cada punta y cempasuchil, una banca
# frente a cada una, cipreses a los lados del palacio y faroles en la orilla. El pasillo de en medio
# (la flecha de la Mojiganga) queda libre
func _atrio() -> void:
	_materiales()
	var atrio := Node3D.new()
	atrio.name = "Atrio"
	atrio.position.y = PASTO_ALTO + 0.04
	add_child(atrio)
	var cx := PLAZA_RECT.get_center().x
	var z := (ATRIO_Z.x + ATRIO_Z.y) / 2.0 - 1.0
	var flores := MultiMesh.new()
	flores.transform_format = MultiMesh.TRANSFORM_3D
	flores.use_colors = true
	flores.mesh = Panteon._malla_flor()
	var en_flores: Array = []
	var azar := RandomNumberGenerator.new()
	azar.seed = SEMILLA
	for x: float in [-24.0, -12.0, 12.0, 24.0]:
		var c := Vector3(cx + x, 0.0, z)
		_bloque(atrio, c + Vector3(0, 0.35, 0), Vector3(8.0, 0.7, 3.0), _mat_cantera)
		_bloque(atrio, c + Vector3(0, 0.71, 0), Vector3(7.4, 0.04, 2.4), _mat_tierra, false)
		for punta in [-1.0, 1.0]:
			_cipres(atrio, c + Vector3(punta * 2.9, 0.72, 0.0), azar.randf_range(5.0, 6.5))
		for k in 46:
			var p := c + Vector3(azar.randf_range(-2.2, 2.2), 0.82 + azar.randf() * 0.08, azar.randf_range(-1.0, 1.0))
			en_flores.append([Transform3D(Basis().scaled(Vector3.ONE * 1.4), p),
				[Color(1.0, 0.5, 0.05), Color(1.0, 0.72, 0.1), Color(0.85, 0.15, 0.35)][azar.randi() % 3]])
		_banca(atrio, c + Vector3(0.0, 0.0, 3.0))
	flores.instance_count = en_flores.size()
	for i in en_flores.size():
		flores.set_instance_transform(i, en_flores[i][0])
		flores.set_instance_color(i, en_flores[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = flores
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 120.0
	atrio.add_child(mmi)
	# Cipreses a los lados y atras del palacio, en su banqueta
	for zz in range(-745, -700, 9):
		_cipres(atrio, Vector3(PLAZA_RECT.position.x + 2.0, 0.0, zz), azar.randf_range(6.0, 8.0))
		_cipres(atrio, Vector3(PLAZA_RECT.end.x - 2.0, 0.0, zz), azar.randf_range(6.0, 8.0))
	for xx in [-20.0, -10.0, 10.0, 20.0]:
		_cipres(atrio, Vector3(cx + xx, 0.0, PLAZA_RECT.position.y + 2.5), azar.randf_range(6.0, 8.0))
	# Faroles en la orilla sur y en las esquinas
	for x in [-33.0, -18.0, -6.0, 6.0, 18.0, 33.0]:
		_farol(atrio, Vector3(cx + x, 0.0, ATRIO_Z.y + 1.0))
	for x in [-33.0, 33.0]:
		_farol(atrio, Vector3(cx + x, 0.0, ATRIO_Z.x + 1.0))
		_farol(atrio, Vector3(cx + x, 0.0, PLAZA_RECT.position.y + 2.0))


func _cipres(padre: Node3D, pie: Vector3, alto: float) -> void:
	var tronco := MeshInstance3D.new()
	var t := CylinderMesh.new()
	t.top_radius = 0.12
	t.bottom_radius = 0.16
	t.height = 0.8
	t.radial_segments = 5
	tronco.mesh = t
	tronco.material_override = _mat_madera
	tronco.position = pie + Vector3(0, 0.4, 0)
	padre.add_child(tronco)
	var copa := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.75
	c.height = alto
	c.radial_segments = 6
	c.rings = 2
	copa.mesh = c
	copa.material_override = _mat_cipres
	copa.position = pie + Vector3(0, 0.6 + alto / 2.0, 0)
	padre.add_child(copa)
	_choque(padre, pie + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.6))


func _banca(padre: Node3D, pie: Vector3) -> void:
	_bloque(padre, pie + Vector3(0, 0.45, 0), Vector3(2.4, 0.08, 0.5), _mat_madera, false)
	_bloque(padre, pie + Vector3(0, 0.75, -0.22), Vector3(2.4, 0.5, 0.06), _mat_madera, false)
	for lado in [-1.0, 1.0]:
		_bloque(padre, pie + Vector3(lado * 1.05, 0.22, 0), Vector3(0.1, 0.44, 0.45), _mat_fierro, false)
	_choque(padre, pie + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.6))


# Un farol de fierro con su foco y su luz (como los de la plaza del palacio de Colon)
func _farol(padre: Node3D, pie: Vector3, con_luz := true) -> void:
	var poste := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.1
	c.height = 4.2
	c.radial_segments = 6
	poste.mesh = c
	poste.material_override = _mat_fierro
	poste.position = pie + Vector3(0, 2.1, 0)
	padre.add_child(poste)
	var foco := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.55, 0.45)
	foco.mesh = b
	foco.material_override = _mat_foco
	foco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foco.position = pie + Vector3(0, 4.45, 0)
	padre.add_child(foco)
	if con_luz:
		var luz := OmniLight3D.new()
		luz.light_color = FAROL_COLOR
		luz.light_energy = 2.4
		luz.omni_range = 16.0
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = 110.0
		luz.distance_fade_length = 30.0
		luz.position = pie + Vector3(0, 4.2, 0)
		padre.add_child(luz)
	_choque(padre, pie + Vector3(0, 2.1, 0), Vector3(0.25, 4.2, 0.25))


# El palacio iluminado de noche: reflectores en el piso que lavan la fachada hacia arriba, luz calida en
# los arcos del portal y reflectores mas tenues en los costados
func _luces_palacio() -> void:
	var luces := Node3D.new()
	luces.name = "LucesPalacio"
	add_child(luces)
	var cx := PLAZA_RECT.get_center().x
	var fachada := -698.7
	for x in [-27.0, -18.0, -9.0, 0.0, 9.0, 18.0, 27.0]:
		_reflector(luces, Vector3(cx + x, PASTO_ALTO + 0.04, fachada + 3.2), Vector3(cx + x, 9.0, fachada), 12.0)
	for lado in [-1.0, 1.0]:
		var xl: float = cx + lado * 30.2
		for zz in [-738.0, -722.0, -706.0]:
			_reflector(luces, Vector3(xl + lado * 2.8, PASTO_ALTO + 0.04, zz), Vector3(xl, 8.0, zz), 8.0)
	for x in [-14.0, 0.0, 14.0]:
		var portal := OmniLight3D.new()
		portal.light_color = Color(1.0, 0.75, 0.45)
		portal.light_energy = 4.0
		portal.omni_range = 12.0
		portal.distance_fade_enabled = true
		portal.distance_fade_begin = 150.0
		portal.distance_fade_length = 40.0
		portal.position = Vector3(cx + x, 2.8, fachada - 2.0)
		luces.add_child(portal)


func _reflector(padre: Node3D, pie: Vector3, hacia: Vector3, energia: float) -> void:
	var caja := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.3, 0.4)
	caja.mesh = b
	caja.material_override = _mat_fierro
	caja.position = pie + Vector3(0, 0.15, 0)
	padre.add_child(caja)
	var vidrio := MeshInstance3D.new()
	var v := BoxMesh.new()
	v.size = Vector3(0.4, 0.22, 0.02)
	vidrio.mesh = v
	vidrio.material_override = _mat_foco
	vidrio.position = pie + Vector3(0, 0.17, 0) + (Vector3(hacia.x, pie.y, hacia.z) - pie).normalized() * 0.21
	vidrio.look_at_from_position(vidrio.position, vidrio.position + (Vector3(hacia.x, vidrio.position.y, hacia.z) - vidrio.position), Vector3.UP)
	padre.add_child(vidrio)
	var luz := SpotLight3D.new()
	luz.light_color = Color(1.0, 0.86, 0.66)
	luz.light_energy = energia
	luz.spot_range = 28.0
	luz.spot_angle = 38.0
	luz.spot_attenuation = 0.6
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 200.0
	luz.distance_fade_length = 50.0
	padre.add_child(luz)
	luz.look_at_from_position(pie + Vector3(0, 0.35, 0), hacia, Vector3.UP)


# Faroles a lo largo de los cuatro andadores, alternando de lado, dentro del panteon
func _faroles_andadores(poligono: PackedVector2Array) -> void:
	var nodo := Node3D.new()
	nodo.name = "FarolesAndadores"
	nodo.position.y = PASTO_ALTO
	add_child(nodo)
	var rects := libres()
	var lado := 1.0
	var con_luz := true
	for i in range(1, rects.size()):
		var r: Rect2 = rects[i]
		var vertical := r.size.y > r.size.x
		var largo := r.size.y if vertical else r.size.x
		var d := FAROL_CADA / 2.0
		while d < largo:
			var p := Vector2(r.get_center().x + lado * 2.4, r.position.y + d) if vertical \
					else Vector2(r.position.x + d, r.get_center().y + lado * 2.4)
			if Geometry2D.is_point_in_polygon(p, Geometry2D.offset_polygon(poligono, -4.0)[0]):
				# Luz en uno si y uno no (cada luz es otra pasada de GPU): los otros solo con el foco
				_farol(nodo, Vector3(p.x, 0.0, p.y), con_luz)
				con_luz = not con_luz
			lado = -lado
			d += FAROL_CADA


## La frente del portal del palacio (para la flecha y las pruebas): el centro de la plaza corrido al sur
static func frente_palacio() -> Vector2:
	return CENTRO + Vector2(0.0, 12.0)


func _relativo(ancestro: Node3D, nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := nodo
	while n != ancestro:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t
