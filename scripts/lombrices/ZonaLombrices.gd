class_name ZonaLombrices
extends Node3D
# Un circulo en el piso que les hace algo a las lombrices (EnjambreLombrices._zonas lee el grupo
# "zonas_lombriz") y a veces a ti:
#   SAL: las empuja y se come sus cabezas; si te cae encima, quema las que traes pegadas.
#   FUEGO: las quema enteras (sin partirlas) y le pega a los sacos de la Madre; a ti tambien.
#   REPELE: un tambo prendido: las aleja. Patearlo (Player._golpear) lo tira y deja FUEGO.
#   LODO: el escupitajo de la Madre o el charco del carcamo: te frena y te puede quemar.
# `dura` 0 = para siempre.

enum Tipo { SAL, FUEGO, REPELE, LODO }

const ALUMBRADO := preload("res://scripts/map/MapAlumbrado.gd")

const COLOR_SAL := Color(0.95, 0.95, 0.9)
const COLOR_LODO := Color(0.12, 0.32, 0.28)
const FUEGO_CADA := 0.7
const FUEGO_DANO := 4
const FUEGO_LLAMAS := 22
const FUEGO_ALTO := 1.2            # alto de la llama del centro (m); hacia la orilla baja
const FUEGO_ALTO_ORILLA := 0.3
const FUEGO_RADIO_BASE := 2.0       # = Arrojadizo.FUEGO_RADIO
const FUEGO_OVALO := 0.68          # eje corto de la mancha / eje largo
const FUEGO_PUNTOS := 56
const LENGUA := preload("res://shaders/fuego_lengua.gdshader")
const MANCHA := preload("res://shaders/mancha_fuego.gdshader")
const PATADA_LARGO := 2.2

@export var tipo := Tipo.SAL
@export var radio := 2.0
@export var dura := 20.0
@export var dano := 0              # LODO: vida por segundo
@export var frena := 1.0           # LODO: x tu velocidad adentro
@export var ver := true            # false: sin disco (la alberca del carcamo ya se ve)

var _edad := 0.0
var _toca := 0.0
var _chupa := 0.0
var _jugador: Node3D
var _visual: Node3D
var _luz: OmniLight3D
var _pateado := false
var giro := NAN                   # FUEGO: hacia donde se alarga la mancha (NAN: al azar)
var _contorno: Array[float] = []   # FUEGO: radio de la mancha en cada angulo (FUEGO_PUNTOS)


static func crear(padre: Node, donde: Vector3, tipo_: Tipo, radio_: float, dura_: float, giro_ := NAN) -> ZonaLombrices:
	var zona := ZonaLombrices.new()
	zona.giro = giro_
	zona.tipo = tipo_
	zona.radio = radio_
	zona.dura = dura_
	# La posicion antes de entrar: _ready arma las llamas donde esta (antes salian en el origen,
	# que en el carcamo es el charco)
	zona.position = (padre as Node3D).to_local(donde) if padre is Node3D else donde
	padre.add_child(zona)
	return zona


func _ready() -> void:
	add_to_group("zonas_lombriz")
	if tipo == Tipo.REPELE:
		add_to_group("tambos_lombriz")
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	match tipo:
		Tipo.SAL:
			_disco(COLOR_SAL, 0.85)
			_bucles("sal_burbujas", 3, 0.25)
			Sonidos.tocar(self, "fizz", -8.0)
		Tipo.LODO:
			if ver:
				_disco(COLOR_LODO, 0.9)
			# El charco del carcamo (dura 0) ya tiene su superficie; el escupitajo burbujea
			if dura > 0.0:
				_bucles("lodo_charco", 1, radio * 0.35)
		Tipo.FUEGO:
			_llamas()


func _disco(color: Color, alfa: float) -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = radio
	disco.bottom_radius = radio
	disco.height = 0.02
	disco.radial_segments = 16
	disco.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alfa)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disco.material = material
	var malla := MeshInstance3D.new()
	malla.mesh = disco
	malla.position.y = 0.02
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla)
	_visual = malla


# Hojas de pixel que se repiten (EfectosPixel.cuadro_bucle; F9 las apaga como los demas)
func _bucles(hoja: String, cuantos: int, escala: float) -> void:
	for n in cuantos:
		var bucle := EfectosPixel.cuadro_bucle(hoja, escala, 1.0, 0.0, false, true)
		if bucle == null:
			return
		var a := TAU * n / cuantos + randf() * 0.5
		var r := 0.0 if cuantos == 1 else radio * 0.55
		bucle.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(bucle)


static var _quad_lengua: QuadMesh
static var _mat_lengua: ShaderMaterial


# Una lengua de fuego suelta (base en el origen del nodo), para las llamas, el trapo y el estallido
static func lengua(ancho: float, alto: float) -> MeshInstance3D:
	if _quad_lengua == null:
		_quad_lengua = QuadMesh.new()
		_quad_lengua.size = Vector2.ONE
		_quad_lengua.center_offset = Vector3(0.0, 0.5, 0.0)
		_mat_lengua = ShaderMaterial.new()
		_mat_lengua.shader = LENGUA
	var l := MeshInstance3D.new()
	l.mesh = _quad_lengua
	l.material_override = _mat_lengua
	l.set_instance_shader_parameter("semilla", randf())
	l.scale = Vector3(ancho, alto, 1.0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


# La bola de fuego al reventar la botella: lenguas que crecen y se apagan, chispas y un destello
static func estallido(padre: Node, donde: Vector3, radio_: float) -> void:
	var nodo := Node3D.new()
	padre.add_child(nodo)
	nodo.global_position = donde
	var k := radio_ / FUEGO_RADIO_BASE
	var lenguas: Array[MeshInstance3D] = []
	for n in 7:
		var a := randf() * TAU
		var r := (0.0 if n == 0 else randf_range(0.2, 0.9)) * radio_ * 0.5
		var l := lengua(0.4, 0.4)
		l.position = Vector3(cos(a) * r, 0.05, sin(a) * r)
		nodo.add_child(l)
		lenguas.append(l)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 6.0
	luz.omni_range = radio_ * 3.0
	luz.position.y = 0.8
	nodo.add_child(luz)
	var chispas := CPUParticles3D.new()
	chispas.amount = 30
	chispas.one_shot = true
	chispas.explosiveness = 0.95
	chispas.lifetime = 0.9
	chispas.direction = Vector3.UP
	chispas.spread = 70.0
	chispas.initial_velocity_min = 2.0
	chispas.initial_velocity_max = 5.0
	chispas.gravity = Vector3(0, -6.0, 0)
	chispas.color = Color(1.0, 0.65, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var punto := QuadMesh.new()
	punto.size = Vector2.ONE * 0.05
	punto.material = mat
	chispas.mesh = punto
	chispas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(chispas)
	chispas.emitting = true
	var tween := nodo.create_tween().set_parallel(true)
	for l in lenguas:
		var alto := randf_range(1.3, 2.0) * k
		tween.tween_property(l, "scale", Vector3(alto * 0.9, alto, 1.0), 0.45).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(v: float): l.set_instance_shader_parameter("opacidad", v), 1.0, 0.0, 0.55).set_delay(0.1)
	tween.tween_property(luz, "light_energy", 0.0, 0.5)
	tween.chain().tween_callback(nodo.queue_free).set_delay(0.5)


# Radio (m) de la mancha en el angulo `a`: un ovalo girado con ondulaciones, que nunca pasa de
# `radio` para que el circulo de dano la cubra entera
func _radio_mancha(a: float, giro: float, fases: Array[float]) -> float:
	var b := a - giro
	var ovalo := 1.0 / sqrt(cos(b) * cos(b) + sin(b) * sin(b) / (FUEGO_OVALO * FUEGO_OVALO))
	var ondas := 1.0 + 0.13 * sin(2.0 * a + fases[0]) + 0.10 * sin(3.0 * a + fases[1]) \
		+ 0.07 * sin(5.0 * a + fases[2]) + 0.04 * sin(9.0 * a + fases[3])
	return ovalo * ondas


# Un poligono (abanico) de la mancha, con COLOR.r = 0 al centro y 1 en la orilla
func _poligono(centro: Vector2, escala: float, giro: float, fases: Array[float]) -> ArrayMesh:
	var puntos := PackedVector3Array([Vector3(centro.x, 0.0, centro.y)])
	var colores := PackedColorArray([Color(0, 0, 0)])
	var indices := PackedInt32Array()
	for n in FUEGO_PUNTOS:
		var a := TAU * n / FUEGO_PUNTOS
		var r := _radio_mancha(a, giro, fases) * escala
		puntos.append(Vector3(centro.x + cos(a) * r, 0.0, centro.y + sin(a) * r))
		colores.append(Color(1, 0, 0))
	for n in FUEGO_PUNTOS:
		indices.append_array([0, 1 + n, 1 + (n + 1) % FUEGO_PUNTOS])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = puntos
	arrays[Mesh.ARRAY_COLOR] = colores
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malla


func _llamas() -> void:
	var visual := Node3D.new()
	add_child(visual)
	_visual = visual

	# La mancha: ovalada e irregular, distinta en cada molotov (con un par de salpicaduras)
	var rumbo := giro if not is_nan(giro) else randf() * TAU
	var fases: Array[float] = [randf() * TAU, randf() * TAU, randf() * TAU, randf() * TAU]
	var mayor := 0.0
	for n in FUEGO_PUNTOS:
		mayor = maxf(mayor, _radio_mancha(TAU * n / FUEGO_PUNTOS, rumbo, fases))
	var escala := radio / mayor
	_contorno.clear()
	for n in FUEGO_PUNTOS:
		_contorno.append(_radio_mancha(TAU * n / FUEGO_PUNTOS, rumbo, fases) * escala)
	var material := ShaderMaterial.new()
	material.shader = MANCHA
	material.set_shader_parameter("semilla", randf() * 50.0)
	var piso := MeshInstance3D.new()
	piso.mesh = _poligono(Vector2.ZERO, escala, rumbo, fases)
	piso.material_override = material
	piso.position.y = 0.03
	piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(piso)
	for n in 3:
		var a := randf() * TAU
		var chica: Array[float] = [randf() * TAU, randf() * TAU, randf() * TAU, randf() * TAU]
		var salpica := MeshInstance3D.new()
		var d := _contorno_en(a) + radio * randf_range(0.05, 0.18)
		salpica.mesh = _poligono(Vector2(cos(a), sin(a)) * d, escala * randf_range(0.1, 0.2), randf() * TAU, chica)
		salpica.material_override = material
		salpica.position.y = 0.03
		salpica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(salpica)

	# Las llamas: altas en el centro (FUEGO_ALTO), mas bajas hacia la orilla
	for n in FUEGO_LLAMAS:
		var u: float
		var a := randf() * TAU
		if n < 4:
			u = randf() * 0.12      # el corazon del fuego
		else:
			u = sqrt(randf()) * 0.88
		var alto := lerpf(FUEGO_ALTO, FUEGO_ALTO_ORILLA, pow(u, 1.3)) * randf_range(0.85, 1.0)
		if n == 0:
			alto = FUEGO_ALTO
			u = 0.0
		var lengua_ := lengua(alto * randf_range(0.8, 1.2), alto)
		var r := _contorno_en(a) * u
		lengua_.position = Vector3(cos(a) * r, 0.02, sin(a) * r)
		visual.add_child(lengua_)

	# Chispas que suben
	var chispas := CPUParticles3D.new()
	chispas.amount = 14
	chispas.lifetime = 1.4
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chispas.emission_sphere_radius = radio * 0.4
	chispas.direction = Vector3.UP
	chispas.spread = 25.0
	chispas.initial_velocity_min = 0.8
	chispas.initial_velocity_max = 1.8
	chispas.gravity = Vector3(0, 0.3, 0)
	chispas.color = Color(1.0, 0.6, 0.15)
	var chispa_mat := StandardMaterial3D.new()
	chispa_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chispa_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	chispa_mat.vertex_color_use_as_albedo = true
	var punto := QuadMesh.new()
	punto.size = Vector2.ONE * 0.04
	punto.material = chispa_mat
	chispas.mesh = punto
	chispas.position.y = 0.3
	chispas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(chispas)

	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.55, 0.2)
	_luz.light_energy = 2.0
	_luz.omni_range = radio * 2.5
	_luz.position.y = 0.8
	add_child(_luz)


# Radio de la mancha hacia el angulo `a` (interpolado entre los puntos del contorno)
func _contorno_en(a: float) -> float:
	if _contorno.is_empty():
		return radio
	var k := fposmod(a, TAU) / TAU * _contorno.size()
	var i := int(k) % _contorno.size()
	return lerpf(_contorno[i], _contorno[(i + 1) % _contorno.size()], k - floorf(k))


func _physics_process(delta: float) -> void:
	_edad += delta
	if dura > 0.0:
		var queda := dura - _edad
		if queda <= 0.0:
			queue_free()
			return
		# Se apaga el ultimo segundo
		if queda < 1.0:
			if _luz:
				_luz.light_energy = 2.0 * queda
			if _visual:
				_visual.scale = Vector3.ONE * maxf(queda, 0.05)
	if _luz and tipo == Tipo.FUEGO and (dura <= 0.0 or dura - _edad >= 1.0):
		_luz.light_energy = 2.0 * (1.0 + 0.18 * sin(_edad * 17.0) + 0.12 * sin(_edad * 31.0 + 1.3))
	if _jugador == null or not is_instance_valid(_jugador):
		return
	var adentro := Vector2(_jugador.global_position.x - global_position.x,
		_jugador.global_position.z - global_position.z).length() < radio \
		and absf(_jugador.global_position.y - 1.0 - global_position.y) < 1.5
	match tipo:
		Tipo.FUEGO:
			_toca -= delta
			if adentro and _toca <= 0.0 and _jugador.has_method("recibir_dano"):
				_toca = FUEGO_CADA
				_jugador.recibir_dano(FUEGO_DANO, global_position, 0.5)
		Tipo.LODO:
			if _jugador.get("lastres") != null:
				if adentro:
					_jugador.lastres[self] = frena
				else:
					_jugador.lastres.erase(self)
			if adentro and dano > 0:
				_chupa += dano * delta
				var salud := get_node_or_null("/root/Salud")
				if salud and _chupa >= 1.0:
					salud.vida -= int(_chupa)
					_chupa -= int(_chupa)


func _exit_tree() -> void:
	if _jugador and is_instance_valid(_jugador) and _jugador.get("lastres") != null:
		_jugador.lastres.erase(self)


# Un tambo pateado se cae y riega fuego hacia donde lo pateaste
func patear(hacia: Vector3) -> void:
	if tipo != Tipo.REPELE or _pateado:
		return
	_pateado = true
	hacia.y = 0.0
	var donde := global_position + hacia.normalized() * PATADA_LARGO
	ZonaLombrices.crear(get_parent(), donde, Tipo.FUEGO, 1.8, 10.0)
	for hijo in get_children():
		if hijo is Node3D:
			(hijo as Node3D).rotation.z = deg_to_rad(80.0)
	radio = 0.0
	remove_from_group("zonas_lombriz")
