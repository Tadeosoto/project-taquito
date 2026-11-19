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
	["Neon", "gordo", Color(0.8, 0.4, 1.0), false, 0.75],
	["Neon_atras", "gordo", Color(0.8, 0.4, 1.0), false, 0.75],
	["Neon_premio", "premio", Color(1.0, 0.3, 0.75), false, 0.7],
	["Neon_abierto", "abierto", Color(0.3, 1.0, 0.6), true, 1.0],
	["Neon_poker", "poker", Color(1.0, 0.75, 0.3), false, 1.0],
	["Neon_barra", "barra", Color(1.0, 0.25, 0.15), false, 0.6],
	["Neon_bano", "bano", Color(0.3, 0.85, 1.0), true, 1.0],
]
const FOCOS := 0.35
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
const TEXTO_BANO := "\"¡Ocupado!\", gritan desde adentro. Huele a lo que huele."
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
	# Los focos de los neones se prenden por turnos, como en las ferias
	_focos_t += delta
	if _focos_t >= FOCOS and not _focos.is_empty():
		_focos_t = 0.0
		var turno := int(Time.get_ticks_msec() / int(FOCOS * 1000.0)) % 2
		for k in 2:
			for m: MeshInstance3D in _focos[k]:
				m.material_override = _foco_prendido if k == turno else _foco_apagado


func _physics_process(delta: float) -> void:
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
	add_child(MuebleCasa.crear("Apostar a los caballitos", marca("Pista").origin, _abrir.bind("res://scripts/sotano/CarrerasUI.gd", {"sotano": self}), 1.0))
	add_child(MuebleCasa.crear("Comprar una caguama (%d fichas)" % CAGUAMA_FICHAS, marca("Congelador").origin, _caguama.bind(CAGUAMA_FICHAS, "Una caguama bien helada."), 1.0))
	add_child(MuebleCasa.crear("Pedir una Tecatl (%d fichas)" % CERVEZA_FICHAS, marca("Barra").origin, _caguama.bind(CERVEZA_FICHAS, "\"Ahí va, bien helada.\""), 1.0))
	add_child(MuebleCasa.crear("Mirar el altar", marca("Altar").origin, avisar.bind(TEXTO_ALTAR), 1.0))
	add_child(MuebleCasa.crear("Tocar la puerta del baño", marca("Bano").origin, avisar.bind(TEXTO_BANO), 0.9))


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
	# Sentados: en cuatro EL GORDO y los tres del poker
	var mesa := marca("Poker").origin - Vector3(0, 0, 1.8)
	var sentados := [["Silla_0", "mujer_07"], ["Silla_2", "hombre_03"], ["Silla_5", "mujer_12"], ["Silla_7", "hombre_14"],
		["Poker_0", "hombre_15"], ["Poker_1", "hombre_31"], ["Poker_2", "mujer_29"]]
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
		nodo.look_at(to_global(Vector3(mira.x, nodo.position.y, mira.z)), Vector3.UP)
		# Sitting_Idle deja la cadera CADERA atras del origen: se adelanta para que caiga en el asiento
		nodo.position -= nodo.transform.basis.z.normalized() * CADERA
	# Uno que platica de pie, junto a la columna
	var miron := _hablador("Miron", "hombre_09", Transform3D(Basis(), Vector3(15.4, -2.6, 3.6)), _linea_miron)
	miron.look_at(to_global(Vector3(15.4, miron.position.y, 0.0)), Vector3.UP)


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
