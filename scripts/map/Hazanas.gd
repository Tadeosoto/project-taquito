class_name Hazanas
extends Node

# Las hazanas que dan trofeos para el taller (Materiales.gd, como las piedras raras de Kingdom
# Hearts que solo salen ganandole de cierta forma a ciertos enemigos). La crea Partida.gd; los
# zombis le avisan al morir (grupo "hazanas"). Cada trofeo sale una vez por noche como mucho,
# menos el diente del jefe. Propuesta de AG.
#   Marca de cazador: matar a un cazador         Ojo de turba: 5 cazadores en 10 s
#   Ceniza: matar a uno quemandose               Chancla de oro: matar a uno sin arma
#   Tapa del tinaco: una noche sin que le peguen al tinaco
#   Diente del jefe: matar al jefe (y suelta el primer plano que falte)
#   Casco de GelA y Cobalto: los zombis raros (Zombie.variante)

const TURBA := 5
const TURBA_SEGUNDOS := 10.0

var refugio: Refugio

var _ya := {}                # trofeo -> true: ya salio esta noche
var _turba: Array[int] = []  # ms de las ultimas muertes de cazadores
var _tinaco_al_anochecer := -1


func _ready() -> void:
	add_to_group("hazanas")
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.anochecio.connect(_anochecio)
		ciclo.amanecio.connect(_amanecio)


func zombi_muerto(zombi: Node, quemado: bool) -> void:
	var morral := get_node("/root/Morral")
	if quemado:
		morral.dar("baba_verde")
		_trofeo("ceniza")
	if zombi.get("cazador") == true:
		_trofeo("marca_cazador")
		var ahora := Time.get_ticks_msec()
		_turba.append(ahora)
		_turba = _turba.filter(func(t: int) -> bool: return ahora - t <= TURBA_SEGUNDOS * 1000.0)
		if _turba.size() >= TURBA:
			_turba.clear()
			_trofeo("ojo_turba")
	var inventario := get_node_or_null("/root/Inventory")
	if inventario and inventario.arma() == null:
		_trofeo("chancla_oro")
	match zombi.get("variante"):
		"gela":
			morral.dar("polvo_serenol")
			_trofeo("casco_gela")
		"cobalto":
			_trofeo("cobalto")
	if zombi.get("es_jefe") == true:
		morral.dar("diente_jefe")
		var taller := get_node("/root/Taller")
		for plano: String in Recetas.PLANOS:
			if not taller.planos.has(plano):
				taller.dar_plano(plano)
				morral.avisar("¡Plano! " + Recetas.PLANOS[plano])
				break


func _trofeo(id: String) -> void:
	if _ya.has(id):
		return
	_ya[id] = true
	get_node("/root/Morral").dar(id)


func _anochecio() -> void:
	_ya.clear()
	_tinaco_al_anochecer = refugio.vida if refugio else -1


func _amanecio() -> void:
	if refugio and _tinaco_al_anochecer >= 0 and refugio.vida >= _tinaco_al_anochecer:
		_trofeo("tapa_tinaco")
	_tinaco_al_anochecer = -1
