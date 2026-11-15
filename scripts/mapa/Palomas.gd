class_name Palomas
extends Node3D

# Parvada de palomas en una plaza (marca "palomas" de Colonia.gd; tambien en el safehouse): de dia
# picotean en el piso dentro del rectangulo `tam`; si el jugador pasa corriendo cerca (o se les
# acerca mucho) salen volando todas, dan una vuelta y vuelven a bajar en otro lugar. De noche no
# hay. Un solo MultiMesh con un cuadro de pixeles que siempre ve a la camara; sin choque ni luz.

const ESPANTA_CORRIENDO := 7.0    # m: a esta distancia se espantan si vienes rapido
const ESPANTA_CERCA := 2.6        # m: y a esta, aunque camines
const RAPIDO := 3.2               # m/s
const VUELO := 7.0                # s en el aire
const SUBE := 9.0                 # m de altura de la vuelta
const NOCHE_DESDE := 0.4          # Ciclo.valor() desde el que ya no hay
const TAMANO := 0.34              # m de lado del cuadro
# 8 x 8: '.' nada, 'g' gris, 'o' gris oscuro, 'b' blanco, 'n' pico y pata
const DIBUJO_PISO := ["........", "...oo...", "..oggn..", "..ggg...", ".ggggg..", "ogggbg..", "..ggg...", "..n.n..."]
const DIBUJO_VUELO := ["........", "o......o", "gg....gg", ".ggoogg.", "..gggg..", "...ggn..", "...bb...", "........"]
const TINTA := {"g": Color(0.5, 0.52, 0.56), "o": Color(0.28, 0.3, 0.34), "b": Color(0.86, 0.86, 0.84), "n": Color(0.75, 0.42, 0.3)}

var tam := Vector2(16.0, 16.0)
var cuantas := 14

var _multi: MultiMesh
var _visible := MultiMeshInstance3D.new()
var _lugares: Array[Vector3] = []       # donde esta parada cada una (local)
var _destinos: Array[Vector3] = []      # a donde baja
var _fases: Array[float] = []
var _vuelo := -1.0                      # s que lleva la parvada en el aire (< 0: en el piso)
var _huida := Vector3.FORWARD
var _jugador: Node3D
var _ciclo: Node
var _reloj := 0.0
static var _textura: ImageTexture


func _ready() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash(String(name))
	for i in cuantas:
		_lugares.append(_al_azar(azar))
		_destinos.append(_lugares[i])
		_fases.append(azar.randf() * TAU)
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(TAMANO, TAMANO)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _atlas()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.uv1_scale = Vector3(0.5, 1.0, 1.0)
	cuadro.material = material
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = false
	_multi.mesh = cuadro
	_multi.instance_count = cuantas
	_visible.multimesh = _multi
	_visible.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visible.custom_aabb = AABB(Vector3(-tam.x - 20.0, -1.0, -tam.y - 20.0), Vector3(tam.x * 2.0 + 40.0, SUBE + 6.0, tam.y * 2.0 + 40.0))
	add_child(_visible)
	_poner()


func en_vuelo() -> bool:
	return _vuelo >= 0.0


func _al_azar(azar: RandomNumberGenerator) -> Vector3:
	return Vector3(azar.randf_range(-tam.x / 2.0, tam.x / 2.0), 0.0, azar.randf_range(-tam.y / 2.0, tam.y / 2.0))


func _process(delta: float) -> void:
	_reloj += delta
	if _ciclo == null:
		_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	var de_dia := _ciclo == null or float(_ciclo.valor()) < NOCHE_DESDE
	_visible.visible = de_dia
	if not de_dia:
		_vuelo = -1.0
		return
	if _vuelo < 0.0:
		if _jugador:
			var local := to_local(_jugador.global_position)
			local.y = 0.0
			var cerca := INF
			for lugar in _lugares:
				cerca = minf(cerca, local.distance_to(lugar))
			var velocidad := 0.0
			if _jugador is CharacterBody3D:
				velocidad = (_jugador as CharacterBody3D).velocity.length()
			if cerca < ESPANTA_CERCA or (cerca < ESPANTA_CORRIENDO and velocidad > RAPIDO):
				_espantar(local)
	else:
		_vuelo += delta
		if _vuelo >= VUELO:
			_vuelo = -1.0
			for i in cuantas:
				_lugares[i] = _destinos[i]
	_poner()


func _espantar(desde: Vector3) -> void:
	_vuelo = 0.0
	var centro := Vector3.ZERO
	for lugar in _lugares:
		centro += lugar / cuantas
	_huida = (centro - desde)
	_huida.y = 0.0
	_huida = _huida.normalized() if _huida.length() > 0.1 else Vector3.FORWARD
	var azar := RandomNumberGenerator.new()
	azar.randomize()
	for i in cuantas:
		_destinos[i] = _al_azar(azar)


func _poner() -> void:
	for i in cuantas:
		var donde := _lugares[i]
		var cuadro := 0.0                       # 0: en el piso; 0.5: volando (mitad derecha del atlas)
		var alto := TAMANO / 2.0
		if _vuelo >= 0.0:
			# Sube alejandose del susto, da la vuelta y baja a su destino
			var t := clampf((_vuelo - i * 0.05) / (VUELO - 0.7), 0.0, 1.0)
			var lado := Vector3(-_huida.z, 0.0, _huida.x)
			var arco := _huida * sin(t * PI) * 16.0 + lado * sin(t * TAU) * 6.0
			donde = _lugares[i].lerp(_destinos[i], smoothstep(0.0, 1.0, t)) + arco
			alto += sin(t * PI) * (SUBE + sin(_fases[i]) * 1.5)
			cuadro = 0.5 if t > 0.0 and t < 1.0 else 0.0
		else:
			# Picotea: un brinquito de vez en cuando
			alto += maxf(0.0, sin(_reloj * 5.0 + _fases[i]) - 0.9) * 0.5
		var escala := Vector3.ONE
		if cuadro > 0.0:
			# El aleteo: el cuadro se aplasta y se estira
			escala.y = 0.55 + 0.45 * absf(sin(_reloj * 14.0 + _fases[i]))
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(escala), donde + Vector3.UP * alto))
	# El cuadro del atlas es el mismo para toda la parvada (se espantan juntas)
	var material := (_multi.mesh as QuadMesh).material as StandardMaterial3D
	material.uv1_offset = Vector3(0.5 if _vuelo >= 0.0 else 0.0, 0.0, 0.0)


static func _atlas() -> ImageTexture:
	if _textura:
		return _textura
	var imagen := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0, 0, 0, 0))
	for n in 2:
		var dibujo: Array = DIBUJO_PISO if n == 0 else DIBUJO_VUELO
		for y in 8:
			var fila: String = dibujo[y]
			for x in 8:
				var c := fila[x]
				if TINTA.has(c):
					imagen.set_pixel(n * 8 + x, y, TINTA[c])
	_textura = ImageTexture.create_from_image(imagen)
	return _textura
