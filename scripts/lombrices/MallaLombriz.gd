class_name MallaLombriz
extends RefCounted
# Las mallas y el material de las lombrices (EnjambreLombrices, MadreCarcamo), hechas una vez.
# Todo va a lo largo de +Y, de -0.5 a 0.5, con radio 1: cada instancia del MultiMesh lo estira
# entre dos puntos (y = el tramo, x/z = el grueso).
# - segmento(): un tubo de LADOS caras, sin tapas (los tramos se enciman).
# - cabeza(): la boca de lamprea: un tubo que se abre en un labio, un anillo de dientes que
#   apuntan hacia adentro y un fondo oscuro. Los dientes llevan UV.x 1.5 y sus puntas 2.5 para que
#   el shader las abra (INSTANCE_CUSTOM.r) y el fondo UV.y = 2.
# El shader (shaders/lombriz.gdshader) pinta los anillos, las venas de Serenol y los dientes.

const SHADER := preload("res://shaders/lombriz.gdshader")
const LADOS := 6
const DIENTES := 8
const SHADER_MADRE := preload("res://shaders/madre.gdshader")

static var _segmento: ArrayMesh
static var _cabeza: ArrayMesh
static var _material: ShaderMaterial
static var _material_madre: ShaderMaterial
static var _material_crias: ShaderMaterial
static var _espina: ArrayMesh
static var _aleta: ArrayMesh


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


# La piel de la Madre (shaders/madre.gdshader): se pone como material_override de sus nodos
static func material_madre() -> ShaderMaterial:
	if _material_madre == null:
		_material_madre = ShaderMaterial.new()
		_material_madre.shader = SHADER_MADRE
	return _material_madre


# Las crias tienen la misma piel que la Madre, en su propio material: EnjambreLombrices le sube
# el brillo de noche sin tocar el de la Madre
static func material_crias() -> ShaderMaterial:
	if _material_crias == null:
		_material_crias = ShaderMaterial.new()
		_material_crias.shader = SHADER_MADRE
	return _material_crias


# Una espina del lomo: piramide de 4 caras de y = 0 (base) a 1 (punta), radio 1 en la base.
# UV.x = 3.5 para que el shader de la Madre la pinte; UV.y = 0 base, 1 punta.
static func espina() -> ArrayMesh:
	if _espina:
		return _espina
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var punta := Vector3(0.0, 1.0, 0.0)
	for k in 4:
		var a0 := TAU * k / 4.0 + PI / 4.0
		var a1 := TAU * (k + 1) / 4.0 + PI / 4.0
		var b0 := Vector3(cos(a0), 0.0, sin(a0))
		var b1 := Vector3(cos(a1), 0.0, sin(a1))
		st.set_uv(Vector2(3.5, 0.0)); st.add_vertex(b0)
		st.set_uv(Vector2(3.5, 0.0)); st.add_vertex(b1)
		st.set_uv(Vector2(3.5, 1.0)); st.add_vertex(punta)
	st.generate_normals()
	_espina = st.commit()
	_espina.surface_set_material(0, material_madre())
	return _espina


# Una aleta del lomo, plana como las del espinosaurio o la cola de Godzilla: ancha a lo largo del
# cuerpo (x, de -1 a 1), delgada de lado (z) y con la punta (x = 0.35) echada hacia la cola (+x).
# Mismo marcador de UV que la espina (x = 3.5; y = 0 base, 1 punta).
static func aleta() -> ArrayMesh:
	if _aleta:
		return _aleta
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var grueso := 0.14
	var b := [Vector3(-1.0, 0.0, -grueso), Vector3(1.0, 0.0, -grueso), Vector3(1.0, 0.0, grueso), Vector3(-1.0, 0.0, grueso)]
	var punta := Vector3(0.35, 1.0, 0.0)
	for k in 4:
		st.set_uv(Vector2(3.5, 0.0)); st.add_vertex(b[k])
		st.set_uv(Vector2(3.5, 0.0)); st.add_vertex(b[(k + 1) % 4])
		st.set_uv(Vector2(3.5, 1.0)); st.add_vertex(punta)
	st.generate_normals()
	_aleta = st.commit()
	_aleta.surface_set_material(0, material_madre())
	return _aleta


static func segmento() -> ArrayMesh:
	if _segmento:
		return _segmento
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	_anillos(st, [Vector2(-0.5, 1.0), Vector2(0.5, 1.0)], LADOS, 0.0)
	st.generate_normals()
	_segmento = st.commit()
	_segmento.surface_set_material(0, material())
	return _segmento


static func cabeza() -> ArrayMesh:
	if _cabeza:
		return _cabeza
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	# Cuello, cachete y labio: (y, radio)
	_anillos(st, [Vector2(-0.5, 1.0), Vector2(0.15, 1.18), Vector2(0.5, 1.0)], DIENTES, 0.0)
	# El labio dobla hacia adentro hasta la garganta
	_anillos(st, [Vector2(0.5, 1.0), Vector2(0.38, 0.6)], DIENTES, 0.0)
	st.set_smooth_group(-1)
	# Fondo oscuro de la garganta
	for k in DIENTES:
		var a0 := TAU * k / DIENTES
		var a1 := TAU * (k + 1) / DIENTES
		st.set_uv(Vector2(0.5, 2.0))
		st.add_vertex(Vector3(0.0, 0.3, 0.0))
		st.set_uv(Vector2(0.5, 2.0))
		st.add_vertex(Vector3(cos(a1) * 0.6, 0.38, sin(a1) * 0.6))
		st.set_uv(Vector2(0.5, 2.0))
		st.add_vertex(Vector3(cos(a0) * 0.6, 0.38, sin(a0) * 0.6))
	# Dientes: un triangulo por diente, de la orilla del labio hacia el centro y adelante
	for k in DIENTES * 2:
		var a := TAU * (k + 0.5) / (DIENTES * 2)
		var ancho := TAU / (DIENTES * 2) * 0.45
		var r := 0.92 if k % 2 == 0 else 0.78
		var base0 := Vector3(cos(a - ancho) * r, 0.47, sin(a - ancho) * r)
		var base1 := Vector3(cos(a + ancho) * r, 0.47, sin(a + ancho) * r)
		var punta := Vector3(cos(a) * r * 0.35, 0.62, sin(a) * r * 0.35)
		for lado in 2:
			st.set_uv(Vector2(1.5, 0.5))
			st.add_vertex(base0 if lado == 0 else base1)
			st.set_uv(Vector2(1.5, 0.5))
			st.add_vertex(base1 if lado == 0 else base0)
			st.set_uv(Vector2(2.5, 0.5))
			st.add_vertex(punta)
	st.generate_normals()
	_cabeza = st.commit()
	_cabeza.surface_set_material(0, material())
	return _cabeza


# Un tubo por anillos (y, radio), UV.x alrededor y UV.y a lo largo
static func _anillos(st: SurfaceTool, anillos: Array, lados: int, giro: float) -> void:
	for r in anillos.size() - 1:
		var a: Vector2 = anillos[r]
		var b: Vector2 = anillos[r + 1]
		var va := float(r) / (anillos.size() - 1)
		var vb := float(r + 1) / (anillos.size() - 1)
		for k in lados:
			var t0 := TAU * k / lados + giro
			var t1 := TAU * (k + 1) / lados + giro
			var p00 := Vector3(cos(t0) * a.y, a.x, sin(t0) * a.y)
			var p01 := Vector3(cos(t1) * a.y, a.x, sin(t1) * a.y)
			var p10 := Vector3(cos(t0) * b.y, b.x, sin(t0) * b.y)
			var p11 := Vector3(cos(t1) * b.y, b.x, sin(t1) * b.y)
			var u0 := float(k) / lados
			var u1 := float(k + 1) / lados
			st.set_uv(Vector2(u0, va)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, vb)); st.add_vertex(p11)
			st.set_uv(Vector2(u1, va)); st.add_vertex(p01)
			st.set_uv(Vector2(u0, va)); st.add_vertex(p00)
			st.set_uv(Vector2(u0, vb)); st.add_vertex(p10)
			st.set_uv(Vector2(u1, vb)); st.add_vertex(p11)


# La transformacion de un tramo de `a` a `b` con `grueso` de radio (para el buffer del MultiMesh)
static func tramo(a: Vector3, b: Vector3, grueso: float, de_mas := 1.25) -> Transform3D:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return Transform3D(Basis.from_scale(Vector3.ZERO), a)
	var y := d / l
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * grueso, y * (l * de_mas + grueso * 0.5), z * grueso), (a + b) * 0.5)


# Escribe una instancia en un buffer de MultiMesh con colores y datos (20 flotantes)
static func escribir(buffer: PackedFloat32Array, n: int, t: Transform3D, color: Color, dato: Color) -> void:
	var b := n * 20
	var bx := t.basis.x
	var by := t.basis.y
	var bz := t.basis.z
	buffer[b] = bx.x
	buffer[b + 1] = by.x
	buffer[b + 2] = bz.x
	buffer[b + 3] = t.origin.x
	buffer[b + 4] = bx.y
	buffer[b + 5] = by.y
	buffer[b + 6] = bz.y
	buffer[b + 7] = t.origin.y
	buffer[b + 8] = bx.z
	buffer[b + 9] = by.z
	buffer[b + 10] = bz.z
	buffer[b + 11] = t.origin.z
	buffer[b + 12] = color.r
	buffer[b + 13] = color.g
	buffer[b + 14] = color.b
	buffer[b + 15] = color.a
	buffer[b + 16] = dato.r
	buffer[b + 17] = dato.g
	buffer[b + 18] = dato.b
	buffer[b + 19] = dato.a


static func multimesh(malla: Mesh, cuantos: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = malla
	mm.instance_count = cuantos
	mm.visible_instance_count = 0
	return mm


static func nodo(mm: MultiMesh, sombra := true) -> MultiMeshInstance3D:
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = mm
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Se mueven por todo el campo: que nunca las recorte la camara
	instancia.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 200, 1000))
	instancia.top_level = true
	return instancia
