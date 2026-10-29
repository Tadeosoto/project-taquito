@tool
class_name Mostrador
extends Node3D

# Mostrador de un interior armado de cajas (no hay modelos que se parezcan), uno por
# estilo copiando las fotos de referencia del usuario:
#   vitrina     abarrotes: base blanca, filos azules, vitrina de vidrio iluminada con
#               dos repisas de mercancia
#   anaquel     OXO: cubierta blanca sobre anaqueles negros con filo rojo, llenos de
#               dulces y botanas viendo al cliente (tambien sirve de anaquel de pared)
#   panel       farmacia: frente azul con cubierta blanca y calcomanias de oferta
#   cajonera    ferreteria: vitrina con cubierta de vidrio y filo verde agua, adentro
#               una cuadricula de cajitas blancas con tornillos y piezas de colores
#   ventanilla  purificadora: repisa blanca en la ventana (la fachada, el anuncio y
#               lo demas de afuera los pone Interior.fachada_mapa)
#   puesto      taqueria: carrito de lamina en la banqueta con toldo de `color`, comal,
#               tabla con cebolla y cilantro y el trompo (Trompo.gd). El taquero
#               queda atras (-Z) y atiende hacia +Z
# El origen es el centro de su base y el frente ve a +Z (como Mueble y Refrigerador).

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
# Empaques de botanas, dulces, refrescos y medicinas
const EMPAQUES := [Color(0.95, 0.55, 0.1), Color(0.95, 0.85, 0.15), Color(0.85, 0.15, 0.12),
	Color(0.2, 0.35, 0.8), Color(0.25, 0.65, 0.25), Color(0.5, 0.2, 0.6), Color(0.95, 0.95, 0.92),
	Color(0.9, 0.4, 0.55)]
const BLANCO := Color(0.93, 0.93, 0.9)
# Etiquetas de la mercancia (tools/make_empaques.py): una fila del atlas por tipo
const EMPAQUE_SHADER := preload("res://shaders/ps1_empaque.gdshader")
const EMPAQUE_ATLAS := preload("res://textures/interiores/empaques.png")
const ETIQUETAS_POR_FILA := 8
enum { BOTANAS, ABARROTES, MEDICINAS, FERRETERIA }
# Piezas sueltas de mercancia, en metros y con la etiqueta hacia +Z; el prefijo del
# archivo es su categoria: el paquete "Comida Low Poly" (tools/map_import/
# separar_comida.gd), la ferreteria y la tiendita (separar_mercancia.gd)
const PIEZAS_DIRS := ["res://models/interiores/comida/piezas/", "res://models/interiores/ferreteria/piezas/",
	"res://models/interiores/tiendita/piezas/"]
# Que va en cada repisa con `con_modelos` (las medicinas no tienen)
const PIEZAS_DE := {
	BOTANAS: ["papas"],
	ABARROTES: ["cereal", "galletas", "aceite", "limpieza", "pan", "refresco"],
	FERRETERIA: ["pintura", "aerosol"],
}
# Charolas: siempre planas, una junto a otra
const SIN_APILAR := ["charola"]

# Categoria -> mallas, cargadas una vez para todos los muebles
static var _piezas := {}

@export_enum("vitrina", "anaquel", "panel", "cajonera", "ventanilla", "puesto") var estilo := 0:
	set(valor):
		estilo = valor
		_reconstruir()
@export var ancho := 2.2:
	set(valor):
		ancho = valor
		_reconstruir()
@export var alto := 1.0:
	set(valor):
		alto = valor
		_reconstruir()
@export var fondo := 0.6:
	set(valor):
		fondo = valor
		_reconstruir()
# Color principal: el azul de la farmacia, el filo de la vitrina, la lona...
@export var color := Color(0.12, 0.3, 0.75):
	set(valor):
		color = valor
		_reconstruir()
# Cuerpo de la vitrina (blanco; gris en los abarrotes)
@export var color_base := BLANCO:
	set(valor):
		color_base = valor
		_reconstruir()
# Texto de las calcomanias (panel)
@export var texto := "":
	set(valor):
		texto = valor
		_reconstruir()
@export var semilla := 0:
	set(valor):
		semilla = valor
		_reconstruir()
# Mercancia de modelos de comida en vez de empaques con etiqueta: charolas de carnes
# frias en la vitrina, abarrotes o papitas en las repisas (Estante)
@export var con_modelos := false:
	set(valor):
		con_modelos = valor
		_reconstruir()
# Visto de lejos (por la puerta de un local del mapa): sin piezas de comida ni
# adornos chicos, como la carita de la rejilla
var sencillo := false
# Con `con_modelos`: categorias de piezas que lleva (Mostrador.piezas); vacio = las
# de su `mercancia` (PIEZAS_DE) o, en el anaquel, dulces, papitas y galletas
@export var categorias := PackedStringArray():
	set(valor):
		categorias = valor
		_reconstruir()
# Pantalla del cajero sobre un poste blanco en la orilla derecha de la cubierta (OXO)
@export var caja_registradora := false:
	set(valor):
		caja_registradora = valor
		_reconstruir()
# Distancia de la pantalla a la orilla derecha (m); mas grande la acerca al vendedor
# Cuanto uso tienen las piezas de fierro/plastico (ps1_gastado; se le suma la zona)
@export_range(0.0, 1.0) var desgaste := 0.6:
	set(valor):
		desgaste = valor
		_reconstruir()
@export var caja_orilla := 0.35:
	set(valor):
		caja_orilla = valor
		_reconstruir()
# Puesto: la parrilla del trompo va del lado del taquero (-Z) y la carne se ve desde
# la calle (los puestos del mapa); si no, hacia el cliente (la escena de la taqueria,
# que ve el puesto desde atras)
@export var parrilla_atras := false:
	set(valor):
		parrilla_atras = valor
		_reconstruir()

var _partes: Node3D
var _rng := RandomNumberGenerator.new()
# Mercancia de modelos: malla -> transformaciones; al final un MultiMesh por malla
var _modelos := {}
# Empaques sueltos (posicion, tamano, color[, etiqueta del atlas[, giro]]): al final
# van en un solo MultiMesh. Etiqueta -1 = color liso (alambres, herramientas)
var _empaques: Array = []
static var _vidrios := {}   # apagado -> StandardMaterial3D


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return
	if _partes:
		_partes.queue_free()
	_partes = Node3D.new()
	add_child(_partes, false, Node.INTERNAL_MODE_FRONT)
	_rng.seed = hash([semilla, estilo, ancho])
	_empaques.clear()
	_modelos.clear()
	_armar()
	_multimesh()


# Estante.gd lo cambia por sus muebles de pared
func _armar() -> void:
	match estilo:
		0: _vitrina()
		1: _anaquel()
		2: _panel()
		3: _cajonera()
		4: _ventanilla()
		5: _puesto()


# Abarrotes: zoclo y base de `color_base` con filos de `color`; arriba la vitrina de vidrio con
# fondo de luz, dos repisas con mercancia y cubierta de vidrio con marco azul
func _vitrina() -> void:
	var z := fondo / 2
	var base := alto * 0.38
	var blanco := _ps1(color_base)
	var filo := _ps1(color)
	_caja(Vector3(ancho, base, fondo), Vector3(0, base / 2, 0), blanco)
	_caja(Vector3(ancho + 0.01, 0.05, fondo + 0.01), Vector3(0, base - 0.025, 0), filo)
	_caja(Vector3(ancho + 0.01, 0.04, fondo + 0.01), Vector3(0, 0.02, 0), _ps1(Color(0.25, 0.25, 0.28)))
	# Rejilla del motor del refrigerador
	_caja(Vector3(ancho * 0.5, base * 0.35, 0.01), Vector3(0, base * 0.45, z + 0.005), _ps1(Color(0.55, 0.57, 0.6)))
	var hueco := alto - base - 0.05
	var y0 := base
	_caja(Vector3(ancho, hueco, 0.02), Vector3(0, y0 + hueco / 2, -z + 0.01), _plano(Color(0.95, 0.95, 0.88)))
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.05, hueco, fondo), Vector3(signo * (ancho / 2 - 0.025), y0 + hueco / 2, 0), filo)
	var repisa := _ps1(Color(0.8, 0.82, 0.85))
	for i in 2:
		var y := y0 + 0.02 + hueco * i / 2.0
		_caja(Vector3(ancho - 0.1, 0.012, fondo - 0.08), Vector3(0, y, -0.02), repisa)
		if con_modelos and not Mostrador.piezas("charola").is_empty():
			# Abajo carnes frias y queso, arriba yogures, cremas y bebidas chicas
			var cosas := ["charola", "lacteo", "bote"] if i == 0 else ["bote", "lacteo", "refresco"]
			_fila_modelos(y + 0.006, ancho - 0.16, Vector2(-z + 0.2, z - 0.2), hueco / 2 - 0.05, cosas)
		else:
			_fila(y + 0.006, ancho - 0.16, Vector2(-z + 0.08, z - 0.12), Vector2(0.08, 0.16), 0.11, ABARROTES)
	# Marco azul arriba y el vidrio (frente y cubierta)
	_caja(Vector3(ancho, 0.05, 0.05), Vector3(0, alto - 0.025, z - 0.025), filo)
	_caja(Vector3(ancho, 0.05, 0.05), Vector3(0, alto - 0.025, -z + 0.025), filo)
	var vidrio := _vidrio()
	_caja(Vector3(ancho - 0.1, hueco - 0.05, 0.01), Vector3(0, y0 + hueco / 2, z - 0.01), vidrio)
	_caja(Vector3(ancho - 0.1, 0.01, fondo - 0.1), Vector3(0, alto - 0.01, 0), vidrio)
	# Tira de luz bajo el marco
	_caja(Vector3(ancho - 0.12, 0.015, 0.02), Vector3(0, alto - 0.06, z - 0.05), _plano(Color(1, 1, 0.95)))


# OXO: cubierta blanca y, abajo, anaqueles negros con filo rojo llenos de dulces
func _anaquel() -> void:
	var z := fondo / 2
	var cubierta := 0.05
	var negro := _ps1(Color(0.07, 0.07, 0.08))
	var rojo := _ps1(Color(0.8, 0.1, 0.1))
	_caja(Vector3(ancho + 0.06, cubierta, fondo + 0.08), Vector3(0, alto - cubierta / 2, 0.02), _ps1(Color(0.92, 0.9, 0.85)))
	var hueco := alto - cubierta
	_caja(Vector3(ancho, hueco, 0.03), Vector3(0, hueco / 2, -z + 0.015), negro)
	_caja(Vector3(ancho, 0.1, fondo), Vector3(0, 0.05, 0), negro)
	# Postes cada ~1 m
	var tramos := maxi(1, roundi(ancho / 1.0))
	for i in tramos + 1:
		var x := -ancho / 2 + ancho * i / tramos
		_caja(Vector3(0.04, hueco, fondo), Vector3(clampf(x, -ancho / 2 + 0.02, ancho / 2 - 0.02), hueco / 2, 0), negro)
	var niveles := maxi(2, roundi((hueco - 0.1) / 0.3))
	var paso := (hueco - 0.1) / niveles
	for i in niveles:
		var y := 0.1 + paso * i
		_caja(Vector3(ancho, 0.02, fondo - 0.03), Vector3(0, y, 0.0), negro)
		# Filo rojo con el precio
		_caja(Vector3(ancho, 0.045, 0.01), Vector3(0, y + 0.012, z + 0.005), rojo)
		if con_modelos:
			var cosas := categorias if not categorias.is_empty() else PackedStringArray(["dulce", "papas", "galletas"])
			_fila_modelos(y + 0.01, ancho - 0.08, Vector2(-z + 0.08, z - 0.08), paso - 0.06, Array(cosas))
		else:
			_fila(y + 0.01, ancho - 0.08, Vector2(-z + 0.06, z - 0.06), Vector2(minf(0.12, paso * 0.45), minf(0.24, paso - 0.06)), 0.13, BOTANAS)
	if caja_registradora:
		_caja_registradora(Vector3(ancho / 2 - caja_orilla, alto, 0.0))


# Pantalla del punto de venta: poste blanco, monitor negro viendo al cajero (-Z) con
# la pantalla prendida, y la terminal de tarjetas; el monitor de espaldas al cliente
# deja ver su carcasa, como en el OXO
func _caja_registradora(base: Vector3) -> void:
	var blanco := _ps1(Color(0.85, 0.85, 0.82))
	var negro := _ps1(Color(0.08, 0.08, 0.09))
	_caja(Vector3(0.12, 0.35, 0.12), base + Vector3(0, 0.175, 0), blanco)
	_caja(Vector3(0.3, 0.03, 0.22), base + Vector3(0, 0.36, 0), blanco)
	var monitor := base + Vector3(0, 0.55, 0)
	_caja(Vector3(0.36, 0.28, 0.06), monitor, negro)
	_caja(Vector3(0.05, 0.12, 0.04), monitor + Vector3(0, -0.17, 0.0), negro)
	# Pantalla hacia el cajero: fondo azul con renglones de la venta
	_caja(Vector3(0.31, 0.22, 0.005), monitor + Vector3(0, 0, -0.032), _plano(Color(0.12, 0.2, 0.35)))
	for i in 5:
		_caja(Vector3(0.24 - 0.03 * (i % 3), 0.018, 0.004), monitor + Vector3(-0.02, 0.07 - i * 0.035, -0.036), _plano(Color(0.55, 0.65, 0.75)))
	# Terminal de tarjetas y el letrero de caja
	_caja(Vector3(0.08, 0.04, 0.15), base + Vector3(-0.3, 0.02, 0.12), negro)
	_caja(Vector3(0.06, 0.005, 0.05), base + Vector3(-0.3, 0.043, 0.14), _plano(Color(0.3, 0.45, 0.35)))
	_caja(Vector3(0.24, 0.07, 0.01), base + Vector3(0, 0.3, 0.065), _plano(Color(0.9, 0.9, 0.88)))
	_letrero("Caja", base + Vector3(0, 0.3, 0.072), 0.12, Color(0.15, 0.15, 0.2))


# Farmacia: cuerpo azul con cubierta blanca, una franja blanca y calcomanias rojas de
# oferta al frente
func _panel() -> void:
	var z := fondo / 2
	_caja(Vector3(ancho, alto - 0.05, fondo), Vector3(0, (alto - 0.05) / 2, 0), _ps1(color))
	_caja(Vector3(ancho + 0.08, 0.05, fondo + 0.1), Vector3(0, alto - 0.025, 0.03), _ps1(BLANCO))
	_caja(Vector3(ancho + 0.005, 0.04, fondo + 0.005), Vector3(0, alto - 0.12, 0), _ps1(BLANCO))
	_caja(Vector3(ancho + 0.005, 0.06, fondo + 0.005), Vector3(0, 0.03, 0), _ps1(color.darkened(0.5)))
	var calcomanias := maxi(1, int(ancho / 1.1))
	for i in calcomanias:
		var x := -ancho / 2 + ancho * (i + 0.5) / calcomanias
		var radio := minf(0.24, alto * 0.25)
		var centro := Vector3(x, alto * 0.42, z + 0.006)
		_disco(radio, centro, Color(0.82, 0.12, 0.15))
		_disco(radio * 0.82, centro + Vector3(0, 0, 0.002), Color(0.95, 0.95, 0.92))
		_disco(radio * 0.7, centro + Vector3(0, 0, 0.004), Color(0.82, 0.12, 0.15))
		_letrero(texto if texto != "" else "HASTA\n75%", centro + Vector3(0, 0, 0.01), radio * 0.9, Color.WHITE)
	# Monitor de la caja y el gel
	var negro := _ps1(Color(0.08, 0.08, 0.09))
	_caja(Vector3(0.5, 0.32, 0.04), Vector3(-ancho * 0.3, alto + 0.27, -0.05), negro)
	_caja(Vector3(0.06, 0.12, 0.06), Vector3(-ancho * 0.3, alto + 0.06, -0.05), negro)
	_caja(Vector3(0.06, 0.16, 0.06), Vector3(ancho / 2 - 0.2, alto + 0.08, 0.05), _vidrio())
	# Letrerito de atencion al publico, a la derecha
	var cartel := Vector3(ancho / 2 - 0.25, alto * 0.62, z + 0.006)
	_caja(Vector3(0.36, 0.14, 0.004), cartel, _plano(Color(0.95, 0.95, 0.95)))
	_letrero("ATENCIÓN AL\nPÚBLICO", cartel + Vector3(0, 0, 0.004), 0.3, color.darkened(0.3))


# Ferreteria: vitrina de piso con cubierta de vidrio y filo verde agua; adentro, una
# cuadricula de cajitas blancas abiertas con piezas de colores
func _cajonera() -> void:
	var z := fondo / 2
	var filo := _ps1(Color(0.25, 0.6, 0.6))
	var marco := _ps1(Color(0.82, 0.84, 0.86))
	_caja(Vector3(ancho, 0.08, fondo), Vector3(0, 0.04, 0), _ps1(Color(0.3, 0.3, 0.32)))
	# Sin luz propia: el fondo y el vidrio se ven con la luz del cuarto
	_caja(Vector3(ancho, alto - 0.08, 0.02), Vector3(0, alto / 2, -z + 0.01), _ps1(Color(0.62, 0.64, 0.66)))
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.03, alto, fondo), Vector3(signo * (ancho / 2 - 0.015), alto / 2, 0), marco)
	var columnas := maxi(2, int(ancho / 0.24))
	var filas := maxi(2, int((alto - 0.15) / 0.24))
	var celda := Vector2((ancho - 0.06) / columnas, (alto - 0.14) / filas)
	var caja_blanca := _ps1(Color(0.7, 0.7, 0.68))
	for f in filas:
		var y := 0.09 + celda.y * f
		_caja(Vector3(ancho - 0.06, 0.012, fondo - 0.04), Vector3(0, y, 0), marco)
		for c in columnas:
			var x := -ancho / 2 + 0.03 + celda.x * (c + 0.5)
			var tam := Vector3(celda.x - 0.03, celda.y * 0.55, fondo * 0.7)
			# Cajita abierta: fondo, lados y frente bajito
			_caja(Vector3(tam.x, 0.01, tam.z), Vector3(x, y + 0.012, 0), caja_blanca)
			_caja(Vector3(tam.x, tam.y * 0.6, 0.01), Vector3(x, y + tam.y * 0.3, tam.z / 2), caja_blanca)
			_caja(Vector3(tam.x, tam.y, 0.01), Vector3(x, y + tam.y / 2, -tam.z / 2), caja_blanca)
			# Piezas: un monton bajito de un color metalico o de color
			if _rng.randf() < 0.85:
				var tinte: Color = Color(0.6, 0.6, 0.62) if _rng.randf() < 0.5 else EMPAQUES[_rng.randi() % EMPAQUES.size()]
				_empaques.append([Vector3(x, y + 0.012 + tam.y * 0.18, 0.0), Vector3(tam.x - 0.02, tam.y * 0.35, tam.z - 0.03), tinte])
	# Cubierta y frente de vidrio con su filo
	var vidrio := _vidrio(true)
	_caja(Vector3(ancho - 0.04, alto - 0.12, 0.01), Vector3(0, alto / 2 + 0.02, z - 0.005), vidrio)
	_caja(Vector3(ancho, 0.015, fondo), Vector3(0, alto - 0.0075, 0), vidrio)
	_caja(Vector3(ancho + 0.01, 0.03, 0.03), Vector3(0, alto - 0.015, z - 0.015), filo)
	_caja(Vector3(ancho + 0.01, 0.03, 0.03), Vector3(0, 0.095, z - 0.015), filo)


# Purificadora: la ventana tiene una repisa blanca; abajo, muro blanco con una lona
# colgada (gota de agua y el texto), y en la banqueta una banca azul sobre piso de
# cuadros
func _ventanilla() -> void:
	_caja(Vector3(ancho, alto - 0.05, fondo), Vector3(0, (alto - 0.05) / 2, 0), _ps1(Color(0.95, 0.95, 0.93)))
	# Repisa que sale por la ventana hacia la banqueta
	_caja(Vector3(ancho + 0.1, 0.05, fondo + 0.45), Vector3(0, alto - 0.025, 0.2), _ps1(Color(0.85, 0.86, 0.88)))


# Taqueria: carrito de lamina, toldo, comal y trompo. Lo ve uno desde atras, del lado
# del taquero (-Z): ahi van la tabla, los botes y la canasta de tortillas
func _puesto() -> void:
	var z := fondo / 2
	var lamina := _ps1(Color(0.66, 0.67, 0.69))
	var oscuro := _ps1(Color(0.3, 0.3, 0.32))
	_caja(Vector3(ancho, alto - 0.04, fondo), Vector3(0, (alto - 0.04) / 2, 0), lamina)
	_caja(Vector3(ancho + 0.06, 0.04, fondo + 0.06), Vector3(0, alto - 0.02, 0), _ps1(Color(0.78, 0.79, 0.8)))
	# Repisa del lado del taquero con botes y la canasta de tortillas
	_caja(Vector3(ancho - 0.1, alto * 0.55, 0.02), Vector3(0, alto * 0.35, -z - 0.005), oscuro)
	_caja(Vector3(ancho - 0.1, 0.02, 0.2), Vector3(0, alto * 0.62, -z - 0.1), lamina)
	for i in 3:
		_cilindro(0.09, 0.08, 0.16, Vector3(-ancho * 0.3 + i * 0.25, alto * 0.63 + 0.08, -z - 0.1), _ps1([Color(0.9, 0.9, 0.88), Color(0.85, 0.3, 0.15), Color(0.2, 0.5, 0.75)][i]))
	_caja(Vector3(ancho, 0.06, 0.04), Vector3(0, 0.03, z + 0.02), oscuro)
	# Comal a la izquierda con carne picada
	var comal := Vector3(-ancho * 0.28, alto, -0.02)
	_cilindro(0.3, 0.27, 0.04, comal + Vector3(0, 0.02, 0), _ps1(Color(0.12, 0.12, 0.12)))
	var humo := Trompo.humo(Vector3(0.2, 0.02, 0.2), 18)
	humo.position = comal + Vector3(0, 0.08, 0)
	_partes.add_child(humo)
	for i in 14:
		var p := comal + Vector3(_rng.randf_range(-0.2, 0.2), 0.045, _rng.randf_range(-0.2, 0.2))
		_empaques.append([p, Vector3(0.04, 0.012, 0.03), Color(0.62, 0.22, 0.08).lerp(Color(0.3, 0.12, 0.05), _rng.randf()), -1])
	# Tabla con cebolla y cilantro, y las tortillas
	var tabla := Vector3(0.05, alto + 0.015, -z + 0.18)
	_caja(Vector3(0.4, 0.025, 0.26), tabla, _ps1(Color(0.62, 0.45, 0.28)))
	_cilindro(0.06, 0.05, 0.04, tabla + Vector3(-0.1, 0.03, 0), _ps1(Color(0.92, 0.92, 0.88)))
	_cilindro(0.06, 0.05, 0.04, tabla + Vector3(0.06, 0.03, 0), _ps1(Color(0.25, 0.5, 0.18)))
	_cilindro(0.1, 0.1, 0.06, Vector3(0.05, alto + 0.03, z - 0.17), _ps1(Color(0.92, 0.85, 0.6)))
	# Trompo a la derecha, con la parrilla hacia el cliente o hacia el taquero
	var trompo := Trompo.new()
	trompo.position = Vector3(ancho * 0.3, alto, 0.0)
	if parrilla_atras:
		trompo.rotation.y = PI
	trompo.semilla = semilla
	_partes.add_child(trompo)
	# Toldo: postes en las esquinas, lona y faldones
	var poste := _ps1(Color(0.5, 0.5, 0.52))
	var alto_toldo := 2.15
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caja(Vector3(0.035, alto_toldo, 0.035), Vector3(sx * (ancho / 2 - 0.02), alto_toldo / 2, sz * (z - 0.02)), poste)
	var lona := _ps1(color)
	lona.set_shader_parameter("metal", false)
	_caja(Vector3(ancho + 0.5, 0.03, fondo + 0.7), Vector3(0, alto_toldo + 0.015, 0), lona)
	var blanco := _ps1(BLANCO)
	blanco.set_shader_parameter("metal", false)
	for sz in [-1.0, 1.0]:
		var zf: float = sz * (z + 0.35)
		_caja(Vector3(ancho + 0.5, 0.22, 0.01), Vector3(0, alto_toldo - 0.11, zf), lona)
		# Franjas blancas abajo del faldon
		var franjas := 8
		for i in franjas:
			_caja(Vector3((ancho + 0.5) / franjas * 0.5, 0.06, 0.012), Vector3(-(ancho + 0.5) / 2 + (ancho + 0.5) * (i + 0.25) / franjas, alto_toldo - 0.19, zf), blanco)
	# Foco pelon colgando del toldo
	_caja(Vector3(0.005, 0.3, 0.005), Vector3(-0.1, alto_toldo - 0.15, 0), oscuro)
	_caja(Vector3(0.06, 0.08, 0.06), Vector3(-0.1, alto_toldo - 0.33, 0), _plano(Color(1, 0.95, 0.75)))
	var luz := OmniLight3D.new()
	luz.light_color = Color(1, 0.88, 0.65)
	luz.light_energy = 0.5
	luz.omni_range = 3.0
	luz.position = Vector3(-0.1, alto_toldo - 0.45, 0)
	_partes.add_child(luz)


func _cilindro(arriba: float, abajo: float, alto_c: float, pos: Vector3, material: Material) -> void:
	var malla := CylinderMesh.new()
	malla.top_radius = arriba
	malla.bottom_radius = abajo
	malla.height = alto_c
	malla.radial_segments = 12
	malla.rings = 1
	malla.material = material
	_malla(malla, pos, Vector3.ONE)


# Una fila de empaques parados sobre una repisa a la altura `y`, de -ancho/2 a ancho/2,
# en dos hileras entre z.x y z.y (atras y adelante), en bloques del mismo empaque con
# etiquetas de la fila `tipo` del atlas
func _fila(y: float, largo: float, z: Vector2, tam: Vector2, paso: float, tipo: int) -> void:
	var cuantos := int(largo / paso)
	var bloque := 0
	var etiqueta := 0
	var dims: Vector3
	for i in cuantos:
		if bloque == 0:
			bloque = _rng.randi_range(2, 4)
			etiqueta = _etiqueta(tipo)
			dims = Vector3(paso * _rng.randf_range(0.7, 0.9), _rng.randf_range(tam.x, tam.y), _rng.randf_range(0.05, 0.1))
		bloque -= 1
		if _rng.randf() < 0.07:
			continue
		var x := -largo / 2 + paso * (i + 0.5)
		for hilera in [z.x, z.y]:
			_empaques.append([Vector3(x, y + dims.y / 2, hilera), dims, Color.WHITE.darkened(0.2 if hilera == z.x else 0.0), etiqueta])


# Como _fila pero con piezas de comida de `categorias`: cada pieza a su tamano, una
# junto a otra, en bloques de la misma pieza; solo las que caben en `alto_max` (si
# ninguna cabe, encogidas). Las chaparras (paquetitos de galletas, latas, yogures) se
# apilan hasta llenar la altura, menos las de SIN_APILAR
func _fila_modelos(y: float, largo: float, z: Vector2, alto_max: float, categorias: Array) -> void:
	var mallas := []
	var todas := []
	var planas := []
	for categoria in categorias:
		todas.append_array(Mostrador.piezas(categoria))
		if categoria in SIN_APILAR:
			planas.append_array(Mostrador.piezas(categoria))
	for malla in todas:
		if malla.get_aabb().size.y <= alto_max:
			mallas.append(malla)
	if mallas.is_empty():
		mallas = todas
	if mallas.is_empty():
		return
	var x := -largo / 2
	var bloque := 0
	var malla: Mesh
	var escala := 1.0
	var paso := 0.0
	var pila := 1
	var alto_pieza := 0.0
	var intentos := 0
	while true:
		if bloque == 0:
			bloque = _rng.randi_range(2, 4)
			malla = mallas[_rng.randi() % mallas.size()]
			var caja := malla.get_aabb()
			escala = minf(1.0, alto_max / caja.size.y)
			paso = caja.size.x * escala + 0.008
			alto_pieza = caja.size.y * escala
			pila = clampi(int(alto_max * 0.8 / alto_pieza), 1, 6) if alto_pieza < alto_max * 0.45 and not malla in planas else 1
		if x + paso > largo / 2:
			# Al final de la repisa: otra pieza mas angosta, si hay
			intentos += 1
			if intentos > 8:
				break
			bloque = 0
			continue
		bloque -= 1
		if _rng.randf() >= 0.07:
			var cuantos := _rng.randi_range(maxi(1, pila - 1), pila)
			for hilera in [z.x, z.y]:
				for nivel in cuantos:
					_modelo(malla, Transform3D(Basis.from_scale(Vector3.ONE * escala), Vector3(x + paso / 2, y + nivel * alto_pieza, hilera)))
		x += paso


func _modelo(malla: Mesh, xform: Transform3D) -> void:
	if not _modelos.has(malla):
		_modelos[malla] = []
	_modelos[malla].append(xform)


static func piezas(categoria: String) -> Array:
	if _piezas.is_empty():
		for carpeta in PIEZAS_DIRS:
			for archivo in ResourceLoader.list_directory(carpeta):
				if archivo.ends_with(".res"):
					var clave := archivo.get_slice("_", 0)
					if not _piezas.has(clave):
						_piezas[clave] = []
					_piezas[clave].append(load(carpeta + archivo))
	return _piezas.get(categoria, [])


func _etiqueta(tipo: int) -> int:
	return tipo * ETIQUETAS_POR_FILA + _rng.randi() % ETIQUETAS_POR_FILA


func _multimesh() -> void:
	for malla in _modelos:
		var lista: Array = _modelos[malla]
		var multi_modelo := MultiMesh.new()
		multi_modelo.transform_format = MultiMesh.TRANSFORM_3D
		multi_modelo.mesh = malla
		multi_modelo.instance_count = lista.size()
		for i in lista.size():
			multi_modelo.set_instance_transform(i, lista[i])
		var instancia_modelo := MultiMeshInstance3D.new()
		instancia_modelo.multimesh = multi_modelo
		_partes.add_child(instancia_modelo)
	if _empaques.is_empty():
		return
	var caja := BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = EMPAQUE_SHADER
	material.set_shader_parameter("atlas", EMPAQUE_ATLAS)
	material.set_shader_parameter("desgaste", 0.5)
	caja.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = caja
	multi.instance_count = _empaques.size()
	for i in _empaques.size():
		var e: Array = _empaques[i]
		var giro: Basis = e[4] if e.size() > 4 else Basis()
		multi.set_instance_transform(i, Transform3D(giro * Basis().scaled(e[1]), e[0]))
		multi.set_instance_color(i, e[2])
		var etiqueta: int = e[3] if e.size() > 3 else -1
		multi.set_instance_custom_data(i, Color(maxi(etiqueta, 0), 1.0 if etiqueta >= 0 else 0.0, 0, 0))
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = multi
	_partes.add_child(instancia)


func _disco(radio: float, pos: Vector3, tinte: Color) -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = radio
	disco.bottom_radius = radio
	disco.height = 0.004
	disco.radial_segments = 16
	disco.rings = 1
	disco.material = _plano(tinte)
	var instancia := _malla(disco, pos, Vector3.ONE)
	instancia.rotation_degrees.x = 90


func _letrero(cadena: String, pos: Vector3, ancho_max: float, tinte: Color) -> void:
	var label := Label3D.new()
	label.text = cadena
	label.pixel_size = 0.002
	var renglones := cadena.split("\n")
	var mas_largo := 1
	for r in renglones:
		mas_largo = maxi(mas_largo, r.length())
	label.font_size = clampi(int(ancho_max / label.pixel_size / (0.62 * mas_largo)), 12, 96)
	label.outline_size = 0
	label.modulate = tinte
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.line_spacing = -label.font_size * 0.25
	label.position = pos
	_partes.add_child(label)


func _malla(malla: Mesh, pos: Vector3, escala: Vector3) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = pos
	instancia.scale = escala
	_partes.add_child(instancia)
	return instancia


func _caja(tamano: Vector3, pos: Vector3, material: Material) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = material
	_malla(malla, pos, Vector3.ONE)


func _ps1(tinte: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("tint", tinte)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	# Fierro pintado con uso (ps1_gastado): manchas, mugre, rayones, despostillado
	material.set_shader_parameter("deterioro_modo", 4)
	material.set_shader_parameter("metal", true)
	material.set_shader_parameter("desgaste", desgaste)
	return material


# Sin sombreado: luces, fondos iluminados, calcomanias, tambien
# con mugre y manchas para que no sean de un color parejo
func _plano(tinte: Color) -> ShaderMaterial:
	var material := _ps1(tinte)
	material.set_shader_parameter("metal", false)
	material.set_shader_parameter("desgaste", 0.3)
	material.set_shader_parameter("sin_sombra", true)
	return material


# `apagado`: el vidrio recibe la luz del cuarto en vez de brillar solo (la vitrina sin
# luz de la ferreteria)
# Compartido (Refrigerador.gd explica por que)
func _vidrio(apagado := false) -> StandardMaterial3D:
	if not _vidrios.has(apagado):
		var vidrio := StandardMaterial3D.new()
		vidrio.albedo_color = Color(0.75, 0.9, 1.0, 0.14)
		vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vidrio.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if apagado else BaseMaterial3D.SHADING_MODE_UNSHADED
		_vidrios[apagado] = vidrio
	return _vidrios[apagado]
