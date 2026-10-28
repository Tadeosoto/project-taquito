extends SceneTree

# Sketchfab solo baja el Mexican Starter Pack entero; esto guarda cada objeto
# como su propia escena en models/objetos/mexican_starter_pack/<objeto>.scn,
# centrado en X/Z y apoyado en y = 0, con el material PS1 del import. El pack
# viene en otra unidad: todo se escala igual para que la caguama del pack (que
# no se guarda) mida ALTO_CAGUAMA.
#
#   godot --path . --headless -s tools/map_import/separar_pack.gd
#
# Necesita el original (scene.gltf, en el .gitignore: bajarlo con
# fetch_sketchfab.py). Correrlo otra vez si cambia el import del pack (TiendaPostImport).

const PACK := "res://models/objetos/mexican_starter_pack/scene.gltf"
const SALIDA := "res://models/objetos/mexican_starter_pack/"
const ALTO_CAGUAMA := 0.32
const CAGUAMA := ["Caguama"]

# Objeto -> prefijos de los nodos de malla del glTF
const OBJETOS := {
	"mochila": ["Mochila", "Line"],
	"mazapan": ["Mazapan", "Envoltura_Mazapan"],
}


func _init() -> void:
	var pack := (load(PACK) as PackedScene).instantiate()
	# _init corre antes de entrar al arbol: las transformaciones se acumulan a mano
	var mallas := {}
	_juntar(pack, Transform3D.IDENTITY, mallas)
	var caguama := _caja(mallas, CAGUAMA)
	var escala := ALTO_CAGUAMA / caguama.size.y
	for objeto in OBJETOS:
		var raiz := Node3D.new()
		raiz.name = objeto
		var caja := _caja(mallas, OBJETOS[objeto])
		var centro := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
		var ajuste := Transform3D(Basis.from_scale(Vector3.ONE * escala), -centro * escala)
		for malla: MeshInstance3D in mallas:
			if _es_de(malla.name, OBJETOS[objeto]):
				var copia := malla.duplicate() as MeshInstance3D
				copia.transform = ajuste * mallas[malla]
				raiz.add_child(copia)
				copia.owner = raiz
		if raiz.get_child_count() == 0:
			push_error("separar_pack: no hay mallas para " + objeto)
			continue
		caja.size *= escala
		var escena := PackedScene.new()
		escena.pack(raiz)
		ResourceSaver.save(escena, SALIDA + objeto + ".scn")
		print("%s: %d mallas, %.2f x %.2f x %.2f m" % [objeto, raiz.get_child_count(), caja.size.x, caja.size.y, caja.size.z])
		raiz.free()
	pack.free()
	quit()


# Malla -> transformacion respecto a la raiz del pack
func _juntar(node: Node, xform: Transform3D, mallas: Dictionary) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D:
		mallas[node] = xform
	for child in node.get_children():
		_juntar(child, xform, mallas)


func _caja(mallas: Dictionary, prefijos: Array) -> AABB:
	var caja := AABB()
	var primera := true
	for malla: MeshInstance3D in mallas:
		if _es_de(malla.name, prefijos):
			var aabb: AABB = mallas[malla] * malla.mesh.get_aabb()
			caja = aabb if primera else caja.merge(aabb)
			primera = false
	return caja


# Los nombres del glTF son "<prefijo>_Material #NN_0" o "<prefijo>__0"
func _es_de(nombre: String, prefijos: Array) -> bool:
	for prefijo in prefijos:
		if nombre.begins_with(prefijo + "_"):
			return true
	return false
