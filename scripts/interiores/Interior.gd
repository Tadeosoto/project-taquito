@tool
class_name Interior
extends Node3D

# Interior de un negocio (docs/especificaciones.md 4.6): una escena fija en primera
# persona, no un espacio que se camina. Ves al que te atiende detras del mostrador y,
# al fondo, estantes o refrigeradores con lo que se vende. En muchos negocios de
# colonia se compra desde la banqueta por una reja: con `reja` la camara queda afuera,
# frente a la fachada con la ventana enrejada, y el mostrador llena la ventana. Con
# `calle` es al reves (la taqueria): uno esta sentado adentro y el fondo es la cortina
# abierta a la banqueta, con el puesto afuera y la calle y las casas de enfrente.
#
# Coordenadas: el frente del mostrador esta en z = 0 (centrado en x = 0), el piso en
# y = 0 y el local se mete `fondo` m hacia -Z. La camara va en +Z viendo hacia -Z.
#
# Cada escena debe tener estos hijos:
#   Camara    (Camera3D) la vista fija; con el mouse se mira un poco alrededor
#   Mostrador (Mostrador.gd con el estilo del giro, un Mueble, o un Marker3D)
#   Vendedor  (por ahora scenes/npc.tscn con su dialogo; despues, su personaje y el menu)
# y puede tener una `Vitrina` (Marker3D) donde flotan dando vueltas los `productos` que
# vende (Vitrina.gd, frente a la camara a la altura del mostrador), con su ficha y tu dinero en pantalla (TiendaUI.gd). Comprar todavia
# no hace nada.
# Con `generar_local` arma piso, paredes, techo, luces y, con `reja`, la fachada; si no,
# el local es un modelo y solo se ponen las luces.
#
# Se puede correr sola para verla: godot --path . scenes/interiores/abarrotes.tscn

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const DITHER_SHADER := preload("res://shaders/dittershader.gdshader")
const SUELO_SHADER := preload("res://shaders/ps1_suelo.gdshader")
const PISO_TEXTURA := preload("res://textures/map/banqueta.png")
const ASFALTO_TEXTURA := preload("res://textures/map/asfalto.png")
const GROSOR := 0.2
const REQUERIDOS := ["Camara", "Mostrador", "Vendedor"]
# Cuanto se puede voltear con el mouse (grados, con la camara de 62 grados; con menos
# angulo se voltea menos, asi la toma cerrada de adentro no deja ver los muros vacios)
# y que tan rapido
const MIRAR_MAX := Vector2(14.0, 8.0)
const MIRAR_FOV := 62.0
const MIRAR_SENSIBILIDAD := 0.06
# Banqueta que se ve frente a la reja (m)
const BANQUETA := 3.0
const BARROTE := 0.025
const BARROTE_PASO := 0.15
# Obra negra: barda.png es un atlas de 3 muros (liso, aplanado caido, block pelon)
const BARDA_TEXTURA := preload("res://textures/map/barda.png")
const GRAFITIS_DIR := "res://textures/map/grafitis/"
# Los tags negros sobre blanco (recortar_calcomanias.py), no las piezas de colores
const GRAFITIS_PREFIJO := "grafiti_firma_"
const BLOCK_TILE := 1.6     # m que mide un cuadro del muro
# Calle frente a la cortina abierta (m): banqueta, arroyo y la hilera de casas
const CALLE_BANQUETA := 3.2
const CALLE_ARROYO := 7.0
const CALLE_LARGO := 30.0
const CASA_COLORES := [Color(0.85, 0.62, 0.35), Color(0.55, 0.7, 0.75), Color(0.85, 0.82, 0.7),
	Color(0.72, 0.42, 0.38), Color(0.6, 0.72, 0.5), Color(0.88, 0.78, 0.45)]

@export var generar_local := true:
	set(valor):
		generar_local = valor
		_reconstruir()
@export var ancho := 4.4:
	set(valor):
		ancho = valor
		_reconstruir()
# Del frente del mostrador a la pared del fondo
@export var fondo := 2.8:
	set(valor):
		fondo = valor
		_reconstruir()
@export var alto := 2.8:
	set(valor):
		alto = valor
		_reconstruir()
# Sin reja: hasta donde sigue el cuarto hacia la camara
@export var frente := 2.5:
	set(valor):
		frente = valor
		_reconstruir()
@export var color_muro := Color(0.9, 0.86, 0.7):
	set(valor):
		color_muro = valor
		_reconstruir()
# Muro de dos colores como los locales de la calle (MapPuntos._make_local): abajo
# `color_guardapolvo` hasta `alto_guardapolvo` y una franja del mismo color encima.
# Alfa 0 = muro de un solo color
@export var color_guardapolvo := Color(0, 0, 0, 0):
	set(valor):
		color_guardapolvo = valor
		_reconstruir()
@export var alto_guardapolvo := 1.1:
	set(valor):
		alto_guardapolvo = valor
		_reconstruir()
@export var color_piso := Color(0.75, 0.72, 0.68):
	set(valor):
		color_piso = valor
		_reconstruir()
@export var color_techo := Color(0.85, 0.85, 0.82):
	set(valor):
		color_techo = valor
		_reconstruir()
@export var color_luz := Color(1.0, 0.97, 0.88):
	set(valor):
		color_luz = valor
		_reconstruir()
@export var energia_luz := 1.3:
	set(valor):
		energia_luz = valor
		_reconstruir()
# Luz sobre el mostrador para que se le vea la cara al que atiende
@export var luz_mostrador := true:
	set(valor):
		luz_mostrador = valor
		_reconstruir()

@export_group("Tienda")
# Lo que vende, en el orden del carrusel (resources/productos/)
@export var productos: Array[InventoryItemData] = []
# Multiplica los precios en pesos (el OXO mas caro que los abarrotes)
@export var precio_factor := 1.0

@export_group("Obra negra")
# Muros de block con hollin y grafitis (el punto) en vez de muros pintados
@export var obra_negra := false:
	set(valor):
		obra_negra = valor
		_reconstruir()
@export var grafitis := 9:
	set(valor):
		grafitis = valor
		_reconstruir()
# Un foco pelon colgando en vez de las lamparas de tubo
@export var foco := false:
	set(valor):
		foco = valor
		_reconstruir()
# Que el foco parpadee como las lamparas de la calle que fallan (Alumbrado.parpadeo)
@export var foco_parpadea := true
# Acomodo de grafitis y manchas
@export var semilla := 0:
	set(valor):
		semilla = valor
		_reconstruir()

@export_group("Reja")
@export var reja := false:
	set(valor):
		reja = valor
		_reconstruir()
# Sin barrotes queda solo la ventana abierta (la purificadora)
@export var barrotes := true:
	set(valor):
		barrotes = valor
		_reconstruir()
@export var ventana_ancho := 2.4:
	set(valor):
		ventana_ancho = valor
		_reconstruir()
@export var ventana_alto := 2.1:
	set(valor):
		ventana_alto = valor
		_reconstruir()
# Los barrotes empiezan aqui; abajo queda la ventanita para pasar las cosas
@export var reja_desde := 1.25:
	set(valor):
		reja_desde = valor
		_reconstruir()
@export var color_fachada := Color(0.85, 0.75, 0.45):
	set(valor):
		color_fachada = valor
		_reconstruir()
@export var color_reja := Color(0.15, 0.15, 0.16):
	set(valor):
		color_reja = valor
		_reconstruir()
# La fachada del mapa en vez de la generica: MapPuntos._make_purificadora con
# solo_fachada, corrida para que su ventanal quede centrado en x = 0 (la purificadora)
@export var fachada_mapa := false:
	set(valor):
		fachada_mapa = valor
		_reconstruir()
# Ancho del lote de esa fachada (el ventanal sale de lo que sobra)
@export var fachada_mapa_ancho := 7.0:
	set(valor):
		fachada_mapa_ancho = valor
		_reconstruir()

@export_group("Calle")
# El muro del fondo es la cortina abierta a la calle (taqueria)
@export var calle := false:
	set(valor):
		calle = valor
		_reconstruir()
@export var calle_vano := 3.0:
	set(valor):
		calle_vano = valor
		_reconstruir()
@export var calle_vano_alto := 2.3:
	set(valor):
		calle_vano_alto = valor
		_reconstruir()

# Lo prende Interiores.gd (o correrla sola): mirar con el mouse
var activo := false
# Lo pone Interiores.gd antes de agregarla: el nombre del negocio del mapa, que va
# pintado en la fachada (sin el, el nombre de la escena)
var nombre := ""

var _local: Node3D
var _foco_luz: OmniLight3D
var _foco_bulbo: StandardMaterial3D
var _camara_base := Vector3.ZERO
var _mirada := Vector2.ZERO
var _tiempo := 0.0
var _vitrina: Vitrina
var _ui: TiendaUI


func _ready() -> void:
	_reconstruir()
	if Engine.is_editor_hint():
		return
	for requerido in REQUERIDOS:
		if not has_node(requerido):
			push_error("Interior %s: falta el nodo %s" % [name, requerido])
	_camara_base = camara().rotation_degrees
	var lugar := get_node_or_null("Vitrina") as Node3D
	if lugar and not productos.is_empty():
		_vitrina = Vitrina.new()
		lugar.add_child(_vitrina)
		_vitrina.mostrar(productos)
	if get_parent() == get_tree().root:
		_solo()


func _get_configuration_warnings() -> PackedStringArray:
	var faltan := PackedStringArray()
	for requerido in REQUERIDOS:
		if not has_node(requerido):
			faltan.append("Falta el nodo %s (todos los interiores llevan mostrador y vendedor)." % requerido)
	return faltan


func camara() -> Camera3D:
	return get_node("Camara") as Camera3D


# Ya en pantalla: mirar con el mouse, el carrusel de productos y su ficha
func activar() -> void:
	activo = true
	_ui = TiendaUI.new()
	add_child(_ui)
	_ficha()
	_ui.decir(dialogo())


func _ficha() -> void:
	if _ui:
		_ui.mostrar(productos[_vitrina.actual()] if _vitrina else null, precio_factor)


func _cambiar(paso: int) -> void:
	if _vitrina:
		_vitrina.mover(paso)
		_ficha()


# Lo que dice el que atiende al llegar
func dialogo() -> String:
	var vendedor := get_node_or_null("Vendedor")
	return String(vendedor.get("dialogue")) if vendedor and vendedor.get("dialogue") else ""


func _unhandled_input(event: InputEvent) -> void:
	if not activo or Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var tope := MIRAR_MAX * camara().fov / MIRAR_FOV
		_mirada -= (event as InputEventMouseMotion).relative * MIRAR_SENSIBILIDAD * camara().fov / MIRAR_FOV
		_mirada = _mirada.clamp(-tope, tope)
	elif event.is_action_pressed("inventory_previous") or event.is_action_pressed("move_left"):
		_cambiar(-1)
	elif event.is_action_pressed("inventory_next") or event.is_action_pressed("move_right"):
		_cambiar(1)
	elif event.is_action_pressed("jump") and _ui:
		_ui.decir("Comprar: próximamente", 1.5)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not has_node("Camara"):
		return
	# Respirar: la vista se mueve apenas para que no parezca foto
	_tiempo += delta
	if _foco_luz and foco_parpadea:
		var brillo := Alumbrado.parpadeo(semilla, Time.get_ticks_msec() / 1000.0)
		_foco_luz.light_energy = energia_luz * brillo
		_foco_bulbo.albedo_color = color_luz.darkened(0.85 * (1.0 - brillo))
	var vivo := Vector2(sin(_tiempo * 0.7) * 0.4, sin(_tiempo * 1.1) * 0.25)
	camara().rotation_degrees = _camara_base + Vector3(_mirada.y + vivo.y, _mirada.x + vivo.x, 0.0)


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _local:
		_local.queue_free()
	_foco_luz = null
	_local = Node3D.new()
	_local.name = "_Local"
	add_child(_local, false, Node.INTERNAL_MODE_FRONT)
	if generar_local:
		_cuarto()
		if reja and fachada_mapa:
			_fachada_mapa()
		elif reja:
			_fachada()
		elif calle:
			_calle()
	_luces()


func _cuarto() -> void:
	var muro: Material = _block(2, BLOCK_TILE) if obra_negra else _material(color_muro, 2)
	var mitad := ancho / 2.0
	# Con reja el cuarto termina en la fachada; sin ella sigue hasta atras de la camara
	var adelante := 0.0 if reja else frente
	var largo := fondo + adelante
	var centro := (adelante - fondo) / 2.0
	_caja(Vector3(ancho + 2 * GROSOR, GROSOR, largo), Vector3(0, -GROSOR / 2, centro), _piso(color_piso))
	_caja(Vector3(ancho + 2 * GROSOR, GROSOR, largo), Vector3(0, alto + GROSOR / 2, centro), _material(color_techo, 1))
	# Los muros se meten en el piso, el techo y entre ellos: el temblor de vertices del
	# shader PS1 abria rendijas en las esquinas
	var alto_muro := alto + 2 * GROSOR
	if calle:
		_muro_vano(Vector3(ancho + 2 * GROSOR, alto_muro, GROSOR), -fondo - GROSOR / 2, muro)
	else:
		_caja(Vector3(ancho + 2 * GROSOR, alto_muro, GROSOR), Vector3(0, alto / 2, -fondo - GROSOR / 2), muro)
	for signo in [-1.0, 1.0]:
		_caja(Vector3(GROSOR, alto_muro, largo + GROSOR), Vector3(signo * (mitad + GROSOR / 2), alto / 2, centro - GROSOR / 2), muro)
	_forro(largo, centro)
	if obra_negra:
		_manchas(largo, centro)
		return
	if color_guardapolvo.a > 0.0:
		# Guardapolvo y franja: una cascara pegada al muro, con su pintura caida
		var pintura := _material(color_guardapolvo, 2)
		for banda in [[0.0, alto_guardapolvo], [alto_guardapolvo + 0.2, alto_guardapolvo + 0.32]]:
			var h: float = banda[1] - banda[0]
			var y: float = (banda[0] + banda[1]) / 2.0
			if calle:
				_muro_vano(Vector3(ancho, h, 0.015), -fondo + 0.0075, pintura, y)
			else:
				_caja(Vector3(ancho, h, 0.015), Vector3(0, y, -fondo + 0.0075), pintura)
			for signo in [-1.0, 1.0]:
				_caja(Vector3(0.015, h, largo), Vector3(signo * (mitad - 0.0075), y, centro), pintura)
	# Rodapie oscuro
	var rodapie := _material(color_muro.darkened(0.45), 1)
	if calle:
		_muro_vano(Vector3(ancho, 0.12, 0.02), -fondo + 0.01, rodapie, 0.06)
	else:
		_caja(Vector3(ancho, 0.12, 0.02), Vector3(0, 0.06, -fondo + 0.01), rodapie)
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.02, 0.12, largo), Vector3(signo * (mitad - 0.01), 0.06, centro), rodapie)


# Caja negra por fuera del cuarto: si queda alguna rendija se ve negro, no el cielo.
# Con `calle` sin la cara del fondo, para ver afuera por el vano
func _forro(largo: float, centro: float) -> void:
	var negro := StandardMaterial3D.new()
	negro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	negro.albedo_color = Color.BLACK
	negro.cull_mode = BaseMaterial3D.CULL_FRONT
	var tamano := Vector3(ancho + 1.0, alto + 1.0, largo + 1.0)
	if not calle:
		var forro := _caja(tamano, Vector3(0, alto / 2, centro), negro)
		forro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	negro.cull_mode = BaseMaterial3D.CULL_DISABLED
	var atras := -fondo - GROSOR - 0.05
	var adelante := centro + tamano.z / 2
	var z := (atras + adelante) / 2
	var largo_forro := adelante - atras
	for pieza in [[Vector3(0.05, tamano.y, largo_forro), Vector3(-tamano.x / 2, alto / 2, z)],
			[Vector3(0.05, tamano.y, largo_forro), Vector3(tamano.x / 2, alto / 2, z)],
			[Vector3(tamano.x, 0.05, largo_forro), Vector3(0, alto / 2 + tamano.y / 2, z)],
			[Vector3(tamano.x, 0.05, largo_forro), Vector3(0, alto / 2 - tamano.y / 2, z)],
			[Vector3(tamano.x, tamano.y, 0.05), Vector3(0, alto / 2, adelante)]]:
		_caja(pieza[0], pieza[1], negro).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Una pieza del muro del fondo (en z) partida por el vano de la cortina: los dos lados
# y, si llega mas arriba, el dintel. `y` es el centro de la pieza
func _muro_vano(tamano: Vector3, z: float, material: Material, y := -1.0) -> void:
	if y < 0.0:
		y = alto / 2
	var lado := (tamano.x - calle_vano) / 2
	for signo in [-1.0, 1.0]:
		_caja(Vector3(lado, tamano.y, tamano.z), Vector3(signo * (calle_vano + lado) / 2, y, z), material)
	var arriba := y + tamano.y / 2
	if arriba > calle_vano_alto:
		var abajo := maxf(y - tamano.y / 2, calle_vano_alto)
		_caja(Vector3(calle_vano, arriba - abajo, tamano.z), Vector3(0, (arriba + abajo) / 2, z), material)


# Afuera de la cortina: la cortina enrollada, banqueta, guarnicion, arroyo y la hilera
# de casas de enfrente (para que no se vea el vacio: el interior esta a 500 m)
func _calle() -> void:
	var z0 := -fondo - GROSOR
	# Umbral entre el piso del local y la banqueta
	_caja(Vector3(calle_vano, GROSOR, GROSOR), Vector3(0, -GROSOR / 2, -fondo - GROSOR / 2), _piso(color_piso))
	# Luz de dia de afuera (corriendo sola no hay sol)
	var dia := OmniLight3D.new()
	dia.light_color = Color(1.0, 0.96, 0.88)
	dia.light_energy = 0.55
	dia.omni_range = 16.0
	dia.omni_attenuation = 0.5
	dia.position = Vector3(0, 6.0, z0 - CALLE_BANQUETA - CALLE_ARROYO / 2)
	_local.add_child(dia)
	var cortina := MeshInstance3D.new()
	var rollo := CylinderMesh.new()
	rollo.top_radius = 0.13
	rollo.bottom_radius = 0.13
	rollo.height = calle_vano + 0.1
	rollo.radial_segments = 10
	rollo.material = _material(Color(0.5, 0.48, 0.45), 1)
	cortina.mesh = rollo
	cortina.rotation.z = PI / 2
	cortina.position = Vector3(0, calle_vano_alto + 0.15, z0 - 0.15)
	_local.add_child(cortina)
	_caja(Vector3(calle_vano + 0.2, 0.25, 0.04), Vector3(0, calle_vano_alto + 0.15, z0 - 0.02), _material(Color(0.45, 0.44, 0.42), 1))
	# Banqueta con su guarnicion pintada y el arroyo
	var banqueta_z := z0 - CALLE_BANQUETA / 2
	_caja(Vector3(CALLE_LARGO, 0.15, CALLE_BANQUETA), Vector3(0, -0.075, banqueta_z), _piso(Color(0.8, 0.8, 0.78)))
	var guarnicion_z := z0 - CALLE_BANQUETA
	_caja(Vector3(CALLE_LARGO, 0.17, 0.15), Vector3(0, -0.085, guarnicion_z + 0.075), _material(Color(0.8, 0.78, 0.4), 1))
	var asfalto := ShaderMaterial.new()
	asfalto.shader = SUELO_SHADER
	asfalto.set_shader_parameter("albedo_texture", ASFALTO_TEXTURA)
	asfalto.set_shader_parameter("tile_size", 4.0)
	asfalto.set_shader_parameter("piso_tipo", 1)
	var arroyo_z := guarnicion_z - CALLE_ARROYO / 2
	_caja(Vector3(CALLE_LARGO, 0.1, CALLE_ARROYO), Vector3(0, -0.2, arroyo_z), asfalto)
	# Banqueta de enfrente y las casas: fachadas de colores con puerta, ventana y barda
	var enfrente := guarnicion_z - CALLE_ARROYO
	_caja(Vector3(CALLE_LARGO, 0.15, 2.0), Vector3(0, -0.075, enfrente - 1.0), _piso(Color(0.78, 0.78, 0.76)))
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var x := -CALLE_LARGO / 2
	var oscuro := _material(Color(0.12, 0.12, 0.13), 1)
	var fachada_z := enfrente - 2.0
	while x < CALLE_LARGO / 2:
		var frente_casa := rng.randf_range(5.0, 8.0)
		var alto_casa := 3.0 if rng.randf() < 0.6 else 5.8
		var color: Color = CASA_COLORES[rng.randi() % CASA_COLORES.size()]
		var cx := x + frente_casa / 2
		_caja(Vector3(frente_casa, alto_casa, 4.0), Vector3(cx, alto_casa / 2, fachada_z - 2.0), _material(color, 2))
		_caja(Vector3(frente_casa + 0.05, 0.4, 0.05), Vector3(cx, 0.2, fachada_z + 0.02), _material(color.darkened(0.4), 2))
		_caja(Vector3(1.0, 2.1, 0.06), Vector3(cx - frente_casa * 0.25, 1.05, fachada_z + 0.02), oscuro)
		for piso in int(alto_casa / 2.8):
			_caja(Vector3(1.3, 1.1, 0.06), Vector3(cx + frente_casa * 0.2, 1.55 + piso * 2.8, fachada_z + 0.02), oscuro)
		x += frente_casa


# Fachada con la ventana enrejada (el mostrador queda en la ventana) y la banqueta
func _fachada() -> void:
	var muro := _material(color_fachada, 2)
	var total := ancho + 2.0
	var lado := (total - ventana_ancho) / 2.0
	var alto_fachada := alto + 0.4
	var z := GROSOR / 2
	for signo in [-1.0, 1.0]:
		_caja(Vector3(lado, alto_fachada, GROSOR), Vector3(signo * (ventana_ancho + lado) / 2, alto_fachada / 2, z), muro)
	_caja(Vector3(ventana_ancho, alto_fachada - ventana_alto, GROSOR), Vector3(0, (alto_fachada + ventana_alto) / 2, z), muro)
	# Guardapolvo pintado abajo, como en las casas
	var guardapolvo := _material(color_fachada.darkened(0.35), 2)
	for signo in [-1.0, 1.0]:
		_caja(Vector3(lado, 0.5, 0.02), Vector3(signo * (ventana_ancho + lado) / 2, 0.25, GROSOR + 0.01), guardapolvo)
	_caja(Vector3(total, GROSOR, BANQUETA), Vector3(0, -GROSOR / 2, GROSOR + BANQUETA / 2), _piso(Color(0.8, 0.8, 0.78)))
	# Nombre pintado arriba de la ventana
	var letrero := Label3D.new()
	letrero.text = (nombre if nombre != "" else String(name)).to_upper()
	letrero.pixel_size = 0.004
	# Que quepa en un poco mas que la ventana (una letra mide ~0.6 de su tamano)
	letrero.font_size = clampi(int((ventana_ancho + 1.2) / letrero.pixel_size / (0.62 * maxi(letrero.text.length(), 1))), 24, 64)
	letrero.outline_size = 0
	letrero.modulate = color_fachada.darkened(0.7)
	letrero.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	letrero.shaded = true
	letrero.position = Vector3(0, ventana_alto + 0.3, GROSOR + 0.01)
	_local.add_child(letrero)
	# Reja: barrotes cada BARROTE_PASO desde `reja_desde`, travesano abajo y arriba (uno a
	# media altura le cruzaba la cara al que atiende)
	if not barrotes:
		return
	var fierro := _material(color_reja, 1)
	var z_reja := GROSOR + 0.03
	var barrotes := int(ventana_ancho / BARROTE_PASO)
	var largo := ventana_alto - reja_desde
	for i in barrotes + 1:
		var x := -ventana_ancho / 2 + ventana_ancho * i / barrotes
		_caja(Vector3(BARROTE, largo, BARROTE), Vector3(x, reja_desde + largo / 2, z_reja), fierro)
	for y in [reja_desde, ventana_alto - 0.02]:
		_caja(Vector3(ventana_ancho, 0.04, 0.03), Vector3(0, y, z_reja), fierro)


# La fachada de la purificadora del mapa (MapPuntos._make_purificadora) con su frente
# en z = GROSOR y el ventanal en x = 0, y la banqueta
func _fachada_mapa() -> void:
	var mapa := MapPuntos.new()
	# El frente del lote queda en fondo / 2
	var punto := {"tipo": "purificadora", "nombre": nombre if nombre != "" else String(name), "ancho": fachada_mapa_ancho, "fondo": 1.0}
	var fachada := mapa._make_purificadora(punto, true)
	mapa.free()
	fachada.position = Vector3(-punto["puerta_x"], 0.0, GROSOR - 0.5)
	_local.add_child(fachada)
	var total := fachada_mapa_ancho + 2.0
	_caja(Vector3(total, GROSOR, BANQUETA), Vector3(0, -GROSOR / 2, GROSOR + BANQUETA / 2), _piso(Color(0.8, 0.8, 0.78)))


# Material de muro con un cuadro de barda.png (1 aplanado caido, 2 block), repetido en
# el mundo cada `cada` m
func _block(cuadro: int, cada: float) -> StandardMaterial3D:
	var imagen := BARDA_TEXTURA.get_image()
	if imagen.is_compressed():
		imagen.decompress()
	var ancho_cuadro := imagen.get_width() / 3
	var recorte := imagen.get_region(Rect2i(ancho_cuadro * cuadro, 0, ancho_cuadro, imagen.get_height()))
	recorte.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(recorte)
	material.albedo_color = color_muro
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / cada
	return material


# Hollin (manchas negras arriba y en las esquinas, como de fogata) y tags negros, como
# calcomanias (Decal) sobre los muros
func _manchas(largo: float, centro: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semilla, ancho, fondo])
	var hollin := _textura_hollin()
	var tags := []
	for archivo in ResourceLoader.list_directory(GRAFITIS_DIR):
		if archivo.begins_with(GRAFITIS_PREFIJO) and not archivo.ends_with("/"):
			tags.append(load(GRAFITIS_DIR + archivo))
	tags.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.resource_path < b.resource_path)
	# Muros: [centro de la cara, normal hacia el cuarto, direccion a lo largo, largo];
	# la direccion es tal que lo largo x la normal apunta hacia abajo (lo alto del Decal)
	var muros := [
		[Vector3(0, 0, -fondo), Vector3.BACK, Vector3.RIGHT, ancho],
		[Vector3(-ancho / 2, 0, centro), Vector3.RIGHT, Vector3.FORWARD, largo],
		[Vector3(ancho / 2, 0, centro), Vector3.LEFT, Vector3.BACK, largo],
	]
	for i in 7:
		var muro: Array = muros[i % muros.size()]
		var tamano := rng.randf_range(1.2, 2.4)
		var arriba := rng.randf() < 0.7
		_decal(muro, rng.randf_range(-0.4, 0.4) * muro[3], alto - tamano * 0.3 if arriba else rng.randf_range(0.3, 1.0),
			Vector2(tamano * 1.4, tamano), hollin, Color(1, 1, 1, rng.randf_range(0.5, 0.9)))
	if tags.is_empty():
		return
	for i in grafitis:
		var muro: Array = muros[i % muros.size()]
		var tag: Texture2D = tags[rng.randi() % tags.size()]
		var ancho_tag := rng.randf_range(0.6, 1.3)
		var proporcion := float(tag.get_height()) / tag.get_width()
		_decal(muro, rng.randf_range(-0.42, 0.42) * muro[3], rng.randf_range(0.8, 1.9),
			Vector2(ancho_tag, ancho_tag * proporcion), tag, Color(0.08, 0.08, 0.08, rng.randf_range(0.75, 1.0)))


# `muro` = [centro, normal, a lo largo, largo]; `a_lo_largo` corre sobre la cara, `y`
# es la altura. El Decal proyecta hacia su -Y: Y = normal, X = a lo largo, Z = abajo
func _decal(muro: Array, a_lo_largo: float, y: float, tamano: Vector2, textura: Texture2D, color: Color) -> void:
	var decal := Decal.new()
	decal.texture_albedo = textura
	decal.modulate = color
	var normal: Vector3 = muro[1]
	var lado: Vector3 = muro[2]
	decal.basis = Basis(lado, normal, lado.cross(normal))
	# Tamano del Decal: x a lo ancho, y lo que proyecta (pegado al muro), z a lo alto
	decal.size = Vector3(tamano.x, 0.4, tamano.y)
	decal.position = muro[0] + lado * a_lo_largo + Vector3.UP * y + normal * 0.1
	decal.cull_mask = 1
	_local.add_child(decal)


# Mancha negra difusa con borde de ruido
func _textura_hollin() -> ImageTexture:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = 0.05
	var lado := 64
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var d := Vector2(x - lado / 2.0, (y - lado / 2.0) * 1.3).length() / (lado / 2.0)
			var a := clampf((1.0 - d) * 1.6 + ruido.get_noise_2d(x, y) * 0.8, 0.0, 1.0)
			imagen.set_pixel(x, y, Color(0.03, 0.03, 0.03, a * a))
	return ImageTexture.create_from_image(imagen)


# Lamparas de tubo en el techo, una cada ~2.5 m de fondo, con su luz (sin sombra), o
# un foco pelon
func _luces() -> void:
	if foco:
		var bulbo := StandardMaterial3D.new()
		bulbo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bulbo.albedo_color = color_luz
		var pos := Vector3(0.3, alto - 0.5, -fondo * 0.5)
		# Sin sombra: el foco tapaba su propia luz y dejaba un cuadro negro en el techo
		_caja(Vector3(0.01, 0.5, 0.01), pos + Vector3.UP * 0.3, _material(Color(0.1, 0.1, 0.1), 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_caja(Vector3(0.08, 0.11, 0.08), pos, bulbo).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var luz := OmniLight3D.new()
		luz.position = pos + Vector3.DOWN * 0.1
		luz.light_color = color_luz
		luz.light_energy = energia_luz
		luz.omni_range = maxf(ancho, fondo) * 1.5
		luz.omni_attenuation = 1.2
		luz.shadow_enabled = true
		_local.add_child(luz)
		_foco_luz = luz
		_foco_bulbo = bulbo
		return
	var filas := maxi(1, roundi(fondo / 2.5))
	var tubo := StandardMaterial3D.new()
	tubo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tubo.albedo_color = color_luz
	for i in filas:
		var pos := Vector3(0, alto - 0.05, -fondo * (i + 0.5) / filas)
		_caja(Vector3(1.2, 0.06, 0.18), pos, tubo)
		var luz := OmniLight3D.new()
		luz.position = pos + Vector3.DOWN * 0.4
		luz.light_color = color_luz
		luz.light_energy = energia_luz
		luz.omni_range = maxf(ancho, fondo) * 1.3
		luz.omni_attenuation = 0.7
		_local.add_child(luz)
	# Una mas sobre el mostrador, para que se le vea la cara al que atiende
	if luz_mostrador:
		var frente_luz := OmniLight3D.new()
		frente_luz.position = Vector3(0, alto - 0.3, -0.2)
		frente_luz.light_color = color_luz
		frente_luz.light_energy = energia_luz * 0.7
		frente_luz.omni_range = 3.5
		_local.add_child(frente_luz)


func _caja(tamano: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = material
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = pos
	_local.add_child(instancia)
	return instancia


# Deterioro (ps1_combined): 0 nada, 1 uso (techo, rodapie, reja: el `gastado` de los
# muebles, modo 4), 2 muro con pintura caida. El deterioro depende de x/z, y el
# interior se pone en la x/z del negocio, asi que va con la zona
func _material(color: Color, deterioro: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("deterioro_modo", 4 if deterioro == 1 else deterioro)
	material.set_shader_parameter("desgaste", 0.5)
	return material


# Concreto de banqueta en mosaicos de 1 m
func _piso(color: Color) -> ShaderMaterial:
	var piso := ShaderMaterial.new()
	piso.shader = SUELO_SHADER
	piso.set_shader_parameter("albedo_texture", PISO_TEXTURA)
	piso.set_shader_parameter("tint", color)
	piso.set_shader_parameter("tile_size", 1.0)
	piso.set_shader_parameter("piso_tipo", 2)
	return piso


# Corriendo la escena sola: ambiente, su camara y la tienda
func _solo() -> void:
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.55, 0.65, 0.75)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	entorno.environment.ambient_light_energy = 0.35
	# El ajuste de color y el postproceso PS1 de scenes/map_test.tscn, para que sola
	# se vea como en el juego
	entorno.environment.adjustment_enabled = true
	entorno.environment.adjustment_contrast = 1.1
	entorno.environment.adjustment_saturation = 1.35
	add_child(entorno)
	var post := CanvasLayer.new()
	var dither := ColorRect.new()
	dither.set_anchors_preset(Control.PRESET_FULL_RECT)
	dither.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = DITHER_SHADER
	material.set_shader_parameter("color_levels", 32.0)
	material.set_shader_parameter("dither_strenght", 0.35)
	material.set_shader_parameter("desaturacion", 0.4)
	material.set_shader_parameter("tinte", Color(1.0, 0.97, 0.84))
	material.set_shader_parameter("contraste", 1.1)
	material.set_shader_parameter("vineta", 0.3)
	dither.material = material
	post.add_child(dither)
	add_child(post)
	camara().make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	activar()
