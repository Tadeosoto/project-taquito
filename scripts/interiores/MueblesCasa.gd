extends Node3D

# Lo que se hace en la casa del jugador (la de JJ, scenes/casa_personaje.tscn): CasaPropia lo
# cuelga de la casa al entrar (su export `muebles`). Cada mueble del que se puede usar algo lleva
# un MuebleCasa (scripts/interiores/MuebleCasa.gd: Area3D del grupo "interactuable", con el
# boton de brincar/interactuar el mas cercano). Busca los muebles de JJ por su nombre de nodo, asi que su constructor
# (tools/construir_casa_personaje.gd) puede rehacer la casa sin romper esto, y pone los que faltan:
#   Cama       dormir hasta el siguiente amanecer o anochecer (Ciclo.saltar) y curarte del todo
#   Closet     el ropero: CreadorPersonaje (como la C del safehouse)
#   Vitrina    la vitrina de trofeos (TilichesUI con vitrina, como la V del yonke)
#   Mesa       el album de tazos;  Sillon: la libreta del Nocturno (InventoryUI.abrir_pagina)
#   Tele2      la tele de la sala: noticias y propaganda de GelA
#   y nuevos:  el baul (Baul.gd, BaulUI.gd), el altar de la Virgen del Tinaco, los garrafones y
#              el mapa de papel en la pared (InventoryUI.abrir_pagina("mapa"))
# Medidas en metros, en el espacio de la casa (sala x 0..5.5, cuarto x 5.5..8, z 0..4.5).

const RADIO := 1.3                 # m desde el mueble en que aparece su letrero
# Lejos de las puertas de JJ (cocina y bano estan en la pared norte de la sala y del cuarto)
const BAUL_EN := Vector3(7.42, 0.0, 2.75)       # a los pies de la cama
const ALTAR_EN := Vector3(4.95, 0.0, 4.22)      # pared sur de la sala, junto a la mesa
const GARRAFONES_EN := Vector3(0.45, 0.0, 4.15)
const MAPA_EN := Vector3(3.2, 1.55, 4.42)
const MAPA_TAM := Vector2(1.2, 1.1)
# El pedazo de textures/map/minimapa.png que se ve en el mapa de la pared: Santa Mugre
# (en px del minimapa, 1 px = 1 m; resources/map/minimapa.json)
const MAPA_RECORTE := Rect2(493.0, 1155.0, 235.0, 224.0)
const NOTICIAS := [
	"GelA: \"El agua es un derecho... de quien la paga a tiempo.\"",
	"Noticias: la gobernadora Lazcano inaugura otra purificadora en San Jodido.",
	"Recuerde: el toque de queda empieza a las nueve. No salga de noche.",
	"\"Reporte las tomas clandestinas al 800-GOTA. Su vecino se lo agradecera.\"",
	"Noticias: siguen las desapariciones nocturnas en Parques del Mosco. GelA pide calma.",
	"\"Serenol: tranquilidad en cada gota.\" (el comercial de siempre)",
]

var _jugador: Node
var _texto: Label
var _negro: ColorRect


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador")
	var casa := get_parent()
	_mueble(casa, "Cama", "Dormir", _dormir)
	_mueble(casa, "Closet", "Cambiarte", _ropero)
	_mueble(casa, "Vitrina", "Ver tus trofeos", _vitrina)
	_mueble(casa, "Mesa", "Ver el album", _pagina.bind("album"))
	_mueble(casa, "Sillon", "Leer la libreta", _pagina.bind("libreta"))
	_mueble(casa, "Tele2", "Prender la tele", _tele)
	_poner_baul()
	_poner_altar()
	_poner_garrafones()
	_poner_mapa()
	var capa := CanvasLayer.new()
	capa.layer = 11
	add_child(capa)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	capa.add_child(_negro)
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


# --- Muebles que se usan ---

func _mueble(casa: Node, nodo: String, texto: String, accion: Callable, en := Vector3.INF) -> void:
	var lugar := en
	if lugar == Vector3.INF:
		var mueble := casa.get_node_or_null(nodo) as Node3D
		if mueble == null:
			push_warning("MueblesCasa: la casa no tiene %s" % nodo)
			return
		lugar = Vector3(mueble.position.x, 0.0, mueble.position.z)
	var area := MuebleCasa.crear(texto, lugar, accion, RADIO)
	area.name = "Usar" + nodo
	add_child(area)


func _avisar(texto: String, segundos := 4.0) -> void:
	_texto.text = texto
	var tween := create_tween()
	tween.tween_property(_texto, "modulate:a", 1.0, 0.25)
	tween.tween_interval(segundos)
	tween.tween_property(_texto, "modulate:a", 0.0, 0.6)


func _dormir() -> void:
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	var tween := create_tween()
	tween.tween_property(_negro, "modulate:a", 1.0, 0.6)
	await tween.finished
	var noche_antes: bool = ciclo.es_noche() if ciclo else false
	if ciclo and ciclo.has_method("saltar"):
		ciclo.saltar(true)
	var salud := get_node_or_null("/root/Salud")
	if salud:
		salud.vida = salud.vida_max
	await get_tree().create_timer(0.8).timeout
	tween = create_tween()
	tween.tween_property(_negro, "modulate:a", 0.0, 0.8)
	_avisar("Dormiste hasta el amanecer." if noche_antes else "Dormiste hasta que se hizo de noche.")


func _ropero() -> void:
	if _jugador == null:
		return
	_jugador.detener()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var creador: Control = load("res://scripts/CreadorPersonaje.gd").new()
	capa.add_child(creador)
	var cerrar := func() -> void:
		capa.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_jugador.reanudar()
		_jugador.aplicar_personaje()
	creador.connect("listo", cerrar)
	creador.connect("volver", cerrar)


# La vitrina de trofeos (TilichesUI con vitrina): flechas para ver, Esc para cerrar
class VitrinaTrofeos extends CanvasLayer:
	var _ui: Control

	func _ready() -> void:
		layer = 12
		process_mode = Node.PROCESS_MODE_ALWAYS
		var fondo := ColorRect.new()
		fondo.color = Color(0, 0, 0, 0.8)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fondo)
		_ui = load("res://scripts/TilichesUI.gd").new()
		_ui.vitrina = true
		add_child(_ui)
		_ui.mostrar()
		get_tree().paused = true

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory_toggle"):
			get_tree().paused = false
			queue_free()
		else:
			_ui.manejar(event)
		get_viewport().set_input_as_handled()


func _vitrina() -> void:
	add_child(VitrinaTrofeos.new())


func _pagina(cual: String) -> void:
	var inventario := get_tree().get_first_node_in_group("inventario_ui")
	if inventario == null:
		for nodo in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if nodo.has_method("abrir_pagina"):
				inventario = nodo
				break
	if inventario:
		inventario.abrir_pagina(cual)


func _tele() -> void:
	_avisar(NOTICIAS[randi() % NOTICIAS.size()], 5.0)


func _abrir_baul() -> void:
	add_child(load("res://scripts/BaulUI.gd").new())


# --- Cosas nuevas en la casa ---

static var _mats := {}


static func _mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_mats[color] = m
	return _mats[color]


func _caja(padre: Node3D, centro: Vector3, tam: Vector3, color: Color, choca := false) -> void:
	var malla := BoxMesh.new()
	malla.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = _mat(color)
	mi.position = centro
	padre.add_child(mi)
	if choca:
		var cuerpo := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = tam
		forma.shape = caja
		cuerpo.position = centro
		cuerpo.add_child(forma)
		padre.add_child(cuerpo)


func _cilindro(padre: Node3D, base: Vector3, radio: float, alto: float, color: Color) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = alto
	malla.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = _mat(color)
	mi.position = base + Vector3.UP * alto / 2.0
	padre.add_child(mi)


func _poner_baul() -> void:
	var baul := Node3D.new()
	baul.name = "Baul"
	baul.position = BAUL_EN
	baul.rotation.y = -PI / 2      # su frente hacia el cuarto
	add_child(baul)
	var madera := Color(0.36, 0.22, 0.12)
	_caja(baul, Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.5), madera, true)
	_caja(baul, Vector3(0, 0.53, 0), Vector3(0.94, 0.08, 0.54), madera.darkened(0.2))
	for x in [-0.3, 0.3]:
		_caja(baul, Vector3(x, 0.3, 0.26), Vector3(0.06, 0.5, 0.02), Color(0.2, 0.2, 0.2))
	_caja(baul, Vector3(0, 0.38, 0.265), Vector3(0.1, 0.1, 0.02), Color(0.8, 0.65, 0.25))
	_mueble(self, "Baul", "Abrir el baul", _abrir_baul, BAUL_EN)


# El altar de la Virgen del Tinaco: repisa, la estampita (la virgen con su tinaco negro),
# veladoras y flores de plastico. Rezar no hace nada... o eso dicen
func _poner_altar() -> void:
	var altar := Node3D.new()
	altar.name = "Altar"
	altar.position = ALTAR_EN
	altar.rotation.y = PI          # pegado a la pared sur, viendo a la sala
	add_child(altar)
	_caja(altar, Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.35), Color(0.45, 0.28, 0.16), true)
	_caja(altar, Vector3(0, 0.93, 0), Vector3(0.9, 0.05, 0.4), Color(0.95, 0.95, 0.92))
	_caja(altar, Vector3(0, 1.3, -0.12), Vector3(0.36, 0.5, 0.03), Color(0.8, 0.65, 0.25))
	_caja(altar, Vector3(0, 1.3, -0.1), Vector3(0.3, 0.44, 0.02), Color(0.25, 0.45, 0.8))
	_cilindro(altar, Vector3(0, 1.32, -0.08), 0.06, 0.12, Color(0.08, 0.08, 0.09))
	for i in 5:
		_cilindro(altar, Vector3(-0.3 + i * 0.15, 0.955, 0.08), 0.03, 0.1, Color(0.95, 0.85, 0.4))
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 1.1, 0.15)
	luz.light_color = Color(1.0, 0.7, 0.35)
	luz.light_energy = 0.6
	luz.omni_range = 1.6
	altar.add_child(luz)
	_mueble(self, "Altar", "Rezarle a la Virgen del Tinaco",
			_avisar.bind("Le prendes una veladora a la Virgen del Tinaco. \"Que no nos falte el agua.\""), ALTAR_EN)


func _poner_garrafones() -> void:
	var pila := Node3D.new()
	pila.name = "Garrafones"
	pila.position = GARRAFONES_EN
	add_child(pila)
	var azul := Color(0.35, 0.6, 0.85)
	for i in 4:
		var x := (i % 2) * 0.32
		var y := (i / 2) * 0.48
		_cilindro(pila, Vector3(x, y, 0), 0.15, 0.46, azul)
		_cilindro(pila, Vector3(x, y + 0.46, 0), 0.05, 0.03, Color(0.15, 0.3, 0.7))


func _poner_mapa() -> void:
	var quad := QuadMesh.new()
	quad.size = MAPA_TAM
	var m := StandardMaterial3D.new()
	var textura := load("res://textures/map/minimapa.png") as Texture2D
	m.albedo_texture = textura
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tam := Vector2(textura.get_width(), textura.get_height()) if textura else Vector2.ONE
	m.uv1_offset = Vector3(MAPA_RECORTE.position.x / tam.x, MAPA_RECORTE.position.y / tam.y, 0)
	m.uv1_scale = Vector3(MAPA_RECORTE.size.x / tam.x, MAPA_RECORTE.size.y / tam.y, 1)
	var mapa := MeshInstance3D.new()
	mapa.name = "MapaPared"
	mapa.mesh = quad
	mapa.material_override = m
	mapa.position = MAPA_EN
	mapa.rotation.y = PI          # pegado a la pared sur, viendo hacia la sala (-z)
	add_child(mapa)
	_caja(self, MAPA_EN + Vector3(0, 0, 0.01), Vector3(MAPA_TAM.x + 0.08, MAPA_TAM.y + 0.08, 0.01), Color(0.85, 0.8, 0.65))
	_mueble(self, "Mapa", "Ver el mapa", _pagina.bind("mapa"), Vector3(MAPA_EN.x, 0.0, MAPA_EN.z - 0.6))
