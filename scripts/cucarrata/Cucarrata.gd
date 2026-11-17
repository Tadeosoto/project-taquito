class_name Cucarrata
extends Node3D
# La cucarrata: cuerpo de cucaracha gigante con cabeza de rata y ojos azules de Serenol.
# Se arma al entrar al arbol con dos modelos de Sketchfab (CC-BY, creditos en CREDITS.md):
# - cucaracha.glb trae el esqueleto y las 6 animaciones; se le quitan los triangulos de su cabeza
#   (los pesados al hueso head_04), y quedan las antenas (horns_*).
# - rata.glb no tiene esqueleto: se corta solo la cabeza (de las orejas a la nariz, sin las patas)
#   y se cuelga de head_04 con un BoneAttachment3D, asi sigue al ataque y al caminar.
# Todo es en codigo (como Catrina y la Madre) para poder mover los numeros sin Blender.

const CUCARACHA := preload("res://models/personajes/cucarrata/cucaracha.glb")
const RATA := preload("res://models/personajes/cucarrata/rata.glb")
const HUESO_CABEZA := "head_04"
const ANTENA_BASE := { "R": "horns_01.R_05", "L": "horns_01.L_07" }

# El corte de la rata, en las coordenadas del glb ya importado (nariz hacia +Z, cola hacia -Z)
const RATA_CORTE_Z := -0.42     # de aqui hacia la nariz
const RATA_CORTE_Y := -0.30     # y de aqui hacia arriba (fuera las patas de enfrente)
const RATA_CUELLO := Vector3(0.01, 0.12, -0.42)   # el punto que queda pegado al cuello
# Donde va el cuello de la rata en el cuerpo de la cucaracha (en reposo, coordenadas del glb)
const CUELLO_CUCARACHA := Vector3(0.0, 0.28, -0.45)
const RATA_ESCALA := 0.5
# Hasta donde se busca el borde del corte para taparlo (metros de la rata desde el cuello)
const CUELLO_TAPA := 0.25
# Ojos: posicion en la rata (antes de escalar; los ojos negros del modelo), espejo en X
const OJO := Vector3(0.19, 0.265, 0.08)
const OJO_RADIO := 0.042
const OJO_COLOR := Color(0.18, 0.77, 1.0)   # el azul de las grietas de la Madre (#2EC4FF)
# La piel es la de la Madre del Carcamo (shaders/cucarrata.gdshader): sus grietas brillan mas
# de COLA_DESDE a COLA_HASTA (z del modelo; la cabeza esta en -Z y el abdomen en +Z)
const SHADER_PIEL := preload("res://shaders/cucarrata.gdshader")
const COLA_DESDE := -0.6
const COLA_HASTA := 1.0

# Nombres cortos de las animaciones (en el glb van con "giant_cockroach_armature|")
const ANIMS := {
	"quieta": "idle", "camina": "walking", "ataca": "Attack", "muere": "death_start",
	"vuela": "flying_straight", "agarra": "flying_kidnapping",
}
const EN_CICLO := ["quieta", "camina", "vuela", "agarra"]

@export var tamano := 1.0
@export var animacion_inicial := "camina"
@export var ojos_con_luz := true

static var _mat_cuerpo: ShaderMaterial
static var _mat_rata: ShaderMaterial
static var _mat_ojo: StandardMaterial3D
static var _malla_cuerpo: ArrayMesh   # la cucaracha sin cabeza, compartida
static var _malla_rata: ArrayMesh     # la cabeza de rata, ya volteada y escalada

var esqueleto: Skeleton3D
var anim: AnimationPlayer
var _modelo: Node3D


func _ready() -> void:
	scale = Vector3.ONE * tamano
	_modelo = CUCARACHA.instantiate()
	add_child(_modelo)
	esqueleto = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	anim = _modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var cuerpo: MeshInstance3D = _modelo.find_children("*", "MeshInstance3D", true, false)[0]
	if _malla_cuerpo == null:
		_malla_cuerpo = _sin_cabeza(cuerpo.mesh, cuerpo.skin)
	cuerpo.mesh = _malla_cuerpo
	cuerpo.material_override = _material_cuerpo(cuerpo)
	_poner_cabeza()
	for corto in EN_CICLO:
		var a := anim.get_animation(_nombre(corto))
		if a: a.loop_mode = Animation.LOOP_LINEAR
	animar(animacion_inicial)


func animar(corto: String, mezcla := 0.15) -> void:
	var n := _nombre(corto)
	if anim.has_animation(n):
		anim.play(n, mezcla)


func _nombre(corto: String) -> String:
	return "giant_cockroach_armature|" + ANIMS.get(corto, corto)


# Quita los triangulos que tengan algun vertice pesado sobre todo al hueso de la cabeza
func _sin_cabeza(malla: Mesh, skin: Skin) -> ArrayMesh:
	var arr := malla.surface_get_arrays(0)
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var n_v: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var por_vertice := huesos.size() / n_v
	var cabeza := esqueleto.find_bone(HUESO_CABEZA)
	var es_cabeza := PackedByteArray()
	es_cabeza.resize(n_v)
	var huesos_de := PackedInt32Array()   # el hueso que mas pesa en cada vertice
	for i in n_v:
		var mejor := -1
		var mejor_peso := 0.0
		for k in por_vertice:
			if pesos[i * por_vertice + k] > mejor_peso:
				mejor_peso = pesos[i * por_vertice + k]
				mejor = huesos[i * por_vertice + k]
		var nombre := skin.get_bind_name(mejor) if mejor >= 0 else &""
		var hueso := esqueleto.find_bone(nombre) if nombre != &"" else skin.get_bind_bone(mejor)
		es_cabeza[i] = 1 if hueso == cabeza else 0
		huesos_de.append(hueso)
	_marcar_antenas(arr, skin, huesos_de)
	var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var quedan := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if es_cabeza[indices[t]] or es_cabeza[indices[t + 1]] or es_cabeza[indices[t + 2]]:
			continue
		quedan.append_array([indices[t], indices[t + 1], indices[t + 2]])
	arr[Mesh.ARRAY_INDEX] = quedan
	var nueva := ArrayMesh.new()
	var formato: int = (malla.surface_get_format(0) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) \
			| Mesh.ARRAY_FORMAT_COLOR
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, formato)
	nueva.surface_set_material(0, malla.surface_get_material(0))
	return nueva


# Las antenas (huesos horns_*) se marcan en el color de vertice para el shader: g = 1 en la
# antena, r = que tan lejos de la base esta (0 base, 1 punta), medido en la pose de reposo
func _marcar_antenas(arr: Array, skin: Skin, huesos_de: PackedInt32Array) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por_vertice := huesos.size() / v.size()
	var colores := PackedColorArray()
	colores.resize(v.size())
	var lejos := {}    # vertice -> distancia a la base de su antena
	var maximo := {}   # lado -> la distancia mas larga
	for i in v.size():
		colores[i] = Color(0, 0, 0, 1)
		var nombre := esqueleto.get_bone_name(huesos_de[i]) if huesos_de[i] >= 0 else ""
		if not nombre.begins_with("horns_"):
			continue
		var lado := "R" if ".R" in nombre else "L"
		var base := esqueleto.get_bone_global_rest(esqueleto.find_bone(ANTENA_BASE[lado])).origin
		var p := Vector3.ZERO
		for k in por_vertice:
			var w := pesos[i * por_vertice + k]
			if w <= 0.0:
				continue
			var b := huesos[i * por_vertice + k]
			var hueso := esqueleto.find_bone(skin.get_bind_name(b))
			if hueso < 0:
				hueso = skin.get_bind_bone(b)
			p += w * (esqueleto.get_bone_global_rest(hueso) * skin.get_bind_pose(b) * v[i])
		lejos[i] = [p.distance_to(base), lado]
		maximo[lado] = max(maximo.get(lado, 0.0), p.distance_to(base))
	for i in lejos:
		colores[i] = Color(lejos[i][0] / maxf(maximo[lejos[i][1]], 0.001), 1, 0, 1)
	arr[Mesh.ARRAY_COLOR] = colores


func _poner_cabeza() -> void:
	if _malla_rata == null:
		_malla_rata = _cortar_rata()
	var pegado := BoneAttachment3D.new()
	pegado.bone_name = HUESO_CABEZA
	esqueleto.add_child(pegado)
	# Donde queda la cabeza en reposo (coordenadas del modelo) -> relativo al hueso
	var hueso := esqueleto.find_bone(HUESO_CABEZA)
	var esqueleto_modelo := _modelo.global_transform.affine_inverse() * esqueleto.global_transform
	var hueso_modelo := esqueleto_modelo * esqueleto.get_bone_global_rest(hueso)
	var cabeza := MeshInstance3D.new()
	cabeza.name = "CabezaRata"
	cabeza.mesh = _malla_rata
	cabeza.material_override = _material_rata()
	cabeza.transform = hueso_modelo.affine_inverse() * Transform3D(Basis(), CUELLO_CUCARACHA)
	pegado.add_child(cabeza)
	for lado in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = OJO_RADIO * RATA_ESCALA
		esfera.height = esfera.radius * 2.0
		esfera.radial_segments = 6
		esfera.rings = 3
		ojo.mesh = esfera
		ojo.material_override = _material_ojo()
		ojo.position = _a_cucaracha(Vector3(OJO.x * lado, OJO.y, OJO.z))
		cabeza.add_child(ojo)
		if ojos_con_luz:
			var luz := OmniLight3D.new()
			luz.light_color = OJO_COLOR
			luz.light_energy = 0.6
			luz.omni_range = 1.2
			luz.position = ojo.position + Vector3(0, 0, -0.15)
			cabeza.add_child(luz)


# De la rata (nariz +Z, cuello en RATA_CUELLO) a la cabeza pegada: volteada (nariz -Z), escalada
# y con el cuello en el origen
func _a_cucaracha(p: Vector3) -> Vector3:
	var q := (p - RATA_CUELLO) * RATA_ESCALA
	return Vector3(-q.x, q.y, -q.z)


func _cortar_rata() -> ArrayMesh:
	var rata: Node3D = RATA.instantiate()
	var mi: MeshInstance3D = rata.find_children("*", "MeshInstance3D", true, false)[0]
	# Transform del nodo de la malla hasta la raiz del glb (no esta en el arbol)
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
	# Aristas de los triangulos que quedan, por posicion (el glb repite vertices por UV): las que
	# usa un solo triangulo son el borde del corte, el agujero del cuello
	var aristas := {}   # [clave a, clave b] ordenadas -> veces
	var pos_de := {}    # clave -> [posicion pegada, uv]
	for k in range(0, indices.size(), 3):
		var dentro := true
		for j in 3:
			var g := t * v[indices[k + j]]
			if g.z < RATA_CORTE_Z or g.y < RATA_CORTE_Y:
				dentro = false
				break
		if not dentro:
			continue
		var claves := []
		for j in 3:
			var i := indices[k + j]
			var p := _a_cucaracha(t * v[i])
			st.set_normal(_a_cucaracha_dir(t.basis * normales[i]))
			st.set_uv(uv[i])
			st.add_vertex(p)
			var clave := Vector3i((p * 1000.0).round())
			pos_de[clave] = [p, uv[i]]
			claves.append(clave)
		for j in 3:
			var par := [claves[j], claves[(j + 1) % 3]]
			par.sort()
			aristas[par] = aristas.get(par, 0) + 1
	_tapar_cuello(st, aristas, pos_de)
	var malla := st.commit()
	malla.surface_set_material(0, mi.mesh.surface_get_material(0))
	rata.free()
	return malla


# Tapa el agujero del cuello con un abanico de triangulos hacia el centro del borde, para que
# no se vea hueca la cabeza por detras cuando el cuerpo se mueve
func _tapar_cuello(st: SurfaceTool, aristas: Dictionary, pos_de: Dictionary) -> void:
	var limite := -CUELLO_TAPA * RATA_ESCALA   # solo el borde de atras (el cuello esta en z = 0)
	var borde := []
	var centro := Vector3.ZERO
	var cuantos := 0
	for par in aristas:
		if aristas[par] != 1:
			continue
		var a: Array = pos_de[par[0]]
		var b: Array = pos_de[par[1]]
		if a[0].z < limite or b[0].z < limite:
			continue
		borde.append([a, b])
		centro += a[0] + b[0]
		cuantos += 2
	if cuantos == 0:
		return
	centro /= cuantos
	var uv_centro: Vector2 = borde[0][0][1]
	for e in borde:
		st.set_normal(Vector3.BACK)
		st.set_uv(uv_centro)
		st.add_vertex(centro)
		st.set_normal(Vector3.BACK)
		st.set_uv(e[0][1])
		st.add_vertex(e[0][0])
		st.set_normal(Vector3.BACK)
		st.set_uv(e[1][1])
		st.add_vertex(e[1][0])


func _a_cucaracha_dir(d: Vector3) -> Vector3:
	return Vector3(-d.x, d.y, -d.z).normalized()


# El cuerpo: grietas mas hacia la cola. La malla con esqueleto queda en el espacio del
# MeshInstance (el glb la gira y la escala), asi que el eje "hacia la cola" (+Z del modelo) se
# pasa a ese espacio para el shader
func _material_cuerpo(cuerpo: MeshInstance3D) -> ShaderMaterial:
	if _mat_cuerpo == null:
		_mat_cuerpo = _material_piel(cuerpo.mesh.surface_get_material(0), 0.6, 1.0)
		var t := _modelo.global_transform.affine_inverse() * cuerpo.global_transform
		var fila_z := Vector3(t.basis.x.z, t.basis.y.z, t.basis.z.z)
		_mat_cuerpo.set_shader_parameter("eje_cola", fila_z)
		_mat_cuerpo.set_shader_parameter("antenas", true)
		_mat_cuerpo.set_shader_parameter("cola_desde", COLA_DESDE - t.origin.z)
		_mat_cuerpo.set_shader_parameter("cola_hasta", COLA_HASTA - t.origin.z)
	return _mat_cuerpo


# La cabeza: menos grietas y mas de la textura, para que se lea la cara de rata
func _material_rata() -> ShaderMaterial:
	if _mat_rata == null:
		_mat_rata = _material_piel(_malla_rata.surface_get_material(0), 0.8, 0.7)
		_mat_rata.set_shader_parameter("escala_celdas", Vector2(18.0, 18.0))
	return _mat_rata


# La piel de la Madre del Carcamo (shaders/cucarrata.gdshader) sobre la textura del glb
func _material_piel(original: Material, sombras: float, grietas: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_PIEL
	if original is BaseMaterial3D:
		m.set_shader_parameter("textura", (original as BaseMaterial3D).albedo_texture)
	m.set_shader_parameter("sombras_textura", sombras)
	m.set_shader_parameter("grietas", grietas)
	return m


func _material_ojo() -> StandardMaterial3D:
	if _mat_ojo == null:
		_mat_ojo = StandardMaterial3D.new()
		_mat_ojo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_ojo.albedo_color = OJO_COLOR * 1.6
	return _mat_ojo
