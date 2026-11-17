class_name CriaCucarrata
extends Node3D
# Las crias que la cucarrata suelta por la cola (Cucarrata.parir): ratas grises y cucarachas cafes
# voladoras, las dos del tamano de un chihuahua (~0.45 m de largo), con la piel de la cucarrata
# (shaders/cucarrata.gdshader). No son la cucarrata escalada: con su escala las grietas quedarian
# de milimetros, asi que cada una lleva sus propias celdas, grandes y en pixeles gruesos, y brilla
# mas. Mismos modelos que la cucarrata (rata.glb entera y cucaracha.glb con su cabeza).
# Solo el modelo por ahora: el diseno del jefe (que hacen, vida, dano) esta pendiente (JJ).

enum Tipo { RATA, CUCARACHA }

# Rata: la del glb mide 1.52 m de alto y 3.5 m sin la cola; a 0.145 queda de ~0.22 m de alto y
# ~0.5 m de largo, mas la cola
const RATA_ESCALA := 0.145
# El punto de la rata del glb que queda en el origen: entre las patas, a media panza
const RATA_ORIGEN := Vector3(0.01, -0.95, -1.15)
const RATA_COLOR := Color(0.8, 0.8, 0.82)   # mas claro que la cabeza de la cucarrata: chica se veia negra
# Cucaracha: ~1.5 m de cuerpo en el glb; a 0.3 queda de ~0.45 m
const CUCARACHA_ESCALA := 0.3
const CUCARACHA_COLOR := Color(0.66, 0.44, 0.28)
# Celdas de la piel de las crias: pocas y grandes (la cucarrata lleva 12 en el cuerpo y 18 en la
# cabeza), y pixeles mas gruesos, para que las grietas se lean a su tamano
const CELDAS_RATA := Vector2(6.0, 6.0)
const CELDAS_CUCARACHA := Vector2(5.0, 5.0)
const PIXELES := Vector2(64.0, 64.0)
const BRILLO := 1.5
const OJO_RADIO := 0.05   # en metros de la rata del glb, antes de escalar

enum Estado { QUIETA, AIRE, SUELO, VUELA }
const GRAVEDAD := 9.8
const RATA_CORRE := 0.9          # segundos que corre al caer
const RATA_VELOCIDAD := 2.6
const ALTURA_VUELO := Vector2(1.0, 1.8)   # metros sobre el piso donde revolotean las cucarachas

@export var tipo := Tipo.RATA
@export var animacion_inicial := "vuela"   # solo la cucaracha

static var _malla_rata: ArrayMesh
static var _malla_cucaracha: ArrayMesh
static var _mat_rata: ShaderMaterial
static var _mat_cucaracha: ShaderMaterial

var anim: AnimationPlayer   # la cucaracha
var _modelo: Node3D
var _t := randf() * 10.0
var _estado := Estado.QUIETA
var _vel := Vector3.ZERO
var _piso := 0.0
var _altura := 0.0
var _corre := 0.0


func _ready() -> void:
	if tipo == Tipo.RATA:
		_armar_rata()
	else:
		_armar_cucaracha()


func animar(corto: String, mezcla := 0.15) -> void:
	if anim:
		var n: String = "giant_cockroach_armature|" + Cucarrata.ANIMS.get(corto, corto)
		if anim.has_animation(n):
			anim.play(n, mezcla)


# Sale de la cola de la cucarrata (Cucarrata._soltar): vuela en arco hasta el piso (piso_y). La
# rata cae y corre un rato hacia donde cayo; la cucaracha abre las alas en el aire y sube a
# revolotear. Solo el vistazo: lo que hagan despues (perseguir, morder) es del diseno pendiente
func lanzar(velocidad: Vector3, piso_y: float) -> void:
	_vel = velocidad
	_piso = piso_y
	_estado = Estado.AIRE
	if tipo == Tipo.CUCARACHA:
		animar("vuela", 0.1)
		_altura = piso_y + randf_range(ALTURA_VUELO.x, ALTURA_VUELO.y)


func _process(delta: float) -> void:
	_t += delta
	match _estado:
		Estado.AIRE:
			_vel.y -= GRAVEDAD * delta
			global_position += _vel * delta
			if tipo == Tipo.RATA:
				rotation.x -= delta * 9.0   # da vueltas en el aire
				if global_position.y <= _piso and _vel.y < 0.0:
					global_position.y = _piso
					rotation.x = 0.0
					var plano := Vector3(_vel.x, 0, _vel.z)
					if plano.length() > 0.1:
						look_at(global_position + plano, Vector3.UP)   # la nariz es -Z: sigue de frente
					_corre = RATA_CORRE
					_estado = Estado.SUELO
			elif _vel.y < 0.0:
				_estado = Estado.VUELA
		Estado.SUELO:
			if _corre > 0.0:
				_corre -= delta
				global_position += -global_transform.basis.z * RATA_VELOCIDAD * delta
		Estado.VUELA:
			# Sube a su altura y se queda revoloteando, frenando lo que traia
			_vel = _vel.lerp(Vector3.ZERO, delta * 2.0)
			_vel.y = (_altura - global_position.y) * 2.0
			global_position += _vel * delta + Vector3(sin(_t * 2.3), sin(_t * 3.1) * 0.6, cos(_t * 1.9)) * 0.25 * delta
	if tipo == Tipo.RATA and _estado != Estado.AIRE:
		# La rata no tiene esqueleto: olfatea quieta y rebota rapido al correr
		var rapido := 22.0 if _corre > 0.0 else 9.0
		_modelo.rotation.x = sin(_t * rapido) * (0.08 if _corre > 0.0 else 0.04 * maxf(0.0, sin(_t * 1.3)))
		_modelo.position.y = absf(sin(_t * rapido)) * (0.02 if _corre > 0.0 else 0.006)


func _armar_rata() -> void:
	if _malla_rata == null:
		_malla_rata = _rata_entera()
	if _mat_rata == null:
		_mat_rata = Cucarrata.material_piel(_malla_rata.surface_get_material(0), 0.5, 1.0)
		_mat_rata.set_shader_parameter("hundido", 0.6)
		_mat_rata.set_shader_parameter("color_piel", RATA_COLOR)
		_mat_rata.set_shader_parameter("escala_celdas", CELDAS_RATA)
		_mat_rata.set_shader_parameter("pixeles", PIXELES)
		_mat_rata.set_shader_parameter("brillo", BRILLO)
		# Sin el degradado hacia la cola de la cucarrata: parejo en todo el cuerpo
		_mat_rata.set_shader_parameter("cola_desde", -100.0)
		_mat_rata.set_shader_parameter("cola_hasta", 50.0)
	_modelo = Node3D.new()
	add_child(_modelo)
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = _malla_rata
	cuerpo.material_override = _mat_rata
	_modelo.add_child(cuerpo)
	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = OJO_RADIO * RATA_ESCALA
		esfera.height = esfera.radius * 2.0
		esfera.radial_segments = 6
		esfera.rings = 3
		ojo.mesh = esfera
		ojo.material_override = Cucarrata.material_ojo()
		var o := Cucarrata.OJO
		ojo.position = _de_rata(Vector3(0.01 + (o.x - 0.01) * lado, o.y, o.z))
		_modelo.add_child(ojo)


# De la rata del glb (nariz +Z) a la cria: nariz hacia -Z como la cucarrata, escalada y con
# RATA_ORIGEN en el origen
static func _de_rata(p: Vector3) -> Vector3:
	var q := (p - RATA_ORIGEN) * RATA_ESCALA
	return Vector3(-q.x, q.y, -q.z)


static func _rata_entera() -> ArrayMesh:
	var rata: Node3D = Cucarrata.RATA.instantiate()
	var mi: MeshInstance3D = rata.find_children("*", "MeshInstance3D", true, false)[0]
	var t := Transform3D()
	var n: Node = mi
	while n != rata:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		var d := t.basis * normales[i]
		st.set_normal(Vector3(-d.x, d.y, -d.z).normalized())
		st.set_uv(uv[i])
		st.add_vertex(_de_rata(t * v[i]))
	var malla := st.commit()
	malla.surface_set_material(0, mi.mesh.surface_get_material(0))
	rata.free()
	return malla


func _armar_cucaracha() -> void:
	_modelo = Cucarrata.CUCARACHA.instantiate()
	_modelo.scale = Vector3.ONE * CUCARACHA_ESCALA
	add_child(_modelo)
	var esq: Skeleton3D = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	anim = _modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var cuerpo: MeshInstance3D = _modelo.find_children("*", "MeshInstance3D", true, false)[0]
	if _malla_cucaracha == null:
		_malla_cucaracha = Cucarrata.preparar_cucaracha(cuerpo.mesh, cuerpo.skin, esq, false)
	cuerpo.mesh = _malla_cucaracha
	if _mat_cucaracha == null:
		_mat_cucaracha = Cucarrata.material_piel(cuerpo.mesh.surface_get_material(0), 0.6, 1.0)
		_mat_cucaracha.set_shader_parameter("color_piel", CUCARACHA_COLOR)
		_mat_cucaracha.set_shader_parameter("escala_celdas", CELDAS_CUCARACHA)
		_mat_cucaracha.set_shader_parameter("pixeles", PIXELES)
		_mat_cucaracha.set_shader_parameter("brillo", BRILLO)
		_mat_cucaracha.set_shader_parameter("antenas", true)
		_mat_cucaracha.set_shader_parameter("antena_tramos", 5.0)
		_mat_cucaracha.set_shader_parameter("cola_desde", -100.0)
		_mat_cucaracha.set_shader_parameter("cola_hasta", 50.0)
	cuerpo.material_override = _mat_cucaracha
	for corto in Cucarrata.EN_CICLO:
		var a := anim.get_animation("giant_cockroach_armature|" + Cucarrata.ANIMS[corto])
		if a: a.loop_mode = Animation.LOOP_LINEAR
	animar(animacion_inicial)
