class_name TunelesNivel
extends Node3D
## Las cañerías del arroyo (P6, JJ 2026-11-21): el colector viejo por donde se llega al carcamo de la
## Madre, entrando por el tubo del arroyo de map_test. Como los colectores de ladrillo de las fotos de JJ:
## una boveda de medio punto de ladrillo con arcos cada ARCOS_CADA m, un canal hundido de agua en medio
## (alumbrado de azul desde abajo, con dos tubos blancos en el fondo) y dos pasillos de concreto a los
## lados. En los muros, nichos de arco oscuros: de ahi salen las crias (`nidos`). Al fondo, la puerta de
## GelA sobre el pasillo derecho; atras, el tubo por donde entra el agua del arroyo. Lo arma todo en
## codigo, como CarcamoNivel; Tuneles pone encima el enjambre, la vida y las flechas.
## Con `boca` arma solo los primeros BOCA_LARGO m, sin luces ni crias, para la boca de afuera en map_test
## (MuroColonia._boca): la misma boveda, el mismo canal y la misma reja oxidada, asi lo de afuera y lo de
## adentro coinciden. Todo el ladrillo es shaders/ladrillo_viejo.gdshader en coordenadas del tunel.
## Recto a proposito: las crias van derecho a su meta empujadas por el campo de distancia y en un
## laberinto se atoraban en las esquinas. El canal si lo cruzan: bajan y trepan por sus orillas.

const LARGO := 64.0
const BOCA_LARGO := 6.0         # lo que se ve del tunel desde afuera
const REJA_EN := 0.6            # m de la boca a la reja oxidada
const COLOR_OXIDO := Color(0.28, 0.15, 0.08)
const CANAL := 1.4              # ancho del canal de en medio
const PASILLO := 1.7            # ancho de cada pasillo
const ANCHO := CANAL + 2.0 * PASILLO   # 4.8 m de muro a muro
const HONDO := 0.6              # el fondo del canal bajo los pasillos
const AGUA := -0.25             # la superficie del agua
const MURO := 1.6               # altura del muro recto hasta donde arranca la boveda
const RADIO := ANCHO / 2.0      # la boveda de medio punto: la clave queda a MURO + RADIO = 4 m
const GRUESO := 0.5
const SEGMENTOS := 14           # lados de la boveda (PS1: se ven las caras)
const ARCOS_CADA := 8.0
const NICHO_ANCHO := 0.9
const NICHO_ALTO := 1.3         # hasta donde arranca su arco
const NICHOS_CADA := 8.0
const NICHOS_DESDE := 14.0      # m desde la entrada: el primero (no salen encima de ti)
const ALUMBRADO := preload("res://scripts/map/MapAlumbrado.gd")
const GOTA := "res://textures/logos-negocios/gela-gota.svg"
const COLOR_GELA := Color(0.12, 0.5, 0.78)
const COLOR_AGUA := Color(0.15, 0.45, 1.0)
const DRENAJE := preload("res://shaders/drenaje_serenol.gdshader")

## Donde aparece el jugador (pasillo derecho), la flecha de salida (el mismo pasillo, en el hueco de la reja) y
## la puerta del fondo (al carcamo, pasillo derecho)
const LADO_PASILLO := CANAL / 2.0 + PASILLO / 2.0
const ENTRADA := Vector3(LADO_PASILLO, 1.0, -2.0)
const SALIDA := Vector3(LADO_PASILLO, 0.0, -1.3)   # frente al hueco forzado de la reja
const FONDO := Vector3(LADO_PASILLO, 0.0, -LARGO + 1.4)
## Cuanto mide este tramo y si es la boca de afuera (ver arriba); se ponen antes de add_child
var largo := LARGO
var boca := false
## Luz ambiente (como CarcamoNivel.ambiente)
var ambiente := 0.1
## De donde salen las crias: frente a cada nicho, en el pasillo
var nidos := PackedVector3Array()

var _ladrillo: ShaderMaterial        # proyectado por la normal: muros planos
var _ladrillo_uv: ShaderMaterial     # con UV propias: la boveda, los arcos y las roscas
var _concreto: StandardMaterial3D
var _metal: StandardMaterial3D
var _negro: StandardMaterial3D
var _tubo_pvc: StandardMaterial3D
var _titilan: Array = []


func _ready() -> void:
	_materiales()
	_pasillos_y_canal()
	_muros_y_boveda()
	_arcos()
	_reja(-REJA_EN)
	if boca:
		_rosca()
		return
	_luz_de_afuera()
	_nichos()
	_escombro()
	_fondo()
	_luces()


# --- Materiales ---

func _materiales() -> void:
	# En coordenadas de este tunel: se arma ya puesto en su lugar (la posicion antes de add_child)
	_ladrillo = material_ladrillo(global_transform, false)
	_ladrillo_uv = material_ladrillo(global_transform, true)
	_concreto = StandardMaterial3D.new()
	_concreto.albedo_texture = CarcamoNivel._textura_ruido(128, 0.4, 0.07, 0.04, true, 31)
	_concreto.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_concreto.uv1_triplanar = true
	_concreto.uv1_scale = Vector3.ONE / 2.4
	_concreto.roughness = 0.9
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.32, 0.34, 0.35)
	_metal.metallic = 0.6
	_metal.roughness = 0.5
	_negro = StandardMaterial3D.new()
	_negro.albedo_color = Color.BLACK
	_negro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tubo_pvc = StandardMaterial3D.new()
	_tubo_pvc.albedo_color = Color(0.85, 0.87, 0.9)
	_tubo_pvc.roughness = 0.4


static var _texturas: Array[Texture2D] = []

## El ladrillo viejo (shaders/ladrillo_viejo) en coordenadas del tunel que esta en `tunel` (su transform
## global): MuroColonia lo usa en el muro de la boca, asi pega con el tunel. `usar_uv`: superficies con sus
## UV en unidades de la textura (la boveda); si no, se proyecta por la normal
static func material_ladrillo(tunel: Transform3D, usar_uv: bool) -> ShaderMaterial:
	if _texturas.is_empty():
		_texturas = [_textura_ladrillo(17), CarcamoNivel._ruido_tex(256, 0.012, 5, 41), CarcamoNivel._ruido_tex(256, 0.05, 3, 42)]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ladrillo_viejo.gdshader")
	material.set_shader_parameter("ladrillo", _texturas[0])
	material.set_shader_parameter("ruido", _texturas[1])
	material.set_shader_parameter("detalle", _texturas[2])
	material.set_shader_parameter("al_tunel", Projection(tunel.affine_inverse()))
	material.set_shader_parameter("usar_uv", usar_uv)
	material.set_shader_parameter("clave", MURO + RADIO)
	return material


# Ladrillo rojo en hiladas a soga (cada hilada corrida medio ladrillo), con juntas de mezcla sucia,
# ladrillos mas quemados, otros deslavados y grano: 64 x 64 px, 16 x 8 por ladrillo
static func _textura_ladrillo(semilla: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var imagen := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var mezcla := Color(0.55, 0.52, 0.46)
	for fila in 8:
		var corrido := 8 if fila % 2 == 1 else 0
		for col in 5:
			var tono := Color(0.52, 0.25, 0.16)
			var r := rng.randf()
			if r < 0.15:
				tono = Color(0.3, 0.15, 0.1)        # quemado
			elif r < 0.3:
				tono = Color(0.62, 0.42, 0.32)      # deslavado
			tono = tono.lerp(Color(0.45, 0.3, 0.22), rng.randf() * 0.4)
			for y in 8:
				for x in 16:
					var px := (col * 16 + x - corrido + 64) % 64
					var py := fila * 8 + y
					var junta := y == 7 or x == 15
					var c := mezcla if junta else tono
					var grano := rng.randf_range(-0.05, 0.05)
					imagen.set_pixel(px, py, Color(c.r + grano, c.g + grano, c.b + grano))
	return ImageTexture.create_from_image(imagen)


# --- Geometria ---

# Los dos pasillos son bloques macizos de concreto a nivel 0; entre ellos el canal, con su fondo,
# el drenaje con Serenol (sin choque) y los dos tubos blancos acostados en el fondo
func _pasillos_y_canal() -> void:
	var medio := -largo / 2.0
	for lado in [-1.0, 1.0]:
		_caja(Vector3(PASILLO, HONDO + GRUESO, largo), Vector3(lado * LADO_PASILLO, -(HONDO + GRUESO) / 2.0, medio), _concreto)
		# La orilla del canal: un borde de concreto un poco mas claro (solo se ve)
		var borde := _malla(Vector3(0.12, 0.04, largo), _concreto)
		borde.position = Vector3(lado * (CANAL / 2.0 + 0.06), 0.02, medio)
	_caja(Vector3(CANAL, GRUESO, largo), Vector3(0.0, -HONDO - GRUESO / 2.0, medio), _concreto)
	# Drenaje revuelto con Serenol (JJ): manchas cafes y azul brillante que corren hacia el carcamo
	var agua := ShaderMaterial.new()
	agua.shader = DRENAJE
	var superficie := _malla(Vector3(CANAL, 0.02, largo), agua)
	superficie.position = Vector3(0.0, AGUA, medio)
	for x in [-0.32, 0.3]:
		var tubo := _cilindro(0.13, largo, _tubo_pvc)
		tubo.rotation.x = PI / 2.0
		tubo.position = Vector3(x, -HONDO + 0.13, medio)


# Los muros rectos de ladrillo y la boveda de medio punto encima. La boveda se ve con sus UV (las
# hiladas corren a lo largo del tunel) y choca con una caja por cada lado, por fuera de la curva
func _muros_y_boveda() -> void:
	var medio := -largo / 2.0
	for lado in [-1.0, 1.0]:
		_caja(Vector3(GRUESO, MURO + HONDO, largo), Vector3(lado * (ANCHO + GRUESO) / 2.0, (MURO - HONDO) / 2.0, medio), _ladrillo)
	add_child(_boveda(0.0, -largo, RADIO, true))
	# Las paredes de los extremos, hasta la clave: la de la boca solo adentro (afuera es el hueco del
	# muro de MuroColonia) y la del fondo, en la boca, negra (lo que sigue no se ve)
	var alto := MURO + RADIO + HONDO
	if not boca:
		_caja(Vector3(ANCHO, alto, GRUESO), Vector3(0.0, (MURO + RADIO - HONDO) / 2.0, GRUESO / 2.0), _ladrillo)
	_caja(Vector3(ANCHO, alto, GRUESO), Vector3(0.0, (MURO + RADIO - HONDO) / 2.0, -largo - GRUESO / 2.0), _negro if boca else _ladrillo)


# Un tramo de boveda de medio punto de `z0` a `z1`, de radio `radio` (cara hacia adentro). Con `choque`,
# una caja de GRUESO detras de cada cara (las crias trepan por ella como por un muro)
func _boveda(z0: float, z1: float, radio: float, choque: bool) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arco := PI * radio / SEGMENTOS
	for i in SEGMENTOS:
		var a0 := PI * i / SEGMENTOS
		var a1 := PI * (i + 1) / SEGMENTOS
		var p0 := Vector2(cos(a0), sin(a0)) * radio
		var p1 := Vector2(cos(a1), sin(a1)) * radio
		var n := -Vector3(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0), 0.0)   # hacia el centro
		var v0 := Vector3(p0.x, MURO + p0.y, z0)
		var v1 := Vector3(p1.x, MURO + p1.y, z0)
		var v2 := Vector3(p1.x, MURO + p1.y, z1)
		var v3 := Vector3(p0.x, MURO + p0.y, z1)
		var u0 := z0 / 1.6
		var u1 := z1 / 1.6
		var t0 := arco * i / 0.8
		var t1 := arco * (i + 1) / 0.8
		for v: Array in [[v0, Vector2(u0, t0)], [v2, Vector2(u1, t1)], [v1, Vector2(u0, t1)],
				[v0, Vector2(u0, t0)], [v3, Vector2(u1, t0)], [v2, Vector2(u1, t1)]]:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var malla := MeshInstance3D.new()
	malla.mesh = st.commit()
	malla.material_override = _ladrillo_uv
	if not choque:
		return malla
	var cuerpo := StaticBody3D.new()
	cuerpo.add_child(malla)
	for i in SEGMENTOS:
		var a := PI * (i + 0.5) / SEGMENTOS
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(GRUESO, PI * radio / SEGMENTOS + 0.1, absf(z1 - z0))
		forma.shape = caja
		var r := radio + GRUESO / 2.0
		forma.position = Vector3(cos(a) * r, MURO + sin(a) * r, (z0 + z1) / 2.0)
		forma.rotation.z = a
		cuerpo.add_child(forma)
	return cuerpo


# Los arcos fajones: cada ARCOS_CADA m un arco de ladrillo que sobresale de la boveda, sobre dos
# pilastras en los muros (las pilastras chocan; el arco de arriba solo se ve)
func _arcos() -> void:
	var z := -4.0
	while z > -largo + 1.0:
		add_child(_boveda(z + 0.3, z - 0.3, RADIO - 0.15, false))
		# Las caras de los lados del arco (donde sobresale)
		for cara in [z + 0.3, z - 0.3]:
			var anillo := _anillo(RADIO - 0.15, RADIO, cara)
			add_child(anillo)
		for lado in [-1.0, 1.0]:
			_caja(Vector3(0.15, MURO, 0.6), Vector3(lado * (ANCHO / 2.0 - 0.075), MURO / 2.0, z), _ladrillo)
		z -= ARCOS_CADA


# La cara plana de un arco (entre dos radios), en el plano z
func _anillo(r0: float, r1: float, z: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTOS:
		var a0 := PI * i / SEGMENTOS
		var a1 := PI * (i + 1) / SEGMENTOS
		var q := [Vector3(cos(a0) * r0, MURO + sin(a0) * r0, z), Vector3(cos(a0) * r1, MURO + sin(a0) * r1, z),
			Vector3(cos(a1) * r1, MURO + sin(a1) * r1, z), Vector3(cos(a1) * r0, MURO + sin(a1) * r0, z)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(q[k].x / 1.6, q[k].y / 0.8))
			st.add_vertex(q[k])
	st.generate_normals()
	var malla := MeshInstance3D.new()
	malla.mesh = st.commit()
	malla.material_override = _ladrillo_uv
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return malla


# Los nichos de los muros, alternados: un arco de medio punto negro (el hueco) con su rosca de
# ladrillo. Las crias nacen enfrente, en el pasillo
func _nichos() -> void:
	var z := -NICHOS_DESDE
	var lado := 1.0
	while z > -largo + 6.0:
		var x: float = lado * (ANCHO / 2.0 - 0.01)
		var nodo := Node3D.new()
		nodo.position = Vector3(x, 0.0, z)
		nodo.rotation.y = -lado * PI / 2.0   # su +Z hacia el centro del tunel
		add_child(nodo)
		nodo.add_child(_arco_plano(NICHO_ANCHO / 2.0, NICHO_ALTO, 0.0, _negro))
		var rosca := _arco_plano(NICHO_ANCHO / 2.0 + 0.14, NICHO_ALTO, -0.005, _ladrillo_uv)
		rosca.position.z = -0.002
		nodo.add_child(rosca)
		nidos.append(Vector3(lado * (ANCHO / 2.0 - 0.8), 0.0, z))
		z -= NICHOS_CADA
		lado = -lado


# Un hueco de arco de medio punto en el plano XY local (ancho 2 x `medio`, recto hasta `alto`), mirando a +Z
func _arco_plano(medio: float, alto: float, z: float, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro := Vector3(0.0, alto * 0.6, z)
	var contorno: Array[Vector3] = [Vector3(medio, 0.0, z)]
	for i in 9:
		var a := PI * i / 8.0
		contorno.append(Vector3(cos(a) * medio, alto + sin(a) * medio, z))
	contorno.append(Vector3(-medio, 0.0, z))
	for i in contorno.size() - 1:
		for p: Vector3 in [centro, contorno[i], contorno[i + 1]]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(p.x / 1.6, p.y / 0.8))
			st.add_vertex(p)
	var malla := MeshInstance3D.new()
	malla.mesh = st.commit()
	malla.material_override = material
	return malla


# La reja oxidada que cierra la boca, a `z`: barrotes hasta la boveda, de muro a muro y del fondo del canal
# para arriba, con tres travesanos. Le faltan los barrotes frente al pasillo derecho (la forzaron: por
# ahi se mete uno). La misma desde afuera (la boca) y desde adentro
func _reja(z: float) -> void:
	var oxido := StandardMaterial3D.new()
	oxido.albedo_color = COLOR_OXIDO
	oxido.metallic = 0.3
	oxido.roughness = 0.8
	var barrotes: Array[Transform3D] = []
	var x := -ANCHO / 2.0 + 0.1
	while x < ANCHO / 2.0:
		var forzado := absf(x - LADO_PASILLO) < 0.45
		var arriba := MURO + sqrt(maxf(RADIO * RADIO - x * x, 0.0))
		var abajo := 0.0 if absf(x) > CANAL / 2.0 else -HONDO
		if forzado:
			# Los dos que quedan doblados, cortos
			arriba = MURO + 0.6
			abajo = 1.8
		var alto := arriba - abajo
		barrotes.append(Transform3D(Basis.from_scale(Vector3(1.0, alto, 1.0)), Vector3(x, (arriba + abajo) / 2.0, z)))
		x += 0.16
	var barrote := BoxMesh.new()
	barrote.size = Vector3(0.035, 1.0, 0.035)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = barrote
	multi.instance_count = barrotes.size()
	for i in barrotes.size():
		multi.set_instance_transform(i, barrotes[i])
	var reja := MultiMeshInstance3D.new()
	reja.multimesh = multi
	reja.material_override = oxido
	add_child(reja)
	for y in [0.15, 1.2, MURO]:
		for tramo: Vector2 in [Vector2(-ANCHO / 2.0, LADO_PASILLO - 0.45), Vector2(LADO_PASILLO + 0.45, ANCHO / 2.0)]:
			if y < 1.0 and tramo.x < 0.0:
				continue   # el de abajo solo va en el pasillo de la derecha, tras el hueco
			var t := _malla(Vector3(tramo.y - tramo.x, 0.05, 0.05), oxido)
			t.position = Vector3((tramo.x + tramo.y) / 2.0, y, z)


# Adentro, detras de la reja: el arco de la boca con la luz gris de afuera (el arroyo de dia o de noche,
# apenas), y un poco de esa luz entrando
func _luz_de_afuera() -> void:
	var afuera := StandardMaterial3D.new()
	afuera.albedo_color = Color(0.42, 0.47, 0.42)
	afuera.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arco := _arco_plano(RADIO - 0.02, MURO + HONDO, 0.0, afuera)
	arco.position = Vector3(0.0, -HONDO, -0.01)
	arco.rotation.y = PI
	add_child(arco)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.75, 0.82, 0.78)
	luz.light_energy = 0.35
	luz.omni_range = 6.0
	luz.position = Vector3(0.0, 1.8, -1.0)
	add_child(luz)


# En la boca de afuera: la rosca de ladrillo alrededor del arco, que sobresale del muro de MuroColonia
func _rosca() -> void:
	add_child(_boveda(0.18, 0.0, RADIO, false))
	add_child(_boveda(0.18, 0.0, RADIO + 0.45, false))
	add_child(_anillo(RADIO, RADIO + 0.45, 0.18))


# Lo viejo: montones de ladrillo caido junto a los muros (bajo un hueco de la boveda), charcos en los
# pasillos. Solo se ven (las crias no los sienten: no estorban al campo)
func _escombro() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var charco := StandardMaterial3D.new()
	charco.albedo_color = Color(0.03, 0.035, 0.04)
	charco.roughness = 0.05
	charco.metallic = 0.4
	for k in 9:
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var z := -rng.randf_range(6.0, largo - 4.0)
		var c := _malla(Vector3(rng.randf_range(0.5, 1.2), 0.01, rng.randf_range(0.6, 1.8)), charco)
		c.position = Vector3(lado * (LADO_PASILLO + rng.randf_range(-0.3, 0.3)), 0.006, z)
	for k in 5:
		var lado := 1.0 if k % 2 == 0 else -1.0
		var z := -rng.randf_range(10.0, largo - 6.0)
		# El hueco de arriba: un pedazo negro de boveda sin ladrillos
		var a := PI / 2.0 + lado * rng.randf_range(0.35, 0.8)
		var hueco := _malla(Vector3(0.02, rng.randf_range(0.6, 1.1), rng.randf_range(0.7, 1.4)), _negro)
		hueco.position = Vector3(cos(a) * (RADIO - 0.01), MURO + sin(a) * (RADIO - 0.01), z)
		hueco.rotation.z = a
		# Lo que se cayo, junto al muro de ese lado
		for n in rng.randi_range(10, 18):
			var pedazo := _malla(Vector3(0.24, 0.07, 0.11), _ladrillo)
			pedazo.position = Vector3(lado * (ANCHO / 2.0 - rng.randf_range(0.1, 0.7)), rng.randf_range(0.035, 0.2),
				z + rng.randf_range(-0.6, 0.6))
			pedazo.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))


# La puerta de acero de GelA al fondo, sobre el pasillo derecho, con su gota y el letrero; la flecha la
# pone Tuneles
func _fondo() -> void:
	var z := -largo + 0.05
	var marco := _malla(Vector3(1.5, 2.4, 0.1), _metal)
	marco.position = Vector3(LADO_PASILLO, 1.2, z)
	var puerta := StandardMaterial3D.new()
	puerta.albedo_color = Color(0.2, 0.3, 0.36)
	puerta.metallic = 0.5
	puerta.roughness = 0.6
	var hoja := _malla(Vector3(1.2, 2.2, 0.08), puerta)
	hoja.position = Vector3(LADO_PASILLO, 1.1, z + 0.06)
	var gota := Sprite3D.new()
	gota.texture = load(GOTA)
	gota.modulate = COLOR_GELA
	gota.pixel_size = 0.4 / maxf(gota.texture.get_width(), 1.0)
	gota.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gota.position = Vector3(LADO_PASILLO, 1.7, z + 0.11)
	add_child(gota)
	var letrero := Label3D.new()
	letrero.text = "CÁRCAMO 3\nSOLO PERSONAL GelA"
	letrero.font_size = 36
	letrero.pixel_size = 0.006
	letrero.modulate = Color(0.9, 0.92, 0.95)
	letrero.outline_size = 8
	letrero.position = Vector3(LADO_PASILLO, 1.15, z + 0.11)
	add_child(letrero)


# Como en las fotos: el canal alumbrado de azul desde abajo (luces bajo el agua cada 6 m) y, arriba,
# focos colgados de la clave cada 8 m, casi todos fundidos, dos titilan (Alumbrado.parpadeo). La puerta
# del fondo tiene su foco verde de emergencia
func _luces() -> void:
	var z := -2.0
	while z > -largo + 1.0:
		var azul := OmniLight3D.new()
		azul.light_color = COLOR_AGUA
		azul.light_energy = 0.6
		azul.omni_range = 4.0
		azul.position = Vector3(0.0, -0.4, z)
		add_child(azul)
		z -= 6.0
	var fundido := StandardMaterial3D.new()
	fundido.albedo_color = Color(0.22, 0.21, 0.19)
	var titilan := {-14.0: 23, -38.0: 57}   # z de los focos (cada 8 m desde -6) que titilan
	var chispas: Array[Vector3] = []
	var clave := MURO + RADIO
	z = -6.0
	while z > -largo + 2.0:
		var cable := _malla(Vector3(0.02, 0.5, 0.02), _metal)
		cable.position = Vector3(0.0, clave - 0.25, z)
		var prende := titilan.has(z)
		var foco: StandardMaterial3D = fundido
		if prende:
			foco = StandardMaterial3D.new()
			foco.albedo_color = Color(1, 0.95, 0.85)
			foco.emission_enabled = true
			foco.emission = Color(1, 0.85, 0.6)
			foco.emission_energy_multiplier = 2.5
		var bulbo := _malla(Vector3(0.14, 0.14, 0.14), foco)
		bulbo.position = Vector3(0.0, clave - 0.56, z)
		if prende:
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.82, 0.6)
			luz.light_energy = 1.2
			luz.omni_range = 8.0
			luz.position = Vector3(0.0, clave - 0.7, z)
			add_child(luz)
			_titilan.append([luz, foco, titilan[z], luz.light_energy])
			chispas.append(Vector3(0.0, clave - 0.6, z))
		z -= 8.0
	if not chispas.is_empty():
		var nodo: Node3D = ALUMBRADO.armar_chispas(chispas, 0.0)
		if nodo:
			add_child(nodo)
	var verde := OmniLight3D.new()
	verde.light_color = Color(0.3, 1.0, 0.45)
	verde.light_energy = 0.5
	verde.omni_range = 4.0
	verde.position = Vector3(LADO_PASILLO, 2.6, -largo + 0.6)
	add_child(verde)
	var mundo := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.0, 0.0, 0.02)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.35, 0.38, 0.6)
	entorno.ambient_light_energy = ambiente
	entorno.fog_enabled = true
	entorno.fog_light_color = Color(0.02, 0.03, 0.08)
	entorno.fog_density = 0.045
	mundo.environment = entorno
	add_child(mundo)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for foco in _titilan:
		var brillo := Alumbrado.parpadeo(foco[2], t)
		(foco[0] as Light3D).light_energy = foco[3] * brillo
		(foco[1] as StandardMaterial3D).emission_energy_multiplier = 2.5 * brillo


# --- Piezas ---

func _caja(medida: Vector3, donde: Vector3, material: Material) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medida
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medida
	bm.material = material
	malla.mesh = bm
	cuerpo.add_child(malla)
	cuerpo.position = donde
	add_child(cuerpo)
	return cuerpo


func _malla(medida: Vector3, material: Material) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medida
	bm.material = material
	malla.mesh = bm
	add_child(malla)
	return malla


func _cilindro(radio: float, alto: float, material: Material) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = alto
	cm.radial_segments = 12
	cm.material = material
	malla.mesh = cm
	add_child(malla)
	return malla
