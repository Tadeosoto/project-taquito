extends SceneTree

# Mercancia de modelo para los muebles de los interiores (Estante.gd, Mostrador.gd):
# guarda cada pieza como malla en models/interiores/<carpeta>/piezas/<categoria>_<NN>.res
# (en metros, centrada en X/Z, apoyada en y = 0, frente hacia +Z, con el material PS1
# del import y el uso de los muebles), como separar_comida.gd. Mostrador.piezas(categoria)
# las carga.
# Ferreteria:
#   herramienta  martillos, pericas, desarmadores, pinzas y llaves de tres paquetes
#                de Sketchfab que vienen acostados y con cada herramienta en varias
#                mallas: las que se tocan son una herramienta. Quedan paradas (lo
#                largo en Y) con la cara de arriba hacia el frente, para colgarlas
#   machete, bate, cinta  los modelos de la tienda (models/armas, models/objetos)
#   pintura, aerosol      botes de pintura y latas de aerosol para las repisas
# Tiendita (OXO):
#   cigarros     la cajetilla de la tienda en varios colores (`tintes`, una pieza por
#                tinte) para la cigarrera de atras
#   dulce        gansito, takis y mazapan para el mostrador
#
#   godot --path . --headless -s tools/map_import/separar_mercancia.gd
#
# Necesita los scene.gltf de models/interiores/ (en el .gitignore: bajarlos con
# fetch_sketchfab.py interiores/herramientas ... interiores/aerosol_2).

const SALIDA := "res://models/interiores/%s/piezas/"
# Acostada (lo largo en Z, la cara en +Y) -> parada con la cara al frente
const PARAR := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
# Lo largo en Z y lo delgado en X (bate, machete, cinta) -> lo largo en Y, lo
# delgado hacia el frente
const GIRAR := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))

# Cajetilla: la cara de la marca ve a +X
const CAJETILLA := Basis(Vector3.UP, -PI / 2)

# escena, categoria, giro, y `escala` (paquetes: cada herramienta por separado, sus
# mallas a esa escala; `categorias` cambia la de algun racimo) o `alto` (el modelo
# entero mide eso en Y ya girado); `carpeta` (ferreteria si no dice) y `tintes`
const FUENTES := [
	{"escena": "res://models/interiores/herramientas/scene.gltf", "categoria": "herramienta", "giro": PARAR, "escala": 0.18},
	{"escena": "res://models/interiores/herramientas_2/scene.gltf", "categoria": "herramienta", "giro": PARAR, "escala": 0.095},
	{"escena": "res://models/interiores/herramientas_psx/scene.gltf", "categoria": "herramienta", "giro": PARAR, "escala": 0.58, "categorias": {2: "machete"}},
	{"escena": "res://models/armas/machete/machete.scn", "categoria": "machete", "giro": GIRAR, "alto": 0.55},
	{"escena": "res://models/armas/bate/bate.scn", "categoria": "bate", "giro": GIRAR, "alto": 0.8},
	{"escena": "res://models/objetos/cinta/cinta.scn", "categoria": "cinta", "giro": GIRAR, "alto": 0.11},
	{"escena": "res://models/interiores/bote_pintura/scene.gltf", "categoria": "pintura", "giro": Basis(), "alto": 0.19},
	{"escena": "res://models/interiores/bote_pintura_2/scene.gltf", "categoria": "pintura", "giro": Basis(), "alto": 0.12},
	{"escena": "res://models/interiores/aerosol/scene.gltf", "categoria": "aerosol", "giro": Basis(), "alto": 0.2},
	{"escena": "res://models/interiores/aerosol_2/scene.gltf", "categoria": "aerosol", "giro": Basis(), "alto": 0.2},
	{"escena": "res://models/objetos/cigarro/cigarro.scn", "categoria": "cigarros", "giro": CAJETILLA, "alto": 0.088, "carpeta": "tiendita",
		"tintes": [Color.WHITE, Color(1.0, 0.35, 0.3), Color(0.5, 0.65, 1.0), Color(0.55, 0.9, 0.6), Color(0.5, 0.5, 0.55), Color(1.0, 0.85, 0.45)]},
	{"escena": "res://models/objetos/gansito/gansito.scn", "categoria": "dulce", "giro": Basis(), "alto": 0.13, "carpeta": "tiendita"},
	{"escena": "res://models/objetos/takis/takis.scn", "categoria": "dulce", "giro": Basis(), "alto": 0.2, "carpeta": "tiendita"},
	{"escena": "res://models/objetos/mexican_starter_pack/mazapan.scn", "categoria": "dulce", "giro": Basis(), "alto": 0.016, "carpeta": "tiendita"},
]


func _init() -> void:
	var cuantas := {}
	for fuente in FUENTES:
		var escena := load(fuente["escena"]) as PackedScene
		if escena == null:
			push_error("separar_mercancia: falta " + fuente["escena"])
			continue
		var raiz := escena.instantiate()
		var mallas := []
		_juntar(raiz, Transform3D.IDENTITY, mallas)
		var grupos: Array = _racimos(mallas) if fuente.has("escala") else [mallas]
		for g in grupos.size():
			var categoria: String = fuente.get("categorias", {}).get(g, fuente["categoria"])
			var giro: Basis = fuente["giro"]
			var caja := _caja(grupos[g], Transform3D(giro, Vector3.ZERO))
			var escala: float = fuente["escala"] if fuente.has("escala") else fuente["alto"] / caja.size.y
			var centro := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
			var ajuste := Transform3D(Basis.from_scale(Vector3.ONE * escala), -centro * escala) * Transform3D(giro, Vector3.ZERO)
			var salida := SALIDA % fuente.get("carpeta", "ferreteria")
			DirAccess.make_dir_recursive_absolute(salida)
			caja.size *= escala
			for tinte in fuente.get("tintes", [Color.WHITE]):
				var n: int = cuantas.get(categoria, 0)
				cuantas[categoria] = n + 1
				ResourceSaver.save(_unir(grupos[g], ajuste, tinte), salida + "%s_%02d.res" % [categoria, n], ResourceSaver.FLAG_COMPRESS)
				print("%s_%02d: %d mallas, %.2f x %.2f x %.2f m" % [categoria, n, grupos[g].size(), caja.size.x, caja.size.y, caja.size.z])
		raiz.free()
	quit()


# Herramientas de un paquete: grupos de mallas cuyas cajas se tocan
func _racimos(mallas: Array) -> Array:
	var cajas := []
	for m in mallas:
		cajas.append((m[1] * (m[0] as MeshInstance3D).mesh.get_aabb()).grow(0.01))
	var grupo := range(mallas.size())
	var cambio := true
	while cambio:
		cambio = false
		for i in mallas.size():
			for j in range(i + 1, mallas.size()):
				if grupo[i] != grupo[j] and cajas[i].intersects(cajas[j]):
					var viejo: int = grupo[j]
					var nuevo: int = mini(grupo[i], viejo)
					for k in mallas.size():
						if grupo[k] == viejo or grupo[k] == grupo[i]:
							grupo[k] = nuevo
					cambio = true
	var por_grupo := {}
	for i in mallas.size():
		if not por_grupo.has(grupo[i]):
			por_grupo[grupo[i]] = []
		por_grupo[grupo[i]].append(mallas[i])
	var lista := []
	for clave in por_grupo.keys():
		lista.append(por_grupo[clave])
	return lista


func _caja(mallas: Array, giro: Transform3D) -> AABB:
	var caja := AABB()
	var primera := true
	for m in mallas:
		var aabb: AABB = giro * m[1] * (m[0] as MeshInstance3D).mesh.get_aabb()
		caja = aabb if primera else caja.merge(aabb)
		primera = false
	return caja


# Una sola malla con todas las superficies ya transformadas; el material con el uso
# de los muebles (ps1_combined modo 4, ps1_gastado) y multiplicado por `tinte`
func _unir(mallas: Array, ajuste: Transform3D, tinte: Color) -> ArrayMesh:
	var malla := ArrayMesh.new()
	for m in mallas:
		var origen: Mesh = (m[0] as MeshInstance3D).mesh
		var xform: Transform3D = ajuste * m[1]
		for s in origen.get_surface_count():
			var arrays := origen.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] = xform * vertices[i]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if arrays[Mesh.ARRAY_NORMAL]:
				var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normales.size():
					normales[i] = (xform.basis * normales[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normales
			arrays[Mesh.ARRAY_TANGENT] = null
			for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
				arrays[custom] = null
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := origen.surface_get_material(s)
			if material is ShaderMaterial:
				material = material.duplicate()
				material.set_shader_parameter("deterioro_modo", 4)
				material.set_shader_parameter("desgaste", 0.25)
				var base = material.get_shader_parameter("tint")
				material.set_shader_parameter("tint", (base if base is Color else Color.WHITE) * tinte)
			malla.surface_set_material(malla.get_surface_count() - 1, material)
	return malla


func _juntar(node: Node, xform: Transform3D, mallas: Array) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		mallas.append([node, xform])
	for child in node.get_children():
		_juntar(child, xform, mallas)
