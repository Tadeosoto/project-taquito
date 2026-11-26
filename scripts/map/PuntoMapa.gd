@tool
class_name PuntoMapa
extends Node3D

# El edificio de El Punto en el mundo: la Cantina El Olvido de dos pisos (models/negocios/punto/
# punto_fuera.glb, de tools/blender/negocios/punto.py), con el anexo del mural al oeste, el lote
# enrejado con el Caprice y la troca al este, y sillas, motos, foquitos y el lowrider en la banqueta.
# MapPuntos lo pone en cada punto (tipo "punto"), y el safehouse uno completo.
#
# Se entra a la cantina caminando (CasaPropia con scenes/casas/cantina.tscn): la flecha va en la
# puerta (Marca_Flecha). Adentro, la puerta de atras lleva a la oficina de Don Lalo (Cantina.gd).
# De noche (Ciclo.anochecio/amanecio) salen dos halcones a la puerta, unos se toman algo afuera y
# se prenden las luces de la banqueta; el letrero de neon siempre brilla.
#
# El origen es el centro de la fachada de la cantina, +Z a la calle. La cantina mide CANTINA_ANCHO;
# en un lote mas angosto todo se encoge (hasta ESCALA_MIN), y el anexo y el lote solo se quedan si
# el terreno alcanza (`ancho` del lote; con 0 se quedan, como en el safehouse).

const MODELO := preload("res://models/negocios/punto/punto_fuera.glb")
const CANTINA_ESCENA := "res://scenes/casas/cantina.tscn"
const CASA_PROPIA := "res://scripts/interiores/CasaPropia.gd"
const NPC := "res://scenes/npc.tscn"
const CANTINA_ANCHO := 6.0
const ANEXO_ANCHO := 6.0          # cada ala (el anexo al oeste, el lote al este)
const ESCALA_MIN := 0.75
const PUERTA_X := 1.7             # x de la puerta de la cantina (punto.py PUERTA)
const LEJOS := 160.0              # m hasta donde se dibuja
const HALCONES := ["Aquí nomás, cuidando. ¿Vas con el patrón? Pásale.", "No vimos nada, compa. Ni a ti."]
const LUZ_NOCHE := Color(1.0, 0.8, 0.5)

@export var ancho := 0.0          # del lote; 0 = sin limite
@export var con_banqueta := true
# Con cantina para caminar (CasaPropia en la puerta); sin ella el edificio es de adorno
@export var con_entrada := true

var _noche: Node3D


func _ready() -> void:
	var edificio := MODELO.instantiate() as Node3D
	edificio.name = "Edificio"
	add_child(edificio)
	var esc := escala(ancho)
	edificio.scale = Vector3.ONE * esc
	var alas := ancho <= 0.0 or ancho >= (CANTINA_ANCHO + 2.0 * ANEXO_ANCHO) * esc
	for nodo in edificio.find_children("*", "", true, false):
		var n := String(nodo.name)
		if (not alas and (n.begins_with("Anexo_") or n.begins_with("Lote_"))) or (not con_banqueta and n.begins_with("Banqueta_")):
			nodo.queue_free()
	for malla in edificio.find_children("*", "GeometryInstance3D", true, false):
		(malla as GeometryInstance3D).visibility_range_end = LEJOS
	if Engine.is_editor_hint():
		return
	if con_entrada:
		var flecha := edificio.find_child("Marca_Flecha", true, false) as Node3D
		_entrada(flecha.global_position if flecha else global_transform * Vector3(PUERTA_X * esc, 0, esc))
	_preparar_noche(edificio)


# Que tanto se encoge el edificio en un lote de `ancho` m (0: nada)
static func escala(ancho_lote: float) -> float:
	if ancho_lote <= 0.0:
		return 1.0
	return clampf(ancho_lote / CANTINA_ANCHO, ESCALA_MIN, 1.0)


# La flecha de la puerta: CasaPropia mete al jugador a la cantina, que se camina
func _entrada(en: Vector3) -> void:
	var jugador := get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	var casa: Node = (load(CASA_PROPIA) as GDScript).new()
	casa.name = "EntradaCantina"
	casa.set("escena", load(CANTINA_ESCENA))
	casa.set("player_path", jugador.get_path())
	var zombis := get_tree().get_first_node_in_group("zombis_mando")
	if zombis:
		casa.set("zombis_path", zombis.get_path())
	casa.set("flecha_en", en)
	casa.set("calle_giro", global_rotation.y)
	casa.set("nombre", "Cantina El Olvido")
	add_child(casa)


# --- De noche

func _preparar_noche(edificio: Node) -> void:
	_noche = Node3D.new()
	_noche.name = "Noche"
	add_child(_noche)
	var halcones := 0
	for marca in edificio.find_children("Marca_Noche_*", "", true, false):
		var m := marca as Node3D
		var nombre := String(m.name)
		var donde := m.global_transform
		if nombre.begins_with("Marca_Noche_halcon"):
			var npc := (load(NPC) as PackedScene).instantiate() as Node3D
			npc.set("modelo", _hombre("halcon_%d" % halcones))
			npc.set("nombre", "Halcón")
			npc.set("dialogue", HALCONES[halcones % HALCONES.size()])
			_noche.add_child(npc)
			npc.global_transform = donde
			halcones += 1
		elif nombre.begins_with("Marca_Noche_toma"):
			var nodo := Node3D.new()
			_noche.add_child(nodo)
			nodo.global_transform = donde
			Civiles.poner(nodo, _hombre(nombre), "Drink")
		elif nombre.begins_with("Marca_Noche_luz"):
			var luz := OmniLight3D.new()
			luz.light_color = LUZ_NOCHE
			luz.light_energy = 1.4
			luz.omni_range = 7.0
			_noche.add_child(luz)
			luz.global_position = donde.origin
	var ciclo := get_tree().get_first_node_in_group("ciclo")
	if ciclo:
		ciclo.anochecio.connect(func() -> void: _de_noche(true))
		ciclo.amanecio.connect(func() -> void: _de_noche(false))
		_de_noche(ciclo.es_noche())
	else:
		_de_noche(false)


func _de_noche(si: bool) -> void:
	_noche.visible = si
	_noche.process_mode = Node.PROCESS_MODE_INHERIT if si else Node.PROCESS_MODE_DISABLED


func _hombre(semilla: String) -> String:
	for k in 50:
		var nombre := Civiles.elegir("punto_%s_%d" % [semilla, k])
		if nombre.begins_with("hombre_"):
			return nombre
	return "hombre_01"
