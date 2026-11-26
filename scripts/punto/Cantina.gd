extends Node3D

# La Cantina El Olvido por dentro (scenes/casas/cantina.tscn, el cuarto es
# models/negocios/punto/cantina.glb de tools/blender/negocios/punto.py cantina_dentro): se camina,
# como el Sotano, porque se entra por CasaPropia (PuntoMapa pone su flecha en la puerta). Sin pelea.
# - El del colchon atiende la barra (docs/personajes.md): le hablas, y en la barra le compras caguama,
#   cigarros y tachas (lo que vendia El Punto antes de ser de fierros).
# - Los de siempre: unos platican (npc.tscn, cada quien su rollo), otros toman sentados, y uno esta
#   dormido en el colchon de la esquina.
# - La rocola cambia de cancion (Sonidos "rocola_1".."rocola_4", JJ las escoge; sin ellas avisa).
# - La puerta de atras (PRIVADO) es la oficina de Don Lalo Santacruz: el interior fijo del giro
#   "punto" (scenes/interiores/punto.tscn) por Interiores, a otra altura para no encimarse.
# Las marcas "Marca_*" vienen del .glb (en medidas de la escena; CasaPropia la agranda x1.25).

const NPC := preload("res://scenes/npc.tscn")
const CADERA := 0.38            # Sitting_Idle deja la cadera atras de los pies (Sotano.CADERA)
const OFICINA_ALTURA := 700.0   # la oficina de Don Lalo (Interiores) va aqui, no a 500 como la cantina
const ROLAS := ["rocola_1", "rocola_2", "rocola_3", "rocola_4"]
const VENTAS := {
	"caguama": "res://resources/productos/caguama.tres",
	"cigarros": "res://resources/productos/cigarros.tres",
	"tachas": "res://resources/productos/tachas.tres",
}
const COLCHONERO := ["Pásale, no hay nadie. Bueno, nadie que importe.",
	"¿Una caguama? Están heladas. Más o menos.",
	"El patrón está atrás. No lo hagas esperar, que se enoja bonito.",
	"Ese del colchón es mi compadre. Déjalo, ya mero se levanta.",
	"Aquí no se fía. Ni a mí me fían."]
const PLATICAS := [
	["Dicen que en la noche la Cucarrata anda por la avenida. Yo nomás la oigo.",
	"Ese Don Lalo reza más que mi abuela. Y mi abuela mataba gallinas.",
	"Si vas con La Chava al yonke, dile que le debo una lámina. No, dos."],
	["La pipa ya no pasa por aquí desde que GelA subió el agua.",
	"¿Viste a los cuicos de la esquina? Esos cobran hasta por mirarlos.",
	"Yo antes era taxista. Ahora soy esto."],
]
const BILLAR := ["Nadie juega desde que se perdió la bola ocho.", "El paño tiene una quemada de cigarro con forma de la Virgen."]

var _avisos: Label
var _rola := -1
var _platica := {}


func _ready() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_avisos = Label.new()
	_avisos.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_avisos.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_avisos.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_avisos.offset_bottom = -40.0
	_avisos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avisos.autowrap_mode = TextServer.AUTOWRAP_WORD
	_avisos.custom_minimum_size.x = 560.0
	_avisos.add_theme_color_override("font_outline_color", Color.BLACK)
	_avisos.add_theme_constant_override("outline_size", 6)
	_avisos.modulate.a = 0.0
	capa.add_child(_avisos)
	_luces()
	var cuarto := get_node_or_null("Cuarto")
	if cuarto == null:
		return
	var parados := 0
	for marca in cuarto.find_children("Marca_*", "", true, false):
		var m := marca as Node3D
		var nombre := String(m.name)
		if nombre == "Marca_Colchonero":
			_hablador(m, "El del colchón", "colchonero", COLCHONERO, 0.85)
		elif nombre.begins_with("Marca_Parado_"):
			_hablador(m, "Parroquiano", "parroquiano_%d" % parados, PLATICAS[parados % PLATICAS.size()], 1.0)
			parados += 1
		elif nombre.begins_with("Marca_Bebedor_"):
			_sentado(m, "bebedor_%s" % nombre)
		elif nombre == "Marca_Dormido":
			_dormido(m)
		elif nombre.begins_with("Marca_Venta_"):
			var que := nombre.trim_prefix("Marca_Venta_")
			_venta(m, que)
		elif nombre == "Marca_Rocola":
			add_child(MuebleCasa.crear("Cambiar la canción", m.position, _rocola))
		elif nombre == "Marca_Puerta_atras":
			add_child(_puerta_atras(m))
	add_child(MuebleCasa.crear("Ver el billar", Vector3(7.2, 0.0, 3.8), func() -> void: _avisar(BILLAR[randi() % BILLAR.size()])))


# Focos calidos: uno en la barra, la lampara del billar y uno en las mesas
func _luces() -> void:
	for datos in [[Vector3(5.6, 2.6, 1.6), Color(1.0, 0.75, 0.45), 1.6, 7.0], [Vector3(7.2, 2.1, 4.6), Color(1.0, 0.9, 0.6), 1.4, 4.0],
			[Vector3(3.0, 2.6, 5.4), Color(1.0, 0.6, 0.35), 1.2, 6.0], [Vector3(10.3, 1.5, 2.6), Color(1.0, 0.45, 0.2), 0.8, 3.0]]:
		var luz := OmniLight3D.new()
		luz.position = datos[0]
		luz.light_color = datos[1]
		luz.light_energy = datos[2]
		luz.omni_range = datos[3]
		add_child(luz)


func _hablador(m: Node3D, nombre: String, semilla: String, lineas: Array, tono: float) -> void:
	var npc := NPC.instantiate() as Node3D
	npc.name = semilla.capitalize().replace(" ", "")
	npc.set("modelo", _hombre(semilla))
	npc.set("nombre", nombre)
	npc.set("serenol", 0)
	npc.set("dialogue", lineas[0])
	npc.set("al_hablar", func() -> String:
		var i: int = _platica.get(semilla, 0)
		_platica[semilla] = i + 1
		return lineas[i % lineas.size()])
	if "tono" in npc:
		npc.set("tono", tono)
	npc.transform = m.transform
	add_child(npc)


func _sentado(m: Node3D, semilla: String) -> void:
	var nodo := Node3D.new()
	nodo.transform = m.transform
	# El civil ve hacia -Z (hacia la mesa): la cadera queda sobre la silla, los pies adelante
	nodo.position += -m.transform.basis.z * CADERA
	add_child(nodo)
	Civiles.poner(nodo, _hombre(semilla), "Sitting_Idle")


func _dormido(m: Node3D) -> void:
	var nodo := Node3D.new()
	nodo.transform = m.transform
	add_child(nodo)
	var animacion := Civiles.poner(nodo, _hombre("dormido"), "Death01")
	# Tirado en el colchon: la caida ya terminada y quieto ahi
	if animacion and animacion.current_animation != "":
		var largo := animacion.current_animation_length
		animacion.seek(largo, true)
		animacion.pause()


func _venta(m: Node3D, que: String) -> void:
	var item := load(VENTAS[que]) as InventoryItemData
	if item == null:
		return
	var precio := roundi(item.precio * _factor())
	add_child(MuebleCasa.crear("Comprar %s ($%d)" % [item.item_name.to_lower(), precio], m.position, _comprar.bind(item, precio), 0.6))


# El precio como en las tiendas (Interior._factor): el Personaje y el Regateo; la piel cambia lo que
# te cobran, no lo que pegas
func _factor() -> float:
	var personaje := get_node_or_null("/root/Personaje")
	var tazos := get_node_or_null("/root/Tazos")
	return (personaje.factor_precio() if personaje and personaje.has_method("factor_precio") else 1.0) \
			* (tazos.factor_precio() if tazos and tazos.has_method("factor_precio") else 1.0)


func _comprar(item: InventoryItemData, precio: int) -> void:
	var cartera := get_node_or_null("/root/Cartera")
	var inventario := get_node_or_null("/root/Inventory")
	if cartera == null or inventario == null:
		return
	if cartera.pesos < precio:
		_avisar("\"¿Y la lana? Aquí no se fía, compa.\"")
	elif not inventario.cabe(item):
		_avisar("No te cabe nada más en la mochila.")
	else:
		cartera.pesos -= precio
		inventario.add_item(item)
		_avisar("\"Ándale, salud.\" (%s, $%d)" % [item.item_name, precio])


func _rocola() -> void:
	_rola = (_rola + 1) % ROLAS.size()
	var nombre: String = ROLAS[_rola]
	if Sonidos.ARCHIVOS.has(nombre):
		Sonidos.tocar(self, nombre, -6.0)
		_avisar("La rocola cambia de canción.")
	else:
		_avisar("La rocola traga la moneda y no suena. Le faltan discos.")


# La puerta de atras: el interior fijo de la oficina de Don Lalo (Interiores, giro "punto")
func _puerta_atras(m: Node3D) -> Area3D:
	var area := Area3D.new()
	area.name = "PuertaAtras"
	area.transform = m.transform
	area.monitorable = false
	area.set_meta("adentro", true)
	area.set_meta("altura", OFICINA_ALTURA)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if not cuerpo is Player:
			return
		var interiores := get_tree().get_first_node_in_group("interiores")
		var puntos: MapPuntos = interiores.get("_puntos") if interiores else null
		if puntos:
			puntos.entrar_negocio.emit("punto", "punto", "La oficina de Don Lalo", false, area))
	return area


func _hombre(semilla: String) -> String:
	for k in 50:
		var nombre := Civiles.elegir("cantina_%s_%d" % [semilla, k])
		if nombre.begins_with("hombre_"):
			return nombre
	return "hombre_01"


func _avisar(texto: String) -> void:
	_avisos.text = texto
	var tween := create_tween()
	tween.tween_property(_avisos, "modulate:a", 1.0, 0.25)
	tween.tween_interval(4.0)
	tween.tween_property(_avisos, "modulate:a", 0.0, 0.6)
