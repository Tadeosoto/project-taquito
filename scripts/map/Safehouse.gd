extends Node3D

# Dev safehouse: un patio cerrado para probar todo sin caminar el mapa, con los sistemas
# de verdad (MapPuntos, Interiores, Maquinita, Zombis, Ciclo, inventario...), no copias.
# Lo que se agregue al juego va aqui tambien.
#
#   godot --path . scenes/safehouse.tscn
#
# Hasta arriba, un negocio de cada giro; a la izquierda las maquinitas, una en cada estado;
# adelante, un objeto de cada uno (todo lo de resources/productos/); atras, casas modelo. En
# medio cabe la pelea. Las teclas de prueba estan en PAGINAS y se ven con F1 (una pagina a la vez).

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
const CHATARRA_EN := [Vector3(17.0, 0.0, 6.0), Vector3(19.5, 0.0, 6.0)]
const MATERIALES_PRUEBA := 5   # de cada material comun y especial con Shift+P
const CANGURERA := "res://resources/productos/cangurera.tres"
const YONKE_EN := Vector3(-36.0, 0.0, 14.0)
const PANZON_DISTANCIA := 18.0   # m enfrente donde sale con Shift+J
const SALTABARDAS_DISTANCIA := 16.0   # m enfrente donde sale con Shift+G
const BOTIN_DISTANCIA := 5.0   # m enfrente a los que salen las cajitas con Shift+Z
# La estela de los golpes (EstelaBarrido.estilo): la 8 prende o apaga la del protagonista
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
# El panel de F1, por paginas (en 640x480 todo junto tapaba la pantalla): F1 pasa a la
# siguiente y despues de la ultima lo esconde. `efectos`: si muestra el estado de F2-F9, 9, 0 y 8
const PAGINAS := [
	{"titulo": "Básico", "efectos": false, "texto": """Tab inventario · M mapa · U todas las piezas
Clic o F pegar · clic der. bloquear · Alt + WASD rodar
S pegando o con pistola: retroceder
Botón de en medio: verte de frente
V dron · N siguiente atardecer/amanecer
H curar · J -%d de vida · P +$100
Y vaciar inventario (sin machete pegas a puñetazos)
C crear personaje · K deterioro
F12 reiniciar todo · F10 ir al mapa"""},
	{"titulo": "Pelea", "efectos": true, "texto": """1 2 machete / pistola · R recargar
9 golpe a tiempo (córtalo cuando gruñe) / sin aturdir
8 estela del protagonista (su mejora) / la de siempre
7 cargado: deja apretado y suelta = tajo, 2.5x
6 en el aire: giro; con Shift, clavado (prueba)
Shift+1 2 3 maquinita: normal, sin monedas, segura"""},
	{"titulo": "Zombis", "efectos": true, "texto": """Z zombi · B turba (Ctrl+B: llenar la libreta, Shift+B: borrarla) · X quitar · F8 jefe
T zombis solos de noche
0 caminan en enjambre / en fila como antes
G tablas · Shift+G Saltabardas · Shift+J Panzón · L -100 al tinaco (refugio a la derecha)
Shift+X La Mojiganga (catrina gigante, ya despierta)
, soltar 80 lombrices enfrente (hornea unos segundos)
Shift+L la Madre del Cárcamo con sus crías · Shift+, explosión
3 sal / molotov (otra vez 3 cambia; caguama + alcohol = molotov)"""},
	{"titulo": "Efectos y tazos", "efectos": true, "texto": """F2-F7 efectos de pixel (propuestas, abajo)
F9 efectos nuevos (tambos y chispas: a la derecha)
O bolsa especial de Takis · Shift+O forzar rareza
I +5 puntos · Shift+I todos los tazos
H/T en el inventario: habilidades y álbum"""},
	{"titulo": "Taller y botín", "efectos": false, "texto": """Shift+P cangurera y +5 de cada material (B en el inventario: tiliches)
Shift+Z cajitas de botín y monedas enfrente
Yonke a la izquierda (V adentro: vitrina) · niño de los tazos junto
Shift+K rango · Ctrl+L trofeos y planos · Shift+Y olvidar el taller
Chatarra junto al pedazo de mapa · L en el inventario: libreta"""},
]
const PANEL_ANCHO := 380.0     # px de 640: deja libre la mira y al personaje
const LOMBRICES_ENFRENTE := 8.0
const LOMBRICES_CAJA := Vector3(32.0, 5.0, 32.0)
# Una tecla por lugar de EfectosPixel, en este orden
const EFECTOS_TECLAS := [KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7]
const EFECTOS_LUGARES := ["golpe", "impacto", "herido", "muerte", "amanecer", "recoger"]

var _jugador: Player
var _lombrices: EnjambreLombrices
var _madre: MadreCarcamo
var _barra_madre: BarraMadre
var _barra_catrina: BarraCatrina
var _zombis: Zombis
var _ciclo: Ciclo
var _salud: Node
var _cartera: Node
var _inventario: Node
var _maquinas: Array[Maquinita] = []
var _objetos: Node3D
var _panel: CanvasLayer
var _pagina := -1               # -1 = panel escondido
var _titulo: Label
var _ayuda: Label
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
	Player.golpe_cargado = true
	Player.giro_aereo = true
	_jugador = get_node("Player")
	# Para probar sin cambiar el personaje guardado: -- --protagonista=N (Personaje.PROTAGONISTAS)
	# y --estela=N (EstelaBarrido.Estilo)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--protagonista="):
			get_node("/root/Personaje").protagonista = int(arg.trim_prefix("--protagonista="))
			_jugador.aplicar_personaje()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--estela="):
			ESTELA.estilo = int(arg.trim_prefix("--estela="))
	_zombis = get_node("Zombis")
	# -- --catrina: La Mojiganga de una vez (como Shift+X), para probar el modelo sin tocar teclas;
	# con -- --salir=<s> imprime como va y sale
	if "--catrina" in OS.get_cmdline_user_args():
		_probar_catrina.call_deferred()
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
	# Uno por mision (Misiones.ARCHIVOS) y el ultimo para el nino de los tazos
	var vecinos: Array[Vector3] = [Vector3(-14.0, 0.0, 2.0), Vector3(-8.0, 0.0, 2.0), Vector3(-2.0, 0.0, 2.0), Vector3(4.0, 0.0, 2.0), Vector3(10.0, 0.0, 2.0), Vector3(-30.0, 0.0, 10.0)]
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
	# El taller de La Chava (YonkeMapa.gd), con su barda de lamina porque aqui no hay baldio
	var yonke := YonkeMapa.new()
	yonke.name = "Yonke"
	yonke.position = YONKE_EN
	yonke.con_barda = true
	yonke.puntos_path = get_node("Puntos").get_path()
	add_child(yonke)
	_armar_panel()


# Un pedazo de mapa: aqui da el primero que falte, porque las zonas son del mapa real
func _poner_pieza_prueba() -> void:
	var pieza := PiezaMapa.new()
	pieza.position = PIEZA_PRUEBA_EN
	add_child(pieza)
	# Y unos montones de chatarra para el taller (Chatarra.gd)
	for monton in get_tree().get_nodes_in_group("chatarra"):
		monton.queue_free()
	for en: Vector3 in CHATARRA_EN:
		var monton := Chatarra.new()
		monton.position = en
		add_child(monton)


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

func _exit_tree() -> void:
	ESTELA.estilo = ESTELA.Estilo.NORMAL
	get_node("/root/Personaje").mejora_estela = false
	Player.golpe_cargado = false
	Player.giro_aereo = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var tecla: int = event.physical_keycode
	if tecla == KEY_F1:
		_pagina += 1
		if _pagina >= PAGINAS.size():
			_pagina = -1
		_mostrar_pagina()
		return
	# En una tienda, en una maquinita o volando estas teclas son de ellos
	if not (_jugador.can_process() and _jugador.is_physics_processing()):
		return
	match tecla:
		KEY_Z when event.shift_pressed:
			# Una cajita de cada color y monedas, enfrente (CajaBotin.gd)
			var frente := -_jugador.frijol.global_transform.basis.z
			frente.y = 0.0
			CajaBotin.soltar(self, _jugador.global_position + frente.normalized() * BOTIN_DISTANCIA + Vector3.UP,
				{"rebaba": 1, "tuerca": 1, "engrane": 1, "varilla_corta": 1}, 6)
		KEY_Z:
			_zombi()
		KEY_X when event.shift_pressed:
			# La Mojiganga a 18 m enfrente, despierta (scripts/catrina/Catrina.gd)
			var enfrente_c := -_jugador.frijol.global_transform.basis.z
			enfrente_c.y = 0.0
			_soltar_catrina(_jugador.global_position + enfrente_c.normalized() * PANZON_DISTANCIA)
		KEY_X:
			_zombis.limpiar()
		KEY_T:
			_zombis.set_physics_process(not _zombis.is_physics_processing())
		KEY_H:
			_salud.vida = _salud.vida_max
		KEY_J when event.shift_pressed:
			# El Panzon a 18 m enfrente: ruge, embiste, avienta losas (Panzon.gd)
			var enfrente_p := -_jugador.frijol.global_transform.basis.z
			enfrente_p.y = 0.0
			_zombis.aparecer_panzon(_jugador.global_position + enfrente_p.normalized() * PANZON_DISTANCIA)
		KEY_J:
			_salud.vida -= DANO_PRUEBA
		KEY_P:
			# Shift: materiales para el taller (Tiliches.gd), sin trofeos
			if event.shift_pressed:
				# Los tiliches van en la cangurera: se la pone si no la trae
				if _inventario.cangurera == null:
					_inventario.add_item(load(CANGURERA))
				for id: String in Materiales.LISTA:
					if not Materiales.es_trofeo(id):
						Tiliches.dar(id, MATERIALES_PRUEBA, false)
			else:
				_cartera.pesos += 100
		KEY_Y when event.shift_pressed:
			# El taller se olvida de ti: rango, planos y vitrina
			Taller.olvidar()
			Tiliches.vaciar_vitrina()
		KEY_K when event.shift_pressed:
			Taller.subir_rango()
		KEY_L when event.ctrl_pressed:
			for id: String in Materiales.de_clase(Materiales.Clase.TROFEO):
				Tiliches.dar(id, 3, false)
			for plano: String in Recetas.PLANOS:
				Taller.dar_plano(plano)
		KEY_Y:
			_inventario.vaciar()
			_inventario.cangurera = null
			_inventario.inventory_changed.emit()
		KEY_B:
			# Ctrl+B: llenar la libreta del Nocturno; Shift+B: olvidarla (para volver a descubrirla)
			if event.ctrl_pressed:
				get_node("/root/Libreta").llenar()
			elif event.shift_pressed:
				get_node("/root/Libreta").olvidar()
			else:
				_zombis.aparecer_turba(TURBA_PRUEBA)
		KEY_U:
			for zona in ZonasMapa.cuantas():
				PiezasMapa.dar(zona)
		KEY_G when event.shift_pressed:
			# Un Saltabardas a 16 m enfrente: grita, salta y se te sube (machaca golpe o brinco)
			var enfrente := -_jugador.frijol.global_transform.basis.z
			enfrente.y = 0.0
			_zombis.aparecer_saltabardas(_jugador.global_position + enfrente.normalized() * SALTABARDAS_DISTANCIA)
		KEY_G:
			_inventario.add_item(load(TABLAS_PRUEBA))
		KEY_L:
			if event.shift_pressed:
				_soltar_madre()
			else:
				_refugio.recibir_golpe(DANO_TINACO)
		KEY_1, KEY_2, KEY_3:
			# Sin Shift, 1-5 cambian de arma (Player._tecla_arma)
			if event.shift_pressed:
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
		KEY_8:
			# Prende o apaga la estela del protagonista (su mejora, Personaje.ESTELAS)
			var personaje := get_node("/root/Personaje")
			personaje.mejora_estela = not personaje.mejora_estela
			ESTELA.estilo = personaje.estela()
			_mostrar_efectos()
		KEY_6:
			Player.giro_aereo = not Player.giro_aereo
			_mostrar_efectos()
		KEY_7:
			Player.golpe_cargado = not Player.golpe_cargado
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
		KEY_COMMA:
			if event.shift_pressed:
				EnjambreLombrices.explotar_en_mira(get_tree(), get_viewport())
			else:
				_soltar_lombrices()
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


# Un enjambre de lombrices (scripts/lombrices/) LOMBRICES_ENFRENTE m enfrente, en el piso
func _soltar_lombrices() -> void:
	if _lombrices == null:
		_lombrices = EnjambreLombrices.new()
		_lombrices.hornear_al_entrar = false
		_lombrices.caja = LOMBRICES_CAJA
		add_child(_lombrices)
	var frente := -_jugador.frijol.global_transform.basis.z
	frente.y = 0.0
	var donde := _jugador.global_position + frente.normalized() * LOMBRICES_ENFRENTE
	donde.y = 0.0
	_lombrices.global_position = donde
	# Solas (,): sin Madre, en fase 3 para ver todo; Shift+L la vuelve a conectar
	if _lombrices.horneado.is_connected(_armar_madre):
		_lombrices.horneado.disconnect(_armar_madre)
	if _madre:
		_madre.visible = false
		_madre.set_physics_process(false)
	_lombrices.fase = 3
	_lombrices.soltar(donde)


# La Madre del Carcamo (MadreCarcamo.gd) bajo el piso donde se sueltan las crias; sin charco,
# se esconde en el piso. Con ella el enjambre arranca en fase 1
func _soltar_madre() -> void:
	_soltar_lombrices()
	if not _lombrices.horneado.is_connected(_armar_madre):
		_lombrices.horneado.connect(_armar_madre)


func _armar_madre() -> void:
	if _madre == null:
		_madre = MadreCarcamo.new()
		_madre.enjambre = _lombrices
		add_child(_madre)
		_barra_madre = BarraMadre.new()
		_barra_madre.madre = _madre
		_barra_madre.enjambre = _lombrices
		add_child(_barra_madre)
		_madre.muerta.connect(_lombrices.disolver)
	_madre.charco = _lombrices.global_position
	_madre.reiniciar()
	_madre.set_physics_process(true)


func _probar_catrina() -> void:
	var enfrente := -_jugador.frijol.global_transform.basis.z
	enfrente.y = 0.0
	_soltar_catrina(_jugador.global_position + enfrente.normalized() * PANZON_DISTANCIA)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--salir="):
			await get_tree().create_timer(float(arg.trim_prefix("--salir="))).timeout
			for catrina in get_tree().get_nodes_in_group("catrina"):
				print("Safehouse: Catrina viva, estado %d, vida %d, modelo %s" % [catrina.estado, catrina.vida(),
					"Blender" if catrina.get("_provisional") == null else "provisional"])
			get_tree().quit()


func _soltar_catrina(lugar: Vector3) -> void:
	for vieja in get_tree().get_nodes_in_group("catrina"):
		vieja._quitar()
	var catrina := Catrina.new()
	catrina.jugador = _jugador
	catrina.zombis = _zombis
	catrina.dormida = false
	add_child(catrina)
	catrina.global_position = Vector3(lugar.x, 0.0, lugar.z)
	catrina.rotation.y = atan2(-(_jugador.global_position.x - lugar.x), -(_jugador.global_position.z - lugar.z))
	if _barra_catrina == null:
		_barra_catrina = BarraCatrina.new()
		add_child(_barra_catrina)
	_barra_catrina.catrina = catrina


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
	Tiliches.reiniciar()
	Bonos.reiniciar()
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
	# Arranca oculto (JJ): F1 lo muestra
	_panel.visible = false
	add_child(_panel)
	var fondo := PanelContainer.new()
	# Debajo de la barra de vida (Supervivencia)
	fondo.position = Vector2(6.0, 26.0)
	# Con el raton capturado el cursor esta en el centro: si el panel llega ahi se comia el
	# mirar y el pegar
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	caja.set_content_margin_all(6.0)
	fondo.add_theme_stylebox_override("panel", caja)
	_panel.add_child(fondo)
	fondo.custom_minimum_size.x = PANEL_ANCHO
	var columna := VBoxContainer.new()
	fondo.add_child(columna)
	_titulo = _renglon(columna, Color(0.6, 0.9, 1.0))
	_ayuda = _renglon(columna, Color.WHITE)
	_efectos = _renglon(columna, Color(0.8, 0.8, 0.8))
	_mostrar_efectos()
	_estado = _renglon(columna, Color(1.0, 0.85, 0.1))
	_mostrar_pagina()


# Un texto del panel: angosto, y lo largo baja de renglon en vez de ensanchar el panel
func _renglon(columna: VBoxContainer, color: Color) -> Label:
	var texto := Label.new()
	texto.add_theme_font_size_override("font_size", 11)
	texto.add_theme_color_override("font_color", color)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = PANEL_ANCHO
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_child(texto)
	return texto


func _mostrar_pagina() -> void:
	_panel.visible = _pagina >= 0
	if _pagina < 0:
		return
	var pagina: Dictionary = PAGINAS[_pagina]
	_titulo.text = "DEV SAFEHOUSE · %s (%d/%d) · F1 siguiente" % [pagina.titulo, _pagina + 1, PAGINAS.size()]
	_ayuda.text = pagina.texto % DANO_PRUEBA if _pagina == 0 else pagina.texto
	_efectos.visible = pagina.efectos
	_mostrar_efectos()
	# El panel no se encoge solo al pasar a una pagina mas corta
	_panel.get_child(0).size = Vector2.ZERO


# El estado de las teclas que cambian algo, solo las de la pagina abierta
func _mostrar_efectos() -> void:
	if _efectos == null:
		return
	var renglones := PackedStringArray()
	match _pagina:
		1:
			renglones.append("9 pelea: " + ("golpe a tiempo" if Player.pelea_a_tiempo else "sin aturdir"))
			renglones.append("8 estela: %d %s" % [ESTELA.estilo, ESTELA.NOMBRES[ESTELA.estilo]])
			renglones.append("7 cargado: %s · 6 giro: %s" % ["sí" if Player.golpe_cargado else "no", "sí" if Player.giro_aereo else "no"])
		2:
			renglones.append("0 zombis: " + ("enjambre" if Zombie.enjambre else "en fila (como antes)"))
		3:
			for i in EFECTOS_LUGARES.size():
				var lugar: String = EFECTOS_LUGARES[i]
				renglones.append("F%d %s: %s" % [i + 2, lugar, _zombis.efectos.nombre_variante(lugar)])
			renglones.append("F9 efectos nuevos: " + ("prendidos" if EfectosPixel.extras else "apagados"))
	_efectos.text = "
".join(renglones)


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var zombis := 0
	for z in get_tree().get_nodes_in_group("zombis"):
		if z.get("estado") != Zombie.Estado.MUERTO:
			zombis += 1
	_estado.text = "Vida %d/%d · $%d · Objetos %d/%d · %s · Zombis %d%s · Director %s %.2f · Deterioro %.1f" % [
		_salud.vida, _salud.vida_max, _cartera.pesos, _inventario.get_item_count(), _inventario.capacidad(),
		"Noche" if _ciclo.es_noche() else "Dia", zombis, "" if _zombis.is_physics_processing() else " (no salen solos)",
		_zombis.director.nombre_fase(), _zombis.director.intensidad, DETERIOROS[_deterioro]] \
		+ "\nTazos %d/%d · Puntos %d libres de %d · Bolsas: %s" % [Tazos.distintos().size(), Tazos.todos.size(), Tazos.libres(), Tazos.puntos,
		"al azar" if Tazos.rareza_forzada < 0 else TazoData.RAREZAS[Tazos.rareza_forzada]]
