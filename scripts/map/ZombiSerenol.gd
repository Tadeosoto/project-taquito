class_name ZombiSerenol
extends RefCounted
# El zombi normal (JJ, 2026-11-17): el monstruo_02 del pack PSX con la piel del Panzon (placas de
# piedra y grietas de Serenol, shaders/zombi_serenol.gdshader) en sus ASPECTOS: hombres sin camisa
# o con una camisa desgarrada, y mujeres con pelo largo ralo (PeloZombi). Zombie.modelo_skin lo usa
# para todos los normales (hordas, defensas, apariciones y la pantalla de inicio).
#
# El shader dibuja las grietas sobre la pose de reposo de cada vertice (centrada y en metros) que va
# en CUSTOM0: asi no resbalan al animar. La malla del fbx viene girada contra su esqueleto, asi que el
# reposo sale de los huesos en reposo por su bind. Se calcula una vez y todos comparten la malla y un
# material por aspecto.

const RUTA := "res://models/personajes/pack_psx/monstruo_02/monstruo_02.fbx"
const ESCALA := 0.47           # la cabeza a ~1.62 m (medida por huesos)
const OX := -0.238255          # el esqueleto viene corrido en x
const SHADER := preload("res://shaders/zombi_serenol.gdshader")
const MUJERES := 0.5           # parte de los zombis que salen mujeres
# Sin camisa sale 3 veces mas que cada camisa (3/7 y 1/7 cada una), para que se vea la piedra (JJ)
const SIN_CAMISA_PESO := 3.0
# Las camisas (parametros del shader); cada una la traen hombres y mujeres
const CAMISAS := {
	"sin_camisa": {},
	"chivas": {"camisa": true, "diseno": 0, "color_base": Color(0.86, 0.84, 0.78), "color_raya": Color(0.82, 0.1, 0.13)},
	"america": {"camisa": true, "diseno": 1, "color_base": Color(0.98, 0.8, 0.1), "color_detalle": Color(0.06, 0.12, 0.38)},
	"seleccion": {"camisa": true, "diseno": 2, "color_base": Color(0.0, 0.42, 0.22), "color_raya": Color(0.0, 0.33, 0.17), "color_detalle": Color(0.9, 0.9, 0.86)},
	"conalep": {"camisa": true, "diseno": 3, "color_base": Color(0.88, 0.88, 0.84), "color_detalle": Color(0.0, 0.45, 0.25)},
}
# nombre, parametros del shader, mujer: las 5 camisas de hombre y las mismas 5 de mujer (con pelo)
static var ASPECTOS := _armar_aspectos()

static var _malla: ArrayMesh
static var _materiales := {}   # aspecto -> ShaderMaterial


static func _armar_aspectos() -> Array:
	var lista := []
	for mujer in [false, true]:
		for camisa: String in CAMISAS:
			lista.append([("mujer_" if mujer else "hombre_") + camisa, CAMISAS[camisa], mujer])
	return lista


# Uno al azar: MUJERES de las veces mujer; dentro, sin camisa pesa SIN_CAMISA_PESO y cada camisa 1
static func al_azar() -> int:
	var mujer := randf() < MUJERES
	var total := 0.0
	for a: Array in ASPECTOS:
		if a[2] == mujer:
			total += _peso(a)
	var tiro := randf() * total
	for i in ASPECTOS.size():
		if ASPECTOS[i][2] == mujer:
			tiro -= _peso(ASPECTOS[i])
			if tiro < 0.0:
				return i
	return 0


static func _peso(aspecto: Array) -> float:
	return SIN_CAMISA_PESO if (aspecto[1] as Dictionary).is_empty() else 1.0


static func nombre(aspecto: int) -> String:
	return ASPECTOS[aspecto][0] if aspecto >= 0 and aspecto < ASPECTOS.size() else "normal"


static func es_mujer(aspecto: int) -> bool:
	return aspecto >= 0 and aspecto < ASPECTOS.size() and ASPECTOS[aspecto][2]


# Le pone al modelo recien instanciado la malla con su reposo, el material de su aspecto y, si es
# mujer, el pelo. Devuelve la malla del cuerpo
static func vestir(modelo: Node3D, aspecto: int) -> MeshInstance3D:
	var piel := modelo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var sk := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if _malla == null:
		_malla = _malla_con_reposo(piel, sk)
	if not _materiales.has(aspecto):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("textura", (piel.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture)
		var params: Dictionary = ASPECTOS[aspecto][1]
		for k in params:
			mat.set_shader_parameter(k, params[k])
		_materiales[aspecto] = mat
	piel.mesh = _malla
	piel.material_override = _materiales[aspecto]
	if es_mujer(aspecto):
		var pelo := PeloZombi.new()
		modelo.add_child(pelo)
		pelo.armar(sk)
	return piel


# Reposo de cada vertice en el espacio del esqueleto: sus huesos en reposo por su bind
static func reposo(piel: MeshInstance3D, sk: Skeleton3D) -> PackedVector3Array:
	var arr := piel.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por := huesos.size() / pos.size()
	var skin := piel.skin
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var hueso_nombre := skin.get_bind_name(b)
		var hueso := sk.find_bone(hueso_nombre) if hueso_nombre != &"" else skin.get_bind_bone(b)
		mats.append(sk.get_bone_global_rest(hueso) * skin.get_bind_pose(b))
	var out := PackedVector3Array()
	out.resize(pos.size())
	for i in pos.size():
		var r := Vector3.ZERO
		for j in por:
			var w := pesos[i * por + j]
			if w > 0.0:
				r += (mats[huesos[i * por + j]] * pos[i]) * w
		out[i] = r
	return out


static func _malla_con_reposo(piel: MeshInstance3D, sk: Skeleton3D) -> ArrayMesh:
	var malla := piel.mesh
	var arr := malla.surface_get_arrays(0)
	var rep := reposo(piel, sk)
	var custom := PackedFloat32Array()
	custom.resize(rep.size() * 4)
	for i in rep.size():
		custom[i * 4] = (rep[i].x - OX) * ESCALA
		custom[i * 4 + 1] = rep[i].y * ESCALA
		custom[i * 4 + 2] = rep[i].z * ESCALA
		custom[i * 4 + 3] = 1.0
	arr[Mesh.ARRAY_CUSTOM0] = custom
	var formato: int = (malla.surface_get_format(0) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(malla.surface_get_primitive_type(0), arr, [], {}, formato)
	nueva.surface_set_material(0, malla.surface_get_material(0))
	return nueva
