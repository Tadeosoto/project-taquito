extends SceneTree

# Prueba sin ventana de las venas de Serenol de la gente de afuera (VenasSerenol.gd, JJ 2026-11-21):
#   godot --path . --headless -s tools/mapa/probar_venas.gd
#
# Que revisa:
#   - poner(true) cambia la textura del civil por shaders/venas_serenol.gdshader con su misma textura,
#     y poner(false) lo deja como estaba; dos civiles iguales comparten el material;
#   - los de ps1_combined (los que platican) tambien, y los cuicos;
#   - de_afuera: falso en una colonia de Blender (grupo "colonia") y adentro de la barda de una fortaleza
#     de map_test, verdadero afuera;
#   - en el safehouse (afuera) los que caminan, los que platican y los vendedores traen venas.

const SAFEHOUSE := "res://scenes/safehouse.tscn"
const MAPA := "res://scenes/map_test.tscn"

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	await _materiales()
	await _safehouse()
	await _fortalezas()
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _con_venas(modelo: Node) -> int:
	var n := 0
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		for s in malla.get_surface_override_material_count():
			var m := malla.get_surface_override_material(s)
			if m and m.has_meta(VenasSerenol.META):
				n += 1
	return n


func _materiales() -> void:
	var a := Node3D.new()
	var b := Node3D.new()
	root.add_child(a)
	root.add_child(b)
	Civiles.poner(a, "hombre_01")
	Civiles.poner(b, "hombre_01")
	VenasSerenol.poner(a, true)
	VenasSerenol.poner(b, true)
	var malla_a := a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var malla_b := b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var copia := malla_a.get_surface_override_material(0) as ShaderMaterial
	var original := malla_a.mesh.surface_get_material(0) as BaseMaterial3D
	_revisar("el civil trae venas", copia != null and copia.shader == VenasSerenol.SHADER, str(copia))
	_revisar("con su misma textura", copia != null and copia.get_shader_parameter("albedo_texture") == original.albedo_texture, "")
	_revisar("dos iguales comparten material", copia == malla_b.get_surface_override_material(0), "")
	VenasSerenol.poner(a, false)
	_revisar("y se le quitan", _con_venas(a) == 0, "")
	var otro := Node3D.new()
	root.add_child(otro)
	Gente.poner_modelo(otro, load("res://models/personajes/cholo/cholo.scn"), 1.7)
	VenasSerenol.poner(otro, true)
	_revisar("los de ps1_combined tambien", _con_venas(otro) > 0, "%d superficies" % _con_venas(otro))
	var cuico := Cuico.new()
	root.add_child(cuico)
	cuico.armar("policia_17")
	_revisar("los cuicos tambien", _con_venas(cuico) > 0, "%d superficies" % _con_venas(cuico))
	for n in [a, b, otro, cuico]:
		n.queue_free()
	await process_frame


func _safehouse() -> void:
	var escena: Node = (load(SAFEHOUSE) as PackedScene).instantiate()
	root.add_child(escena)
	var gente := escena.get_node("Gente") as Gente
	var espera := 0
	while gente.caminando.size() < 3 and espera < 60 * 30:
		await process_frame
		espera += 1
	var caminan := 0
	for c: Dictionary in gente.caminando:
		if _con_venas(c["nodo"]) > 0:
			caminan += 1
	_revisar("en el safehouse los que caminan traen venas", caminan > 0 and caminan == gente.caminando.size(),
		"%d de %d" % [caminan, gente.caminando.size()])
	var platican := 0
	for npc: Node in gente.platicando.values():
		if _con_venas(npc) > 0:
			platican += 1
	_revisar("y los que platican", platican == gente.platicando.size(), "%d de %d" % [platican, gente.platicando.size()])
	var vendedores := 0
	var con := 0
	for n: Node in escena.find_children("Vendedor", "", true, false):
		if n.get("modelo") is String and n.get("modelo") != "":
			vendedores += 1
			if _con_venas(n) > 0:
				con += 1
	_revisar("y los vendedores", vendedores > 0 and con == vendedores, "%d de %d" % [con, vendedores])
	escena.queue_free()
	await process_frame
	await process_frame


func _fortalezas() -> void:
	var colonia := Node3D.new()
	root.add_child(colonia)
	colonia.add_to_group("colonia")
	_revisar("en una colonia de Blender no hay venas", not VenasSerenol.de_afuera(self, Vector3.ZERO), "")
	colonia.free()
	_revisar("sin colonia ni barda, si", VenasSerenol.de_afuera(self, Vector3.ZERO), "")
	var mapa: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(mapa)
	await process_frame
	await process_frame
	var muros := get_nodes_in_group("muro_colonia")
	var adentro_bien := 0
	for muro: Node in muros:
		var pol: PackedVector2Array = muro.get("poligono")
		if pol.is_empty():
			continue
		var c := Vector2.ZERO
		for p in pol:
			c += p
		c /= pol.size()
		if muro.contiene(c) and not VenasSerenol.de_afuera(self, Vector3(c.x, 0.0, c.y)):
			adentro_bien += 1
	_revisar("adentro de las bardas de map_test no hay venas", muros.size() > 0 and adentro_bien > 0,
		"%d de %d fortalezas" % [adentro_bien, muros.size()])
	# La enfermería de la reja oriente de Santa Mugre (FortalezasMapa.CLINICAS[0]; nombrarlo desde aqui
	# no compila: FortalezasMapa usa Misiones, y con -s los autoloads aun no existen)
	var clinica := Vector2(-297.6, 560.1)
	_revisar("afuera de las bardas, si", VenasSerenol.de_afuera(self, Vector3(clinica.x, 0.0, clinica.y)), "en la enfermería de la reja oriente")
	mapa.queue_free()
	await process_frame


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s  %s  %s" % ["ok   " if bien else "FALLA", que, detalle])
