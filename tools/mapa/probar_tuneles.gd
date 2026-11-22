extends SceneTree

# Prueba sin ventana de las cañerías del arroyo (scenes/tuneles.tscn, P6):
#   godot --path . --headless -s tools/mapa/probar_tuneles.gd
#
# Que revisa:
#   - el campo se hornea (o se carga) y las crias nacen frente a las bocas de tubo, dentro del tunel;
#   - hay flecha de salida (atras) y flecha al carcamo (al fondo);
#   - machetazos, balas y explosiones no matan ninguna cria (solo_sal_y_fuego) y avisan con `rebote`;
#   - un puñado de sal y una zona de fuego si las matan;
#   - sin sal ni molotov, quieto al principio del tunel, las crias llegan y te bajan la vida;
#   - en map_test esta la EntradaJefe "tuneles" frente a la boca de ladrillo del arroyo, apuntando a esta escena;
#   - al ganarle a la Madre sales por el carcamo (TunelesNivel.CARCAMO_EN_MAPA), afuera de la punta norte.

const TUNELES := "res://scenes/tuneles.tscn"
const MAPA := "res://scenes/map_test.tscn"

var _fallas := 0
var _total := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	PasoColonia.simular = true
	await _tuneles()
	await _entrada_en_el_mapa()
	print("RESULTADO %d/%d" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)


func _tuneles() -> void:
	var escena: Node = (load(TUNELES) as PackedScene).instantiate()
	root.add_child(escena)
	var enjambre := escena.get_node("EnjambreLombrices") as EnjambreLombrices
	var jugador := escena.get_node("Player") as CharacterBody3D
	var salud := root.get_node("/root/Salud")
	salud.vida = salud.vida_max
	# Que no te maten mientras se revisan las armas
	escena.set("inmortal", true)
	var espera := 0
	while enjambre.horneando or enjambre.vivos_total == 0:
		await _cuadros(1)
		espera += 1
		if espera > 60 * 40:
			break
	_revisar("el campo esta listo y hay crias", not enjambre.horneando and enjambre.vivos_total == 48 * 12,
		"vivos %d" % enjambre.vivos_total)
	_revisar("las crias nacen frente a las bocas", enjambre.nidos.size() >= 5, "%d bocas" % enjambre.nidos.size())
	var adentro := true
	for i in range(0, enjambre.pos.size(), 12):
		var p := enjambre.pos[i]
		if absf(p.x) > TunelesNivel.ANCHO / 2.0 or p.z > 0.0 or p.z < -TunelesNivel.LARGO:
			adentro = false
	_revisar("todas nacen dentro del tunel", adentro, "")
	var flechas := escena.find_children("*", "Area3D", false, false)
	_revisar("flecha de salida y flecha al carcamo", flechas.size() == 2, str(flechas.size()))

	# Las armas que no sirven: una cria cualquiera, de frente
	var rebotes := [0]
	enjambre.rebote.connect(func() -> void: rebotes[0] += 1)
	await _cuadros(2)
	var antes := enjambre.vivos_total
	var p0: Vector3 = enjambre.vista[0]
	var origen := p0 + Vector3(0.0, 0.3, 1.0)
	for n in 5:
		enjambre.golpe_cuerpo(origen, Vector3.FORWARD, 3.0, -1.0, 12, true, n == 4)
		await _cuadros(3)
	_revisar("machetazos (y el tajo) no matan", enjambre.vivos_total == antes, "%d -> %d" % [antes, enjambre.vivos_total])
	for n in 5:
		var i := 0
		while i < enjambre.vivos.size() and enjambre.vivos[i] == 0:
			i += 1
		enjambre.bullet_hit(i, enjambre.vista[i], Vector3.FORWARD)
		await _cuadros(3)
	enjambre.apply_explosion_impulse(enjambre.vista[0], 3.0, 12.0, true)
	await _cuadros(3)
	_revisar("balas y explosiones no matan", enjambre.vivos_total == antes, "%d -> %d" % [antes, enjambre.vivos_total])
	_revisar("los golpes avisan (rebote)", rebotes[0] > 0, str(rebotes[0]))

	# La sal y el fuego si: donde hay crias juntas (el primer nido)
	var nido := enjambre.nidos[0]
	enjambre.salar_cono(Vector3(0.0, 0.5, nido.z), Vector3(nido.x, 0.0, 0.0).normalized(), 4.0, -1.0, 20)
	await _cuadros(4)
	var con_sal := enjambre.vivos_total
	_revisar("la sal las mata", con_sal < antes, "%d -> %d" % [antes, con_sal])
	ZonaLombrices.crear(escena, Vector3(enjambre.vista[enjambre.vivos.find(1)].x, 0.0, enjambre.vista[enjambre.vivos.find(1)].z),
		ZonaLombrices.Tipo.FUEGO, 3.0, 2.0)
	await _cuadros(30)
	_revisar("el fuego las mata", enjambre.vivos_total < con_sal, "%d -> %d" % [con_sal, enjambre.vivos_total])

	# Sin nada: te alcanzan y te bajan la vida
	enjambre.rearmar()
	escena.set("inmortal", false)
	salud.vida = salud.vida_max
	jugador.global_position = TunelesNivel.ENTRADA - Vector3(0.0, 0.0, 1.5)
	var vida0: int = salud.vida
	var menor: int = vida0
	for n in 60 * 15:
		await physics_frame
		menor = mini(menor, salud.vida)
		if salud.vida <= 0:
			break
	_revisar("sin sal ni molotov las crias te bajan la vida", menor < vida0 * 0.5, "vida %d -> %d en 15 s" % [vida0, menor])
	escena.queue_free()
	await _cuadros(3)


func _entrada_en_el_mapa() -> void:
	var escena: Node = (load(MAPA) as PackedScene).instantiate()
	root.add_child(escena)
	await _cuadros(2)
	var entrada := escena.get_node_or_null("EntradaTuneles") as Area3D
	_revisar("map_test tiene la entrada a las cañerías", entrada != null and entrada.get("escena") == TUNELES and entrada.get("id") == "tuneles", "")
	var arroyo := MuroColonia.de(self, "arroyo")
	if entrada and arroyo:
		var tubo := arroyo.get_node("Boca") as Node3D
		var donde := Vector2(entrada.global_position.x, entrada.global_position.z)
		var frente := entrada.global_transform.basis.z
		var salida := Vector2(TunelesNivel.CARCAMO_EN_MAPA.x, TunelesNivel.CARCAMO_EN_MAPA.z)
		var escalera := arroyo.get_node_or_null("Salida") as Node3D
		_revisar("al ganarle a la Madre sales afuera del arroyo, frente a la escalera de la punta norte",
			escalera != null and not arroyo.contiene(salida) and salida.distance_to(donde) > 300.0
			and salida.distance_to(Vector2(escalera.global_position.x, escalera.global_position.z)) < 4.0
			and (Vector3(salida.x, 0.0, salida.y) - escalera.global_position).dot(escalera.global_transform.basis.z) < -2.0, str(salida))
		_revisar("la flecha queda afuera, frente a la boca",
			not arroyo.contiene(donde) and donde.distance_to(Vector2(tubo.global_position.x, tubo.global_position.z)) < 3.0
			and frente.dot(tubo.global_transform.basis.z) < -0.9, str(donde))
	escena.queue_free()
	await _cuadros(2)


func _revisar(que: String, bien: bool, detalle: String) -> void:
	_total += 1
	if not bien:
		_fallas += 1
	print("%s %s %s" % ["ok   " if bien else "FALLA", que, detalle])


func _cuadros(n: int) -> void:
	for i in n:
		await physics_frame
