@tool
class_name Punto
extends Interior

# El Punto: la oficina de atras de la Cantina El Olvido (models/negocios/punto/punto_dentro.glb, de
# tools/blender/negocios/punto.py), donde el patron vende fierros (las armas de fuego) sentado en su
# silla de piel detras del escritorio: madera oscura, la pared de cuernos, cajas de balas y la bolsa
# en el escritorio. Es un interior como las tiendas: lo que vende flota en la Vitrina y se compra
# con saltar.
#
# El patron es hombre_04 del pack PSX (el mismo cuerpo que El Compa) con su textura propia
# (tools/personajes/el_compa.gd -- --patron: seda negra con estampado barroco, cadena de oro, rapado
# y candado), sentado con Sitting_Idle. El Vendedor de la escena es un Node3D solo, como La Chava
# del Yonke: Interiores le pone "modelo" pero aqui no se usa.

const MODELO := "hombre_04"
const TEXTURA := preload("res://models/personajes/patron/Character_04.png")
# Sitting_Idle deja la cadera CADERA m detras de los pies (Sotano.CADERA): el Vendedor marca el
# centro del asiento y el modelo se adelanta eso
const CADERA := 0.38
# La lampara de banquero del escritorio (punto.py: O_lampara_*) alumbra de verdad: sin ella al
# patron solo lo alumbraba el foco de atras y se veia en sombra
const LAMPARA := Vector3(-0.75, 1.05, -0.78)
const LAMPARA_COLOR := Color(1.0, 0.8, 0.5)
const LAMPARA_ENERGIA := 2.2
const SALUDOS := [
	"Pásale, pásale. Aquí no hay nada que no se pueda arreglar con un fierro.",
	"¿Qué ocupas, mijo? Aquí todo es de calidad. Bueno, casi todo.",
	"Siéntate... no, mejor no te sientes. ¿Qué vas a llevar?",
	"Los zombis no respetan a nadie. Esto sí lo respetan.",
]


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var lampara := OmniLight3D.new()
	lampara.name = "Lampara"
	lampara.position = LAMPARA
	lampara.light_color = LAMPARA_COLOR
	lampara.light_energy = LAMPARA_ENERGIA
	lampara.omni_range = 3.0
	add_child(lampara)
	var vendedor := get_node_or_null("Vendedor") as Node3D
	if vendedor == null:
		return
	var asiento := Node3D.new()
	asiento.name = "Patron"
	asiento.position = Vector3(0.0, 0.0, CADERA)
	# hombre_04 queda de espaldas con Civiles.poner (los civiles de la calle no tienen frente fijo):
	# media vuelta para que vea a la camara
	asiento.rotation.y = PI
	vendedor.add_child(asiento)
	Civiles.poner(asiento, MODELO, "Sitting_Idle")
	# Su textura en vez de la del pack: un material por malla, hecho una vez al entrar
	var material := StandardMaterial3D.new()
	material.albedo_texture = TEXTURA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	for malla: MeshInstance3D in asiento.find_children("*", "MeshInstance3D", true, false):
		for i in malla.mesh.get_surface_count():
			malla.set_surface_override_material(i, material)


func dialogo() -> String:
	return SALUDOS[randi() % SALUDOS.size()]
