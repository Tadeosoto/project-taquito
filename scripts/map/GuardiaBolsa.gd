class_name GuardiaBolsa
extends Node3D

# La bolsa de tu desmayo, como en Dark Souls (docs/especificaciones.md 1.5). Lo que hay adentro
# vive en Noches.bolsa; este nodo (lo pone Partida) la pone en el mundo:
#   - De dia: tirada en el piso (BolsaMuerte), cualquiera la recoge (AG, 2026-11-23).
#   - De noche: la carga un zombi lider en la espalda y la cuidan 3-5 mas (mas en zonas feas y
#     en noches altas, y un cazador desde la noche 6). Salen al acercarte (ACERCA) y se van si te
#     alejas (LEJOS), acordandose de cuantos mataste. El lider se toma el agua de la bolsa cada
#     rato (la pierdes). Solo matandolo la suelta; desde ahi se queda en el piso.
#   - Al amanecer los guardias caen como todos y la bolsa queda tirada. Si nadie la recoge, al
#     anochecer el lider (si sigue vivo) la vuelve a cargar.
# Adentro de una colonia amurallada (Santa Mugre: MuroColonia, o el mapa de la colonia) no hay
# guardias: alli no entran zombis de noche. Caer otra vez antes de recogerla la pierde
# (Noches.nueva_bolsa). Todos los numeros son primera propuesta (first guess).

const ACERCA := 45.0          # m: mas cerca salen los guardias
const LEJOS := 70.0           # m: mas lejos se van (Zombis.LEJOS)
const CORREA := 15.0          # m de la bolsa: mas lejos te dejan y regresan a cuidarla
const GUARDIAS_BASE := 3
const GUARDIAS_ZONA := 2      # mas en la zona mas fea (Deterioro.zona = 1)
const GUARDIAS_TOPE := 5
const GUARDIAS_CADA_NOCHES := 5   # uno mas cada tantas noches
const CAZADOR_DESDE := 6      # "despues de la noche 5"
const ALREDEDOR := Vector2(1.5, 4.0)   # m de la bolsa donde aparecen
const BEBE_CADA := Vector2(8.0, 12.0)  # s entre trago y trago
const BEBE_DURA := 2.5
const TEXTO_AVISO := "Tus cosas: las trae un zombi en la espalda"
const TEXTO_SOLTO := "¡Soltó tu bolsa!"
const TEXTO_BEBIO := "Se tomó tu %s"
const MAPA_COLONIA := "res://scenes/mapa.tscn"

var _noches: Node
var _ciclo: Ciclo
var _zombis: Zombis
var _jugador: Node3D
var _supervivencia: Node
var _piso: Node3D              # la BolsaMuerte tirada
var _lider: Zombie
var _guardias: Array[Zombie] = []
var _conexiones := {}          # guardia -> su Callable de murio, para soltarlo al devolverlo
var _marca: Node3D            # la marca del minimapa mientras la carga el lider
var _bebe_en := 0.0
var _revisar := 0.0


func _ready() -> void:
	_noches = get_node("/root/Noches")
	_ciclo = get_tree().get_first_node_in_group("ciclo") as Ciclo
	_zombis = get_tree().get_first_node_in_group("zombis_mando") as Zombis
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	_marca = Node3D.new()
	_marca.set("name", "MarcaBolsa")
	_marca.set_meta("marca", true)
	_marca.add_to_group("marca_minimapa")
	_marca.visible = false
	add_child(_marca)
	_noches.cambio.connect(_al_cambiar)
	if _ciclo:
		_ciclo.amanecio.connect(_amanecio)
		_ciclo.anochecio.connect(_al_cambiar)
	_al_cambiar()


# La de esta escena; si es de otra escena no se pone aqui
func _bolsa() -> Dictionary:
	var bolsa: Dictionary = _noches.bolsa
	if bolsa.is_empty() or bolsa.get("escena", "") != get_tree().current_scene.scene_file_path:
		return {}
	return bolsa


func _de_noche() -> bool:
	return _ciclo != null and _ciclo.es_noche()


# Se carga en la espalda (de noche, con el lider vivo y fuera de las murallas) o va al piso
func _cargada(bolsa: Dictionary) -> bool:
	return _de_noche() and bolsa.get("lider_vivo", true) and not _adentro_de_muralla(bolsa["posicion"])


func _adentro_de_muralla(punto: Vector3) -> bool:
	if get_tree().current_scene.scene_file_path == MAPA_COLONIA:
		return true
	for muro in get_tree().get_nodes_in_group("muro_colonia"):
		if muro.has_method("adentro") and muro.adentro(punto):
			return true
	return false


func _al_cambiar() -> void:
	var bolsa := _bolsa()
	if bolsa.is_empty():
		_marca.visible = false
		_quitar_piso()
		_quitar_guardias()
		return
	_marca.visible = _cargada(bolsa)
	if _marca.visible:
		_marca.global_position = bolsa["posicion"]
	if _cargada(bolsa):
		_quitar_piso()
	else:
		_quitar_guardias()
		_poner_piso(bolsa)


func _amanecio() -> void:
	# Los guardias ya cayeron con todos (Zombis._amanecer): no cuentan como muertos
	_lider = null
	_guardias.clear()
	_conexiones.clear()
	_al_cambiar()


func _poner_piso(bolsa: Dictionary) -> void:
	if is_instance_valid(_piso):
		_piso.items = bolsa["items"]
		return
	_piso = load("res://scripts/map/BolsaMuerte.gd").new()
	_piso.items = bolsa["items"]
	_piso.recogida.connect(_recogida)
	add_child(_piso)
	_piso.global_position = bolsa["posicion"]


func _quitar_piso() -> void:
	if is_instance_valid(_piso):
		_piso.queue_free()
	_piso = null


func _recogida(quedan: Array[InventoryItemData]) -> void:
	if quedan.is_empty():
		_piso = null
		_noches.quitar_bolsa()
	else:
		_noches.bolsa["items"] = quedan


func _physics_process(delta: float) -> void:
	_revisar -= delta
	if _revisar > 0.0:
		return
	_revisar = 0.25
	var bolsa := _bolsa()
	if bolsa.is_empty() or not _cargada(bolsa) or _zombis == null or _jugador == null:
		return
	var centro: Vector3 = bolsa["posicion"]
	var lejos := _jugador.global_position.distance_to(centro)
	var hay := is_instance_valid(_lider) or not _guardias.is_empty()
	if not hay and lejos <= ACERCA:
		_sacar(bolsa)
	elif hay and lejos > LEJOS:
		_quitar_guardias()
	if not hay:
		return
	# Si te alejas de la bolsa te dejan y regresan a cuidarla (menos el cazador)
	if lejos > CORREA:
		for zombi: Zombie in _todos():
			if zombi.alerta and not zombi.cazador:
				zombi.calmar()
	_beber(0.25)


func _todos() -> Array[Zombie]:
	var lista: Array[Zombie] = []
	if is_instance_valid(_lider):
		lista.append(_lider)
	for zombi in _guardias:
		if is_instance_valid(zombi) and zombi.despierto and zombi.estado != Zombie.Estado.MUERTO:
			lista.append(zombi)
	return lista


func cuantos_guardias(posicion: Vector3) -> int:
	var cuantos := GUARDIAS_BASE + roundi(Deterioro.zona(posicion.x, posicion.z) * GUARDIAS_ZONA)
	return mini(cuantos, GUARDIAS_TOPE) + int(_noches.noche / GUARDIAS_CADA_NOCHES)


func _sacar(bolsa: Dictionary) -> void:
	var centro: Vector3 = bolsa["posicion"]
	if bolsa.get("lider_vivo", true):
		var lugar := _lugar(centro)
		_lider = Zombie.new()
		_lider.lider = true
		_lider.jugador = _jugador
		_lider.zombis = _zombis
		_zombis.add_child(_lider)
		_lider.termino.connect(_lider.queue_free)
		_lider.murio.connect(_murio_lider.bind(_lider))
		_lider.despertar(lugar, false)
		_lider.guardia = true
		_lider.ancla = centro
		_bebe_en = randf_range(BEBE_CADA.x, BEBE_CADA.y)
	var faltan := cuantos_guardias(centro) - int(bolsa.get("guardias_muertos", 0))
	for i in maxi(faltan, 0):
		var lugar := _lugar(centro)
		var zombi := _zombis.sacar(lugar, false)
		_poner_guardia(zombi, centro)
	if _noches.noche >= CAZADOR_DESDE and int(bolsa.get("guardias_muertos", 0)) <= cuantos_guardias(centro):
		var cazador := _zombis.sacar(_lugar(centro), true)
		_poner_guardia(cazador, centro)
	if _supervivencia == null:
		_supervivencia = get_tree().current_scene.find_child("Supervivencia", false, false)
	if _supervivencia and _supervivencia.has_method("avisar"):
		_supervivencia.avisar(TEXTO_AVISO)


func _poner_guardia(zombi: Zombie, centro: Vector3) -> void:
	zombi.guardia = true
	zombi.ancla = centro
	var al_morir := _murio_guardia.bind(zombi)
	zombi.murio.connect(al_morir, CONNECT_ONE_SHOT)
	_conexiones[zombi] = al_morir
	_guardias.append(zombi)


# Un punto en el piso alrededor de la bolsa (como Zombis._lugar_libre, sin esconderse de la camara)
func _lugar(centro: Vector3) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	for i in 8:
		var giro := randf() * TAU
		var radio := randf_range(ALREDEDOR.x, ALREDEDOR.y)
		var punto := centro + Vector3(cos(giro) * radio, 0.0, sin(giro) * radio)
		var rayo := PhysicsRayQueryParameters3D.create(Vector3(punto.x, centro.y + 3.0, punto.z), Vector3(punto.x, centro.y - 3.0, punto.z), 1)
		var pego := espacio.intersect_ray(rayo)
		if pego and absf(pego.position.y - centro.y) < 1.0:
			return pego.position + Vector3.UP * 0.05
	return centro + Vector3.UP * 0.05


func _murio_guardia(zombi: Zombie) -> void:
	_guardias.erase(zombi)
	_conexiones.erase(zombi)
	# Al amanecer caen todos: esos no cuentan
	if not _de_noche() or _noches.bolsa.is_empty():
		return
	_noches.bolsa["guardias_muertos"] = int(_noches.bolsa.get("guardias_muertos", 0)) + 1


func _murio_lider(zombi: Zombie) -> void:
	if zombi == _lider:
		_lider = null
	if not _de_noche() or _noches.bolsa.is_empty():
		return
	# La suelta donde cayo, y ya se queda en el piso
	_noches.bolsa["lider_vivo"] = false
	_noches.bolsa["posicion"] = zombi.global_position
	if _supervivencia and _supervivencia.has_method("avisar"):
		_supervivencia.avisar(TEXTO_SOLTO)
	_al_cambiar()


# El lider se toma un trago de lo que haya de agua en tu bolsa
func _beber(delta: float) -> void:
	if not is_instance_valid(_lider):
		return
	_bebe_en -= delta
	if _bebe_en > 0.0:
		return
	_bebe_en = randf_range(BEBE_CADA.x, BEBE_CADA.y)
	var items: Array = _noches.bolsa.get("items", [])
	var agua := -1
	for i in items.size():
		if items[i] and items[i].resource_path.get_file().contains("agua"):
			agua = i
			break
	if agua < 0 or not _lider.beber(BEBE_DURA):
		return
	var nombre: String = items[agua].item_name
	items.remove_at(agua)
	if items.is_empty():
		# Se lo tomo todo: ya no hay bolsa que cuidar
		_noches.quitar_bolsa()
	print("GuardiaBolsa: el lider se tomo %s" % nombre)
	if _supervivencia and _supervivencia.has_method("avisar") and _jugador.global_position.distance_to(_lider.global_position) < CORREA:
		_supervivencia.avisar(TEXTO_BEBIO % nombre)


func _quitar_guardias() -> void:
	if is_instance_valid(_lider) and _lider.estado != Zombie.Estado.MUERTO:
		_lider.queue_free()
	_lider = null
	for zombi in _guardias:
		if not is_instance_valid(zombi):
			continue
		var al_morir: Callable = _conexiones.get(zombi, Callable())
		if al_morir.is_valid() and zombi.murio.is_connected(al_morir):
			zombi.murio.disconnect(al_morir)
		if zombi.despierto and zombi.estado != Zombie.Estado.MUERTO:
			zombi.guardia = false
			_zombis.devolver(zombi)
	_guardias.clear()
	_conexiones.clear()


# Prueba del safehouse: tirar una bolsa aqui con lo que traes
func soltar_aqui() -> void:
	var inventario := get_node("/root/Inventory")
	if inventario.items.is_empty() or _jugador == null:
		return
	_noches.nueva_bolsa(inventario.unidades(), _jugador.global_position + Vector3.DOWN + _jugador.global_basis.z * -3.0, get_tree().current_scene.scene_file_path)
	inventario.vaciar()
