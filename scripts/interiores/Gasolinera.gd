@tool
class_name Gasolinera
extends Interior

# La escena del surtidor de la gasolinera (JJ, 2026-11-10): al pisar la flecha amarilla que hay junto a
# la bomba (MapPuntos._marcadores_gasolinera) la camara cambia de angulo y el despachador te ensena
# lo que vende: gasolina de limon (verde) y de cereza (roja, 25 % mas cara), por llenarte una botella
# vacia (`InventoryItemData.requiere`, Interior._comprar). No es un cuarto: es el pedazo de la isla
# bajo el techo de la estacion, abierto a los lados. Se arma en codigo (como Refrigerador o Mesa), con
# la base de Interior (camara, tienda, compra); su `Vendedor` es el despachador, que MapPuntos pone al
# mismo civil que vio afuera junto a la bomba.
#
# Coordenadas como las de Interior: camara en +Z viendo hacia -Z, piso en y = 0; el surtidor en
# `bomba_x`, `BOMBA_Z`, de frente a la camara, y el despachador a su izquierda.

const VERDE := Color(0.3, 0.95, 0.12)        # la manguera y la luz del limon
const ROJO := Color(0.95, 0.1, 0.12)         # y las de la cereza
const TEAL := Color(0.06, 0.55, 0.28)        # el verde de las barras del modelo de la estacion (MapPuntos)
const BLANCO_PEMEX := Color(0.95, 0.95, 0.93)
const CONCRETO := Color(0.66, 0.65, 0.63)
const TECHO_ALTO := 3.9
const ISLA_ALTO := 0.15
const BOMBA_Z := -1.9
const COLUMNA := 0.4
const SEGMENTOS_MANGUERA := 8

@export var bomba_x := 0.85


# Se arma todo en codigo y no hay cuarto (Interior.generar_local no aplica)
func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _local:
		_local.queue_free()
	_foco_luz = null
	_local = Node3D.new()
	_local.name = "_Local"
	add_child(_local, false, Node.INTERNAL_MODE_FRONT)
	_suelo()
	_techo()
	_fondo()
	_surtidor(Vector3(bomba_x, ISLA_ALTO, BOMBA_Z), true)
	# Otra isla mas atras, para que se sienta la estacion
	_isla(Vector3(-1.2, 0.0, -7.2), 5.6)
	_surtidor(Vector3(-2.3, ISLA_ALTO, -7.2), false)
	_surtidor(Vector3(0.1, ISLA_ALTO, -7.2), false)
	_luz_dia()


func _liso(color: Color, brilla := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if brilla:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _cilindro(radio: float, largo: float, desde: Vector3, hasta: Vector3, material: Material) -> MeshInstance3D:
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = maxf(largo, 0.001)
	malla.radial_segments = 8
	malla.rings = 1
	malla.material = material
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	var dir := (hasta - desde).normalized()
	var giro := Quaternion(Vector3.UP, dir) if dir.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	instancia.transform = Transform3D(Basis(giro), (desde + hasta) / 2.0)
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_local.add_child(instancia)
	return instancia


# El piso: la isla de concreto levantada para la bomba, y alrededor el asfalto donde se paran los
# carros, con una raya amarilla en la orilla de la isla
func _suelo() -> void:
	var asfalto := ShaderMaterial.new()
	asfalto.shader = SUELO_SHADER
	asfalto.set_shader_parameter("albedo_texture", ASFALTO_TEXTURA)
	asfalto.set_shader_parameter("tile_size", 3.0)
	asfalto.set_shader_parameter("piso_tipo", 1)
	_caja(Vector3(24.0, GROSOR, 22.0), Vector3(0, -GROSOR / 2.0, -3.0), asfalto)
	_isla(Vector3(0.3, 0.0, BOMBA_Z), 4.6)


# Una isla de concreto de `ancho` m centrada en `centro`, con los bolardos en las puntas
func _isla(centro: Vector3, ancho: float) -> void:
	var fondo_isla := 1.7
	_caja(Vector3(ancho, ISLA_ALTO, fondo_isla), Vector3(centro.x, ISLA_ALTO / 2.0, centro.z), _piso(CONCRETO))
	# La raya amarilla de la orilla, pintada encima
	_caja(Vector3(ancho, 0.01, 0.14), Vector3(centro.x, ISLA_ALTO + 0.005, centro.z + fondo_isla / 2.0 - 0.1), _material(Color(0.95, 0.8, 0.1), 0))
	for signo in [-1.0, 1.0]:
		var x: float = centro.x + signo * (ancho / 2.0 - 0.25)
		_caja(Vector3(0.26, 0.7, 0.26), Vector3(x, ISLA_ALTO + 0.35, centro.z), _material(BLANCO_PEMEX, 0))
		_caja(Vector3(0.27, 0.3, 0.27), Vector3(x, ISLA_ALTO + 0.75, centro.z), _material(TEAL, 0))


# El techo de la estacion: una losa oscura con su cara verde al frente, dos tiras de luz y las
# columnas blancas
func _techo() -> void:
	_caja(Vector3(24.0, 0.5, 22.0), Vector3(0, TECHO_ALTO + 0.25, -3.0), _material(Color(0.32, 0.32, 0.34), 1))
	# La cara verde del borde, de frente a la camara; se ve arriba si miras alto
	_caja(Vector3(24.0, 0.9, 0.3), Vector3(0, TECHO_ALTO - 0.15, 4.6), _material(TEAL, 0))
	var tubo := _liso(Color(1.0, 0.97, 0.88), true)
	for z in [0.4, -4.0]:
		_caja(Vector3(5.0, 0.06, 0.5), Vector3(0.3, TECHO_ALTO - 0.03, z), tubo)
		var luz := OmniLight3D.new()
		luz.position = Vector3(0.3, TECHO_ALTO - 0.6, z)
		luz.light_color = Color(1.0, 0.96, 0.86)
		luz.light_energy = 1.6
		luz.omni_range = 9.0
		luz.omni_attenuation = 0.7
		_local.add_child(luz)
	# Las columnas, a los lados de la isla, blancas con su banda verde abajo
	for x in [-3.6, 4.2]:
		_caja(Vector3(COLUMNA, TECHO_ALTO + 0.1, COLUMNA), Vector3(x, TECHO_ALTO / 2.0, BOMBA_Z - 0.2), _material(BLANCO_PEMEX, 0))
		_caja(Vector3(COLUMNA + 0.02, 0.45, COLUMNA + 0.02), Vector3(x, 0.4, BOMBA_Z - 0.2), _material(TEAL, 0))


# Atras, la tienda de la estacion (la del modelo del mapa): pared blanca, banda verde y los
# ventanales azules, con una luz suave para que no quede negra
func _fondo() -> void:
	var z := -10.5
	_caja(Vector3(24.0, 4.2, 0.4), Vector3(0, 2.1, z), _material(BLANCO_PEMEX, 2))
	_caja(Vector3(24.0, 0.5, 0.45), Vector3(0, 3.55, z + 0.03), _material(TEAL, 0))
	var vidrio := _liso(Color(0.1, 0.55, 0.85), true)
	for x in [-6.5, -2.2, 2.2, 6.5]:
		_caja(Vector3(3.4, 1.9, 0.05), Vector3(x, 1.65, z + 0.22), vidrio)
		_caja(Vector3(0.12, 1.95, 0.06), Vector3(x, 1.65, z + 0.23), _material(BLANCO_PEMEX, 0))
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 2.5, z + 3.0)
	luz.light_color = Color(0.85, 0.92, 1.0)
	luz.light_energy = 0.8
	luz.omni_range = 9.0
	_local.add_child(luz)


# Luz de dia que se cuela por los lados del techo (corriendo sola no hay sol)
func _luz_dia() -> void:
	# Una de relleno junto a la bomba, para que se le vean los colores a las mangueras
	var relleno := OmniLight3D.new()
	relleno.position = Vector3(bomba_x - 0.4, 2.2, BOMBA_Z + 2.6)
	relleno.light_color = Color(1.0, 0.97, 0.9)
	relleno.light_energy = 1.1
	relleno.omni_range = 5.5
	_local.add_child(relleno)
	var dia := OmniLight3D.new()
	dia.position = Vector3(0.0, 3.4, 4.0)
	dia.light_color = Color(1.0, 0.96, 0.88)
	dia.light_energy = 0.7
	dia.omni_range = 12.0
	dia.omni_attenuation = 0.6
	_local.add_child(dia)


# Un surtidor parado en `pie` (el piso de la isla), de frente a +Z: abajo verde, arriba
# blanco con su ventana oscura y, en la cabecera, los paneles de colores del modelo. Con `completo`
# lleva a los lados las dos mangueras: la verde (limon) a la izquierda y la roja (cereza) a la derecha
func _surtidor(pie: Vector3, completo: bool) -> void:
	var y := pie.y
	var x := pie.x
	var z := pie.z
	_caja(Vector3(1.0, 0.1, 0.66), Vector3(x, y + 0.05, z), _material(Color(0.2, 0.2, 0.22), 1))
	_caja(Vector3(0.9, 0.85, 0.56), Vector3(x, y + 0.525, z), _material(TEAL, 0))
	_caja(Vector3(0.9, 0.75, 0.5), Vector3(x, y + 1.33, z), _material(BLANCO_PEMEX, 0))
	# La ventana de los numeros y el cuadro de botones
	_caja(Vector3(0.62, 0.24, 0.02), Vector3(x, y + 1.5, z + 0.255), _material(Color(0.1, 0.1, 0.12), 0))
	var cifras := _liso(Color(0.35, 1.0, 0.3), true)
	for dx in [-0.16, 0.0, 0.16]:
		_caja(Vector3(0.1, 0.1, 0.01), Vector3(x + dx, y + 1.5, z + 0.268), cifras)
	for dx in [-0.21, -0.07, 0.07, 0.21]:
		_caja(Vector3(0.1, 0.08, 0.02), Vector3(x + dx, y + 1.15, z + 0.255), _material(Color(0.25, 0.25, 0.28), 0))
	# La cabecera verde con los paneles: el verde (limon) a la izquierda y el rojo (cereza) a la derecha
	_caja(Vector3(1.0, 0.3, 0.58), Vector3(x, y + 1.88, z), _material(TEAL, 0))
	_caja(Vector3(0.32, 0.18, 0.02), Vector3(x - 0.24, y + 1.88, z + 0.295), _liso(VERDE, true))
	_caja(Vector3(0.32, 0.18, 0.02), Vector3(x + 0.24, y + 1.88, z + 0.295), _liso(ROJO, true))
	if not completo:
		return
	for lado in [[-1.0, VERDE], [1.0, ROJO]]:
		var signo: float = lado[0]
		var color: Color = lado[1]
		var soporte := Vector3(x + signo * 0.5, y + 1.05, z + 0.08)
		# El soporte de la pistola y la pistola colgada en el
		_caja(Vector3(0.1, 0.3, 0.22), soporte, _material(Color(0.15, 0.15, 0.17), 0))
		var pistola := soporte + Vector3(signo * 0.1, -0.05, 0.0)
		_caja(Vector3(0.08, 0.26, 0.16), pistola, _liso(color))
		_cilindro(0.025, 0.2, pistola + Vector3(signo * 0.04, -0.05, 0.08), pistola + Vector3(signo * 0.04, -0.17, 0.2), _liso(Color(0.12, 0.12, 0.13)))
		# La manguera: de la pistola cae en curva hasta casi el piso y vuelve a la bomba
		_manguera(pistola + Vector3(0.0, -0.12, 0.0), Vector3(x + signo * 0.42, y + 0.55, z + 0.28), 0.5, color)


# Una manguera de `desde` a `hasta` que se descuelga `caida` m en medio
func _manguera(desde: Vector3, hasta: Vector3, caida: float, color: Color) -> void:
	var material := _liso(color.darkened(0.25))
	var anterior := desde
	for i in range(1, SEGMENTOS_MANGUERA + 1):
		var t := float(i) / SEGMENTOS_MANGUERA
		var punto := desde.lerp(hasta, t) + Vector3.DOWN * caida * sin(PI * t)
		_cilindro(0.03, anterior.distance_to(punto) + 0.01, anterior, punto, material)
		anterior = punto
