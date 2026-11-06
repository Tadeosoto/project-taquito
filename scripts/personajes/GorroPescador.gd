class_name GorroPescador
extends RefCounted
# El gorro de pescador azul de Ramon, el tercer protagonista (Personaje.GORROS). No viene en el modelo:
# es una malla hecha aqui (copa, tapa y ala caida, con costuras pintadas con color de vertice)
# que Personaje.vestir pega al hueso Head con un BoneAttachment3D. Una sola malla y un solo
# material para todos (los StandardMaterial3D por instancia trababan al compilarse).
# Las medidas son del espacio del hueso Head de el_compa (su pose de enlace en el skin, sin la
# escala 0.39 del jugador): X es el ancho (+-0.245), la cara ve hacia +Z (el craneo va de z -0.26
# a la nariz en 0.35) y la coronilla queda en y 0.55.

const AZUL := Color(0.16, 0.30, 0.62)
const COSTURA := 0.72          # que tan oscura sale una costura
const CENTRO := Vector3(0.0, 0.0, 0.0)
const FONDO := 1.06            # la cabeza es un poco mas larga (z) que ancha (x)
const COPA_ABAJO := 0.33       # y donde empieza la copa (justo arriba de las cejas)
const COPA_ARRIBA := 0.63
const COPA_RADIO := Vector2(0.272, 0.225)   # abajo, arriba
const ALA_RADIO := 0.42
const ALA_CAE := 0.085         # cuanto baja la orilla del ala
const ALA_GRUESO := 0.012
const LADOS := 20
const COSTURAS_ALA := 3        # anillos de pespunte en el ala

static var _malla: Mesh
static var _material: StandardMaterial3D


static func crear() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "GorroPescador"
	mi.mesh = _armar()
	mi.material_override = _mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _mat() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.albedo_color = AZUL
		_material.roughness = 1.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


# Punto del anillo de radio r a la altura y, en el angulo del lado i
static func _punto(i: int, r: float, y: float) -> Vector3:
	var a := TAU * float(i) / LADOS
	return CENTRO + Vector3(cos(a) * r, y, sin(a) * r * FONDO)


static func _armar() -> Mesh:
	if _malla != null:
		return _malla
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var claro := Color.WHITE
	var oscuro := Color(COSTURA, COSTURA, COSTURA)
	# Copa: dos tramos, con una costura en medio y la cinta de abajo mas oscura
	var anillos := [
		[COPA_RADIO.x, COPA_ABAJO, oscuro],
		[COPA_RADIO.x * 0.99, COPA_ABAJO + 0.05, oscuro],
		[COPA_RADIO.x * 0.98, COPA_ABAJO + 0.055, claro],
		[lerpf(COPA_RADIO.x, COPA_RADIO.y, 0.5), (COPA_ABAJO + COPA_ARRIBA) * 0.5, claro],
		[lerpf(COPA_RADIO.x, COPA_RADIO.y, 0.52), (COPA_ABAJO + COPA_ARRIBA) * 0.5 + 0.006, oscuro],
		[lerpf(COPA_RADIO.x, COPA_RADIO.y, 0.55), (COPA_ABAJO + COPA_ARRIBA) * 0.5 + 0.014, claro],
		[COPA_RADIO.y, COPA_ARRIBA, claro],
	]
	for k in anillos.size() - 1:
		var a: Array = anillos[k]
		var b: Array = anillos[k + 1]
		for i in LADOS:
			_cuad(st, _punto(i, a[0], a[1]), _punto(i + 1, a[0], a[1]),
					_punto(i + 1, b[0], b[1]), _punto(i, b[0], b[1]), a[2], b[2])
	# Tapa: un poco abombada, con un pespunte en circulo
	var tapa := CENTRO + Vector3(0, COPA_ARRIBA + 0.03, 0)
	var r_costura := COPA_RADIO.y * 0.7
	for i in LADOS:
		_cuad(st, _punto(i, COPA_RADIO.y, COPA_ARRIBA), _punto(i + 1, COPA_RADIO.y, COPA_ARRIBA),
				_punto(i + 1, r_costura, COPA_ARRIBA + 0.02), _punto(i, r_costura, COPA_ARRIBA + 0.02), claro, oscuro)
		_tri(st, _punto(i, r_costura, COPA_ARRIBA + 0.02), _punto(i + 1, r_costura, COPA_ARRIBA + 0.02), tapa, oscuro, oscuro, claro)
	# Ala: de la base de la copa hacia afuera y abajo, con pespuntes y canto grueso
	var pasos := COSTURAS_ALA * 2 + 1
	for k in pasos:
		var t0 := float(k) / pasos
		var t1 := float(k + 1) / pasos
		var c0 := oscuro if k % 2 == 1 else claro
		var c1 := oscuro if k % 2 == 1 else claro
		for i in LADOS:
			_cuad(st, _ala(i, t0), _ala(i + 1, t0), _ala(i + 1, t1), _ala(i, t1), c0, c1)
	for i in LADOS:
		var a := _ala(i, 1.0)
		var b := _ala(i + 1, 1.0)
		_cuad(st, a, b, b + Vector3.DOWN * ALA_GRUESO, a + Vector3.DOWN * ALA_GRUESO, oscuro, oscuro)
	st.generate_normals()
	_malla = st.commit()
	return _malla


# Punto del ala: t 0 en la base de la copa, 1 en la orilla (cae como curva, no recta)
static func _ala(i: int, t: float) -> Vector3:
	var r := lerpf(COPA_RADIO.x, ALA_RADIO, t)
	return _punto(i, r, COPA_ABAJO - ALA_CAE * t * (0.4 + 0.6 * t))


# a y b llevan el color ca; c y d el cc
static func _cuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cc: Color) -> void:
	_tri(st, a, b, c, ca, ca, cc)
	_tri(st, a, c, d, ca, cc, cc)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for par in [[a, ca], [b, cb], [c, cc]]:
		st.set_color(par[1])
		st.add_vertex(par[0])
