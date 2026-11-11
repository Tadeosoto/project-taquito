extends SceneTree

# Arma las casas de los vecinos de Santa Mugre (scenes/casas/<quien>.tscn): un cuarto de 6 x 5 m
# con la puerta en la pared oeste en el mismo lugar que la casa de JJ (z = 3.11, asi CasaPropia.gd
# las entra con sus mismos ADENTRO y PUERTA), las texturas de textures/casa_personaje/, los muebles
# de Sketchfab de models/casa_personaje/ (con las escalas de tools/construir_casa_personaje.gd) y
# cosas hechas con cajas. La raiz lleva scripts/interiores/CasaVecino.gd, que pone a quien vive.
#
#   godot --path . --headless --script res://tools/construir_casas_vecinos.gd

const SALIDA := "res://scenes/casas/%s.tscn"
const MODELOS := "res://models/casa_personaje/%s/%s.glb"
const ANCHO := 6.0          # x
const FONDO := 5.0          # z
const ALTO := 2.6
const GRUESO := 0.15
const PUERTA_Z := 3.11
const PUERTA_ANCHO := 1.0
const PUERTA_ALTO := 2.1
# Las escalas de los modelos de JJ (tools/construir_casa_personaje.gd)
const ESCALA := {"sillon": 0.01, "vitrina": 1.0, "tele": 0.975, "mesa": 2.2 / 388.137, "silla": 1.0,
		"cama": 0.047, "closet": 1.0}

var _raiz: Node3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/casas")
	_casa("guero", Color(0.85, 0.82, 0.7), _amueblar_guero)
	_casa("sofia", Color(0.45, 0.5, 0.55), _amueblar_sofia)
	_casa("tono", Color(0.95, 0.7, 0.45), _amueblar_tono)
	_casa("clausurada", Color(0.6, 0.58, 0.5), _amueblar_clausurada)
	quit()


func _casa(quien: String, color_pared: Color, amueblar: Callable) -> void:
	_raiz = Node3D.new()
	_raiz.name = "Casa_" + quien
	_raiz.set_script(load("res://scripts/interiores/CasaVecino.gd"))
	_raiz.set("quien", quien)
	# Paredes de aplanado blanco (textures/mapa/) tenido del color de cada casa: el pared.png de JJ es
	# turquesa y tenido no da otros colores
	var pared := _textura("pared", 1.0, color_pared, "res://textures/mapa/aplanado_blanco.png")
	var piso := _textura("piso", 1.0, Color.WHITE)
	var techo := _textura("techo", 1.0, Color.WHITE)
	_caja("Piso", 0, ANCHO, -0.1, 0, 0, FONDO, piso)
	_caja("Techo", 0, ANCHO, ALTO, ALTO + 0.1, 0, FONDO, techo)
	_caja("ParedNorte", 0, ANCHO, 0, ALTO, -GRUESO, 0, pared)
	_caja("ParedSur", 0, ANCHO, 0, ALTO, FONDO, FONDO + GRUESO, pared)
	_caja("ParedEste", ANCHO, ANCHO + GRUESO, 0, ALTO, 0, FONDO, pared)
	# La oeste con el hueco de la puerta (y la puerta de madera abierta contra la pared)
	var z0 := PUERTA_Z - PUERTA_ANCHO / 2.0
	var z1 := PUERTA_Z + PUERTA_ANCHO / 2.0
	_caja("ParedOeste0", -GRUESO, 0, 0, ALTO, 0, z0, pared)
	_caja("ParedOeste1", -GRUESO, 0, 0, ALTO, z1, FONDO, pared)
	_caja("ParedOesteDintel", -GRUESO, 0, PUERTA_ALTO, ALTO, z0, z1, pared)
	_caja("Puerta", 0.0, 0.05, 0, PUERTA_ALTO, z1, z1 + PUERTA_ANCHO * 0.9, _color(Color(0.4, 0.25, 0.15)), false)
	var foco := OmniLight3D.new()
	foco.name = "Foco"
	foco.position = Vector3(ANCHO / 2.0, ALTO - 0.15, FONDO / 2.0)
	foco.omni_range = 6.0
	foco.light_energy = 1.6 if quien != "clausurada" else 0.6
	foco.light_color = Color(1.0, 0.92, 0.75) if quien != "sofia" else Color(0.75, 0.85, 1.0)
	_raiz.add_child(foco)
	foco.owner = _raiz
	amueblar.call()
	var paquete := PackedScene.new()
	paquete.pack(_raiz)
	print("guardado ", SALIDA % quien, " -> ", error_string(ResourceSaver.save(paquete, SALIDA % quien)))
	_raiz.free()


# --- Muebles de cada casa (el vecino va en CasaVecino.PERSONA_EN, 4.2, 2.5) ---

func _amueblar_guero() -> void:
	# Ordenado, de oficinista: mesa con papeles y el sello, el closet, la tele y su vitrina
	_mueble("Mesa", "mesa", 3.0, 1.2, 0.0)
	_mueble("Silla1", "silla", 3.0, 0.5, 0.0)
	for i in 4:
		_caja("Papeles%d" % i, 2.3 + i * 0.4, 2.6 + i * 0.4, 0.78, 0.78 + 0.04 + i * 0.03, 1.0, 1.3, _color(Color(0.95, 0.95, 0.9)), false)
	_caja("Sello", 3.9, 4.0, 0.78, 0.9, 1.1, 1.2, _color(Color(0.1, 0.1, 0.1)), false)
	_mueble("Closet", "closet", 5.5, 4.4, 180.0)
	_mueble("Vitrina", "vitrina", 5.6, 0.4, 0.0)
	_mueble("Sillon", "sillon", 1.6, 4.5, 180.0)


func _amueblar_sofia() -> void:
	# El taller con la radio: mesa de trabajo con el transmisor, la antena al techo, cables,
	# una bateria de carro, llantas y la tele vieja que hace de monitor
	_mueble("Mesa", "mesa", 3.0, 0.8, 0.0)
	_caja("Transmisor", 2.4, 3.2, 0.78, 1.15, 0.6, 1.0, _color(Color(0.2, 0.22, 0.2)), false)
	_caja("Perillas", 2.5, 3.1, 0.95, 1.05, 1.0, 1.02, _color(Color(0.8, 0.6, 0.2)), false)
	_caja("Microfono", 3.4, 3.5, 0.78, 1.05, 0.9, 1.0, _color(Color(0.1, 0.1, 0.1)), false)
	_caja("Antena", 2.75, 2.8, 1.15, ALTO, 0.75, 0.8, _color(Color(0.5, 0.5, 0.5)), false)
	_mueble("Tele", "tele", 4.0, 0.6, 0.0, 0.78, false)
	_caja("Bateria", 1.0, 1.4, 0, 0.25, 0.3, 0.55, _color(Color(0.15, 0.15, 0.15)))
	for i in 3:
		_cilindro("Llanta%d" % i, Vector3(5.3, i * 0.24, 4.3), 0.35, 0.22, Color(0.08, 0.08, 0.08))
	_mueble("Silla1", "silla", 3.0, 1.5, 180.0)
	_mueble("Cama", "cama", 5.2, 1.4, 0.0)
	_caja("Cortina", ANCHO - 0.02, ANCHO, 0.8, 2.2, 2.0, 3.6, _color(Color(0.1, 0.1, 0.15)), false)


func _amueblar_tono() -> void:
	# La casa del tianguista: cajas de fruta apiladas, su mesa y la tele
	_mueble("Mesa", "mesa", 3.2, 4.2, 90.0)
	_mueble("Silla1", "silla", 2.2, 4.2, 90.0)
	_mueble("Sillon", "sillon", 1.6, 0.6, 0.0)
	_mueble("Tele", "tele", 5.5, 2.5, -90.0, 0.0, false)
	var frutas := [Color(0.95, 0.5, 0.1), Color(0.8, 0.15, 0.1), Color(0.95, 0.85, 0.2), Color(0.3, 0.6, 0.2)]
	for i in 6:
		var x := 4.6 + (i % 2) * 0.65
		var y := (i / 2) * 0.32
		_caja("Caja%d" % i, x, x + 0.6, y, y + 0.3, 0.2, 0.6, _color(Color(0.55, 0.38, 0.22)))
		_caja("Fruta%d" % i, x + 0.05, x + 0.55, y + 0.24, y + 0.31, 0.25, 0.55, _color(frutas[i % frutas.size()]), false)
	_mueble("Cama", "cama", 5.3, 4.0, 90.0)


func _amueblar_clausurada() -> void:
	# Abandonada: el sillon volteado, la cama sin colchon, cajas y bolsas, y los sellos de GelA
	_mueble("Sillon", "sillon", 2.0, 1.2, 25.0)
	_mueble("Cama", "cama", 5.0, 1.5, 0.0)
	for i in 4:
		_caja("Caja%d" % i, 3.6 + i * 0.5, 4.0 + i * 0.5, 0, 0.35 + (i % 2) * 0.2, 4.2, 4.65, _color(Color(0.5, 0.4, 0.28)))
	for i in 5:
		_cilindro("Bolsa%d" % i, Vector3(0.8 + i * 0.35, 0, 4.4 - (i % 2) * 0.3), 0.22, 0.4, Color(0.05, 0.05, 0.06))
	# Sellos amarillos de GelA cruzados en las paredes
	for i in 3:
		var y := 1.2 + i * 0.35
		_caja("Sello%d" % i, 0.8, 2.6, y, y + 0.08, 0.01, 0.03, _color(Color(0.95, 0.8, 0.1)), false)


# --- Ayudas ---

func _color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _textura(archivo: String, periodo: float, tinte: Color, ruta := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(ruta if ruta else "res://textures/casa_personaje/%s.png" % archivo)
	m.albedo_color = tinte
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / periodo
	m.roughness = 0.95
	return m


# Caja de (x0, z0)-(x1, z1) en planta y de y0 a y1, con su choque
func _caja(nombre: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material, choca := true) -> void:
	var tam := Vector3(x1 - x0, y1 - y0, z1 - z0)
	var centro := Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	var nodo: Node3D = StaticBody3D.new() if choca else Node3D.new()
	nodo.name = nombre
	nodo.position = centro
	_raiz.add_child(nodo)
	nodo.owner = _raiz
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = mat
	nodo.add_child(malla)
	malla.owner = _raiz
	if choca:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = tam
		forma.shape = box
		nodo.add_child(forma)
		forma.owner = _raiz


func _cilindro(nombre: String, base: Vector3, radio: float, alto: float, color: Color) -> void:
	var malla := MeshInstance3D.new()
	malla.name = nombre
	var c := CylinderMesh.new()
	c.top_radius = radio
	c.bottom_radius = radio
	c.height = alto
	c.radial_segments = 10
	malla.mesh = c
	malla.material_override = _color(color)
	malla.position = base + Vector3.UP * alto / 2.0
	_raiz.add_child(malla)
	malla.owner = _raiz


# Un modelo de JJ con su escala, centrado en (x, z), apoyado en y = ybase y girado `giro` grados
func _mueble(nombre: String, modelo: String, x: float, z: float, giro: float, ybase := 0.0, choca := true) -> void:
	var contenedor := Node3D.new()
	contenedor.name = nombre
	_raiz.add_child(contenedor)
	contenedor.owner = _raiz
	var inst: Node3D = (load(MODELOS % [modelo, modelo]) as PackedScene).instantiate()
	inst.name = "Modelo"
	inst.scale = Vector3.ONE * ESCALA[modelo]
	contenedor.add_child(inst)
	inst.owner = _raiz
	var caja := _caja_total(inst)
	inst.position = Vector3(-(caja.position.x + caja.size.x / 2.0), -caja.position.y, -(caja.position.z + caja.size.z / 2.0))
	contenedor.position = Vector3(x, ybase, z)
	contenedor.rotation_degrees.y = giro
	if choca:
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Colision"
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caja.size
		forma.shape = box
		forma.position = Vector3(0, caja.size.y / 2.0, 0)
		cuerpo.add_child(forma)
		contenedor.add_child(cuerpo)
		cuerpo.owner = _raiz
		forma.owner = _raiz


func _caja_total(nodo: Node3D) -> AABB:
	var acc: Array = []
	_caja_de(nodo, Transform3D.IDENTITY, acc)
	var u: AABB = acc[0]
	for a in acc:
		u = u.merge(a)
	return u


func _caja_de(nodo: Node, xform: Transform3D, acc: Array) -> void:
	var t := xform
	if nodo is Node3D:
		t = xform * (nodo as Node3D).transform
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
		acc.append(t * (nodo as MeshInstance3D).mesh.get_aabb())
	for hijo in nodo.get_children():
		_caja_de(hijo, t, acc)
