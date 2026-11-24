class_name SimiSerenol
# El Simi gigante con Serenol (JJ 2026-11-22): la botarga que baila afuera de las farmacias, en su
# copia con retarget al perfil humanoide (`simi_jefe.scn`, ver tools/simi/separar_simi_jefe.gd), a
# `ALTO` metros, bailando "h/Simi_Baile" de la libreria humana (el mismo que bailan los zombis y el
# jugador cuando los agarra el baile), con la piel
# de piedra y grietas del Panzon y los zombis debajo de la bata rota (`shaders/simi_serenol.gdshader`).
#
# El shader dibuja en la pose de reposo, que va en CUSTOM0 de cada malla (como ZombiSerenol), en metros
# de un Simi de `ALTO_REPOSO` (1.75 m), centrado en x/z y con los pies en 0. Mallas y materiales se
# arman una vez y los comparten todos los Simis.
#
#   var simi := SimiSerenol.modelo()      # Node3D con los pies en 0, mirando a +Z, ya bailando
#   SimiSerenol.reproductor(simi)          # su AnimationPlayer, con la libreria "h"

const ESCENA := "res://models/personajes/simi_jefe/simi_jefe.scn"
const BAILE := &"h/Simi_Baile"
const SHADER := preload("res://shaders/simi_serenol.gdshader")
const ALTO := 7.0
const ALTO_REPOSO := 1.75
# Que parte del shader le toca a cada malla de la botarga
# Los pelos parados de la coronilla se quitan (JJ: que no sea igual al Simi de verdad): los triangulos
# oscuros de la textura arriba de PELO_DESDE (fraccion del alto de reposo, de los pies a la coronilla)
const PELO_DESDE := 0.915
const PARTES := {"Object_8": 0, "Object_9": 0, "Object_10": 1, "Object_11": 2}

static var _mallas := {}       # nombre -> ArrayMesh con reposo
static var _materiales := {}   # parte -> ShaderMaterial
static var _pies := Vector3.ZERO   # punto entre los pies, en el espacio del esqueleto
static var _alto_sk := 1.0         # alto de reposo en unidades del esqueleto


static func modelo(alto := ALTO) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "SimiSerenol"
	var botarga := (load(ESCENA) as PackedScene).instantiate() as Node3D
	raiz.add_child(botarga)
	var sk := botarga.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if _mallas.is_empty():
		_armar(botarga, sk)
	for m: MeshInstance3D in botarga.find_children("*", "MeshInstance3D", true, false):
		if _mallas.has(String(m.name)):
			m.mesh = _mallas[String(m.name)]
			m.material_override = _materiales[PARTES[String(m.name)]]
	# El esqueleto contra la raiz de la botarga (escala 0.01 y corrido del kiosco)
	var t := _hasta(botarga, sk)
	var escala := alto / (_alto_sk * t.basis.get_scale().y)
	botarga.scale = Vector3.ONE * escala
	botarga.position = -(t * _pies) * escala
	var ap := reproductor(raiz)
	if not ap.has_animation_library(Civiles.LIB):
		ap.add_animation_library(Civiles.LIB, Civiles.BIBLIOTECA)
	ap.play(BAILE)
	return raiz


static func reproductor(simi: Node3D) -> AnimationPlayer:
	return simi.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


static func material(parte: int) -> ShaderMaterial:
	return _materiales.get(parte)


static func _hasta(botarga: Node3D, nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = nodo
	while n != botarga and n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _armar(botarga: Node3D, sk: Skeleton3D) -> void:
	var reposos := {}
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for m: MeshInstance3D in botarga.find_children("*", "MeshInstance3D", true, false):
		if not PARTES.has(String(m.name)):
			continue
		var rep := ZombiSerenol.reposo(m, sk)
		reposos[String(m.name)] = rep
		for p in rep:
			lo = lo.min(p)
			hi = hi.max(p)
	_alto_sk = hi.y - lo.y
	var k := ALTO_REPOSO / _alto_sk
	# Centro en x/z: el de la cabeza (los ojos), para que la cara quede en x = 0
	var ojos: PackedVector3Array = reposos["Object_11"]
	var c_ojos := Vector3.ZERO
	for p in ojos:
		c_ojos += p
	c_ojos /= ojos.size()
	_pies = Vector3(c_ojos.x, lo.y, (lo.z + hi.z) * 0.5)
	var a_metros := func(p: Vector3) -> Vector3: return (p - _pies) * k
	var img := (load("res://models/personajes/dr_simi/textures/body_baseColor.jpeg") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	for nombre: String in reposos:
		var m := botarga.find_children(nombre, "MeshInstance3D", true, false)[0] as MeshInstance3D
		var rep: PackedVector3Array = reposos[nombre]
		var custom := PackedFloat32Array()
		custom.resize(rep.size() * 4)
		for i in rep.size():
			var q: Vector3 = a_metros.call(rep[i])
			custom[i * 4] = q.x
			custom[i * 4 + 1] = q.y
			custom[i * 4 + 2] = q.z
			custom[i * 4 + 3] = 1.0
		var arr := m.mesh.surface_get_arrays(0)
		arr[Mesh.ARRAY_CUSTOM0] = custom
		if nombre == "Object_8":
			arr[Mesh.ARRAY_INDEX] = _sin_pelo(arr, rep, img, lo.y + PELO_DESDE * _alto_sk)
		var formato: int = (m.mesh.surface_get_format(0) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) \
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		var nueva := ArrayMesh.new()
		nueva.add_surface_from_arrays(m.mesh.surface_get_primitive_type(0), arr, [], {}, formato)
		_mallas[nombre] = nueva
	# Los ojos: cada uno es la mitad de la malla de un lado de su centro
	var ia := Vector3.ZERO
	var ib := Vector3.ZERO
	var na := 0
	var nb := 0
	var radio := 0.0
	for p in ojos:
		var q: Vector3 = a_metros.call(p)
		if q.x < 0.0:
			ia += q
			na += 1
		else:
			ib += q
			nb += 1
	ia /= maxi(na, 1)
	ib /= maxi(nb, 1)
	for p in ojos:
		var q: Vector3 = a_metros.call(p)
		var d := Vector2(q.x - (ia.x if q.x < 0.0 else ib.x), q.y - (ia.y if q.x < 0.0 else ib.y)).length()
		radio = maxf(radio, d)
	# La panza: abajo de la corbata, un poco adentro
	var corbata_lo := Vector3.INF
	var corbata_hi := -Vector3.INF
	var m8 := botarga.find_children("Object_8", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var uv: PackedVector2Array = m8.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var rep8: PackedVector3Array = reposos["Object_8"]
	for i in rep8.size():
		var px := img.get_pixel(clampi(int(uv[i].x * img.get_width()), 0, img.get_width() - 1), clampi(int(uv[i].y * img.get_height()), 0, img.get_height() - 1))
		if px.b - px.r > 0.2:
			var q: Vector3 = a_metros.call(rep8[i])
			corbata_lo = corbata_lo.min(q)
			corbata_hi = corbata_hi.max(q)
	var panza := Vector3((corbata_lo.x + corbata_hi.x) * 0.5, corbata_lo.y - 0.08, corbata_lo.z - 0.06)
	for nombre: String in PARTES:
		var parte: int = PARTES[nombre]
		if _materiales.has(parte):
			continue
		var m := botarga.find_children(nombre, "MeshInstance3D", true, false)[0] as MeshInstance3D
		var viejo := m.get_active_material(0)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		var t: Texture2D = null
		if viejo is ShaderMaterial:
			t = (viejo as ShaderMaterial).get_shader_parameter("albedo_texture")
		elif viejo is BaseMaterial3D:
			t = (viejo as BaseMaterial3D).albedo_texture
		mat.set_shader_parameter("textura", t)
		mat.set_shader_parameter("parte", parte)
		mat.set_shader_parameter("centro_panza", panza)
		mat.set_shader_parameter("ojo_a", ia)
		mat.set_shader_parameter("ojo_b", ib)
		mat.set_shader_parameter("ojo_radio", radio)
		mat.set_shader_parameter("unidades", 1.0 / k)
		_materiales[parte] = mat


# Los indices sin los triangulos del pelo: oscuros en la textura y arriba de PELO_DESDE
static func _sin_pelo(arr: Array, rep: PackedVector3Array, img: Image, desde: float) -> PackedInt32Array:
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedInt32Array()
	for t in idx.size() / 3:
		var y := 0.0
		var lum := 0.0
		for j in 3:
			var v := idx[t * 3 + j]
			y += rep[v].y / 3.0
			lum += img.get_pixel(clampi(int(uv[v].x * w), 0, w - 1), clampi(int(uv[v].y * h), 0, h - 1)).get_luminance() / 3.0
		if y > desde and lum < 0.3:
			continue
		out.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
	return out
