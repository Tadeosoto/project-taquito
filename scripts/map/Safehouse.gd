extends Node3D

# Dev safehouse: un patio cerrado para probar todo sin caminar el mapa, con los sistemas
# de verdad (MapPuntos, Interiores, Maquinita, Zombis, Ciclo, inventario...), no copias.
# Lo que se agregue al juego va aqui tambien.
#
#   godot --path . scenes/safehouse.tscn
#
# Hasta arriba, un negocio de cada giro; a la izquierda las maquinitas, una en cada estado;
# adelante, un objeto de cada uno (todo lo de resources/productos/); atras, casas modelo. En
# medio cabe la pelea. Las teclas de prueba estan en PANEL_TEXTO y se ven en pantalla.

const PUNTOS_JSON := "user://puntos_safehouse.json"
const CASAS_JSON := "user://casas_safehouse.json"
const NPC := preload("res://scenes/npc.tscn")
const SUELO_SHADER := preload("res://shaders/ps1_suelo.gdshader")
const MURO_SHADER := preload("res://shaders/ps1_combined.gdshader")
const BANQUETA := preload("res://textures/map/banqueta.png")
const OBJETOS_DIR := "res://resources/productos/"
const OBJETOS_SUELTOS := ["res://resources/agua_mala.tres", "res://resources/taco_pastor.tres"]

const LADO := 50.0        # medio patio
const MURO_ALTO := 3.0
const FACHADAS_Z := -32.0
const NEGOCIOS_X := -48.0
const SEPARACION := 1.0
# [tipo, giro, nombre, frente, fondo, aire libre]
const NEGOCIOS := [
	["abarrotes", "abarrotes", "Abarrotes", 6.0, 10.0, false],
	["licoreria", "licoreria", "Licoreria", 6.0, 10.0, false],
	["farmacia", "farmacia", "Farmacia", 7.0, 10.0, false],
	["ferreteria", "ferreteria", "Ferreteria", 6.0, 10.0, false],
	["oxxo", "oxxo", "Oxo", 7.0, 10.0, false],
	["taqueria", "taqueria", "Taqueria", 6.5, 10.0, false],
	["purificadora", "purificadora", "Purificadora", 7.0, 10.0, false],
	["gasolinera", "gasolinera", "Perez", 14.0, 16.0, false],
	["punto", "punto", "El punto", 3.0, 2.0, true],
	["puesto_tacos", "puesto_tacos", "Puesto de tacos", 2.6, 1.6, true],
	["puesto", "tejuino", "Tejuino", 2.5, 2.0, true],
]
# Frente y fondo de las casas Urbi (huellas_tiendas.json)
const CASAS := {"urbi_1p_a": Vector2(6.79, 7.37), "urbi_1p_b": Vector2(6.8, 7.37), "urbi_1p_c": Vector2(7.59, 7.37),
	"urbi_2p_a": Vector2(7.5, 6.94), "urbi_2p_b": Vector2(8.42, 6.94), "urbi_2p_c": Vector2(8.58, 6.94)}
const CASAS_Z := 41.0
const COLORES := ["#e05a47", "#f2994a", "#f2c94c", "#7cc06a", "#4aa3df", "#b07cc6"]
const MAQUINAS_X := -46.0
const MAQUINAS_Z := [-14.0, -9.0, -4.0]
const MAQUINAS_NOMBRES := ["Normal", "Sin monedas", "Segura"]
const OBJETOS_ORIGEN := Vector2(-14.0, 18.0)
const OBJETOS_COLUMNAS := 10
const OBJETOS_PASO := 3.0
const ZOMBI_DISTANCIA := 8.0
const DETERIOROS := [0.0, 0.4, 0.8]
const DINERO := 500
const DANO_PRUEBA := 20
const PANEL_TEXTO := """DEV SAFEHOUSE  (F1 oculta esto)
Tab inventario · clic o F pegar · V dron
N siguiente atardecer/amanecer
Z zombi · X quitar zombis · T zombis solos de noche
H curar · J -%d de vida · M +$100 · Y vaciar inventario
1 2 3 maquinita cercana: normal, sin monedas, segura
K deterioro · R reiniciar todo · F10 ir al mapa"""

var _jugador: Player
var _zombis: Zombis
var _ciclo: Ciclo
var _salud: Node
var _cartera: Node
var _inventario: Node
var _maquinas: Array[Maquinita] = []
var _objetos: Node3D
var _panel: CanvasLayer
var _estado: Label
var _deterioro := 2


func _enter_tree() -> void:
	# Antes del _ready de Casas y Puntos, que leen estos archivos
	_guardar(PUNTOS_JSON, {"puntos": _puntos()})
	_guardar(CASAS_JSON, {"casas": _casas()})


func _puntos() -> Array:
	var puntos := []
	var x := NEGOCIOS_X
	for i in NEGOCIOS.size():
		var n: Array = NEGOCIOS[i]
		puntos.append({"tipo": n[0], "giro": n[1], "nombre": n[2], "x": x + n[3] / 2.0, "z": FACHADAS_Z - n[4] / 2.0,
			"rotacion_y": 0.0, "ancho": n[3], "fondo": n[4], "pisos": 1, "interactivo": true, "aire_libre": n[5],
			"origen": "safehouse/%d" % i})
		x += n[3] + SEPARACION
	return puntos


func _casas() -> Array:
	var casas := []
	var x := -24.0
	var i := 0
	for modelo: String in CASAS:
		var medida: Vector2 = CASAS[modelo]
		casas.append({"modelo": modelo, "x": x + medida.x / 2.0, "z": CASAS_Z, "rotacion_y": PI, "ancho": medida.x, "fondo": medida.y,
			"pisos": 1 if modelo.contains("1p") else 2, "color": COLORES[i], "colonia": ""})
		x += medida.x
		i += 1
	return casas


func _guardar(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _ready() -> void:
	_jugador = get_node("Player")
	_zombis = get_node("Zombis")
	_ciclo = get_node("Ciclo")
	_salud = get_node("/root/Salud")
	_cartera = get_node("/root/Cartera")
	_inventario = get_node("/root/Inventory")
	_cartera.pesos = DINERO
	_patio()
	_poner_maquinas()
	_objetos = Node3D.new()
	_objetos.name = "Objetos"
	add_child(_objetos)
	_poner_objetos()
	var npc := NPC.instantiate()
	npc.set("dialogue", "Aquí se prueba de todo, joven.")
	npc.set("tint", Color(0.5, 0.8, 1.0))
	npc.position = Vector3(10.0, 0.0, -14.0)
	add_child(npc)
	_letrero("NEGOCIOS", Vector3(-10.0, 6.0, FACHADAS_Z))
	_letrero("MAQUINITAS", Vector3(MAQUINAS_X, 4.5, -9.0))
	_letrero("OBJETOS", Vector3(0.0, 3.0, OBJETOS_ORIGEN.y - 3.0))
	_letrero("CASAS", Vector3(0.0, 9.0, CASAS_Z))
	_armar_panel()


# --- El patio ---

func _patio() -> void:
	var piso := StaticBody3D.new()
	piso.name = "Piso"
	add_child(piso)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(LADO * 2.0, 1.0, LADO * 2.0)
	forma.shape = caja
	forma.position.y = -0.5
	piso.add_child(forma)
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * LADO * 2.0
	var malla := MeshInstance3D.new()
	malla.mesh = plano
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SUELO_SHADER
	material.set_shader_parameter("albedo_texture", BANQUETA)
	material.set_shader_parameter("tile_size", 2.0)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	malla.material_override = material
	piso.add_child(malla)
	var muro := ShaderMaterial.new()
	muro.shader = MURO_SHADER
	muro.set_shader_parameter("tint", Color(0.42, 0.44, 0.48))
	muro.set_shader_parameter("deterioro_modo", 2)
	muro.set_shader_parameter("wobble_enabled", false)
	muro.set_shader_parameter("affine_enabled", false)
	for lado in [Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]:
		var medida := Vector3(LADO * 2.0 + 2.0, MURO_ALTO, 1.0) if lado.x == 0.0 else Vector3(1.0, MURO_ALTO, LADO * 2.0 + 2.0)
		_muro(medida, lado * (LADO + 0.5) + Vector3.UP * MURO_ALTO / 2.0, muro)


func _muro(medida: Vector3, donde: Vector3, material: Material) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = donde
	add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medida
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	cubo.size = medida
	malla.mesh = cubo
	malla.material_override = material
	cuerpo.add_child(malla)


func _letrero(texto: String, donde: Vector3, tamano := 0.02) -> void:
	var label := Label3D.new()
	label.text = texto
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = tamano
	label.modulate = Color(1.0, 0.85, 0.1)
	label.position = donde
	add_child(label)


# --- Maquinitas: una de cada estado ---

func _poner_maquinas() -> void:
	for i in MAQUINAS_Z.size():
		var maquina := Maquinita.new()
		maquina.name = "Maquinita%d" % i
		maquina.id = "safehouse/maquinita/%d" % i
		maquina.position = Vector3(MAQUINAS_X, 0.0, MAQUINAS_Z[i])
		maquina.rotation.y = PI / 2.0
		add_child(maquina)
		_maquinas.append(maquina)
		_letrero(MAQUINAS_NOMBRES[i], maquina.position + Vector3.UP * 2.5, 0.008)
	_reiniciar_maquinas()


func _reiniciar_maquinas() -> void:
	for i in _maquinas.size():
		_poner_estado(_maquinas[i], i)


func _poner_estado(maquina: Maquinita, estado: int) -> void:
	maquina.placa.segura = estado == Tragamonedas.Estado.SEGURA
	maquina.placa.caja_monedas_interna = 5 if estado == Tragamonedas.Estado.SIN_MONEDAS else Tragamonedas.CAJA_INICIAL
	maquina.mostrar_estado(maquina.placa.estado())


func _maquina_cercana() -> Maquinita:
	var mejor: Maquinita = null
	for maquina in _maquinas:
		if mejor == null or maquina.global_position.distance_squared_to(_jugador.global_position) < mejor.global_position.distance_squared_to(_jugador.global_position):
			mejor = maquina
	return mejor


# --- Objetos: uno de cada uno, y lo nuevo sale solo ---

func _poner_objetos() -> void:
	for hijo in _objetos.get_children():
		hijo.free()
	var rutas: Array = OBJETOS_SUELTOS.duplicate()
	for archivo in ResourceLoader.list_directory(OBJETOS_DIR):
		if archivo.ends_with(".tres"):
			rutas.append(OBJETOS_DIR + archivo)
	for i in rutas.size():
		var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
		objeto.set("item_data", load(rutas[i]))
		objeto.position = Vector3(OBJETOS_ORIGEN.x + (i % OBJETOS_COLUMNAS) * OBJETOS_PASO, 0.5, OBJETOS_ORIGEN.y + (i / OBJETOS_COLUMNAS) * OBJETOS_PASO)
		_objetos.add_child(objeto)


# --- Teclas de prueba ---

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var tecla: int = event.physical_keycode
	if tecla == KEY_F1:
		_panel.visible = not _panel.visible
		return
	# En una tienda, en una maquinita o volando estas teclas son de ellos
	if not (_jugador.can_process() and _jugador.is_physics_processing()):
		return
	match tecla:
		KEY_Z:
			_zombi()
		KEY_X:
			_zombis.limpiar()
		KEY_T:
			_zombis.set_physics_process(not _zombis.is_physics_processing())
		KEY_H:
			_salud.vida = _salud.vida_max
		KEY_J:
			_salud.vida -= DANO_PRUEBA
		KEY_M:
			_cartera.pesos += 100
		KEY_Y:
			_inventario.items.clear()
			_inventario.inventory_changed.emit()
		KEY_1, KEY_2, KEY_3:
			_poner_estado(_maquina_cercana(), tecla - KEY_1)
		KEY_K:
			_deterioro = wrapi(_deterioro + 1, 0, DETERIOROS.size())
			Deterioro.configurar(DETERIOROS[_deterioro], 150.0)
		KEY_R:
			_reiniciar()
		KEY_F10:
			# Al cambiar de escena este nodo ya no tiene viewport. En coop solo el host, y se
			# van todos con el
			get_viewport().set_input_as_handled()
			Red.cambiar_escena("res://scenes/map_test.tscn")
			return
		_:
			return
	get_viewport().set_input_as_handled()


func _zombi() -> void:
	var frente := -_jugador.frijol.global_transform.basis.z
	frente.y = 0.0
	var zombi := Zombie.new()
	zombi.jugador = _jugador
	_zombis.add_child(zombi)
	var donde := _jugador.global_position + frente.normalized() * ZOMBI_DISTANCIA
	zombi.global_position = Vector3(donde.x, 0.1, donde.z)


func _reiniciar() -> void:
	_zombis.limpiar()
	_zombis.set_physics_process(true)
	_salud.vida = _salud.vida_max
	_cartera.pesos = DINERO
	_inventario.items.clear()
	_inventario.mochila = null
	_inventario._ready()
	_inventario.inventory_changed.emit()
	_reiniciar_maquinas()
	_poner_objetos()
	_ciclo._tiempo = _ciclo.inicio


# --- Lo que se ve encima ---

func _armar_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.name = "Panel"
	_panel.layer = 7
	add_child(_panel)
	var fondo := PanelContainer.new()
	fondo.position = Vector2(6.0, 6.0)
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	caja.set_content_margin_all(6.0)
	fondo.add_theme_stylebox_override("panel", caja)
	_panel.add_child(fondo)
	var columna := VBoxContainer.new()
	fondo.add_child(columna)
	var ayuda := Label.new()
	ayuda.text = PANEL_TEXTO % DANO_PRUEBA
	ayuda.add_theme_font_size_override("font_size", 11)
	columna.add_child(ayuda)
	_estado = Label.new()
	_estado.add_theme_font_size_override("font_size", 11)
	_estado.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	columna.add_child(_estado)


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var zombis := 0
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		if z.estado != Zombie.Estado.MUERTO:
			zombis += 1
	_estado.text = "Vida %d/%d · $%d · Objetos %d/%d · %s · Zombis %d%s · Deterioro %.1f" % [
		_salud.vida, _salud.vida_max, _cartera.pesos, _inventario.get_item_count(), _inventario.capacidad(),
		"Noche" if _ciclo.es_noche() else "Dia", zombis, "" if _zombis.is_physics_processing() else " (no salen solos)", DETERIOROS[_deterioro]]
