extends RefCounted

# Piezas sueltas de los packs del proyecto para armar los puestos del tianguis: un nodo (con sus
# mallas) sacado de una escena, asentado con su base en el origen y en metros reales.
# pieza(pack, nodo) da un Node3D nuevo; las mallas y materiales son los de la escena (compartidos).

const PACKS := {
	"tacos": "res://models/tiendas/tacos_props/tacos_props.scn",
	"fruta": "res://models/interiores/estante_fruta/estante_fruta.scn",
	"silla": "res://models/interiores/silla_plegable/silla_plegable.scn",
	"cajas": "res://models/bodegas/cajas/cajas.scn",
	"mesa": "res://models/casa_personaje/mesa/mesa.glb",
	"estante": "res://models/bodegas/estante_oxidado/estante_oxidado.scn",
	"mostrador": "res://models/interiores/mostrador/mostrador.scn",
}

# [pack/nodo] -> [[mesh, transform respecto a la base, materiales]]
static var _cache := {}
static var _abiertos := {}


# Suelta lo guardado: las escenas abiertas quedan fuera del arbol y, sin liberarlas, Godot las reporta
# como fugas al cerrar (hay que llamarla cuando ya no queda ningun Tianguis)
static func vaciar() -> void:
	for escena: Node in _abiertos.values():
		if is_instance_valid(escena):
			escena.free()
	_abiertos.clear()
	_cache.clear()


static func pieza(pack: String, nodo: String) -> Node3D:
	var clave := pack + "/" + nodo
	if not _cache.has(clave):
		_cache[clave] = _sacar(pack, nodo)
	var partes: Array = _cache[clave]
	if partes.is_empty():
		return null
	var raiz := Node3D.new()
	raiz.name = nodo if nodo != "" else pack
	for p in partes:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[1]
		for s in p[2].size():
			if p[2][s]:
				mi.set_surface_override_material(s, p[2][s])
		raiz.add_child(mi)
	return raiz


static func caja_de(raiz: Node3D) -> AABB:
	var caja := AABB()
	var hay := false
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.transform * mi.mesh.get_aabb()
		caja = b if not hay else caja.merge(b)
		hay = true
	return caja


static func _sacar(pack: String, nodo: String) -> Array:
	# Instancia la escena una vez (fuera del arbol), busca el nodo y junta sus mallas con su
	# transformacion respecto a la raiz de la escena; luego las recorre para que la base quede en 0
	if not _abiertos.has(pack):
		_abiertos[pack] = (load(PACKS[pack]) as PackedScene).instantiate()
	var escena: Node3D = _abiertos[pack]
	var desde: Node = escena if nodo == "" else escena.find_child(nodo, true, false)
	if desde == null:
		push_warning("TianguisPiezas: no hay %s en %s" % [nodo, pack])
		return []
	var mallas: Array = desde.find_children("*", "MeshInstance3D", true, false)
	if desde is MeshInstance3D:
		mallas.append(desde)
	var partes := []
	var caja := AABB()
	for m in mallas:
		var mi := m as MeshInstance3D
		var t := _relativo(escena, mi)
		var mats := []
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s) if mi.get_surface_override_material(s) else mi.material_override)
		partes.append([mi.mesh, t, mats])
		var b := t * mi.mesh.get_aabb()
		caja = b if partes.size() == 1 else caja.merge(b)
	var base := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
	for p in partes:
		p[1].origin -= base
	return partes


static func _relativo(raiz: Node, nodo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = nodo
	while n != raiz and n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
