extends SceneTree

# Los modelos de lo que se hace en el taller (Recetas.gd):
#   - separa el paquete models/armas/melee_psx (un solo .scn con 12 armas) en una escena por
#     arma en models/armas/melee_psx/piezas/<nombre>.scn, centrada y en sus unidades (el
#     inventario las normaliza con InventoryItemData.crear_modelo);
#   - arma figuras sencillas para amuletos y estampitas en models/taller/<forma>.scn con el
#     material PS1 en blanco, para que `tinte` del .tres les ponga su color.
#
#   godot --path . --headless -s tools/taller/modelos.gd
#   godot --path . --headless --import

const PAQUETE := "res://models/armas/melee_psx/melee_psx.scn"
const PIEZAS := "res://models/armas/melee_psx/piezas/"
const FORMAS := "res://models/taller/"
const SHADER := preload("res://shaders/ps1_combined.gdshader")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIEZAS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORMAS))
	_separar_armas()
	_formas()
	quit()


func _separar_armas() -> void:
	var raiz := (load(PAQUETE) as PackedScene).instantiate()
	for malla: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
		# El nodo papa se llama como el arma (bat, axe_bloody...)
		var nombre := String(malla.get_parent().name).to_lower()
		var copia := MeshInstance3D.new()
		copia.name = "Malla"
		copia.mesh = malla.mesh
		for s in malla.get_surface_override_material_count():
			copia.set_surface_override_material(s, malla.get_surface_override_material(s))
		copia.position = -malla.mesh.get_aabb().get_center()
		_guardar(copia, PIEZAS + nombre + ".scn")
		print("arma ", nombre)
	raiz.free()


func _formas() -> void:
	var aro := TorusMesh.new()
	aro.inner_radius = 0.035
	aro.outer_radius = 0.05
	aro.rings = 12
	aro.ring_segments = 6
	_guardar(_malla(aro), FORMAS + "aro.scn")
	var medalla := Node3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.028
	disco.bottom_radius = 0.028
	disco.height = 0.005
	disco.radial_segments = 12
	var cara := _malla(disco)
	cara.rotation.x = PI / 2.0
	medalla.add_child(cara)
	var argolla := TorusMesh.new()
	argolla.inner_radius = 0.006
	argolla.outer_radius = 0.01
	argolla.rings = 8
	argolla.ring_segments = 4
	var arriba := _malla(argolla)
	arriba.position.y = 0.036
	arriba.rotation.z = PI / 2.0
	medalla.add_child(arriba)
	_guardar(medalla, FORMAS + "medalla.scn")
	var placa := BoxMesh.new()
	placa.size = Vector3(0.06, 0.09, 0.004)
	_guardar(_malla(placa), FORMAS + "placa.scn")
	var rodillera := SphereMesh.new()
	rodillera.radius = 0.08
	rodillera.height = 0.1
	rodillera.radial_segments = 10
	rodillera.rings = 5
	var r := _malla(rodillera)
	r.scale = Vector3(1.0, 1.3, 0.6)
	_guardar(r, FORMAS + "rodillera.scn")
	var corona := CylinderMesh.new()
	corona.top_radius = 0.09
	corona.bottom_radius = 0.08
	corona.height = 0.06
	corona.radial_segments = 8
	corona.cap_top = false
	_guardar(_malla(corona), FORMAS + "corona.scn")
	var liston := BoxMesh.new()
	liston.size = Vector3(0.025, 0.28, 0.003)
	_guardar(_malla(liston), FORMAS + "liston.scn")
	var faja := BoxMesh.new()
	faja.size = Vector3(0.32, 0.09, 0.02)
	_guardar(_malla(faja), FORMAS + "faja.scn")
	var chamarra := BoxMesh.new()
	chamarra.size = Vector3(0.42, 0.46, 0.1)
	_guardar(_malla(chamarra), FORMAS + "chamarra.scn")
	var lampara := Node3D.new()
	var cuerpo := CylinderMesh.new()
	cuerpo.top_radius = 0.025
	cuerpo.bottom_radius = 0.022
	cuerpo.height = 0.16
	cuerpo.radial_segments = 8
	lampara.add_child(_malla(cuerpo))
	var cabeza := CylinderMesh.new()
	cabeza.top_radius = 0.04
	cabeza.bottom_radius = 0.026
	cabeza.height = 0.05
	cabeza.radial_segments = 8
	var c := _malla(cabeza)
	c.position.y = 0.1
	lampara.add_child(c)
	_guardar(lampara, FORMAS + "lampara.scn")
	print("formas listas")


func _malla(malla: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = malla
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_color", Color(0.9, 0.9, 0.9))
	material.set_shader_parameter("affine_enabled", false)
	# En la superficie y no como material_override: InventoryItemData._pintar cambia esas
	m.set_surface_override_material(0, material)
	return m


# Guarda `nodo` como escena con raiz Node3D (InventoryItemData.crear_modelo lo pide)
func _guardar(nodo: Node3D, ruta: String) -> void:
	var raiz := Node3D.new()
	raiz.name = ruta.get_file().get_basename().capitalize().replace(" ", "")
	raiz.add_child(nodo)
	_duenos(nodo, raiz)
	var escena := PackedScene.new()
	escena.pack(raiz)
	ResourceSaver.save(escena, ruta, ResourceSaver.FLAG_COMPRESS)
	raiz.free()


func _duenos(nodo: Node, raiz: Node) -> void:
	nodo.owner = raiz
	for hijo in nodo.get_children():
		_duenos(hijo, raiz)
