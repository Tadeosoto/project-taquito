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
const BANQUETAS_JSON := "user://banquetas_safehouse.json"
const BANQUETAS := [[[-44.0, -24.0], [20.0, -24.0], [20.0, 12.0], [-44.0, 12.0], [-44.0, -24.0]]]
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
# Tambos con fuego y un poste con chispas como los del mapa (MapAlumbrado), que aqui no hay calles
const MapAlumbrado := preload("res://scripts/map/MapAlumbrado.gd")
const EFECTOS_EN := Vector3(40.0, 0.0, 16.0)
# Tazos y habilidades (Tazos.gd)
const BOLSA_TAZO := "res://resources/productos/takis_tazo.tres"
const PUNTOS_PRUEBA := 5
const POSTE_ALTO := 5.0
const DINERO := 500
const DANO_PRUEBA := 20
const REFUGIO_EN := Vector3(30.0, 0.0, -10.0)
const TABLAS_PRUEBA := "res://resources/productos/tablas.tres"
const DANO_TINACO := 100
const TURBA_PRUEBA := 12
const PIEZA_PRUEBA_EN := Vector3(14.0, 0.0, 6.0)
const PANEL_TEXTO := """DEV SAFEHOUSE  (F1 oculta esto)
Tab inventario · clic o F pegar · V dron
N siguiente atardecer/amanecer
Z zombi · B turba · X quitar zombis · T zombis solos de noche
H curar · J -%d de vida · P +$100 · Y vaciar inventario
G tablas · L -100 al tinaco (refugio a la derecha)
M mapa (sin piezas se ve vacío) · U todas las piezas
1 2 3 maquinita cercana: normal, sin monedas, segura
C crear personaje · K deterioro · F12 reiniciar todo · F10 ir al mapa
F8 sacar al jefe · F9 prender/apagar los efectos nuevos (tambos y chispas: a la derecha)
9 pelea: golpe a tiempo (córtalo cuando gruñe) / sin aturdir nunca
0 zombis: enjambre (carriles, atajos, rebasan) / en fila como antes
O bolsa especial de Takis · Shift+O forzar rareza · I +5 puntos · Shift+I todos los tazos (H/T en el inventario)
Efectos de pixel, propuestas (F2-F7 cambian):"""
# Una tecla por lugar de EfectosPixel, en este orden
const EFECTOS_TECLAS := [KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7]
const EFECTOS_LUGARES := ["golpe", "impacto", "herido", "muerte", "amanecer", "recoger"]

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
var _efectos: Label
var _deterioro := 2
var _refugio: Refugio
var _partida: Partida


func _enter_tree() -> void:
	# Antes del _ready de Casas y Puntos, que leen estos archivos
	_guardar(PUNTOS_JSON, {"puntos": _puntos()})
	_guardar(CASAS_JSON, {"casas": _casas()})
	_guardar(BANQUETAS_JSON, {"banquetas": BANQUETAS})


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
	npc.set("modelo", Civiles.al_azar())
	npc.position = Vector3(10.0, 0.0, -14.0)
	add_child(npc)
	_refugio = Refugio.new()
	_refugio.name = "Refugio"
	_refugio.position = REFUGIO_EN
	add_child(_refugio)
	_partida = Partida.new()
	_partida.name = "Partida"
	_partida.zombis_path = _zombis.get_path()
	_partida.supervivencia_path = get_node("Supervivencia").get_path()
	_partida.refugio_path = _refugio.get_path()
	_partida.piezas_en_el_mapa = false
	var vecinos: Array[Vector3] = [Vector3(-14.0, 0.0, 2.0), Vector3(-8.0, 0.0, 2.0), Vector3(-2.0, 0.0, 2.0)]
	_partida.misiones_config = {"puntos_path": PUNTOS_JSON, "casas_path": CASAS_JSON, "vecinos_fijos": vecinos, "perro_fijo": Vector3(38.0, 0.0, 20.0)}
	add_child(_partida)
	_poner_pieza_prueba()
	var gente := Gente.new()
	gente.name = "Gente"
	gente.banquetas_path = BANQUETAS_JSON
	gente.puntos_path = PUNTOS_JSON
	add_child(gente)
	_letrero("NEGOCIOS", Vector3(-10.0, 6.0, FACHADAS_Z))
	_letrero("MAQUINITAS", Vector3(MAQUINAS_X, 4.5, -9.0))
	_letrero("OBJETOS", Vector3(0.0, 3.0, OBJETOS_ORIGEN.y - 3.0))
	_letrero("CASAS", Vector3(0.0, 9.0, CASAS_Z))
	_efectos_demo()
	_armar_panel()


# Un pedazo de mapa: aqui da el primero que falte, porque las zonas son del mapa real
func _poner_pieza_prueba() -> void:
	var pieza := PiezaMapa.new()
	pieza.position = PIEZA_PRUEBA_EN
	add_child(pieza)


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
	muro.set_shader_parameter("jitter_enabled", false)
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


# Dos tambos y un poste que echa chispas, armados con lo mismo que el mapa
func _efectos_demo() -> void:
	var tambos: Array[Transform3D] = [Transform3D(Basis.IDENTITY, EFECTOS_EN), Transform3D(Basis.IDENTITY, EFECTOS_EN + Vector3(2.5, 0.0, 1.5))]
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	for tambo in tambos:
		cuerpo.add_child(MapAlumbrado.colision_tambo(tambo))
	for nodo in MapAlumbrado.armar_tambos(tambos, 0.0):
		add_child(nodo)
	var poste := Vector3(EFECTOS_EN.x + 6.0, 0.0, EFECTOS_EN.z)
	var material := ShaderMaterial.new()
	material.shader = MURO_SHADER
	material.set_shader_parameter("tint", Color(0.34, 0.35, 0.36))
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	_muro(Vector3(0.2, POSTE_ALTO, 0.2), poste + Vector3.UP * POSTE_ALTO / 2.0, material)
	var chispas: Array[Vector3] = [poste + Vector3.UP * (POSTE_ALTO - 0.3)]
	var nodo := MapAlumbrado.armar_chispas(chispas, 0.0)
	if nodo:
		add_child(nodo)
	_letrero("EFECTOS", EFECTOS_EN + Vector3(3.0, 4.0, 0.0))


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
		KEY_P:
			_cartera.pesos += 100
		KEY_Y:
			_inventario.items.clear()
			_inventario.inventory_changed.emit()
		KEY_B:
			_zombis.aparecer_turba(TURBA_PRUEBA)
		KEY_U:
			for zona in ZonasMapa.cuantas():
				PiezasMapa.dar(zona)
		KEY_G:
			_inventario.add_item(load(TABLAS_PRUEBA))
		KEY_L:
			_refugio.recibir_golpe(DANO_TINACO)
		KEY_1, KEY_2, KEY_3:
			_poner_estado(_maquina_cercana(), tecla - KEY_1)
		KEY_K:
			_deterioro = wrapi(_deterioro + 1, 0, DETERIOROS.size())
			Deterioro.configurar(DETERIOROS[_deterioro], 150.0)
		KEY_F12:
			_reiniciar()
		KEY_C:
			_crear_personaje()
		KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7:
			_zombis.efectos.cambiar(EFECTOS_LUGARES[EFECTOS_TECLAS.find(tecla)])
			_mostrar_efectos()
		KEY_F8:
			var frente := -_jugador.frijol.global_transform.basis.z
			frente.y = 0.0
			_zombis.aparecer_jefe(_jugador.global_position + frente.normalized() * ZOMBI_DISTANCIA * 2.0)
		KEY_F9:
			EfectosPixel.poner_extras(not EfectosPixel.extras)
			_mostrar_efectos()
		KEY_9:
			Player.pelea_a_tiempo = not Player.pelea_a_tiempo
			_mostrar_efectos()
		KEY_0:
			Zombie.enjambre = not Zombie.enjambre
			_mostrar_efectos()
		KEY_O:
			if event.shift_pressed:
				Tazos.rareza_forzada = wrapi(Tazos.rareza_forzada + 1, -1, TazoData.Rareza.size())
			else:
				_inventario.add_item(load(BOLSA_TAZO))
		KEY_I:
			# Shift: uno de cada tazo que falte, para ver el album lleno y los premios de serie
			if event.shift_pressed:
				for tazo: TazoData in Tazos.todos:
					if not Tazos.coleccion.has(tazo.id):
						Tazos.dar_tazo(tazo)
			else:
				Tazos.dar_puntos(PUNTOS_PRUEBA)
		KEY_F10:
			# Al cambiar de escena este nodo ya no tiene viewport
			get_viewport().set_input_as_handled()
			get_tree().change_scene_to_file("res://scenes/map_test.tscn")
			return
		_:
			return
	get_viewport().set_input_as_handled()


# La misma pantalla de Jugar, con el juego en pausa; al cerrarla ya eres el nuevo
func _crear_personaje() -> void:
	_jugador.detener()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var capa := CanvasLayer.new()
	capa.layer = 20
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


func _zombi() -> void:
	var frente := -_jugador.frijol.global_transform.basis.z
	frente.y = 0.0
	var donde := _jugador.global_position + frente.normalized() * ZOMBI_DISTANCIA
	_zombis.sacar(Vector3(donde.x, 0.1, donde.z), false)


func _reiniciar() -> void:
	_zombis.limpiar()
	_zombis.set_physics_process(true)
	_salud.reiniciar()
	_cartera.pesos = DINERO
	_inventario.reiniciar()
	_zombis.noches = 0
	_zombis.director.reiniciar()
	_partida.reiniciar()
	PiezasMapa.reiniciar()
	Misiones.reiniciar()
	Tazos.reiniciar()
	for pieza in get_tree().get_nodes_in_group("piezas_mapa"):
		pieza.queue_free()
	_poner_pieza_prueba()
	for bolsa in get_tree().get_nodes_in_group("bolsa_muerte"):
		bolsa.queue_free()
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
	# Con el raton capturado el cursor esta en el centro: si el panel llega ahi se comia el
	# mirar y el pegar
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_efectos = Label.new()
	_efectos.add_theme_font_size_override("font_size", 11)
	columna.add_child(_efectos)
	_mostrar_efectos()
	_estado = Label.new()
	_estado.add_theme_font_size_override("font_size", 11)
	_estado.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	columna.add_child(_estado)


func _mostrar_efectos() -> void:
	# Tres por renglon, para que el panel no crezca tanto
	var partes := PackedStringArray()
	for i in EFECTOS_LUGARES.size():
		var lugar: String = EFECTOS_LUGARES[i]
		partes.append("F%d %s: %s" % [i + 2, lugar, _zombis.efectos.nombre_variante(lugar)])
		if i % 3 == 2 and i < EFECTOS_LUGARES.size() - 1:
			partes.append("\n")
	_efectos.text = " · ".join(partes).replace(" · \n · ", "\n") \
		+ "\nF9 efectos nuevos: " + ("prendidos" if EfectosPixel.extras else "apagados") \
		+ " · 9 pelea: " + ("golpe a tiempo" if Player.pelea_a_tiempo else "sin aturdir") \
		+ "\n0 zombis: " + ("enjambre" if Zombie.enjambre else "en fila (como antes)")


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var zombis := 0
	for z: Zombie in get_tree().get_nodes_in_group("zombis"):
		if z.estado != Zombie.Estado.MUERTO:
			zombis += 1
	_estado.text = "Vida %d/%d · $%d · Objetos %d/%d · %s · Zombis %d%s · Director %s %.2f · Deterioro %.1f" % [
		_salud.vida, _salud.vida_max, _cartera.pesos, _inventario.get_item_count(), _inventario.capacidad(),
		"Noche" if _ciclo.es_noche() else "Dia", zombis, "" if _zombis.is_physics_processing() else " (no salen solos)",
		_zombis.director.nombre_fase(), _zombis.director.intensidad, DETERIOROS[_deterioro]] \
		+ "\nTazos %d/%d · Puntos %d libres de %d · Bolsas: %s" % [Tazos.distintos().size(), Tazos.todos.size(), Tazos.libres(), Tazos.puntos,
		"al azar" if Tazos.rareza_forzada < 0 else TazoData.RAREZAS[Tazos.rareza_forzada]]
