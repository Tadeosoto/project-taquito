extends Node3D

# Escena de prueba de la defensa del tinaco ("Vela del tinaco", docs/misiones.md §0):
# noches encadenadas de 3:30 min (22:00 a 6:00, `duracion_noche`) en el Parque Jardin
# Imperial (Parques del Mosco) del mapa real. Las hordas (Hordas.gd) salen de las orillas y
# corren al tinaco; al amanecer se cobra y sale el menu de ganaste (Siguiente, Cambiar
# personaje, Salir). Cada noche sube la dificultad (mas zombis por grupo y pegan mas) hasta
# que te desmayas o rompen el tinaco: entonces el menu deja reintentar esa misma noche. Si
# lo rompen se corta a negro, amanece y no se paga nada: con media paga convenia entrar y
# dejarse perder. Desmayarte tambien acaba la noche sin paga (en coop, el desmayado
# esperaria a los demas). Suena audio/musica/pt_tema.mp3 en bucle. Por ahora es una escena
# sola: la flecha amarilla en el mapa, la zona al azar por colonia y el regreso van despues.
#
#   godot --path . scenes/defensa_tinaco.tscn [-- --semilla=N]
#   godot --path . scenes/defensa_tinaco.tscn -- --capturas=<carpeta> [--semilla=N]
#   godot --path . scenes/defensa_tinaco.tscn -- --monitor=<carpeta>   (MonitorDefensa.gd)
#   godot --path . scenes/defensa_tinaco.tscn -- --noche=<segundos> --modo=facil|medio|dificil
#   godot --path . scenes/defensa_tinaco.tscn -- --estela   (la mejora de estela del protagonista)
#
# El mapa se arma con los mismos sistemas de map_test alrededor del nodo Centro, con
# radios chicos; los negocios salen cerrados (sin flecha). La barricada se genera hasta
# que cargo lo de alrededor, porque se brinca lo que choca con casas y bardas. La noche
# no corre mientras. G arma otra barricada (para probar); la semilla sale en la consola.
# Con --capturas pone la camara en VISTAS, guarda un PNG de cada una y se sale.

const MapAlumbrado := preload("res://scripts/map/MapAlumbrado.gd")
const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")

const CENTRO := Vector3(163.0, 0.0, -515.0)
const LADO := 50.0                     # medio lado de donde se puede andar
const JUGADOR_SALE := Vector3(2.5, 1.2, 2.5)   # junto al tinaco (Barricada.JUGADOR_SALE)
const PARED_CAPA := 16                 # capa 5: solo la tiene el jugador en su mascara
const PARED_ALTO := 20.0
# Los negocios de alrededor, cerrados: MapPuntos lee este archivo (antes de su _ready)
const PUNTOS_JSON := "user://puntos_defensa.json"
const PUNTOS_RADIO := 150.0
# Esperar al mapa: hasta que CargaCuadro pase MAPA_QUIETO cuadros seguidos sin armar nada
const MAPA_QUIETO := 20
const MAPA_MAXIMO := 10.0              # s
# La paga (docs/misiones.md: 150, 200 o 250 segun la zona; aqui la baja)
const PAGA := 150
const GALON := preload("res://resources/productos/galon_agua.tres")
# Los vecinos te dejan comida para la noche: se completa hasta PROVISIONES curaciones (Q),
# y te prestan una mochila para que quepan
const TACOS := preload("res://resources/productos/tacos.tres")
const PROVISIONES := 5
const MOCHILA := preload("res://resources/productos/mochila_escolar.tres")
const FIN_ESPERA := 2.5                # s de amanecer antes de la pantalla final
const FUNDIDO := 0.8                   # s a negro y de regreso cuando rompen el tinaco
# Noches encadenadas: cada una es mas dificil. Los grupos del modo crecen esta fraccion por
# noche y el zombi pega DANO_POR_NOCHE mas, hasta DANO_TOPE (el del mapa). Los grupos no
# tienen tope propio: Hordas los limita con Zombis.max_total, asi que llega un momento en
# que no se puede ganar y se pierde (y se reintenta esa misma noche). Todo se ajusta
# jugando: al empezar cada noche se imprime en consola lo que quedo.
const DIFICULTAD_POR_NOCHE := 1.25
const DANO_POR_NOCHE := 1
const DANO_TOPE := 12
const FUNDIDO_SALE := 0.25             # s a negro antes de rearmar la noche
const SALIDA_ESPERA := 4.0               # s de aviso antes de volver al mapa (desde el juego)
const MODO_CARRERA := 1                  # Pruebas.Modo.CARRERA
const MODO_GODMODE := 2                  # Pruebas.Modo.GODMODE
const FUNDIDO_ENTRA := 0.6             # s de regreso desde negro

# [nombre, desde, hacia], respecto al tinaco
const VISTAS := [
	["cenital", Vector3(0.0, 60.0, 0.1), Vector3.ZERO],
	["sureste", Vector3(21.0, 8.0, 21.0), Vector3(0.0, 0.5, 0.0)],
	["ras_norte", Vector3(0.0, 2.0, -24.0), Vector3(0.0, 0.8, 0.0)],
	["ras_este", Vector3(24.0, 2.0, 0.0), Vector3(0.0, 0.8, 0.0)],
	["ras_sur", Vector3(0.0, 2.0, 24.0), Vector3(0.0, 0.8, 0.0)],
	["ras_oeste", Vector3(-24.0, 2.0, 0.0), Vector3(0.0, 0.8, 0.0)],
	["desde_tinaco", Vector3(1.5, 2.2, 1.5), Vector3(9.0, 1.0, 12.0)],
	["noche", Vector3(21.0, 8.0, 21.0), Vector3(0.0, 0.5, 0.0)],
]
const LUZ_REVISION := 1.5   # luz sin niebla para revisar el acomodo (todas menos "noche")

# Minimapa: el PNG del mapa real (tools/map_import/make_minimapa.py) recortado alrededor,
# al doble, con la barricada, los tambos y el tinaco encima y oscuro fuera de las paredes
const MINIMAPA := "res://textures/map/minimapa.png"
const MINIMAPA_DATOS := "res://resources/map/minimapa.json"
const MAPA_LADO := 60.0
const MAPA_M_POR_PIXEL := 0.5
const MAPA_BARRICADA := Color(0.8, 0.76, 0.64)
const MAPA_TINACO := Color(0.35, 0.6, 1.0)
const MAPA_TAMBO := Color(1.0, 0.55, 0.15)
const MAPA_AFUERA := 0.45

const AMARILLO := Color(1.0, 0.85, 0.1)
const AGUA := Color(0.35, 0.6, 1.0)
const ROJO := Color(0.9, 0.15, 0.1)
const TEMA := preload("res://resources/ui/tema_pixel.tres")

const MUSICA := preload("res://audio/musica/pt_tema.mp3")
# Lo unico que suena ademas de la musica (Sonidos.solo): el machete al cortar el aire y al
# pegar, y la pistola
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
# Matando a tantos con la espada en la noche se enciende la estela del protagonista (solo
# estetica, no da dano). Mitad de los ~55 zombis que caen por noche en modo medio
# (docs/pruebas-balance.md: machete 774 + pistola 870 de dano, vida 30)
const ESTELA_MUERTES := 27
# golpe y morir_zombi: el Panzon (azotones, pisotones, losas) y su muerte; zumbido_oidos y
# bocina_*: la palomita y la bocina senuelo
const SONIDOS := ["machetazo", "whack", "bloqueo", "disparo", "disparo_1", "disparo_2", "disparo_3", "disparo_4", "rugido", "rugido_corto", "casquillo", "disparo_pistola", "recarga_suelta", "recarga_mete", "recarga_cierra", "golpe", "morir_zombi", "zumbido_oidos", "bocina_musica", "bocina_apaga"]
const MUSICA_VOLUMEN := -8.0   # dB
const MUSICA_SILENCIO := -40.0
const MUSICA_ENTRA := 2.0      # s
const MUSICA_SALE := 2.0

# La pantalla final: el titulo cae y rebota, luego cada renglon con su sonido y la paga
# contando hacia arriba con monedas de pixelfx
const TITULO_TAMANO := 32
const RENGLON_TAMANO := 16
const RENGLON_CADA := 0.45     # s entre renglon y renglon
const CUENTA_DURA := 1.2       # s que tarda en contar la paga
const CUENTA_PASOS := 10       # monedas que suenan mientras cuenta
const CIERRES_GANO := ["La colonia tiene agua otro día.", "Ya hay pa' lavar los trastes.", "Hoy sí hay pa'l cafecito."]
const CIERRES_TINACO := ["La colonia se quedó sin agua.", "A acarrear garrafones otra vez."]
const CIERRES_DESMAYO := ["El tinaco no se cuida solo.", "Mañana la colonia te lo va a recordar."]

# Lo que dura la noche, de las 22:00 a las 6:00 (s de juego). JJ: 6 min se hacian largos.
# Tambien se cambia con `-- --noche=<segundos>`
@export var duracion_noche := 210.0
# Hordas.MODOS. Tambien `-- --modo=facil|medio|dificil`
@export_enum("facil", "medio", "dificil") var modo := "medio"

@onready var _barricada := $Barricada as Barricada
@onready var _minimapa := $Minimapa
@onready var _ciclo := $Ciclo as Ciclo
@onready var _zombis := $Zombis as Zombis
@onready var _supervivencia := $Supervivencia
@onready var _jugador := $Player as Player
var _tinaco: TinacoDefensa
var _hordas: Hordas
var _decoracion: DecoracionDefensa   # bocinas y camionetas que se van (visual)
var _hora: Label
var _amanecer: ColorRect
var _vida_tinaco: ColorRect
# La barra del Panzon (Panzon.gd), arriba al centro, solo mientras hay uno vivo
var _jefe: Control
var _jefe_barra: ColorRect
const JEFE_ANCHO := 300.0
var _listo := false
var _terminado := false
var _noche_cerrada := false
var _musica: AudioStreamPlayer
var _musica_apagada := false
var _hora_fin := 0.0          # a que hora se perdio
# La noche de la carrera (1, 2, 3...). Sube con Siguiente y NO baja al reintentar la misma
var noche := 1
var _dificultad_base := 1.0   # la del modo (Hordas.MODOS) antes de la escalada
var _dano_base := 6           # Zombis.dano_jugador de la escena antes de la escalada
var _menu_capa: CanvasLayer   # el menu de entre noches, si esta abierto
var _botones: HBoxContainer
var _primer_boton: Button
var _capa_fundido: CanvasLayer
var _fundido: ColorRect
var _en_transicion := false   # entre el menu y la noche siguiente
var _creador_abierto := false


func _enter_tree() -> void:
	# Antes del _ready de Puntos
	var todos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/map/puntos_mapa.json"))
	var cerca := []
	for punto: Dictionary in todos["puntos"]:
		if Vector2(punto["x"] - CENTRO.x, punto["z"] - CENTRO.z).length() <= PUNTOS_RADIO:
			punto["interactivo"] = false
			cerca.append(punto)
	var archivo := FileAccess.open(PUNTOS_JSON, FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"puntos": cerca}))
	archivo.close()


func _ready() -> void:
	_tinaco = _barricada.get_node("Tinaco") as TinacoDefensa
	Sonidos.solo.assign(SONIDOS)
	_ciclo.process_mode = Node.PROCESS_MODE_DISABLED
	_jugador.collision_mask |= PARED_CAPA
	_jugador.mato_con_espada.connect(_revisar_estela)
	_armar_paredes()
	_armar_hud()
	_armar_fundido()
	_hordas = Hordas.new()
	_hordas.name = "Hordas"
	_hordas.centro = CENTRO
	_hordas.zombis = _zombis
	_hordas.ciclo = _ciclo
	add_child(_hordas)
	_decoracion = DecoracionDefensa.new()
	_decoracion.name = "Decoracion"
	add_child(_decoracion)
	_tinaco.aviso.connect(_supervivencia.avisar)
	_tinaco.cayo.connect(_tinaco_roto)
	_supervivencia.desmayo_final = _desmayado
	_musica = AudioStreamPlayer.new()
	_musica.stream = MUSICA
	(_musica.stream as AudioStreamMP3).loop = true
	_musica.volume_db = MUSICA_SILENCIO
	_musica.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_musica)
	_ciclo.amanecio.connect(_fin)
	# Si se lanza directo (sin lanzador), es el godmode de mecanicas. El refugio pone CARRERA
	# antes de cargar esta escena.
	var pruebas = _pruebas()
	# Desde el juego (PasoJefe, una mision ENTRAR_A a esta escena) no es un test: tu equipo, sin
	# godmode, sin carrera ni registro, y al acabar vuelves al mapa
	if pruebas and pruebas.modo == 0 and not PasoJefe.desde_juego:
		pruebas.preparar_test(pruebas.Modo.GODMODE, pruebas.dificultad, pruebas.duracion_noche)
	var semilla := 0
	var capturas := ""
	var monitor_pedido := false
	var noche_arg := false
	var modo_arg := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--semilla="):
			semilla = int(arg.trim_prefix("--semilla="))
		elif arg.begins_with("--capturas="):
			capturas = arg.trim_prefix("--capturas=")
		elif arg.begins_with("--modo="):
			modo = arg.trim_prefix("--modo=")
			modo_arg = true
		elif arg.begins_with("--noche="):
			duracion_noche = float(arg.trim_prefix("--noche="))
			noche_arg = true
		elif arg == "--estela":
			get_node("/root/Personaje").mejora_estela = true
			_jugador.aplicar_personaje()
		elif arg.begins_with("--monitor="):
			monitor_pedido = true
	if pruebas:
		if not modo_arg:
			modo = pruebas.dificultad
		if not noche_arg:
			duracion_noche = pruebas.duracion_noche
		pruebas.dificultad = modo
		pruebas.duracion_noche = duracion_noche
	_ciclo.noche_duracion = duracion_noche
	_hordas.usar_modo(modo)
	_dificultad_base = _hordas.dificultad
	_dano_base = _zombis.dano_jugador
	print("Defensa: modo %s, noche de %.0f s" % [modo, duracion_noche])
	await _esperar_mapa()
	_al_suelo()
	_generar(semilla)
	_listo = true
	if capturas != "":
		_capturas(capturas)
		return
	_iniciar_noche()
	if monitor_pedido:
		_crear_monitor()


# Antes de empezar: la pantalla de personaje de Jugar. La noche sigue sin correr (el ciclo esta
# apagado) hasta que le das Empezar; Volver regresa al inicio
func _escoger_personaje() -> void:
	_jugador.detener()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 20
	add_child(capa)
	var creador: Control = load("res://scripts/CreadorPersonaje.gd").new()
	capa.add_child(creador)
	creador.volver.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/inicio.tscn"))
	await creador.listo
	capa.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_jugador.reanudar()
	_jugador.aplicar_personaje()


func _revisar_estela() -> void:
	if _pruebas():
		return
	var personaje := get_node("/root/Personaje")
	if personaje.mejora_estela or _jugador.muertes_espada < ESTELA_MUERTES:
		return
	personaje.mejora_estela = true
	ESTELA.estilo = personaje.estela()


# Al salir (Salir) los demas sonidos vuelven
func _exit_tree() -> void:
	Sonidos.solo.clear()
	Player.golpe_cargado = false
	Player.giro_aereo = false
	ESTELA.estilo = ESTELA.Estilo.NORMAL
	get_node("/root/Personaje").mejora_estela = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _listo and event.physical_keycode == KEY_C and not PasoJefe.desde_juego and not (_pruebas() and _pruebas().es_carrera()):
		_cambiar_personaje()
		return
	if _listo and event.physical_keycode == KEY_G:
		_generar(0)
	# M prende y apaga la musica (el inventario de aqui no tiene mapa de papel)
	elif event.physical_keycode == KEY_M:
		_musica_apagada = not _musica_apagada
		_musica.stream_paused = _musica_apagada


func _process(_delta: float) -> void:
	if not _listo:
		_hora.text = "Cargando..."
		return
	var hora := _hordas.hora() if _ciclo.es_noche() or _terminado else Hordas.HORA_EMPIEZA
	_hora.text = "Noche %d · %s" % [noche, Hordas.texto_hora(hora)]
	_amanecer.scale.x = (hora - Hordas.HORA_EMPIEZA) / Hordas.HORAS
	_vida_tinaco.scale.x = _tinaco.fraccion()
	var panzon := get_tree().get_first_node_in_group("panzon")
	_jefe.visible = panzon != null
	if panzon:
		_jefe_barra.scale.x = clampf(float(panzon.vida()) / Panzon.VIDA, 0.0, 1.0)


# Lo de alrededor ya cargo: CargaCuadro lleva un rato sin que nadie arme nada
func _esperar_mapa() -> void:
	var quieto := 0
	var desde := Time.get_ticks_msec()
	await get_tree().physics_frame
	while quieto < MAPA_QUIETO and Time.get_ticks_msec() - desde < MAPA_MAXIMO * 1000.0:
		await get_tree().process_frame
		var armo := CargaCuadro._cuadro == Engine.get_process_frames() - 1 and CargaCuadro._usado > 0
		quieto = 0 if armo else quieto + 1
	await get_tree().physics_frame


# El tinaco y el jugador a la altura del suelo del parque
func _al_suelo() -> void:
	var rayo := PhysicsRayQueryParameters3D.create(CENTRO + Vector3.UP * 5.0, CENTRO + Vector3.DOWN * 5.0, 1, [_jugador.get_rid(), _tinaco.get_rid()])
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	if pego:
		_barricada.global_position = pego.position
	_jugador.global_position = _barricada.global_position + JUGADOR_SALE
	_supervivencia.punto_regreso = _jugador.global_transform


func _generar(semilla: int) -> void:
	_barricada.generar(semilla)
	_zombis.olvidar_paredes()
	_zombis.usar_huecos(_barricada.huecos_mundo)
	_decoracion.armar(_barricada, _hordas)
	_minimapa.usar_mapa(_dibujar_mapa(), Vector2(CENTRO.x - MAPA_LADO, CENTRO.z - MAPA_LADO), Vector2.ONE * MAPA_LADO * 2.0)
	print("Barricada: semilla %d, %d piezas no cupieron" % [_barricada.semilla_usada, _barricada.quitadas])


# --- Noches encadenadas: dificultad y reinicio ---

# La dificultad de la noche que va: los grupos del modo crecen y el zombi pega mas. Los
# grupos los limita Zombis.max_total (40), asi que en algun momento ya no se puede ganar.
func _aplicar_noche() -> void:
	_hordas.dificultad = _dificultad_base * pow(DIFICULTAD_POR_NOCHE, maxi(noche, 1) - 1)
	_zombis.dano_jugador = mini(_dano_base + (maxi(noche, 1) - 1) * DANO_POR_NOCHE, DANO_TOPE)
	print("Noche %d: grupos x%.2f, zombi pega %d" % [noche, _hordas.dificultad, _zombis.dano_jugador])


# Los vecinos dejan comida para la noche (solo el godmode; en la carrera se compra)
func _dar_provisiones() -> void:
	var inventario := get_node("/root/Inventory")
	inventario.equipar_mochila(MOCHILA)
	while inventario.curaciones() < PROVISIONES and inventario.add_item(TACOS):
		pass


# Arranque de la noche (las dos ramas del test): estado, dificultad, registro y musica.
func _iniciar_noche() -> void:
	var pruebas = _pruebas()
	var godmode: bool = not PasoJefe.desde_juego and (pruebas == null or pruebas.modo == MODO_GODMODE)
	noche = pruebas.noche if (pruebas and pruebas.modo == MODO_CARRERA) else 1
	# En los tests no hay drops de zombis: todo se compra con la paga
	_zombis.paga_muertes = PasoJefe.desde_juego
	if PasoJefe.desde_juego:
		pass
	elif godmode:
		_aplicar_godmode()
	else:
		_aplicar_mejoras()
	_aplicar_noche()
	_preparar_noche()
	if PasoJefe.desde_juego:
		_arrancar_reloj()
		return
	if pruebas:
		pruebas.empezar_noche()
	_registro_inicio()
	if _hordas:
		if not _hordas.ola_empezada.is_connected(_registro_ola):
			_hordas.ola_empezada.connect(_registro_ola)
		if not _hordas.emboscada_empezada.is_connected(_registro_emboscada):
			_hordas.emboscada_empezada.connect(_registro_emboscada)
	_arrancar_reloj()


# Corre el ciclo (la noche) y entra la musica
func _arrancar_reloj() -> void:
	_ciclo.process_mode = Node.PROCESS_MODE_INHERIT
	_musica.play()
	_musica.stream_paused = _musica_apagada
	_volumen_musica(MUSICA_VOLUMEN, MUSICA_ENTRA)


# El godmode: todo el catalogo al maximo, todos los productos e infinitos. La misma escena,
# las mismas mecanicas y la misma estetica que la carrera.
func _aplicar_godmode() -> void:
	var mejoras := get_node_or_null("/root/Mejoras")
	if mejoras:
		mejoras.reiniciar()
		mejoras.maximo()
		mejoras.activo = true
		mejoras.aplicar_en_jugador(_jugador)
	var inventario := get_node_or_null("/root/Inventory")
	if inventario:
		inventario.infinito = true
		inventario.items.clear()
		inventario.mochila = null
		inventario.dar_todos_los_productos()
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.reiniciar()


# La carrera: solo aplica lo comprado en el refugio; no reinicia el catalogo.
func _aplicar_mejoras() -> void:
	var mejoras := get_node_or_null("/root/Mejoras")
	if mejoras:
		mejoras.activo = true
		mejoras.aplicar_en_jugador(_jugador)


# Deja el mundo como al empezar una noche: tinaco y vida llenos, zombis guardados y el reloj
# otra vez a las 22:00. El dinero, el inventario y el personaje siguen.
func _preparar_noche() -> void:
	_terminado = false
	_noche_cerrada = false
	_hora_fin = 0.0
	_zombis.limpiar()
	_hordas.reiniciar()
	_tinaco.reiniciar()
	_jugador.global_transform = _supervivencia.punto_regreso
	_jugador.velocity = Vector3.ZERO
	_jugador.reanudar()
	_jugador.aplicar_personaje()
	_supervivencia.rearmar_noche()
	_ciclo.reiniciar_noche()


# Al cerrar la noche: Registro y paga/ayuda UNA vez; despues el menu.
func _registro_inicio() -> void:
	var registro = get_node_or_null("/root/Registro")
	if registro == null:
		return
	registro.config_enemigos(_zombis.config)
	registro.config_extra("dificultad", modo)
	registro.config_extra("duracion_noche", duracion_noche)
	registro.config_extra("dano_jugador", _zombis.dano_jugador)
	registro.config_extra("tinaco_vida", TinacoDefensa.VIDA)


func _registro_ola(n: int, cuantos: int, corredores: float, hora: float) -> void:
	var registro = get_node_or_null("/root/Registro")
	if registro:
		registro.ola_empezada(n, cuantos, corredores, hora)


func _registro_emboscada(n: int, cuantos: int, hora: float) -> void:
	var registro = get_node_or_null("/root/Registro")
	if registro:
		registro.emboscada(n, cuantos, hora)


func _crear_monitor() -> void:
	var pruebas = _pruebas()
	var monitor := preload("res://scripts/defensa/MonitorDefensa.gd").new()
	monitor.name = "Monitor"
	monitor.defensa = self
	monitor.carpeta = pruebas.carpeta_noche if pruebas and pruebas.carpeta_noche != "" else pruebas.carpeta
	add_child(monitor)


func _pruebas():
	return get_node_or_null("/root/Pruebas")


# Siguiente (gano) o reintentar la misma noche (perdio): en la carrera vuelve al refugio. En el
# godmode no hay progresion: "Otra vez" recarga la misma noche con todo al maximo.
func _avanzar_noche(siguiente: bool) -> void:
	if _en_transicion or _creador_abierto:
		return
	var pruebas = _pruebas()
	if pruebas and pruebas.es_carrera():
		if siguiente:
			pruebas.siguiente_noche()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/escena_carrera.tscn")
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


# Cambiar personaje sin salir del menu: el creador de Jugar, encima y en pausa. Volver (Esc)
# regresa al menu; para salir de la carrera esta el boton Salir
func _cambiar_personaje() -> void:
	if _creador_abierto or _en_transicion:
		return
	_creador_abierto = true
	var pausar := not get_tree().paused
	if pausar:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 21
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var creador: Control = load("res://scripts/CreadorPersonaje.gd").new()
	capa.add_child(creador)
	var cerrar := func() -> void:
		if is_instance_valid(capa):
			capa.queue_free()
		_creador_abierto = false
		_jugador.aplicar_personaje()
		if pausar:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(_primer_boton) and _primer_boton.is_inside_tree():
			_primer_boton.grab_focus()
	creador.listo.connect(cerrar)
	creador.volver.connect(cerrar)


# Volver al menu de inicio (y de ahi, a jugar el mapa)
func _salir() -> void:
	if _en_transicion:
		return
	var pruebas = _pruebas()
	if pruebas:
		pruebas.cerrar()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/inicio.tscn")


# --- Al amanecer: la paga ---

# Se acabo: a negro y ya es de dia (los zombis se caen y sale la pantalla final)
func _tinaco_roto() -> void:
	# Ya se cerro la noche (gano o se desmayo): no meter otro fundido encima del menu
	if _terminado:
		return
	_hora_fin = _hordas.hora()
	_supervivencia.avisar("¡Rompieron el tinaco!")
	_volumen_musica(MUSICA_SILENCIO, FUNDIDO)
	var capa := CanvasLayer.new()
	capa.layer = 19
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color(0.0, 0.0, 0.0, 0.0)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(negro)
	var tween := create_tween()
	tween.tween_property(negro, "color:a", 1.0, FUNDIDO)
	await tween.finished
	_ciclo.amanecer_ya(true)
	tween = create_tween()
	tween.tween_interval(FUNDIDO)
	tween.tween_property(negro, "color:a", 0.0, FUNDIDO)
	tween.tween_callback(capa.queue_free)


# Supervivencia ya apago la tele: la noche se acaba aqui
func _desmayado() -> void:
	if _terminado:
		return
	_terminado = true
	_hora_fin = _hordas.hora()
	_volumen_musica(MUSICA_SILENCIO, FUNDIDO)
	_cerrar_noche(false, true)


func _fin() -> void:
	if _terminado:
		return
	_terminado = true
	_volumen_musica(MUSICA_SILENCIO, MUSICA_SALE)
	await get_tree().create_timer(FIN_ESPERA).timeout
	_cerrar_noche(_tinaco.vida > 0, false)


func _volumen_musica(db: float, segundos: float) -> void:
	var tween := _musica.create_tween()
	tween.tween_property(_musica, "volume_db", db, segundos)
	if db <= MUSICA_SILENCIO:
		tween.tween_callback(_musica.stop)


# --- El menu entre noches ---

# Cierra la noche UNA vez: Registro y paga/ayuda en Pruebas, y luego el menu.
func _cerrar_noche(gano: bool, desmayo: bool) -> void:
	if _noche_cerrada:
		return
	_noche_cerrada = true
	if PasoJefe.desde_juego:
		_volver_al_mapa(gano, desmayo)
		return
	var pruebas = _pruebas()
	if pruebas:
		pruebas.terminar_noche(gano)
	_pantalla_noche(gano, desmayo)


# Desde el juego (PasoJefe): un aviso y de regreso al mapa. Aguantar hasta el amanecer cumple el
# paso de la mision (que es la que paga); perder no
func _volver_al_mapa(gano: bool, desmayo: bool) -> void:
	var texto := "Amaneció y el tinaco aguantó." if gano \
			else ("Te desmayaste. El tinaco quedó solo." if desmayo else "El tinaco no aguantó.")
	_supervivencia.avisar(texto)
	await get_tree().create_timer(SALIDA_ESPERA).timeout
	PasoJefe.volver(self, gano)


# Gano: paga y deja seguir con la noche siguiente (carrera) o repetir (godmode). Perdio:
# ayuda y la misma noche. Todo corre en pausa: la capa, sus tweens y sus sonidos siempre.
func _pantalla_noche(gano: bool, desmayo: bool) -> void:
	if is_instance_valid(_menu_capa):
		return
	var pruebas = _pruebas()
	var es_carrera: bool = pruebas != null and pruebas.es_carrera()
	var cartera := get_node_or_null("/root/Cartera")
	var dinero_ahora: int = cartera.pesos if cartera else 0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	_menu_capa = capa
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.7) if gano else Color(0.22, 0.0, 0.0, 0.85)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)
	var pantalla := fondo.get_viewport_rect().size
	if gano:
		_hoja(fondo, "amanecer_rayos", Rect2(Vector2.ZERO, pantalla), true, 0.6, 22.0)
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 6)
	capa.add_child(caja)
	var titulo_texto := ""
	if gano:
		titulo_texto = "¡GANASTE LA NOCHE %d!" % noche
	elif desmayo:
		titulo_texto = "TE DESMAYASTE EN LA NOCHE %d" % noche
	else:
		titulo_texto = "TINACO ROTO · NOCHE %d" % noche
	var titulo := _etiqueta(titulo_texto, TITULO_TAMANO, AMARILLO if gano else ROJO)
	titulo.add_theme_constant_override("outline_size", 6)
	caja.add_child(titulo)
	caja.add_child(_espacio(8.0))
	var renglones: Array[Label] = []
	renglones.append(_etiqueta("Zombis reventados: %d" % _hordas.muertos, RENGLON_TAMANO, Color.WHITE))
	if gano:
		renglones.append(_etiqueta("Lo más feo: %d a la vez, a las %s" % [_hordas.mas_juntos, Hordas.texto_hora(_hordas.hora_mas_juntos)], RENGLON_TAMANO, Color.WHITE))
		renglones.append(_etiqueta("Agua en el tinaco: %d %%" % roundi(_tinaco.fraccion() * 100.0), RENGLON_TAMANO, AGUA))
		if es_carrera:
			renglones.append(_etiqueta("Dinero al empezar: $%d" % pruebas.pesos_al_empezar, RENGLON_TAMANO, Color.WHITE))
			renglones.append(_etiqueta("Paga: +$%d · Ahora: $%d" % [pruebas.PAGA, dinero_ahora], RENGLON_TAMANO, AMARILLO))
			var siguiente := _dificultad_base * pow(DIFICULTAD_POR_NOCHE, noche)
			renglones.append(_etiqueta("La siguiente: grupos x%.2f, zombi pega %d" % [siguiente, mini(_dano_base + noche * DANO_POR_NOCHE, DANO_TOPE)], RENGLON_TAMANO, AMARILLO))
	else:
		renglones.append(_etiqueta("Aguantaste hasta las %s" % Hordas.texto_hora(_hora_fin), RENGLON_TAMANO, Color.WHITE))
		if es_carrera:
			renglones.append(_etiqueta("Dinero al empezar: $%d" % pruebas.pesos_al_empezar, RENGLON_TAMANO, Color.WHITE))
			renglones.append(_etiqueta("Ayuda para la revancha: +$%d · Ahora: $%d" % [pruebas.BONO_PERDIDA, dinero_ahora], RENGLON_TAMANO, AMARILLO))
			renglones.append(_etiqueta("Reintentas la noche %d con lo comprado." % noche, RENGLON_TAMANO, Color.WHITE))
		else:
			renglones.append(_etiqueta("Prueba de mecánicas sin progresión.", RENGLON_TAMANO, ROJO))
	for renglon in renglones:
		renglon.modulate.a = 0.0
		caja.add_child(renglon)
	var paga: Label = null
	if gano and es_carrera:
		paga = _etiqueta("$0", TITULO_TAMANO, AMARILLO)
		paga.modulate.a = 0.0
		caja.add_child(paga)
	var cierres: Array = CIERRES_GANO if gano else (CIERRES_DESMAYO if desmayo else CIERRES_TINACO)
	var cierre := _etiqueta(cierres.pick_random(), RENGLON_TAMANO, Color(0.85, 0.85, 0.85))
	cierre.modulate.a = 0.0
	caja.add_child(_espacio(6.0))
	caja.add_child(cierre)
	caja.add_child(_espacio(6.0))
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	botones.modulate.a = 0.0
	caja.add_child(botones)
	_botones = botones
	var seguir := Button.new()
	if es_carrera:
		seguir.text = "Siguiente" if gano else "Reintentar la noche"
	else:
		seguir.text = "Otra vez"
	seguir.theme = TEMA
	seguir.disabled = true
	seguir.pressed.connect(_avanzar_noche.bind(gano if es_carrera else false))
	botones.add_child(seguir)
	_primer_boton = seguir
	var cambiar := Button.new()
	cambiar.text = "Cambiar personaje"
	cambiar.theme = TEMA
	cambiar.disabled = true
	cambiar.pressed.connect(_cambiar_personaje)
	botones.add_child(cambiar)
	var salir := Button.new()
	salir.text = "Salir"
	salir.theme = TEMA
	salir.disabled = true
	salir.pressed.connect(_salir)
	botones.add_child(salir)
	await get_tree().process_frame
	titulo.pivot_offset = titulo.size / 2.0
	# El titulo: cae grande y rebota (gano) o tiembla y se pone rojo (perdio)
	var tween := capa.create_tween()
	if gano:
		titulo.scale = Vector2.ONE * 2.5
		titulo.modulate.a = 0.0
		tween.tween_property(titulo, "modulate:a", 1.0, 0.15)
		tween.parallel().tween_property(titulo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: Sonidos.tocar(capa, "boom", -6.0))
		tween.tween_property(titulo, "rotation", 0.05, 0.06)
		tween.tween_property(titulo, "rotation", -0.04, 0.06)
		tween.tween_property(titulo, "rotation", 0.0, 0.06)
	else:
		_hoja(fondo, "tinaco_chorro", Rect2(Vector2(pantalla.x * 0.5 + 60.0, pantalla.y * 0.18), Vector2(188.0, 80.0)), false, 0.9)
		var izquierda := _hoja(fondo, "tinaco_chorro", Rect2(Vector2(pantalla.x * 0.5 - 248.0, pantalla.y * 0.18), Vector2(188.0, 80.0)), false, 0.9)
		if izquierda:
			izquierda.flip_h = true
		titulo.modulate = Color.WHITE
		tween.tween_callback(func() -> void: Sonidos.tocar(capa, "perder", -2.0))
		tween.tween_property(titulo, "rotation", -0.12, 0.08)
		tween.tween_property(titulo, "rotation", 0.08, 0.08)
		tween.tween_property(titulo, "rotation", -0.04, 0.08)
		tween.parallel().tween_property(titulo, "scale", Vector2(1.08, 0.9), 0.08)
		tween.tween_property(titulo, "rotation", 0.0, 0.1)
		tween.parallel().tween_property(titulo, "scale", Vector2.ONE, 0.1)
	# Los renglones, uno por uno
	for renglon in renglones:
		tween.tween_interval(RENGLON_CADA)
		tween.tween_callback(func() -> void: Sonidos.tocar(capa, "boton", -4.0))
		tween.tween_property(renglon, "modulate:a", 1.0, 0.12)
	# La paga, contando
	if paga:
		tween.tween_interval(RENGLON_CADA)
		tween.tween_property(paga, "modulate:a", 1.0, 0.1)
		var pasos := [0]
		tween.tween_method(func(valor: float) -> void:
			paga.text = "$%d" % roundi(valor)
			var paso := int(valor / maxf(float(pruebas.PAGA), 1.0) * CUENTA_PASOS)
			if paso > pasos[0]:
				pasos[0] = paso
				Sonidos.tocar(capa, "moneda", -8.0), 0.0, float(pruebas.PAGA), CUENTA_DURA)
		tween.tween_callback(func() -> void:
			var donde := paga.get_global_rect()
			_hoja(fondo, "premio_monedas", Rect2(donde.get_center() - Vector2(80.0, 70.0), Vector2(160.0, 88.0)))
			Sonidos.tocar(capa, "campana", -6.0))
		tween.tween_property(paga, "scale", Vector2.ONE * 1.25, 0.08)
		tween.tween_property(paga, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(RENGLON_CADA)
	tween.tween_property(cierre, "modulate:a", 1.0, 0.3)
	tween.tween_property(botones, "modulate:a", 1.0, 0.2)
	# Hasta que no acaba la animacion no se pueden pulsar: se ven pero estan apagados
	tween.tween_callback(func() -> void:
		for hijo in botones.get_children():
			if hijo is Button:
				(hijo as Button).disabled = false
		_primer_boton.grab_focus())
	if paga:
		paga.resized.connect(func() -> void: paga.pivot_offset = paga.size / 2.0)
		paga.pivot_offset = paga.size / 2.0


# Una hoja de pixelfx dentro de un Control, animada con un tween (corre en pausa si su
# padre corre). Las que no se repiten se borran al terminar. `recorte`: px de abajo
func _hoja(padre: Control, nombre: String, lugar: Rect2, aditivo := false, alfa := 1.0, recorte := 0.0) -> TextureRect:
	var hoja := EfectosPixel.hoja_de(nombre)
	if hoja.is_empty():
		return null
	var tamano: Vector2 = hoja["tamano"] - Vector2(0.0, recorte)
	var region := AtlasTexture.new()
	region.atlas = hoja["textura"]
	region.region = Rect2(Vector2.ZERO, tamano)
	var cuadro := TextureRect.new()
	cuadro.texture = region
	cuadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cuadro.stretch_mode = TextureRect.STRETCH_SCALE
	cuadro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuadro.position = lugar.position
	cuadro.size = lugar.size
	cuadro.modulate.a = alfa
	if aditivo:
		var mezcla := CanvasItemMaterial.new()
		mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cuadro.material = mezcla
	padre.add_child(cuadro)
	var dura: float = hoja["cuadros"] / hoja["fps"]
	var tween := cuadro.create_tween()
	if hoja["loop"]:
		tween.set_loops()
	tween.tween_method(func(t: float) -> void:
		var i := mini(int(t * hoja["fps"]), hoja["cuadros"] - 1)
		region.region = Rect2(Vector2(i % hoja["columnas"], i / hoja["columnas"]) * hoja["tamano"], tamano), 0.0, dura, dura)
	if not hoja["loop"]:
		tween.tween_callback(cuadro.queue_free)
	return cuadro


func _espacio(alto: float) -> Control:
	var espacio := Control.new()
	espacio.custom_minimum_size.y = alto
	return espacio


# --- Lo de la pantalla ---

func _armar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 3
	add_child(capa)
	_hora = _etiqueta("", 20, Color.WHITE)
	_hora.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Abajo de la barra de vida (Supervivencia)
	_hora.position = Vector2(10.0, 20.0)
	capa.add_child(_hora)
	_amanecer = _barra(capa, Vector2(10.0, 48.0), AMARILLO, "amanecer")
	_vida_tinaco = _barra(capa, Vector2(10.0, 62.0), AGUA, "tinaco")
	_jefe = Control.new()
	_jefe.visible = false
	_jefe.position = Vector2((640.0 - JEFE_ANCHO) / 2.0, 14.0)
	capa.add_child(_jefe)
	var nombre := _etiqueta("EL PANZÓN", 16, ROJO)
	nombre.size = Vector2(JEFE_ANCHO, 18.0)
	nombre.position = Vector2(0.0, -2.0)
	_jefe.add_child(nombre)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.position = Vector2(-1.0, 17.0)
	fondo.size = Vector2(JEFE_ANCHO + 2.0, 9.0)
	_jefe.add_child(fondo)
	_jefe_barra = ColorRect.new()
	_jefe_barra.color = ROJO
	_jefe_barra.position = Vector2(0.0, 18.0)
	_jefe_barra.size = Vector2(JEFE_ANCHO, 7.0)
	_jefe.add_child(_jefe_barra)


# El negro del cambio de noche. Va arriba de todo (el menu y el creador usan 20 y 21) y
# corre siempre, para poder fundir mientras el juego esta en pausa
func _armar_fundido() -> void:
	_capa_fundido = CanvasLayer.new()
	_capa_fundido.layer = 23
	_capa_fundido.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_capa_fundido)
	_fundido = ColorRect.new()
	_fundido.color = Color(0.0, 0.0, 0.0, 0.0)
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundido.visible = false
	_capa_fundido.add_child(_fundido)


# Una barra de 110 px que se llena con scale.x, con su nombre al lado
func _barra(capa: CanvasLayer, donde: Vector2, color: Color, nombre: String) -> ColorRect:
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.6)
	fondo.position = donde - Vector2.ONE
	fondo.size = Vector2(112.0, 8.0)
	capa.add_child(fondo)
	var barra := ColorRect.new()
	barra.color = color
	barra.position = donde
	barra.size = Vector2(110.0, 6.0)
	capa.add_child(barra)
	var etiqueta := _etiqueta(nombre, 12, color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	etiqueta.position = donde + Vector2(118.0, -6.0)
	capa.add_child(etiqueta)
	return barra


func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.theme = TEMA
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_shadow_color", Color.BLACK)
	return etiqueta


# Paredes invisibles en la orilla, solo para el jugador: los zombis salen adentro
func _armar_paredes() -> void:
	var paredes := StaticBody3D.new()
	paredes.name = "Paredes"
	paredes.collision_layer = PARED_CAPA
	paredes.collision_mask = 0
	add_child(paredes)
	for i in 4:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(LADO * 2.0 + 2.0, PARED_ALTO, 1.0)
		forma.shape = caja
		var hacia := Vector3(sin(i * PI / 2.0), 0.0, -cos(i * PI / 2.0))
		forma.transform = Transform3D(Basis(Vector3.UP, i * PI / 2.0), CENTRO + hacia * (LADO + 0.5) + Vector3.UP * PARED_ALTO / 4.0)
		paredes.add_child(forma)


# --- Minimapa ---

func _dibujar_mapa() -> ImageTexture:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MINIMAPA_DATOS))
	var por_pixel: float = datos["metros_por_pixel"]
	var completo := (load(MINIMAPA) as Texture2D).get_image()
	completo.decompress()
	var lado := int(MAPA_LADO * 2.0 / por_pixel)
	var desde := Vector2i(int((CENTRO.x - MAPA_LADO - datos["x0"]) / por_pixel), int((CENTRO.z - MAPA_LADO - datos["z0"]) / por_pixel))
	var imagen := completo.get_region(Rect2i(desde, Vector2i(lado, lado)))
	imagen.convert(Image.FORMAT_RGB8)
	var final := int(MAPA_LADO * 2.0 / MAPA_M_POR_PIXEL)
	imagen.resize(final, final, Image.INTERPOLATE_NEAREST)
	# Fuera de las paredes, oscuro
	var adentro := _pixel(Vector3(CENTRO.x - LADO, 0.0, CENTRO.z - LADO))
	var hasta := _pixel(Vector3(CENTRO.x + LADO, 0.0, CENTRO.z + LADO))
	for px in final:
		for pz in final:
			if px < adentro.x or pz < adentro.y or px >= hasta.x or pz >= hasta.y:
				imagen.set_pixel(px, pz, imagen.get_pixel(px, pz).darkened(MAPA_AFUERA))
	var base := _barricada.global_transform
	for huella: Array in _barricada.huellas:
		_pintar_caja(imagen, base * huella[0], huella[1], MAPA_BARRICADA)
	for tambo in _barricada.tambos:
		_pintar_circulo(imagen, base * tambo.origin, MapAlumbrado.TAMBO_RADIO + 0.2, MAPA_TAMBO)
	_pintar_circulo(imagen, _tinaco.global_position, _tinaco.radio, MAPA_TINACO)
	return ImageTexture.create_from_image(imagen)


# Del mundo al pixel del minimapa: columna = x, fila = z, desde la esquina de menor valor
func _pixel(mundo: Vector3) -> Vector2i:
	return Vector2i(int((mundo.x - CENTRO.x + MAPA_LADO) / MAPA_M_POR_PIXEL), int((mundo.z - CENTRO.z + MAPA_LADO) / MAPA_M_POR_PIXEL))


func _mundo(px: int, pz: int) -> Vector3:
	return Vector3(CENTRO.x - MAPA_LADO + (px + 0.5) * MAPA_M_POR_PIXEL, 0.0, CENTRO.z - MAPA_LADO + (pz + 0.5) * MAPA_M_POR_PIXEL)


# Solo recorre los pixeles de la caja que la encierra
func _pintar_caja(imagen: Image, lugar: Transform3D, medida: Vector2, color: Color) -> void:
	var inversa := lugar.affine_inverse()
	var alcance := Vector3.ONE * medida.length() / 2.0
	var lado := imagen.get_width()
	var desde := _pixel(lugar.origin - alcance)
	var hasta := _pixel(lugar.origin + alcance)
	for px in range(maxi(0, desde.x), mini(lado, hasta.x + 1)):
		for pz in range(maxi(0, desde.y), mini(lado, hasta.y + 1)):
			var local := inversa * (_mundo(px, pz) + Vector3.UP * lugar.origin.y)
			if absf(local.x) <= medida.x / 2.0 and absf(local.z) <= medida.y / 2.0:
				imagen.set_pixel(px, pz, color)


func _pintar_circulo(imagen: Image, centro: Vector3, radio: float, color: Color) -> void:
	var lado := imagen.get_width()
	var alcance := Vector3.ONE * radio
	var desde := _pixel(centro - alcance)
	var hasta := _pixel(centro + alcance)
	for px in range(maxi(0, desde.x), mini(lado, hasta.x + 1)):
		for pz in range(maxi(0, desde.y), mini(lado, hasta.y + 1)):
			var mundo := _mundo(px, pz)
			if Vector2(mundo.x - centro.x, mundo.z - centro.z).length() <= maxf(radio, MAPA_M_POR_PIXEL):
				imagen.set_pixel(px, pz, color)


# --- Capturas para revisar ---

func _capturas(carpeta: String) -> void:
	DirAccess.make_dir_recursive_absolute(carpeta)
	var centro := _barricada.global_position
	var camara := Camera3D.new()
	camara.fov = 60.0
	add_child(camara)
	camara.make_current()
	# Dejar que carguen los modelos y los shaders
	for i in 30:
		await get_tree().process_frame
	var ambiente := (get_node("WorldEnvironment") as WorldEnvironment).environment
	var noche := ambiente.ambient_light_energy
	for vista: Array in VISTAS:
		camara.look_at_from_position(centro + vista[1], centro + vista[2], Vector3.FORWARD if vista[0] == "cenital" else Vector3.UP)
		ambiente.ambient_light_energy = noche if vista[0] == "noche" else LUZ_REVISION
		ambiente.fog_enabled = vista[0] == "noche"
		_jugador.visible = vista[0] != "desde_tinaco"
		for i in 8:
			await get_tree().process_frame
		var imagen := get_viewport().get_texture().get_image()
		imagen.save_png(carpeta.path_join("%s.png" % vista[0]))
	# De cerca: las bocinas y las camionetas (DecoracionDefensa.vistas)
	ambiente.ambient_light_energy = LUZ_REVISION
	ambiente.fog_enabled = false
	_jugador.visible = false
	_decoracion.dibujar_rutas()
	for vista: Array in _decoracion.vistas():
		camara.look_at_from_position(vista[1], vista[2], Vector3.UP)
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s.png" % vista[0]))
	# Y el minimapa solo, para ver la barricada sobre las calles
	var minimapa := _minimapa.mapa as Texture2D
	minimapa.get_image().save_png(carpeta.path_join("minimapa.png"))
	get_tree().quit()
