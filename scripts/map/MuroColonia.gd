class_name MuroColonia
extends Node3D
## El muro que encierra Parques de Santa Mugre en el mapa completo: ahi se entra por la flecha
## amarilla a la escena con mas detalle (el mapa de Blender), no caminando. Coincide con las cuatro
## bardas de tools/blender/mapa/colonias/santa_mugre.json (Barda_norte/sur/poniente/oriente): el
## rectangulo `recorte`, 2.6 m de alto y 0.3 m de grueso, centradas sobre cada borde.
## Donde la avenida (Av. Bahia de Todos los Sedientos) cruza el muro hay una reja de fierro, cerrada
## y solida, con una flecha amarilla por fuera: pisarla lleva a scenes/mapa.tscn por esa reja
## (PasoColonia). Las rejas coinciden con `rejas` del mismo .json.
## Si cambia el recorte o las rejas en el JSON, cambian `rect` y `rejas` aqui.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")

## x0, z0, x1, z1 del recorte (el mismo de santa_mugre.json y recorte_santa_mugre.py)
@export var rect := Rect2(-420.0, 258.0, 235.0, 224.0)
@export var alto := 2.6
@export var grueso := 0.3
@export var color := Color(0.62, 0.6, 0.57)
@export var color_fierro := Color(0.12, 0.12, 0.13)
## Cada reja: lado ("poniente" u "oriente") y su tramo en z (los del "rejas" del JSON)
@export var rejas := {"poniente": Vector2(445.0, 464.0), "oriente": Vector2(463.8, 481.4)}
@export var jugador_path: NodePath

## De la reja a la flecha de entrada, y a donde aparece el jugador al salir del mapa de Blender
const FLECHA_FUERA := 2.2
const LLEGADA_FUERA := 5.4
const TEXTO_ENTRADA := "Entrar a Santa Mugre"

var _material_muro: ShaderMaterial
var _material_fierro: ShaderMaterial


func _enter_tree() -> void:
	# Si se llego del mapa de Blender por una reja (PasoColonia), el jugador aparece afuera de ella.
	# Esto va aqui, antes de que el jugador, el dron y Supervivencia lean su posicion (este nodo va
	# antes que ellos en la escena y todavia no entran al arbol)
	var por := PasoColonia.tomar_lado()
	if por == "" or not rejas.has(por):
		return
	var jugador := get_node_or_null(jugador_path) as Node3D
	if jugador == null:
		return
	var donde := _afuera(por, LLEGADA_FUERA)
	jugador.position = Vector3(donde.x, 1.5, donde.y)


func _ready() -> void:
	_material_muro = _material(color)
	_material_fierro = _material(color_fierro)

	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var ancho := x1 - x0
	var fondo := z1 - z0
	# Lados centrados sobre el borde; los de oriente y poniente se alargan para cerrar las esquinas
	_pared(Vector3((x0 + x1) / 2.0, 0.0, z0), Vector3(ancho + grueso, alto, grueso), _material_muro)
	_pared(Vector3((x0 + x1) / 2.0, 0.0, z1), Vector3(ancho + grueso, alto, grueso), _material_muro)
	# Poniente y oriente: el muro corre de esquina a esquina menos el hueco de la reja
	for lado: String in ["poniente", "oriente"]:
		var x := x0 if lado == "poniente" else x1
		var tramo: Vector2 = rejas.get(lado, Vector2.ZERO)
		if tramo == Vector2.ZERO:
			_pared(Vector3(x, 0.0, (z0 + z1) / 2.0), Vector3(grueso, alto, fondo + grueso), _material_muro)
			continue
		var arriba := tramo.x - (z0 - grueso / 2.0)
		var abajo := (z1 + grueso / 2.0) - tramo.y
		_pared(Vector3(x, 0.0, tramo.x - arriba / 2.0), Vector3(grueso, alto, arriba), _material_muro)
		_pared(Vector3(x, 0.0, tramo.y + abajo / 2.0), Vector3(grueso, alto, abajo), _material_muro)
		_reja(lado, x, tramo)


func _material(base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("deterioro_modo", 2)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


func _pared(centro: Vector3, tam: Vector3, material: Material) -> void:
	# Del piso (y 0) hacia arriba; colisiona en la capa 1, como las casas: jugador, zombis y
	# CampoFlujo la ven sin cambios. Baja 1 m bajo el piso por si el terreno sube.
	var cuerpo := StaticBody3D.new()
	cuerpo.position = centro + Vector3(0.0, tam.y / 2.0 - 0.5, 0.0)
	var alto_total := tam.y + 1.0
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(tam.x, alto_total, tam.z)
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(tam.x, alto_total, tam.z)
	malla.mesh = box
	malla.material_override = material
	cuerpo.add_child(malla)
	add_child(cuerpo)


# --- Las rejas de la avenida ---

# Punto (x, z) a `m` metros de la reja de `lado`, hacia afuera del recorte
func _afuera(lado: String, m: float) -> Vector2:
	var tramo: Vector2 = rejas[lado]
	var z := (tramo.x + tramo.y) / 2.0
	return Vector2(rect.position.x - m, z) if lado == "poniente" else Vector2(rect.end.x + m, z)


func _reja(lado: String, x: float, tramo: Vector2) -> void:
	var largo := tramo.y - tramo.x
	var zc := (tramo.x + tramo.y) / 2.0
	var reja := Node3D.new()
	reja.name = "Reja_" + lado
	reja.position = Vector3(x, 0.0, zc)
	add_child(reja)
	# Postes de concreto en las orillas y al centro, donde se juntan las dos hojas
	for z in [-largo / 2.0 + 0.3, 0.0, largo / 2.0 - 0.3]:
		_caja(reja, Vector3(grueso + 0.1, alto + 0.3, 0.6), Vector3(0.0, (alto + 0.3) / 2.0, z), _material_muro)
	# Travesanos de cada hoja entre los postes
	for hoja in [-1.0, 1.0]:
		var z0: float = -largo / 2.0 + 0.6 if hoja < 0.0 else 0.3
		var z1: float = -0.3 if hoja < 0.0 else largo / 2.0 - 0.6
		for y in [0.25, alto - 0.35, alto * 0.5]:
			_caja(reja, Vector3(0.07, 0.07, z1 - z0), Vector3(0.0, y, (z0 + z1) / 2.0), _material_fierro)
	# Los barrotes de las dos hojas, todos en un solo MultiMesh
	var barrote := BoxMesh.new()
	barrote.size = Vector3(0.035, alto - 0.1, 0.035)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = barrote
	var zs: Array[float] = []
	for hoja in [-1.0, 1.0]:
		var z0: float = -largo / 2.0 + 0.6 if hoja < 0.0 else 0.3
		var z1: float = -0.3 if hoja < 0.0 else largo / 2.0 - 0.6
		var n := maxi(2, int((z1 - z0) / 0.2))
		for i in n + 1:
			zs.append(z0 + (z1 - z0) * i / n)
	multi.instance_count = zs.size()
	for i in zs.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, alto / 2.0 - 0.05, zs[i])))
	var barrotes := MultiMeshInstance3D.new()
	barrotes.multimesh = multi
	barrotes.material_override = _material_fierro
	reja.add_child(barrotes)
	# Choque cerrado de lado a lado, como el muro (capa 1)
	var cuerpo := StaticBody3D.new()
	cuerpo.position = Vector3(0.0, alto / 2.0 - 0.5, 0.0)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(grueso + 0.1, alto + 1.0, largo)
	forma.shape = caja
	cuerpo.add_child(forma)
	reja.add_child(cuerpo)
	_flecha_de_entrada(lado)


func _caja(padre: Node3D, tam: Vector3, donde: Vector3, material: Material) -> void:
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	malla.mesh = box
	malla.position = donde
	malla.material_override = material
	padre.add_child(malla)


# La flecha amarilla por fuera de la reja: pisarla entra al mapa de Blender por esa reja
func _flecha_de_entrada(lado: String) -> void:
	var donde := _afuera(lado, FLECHA_FUERA)
	var area := Area3D.new()
	area.name = "Entrada_" + lado
	area.position = Vector3(donde.x, 0.0, donde.y)
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	var letrero := Label3D.new()
	letrero.text = TEXTO_ENTRADA
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.position = Vector3(0.0, 2.6, 0.0)
	letrero.visibility_range_end = 25.0
	area.add_child(letrero)
	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo is Player:
			PasoColonia.ir_a(self, PasoColonia.MAPA_COLONIA, lado))
	add_child(area)
