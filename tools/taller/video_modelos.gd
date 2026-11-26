extends Node3D
# Video de los modelos de la Fase T (docs/plan-noche.md): los tiliches en secuencia y luego todo
# lo que se craftea, cada uno dando vueltas como en las tiendas, con su nombre.
#   godot --path . --write-movie dir/modelos.avi --fixed-fps 30 --resolution 640x480 tools/taller/video_modelos.tscn

const GIRO := 0.45      # vueltas por segundo
const CADA := 2.6       # segundos por modelo
const TITULO := 2.2     # segundos del letrero de cada seccion
const FOV := 40.0

const SECCIONES := [
	["Tiliches", "tiliches", [
		["lata", "Lata"], ["varilla", "Varilla"], ["cobalto_84", "Cobalto 84"], ["hilacha", "Hilacha"],
		["tela", "Tela"], ["cuero", "Cuero"], ["liga", "Liga"], ["hule", "Hule"], ["llanta", "Llanta"],
		["frijol_rojo", "Frijol rojo"], ["obsidiana", "Obsidiana"], ["cuarzo", "Cuarzo"],
		["plata_taxco", "Plata de Taxco"]]],
	["Trofeos", "tiliches", [
		["marca_cazador", "Marca de cazador"], ["ojo_turba", "Ojo de turba"], ["tapa_tinaco", "Tapa del tinaco"],
		["diente_jefe", "Diente del jefe"], ["chancla_oro", "Chancla de oro"], ["casco_gela", "Casco de GelA"],
		["escama_madre", "Escama de la Madre"], ["corona_flores", "Corona de flores"]]],
	["Armas", "taller", [
		["machete_oxidado", "Machete oxidado"], ["machete_reforzado", "Machete reforzado"],
		["machete_canero", "Machete de cañero"], ["macheton_84", "Machetón del 84"], ["tubo", "Tubo"],
		["marro", "Marro"], ["bate_clavos", "Bate con clavos"], ["femur_cobalto", "Fémur de Mojiganga"]]],
	["Armadura y botas", "taller", [
		["coderas_rodilleras", "Coderas y rodilleras"], ["faja", "Faja de cargador"],
		["chaleco_llanta", "Chaleco de llanta"], ["chamarra_machetes", "Chamarra del Machetes"],
		["tenis_tianguis", "Tenis de tianguis"], ["botas_obra", "Botas de obra"],
		["botas_casquillo", "Botas de casquillo"], ["botas_84", "Botas del 84"]]],
	["Amuletos", "taller", [
		["escapulario", "Escapulario"], ["ojo_venado", "Ojo de venado"], ["collar_obsidiana", "Collar de obsidiana"],
		["medalla_virgen", "Medalla de la Virgen"], ["medalla_san_judas", "Medalla de San Judas"],
		["pulsera_san_benito", "Pulsera de San Benito"], ["liston_virgen", "Listón de la Virgen"],
		["collar_santa_muerte", "Collar de la Santa Muerte"]]],
]

var _camara: Camera3D
var _pivote: Node3D
var _nombre: Label
var _titulo: Label
var _seccion: Label


func _ready() -> void:
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.13, 0.11, 0.16)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color.WHITE
	entorno.environment.ambient_light_energy = 0.7
	add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sol)
	_camara = Camera3D.new()
	_camara.fov = FOV
	add_child(_camara)
	_pivote = Node3D.new()
	add_child(_pivote)
	var capa := CanvasLayer.new()
	add_child(capa)
	_nombre = _letrero(capa, Vector2(0, 420), 1)
	_seccion = _letrero(capa, Vector2(0, 16), 1)
	_seccion.modulate = Color(1.0, 0.8, 0.35)
	_titulo = _letrero(capa, Vector2(0, 200), 2)
	await _video()
	get_tree().quit()


func _letrero(capa: CanvasLayer, donde: Vector2, escala: int) -> Label:
	var l := Label.new()
	l.theme = preload("res://resources/ui/tema_pixel.tres")
	l.position = donde
	l.size = Vector2(640 / escala, 40)
	l.scale = Vector2.ONE * escala
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	capa.add_child(l)
	return l


func _process(delta: float) -> void:
	_pivote.rotate_y(TAU * GIRO * delta)


func _seg(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _video() -> void:
	for seccion: Array in SECCIONES:
		for hijo in _pivote.get_children():
			hijo.free()   # el letrero de la seccion va solo, sin el ultimo modelo atras
		_seccion.text = ""
		_nombre.text = ""
		_titulo.text = seccion[0]
		await _seg(TITULO)
		_titulo.text = ""
		_seccion.text = seccion[0]
		for modelo: Array in seccion[2]:
			_mostrar("res://models/%s/%s/%s.scn" % [seccion[1], modelo[0], modelo[0]])
			_nombre.text = modelo[1]
			await _seg(CADA)
	for hijo in _pivote.get_children():
		hijo.queue_free()
	_seccion.text = ""
	_nombre.text = ""
	_titulo.text = "Fase T completa"
	await _seg(2.5)


# Pone el modelo con su centro en el pivote y la camara a la distancia que lo encuadra entero
# (con el radio de la caja: dando vueltas no se sale)
func _mostrar(ruta: String) -> void:
	for hijo in _pivote.get_children():
		hijo.free()
	_pivote.rotation = Vector3.ZERO
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_error("video_modelos: no hay " + ruta)
		return
	var modelo := escena.instantiate() as Node3D
	_pivote.add_child(modelo)
	var caja := AABB()
	var primera := true
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var aabb := malla.global_transform * malla.get_aabb()
		caja = aabb if primera else caja.merge(aabb)
		primera = false
	modelo.position = -caja.get_center()
	var radio: float = maxf(caja.size.length() * 0.5, 0.03)
	var distancia := radio / sin(deg_to_rad(FOV * 0.5)) * 0.95
	_camara.near = distancia * 0.01
	_camara.far = distancia * 10.0
	_camara.position = Vector3(0.0, 0.3, 1.0).normalized() * distancia
	_camara.look_at(Vector3.ZERO)
