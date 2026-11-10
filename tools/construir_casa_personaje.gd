extends SceneTree

# Arma scenes/casa_personaje.tscn: la casa del personaje (sala-comedor con la puerta de salida
# y un cuarto con cama), con los modelos de models/casa_personaje/ (Sketchfab, ver CREDITS.md).
#
#   godot --path . --headless --script res://tools/construir_casa_personaje.gd
#
# Medidas en metros, piso en y=0. Sala: x 0..5.5, z 0..4.5. Cuarto: x 5.5..8, z 0..4.5, unido
# a la sala por un vano en x=5.5. La puerta de salida esta en la pared oeste (x=0).

const SALIDA := "res://scenes/casa_personaje.tscn"
const MODELOS := "res://models/casa_personaje/%s/%s.glb"
const ALTO := 2.6
const GRUESO := 0.15

var _raiz: Node3D
var _mat_pared: StandardMaterial3D


func _init() -> void:
	_raiz = Node3D.new()
	_raiz.name = "CasaPersonaje"
	_raiz.set_script(load("res://scripts/CasaPersonaje.gd"))
	_mat_pared = _material_textura("pared", 1.0, 0.95)

	_construir_cascaron()
	_amueblar()
	_luces()

	var paquete := PackedScene.new()
	paquete.pack(_raiz)
	var err := ResourceSaver.save(paquete, SALIDA)
	print("guardado ", SALIDA, " -> ", error_string(err))
	_raiz.free()
	quit()


func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	return m


# Material con una textura de textures/casa_personaje/ proyectada con coordenadas de mundo, para
# que siga continua de una caja a otra; "periodo" es lo que mide en metros una repeticion.
func _material_textura(archivo: String, periodo: float, rugosidad: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/casa_personaje/%s.png" % archivo)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / periodo
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = rugosidad
	return m


# Caja visible y con colision; (x0,z0)-(x1,z1) en planta, de y0 a y1.
func _caja(nombre: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
		mat: Material, padre: Node = null, colision := true) -> void:
	var tam := Vector3(x1 - x0, y1 - y0, z1 - z0)
	var centro := Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	var cuerpo: Node3D = StaticBody3D.new() if colision else Node3D.new()
	cuerpo.name = nombre
	cuerpo.position = centro
	(padre if padre else _raiz).add_child(cuerpo)
	cuerpo.owner = _raiz
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	caja.material = mat
	malla.mesh = caja
	cuerpo.add_child(malla)
	malla.owner = _raiz
	if colision:
		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		var box := BoxShape3D.new()
		box.size = tam
		forma.shape = box
		cuerpo.add_child(forma)
		forma.owner = _raiz


# Pared recta con vanos; vanos = [[desde, hasta, y_bajo, y_alto], ...] a lo largo de la pared.
# Si es_x la pared corre a lo largo de x (z fijo), si no a lo largo de z (x fijo).
func _pared(nombre: String, es_x: bool, fijo: float, desde: float, hasta: float, vanos: Array) -> void:
	var grupo := Node3D.new()
	grupo.name = nombre
	_raiz.add_child(grupo)
	grupo.owner = _raiz
	var corte := desde
	var n := 0
	vanos.sort_custom(func(a, b): return a[0] < b[0])
	for v in vanos:
		if v[0] > corte:
			_tramo(grupo, n, es_x, fijo, corte, v[0], 0.0, ALTO); n += 1
		if v[2] > 0.0:
			_tramo(grupo, n, es_x, fijo, v[0], v[1], 0.0, v[2]); n += 1
		if v[3] < ALTO:
			_tramo(grupo, n, es_x, fijo, v[0], v[1], v[3], ALTO); n += 1
		corte = v[1]
	if corte < hasta:
		_tramo(grupo, n, es_x, fijo, corte, hasta, 0.0, ALTO)


func _tramo(grupo: Node, n: int, es_x: bool, fijo: float, a: float, b: float, y0: float, y1: float) -> void:
	var h := GRUESO / 2.0
	if es_x:
		_caja("Tramo%d" % n, a, b, y0, y1, fijo - h, fijo + h, _mat_pared, grupo)
	else:
		_caja("Tramo%d" % n, fijo - h, fijo + h, y0, y1, a, b, _mat_pared, grupo)


func _construir_cascaron() -> void:
	var mat_piso := _material_textura("piso", 0.8, 0.35)
	var mat_techo := _material_textura("techo", 1.0, 1.0)
	_caja("Piso", 0.0, 8.0, -0.1, 0.0, 0.0, 4.5, mat_piso)
	_caja("Techo", 0.0, 8.0, ALTO, ALTO + 0.1, 0.0, 4.5, mat_techo)

	# Pared oeste con el vano de la puerta de salida (z 2.56..3.66, 2.0 m de alto, centrada entre
	# la orilla de la ventana y la pared sur) y, al lado, el de la ventana con reja (z 0.35..1.8, y 0.95..2.0)
	_pared("ParedOeste", false, 0.0, 0.0, 4.5, [[2.56, 3.66, 0.0, 2.0], [0.35, 1.8, 0.95, 2.0]])
	# Pared este del cuarto
	_pared("ParedEste", false, 8.0, 0.0, 4.5, [])
	# Pared norte, corrida de lado a lado
	_pared("ParedNorte", true, 0.0, 0.0, 8.0, [])
	# Pared sur, corrida de lado a lado
	_pared("ParedSur", true, 4.5, 0.0, 8.0, [])
	# Pared divisoria con el vano al cuarto (z 1.05..2.05, 1.95 m de alto: la luz libre de la puerta)
	_pared("ParedDivisoria", false, 5.5, 0.0, 4.5, [[1.05, 2.05, 0.0, 1.95]])

	_ventana_oeste()


# Barra delgada en la pared oeste (plano y-z): del punto a al b, con el grosor dado.
func _barra(grupo: Node, nombre: String, a: Vector2, b: Vector2, x: float, grosor: float, mat: Material) -> void:
	var dir := b - a
	var malla := MeshInstance3D.new()
	malla.name = nombre
	var caja := BoxMesh.new()
	caja.size = Vector3(grosor, dir.length(), grosor)
	caja.material = mat
	malla.mesh = caja
	malla.position = Vector3(x, (a.x + b.x) / 2.0, (a.y + b.y) / 2.0)
	# el eje largo de la caja es y; se gira sobre x hasta alinearlo con dir (y, z)
	malla.rotation.x = atan2(dir.y, dir.x)
	grupo.add_child(malla)
	malla.owner = _raiz


# Ventana de la foto de referencia: marco blanco con tres cuerpos de vidrio opaco y, por fuera,
# la reja blanca de herreria (barra al centro, rombo y argolla en cada cuerpo).
func _ventana_oeste() -> void:
	const Z0 := 0.35
	const Z1 := 1.8
	const Y0 := 0.95
	const Y1 := 2.0
	var blanco := _material(Color(0.93, 0.93, 0.9), 0.5)
	var vidrio := _material(Color(0.82, 0.88, 0.88, 0.55), 0.15)
	vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grupo := Node3D.new()
	grupo.name = "VentanaOeste"
	_raiz.add_child(grupo)
	grupo.owner = _raiz
	var h := GRUESO / 2.0
	# vidrio y marco, del lado de adentro de la pared (x > 0)
	_caja("Vidrio", -0.01, 0.01, Y0, Y1, Z0, Z1, vidrio, grupo, false)
	_caja("MarcoArriba", -0.02, h + 0.02, Y1 - 0.04, Y1 + 0.02, Z0 - 0.02, Z1 + 0.02, blanco, grupo, false)
	_caja("MarcoAbajo", -0.02, h + 0.02, Y0 - 0.02, Y0 + 0.04, Z0 - 0.02, Z1 + 0.02, blanco, grupo, false)
	_caja("MarcoNorte", -0.02, h + 0.02, Y0 - 0.02, Y1 + 0.02, Z0 - 0.02, Z0 + 0.04, blanco, grupo, false)
	_caja("MarcoSur", -0.02, h + 0.02, Y0 - 0.02, Y1 + 0.02, Z1 - 0.04, Z1 + 0.02, blanco, grupo, false)
	var ancho := (Z1 - Z0) / 3.0
	for k in [1, 2]:
		var zc: float = Z0 + ancho * k
		_caja("Divisor%d" % k, -0.02, h + 0.02, Y0, Y1, zc - 0.025, zc + 0.025, blanco, grupo, false)
	# la hoja corrediza (el primer cuerpo) lleva un travesaño
	_caja("Travesano", -0.02, h + 0.02, 1.62, 1.67, Z0, Z0 + ancho, blanco, grupo, false)
	# repisa
	_caja("Repisa", h - 0.01, h + 0.08, Y0 - 0.05, Y0, Z0 - 0.05, Z1 + 0.05, blanco, grupo, false)
	# reja por fuera (x < 0): por cada cuerpo, una barra al centro, un rombo y una argolla
	var xr := -h - 0.02
	for k in 3:
		var za := Z0 + ancho * k
		var zb := za + ancho
		var zm := (za + zb) / 2.0
		var ym := (Y0 + Y1) / 2.0
		var dz := ancho / 2.0 - 0.04
		var dy := (Y1 - Y0) / 2.0 - 0.04
		_barra(grupo, "Barra%d" % k, Vector2(Y0 + 0.03, zm), Vector2(Y1 - 0.03, zm), xr, 0.02, blanco)
		var puntas := [Vector2(ym + dy, zm), Vector2(ym, zm + dz), Vector2(ym - dy, zm), Vector2(ym, zm - dz)]
		for i in 4:
			_barra(grupo, "Rombo%d_%d" % [k, i], puntas[i], puntas[(i + 1) % 4], xr, 0.015, blanco)
		var argolla := MeshInstance3D.new()
		argolla.name = "Argolla%d" % k
		var toro := TorusMesh.new()
		toro.inner_radius = 0.055
		toro.outer_radius = 0.075
		toro.material = blanco
		argolla.mesh = toro
		argolla.position = Vector3(xr, ym, zm)
		argolla.rotation.z = PI / 2.0   # el aro mira hacia la calle
		grupo.add_child(argolla)
		argolla.owner = _raiz


# Puerta de salida de herreria, toda de metal pintado de blanco, en el vano de la pared oeste
# (z 2.56..3.66, 2.0 m de alto): marco, hoja con panel acanalado abajo, vidrio con reja de rombos
# arriba y una rejilla de ventilacion en lo alto, bisagras y manija. Cerrada y sin colision,
# como el resto de la decoracion; la abre quien la programe.
func _puerta_salida() -> void:
	const Z0 := 2.56
	const Z1 := 3.66
	const ALTO_VANO := 2.0
	var blanco := _material(Color(0.93, 0.93, 0.9), 0.5)
	var vidrio := _material(Color(0.8, 0.9, 0.9, 0.4), 0.15)
	vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grupo := Node3D.new()
	grupo.name = "PuertaSalida"
	_raiz.add_child(grupo)
	grupo.owner = _raiz
	var h := GRUESO / 2.0
	# marco: dos jambas y el dintel, a ras de los dos lados de la pared
	_caja("JambaNorte", -h - 0.01, h + 0.01, 0.0, ALTO_VANO, Z0, Z0 + 0.05, blanco, grupo, false)
	_caja("JambaSur", -h - 0.01, h + 0.01, 0.0, ALTO_VANO, Z1 - 0.05, Z1, blanco, grupo, false)
	_caja("Dintel", -h - 0.01, h + 0.01, ALTO_VANO - 0.05, ALTO_VANO, Z0, Z1, blanco, grupo, false)
	# hoja: tubos del borde y travesanos
	var a := Z0 + 0.05
	var b := Z1 - 0.05
	var top := ALTO_VANO - 0.05
	_caja("HojaNorte", -0.03, 0.03, 0.0, top, a, a + 0.07, blanco, grupo, false)
	_caja("HojaSur", -0.03, 0.03, 0.0, top, b - 0.07, b, blanco, grupo, false)
	_caja("HojaArriba", -0.03, 0.03, top - 0.07, top, a, b, blanco, grupo, false)
	_caja("HojaAbajo", -0.03, 0.03, 0.0, 0.08, a, b, blanco, grupo, false)
	_caja("TravesanoMedio", -0.03, 0.03, 0.93, 1.0, a, b, blanco, grupo, false)
	_caja("TravesanoVentila", -0.03, 0.03, 1.74, 1.8, a, b, blanco, grupo, false)
	# panel de abajo: lamina con nervaduras verticales por los dos lados
	_caja("Lamina", -0.012, 0.012, 0.08, 0.93, a + 0.07, b - 0.07, blanco, grupo, false)
	var z := a + 0.12
	var n := 0
	while z < b - 0.1:
		_caja("Nervio%d" % n, 0.012, 0.03, 0.1, 0.91, z, z + 0.035, blanco, grupo, false)
		_caja("NervioFuera%d" % n, -0.03, -0.012, 0.1, 0.91, z, z + 0.035, blanco, grupo, false)
		z += 0.095
		n += 1
	# vidrio de la ventana de la hoja y su reja de rombos por fuera
	var vz0 := a + 0.07
	var vz1 := b - 0.07
	var vy0 := 1.0
	var vy1 := 1.74
	_caja("Vidrio", -0.005, 0.005, vy0, vy1, vz0, vz1, vidrio, grupo, false)
	var zm := (vz0 + vz1) / 2.0
	var ym := (vy0 + vy1) / 2.0
	var dz := (vz1 - vz0) / 2.0 - 0.02
	var dy := (vy1 - vy0) / 2.0 - 0.02
	var xr := -0.045
	_barra(grupo, "BarraCentro", Vector2(vy0, zm), Vector2(vy1, zm), xr, 0.02, blanco)
	_barra(grupo, "BarraMedia", Vector2(ym, vz0), Vector2(ym, vz1), xr, 0.02, blanco)
	var puntas := [Vector2(ym + dy, zm), Vector2(ym, zm + dz), Vector2(ym - dy, zm), Vector2(ym, zm - dz)]
	for i in 4:
		_barra(grupo, "Rombo%d" % i, puntas[i], puntas[(i + 1) % 4], xr, 0.02, blanco)
	# rejilla de ventilacion de arriba: vidrio con tablillas horizontales
	_caja("VidrioVentila", -0.005, 0.005, 1.8, top - 0.07, vz0, vz1, vidrio, grupo, false)
	var yv := 1.82
	while yv < top - 0.09:
		_caja("Tablilla%d" % int(yv * 100.0), -0.02, 0.02, yv, yv + 0.015, vz0, vz1, blanco, grupo, false)
		yv += 0.05
	# bisagras en el lado norte y cerrojo con manija en el sur
	for y in [0.25, 1.0, 1.75]:
		_caja("Bisagra%d" % int(y * 100.0), -0.05, 0.05, y - 0.05, y + 0.05, a - 0.02, a + 0.02, blanco, grupo, false)
	_caja("PlacaCerradura", -0.035, 0.035, 0.8, 0.93, b - 0.07, b - 0.01, blanco, grupo, false)
	_caja("Manija", 0.035, 0.1, 0.84, 0.88, b - 0.2, b - 0.04, blanco, grupo, false)
	_caja("ManijaFuera", -0.1, -0.035, 0.84, 0.88, b - 0.2, b - 0.04, blanco, grupo, false)


# Mide la caja de un modelo con sus transformaciones, en el espacio de su raiz.
func _caja_de(nodo: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if nodo is Node3D:
		t = xf * (nodo as Node3D).transform
	if nodo is MeshInstance3D and nodo.mesh:
		acc.append(t * nodo.mesh.get_aabb())
	for h in nodo.get_children():
		_caja_de(h, t, acc)


func _caja_total(nodo: Node3D) -> AABB:
	var acc: Array = []
	_caja_de(nodo, Transform3D.IDENTITY, acc)
	var u: AABB = acc[0]
	for a in acc:
		u = u.merge(a)
	return u


# Mete un modelo: lo escala a "largo" metros en su eje mas largo si largo > 0, si no usa
# "escala". Lo apoya en y=ybase con el centro de la huella en (x, z) y lo gira "giro" grados.
# Devuelve el nodo contenedor.
func _mueble(nombre: String, modelo: String, x: float, z: float, giro: float, escala: float,
		ybase := 0.0, colision := true) -> Node3D:
	var contenedor := Node3D.new()
	contenedor.name = nombre
	_raiz.add_child(contenedor)
	contenedor.owner = _raiz
	var inst: Node3D = (load(MODELOS % [modelo, modelo]) as PackedScene).instantiate()
	inst.name = "Modelo"
	inst.scale = Vector3.ONE * escala
	contenedor.add_child(inst)
	inst.owner = _raiz
	var caja := _caja_total(inst)
	# centra la huella en el origen del contenedor y apoya la base en y=0
	inst.position = Vector3(-(caja.position.x + caja.size.x / 2.0), -caja.position.y, -(caja.position.z + caja.size.z / 2.0))
	contenedor.position = Vector3(x, ybase, z)
	contenedor.rotation_degrees.y = giro
	if colision:
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Colision"
		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		var box := BoxShape3D.new()
		box.size = caja.size
		forma.shape = box
		forma.position = Vector3(0, caja.size.y / 2.0, 0)
		cuerpo.add_child(forma)
		contenedor.add_child(cuerpo)
		cuerpo.owner = _raiz
		forma.owner = _raiz
	return contenedor


func _amueblar() -> void:
	_puerta_salida()

	# --- Sala-comedor ---
	_mueble("Sillon", "sillon", 2.0, 0.62, 0.0, 0.01)
	_mueble("Vitrina", "vitrina", 4.3, 0.37, 0.0, 1.0)
	# mesita de la tele pegada a la pared sur, enfrente del sillon, con otra tele encima mirando a el
	var alto_mesita := _mesita("MesitaTele", 2.0, 4.2)
	_mueble("Tele2", "tele", 2.0, 4.2, 90.0, 0.65, alto_mesita, false)
	# comedor a lo largo de z, en el lado este de la sala; las sillas van metidas 15 cm bajo la mesa
	_mueble("Mesa", "mesa", 4.25, 3.15, 0.0, 2.2 / 388.137)
	_mueble("Silla1", "silla", 3.62, 2.7, 90.0, 1.0)
	_mueble("Silla2", "silla", 3.62, 3.6, 90.0, 1.0)
	_mueble("Silla3", "silla", 4.9, 2.7, -90.0, 1.0)
	_mueble("Silla4", "silla", 4.9, 3.6, -90.0, 1.0)
	_mueble("Silla5", "silla", 4.25, 1.96, 0.0, 1.0)

	# --- Cuarto ---
	_mueble("Cama", "cama", 7.42, 1.2, 0.0, 0.047)
	var closet := _mueble("Closet", "closet", 7.2, 4.0, 180.0, 1.0)
	var alto_closet := _caja_total(closet.get_node("Modelo")).size.y
	_mueble("Tele", "tele", 7.2, 4.0, 90.0, 0.65, alto_closet, false)


# Mesita baja de madera (tapa y cuatro patas), solo para apoyar la tele. Devuelve la altura de
# la tapa. Hecha con codigo; el color es el de la madera de las sillas.
func _mesita(nombre: String, x: float, z: float) -> float:
	const ANCHO := 0.9
	const FONDO := 0.45
	const ALTURA := 0.5
	const TAPA := 0.04
	var madera := _material(Color(0.42, 0.28, 0.16), 0.8)
	var grupo := Node3D.new()
	grupo.name = nombre
	_raiz.add_child(grupo)
	grupo.owner = _raiz
	_caja("Tapa", x - ANCHO / 2.0, x + ANCHO / 2.0, ALTURA - TAPA, ALTURA, z - FONDO / 2.0, z + FONDO / 2.0, madera, grupo)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			var px: float = x + dx * (ANCHO / 2.0 - 0.05)
			var pz: float = z + dz * (FONDO / 2.0 - 0.05)
			_caja("Pata%d%d" % [dx + 1, dz + 1], px - 0.025, px + 0.025, 0.0, ALTURA - TAPA, pz - 0.025, pz + 0.025, madera, grupo, false)
	return ALTURA


func _luces() -> void:
	var ambiente := WorldEnvironment.new()
	ambiente.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.85)
	env.ambient_light_energy = 0.35
	ambiente.environment = env
	_raiz.add_child(ambiente)
	ambiente.owner = _raiz
	for datos in [["FocoSala", Vector3(2.75, 2.45, 2.25), 5.5], ["FocoCuarto", Vector3(6.75, 2.45, 2.25), 4.0]]:
		var foco := OmniLight3D.new()
		foco.name = datos[0]
		foco.position = datos[1]
		foco.omni_range = datos[2]
		foco.light_color = Color(1.0, 0.93, 0.78)
		foco.light_energy = 1.6
		foco.shadow_enabled = true
		_raiz.add_child(foco)
		foco.owner = _raiz
