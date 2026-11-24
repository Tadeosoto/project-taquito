class_name PalacioOficinas
extends Node3D

## Las oficinas de GelA dentro del palacio de gobierno (El Decreto 47, Sofia; JJ 2026-11-20: los papeles se buscan
## en el palacio, ya no en la bodega de GelA). El modelo del palacio es solo fachada: al fondo del portal va una
## puerta de madera que se FUERZA de noche con la mision (Espacio FORZAR s, como la cortina de BodegaGela: el ruido
## trae zombis de la calle). Abierta (Misiones.palacio_abierto, para siempre) es una flecha amarilla que te sube a
## las oficinas: un piso armado aqui mismo, ALTURA m arriba del palacio, que se camina con el jugador de verdad y
## CON pelea (no como CasaPropia). Un pasillo recto con dos oficinas por lado y el archivo al fondo, donde estan los
## papeles (MisionesMundo, `papeles_decreto`); adentro salen ADENTRO_ZOMBIS cada vez que entras por ellos.
## Adentro no hay zombis espontaneos y los zombis van derecho (Zombis.sin_campo): el campo de flujo mide a 1 m del
## suelo de abajo y no ve estas paredes; por eso el piso es un pasillo recto.
## Lo crea FortalezasMapa._palacio con el transform del palacio: los ejes son los suyos (origen al pie del portal,
## +Z hacia la plaza; la pared del fondo del portal esta en z = -0.3).

const ALTURA := 500.0
const FORZAR := 5.0            # s con Espacio apretado
const ALCANCE := 3.0           # m de la puerta para forzarla
const RUIDO_CADA := 0.6
const RUIDO_ZOMBIS := 3
const RUIDO_A := 35.0
const ADENTRO_ZOMBIS := 4
const FUNDIDO := 0.3
const TEXTO_DIA := "De día hay cuicos cuidando el palacio. Vuelve de noche."
const TEXTO_ENTRAR := "Oficinas del palacio"
const TEXTO_SALIR := "Sal por la puerta"

## Afuera, en los ejes del palacio: la puerta (al fondo del portal, al centro) y la flecha para entrar
const PUERTA := Vector3(0.0, 0.0, -0.15)
const PUERTA_TAM := Vector3(2.6, 3.6, 0.12)
const ENTRAR_EN := Vector3(0.0, 0.0, 1.6)
const SALES_EN := Vector3(0.0, 0.0, 3.6)     # donde te deja al salir, viendo a la plaza
## Adentro (sobre ALTURA): donde apareces, la flecha para salir, y los papeles en el archivo
const APARECES := Vector3(0.0, 0.0, -2.6)
const SALIR_EN := Vector3(0.0, 0.0, -0.9)
const PAPELES := [Vector3(-5.6, 0.0, -31.2), Vector3(5.6, 0.0, -31.2)]   # sobre las mesas del fondo (0.76 m)
const ZOMBIS_EN := [Vector3(-3.0, 0.0, -26.0), Vector3(3.0, 0.0, -29.5), Vector3(0.0, 0.0, -18.0), Vector3(1.5, 0.0, -21.0)]

## La planta (m): pasillo, oficinas a los lados y archivo al fondo
const PASILLO := 2.5           # medio ancho
const LADO := 8.5              # hasta la pared de afuera
const PASILLO_HASTA := -22.0
const ARCHIVO_MEDIO := 7.0
const ARCHIVO_HASTA := -32.0
const ALTO := 3.4
const GRUESO := 0.3
const CORTE_OFICINAS := -11.0  # la pared entre las dos oficinas de cada lado
const VANOS := [-5.75, -16.25] # centro de la puerta de cada oficina, en la pared del pasillo
const VANO := 1.8

## Adentro: backrooms en ruinas (JJ, 2026-11-20). Texturas de tools/map_import/make_texturas_oficinas.py
const DIR_TEX := "res://textures/palacio_oficinas/"
const TEXTURA_CADA := 2.0
const COLOR_ZOCLO := Color(0.28, 0.22, 0.13)
const ZOCLO := 0.12
const PLAFON := 0.6            # placas del plafon
const SEMILLA := 4747          # todo lo revuelto sale de aqui: siempre igual
const COLOR_MADERA := Color(0.36, 0.22, 0.12)
const COLOR_METAL := Color(0.45, 0.47, 0.48)
const COLOR_CARTON := Color(0.62, 0.5, 0.33)
const COLOR_PAPEL := Color(0.9, 0.88, 0.8)
const COLOR_LUZ := Color(1.0, 0.92, 0.68)
const COLOR_AMBIENTE := Color(0.07, 0.06, 0.035)
const LUZ_TENUE := 0.55
const LUZ_PARPADEA := 0.95
const LUZ_ALCANCE := 6.5
## Las lamparas de tubo (x, z del centro del panel de 0.6 x 1.2 m, en la reja del plafon) y como estan. Casi todas
## muertas: la oficina de atras a la derecha queda a oscuras y de ahi sale el rastro de sangre
const LAMPARAS := [
	[0.0, -1.8, "apagada"], [0.0, -4.2, "tenue"], [0.0, -6.6, "apagada"], [0.0, -9.0, "parpadea"],
	[0.0, -11.4, "apagada"], [0.0, -13.8, "rota"], [0.0, -16.2, "parpadea"], [0.0, -18.6, "apagada"], [0.0, -21.0, "tenue"],
	[5.4, -3.6, "parpadea"], [5.4, -7.2, "apagada"], [5.4, -13.8, "apagada"], [5.4, -19.2, "apagada"],
	[-5.4, -3.6, "tenue"], [-5.4, -7.2, "apagada"], [-5.4, -13.8, "parpadea"], [-5.4, -19.2, "rota"],
	[0.0, -26.4, "parpadea"], [0.0, -30.0, "tenue"], [-5.4, -30.0, "apagada"], [5.4, -30.0, "parpadea"],
]
## Placas del plafon que faltan (centro de su celda): hoyo negro, la placa colgando o tirada, cascajo y a veces un
## cable; abajo de las de CHARCOS gotea y hay charco
const HOYOS := [[0.6, -2.7], [-1.2, -8.1], [0.0, -12.3], [1.2, -14.7], [-0.6, -19.5], [6.0, -5.1], [-4.2, -9.3],
	[4.8, -17.1], [-6.6, -15.9], [-1.8, -25.5], [2.4, -29.1], [-4.2, -31.5]]
const CHARCOS := [1, 4, 9]

## Lo que leen MisionesMundo y la prueba: el marco del palacio (listo cuando se arma) y si estas adentro
static var listo := false
static var marco := Transform3D.IDENTITY
static var adentro := false

var _materiales := {}
var _hojas: Array[Node3D] = []
var _entrar: Node3D
var _salir: Node3D
var _letrero: Label3D
var _negro: ColorRect
var _aviso: Label
var _progreso := 0.0
var _forzando := false
var _hizo_ruido := false
var _golpe_en := 0.0
var _ocupado := false
var _armada := false   # la flecha cuenta hasta que te bajas de ella una vez (al abrir, al entrar o al salir estabas encima)
var _espontaneos := true
var _piso: Node3D
var _azar := RandomNumberGenerator.new()
var _tramos: Array = []                 # las paredes [a, b], para la mugre
var _parpadeo: Array[Dictionary] = []   # las lamparas que parpadean (_parpadear)
var _zumbidos: Array[AudioStreamPlayer3D] = []
var _despegados: Array[Vector3] = []     # donde quedo el papel despegado y hacia donde ve (para las fotos)
var _despegados_n: Array[Vector3] = []


## Afuera, en metros del juego: frente a la puerta (a donde apunta la flecha de la mision)
static func frente_puerta() -> Vector3:
	return marco * ENTRAR_EN


static func papel(i: int) -> Vector3:
	return marco * (PAPELES[i] + Vector3.UP * ALTURA)


func _enter_tree() -> void:
	marco = transform
	listo = true
	adentro = false


func _exit_tree() -> void:
	listo = false
	adentro = false


func _ready() -> void:
	add_to_group("interactuable")
	_puerta()
	_oficinas()
	_entrar = _marcador(ENTRAR_EN, 0.0, _al_entrar)
	add_child(_entrar)
	_salir = _marcador(SALIR_EN + Vector3.UP * ALTURA, PI, _al_salir)
	add_child(_salir)
	_letrero = Label3D.new()
	_letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_letrero.font_size = 48
	_letrero.pixel_size = 0.01
	_letrero.outline_size = 12
	_letrero.no_depth_test = true
	_letrero.visible = false
	_letrero.position = PUERTA + Vector3(0.0, 2.4, 0.8)
	add_child(_letrero)
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	capa.add_child(_negro)
	_aviso = Label.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.offset_top = 24.0
	_aviso.add_theme_color_override("font_color", MapPuntos.MARCADOR_COLOR)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.modulate.a = 0.0
	capa.add_child(_aviso)
	_mostrar(Misiones.palacio_abierto)


func _mostrar(abierta: bool) -> void:
	# Las dos hojas se abren hacia adentro (contra la pared, sin choque: detras no hay nada)
	for i in _hojas.size():
		_hojas[i].rotation.y = (-1.0 if i == 0 else 1.0) * (deg_to_rad(80.0) if abierta else 0.0)
	_entrar.visible = abierta


# --- La puerta (afuera) ---

func _puerta() -> void:
	var madera := _material("madera", COLOR_MADERA)
	var marco_puerta := _caja(self, PUERTA + Vector3(0.0, PUERTA_TAM.y + 0.15, 0.02), Vector3(PUERTA_TAM.x + 0.5, 0.3, 0.2), _material("metal", COLOR_METAL))
	marco_puerta.name = "Dintel"
	# Lo de detras de la puerta: oscuro (el modelo no tiene nada)
	_caja(self, PUERTA + Vector3(0.0, PUERTA_TAM.y / 2.0, -0.05), Vector3(PUERTA_TAM.x, PUERTA_TAM.y, 0.02), _material("negro", Color(0.02, 0.02, 0.02)))
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		var bisagra := Node3D.new()
		bisagra.name = "Hoja%d" % i
		bisagra.position = PUERTA + Vector3(lado * PUERTA_TAM.x / 2.0, 0.0, 0.0)
		add_child(bisagra)
		_caja(bisagra, Vector3(-lado * PUERTA_TAM.x / 4.0, PUERTA_TAM.y / 2.0, 0.0), Vector3(PUERTA_TAM.x / 2.0 - 0.02, PUERTA_TAM.y, PUERTA_TAM.z), madera)
		_hojas.append(bisagra)
	var placa := Label3D.new()
	placa.text = "OFICINAS\nGobierno del Estado · GelA"
	placa.font_size = 40
	placa.pixel_size = 0.008
	placa.outline_size = 8
	placa.position = PUERTA + Vector3(0.0, PUERTA_TAM.y + 0.65, 0.1)
	placa.visibility_range_end = 30.0
	add_child(placa)


func _jugador() -> Player:
	return get_tree().get_first_node_in_group("jugador") as Player


func _de_la_mision() -> bool:
	return Misiones.activa != null and Misiones.activa.id == "decreto_47" and Misiones.paso() != null \
			and Misiones.paso().lugar == "papeles_decreto"


func _cerca() -> bool:
	var j := _jugador()
	if j == null:
		return false
	var p := marco * PUERTA
	return Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(p.x, p.z)) <= ALCANCE and j.global_position.y < ALTURA / 2.0


## Para el Espacio del jugador (Player._nearby_interactable): solo en la mision y mientras siga cerrada
func is_player_inside() -> bool:
	return not Misiones.palacio_abierto and _de_la_mision() and _cerca()


func interact() -> void:
	if Misiones.palacio_abierto or not _de_la_mision():
		return
	if Misiones.hora_que_falta(Misiones.paso()) != "":
		var supervivencia := get_tree().get_first_node_in_group("supervivencia")
		if supervivencia and supervivencia.has_method("avisar"):
			supervivencia.avisar(TEXTO_DIA)
		Sonidos.tocar(self, "ui_error", -6.0)
		return
	_forzando = true
	if not _hizo_ruido:
		_hizo_ruido = true
		var desde := marco * PUERTA
		_sacar(RUIDO_ZOMBIS, func(_k: int) -> Vector3:
			var lado := Vector2.from_angle(randf() * TAU) * RUIDO_A
			return desde + Vector3(lado.x, 0.0, lado.y))


func _process(delta: float) -> void:
	if _piso.visible:
		_parpadear(delta)
	if not _forzando:
		return
	if not Input.is_action_pressed("jump") or not _cerca():
		_forzando = false
		_letrero.visible = false
		return
	_progreso += delta
	_letrero.visible = true
	_letrero.text = "Forzando la puerta... %d%%" % mini(roundi(100.0 * _progreso / FORZAR), 100)
	_golpe_en -= delta
	if _golpe_en <= 0.0:
		_golpe_en = RUIDO_CADA
		Sonidos.tocar(self, "golpe_seco", -4.0)
	if _progreso >= FORZAR:
		_abrir()


func _abrir() -> void:
	_forzando = false
	_letrero.visible = false
	Misiones.palacio_abierto = true
	_armada = false
	_mostrar(true)
	Sonidos.tocar(self, "bloqueo", -6.0)
	Misiones.cambio.emit()


func _sacar(cuantos: int, donde: Callable) -> void:
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando == null:
		return
	for k in cuantos:
		mando.sacar(donde.call(k), false)


# --- Entrar y salir ---

func _marcador(lugar: Vector3, giro: float, al_pisar: Callable) -> Node3D:
	var area := Node3D.new()
	area.position = lugar
	area.rotation.y = giro
	# Se pisa por distancia (_physics_process): body_entered no sale si ya estabas encima al abrirse la puerta
	area.set_meta("al_pisar", al_pisar)
	area.add_child(MapPuntos.flecha())
	return area


func _al_entrar() -> void:
	if _ocupado or adentro or not Misiones.palacio_abierto:
		return
	_ocupado = true
	var jugador := _jugador()
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	await _fundir(1.0)
	adentro = true
	ver_piso(true)
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando:
		_espontaneos = mando.espontaneos
		mando.espontaneos = false
		mando.sin_campo = true
	_poner(jugador, APARECES + Vector3.UP * (ALTURA + 1.2), Vector3.FORWARD)
	# Por los papeles: los de adentro (cada vez que entras por ellos; de noche, como en la mision)
	if _de_la_mision() and Misiones.es_noche:
		_sacar(ADENTRO_ZOMBIS, func(k: int) -> Vector3:
			return marco * (ZOMBIS_EN[k % ZOMBIS_EN.size()] + Vector3.UP * (ALTURA + 0.1)))
	await _fundir(0.0)
	_avisar(TEXTO_ENTRAR)
	_ocupado = false
	Misiones.cambio.emit()


func _al_salir() -> void:
	if _ocupado or not adentro:
		return
	_ocupado = true
	var jugador := _jugador()
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	await _fundir(1.0)
	_ya_afuera()
	_poner(jugador, SALES_EN + Vector3.UP * 1.2, Vector3.BACK)
	await _fundir(0.0)
	_ocupado = false
	Misiones.cambio.emit()


func _ya_afuera() -> void:
	adentro = false
	ver_piso(false)
	var mando := get_tree().get_first_node_in_group("zombis_mando") as Zombis
	if mando:
		mando.espontaneos = _espontaneos
		mando.sin_campo = false


func _physics_process(_delta: float) -> void:
	var jugador := _jugador()
	if jugador == null or _ocupado:
		return
	# Te desmayaste adentro: Supervivencia te bajo por su cuenta
	if adentro and jugador.global_position.y < ALTURA - 50.0:
		_ya_afuera()
	var flecha := _salir if adentro else (_entrar if Misiones.palacio_abierto else null)
	if flecha == null:
		return
	var en := flecha.global_position
	var lejos := Vector2(jugador.global_position.x, jugador.global_position.z).distance_to(Vector2(en.x, en.z))
	var encima := lejos <= MapPuntos.MARCADOR_RADIO and absf(jugador.global_position.y - en.y) < 2.5
	if not encima:
		_armada = true
	elif _armada:
		_armada = false
		(flecha.get_meta("al_pisar") as Callable).call()


# `local` en los ejes del palacio; `hacia` a donde ve, tambien en sus ejes
func _poner(jugador: Player, local: Vector3, hacia: Vector3) -> void:
	var d := marco.basis * hacia
	var giro := atan2(-d.x, -d.z)
	jugador.global_position = marco * local
	jugador.velocity = Vector3.ZERO
	jugador.camera_pivot.global_rotation.y = giro
	jugador.frijol.global_rotation.y = giro
	jugador.process_mode = Node.PROCESS_MODE_INHERIT


func _fundir(alfa: float) -> void:
	var tween := create_tween()
	tween.tween_property(_negro, "modulate:a", alfa, FUNDIDO)
	await tween.finished


func _avisar(texto: String) -> void:
	_aviso.text = "%s\n%s" % [texto, TEXTO_SALIR]
	var tween := create_tween()
	tween.tween_property(_aviso, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.8)


# --- Las oficinas (arriba): backrooms en ruinas ---
# Papel tapiz amarillo, alfombra humeda, plafon con placas que faltan y lamparas de tubo casi todas muertas: unas
# apagadas, unas tenues y otras que parpadean con su zumbido. Humedad que escurre del techo, papel tapiz
# despegado y grietas, sangre, muebles volcados, papeles por todos lados. Lo que estorba al caminar (escritorios, archiveros,
# estantes) choca; el cascajo, los papeles y las placas tiradas no, para que el pasillo y el archivo queden libres
# (los zombis de adentro van derecho, Zombis.sin_campo). Todo sale de SEMILLA: siempre igual.

func _oficinas() -> void:
	_azar.seed = SEMILLA
	_piso = Node3D.new()
	_piso.name = "Oficinas"
	_piso.position.y = ALTURA
	_piso.visible = false
	add_child(_piso)
	var piso := _piso
	var pared := _material("pared", Color.WHITE, DIR_TEX + "papel_tapiz.png")
	var fondo := ARCHIVO_HASTA
	# Piso (alfombra) y techo (plafon); el techo un poco mas ancho que la planta, que no se asome nada
	_bloque(piso, Vector3(0.0, -0.1, fondo / 2.0), Vector3(LADO * 2.0, 0.2, -fondo), _material("alfombra", Color.WHITE, DIR_TEX + "alfombra.png"))
	var techo := _bloque(piso, Vector3(0.0, ALTO + 0.1, fondo / 2.0), Vector3(LADO * 2.0 + 0.6, 0.2, -fondo + 0.6), _material("plafon", Color.WHITE, DIR_TEX + "plafon.png", 1.2))
	techo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Que adentro no alumbre el cielo: el techo y las paredes tapan el sol (que tiene sombras) y el ambiente es casi
	# negro (una sonda de interior manda sobre el ambiente del Environment, que Ciclo cambia con la hora)
	var sonda := ReflectionProbe.new()
	sonda.size = Vector3(LADO * 2.0 + 1.0, ALTO + 1.0, -fondo + 1.0)
	sonda.position = Vector3(0.0, ALTO / 2.0, fondo / 2.0)
	sonda.interior = true
	sonda.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	sonda.ambient_color = COLOR_AMBIENTE
	sonda.ambient_color_energy = 1.0
	sonda.update_mode = ReflectionProbe.UPDATE_ONCE
	piso.add_child(sonda)
	# Las de afuera: el frente (con la puerta pintada por dentro), los costados, el escalon al archivo y el fondo
	_pared(piso, Vector2(-LADO, 0.0), Vector2(LADO, 0.0), pared)
	for s in [-1.0, 1.0]:
		_pared(piso, Vector2(s * LADO, 0.0), Vector2(s * LADO, PASILLO_HASTA), pared)
		_pared(piso, Vector2(s * PASILLO, PASILLO_HASTA), Vector2(s * LADO, PASILLO_HASTA), pared)
		_pared(piso, Vector2(s * ARCHIVO_MEDIO, PASILLO_HASTA), Vector2(s * ARCHIVO_MEDIO, fondo), pared)
		# Entre las dos oficinas de ese lado
		_pared(piso, Vector2(s * PASILLO, CORTE_OFICINAS), Vector2(s * LADO, CORTE_OFICINAS), pared)
		# La del pasillo, con un vano por oficina
		var desde := 0.0
		for vano: float in VANOS:
			_pared(piso, Vector2(s * PASILLO, desde), Vector2(s * PASILLO, vano + VANO / 2.0), pared)
			desde = vano - VANO / 2.0
		_pared(piso, Vector2(s * PASILLO, desde), Vector2(s * PASILLO, PASILLO_HASTA), pared)
	_pared(piso, Vector2(-ARCHIVO_MEDIO, fondo), Vector2(ARCHIVO_MEDIO, fondo), pared)
	# La puerta por dentro y el letrero verde de salida encima (lo unico que siempre se ve)
	_caja(piso, Vector3(0.0, PUERTA_TAM.y / 2.0, -GRUESO / 2.0 - 0.03), Vector3(PUERTA_TAM.x, PUERTA_TAM.y, 0.06), _material("madera", COLOR_MADERA))
	_salida(piso)
	_plafon(piso)
	_lamparas(piso)
	_muebles(piso)
	_mugre(piso)


## Mostrar el piso solo con alguien adentro (y la prueba de fotos): ahorra sus luces y su zumbido afuera
func ver_piso(si: bool) -> void:
	_piso.visible = si
	for p: Dictionary in _parpadeo:
		var voz := p["voz"] as AudioStreamPlayer3D
		if voz:
			voz.playing = si
			voz.stream_paused = not p["prendida"]
	for voz: AudioStreamPlayer3D in _zumbidos:
		voz.playing = si


func _salida(piso: Node3D) -> void:
	var letrero := Label3D.new()
	letrero.text = "SALIDA"
	letrero.font_size = 40
	letrero.pixel_size = 0.006
	letrero.outline_size = 6
	letrero.modulate = Color(0.3, 1.0, 0.45)
	letrero.outline_modulate = Color(0.0, 0.15, 0.05)
	letrero.shaded = false
	letrero.position = Vector3(0.0, PUERTA_TAM.y + 0.3, -GRUESO / 2.0 - 0.08)
	letrero.rotation.y = PI
	piso.add_child(letrero)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.3, 1.0, 0.45)
	luz.light_energy = 0.35
	luz.omni_range = 3.5
	luz.position = letrero.position + Vector3(0.0, 0.0, -0.3)
	piso.add_child(luz)


# La reja de aluminio del plafon (cada PLAFON m, una sola malla) y las placas que faltan (HOYOS)
func _plafon(piso: Node3D) -> void:
	var rieles: Array = []
	var y := ALTO - 0.012
	var x := -LADO + 0.2
	while x < LADO:
		var linea := snappedf(x - PLAFON / 2.0, PLAFON) + PLAFON / 2.0
		rieles.append([Vector3(linea, y, ARCHIVO_HASTA / 2.0), Vector3(0.035, 0.024, -ARCHIVO_HASTA), Basis()])
		x += PLAFON
	var z := 0.0
	while z > ARCHIVO_HASTA:
		rieles.append([Vector3(0.0, y, z), Vector3(LADO * 2.0, 0.024, 0.035), Basis()])
		z -= PLAFON
	_juntar(piso, rieles, _material("riel", Color(0.55, 0.53, 0.47)))
	var negro := _material("hueco", Color(0.01, 0.01, 0.01))
	negro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var placas: Array = []
	var cascajo: Array = []
	var cables: Array = []
	for i in HOYOS.size():
		var h: Array = HOYOS[i]
		var centro := Vector3(h[0], ALTO - 0.004, h[1])
		_calco(piso, centro, Vector3.DOWN, Vector2(PLAFON - 0.03, PLAFON - 0.03), negro)
		if i % 3 == 0:
			# La placa colgando de una orilla
			var colgada := Basis(Vector3.RIGHT, deg_to_rad(_azar.randf_range(45.0, 70.0)))
			placas.append([centro + Vector3(0.0, -0.22, 0.17), Vector3(PLAFON - 0.04, 0.015, PLAFON - 0.04), colgada])
		else:
			placas.append([Vector3(h[0] + _azar.randf_range(-0.6, 0.6), 0.02, h[1] + _azar.randf_range(-0.6, 0.6)),
				Vector3(PLAFON - 0.04, 0.015, PLAFON - 0.04), Basis(Vector3.UP, _azar.randf() * TAU) * Basis(Vector3.RIGHT, _azar.randf_range(-0.12, 0.12))])
		if i % 2 == 1:
			cables.append([centro + Vector3(0.1, -0.45, 0.0), Vector3(0.018, 0.9, 0.018), Basis(Vector3.FORWARD, _azar.randf_range(-0.3, 0.3))])
		for k in 5:
			var t := _azar.randf_range(0.04, 0.16)
			cascajo.append([Vector3(h[0] + _azar.randf_range(-0.5, 0.5), t / 2.0, h[1] + _azar.randf_range(-0.5, 0.5)),
				Vector3(t * 1.4, t, t), Basis(Vector3.UP, _azar.randf() * TAU)])
		if i in CHARCOS:
			_calco(piso, Vector3(h[0], 0.008, h[1]), Vector3.UP, Vector2.ONE * _azar.randf_range(1.2, 1.8), _charco(), _azar.randf() * TAU)
	_juntar(piso, placas, _material("plafon", Color.WHITE, DIR_TEX + "plafon.png", 1.2))
	_juntar(piso, cascajo, _material("cascajo", Color(0.72, 0.7, 0.64)))
	_juntar(piso, cables, _material("cable", Color(0.08, 0.08, 0.08)))


func _lamparas(piso: Node3D) -> void:
	var apagada := _material("tubo_apagado", Color(0.42, 0.42, 0.38))
	var marco_lampara := _material("lampara", Color(0.6, 0.58, 0.52))
	for l: Array in LAMPARAS:
		var en := Vector3(l[0], ALTO - 0.02, l[1])
		var estado: String = l[2]
		_caja(piso, en + Vector3.UP * 0.005, Vector3(0.62, 0.02, 1.22), marco_lampara)
		if estado == "apagada":
			_caja(piso, en, Vector3(0.56, 0.03, 1.16), apagada)
			continue
		if estado == "rota":
			# Sin rejilla: un tubo colgando de un lado y el otro tirado
			var tubo_roto := _caja(piso, en + Vector3(0.12, -0.3, 0.2), Vector3(0.04, 0.04, 1.1), apagada)
			tubo_roto.rotation.x = deg_to_rad(28.0)
			_caja(piso, Vector3(l[0] + 0.5, 0.03, l[1] - 0.4), Vector3(0.04, 0.04, 1.1), apagada).rotation.y = 0.7
			_calco(piso, en + Vector3.DOWN * 0.012, Vector3.DOWN, Vector2(0.5, 1.1), _material("hueco", Color.BLACK))
			continue
		var material := _material("tubo", COLOR_LUZ).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = COLOR_LUZ
		material.emission_energy_multiplier = 0.6 if estado == "tenue" else 1.0
		_caja(piso, en, Vector3(0.56, 0.03, 1.16), material)
		var luz := OmniLight3D.new()
		luz.position = en + Vector3.DOWN * 0.25
		luz.light_color = COLOR_LUZ
		luz.light_energy = LUZ_TENUE if estado == "tenue" else LUZ_PARPADEA
		luz.omni_range = LUZ_ALCANCE
		luz.omni_attenuation = 1.4
		luz.shadow_enabled = false
		piso.add_child(luz)
		var voz := AudioStreamPlayer3D.new()
		voz.stream = Sonidos.sonido("fluorescente")
		voz.volume_db = -16.0 if estado == "tenue" else -12.0
		voz.unit_size = 1.5
		voz.max_distance = 9.0
		voz.pitch_scale = _azar.randf_range(0.97, 1.03)
		voz.position = en
		piso.add_child(voz)
		if estado == "tenue":
			_zumbidos.append(voz)
			continue
		var chispa := AudioStreamPlayer3D.new()
		chispa.stream = Sonidos.sonido("chispa")
		chispa.volume_db = -8.0
		chispa.unit_size = 2.0
		chispa.max_distance = 14.0
		chispa.position = en
		piso.add_child(chispa)
		_parpadeo.append({"luz": luz, "material": material, "voz": voz, "chispa": chispa, "prendida": true,
			"cambia_en": _azar.randf_range(0.1, 2.0), "muriendo": _parpadeo.size() % 2 == 1, "energia": luz.light_energy})


# Las que parpadean: unas casi siempre prendidas con apagones cortos, otras ("muriendo") casi siempre apagadas con
# chispazos. Al prender a veces truena (chispa) y el zumbido solo suena prendida.
func _parpadear(delta: float) -> void:
	for p: Dictionary in _parpadeo:
		p["cambia_en"] -= delta
		if p["cambia_en"] > 0.0:
			continue
		var prendida: bool = not p["prendida"]
		p["prendida"] = prendida
		var muriendo: bool = p["muriendo"]
		if prendida:
			p["cambia_en"] = randf_range(0.03, 0.14) if muriendo else (randf_range(0.04, 0.12) if randf() < 0.5 else randf_range(0.8, 4.0))
		else:
			p["cambia_en"] = randf_range(0.3, 2.6) if muriendo else randf_range(0.03, 0.2)
		var fuerza := randf_range(0.55, 1.0) if prendida else 0.0
		(p["luz"] as OmniLight3D).light_energy = p["energia"] * fuerza
		(p["luz"] as OmniLight3D).visible = prendida
		(p["material"] as StandardMaterial3D).emission_energy_multiplier = fuerza
		(p["voz"] as AudioStreamPlayer3D).stream_paused = not prendida
		if prendida and randf() < (0.5 if muriendo else 0.12):
			(p["chispa"] as AudioStreamPlayer3D).pitch_scale = randf_range(0.8, 1.25)
			(p["chispa"] as AudioStreamPlayer3D).play()


func _muebles(piso: Node3D) -> void:
	var madera := _material("madera", COLOR_MADERA)
	var metal := _material("metal", COLOR_METAL)
	var carton := _material("carton", COLOR_CARTON)
	var hojas: Array = []
	# Las cuatro oficinas, cada una revuelta a su modo (centro: la de enfrente y la de atras de cada lado)
	var k := 0
	for s in [-1.0, 1.0]:
		for centro_z: float in [(0.0 + CORTE_OFICINAS) / 2.0, (CORTE_OFICINAS + PASILLO_HASTA) / 2.0]:
			var x: float = s * (LADO - 1.3)
			var forma := k
			k += 1
			match forma:
				0:
					# Escritorio de pie, su silla tirada, archivero con los cajones de fuera
					_bloque(piso, Vector3(x, 0.38, centro_z), Vector3(0.8, 0.76, 1.8), madera)
					_caja(piso, Vector3(x - s * 1.1, 0.25, centro_z + 0.9), Vector3(0.5, 0.5, 0.5), metal).rotation = Vector3(0.0, 0.5, PI / 2.0)
					_archivero(piso, Vector3(s * (LADO - 0.45), 0.0, centro_z - 3.6), s, true)
				1:
					# Escritorio volcado de lado y el archivero tirado
					_bloque(piso, Vector3(x - s * 0.5, 0.4, centro_z + 0.4), Vector3(0.76, 0.8, 1.8), madera, Basis(Vector3.UP, 0.35))
					_bloque(piso, Vector3(s * (LADO - 1.6), 0.25, centro_z - 3.2), Vector3(1.3, 0.5, 0.6), metal, Basis(Vector3.UP, 0.2))
				2:
					# Escritorio partido: la cubierta caida de un lado
					_bloque(piso, Vector3(x, 0.38, centro_z - 0.6), Vector3(0.8, 0.76, 0.6), madera)
					_caja(piso, Vector3(x, 0.4, centro_z + 0.45), Vector3(0.8, 0.05, 1.3), madera).rotation.x = deg_to_rad(-32.0)
					_archivero(piso, Vector3(s * (LADO - 0.45), 0.0, centro_z + 3.6), s, false)
				3:
					# Escritorio arrastrado contra la pared de en medio y cajas de archivo reventadas
					_bloque(piso, Vector3(s * 5.0, 0.38, CORTE_OFICINAS - 0.6), Vector3(1.8, 0.76, 0.8), madera, Basis(Vector3.UP, 0.15))
					for c in 4:
						var caja := _caja(piso, Vector3(x - s * _azar.randf_range(0.2, 1.4), 0.17, centro_z + _azar.randf_range(-2.0, 2.0)), Vector3(0.45, 0.33, 0.35), carton)
						caja.rotation = Vector3(0.0, _azar.randf() * TAU, PI / 2.0 if c % 2 == 0 else 0.0)
			for h in 26:
				hojas.append(_hoja(Vector3(s * _azar.randf_range(PASILLO + 0.3, LADO - 0.3), 0.0, centro_z + _azar.randf_range(-5.0, 5.0))))
	# El pasillo: las bancas de espera (una volcada) y el retrato oficial caido, recargado en la pared
	_bloque(piso, Vector3(-PASILLO + 0.35, 0.23, -3.0), Vector3(0.45, 0.46, 1.6), madera)
	_caja(piso, Vector3(-PASILLO + 0.45, 0.23, -9.0), Vector3(0.45, 0.46, 1.6), madera).rotation.z = PI / 2.0
	_bloque(piso, Vector3(-PASILLO + 0.35, 0.23, -14.0), Vector3(0.45, 0.46, 1.6), madera, Basis(Vector3.UP, 0.18))
	var cuadro := _caja(piso, Vector3(PASILLO - 0.3, 0.5, -9.0), Vector3(0.05, 1.0, 0.8), madera)
	cuadro.name = "Retrato"
	cuadro.rotation.z = deg_to_rad(-16.0)
	var lema := Label3D.new()
	lema.text = "GOBIERNO DEL ESTADO\nGelA · Agua segura para todos"
	lema.font_size = 36
	lema.pixel_size = 0.006
	lema.outline_size = 6
	lema.modulate = Color(0.75, 0.7, 0.55)
	lema.rotation.y = -PI / 2.0
	lema.position = Vector3(PASILLO - 0.17, 2.65, -9.0)
	piso.add_child(lema)
	var archivo := Label3D.new()
	archivo.text = "ARCHIVO"
	archivo.font_size = 48
	archivo.pixel_size = 0.008
	archivo.outline_size = 8
	archivo.modulate = Color(0.75, 0.7, 0.55)
	archivo.position = Vector3(0.0, ALTO - 0.4, PASILLO_HASTA - 0.2)
	piso.add_child(archivo)
	for h in 30:
		hojas.append(_hoja(Vector3(_azar.randf_range(-PASILLO + 0.2, PASILLO - 0.2), 0.0, _azar.randf_range(-21.5, -1.5))))
	# El archivo: dos hileras de estantes a cada lado del pasillo del centro; faltan cajas, que estan tiradas
	# atras de su estante (nunca en el pasillo del centro)
	for z: float in [-24.5, -27.5]:
		for s in [-1.0, 1.0]:
			var x: float = s * 3.6
			_estante(piso, Vector3(x, 0.0, z), Vector3(4.6, 2.0, 0.5), metal)
			for nivel in 3:
				for c in 5:
					var r := _azar.randf()
					if r < 0.6:
						_caja(piso, Vector3(x - 1.8 + c * 0.9, 0.35 + nivel * 0.65, z), Vector3(0.7, 0.4, 0.45), carton)
					elif r < 0.85:
						var tirada := _caja(piso, Vector3(x - 1.8 + c * 0.9 + _azar.randf_range(-0.3, 0.3), 0.2, z + _azar.randf_range(0.6, 1.1)), Vector3(0.7, 0.4, 0.45), carton)
						tirada.rotation = Vector3(_azar.randf_range(-0.2, 0.2), _azar.randf() * TAU, PI / 2.0 if _azar.randf() < 0.3 else 0.0)
	for h in 40:
		hojas.append(_hoja(Vector3(_azar.randf_range(-6.6, 6.6), 0.0, _azar.randf_range(-31.6, -22.5))))
	_juntar(piso, hojas, _material("papel", COLOR_PAPEL))
	# Las dos mesas del fondo, donde estan los papeles (MisionesMundo pone el expediente y la hoja encima)
	for p: Vector3 in PAPELES:
		_bloque(piso, Vector3(p.x, 0.38, p.z), Vector3(1.6, 0.76, 0.8), madera)
		_caja(piso, Vector3(p.x + 0.55, 0.94, p.z), Vector3(0.45, 0.35, 0.4), carton)


# Un archivero de metal contra la pared (`s` el lado), de pie; `abierto` con dos cajones de fuera
func _archivero(piso: Node3D, pie: Vector3, s: float, abierto: bool) -> void:
	var metal := _material("metal", COLOR_METAL)
	_bloque(piso, pie + Vector3(0.0, 0.65, 0.0), Vector3(0.5, 1.3, 0.6), metal)
	if abierto:
		for n in 2:
			_caja(piso, pie + Vector3(-s * 0.4, 0.95 - n * 0.55, 0.0), Vector3(0.35, 0.25, 0.5), metal)


func _hoja(en: Vector3) -> Array:
	return [en + Vector3.UP * _azar.randf_range(0.006, 0.02), Vector3(0.22, 0.004, 0.3),
		Basis(Vector3.UP, _azar.randf() * TAU) * Basis(Vector3.RIGHT, _azar.randf_range(-0.08, 0.08))]


# La mugre: en cada tramo de pared humedad que escurre del techo, manchas, grietas, a veces sangre o el papel tapiz
# despegado (la tablaroca a la vista y una tira de papel que se sale de la pared); manchas en el plafon y la
# alfombra, y un rastro de sangre por el pasillo. Nada de hoyos pintados: en una pared plana se veian calcomania
func _mugre(piso: Node3D) -> void:
	var mancha := _material_calco("mancha", "mancha.png")
	var escurrido := _material_calco("escurrido", "escurrido.png")
	var sangre := _material_calco("sangre", "sangre.png")
	var despegado := _material_calco("despegado", "despegado.png")
	var grieta := _material_calco("grieta", "grieta.png")
	var tiras: Array = []
	var despegues := _despegados
	for t: Array in _tramos:
		var a: Vector2 = t[0]
		var b: Vector2 = t[1]
		var largo := a.distance_to(b)
		if largo < 1.2:
			continue
		var eje := (b - a) / largo
		var normal := Vector3(-eje.y, 0.0, eje.x)
		for lado in [-1.0, 1.0]:
			var n: Vector3 = normal * lado
			# Solo las caras de adentro: la de fuera de una pared de orilla no la ve nadie
			var medio := (a + b) / 2.0
			if not _adentro_de_planta(Vector2(medio.x + n.x * 0.5, medio.y + n.z * 0.5)):
				continue
			var cara := func(u: float, y: float) -> Vector3:
				var p := a + eje * u
				return Vector3(p.x, y, p.y) + n * (GRUESO / 2.0 + 0.012)
			var cuantas := ceili(largo / 3.0)
			for i in cuantas:
				if _azar.randf() < 0.55:
					_calco(piso, cara.call(_azar.randf_range(0.4, largo - 0.4), ALTO - 1.0), n, Vector2(_azar.randf_range(0.5, 0.9), 2.0), escurrido)
				if _azar.randf() < 0.5:
					var tam := _azar.randf_range(0.7, 1.8)
					_calco(piso, cara.call(_azar.randf_range(0.6, largo - 0.6), _azar.randf_range(0.6, ALTO - 0.8)), n, Vector2.ONE * tam, mancha, _azar.randf() * TAU)
				if _azar.randf() < 0.12:
					_calco(piso, cara.call(_azar.randf_range(0.4, largo - 0.4), _azar.randf_range(0.8, 1.5)), n, Vector2.ONE * 0.6, sangre, _azar.randf_range(-0.3, 0.3))
				if _azar.randf() < 0.22:
					var tam := _azar.randf_range(0.6, 1.2)
					_calco(piso, cara.call(_azar.randf_range(0.5, largo - 0.5), _azar.randf_range(ALTO - 1.6, ALTO - 0.5)), n, Vector2.ONE * tam, grieta, _azar.randf_range(-0.4, 0.4))
				if largo > 1.6 and _azar.randf() < 0.2:
					var ancho := _azar.randf_range(0.35, 0.6)
					var alto := _azar.randf_range(0.8, 1.5)
					var u := _azar.randf_range(ancho, largo - ancho)
					var y := _azar.randf_range(alto / 2.0 + 0.3, ALTO - alto / 2.0 - 0.2)
					var en: Vector3 = cara.call(u, y)
					if despegues.any(func(otro: Vector3) -> bool: return otro.distance_to(en) < 1.5):
						continue
					despegues.append(en)
					_despegados_n.append(n)
					_calco(piso, cara.call(u, y), n, Vector2(ancho * 1.3, alto), despegado)
					_tira(tiras, cara.call(u, y - alto * 0.5 + 0.05) + n * 0.004, n, Vector3(eje.x, 0.0, eje.y), ancho, alto)
	_juntar(piso, tiras, _material("reverso", Color(0.86, 0.83, 0.72)))
	# Plafon y alfombra
	for i in 16:
		_calco(piso, Vector3(_azar.randf_range(-7.5, 7.5), ALTO - 0.006, _azar.randf_range(-31.0, -1.0)), Vector3.DOWN, Vector2.ONE * _azar.randf_range(0.6, 1.6), mancha, _azar.randf() * TAU)
	for i in 18:
		_calco(piso, Vector3(_azar.randf_range(-7.5, 7.5), 0.006, _azar.randf_range(-31.0, -1.0)), Vector3.UP, Vector2.ONE * _azar.randf_range(0.8, 2.2), mancha, _azar.randf() * TAU)
	# El rastro: de la oficina oscura (la de atras a la derecha) por el pasillo hasta el archivo
	var z := -16.0
	var x := 2.0
	while z > -23.5:
		_calco(piso, Vector3(x, 0.01, z), Vector3.UP, Vector2(0.55, 0.9), sangre, PI + _azar.randf_range(-0.25, 0.25))
		z -= 0.8
		x = move_toward(x, 0.4, 0.35)


func _adentro_de_planta(p: Vector2) -> bool:
	if p.y > 0.0 or p.y < ARCHIVO_HASTA or absf(p.x) > LADO:
		return false
	return p.y > PASILLO_HASTA or absf(p.x) < ARCHIVO_MEDIO


# La tira de papel que se despego: se solto de arriba y cayo hacia fuera; sigue pegada del borde de abajo (`pie`, en
# la cara de la pared) y cuelga enrollandose en cuatro tramos (se ve su reverso blanco, y arriba la tablaroca)
func _tira(tiras: Array, pie: Vector3, n: Vector3, e: Vector3, ancho: float, alto: float) -> void:
	var largo := alto * _azar.randf_range(0.6, 0.8) / 4.0
	var punto := pie
	var desde := _azar.randf_range(18.0, 30.0)
	var abre := _azar.randf_range(24.0, 32.0)
	for tramo in 4:
		var angulo := deg_to_rad(desde + abre * tramo)
		var d := Vector3.DOWN * cos(angulo) + n * sin(angulo)
		var y := d.cross(e).normalized()
		tiras.append([punto + d * largo / 2.0, Vector3(ancho * 1.15, 0.006, largo + 0.01), Basis(e, y, d)])
		punto += d * largo


# --- Piezas ---

# Pocos y compartidos (uno por clave). Las texturas se proyectan en los ejes de cada caja (triplanar local, una
# repeticion cada `cada` m): las paredes largas no se estiran y siguen al palacio aunque este girado
func _material(clave: String, base: Color, textura := "", cada := TEXTURA_CADA) -> StandardMaterial3D:
	if _materiales.has(clave):
		return _materiales[clave]
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if textura != "":
		material.albedo_texture = load(textura)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / cada
	_materiales[clave] = material
	return material


# Para las calcomanias (manchas, sangre, papel despegado, grietas): textura con alfa sobre un cuadro
func _material_calco(clave: String, archivo: String) -> StandardMaterial3D:
	if _materiales.has(clave):
		return _materiales[clave]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(DIR_TEX + archivo)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.disable_receive_shadows = true
	_materiales[clave] = material
	return material


# Un charco: la forma de la mancha, oscuro y brilloso (refleja las lamparas)
func _charco() -> StandardMaterial3D:
	if _materiales.has("charco"):
		return _materiales["charco"]
	var material := _material_calco("charco_base", "mancha.png").duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.25, 0.22, 0.16, 0.9)
	material.roughness = 0.05
	material.metallic = 0.4
	material.metallic_specular = 1.0
	_materiales["charco"] = material
	return material


# Un cuadro plano en `centro`, de cara hacia `normal`, girado `giro` sobre ella
func _calco(padre: Node3D, centro: Vector3, normal: Vector3, tam: Vector2, material: Material, giro := 0.0) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var cuadro := QuadMesh.new()
	cuadro.size = tam
	malla.mesh = cuadro
	malla.material_override = material
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arriba := Vector3.FORWARD if absf(normal.y) > 0.9 else Vector3.UP
	malla.transform = Transform3D(Basis.looking_at(-normal, arriba) * Basis(Vector3.BACK, giro), centro)
	padre.add_child(malla)
	return malla


# Muchas cajas chicas en una sola malla (papeles, cascajo, rieles): [centro, tam, basis] cada una, sin choque
func _juntar(padre: Node3D, piezas: Array, material: Material) -> void:
	if piezas.is_empty():
		return
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	var st := SurfaceTool.new()
	for p: Array in piezas:
		var tam: Vector3 = p[1]
		st.append_from(caja, 0, Transform3D((p[2] as Basis) * Basis.from_scale(tam), p[0]))
	var malla := MeshInstance3D.new()
	malla.mesh = st.commit()
	malla.material_override = material
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(malla)


# Una caja que se ve (sin choque)
func _caja(padre: Node3D, centro: Vector3, tam: Vector3, material: Material) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	malla.mesh = caja
	malla.material_override = material
	malla.position = centro
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(malla)
	return malla


# Una caja que se ve y choca (girada con `base`)
func _bloque(padre: Node3D, centro: Vector3, tam: Vector3, material: Material, base := Basis()) -> MeshInstance3D:
	var malla := _caja(padre, centro, tam, material)
	malla.basis = base
	var cuerpo := StaticBody3D.new()
	cuerpo.transform = Transform3D(base, centro)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)
	return malla


# Una pared de `a` a `b` (x, z en el piso), alineada a un eje, con un zoclo delgado oscuro; se anota en _tramos
# para la mugre
func _pared(padre: Node3D, a: Vector2, b: Vector2, material: Material) -> void:
	var centro := (a + b) / 2.0
	var largo := a.distance_to(b)
	if largo < 0.05:
		return
	_tramos.append([a, b])
	var tam := Vector3(largo + GRUESO, ALTO, GRUESO) if absf(a.y - b.y) < 0.01 else Vector3(GRUESO, ALTO, largo + GRUESO)
	_bloque(padre, Vector3(centro.x, ALTO / 2.0, centro.y), tam, material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_caja(padre, Vector3(centro.x, ZOCLO / 2.0, centro.y), Vector3(tam.x + 0.03, ZOCLO, tam.z + 0.03), _material("zoclo", COLOR_ZOCLO))


# Un estante de metal que se ve por dentro (cuatro postes y tres repisas) y choca como una caja
func _estante(padre: Node3D, pie: Vector3, tam: Vector3, material: Material) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caja(padre, pie + Vector3(sx * (tam.x / 2.0 - 0.03), tam.y / 2.0, sz * (tam.z / 2.0 - 0.03)), Vector3(0.05, tam.y, 0.05), material)
	for nivel in 3:
		_caja(padre, pie + Vector3(0.0, 0.13 + nivel * 0.65, 0.0), Vector3(tam.x, 0.03, tam.z), material)
	var cuerpo := StaticBody3D.new()
	cuerpo.position = pie + Vector3.UP * tam.y / 2.0
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)
