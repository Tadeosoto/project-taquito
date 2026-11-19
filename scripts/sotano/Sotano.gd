extends Node3D

# Raiz del Sotano, el casino clandestino de los Gotera bajo unos abarrotes de Santa Mugre
# (scenes/casas/sotano.tscn; docs/lore.md 11 y docs/sistemas/sotano.md). Se entra caminando como
# las casas de los vecinos (CasaPropia.gd, marca "casa_vecino" con "abierto": "noche").
# El cuarto es el .glb de Blender (Cuarto, de tools/blender/sotano/sotano.py): sus vacios
# "Marca_*" dicen donde va cada cosa, y aqui se pone lo que se juega y quien esta:
#   el de la puerta y su cadena (Cadena-colonly): sin permiso (Fichas.permiso) no pasas, salvo que
#   le pagues la cuota; la ventanilla del Primo (VentanillaUI), seis OL PLEY (GabineteOlPley +
#   OlPleyUI), dos de frutas (Maquinita en fichas), la loteria (LoteriaUI), las carreras
#   (CarrerasUI, que mueve los caballitos con correr()), el congelador de caguamas, el altar, la
#   bocina, los tubos de luz (dos parpadean) y jugadores sentados.
# Todo en metros de la escena: CasaPropia la agranda x1.25.

const NPC := preload("res://scenes/npc.tscn")
const CAGUAMA := "res://resources/productos/caguama.tres"
const CAGUAMA_FICHAS := 3
const LUZ_COLOR := Color(0.85, 0.95, 1.0)
const LUZ_ENERGIA := 1.4
const LUZ_ALCANCE := 5.5
const PARPADEAN := [1, 4]           # los tubos que fallan
const NEON := Color(1.0, 0.3, 0.75)
const PISTA_META := 6.0             # z (del cuarto) donde llegan los caballitos
const CARRERA := 5.5                # s que dura una carrera
const VENTILADOR := 4.0             # rad/s

const LINEAS_GUARDIA := [
	"¿Y tú quién eres? Aquí abajo no hay nada, mijo. Nomás refrescos.",
	"Si no eres de los muchachos, son %d pesos. Una vez, y ya eres de confianza.",
	"Ándale, que no tengo tu tiempo.",
]
const LINEAS_GUARDIA_PASA := [
	"Pásale. Ya te conocen.",
	"Nada de fotos, nada de pleitos, nada de contarle al padre.",
]
const LINEAS_GRITON := [
	"¡Tablas a tres fichas! ¡Corre y se va corriendo!",
	"Aquí se canta derecho, mijo. Lo que salga, salió.",
	"Tacho siempre se sienta junto a mí. Es de la suerte.",
]
const LINEAS_JUGADORES := [
	"Esta maquinita me debe una casa.",
	"La de en medio está caliente. ¿Ves cómo parpadea? Ahorita paga.",
	"Mi vieja cree que ando en el rosario.",
	"El Tinaco paga doble. Eso sí es milagro.",
	"Allá afuera andan los poseídos; aquí abajo nomás andamos los perdidos.",
	"Ese Tacho gana mucho, ¿no? Nomás digo.",
]
const TEXTO_ALTAR := "La Virgen del Tinaco con billetes pegados alrededor. Al pie, en plumón: \"Para que no me mire. El Primo.\""
const TEXTO_FICHAS_AFUERA := "\"¡Oye! Allá afuera tus fichas no valen nada\", grita el Primo. \"Cámbialas aquí.\""

var _marcas := {}                   # "Marca_X" -> Transform3D en la escena
var _caballos: Array[Node3D] = []
var _caballos_z0: Array[float] = []
var _cadena: Node3D
var _luces: Array[OmniLight3D] = []
var _aspas: Node3D
var _texto: Label
var _guardia_linea := 0
var _griton_linea := 0
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
				_caballos_z0.append(c.position.z)
		_cadena = cuarto.find_child("Cadena", true, false) as Node3D
		_armar_ventilador(cuarto)
	_armar_texto()
	_armar_luces()
	_armar_juegos()
	_armar_gente()
	_armar_bocina()
	_puerta()


func _physics_process(_delta: float) -> void:
	if _aspas:
		_aspas.rotate_y(VENTILADOR * _delta)
	# Subiendo la escalera con fichas: el Primo te grita una vez
	if _player and not _aviso_fichas:
		var aqui := to_local(_player.global_position)
		var f := get_node_or_null("/root/Fichas")
		if aqui.x < 3.2 and aqui.y > -0.6 and f and f.fichas > 0:
			_aviso_fichas = true
			avisar(TEXTO_FICHAS_AFUERA)


# --- Lo que se arma ---

func _armar_luces() -> void:
	for i in 6:
		var t := marca("Luz_%d" % i)
		var luz := OmniLight3D.new()
		luz.light_color = LUZ_COLOR
		luz.light_energy = LUZ_ENERGIA
		luz.omni_range = LUZ_ALCANCE
		luz.shadow_enabled = false
		luz.position = t.origin
		add_child(luz)
		_luces.append(luz)
	for i in PARPADEAN:
		_parpadear(_luces[i])
	var neon := marca("Neon")
	var letrero := Label3D.new()
	letrero.text = "OL PLEY"
	letrero.font_size = 96
	letrero.pixel_size = 0.006
	letrero.modulate = NEON
	letrero.outline_modulate = Color(0.4, 0.0, 0.25)
	letrero.outline_size = 18
	letrero.shaded = false
	letrero.position = neon.origin - Vector3(0, 0, 0.27)
	add_child(letrero)
	var luz := OmniLight3D.new()
	luz.light_color = NEON
	luz.light_energy = 1.2
	luz.omni_range = 3.5
	luz.position = neon.origin + Vector3(0, -0.2, 0.3)
	add_child(luz)


# Un tubo que falla: se apaga a ratos, de a parpadeos
func _parpadear(luz: OmniLight3D) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(1.5, 6.0)).timeout
		if not is_inside_tree():
			return
		for k in randi_range(2, 5):
			luz.light_energy = 0.1
			await get_tree().create_timer(randf_range(0.04, 0.12)).timeout
			if not is_inside_tree():
				return
			luz.light_energy = LUZ_ENERGIA
			await get_tree().create_timer(randf_range(0.03, 0.1)).timeout
			if not is_inside_tree():
				return


func _armar_juegos() -> void:
	# Las seis OL PLEY: rojas, negras y moradas revueltas
	for i in 6:
		var t := marca("OlPley_%d" % i)
		var g := GabineteOlPley.new()
		g.name = "OlPley_%d" % i
		g.color = [0, 1, 2, 0, 2, 1][i]
		g.transform = t
		add_child(g)
		add_child(MuebleCasa.crear("Jugar OL PLEY", t.origin + t.basis.z * 0.7, _abrir_olpley.bind(g), 0.6))
	# Dos de frutas, en fichas y abiertas de noche
	for i in 2:
		var t := marca("Frutas_%d" % i)
		var m := Maquinita.new()
		m.name = "Frutas_%d" % i
		m.id = "sotano_%d" % i
		m.set("moneda", "fichas")
		m.transform = t
		add_child(m)
	add_child(MuebleCasa.crear("Cambiar fichas", marca("Ventanilla").origin, _abrir.bind("res://scripts/sotano/VentanillaUI.gd", {}), 0.9))
	add_child(MuebleCasa.crear("Jugar a la lotería", marca("Loteria").origin, _abrir.bind("res://scripts/sotano/LoteriaUI.gd", {}), 1.0))
	add_child(MuebleCasa.crear("Apostar a los caballitos", marca("Pista").origin, _abrir.bind("res://scripts/sotano/CarrerasUI.gd", {"sotano": self}), 1.0))
	add_child(MuebleCasa.crear("Comprar una caguama (%d fichas)" % CAGUAMA_FICHAS, marca("Congelador").origin, _caguama, 1.0))
	add_child(MuebleCasa.crear("Mirar el altar", marca("Altar").origin, avisar.bind(TEXTO_ALTAR), 1.0))


func _armar_gente() -> void:
	var primo := _hablador("Primo", "hombre_12", marca("Primo"), func() -> String:
		return "\"¿Cuántas fichas, mijo? Pásate a la ventanilla.\"")
	primo.look_at(to_global(marca("Ventanilla").origin), Vector3.UP)
	var guardia := _hablador("Guardia", "hombre_07", marca("Guardia"), _linea_guardia)
	guardia.look_at(to_global(Vector3(5.5, guardia.position.y, 3.1)), Vector3.UP)
	var griton := _hablador("Griton", "hombre_30", marca("Griton"), func() -> String:
		var l: String = LINEAS_GRITON[_griton_linea % LINEAS_GRITON.size()]
		_griton_linea += 1
		return l)
	griton.look_at(to_global(Vector3(10.9, griton.position.y, 5.3)), Vector3.UP)
	# Jugadores sentados: en tres OL PLEY y en tres bancos de la loteria (Tacho, el palero, junto al griton)
	var sentados := [["Silla_0", "mujer_07"], ["Silla_2", "hombre_03"], ["Silla_5", "mujer_12"],
		["Banco_0", "mujer_29"], ["Banco_1", "hombre_15"], ["Banco_3", "hombre_31"]]
	for k in sentados.size():
		var t := marca(sentados[k][0])
		var nodo := Node3D.new()
		nodo.name = "Jugador_%d" % k
		# El clip de sentado ya trae la altura de la silla: el civil va al piso
		nodo.position = t.origin
		add_child(nodo)
		Civiles.poner(nodo, sentados[k][1], "Sitting_Idle")
		var mira := marca("OlPley_%d" % int(String(sentados[k][0]).right(1))).origin if String(sentados[k][0]).begins_with("Silla") \
			else Vector3(10.9, nodo.position.y, 5.3)
		nodo.look_at(to_global(Vector3(mira.x, nodo.position.y, mira.z)), Vector3.UP)
	# Uno que platica de pie, junto a la pista
	var miron := _hablador("Miron", "hombre_09", Transform3D(Basis(), Vector3(14.6, -2.6, 6.4)), _linea_miron)
	miron.look_at(to_global(Vector3(16.0, miron.position.y, 3.5)), Vector3.UP)


# El miron sabe leer las senas: si una OL PLEY esta caliente te dice cual (contando desde la
# escalera); si no, platica
func _linea_miron() -> String:
	for i in 6:
		var g := get_node_or_null("OlPley_%d" % i) as GabineteOlPley
		if g and g.placa.estado == Carretes.Estado.CALIENTE:
			return "Fíjate en la %s de la izquierda: le parpadea el foco de arriba. Esa ya va a pagar." % ["primera", "segunda", "tercera", "cuarta", "quinta", "sexta"][i]
	var l: String = LINEAS_JUGADORES[_jugadores_linea % LINEAS_JUGADORES.size()]
	_jugadores_linea += 1
	return l


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


func _armar_ventilador(cuarto: Node) -> void:
	var eje := cuarto.find_child("Ventilador_eje", true, false) as Node3D
	if eje == null:
		return
	_aspas = Node3D.new()
	_aspas.name = "Aspas"
	add_child(_aspas)
	_aspas.global_position = eje.global_position
	for i in 3:
		var aspa := cuarto.find_child("Ventilador_aspa_%d" % i, true, false) as Node3D
		if aspa:
			aspa.reparent(_aspas, true)


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
	var donde := guardia.position + Vector3(-0.8, 0, 0) if guardia else Vector3(6.2, -2.6, 3.1)
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
	# El choque: el cuerpo que el importador armo de "Cadena-colonly"
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


# --- Juegos ---

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


func _caguama() -> void:
	var f := get_node_or_null("/root/Fichas")
	var inventario := get_node_or_null("/root/Inventory")
	if f == null or inventario == null:
		return
	if not f.gastar(CAGUAMA_FICHAS):
		avisar("\"Son %d fichas, compa.\"" % CAGUAMA_FICHAS)
		return
	if inventario.add_item(load(CAGUAMA)):
		avisar("Una caguama bien helada.")
	else:
		f.fichas += CAGUAMA_FICHAS
		avisar("Ya no te cabe nada.")


# Antes de arrancar, el que la casa quiere que gane tiembla en su riel (la sena de la trampa)
func temblar(i: int) -> void:
	if i >= _caballos.size():
		return
	var c := _caballos[i]
	var x0 := c.position.x
	for k in 10:
		c.position.x = x0 + (0.01 if k % 2 == 0 else -0.01)
		await get_tree().create_timer(0.05).timeout
	c.position.x = x0


# La carrera: todos al arrancadero, salen a tirones y `ganador` llega primero a la meta
func correr(ganador: int) -> void:
	if _caballos.is_empty():
		return
	var n := _caballos.size()
	var llegan: Array[float] = []
	for i in n:
		_caballos[i].position.z = _caballos_z0[i]
		llegan.append(CARRERA * (1.0 if i == ganador else randf_range(1.06, 1.3)))
	var t := 0.0
	while t < CARRERA * 1.3:
		await get_tree().process_frame
		t += get_process_delta_time()
		for i in n:
			var avance := clampf(t / llegan[i], 0.0, 1.0)
			# a tirones, como los de la feria
			avance = clampf(avance + sin(t * 9.0 + i * 1.7) * 0.012 * (1.0 - avance), 0.0, 1.0)
			_caballos[i].position.z = lerpf(_caballos_z0[i], PISTA_META, avance)
		if t > llegan.min() + 0.6 and t > CARRERA:
			break
	await get_tree().create_timer(0.8).timeout
	for i in n:
		_caballos[i].position.z = _caballos_z0[i]


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
