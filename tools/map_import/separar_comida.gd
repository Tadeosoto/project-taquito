extends SceneTree

# Sketchfab baja "Comida Low Poly" (models/interiores/comida) como un solo glTF con
# 121 piezas sueltas de nombres genericos; esto guarda cada una que se usa como malla
# en models/interiores/comida/piezas/<categoria>_<NN>.res, en metros, centrada en X/Z,
# apoyada en y = 0 y con el frente (la etiqueta) hacia +Z, con el material PS1 del
# import. Mostrador.comida(categoria) las carga por el prefijo.
#
#   godot --path . --headless -s tools/map_import/separar_comida.gd
#
# Las piezas que no van en ninguna categoria (34, 35: cajas de carton; 104: pizza)
# no se guardan.
#
# Necesita el original (scene.gltf, en el .gitignore: bajarlo con
# fetch_sketchfab.py interiores/comida). Correrlo otra vez si cambia su import.

const ORIGEN := "res://models/interiores/comida/scene.gltf"
const SALIDA := "res://models/interiores/comida/piezas/"
# Metros por unidad del modelo: la caja de cereal (2 unidades) queda de 26 cm
const ESCALA := 0.13

# Categoria -> indices de las mallas en el orden del arbol del glTF (se vieron en una
# hoja de contacto; los nombres del glTF son Material_0NN-materialN)
const CATEGORIAS := {
	# De refrigerador
	"charola": [2, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25],
	"bote": [112, 113, 114, 115, 116, 117, 118, 119, 120],
	# Cuna de queso amarillo, bloques blancos (panela/fresco) y uno azul (mantequilla)
	"lacteo": [5, 36, 37, 38],
	# De anaquel
	"papas": [0, 1, 3, 4, 26, 27, 28, 29, 30, 31, 32, 33],
	"cereal": [39, 40, 41, 42, 43, 44, 45, 46, 47],
	"galletas": [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58],
	"aceite": [64, 70, 71, 73],
	"refresco": [65, 66, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103],
	"limpieza": [72, 74, 75, 76, 77, 78, 79, 80, 81, 82],
	"pan": [88, 89, 90],
	"vino": [59, 60, 61, 62, 63, 83, 84, 85, 86, 87],
	"fruta": [105, 106, 107, 108, 109, 110, 111],
}


func _init() -> void:
	var raiz := (load(ORIGEN) as PackedScene).instantiate()
	var mallas := []
	_juntar(raiz, Transform3D.IDENTITY, mallas)
	if mallas.size() != 121:
		push_error("separar_comida: se esperaban 121 mallas y hay %d; revisar CATEGORIAS" % mallas.size())
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var total := 0
	for categoria in CATEGORIAS:
		var n := 0
		for indice in CATEGORIAS[categoria]:
			var instancia: MeshInstance3D = mallas[indice][0]
			var xform: Transform3D = mallas[indice][1]
			var caja: AABB = xform * instancia.mesh.get_aabb()
			var centro := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
			var ajuste := Transform3D(Basis.from_scale(Vector3.ONE * ESCALA), -centro * ESCALA) * xform
			ResourceSaver.save(_transformar(instancia.mesh, ajuste), SALIDA + "%s_%02d.res" % [categoria, n], ResourceSaver.FLAG_COMPRESS)
			n += 1
		total += n
		print("%s: %d" % [categoria, n])
	print("separar_comida: %d piezas en %s" % [total, SALIDA])
	raiz.free()
	quit()


# Copia de la malla con los vertices y normales ya transformados (mismos materiales)
func _transformar(origen: Mesh, xform: Transform3D) -> ArrayMesh:
	var malla := ArrayMesh.new()
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
		# Polvo y uso como los muebles (ps1_combined modo 4, ps1_gastado)
		var material := origen.surface_get_material(s).duplicate() as ShaderMaterial
		material.set_shader_parameter("deterioro_modo", 4)
		material.set_shader_parameter("desgaste", 0.25)
		malla.surface_set_material(s, material)
	return malla


# [MeshInstance3D, transformacion respecto a la raiz], en el orden del arbol
func _juntar(node: Node, xform: Transform3D, mallas: Array) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		mallas.append([node, xform])
	for child in node.get_children():
		_juntar(child, xform, mallas)
