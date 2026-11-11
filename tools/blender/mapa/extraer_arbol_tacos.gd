extends SceneTree
# Saca de "Tacos_ Props" (Elbolillo, CC BY 4.0, models/tiendas/tacos_props/tacos_props.scn) los dos
# arboles del paquete (Tree_ y Tree_01: tronco "BarkDecidious" y copa "Branches", ~750 triangulos
# cada uno) a tools/blender/mapa/modelos/arbol_tacos.json, para que la pieza `ficus` los arme en
# Blender (kit.py: Constructor.arbol_modelo), y copia sus dos texturas a textures/mapa/.
# Cada variante queda en metros, con la base del tronco en (0, 0, 0), Y arriba, y su altura y ancho:
#
#     godot --headless --path . -s tools/blender/mapa/extraer_arbol_tacos.gd

const ORIGEN := "res://models/tiendas/tacos_props/tacos_props.scn"
const SALIDA := "res://tools/blender/mapa/modelos/arbol_tacos.json"
const TEXTURAS := {
	"corteza": ["res://models/tiendas/tacos_props/textures/BarkDecidious_baseColor.jpeg", "res://textures/mapa/arbol_corteza.png"],
	"hojas": ["res://models/tiendas/tacos_props/textures/Branches_baseColor.png", "res://textures/mapa/arbol_hojas.png"],
}
const VARIANTES := ["Tree_", "Tree_01_"]
const PARTES := {"BarkDecidious_0": "corteza", "Branches_0": "hojas"}
const TEXTURA_MAX := 256


func _init() -> void:
	var raiz: Node = (load(ORIGEN) as PackedScene).instantiate()
	var salida := []
	for prefijo in VARIANTES:
		var partes := {}
		var minimo := Vector3(INF, INF, INF)
		var maximo := Vector3(-INF, -INF, -INF)
		for sufijo in PARTES:
			var nodo := raiz.find_child(prefijo + sufijo, true, false) as MeshInstance3D
			if nodo == null:
				push_error("falta %s%s" % [prefijo, sufijo])
				continue
			var xform := _global(nodo, raiz)
			var v := PackedVector3Array()
			var uv := PackedVector2Array()
			var idx := PackedInt32Array()
			for s in nodo.mesh.get_surface_count():
				var arr := nodo.mesh.surface_get_arrays(s)
				var base := v.size()
				for p: Vector3 in arr[Mesh.ARRAY_VERTEX]:
					var q := xform * p
					v.append(q)
					minimo = minimo.min(q)
					maximo = maximo.max(q)
				if arr[Mesh.ARRAY_TEX_UV] != null:
					uv.append_array(arr[Mesh.ARRAY_TEX_UV])
				for i: int in arr[Mesh.ARRAY_INDEX]:
					idx.append(base + i)
			partes[PARTES[sufijo]] = {"v": v, "uv": uv, "i": idx}
		# Base del tronco en el origen: centro en x y z de la caja, y = 0 en lo mas bajo
		var centro := Vector3((minimo.x + maximo.x) / 2.0, minimo.y, (minimo.z + maximo.z) / 2.0)
		var variante := {"altura": snapped(maximo.y - minimo.y, 0.001), "ancho": snapped(maxf(maximo.x - minimo.x, maximo.z - minimo.z), 0.001)}
		for nombre in partes:
			var datos: Dictionary = partes[nombre]
			var lista := []
			for p: Vector3 in datos["v"]:
				var q := p - centro
				lista.append([snapped(q.x, 0.001), snapped(q.y, 0.001), snapped(q.z, 0.001)])
			var uvs := []
			for t: Vector2 in datos["uv"]:
				uvs.append([snapped(t.x, 0.0001), snapped(t.y, 0.0001)])
			variante[nombre] = {"v": lista, "uv": uvs, "i": Array(datos["i"])}
		salida.append(variante)
		print(prefijo, " altura ", variante["altura"], " ancho ", variante["ancho"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA).get_base_dir())
	var f := FileAccess.open(SALIDA, FileAccess.WRITE)
	f.store_string(JSON.stringify({"variantes": salida}))
	f.close()
	for nombre in TEXTURAS:
		var imagen := Image.load_from_file(ProjectSettings.globalize_path(TEXTURAS[nombre][0]))
		if maxi(imagen.get_width(), imagen.get_height()) > TEXTURA_MAX:
			var k := float(TEXTURA_MAX) / maxi(imagen.get_width(), imagen.get_height())
			imagen.resize(int(imagen.get_width() * k), int(imagen.get_height() * k), Image.INTERPOLATE_LANCZOS)
		imagen.save_png(ProjectSettings.globalize_path(TEXTURAS[nombre][1]))
		print("textura ", nombre, " ", imagen.get_size())
	print("guardado ", SALIDA)
	raiz.free()
	quit()


# La transformacion del nodo respecto a la raiz (el arbol no esta en la escena, sin global_transform)
func _global(nodo: Node3D, raiz: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = nodo
	while n != null and n != raiz:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
