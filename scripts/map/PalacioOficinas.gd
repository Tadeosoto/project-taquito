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
const ZOMBIS_EN := [Vector3(-3.0, 0.0, -27.0), Vector3(3.0, 0.0, -27.5), Vector3(0.0, 0.0, -18.0), Vector3(5.5, 0.0, -16.0)]

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

const COLOR_PARED := Color(0.8, 0.75, 0.62)    # crema de oficina de gobierno, con zoclo de madera
const ZOCLO := 0.9
const TEX_PISO := "res://textures/casa_personaje/piso.png"
const TEX_TECHO := "res://textures/casa_personaje/techo.png"
const TEXTURA_CADA := 2.0
const COLOR_MADERA := Color(0.36, 0.22, 0.12)
const COLOR_METAL := Color(0.45, 0.47, 0.48)
const COLOR_CARTON := Color(0.62, 0.5, 0.33)
const COLOR_PAPEL := Color(0.9, 0.88, 0.8)
const COLOR_LUZ := Color(0.85, 0.95, 1.0)

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
var _luces_titilan: Array[OmniLight3D] = []
var _t := 0.0


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
	_t += delta
	for luz in _luces_titilan:
		luz.visible = fmod(_t * 7.3 + luz.position.z, 5.0) > 0.35
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


# --- Las oficinas (arriba) ---

func _oficinas() -> void:
	var piso := Node3D.new()
	piso.name = "Oficinas"
	piso.position.y = ALTURA
	add_child(piso)
	var pared := _material("pared", COLOR_PARED)
	var fondo := ARCHIVO_HASTA
	# Piso y techo
	_bloque(piso, Vector3(0.0, -0.1, fondo / 2.0), Vector3(LADO * 2.0, 0.2, -fondo), _material("piso", Color.WHITE, TEX_PISO))
	_bloque(piso, Vector3(0.0, ALTO + 0.1, fondo / 2.0), Vector3(LADO * 2.0, 0.2, -fondo), _material("techo", Color.WHITE, TEX_TECHO))
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
	# La puerta por dentro
	_caja(piso, Vector3(0.0, PUERTA_TAM.y / 2.0, -GRUESO / 2.0 - 0.03), Vector3(PUERTA_TAM.x, PUERTA_TAM.y, 0.06), _material("madera", COLOR_MADERA))
	_muebles(piso)
	_luces(piso)


func _muebles(piso: Node3D) -> void:
	var madera := _material("madera", COLOR_MADERA)
	var metal := _material("metal", COLOR_METAL)
	var carton := _material("carton", COLOR_CARTON)
	var papel := _material("papel", COLOR_PAPEL)
	# Cada oficina: un escritorio contra la pared de afuera, su silla, un archivero y papeles tirados
	for s in [-1.0, 1.0]:
		for centro_z: float in [(0.0 + CORTE_OFICINAS) / 2.0, (CORTE_OFICINAS + PASILLO_HASTA) / 2.0]:
			var x: float = s * (LADO - 1.3)
			_bloque(piso, Vector3(x, 0.38, centro_z), Vector3(0.8, 0.76, 1.8), madera)
			_caja(piso, Vector3(x - s * 0.9, 0.25, centro_z + 0.3), Vector3(0.5, 0.5, 0.5), metal)
			_bloque(piso, Vector3(s * (PASILLO + 0.5), 0.65, centro_z - 3.2), Vector3(0.6, 1.3, 0.5), metal)
			for k in 4:
				var hoja := _caja(piso, Vector3(s * (PASILLO + 1.5 + randf() * 3.0), 0.01, centro_z + randf_range(-3.0, 3.0)), Vector3(0.22, 0.01, 0.3), papel)
				hoja.rotation.y = randf() * TAU
			_caja(piso, Vector3(x, 0.79, centro_z - 0.4), Vector3(0.3, 0.06, 0.4), papel)
	# El pasillo: bancas de espera y el retrato oficial con el lema
	for z: float in [-3.0, -9.0, -14.0]:
		_bloque(piso, Vector3(-PASILLO + 0.35, 0.23, z), Vector3(0.45, 0.46, 1.6), madera)
	var cuadro := _caja(piso, Vector3(PASILLO - 0.18, 1.9, -9.0), Vector3(0.05, 1.0, 0.8), madera)
	cuadro.name = "Retrato"
	var lema := Label3D.new()
	lema.text = "GOBIERNO DEL ESTADO\nGelA · Agua segura para todos"
	lema.font_size = 36
	lema.pixel_size = 0.006
	lema.outline_size = 6
	lema.rotation.y = -PI / 2.0
	lema.position = Vector3(PASILLO - 0.2, 2.65, -9.0)
	piso.add_child(lema)
	var archivo := Label3D.new()
	archivo.text = "ARCHIVO"
	archivo.font_size = 48
	archivo.pixel_size = 0.008
	archivo.outline_size = 8
	archivo.position = Vector3(0.0, ALTO - 0.4, PASILLO_HASTA - 0.2)
	piso.add_child(archivo)
	# El archivo: dos hileras de estantes de metal a cada lado del pasillo del centro, llenos de cajas
	for z: float in [-24.5, -27.5]:
		for s in [-1.0, 1.0]:
			var x: float = s * 3.6
			_estante(piso, Vector3(x, 0.0, z), Vector3(4.6, 2.0, 0.5), metal)
			for nivel in 3:
				for k in 5:
					if randf() < 0.85:
						_caja(piso, Vector3(x - 1.8 + k * 0.9, 0.35 + nivel * 0.65, z), Vector3(0.7, 0.4, 0.45), carton)
	# Las dos mesas del fondo, donde estan los papeles (MisionesMundo pone el expediente y la hoja encima)
	for p: Vector3 in PAPELES:
		_bloque(piso, Vector3(p.x, 0.38, p.z), Vector3(1.6, 0.76, 0.8), madera)
		_caja(piso, Vector3(p.x + 0.55, 0.94, p.z), Vector3(0.45, 0.35, 0.4), carton)


func _luces(piso: Node3D) -> void:
	# Lamparas de tubo: dos en el pasillo (una titila), una en el archivo y una por oficina, bajitas
	var en := [[Vector3(0.0, ALTO - 0.15, -5.0), 1.1, false], [Vector3(0.0, ALTO - 0.15, -16.0), 1.0, true],
		[Vector3(0.0, ALTO - 0.15, -27.0), 1.2, false]]
	for s in [-1.0, 1.0]:
		en.append([Vector3(s * 5.5, ALTO - 0.15, -5.5), 0.6, false])
		en.append([Vector3(s * 5.5, ALTO - 0.15, -16.5), 0.5, s > 0.0])
	var tubo := _material("tubo", Color(1.0, 1.0, 1.0))
	tubo.emission_enabled = true
	tubo.emission = COLOR_LUZ
	for l: Array in en:
		var luz := OmniLight3D.new()
		luz.position = l[0]
		luz.light_color = COLOR_LUZ
		luz.light_energy = l[1]
		luz.omni_range = 8.0
		luz.shadow_enabled = false
		piso.add_child(luz)
		_caja(piso, l[0] + Vector3.UP * 0.08, Vector3(0.25, 0.06, 1.4), tubo)
		if l[2]:
			_luces_titilan.append(luz)


# --- Piezas ---

# Pocos y compartidos (uno por clave): las texturas se proyectan en metros (triplanar, una repeticion cada
# TEXTURA_CADA m) para que las paredes largas no se estiren
func _material(clave: String, base: Color, textura := "") -> StandardMaterial3D:
	if _materiales.has(clave):
		return _materiales[clave]
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if textura != "":
		material.albedo_texture = load(textura)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE / TEXTURA_CADA
	_materiales[clave] = material
	return material


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


# Una caja que se ve y choca
func _bloque(padre: Node3D, centro: Vector3, tam: Vector3, material: Material) -> void:
	_caja(padre, centro, tam, material)
	var cuerpo := StaticBody3D.new()
	cuerpo.position = centro
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


# Una pared de `a` a `b` (x, z en el piso), alineada a un eje, con su zoclo de madera (un poco mas gruesa, abajo)
func _pared(padre: Node3D, a: Vector2, b: Vector2, material: Material) -> void:
	var centro := (a + b) / 2.0
	var largo := a.distance_to(b)
	if largo < 0.05:
		return
	var tam := Vector3(largo + GRUESO, ALTO, GRUESO) if absf(a.y - b.y) < 0.01 else Vector3(GRUESO, ALTO, largo + GRUESO)
	_bloque(padre, Vector3(centro.x, ALTO / 2.0, centro.y), tam, material)
	var zoclo := Vector3(tam.x + 0.04 if tam.x > tam.z else tam.x + 0.04, ZOCLO, tam.z + 0.04 if tam.x > tam.z else tam.z + 0.04)
	_caja(padre, Vector3(centro.x, ZOCLO / 2.0, centro.y), zoclo, _material("madera", COLOR_MADERA))


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
