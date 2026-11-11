class_name Tianguis
extends Node3D

# Un tramo de tianguis sobre una calle: dos filas de carpas de lona sobre tubos, una junto a otra a
# lo largo del tramo (eje X local, de 0 a `largo`), con la espalda en la orilla de cada banqueta y
# el vuelo de la lona hacia el centro. Las lonas de las dos filas casi se tocan y hacen un techo
# seguido; abajo queda el pasillo para caminar y las banquetas libres. Cada puesto se llena con un
# giro usando las piezas del proyecto (TianguisPiezas, objetos, el carrito de tacos y el de tejuino).
#
# Lo arma Colonia.gd con las marcas "tianguis" (tools/blender/mapa/exportar.py: los `huecos` frente
# a las puertas y las calles que cruzan, y los `reservados` de los puestos sueltos de MapPuntos que
# quedan debajo de una carpa vacia), y el borrador scenes/tianguis_borrador.tscn.
#
# Para que aguante en el mapa: lo quieto se hornea en un MultiMesh por malla y material (los
# colores de las lonas y de la ropa van por instancia), los marchantes y compradores solo existen
# cerca de la camara (unos pocos por cuadro) y de noche quedan los fierros y los tablones: sin
# lonas, mercancia ni gente (a la hora de NinosCancha). Todo con azar fijo (semilla).

const LONA_TEX := preload("res://models/tianguis/carpas/lona.png")
const LONA_NORMAL := preload("res://models/tianguis/carpas/lona_normal.png")
const Piezas := preload("res://scripts/map/TianguisPiezas.gd")
# Mallas aligeradas de las piezas muy pesadas (la mesa torneada, los jarritos): las saca
# tools/tianguis/aligerar_piezas.gd y al hornear se usan en lugar de la original
const LIGERAS := "res://models/tianguis/ligeras/ligeras.json"

# [escena, ancho del glb, fondo del glb, cuantas veces sale]: frente en -Z, espalda en z = 0
# (tools/blender/tianguis/carpas.py)
const CARPAS := [
	["res://models/tianguis/carpas/carpa_una_agua.glb", 3.0, 2.2, 3],
	["res://models/tianguis/carpas/carpa_panza.glb", 3.0, 2.2, 3],
	["res://models/tianguis/carpas/carpa_dos_aguas.glb", 3.5, 2.4, 1],
	["res://models/tianguis/carpas/carpa_rayas.glb", 4.0, 2.2, 1],
	["res://models/tianguis/carpas/carpa_remendada.glb", 3.0, 2.2, 2],
]
const RAYAS := 3

# Lonas de tianguis: chillonas, y luego cada una mas o menos deslavada por el sol
const COLORES := [
	Color(0.89, 0.12, 0.45), Color(0.1, 0.3, 0.75), Color(0.95, 0.78, 0.1), Color(0.95, 0.45, 0.08),
	Color(0.15, 0.6, 0.3), Color(0.82, 0.12, 0.12), Color(0.45, 0.22, 0.65), Color(0.35, 0.65, 0.9),
	Color(0.92, 0.92, 0.88), Color(0.95, 0.55, 0.65),
]

# Lo que se vende. Cada cosa: [pieza, tamano (lo mas largo, m)]. La pieza es una escena
# ("res://...") o un nodo de un pack de TianguisPiezas ("pack:Nodo"). "mesa" va sobre el tablon
# (en filas apretadas), "suelo" al pie del puesto, "colgado" del tubo de enfrente, "atras"
# contra la espalda del puesto.
const O := "res://models/objetos/"
const GIROS := {
	"fruta": {"sin_mesa": true, "suelo": [[O + "costal_chiles/costal_chiles.tscn", 0.6]]},
	"verdura": {"mesa": [[O + "costal_chiles/costal_chiles.tscn", 0.45], ["tacos:Onion_Coriander", 0.3],
			["tacos:Plate_Limon", 0.25]],
		"suelo": [[O + "costal_chiles/costal_chiles.tscn", 0.65]]},
	"abarrotes": {"mesa": [[O + "takis/takis.scn", 0.2], [O + "gansito/gansito.scn", 0.12],
			[O + "refrescos/refrescos.scn", 0.3],
			[O + "mexican_starter_pack/mazapan.scn", 0.08], ["tacos:Soda_001", 0.3]],
		"suelo": [["tacos:Soda_Box_01", 0.75], [O + "galon_agua/galon_agua.scn", 0.4]],
		"atras": [["tacos:Refrigerator", 1.8]]},
	# Los puestos sueltos del mapa, debajo de la carpa: el carrito del tejuino (el prefab "puesto"
	# de MapPuntos) y el carrito de tacos (Mostrador estilo puesto, sin su toldo)
	"tejuino": {"carrito": "res://models/tiendas/carrito/carrito.scn",
		"suelo": [["tacos:trash_can", 0.85], ["tacos:bucket", 0.4], ["tacos:Soda_Box_02", 1.0]]},
	"tacos": {"taqueria": true, "suelo": [["tacos:gas_tank", 1.1], ["tacos:trash_can", 0.8]], "bancos": true},
	"chacharas": {"mesa": [[O + "bocina/bocina.scn", 0.35], [O + "cinta/cinta.scn", 0.1],
			[O + "chancla/chancla.scn", 0.26], [O + "patito/patito.scn", 0.12],
			[O + "llave/llave.scn", 0.15], [O + "vaporub/vaporub.scn", 0.07]],
		"colgado": [[O + "mexican_starter_pack/mochila.scn", 0.35], [O + "trapo/trapo.scn", 0.3]],
		"atras": [["estante:", 1.7]]},
	"limpieza": {"mesa": [[O + "cloralex/cloralex.scn", 0.3], [O + "vaporub/vaporub.scn", 0.07],
			[O + "trapo/trapo.scn", 0.3]],
		"suelo": [[O + "galon_agua/galon_agua.scn", 0.4], ["tacos:bucket", 0.4]]},
	"tortillas": {"mesa": [[O + "tortillas/tortillas.tscn", 0.3], ["tacos:plastic_bag_P", 0.4], ["tacos:Napkins", 0.25]],
		"suelo": [["tacos:bucket", 0.4]]},
	"ropa": {"mesa": [], "colgado": [[O + "mexican_starter_pack/mochila.scn", 0.35]], "ropa": true},
}
const GIRO_PESOS := {"fruta": 4, "verdura": 2, "abarrotes": 2, "tejuino": 1, "chacharas": 3, "limpieza": 1,
	"tortillas": 1, "tacos": 2, "ropa": 3}
const ALTO_MESA := 0.78

# Gente: existe a menos de RADIO_GENTE m de la camara y se quita pasando RADIO_SUELTA; se crean
# POR_CUADRO por cuadro (el primer civil de cada modelo tarda unos ms)
const RADIO_GENTE := 32.0
const RADIO_SUELTA := 40.0
const REVISA := 0.3
const POR_CUADRO := 2
# Lo chico que se hornea (mercancia, menos de CHICO m) va en trozos de TROZO m a lo largo del
# tramo y se deja de dibujar a CHICO_HASTA m; lo demas, un MultiMesh por tramo
const TROZO := 20.0
const CHICO := 0.7
const CHICO_HASTA := 35.0

@export var semilla := 7
@export var largo := 40.0           # del tramo, a lo largo de X local
@export var arroyo := 8.0           # de banqueta a banqueta
@export var pasillo := 2.6          # libre entre los tubos de enfrente de las dos filas
@export var gente := true           # marchantes, compradores y los que pasan (civiles del juego)
@export var caminantes_por_m := 0.3
@export var compradores := 0.6      # probabilidad de un comprador frente a cada puesto
# [lado (1 = +Z, -1 = -Z, 0 = los dos), desde, hasta] en X: sin puestos (puertas, calles que cruzan)
@export var huecos: Array = []
# [lado, x del centro, ancho]: carpa vacia encima de un puesto suelto de MapPuntos
@export var reservados: Array = []
@export var hornear := true         # false: deja los nodos (aligerar_piezas.gd los recorre)

static var _ligeras := {}           # clave de malla -> ruta de la aligerada
static var _ligeras_cargadas := {}

var _rng := RandomNumberGenerator.new()
var _escenas := {}
var _mat_fierro: StandardMaterial3D
var _mat_madera: StandardMaterial3D
var _materiales := {}
var _tintes := {}                   # clase -> material compartido con el color por instancia
var _mallas := {}                   # [malla, superficie] -> malla de una superficie
var _bolsa: Array[String] = []
# Gente: {t: Transform3D (en el tramo), modelo, clip, vel (0 = quieto), nodo, en_cola}
var _gente: Array[Dictionary] = []
var _cola: Array[Dictionary] = []
var _de_dia: Array[Node3D] = []     # lo horneado de dia y los carritos: se esconde de noche
var _es_de_dia := true
var _revisa := 0.0
var _ciclo: Node


func _ready() -> void:
	_rng.seed = semilla
	_mat_fierro = _material(Color(0.4, 0.38, 0.36), 0.5, 0.6)
	_mat_madera = _material(Color(0.5, 0.36, 0.22), 0.95)
	var fondo := arroyo / 2.0 - pasillo / 2.0 - 0.15
	for fila in 2:
		_fila(fila, fondo)
	var ambiente := Node3D.new()
	ambiente.name = "Ambiente"
	ambiente.set_meta("dia", true)
	add_child(ambiente)
	_focos(ambiente)
	_estorbos(ambiente)
	if gente:
		_caminantes()
	if hornear:
		_hornear()


func _process(delta: float) -> void:
	_revisa -= delta
	if _revisa <= 0.0:
		_revisa = REVISA
		_revisar()
	# Los que pasan caminan a lo largo del pasillo y dan la vuelta al llegar a la orilla
	for e in _gente:
		var vel: float = e["vel"]
		if vel == 0.0:
			continue
		var t: Transform3D = e["t"]
		t.origin.x += vel * delta
		if t.origin.x < -1.0 or t.origin.x > largo + 1.0:
			t.origin.x = clampf(t.origin.x, -1.0, largo + 1.0)
			e["vel"] = -vel
			t.basis = Basis(Vector3.UP, PI / 2.0 if vel > 0.0 else -PI / 2.0)
		e["t"] = t
		if e["nodo"]:
			(e["nodo"] as Node3D).transform = t
	var n := 0
	while not _cola.is_empty() and n < POR_CUADRO:
		var e: Dictionary = _cola.pop_back()
		e["en_cola"] = false
		if e["nodo"] == null and _es_de_dia:
			_crear(e)
			n += 1


# De dia o de noche (Ciclo), y quien debe existir segun la distancia a la camara
func _revisar() -> void:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
	var de_dia := _ciclo == null or float(_ciclo.valor()) < NinosCancha.NOCHE_DESDE
	if de_dia != _es_de_dia:
		_es_de_dia = de_dia
		for nodo in _de_dia:
			nodo.visible = de_dia
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var aqui := to_local(camara.global_position)
	for e in _gente:
		var d := (e["t"] as Transform3D).origin.distance_to(aqui)
		if e["nodo"] != null:
			if not _es_de_dia or d > RADIO_SUELTA:
				(e["nodo"] as Node).queue_free()
				e["nodo"] = null
		elif _es_de_dia and d < RADIO_GENTE and not e["en_cola"]:
			e["en_cola"] = true
			_cola.append(e)


func _crear(e: Dictionary) -> void:
	var p := Node3D.new()
	p.transform = e["t"]
	add_child(p)
	var animacion := Civiles.poner(p, e["modelo"], e["clip"])
	if e["vel"] != 0.0:
		animacion.speed_scale = absf(e["vel"]) / 1.2
	e["nodo"] = p


func _persona(t: Transform3D, clip: String, vel := 0.0) -> void:
	if gente:
		_gente.append({"t": t, "modelo": Civiles.MODELOS[_rng.randi() % Civiles.MODELOS.size()],
			"clip": clip, "vel": vel, "nodo": null, "en_cola": false})


func _caminantes() -> void:
	for i in int(largo * caminantes_por_m):
		var vel := _rng.randf_range(0.9, 1.4) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var t := Transform3D(Basis(Vector3.UP, -PI / 2.0 if vel > 0.0 else PI / 2.0),
			Vector3(_rng.randf_range(0.0, largo), 0.0, _rng.randf_range(-0.6, 0.6)))
		_persona(t, "Walk_Carry" if _rng.randf() < 0.25 else "Walk", vel)


# --- Puestos -------------------------------------------------------------------------------------

func _fila(fila: int, fondo: float) -> void:
	# Fila 0 del lado +Z (espalda en +Z, frente hacia -Z sin girar); fila 1 del lado -Z, girada
	var lado := 1.0 if fila == 0 else -1.0
	var tapan := []
	for h in huecos:
		if h[0] == 0 or signf(h[0]) == lado:
			tapan.append([float(h[1]), float(h[2])])
	var guardados := []
	for r in reservados:
		if signf(r[0]) == lado:
			guardados.append([float(r[1]) - float(r[2]) / 2.0, float(r[2])])
	guardados.sort_custom(func(a, b): return a[0] < b[0])
	var x := _rng.randf_range(0.0, 0.8)
	var i := 0
	while x < largo:
		var tipo := _sacar_carpa()
		var esc_x := _rng.randf_range(0.9, 1.1)
		var ancho: float = CARPAS[tipo][1] * esc_x
		# El lugar de un puesto suelto: una carpa justo encima (aunque caiga en un hueco); si el
		# puesto que sigue no cabe antes, queda un hueco chico
		if not guardados.is_empty() and x + ancho > guardados[0][0] - 0.1:
			var r: Array = guardados.pop_front()
			tipo = _rng.randi() % 2
			_puesto(fila, lado, i, r[0], r[1], r[1] / CARPAS[tipo][1], tipo, fondo, true)
			x = r[0] + r[1] + _rng.randf_range(0.0, 0.2)
			i += 1
			continue
		if x + ancho > largo:
			break
		var hueco: Array = []
		for h in tapan:
			if x < h[1] and x + ancho > h[0]:
				hueco = h
				break
		if not hueco.is_empty():
			x = hueco[1] + 0.1
			continue
		_puesto(fila, lado, i, x, ancho, esc_x, tipo, fondo, false)
		x += ancho + _rng.randf_range(0.0, 0.2)
		i += 1


func _puesto(fila: int, lado: float, i: int, x0: float, ancho: float, esc_x: float, tipo: int, fondo: float, reservado: bool) -> void:
	var datos: Array = CARPAS[tipo]
	var puesto := Node3D.new()
	puesto.name = "Puesto_%d_%d" % [fila, i]
	add_child(puesto)
	# Espalda en la orilla de la banqueta, un poco adelante o atras, y no del todo derecho
	var atras := arroyo / 2.0 - _rng.randf_range(0.0, 0.2)
	puesto.position = Vector3(x0 + ancho / 2.0, 0.0, lado * atras)
	puesto.rotation.y = (0.0 if fila == 0 else PI) + _rng.randf_range(-0.035, 0.035)
	var carpa: Node3D = (_escena(datos[0]) as PackedScene).instantiate()
	var esc_z: float = fondo / datos[2] * _rng.randf_range(0.95, 1.05)
	carpa.scale = Vector3(esc_x, _rng.randf_range(0.97, 1.05), esc_z)
	carpa.set_meta("carpa", true)
	puesto.add_child(carpa)
	_pintar(carpa, tipo == RAYAS)
	_choques(puesto, ancho, datos[2] * esc_z, not reservado)
	if reservado:
		puesto.set_meta("giro", "suelto")
	else:
		_llenar(puesto, ancho, fondo)


func _sacar_carpa() -> int:
	var total := 0
	for c in CARPAS:
		total += c[3]
	var r := _rng.randi_range(1, total)
	for i in CARPAS.size():
		r -= CARPAS[i][3]
		if r <= 0:
			return i
	return 0


func _pintar(carpa: Node3D, rayas: bool) -> void:
	# Un color por hueco de lona (lona_0, lona_1, lona_2); el fierro con lo de siempre
	var colores := []
	for i in 3:
		var c: Color = COLORES[_rng.randi() % COLORES.size()]
		colores.append(c.lerp(Color(0.8, 0.8, 0.78), _rng.randf_range(0.0, 0.35)))
	if rayas:
		colores[0] = Color(0.9, 0.9, 0.86)
	for m in carpa.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var nombre := mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) else ""
			if nombre.begins_with("lona_"):
				mi.set_surface_override_material(s, _lona(colores[int(nombre.substr(5)) % 3]))
			elif nombre.begins_with("fierro"):
				mi.set_surface_override_material(s, _mat_fierro)
			elif nombre.begins_with("madera"):
				mi.set_surface_override_material(s, _mat_madera)


func _lona(color: Color) -> StandardMaterial3D:
	# Cada color es un material "de tinte": al hornear queda uno solo con el color por instancia
	var m := _material(color, 0.85)
	m.set_meta("clase", "lona")
	return m


func _choques(puesto: Node3D, ancho: float, fondo: float, con_mesa: bool) -> void:
	# Tubos de las cuatro esquinas y la mesa (la lona no choca: va arriba de la cabeza)
	var cuerpo := StaticBody3D.new()
	puesto.add_child(cuerpo)
	for x in [-ancho / 2.0 + 0.05, ancho / 2.0 - 0.05]:
		for z in [0.0, -fondo]:
			_forma(cuerpo, Vector3(x, 1.2, z), Vector3(0.08, 2.4, 0.08))
	if con_mesa:
		_forma(cuerpo, Vector3(0, 0.45, -fondo * 0.55), Vector3(ancho - 0.5, 0.9, 0.9))


func _llenar(puesto: Node3D, ancho: float, fondo: float) -> void:
	var giro := _sacar_giro()
	puesto.set_meta("giro", giro)
	var g: Dictionary = GIROS[giro]
	var mesa_z := -fondo * 0.55
	var mesa_x := ancho - 0.6
	# Lo que solo esta de dia (mercancia, bodega, ropa) va en "Dia"; la mesa y las sillas se quedan
	var dia := Node3D.new()
	dia.name = "Dia"
	puesto.add_child(dia)
	if g.has("carrito"):
		var n := _poner(puesto, g["carrito"], minf(ancho - 0.5, 2.0), Vector3(0, 0, mesa_z))
		n.rotation.y = PI + _rng.randf_range(-0.1, 0.1)
		_suelto(n)
	elif g.get("taqueria", false):
		var m := Mostrador.new()
		m.estilo = 5
		m.toldo = false
		m.parrilla_atras = true
		m.ancho = minf(ancho - 0.6, 2.1)
		m.alto = 0.92
		m.fondo = 0.7
		m.color = Color(0.7, 0.1, 0.08)
		m.semilla = _rng.randi()
		# Su frente (+Z) al pasillo, que en el puesto es -Z
		m.position = Vector3(0, 0, mesa_z)
		m.rotation.y = PI
		puesto.add_child(m)
		_suelto(m)
	elif g.get("sin_mesa", false):
		# Fruteria: el exhibidor de huacales con fruta y verdura en lugar del tablon
		var n := _pieza(dia, "fruta:Box", Vector3(0, 0, mesa_z - 0.1), 0.0)
		var c := Piezas.caja_de(n)
		n.scale = Vector3(minf(ancho - 0.4, 2.6) / c.size.x, 1.15 / c.size.y, 1.3 / c.size.z)
	else:
		_mesa(puesto, mesa_x, mesa_z)
		_llenar_mesa(dia, g.get("mesa", []), mesa_x, mesa_z)
	if g.get("ropa", false):
		_ropa(dia, ancho, fondo, mesa_x, mesa_z)
	for c in g.get("suelo", []):
		for k in _rng.randi_range(1, 2):
			var lado := -1.0 if _rng.randf() < 0.5 else 1.0
			_cosa(dia, c, Vector3(lado * _rng.randf_range(ancho / 2.0 - 0.45, ancho / 2.0 - 0.25), 0.0, mesa_z + _rng.randf_range(-0.5, 0.4)))
	for c in g.get("colgado", []):
		var px := -ancho / 2.0 + 0.35
		while px < ancho / 2.0 - 0.3:
			if _rng.randf() < 0.6:
				var n := _cosa(dia, c, Vector3(px, 0.0, -fondo + 0.04))
				# Colgado del tubo: la punta de arriba a 2.3 m
				var caja := _aabb(n)
				n.position.y = 2.3 - (caja.position.y + caja.size.y) * n.scale.y
			px += _rng.randf_range(0.45, 0.7)
	for c in g.get("atras", []):
		if _rng.randf() < 0.7:
			# El estante se queda de noche; el refri se lo llevan
			_cosa(puesto if String(c[0]).begins_with("estante") else dia, c, Vector3(_rng.randf_range(-ancho / 4.0, ancho / 4.0), 0.0, -0.4), 0.0)
	if g.get("bancos", false):
		# Bancos para los que comen, del lado del pasillo
		for k in _rng.randi_range(2, 3):
			_pieza(puesto, "tacos:Chair", Vector3(_rng.randf_range(-ancho / 2.0 + 0.4, ancho / 2.0 - 0.4), 0.0, -fondo - 0.25), 0.8)
	# La bodega del puesto: cajas de carton y rejas atras de la mesa
	for k in _rng.randi_range(1, 2):
		var p := Vector3(_rng.randf_range(-ancho / 2.0 + 0.5, ancho / 2.0 - 0.5), 0.0, _rng.randf_range(-0.55, -0.3))
		if _rng.randf() < 0.6:
			_pieza(dia, "cajas:", p, _rng.randf_range(0.8, 1.1))
		else:
			_pieza(dia, ["tacos:Soda_Box", "tacos:Soda_Box_01", "tacos:Soda_Box_02"][_rng.randi() % 3], p, 0.0).scale = Vector3.ONE * 0.95
	# El marchante detras de la mesa: parado, platicando o sentado en su silla de plastico
	var bx := _rng.randf_range(-0.6, 0.6)
	var giro_m := _rng.randf_range(-0.4, 0.4)
	var en := Vector3(bx, 0.0, mesa_z + 0.75)
	var clip: String = ["Idle", "Idle_Talking", "Sitting_Idle", "Idle"][_rng.randi() % 4]
	var silla_en := Vector3(bx, 0.0, en.z + 0.05) if clip == "Sitting_Idle" else Vector3(-bx, 0.0, mesa_z + 0.8)
	if clip == "Sitting_Idle" or _rng.randf() < 0.5:
		var silla := _pieza(puesto, "silla:" if _rng.randf() < 0.6 else "tacos:Chair", silla_en, 0.85)
		silla.rotation.y = PI + _rng.randf_range(-0.3, 0.3) if clip == "Sitting_Idle" else _rng.randf_range(-PI, PI)
	_persona(puesto.transform * Transform3D(Basis(Vector3.UP, giro_m), en), clip)
	# Un comprador en el pasillo viendo el puesto (el civil ve a su -Z: se voltea hacia la mesa)
	if _rng.randf() < compradores:
		var c_en := Vector3(_rng.randf_range(-ancho / 2.0 + 0.4, ancho / 2.0 - 0.4), 0.0, -fondo - _rng.randf_range(0.25, 0.6))
		_persona(puesto.transform * Transform3D(Basis(Vector3.UP, PI + _rng.randf_range(-0.5, 0.5)), c_en),
			["Idle", "Idle_Talking", "Interact", "PickUp_Table"][_rng.randi() % 4])


func _suelto(n: Node3D) -> void:
	# No se hornea (trae su MultiMesh, su humo o su animacion) y se esconde de noche
	n.set_meta("suelto", true)
	_de_dia.append(n)


func _mesa(puesto: Node3D, largo_m: float, z: float) -> void:
	# El tablon de madera del proyecto, estirado al ancho del puesto
	var n := Piezas.pieza("mesa", "")
	var c := Piezas.caja_de(n)
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, z)
	puesto.add_child(holder)
	holder.add_child(n)
	if c.size.z > c.size.x:
		n.rotation.y = PI / 2.0
		c = AABB(c.position, Vector3(c.size.z, c.size.y, c.size.x))
	holder.scale = Vector3(largo_m / c.size.x, ALTO_MESA / c.size.y, 0.85 / c.size.z)


func _llenar_mesa(padre: Node3D, cosas: Array, mesa_x: float, mesa_z: float) -> void:
	# Filas de lo mismo, apretadas y no muy derechas, como se acomoda en el tianguis
	if cosas.is_empty():
		return
	var x := -mesa_x / 2.0 + 0.1
	while x < mesa_x / 2.0 - 0.1:
		var c: Array = cosas[_rng.randi() % cosas.size()]
		var tam: float = c[1]
		for fila_z in [-0.25, 0.0, 0.25]:
			if tam > 0.4 and fila_z != 0.0:
				continue
			_cosa(padre, c, Vector3(x + tam / 2.0, ALTO_MESA, mesa_z + fila_z + _rng.randf_range(-0.04, 0.04)))
		x += tam + _rng.randf_range(0.02, 0.08)


func _sacar_giro() -> String:
	# De una bolsa revuelta con cada giro tantas veces como su peso: sale de todo y no se repiten
	# cinco fruterias seguidas
	if _bolsa.is_empty():
		for g in GIRO_PESOS:
			for k in GIRO_PESOS[g]:
				_bolsa.append(g)
		for i in range(_bolsa.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var t := _bolsa[i]
			_bolsa[i] = _bolsa[j]
			_bolsa[j] = t
	return _bolsa.pop_back()


func _ropa(padre: Node3D, ancho: float, fondo: float, mesa_x: float, mesa_z: float) -> void:
	# Montones de ropa doblada en la mesa y prendas colgadas de ganchos del tubo de enfrente
	var x := -mesa_x / 2.0 + 0.2
	while x < mesa_x / 2.0 - 0.2:
		var c := Color.from_hsv(_rng.randf(), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.3, 0.9))
		var h := _rng.randf_range(0.08, 0.25)
		_caja(padre, Vector3(x, ALTO_MESA + h / 2.0, mesa_z + _rng.randf_range(-0.2, 0.2)), Vector3(0.35, h, 0.3), _material(c, 0.95))
		x += 0.38
	var px := -ancho / 2.0 + 0.3
	while px < ancho / 2.0 - 0.25:
		var m := _material(Color.from_hsv(_rng.randf(), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.3, 0.9)), 0.95)
		var prenda := Node3D.new()
		prenda.position = Vector3(px, 2.25, -fondo + 0.03)
		prenda.rotation.y = _rng.randf_range(-0.3, 0.3)
		padre.add_child(prenda)
		if _rng.randf() < 0.6:
			_caja(prenda, Vector3(0, -0.35, 0), Vector3(0.4, 0.6, 0.02), m)
			_caja(prenda, Vector3(0, -0.12, 0), Vector3(0.62, 0.16, 0.02), m)
		else:
			for lado in [-0.1, 0.1]:
				_caja(prenda, Vector3(lado, -0.5, 0), Vector3(0.17, 0.9, 0.02), m)
			_caja(prenda, Vector3(0, -0.1, 0), Vector3(0.38, 0.12, 0.02), m)
		px += _rng.randf_range(0.8, 1.2)


# --- Ambiente ------------------------------------------------------------------------------------

func _focos(padre: Node3D) -> void:
	# Cables con focos colgando a lo largo del pasillo, abajo de las lonas
	var cable := _material(Color(0.05, 0.05, 0.05), 0.8)
	var foco := StandardMaterial3D.new()
	foco.albedo_color = Color(1.0, 0.92, 0.7)
	foco.emission_enabled = true
	foco.emission = Color(1.0, 0.85, 0.55)
	foco.emission_energy_multiplier = 2.0
	var bola := SphereMesh.new()
	bola.radius = 0.05
	bola.height = 0.12
	bola.radial_segments = 8
	bola.rings = 4
	for z in [-0.6, 0.7]:
		_caja(padre, Vector3(largo / 2.0, 2.45, z), Vector3(largo, 0.015, 0.015), cable)
		var x := _rng.randf_range(0.5, 2.0)
		while x < largo:
			var cuelga := _rng.randf_range(0.15, 0.35)
			_caja(padre, Vector3(x, 2.45 - cuelga / 2.0, z), Vector3(0.01, cuelga, 0.01), cable)
			var mi := MeshInstance3D.new()
			mi.mesh = bola
			mi.material_override = foco
			mi.position = Vector3(x, 2.45 - cuelga - 0.05, z)
			padre.add_child(mi)
			x += _rng.randf_range(2.5, 5.0)


func _estorbos(padre: Node3D) -> void:
	# Lo que invade el pasillo: carrito de super, cajas, costales, cubetas, rejas, el tambo
	var x := 2.0
	while x < largo - 2.0:
		var en := Vector3(x, 0.0, _rng.randf_range(-pasillo / 2.0 + 0.3, pasillo / 2.0 - 0.3))
		match _rng.randi() % 6:
			0:
				_poner(padre, O + "carrito_super/carrito_super.scn", 1.0, en)
			1:
				_pieza(padre, "cajas:", en, _rng.randf_range(0.7, 1.0))
			2:
				_poner(padre, O + "costal_chiles/costal_chiles.tscn", 0.6, en)
			3:
				_pieza(padre, "tacos:bucket", en, 0.4)
			4:
				_pieza(padre, "tacos:Soda_Box_01", en, 0.75)
			5:
				_pieza(padre, "tacos:trash_can", en, 0.85)
		x += _rng.randf_range(3.0, 7.0)


# --- Horneado ------------------------------------------------------------------------------------

func _hornear() -> void:
	# Todo lo quieto a un MultiMesh por (malla de una superficie, material, de dia o no). Los
	# materiales "de tinte" (lonas, ropa, cajas lisas) se juntan en uno con el color por instancia.
	# Luego se quitan los nodos horneados: de cada puesto quedan su cuerpo de choque y los carritos.
	var inv := global_transform.affine_inverse()
	var grupos := {}
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or _hay_meta(mi, "suelto"):
			continue
		var dia := _hay_meta(mi, "dia") or mi.name.contains("_lona") or mi.name.contains("_cuerdas")
		# Solo las carpas dan sombra: lo de abajo ya queda a la sombra de la lona
		var sombra := _hay_meta(mi, "carpa")
		var t := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var color := Color.WHITE
			if mat and mat.has_meta("clase"):
				color = (mat as StandardMaterial3D).albedo_color
				mat = _tinte(String(mat.get_meta("clase")))
			var malla := _una_superficie(mi.mesh, s)
			var tam := t.basis.get_scale() * malla.get_aabb().size
			var chico := maxf(tam.x, maxf(tam.y, tam.z)) < CHICO
			var trozo := floori(t.origin.x / TROZO) if chico else 0
			var clave := "%d_%d_%s_%d_%s" % [malla.get_instance_id(), mat.get_instance_id() if mat else 0, dia, trozo, chico]
			if not grupos.has(clave):
				grupos[clave] = [malla, mat, dia, [], [], chico, sombra]
			grupos[clave][3].append(t)
			grupos[clave][4].append(color)
	for clave in grupos:
		var g: Array = grupos[clave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = g[0]
		mm.instance_count = g[3].size()
		for i in g[3].size():
			mm.set_instance_transform(i, g[3][i])
			mm.set_instance_color(i, g[4][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = g[1]
		if not g[6]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if g[5]:
			mmi.visibility_range_end = CHICO_HASTA
			mmi.visibility_range_end_margin = 4.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		if g[2]:
			_de_dia.append(mmi)
	for hijo in get_children():
		if hijo.name == "Ambiente":
			hijo.queue_free()
		elif hijo.name.begins_with("Puesto_"):
			for c in hijo.get_children():
				if not (c is StaticBody3D or c.has_meta("suelto")):
					c.queue_free()


func _hay_meta(nodo: Node, meta: String) -> bool:
	var n := nodo
	while n != null and n != self:
		if n.has_meta(meta) or (meta == "dia" and n.name == "Dia"):
			return true
		n = n.get_parent()
	return false


func _tinte(clase: String) -> StandardMaterial3D:
	if not _tintes.has(clase):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.9
		if clase == "lona":
			m.albedo_texture = LONA_TEX
			m.normal_enabled = true
			m.normal_texture = LONA_NORMAL
			m.normal_scale = 0.5
			m.roughness = 0.85
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# La luz pasa la lona: abajo se ve encendida
			m.backlight_enabled = true
			m.backlight = Color(0.45, 0.45, 0.45)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_tintes[clase] = m
	return _tintes[clase]


static func clave_malla(malla: Mesh, s: int) -> String:
	# Las mallas de las escenas del proyecto por su ruta; las de un .glb importado por su nombre
	var ruta := malla.resource_path
	if not ruta.begins_with("res://") or ruta.contains("/.godot/"):
		ruta = malla.resource_name
	return "%s#%d" % [ruta, s]


func _una_superficie(malla: Mesh, s: int) -> Mesh:
	if _ligeras.is_empty() and FileAccess.file_exists(LIGERAS):
		_ligeras = JSON.parse_string(FileAccess.get_file_as_string(LIGERAS))
	var ligera: String = _ligeras.get(clave_malla(malla, s), "")
	if ligera != "":
		if not _ligeras_cargadas.has(ligera):
			_ligeras_cargadas[ligera] = load(ligera)
		return _ligeras_cargadas[ligera]
	if malla.get_surface_count() == 1:
		return malla
	var clave := "%d_%d" % [malla.get_instance_id(), s]
	if not _mallas.has(clave):
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(malla.surface_get_primitive_type(s), malla.surface_get_arrays(s))
		_mallas[clave] = am
	return _mallas[clave]


# --- Ayudas --------------------------------------------------------------------------------------

func _cosa(padre: Node3D, c: Array, en: Vector3, giro := INF) -> Node3D:
	# Una cosa de GIROS: escena del proyecto o pieza de un pack
	var ref: String = c[0]
	if ref.begins_with("res://"):
		return _poner(padre, ref, c[1], en)
	return _pieza(padre, ref, en, c[1], giro)


func _pieza(padre: Node3D, ref: String, en: Vector3, tam: float, giro := INF) -> Node3D:
	# Pieza de un pack ("pack:Nodo"), con lo mas largo a `tam` m (0 = su tamano), base en `en`
	var partes := ref.split(":")
	var n := Piezas.pieza(partes[0], partes[1])
	if n == null:
		return Node3D.new()
	padre.add_child(n)
	if tam > 0.0:
		var c := Piezas.caja_de(n)
		n.scale = Vector3.ONE * tam / maxf(c.size.x, maxf(c.size.y, c.size.z))
	n.position = en
	n.rotation.y = _rng.randf_range(-0.4, 0.4) if giro == INF else giro
	return n


func _poner(padre: Node3D, ruta: String, tam: float, en: Vector3) -> Node3D:
	# Instancia la escena y la escala para que lo mas largo mida `tam`, asentada en `en`
	if not ResourceLoader.exists(ruta):
		return Node3D.new()
	var cosa: Node3D = (_escena(ruta) as PackedScene).instantiate()
	padre.add_child(cosa)
	var caja := _aabb(cosa)
	if caja.size == Vector3.ZERO:
		return cosa
	var s := tam / maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
	cosa.scale = Vector3.ONE * s
	cosa.rotation.y = _rng.randf_range(-0.4, 0.4)
	var centro := cosa.basis * (caja.get_center() * Vector3(1, 0, 1))
	cosa.position = en - centro - Vector3(0, caja.position.y * s, 0)
	# Lo de las tiendas trae sus cuerpos; en el tianguis no estorban
	for c in cosa.find_children("*", "CollisionObject3D", true, false):
		(c as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
	return cosa


func _aabb(raiz: Node3D) -> AABB:
	var caja := AABB()
	var hay := false
	var inv := raiz.global_transform.affine_inverse()
	for v in raiz.find_children("*", "VisualInstance3D", true, false):
		var vi := v as VisualInstance3D
		var b := (inv * vi.global_transform) * vi.get_aabb()
		caja = b if not hay else caja.merge(b)
		hay = true
	return caja


func _escena(ruta: String) -> Resource:
	if not _escenas.has(ruta):
		_escenas[ruta] = load(ruta)
	return _escenas[ruta]


func _material(color: Color, rugoso := 0.9, metal := 0.0) -> StandardMaterial3D:
	# Materiales lisos "de tinte": al hornear se vuelven uno con el color por instancia, asi que
	# aqui solo se comparten por color redondeado
	var c := Color(snappedf(color.r, 0.05), snappedf(color.g, 0.05), snappedf(color.b, 0.05))
	var clave := "%s_%.2f_%.1f" % [c.to_html(false), rugoso, metal]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugoso
	m.metallic = metal
	if metal == 0.0:
		m.set_meta("clase", "plano")
	_materiales[clave] = m
	return m


func _caja(padre: Node3D, centro: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = centro
	padre.add_child(mi)
	return mi


func _forma(cuerpo: StaticBody3D, centro: Vector3, tam: Vector3) -> void:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	f.shape = b
	f.position = centro
	cuerpo.add_child(f)
