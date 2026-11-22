class_name Transicion
extends RefCounted

# Los de en medio de las cañerías (JJ, 2026-11-21; lore §8 "Los de en medio"): ni persona ni zombi,
# no atacan, deambulan. humano() pone un civil del pack PSX con shaders/transicion_humano.gdshader (su
# piel de siempre, ropa desgarrada, grietas que brillan a manchones), ojos que brillan pegados al hueso
# Head y pose de zombi de Quaternius (Zombie_Idle) o la fetal hecha aqui. Los pone DeEnMedio.gd.
# Se ven en godot --path . tools/probar_transicion.tscn

const HUMANO := preload("res://shaders/transicion_humano.gdshader")

# Los cinco de JJ (2026-11-21): modelo, que tan rota la ropa, cuanta piel agrietada. Uno es policia
const MODELOS := [
	["hombre_03", 0.5, 0.65],
	["mujer_05", 0.6, 0.6],
	["policia_17", 0.45, 0.7],
	["mujer_30", 0.5, 0.55],
	["hombre_12", 0.65, 0.75],
]

static var _piel_de := {}      # textura -> su color de piel medido
static var _con_cabeza := {}   # malla original -> copia con COLOR.r = cuanto es de la cabeza


const OJO := preload("res://shaders/ojo_serenol.gdshader")
const OJO_TAMANO := 0.022      # m de lado del cuadrito de cada ojo
const OJO_SEPARA := 0.031      # m del centro de la cara a cada ojo
# Donde estan los ojos pintados en la textura de cada modelo (pixeles, medidos a mano): el ojo azul
# se pone en el punto de la malla que cae ahi. Sin el modelo aqui, se mide de la cabeza (menos fino)
const OJOS_PX := {
	"hombre_03": [Vector2(310, 106), Vector2(396, 316)],
	"mujer_05": [Vector2(58, 77), Vector2(63, 107)],
	"policia_17": [Vector2(451, 161), Vector2(43, 226)],
	"mujer_30": [Vector2(164, 43), Vector2(144, 56)],
	"hombre_12": [Vector2(450, 162), Vector2(41, 227)],
}
static var _ojos_de := {}      # malla original -> [ojo izquierdo, derecho, luz] en el espacio del civil

static var _mat_ojo: ShaderMaterial
static var _malla_ojo: QuadMesh


static func humano(nombre: String, semilla := 0.0, desgarre := 0.5, grietas := 0.65, clip := "Zombie_Idle") -> Node3D:
	var n := Node3D.new()
	n.name = "Transicion_" + nombre
	var ap := Civiles.poner(n, nombre, "Idle" if clip == "Fetal" else clip)
	if clip == "Fetal":
		if not ap.has_animation_library(LIB_PROPIA):
			ap.add_animation_library(LIB_PROPIA, biblioteca_propia())
		ap.play(LIB_PROPIA + "/Fetal")
		ap.seek(randf() * 4.0, true)
	poner_ojos(n, nombre)
	for malla: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if malla.mesh == null:
			continue
		_marcar_cabeza(malla)
		for s in malla.mesh.get_surface_count():
			var original := malla.mesh.surface_get_material(s) as BaseMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			var m := ShaderMaterial.new()
			m.shader = HUMANO
			m.set_shader_parameter("albedo_texture", original.albedo_texture)
			m.set_shader_parameter("tint", original.albedo_color)
			m.set_shader_parameter("color_piel", piel_de(original.albedo_texture))
			m.set_shader_parameter("semilla", semilla)
			m.set_shader_parameter("desgarre", desgarre)
			m.set_shader_parameter("grietas", grietas)
			m.set_shader_parameter("jitter_enabled", false)
			m.set_shader_parameter("wobble_enabled", false)
			m.set_shader_parameter("affine_enabled", false)
			malla.set_surface_override_material(s, m)
	return n


# --- Sentado en posicion fetal (JJ, 2026-11-21): Quaternius no la trae; se arma de Sitting_Idle
# bajando la cadera al suelo y girando de mas cada hueso (grados en sus ejes locales, del perfil
# humanoide). Se guarda en su propia biblioteca "t" para no tocar la de los civiles ---
const LIB_PROPIA := "t"
const FETAL_BAJA := 0.42                      # cuanto baja la cadera (unidades del esqueleto)
const FETAL := {
	"LeftUpperLeg": Vector3(38, 0, 0), "RightUpperLeg": Vector3(38, 0, 0),
	"LeftLowerLeg": Vector3(60, 0, 0), "RightLowerLeg": Vector3(60, 0, 0),
	"Chest": Vector3(18, 0, 0), "UpperChest": Vector3(18, 0, 0), "Neck": Vector3(10, 0, 0), "Head": Vector3(25, 0, 0),
	"LeftUpperArm": Vector3(50, 0, 0), "RightUpperArm": Vector3(50, 0, 0),
	"LeftLowerArm": Vector3(60, 0, 0), "RightLowerArm": Vector3(60, 0, 0),
}
static var _lib_propia: AnimationLibrary


static func biblioteca_propia() -> AnimationLibrary:
	if _lib_propia == null:
		_lib_propia = AnimationLibrary.new()
		_lib_propia.add_animation("Fetal", _armar_fetal())
	return _lib_propia


static func _armar_fetal() -> Animation:
	var base: Animation = Civiles.BIBLIOTECA.get_animation("Sitting_Idle")
	var a := Animation.new()
	a.length = 4.0
	a.loop_mode = Animation.LOOP_LINEAR
	for t in base.get_track_count():
		var ruta := base.track_get_path(t)
		var hueso := ruta.get_concatenated_subnames()
		var tipo := base.track_get_type(t)
		var nueva := a.add_track(tipo)
		a.track_set_path(nueva, ruta)
		var valor = base.track_get_key_value(t, 0)
		if tipo == Animation.TYPE_POSITION_3D and hueso == "Hips":
			valor = (valor as Vector3) + Vector3(0, -FETAL_BAJA, 0)
			a.track_insert_key(nueva, 0.0, valor)
		elif tipo == Animation.TYPE_ROTATION_3D:
			var q := valor as Quaternion
			if FETAL.has(hueso):
				var g: Vector3 = FETAL[hueso]
				q = q * Quaternion.from_euler(Vector3(deg_to_rad(g.x), deg_to_rad(g.y), deg_to_rad(g.z)))
			a.track_insert_key(nueva, 0.0, q)
			# Se mece apenas, como quien tiembla: el pecho y la cabeza
			if hueso in ["UpperChest", "Head"]:
				a.track_insert_key(nueva, 2.0, q * Quaternion.from_euler(Vector3(deg_to_rad(4.0), 0, 0)))
				a.track_insert_key(nueva, 4.0, q)
		else:
			a.track_insert_key(nueva, 0.0, valor)
	return a


# La copia de la malla con COLOR.r = el peso de los huesos Head y Neck en cada vertice: el shader no
# rasga ahi (el pelo no es ropa) aunque la pose agache la cabeza. Una copia por malla, guardada
static func _marcar_cabeza(malla: MeshInstance3D) -> void:
	var original := malla.mesh as ArrayMesh
	if original == null or malla.skin == null:
		return
	if not _con_cabeza.has(original):
		var sk := malla.get_node_or_null(malla.skeleton) as Skeleton3D
		var cabeza := {}
		for b in malla.skin.get_bind_count():
			var nombre := malla.skin.get_bind_name(b)
			if nombre == "" and sk:
				nombre = sk.get_bone_name(malla.skin.get_bind_bone(b))
			if nombre in ["Head", "Neck"]:
				cabeza[b] = true
		var copia := ArrayMesh.new()
		for s in original.get_surface_count():
			var arr := original.surface_get_arrays(s)
			var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var por := huesos.size() / maxi(nv, 1)
			var colores := PackedColorArray()
			colores.resize(nv)
			for v in nv:
				var w := 0.0
				for k in por:
					if cabeza.has(huesos[v * por + k]):
						w += pesos[v * por + k]
				colores[v] = Color(clampf(w, 0.0, 1.0), 0, 0)
			arr[Mesh.ARRAY_COLOR] = colores
			var formato := original.surface_get_format(s) & ~Mesh.ARRAY_FORMAT_COLOR
			if por == 8:
				formato |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			copia.add_surface_from_arrays(original.surface_get_primitive_type(s), arr, [], {}, formato | Mesh.ARRAY_FORMAT_COLOR)
			copia.surface_set_material(s, original.surface_get_material(s))
		_con_cabeza[original] = copia
	malla.mesh = _con_cabeza[original]


# Dos ojos que brillan todos (shaders/ojo_serenol.gdshader: azul de la Madre por fuera, blanco en
# medio, respiran), en un BoneAttachment3D del hueso Head: siguen la cabeza en cualquier
# clip y sirven para cualquier civil sin buscar su cara en la textura. Donde van se mide en la malla:
# la mitad de la altura de la cabeza (lo que pesa en Head), al frente de la cara, a OJO_SEPARA del
# centro. Con el modelo en OJOS_PX van exactos, donde estan pintados en la textura
static func poner_ojos(n: Node3D, nombre := "") -> void:
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hueso := sk.find_bone("Head")
	var malla := n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	if hueso < 0 or malla.skin == null:
		return
	if _mat_ojo == null:
		_mat_ojo = ShaderMaterial.new()
		_mat_ojo.shader = OJO
		_malla_ojo = QuadMesh.new()
		_malla_ojo.size = Vector2.ONE * OJO_TAMANO
		_malla_ojo.material = _mat_ojo
	# El hueso en reposo puesto en el civil (que ve a su -Z)
	var reposo := _a_civil(n, sk) * sk.get_bone_global_rest(hueso)
	if not _ojos_de.has(malla.mesh):
		var en_tex: Array = _ojos_en_textura(malla, sk, reposo, OJOS_PX[nombre]) if OJOS_PX.has(nombre) else []
		_ojos_de[malla.mesh] = en_tex if not en_tex.is_empty() else _medir_ojos(malla, sk, reposo)
	var ojos: Array = _ojos_de[malla.mesh]
	if ojos.is_empty():
		return
	var pegado := BoneAttachment3D.new()
	pegado.bone_name = "Head"
	sk.add_child(pegado)
	for i in 2:
		var ojo := MeshInstance3D.new()
		ojo.mesh = _malla_ojo
		ojo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pegado.add_child(ojo)
		# Viendo al frente del civil (-Z); del civil al hueso, que tambien deshace la escala
		ojo.transform = reposo.affine_inverse() * Transform3D(Basis(Vector3.UP, PI), ojos[i])
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.18, 0.77, 1.0)
	luz.light_energy = 0.06
	luz.omni_range = 0.4
	luz.shadow_enabled = false
	pegado.add_child(luz)
	luz.transform = reposo.affine_inverse() * Transform3D(Basis(), ojos[2])


# Del espacio de `nodo` al del civil `n`, a mano por la cadena de padres (todavia no esta en el arbol)
static func _a_civil(n: Node, nodo: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while nodo != n and nodo != null:
		t = (nodo as Node3D).transform * t
		nodo = nodo.get_parent()
	return t


# Los ojos en el punto de la malla cuya UV cae en esos pixeles de la textura: el triangulo que la
# contiene, interpolado. En el espacio del civil con el hueso Head en reposo, un pelo al frente
static func _ojos_en_textura(malla: MeshInstance3D, sk: Skeleton3D, reposo: Transform3D, pixeles: Array) -> Array:
	var bind := _bind_de(malla, sk, "Head")
	var t := reposo * bind
	var mesh := malla.mesh
	var original := mesh.surface_get_material(0) as BaseMaterial3D
	if original == null or original.albedo_texture == null:
		return []
	var lado := Vector2(original.albedo_texture.get_size())
	var ojos := []
	for px: Vector2 in pixeles:
		var uv := (px + Vector2(0.5, 0.5)) / lado
		var punto = null
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var n_tri := idx.size() / 3 if not idx.is_empty() else vs.size() / 3
			for k in n_tri:
				var i0 := idx[k * 3] if not idx.is_empty() else k * 3
				var i1 := idx[k * 3 + 1] if not idx.is_empty() else k * 3 + 1
				var i2 := idx[k * 3 + 2] if not idx.is_empty() else k * 3 + 2
				var b := _baricentro(uv, uvs[i0], uvs[i1], uvs[i2])
				if b.x >= -0.001 and b.y >= -0.001 and b.z >= -0.001:
					punto = t * (vs[i0] * b.x + vs[i1] * b.y + vs[i2] * b.z)
					break
			if punto != null:
				break
		if punto == null:
			return []
		ojos.append((punto as Vector3) + Vector3(0, 0, -0.004))
	ojos.append((ojos[0] + ojos[1]) * 0.5 + Vector3(0, 0, -0.15))
	return ojos


static func _baricentro(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-12:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)


static func _bind_de(malla: MeshInstance3D, sk: Skeleton3D, hueso: String) -> Transform3D:
	for b in malla.skin.get_bind_count():
		var nombre := malla.skin.get_bind_name(b)
		if nombre == "":
			nombre = sk.get_bone_name(malla.skin.get_bind_bone(b))
		if nombre == hueso:
			return malla.skin.get_bind_pose(b)
	return Transform3D.IDENTITY


static func _medir_ojos(malla: MeshInstance3D, sk: Skeleton3D, reposo: Transform3D) -> Array:
	var binds := {}
	var bind_cabeza := Transform3D.IDENTITY
	for b in malla.skin.get_bind_count():
		var nombre := malla.skin.get_bind_name(b)
		if nombre == "":
			nombre = sk.get_bone_name(malla.skin.get_bind_bone(b))
		if nombre == "Head":
			binds[b] = true
			bind_cabeza = malla.skin.get_bind_pose(b)
	# Cada vertice en el espacio del hueso es bind * v (la malla cruda va girada: ve hacia X); con el
	# hueso en reposo queda en el civil, viendo a -Z
	var t := reposo * bind_cabeza
	var puntos := PackedVector3Array()
	var mesh := malla.mesh
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var por := huesos.size() / maxi(vs.size(), 1)
		for v in vs.size():
			var w := 0.0
			for k in por:
				if binds.has(huesos[v * por + k]):
					w += pesos[v * por + k]
			if w > 0.6:
				puntos.append(t * vs[v])
	if puntos.size() < 20:
		return []
	var abajo := INF
	var arriba := -INF
	var cx := 0.0
	for p in puntos:
		abajo = minf(abajo, p.y)
		arriba = maxf(arriba, p.y)
		cx += p.x
	cx /= puntos.size()
	var alto := abajo + (arriba - abajo) * 0.5
	# El frente: lo mas adelantado a la altura de los ojos, a los lados de la nariz
	var frente := INF
	for p in puntos:
		if absf(p.y - alto) < 0.03 and absf(absf(p.x - cx) - OJO_SEPARA) < 0.02:
			frente = minf(frente, p.z)
	if frente == INF:
		for p in puntos:
			if absf(p.y - alto) < 0.03:
				frente = minf(frente, p.z + 0.01)
	if frente == INF:
		return []
	return [Vector3(cx - OJO_SEPARA, alto, frente - 0.003), Vector3(cx + OJO_SEPARA, alto, frente - 0.003),
		Vector3(cx, alto, frente - 0.15)]


# El color promedio de lo que parece piel en la textura (los mismos rangos YCbCr del shader)
static func piel_de(textura: Texture2D) -> Color:
	if _piel_de.has(textura):
		return _piel_de[textura]
	var img := textura.get_image()
	var suma := Vector3.ZERO
	var n := 0
	if img:
		if img.is_compressed():
			img.decompress()
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				var yy := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				var cb := 0.5 - 0.168736 * c.r - 0.331264 * c.g + 0.5 * c.b
				var cr := 0.5 + 0.5 * c.r - 0.418688 * c.g - 0.081312 * c.b
				if cb > 0.302 and cb < 0.498 and cr > 0.537 and cr < 0.686 and yy > 0.2 and c.r > c.g and c.g >= c.b * 0.9:
					suma += Vector3(c.r, c.g, c.b)
					n += 1
	var color := Color(suma.x / n, suma.y / n, suma.z / n) if n > 20 else Color(0.72, 0.52, 0.40)
	_piel_de[textura] = color
	return color
