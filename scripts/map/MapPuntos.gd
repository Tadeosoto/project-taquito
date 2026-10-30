@tool
class_name MapPuntos
extends Node3D

# Coloca las tiendas y puestos del mapa (OXXO, farmacias, taquerias...).
# Las posiciones vienen de resources/map/puntos_mapa.json, que genera
# tools/map_import/prepare_osm.py a partir de data/map/puntos.json.
# Si un tipo tiene modelo en `prefabs` se usa ese, con sus proporciones y el frente
# de `prefab_ancho` (girado con `prefab_rotacion` si su fachada no ve a +Z; modelos:
# tools/map_import/fetch_sketchfab.py); puede encimarse en las casas vecinas;
# los tipos de GIROS_LOCAL salen como una casa-local de la hilera, pintada con los
# colores de su giro y con la cortina abierta, y adentro su escena de interior; lo
# demas, como una caja de color del tamano del lote.
# En el editor se ven todas; en el juego solo existen las que estan a menos de
# load_radius del jugador (target_path), igual que los cuadros de MapStreamer.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

const PLACEHOLDER_HEIGHT := 3.5

# Mas alla de esto (m) los modelos de tiendas no se dibujan (el mapa usa ~340 m)
const PREFAB_VISIBILITY_RANGE := 250.0
# _calentar: cuadros que se dibuja la miniatura y su escala
const CALENTAR_CUADROS := 3
const CALENTAR_ESCALA := 0.002

# Colores de las cajas mientras no hay modelo
const TIPO_COLORS := {
	"oxxo": Color(0.85, 0.15, 0.12),
	"abarrotes": Color(0.95, 0.9, 0.75),
	"licoreria": Color(0.08, 0.2, 0.55),
	"farmacia": Color(0.2, 0.45, 0.85),
	"taqueria": Color(0.95, 0.55, 0.15),
	"puesto_tacos": Color(0.98, 0.8, 0.2),
	"gasolinera": Color(0.15, 0.6, 0.3),
	"puesto": Color(0.75, 0.35, 0.6),
	"ferreteria": Color(0.9, 0.45, 0.1),
	"purificadora": Color(0.2, 0.6, 0.9),
}

# Casas-local de la hilera, armadas con cajas como las tienditas de barrio: muro del
# color del giro con rodapie y franja (`acento`), la puerta con su marco (`marco`, si
# no del acento) y la cortina enrollada, y adentro la escena del interior de su giro
# (`interior`, la de Interiores.escenas) para que desde la calle se vea el mostrador
# con el que atiende. Sin letreros con el nombre: `letrero` solo es el nombre del giro
# al entrar si el negocio no tiene; `banda`: franja de color en la fachada; `cruz`:
# letrero de bandera de farmacia; `botarga`: el Simi bailando en la banqueta;
# `guardapolvo`: el de las paredes de adentro, si no es el de la escena del interior;
# `relleno`: con que muebles (RELLENO) se llenan las paredes que la escena deja vacias.
const LOCAL_BLANCO := Color(0.93, 0.92, 0.88)
const ROJO := Color(0.72, 0.1, 0.09)
const AZUL_CERVEZA := Color(0.08, 0.2, 0.55)
const AMARILLO := Color(0.96, 0.76, 0.12)
const AZUL_FARMACIA := Color(0.1, 0.3, 0.72)
const NARANJA := Color(0.93, 0.45, 0.07)
const NEGRO := Color(0.09, 0.09, 0.09)
const GIROS_LOCAL := {
	"abarrotes": {"muro": LOCAL_BLANCO, "acento": ROJO, "letrero": "ABARROTES", "interior": "abarrotes", "relleno": "comida"},
	"licoreria": {"muro": AZUL_CERVEZA, "acento": AMARILLO, "letrero": "CERVEZA • VINOS • LICORES", "interior": "licoreria", "relleno": "licor",
		"guardapolvo": AZUL_CERVEZA},
	"farmacia": {"muro": LOCAL_BLANCO, "acento": AZUL_FARMACIA, "letrero": "FARMACIA", "interior": "farmacia", "relleno": "medicinas",
		"cruz": true, "botarga": true},
	"ferreteria": {"muro": NARANJA, "acento": NEGRO, "letrero": "FERRETERÍA Y TLAPALERÍA", "interior": "ferreteria"},
	"oxxo": {"muro": LOCAL_BLANCO, "acento": ROJO, "banda": ROJO, "letrero": "OXO", "interior": "oxxo"},
	"taqueria": {"muro": LOCAL_BLANCO, "acento": ROJO, "letrero": "", "interior": ""},
}
const RODAPIE := 0.9
# Alturas (m) para quedar como las casas Urbi de 1 y 2 pisos (3.9 y 7.4 m con el pretil)
const PLANTA_BAJA := 3.2
const PISO_ALTO := 3.0
const PRETIL := 0.4
const VANO_ALTO := 2.4
const LETRERO_ALTO := 1.15   # con 2 pisos, franja de la losa a las ventanas
const LOCAL_PILAR := 0.35     # muro minimo a cada lado del cuarto
const LOCAL_SALA_MAX := 5.0   # ancho maximo del cuarto
const LOCAL_MURO := 0.3       # grueso de la fachada
# La puerta: fraccion del ancho del cuarto, entre estos anchos (m)
const LOCAL_PUERTA_FRACCION := 0.6
const LOCAL_PUERTA := Vector2(2.2, 3.0)
const LOCAL_MARCO := Vector2(0.16, 0.04)   # ancho del marco y lo que sale del muro
const LOCAL_CUARTO := 4.5     # fondo maximo del cuarto que se ve desde la calle
# Tamano minimo de un local (m): en lotes angostos se sale a los lados y hacia atras
const LOCAL_MIN := Vector2(4.5, 6.0)
# Purificadora (foto del usuario): anuncio sobre postes en la banqueta
const PURIFICADORA_LONA := preload("res://textures/map/purificadora_lona.png")
const PURIFICADORA_POSTES := 1.5   # de la fachada a los postes (orilla de la banqueta)
const PURIFICADORA_ANUNCIO := Vector2(2.9, 1.7)   # altura de abajo y alto del anuncio
const PURIFICADORA_AZUL := Color(0.1, 0.4, 0.8)
const PURIFICADORA_ALTO := 3.2
# Taqueria (como scenes/interiores/taqueria.tscn vista desde la calle): mesas y refris
# rojos adentro y el puesto con el taquero en la banqueta
const TAQUERIA_MESA := Color(0.88, 0.07, 0.05)
const TAQUERIA_PUESTO := 1.3   # de la fachada al centro del puesto (m)
# Muebles para rellenar las paredes del cuarto que la escena del interior deja vacias
# (sobre todo entre la fachada y el mostrador), por `relleno` de GIROS_LOCAL (solo
# abarrotes, licoreria y farmacia): refris, anaqueles con comida o medicinas y
# exhibidores de papitas. [tipo, ancho, fondo]
const RELLENO := {
	"comida": [["refri", 0.8, 0.65], ["repisas_comida", 1.2, 0.4], ["papas", 0.8, 0.42]],
	"licor": [["refri_cerveza", 0.8, 0.65], ["papas", 0.8, 0.42], ["repisas_botanas", 1.2, 0.4]],
	"medicinas": [["repisas_medicinas", 1.2, 0.38]],
}
const RELLENO_FRANJA := 0.75   # que tanto entra de la pared un mueble de la escena para contar
const PUESTO_TACOS := Vector2(2.1, 0.7)   # frente y fondo del carrito del puesto de tacos (m)
const PUESTO_DETALLE := 150.0  # el puesto de tacos suelto se ve desde mas lejos
# Maquinita de frutas (Maquinita.gd): que giros la pueden traer y su centro desde la orilla de la puerta
const MAQUINITA_GIROS := ["abarrotes", "licoreria"]
const MAQUINITA_PUERTA := 0.6
# El interior de los locales solo se ve por la puerta de cerca: se arma a menos de
# INTERIOR_CARGA m, se dibuja a menos de INTERIOR_VISTA y se quita a mas de INTERIOR_QUITAR
const INTERIOR_VISTA := 30.0
const INTERIOR_CARGA := 35.0
const INTERIOR_QUITAR := 50.0

# Marcador de los negocios interactivos (docs/especificaciones.md 4.6): flecha
# amarilla frente a la puerta; al pisarla se entra al interior (scripts/interiores/Interiores.gd)
const MARCADOR_COLOR := Color(1.0, 0.85, 0.1)
const MARCADOR_RADIO := 0.8
const MARCADOR_FRENTE := 0.8   # que tanto sale de la fachada (m)
# Solo aparece de cerca: se desvanece entre estas distancias (m)
const MARCADOR_VISTA := 18.0
const MARCADOR_VISTA_FADE := 6.0
# Y con la camara encima tampoco (al salir de un interior queda pegada a la flecha)
const MARCADOR_CERCA := 2.0
# Lo que dice el que atiende un puesto al aire libre, por giro
const VENDEDOR_DIALOGO := {
	"puesto_tacos": "¿De qué van a ser, joven? (Menú: próximamente)",
	"tejuino": "¿Un tejuino bien frío? (Menú: próximamente)",
}
const MARCADOR_ALFA := 0.6

# `marcador`: el Area3D de la flecha (su +Z apunta a la calle), para volver a ponerte
# ahi; en los puestos al aire libre trae de hijo al `Vendedor` que atiende
signal entrar_negocio(tipo: String, giro: String, nombre: String, aire_libre: bool, marcador: Node3D)

@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"

# tipo -> escena del modelo (ej. "oxxo" -> res://models/oxxo.glb)
@export var prefabs: Dictionary[String, PackedScene] = {}

# tipo -> grados extra para que la fachada del modelo vea a +Z
@export var prefab_rotacion: Dictionary[String, float] = {}

# tipo -> metros de frente del modelo. Se escala parejo, sin deformarlo, aunque
# se salga del lote (los lotes de Google a veces son tiras angostas y apachurraban
# los modelos). Sin valor, el frente es el ancho del lote.
@export var prefab_ancho: Dictionary[String, float] = {}

# tipo -> nombres de nodos del modelo que se quitan antes de medirlo y ponerlo (ej. la
# losa de concreto del kiosco de Similares, que lo hacia ver chico y hundido)
@export var prefab_quitar: Dictionary[String, PackedStringArray] = {}

# tipo -> {nodo del modelo: corrimiento en m (x a la derecha, z hacia la calle)},
# aplicado despues de medir y escalar el modelo (ej. el Simi que bailaba sobre la flecha)
@export var prefab_mover: Dictionary[String, Dictionary] = {}

# tipo -> corrimiento (m) de la puerta a la derecha del centro de la fachada
@export var prefab_puerta: Dictionary[String, float] = {}

# El que atiende en los puestos al aire libre (puesto de tacos, tejuino), parado
# detras del puesto viendo a la calle; por ahora scenes/npc.tscn
@export var vendedor_escena: PackedScene
# tipo -> que tanto atras de la flecha se para (m): detras del carrito, dentro del
# puesto de tacos. Solo los tipos que estan aqui llevan vendedor (el punto te mete a
# su cuarto, scenes/interiores/punto.tscn)
@export var vendedor_atras: Dictionary[String, float] = {}

# El nodo Interiores (scripts/interiores/Interiores.gd): de su `escenas` sale lo que
# se ve adentro de cada local por la cortina abierta
@export var interiores_path: NodePath
# La botarga del Simi que baila afuera de las farmacias
@export var botarga: PackedScene
@export var botarga_escala := 1.0
# giro -> escena del interior (de interiores_path, o puesta a mano antes de _ready)
var escenas_interior: Dictionary = {}

# El jugador; sin el se crean todas las tiendas de una vez
@export var target_path: NodePath
@export var load_radius := 250.0
@export var unload_radius := 320.0

var _puntos := []
var _nodes := {}           # indice en _puntos -> Node3D
var _por_crear := []       # indices en _puntos que faltan armar, el mas cercano primero
var _box_materials := {}   # tipo -> ShaderMaterial de las cajas
var _sucios := {}          # material de un prefab -> copia con deterioro
var _target: Node3D
var _timer := 0.0
var _timer_interiores := 0.0
# Materiales StandardMaterial3D compartidos (Refrigerador.gd explica por que)
static var _material_tubo: StandardMaterial3D
static var _material_vidrio: StandardMaterial3D
# Muebles de un interior que faltan de meter al arbol, uno por cuadro: [padre, mueble]
var _pendientes: Array = []
# Locales en miniatura que se dibujan al cargar para compilar sus shaders (_calentar)
var _calentando: Node3D
var _calentar_cuadros := 0
var _aviso: Label
var _aviso_tween: Tween


func _ready() -> void:
	# Los hijos se generan cada vez y no se guardan en la escena (no tienen owner)
	for child in get_children():
		child.queue_free()

	var text := FileAccess.get_file_as_string(puntos_path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_warning("MapPuntos: no se pudo leer %s" % puntos_path)
		return
	_puntos = data.get("puntos", [])
	var interiores := get_node_or_null(interiores_path)
	if interiores:
		escenas_interior = interiores.get("escenas")

	if not Engine.is_editor_hint():
		_target = get_node_or_null(target_path) as Node3D
		if _target:
			_calentar()
	_update_nearby()
	_crear_pendientes(true)


# Lo que la primera vez tarda mucho, en la carga y no al llegar al primer local: las
# piezas de mercancia (~100 ms de disco) y un refri, que deja compilados sus materiales
# compartidos (~25 ms). Ademas se arma un local de cada giro con su interior (y un puesto
# de tacos y una purificadora) en miniatura frente a la camara durante unos cuadros:
# la primera vez que se dibuja cada material se compila su shader y la primera vez que
# se instancia cada escena de interior se carga, y eso trababa 25-60 ms el cuadro en
# que aparecia el primer local de cada giro.
func _calentar() -> void:
	Mostrador.piezas("")
	var refri := Refrigerador.new()
	refri.visible = false
	add_child(refri)
	refri.queue_free()

	_calentando = Node3D.new()
	_calentando.name = "Calentando"
	add_child(_calentando)
	var x := 0.0
	for tipo: String in GIROS_LOCAL.keys() + ["puesto_tacos", "purificadora"]:
		var punto := {"tipo": tipo, "nombre": "", "x": 0.0, "z": 0.0, "rotacion_y": 0.0,
			"ancho": 6.0, "fondo": 8.0, "pisos": 2}
		var node := _make_punto(punto)
		node.position.x = x
		x += 8.0
		_calentando.add_child(node)
		if GIROS_LOCAL.has(tipo):
			_armar_interior(node, punto, true)
	# Las chispas de los cohetes, para no trabar el cuadro del primer premio
	_calentando.add_child(Cohetes.chispas(4, 1.0, Color.WHITE, 1.0))
	_calentar_cuadros = CALENTAR_CUADROS
	_achicar_calentando()


# Las luces de la miniatura alumbraban la calle y el humo (billboard) no se encoge con
# la escala del nodo; tambien a los muebles que van entrando de _pendientes
func _achicar_calentando() -> void:
	for luz: Light3D in _calentando.find_children("*", "Light3D", true, false):
		luz.visible = false
	for humo: CPUParticles3D in _calentando.find_children("*", "CPUParticles3D", true, false):
		if not humo.has_meta("calentando"):
			humo.set_meta("calentando", true)
			humo.local_coords = true
			humo.scale_amount_min *= CALENTAR_ESCALA
			humo.scale_amount_max *= CALENTAR_ESCALA
			humo.restart()


# Pone la miniatura de _calentar frente a la camara hasta que entren todos sus muebles
# pendientes y se dibuje CALENTAR_CUADROS veces; luego la quita
func _seguir_calentando() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara:
		_calentando.global_transform = camara.global_transform \
				* Transform3D(Basis.from_scale(Vector3.ONE * CALENTAR_ESCALA), Vector3(0.0, 0.0, -2.0))
	_achicar_calentando()
	if not _pendientes.is_empty():
		return
	_calentar_cuadros -= 1
	if _calentar_cuadros <= 0:
		_calentando.queue_free()
		_calentando = null


func _exit_tree() -> void:
	for pendiente: Array in _pendientes:
		(pendiente[1] as Node).free()
	_pendientes.clear()


func _process(delta: float) -> void:
	if _target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_nearby()
	_crear_pendientes()
	_meter_pendiente()
	if _calentando:
		_seguir_calentando()
	# Los interiores mas seguido (uno cada vez): a pie se llega rapido a INTERIOR_VISTA
	_timer_interiores -= delta
	if _timer_interiores <= 0.0 and not Engine.is_editor_hint():
		_timer_interiores = 0.15
		_interiores_cerca()


func _update_nearby() -> void:
	var nuevos := []
	for i in _puntos.size():
		var punto: Dictionary = _puntos[i]
		var distance := 0.0
		if _target:
			distance = Vector2(_target.global_position.x - punto["x"], _target.global_position.z - punto["z"]).length()
		if distance < load_radius and not _nodes.has(i):
			nuevos.append([distance, i])
		elif distance > unload_radius and _nodes.has(i):
			_nodes[i].queue_free()
			_nodes.erase(i)
	nuevos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_por_crear = nuevos.map(func(n: Array) -> int: return n[1])


# Arma los puntos encolados hasta gastar el presupuesto del cuadro (CargaCuadro; todos con `de_una`)
func _crear_pendientes(de_una := false) -> void:
	while not _por_crear.is_empty() and (de_una or CargaCuadro.hay()):
		var inicio := Time.get_ticks_usec()
		var i: int = _por_crear.pop_front()
		if _nodes.has(i):
			continue
		var punto: Dictionary = _puntos[i]
		var node := _make_punto(punto)
		node.position = Vector3(punto["x"], 0.0, punto["z"])
		node.rotation.y = punto["rotacion_y"]
		add_child(node)
		_nodes[i] = node
		CargaCuadro.gastar(inicio)


func _make_punto(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var node: Node3D
	if tipo == "punto":
		# La casa ya la dibuja MapCasas; aqui solo va su marcador
		node = Node3D.new()
		node.name = "punto_%s" % punto.get("origen", "")
	elif GIROS_LOCAL.has(tipo):
		node = _make_local_giro(punto)
	elif tipo == "puesto_tacos":
		node = _make_puesto_tacos(punto)
	elif prefabs.has(tipo) and prefabs[tipo] != null:
		node = _make_prefab(punto)
	elif tipo == "purificadora":
		node = _make_purificadora(punto)
	else:
		node = _make_placeholder(punto)
	if punto.get("interactivo", false) and not Engine.is_editor_hint():
		node.add_child(_marcador(punto))
	return node


# Flecha amarilla semitransparente que gira y flota frente a la puerta (solo se ve de
# cerca), y un Area3D que avisa al pisarla
func _marcador(punto: Dictionary) -> Node3D:
	var area := Area3D.new()
	area.name = "Marcador"
	# `puerta_x`: el local armado dice donde esta su puerta (la ventanilla de la purificadora)
	area.position = Vector3(punto.get("puerta_x", prefab_puerta.get(punto["tipo"], 0.0)), 0.0, punto["fondo"] / 2.0 + MARCADOR_FRENTE)
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MARCADOR_RADIO
	cilindro.height = 2.0
	shape.shape = cilindro
	shape.position.y = 1.0
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_entrar(punto, area))
	if punto.get("aire_libre", false) and vendedor_escena and (punto.has("vendedor_atras") or vendedor_atras.has(punto["tipo"])):
		area.add_child(_vendedor(punto))
	area.add_child(flecha())
	return area


static var _flecha_cache: Mesh

# Flecha que flota y gira
static func flecha() -> MeshInstance3D:
	if _flecha_cache == null:
		_flecha_cache = _flecha_mesh()
	var malla := MeshInstance3D.new()
	malla.mesh = _flecha_cache
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	malla.visibility_range_end = MARCADOR_VISTA
	malla.visibility_range_end_margin = MARCADOR_VISTA_FADE
	malla.visibility_range_begin = MARCADOR_CERCA
	malla.visibility_range_begin_margin = 0.5
	malla.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# El tween se crea ya en el arbol (se libera con la flecha)
	malla.ready.connect(func() -> void:
		var tween := malla.create_tween().set_loops()
		tween.tween_property(malla, "position:y", 0.25, 0.8).from(0.0).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(malla, "rotation:y", PI, 0.8).from(0.0)
		tween.tween_property(malla, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(malla, "rotation:y", TAU, 0.8), CONNECT_ONE_SHOT)
	return malla


# Flecha hacia abajo (cono y palo) a ~1.3 m del piso, amarilla y sin sombra para que
# se vea igual de noche
static func _flecha_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(MARCADOR_COLOR, MARCADOR_ALFA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var punta := CylinderMesh.new()
	punta.top_radius = 0.35
	punta.bottom_radius = 0.0
	punta.height = 0.5
	punta.radial_segments = 6
	punta.rings = 1
	var palo := CylinderMesh.new()
	palo.top_radius = 0.13
	palo.bottom_radius = 0.13
	palo.height = 0.5
	palo.radial_segments = 6
	palo.rings = 1
	var tools := SurfaceTool.new()
	tools.begin(Mesh.PRIMITIVE_TRIANGLES)
	tools.append_from(punta, 0, Transform3D(Basis(), Vector3(0.0, 1.3, 0.0)))
	tools.append_from(palo, 0, Transform3D(Basis(), Vector3(0.0, 1.8, 0.0)))
	var mesh := tools.commit()
	mesh.surface_set_material(0, material)
	return mesh


# Viendo a la calle (+Z del marcador; el npc ve a su -Z), sin su area de platica: se le
# habla pisando la flecha, no con el boton de saltar
func _vendedor(punto: Dictionary) -> Node3D:
	var vendedor := vendedor_escena.instantiate() as Node3D
	vendedor.name = "Vendedor"
	vendedor.position = Vector3(0.0, 0.0, -punto.get("vendedor_atras", vendedor_atras.get(punto["tipo"], 1.5)))
	vendedor.rotation.y = PI
	vendedor.set("dialogue", VENDEDOR_DIALOGO.get(punto.get("giro", ""), ""))
	vendedor.ready.connect(func() -> void:
		(vendedor.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
	return vendedor


func _entrar(punto: Dictionary, marcador: Node3D) -> void:
	var nombre: String = punto.get("nombre", "")
	if nombre == "" or nombre.to_upper().contains("SIN NOMBRE"):
		nombre = GIROS_LOCAL.get(punto["tipo"], {}).get("letrero", String(punto.get("giro", "")).capitalize())
	entrar_negocio.emit(punto["tipo"], punto.get("giro", ""), nombre, punto.get("aire_libre", false), marcador)
	# Sin nadie que lo atienda (Interiores) no hay a donde entrar
	if not entrar_negocio.has_connections():
		avisar("%s: Próximamente" % nombre)


# Texto abajo al centro que se desvanece solo
func avisar(texto: String) -> void:
	if _aviso == null:
		var capa := CanvasLayer.new()
		capa.layer = 3
		add_child(capa)
		_aviso = Label.new()
		_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_aviso.offset_bottom = -60.0
		_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_aviso.add_theme_color_override("font_color", MARCADOR_COLOR)
		_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
		_aviso.add_theme_constant_override("outline_size", 6)
		capa.add_child(_aviso)
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _aviso_tween:
		_aviso_tween.kill()
	_aviso_tween = create_tween()
	_aviso_tween.tween_interval(1.5)
	_aviso_tween.tween_property(_aviso, "modulate:a", 0.0, 1.0)


# Frente y fondo (m) que ocupa el modelo de `tipo` ya escalado (Vector2.ZERO si no
# tiene modelo). Lo usa tools/map_import/huellas_tiendas.gd para que prepare_osm.py
# quite las casas que quedan debajo del negocio.
func huella_modelo(tipo: String) -> Vector2:
	if not prefabs.has(tipo) or prefabs[tipo] == null or not prefab_ancho.has(tipo):
		return Vector2.ZERO
	var model := _instanciar(tipo)
	var aabb := _mesh_aabb(model, model.transform)
	model.free()
	if aabb.size.x <= 0.01:
		return Vector2.ZERO
	var fit: float = prefab_ancho[tipo] / aabb.size.x
	return Vector2(aabb.size.x, aabb.size.z) * fit


# El modelo de `tipo` girado prefab_rotacion[tipo] grados y sin los nodos de prefab_quitar
func _instanciar(tipo: String) -> Node3D:
	var model := prefabs[tipo].instantiate() as Node3D
	model.rotation.y = deg_to_rad(prefab_rotacion.get(tipo, 0.0))
	for nombre in prefab_quitar.get(tipo, PackedStringArray()):
		var nodo := model.find_child(nombre, true, false)
		if nodo:
			nodo.get_parent().remove_child(nodo)
			nodo.free()
	return model


# El modelo se gira prefab_rotacion[tipo] grados (para que su fachada vea a +Z),
# se escala parejo a prefab_ancho[tipo] metros de frente y se apoya en el piso con
# la fachada en la orilla del lote que da a la calle; crece hacia atras.
func _make_prefab(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var holder := Node3D.new()
	holder.name = "%s_%s" % [tipo, punto.get("nombre", "")]

	var model := _instanciar(tipo)
	holder.add_child(model)
	if not Engine.is_editor_hint():
		_animar(model)

	var aabb := _mesh_aabb(model, model.transform)
	if aabb.size.x > 0.01 and aabb.size.z > 0.01:
		var fit: float = prefab_ancho.get(tipo, punto["ancho"]) / aabb.size.x
		var front: float = punto["fondo"] / 2.0
		model.scale *= fit
		model.position = Vector3(-aabb.get_center().x * fit, -aabb.position.y * fit, front - aabb.end.z * fit)
		for nombre in prefab_mover.get(tipo, {}):
			var nodo := model.find_child(nombre, true, false) as Node3D
			if nodo:
				# Del espacio del negocio al del padre del nodo
				var xform := Transform3D()
				var n: Node = nodo.get_parent()
				while n != holder:
					if n is Node3D:
						xform = (n as Node3D).transform * xform
					n = n.get_parent()
				nodo.position += xform.basis.inverse() * Vector3(prefab_mover[tipo][nombre])
		_set_far_mesh_options(model)

		# Colision de caja del tamano del modelo (las mallas de Sketchfab no traen)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = aabb.size * fit
		shape.shape = box_shape
		shape.position = Vector3(0.0, box_shape.size.y / 2.0, front - box_shape.size.z / 2.0)
		body.add_child(shape)
		holder.add_child(body)
	return holder


# Los modelos animados (el Simi del kiosco de Similares) bailan en loop
func _animar(node: Node) -> void:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		var lista := player.get_animation_list()
		if not lista.is_empty():
			player.get_animation(lista[0]).loop_mode = Animation.LOOP_LINEAR
			player.play.call_deferred(lista[0])
		return
	for child in node.get_children():
		_animar(child)


# Igual que los cuadros del mapa (MapPostImport): sin sombras y ocultos de lejos.
# Tambien les pone la mugre de la zona (ps1_deterioro) a sus materiales PS1.
func _set_far_mesh_options(node: Node) -> void:
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = PREFAB_VISIBILITY_RANGE
		var instance := node as MeshInstance3D
		if instance.mesh:
			for surface in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface) as ShaderMaterial
				if material == null or material.shader != PS1_SHADER:
					continue
				if not _sucios.has(material):
					var sucio := material.duplicate() as ShaderMaterial
					sucio.set_shader_parameter("deterioro_modo", 1)
					_sucios[material] = sucio
				instance.set_surface_override_material(surface, _sucios[material])
	for child in node.get_children():
		_set_far_mesh_options(child)


# AABB de todas las mallas de `node`, en el espacio de su padre
func _mesh_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D and node.mesh:
		result = xform * node.mesh.get_aabb()
		first = false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_aabb := _mesh_aabb(child, xform * (child as Node3D).transform)
		if child_aabb.size == Vector3.ZERO:
			continue
		result = child_aabb if first else result.merge(child_aabb)
		first = false
	return result


func _make_placeholder(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var size := Vector3(punto["ancho"], PLACEHOLDER_HEIGHT, punto["fondo"])
	if tipo.begins_with("puesto"):
		size.y = 2.2

	var body := StaticBody3D.new()
	body.name = "%s_%s" % [tipo, punto.get("nombre", "")]

	var box := BoxMesh.new()
	box.size = size
	if not _box_materials.has(tipo):
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter("tint", TIPO_COLORS.get(tipo, Color(0.6, 0.6, 0.6)))
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("deterioro_modo", 2)
		_box_materials[tipo] = material
	box.material = _box_materials[tipo]

	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	mesh.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position.y = size.y / 2.0
	body.add_child(shape)

	# Letrero sobre la fachada (+Z)
	var label := Label3D.new()
	label.text = punto.get("nombre", "") if punto.get("nombre", "") != "" else tipo
	label.position = Vector3(0.0, size.y + 0.6, size.z / 2.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# De lejos los letreros nomas ensucian (y cuestan)
	label.visibility_range_end = 80.0
	label.pixel_size = 0.01
	label.font_size = 64
	label.outline_size = 12
	body.add_child(label)
	return body


# Casa-local de la hilera (docs/mapa): del tamano del lote (minimo LOCAL_MIN), de 1 o
# 2 pisos (`punto["pisos"]`, como las casas vecinas), con el muro del color de su
# giro (GIROS_LOCAL) y su rodapie y franja. Como los locales de verdad, la entrada no
# abarca todo el frente: es un vano con marco (jambas y cabezal, sin umbral) en medio
# de la fachada, con la cortina enrollada arriba por dentro, y adentro, en un cuarto
# mas ancho que el vano y de hasta LOCAL_CUARTO m, la escena del interior de su giro
# (mostrador, el que atiende y los muebles de atras). La taqueria trae en cambio sus
# mesas y el puesto en la banqueta. Sin letreros con el nombre. La fachada ve a +Z,
# en la orilla del lote; la flecha va frente al vano (o donde diga `puerta_x`).
func _make_local_giro(punto: Dictionary) -> Node3D:
	var tipo: String = punto["tipo"]
	var info: Dictionary = GIROS_LOCAL[tipo]
	var nombre: String = punto.get("nombre", "")
	var m := _medidas(punto)
	var w: float = m["w"]
	var d: float = m["d"]
	var front: float = m["front"]
	var pisos: int = m["pisos"]
	var alto: float = m["alto"]
	var sala: float = m["sala"]
	var pilar := (w - sala) / 2.0
	var puerta: float = m["puerta"]
	var cuarto: float = m["cuarto"]
	var muro: Color = info["muro"]
	var acento: Color = info["acento"]
	var body := StaticBody3D.new()
	body.name = "%s_%s" % [tipo, nombre]

	# Lo de atras del cuarto, macizo; los muros de los lados a todo el fondo del cuarto;
	# la fachada a los lados de la puerta y arriba de ella el dintel (con 1 piso, hasta
	# el pretil) o el piso de arriba
	var atras := d - cuarto
	_fachada_tramo(body, Vector2(-w / 2.0, w / 2.0), 0.0, alto, front - cuarto - atras / 2.0, atras, acento, muro)
	for lado in [-1.0, 1.0]:
		var x: float = lado * (sala + pilar) / 2.0
		_fachada_tramo(body, Vector2(x - pilar / 2.0, x + pilar / 2.0), 0.0, alto, front - cuarto / 2.0, cuarto, acento, muro)
	var dintel_arriba := alto if pisos == 1 else PLANTA_BAJA
	var z := front - LOCAL_MURO / 2.0
	for lado in [-1.0, 1.0]:
		var tramo: Vector2 = Vector2(puerta / 2.0, sala / 2.0) * lado
		_fachada_tramo(body, Vector2(minf(tramo.x, tramo.y), maxf(tramo.x, tramo.y)), 0.0, dintel_arriba, z, LOCAL_MURO, acento, muro)
	_fachada_tramo(body, Vector2(-puerta / 2.0, puerta / 2.0), VANO_ALTO, dintel_arriba, z, LOCAL_MURO, acento, muro)
	_marco(body, puerta, z, info.get("marco", acento))
	if pisos > 1:
		_piso_alto(body, w, sala, cuarto, front, alto, muro, acento)
	# Techo y piso del cuarto, tubo de luz y la cortina enrollada (por dentro, arriba
	# de la puerta)
	_local_box(body, Vector3(sala, 0.2, cuarto), Vector3(0.0, PLANTA_BAJA - 0.1, front - cuarto / 2.0), Color(0.85, 0.85, 0.82), false)
	_local_box(body, Vector3(sala, 0.02, cuarto), Vector3(0.0, 0.01, front - cuarto / 2.0), Color(0.6, 0.55, 0.5), false)
	var tubo := _local_box(body, Vector3(1.2, 0.05, 0.15), Vector3(0.0, PLANTA_BAJA - 0.23, front - cuarto * 0.5), Color(1.0, 1.0, 0.95), false)
	if _material_tubo == null:
		_material_tubo = StandardMaterial3D.new()
		_material_tubo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_tubo.albedo_color = Color(0.95, 0.97, 1.0)
	tubo.material_override = _material_tubo
	_local_box(body, Vector3(puerta + 0.1, 0.25, 0.25), Vector3(0.0, VANO_ALTO - 0.13, front - LOCAL_MURO - 0.13), Color(0.55, 0.57, 0.6), false)
	# Franja de color sin letras (OXO)
	if info.has("banda"):
		var abajo := VANO_ALTO + 0.3 if pisos == 1 else PLANTA_BAJA + 0.15
		var arriba := dintel_arriba - 0.1 if pisos == 1 else PLANTA_BAJA + 0.75
		_local_box(body, Vector3(w + 0.02, arriba - abajo, 0.03), Vector3(0.0, (abajo + arriba) / 2.0, front + 0.01), info["banda"], false)
	if info.get("cruz", false):
		_cruz_bandera(body, w, front, dintel_arriba, acento)

	# Lo de la banqueta y lo de adentro solo en el juego (en el editor estan todos los
	# negocios a la vez). Lo de la banqueta (el puesto de la taqueria, la botarga) se ve
	# de lejos; el interior solo se arma de cerca (_interiores_cerca) o, sin objetivo
	# que seguir, de una vez
	if Engine.is_editor_hint():
		return body
	var banqueta := Node3D.new()
	banqueta.name = "Banqueta"
	body.add_child(banqueta)
	if tipo == "taqueria":
		_taqueria_puesto(body, banqueta, punto, sala, puerta, front)
	if info.get("botarga", false) and botarga:
		# Junto al pilar izquierdo, bailando, lejos de la flecha
		var simi := botarga.instantiate() as Node3D
		simi.name = "Botarga"
		simi.scale = Vector3.ONE * botarga_escala
		simi.position = Vector3(-w / 2.0 + 0.45, 0.0, front + 0.9)
		banqueta.add_child(simi)
	_maquinita(banqueta, punto, w, puerta, front)
	# Los muebles se arman al entrar al arbol: hasta entonces no tienen mallas. En el
	# juego entran de uno por cuadro, como los del interior
	if _target:
		_sacar_muebles(banqueta, PUESTO_DETALLE)
	banqueta.ready.connect(func() -> void:
		_detalle_lejos(banqueta, PUESTO_DETALLE)
		sin_textos(banqueta)
		_animar(banqueta), CONNECT_ONE_SHOT)
	if _target == null:
		_armar_interior(body, punto, true)
	return body


# La maquinita de frutas afuera de la mitad de las tienditas: a un lado de la puerta, de
# espaldas a la fachada, si cabe. Cual tienda y de que lado sale de su `origen`.
func _maquinita(banqueta: Node3D, punto: Dictionary, w: float, puerta: float, front: float) -> void:
	if not punto["tipo"] in MAQUINITA_GIROS:
		return
	var origen: String = punto.get("origen", "")
	var tiro := absi(hash(origen))
	# Sin origen es el de _calentar o locales_preview: siempre
	if origen != "" and tiro % 2 == 0:
		return
	var x := puerta / 2.0 + MAQUINITA_PUERTA
	if x + Maquinita.ANCHO / 2.0 > w / 2.0:
		return
	var maquina := Maquinita.new()
	maquina.name = "Maquinita"
	maquina.id = origen
	maquina.position = Vector3(x if tiro % 4 < 2 else -x, 0.0, front + Maquinita.FONDO / 2.0 + 0.02)
	banqueta.add_child(maquina)


# Medidas de una casa-local: frente `w` y fondo `d` (minimo LOCAL_MIN), `front` (la
# fachada), `pisos` y `alto` hasta el pretil, el cuarto (`sala` de ancho entre los
# muros de los lados, `cuarto` de fondo) y la `puerta`, mas angosta, en medio
static func _medidas(punto: Dictionary) -> Dictionary:
	var w: float = maxf(punto["ancho"], LOCAL_MIN.x)
	var d: float = maxf(punto["fondo"], LOCAL_MIN.y)
	var pisos := clampi(int(punto.get("pisos", 1)), 1, 2)
	var sala := minf(w - 2.0 * LOCAL_PILAR, LOCAL_SALA_MAX)
	return {
		"w": w, "d": d, "front": punto["fondo"] / 2.0, "pisos": pisos,
		"alto": PLANTA_BAJA + (pisos - 1) * PISO_ALTO + PRETIL,
		"sala": sala, "cuarto": minf(d - 0.5, LOCAL_CUARTO),
		"puerta": clampf(sala * LOCAL_PUERTA_FRACCION, LOCAL_PUERTA.x, minf(LOCAL_PUERTA.y, sala - 0.8)),
	}


# Lo de adentro del local (`Detalle`): la escena del interior con su relleno, o las
# mesas y refris de la taqueria. Solo se dibuja a menos de INTERIOR_VISTA m. Cada
# mueble se arma al entrar al arbol (~1 ms cada uno, ~15 ms el cuarto entero), asi que
# en el juego entran de uno por cuadro (_meter_pendiente); `de_una` los mete todos ya
func _armar_interior(body: Node3D, punto: Dictionary, de_una := false) -> void:
	var m := _medidas(punto)
	var detalle := Node3D.new()
	detalle.name = "Detalle"
	if punto["tipo"] == "taqueria":
		_taqueria_cuarto(detalle, punto, m["sala"], m["cuarto"], m["front"])
	else:
		_interior_local(detalle, GIROS_LOCAL[punto["tipo"]], m["sala"], m["cuarto"], m["front"])
	if not de_una:
		_sacar_muebles(detalle)
	detalle.ready.connect(func() -> void:
		_detalle_lejos(detalle)
		sin_textos(detalle), CONNECT_ONE_SHOT)
	body.add_child(detalle)


# Saca de `nodo` los muebles (lo que se arma en _ready: Mostrador y sus hijos,
# Refrigerador, escenas como el vendedor o la botarga) y los forma en _pendientes,
# para dibujarse a menos de `distancia` m
func _sacar_muebles(nodo: Node, distancia := INTERIOR_VISTA) -> void:
	for hijo in nodo.get_children():
		if hijo is Mostrador or hijo is Refrigerador or hijo is Maquinita or hijo.scene_file_path != "":
			nodo.remove_child(hijo)
			_pendientes.append([nodo, hijo, distancia])
		else:
			_sacar_muebles(hijo, distancia)


# Mete al arbol el siguiente mueble pendiente (si su local no se quito mientras)
func _meter_pendiente() -> void:
	while not _pendientes.is_empty():
		var pendiente: Array = _pendientes.pop_front()
		var padre: Node = pendiente[0]
		var mueble: Node = pendiente[1]
		if is_instance_valid(padre) and padre.is_inside_tree() and not padre.is_queued_for_deletion() \
				and not String(padre.get_path()).contains("Detalle_quitado"):
			padre.add_child(mueble)
			_detalle_lejos(mueble, pendiente[2])
			sin_textos(mueble)
			if mueble.name == "Botarga":
				_animar(mueble)
			return
		mueble.free()


# Interiores de los locales: se arma el del local mas cercano a menos de INTERIOR_CARGA
# m (uno por vuelta, para no trabar el juego) y se quitan los que quedan a mas de
# INTERIOR_QUITAR m. Medido en el piso: el objetivo es el Dron, que va a 30 m de alto
# aun siguiendo al jugador; volando no se arma ninguno
func _interiores_cerca() -> void:
	var volando: bool = _target.has_method("volando") and _target.volando()
	var cerca := -1
	var mejor := INTERIOR_CARGA
	var donde := Vector2(_target.global_position.x, _target.global_position.z)
	for i: int in _nodes:
		if not GIROS_LOCAL.has(_puntos[i]["tipo"]):
			continue
		var node: Node3D = _nodes[i]
		var distancia := donde.distance_to(Vector2(node.global_position.x, node.global_position.z))
		var detalle := node.get_node_or_null("Detalle")
		if detalle and distancia > INTERIOR_QUITAR:
			detalle.name = "Detalle_quitado"
			detalle.queue_free()
		elif detalle == null and distancia < mejor:
			mejor = distancia
			cerca = i
	if cerca >= 0 and not volando and _pendientes.is_empty():
		_armar_interior(_nodes[cerca], _puntos[cerca])


# Puesto de tacos en la banqueta, como el de la taqueria: el carrito (Mostrador estilo
# puesto, con toldo, comal, trompo y humo) con los clientes del lado de la calle (+Z)
# y el frente en la orilla del lote, y detras el taquero viendo a la calle. Si el
# puesto es interactivo el taquero es el `Vendedor` del marcador (para el acercamiento,
# `punto["vendedor_atras"]`); si no, va suelto.
func _make_puesto_tacos(punto: Dictionary) -> Node3D:
	var front: float = punto["fondo"] / 2.0
	var body := StaticBody3D.new()
	body.name = "puesto_tacos_%s" % punto.get("nombre", "")
	var puesto := Mostrador.new()
	puesto.estilo = 5
	puesto.parrilla_atras = true
	puesto.ancho = PUESTO_TACOS.x
	puesto.alto = 0.92
	puesto.fondo = PUESTO_TACOS.y
	puesto.color = Color(0.7, 0.1, 0.08)
	puesto.semilla = absi(String(punto.get("nombre", "")).hash())
	puesto.position = Vector3(0.0, 0.0, front - PUESTO_TACOS.y / 2.0)
	body.add_child(puesto)
	var caja := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(PUESTO_TACOS.x, 1.0, PUESTO_TACOS.y)
	caja.shape = forma
	caja.position = puesto.position + Vector3(0.0, 0.5, 0.0)
	body.add_child(caja)
	# Del frente del lote al taquero (m), y de la flecha al taquero
	var atras := PUESTO_TACOS.y + 0.55
	punto["vendedor_atras"] = atras + MARCADOR_FRENTE
	if vendedor_escena and not (punto.get("interactivo", false) and punto.get("aire_libre", false)):
		var taquero := vendedor_escena.instantiate() as Node3D
		taquero.name = "Taquero"
		taquero.position = Vector3(0.0, 0.0, front - atras)
		taquero.rotation.y = PI
		taquero.ready.connect(func() -> void:
			(taquero.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
		body.add_child(taquero)
	if _target:
		_sacar_muebles(body, PUESTO_DETALLE)
	if not Engine.is_editor_hint():
		body.ready.connect(func() -> void:
			_detalle_lejos(body, PUESTO_DETALLE)
			sin_textos(body), CONNECT_ONE_SHOT)
	return body


# Marco de la puerta: dos jambas y el cabezal que salen un poco del muro (sin umbral)
func _marco(body: StaticBody3D, puerta: float, z: float, color: Color) -> void:
	var grueso := LOCAL_MURO + 2.0 * LOCAL_MARCO.y
	for lado in [-1.0, 1.0]:
		_local_box(body, Vector3(LOCAL_MARCO.x, VANO_ALTO + LOCAL_MARCO.x, grueso),
			Vector3(lado * (puerta + LOCAL_MARCO.x) / 2.0, (VANO_ALTO + LOCAL_MARCO.x) / 2.0, z), color, false)
	_local_box(body, Vector3(puerta + 2.0 * LOCAL_MARCO.x, LOCAL_MARCO.x, grueso),
		Vector3(0.0, VANO_ALTO + LOCAL_MARCO.x / 2.0, z), color, false)


# Sin letreros: los Label3D de los muebles (cabeceras, marcas, ofertas) se esconden.
# Tambien lo usan los interiores (Interior.gd)
static func sin_textos(node: Node) -> void:
	if node is Label3D:
		(node as Label3D).visible = false
	for child in node.get_children(true):
		sin_textos(child)


# Segundo piso (casa arriba del local): muro del giro con la franja, losa que sobresale
# y una o dos ventanas con marco de aluminio y reja
func _piso_alto(body: StaticBody3D, w: float, sala: float, cuarto: float, front: float, alto: float, muro: Color, acento: Color) -> void:
	_local_box(body, Vector3(sala, alto - PLANTA_BAJA, cuarto), Vector3(0.0, (PLANTA_BAJA + alto) / 2.0, front - cuarto / 2.0), muro, true)
	_local_box(body, Vector3(w + 0.1, 0.14, 0.4), Vector3(0.0, PLANTA_BAJA, front + 0.05), Color(0.72, 0.71, 0.68), false)
	_local_box(body, Vector3(w + 0.03, 0.12, 0.03), Vector3(0.0, alto - PRETIL - 0.1, front + 0.01), acento, false)
	var ventanas := 2 if w >= 6.5 else 1
	var y := PLANTA_BAJA + LETRERO_ALTO + 0.7
	for i in ventanas:
		var x := 0.0 if ventanas == 1 else (-1.0 if i == 0 else 1.0) * w / 4.0
		_local_box(body, Vector3(1.5, 1.0, 0.04), Vector3(x, y, front + 0.01), Color(0.78, 0.79, 0.8), false)
		_local_box(body, Vector3(1.4, 0.9, 0.04), Vector3(x, y, front + 0.02), Color(0.1, 0.12, 0.14), false)
		_local_box(body, Vector3(0.04, 0.9, 0.04), Vector3(x, y, front + 0.04), Color(0.78, 0.79, 0.8), false)
		for b in 6:
			_local_box(body, Vector3(0.025, 1.0, 0.025), Vector3(x - 0.65 + 1.3 * b / 5.0, y, front + 0.08), NEGRO, false)


# Letrero de bandera de farmacia: cuadro blanco con la cruz de los dos lados, de lado
# a la calle sobre el pilar derecho
func _cruz_bandera(body: StaticBody3D, w: float, front: float, arriba: float, color: Color) -> void:
	var centro := Vector3(w / 2.0 - 0.2, arriba - 0.55, front + 0.55)
	_local_box(body, Vector3(0.05, 0.05, 0.6), centro + Vector3(0.0, 0.42, -0.3), Color(0.3, 0.3, 0.32), false)
	_local_box(body, Vector3(0.06, 0.7, 0.7), centro, LOCAL_BLANCO, false)
	_local_box(body, Vector3(0.08, 0.5, 0.16), centro, color, false)
	_local_box(body, Vector3(0.08, 0.16, 0.5), centro, color, false)


# Lo que se ve por la cortina: de la escena del interior del giro (Interiores.escenas)
# solo el mostrador, el que atiende, los muebles, los refris y el letrero, con la pared
# de atras de la escena en el fondo del cuarto y achicados parejo si el cuarto es mas
# angosto que la escena. Las paredes del cuarto por dentro, del color de la escena.
func _interior_local(detalle: Node3D, info: Dictionary, sala: float, cuarto: float, front: float) -> void:
	var escena: PackedScene = escenas_interior.get(info["interior"])
	if escena == null:
		return
	var interior := escena.instantiate() as Node3D
	var ancho_escena: float = interior.get("ancho")
	var fondo_escena: float = interior.get("fondo")
	var color_muro: Color = interior.get("color_muro")
	var guardapolvo: Color = info.get("guardapolvo", interior.get("color_guardapolvo"))
	var alto_escena: float = interior.get("alto")
	var energia: float = interior.get("energia_luz")
	var color_luz: Color = interior.get("color_luz")
	var luz_mostrador: bool = interior.get("luz_mostrador")
	var cosas := Node3D.new()
	cosas.name = "Interior"
	for parte in ["Mostrador", "Vendedor", "Muebles", "Refrigeradores", "Letrero"]:
		var nodo := interior.get_node_or_null(parte)
		if nodo:
			_sin_dueno(nodo, interior)
			interior.remove_child(nodo)
			cosas.add_child(nodo)
	interior.free()
	_sencillo(cosas)
	var vendedor := cosas.get_node_or_null("Vendedor")
	if vendedor:
		vendedor.ready.connect(func() -> void:
			(vendedor.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
	var escala := minf(1.0, (sala - 0.1) / ancho_escena)
	cosas.scale = Vector3.ONE * escala
	cosas.position = Vector3(0.0, 0.0, front - cuarto + fondo_escena * escala)
	detalle.add_child(cosas)
	if info.has("relleno"):
		_relleno(detalle, cosas, RELLENO[info["relleno"]], sala, cuarto, front)
	# Forro de las paredes por dentro: atras y a los lados, con el guardapolvo
	var adentro := PLANTA_BAJA - 0.2
	var forros := [[Vector3(sala, adentro, 0.02), Vector3(0.0, adentro / 2.0, front - cuarto + 0.01)]]
	for lado in [-1.0, 1.0]:
		forros.append([Vector3(0.02, adentro, cuarto - 0.35), Vector3(lado * (sala / 2.0 - 0.01), adentro / 2.0, front - cuarto / 2.0 - 0.15)])
	for forro: Array in forros:
		var size: Vector3 = forro[0]
		var pos: Vector3 = forro[1]
		var malla := _caja_detalle(size, pos, color_muro, true)
		detalle.add_child(malla)
		if guardapolvo.a > 0.0:
			var franja := Vector3(size.x + (0.01 if size.x < 0.1 else 0.0), 1.1, size.z + (0.01 if size.z < 0.1 else 0.0))
			detalle.add_child(_caja_detalle(franja, Vector3(pos.x, 0.55, pos.z), guardapolvo, false))
	# Las luces de la escena (Interior._luces), sin sombra: los tubos del techo con su
	# energia y, si la escena la trae, la del mostrador (la ferreteria no: su mostrador
	# se ve apagado). Se ve adentro tambien de noche
	var luces: Array = [[Vector3(0.0, alto_escena - 0.45, -fondo_escena * 0.5), energia]]
	if luz_mostrador:
		luces.append([Vector3(0.0, alto_escena - 0.3, -0.2), energia * 0.7])
	for datos: Array in luces:
		var luz := OmniLight3D.new()
		luz.position = cosas.transform * (datos[0] as Vector3)
		luz.omni_range = maxf(ancho_escena, fondo_escena) * 1.3
		luz.omni_attenuation = 0.7
		luz.light_energy = datos[1]
		luz.light_color = color_luz
		luz.shadow_enabled = false
		detalle.add_child(luz)


# Por la puerta el interior solo se ve de cerca y de pasada: la mercancia va en cajas
# con etiqueta (sin las piezas de Comida Low Poly ni adornos chicos) y los refris con sus botellas de
# cilindro (sin caguamas ni Jarritos), que es lo que mas mallas y nodos agregaba
static func _sencillo(nodo: Node) -> void:
	if nodo is Refrigerador:
		nodo.botella_abajo = null
		nodo.botella_arriba = null
	elif nodo is Mostrador:
		nodo.sencillo = true
		nodo.con_modelos = false
	for hijo in nodo.get_children():
		_sencillo(hijo)


# Llena con muebles de `catalogo` las paredes de los lados del cuarto donde no hay
# muebles de la escena (`cosas`): mide lo que ocupa cada mueble de la escena que llega
# a menos de RELLENO_FRANJA m de la pared y pone, en los tramos libres de la fachada
# hacia atras, muebles de pared viendo al centro, elegidos por la semilla del cuarto.
func _relleno(detalle: Node3D, cosas: Node3D, catalogo: Array, sala: float, cuarto: float, front: float) -> void:
	var adelante := front - LOCAL_MURO - 0.1
	var atras := front - cuarto + 0.05
	var ocupado := {-1.0: [], 1.0: []}   # lado -> [(z de atras, z de adelante)]
	for mueble in _muebles(cosas, Transform3D()):
		var xform: Transform3D = mueble[0]
		var medida: Vector2 = mueble[1]
		var xs := []
		var zs := []
		for esquina: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
			var p := cosas.transform * xform * (esquina * Vector3(medida.x / 2.0, 0.0, medida.y / 2.0))
			xs.append(p.x)
			zs.append(p.z)
		for lado in [-1.0, 1.0]:
			if (lado < 0.0 and xs.min() < -sala / 2.0 + RELLENO_FRANJA) or (lado > 0.0 and xs.max() > sala / 2.0 - RELLENO_FRANJA):
				ocupado[lado].append(Vector2(zs.min() - 0.05, zs.max() + 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sala, cuarto, catalogo.size()])
	for lado in [-1.0, 1.0]:
		# De adelante hacia atras, saltando lo ocupado
		var z := adelante
		while z - 0.8 > atras:
			var choque: Vector2 = Vector2.INF
			for tramo: Vector2 in ocupado[lado]:
				if tramo.y > z - 0.8 and tramo.x < z:
					choque = tramo
			if choque != Vector2.INF:
				z = choque.x
				continue
			# El mas ancho que quepa hasta el siguiente mueble de la escena
			var libre := z - atras
			for tramo: Vector2 in ocupado[lado]:
				if tramo.y <= z:
					libre = minf(libre, z - tramo.y)
			var caben := catalogo.filter(func(m: Array) -> bool: return m[1] <= libre)
			if caben.is_empty():
				break
			var elegido: Array = caben[rng.randi() % caben.size()]
			var ancho: float = elegido[1]
			var fondo: float = elegido[2]
			var nodo := _mueble_relleno(elegido[0], rng.randi() % 1000)
			nodo.position = Vector3(lado * (sala / 2.0 - fondo / 2.0 - 0.03), 0.0, z - ancho / 2.0)
			nodo.rotation.y = -lado * PI / 2.0
			detalle.add_child(nodo)
			z -= ancho + 0.05


# [transform dentro de `node`, (ancho, fondo)] de cada mueble de la escena (los que
# tienen `ancho` y `fondo`: Mostrador, Estante, Refrigerador...), sin el vendedor
func _muebles(node: Node, xform: Transform3D) -> Array:
	var lista := []
	for child in node.get_children():
		if not child is Node3D or child.name == "Vendedor":
			continue
		var t := xform * (child as Node3D).transform
		if child.get("ancho") != null and child.get("fondo") != null:
			lista.append([t, Vector2(child.get("ancho"), child.get("fondo"))])
		else:
			lista += _muebles(child, t)
	return lista


func _mueble_relleno(tipo: String, semilla: int) -> Node3D:
	if tipo.begins_with("refri"):
		var refri := Refrigerador.new()
		refri.ancho = 0.8
		refri.fondo = 0.65
		refri.alto = 2.0
		refri.repisas = 5
		refri.luz = 0.0
		refri.semilla = semilla
		refri.color = Color(0.6, 0.13, 0.11) if semilla % 2 == 0 else Color(0.12, 0.25, 0.6)
		return refri
	var estante := Estante.new()
	estante.semilla = semilla
	estante.sencillo = true
	estante.fondo = 0.4
	match tipo:
		"papas":
			estante.tipo = 3
			estante.ancho = 0.8
			estante.alto = 1.85
			estante.fondo = 0.42
			estante.niveles = 5
			estante.color = Color(0.6, 0.15, 0.12)
			estante.color_filo = Color(0.78, 0.64, 0.2)
		"repisas_comida", "repisas_botanas":
			estante.ancho = 1.2
			estante.alto = 2.0
			estante.niveles = 5
			estante.color = Color(0.85, 0.82, 0.75)
			estante.mercancia = 1 if tipo == "repisas_comida" else 0
		"repisas_medicinas":
			estante.ancho = 1.2
			estante.alto = 2.2
			estante.fondo = 0.38
			estante.niveles = 6
			estante.color = Color(0.12, 0.3, 0.75)
			estante.color_filo = Color(0.95, 0.8, 0.1)
			estante.mercancia = 2
	return estante


# Suelta `node` y sus hijos de la escena `dueno` antes de cambiarlos de padre
func _sin_dueno(node: Node, dueno: Node) -> void:
	if node.owner == dueno:
		node.owner = null
	for child in node.get_children():
		_sin_dueno(child, dueno)


# Una caja sin colision (forros del cuarto)
func _caja_detalle(size: Vector3, pos: Vector3, color: Color, muro: bool) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _color_material(color, muro)
	var malla := MeshInstance3D.new()
	malla.mesh = box
	malla.position = pos
	return malla


# Taqueria como la escena de adentro (scenes/interiores/taqueria.tscn) vista desde la
# calle: refris rojos contra el muro izquierdo y mesas rojas con sus sillas en lo que
# queda del cuarto (de cerca, en `Detalle`)
func _taqueria_cuarto(muebles: Node3D, punto: Dictionary, sala: float, cuarto: float, front: float) -> void:
	var semilla := absi(String(punto.get("nombre", "")).hash())
	var refris := 2 if cuarto > 3.2 else 1
	for i in refris:
		var refri := Refrigerador.new()
		refri.ancho = 0.8
		refri.fondo = 0.65
		refri.color = Color(0.6, 0.13, 0.11)
		refri.repisas = 5
		refri.luz = 0.0
		refri.semilla = semilla + i
		refri.position = Vector3(-sala / 2.0 + 0.36, 0.0, front - cuarto + 0.6 + i * 0.82)
		refri.rotation.y = PI / 2.0
		muebles.add_child(refri)
	var mesas := [Vector3(0.45, 0.0, front - 1.0), Vector3(-0.35, 0.0, front - 2.4), Vector3(0.9, 0.0, front - 3.4)]
	for i in mesas.size():
		var pos: Vector3 = mesas[i]
		if pos.z < front - cuarto + 0.7:
			break
		var mesa := Mesa.new()
		mesa.color = TAQUERIA_MESA
		mesa.semilla = semilla + i
		mesa.position = pos
		mesa.rotation.y = deg_to_rad(float((semilla + i * 7) % 11) - 5.0)
		muebles.add_child(mesa)


# En la banqueta de la taqueria, frente al local y un poco a la derecha, el puesto de
# tacos (Mostrador estilo puesto, con su trompo y su humo) con los clientes del lado de
# la calle (+Z) y el taquero entre el puesto y el local, viendo a la calle. La flecha
# va en el lado libre de la puerta (`punto["puerta_x"]`).
func _taqueria_puesto(body: StaticBody3D, banqueta: Node3D, punto: Dictionary, sala: float, puerta: float, front: float) -> void:
	var semilla := absi(String(punto.get("nombre", "")).hash())
	var puesto := Mostrador.new()
	puesto.estilo = 5
	puesto.parrilla_atras = true
	puesto.ancho = minf(2.1, sala - 1.4)
	puesto.alto = 0.92
	puesto.fondo = 0.7
	puesto.color = Color(0.7, 0.1, 0.08)
	puesto.semilla = semilla
	var puesto_x := sala / 2.0 - puesto.ancho / 2.0 - 0.1
	puesto.position = Vector3(puesto_x, 0.0, front + TAQUERIA_PUESTO)
	banqueta.add_child(puesto)
	var caja := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(puesto.ancho, 1.0, puesto.fondo)
	caja.shape = forma
	caja.position = puesto.position + Vector3(0.0, 0.5, 0.0)
	body.add_child(caja)
	if vendedor_escena:
		var taquero := vendedor_escena.instantiate() as Node3D
		taquero.name = "Taquero"
		taquero.position = Vector3(puesto_x + 0.1, 0.0, front + TAQUERIA_PUESTO - 0.7)
		taquero.rotation.y = PI
		taquero.set("tint", Color(0.85, 0.8, 0.7))
		taquero.ready.connect(func() -> void:
			(taquero.get_node("TalkArea") as Area3D).monitoring = false, CONNECT_ONE_SHOT)
		banqueta.add_child(taquero)
	punto["puerta_x"] = (-puerta / 2.0 + minf(puerta / 2.0, puesto_x - puesto.ancho / 2.0)) / 2.0


# Purificadora como la foto de referencia: de izquierda a derecha puerta de barrotes
# metida, el despachador automatico azul en el muro y el ventanal de aluminio con los
# garrafones adentro; muro blanco con rodapie y franja azules como los demas locales y
# el anuncio grande (purificadora_lona.png + letreros) sobre postes en la orilla de la
# banqueta, sin tejado. Guarda en `punto["puerta_x"]` el centro del ventanal, donde
# va la flecha. La fachada ve a +Z, en la orilla del lote.
# Con `solo_fachada` (la escena de compra, Interior.fachada_mapa) no arma el cuerpo ni
# lo de adentro del ventanal, y el ventanal queda abierto: sin vidrios ni travesano,
# solo su marco, para ver al que atiende.
func _make_purificadora(punto: Dictionary, solo_fachada := false) -> Node3D:
	var nombre: String = punto.get("nombre", "")
	var w: float = maxf(punto["ancho"], LOCAL_MIN.x)
	var d: float = maxf(punto["fondo"], LOCAL_MIN.y)
	var h := PURIFICADORA_ALTO
	var front: float = punto["fondo"] / 2.0
	var muro := 0.3   # grueso de la fachada; atras, el cuerpo
	var body := StaticBody3D.new()
	body.name = "purificadora_%s" % nombre
	if not solo_fachada:
		_local_box(body, Vector3(w, h, d - muro), Vector3(0.0, h / 2.0, front - muro - (d - muro) / 2.0), LOCAL_BLANCO, true)
	# Tramos de la fachada de izquierda a derecha
	var x := -w / 2.0
	var puerta := Vector2(x + 0.25, x + 1.45)
	var despachador := Vector2(puerta.y, puerta.y + 0.8)
	var ventana := Vector2(despachador.y + 0.3, minf(w / 2.0 - 0.3, despachador.y + 0.3 + 3.2))
	var oscuro := Color(0.08, 0.08, 0.09)
	var acento := PURIFICADORA_AZUL
	var z := front - muro / 2.0
	# Muro: macizos a los lados de los huecos, dintel de la puerta y antepecho y dintel
	# del ventanal
	var macizos := [Vector2(-w / 2.0, puerta.x), Vector2(despachador.x, ventana.x), Vector2(ventana.y, w / 2.0)]
	for tramo: Vector2 in macizos:
		if tramo.y - tramo.x > 0.01:
			_fachada_tramo(body, tramo, 0.0, h, z, muro, acento)
	_fachada_tramo(body, puerta, 2.3, h, z, muro, acento)
	_fachada_tramo(body, ventana, 0.0, 1.15, z, muro, acento)
	_fachada_tramo(body, ventana, 2.35, h, z, muro, acento)
	# Puerta: fondo oscuro y barrotes negros
	_local_box(body, Vector3(puerta.y - puerta.x, 2.3, 0.05), Vector3((puerta.x + puerta.y) / 2.0, 1.15, front - muro + 0.03), oscuro, false)
	var barrotes := 9
	for i in barrotes + 1:
		var bx := puerta.x + 0.04 + (puerta.y - puerta.x - 0.08) * i / barrotes
		_local_box(body, Vector3(0.025, 2.26, 0.025), Vector3(bx, 1.13, front - 0.08), Color(0.1, 0.1, 0.1), false)
	for y in [0.15, 1.15, 2.2]:
		_local_box(body, Vector3(puerta.y - puerta.x, 0.04, 0.03), Vector3((puerta.x + puerta.y) / 2.0, y, front - 0.08), Color(0.1, 0.1, 0.1), false)
	# Despachador automatico en el muro: marco gris, maquina azul, pantallita y ranura
	var cx := (despachador.x + despachador.y) / 2.0
	_local_box(body, Vector3(0.58, 0.78, 0.03), Vector3(cx, 1.35, front + 0.015), Color(0.62, 0.63, 0.64), false)
	_local_box(body, Vector3(0.46, 0.64, 0.04), Vector3(cx, 1.35, front + 0.02), Color(0.15, 0.4, 0.75), false)
	_local_box(body, Vector3(0.18, 0.1, 0.01), Vector3(cx - 0.08, 1.52, front + 0.045), Color(0.2, 0.75, 0.9), false)
	_local_box(body, Vector3(0.05, 0.12, 0.01), Vector3(cx + 0.13, 1.45, front + 0.045), oscuro, false)
	_local_box(body, Vector3(0.3, 0.2, 0.01), Vector3(cx, 1.15, front + 0.045), oscuro, false)
	# Ventanal: adentro oscuro, repisa con garrafones, marco de aluminio y vidrios
	var vx := (ventana.x + ventana.y) / 2.0
	var vw := ventana.y - ventana.x
	punto["puerta_x"] = vx
	var aluminio := Color(0.78, 0.79, 0.8)
	if solo_fachada:
		for y in [1.17, 2.33]:
			_local_box(body, Vector3(vw, 0.05, 0.06), Vector3(vx, y, front - 0.03), aluminio, false)
		for lado in [ventana.x + 0.025, ventana.y - 0.025]:
			_local_box(body, Vector3(0.05, 1.18, 0.06), Vector3(lado, 1.75, front - 0.03), aluminio, false)
		_anuncio(body, punto, w, front, (despachador.y + ventana.x) / 2.0)
		return body
	_local_box(body, Vector3(vw, 1.2, 0.05), Vector3(vx, 1.75, front - muro + 0.03), Color(0.14, 0.16, 0.18), false)
	var garrafones := int(vw / 0.42)
	for i in garrafones:
		var g := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.1
		cilindro.bottom_radius = 0.13
		cilindro.height = 0.42
		cilindro.radial_segments = 8
		cilindro.rings = 1
		cilindro.material = _color_material(Color(0.35, 0.6, 0.9), false)
		g.mesh = cilindro
		g.position = Vector3(ventana.x + 0.21 + i * 0.42, 1.38, front - muro + 0.16)
		g.visibility_range_end = 60.0
		body.add_child(g)
	for y in [1.17, 1.72, 2.33]:
		_local_box(body, Vector3(vw, 0.05, 0.06), Vector3(vx, y, front - 0.03), aluminio, false)
	var hojas := 3 if vw > 2.4 else 2
	for i in hojas + 1:
		_local_box(body, Vector3(0.05, 1.18, 0.06), Vector3(ventana.x + 0.025 + (vw - 0.05) * i / hojas, 1.75, front - 0.03), aluminio, false)
	var vidrio := MeshInstance3D.new()
	var plano := QuadMesh.new()
	plano.size = Vector2(vw, 1.16)
	if _material_vidrio == null:
		_material_vidrio = StandardMaterial3D.new()
		_material_vidrio.albedo_color = Color(0.7, 0.85, 0.95, 0.18)
		_material_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_vidrio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plano.material = _material_vidrio
	vidrio.mesh = plano
	vidrio.position = Vector3(vx, 1.75, front - 0.05)
	vidrio.visibility_range_end = 80.0
	body.add_child(vidrio)
	_anuncio(body, punto, w, front, (despachador.y + ventana.x) / 2.0)
	return body


# Solo de cerca (`distancia` m): sin sombras y las luces apagandose (sus piezas son hijos internos)
func _detalle_lejos(node: Node, distancia := INTERIOR_VISTA) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = distancia
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif node is Light3D:
		var luz := node as Light3D
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = distancia * 0.5
		luz.distance_fade_length = distancia * 0.25
	for child in node.get_children(true):
		_detalle_lejos(child, distancia)


# Un tramo de la fachada entre x.x y x.y, de y0 a y1: muro (blanco si no) y, donde le toquen,
# el rodapie y la franja de `acento` (cascara apenas mas grande, como en las casas-local)
func _fachada_tramo(body: StaticBody3D, x: Vector2, y0: float, y1: float, z: float, grueso: float, acento: Color, muro := LOCAL_BLANCO) -> void:
	var ancho := x.y - x.x
	var centro := (x.x + x.y) / 2.0
	_local_box(body, Vector3(ancho, y1 - y0, grueso), Vector3(centro, (y0 + y1) / 2.0, z), muro, true)
	for banda: Vector2 in [Vector2(0.0, RODAPIE), Vector2(RODAPIE + 0.2, RODAPIE + 0.3)]:
		var abajo := maxf(banda.x, y0)
		var arriba := minf(banda.y, y1)
		if arriba > abajo:
			_local_box(body, Vector3(ancho + 0.03, arriba - abajo, grueso + 0.03), Vector3(centro, (abajo + arriba) / 2.0, z), acento, false)


# Anuncio de la purificadora en la orilla de la banqueta: lona, letreros, lamparas,
# los postes que lo cargan y dos largueros hasta la fachada (sin techo). El poste de
# en medio va en `poste_x`, entre el despachador y el ventanal, para no tapar la ventanilla
func _anuncio(body: StaticBody3D, punto: Dictionary, w: float, front: float, poste_x: float) -> void:
	var z := front + PURIFICADORA_POSTES
	var abajo := PURIFICADORA_ANUNCIO.x
	var alto := PURIFICADORA_ANUNCIO.y
	var largo := w + 0.3
	var centro := Vector3(0.0, abajo + alto / 2.0, z)
	var blanco := Color(0.92, 0.92, 0.9)
	_local_box(body, Vector3(largo + 0.08, alto + 0.08, 0.08), centro + Vector3(0, 0, -0.05), Color(0.3, 0.3, 0.32), false)
	var lona := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(largo, alto)
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("albedo_texture", PURIFICADORA_LONA)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("deterioro_modo", 1)
	quad.material = material
	lona.mesh = quad
	lona.position = centro
	lona.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(lona)
	# Letreros: arriba "Agua purificada", la marca grande y el lema, entre el garrafon
	# (izquierda) y el vaso (derecha) de la lona
	# En DENUE casi todas se llaman "Purificadora de Agua X": en el anuncio va solo X
	var marca: String = punto.get("nombre", "").to_upper()
	for prefijo in ["PURIFICADORA DE AGUA ", "AGUA PURIFICADA ", "PURIFICADORA "]:
		if marca.begins_with(prefijo):
			marca = marca.substr(prefijo.length())
			break
	if marca == "" or marca.length() > 18 or marca.contains("SIN NOMBRE"):
		marca = "AGUA PURA"
	var x_texto := largo * 0.04
	var ancho_texto := largo * 0.55
	for renglon in [["Agua purificada", 0.33, Color(0.15, 0.55, 0.85), 0.55], [marca, 0.08, Color(0.2, 0.25, 0.65), 1.0],
			["Salud y pureza en cada gota", -0.17, Color(0.1, 0.2, 0.45), 0.6]]:
		var label := Label3D.new()
		label.text = renglon[0]
		label.font_size = 64
		label.outline_size = 0
		label.modulate = renglon[2]
		# ~0.7 del font_size por letra (mayusculas)
		label.pixel_size = minf(alto * 0.3 * renglon[3] / 64.0, ancho_texto / (label.text.length() * 45.0))
		label.position = Vector3(x_texto, centro.y + alto * renglon[1], z + 0.01)
		label.visibility_range_end = 80.0
		body.add_child(label)
	# Lamparas arriba, viendo al anuncio
	for i in 3:
		var lx := -largo * 0.35 + largo * 0.35 * i
		_local_box(body, Vector3(0.03, 0.03, 0.35), Vector3(lx, abajo + alto + 0.06, z + 0.15), Color(0.15, 0.15, 0.15), false)
		_local_box(body, Vector3(0.2, 0.08, 0.12), Vector3(lx, abajo + alto + 0.08, z + 0.35), Color(0.15, 0.15, 0.15), false)
	# Postes en la orilla de la banqueta y largueros hasta la fachada
	for px in [-w / 2.0 + 0.1, poste_x, w / 2.0 - 0.1]:
		_local_box(body, Vector3(0.1, abajo, 0.1), Vector3(px, abajo / 2.0, z), blanco, true)
	for px in [-w / 2.0 + 0.1, w / 2.0 - 0.1]:
		_local_box(body, Vector3(0.08, 0.08, PURIFICADORA_POSTES), Vector3(px, abajo - 0.04, front + PURIFICADORA_POSTES / 2.0), blanco, false)


# Una caja del local; con `solid` tambien lleva colision
func _local_box(body: StaticBody3D, size: Vector3, pos: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _color_material(color, solid)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = PREFAB_VISIBILITY_RANGE
	body.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		body.add_child(shape)
	return mesh


# `muro`: paredes del local, con pintura caida y escurrimientos; lo demas, solo mugre
func _color_material(color: Color, muro: bool) -> ShaderMaterial:
	var key := [color, muro]
	if not _box_materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = PS1_SHADER
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("affine_enabled", false)
		material.set_shader_parameter("deterioro_modo", 2 if muro else 1)
		_box_materials[key] = material
	return _box_materials[key]
