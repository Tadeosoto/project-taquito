extends SceneTree
# Las armas de fuego de caricatura (La Tinaquera, La Matraca, La Chicharra; AG, 2026-11-11).
# Blender (models/armas/fuente/armas_caricatura.blend) exporta cada una como una sola malla con el
# color en los vertices, a models/armas/<nombre>/<nombre>.glb, con la boca hacia -X como la pistola.
# Esto la guarda como <nombre>.scn con el material PS1 leyendo ese color: un solo material por arma.
#   godot --path . --headless --import
#   godot --path . --headless -s tools/armas/caricatura.gd
#   godot --path . --headless --import

const SHADER := preload("res://shaders/ps1_combined.gdshader")
const ARMAS := ["la_tinaquera", "la_matraca", "la_chicharra"]


func _init() -> void:
	for nombre: String in ARMAS:
		var base := "res://models/armas/%s/%s" % [nombre, nombre]
		var escena := load(base + ".glb") as PackedScene
		if escena == null:
			push_error("falta " + base + ".glb (corre --import primero)")
			continue
		var origen := escena.instantiate()
		var mallas := origen.find_children("*", "MeshInstance3D", true, false)
		if mallas.is_empty():
			push_error(nombre + ": sin malla")
			origen.free()
			continue
		var malla := MeshInstance3D.new()
		malla.name = "Malla"
		malla.mesh = (mallas[0] as MeshInstance3D).mesh
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("use_vertex_color", true)
		material.set_shader_parameter("affine_enabled", false)
		# En la superficie y no como material_override, igual que tools/taller/modelos.gd
		for s in malla.mesh.get_surface_count():
			malla.set_surface_override_material(s, material)
		var raiz := Node3D.new()
		raiz.name = nombre.capitalize().replace(" ", "")
		raiz.add_child(malla)
		malla.owner = raiz
		var paquete := PackedScene.new()
		paquete.pack(raiz)
		var error := ResourceSaver.save(paquete, base + ".scn", ResourceSaver.FLAG_COMPRESS)
		var caja := malla.mesh.get_aabb()
		print("%s: %s, %d superficies, %s m, color en vertices: %s" % [nombre, "ok" if error == OK else "ERROR %d" % error,
			malla.mesh.get_surface_count(), caja.size, (malla.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0])
		raiz.free()
		origen.free()
	quit()
