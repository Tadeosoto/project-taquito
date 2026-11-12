class_name CajaGela
extends Node3D

# La caja de GelA del reten de la avenida (marca "caja_gela" de Colonia.gd, idea de AG): de dia
# la cuidan los guardias y no se toca; de noche, sin nadie, se abre una vez por noche y suelta
# 1-2 cosas al azar de CONTENIDO. Al amanecer se vuelve a llenar.

const RADIO := 1.8
const CONTENIDO := [
	"res://resources/productos/galon_agua.tres",
	"res://resources/productos/tacos.tres",
	"res://resources/productos/takis_tazo.tres",
	"res://resources/productos/cinta.tres",
]
const NOCHE_DESDE := 0.5          # Ciclo.valor() desde el que ya no hay guardias
# De quien es (marca "de"): "gela" es la del reten de antes; "ofrendas" es la caja de ofrendas de
# los fieles junto a la reja de Santa Mugre (la fortaleza ya no tiene reten de GelA): de dia la
# reparten las señoras y de noche el que hace guardia toma lo que necesita
const TEXTOS := {
	"gela": ["%s: abrir la caja de GelA", "Caja de GelA (de dia la cuidan)", Color(0.1, 0.33, 0.72)],
	"ofrendas": ["%s: tomar de las ofrendas", "Ofrendas a la Virgen (se reparten de noche)", Color(0.1, 0.38, 0.36)],
}
var de := "gela"

var _player_inside := false
var _aviso: Label3D
var _abierta := false
var _ciclo: Node
var _tapa: Node3D                 # la bisagra de la tapa

static var _materiales := {}
var _material: StandardMaterial3D


func _ready() -> void:
	_armar_caja()
	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.pixel_size = 0.006
	_aviso.position.y = 1.3
	_aviso.visible = false
	add_child(_aviso)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = RADIO
	forma.shape = esfera
	forma.position.y = 0.6
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = true
			_avisar())
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_player_inside = false
			_aviso.visible = false)
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo and _ciclo.has_signal("amanecio"):
		_ciclo.amanecio.connect(_llenar)
	add_to_group("interactuable")


func _de_noche() -> bool:
	return _ciclo != null and float(_ciclo.valor()) >= NOCHE_DESDE


func _avisar() -> void:
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	if _abierta:
		_aviso.text = "Ya la vaciaste"
	elif _de_noche():
		_aviso.text = String(TEXTOS[de][0]) % tecla
	else:
		_aviso.text = String(TEXTOS[de][1])
	_aviso.visible = true


func is_player_inside() -> bool:
	return _player_inside and _de_noche() and not _abierta


func interact() -> void:
	if not is_player_inside():
		return
	_abierta = true
	_tapa.rotation.x = -1.1
	var inventario := get_node_or_null("/root/Inventory")
	var cuantos := randi_range(1, 2)
	for i in cuantos:
		var item := load(CONTENIDO.pick_random()) as InventoryItemData
		if inventario == null or not inventario.add_item(item):
			# Si no cabe se queda tirada junto a la caja, como lo que sobra de una mision
			var tirado: Node3D = load("res://scripts/WorldItem.gd").new()
			tirado.set("item_data", item)
			get_parent().add_child(tirado)
			tirado.global_position = global_position + global_basis.z * 1.2 + Vector3.UP * 0.5
	_avisar()


func _llenar() -> void:
	_abierta = false
	_tapa.rotation.x = 0.0


func _armar_caja() -> void:
	if not TEXTOS.has(de):
		de = "gela"
	if not _materiales.has(de):
		var nuevo := StandardMaterial3D.new()
		nuevo.albedo_color = TEXTOS[de][2]
		_materiales[de] = nuevo
	_material = _materiales[de]
	var cuerpo := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = Vector3(1.0, 0.6, 0.6)
	malla.material = _material
	cuerpo.mesh = malla
	cuerpo.position.y = 0.3
	add_child(cuerpo)
	# La tapa gira desde la orilla de atras
	var bisagra := Node3D.new()
	bisagra.position = Vector3(0.0, 0.6, -0.3)
	add_child(bisagra)
	var tapa := MeshInstance3D.new()
	var malla_tapa := BoxMesh.new()
	malla_tapa.size = Vector3(1.04, 0.06, 0.64)
	malla_tapa.material = _material
	tapa.mesh = malla_tapa
	tapa.position = Vector3(0.0, 0.03, 0.3)
	bisagra.add_child(tapa)
	_tapa = bisagra
