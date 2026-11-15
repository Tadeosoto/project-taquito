class_name TinacoComunitario
extends StaticBody3D

# El tinaco comunitario de la plaza de Santa Mugre con la Virgen del Tinaco (marca "tinaco" de Colonia):
# un tinaco de plastico tipo Rotoplas hecho en codigo por revolucion (redondo en todas sus partes: el modelo
# de la defensa es octagonal y su tercera capa venia chueca), con los anillos del cuerpo, el hombro curvo,
# la tapa negra de rosca y la mugre (lodo abajo, escurridos de los anillos); la mancha de moho de la Virgen
# pegada a la base y lo que la gente le deja en el piso: veladoras prendidas, caléndulas y petalos sueltos.
# Lo arma `armar(litros)` antes de entrar al arbol.

const MANCHA_TINACO := preload("res://textures/mapa/mancha_tinaco.png")
# Lo que la gente va y deja: escena, alto que se le da (m), cuantas (para uno de 20 mil litros) y que tan
# lejos de la pared (0 = pegada, 1 = hasta la orilla de la ofrenda: las velas al frente, las flores atras)
const OFRENDA := [
	[preload("res://models/props/calendula/calendula.scn"), 0.5, 13, 0.45],
	[preload("res://models/props/veladora/veladora.scn"), 0.26, 11, 1.0],
]
const VELA_FLAMA := 0.62        # a que fraccion del alto de la veladora va la flama
const OFRENDA_HASTA := 60.0     # m a los que se deja de dibujar la ofrenda (y los petalos)
const PETALOS := 70             # sueltos en el piso, para uno de 20 mil litros

const ALTO_10MIL := 2.8         # Barricada.TINACO_ALTO: uno de 10 mil litros
const RADIO := 0.39             # del alto (2.8 m de alto, 2.2 de ancho)
const LADOS := 48
# Perfil del cuerpo (fraccion del alto, fraccion del radio): pie, cuerpo con anillos, hombro y cuello
const CUERPO_HASTA := 0.76
const HOMBRO_HASTA := 0.925
const CUELLO := 0.44
const ANILLOS := 7
const ANILLO_SALE := 0.022
const TAPA := [0.47, 0.925, 0.985]   # radio, de, hasta

const COLOR_PLASTICO := Color(0.76, 0.70, 0.55)
const COLOR_LODO := Color(0.33, 0.28, 0.21)
const COLOR_ESCURRE := Color(0.47, 0.46, 0.34)
const COLOR_TAPA := Color(0.09, 0.09, 0.1)

# La mancha de la Virgen: hacia donde ve (rad; x = cos, z = sin: la fila del agua; igual en piezas.py), cuanto
# abarca de lado a lado y de que fraccion del alto a cual (pegada a la base)
const MANCHA_RUMBO := 1.2
const MANCHA_ARCO := 0.62
const MANCHA_DE := 0.02
const MANCHA_HASTA := 0.46
const MANCHA_FILAS := 16
const MANCHA_COLUMNAS := 6

var alto := ALTO_10MIL
var radio := ALTO_10MIL * RADIO
var _flamas: MultiMesh
var _flamas_base: Array[Transform3D] = []
var _luz: OmniLight3D
var _luz_base := 0.0
var _t := 0.0


func armar(litros: float, con_virgen := true, comunitario := true) -> void:
	name = "TinacoComunitario"
	if comunitario:
		add_to_group("tinaco_comunitario")   # donde va la mision de la defensa del tinaco
	alto = ALTO_10MIL * pow(litros / 10000.0, 1.0 / 3.0)
	radio = alto * RADIO
	var factor := pow(litros / 20000.0, 1.0 / 3.0)   # contra uno de 20 mil litros
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "Tinaco"
	cuerpo.mesh = _malla_tinaco()
	add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = radio
	cilindro.height = alto
	forma.shape = cilindro
	forma.position.y = alto / 2.0
	add_child(forma)
	if con_virgen:
		add_child(_mancha())
		add_child(_ofrenda(factor))
		add_child(_petalos(factor))
		# La luz de las veladoras, al pie de la mancha; titila
		_luz = OmniLight3D.new()
		_luz.name = "LuzVeladoras"
		_luz.light_color = Color(1.0, 0.62, 0.28)
		_luz_base = 0.7 * factor
		_luz.light_energy = _luz_base
		_luz.omni_range = 4.0 * factor
		_luz.position = _al_frente(radio + 0.45 * factor, 0.0) + Vector3(0.0, 0.6, 0.0)
		add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	if _luz:
		_luz.light_energy = _luz_base * (0.88 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0 + 1.3))
	if _flamas == null:
		return
	for i in _flamas_base.size():
		var alto_flama := 1.0 + 0.18 * sin(_t * 11.0 + i * 1.7) + 0.08 * sin(_t * 27.0 + i)
		_flamas.set_instance_transform(i, _flamas_base[i].scaled_local(Vector3(1.0, alto_flama, 1.0)))


# Un punto a `r` del eje, hacia la mancha y corrido `lado` m de lado
func _al_frente(r: float, lado: float) -> Vector3:
	return Vector3(cos(MANCHA_RUMBO) * r - sin(MANCHA_RUMBO) * lado, 0.0, sin(MANCHA_RUMBO) * r + cos(MANCHA_RUMBO) * lado)


# --- El tinaco ---

# El radio del cuerpo (fraccion) a la fraccion de alto `y`: el pie un poco metido, los anillos y el hombro
static func radio_en(y: float) -> float:
	if y < 0.025:
		return lerpf(0.955, 1.0, smoothstep(0.0, 0.025, y))
	if y <= CUERPO_HASTA:
		var r := 1.0
		for k in ANILLOS:
			var c := lerpf(0.09, CUERPO_HASTA - 0.04, float(k) / (ANILLOS - 1))
			r += ANILLO_SALE * exp(-pow((y - c) / 0.012, 2.0))
		return r
	if y <= HOMBRO_HASTA:
		# Un cuarto de elipse: de pared derecha a casi plano hacia el cuello
		var t := (y - CUERPO_HASTA) / (HOMBRO_HASTA - CUERPO_HASTA)
		return CUELLO + (1.0 - CUELLO) * sqrt(maxf(1.0 - t * t, 0.0))
	return CUELLO


func _malla_tinaco() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cuerpo: del piso al cuello, con mas anillos de vertices donde cambia
	var perfil: Array[Vector2] = []
	var y := 0.0
	while y < HOMBRO_HASTA:
		perfil.append(Vector2(radio_en(y), y))
		y += 0.004 if y < CUERPO_HASTA else 0.008
	perfil.append(Vector2(CUELLO, HOMBRO_HASTA))
	_torno(st, perfil, _color_cuerpo)
	# Tapa de rosca: un aro con estrias y la tapa casi plana
	var tapa: Array[Vector2] = []
	var paso := (TAPA[2] - TAPA[1]) / 10.0
	for i in 11:
		var yy: float = TAPA[1] + paso * i
		tapa.append(Vector2(TAPA[0] * (1.0 + 0.02 * float(i % 2)), yy))
	_torno(st, tapa, func(_a, _y): return COLOR_TAPA)
	var arriba: Array[Vector2] = [Vector2(TAPA[0], TAPA[2]), Vector2(TAPA[0] * 0.8, TAPA[2] + 0.008), Vector2(TAPA[0] * 0.25, TAPA[2] + 0.014), Vector2(0.0, TAPA[2] + 0.015)]
	_torno(st, arriba, func(_a, _y): return COLOR_TAPA.lightened(0.06))
	st.generate_normals()
	var malla := st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	material.metallic_specular = 0.25
	malla.surface_set_material(0, material)
	return malla


# Mugre del plastico: lodo salpicado abajo, escurridos verdosos bajo cada anillo, sol en el hombro
func _color_cuerpo(ang: float, y: float) -> Color:
	var c := COLOR_PLASTICO
	var ruido := 0.5 + 0.25 * sin(ang * 7.0 + 1.1) + 0.25 * sin(ang * 17.0 + y * 9.0)
	var lodo := clampf(1.0 - y / (0.09 + 0.08 * ruido), 0.0, 1.0)
	var escurre := pow(clampf(0.5 + 0.5 * sin(ang * 23.0 + sin(ang * 5.0) * 2.0), 0.0, 1.0), 6.0) * clampf(1.0 - y / CUERPO_HASTA, 0.15, 1.0)
	c = c.lerp(COLOR_ESCURRE, escurre * 0.75)
	# Polvo parejo que baja hacia el pie
	c = c.lerp(COLOR_LODO, clampf(0.35 - y * 0.45, 0.0, 0.35) * ruido)
	c = c.lerp(COLOR_LODO, lodo * 0.85)
	if y > CUERPO_HASTA:
		c = c.lerp(COLOR_PLASTICO.lightened(0.08), 0.4).lerp(COLOR_ESCURRE, 0.18 * ruido)
	return c


# Gira el perfil (radio, alto en fracciones) con LADOS caras; los vertices del giro se comparten (sin costura),
# asi que generate_normals lo deja liso
func _torno(st: SurfaceTool, perfil: Array[Vector2], color: Callable) -> void:
	var base := _vertices
	for p in perfil:
		for l in LADOS:
			var ang := TAU * l / LADOS
			st.set_color(color.call(ang, p.y))
			st.add_vertex(Vector3(cos(ang) * p.x * radio, p.y * alto, sin(ang) * p.x * radio))
			_vertices += 1
	for i in perfil.size() - 1:
		for l in LADOS:
			var a := base + i * LADOS + l
			var b := base + i * LADOS + (l + 1) % LADOS
			var c := a + LADOS
			var d := b + LADOS
			# Horario visto desde afuera
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)

var _vertices := 0


# --- La Virgen ---

# La mancha de moho (textures/mapa/mancha_tinaco.png, tools/map_import/make_mancha_tinaco.py): un parche curvo
# pegado al cuerpo que sigue su contorno
func _mancha() -> MeshInstance3D:
	var y0 := MANCHA_DE
	var y1 := MANCHA_HASTA
	var a0 := MANCHA_RUMBO + MANCHA_ARCO / 2.0
	var a1 := MANCHA_RUMBO - MANCHA_ARCO / 2.0
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var filas := MANCHA_FILAS * 3   # mas filas para seguir los anillos
	for fila in range(filas + 1):
		var f := float(fila) / filas
		var y := lerpf(y1, y0, f)
		var r := radio * (1.0 + ANILLO_SALE + 0.004) + 0.006
		r = maxf(r, radio * radio_en(y) + 0.006)
		for col in range(MANCHA_COLUMNAS * 2 + 1):
			var c := float(col) / (MANCHA_COLUMNAS * 2)
			var ang := lerpf(a0, a1, c)
			vertices.append(Vector3(cos(ang) * r, y * alto, sin(ang) * r))
			uvs.append(Vector2(c, f))
	var ancho := MANCHA_COLUMNAS * 2 + 1
	for fila in filas:
		for col in ancho - 1:
			var i := fila * ancho + col
			indices.append_array([i, i + 1, i + ancho, i + 1, i + ancho + 1, i + ancho])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = MANCHA_TINACO
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	malla.surface_set_material(0, material)
	var instancia := MeshInstance3D.new()
	instancia.name = "ManchaVirgen"
	instancia.mesh = malla
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instancia


# --- La ofrenda ---

# Lo que la gente va y deja al pie de la mancha, sin orden pero no parejo: en una media luna pegada al tinaco,
# mas junto al centro de la mancha; las flores contra la pared y las veladoras al frente, prendidas. Todo va
# horneado en un MultiMesh por malla de cada modelo (y uno para las flamas), sin sombra y hasta OFRENDA_HASTA m:
# eran ~90 mallas sueltas con sombra
func _ofrenda(factor: float) -> Node3D:
	var ofrenda := Node3D.new()
	ofrenda.name = "Ofrenda"
	var azar := RandomNumberGenerator.new()
	azar.seed = 4711
	var flamas: Array[Transform3D] = []
	for tipo: Array in OFRENDA:
		var escena: PackedScene = tipo[0]
		var muestra := escena.instantiate() as Node3D
		var caja := Barricada._caja_de(muestra)
		# Las mallas del modelo con su transformacion, ya centrado y con la base en el piso
		var centrar := Transform3D(Basis.IDENTITY, Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z))
		var piezas := []
		for m: MeshInstance3D in muestra.find_children("*", "MeshInstance3D", true, false):
			if m.mesh == null:
				continue
			var t := Transform3D.IDENTITY
			var nodo: Node = m
			while nodo != muestra:
				t = (nodo as Node3D).transform * t
				nodo = nodo.get_parent()
			piezas.append([m.mesh, centrar * t, m.material_override])
		muestra.free()
		var escala: float = float(tipo[1]) / caja.size.y
		var es_vela := tipo == OFRENDA[1]
		var puestas: Array[Vector3] = []
		var lugares: Array[Transform3D] = []
		for i in roundi(int(tipo[2]) * factor * factor):
			# Lado: mas cerca del centro (suma de dos azares); fondo: hasta la orilla de su tipo
			var lado := (azar.randf() + azar.randf() - 1.0) * 1.15 * factor
			var fondo := absf(azar.randfn(0.0, 0.45)) * float(tipo[3]) * 0.6 * factor
			if es_vela:
				fondo += 0.15 * factor
			# Que no queden una dentro de otra
			var pos := _al_frente(radio + 0.12 + fondo, lado)
			var otra := false
			for p in puestas:
				if p.distance_to(pos) < float(tipo[1]) * (0.35 if es_vela else 0.3):
					otra = true
					break
			if otra:
				continue
			puestas.append(pos)
			var tam := escala * azar.randf_range(0.85, 1.15)
			var giro := Vector3(0.0, azar.randf_range(0.0, TAU), 0.0)
			if not es_vela:
				# Las flores se recargan un poco, unas hacia el tinaco y otras de lado
				giro.x = azar.randf_range(-0.25, 0.25)
				giro.z = azar.randf_range(-0.25, 0.25)
			lugares.append(Transform3D(Basis.from_euler(giro).scaled(Vector3.ONE * tam), pos))
			# Una de cada ocho ya se apago
			if es_vela and azar.randf() > 0.125:
				flamas.append(Transform3D(Basis.IDENTITY, pos + Vector3(0.0, caja.size.y * tam * VELA_FLAMA, 0.0)))
		for pieza: Array in piezas:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = pieza[0]
			mm.instance_count = lugares.size()
			for i in lugares.size():
				mm.set_instance_transform(i, lugares[i] * (pieza[1] as Transform3D))
			ofrenda.add_child(_horneado(mm, pieza[2]))
	_flamas_base = flamas
	_flamas = MultiMesh.new()
	_flamas.transform_format = MultiMesh.TRANSFORM_3D
	_flamas.mesh = _malla_flama()
	_flamas.instance_count = flamas.size()
	for i in flamas.size():
		_flamas.set_instance_transform(i, flamas[i])
	ofrenda.add_child(_horneado(_flamas, null))
	return ofrenda


func _horneado(mm: MultiMesh, material: Material) -> MultiMeshInstance3D:
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = mm
	instancia.material_override = material
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instancia.visibility_range_end = OFRENDA_HASTA
	return instancia


# Una flamita: dos planos cruzados con una gota de amarillo a naranja, sin luz propia (la da LuzVeladoras)
func _malla_flama() -> ArrayMesh:
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 8:
			var u := (x + 0.5) / 8.0 - 0.5
			var v := (y + 0.5) / 16.0          # 0 arriba
			var ancho := 0.42 * sin(PI * pow(v, 0.7))
			var a := 1.0 if absf(u) < ancho else 0.0
			var c := Color(1.0, 0.95, 0.6).lerp(Color(1.0, 0.45, 0.1), clampf(absf(u) / maxf(ancho, 0.01) * 0.8 + (1.0 - v) * 0.4, 0.0, 1.0))
			c.a = a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var material := StandardMaterial3D.new()
	material.albedo_texture = tex
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var w := 0.03
	var h := 0.075
	for eje in [Vector3.RIGHT, Vector3.BACK]:
		vertices.append_array([-eje * w, eje * w, eje * w + Vector3(0, h, 0), -eje * w, eje * w + Vector3(0, h, 0), -eje * w + Vector3(0, h, 0)])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malla.surface_set_material(0, material)
	return malla


# Petalos de cempasuchil y rosa regados en el piso alrededor de la ofrenda (un MultiMesh de cuadritos)
func _petalos(factor: float) -> MultiMeshInstance3D:
	var azar := RandomNumberGenerator.new()
	azar.seed = 1912
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.045)
	quad.orientation = PlaneMesh.FACE_Y
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	quad.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var n := roundi(PETALOS * factor * factor)
	mm.instance_count = n
	var colores := [Color(0.85, 0.36, 0.03), Color(0.8, 0.26, 0.02), Color(0.9, 0.5, 0.06), Color(0.6, 0.05, 0.09)]
	for i in n:
		var lado := azar.randfn(0.0, 0.5) * factor
		var fondo := absf(azar.randfn(0.0, 0.32)) * factor
		var pos := _al_frente(radio + 0.08 + fondo, lado) + Vector3(0.0, 0.004 + i * 0.00002, 0.0)
		var basis := Basis(Vector3.UP, azar.randf_range(0.0, TAU)).scaled(Vector3.ONE * azar.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var c: Color = colores[0 if azar.randf() < 0.45 else (1 if azar.randf() < 0.5 else (2 if azar.randf() < 0.7 else 3))]
		mm.set_instance_color(i, c.darkened(azar.randf_range(0.0, 0.35)))
	var instancia := MultiMeshInstance3D.new()
	instancia.name = "Petalos"
	instancia.visibility_range_end = OFRENDA_HASTA
	instancia.multimesh = mm
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instancia
