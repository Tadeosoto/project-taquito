class_name Colonia
extends Node3D

# Una colonia del mapa hecho en Blender (tools/blender/mapa/, docs/mapa/tecnico.md): pone su
# .glb (geometria y cajas "-colonly", que Godot vuelve StaticBody3D en la capa 1) y arma lo de
# juego desde sus marcas (resources/mapa/<colonia>/marcas.json, escritas por exportar.py):
#   spawn   donde aparece el jugador. Se pone en _enter_tree, antes que nada lo lea: MapDron
#           toma la posicion del jugador en su _enter_tree y en su _ready lo aterriza debajo
#           del dron, y Supervivencia guarda ahi su punto de regreso. Por eso este nodo va
#           antes que el jugador, el dron y Supervivencia en la escena.
#   puerta  la flecha amarilla de un negocio o casa: al pisarla emite MapPuntos.entrar_negocio
#           con su giro, igual que YonkeMapa; su +Z da a la calle (ahi te deja Interiores al salir)
#   yonke   El Yonke de Don Chava (YonkeMapa, con su barda), con su +Z a la calle
#   casa_propia  la flecha de la casa del jugador (CasaPropia, la casa de JJ que se camina)
#   casa_vecino  la flecha de la casa de un vecino (CasaPropia con scenes/casas/<quien>.tscn)
#   reflector  una luz de reflector (los postes de la cancha) a la altura "y", viendo hacia su +Z
#           inclinada "baja" grados hacia el piso (negativo: hacia arriba, para un anuncio) y con
#           "alcance" m; se prende de noche con Ciclo.valor()
#   foco    un foco colgado de un cable en un callejon (los escribe exportar.py, no van en el
#           .json): luz chica y calida, de noche, y uno de cada FOCO_PARPADEA parpadea
#   mision  un punto con nombre para las misiones (Colonia.puntos_mision): donde se para el que
#           da una ("donde" de MisionData) o donde esta lo que hay que recoger
#   botin   algo en una azotea para el que sube (tambien de exportar.py): "que" es "chatarra"
#           (un monton de Chatarra), "bolsa" (Takis con tazo) o "curacion" (tacos o caguama)

const PUERTA_RADIO := 0.8
const CASA_PROPIA := preload("res://scripts/interiores/CasaPropia.gd")
const CASA_ESCENA := "res://scenes/casa_personaje.tscn"
const MUEBLES := preload("res://scripts/interiores/MueblesCasa.gd")
# Letrero del negocio: arriba de la puerta y casi contra la fachada (la marca va 0.8 m delante)
const LETRERO_ALTO := 3.0
const LETRERO_ATRAS := 0.7
const LETRERO_LEJOS := 60.0
const LETRERO_COLOR := Color(1.0, 0.92, 0.55)

@export var modelo: PackedScene
@export_file("*.json") var marcas_path := ""
# MapPuntos: Interiores escucha su señal entrar_negocio
@export var puntos_path: NodePath
@export var jugador_path: NodePath

# Marcas "mision" de la colonia cargada: nombre -> Transform3D (MisionesMundo las busca como
# "marca:<nombre>"). Se llenan en _enter_tree, antes que Partida arme MisionesMundo
static var puntos_mision := {}

var _puntos: MapPuntos
var _marcas: Array = []
var _reflectores: Array[Light3D] = []
var _energias: Array[float] = []      # la de cada luz de _reflectores, de noche
var _parpadean: Array[bool] = []
var _ciclo: Node

# Reflectores (marca "reflector"): luz calida sin sombra, como los de la cancha de la foto
const REFLECTOR_ENERGIA := 4.0
const REFLECTOR_ALCANCE := 24.0
const REFLECTOR_ANGULO := 55.0
const REFLECTOR_COLOR := Color(1.0, 0.93, 0.78)
const FOCO_ENERGIA := 1.6
const FOCO_ALCANCE := 6.0
const FOCO_COLOR := Color(1.0, 0.8, 0.5)
const FOCO_PARPADEA := 4
const BOTIN_BOLSA := "res://resources/productos/takis_tazo.tres"
const BOTIN_CURACION := ["res://resources/productos/tacos.tres", "res://resources/productos/caguama.tres"]


func _enter_tree() -> void:
	var datos = JSON.parse_string(FileAccess.get_file_as_string(marcas_path))
	if not datos is Dictionary:
		push_warning("Colonia: no se pudo leer %s" % marcas_path)
		return
	_marcas = datos.get("marcas", [])
	puntos_mision.clear()
	for marca: Dictionary in _marcas:
		if marca.get("tipo") == "spawn":
			_spawn(marca)
		elif marca.get("tipo") == "mision":
			puntos_mision[String(marca.get("nombre", ""))] = lugar(marca)


func _ready() -> void:
	add_to_group("colonia")
	_puntos = get_node_or_null(puntos_path) as MapPuntos
	if modelo:
		add_child(modelo.instantiate())
	for marca: Dictionary in _marcas:
		match String(marca.get("tipo", "")):
			"spawn", "mision":
				pass
			"puerta":
				_puerta(marca)
			"yonke":
				_yonke(marca)
			"casa_propia":
				_casa_propia(marca)
			"casa_vecino":
				_casa_vecino(marca)
			"reflector":
				_reflector(marca)
			"foco":
				_foco(marca)
			"botin":
				_botin(marca)
			var otro:
				push_warning("Colonia: marca %s de tipo desconocido '%s'" % [marca.get("nombre", "?"), otro])


	set_process(not _reflectores.is_empty())


# Los reflectores siguen a Ciclo.valor() (0 de dia, 1 de noche), asi se prenden al oscurecer
func _process(_delta: float) -> void:
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
		if _ciclo == null:
			return
	var noche := float(_ciclo.valor())
	var t := Time.get_ticks_msec() / 1000.0
	for i in _reflectores.size():
		var energia := _energias[i] * noche
		if _parpadean[i] and energia > 0.0:
			# Foco que falla: casi siempre prendido, con cortes cortos e irregulares
			var n := sin(t * 23.0 + i * 7.1) + sin(t * 3.7 + i * 1.3)
			if n > 1.55:
				energia *= 0.08
		_reflectores[i].light_energy = energia
		_reflectores[i].visible = energia > 0.01


func _reflector(marca: Dictionary) -> void:
	var luz := SpotLight3D.new()
	luz.name = String(marca.get("nombre", "Reflector"))
	luz.spot_range = float(marca.get("alcance", REFLECTOR_ALCANCE))
	luz.spot_angle = REFLECTOR_ANGULO
	luz.light_color = REFLECTOR_COLOR
	luz.shadow_enabled = false
	luz.visible = false
	# La luz ve hacia su -Z: se voltea para que vea al +Z de la marca y se baja "baja" grados
	var t := lugar(marca)
	t.basis = t.basis * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -deg_to_rad(float(marca.get("baja", 35.0))))
	luz.transform = t
	add_child(luz)
	_agregar_luz(luz, REFLECTOR_ENERGIA, false)


func _foco(marca: Dictionary) -> void:
	var luz := OmniLight3D.new()
	luz.name = String(marca.get("nombre", "Foco"))
	luz.omni_range = FOCO_ALCANCE
	luz.light_color = FOCO_COLOR
	luz.shadow_enabled = false
	luz.visible = false
	luz.transform = lugar(marca)
	add_child(luz)
	_agregar_luz(luz, FOCO_ENERGIA, _reflectores.size() % FOCO_PARPADEA == 1)


func _botin(marca: Dictionary) -> void:
	var que := String(marca.get("que", "chatarra"))
	var nodo: Node3D
	if que == "chatarra":
		nodo = Chatarra.new()
	else:
		var ruta: String = BOTIN_BOLSA if que == "bolsa" else BOTIN_CURACION[_marcas.find(marca) % BOTIN_CURACION.size()]
		nodo = load("res://scripts/WorldItem.gd").new()
		nodo.set("item_data", load(ruta))
	nodo.name = String(marca.get("nombre", "Botin"))
	var t := lugar(marca)
	if que != "chatarra":
		t.origin.y += 0.5          # WorldItem se pone a media altura, como los de Partida
	nodo.transform = t
	add_child(nodo)


func _agregar_luz(luz: Light3D, energia: float, parpadea: bool) -> void:
	_reflectores.append(luz)
	_energias.append(energia)
	_parpadean.append(parpadea)


static func lugar(marca: Dictionary) -> Transform3D:
	var base := Basis(Vector3.UP, float(marca.get("rot", 0.0)))
	return Transform3D(base, Vector3(float(marca["x"]), float(marca.get("y", 0.0)), float(marca["z"])))


func _spawn(marca: Dictionary) -> void:
	var jugador := get_node_or_null(jugador_path) as Node3D
	if jugador == null:
		return
	var donde := lugar(marca)
	# El origen del jugador esta a 1 m del piso (su capsula mide 2 m). Todavia no entra al
	# arbol, asi que se pone en el espacio de su padre
	var mundo := Transform3D(donde.basis, donde.origin + Vector3.UP * 1.2)
	var padre := jugador.get_parent() as Node3D
	jugador.transform = padre.global_transform.affine_inverse() * mundo if padre and padre.is_inside_tree() else mundo


# La casa del jugador (la de JJ: scenes/casa_personaje.tscn, CasaPropia.gd): se camina, sin
# pelea, y se entra tambien de noche. Su flecha es la marca (+Z hacia donde te deja al salir)
func _casa_propia(marca: Dictionary) -> void:
	var casa: Node = CASA_PROPIA.new()
	casa.name = "CasaPropia"
	casa.set("escena", load(CASA_ESCENA))
	casa.set("flecha_en", Vector3(float(marca["x"]), float(marca.get("y", 0.0)), float(marca["z"])))
	casa.set("calle_giro", float(marca.get("rot", 0.0)))
	casa.set("nombre", String(marca.get("texto", "Tu casa")))
	casa.set("muebles", MUEBLES)
	var jugador := get_node_or_null(jugador_path)
	if jugador:
		casa.set("player_path", jugador.get_path())
	var zombis := get_parent().get_node_or_null("Zombis")
	if zombis:
		casa.set("zombis_path", zombis.get_path())
	add_child(casa)


# Las casas de los vecinos (scenes/casas/*.tscn, CasaVecino.gd): se entran como la del jugador,
# sin muebles que se usen; `abierto` (siempre, noche, dia) y su escena vienen en la marca
func _casa_vecino(marca: Dictionary) -> void:
	var casa: Node = CASA_PROPIA.new()
	casa.name = String(marca.get("nombre", "CasaVecino"))
	casa.set("escena", load(String(marca["escena"])))
	casa.set("flecha_en", Vector3(float(marca["x"]), float(marca.get("y", 0.0)), float(marca["z"])))
	casa.set("calle_giro", float(marca.get("rot", 0.0)))
	casa.set("nombre", String(marca.get("texto", "Casa")))
	casa.set("abierto", String(marca.get("abierto", "siempre")))
	casa.set("texto_cerrado", String(marca.get("cerrado", "Nadie abre.")))
	var jugador := get_node_or_null(jugador_path)
	if jugador:
		casa.set("player_path", jugador.get_path())
	var zombis := get_parent().get_node_or_null("Zombis")
	if zombis:
		casa.set("zombis_path", zombis.get_path())
	add_child(casa)


func _yonke(marca: Dictionary) -> void:
	var yonke := YonkeMapa.new()
	yonke.name = "Yonke"
	yonke.transform = lugar(marca)
	yonke.con_barda = true
	if _puntos:
		yonke.puntos_path = _puntos.get_path()
	add_child(yonke)


func _puerta(marca: Dictionary) -> void:
	var giro := String(marca.get("giro", ""))
	var texto := String(marca.get("texto", giro.capitalize()))
	var area := Area3D.new()
	area.name = String(marca.get("nombre", "Puerta"))
	area.transform = lugar(marca)
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = PUERTA_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	# El mismo civil atiende siempre (Interiores lo lee de aqui)
	area.set_meta("civil", MapPuntos.civil({"origen": texto}))
	# El letrero arriba de la puerta, contra la fachada (la flecha esta PUERTA_AFUERA delante)
	if marca.get("letrero", true) and giro != "punto":
		var letrero := Label3D.new()
		letrero.text = texto.to_upper()
		letrero.font_size = 48
		letrero.pixel_size = 0.01
		letrero.modulate = LETRERO_COLOR
		letrero.outline_size = 10
		letrero.position = Vector3(0.0, LETRERO_ALTO, -LETRERO_ATRAS)
		letrero.visibility_range_end = LETRERO_LEJOS
		area.add_child(letrero)
	add_child(area)
	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo is Player and _puntos:
			_puntos.entrar_negocio.emit(giro, giro, texto, false, area))
