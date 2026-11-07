class_name CajaBotin
extends Node3D

# Cajitas de botin como las de Kingdom Hearts (propuesta de AG): un zombi que matas suelta
# una caja por cada material (Materiales.botin) y unas monedas con sus pesos. Salen
# brincando, rebotan en el piso, brillan con chispitas de pixel y, pasado un ratito, se
# le juntan al jugador que este cerca y se recogen solas con una campanita.
#   - Color por nivel: suelto morado y oro, bueno rojo y plata, fino azul y blanco,
#     especial verde. Las monedas son de oro.
#   - Sin cangurera las cajas de material no se juntan: se quedan en el piso y avisan
#     (Tiliches.puede_guardar). Las monedas y los trofeos si.
#   - Duran VIDA s (parpadean al final). Hay a lo mucho MAXIMO cajas y MAXIMO monedas: la
#     mas vieja se va.
#   - Los tiempos usan el delta del juego, asi se quedan colgadas en la congelada de los
#     golpes (Engine.time_scale) igual que todo lo demas.
# Mallas y materiales compartidos (static var): nada por instancia. No nombra autoloads:
# Zombie.gd, que la usa, lo cargan scripts de tools/.

enum Tipo { SUELTO, BUENO, FINO, ESPECIAL, MONEDA }

const VIDA := 30.0
const PARPADEA := 5.0          # s del final en que parpadea
const MAXIMO := 24             # cajas vivas (y otras tantas monedas)
const GRACIA := 0.35           # s antes de que se junte: que se vea salir
const RADIO := 4.0             # m a los que se te junta
const ACELERA := 40.0          # m/s2 hacia el jugador
const VELOCIDAD_MAX := 26.0    # mas que el jugador corriendo (18)
const RECOGE := 0.6            # m al pecho para recogerla
const PECHO := 0.9
const GRAVEDAD := 18.0
const REBOTE := 0.45           # cuanto de la velocidad vertical le queda al rebotar
const FRENO := 0.7             # y de la horizontal
const QUIETA := 0.6            # m/s: abajo de eso ya no rebota
const GIRO := 2.2              # rad/s
const FLOTA := 0.06            # m que sube y baja quieta
const ALTO := 0.12             # m del centro de la caja al piso
const LEJOS := 45.0            # m hasta donde se dibuja
const CHISPAS_LEJOS := 30.0
const SALTO := Vector2(4.0, 6.0)
const ABRE := 2.0
const VOLUMEN := -6.0
# cuerpo, adornos (tapa, cinchos, chapa)
const COLORES := {
	Tipo.SUELTO: [Color(0.42, 0.16, 0.62), Color(1.0, 0.8, 0.22)],
	Tipo.BUENO: [Color(0.75, 0.12, 0.14), Color(0.82, 0.84, 0.9)],
	Tipo.FINO: [Color(0.14, 0.32, 0.85), Color(0.96, 0.97, 1.0)],
	Tipo.ESPECIAL: [Color(0.12, 0.6, 0.28), Color(0.95, 0.85, 0.35)],
	Tipo.MONEDA: [Color(1.0, 0.78, 0.18), Color(1.0, 0.92, 0.5)],
}

static var _mallas := {}            # Tipo -> Mesh
static var _chispas := {}           # Tipo -> ParticleProcessMaterial
static var _material: StandardMaterial3D
static var _cuadro: QuadMesh
static var _vivas: Array = []       # sin tipo: una ya borrada no se convierte
static var _monedas: Array = []

var tipo := Tipo.SUELTO
var material := ""     # id de Materiales, o "" en una moneda
var pesos := 0

var _velocidad := Vector3.ZERO
var _suelo := NAN
var _quieta := false
var _edad := 0.0
var _jugador: Node3D
var _cerca := false
var _jalando := false
var _rapidez := 0.0
var _modelo: MeshInstance3D
var _particulas: GPUParticles3D


# Suelta el botin de un zombi: una caja por material y de 1 a 3 monedas con `pesos`.
# `abre` multiplica que tan lejos salen (el jefe, mas)
static func soltar(padre: Node, desde: Vector3, materiales: Dictionary, pesos_total: int, abre := 1.0) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	for id: String in materiales:
		for i in int(materiales[id]):
			var caja := CajaBotin.new()
			caja.material = id
			caja.tipo = tipo_de(id)
			_lanzar(padre, caja, desde, abre)
	if pesos_total > 0:
		var cuantas := mini(pesos_total, 3)
		for i in cuantas:
			var moneda := CajaBotin.new()
			moneda.tipo = Tipo.MONEDA
			# Se reparten parejo; lo que sobra va en las primeras
			moneda.pesos = pesos_total / cuantas + (1 if i < pesos_total % cuantas else 0)
			_lanzar(padre, moneda, desde, abre)


static func tipo_de(id: String) -> Tipo:
	var dato := Materiales.dato(id)
	if dato.get("clase", -1) != Materiales.Clase.COMUN:
		return Tipo.ESPECIAL
	return [Tipo.SUELTO, Tipo.BUENO, Tipo.FINO][clampi(dato.get("nivel", 0), 0, 2)]


static func _lanzar(padre: Node, caja: CajaBotin, desde: Vector3, abre: float) -> void:
	var lista := _monedas if caja.tipo == Tipo.MONEDA else _vivas
	lista.assign(lista.filter(func(c) -> bool: return is_instance_valid(c)))
	while lista.size() >= MAXIMO:
		lista.pop_front().queue_free()
	lista.append(caja)
	caja._velocidad = Vector3(randf_range(-ABRE, ABRE) * abre, randf_range(SALTO.x, SALTO.y), randf_range(-ABRE, ABRE) * abre)
	padre.add_child(caja)
	caja.global_position = desde


func _ready() -> void:
	add_to_group("botin")
	_preparar()
	_modelo = MeshInstance3D.new()
	_modelo.mesh = _mallas[tipo]
	_modelo.material_override = _material
	_modelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_modelo.visibility_range_end = LEJOS
	_modelo.rotation.y = randf() * TAU
	add_child(_modelo)
	_particulas = GPUParticles3D.new()
	_particulas.amount = 6
	_particulas.lifetime = 1.1
	_particulas.randomness = 0.5
	_particulas.process_material = _chispas[tipo]
	_particulas.draw_pass_1 = _cuadro
	_particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particulas.visibility_range_end = CHISPAS_LEJOS
	_particulas.visibility_aabb = AABB(Vector3(-0.6, -0.3, -0.6), Vector3(1.2, 1.6, 1.2))
	add_child(_particulas)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = _radio()
	forma.shape = esfera
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_entro)
	area.body_exited.connect(_salio)


# Iman (Tazos.gd) junta desde mas lejos
func _radio() -> float:
	var tazos := get_node_or_null("/root/Tazos")
	if tazos and tazos.tiene("iman"):
		return maxf(RADIO, Habilidades.IMAN_RADIO)
	return RADIO


func _entro(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		_jugador = cuerpo
		_cerca = true
		if not _cabe():
			get_node("/root/Tiliches").avisar_sin_cangurera()


func _salio(cuerpo: Node3D) -> void:
	if cuerpo == _jugador:
		_cerca = false


func _cabe() -> bool:
	if material == "":
		return true
	var tiliches := get_node_or_null("/root/Tiliches")
	return tiliches != null and tiliches.puede_guardar(material)


func _physics_process(delta: float) -> void:
	# En una tienda, una maquinita o el dron no se mueve ni envejece
	if _jugador and not (_jugador.can_process() and _jugador.is_physics_processing()):
		return
	_edad += delta
	if _edad >= VIDA:
		queue_free()
		return
	if _edad > VIDA - PARPADEA:
		_modelo.visible = fmod(_edad * 8.0, 1.0) < 0.6
	_modelo.rotation.y += GIRO * delta
	if not _jalando and _cerca and _edad >= GRACIA and _cabe():
		_jalando = true
		_rapidez = maxf(_velocidad.length(), 2.0)
		_particulas.emitting = false
	if _jalando:
		_jalar(delta)
	elif _quieta:
		_modelo.position.y = sin(_edad * 3.0) * FLOTA + FLOTA
	else:
		_brincar(delta)


func _brincar(delta: float) -> void:
	if is_nan(_suelo):
		_suelo = _buscar_suelo()
	_velocidad.y -= GRAVEDAD * delta
	global_position += _velocidad * delta
	if global_position.y <= _suelo + ALTO and _velocidad.y < 0.0:
		global_position.y = _suelo + ALTO
		_velocidad.y = -_velocidad.y * REBOTE
		_velocidad.x *= FRENO
		_velocidad.z *= FRENO
		if _velocidad.y < QUIETA:
			_velocidad = Vector3.ZERO
			_quieta = true


func _buscar_suelo() -> float:
	var consulta := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 8.0, 1)
	var choque := get_world_3d().direct_space_state.intersect_ray(consulta)
	return choque.position.y if choque else global_position.y - 1.0


func _jalar(delta: float) -> void:
	var hacia := _jugador.global_position + Vector3.UP * PECHO
	_rapidez = minf(_rapidez + ACELERA * delta, VELOCIDAD_MAX)
	global_position = global_position.move_toward(hacia, _rapidez * delta)
	if global_position.distance_to(hacia) <= RECOGE:
		_recoger()


func _recoger() -> void:
	if material != "":
		get_node("/root/Tiliches").dar(material, 1)
	elif pesos > 0:
		var cartera := get_node_or_null("/root/Cartera")
		if cartera:
			cartera.pesos += pesos
	var voz := AudioStreamPlayer3D.new()
	voz.stream = Sonidos.sonido("botin")
	voz.volume_db = VOLUMEN
	voz.pitch_scale = randf_range(1.05, 1.2)
	voz.finished.connect(voz.queue_free)
	get_parent().add_child(voz)
	voz.global_position = global_position
	voz.play()
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos:
		efectos.lanzar("recoger", global_position, Vector3.ZERO, 0.6)
	queue_free()


# --- Mallas y materiales, una vez ---

static func _preparar() -> void:
	if _material:
		return
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Sin luz las normales no importan: asi no hay que cuidar el sentido de las caras
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pixel := StandardMaterial3D.new()
	pixel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pixel.vertex_color_use_as_albedo = true
	pixel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pixel.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pixel.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pixel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cuadro = QuadMesh.new()
	# Los billboards no hacen caso a la escala de la particula: el tamano va aqui
	_cuadro.size = Vector2(0.05, 0.05)
	_cuadro.material = pixel
	for t: int in COLORES:
		_mallas[t] = _moneda(COLORES[t]) if t == Tipo.MONEDA else _cofre(COLORES[t])
		_chispas[t] = _chispa(COLORES[t][1])


static func _chispa(color: Color) -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.0, 0.4, 0.0)
	# Titila: prende, se apaga, prende y se va
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.25, 0.45, 0.65, 1.0])
	rampa.colors = PackedColorArray([Color(color, 0.0), Color(color, 1.0), Color(color, 0.2), Color(color, 1.0), Color(color, 0.0)])
	var textura := GradientTexture1D.new()
	textura.gradient = rampa
	p.color_ramp = textura
	return p


# Un cofrecito facetado: cuerpo, tapa con bisel, dos cinchos y la chapa
static func _cofre(colores: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuerpo: Color = colores[0]
	var adorno: Color = colores[1]
	_tronco(st, Vector3(0.0, -0.04, 0.0), Vector2(0.3, 0.2), Vector2(0.3, 0.2), 0.16, cuerpo)
	_tronco(st, Vector3(0.0, 0.06, 0.0), Vector2(0.32, 0.22), Vector2(0.32, 0.22), 0.04, adorno)
	_tronco(st, Vector3(0.0, 0.11, 0.0), Vector2(0.3, 0.2), Vector2(0.22, 0.1), 0.06, cuerpo.lightened(0.15))
	for x in [-0.09, 0.09]:
		_tronco(st, Vector3(x, -0.03, 0.0), Vector2(0.035, 0.21), Vector2(0.035, 0.21), 0.18, adorno)
	_tronco(st, Vector3(0.0, 0.03, 0.105), Vector2(0.05, 0.02), Vector2(0.05, 0.02), 0.06, adorno.lightened(0.3))
	return st.commit()


# Una moneda de ocho lados, parada para que se vea al girar
static func _moneda(colores: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LADOS := 8
	const R := 0.12
	const GRUESO := 0.025
	var cara: Color = colores[0]
	var canto: Color = colores[1]
	for i in LADOS:
		var a := TAU * i / LADOS
		var b := TAU * (i + 1) / LADOS
		var pa := Vector3(cos(a) * R, sin(a) * R, 0.0)
		var pb := Vector3(cos(b) * R, sin(b) * R, 0.0)
		var frente := Vector3(0.0, 0.0, GRUESO)
		_tri(st, frente, pa + frente, pb + frente, cara)
		_tri(st, -frente, pb - frente, pa - frente, cara.darkened(0.15))
		_cuad(st, pa + frente, pa - frente, pb - frente, pb + frente, canto)
	return st.commit()


# Un tronco de piramide: base `abajo` (x, z), tapa `arriba`, de `alto`, centrado en `centro`
static func _tronco(st: SurfaceTool, centro: Vector3, abajo: Vector2, arriba: Vector2, alto: float, color: Color) -> void:
	var h := alto * 0.5
	var b := [
		centro + Vector3(-abajo.x, -alto, -abajo.y) * 0.5, centro + Vector3(abajo.x, -alto, -abajo.y) * 0.5,
		centro + Vector3(abajo.x, -alto, abajo.y) * 0.5, centro + Vector3(-abajo.x, -alto, abajo.y) * 0.5,
	]
	var t := [
		centro + Vector3(-arriba.x * 0.5, h, -arriba.y * 0.5), centro + Vector3(arriba.x * 0.5, h, -arriba.y * 0.5),
		centro + Vector3(arriba.x * 0.5, h, arriba.y * 0.5), centro + Vector3(-arriba.x * 0.5, h, arriba.y * 0.5),
	]
	# Caras con un poco de sombra pintada, para que se lea facetado sin luz
	_cuad(st, t[3], t[2], t[1], t[0], color.lightened(0.2))
	_cuad(st, b[0], b[1], b[2], b[3], color.darkened(0.4))
	for i in 4:
		var j := (i + 1) % 4
		_cuad(st, b[j], b[i], t[i], t[j], color.darkened(0.12 * (i % 2) + 0.05))


static func _cuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)
