class_name BocinaEncintada
extends Node3D

# La bocina encintada a una botella de agua (JJ): el señuelo de verdad. La bocina sola apenas jala
# zombis de cerca; con la botella de agua retumba mas y los jala de lejos (Senuelo). Se arma con
# bocina + botella de agua (resources/recetas/bocina_encintada.tres); la cinta solo se ve (JJ).
# La bocina (Bocina) acostada en X y, pegada a un lado (-Z), la botella (BotellaAgua) apoyada en
# el mismo piso; dos tiras de cinta gris le dan la vuelta a las dos. Todo se pone en _init para
# que InventoryItemData.crear_modelo lo mida (scenes/bocina_encintada.tscn). El origen es el
# centro de la bocina.

const CINTA_ANCHO := 0.032
const CINTAS := [-0.07, 0.06]  # x de cada tira
const COLOR_CINTA := Color(0.62, 0.63, 0.62)
# En la mano, como la bocina sola
const EN_MANO := Bocina.EN_MANO
const GIRO_MANO := Bocina.GIRO_MANO

static var _cinta: ArrayMesh


func _init() -> void:
	add_child(Bocina.new())
	var botella := BotellaAgua.new()
	botella.position = centro_botella()
	add_child(botella)
	var cinta := MeshInstance3D.new()
	cinta.mesh = malla_cinta()
	add_child(cinta)


# Donde va el centro de la botella: junto a la bocina, apoyada en el mismo piso
static func centro_botella() -> Vector3:
	return Vector3(-0.01, -(Bocina.RADIO - BotellaAgua.RADIO), -(Bocina.RADIO + BotellaAgua.RADIO))


# Las tiras de cinta: el contorno de los dos circulos juntos (bocina y botella), de CINTA_ANCHO
static func malla_cinta() -> ArrayMesh:
	if _cinta:
		return _cinta
	var c := centro_botella()
	var contorno := _contorno(Vector2.ZERO, Bocina.RADIO * 1.07, Vector2(c.y, c.z), BotellaAgua.RADIO * 1.04)
	var cinta := SurfaceTool.new()
	cinta.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in CINTAS:
		_tira(cinta, contorno, x)
	cinta.generate_normals()
	_cinta = cinta.commit()
	_cinta.surface_set_material(0, Bocina._material(COLOR_CINTA))
	return _cinta


# El contorno (en el plano YZ, como Vector2(y, z)) de dos circulos juntos: la envolvente convexa
# de puntos en las dos orillas, en orden alrededor
static func _contorno(a: Vector2, ra: float, b: Vector2, rb: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for k in 24:
		var ang := TAU * k / 24.0
		var dir := Vector2(cos(ang), sin(ang))
		puntos.append(a + dir * ra)
		puntos.append(b + dir * rb)
	return Geometry2D.convex_hull(puntos)


# Una tira de cinta en `x`: la orilla de afuera del contorno
static func _tira(st: SurfaceTool, contorno: PackedVector2Array, x: float) -> void:
	var izq := x - CINTA_ANCHO * 0.5
	var der := x + CINTA_ANCHO * 0.5
	for i in contorno.size() - 1:
		var p := contorno[i]
		var q := contorno[i + 1]
		var a := Vector3(izq, p.x, p.y)
		var b := Vector3(der, p.x, p.y)
		var c := Vector3(der, q.x, q.y)
		var d := Vector3(izq, q.x, q.y)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)
