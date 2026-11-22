class_name Panteon
extends Node3D
## El panteon del Club Bancario (JJ, 2026-11-22): filas de tumbas espalda con espalda (las cabeceras
## juntas, los pies a un corredor), con corredores entre cada pareja de filas para ir a visitarlas y
## un corredor de cruce cada TRAMO m. Las lapidas son modelos de Sketchfab (models/panteon/, CC-BY):
## la mexicana de 1918, el juego de lapidas viejas, las dos PS1 y las cruces de madera de las fosas
## recientes; las criptas son el mausoleo PS1. Cada tumba lleva su cajon de cantera gastada (la
## textura de las lapidas del juego, con mugre del shader) o, si es reciente, su monton de tierra.
## Una de cada OFRENDA tumbas tiene ofrenda al pie: veladoras y flores como las del altar de la
## Virgen de Santa Mugre (tools/blender/mapa/piezas.py `nicho_virgen`).
##
## Todo va en MultiMesh: una por pieza y material y por CUADRO, con su distancia de dibujo (las lapidas
## hasta VER_LAPIDAS, los cajones hasta VER_CAJONES, la ofrenda hasta VER_OFRENDA), y un cuerpo de choques
## por cuadro. `armar(rect, semilla)` llena un rectangulo en coordenadas locales (filas a lo largo de X,
## +Z al sur), sin salirse de `poligono` (si se da) ni meterse en `libres` (la plaza, los andadores).
## `armar` junta los datos de una vez y arma los cuadros uno por frame (con `poco_a_poco`).
## Probar: godot --path . tools/probar_panteon.tscn

const CORREDOR := 1.4           # entre parejas de filas, por donde se visita
const LARGO := 2.4              # de la cabecera a los pies de una tumba
const PASO := 1.25              # de una tumba a la de al lado
const TRAMO := 24.0             # cada cuanto hay un corredor de cruce
const CRUCE := 2.0              # ancho del corredor de cruce
const OFRENDA := 10             # una de cada tantas tumbas tiene veladoras y flores
const VACIO := 0.07             # lugares sin tumba (pasto)
const RECIENTE := 0.12          # fosas recientes: tierra y cruz de madera
const CRIPTAS := 0.035          # por lugar de la fila de enfrente: una cripta ocupa 3 lugares de las dos filas

# Las lapidas: escena, nodos (vacio = todos), alto al que se escala, si ocupa dos lugares
const LAPIDAS := [
	["res://models/panteon/mexicana_1918/mexicana_1918.scn", [], 2.1, true, 1.0],
	["res://models/panteon/lapidas_pack/lapidas_pack.scn", ["grave_stone_01"], 1.15, false, 3.0],
	["res://models/panteon/lapidas_pack/lapidas_pack.scn", ["grave_stone_02"], 1.05, false, 3.0],
	["res://models/panteon/lapidas_pack/lapidas_pack.scn", ["grave_stone_03"], 1.7, false, 2.0],
	["res://models/panteon/lapidas_pack/lapidas_pack.scn", ["grave_stone_04"], 0.9, false, 3.0],
	["res://models/panteon/lapidas_pack/lapidas_pack.scn", ["grave_stone_05"], 1.9, false, 1.5],
	["res://models/panteon/ps1_lapida/ps1_lapida.scn", [], 1.0, false, 3.0],
	["res://models/panteon/ps1_lapida2/ps1_lapida2.scn", [], 1.1, false, 3.0],
]
const CRUCES := [
	["res://models/panteon/props/props.scn", ["pCube39"], 1.3],
	["res://models/panteon/props/props.scn", ["polySurface7"], 1.45],
	["res://models/panteon/props/props.scn", ["pCube47"], 1.15],
]
const CRIPTA := ["res://models/panteon/ps1_mausoleo/ps1_mausoleo.scn", [], 4.0]
const TEXTURA_CANTERA := "res://models/panteon/lapidas_pack/textures/grave_stone_02.005_baseColor.png"
const TEXTURA_TIERRA := "res://textures/map/suelo.png"
const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const CUADRO := 48.0
# Las lapidas con detalle, su bloque de lejos y las ofrendas van en cuadros chicos: Godot mide el rango al
# centro del cuadro, y con 48 m las lapidas de 700 triangulos se veian hasta ~70 m (900k primitivas)
const CUADRO_FINO := 16.0
# Las lapidas de Sketchfab (300-1600 triangulos) solo de cerca; de VER_DETALLE a VER_LAPIDAS se ve en su
# lugar un bloque de su tamano con la misma piedra (12 triangulos). Medido en el andador sur: con todo
# hasta 90 m y con sombras eran 3.1 M primitivas y +14 ms de GPU
const VER_DETALLE := 35.0
const VER_LAPIDAS := 110.0
const VER_CAJONES := 160.0
const VER_OFRENDA := 40.0
const POR_FRAME := 3

## Donde caben las tumbas (vacio = todo el rectangulo) y donde no (Rect2 en x, z)
var poligono := PackedVector2Array()
var libres: Array[Rect2] = []
## Arma un cuadro por frame (en el mapa); si no, todo de una vez (la prueba)
var poco_a_poco := false

# Piezas listas para MultiMesh: {malla: ArrayMesh, base: Transform3D (escala y centrado)}
static var _piezas := {}
static var _cajon: ArrayMesh
static var _tierra: ArrayMesh
static var _vaso: ArrayMesh
static var _flama: ArrayMesh
static var _flor: ArrayMesh
static var _florero: ArrayMesh
static var _bloque: ArrayMesh
static var _petalo: ArrayMesh
## Donde quedo el pie de cada ofrenda (local a este nodo): para pruebas y capturas
var ofrendas := PackedVector3Array()
# Que mallas son lapidas con detalle (se cambian por bloque de lejos) y cuales criptas (con sombra)
static var _detalle := {}
static var _criptas := {}

# Lo que se va juntando antes de hacer las MultiMesh: malla -> Array[Transform3D] (+ colores)
var _lotes := {}
var _choques: Array = []        # [centro, tamano, giro]


## Llena `rect` (x, z locales) de filas. Las filas corren a lo largo de X
func armar(rect: Rect2, semilla: int) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var periodo := CORREDOR + 2.0 * LARGO
	var z := rect.position.y + CORREDOR
	while z + 2.0 * LARGO <= rect.end.y:
		var espalda := z + LARGO          # donde se juntan las cabeceras
		var x := rect.position.x + PASO / 2.0
		var hasta_cruce := TRAMO
		while x + PASO / 2.0 <= rect.end.x:
			if x - rect.position.x > hasta_cruce:
				hasta_cruce += TRAMO
				x += CRUCE
				continue
			# Una cripta: tres lugares de las dos filas
			if azar.randf() < CRIPTAS and x + 3.0 * PASO <= rect.end.x \
					and _cabe(Vector2(x + PASO, espalda), Vector2(3.0 * PASO, 2.0 * LARGO)):
				_cripta(Vector3(x + PASO, 0.0, espalda), azar)
				x += 3.0 * PASO
				continue
			for lado in [-1.0, 1.0]:
				if _cabe(Vector2(x, espalda + lado * LARGO * 0.5), Vector2(PASO, LARGO)):
					_tumba(Vector3(x, 0.0, espalda), lado, azar)
			x += PASO
		z += periodo
	_hacer_lotes()


# Si un rectangulo (centro, tamano) cae entero en el poligono y fuera de los libres
func _cabe(centro: Vector2, tam: Vector2) -> bool:
	var r := Rect2(centro - tam / 2.0, tam)
	for libre: Rect2 in libres:
		if libre.intersects(r):
			return false
	if poligono.is_empty():
		return true
	for esquina in [r.position, r.position + Vector2(tam.x, 0.0), r.end, r.position + Vector2(0.0, tam.y)]:
		if not Geometry2D.is_point_in_polygon(esquina, poligono):
			return false
	return true


# Una tumba con la cabecera en `espalda` y los pies hacia `lado` (-1: hacia -Z, al corredor de antes)
func _tumba(espalda: Vector3, lado: float, azar: RandomNumberGenerator) -> void:
	var r := azar.randf()
	if r < VACIO:
		return
	# El frente de la tumba ve a los pies: +Z local de la pieza hacia `lado`
	var giro := 0.0 if lado > 0.0 else PI
	giro += azar.randf_range(-0.05, 0.05)
	var base := Transform3D(Basis(Vector3.UP, giro), espalda + Vector3(azar.randf_range(-0.06, 0.06), 0.0, 0.0))
	var adelante := base.basis.z
	var reciente := r < VACIO + RECIENTE
	if reciente:
		var monton := base.translated(adelante * (LARGO * 0.5))
		_poner(_malla_tierra(), monton.scaled_local(Vector3(1.0, azar.randf_range(0.7, 1.2), 1.0)))
		var cruz: Array = CRUCES[azar.randi() % CRUCES.size()]
		var t := base.translated(adelante * 0.25)
		t.basis = t.basis.rotated(t.basis.x.normalized(), azar.randf_range(-0.12, 0.08))
		_poner_pieza(cruz[0], cruz[1], cruz[2], t)
		_choques.append([monton.origin + Vector3(0.0, 0.2, 0.0), Vector3(0.9, 0.4, LARGO - 0.4), giro])
	else:
		var cual: Array = _pesada(azar)
		var cajon := base.translated(adelante * (LARGO * 0.5 + 0.05))
		_poner(_malla_cajon(), cajon.scaled_local(Vector3(1.0, azar.randf_range(0.8, 1.3), 1.0)), _color_cajon(azar))
		var t := base.translated(adelante * 0.2 + Vector3.UP * 0.3)
		# Las viejas, algunas ladeadas o hundidas
		if azar.randf() < 0.25:
			t.basis = t.basis.rotated(t.basis.z.normalized(), azar.randf_range(-0.12, 0.12))
			t.basis = t.basis.rotated(t.basis.x.normalized(), azar.randf_range(-0.1, 0.06))
			t.origin.y -= azar.randf_range(0.0, 0.12)
		_poner_pieza(cual[0], cual[1], cual[2], t)
		_choques.append([cajon.origin + Vector3(0.0, 0.5, 0.0), Vector3(1.0, 1.0, LARGO), giro])
	if azar.randi() % OFRENDA == 0:
		_ofrenda(base.translated(adelante * (LARGO - 0.15)), azar)


# Cantera (la mayoria), encalados o pintados y deslavados como en los panteones de aqui
func _color_cajon(azar: RandomNumberGenerator) -> Color:
	var r := azar.randf()
	if r < 0.55:
		return Color(0.78, 0.76, 0.72) * azar.randf_range(0.8, 1.0)     # cantera
	if r < 0.75:
		return Color(1.0, 0.99, 0.95) * azar.randf_range(0.92, 1.0)     # cal
	var pinturas := [Color(0.95, 0.66, 0.72), Color(0.62, 0.78, 0.97), Color(0.66, 0.9, 0.8), Color(0.97, 0.88, 0.62)]
	return pinturas[azar.randi() % pinturas.size()] * azar.randf_range(0.85, 1.0)


func _pesada(azar: RandomNumberGenerator) -> Array:
	var total := 0.0
	for l: Array in LAPIDAS:
		total += l[4]
	var r := azar.randf() * total
	for l: Array in LAPIDAS:
		r -= l[4]
		if r <= 0.0:
			return l
	return LAPIDAS[0]


func _cripta(centro: Vector3, azar: RandomNumberGenerator) -> void:
	var giro := (0.0 if azar.randf() < 0.5 else PI) + azar.randf_range(-0.03, 0.03)
	var t := Transform3D(Basis(Vector3.UP, giro), centro)
	_poner_pieza(CRIPTA[0], CRIPTA[1], CRIPTA[2], t, true)
	_choques.append([centro + Vector3(0.0, 1.8, 0.0), Vector3(3.0 * PASO, 3.6, 2.0 * LARGO - 0.6), giro])
	if azar.randi() % 3 == 0:
		_ofrenda(t.translated(t.basis.z * (LARGO - 0.2)), azar)


# Veladoras y flores al pie (`pie` ve hacia afuera de la tumba con su +Z)
func _ofrenda(pie: Transform3D, azar: RandomNumberGenerator) -> void:
	ofrendas.append(pie.origin)
	var colores := [Color(0.75, 0.1, 0.1), Color(0.95, 0.92, 0.85), Color(0.95, 0.8, 0.35), Color(0.2, 0.35, 0.8)]
	for i in azar.randi_range(2, 5):
		var p := pie.origin + pie.basis.x * azar.randf_range(-0.4, 0.4) + pie.basis.z * azar.randf_range(0.0, 0.3)
		_poner(_malla_vaso(), Transform3D(Basis(), p), colores[azar.randi() % colores.size()])
		_poner(_malla_flama(), Transform3D(Basis(), p + Vector3(0.0, 0.3, 0.0)))
	# Uno o dos floreros con su racimo: cempasuchil, amarillas y blancas, como el altar de la Virgen
	var flores := [Color(1.0, 0.5, 0.05), Color(1.0, 0.8, 0.1), Color(0.95, 0.95, 0.9), Color(0.85, 0.15, 0.35)]
	for j in azar.randi_range(1, 2):
		var lado := -1.0 if j == 0 else 1.0
		var f := pie.origin + pie.basis.x * (lado * azar.randf_range(0.2, 0.42)) - pie.basis.z * 0.05
		_poner(_malla_florero(), Transform3D(Basis(), f))
		var color: Color = flores[azar.randi() % flores.size()]
		for k in 9:
			var a := TAU * k / 9.0 + azar.randf()
			var r := 0.05 if k < 4 else 0.12
			var p := f + Vector3(cos(a) * r, 0.36 + azar.randf_range(0.0, 0.16), sin(a) * r)
			_poner(_malla_flor(), Transform3D(Basis(), p), color if k % 2 == 0 else flores[azar.randi() % flores.size()])
	# Y el camino de cempasuchil regado al pie, que se ve desde el corredor
	for k in azar.randi_range(8, 14):
		var p := pie.origin + pie.basis.x * azar.randf_range(-0.45, 0.45) + pie.basis.z * azar.randf_range(0.2, 0.75)
		_poner(_malla_petalo(), Transform3D(Basis(Vector3.UP, azar.randf() * TAU), p + Vector3(0.0, 0.015, 0.0)),
				flores[0] if azar.randf() < 0.75 else flores[1])


# --- Lotes ---

func _poner(malla: Mesh, t: Transform3D, color := Color.WHITE) -> void:
	var cuadro := _clave(t.origin, _es_fino(malla))
	if not _lotes.has(cuadro):
		_lotes[cuadro] = {}
	var del_cuadro: Dictionary = _lotes[cuadro]
	if not del_cuadro.has(malla):
		del_cuadro[malla] = [[], []]
	del_cuadro[malla][0].append(t)
	del_cuadro[malla][1].append(color)


func _cuadro_de(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CUADRO), floori(p.z / CUADRO))


# La clave del lote: (x, z, 0) en cuadros de CUADRO o (x, z, 1) en los de CUADRO_FINO
func _clave(p: Vector3, fino: bool) -> Vector3i:
	var tam := CUADRO_FINO if fino else CUADRO
	return Vector3i(floori(p.x / tam), floori(p.z / tam), 1 if fino else 0)


func _es_fino(malla: Mesh) -> bool:
	return _detalle.has(malla) or malla in [_bloque, _flor, _flama, _vaso, _florero, _petalo]


static func _centro_clave(c: Vector3i) -> Vector2:
	var tam := CUADRO_FINO if c.z == 1 else CUADRO
	return (Vector2(c.x, c.y) + Vector2(0.5, 0.5)) * tam


func _poner_pieza(ruta: String, nodos: Array, alto: float, t: Transform3D, cripta := false) -> void:
	var pieza := _pieza(ruta, nodos, alto)
	var malla: ArrayMesh = pieza["malla"]
	_poner(malla, t * pieza["base"])
	if cripta:
		_criptas[malla] = true
		return
	# El bloque de lejos, del tamano de la pieza
	_detalle[malla] = true
	var tam: Vector3 = pieza["tam"]
	_poner(_malla_bloque(), t.scaled_local(Vector3(tam.x * 0.85, tam.y, maxf(tam.z, 0.12))), Color(0.75, 0.74, 0.7))


func _hacer_lotes() -> void:
	var choques_por := {}
	for c: Array in _choques:
		var cuadro := _clave(c[0], false)
		if not choques_por.has(cuadro):
			choques_por[cuadro] = []
		choques_por[cuadro].append(c)
	_choques.clear()
	var lotes := _lotes
	_lotes = {}
	# Primero los cuadros mas cercanos al jugador (o a la camara), POR_FRAME por frame
	var orden := lotes.keys()
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D if is_inside_tree() else null
	if jugador:
		var donde := Vector2(jugador.global_position.x, jugador.global_position.z)
		orden.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return _centro_clave(a).distance_to(donde) < _centro_clave(b).distance_to(donde))
	# Un cuadro fino pesa lo que su area: 1/9 de uno grande
	var fino := (CUADRO_FINO * CUADRO_FINO) / (CUADRO * CUADRO)
	var hecho := 0.0
	for cuadro: Vector3i in orden:
		_hacer_cuadro(cuadro, lotes[cuadro], choques_por.get(cuadro, []))
		hecho += fino if cuadro.z == 1 else 1.0
		if poco_a_poco and is_inside_tree() and hecho >= POR_FRAME:
			hecho = 0.0
			await get_tree().process_frame


func _hacer_cuadro(cuadro: Vector3i, del_cuadro: Dictionary, choques: Array) -> void:
	var nodo := Node3D.new()
	nodo.name = ("Fino_%d_%d" if cuadro.z == 1 else "Cuadro_%d_%d") % [cuadro.x, cuadro.y]
	add_child(nodo)
	for malla: Mesh in del_cuadro:
		var datos: Array = del_cuadro[malla]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = malla
		mm.instance_count = datos[0].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, datos[0][i])
			mm.set_instance_color(i, datos[1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var chico: bool = malla in [_flor, _flama, _vaso, _florero, _petalo]
		# Solo las criptas dan sombra (las lapidas la doblaban: cada sombra es otra pasada)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _criptas.has(malla) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Godot mide al centro del AABB del cuadro: se le suma medio cuadro
		var medio := (CUADRO_FINO if cuadro.z == 1 else CUADRO) * 0.7
		if _detalle.has(malla) or chico:
			mmi.visibility_range_end = (VER_OFRENDA if chico else VER_DETALLE) + medio
		elif malla == _bloque:
			mmi.visibility_range_begin = VER_DETALLE + medio
			mmi.visibility_range_end = VER_LAPIDAS + medio
		elif _criptas.has(malla):
			mmi.visibility_range_end = VER_CAJONES + medio
		else:
			mmi.visibility_range_end = (VER_CAJONES if malla in [_cajon, _tierra] else VER_LAPIDAS) + medio
		nodo.add_child(mmi)
	if choques.is_empty():
		return
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Choques"
	nodo.add_child(cuerpo)
	for c: Array in choques:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = c[1]
		forma.shape = caja
		forma.transform = Transform3D(Basis(Vector3.UP, c[2]), c[0])
		cuerpo.add_child(forma)


# --- Piezas de Sketchfab: los nodos pedidos juntos en una ArrayMesh, la base en el piso, escalada a `alto` ---

static func _pieza(ruta: String, nodos: Array, alto: float) -> Dictionary:
	var llave := "%s|%s|%s" % [ruta, ",".join(nodos), alto]
	if _piezas.has(llave):
		return _piezas[llave]
	var escena: Node3D = (load(ruta) as PackedScene).instantiate()
	var malla := ArrayMesh.new()
	var caja := AABB()
	var primero := true
	for m: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		if not nodos.is_empty() and not nodos.any(func(n: String) -> bool: return String(m.name).begins_with(n)):
			continue
		var t := _a_raiz(m, escena)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in v.size():
				v[i] = t * v[i]
				if not primero or i > 0:
					caja = caja.expand(v[i])
				else:
					caja = AABB(v[i], Vector3.ZERO)
					primero = false
				if n.size() > i:
					n[i] = (t.basis * n[i]).normalized()
			# Solo lo que usa el shader: posicion, normal, UV e indices
			var limpio := []
			limpio.resize(Mesh.ARRAY_MAX)
			limpio[Mesh.ARRAY_VERTEX] = v
			if n.size() == v.size():
				limpio[Mesh.ARRAY_NORMAL] = n
			limpio[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
			limpio[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, limpio)
			var material := m.get_active_material(s)
			if material is ShaderMaterial:
				material = (material as ShaderMaterial).duplicate()
				material.set_shader_parameter("use_vertex_color", true)
				material.set_shader_parameter("deterioro_modo", 1)
			malla.surface_set_material(malla.get_surface_count() - 1, material)
	escena.free()
	var escala := alto / maxf(caja.size.y, 0.001)
	var base := Transform3D(Basis().scaled(Vector3.ONE * escala),
			Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z) * escala)
	var pieza := {"malla": malla, "base": base, "tam": caja.size * escala}
	_piezas[llave] = pieza
	return pieza


static func _a_raiz(nodo: Node3D, raiz: Node3D) -> Transform3D:
	var t := nodo.transform
	var p := nodo.get_parent()
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


# --- Mallas propias (compartidas) ---

static func _material(textura: String, modo: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1_SHADER
	m.set_shader_parameter("albedo_texture", load(textura))
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("deterioro_modo", modo)
	m.set_shader_parameter("affine_enabled", false)
	return m


# El cajon de cantera: 0.95 x 0.32 x 2.2, con la textura de las lapidas (una zona lisa de piedra
# vieja) en cada cara, y mugre
static func _malla_cajon() -> ArrayMesh:
	if _cajon == null:
		_cajon = _caja(Vector3(0.95, 0.32, LARGO - 0.2), Rect2(0.43, 0.75, 0.29, 0.18), _material(TEXTURA_CANTERA, 1))
	return _cajon


# El bloque de lejos: una caja de 1 m con la base en el piso, con la piedra de los cajones
static func _malla_bloque() -> ArrayMesh:
	if _bloque == null:
		_bloque = _caja(Vector3.ONE, Rect2(0.43, 0.75, 0.29, 0.18), _material(TEXTURA_CANTERA, 1))
	return _bloque


static func _malla_tierra() -> ArrayMesh:
	if _tierra == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Un monton bajo: caja con la tapa abombada (5 x 3 puntos)
		var ancho := 0.85
		var largo := LARGO - 0.5
		var alto := 0.32
		var puntos := []
		for i in 5:
			var fila := []
			for j in 3:
				var x := (j / 2.0 - 0.5) * ancho
				var z := (i / 4.0 - 0.5) * largo
				var y := alto * (1.0 - pow(abs(j - 1.0), 2.0) * 0.7) * (1.0 - pow(abs(i - 2.0) / 2.0, 2.0) * 0.5)
				fila.append(Vector3(x, y, z))
			puntos.append(fila)
		for i in 4:
			for j in 2:
				var a: Vector3 = puntos[i][j]
				var b: Vector3 = puntos[i][j + 1]
				var c: Vector3 = puntos[i + 1][j + 1]
				var d: Vector3 = puntos[i + 1][j]
				for p in [a, b, c, a, c, d]:
					st.set_uv(Vector2(p.x, p.z) * 0.6)
					st.add_vertex(p)
		# Los lados hasta el piso
		var orilla := []
		for i in 5:
			orilla.append(puntos[i][0])
		for j in range(1, 3):
			orilla.append(puntos[4][j])
		for i in range(3, -1, -1):
			orilla.append(puntos[i][2])
		for j in range(1, -1, -1):
			orilla.append(puntos[0][j])
		for k in orilla.size() - 1:
			var a: Vector3 = orilla[k]
			var b: Vector3 = orilla[k + 1]
			var a0 := Vector3(a.x * 1.12, 0.0, a.z * 1.06)
			var b0 := Vector3(b.x * 1.12, 0.0, b.z * 1.06)
			for p in [a, b, b0, a, b0, a0]:
				st.set_uv(Vector2(p.x + p.z, p.y) * 0.6)
				st.add_vertex(p)
		st.generate_normals()
		_tierra = st.commit()
		_tierra.surface_set_material(0, _material(TEXTURA_TIERRA, 0))
	return _tierra


static func _malla_vaso() -> ArrayMesh:
	if _vaso == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.06
		c.height = 0.26
		c.radial_segments = 6
		c.rings = 1
		_vaso = _a_array(c, Vector3(0.0, 0.13, 0.0))
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.4
		_vaso.surface_set_material(0, m)
	return _vaso


static func _malla_flama() -> ArrayMesh:
	if _flama == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.05, 0.1, 0.05)
		_flama = _a_array(b, Vector3.ZERO)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.82, 0.4)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.2)
		m.emission_energy_multiplier = 2.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flama.surface_set_material(0, m)
	return _flama


static func _malla_flor() -> ArrayMesh:
	if _flor == null:
		var e := SphereMesh.new()
		e.radius = 0.08
		e.height = 0.13
		e.radial_segments = 5
		e.rings = 2
		_flor = _a_array(e, Vector3.ZERO)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		_flor.surface_set_material(0, m)
	return _flor


# Los petalos regados: un cuadrito plano (2 triangulos), del color de la flor
static func _malla_petalo() -> ArrayMesh:
	if _petalo == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.11, 0.11)
		q.orientation = PlaneMesh.FACE_Y
		_petalo = _a_array(q, Vector3.ZERO)
		_petalo.surface_set_material(0, _malla_flor().surface_get_material(0))
	return _petalo


static func _malla_florero() -> ArrayMesh:
	if _florero == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.09
		c.bottom_radius = 0.06
		c.height = 0.34
		c.radial_segments = 6
		c.rings = 1
		_florero = _a_array(c, Vector3(0.0, 0.17, 0.0))
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.47, 0.42)
		m.roughness = 0.9
		_florero.surface_set_material(0, m)
	return _florero


static func _a_array(primitiva: PrimitiveMesh, mover: Vector3) -> ArrayMesh:
	var arr := primitiva.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] += mover
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# Una caja centrada en x/z con la base en el piso, cada cara con la misma zona `uv` de la textura
static func _caja(tam: Vector3, uv: Rect2, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := Vector3(tam.x / 2.0, 0.0, tam.z / 2.0)
	var caras := [
		[Vector3(-h.x, tam.y, -h.z), Vector3(h.x, tam.y, -h.z), Vector3(h.x, tam.y, h.z), Vector3(-h.x, tam.y, h.z)],
		[Vector3(-h.x, 0, h.z), Vector3(h.x, 0, h.z), Vector3(h.x, tam.y, h.z), Vector3(-h.x, tam.y, h.z)],
		[Vector3(h.x, 0, -h.z), Vector3(-h.x, 0, -h.z), Vector3(-h.x, tam.y, -h.z), Vector3(h.x, tam.y, -h.z)],
		[Vector3(h.x, 0, h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, tam.y, -h.z), Vector3(h.x, tam.y, h.z)],
		[Vector3(-h.x, 0, -h.z), Vector3(-h.x, 0, h.z), Vector3(-h.x, tam.y, h.z), Vector3(-h.x, tam.y, -h.z)],
	]
	var esquinas := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for c in caras.size():
		var cara: Array = caras[c]
		# La tapa se ve desde arriba y los lados desde afuera: el orden cambia
		for k in ([0, 1, 2, 0, 2, 3] if c == 0 else [0, 2, 1, 0, 3, 2]):
			st.set_uv(uv.position + esquinas[k] * uv.size)
			st.add_vertex(cara[k])
	st.generate_normals()
	var malla := st.commit()
	malla.surface_set_material(0, material)
	return malla
