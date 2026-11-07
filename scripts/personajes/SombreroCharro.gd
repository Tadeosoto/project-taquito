class_name SombreroCharro
extends RefCounted
# El sombrero charro de Emiliano (Personaje.GORROS): copa alta y redondeada, ala muy ancha que en
# la orilla se dobla hacia arriba, todo tejido en zigzag (chevrones) gris verdoso, como el de la
# foto de Zapata. Malla hecha aqui, una sola para todos, pegada al hueso Head como GorroPescador:
# mismas medidas (espacio del hueso Head de el_compa: X el ancho, la cara ve hacia +Z, la coronilla
# en y 0.55, sin la escala 0.39 del jugador). Cada cara lleva un solo color, para que el tejido
# salga en cuadritos limpios como pixel art.

const PAJA := Color(0.58, 0.58, 0.48)
const TEJIDO := Color(0.30, 0.32, 0.26)
const DEBAJO := 0.55           # el ala por debajo, a la sombra
const FONDO := 1.06
const COPA_ABAJO := 0.34
const COPA_RADIO := 0.275
const COPA_ALTO := 0.52        # cuanto sube la copa desde COPA_ABAJO
const COPA_PUNTA := 0.17       # radio arriba, antes de cerrarse redonda
const ALA_RADIO := 0.86
const ALA_SUBE := 0.16         # cuanto se levanta la orilla
const ALA_ROLLO := 0.05        # el rollo de la orilla
const LADOS := 40
const TRAMOS_COPA := 12
const TRAMOS_ALA := 12

static var _malla: Mesh
static var _material: StandardMaterial3D


static func crear() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "SombreroCharro"
	mi.mesh = _armar()
	mi.material_override = _mat()
	return mi


static func _mat() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# Los colores de arriba son sRGB, como los de la foto (sin esto salia casi blanco)
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _punto(i: int, r: float, y: float) -> Vector3:
	var a := TAU * float(i) / LADOS
	return Vector3(cos(a) * r, y, sin(a) * r * FONDO)


# Zigzag: el anillo k y el lado i dan tejido oscuro o paja (chevrones que dan vuelta)
static func _color(i: int, k: int, banda: int) -> Color:
	var zig := absi((i % 6) - 3)
	return TEJIDO if (k + zig) % banda == 0 else PAJA


static func _armar() -> Mesh:
	if _malla != null:
		return _malla
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Copa: sube casi recta, se angosta y cierra redonda
	var copa: Array[Vector2] = []   # (radio, y)
	for k in TRAMOS_COPA + 1:
		var t := float(k) / TRAMOS_COPA
		var r := lerpf(COPA_RADIO, COPA_PUNTA, t * t)
		copa.append(Vector2(r, COPA_ABAJO + COPA_ALTO * t))
	for k in TRAMOS_COPA:
		for i in LADOS:
			var a := copa[k]
			var b := copa[k + 1]
			_cuad(st, _punto(i, a.x, a.y), _punto(i + 1, a.x, a.y), _punto(i + 1, b.x, b.y), _punto(i, b.x, b.y),
					_color(i, k, 4))
	var tope := COPA_ABAJO + COPA_ALTO
	for i in LADOS:
		_tri(st, _punto(i, COPA_PUNTA, tope), _punto(i + 1, COPA_PUNTA, tope), Vector3(0, tope + 0.05, 0),
				PAJA)
	# Ala: casi plana cerca de la copa y levantandose hacia la orilla, con el rollo al final
	var ala: Array[Vector2] = []
	for k in TRAMOS_ALA + 1:
		var t := float(k) / TRAMOS_ALA
		ala.append(Vector2(lerpf(COPA_RADIO, ALA_RADIO, t), COPA_ABAJO + ALA_SUBE * pow(t, 2.5)))
	ala.append(Vector2(ALA_RADIO + ALA_ROLLO * 0.4, COPA_ABAJO + ALA_SUBE + ALA_ROLLO))
	ala.append(Vector2(ALA_RADIO - ALA_ROLLO * 0.3, COPA_ABAJO + ALA_SUBE + ALA_ROLLO * 1.3))
	for k in ala.size() - 1:
		for i in LADOS:
			var a := ala[k]
			var b := ala[k + 1]
			var arriba := _color(i, k, 3) if k < TRAMOS_ALA else TEJIDO
			var p := [_punto(i, a.x, a.y), _punto(i + 1, a.x, a.y), _punto(i + 1, b.x, b.y), _punto(i, b.x, b.y)]
			_cuad(st, p[0], p[1], p[2], p[3], arriba)
			# Por debajo, un poquito abajo y oscuro (sin esto se veia el tejido de arriba al reves)
			var abajo := Vector3.DOWN * 0.008
			_cuad(st, p[3] + abajo, p[2] + abajo, p[1] + abajo, p[0] + abajo, PAJA * DEBAJO)
	st.generate_normals()
	_malla = st.commit()
	return _malla


static func _cuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
