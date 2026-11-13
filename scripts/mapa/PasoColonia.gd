class_name PasoColonia
extends RefCounted
## El paso entre el mapa grande (map_test) y una colonia del mapa de Blender (scenes/mapa.tscn, que
## carga la colonia que diga `colonia`: MapaColonia.gd), o entre dos colonias de Blender (La Gotera y
## su favela). Cada reja o boca tiene una flecha amarilla de cada lado. Pisarla funde a negro y cambia
## de escena; la hora del dia pasa por aqui (Ciclo, Zombis y Partida son nodos de cada escena y
## arrancan de cero), y el jugador aparece junto a la reja del mismo lado (`lado`): MuroColonia y
## FortalezasMapa (en map_test, afuera de su reja) y Colonia.gd (en mapa.tscn, adentro) leen
## `tomar_lado()`. Inventario, dinero y vida persisten solos (son autoloads).

const MAPA_GRANDE := "res://scenes/map_test.tscn"
const MAPA_COLONIA := "res://scenes/mapa.tscn"
const FUNDIDO := 0.35
# Cuadros que se esperan, ya en la escena nueva, antes de quitar el negro
const ESPERA_FRAMES := 12

## Lado por el que se paso ("poniente", "oriente", "norte", "sur" o la boca de una favela); "" si no
## se paso por una reja
static var lado := ""
## La colonia de Blender del lado de mapa.tscn del paso: a la que se va (MapaColonia.gd la carga) o de
## la que se viene al regresar a map_test (MuroColonia y FortalezasMapa ven si es la suya)
static var colonia := "santa_mugre"
## Hora del dia como fraccion de su ciclo (0..1) para la escena nueva; -1 si no hay
static var fraccion_del_dia := -1.0

static var _yendo := false
## Para las pruebas sin ventana: con true, `ir_a` solo anota `lado` y `colonia` y no cambia de escena
static var simular := false


## Cambia a `escena` por la reja de `por`. `desde` es cualquier nodo del arbol (la flecha pisada).
## `hora` (fraccion del dia) fuerza la hora de la escena nueva; -2 es la de la escena de la que se sale.
## `a_colonia` es la colonia de Blender del paso (ver `colonia`); "" la deja como estaba (Santa Mugre
## por omision)
static func ir_a(desde: Node, escena: String, por: String, hora := -2.0, a_colonia := "") -> void:
	if _yendo:
		return
	_yendo = true
	if a_colonia != "":
		colonia = a_colonia
	if simular:
		lado = por
		_yendo = false
		return
	var arbol := desde.get_tree()
	var jugador := arbol.get_first_node_in_group("jugador")
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_DISABLED
	var capa := CanvasLayer.new()
	capa.layer = 100
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.modulate.a = 0.0
	capa.add_child(negro)
	arbol.root.add_child(capa)
	var entra := capa.create_tween()
	entra.tween_property(negro, "modulate:a", 1.0, FUNDIDO)
	await entra.finished
	# La hora: como fraccion, porque cada escena tiene su propia duracion de dia y de noche
	var ciclo := arbol.get_first_node_in_group("ciclo") as Ciclo
	fraccion_del_dia = -1.0
	if ciclo:
		fraccion_del_dia = ciclo.tiempo() / maxf(ciclo.dia_duracion + ciclo.noche_duracion, 0.001)
	if hora != -2.0:
		fraccion_del_dia = hora
	lado = por
	arbol.change_scene_to_file(escena)
	for i in ESPERA_FRAMES:
		await arbol.process_frame
	var sale := capa.create_tween()
	sale.tween_property(negro, "modulate:a", 0.0, FUNDIDO)
	await sale.finished
	capa.queue_free()
	_yendo = false


## El lado por el que se llego, una sola vez (lo lee la escena nueva y lo borra)
static func tomar_lado() -> String:
	var que := lado
	lado = ""
	return que


## La hora que trae la escena nueva (fraccion de su ciclo), una sola vez; -1 si no hay
static func tomar_hora() -> float:
	var que := fraccion_del_dia
	fraccion_del_dia = -1.0
	return que
