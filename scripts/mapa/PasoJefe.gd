class_name PasoJefe
extends RefCounted
## El paso del mapa a una escena de jefe (la plaza de la Mojiganga, el carcamo de la Madre) y el
## regreso (docs/plan-noche.md S8). Esas escenas tambien se lanzan solas, como prueba (reiniciar con
## la coma, capturas, mediciones): lo que decide es `desde_juego`, que solo se pone aqui al entrar
## desde una mision (PasoMision ENTRAR_A con `escena`). Las escenas de jefe lo preguntan al ganar y
## al desmayarte: con la bandera vuelven al mapa (`volver`); sin ella, como siempre.
##
## Se puede llegar a un jefe de dos maneras: con la mision que manda entrar ahi (`con_mision`) o
## sin ella, porque encontraste una EntradaJefe. Sin mision no hay premio (`hay_premio`) ni avanza
## nada: ganar solo marca al jefe como vencido (`vencido`), y la entrada ofrece repetir.
##
## Al volver, la escena de origen (MuroColonia en map_test) pone al jugador donde entro
## (`tomar_regreso`), la hora es la que tenia (PasoColonia.fraccion_del_dia) y MisionesMundo lee
## el resultado (`tomar_resultado`): ganar cumple el paso ENTRAR_A; perder lo deja para otro intento.

enum Resultado { NADA, GANO, PERDIO }

## La escena se abrio desde el juego (no como prueba suelta)
static var desde_juego := false
static var escena_origen := ""
static var regreso := Vector3.INF
static var hora_origen := -1.0
static var resultado := Resultado.NADA
## Se entro con la mision de entrar ahi: si, ganar da premio y cumple el paso
static var con_mision := false
## Los jefes que ya caen en esta partida ("catrina", "lombrices")
static var vencidos := {}
static var _jefe := ""

static var _yendo := false


## El jefe de una escena: su nombre de archivo ("catrina", "lombrices")
static func jefe_de(escena: String) -> String:
	return escena.get_file().get_basename()


static func vencido(jefe: String) -> bool:
	return vencidos.get(jefe, false)


## En la escena de jefe, al ganar: da el premio solo si se entro con la mision (o si la escena se
## lanzo sola, como prueba)
static func hay_premio() -> bool:
	return not desde_juego or con_mision


## Partida nueva (Misiones.reiniciar)
static func reiniciar() -> void:
	vencidos.clear()
	desde_juego = false
	con_mision = false
	regreso = Vector3.INF
	resultado = Resultado.NADA


## Entra a `escena` desde el mapa (`desde` es cualquier nodo del arbol, el lugar de entrada);
## `con_mision`: la mision activa manda entrar aqui; `regreso_en`: donde apareces al volver (si no,
## donde estas ahora)
static func entrar(desde: Node, escena: String, con_la_mision := false, regreso_en := Vector3.INF) -> void:
	if _yendo or desde_juego:
		return
	var arbol := desde.get_tree()
	var jugador := arbol.get_first_node_in_group("jugador") as Node3D
	var ciclo := arbol.get_first_node_in_group("ciclo") as Ciclo
	escena_origen = arbol.current_scene.scene_file_path
	regreso = regreso_en if regreso_en != Vector3.INF else (jugador.global_position if jugador else Vector3.INF)
	hora_origen = -1.0
	if ciclo:
		hora_origen = ciclo.tiempo() / maxf(ciclo.dia_duracion + ciclo.noche_duracion, 0.001)
	resultado = Resultado.NADA
	con_mision = con_la_mision
	_jefe = jefe_de(escena)
	desde_juego = true
	_yendo = true
	await PasoColonia.ir_a(desde, escena, "")
	_yendo = false


## Vuelve a la escena de origen. Las de jefe lo llaman al ganar (`gano`) o al desmayarse; si no se
## abrio desde el juego no hace nada y devuelve false (la escena sigue con su reinicio de prueba)
static func volver(desde: Node, gano: bool) -> bool:
	if not desde_juego or _yendo or escena_origen == "":
		return false
	_yendo = true
	# Ganar sin la mision no cumple nada (solo queda vencido); perder se avisa siempre
	if gano:
		vencidos[_jefe] = true
		resultado = Resultado.GANO if con_mision else Resultado.NADA
	else:
		resultado = Resultado.PERDIO
	desde_juego = false
	var salud := desde.get_node_or_null("/root/Salud")
	if salud and salud.vida < salud.vida_max / 2:
		salud.vida = salud.vida_max / 2
	await PasoColonia.ir_a(desde, escena_origen, "", hora_origen)
	_yendo = false
	return true


## Donde entro el jugador, una sola vez; Vector3.INF si no se vuelve de un jefe
static func tomar_regreso() -> Vector3:
	var donde := regreso
	regreso = Vector3.INF
	return donde


## Como termino la visita al jefe, una sola vez
static func tomar_resultado() -> Resultado:
	var que := resultado
	resultado = Resultado.NADA
	return que
