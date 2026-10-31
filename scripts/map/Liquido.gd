class_name Liquido
extends Node3D

# El agua sucia y la sangre (docs/especificaciones.md 4.2): gotas pesadas que salen de adentro
# del cuerpo, se estiran al volar, caen con gravedad y dejan una mancha donde tocan el piso.
# CPUParticles3D no dice donde cae cada una, asi que se simulan aqui. Son dos MultiMesh: una
# llamada de dibujo por cada uno, por muchas gotas que haya, y un solo material. Las gotas
# avanzan con el tiempo del juego, asi que en la congelada de un golpe se quedan quietas y
# salen al soltar. Una por escena: la crea Zombis.gd y la encuentran por el grupo `liquido`.

const MAX_GOTAS := 256
const MAX_MANCHAS := 60
const GRAVEDAD := 14.0
const GOTA_GRUESO := Vector2(0.06, 0.13)
const GOTA_LARGO := 0.035      # m por m/s: entre mas rapido, mas estirada
const GOTA_ESTIRA_MAX := 2.8   # nunca mas larga que esto por lo gruesa que es
const MANCHA_LADO := Vector2(0.18, 0.5)
const MANCHA_DURA := 15000     # ms
const MANCHA_APAGA := 5000     # ms antes del final en que empieza a desvanecerse
const MANCHA_ALTO := 0.045     # m sobre el piso
const MANCHA_ALFA := 0.9
const MANCHA_CADA := 0.25      # s entre revisar cuales se apagan
const MANCHA_FRACCION := 0.6   # no todas las gotas dejan mancha
const OSCURECE := 0.3          # que tan distinta sale cada gota de su color
const ORILLAS := 11

var cuantas := 0

var _gotas: MultiMesh
var _manchas: MultiMesh
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _piso := PackedFloat32Array()
var _grueso := PackedFloat32Array()
var _color := PackedColorArray()
var _nacio := PackedInt64Array()
var _color_mancha := PackedColorArray()
var _siguiente := 0
var _espera := 0.0


func _ready() -> void:
	add_to_group("liquido")
	_pos.resize(MAX_GOTAS)
	_vel.resize(MAX_GOTAS)
	_piso.resize(MAX_GOTAS)
	_grueso.resize(MAX_GOTAS)
	_color.resize(MAX_GOTAS)
	_nacio.resize(MAX_MANCHAS)
	_color_mancha.resize(MAX_MANCHAS)
	# De pocas caras, como todo en un juego de PS1: de un metro y se escala en cada gota
	var gota := SphereMesh.new()
	gota.radius = 0.5
	gota.height = 1.0
	gota.radial_segments = 6
	gota.rings = 3
	_gotas = _multimesh(gota, MAX_GOTAS, false)
	_manchas = _multimesh(_malla_mancha(), MAX_MANCHAS, true)
	for i in MAX_MANCHAS:
		_nacio[i] = -1
		_manchas.set_instance_transform(i, _nada())
		_manchas.set_instance_color(i, Color(0, 0, 0, 0))
	# Una gota sin tamano siempre dibujada: asi su material se compila al cargar y no en el
	# primer golpe
	_gotas.set_instance_transform(0, _nada())
	_gotas.visible_instance_count = 1


func _multimesh(malla: Mesh, cuantos: int, transparente: bool) -> MultiMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	# Si no, los colores oscuros salen deslavados
	material.vertex_color_is_srgb = true
	if transparente:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = malla
	multimesh.instance_count = cuantos
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = multimesh
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Las gotas andan por todo el mapa
	instancia.custom_aabb = AABB(Vector3(-2000.0, -50.0, -2000.0), Vector3(4000.0, 200.0, 4000.0))
	add_child(instancia)
	return multimesh


func _nada() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)


# Una mancha dispareja, plana en el piso, de un metro de lado: se escala y se gira en cada una
func _malla_mancha() -> ArrayMesh:
	var azar := RandomNumberGenerator.new()
	azar.seed = 71
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var orilla := []
	for i in ORILLAS:
		var giro := TAU * i / ORILLAS
		var radio := azar.randf_range(0.28, 0.5)
		orilla.append(Vector3(cos(giro) * radio, 0.0, sin(giro) * radio))
	for i in ORILLAS:
		for punto: Vector3 in [Vector3.ZERO, orilla[(i + 1) % ORILLAS], orilla[i]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(punto)
	return st.commit()


# Gotas hacia `hacia`, saliendo de adentro de la esfera de `radio` alrededor de `origen`.
# `abre`: que tanto se dispersan (0 todas derecho, 1 como 45 grados). `piso`: donde caen.
func salpicar(origen: Vector3, radio: float, piso: float, hacia: Vector3, cantidad: int, color: Color, velocidad: Vector2, abre: float) -> void:
	for i in cantidad:
		var d := (hacia + _al_azar() * abre).normalized()
		_nueva(origen + _al_azar() * randf() * radio, d * randf_range(velocidad.x, velocidad.y), piso, color)


# Para todos lados y sobre todo hacia arriba: un globo que truena
func reventar(origen: Vector3, radio: float, piso: float, cantidad: int, color: Color, velocidad: Vector2) -> void:
	for i in cantidad:
		var d := _al_azar()
		d.y = absf(d.y) * 0.8 + 0.1
		_nueva(origen + _al_azar() * randf() * radio, d.normalized() * randf_range(velocidad.x, velocidad.y), piso, color)


func _al_azar() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()


func _nueva(donde: Vector3, velocidad: Vector3, piso: float, color: Color) -> void:
	# Lleno: se pierde la mas vieja de las que siguen en el aire
	var i := cuantas if cuantas < MAX_GOTAS else randi() % MAX_GOTAS
	if cuantas < MAX_GOTAS:
		cuantas += 1
	_pos[i] = donde
	_vel[i] = velocidad
	_piso[i] = piso
	_grueso[i] = randf_range(GOTA_GRUESO.x, GOTA_GRUESO.y)
	_color[i] = color.darkened(randf() * OSCURECE)
	_gotas.set_instance_color(i, _color[i])
	_gotas.set_instance_transform(i, _transformar(i))
	_gotas.visible_instance_count = maxi(cuantas, 1)


func _process(delta: float) -> void:
	_mover(delta)
	_espera -= delta
	if _espera <= 0.0:
		_espera = MANCHA_CADA
		_apagar_manchas()


func _mover(delta: float) -> void:
	if delta <= 0.0 or cuantas == 0:
		return
	var i := 0
	while i < cuantas:
		_vel[i].y -= GRAVEDAD * delta
		_pos[i] += _vel[i] * delta
		if _pos[i].y <= _piso[i]:
			_caer(i)
			# La ultima toma su lugar y se revisa en esta misma vuelta
			continue
		_gotas.set_instance_transform(i, _transformar(i))
		i += 1
	if cuantas == 0:
		_gotas.set_instance_transform(0, _nada())
	_gotas.visible_instance_count = maxi(cuantas, 1)


# Cubo alargado en la direccion en que va
func _transformar(i: int) -> Transform3D:
	var v := _vel[i]
	var rapidez := v.length()
	var largo := clampf(rapidez * GOTA_LARGO, _grueso[i], _grueso[i] * GOTA_ESTIRA_MAX)
	var z := v / rapidez if rapidez > 0.01 else Vector3.UP
	var x := z.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := x.cross(z)
	return Transform3D(Basis(x * _grueso[i], y * _grueso[i], z * largo), _pos[i])


func _caer(i: int) -> void:
	if randf() < MANCHA_FRACCION:
		_mancha(Vector3(_pos[i].x, _piso[i], _pos[i].z), _color[i])
	cuantas -= 1
	if i < cuantas:
		_pos[i] = _pos[cuantas]
		_vel[i] = _vel[cuantas]
		_piso[i] = _piso[cuantas]
		_grueso[i] = _grueso[cuantas]
		_color[i] = _color[cuantas]
		_gotas.set_instance_color(i, _color[i])


# En reloj real, y la mas vieja deja su lugar: siempre hay MAX_MANCHAS o menos
func _mancha(donde: Vector3, color: Color) -> void:
	var i := _siguiente
	_siguiente = (_siguiente + 1) % MAX_MANCHAS
	_nacio[i] = Time.get_ticks_msec()
	var oscura := color.darkened(0.25)
	oscura.a = MANCHA_ALFA
	_color_mancha[i] = oscura
	var lado := randf_range(MANCHA_LADO.x, MANCHA_LADO.y)
	# Cada una un poco mas alta que la anterior, para que dos encimadas no parpadeen
	var alto := MANCHA_ALTO + 0.0004 * i
	_manchas.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(lado, 1.0, lado)), donde + Vector3.UP * alto))
	_manchas.set_instance_color(i, oscura)


func _apagar_manchas() -> void:
	var ahora := Time.get_ticks_msec()
	for i in MAX_MANCHAS:
		if _nacio[i] < 0:
			continue
		var edad := ahora - _nacio[i]
		if edad >= MANCHA_DURA:
			_nacio[i] = -1
			_manchas.set_instance_transform(i, _nada())
		elif edad >= MANCHA_DURA - MANCHA_APAGA:
			var color := _color_mancha[i]
			color.a = MANCHA_ALFA * float(MANCHA_DURA - edad) / MANCHA_APAGA
			_manchas.set_instance_color(i, color)


func manchas_vivas() -> int:
	var n := 0
	for i in MAX_MANCHAS:
		if _nacio[i] >= 0:
			n += 1
	return n


# Las teclas de prueba y los reinicios
func limpiar() -> void:
	cuantas = 0
	_gotas.set_instance_transform(0, _nada())
	_gotas.visible_instance_count = 1
	for i in MAX_MANCHAS:
		_nacio[i] = -1
		_manchas.set_instance_transform(i, _nada())
