class_name Horizonte
extends Node3D

# Lo que se ve mas alla de la muralla de una colonia del mapa en Blender (scenes/mapa.tscn): antes
# era niebla vacia, porque el mapa grande es otra escena. Un anillo de siluetas alrededor del
# recorte, en UNA malla sin choque y con un material (shaders/horizonte.gdshader, color en los
# vertices): tres hileras de casas con su tinaco, torres de luz, dos naves de GelA y los cerros
# al fondo. Siempre igual (azar con semilla). De noche se oscurece y se prenden ventanas: afuera
# vive la gente bajo Serenol (docs/lore.md).

const SHADER := preload("res://shaders/horizonte.gdshader")
const REVISA := 0.5            # s entre lecturas de Ciclo.valor()
const COLORES := [Color(0.62, 0.42, 0.36), Color(0.7, 0.62, 0.5), Color(0.52, 0.5, 0.48), Color(0.66, 0.5, 0.42),
	Color(0.58, 0.6, 0.56), Color(0.74, 0.7, 0.62), Color(0.5, 0.42, 0.4)]
const TINACO := Color(0.08, 0.08, 0.09)
const FIERRO := Color(0.2, 0.2, 0.22)
const CERRO := Color(0.3, 0.33, 0.3)
const GELA := Color(0.82, 0.84, 0.86)
const GELA_AZUL := Color(0.1, 0.33, 0.72)

## x0, z0, ancho, fondo del recorte (el de tools/blender/mapa/colonias/<colonia>.json)
@export var rect := Rect2(-420.0, 258.0, 235.0, 224.0)
## De la muralla a la primera hilera y a la ultima
@export var cerca := 14.0
@export var lejos := 150.0
@export var semilla := 7

var _material: ShaderMaterial
var _ciclo: Node
var _espera := 0.0
var _vertices := PackedVector3Array()
var _colores := PackedColorArray()


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	_casas(azar)
	_torres(azar)
	_naves()
	_cerros(azar)
	var arreglos := []
	arreglos.resize(Mesh.ARRAY_MAX)
	arreglos[Mesh.ARRAY_VERTEX] = _vertices
	arreglos[Mesh.ARRAY_COLOR] = _colores
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
	malla.surface_set_material(0, _material)
	var nodo := MeshInstance3D.new()
	nodo.name = "Siluetas"
	nodo.mesh = malla
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	_vertices = PackedVector3Array()
	_colores = PackedColorArray()


func _process(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = REVISA
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo:
		_material.set_shader_parameter("noche", float(_ciclo.valor()))


# Un punto del anillo a `fuera` m de la orilla del recorte, segun `t` (0..1 dando la vuelta), y
# hacia donde queda afuera
func _en_anillo(t: float, fuera: float) -> Array:
	var x0 := rect.position.x - fuera
	var z0 := rect.position.y - fuera
	var x1 := rect.end.x + fuera
	var z1 := rect.end.y + fuera
	var ancho := x1 - x0
	var fondo := z1 - z0
	var d := fposmod(t, 1.0) * 2.0 * (ancho + fondo)
	if d < ancho:
		return [Vector3(x0 + d, 0.0, z0), Vector3(0, 0, -1)]
	d -= ancho
	if d < fondo:
		return [Vector3(x1, 0.0, z0 + d), Vector3(1, 0, 0)]
	d -= fondo
	if d < ancho:
		return [Vector3(x1 - d, 0.0, z1), Vector3(0, 0, 1)]
	return [Vector3(x0, 0.0, z1 - (d - ancho)), Vector3(-1, 0, 0)]


func _casas(azar: RandomNumberGenerator) -> void:
	for hilera in 3:
		var fuera := lerpf(cerca, lejos * 0.6, hilera / 2.0)
		var largo := 2.0 * (rect.size.x + rect.size.y + 4.0 * fuera)
		var avance := 0.0
		while avance < largo:
			var ancho := azar.randf_range(6.0, 12.0)
			var alto := azar.randf_range(3.0, 6.5) + hilera * azar.randf_range(0.5, 3.0)
			var fondo := azar.randf_range(7.0, 11.0)
			var lugar := _en_anillo((avance + ancho / 2.0) / largo, fuera + azar.randf_range(0.0, 6.0))
			var centro: Vector3 = lugar[0]
			var afuera: Vector3 = lugar[1]
			var lado := Vector3(-afuera.z, 0.0, afuera.x)
			var color: Color = COLORES[azar.randi() % COLORES.size()]
			_caja(centro + afuera * fondo / 2.0, lado, afuera, Vector3(ancho, alto, fondo), color, true)
			if azar.randf() < 0.7:
				var corrido := lado * azar.randf_range(-ancho * 0.3, ancho * 0.3)
				_caja(centro + afuera * fondo / 2.0 + corrido + Vector3.UP * alto, lado, afuera, Vector3(1.1, 1.3, 1.1), TINACO, false)
			avance += ancho + (azar.randf_range(0.0, 1.5) if azar.randf() < 0.8 else azar.randf_range(6.0, 10.0))


# Torres de luz (las que en el lore sirven de antenas): dos planos cruzados que se angostan
func _torres(azar: RandomNumberGenerator) -> void:
	for i in 7:
		var lugar := _en_anillo((i + azar.randf_range(0.1, 0.9)) / 7.0, azar.randf_range(lejos * 0.35, lejos * 0.8))
		var base: Vector3 = lugar[0]
		var alto := azar.randf_range(24.0, 32.0)
		for eje: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
			for signo: float in [-1.0, 1.0]:
				# Cada pata: un triangulo delgado de la base a la punta
				var pie := base + eje * signo * 2.6
				_tri(pie - eje * 0.25, pie + eje * 0.25, base + Vector3.UP * alto, FIERRO, 0.0)
			# Crucetas
			for y: float in [alto * 0.72, alto * 0.86]:
				_cuadro(base + Vector3.UP * y - eje * 3.2, base + Vector3.UP * y + eje * 3.2, 0.35, FIERRO)


# Dos naves de GelA: lo unico limpio y grande que se ve desde adentro
func _naves() -> void:
	for dato: Array in [[0.31, lejos * 0.55, 46.0, 15.0], [0.82, lejos * 0.7, 60.0, 18.0]]:
		var lugar := _en_anillo(dato[0], dato[1])
		var centro: Vector3 = lugar[0]
		var afuera: Vector3 = lugar[1]
		var lado := Vector3(-afuera.z, 0.0, afuera.x)
		_caja(centro, lado, afuera, Vector3(dato[2], dato[3], 24.0), GELA, false)
		_caja(centro + Vector3.UP * (float(dato[3]) * 0.72) - afuera * 12.1, lado, afuera, Vector3(dato[2], float(dato[3]) * 0.16, 0.2), GELA_AZUL, false)
		# El tanque elevado
		_caja(centro + lado * (float(dato[2]) * 0.5 + 8.0), lado, afuera, Vector3(1.2, 26.0, 1.2), FIERRO, false)
		_caja(centro + lado * (float(dato[2]) * 0.5 + 8.0) + Vector3.UP * 26.0, lado, afuera, Vector3(7.0, 5.0, 7.0), GELA, false)


# Los cerros: una cresta quebrada dando toda la vuelta, detras de todo
func _cerros(azar: RandomNumberGenerator) -> void:
	var pasos := 48
	var crestas: Array[Vector3] = []
	for i in pasos:
		var lugar := _en_anillo(float(i) / pasos, lejos * 1.9)
		var alto := 16.0 + 26.0 * absf(sin(i * 0.9 + azar.randf() * 0.8)) * azar.randf_range(0.5, 1.0)
		crestas.append((lugar[0] as Vector3) + Vector3.UP * alto)
	for i in pasos:
		var a := crestas[i]
		var b := crestas[(i + 1) % pasos]
		var a0 := Vector3(a.x, -2.0, a.z)
		var b0 := Vector3(b.x, -2.0, b.z)
		_tri(a0, b0, b, CERRO, 0.0)
		_tri(a0, b, a, CERRO, 0.0)


# Caja sin tapa de abajo. `lado` y `afuera` son sus ejes en el piso; `ventanas` = alfa 1 en las
# paredes (el shader prende ventanas de noche donde el alfa es 1)
func _caja(centro: Vector3, lado: Vector3, afuera: Vector3, tam: Vector3, color: Color, ventanas: bool) -> void:
	var sx := lado * tam.x / 2.0
	var sz := afuera * tam.z / 2.0
	var arriba := Vector3.UP * tam.y
	var p := [centro - sx - sz, centro + sx - sz, centro + sx + sz, centro - sx + sz]
	var alfa := 1.0 if ventanas else 0.0
	for i in 4:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		# Cada pared un poco distinta de tono, para que la caja se lea sin luz
		var tono := color * (1.0 - 0.14 * (i % 2)) * (0.9 if i >= 2 else 1.0)
		_tri(a, b, b + arriba, tono, alfa)
		_tri(a, b + arriba, a + arriba, tono, alfa)
	var techo := color * 0.8
	_tri(p[0] + arriba, p[1] + arriba, p[2] + arriba, techo, 0.0)
	_tri(p[0] + arriba, p[2] + arriba, p[3] + arriba, techo, 0.0)


func _cuadro(a: Vector3, b: Vector3, alto: float, color: Color) -> void:
	_tri(a, b, b + Vector3.UP * alto, color, 0.0)
	_tri(a, b + Vector3.UP * alto, a + Vector3.UP * alto, color, 0.0)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color, alfa: float) -> void:
	_vertices.append_array([a, b, c])
	var con_alfa := Color(color.r, color.g, color.b, alfa)
	_colores.append_array([con_alfa, con_alfa, con_alfa])
