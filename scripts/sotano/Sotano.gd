extends Node3D

# Raiz del Sotano, el casino clandestino de los Gotera bajo unos abarrotes de Santa Mugre
# (scenes/casas/sotano.tscn; docs/lore.md 11 y docs/sistemas/sotano.md). Se entra caminando como
# las casas de los vecinos (CasaPropia.gd, marca "casa_vecino" con "abierto": "noche").
# El cuarto es el .glb de Blender (Cuarto, de tools/blender/sotano/sotano.py): dos salones (las
# maquinitas; y, por un arco, el poker, la barra, el bano y la pista). Sus vacios "Marca_*" dicen
# donde va cada cosa, y aqui se pone lo que se juega y quien esta:
#   el de la puerta y su cadena (CadenaChoque-colonly): sin permiso (Fichas.permiso) no pasas,
#   salvo que le pagues la cuota; la ventanilla del Primo (VentanillaUI), diez EL GORDO
#   (GabineteOlPley + OlPleyUI), dos de frutas (Maquinita en fichas), la mesa de poker (PokerUI),
#   las carreras (CarrerasUI, que mueve los caballitos con correr()), la barra del cantinero, el
#   congelador, el altar, la bocina, los tubos de luz (dos fallan), neones, carteles de cerveza,
#   jugadores sentados y la gente que camina (GenteSotano).
# Todo en metros de la escena: CasaPropia la agranda x1.25.

const NPC := preload("res://scenes/npc.tscn")
const ANUNCIOS := preload("res://textures/sotano/anuncios.png")
const CAGUAMA := "res://resources/productos/caguama.tres"
const CAGUAMA_FICHAS := 3
const CERVEZA_FICHAS := 2           # en la barra, una Tecatl
const LUZ_COLOR := Color(0.85, 0.95, 1.0)
const LUZ_ENERGIA := 1.3
const LUZ_ALCANCE := 6.0
const PARPADEAN := [1, 5]           # los tubos que fallan
const CADERA := 0.38                # m que Sitting_Idle deja la cadera atras de los pies (medir_sentado.gd)
const PISTA_META := 16.5            # x (del cuarto) donde llegan los caballitos (sotano.py PISTA_META)
const CARRERA := 5.5                # s que dura una carrera
const VENTILADOR := 4.0             # rad/s
const ANUNCIO := Vector2(0.8, 1.2)  # m de un cartel (escena)
# Los neones de tubo (models/sotano/neones.glb, de tools/blender/sotano/neones.py): marca, letrero
# del .glb (Neon_<nombre>), color de su luz, si falla y su escala. Los focos van por turnos (FOCOS s).
const NEONES_GLB := preload("res://models/sotano/neones.glb")
const NEONES := [
	["Neon", "gordo", Color(0.8, 0.4, 1.0), false, 0.85],
	["Neon_atras", "gordo", Color(0.8, 0.4, 1.0), false, 0.85],
	["Neon_premio", "premio", Color(1.0, 0.3, 0.75), false, 0.7],
	["Neon_abierto", "abierto", Color(0.3, 1.0, 0.6), true, 1.0],
	["Neon_poker", "poker", Color(1.0, 0.75, 0.3), false, 1.0],
	["Neon_barra", "barra", Color(1.0, 0.25, 0.15), false, 0.6],
	["Neon_bano", "bano", Color(0.3, 0.85, 1.0), true, 1.0],
	["Neon_dados", "dados", Color(0.7, 0.3, 1.0), false, 0.9],
]
const FOCOS := 0.35
const LUCES_BARRA := [Color(1.0, 0.3, 0.75), Color(0.3, 0.85, 1.0), Color(0.65, 0.3, 1.0), Color(0.35, 0.45, 1.0)]
# Que cartel va en cada Marca_Anuncio_k (indice en textures/sotano/anuncios.png, arte.CERVEZAS)
const CARTELES := [0, 1, 2, 5, 3, 4]

const LINEAS_GUARDIA := [
	"¿Y tú quién eres? Aquí abajo no hay nada, mijo. Nomás refrescos.",
	"Si no eres de los muchachos, son %d pesos. Una vez, y ya eres de confianza.",
	"Ándale, que no tengo tu tiempo.",
]
const LINEAS_GUARDIA_PASA := [
	"Pásale. Ya te conocen.",
	"Nada de fotos, nada de pleitos, nada de contarle al padre.",
]
const LINEAS_CANTINERO := [
	"¿Una Tecatl? Dos fichas, y va bien helada.",
	"Aquí abajo no hay ley seca, mijo. Ni de ninguna.",
	"El del poker de la gorra cuenta las cartas. Yo no te dije.",
	"Si ves al padre, no me viste.",
]
const LINEAS_CRUPIER := [
	"Ciegas de una y dos. La casa se queda el diez del bote.",
	"Siéntate, que la mesa no espera.",
]
const LINEAS_JUGADORES := [
	"Esta maquinita me debe una casa.",
	"Mi vieja cree que ando en el rosario.",
	"El Tinaco paga doble. Eso sí es milagro.",
	"Allá afuera andan los poseídos; aquí abajo nomás andamos los perdidos.",
	"El de la gorra en el poker nunca se va antes del río. Raro, ¿no?",
]
const TEXTO_ALTAR := "La Virgen del Tinaco con billetes pegados alrededor. Al pie, en plumón: \"Para que no me mire. El Primo.\""
# El bano: la puerta se abre (Bano_bisagra de sotano.py) y adentro todo esta mal, como en Silent Hill
const PUERTA_BANO_ABIERTA := -95.0   # grados en y de la bisagra
# Lo que trae en la mano cada sentado (por su marca): "cigarro" (con humo) o "cerveza"
const VICIOS := {"Poker_0": "cigarro", "Poker_1": "cigarro", "Poker_2": "cerveza", "Silla_2": "cigarro",
	"Silla_7": "cerveza", "Silla_0": "cigarro", "Blackjack_0": "cigarro", "Blackjack_1": "cerveza",
	"Baccarat_0": "cigarro"}
# Los de pie, cada quien en lo suyo (nada limpio): nombre, modelo, donde (x, z), hacia donde ve
# (x, z), clip, lo que trae en la mano y lo que dice. Sin marca: van en metros del cuarto
const TURBIOS := [
	["Halcon", "hombre_05", Vector2(7.7, 4.9), Vector2(5.0, 3.1), "Idle", "",
		["Yo no vi nada. Tú tampoco.", "Si baja alguien de uniforme, chiflo dos veces."]],
	["Vendedor", "hombre_06", Vector2(21.7, -0.7), Vector2(22.4, -0.1), "Interact", "paquete",
		["Circule, circule. Aquí nomás estamos platicando.", "¿Qué me ves? Esto es de la casa."]],
	["Cliente", "mujer_02", Vector2(22.4, -0.1), Vector2(21.7, -0.7), "Idle_Talking", "billetes",
		["Ya te pagué, ¿no? Dame lo mío.", "No me hables, que nos ven."]],
	["Contador", "hombre_08", Vector2(19.9, 6.4), Vector2(17.0, 6.4), "Interact", "billetes",
		["...ochocientos, novecientos... ¿Qué? Me desconcentras.", "La lana de las maquinitas no se cuenta sola."]],
	["Borracho", "hombre_10", Vector2(28.1, 0.75), Vector2(28.1, -1.0), "Drink", "cerveza",
		["Una más y me voy. Llevo diciendo eso desde el martes.", "El de la gorra... ese no pierde nunca, compa. Nunca."]],
]
const LINEAS_ESPEJO := [
	"Te ves cansado. Detrás de ti, en el espejo, la puerta de la caseta está abierta. Volteas: está cerrada.",
	"El espejo está estrellado justo donde va tu cara.",
	"Alguien escribió con el dedo en el vapor: \"ya viene\". No hay vapor.",
	"Por un segundo tu reflejo parpadea después que tú.",
]
const LINEAS_CASETA := [
	"Toc, toc. Desde adentro alguien toca de vuelta. Tres veces.",
	"\"Ocupado\", dice una voz que suena como la tuya.",
	"La caseta está cerrada por dentro. Abajo de la puerta no se ven pies.",
]
const TEXTO_FICHAS_AFUERA := "\"¡Oye! Allá afuera tus fichas no valen nada\", grita el Primo. \"Cámbialas aquí.\""

var _marcas := {}                   # "Marca_X" -> Transform3D en la escena
var _caballos: Array[Node3D] = []
var _caballos_x0: Array[float] = []
var _luces: Array[OmniLight3D] = []
var _focos: Array = []               # por turno ("a", "b"): las mallas de focos de los neones
var _focos_t := 0.0
static var _foco_prendido: StandardMaterial3D
static var _foco_apagado: StandardMaterial3D
var _aspas: Array[Node3D] = []
var _texto: Label
var _guardia_linea := 0
var _cantinero_linea := 0
var _jugadores_linea := 0
var _aviso_fichas := false
var _cuota: MuebleCasa
var _player: Node3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("jugador") as Node3D
	var cuarto := get_node_or_null("Cuarto")
	if cuarto:
		for nodo in cuarto.find_children("Marca_*", "Node3D", true, false):
			_marcas[nodo.name] = _local(nodo as Node3D)
		for i in 5:
			var c := cuarto.find_child("Caballo_%d" % (i + 1), true, false) as Node3D
			if c:
				_caballos.append(c)
				_caballos_x0.append(c.position.x)
		for v in 2:
			_armar_ventilador(cuarto, v)
	_armar_texto()
	_armar_luces()
	_armar_neones()
	_armar_anuncios()
	_armar_juegos()
	_armar_gente()
	_armar_bocina()
	_puerta()
	var gente := load("res://scripts/sotano/GenteSotano.gd") if ResourceLoader.exists("res://scripts/sotano/GenteSotano.gd") else null
	if gente:
		var g: Node = gente.new()
		g.name = "Gente"
		g.set("sotano", self)
		add_child(g)


func _process(delta: float) -> void:
	# El halcon voltea de la escalera al salon y de regreso, vigilando
	if _halcon:
		_halcon_t += delta
		_halcon.rotation.y = _halcon_base + sin(_halcon_t * 0.7) * 0.9
	# Los focos de los neones se prenden por turnos, como en las ferias
	_focos_t += delta
	if _focos_t >= FOCOS and not _focos.is_empty():
		_focos_t = 0.0
		var turno := int(Time.get_ticks_msec() / int(FOCOS * 1000.0)) % 2
		for k in 2:
			for m: MeshInstance3D in _focos[k]:
				m.material_override = _foco_prendido if k == turno else _foco_apagado


func _physics_process(delta: float) -> void:
	# En el bano gotea, a ratos
	if _player and _marcas.has("Marca_Bano_centro"):
		var en_bano := to_local(_player.global_position).x > marca("Bano_centro").origin.x - 1.8
		_gota_t -= delta
		if en_bano and _gota_t <= 0.0:
			_gota_t = randf_range(0.8, 3.0)
			Sonidos.tocar(self, "paso", -16.0, randf_range(0.45, 0.6))
	for aspas in _aspas:
		aspas.rotate_y(VENTILADOR * delta)
	# Subiendo la escalera con fichas: el Primo te grita una vez
	if _player and not _aviso_fichas:
		var aqui := to_local(_player.global_position)
		var f := get_node_or_null("/root/Fichas")
		if aqui.x < 3.2 and aqui.y > -0.6 and f and f.fichas > 0:
			_aviso_fichas = true
			avisar(TEXTO_FICHAS_AFUERA)


# --- Luz, neon y carteles ---

func _armar_luces() -> void:
	var k := 0
	while _marcas.has("Marca_Luz_%d" % k):
		var luz := _luz(marca("Luz_%d" % k).origin, LUZ_COLOR, LUZ_ENERGIA, LUZ_ALCANCE)
		_luces.append(luz)
		k += 1
	for i in PARPADEAN:
		if i < _luces.size():
			_parpadear(_luces[i], LUZ_ENERGIA)
	# La lampara verde de la ventanilla (el Primo se ve) y la de la mesa de poker
	_luz(marca("Luz_ventanilla").origin, Color(1.0, 0.85, 0.6), 1.6, 3.0)
	_luz(marca("Luz_poker").origin, Color(1.0, 0.9, 0.7), 2.2, 4.0)
	# Un foco sobre la rueda de la ruleta (las casillas se pierden en lo oscuro)
	if _marcas.has("Marca_Ruleta"):
		_luz(marca("Ruleta").origin + Vector3(-0.55, 1.5, -1.5), Color(1.0, 0.92, 0.75), 1.6, 2.4)
		_luz(marca("Ruleta").origin + Vector3(0.6, 1.5, -0.9), Color(1.0, 0.92, 0.75), 1.0, 2.2)
	if _marcas.has("Marca_Luz_baccarat"):
		_luz(marca("Luz_baccarat").origin, Color(1.0, 0.9, 0.7), 1.6, 3.2)
	if _marcas.has("Marca_Luz_blackjack"):
		_luz(marca("Luz_blackjack").origin, Color(1.0, 0.9, 0.7), 1.8, 3.5)
	# Las luces de color de la barra (con sus tiras de neon): rosa, cian, morado y la de abajo, azul
	for b in LUCES_BARRA.size():
		if _marcas.has("Marca_Luz_barra_%d" % b):
			_luz(marca("Luz_barra_%d" % b).origin, LUCES_BARRA[b], 1.1, 2.6)
	# La luz blanca del refri de la Tecatl, que sale por el vidrio
	if _marcas.has("Marca_Luz_refri"):
		_luz(marca("Luz_refri").origin, Color(0.8, 0.92, 1.0), 0.9, 2.2)


func _luz(donde: Vector3, color: Color, energia: float, alcance: float) -> OmniLight3D:
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = energia
	luz.omni_range = alcance
	luz.shadow_enabled = false
	luz.position = donde
	add_child(luz)
	return luz


# Un tubo o un neon que falla: se apaga a ratos, de a parpadeos
func _parpadear(luz: Node, energia: float) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(1.5, 6.0)).timeout
		for k in randi_range(2, 5):
			if not is_inside_tree():
				return
			_prender(luz, energia, false)
			await get_tree().create_timer(randf_range(0.04, 0.12)).timeout
			if not is_inside_tree():
				return
			_prender(luz, energia, true)
			await get_tree().create_timer(randf_range(0.03, 0.1)).timeout


func _prender(luz: Node, energia: float, si: bool) -> void:
	if luz is OmniLight3D:
		(luz as OmniLight3D).light_energy = energia if si else energia * 0.08
	elif luz is Label3D:
		(luz as Label3D).modulate.a = 1.0 if si else 0.15
	elif luz is Node3D:
		(luz as Node3D).visible = si


func _armar_neones() -> void:
	_foco_prendido = _foco_material(Color(1.0, 0.92, 0.6))
	_foco_apagado = _foco_material(Color(0.35, 0.28, 0.15))
	_focos = [[], []]
	var glb := NEONES_GLB.instantiate()
	for n: Array in NEONES:
		var t := marca(n[0])
		var modelo := glb.find_child("Neon_" + n[1], true, false) as Node3D
		if t == Transform3D() or modelo == null:
			continue
		var letrero := modelo.duplicate() as Node3D
		letrero.transform = t.scaled_local(Vector3.ONE * float(n[4]))
		add_child(letrero)
		for m: MeshInstance3D in letrero.find_children("*_focos_*", "MeshInstance3D", true, false):
			_focos[0 if m.name.ends_with("_a") else 1].append(m)
		var luz := _luz(t.origin + t.basis.z * 0.4, n[2], 1.2, 3.5)
		if n[3]:
			_parpadear(letrero, 1.0)
			_parpadear(luz, 1.2)
	glb.free()


static func _foco_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


# Los carteles de cerveza (textures/sotano/anuncios.png, de arte.py): un cuadro por cartel, con su
# parte del atlas; uno por cartel distinto, compartido
func _armar_anuncios() -> void:
	var k := 0
	while _marcas.has("Marca_Anuncio_%d" % k):
		var t := marca("Anuncio_%d" % k)
		var cartel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = ANUNCIO
		cartel.mesh = quad
		cartel.material_override = _material_cartel(CARTELES[k % CARTELES.size()])
		cartel.transform = t
		cartel.position += t.basis.z * 0.01
		add_child(cartel)
		k += 1


static var _carteles := {}

static func _material_cartel(i: int) -> StandardMaterial3D:
	if not _carteles.has(i):
		var m := StandardMaterial3D.new()
		m.albedo_texture = ANUNCIOS
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(1.0 / 6.0, 1.0, 1.0)
		m.uv1_offset = Vector3(i / 6.0, 0.0, 0.0)
		m.roughness = 0.9
		_carteles[i] = m
	return _carteles[i]


# --- Lo que se juega ---

func _armar_juegos() -> void:
	var k := 0
	while _marcas.has("Marca_OlPley_%d" % k):
		var t := marca("OlPley_%d" % k)
		var g := GabineteOlPley.new()
		g.name = "OlPley_%d" % k
		g.color = [0, 1, 2, 0, 2, 1, 0, 2, 1, 0][k % 10]
		g.transform = t
		add_child(g)
		add_child(MuebleCasa.crear("Jugar al Gordo", t.origin + t.basis.z * 0.7, _abrir_olpley.bind(g), 0.6))
		k += 1
	for i in 2:
		var t := marca("Frutas_%d" % i)
		var m := Maquinita.new()
		m.name = "Frutas_%d" % i
		m.id = "sotano_%d" % i
		m.set("moneda", "fichas")
		m.transform = t
		add_child(m)
	add_child(MuebleCasa.crear("Cambiar fichas", marca("Ventanilla").origin, _abrir.bind("res://scripts/sotano/VentanillaUI.gd", {}), 0.9))
	add_child(MuebleCasa.crear("Sentarte al póker", marca("Poker").origin, _abrir_poker, 1.0))
	if _marcas.has("Marca_Blackjack"):
		add_child(MuebleCasa.crear("Jugar blackjack", marca("Blackjack").origin, _abrir.bind("res://scripts/sotano/BlackjackUI.gd", {"sotano": self}), 0.9))
	if _marcas.has("Marca_Baccarat"):
		add_child(MuebleCasa.crear("Jugar baccarat", marca("Baccarat").origin, _abrir.bind("res://scripts/sotano/BaccaratUI.gd", {"sotano": self}), 0.9))
	if _marcas.has("Marca_Ruleta"):
		add_child(MuebleCasa.crear("Jugar a la ruleta", marca("Ruleta").origin, _abrir.bind("res://scripts/sotano/RuletaUI.gd", {"sotano": self}), 0.9))
	add_child(MuebleCasa.crear("Apostar a los caballitos", marca("Pista").origin, _abrir.bind("res://scripts/sotano/CarrerasUI.gd", {"sotano": self}), 1.0))
	add_child(MuebleCasa.crear("Comprar una caguama (%d fichas)" % CAGUAMA_FICHAS, marca("Congelador").origin, _caguama.bind(CAGUAMA_FICHAS, "Una caguama bien helada."), 1.0))
	add_child(MuebleCasa.crear("Pedir una Tecatl (%d fichas)" % CERVEZA_FICHAS, marca("Barra").origin, _caguama.bind(CERVEZA_FICHAS, "\"Ahí va, bien helada.\""), 1.0))
	add_child(MuebleCasa.crear("Mirar el altar", marca("Altar").origin, avisar.bind(TEXTO_ALTAR), 1.0))
	_armar_bano()


# --- El bano ---

var _bisagra: Node3D
var _puerta_tope: StaticBody3D
var _bano_abierto := false
var _espejo_linea := 0
var _caseta_linea := 0
var _gota_t := 0.0


func _armar_bano() -> void:
	var cuarto := get_node_or_null("Cuarto")
	_bisagra = cuarto.find_child("Bano_bisagra", true, false) as Node3D if cuarto else null
	add_child(MuebleCasa.crear("Abrir la puerta del baño", marca("Bano").origin, _puerta_bano, 0.9))
	# Mientras esta cerrada la puerta tapa (la malla no choca)
	if _bisagra:
		_puerta_tope = StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(0.1, 2.0, 0.9)
		forma.shape = caja
		_puerta_tope.add_child(forma)
		_puerta_tope.position = to_local(_bisagra.global_position) + Vector3(0.0, 1.0, 0.45)
		add_child(_puerta_tope)
	if not _marcas.has("Marca_Bano_centro"):
		return
	add_child(MuebleCasa.crear("Mirarte en el espejo", marca("Bano_espejo").origin, func() -> void:
		avisar(LINEAS_ESPEJO[_espejo_linea % LINEAS_ESPEJO.size()])
		_espejo_linea += 1, 0.8))
	add_child(MuebleCasa.crear("Tocar la caseta", marca("Bano_caseta").origin, func() -> void:
		avisar(LINEAS_CASETA[_caseta_linea % LINEAS_CASETA.size()])
		_caseta_linea += 1
		Sonidos.tocar(self, "golpe", -12.0, 0.7), 0.8))
	# El foco pelon que parpadea seguido, de color enfermo
	var foco := _luz(marca("Luz_bano").origin, Color(1.0, 0.82, 0.55), 0.9, 3.6)
	_parpadear(foco, 0.9)
	_parpadear(foco, 0.9)
	# La niebla: cuadros grandes casi transparentes que flotan despacio
	var niebla := CPUParticles3D.new()
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(1.4, 1.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.42, 0.45, 0.38, 0.09)
	# Suave en las orillas (un cuadro con orilla dura se veia como vidrio)
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1, 1, 1, 1))
	gradiente.set_color(1, Color(1, 1, 1, 0))
	var mancha := GradientTexture2D.new()
	mancha.gradient = gradiente
	mancha.fill = GradientTexture2D.FILL_RADIAL
	mancha.fill_from = Vector2(0.5, 0.5)
	mancha.fill_to = Vector2(0.5, 0.0)
	mancha.width = 64
	mancha.height = 64
	m.albedo_texture = mancha
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cuadro.material = m
	niebla.mesh = cuadro
	niebla.amount = 16
	niebla.lifetime = 9.0
	niebla.preprocess = 9.0
	niebla.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	niebla.emission_box_extents = Vector3(1.5, 0.7, 1.9)
	niebla.direction = Vector3(0.3, 0.1, 0.2)
	niebla.spread = 180.0
	niebla.gravity = Vector3.ZERO
	niebla.initial_velocity_min = 0.03
	niebla.initial_velocity_max = 0.08
	niebla.position = marca("Bano_centro").origin + Vector3(0.0, 0.9, 0.0)
	add_child(niebla)
	# La radio con estatica (en algun lado del bano) y las gotas
	var radio := AudioStreamPlayer3D.new()
	radio.stream = _estatica()
	radio.volume_db = -10.0
	radio.unit_size = 1.5
	radio.max_distance = 7.0
	radio.position = marca("Bano_caseta").origin + Vector3(0.0, 1.0, 0.0)
	add_child(radio)
	radio.play()


func _puerta_bano() -> void:
	if _bisagra == null:
		return
	_bano_abierto = not _bano_abierto
	var tween := create_tween()
	tween.tween_property(_bisagra, "rotation:y", deg_to_rad(PUERTA_BANO_ABIERTA) if _bano_abierto else 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sonidos.tocar(self, "boton", -6.0, 0.35)
	if _puerta_tope:
		_puerta_tope.process_mode = Node.PROCESS_MODE_DISABLED if _bano_abierto else Node.PROCESS_MODE_INHERIT
		(_puerta_tope.get_child(0) as CollisionShape3D).disabled = _bano_abierto


# Ruido de radio que no agarra estacion, en vuelta: soplido con chasquidos y un tono que va y viene
static func _estatica() -> AudioStreamWAV:
	var muestras := 22050
	var segundos := 3.0
	var datos := PackedByteArray()
	datos.resize(int(muestras * segundos) * 2)
	var azar := RandomNumberGenerator.new()
	azar.seed = 66
	var fase := 0.0
	for i in int(muestras * segundos):
		var t := float(i) / muestras
		var ruido := azar.randf_range(-1.0, 1.0) * (0.25 + 0.15 * sin(t * 2.3))
		if azar.randf() < 0.0015:
			ruido += azar.randf_range(-1.0, 1.0)
		fase += (180.0 + 40.0 * sin(t * 1.7)) / muestras
		ruido += sin(fase * TAU) * 0.05 * (0.5 + 0.5 * sin(t * 0.9))
		datos.encode_s16(i * 2, int(clampf(ruido, -1.0, 1.0) * 12000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = muestras
	wav.data = datos
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(muestras * segundos)
	return wav


func _abrir_poker() -> void:
	if ResourceLoader.exists("res://scripts/sotano/PokerUI.gd"):
		_abrir("res://scripts/sotano/PokerUI.gd", {"sotano": self})
	else:
		avisar("\"La mesa se arma más noche, mijo.\"")


# --- La gente fija ---

func _armar_gente() -> void:
	var primo := _hablador("Primo", "hombre_12", marca("Primo"), func() -> String:
		return "\"¿Cuántas fichas, mijo? Pásate a la ventanilla.\"")
	primo.look_at(to_global(marca("Ventanilla").origin), Vector3.UP)
	var guardia := _hablador("Guardia", "hombre_07", marca("Guardia"), _linea_guardia)
	guardia.look_at(to_global(Vector3(5.5, guardia.position.y, 3.1)), Vector3.UP)
	var cantinero := _hablador("Cantinero", "hombre_30", marca("Cantinero"), _rotar.bind(LINEAS_CANTINERO, "_cantinero_linea"))
	cantinero.look_at(to_global(marca("Barra").origin), Vector3.UP)
	var crupier := _hablador("Crupier", "hombre_16", marca("Crupier"), _rotar.bind(LINEAS_CRUPIER, "_jugadores_linea"))
	crupier.look_at(to_global(marca("Poker").origin), Vector3.UP)
	# La Guera en el blackjack y el de la ruleta
	if _marcas.has("Marca_Crupier_bj"):
		var guera := _hablador("Guera", "mujer_13", marca("Crupier_bj"), func() -> String:
			return "\"Siéntate, mijo. La casa paga 3 a 2... cuando paga.\"")
		guera.look_at(to_global(marca("Blackjack").origin), Vector3.UP)
	if _marcas.has("Marca_Crupier_baccarat"):
		var chepe := _hablador("Chepe", "hombre_02", marca("Crupier_baccarat"), func() -> String:
			return "\"Punto o banca, joven. El empate es para los soñadores.\"")
		chepe.look_at(to_global(marca("Baccarat").origin), Vector3.UP)
	if _marcas.has("Marca_Crupier_ruleta"):
		var ruletero := _hablador("Ruletero", "hombre_13", marca("Crupier_ruleta"), func() -> String:
			return "\"Rojo, negro o verde. Y si ganas, ¿le dobleteas?\"")
		ruletero.look_at(to_global(marca("Ruleta").origin), Vector3.UP)
	# Sentados: en cuatro EL GORDO y los tres del poker
	var mesa := marca("Poker").origin - Vector3(0, 0, 1.8)
	var sentados := [["Silla_0", "mujer_07"], ["Silla_2", "hombre_03"], ["Silla_5", "mujer_12"], ["Silla_7", "hombre_14"],
		["Poker_0", "hombre_15"], ["Poker_1", "hombre_31"], ["Poker_2", "mujer_29"],
		["Blackjack_0", "mujer_15"], ["Blackjack_1", "hombre_01"], ["Baccarat_0", "mujer_16"]]
	for k in sentados.size():
		var nombre: String = sentados[k][0]
		var t := marca(nombre)
		if t == Transform3D():
			continue
		var nodo := Node3D.new()
		nodo.name = "Jugador_%d" % k
		nodo.position = t.origin
		add_child(nodo)
		Civiles.poner(nodo, sentados[k][1], "Sitting_Idle")
		var mira := mesa if nombre.begins_with("Poker") else marca("OlPley_%s" % nombre.trim_prefix("Silla_")).origin
		if nombre.begins_with("Blackjack"):
			mira = marca("Crupier_bj").origin
		elif nombre.begins_with("Baccarat"):
			mira = marca("Crupier_baccarat").origin
		nodo.look_at(to_global(Vector3(mira.x, nodo.position.y, mira.z)), Vector3.UP)
		# Sitting_Idle deja la cadera CADERA atras del origen: se adelanta para que caiga en el asiento
		nodo.position -= nodo.transform.basis.z.normalized() * CADERA
		# Todos en algo: fuman o tienen su cerveza en la mano (VICIOS)
		if VICIOS.has(nombre):
			_dar(nodo, VICIOS[nombre])
	_armar_turbios()
	# Uno que platica de pie, junto a la columna
	var miron := _hablador("Miron", "hombre_09", Transform3D(Basis(), Vector3(15.4, -2.6, 3.6)), _linea_miron)
	miron.look_at(to_global(Vector3(15.4, miron.position.y, 0.0)), Vector3.UP)


# --- La gente turbia y lo que trae en la mano ---

func _armar_turbios() -> void:
	for t: Array in TURBIOS:
		var lineas: Array = t[6]
		var contador := {"n": 0}
		var nodo := _hablador(t[0], t[1], Transform3D(Basis(), Vector3(t[2].x, -2.6, t[2].y)), func() -> String:
			contador.n += 1
			return "\"%s\"" % lineas[(contador.n - 1) % lineas.size()])
		nodo.look_at(to_global(Vector3(t[3].x, nodo.position.y, t[3].y)), Vector3.UP)
		# (el npc ya puso su modelo al entrar al arbol)
		var clip: String = t[4]
		var cosa: String = t[5]
		var anim := nodo.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation(Civiles.LIB + "/" + clip):
			anim.get_animation(Civiles.LIB + "/" + clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(Civiles.LIB + "/" + clip)
		if cosa != "":
			_dar(nodo, cosa)
		if t[0] == "Halcon":
			_halcon = nodo
			_halcon_base = nodo.rotation.y


var _halcon: Node3D
var _halcon_t := 0.0
var _halcon_base := 0.0


# Una cosa en la mano derecha (cigarro, cerveza, paquete o billetes): un BoneAttachment3D en el
# hueso RightHand; la cosa se agranda 1/Civiles.ESCALA porque el modelo va a esa escala
func _dar(nodo: Node3D, cosa: String) -> void:
	var esqueletos := nodo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	var esq := esqueletos[0] as Skeleton3D
	var mano := BoneAttachment3D.new()
	mano.bone_name = "LeftHand" if cosa == "billetes" else "RightHand"
	esq.add_child(mano)
	var objeto := _cosa(cosa)
	# (el cigarro un poco mas grande que de verdad: a 640 x 480 no se veia)
	objeto.scale = Vector3.ONE / Civiles.ESCALA * (1.7 if cosa == "cigarro" else 1.0)
	mano.add_child(objeto)


static func _cosa(cosa: String) -> Node3D:
	var raiz := Node3D.new()
	match cosa:
		"cerveza":
			var botellas := (load("res://models/sotano/botellas.glb") as PackedScene).instantiate()
			var b := botellas.find_child("Botella_cerveza", true, false) as Node3D
			if b:
				var copia := b.duplicate() as Node3D
				copia.position = Vector3(0.0, -0.06, 0.03)
				raiz.add_child(copia)
			botellas.free()
		"cigarro":
			var palo := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.004
			c.bottom_radius = 0.004
			c.height = 0.06
			c.radial_segments = 5
			palo.mesh = c
			palo.material_override = _material_liso(Color(0.95, 0.93, 0.88))
			palo.rotation_degrees = Vector3(0, 0, 80)
			palo.position = Vector3(0.03, 0.0, 0.02)
			raiz.add_child(palo)
			var brasa := MeshInstance3D.new()
			var b2 := SphereMesh.new()
			b2.radius = 0.006
			b2.height = 0.012
			brasa.mesh = b2
			var m := _material_liso(Color(1.0, 0.45, 0.1))
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			brasa.material_override = m
			brasa.position = Vector3(0.06, 0.005, 0.02)
			raiz.add_child(brasa)
			brasa.add_child(_humo())
		"paquete":
			var caja := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.07, 0.05, 0.1)
			caja.mesh = bm
			caja.material_override = _material_liso(Color(0.45, 0.32, 0.18))
			caja.position = Vector3(0.0, -0.03, 0.04)
			raiz.add_child(caja)
		"billetes":
			for k in 4:
				var billete := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.12, 0.002, 0.055)
				billete.mesh = bm
				billete.material_override = _material_liso(Color(0.5, 0.72, 0.5) if k % 2 == 0 else Color(0.85, 0.6, 0.65))
				billete.position = Vector3(0.0, -0.02 - k * 0.003, 0.03)
				billete.rotation_degrees = Vector3(0, -20 + k * 14, 0)
				raiz.add_child(billete)
	return raiz


static var _lisos := {}


static func _material_liso(c: Color) -> StandardMaterial3D:
	if not _lisos.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		_lisos[c] = m
	return _lisos[c]


# El humo del cigarro: sube despacio en el mundo (no sigue a la mano), gris y suave
static func _humo() -> CPUParticles3D:
	var humo := CPUParticles3D.new()
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.75, 0.75, 0.75, 0.35)
	m.vertex_color_use_as_albedo = true
	cuadro.material = m
	humo.mesh = cuadro
	humo.local_coords = false
	humo.amount = 10
	humo.lifetime = 2.2
	humo.direction = Vector3.UP
	humo.spread = 12.0
	humo.gravity = Vector3(0.02, 0.06, 0.0)
	humo.initial_velocity_min = 0.04
	humo.initial_velocity_max = 0.09
	humo.scale_amount_min = 0.6
	humo.scale_amount_max = 1.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(1, 2.5))
	humo.scale_amount_curve = curva
	var desvanece := Gradient.new()
	desvanece.set_color(0, Color(1, 1, 1, 0.8))
	desvanece.set_color(1, Color(1, 1, 1, 0.0))
	humo.color_ramp = desvanece
	return humo


func _rotar(lineas: Array, contador: String) -> String:
	var n: int = get(contador)
	set(contador, n + 1)
	return lineas[n % lineas.size()]


# El miron sabe leer las senas: si una EL GORDO esta caliente te dice cual (contando desde la
# escalera); si no, platica
func _linea_miron() -> String:
	var k := 0
	while get_node_or_null("OlPley_%d" % k):
		var g := get_node("OlPley_%d" % k) as GabineteOlPley
		if g.placa.estado == Carretes.Estado.CALIENTE:
			return "Fíjate en el Gordo número %d, contando desde la escalera: le parpadea el foco. Esa ya va a pagar." % (k + 1)
		k += 1
	return _rotar(LINEAS_JUGADORES, "_jugadores_linea")


func _hablador(nombre: String, modelo: String, t: Transform3D, al_hablar: Callable) -> Node3D:
	var npc := NPC.instantiate() as Node3D
	npc.name = nombre
	npc.set("modelo", modelo)
	npc.set("dialogue", al_hablar.call())
	npc.set("al_hablar", al_hablar)
	npc.position = t.origin
	add_child(npc)
	return npc


func _armar_bocina() -> void:
	var musica := Sonidos.sonido("bocina_musica")
	if musica == null:
		return
	var voz := AudioStreamPlayer3D.new()
	voz.stream = musica
	voz.volume_db = -14.0
	voz.unit_size = 3.0
	voz.max_distance = 30.0
	voz.position = marca("Bocina").origin
	add_child(voz)
	voz.finished.connect(voz.play)
	voz.play()


func _armar_ventilador(cuarto: Node, v: int) -> void:
	var eje := cuarto.find_child("Ventilador_%d_eje" % v, true, false) as Node3D
	if eje == null:
		return
	var aspas := Node3D.new()
	aspas.name = "Aspas_%d" % v
	add_child(aspas)
	aspas.global_position = eje.global_position
	for i in 3:
		var aspa := cuarto.find_child("Ventilador_%d_aspa_%d" % [v, i], true, false) as Node3D
		if aspa:
			aspa.reparent(aspas, true)
	_aspas.append(aspas)


func _armar_texto() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 11
	add_child(capa)
	_texto = Label.new()
	_texto.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_texto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_texto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_texto.offset_bottom = -40.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	_texto.custom_minimum_size.x = 560.0
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 6)
	_texto.modulate.a = 0.0
	capa.add_child(_texto)


# --- La puerta: el de la cadena ---

func _puerta() -> void:
	var f := get_node_or_null("/root/Fichas")
	if f and f.permiso > 0:
		_quitar_cadena()
		return
	var guardia := get_node_or_null("Guardia") as Node3D
	# A un lado del de la puerta: su letrero no se encima con el de hablar con el
	var donde := guardia.position + Vector3(-0.8, 0, 0.9) if guardia else Vector3(6.2, -2.6, 3.1)
	_cuota = MuebleCasa.crear("Pagarle la cuota ($%d)" % (f.CUOTA if f else 300), donde, _pagar_cuota, 1.1)
	add_child(_cuota)


func _pagar_cuota() -> void:
	var f := get_node_or_null("/root/Fichas")
	if f == null:
		return
	if f.pagar_cuota():
		Sonidos.tocar(self, "moneda", -4.0)
		avisar("\"Órale. Ya eres de confianza. Pásale, y no le cuentes al padre.\"")
		_quitar_cadena()
		if _cuota:
			_cuota.queue_free()
			_cuota = null
	else:
		avisar("\"Son %d pesos, mijo. Regresa cuando traigas.\"" % f.CUOTA)


func _quitar_cadena() -> void:
	var cuarto := get_node_or_null("Cuarto")
	if cuarto == null:
		return
	for nombre in ["Cadena", "Poste_cadena_0", "Poste_cadena_1"]:
		var n := cuarto.find_child(nombre, true, false)
		if n is Node3D:
			(n as Node3D).visible = false
	# El choque: el cuerpo que el importador armo de "CadenaChoque-colonly"
	for cuerpo in cuarto.find_children("*", "StaticBody3D", true, false):
		if String(cuerpo.name).begins_with("Cadena"):
			cuerpo.queue_free()


func _linea_guardia() -> String:
	var f := get_node_or_null("/root/Fichas")
	if f and f.permiso > 0:
		var l: String = LINEAS_GUARDIA_PASA[_guardia_linea % LINEAS_GUARDIA_PASA.size()]
		_guardia_linea += 1
		return l
	var linea: String = LINEAS_GUARDIA[_guardia_linea % LINEAS_GUARDIA.size()]
	_guardia_linea += 1
	return linea % (f.CUOTA if f else 300) if "%d" in linea else linea


# --- Abrir juegos ---

func _abrir_olpley(g: GabineteOlPley) -> void:
	_abrir("res://scripts/sotano/OlPleyUI.gd", {"placa": g.placa, "gabinete": g})


func _abrir(ruta: String, datos: Dictionary) -> void:
	if get_tree().get_first_node_in_group("juego_sotano"):
		return
	var ui: CanvasLayer = load(ruta).new()
	for k in datos:
		ui.set(k, datos[k])
	ui.add_to_group("juego_sotano")
	get_tree().current_scene.add_child(ui)


# Una caguama del congelador o una Tecatl de la barra (las dos son la caguama del inventario)
func _caguama(fichas := CAGUAMA_FICHAS, texto := "Una caguama bien helada.") -> void:
	var f := get_node_or_null("/root/Fichas")
	var inventario := get_node_or_null("/root/Inventory")
	if f == null or inventario == null:
		return
	if not f.gastar(fichas):
		avisar("\"Son %d fichas, compa.\"" % fichas)
		return
	if inventario.add_item(load(CAGUAMA)):
		avisar(texto)
	else:
		f.fichas += fichas
		avisar("Ya no te cabe nada.")


# Antes de arrancar, el que la casa quiere que gane tiembla en su riel (la sena de la trampa)
func temblar(i: int) -> void:
	if i >= _caballos.size():
		return
	var c := _caballos[i]
	var z0 := c.position.z
	for k in 10:
		c.position.z = z0 + (0.01 if k % 2 == 0 else -0.01)
		await get_tree().create_timer(0.05).timeout
	c.position.z = z0


# La carrera: todos al arrancadero, salen a tirones y `ganador` llega primero a la meta (en x)
func correr(ganador: int) -> void:
	if _caballos.is_empty():
		return
	var n := _caballos.size()
	var llegan: Array[float] = []
	for i in n:
		_caballos[i].position.x = _caballos_x0[i]
		llegan.append(CARRERA * (1.0 if i == ganador else randf_range(1.06, 1.3)))
	var t := 0.0
	while t < CARRERA * 1.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		for i in n:
			var avance := clampf(t / llegan[i], 0.0, 1.0)
			avance = clampf(avance + sin(t * 9.0 + i * 1.7) * 0.012 * (1.0 - avance), 0.0, 1.0)
			_caballos[i].position.x = lerpf(_caballos_x0[i], PISTA_META, avance)
		if t > llegan.min() + 0.6 and t > CARRERA:
			break
	await get_tree().create_timer(0.8).timeout
	for i in n:
		_caballos[i].position.x = _caballos_x0[i]


# --- Ayudas ---

func marca(nombre: String) -> Transform3D:
	return _marcas.get("Marca_" + nombre, Transform3D())


# El transform de un nodo del cuarto en el espacio de esta raiz (sin contar la escala de la casa)
func _local(nodo: Node3D) -> Transform3D:
	var t := nodo.transform
	var padre := nodo.get_parent()
	while padre and padre != self:
		if padre is Node3D:
			t = (padre as Node3D).transform * t
		padre = padre.get_parent()
	return t


func avisar(texto: String) -> void:
	_texto.text = texto
	var tween := create_tween()
	tween.tween_property(_texto, "modulate:a", 1.0, 0.25)
	tween.tween_interval(5.0)
	tween.tween_property(_texto, "modulate:a", 0.0, 0.6)
