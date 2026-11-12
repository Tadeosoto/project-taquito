extends SceneTree

# Arma el interior de la parroquia de Santa Mugre (scenes/casas/templo.tscn), que se entra caminando
# como las casas de los vecinos (CasaPropia.gd: puerta en la pared oeste en z = 3.11, sus mismos
# ADENTRO y PUERTA). La raiz lleva scripts/interiores/Templo.gd, que pone al padre Chuy y lo que se
# puede mirar; si se mueve algo de aqui, se mueven alla sus lugares.
#
#   godot --path . --headless --script res://tools/construir_templo.gd
#
# Planta (m, antes de la escala de CasaPropia):
#   nave           x 0-14, z 0-6.22, 5 m de alto; bancas a los lados del pasillo
#   presbiterio    x 9.8-14, tarima de 0.2 m: el altar, y contra el retablo la Virgen del Tinaco
#   retablo        la pared de x = 14; a su izquierda (z 0.15-1.5) una cortina sin choque
#   pasillo        x 14.15-15.4, detras del retablo, a la altura de la tarima
#   bajada         rampa de x 15.4 a 19.8 (z 4.7-6.07) hasta el piso del pozo, 3 m abajo
#   cuarto del pozo x 15.4-22, z 0-4.6 (y el pie de la rampa), 2.7 m de alto: pozo, filtro, garrafones

const SALIDA := "res://scenes/casas/templo.tscn"
const FONDO := 6.22
const NAVE := 14.0
const ALTO := 5.0
const G := 0.15                 # grueso de las paredes
const PUERTA_Z := 3.11
const PUERTA_ANCHO := 1.4
const PUERTA_ALTO := 2.4
const TARIMA_X := 9.8
const TARIMA := 0.2
const PASILLO := 15.4           # x de la pared entre el pasillo y el pozo
const FIN := 22.0               # x de la pared del fondo
const ABAJO := -2.8             # piso del cuarto del pozo
const TECHO_POZO := -0.1
const TIRO_Z := 4.6             # z de la pared entre el cuarto del pozo y el tiro de la rampa
const RAMPA_FIN := 19.8

var _raiz: Node3D


func _init() -> void:
	_raiz = Node3D.new()
	_raiz.name = "Templo"
	_raiz.set_script(load("res://scripts/interiores/Templo.gd"))
	var pared := _textura("res://textures/mapa/aplanado_blanco.png", Color(0.93, 0.88, 0.76), 1.6)
	var piso := _textura("res://textures/mapa/piedra_plaza_rosa.png", Color(0.9, 0.86, 0.8), 2.0)
	var cantera := _textura("res://textures/mapa/cantera_rosa.png", Color.WHITE, 1.5)
	var piedra := _textura("res://textures/mapa/mamposteria.png", Color(0.62, 0.6, 0.62), 1.5)
	var madera := _textura("res://textures/mapa/madera.png", Color(0.75, 0.6, 0.45), 1.5)
	var tierra := _textura("res://textures/mapa/tierra.png", Color(0.6, 0.58, 0.56), 2.0)

	# --- Nave ---
	_caja("Piso", 0, PASILLO, -0.1, 0, 0, FONDO, piso)
	_caja("Techo", 0, PASILLO, ALTO, ALTO + 0.1, 0, FONDO, madera)
	_caja("ParedNorte", 0, PASILLO, 0, ALTO, -G, 0, pared)
	_caja("ParedSur", 0, FIN, ABAJO, ALTO, FONDO, FONDO + G, pared)
	var z0 := PUERTA_Z - PUERTA_ANCHO / 2.0
	var z1 := PUERTA_Z + PUERTA_ANCHO / 2.0
	_caja("ParedOeste0", -G, 0, 0, ALTO, 0, z0, pared)
	_caja("ParedOeste1", -G, 0, 0, ALTO, z1, FONDO, pared)
	_caja("ParedOesteDintel", -G, 0, PUERTA_ALTO, ALTO, z0, z1, pared)
	_caja("Porton", 0.0, 0.06, 0, PUERTA_ALTO, z1, z1 + PUERTA_ANCHO * 0.5, madera, false)
	# Vigas del techo y guardapolvo de cantera
	for i in 6:
		_caja("Viga%d" % i, 1.2 + i * 2.3, 1.45 + i * 2.3, ALTO - 0.3, ALTO, 0, FONDO, madera, false)
	_caja("ZocaloN", 0, NAVE, 0, 0.9, 0, 0.04, cantera, false)
	_caja("ZocaloS", 0, NAVE, 0, 0.9, FONDO - 0.04, FONDO, cantera, false)
	# Vitrales: cuadros de color que brillan, altos en las paredes largas
	var colores := [Color(0.9, 0.3, 0.2), Color(0.2, 0.5, 0.85), Color(0.95, 0.8, 0.25), Color(0.2, 0.65, 0.45)]
	for i in 4:
		var x := 2.0 + i * 2.4
		for lado in 2:
			var z := 0.02 if lado == 0 else FONDO - 0.05
			_caja("Vitral%d_%d" % [i, lado], x, x + 0.9, 2.6, 4.2, z, z + 0.03, _brillo(colores[(i + lado) % 4]), false)
			_caja("VitralCruz%d_%d" % [i, lado], x + 0.42, x + 0.48, 2.6, 4.2, z - 0.005, z + 0.035, _color(Color(0.1, 0.1, 0.1)), false)
	# Bancas: seis filas a cada lado del pasillo central
	for fila in 6:
		var x := 2.6 + fila * 1.15
		for lado: Array in [[0.45, 2.35], [3.87, 5.77]]:
			var n := "Banca%d_%d" % [fila, int(lado[0])]
			_caja(n, x, x + 0.42, 0, 0.45, lado[0], lado[1], madera)
			_caja(n + "_Respaldo", x - 0.06, x, 0, 0.95, lado[0], lado[1], madera, false)
	# Pila de agua bendita junto a la puerta
	_cilindro("Pila", Vector3(1.4, 0, 1.2), 0.22, 0.85, cantera, true)
	_cilindro("PilaTaza", Vector3(1.4, 0.85, 1.2), 0.38, 0.14, cantera)
	_cilindro("PilaAgua", Vector3(1.4, 0.96, 1.2), 0.32, 0.04, _color(Color(0.25, 0.45, 0.55)))

	# --- Presbiterio ---
	_caja("Tarima", TARIMA_X, PASILLO, 0, TARIMA, 0, FONDO, cantera)
	_rampa("TarimaSubida", Vector3(TARIMA_X - 0.6, 0, 0), Vector3(TARIMA_X, TARIMA, FONDO), cantera)
	_caja("Altar", 11.4, 12.1, TARIMA, TARIMA + 0.95, 2.2, 4.0, cantera)
	_caja("Mantel", 11.38, 12.12, TARIMA + 0.95, TARIMA + 0.98, 2.1, 4.1, _color(Color(0.95, 0.94, 0.9)), false)
	# El retablo: la pared de x = NAVE con su hueco a la izquierda (z 0.15-1.5), tapado con una cortina
	_caja("Retablo", NAVE, NAVE + G, 0, ALTO, 1.5, FONDO, pared)
	_caja("RetabloDintel", NAVE, NAVE + G, 2.3, ALTO, 0, 1.5, pared)
	_caja("Cortina", NAVE + 0.04, NAVE + 0.08, TARIMA, 2.3, 0.1, 1.5, _color(Color(0.42, 0.08, 0.1)), false)
	# La Virgen del Tinaco: nicho dorado, el tinaco negro con su mancha, resplandor, veladoras y flores
	_caja("Nicho", NAVE - 0.12, NAVE, TARIMA, 4.4, 1.9, 4.3, _color(Color(0.62, 0.5, 0.2)), false)
	_cilindro("Pedestal", Vector3(13.2, TARIMA, PUERTA_Z), 0.7, 0.5, cantera, true)
	_cilindro("Tinaco", Vector3(13.2, TARIMA + 0.5, PUERTA_Z), 0.55, 1.25, _color(Color(0.07, 0.07, 0.08)))
	_cilindro("TinacoTapa", Vector3(13.2, TARIMA + 1.75, PUERTA_Z), 0.2, 0.14, _color(Color(0.07, 0.07, 0.08)))
	var mancha := MeshInstance3D.new()
	mancha.name = "Mancha"
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(0.42, 1.1)
	mancha.mesh = cuadro
	var mat_mancha := StandardMaterial3D.new()
	mat_mancha.albedo_texture = load("res://textures/mapa/mancha_tinaco.png")
	mat_mancha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat_mancha.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat_mancha.cull_mode = BaseMaterial3D.CULL_DISABLED
	mancha.material_override = mat_mancha
	mancha.position = Vector3(13.2 - 0.57, TARIMA + 1.12, PUERTA_Z)
	mancha.rotation.y = -PI / 2.0        # viendo a la puerta (-x)
	_raiz.add_child(mancha)
	mancha.owner = _raiz
	for i in 16:
		var a := TAU * i / 16.0
		var largo := 0.5 if i % 2 == 0 else 0.34
		var rayo := _caja("Rayo%d" % i, -0.02, 0.02, 0.0, largo, -0.03, 0.03, _brillo(Color(0.95, 0.75, 0.25)), false)
		rayo.position = Vector3(NAVE - 0.14, TARIMA + 1.2 + cos(a) * 1.25, PUERTA_Z + sin(a) * 1.0)
		rayo.rotation.x = a
	var velas := [Color(0.7, 0.1, 0.1), Color(0.9, 0.88, 0.8), Color(0.2, 0.35, 0.7), Color(0.2, 0.5, 0.3)]
	for i in 14:
		var z := 1.95 + i * 0.18
		var alto := 0.14 + (i % 3) * 0.05
		_cilindro("Veladora%d" % i, Vector3(12.45 + (i % 2) * 0.16, TARIMA, z), 0.05, alto, _color(velas[i % 4]))
		_caja("Flama%d" % i, 12.435 + (i % 2) * 0.16, 12.465 + (i % 2) * 0.16, TARIMA + alto, TARIMA + alto + 0.06, z - 0.015, z + 0.015, _brillo(Color(1.0, 0.8, 0.35)), false)
	for i in 6:
		var flor := _color([Color(0.95, 0.5, 0.08), Color(0.96, 0.8, 0.14), Color(0.92, 0.92, 0.86)][i % 3])
		_cilindro("Flores%d" % i, Vector3(13.0 + (i % 2) * 0.3, TARIMA, 1.7 + (i / 2) * 1.5), 0.16, 0.42, flor)
	_luz("LuzNave0", Vector3(3.6, 4.2, PUERTA_Z), 7.5, 1.3, Color(1.0, 0.9, 0.72))
	_luz("LuzNave1", Vector3(8.0, 4.2, PUERTA_Z), 7.5, 1.3, Color(1.0, 0.9, 0.72))
	_luz("LuzAltar", Vector3(12.3, 1.9, PUERTA_Z), 5.0, 2.2, Color(1.0, 0.78, 0.45))

	# --- Detras del retablo: el pasillo y la bajada ---
	_caja("ParedPasillo", PASILLO, PASILLO + G, ABAJO, ALTO, 0, TIRO_Z, piedra)
	_caja("ParedTiro", PASILLO, RAMPA_FIN, ABAJO, 2.6, TIRO_Z, TIRO_Z + G, piedra)
	_caja("ParedTiroArriba", RAMPA_FIN, FIN, TECHO_POZO, 2.6, TIRO_Z, TIRO_Z + G, piedra)
	_caja("TechoTiro", PASILLO, FIN + G, 2.6, 2.7, TIRO_Z, FONDO, piedra, false)
	_caja("ParedTiroSobrePuerta", PASILLO, PASILLO + G, 2.6, ALTO, TIRO_Z, FONDO, pared)
	_rampa("Bajada", Vector3(PASILLO, TARIMA, TIRO_Z + G), Vector3(RAMPA_FIN, ABAJO, FONDO), piedra)
	for i in 10:
		# Escalones dibujados sobre la rampa (el choque es la rampa)
		var x := PASILLO + (i + 0.5) * (RAMPA_FIN - PASILLO) / 10.0
		var y := lerpf(TARIMA, ABAJO, (i + 1) / 10.0)
		_caja("Escalon%d" % i, x - 0.22, x + 0.22, y, y + 0.16, TIRO_Z + G, FONDO, piedra, false)
	_luz("LuzBajada", Vector3(17.4, 1.6, 5.4), 5.0, 0.7, Color(0.9, 0.75, 0.5))

	# --- El cuarto del pozo ---
	_caja("PisoPozo", PASILLO, FIN, ABAJO - 0.1, ABAJO, 0, FONDO, tierra)
	_caja("TechoPozo", PASILLO, FIN, TECHO_POZO, TECHO_POZO + 0.1, 0, TIRO_Z, piedra)
	_caja("TechoPozoPie", RAMPA_FIN, FIN, TECHO_POZO, TECHO_POZO + 0.1, TIRO_Z, FONDO, piedra, false)
	_caja("ParedNortePozo", PASILLO, FIN, ABAJO, TECHO_POZO, -G, 0, piedra)
	_caja("ParedFondo", FIN, FIN + G, ABAJO, 2.7, 0, FONDO, piedra)
	# El pozo: brocal de piedra, el agua negra abajo, el arco con su polea y la cubeta
	var pozo := Vector3(18.6, ABAJO, 2.2)
	_cilindro("Brocal", pozo, 0.95, 0.75, piedra, true)
	_cilindro("PozoHueco", pozo + Vector3.UP * 0.7, 0.75, 0.06, _color(Color(0.02, 0.03, 0.05)))
	for z: float in [1.3, 3.1]:
		_caja("PozoPoste%d" % int(z), 18.54, 18.66, ABAJO, ABAJO + 2.1, z - 0.06, z + 0.06, madera, false)
	_caja("PozoTravesano", 18.54, 18.66, ABAJO + 2.0, ABAJO + 2.12, 1.3, 3.1, madera, false)
	_caja("PozoCuerda", 18.59, 18.61, ABAJO + 1.0, ABAJO + 2.0, 2.19, 2.21, _color(Color(0.6, 0.5, 0.3)), false)
	_cilindro("Cubeta", Vector3(18.6, ABAJO + 0.78, 2.2), 0.16, 0.26, _color(Color(0.5, 0.52, 0.55)))
	# El filtro robado (docs/personajes.md): un tanque azul con mangueras a dos tambos
	_cilindro("Filtro", Vector3(21.2, ABAJO, 0.7), 0.3, 1.3, _color(Color(0.1, 0.33, 0.72)), true)
	_caja("FiltroEtiqueta", 20.89, 20.9, ABAJO + 0.6, ABAJO + 0.95, 0.55, 0.85, _color(Color(0.9, 0.9, 0.86)), false)
	for i in 2:
		_cilindro("Tambo%d" % i, Vector3(20.2 - i * 0.75, ABAJO, 0.6), 0.3, 0.9, _color(Color(0.2, 0.35, 0.7)), true)
		_caja("Manguera%d" % i, 20.2 - i * 0.75, 21.2, ABAJO + 1.0, ABAJO + 1.04, 0.58, 0.62, _color(Color(0.15, 0.4, 0.2)), false)
	# Garrafones llenos contra la pared y la mesa con el cuaderno
	for i in 8:
		_cilindro("Garrafon%d" % i, Vector3(16.0 + (i % 4) * 0.42, ABAJO + (i / 4) * 0.5, 0.45), 0.15, 0.48, _color(Color(0.3, 0.55, 0.9)))
	_caja("Mesa", 20.6, 21.6, ABAJO + 0.7, ABAJO + 0.76, 4.9, 5.7, madera)
	for x: float in [20.66, 21.5]:
		for z: float in [4.96, 5.6]:
			_caja("MesaPata%d_%d" % [int(x * 10), int(z * 10)], x, x + 0.06, ABAJO, ABAJO + 0.7, z, z + 0.06, madera, false)
	_caja("Cuaderno", 20.9, 21.2, ABAJO + 0.76, ABAJO + 0.79, 5.15, 5.4, _color(Color(0.92, 0.9, 0.82)), false)
	_luz("LuzPozo", Vector3(18.6, TECHO_POZO - 0.4, 2.2), 6.5, 0.9, Color(0.7, 0.85, 1.0))

	var paquete := PackedScene.new()
	paquete.pack(_raiz)
	print("guardado ", SALIDA, " -> ", error_string(ResourceSaver.save(paquete, SALIDA)))
	_raiz.free()
	quit()


# --- Ayudas ---

func _color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _brillo(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _textura(ruta: String, tinte: Color, periodo: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(ruta)
	m.albedo_color = tinte
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / periodo
	m.roughness = 0.95
	return m


func _luz(nombre: String, donde: Vector3, alcance: float, energia: float, color: Color) -> void:
	var foco := OmniLight3D.new()
	foco.name = nombre
	foco.position = donde
	foco.omni_range = alcance
	foco.light_energy = energia
	foco.light_color = color
	_raiz.add_child(foco)
	foco.owner = _raiz


# Caja de (x0, z0)-(x1, z1) en planta y de y0 a y1, con su choque
func _caja(nombre: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material, choca := true) -> Node3D:
	var tam := Vector3(x1 - x0, y1 - y0, z1 - z0)
	var nodo: Node3D = StaticBody3D.new() if choca else Node3D.new()
	nodo.name = nombre
	nodo.position = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
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
	return nodo


func _cilindro(nombre: String, base: Vector3, radio: float, alto: float, mat: Material, choca := false) -> void:
	var nodo: Node3D = StaticBody3D.new() if choca else Node3D.new()
	nodo.name = nombre
	nodo.position = base + Vector3.UP * alto / 2.0
	_raiz.add_child(nodo)
	nodo.owner = _raiz
	var malla := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radio
	c.bottom_radius = radio
	c.height = alto
	c.radial_segments = 10
	malla.mesh = c
	malla.material_override = mat
	nodo.add_child(malla)
	malla.owner = _raiz
	if choca:
		var forma := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = radio
		cil.height = alto
		forma.shape = cil
		nodo.add_child(forma)
		forma.owner = _raiz


# Rampa que va en x de `a` (x, y de un extremo y z de un lado) a `b` (x, y del otro extremo y z
# del otro lado): una losa inclinada de 0.2 m con su choque, de z = a.z a z = b.z
func _rampa(nombre: String, a: Vector3, b: Vector3, mat: Material) -> void:
	var largo := Vector2(b.x - a.x, b.y - a.y).length()
	var angulo := atan2(b.y - a.y, b.x - a.x)
	var tam := Vector3(largo, 0.2, absf(b.z - a.z))
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre
	# La cara de arriba de la losa pasa por los dos extremos
	var medio := Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, (a.z + b.z) / 2.0)
	cuerpo.rotation.z = angulo
	cuerpo.position = medio - Vector3(-sin(angulo), cos(angulo), 0.0) * 0.1
	_raiz.add_child(cuerpo)
	cuerpo.owner = _raiz
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = mat
	cuerpo.add_child(malla)
	malla.owner = _raiz
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tam
	forma.shape = box
	cuerpo.add_child(forma)
	forma.owner = _raiz
