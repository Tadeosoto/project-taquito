extends SceneTree
# Saca de los arboles de Sketchfab de models/arboles/ (arce, realista, roble; los baja
# tools/map_import/fetch_sketchfab.py arboles/arce arboles/realista arboles/roble) la malla de cada uno
# a resources/mapa/arboles_modelos.json, que dibuja scripts/mapa/ArbolesModelo.gd en el juego (un
# MultiMesh por arbol, desde resources/mapa/<colonia>/arboles_modelo.json), y sus dos texturas (corteza y hojas, esta con alfa) a
# textures/mapa/arbol_<nombre>_corteza.png y _hojas.png. Cada arbol queda en metros-unidad (la altura
# se normaliza a 1), con la base del tronco en (0, 0, 0), Y arriba, y su ancho (en alturas):
#
#     godot --headless --path . -s tools/blender/mapa/extraer_arboles.gd

const ARBOLES := {
	# nombre: [escena, texturas que se tiran (el pasto y la hojarasca del suelo del arce)]
	"arce": ["res://models/arboles/arce/scene.gltf", ["grass_baseColor.jpeg", "Groundcover_Wood_Mix_baseColor.jpeg"]],
	"realista": ["res://models/arboles/realista/scene.gltf", []],
	"roble": ["res://models/arboles/roble/scene.gltf", []],
}
const SALIDA := "res://resources/mapa/arboles_modelos.json"
const TEXTURA_MAX := 256


func _init() -> void:
	var salida := {}
	for nombre in ARBOLES:
		var raiz: Node = (load(ARBOLES[nombre][0]) as PackedScene).instantiate()
		var tirar: Array = ARBOLES[nombre][1]
		# textura (nombre del archivo o del recurso) -> {"v", "uv", "i", "imagen"}
		var grupos := {}
		_recoger(raiz, raiz, tirar, grupos)
		raiz.free()
		var minimo := Vector3(INF, INF, INF)
		var maximo := Vector3(-INF, -INF, -INF)
		for k in grupos:
			for p: Vector3 in grupos[k]["v"]:
				minimo = minimo.min(p)
				maximo = maximo.max(p)
		var altura := maximo.y - minimo.y
		var corteza := ""
		var hojas := ""
		for k in grupos:
			var imagen: Image = grupos[k]["imagen"]
			var minuscula: String = String(k).to_lower()
			if "leaf" in minuscula or "leaves" in minuscula or (imagen != null and imagen.detect_alpha() != Image.ALPHA_NONE and _alfa_real(imagen)):
				hojas = k
			elif corteza == "":
				corteza = k
		# Base del tronco: el promedio en x y z de los vertices de la corteza en su 5 % de abajo
		var suma := Vector2.ZERO
		var cuantos := 0
		for p: Vector3 in grupos[corteza]["v"]:
			if p.y < minimo.y + altura * 0.05:
				suma += Vector2(p.x, p.z)
				cuantos += 1
		var base := Vector3(suma.x / maxi(cuantos, 1), minimo.y, suma.y / maxi(cuantos, 1))
		var arbol := {}
		var ancho := 0.0
		for rol in {"corteza": corteza, "hojas": hojas}:
			var clave: String = corteza if rol == "corteza" else hojas
			if clave == "":
				continue
			var g: Dictionary = grupos[clave]
			var v := []
			for p: Vector3 in g["v"]:
				var q := (p - base) / altura
				ancho = maxf(ancho, maxf(absf(q.x), absf(q.z)) * 2.0)
				v.append([snapped(q.x, 0.0005), snapped(q.y, 0.0005), snapped(q.z, 0.0005)])
			var uv := []
			for t: Vector2 in g["uv"]:
				uv.append([snapped(t.x, 0.001), snapped(t.y, 0.001)])
			arbol[rol] = {"v": v, "uv": uv, "i": Array(g["i"])}
			var imagen: Image = g["imagen"].duplicate()
			if imagen.is_compressed():
				imagen.decompress()
			if maxi(imagen.get_width(), imagen.get_height()) > TEXTURA_MAX:
				var k := float(TEXTURA_MAX) / maxi(imagen.get_width(), imagen.get_height())
				imagen.resize(maxi(int(imagen.get_width() * k), 1), maxi(int(imagen.get_height() * k), 1), Image.INTERPOLATE_LANCZOS)
			if rol == "hojas":
				_sin_halo(imagen)
				_apagar_brillos(imagen)
			imagen.save_png(ProjectSettings.globalize_path("res://textures/mapa/arbol_%s_%s.png" % [nombre, rol]))
			print(nombre, " ", rol, " ", g["i"].size() / 3, " triangulos, textura ", imagen.get_size())
		arbol["ancho"] = snapped(ancho, 0.001)
		salida[nombre] = arbol
		print(nombre, ": altura original ", snapped(altura, 0.01), ", ancho (en alturas) ", arbol["ancho"])
	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify(salida))
	f.close()
	print("guardado ", SALIDA)
	quit()


# Lo transparente de las hojas toma el color promedio de lo opaco: con el color que traia (blanco),
# el borde de cada hoja salia con un halo claro al achicar la textura y al filtrar
func _sin_halo(imagen: Image) -> void:
	imagen.convert(Image.FORMAT_RGBA8)
	var suma := Vector3.ZERO
	var cuantos := 0
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			if c.a > 0.5:
				suma += Vector3(c.r, c.g, c.b)
				cuantos += 1
	if cuantos == 0:
		return
	var medio := suma / cuantos
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			if c.a <= 0.5:
				imagen.set_pixel(x, y, Color(medio.x, medio.y, medio.z, c.a))


# Las nervaduras y brillos casi blancos de algunas hojas (el arce: 20 % de la textura) se veian como
# destellos blancos entre la copa: lo que pasa de BRILLO_MAX se baja a casi nada de ahi para arriba
const BRILLO_MAX := 0.55
const BRILLO_RESTO := 0.25


func _apagar_brillos(imagen: Image) -> void:
	for y in imagen.get_height():
		for x in imagen.get_width():
			var c := imagen.get_pixel(x, y)
			var mayor := maxf(c.r, maxf(c.g, c.b))
			if mayor > BRILLO_MAX:
				var k := (BRILLO_MAX + (mayor - BRILLO_MAX) * BRILLO_RESTO) / mayor
				imagen.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))


# Una textura con alfa de verdad (no un canal alfa todo opaco)
func _alfa_real(imagen: Image) -> bool:
	var copia := imagen.duplicate() as Image
	if copia.is_compressed():
		copia.decompress()
	var paso := maxi(copia.get_width() / 32, 1)
	for y in range(0, copia.get_height(), paso):
		for x in range(0, copia.get_width(), paso):
			if copia.get_pixel(x, y).a < 0.5:
				return true
	return false


func _recoger(nodo: Node, raiz: Node, tirar: Array, grupos: Dictionary) -> void:
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
		var m := nodo as MeshInstance3D
		var t := Transform3D.IDENTITY
		var a: Node = nodo
		while a != null and a != raiz:
			if a is Node3D:
				t = (a as Node3D).transform * t
			a = a.get_parent()
		for s in m.mesh.get_surface_count():
			var textura := _textura(m.mesh.surface_get_material(s))
			var clave := textura.resource_path.get_file() if textura else "sin_textura"
			if textura and textura.resource_path.get_file() == "" :
				clave = String(textura.resource_name) if textura.resource_name != "" else "tex_%d" % textura.get_instance_id()
			if clave in tirar or textura == null:
				continue
			if not grupos.has(clave):
				grupos[clave] = {"v": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array(), "imagen": textura.get_image()}
			var g: Dictionary = grupos[clave]
			var arr := m.mesh.surface_get_arrays(s)
			var base: int = g["v"].size()
			for p: Vector3 in arr[Mesh.ARRAY_VERTEX]:
				g["v"].append(t * p)
			if arr[Mesh.ARRAY_TEX_UV] != null:
				g["uv"].append_array(arr[Mesh.ARRAY_TEX_UV])
			else:
				for _i in arr[Mesh.ARRAY_VERTEX].size():
					g["uv"].append(Vector2.ZERO)
			for i: int in arr[Mesh.ARRAY_INDEX]:
				g["i"].append(base + i)
	for h in nodo.get_children():
		_recoger(h, raiz, tirar, grupos)


func _textura(mt: Material) -> Texture2D:
	if mt is ShaderMaterial:
		return (mt as ShaderMaterial).get_shader_parameter("albedo_texture") as Texture2D
	if mt is BaseMaterial3D:
		return (mt as BaseMaterial3D).albedo_texture
	return null
