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
# El cuerpo cafe de cucaracha de casa con las vetas azules; la cabeza de rata queda gris piedra
# (el color_piel del shader)
const CUERPO_COLOR := Color(0.66, 0.44, 0.28)
# El cuerpo del glb es plano (2.2 veces mas ancho que alto): se estira de arriba a abajo (JJ: mas
# gordo, mas cilindrico). Solo los huesos del cuerpo; el eje que no se mueve va cerca de la panza,
# asi crece casi todo hacia el lomo y la panza no se mete al piso. Las alas suben con el lomo
const GORDURA := 2.1
const GORDURA_EJE := 0.3   # de la panza (0) al lomo (1) de cada pedazo
const HUESOS_CUERPO := ["body_02_01", "body_03_02", "body_04_03", "body_02.001_036"]
const HUESO_ALAS := "body_03_02"   # las alas se pegan al lomo de este pedazo

# Nombres cortos de las animaciones (en el glb van con "giant_cockroach_armature|")
const ANIMS := {
	"quieta": "idle", "camina": "walking", "ataca": "Attack", "muere": "death_start",
	"vuela": "flying_straight", "agarra": "flying_kidnapping",
}
const EN_CICLO := ["quieta", "camina", "vuela", "agarra"]
const ALTO_MODELO := 0.58   # m del glb en "quieta", del piso al lomo, sin antenas

# Parir (parir()): la animacion "pare" la arma el codigo sobre "idle" (el glb no la trae). El
# abdomen (hueso body_02.001_036; en su X local, negativo = arriba) se levanta y se hincha, y con
# cada contraccion sale una cria por la punta de la cola con un arco hacia atras
const HUESO_ABDOMEN := "body_02.001_036"
const PARE_DURA := 2.6
const PARE_SUBE := -0.55      # radianes que se levanta el abdomen
const PARE_EMPUJA := -0.8     # en cada contraccion
const PARE_HINCHA := 1.12     # escala del abdomen levantado
const PARE_PUJA := 1.28       # escala en cada contraccion
const PARE_PUJOS := [0.8, 1.2, 1.6, 2.0]   # segundos de cada contraccion (una cria cada una)
const PUNTA_COLA := Vector3(0.0, 0.32, 1.0)   # en el modelo en reposo
const CRIA_SALE := Vector2(3.5, 3.5)   # m/s hacia atras y hacia arriba al salir
# Sale un enjambre (JJ): cada pujo suelta POR_PUJO[tipo] crias de ese tipo, una tras otra cada
# ENJAMBRE_CADA s, abiertas hacia los lados y con velocidades distintas
const POR_PUJO := { CriaCucarrata.Tipo.RATA: 5, CriaCucarrata.Tipo.CUCARACHA: 4 }   # JJ: cucarachas mas chicas pero el doble
const ENJAMBRE_CADA := 0.06
const ENJAMBRE_ABRE := 2.2     # m/s de lado, al azar a cada lado
const ENJAMBRE_VARIA := Vector2(0.75, 1.3)   # la velocidad de salida se multiplica por esto

signal pario(cria: CriaCucarrata)

# Alto en metros sin las antenas (JJ: primero 3 m, gigante; en la pelea se veia demasiado grande:
# 2 m, ~7 de largo). El modelo mide ALTO_MODELO
@export var alto := 2.0
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
var _punta_en_abdomen := Vector3.ZERO


func _ready() -> void:
	scale = Vector3.ONE * escala()
	_modelo = CUCARACHA.instantiate()
	add_child(_modelo)
	esqueleto = _modelo.find_children("*", "Skeleton3D", true, false)[0]
	anim = _modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var cuerpo: MeshInstance3D = _modelo.find_children("*", "MeshInstance3D", true, false)[0]
	if _malla_cuerpo == null:
		_malla_cuerpo = preparar_cucaracha(cuerpo.mesh, cuerpo.skin, esqueleto, true)
	cuerpo.mesh = _malla_cuerpo
	cuerpo.material_override = _material_cuerpo(cuerpo)
	_poner_cabeza()
	for corto in EN_CICLO:
		var a := anim.get_animation(_nombre(corto))
		if a: a.loop_mode = Animation.LOOP_LINEAR
	_armar_pare()
	# La punta de la cola en el espacio del hueso del abdomen, para seguirla cuando se mueve
	var abdomen := esqueleto.find_bone(HUESO_ABDOMEN)
	var esqueleto_modelo := _modelo.global_transform.affine_inverse() * esqueleto.global_transform
	_punta_en_abdomen = (esqueleto_modelo * esqueleto.get_bone_global_rest(abdomen)).affine_inverse() \
			* PUNTA_COLA
	animar(animacion_inicial)


func escala() -> float:
	return alto / ALTO_MODELO


func animar(corto: String, mezcla := 0.15) -> void:
	var n := _nombre(corto)
	if anim.has_animation(n):
		anim.play(n, mezcla)


func _nombre(corto: String) -> String:
	if corto == "pare":
		return "pare"
	return "giant_cockroach_armature|" + ANIMS.get(corto, corto)


# Cada parto es de un solo tipo y se alternan (JJ: no te puedes defender de las dos a la vez):
# primero ratas, luego cucarachas. TANDA = cuantos pujos tiene el parto de cada tipo
const TANDA := { CriaCucarrata.Tipo.RATA: 3, CriaCucarrata.Tipo.CUCARACHA: 2 }   # 15 ratas u 8 cucarachas
var siguiente_tipo := CriaCucarrata.Tipo.RATA


# Suelta crias por la cola, POR_PUJO[tipo] por contraccion (tipos: CriaCucarrata.Tipo, uno
# por pujo, en orden). Sin tipos, pare una tanda de siguiente_tipo y alterna. Las crias van al
# padre de la cucarrata (no se mueven con ella). Al acabar vuelve a "quieta". Sin animacion (volando:
# "pare" le pararia las alas) solo las suelta al ritmo de los pujos
func parir(tipos: Array = [], con_animacion := true) -> void:
	if tipos.is_empty():
		for i in TANDA[siguiente_tipo]:
			tipos.append(siguiente_tipo)
		siguiente_tipo = CriaCucarrata.Tipo.CUCARACHA if siguiente_tipo == CriaCucarrata.Tipo.RATA \
				else CriaCucarrata.Tipo.RATA
	if con_animacion:
		animar("pare", 0.2)
	var inicio := Time.get_ticks_msec()
	for k in tipos.size():
		var n := k % PARE_PUJOS.size()
		if n == 0 and k > 0:
			if con_animacion:
				anim.play("pare", 0.1)   # mas crias que pujos: otra vuelta
			inicio = Time.get_ticks_msec()
		while (Time.get_ticks_msec() - inicio) / 1000.0 < PARE_PUJOS[n]:
			if not is_inside_tree():
				return
			await get_tree().process_frame
		for j in POR_PUJO[tipos[k]]:
			if j > 0:
				var desde := Time.get_ticks_msec()
				while (Time.get_ticks_msec() - desde) / 1000.0 < ENJAMBRE_CADA:
					if not is_inside_tree():
						return
					await get_tree().process_frame
			if not is_inside_tree():
				return
			_soltar(tipos[k])
	if con_animacion:
		# No await animation_finished: si "pare" acabo antes que la ultima cria (los pujos van con
		# el reloj real), la senal ya paso y se quedaba parada para siempre
		while anim.is_playing() and anim.current_animation == "pare":
			await get_tree().process_frame
			if not is_inside_tree():
				return
		animar("quieta", 0.3)


func punta_cola() -> Vector3:
	var abdomen := esqueleto.find_bone(HUESO_ABDOMEN)
	return esqueleto.global_transform * esqueleto.get_bone_global_pose(abdomen) * _punta_en_abdomen


func _soltar(tipo: int) -> void:
	var cria := CriaCucarrata.new()
	cria.tipo = tipo
	cria.animacion_inicial = "quieta"
	get_parent().add_child(cria)
	cria.global_position = punta_cola()
	var atras := global_transform.basis.z.normalized()
	var lado := global_transform.basis.x.normalized() * randf_range(-ENJAMBRE_ABRE, ENJAMBRE_ABRE)
	cria.rotation.y = rotation.y + randf_range(-0.8, 0.8)
	var sale := atras * CRIA_SALE.x * randf_range(ENJAMBRE_VARIA.x, ENJAMBRE_VARIA.y) \
			+ Vector3.UP * CRIA_SALE.y * randf_range(ENJAMBRE_VARIA.x, ENJAMBRE_VARIA.y)
	cria.lanzar(sale + lado, global_position.y)
	pario.emit(cria)


# "pare": "idle" con el abdomen levantado, hinchado y pujando. Se agrega a la libreria del glb
# (compartida por todas las cucarratas), una sola vez
func _armar_pare() -> void:
	if anim.has_animation("pare"):
		return
	var a: Animation = anim.get_animation(_nombre("quieta")).duplicate(true)
	a.loop_mode = Animation.LOOP_NONE
	a.length = PARE_DURA
	var ruta := ""
	for t in range(a.get_track_count() - 1, -1, -1):
		var p := str(a.track_get_path(t))
		if p.ends_with(":" + HUESO_ABDOMEN):
			ruta = p
			if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
				a.remove_track(t)
	var b := esqueleto.find_bone(HUESO_ABDOMEN)
	var reposo := esqueleto.get_bone_rest(b).basis.get_rotation_quaternion()
	var giro := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(giro, ruta)
	var escala := a.add_track(Animation.TYPE_SCALE_3D)
	a.track_set_path(escala, ruta)
	var claves := [[0.0, 0.0, 1.0], [0.5, PARE_SUBE, PARE_HINCHA]]
	for puja in PARE_PUJOS:
		claves.append([puja - 0.12, PARE_SUBE, PARE_HINCHA])
		claves.append([puja, PARE_EMPUJA, PARE_PUJA])
		claves.append([puja + 0.15, PARE_SUBE, PARE_HINCHA])
	claves.append([PARE_DURA, 0.0, 1.0])
	for c in claves:
		a.rotation_track_insert_key(giro, c[0], reposo * Quaternion(Vector3.RIGHT, c[1]))
		a.scale_track_insert_key(escala, c[0], Vector3.ONE * c[2])
	anim.get_animation_library("").add_animation("pare", a)


# Prepara la malla de la cucaracha para el shader: marca las antenas en el color de vertice y,
# con quitar_cabeza, quita los triangulos que tengan algun vertice pesado sobre todo al hueso de
# la cabeza. La usan la cucarrata (sin cabeza) y las cucarachas chicas (CriaCucarrata, con ella)
static func preparar_cucaracha(malla: Mesh, skin: Skin, esq: Skeleton3D, quitar_cabeza: bool) -> ArrayMesh:
	var arr := malla.surface_get_arrays(0)
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var n_v: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var por_vertice := huesos.size() / n_v
	var cabeza := esq.find_bone(HUESO_CABEZA)
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
		var hueso := esq.find_bone(nombre) if nombre != &"" else skin.get_bind_bone(mejor)
		es_cabeza[i] = 1 if hueso == cabeza and quitar_cabeza else 0
		huesos_de.append(hueso)
	_marcar_antenas(arr, skin, esq, huesos_de)
	_engordar(arr, skin, esq, huesos_de)
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


# Estira en Y (de la malla) los vertices del cuerpo alrededor de su eje, mezclado por cuanto pesan
# los huesos del cuerpo en cada vertice (las raices de las patas se mueven poco y no se despegan)
static func _engordar(arr: Array, skin: Skin, esq: Skeleton3D, huesos_de: PackedInt32Array) -> void:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por_vertice := huesos.size() / v.size()
	var rango := {}   # hueso -> [y de la panza, y del lomo]
	for i in v.size():
		var nombre := esq.get_bone_name(huesos_de[i]) if huesos_de[i] >= 0 else ""
		if nombre in HUESOS_CUERPO:
			var r: Array = rango.get(nombre, [v[i].y, v[i].y])
			rango[nombre] = [minf(r[0], v[i].y), maxf(r[1], v[i].y)]
	if not rango.has(HUESO_ALAS):
		return
	var eje := {}
	for nombre in rango:
		eje[nombre] = lerpf(rango[nombre][0], rango[nombre][1], GORDURA_EJE)
	var sube_alas: float = (rango[HUESO_ALAS][1] - eje[HUESO_ALAS]) * (GORDURA - 1.0)
	for i in v.size():
		var nombre := esq.get_bone_name(huesos_de[i]) if huesos_de[i] >= 0 else ""
		if nombre.begins_with("wing_"):
			v[i].y += sube_alas
			continue
		var w_cuerpo := 0.0
		var centro := 0.0
		for k in por_vertice:
			var w := pesos[i * por_vertice + k]
			var hueso := skin.get_bind_name(huesos[i * por_vertice + k])
			if w > 0.0 and eje.has(String(hueso)):
				w_cuerpo += w
				centro += w * eje[String(hueso)]
		if w_cuerpo <= 0.0:
			continue
		centro /= w_cuerpo
		var f := lerpf(1.0, GORDURA, w_cuerpo)
		v[i].y = centro + (v[i].y - centro) * f
		if normales.size() == v.size():
			var n := normales[i]
			normales[i] = Vector3(n.x, n.y / f, n.z).normalized()
	arr[Mesh.ARRAY_VERTEX] = v
	if normales.size() == v.size():
		arr[Mesh.ARRAY_NORMAL] = normales


# Las antenas (huesos horns_*) se marcan en el color de vertice para el shader: g = 1 en la
# antena, r = que tan lejos de la base esta (0 base, 1 punta), medido en la pose de reposo
static func _marcar_antenas(arr: Array, skin: Skin, esq: Skeleton3D, huesos_de: PackedInt32Array) -> void:
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
		var nombre := esq.get_bone_name(huesos_de[i]) if huesos_de[i] >= 0 else ""
		if not nombre.begins_with("horns_"):
			continue
		var lado := "R" if ".R" in nombre else "L"
		var base := esq.get_bone_global_rest(esq.find_bone(ANTENA_BASE[lado])).origin
		var p := Vector3.ZERO
		for k in por_vertice:
			var w := pesos[i * por_vertice + k]
			if w <= 0.0:
				continue
			var b := huesos[i * por_vertice + k]
			var hueso := esq.find_bone(skin.get_bind_name(b))
			if hueso < 0:
				hueso = skin.get_bind_bone(b)
			p += w * (esq.get_bone_global_rest(hueso) * skin.get_bind_pose(b) * v[i])
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
		ojo.material_override = material_ojo()
		ojo.position = _a_cucaracha(Vector3(OJO.x * lado, OJO.y, OJO.z))
		cabeza.add_child(ojo)
		if ojos_con_luz:
			var luz := OmniLight3D.new()
			luz.light_color = OJO_COLOR
			luz.light_energy = 0.6 + escala() * 0.15
			luz.omni_range = 1.2 * escala()   # el alcance de la luz no crece con la escala del nodo
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
		_mat_cuerpo = material_piel(cuerpo.mesh.surface_get_material(0), 0.6, 1.0)
		var t := _modelo.global_transform.affine_inverse() * cuerpo.global_transform
		var fila_z := Vector3(t.basis.x.z, t.basis.y.z, t.basis.z.z)
		_mat_cuerpo.set_shader_parameter("eje_cola", fila_z)
		_mat_cuerpo.set_shader_parameter("antenas", true)
		_mat_cuerpo.set_shader_parameter("color_piel", CUERPO_COLOR)
		_mat_cuerpo.set_shader_parameter("cola_desde", COLA_DESDE - t.origin.z)
		_mat_cuerpo.set_shader_parameter("cola_hasta", COLA_HASTA - t.origin.z)
	return _mat_cuerpo


# La cabeza: menos grietas y mas de la textura, para que se lea la cara de rata
func _material_rata() -> ShaderMaterial:
	if _mat_rata == null:
		_mat_rata = material_piel(_malla_rata.surface_get_material(0), 0.8, 0.7)
		_mat_rata.set_shader_parameter("escala_celdas", Vector2(18.0, 18.0))
	return _mat_rata


# La piel de la Madre del Carcamo (shaders/cucarrata.gdshader) sobre la textura del glb
static func material_piel(original: Material, sombras: float, grietas: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_PIEL
	if original is BaseMaterial3D:
		m.set_shader_parameter("textura", (original as BaseMaterial3D).albedo_texture)
	m.set_shader_parameter("sombras_textura", sombras)
	m.set_shader_parameter("grietas", grietas)
	return m


static func material_ojo() -> StandardMaterial3D:
	if _mat_ojo == null:
		_mat_ojo = StandardMaterial3D.new()
		_mat_ojo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_ojo.albedo_color = OJO_COLOR * 1.6
	return _mat_ojo
