class_name EntradaJefe
extends Node3D

# La flecha amarilla a la arena de un jefe (PasoArena.gd): La Madre del Carcamo desde la noche
# 10, La Mojiganga desde la 15 (resources/noches/hitos.tres). Solo se ve y solo funciona de
# noche, desde su hito. La pone Partida en un lugar fijo del mapa; se marca en el minimapa
# (grupo "marca_minimapa"). Al regresar de la arena apareces frente a ella (REGRESO_FRENTE).

const REGRESO_FRENTE := 3.0   # m frente a la flecha, para no volver a pisarla al regresar
const LETRERO_ALTO := 2.6

## HitoNoche.Tipo del jefe (MADRE_CARCAMO o MOJIGANGA)
@export var tipo: HitoNoche.Tipo = HitoNoche.Tipo.MADRE_CARCAMO
@export var texto := "La Madre del Cárcamo"
## Para probar (el safehouse): abierta aunque no sea su noche
@export var siempre := false

var marca_color := Color(1.0, 0.85, 0.1)   # MapMinimapa la pinta asi

var _area: Area3D
var _ciclo: Ciclo
var _noches: Node


func _ready() -> void:
	add_to_group("marca_minimapa")
	_ciclo = get_tree().get_first_node_in_group("ciclo") as Ciclo
	_noches = get_node_or_null("/root/Noches")
	_area = Area3D.new()
	_area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	_area.add_child(forma)
	_area.add_child(MapPuntos.flecha())
	var letrero := Label3D.new()
	letrero.text = texto
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.position = Vector3(0.0, LETRERO_ALTO, 0.0)
	letrero.visibility_range_end = 40.0
	_area.add_child(letrero)
	_area.body_entered.connect(_pisada)
	add_child(_area)
	_actualizar()


func abierta() -> bool:
	if siempre:
		return true
	return _noches != null and _ciclo != null and _ciclo.es_noche() and _noches.arena_abierta(tipo)


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var si := abierta()
	if visible != si:
		visible = si
	_area.monitoring = si


func _pisada(cuerpo: Node3D) -> void:
	if not cuerpo is Player or not abierta():
		return
	var escena := PasoArena.ARENA_MADRE if tipo == HitoNoche.Tipo.MADRE_CARCAMO else PasoArena.ARENA_MOJIGANGA
	var regreso := Transform3D(global_basis, global_position + global_basis.z * REGRESO_FRENTE + Vector3.UP * 1.1)
	var fuerza: float = _noches.fuerza_jefe() if _noches else 1.0
	PasoArena.ir(self, escena, regreso, fuerza)
