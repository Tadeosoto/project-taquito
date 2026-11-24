class_name Partida
extends CanvasLayer

# La partida sin fin (docs/especificaciones.md 1.2): ya no hay 3 noches ni pantalla final, el
# juego no se acaba. La cuenta de noches, el record y los hitos los lleva el autoload Noches
# (sobrevive a cambiar de escena); aqui se dicen y se arma lo de cada noche:
#   - Al amanecer "Sobreviviste la noche N" y, si fue la noche de un hito, su tazo holografico.
#   - En la noche del garrafonero (la 3 y sus repeticiones) sale cerca de ti; ya no detiene la
#     noche: si no lo matas, cae al amanecer con todos.
#   - Tu bolsa del desmayo (GuardiaBolsa). Las peleas de jefe son las de Juanjo (EntradaJefe y
#     PasoJefe, scripts/mapa/): Noches solo decide desde que noche se entra sin mision.
# Con Refugio (el safehouse) se defiende su tinaco; si lo tumban ya no se pierde: se avisa y se
# repara al amanecer. Morir no la termina ni reinicia la noche (Supervivencia.gd). Guarda la
# partida al amanecer (Guardado). En coop la lleva el servidor.

const JEFE_CERCA := 70.0     # Zombis.LEJOS: mas lejos puede no estar cargado el mapa ahi
const JEFE_REINTENTO := 1.0
const TEXTO_TUMBARON := "Tumbaron el tinaco. Se arregla al amanecer."
const TEXTO_JEFE := "¡Ahí viene el garrafonero!"
const TEXTO_JEFE_MUERTO := "%s mató al garrafonero."
const TEXTO_JEFE_SE_FUE := "El garrafonero se fue con la luz."
const TEXTO_JEFE_SUELTO := "Esta noche anda suelto un jefe. Búscalo en el mapa."
const TEXTO_HITO := "Premio de la noche %d"
const TEXTO_PIEZA := "Pedazo de mapa: %s"
const TEXTO_ZONA := "Entrando a: %s"
const ZONA_CADA := 0.5
const PIEZA_FRENTE := 3.0    # m frente a la fachada
const PIEZA_POSTE := 1.5     # m junto al poste
# Cada tantas noches las casas saqueadas de los vecinos (Baul.saqueadas) se vuelven a llenar (first guess)
const SAQUEO_CADA := 7
# Bolsas especiales de Takis escondidas (Tazos.gd): en estas zonas, junto a donde va su pieza
const BOLSAS_ZONAS := [1, 3, 5, 7]
const BOLSA_LADO := Vector2(4.0, 0.0)  # m de la pieza, para que no se encimen
const BOLSA := "res://resources/productos/takis_tazo.tres"
# Montones de chatarra para el taller (Chatarra.gd)
const CHATARRA_POR_ZONA := 3
const CHATARRA_LADO := Vector2(0.0, 1.6)   # m del poste
# Fierros de obra negra (alambron) y dos planos del taller frente a casas en obra negra
const OBRAS := 10
const OBRA_FRENTE := 1.5
const PLANOS_EN_OBRAS := ["lanza_varilla", "bate_cobalto"]
# Los datos del mapa: los del de OSM (map_test) o los de una colonia de Blender (scenes/mapa.tscn,
# resources/mapa/<colonia>/); MisionesMundo recibe los mismos
@export_file("*.json") var casas_json := "res://resources/map/casas_mapa.json"
const MAP_CASAS := preload("res://scripts/map/MapCasas.gd")   # sin class_name: su es_obra_negra es estatica
# Para ajustar RitmoNoche jugando. Ya no da punto de habilidad: los puntos solo salen de tazos nuevos (Tazos.gd)
const TEXTO_NOCHE := "Salieron %d zombis, mataste %d (turbas: %d)"
@export_file("*.json") var puntos_json := "res://resources/map/puntos_mapa.json"
@export_file("*.json") var postes_json := "res://resources/map/alumbrado_mapa.json"

# Las zonas y los pedazos son del mapa real; el safehouse tiene los suyos
@export var piezas_en_el_mapa := true
var misiones_config := {}
@export var zombis_path: NodePath
@export var supervivencia_path: NodePath
# Vacio: sin refugio (ver arriba)
@export var refugio_path: NodePath
# El tajo cargado y el giro en el aire (de JJ, Player.golpe_cargado / giro_aereo) se prenden con
# sus habilidades de tazo (Habilidades "tajo_cargado", "giro_aereo"). El safehouse lo apaga: ahi
# los prende siempre, con sus teclas 6 y 7
@export var habilidades_de_tazos := true

# La noche que va (la lleva Noches; esta copia es para quien la leia de aqui)
var noche := 0

var _zombis: Zombis
var _supervivencia: Node
var _refugio: Refugio
var _ciclo: Node
var _jugador: Player
var _noches: Node
var _jefe_pendiente := false
var _espera_jefe := 0.0
var _tinaco_caido := false
var _zona_actual := -1
var _espera_zona := 0.0
var _estado: Label
var _guardia_bolsa: GuardiaBolsa


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("partida")
	_noches = get_node("/root/Noches")
	noche = _noches.noche
	_zombis = get_node(zombis_path) as Zombis
	_supervivencia = get_node(supervivencia_path)
	_refugio = get_node_or_null(refugio_path) as Refugio if not refugio_path.is_empty() else null
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	_jugador = get_tree().get_first_node_in_group("jugador") as Player
	# Llegando de Continuar (Guardado): donde estabas. Supervivencia ya tomo donde empieza la escena
	# como punto de regreso; ese se queda. (De una pelea de jefe te pone MuroColonia, PasoJefe)
	var llegada: Variant = get_node("/root/Guardado").tomar_llegada()
	if llegada is Transform3D:
		_jugador.global_transform = llegada
		_jugador.velocity = Vector3.ZERO
	# Sin refugio regresas a donde empezaste (Supervivencia ya lo tiene)
	if _refugio:
		_supervivencia.punto_regreso = _refugio.punto_regreso()
		_refugio.cayo.connect(_tumbaron)
		_refugio.aviso.connect(_supervivencia.avisar)
		_refugio.noche = noche
	_ciclo.anochecio.connect(_anochecio)
	_ciclo.amanecio.connect(_amanecio)
	_armar_pantalla()
	PiezasMapa.recogida.connect(func(zona: int) -> void:
		_supervivencia.avisar(TEXTO_PIEZA % ZonasMapa.etiqueta(zona)))
	# Las hazanas que dan trofeos para el taller (Hazanas.gd)
	var hazanas := Hazanas.new()
	hazanas.name = "Hazanas"
	hazanas.refugio = _refugio
	add_child(hazanas)
	# Pasos y latido del jugador (SonidosJugador.gd)
	var cuerpo := SonidosJugador.new()
	cuerpo.name = "SonidosJugador"
	add_child(cuerpo)
	var ambiente := AmbienteMundo.new()
	ambiente.name = "AmbienteMundo"
	add_child(ambiente)
	if piezas_en_el_mapa:
		_poner_piezas()
		_poner_bolsas()
		_poner_chatarra()
		_poner_obras()
	_poner_misiones()
	if habilidades_de_tazos:
		Tazos.cambio.connect(_aplicar_habilidades)
		_aplicar_habilidades()
	_guardia_bolsa = GuardiaBolsa.new()
	_guardia_bolsa.name = "GuardiaBolsa"
	_guardia_bolsa.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_guardia_bolsa)
	# Se llego de noche (Continuar, regreso de una arena): que el jefe de esta noche salga igual
	if _ciclo.es_noche() and _noches.jefe_de() == HitoNoche.Tipo.GARRAFONERO:
		_jefe_pendiente = true


# Los tazos son la unica progresion (2026-11-23): las Mejoras ya solo estan en las pruebas
# Lo que abren tanto la campana (misiones que enseñan) como los tazos: Misiones.ataques_de_campana
func _aplicar_habilidades() -> void:
	Misiones.ataques_de_campana()


func _exit_tree() -> void:
	if habilidades_de_tazos and Tazos.cambio.is_connected(_aplicar_habilidades):
		Tazos.cambio.disconnect(_aplicar_habilidades)


# Prueba del safehouse: tu bolsa con guardias aqui mismo
func soltar_bolsa_aqui() -> void:
	_guardia_bolsa.soltar_aqui()


# "Sobreviviste la noche N" con el resumen (RitmoNoche), el record (Noches) y, si fue la noche
# de un hito, su tazo. Ya no da puntos por noche: solo los tazos nuevos (Tazos.gd). Guarda
func _amanecio() -> void:
	_jefe_pendiente = false
	if _refugio and _tinaco_caido:
		_tinaco_caido = false
		_refugio.reiniciar()
		_refugio.noche = noche
	if noche <= 0:
		return
	_supervivencia.avisar("%s\n%s" % [_noches.texto_sobreviviste(), TEXTO_NOCHE % [_zombis.salieron_noche, _zombis.muertos_noche, _zombis.turbas_noche]])
	var hito: HitoNoche = _noches.amanecio()
	if hito:
		_premio(hito)
	var guardado := get_node_or_null("/root/Guardado")
	if guardado:
		guardado.guardar.call_deferred()


# El tazo holografico del hito, con su show (como el nino de los tazos), en pausa
func _premio(hito: HitoNoche) -> void:
	var tazo: TazoData = _noches.dar_premio(hito)
	if tazo == null:
		return
	await get_tree().create_timer(2.0).timeout
	var arbol := get_tree()
	arbol.paused = true
	var show := TazoRevelacion.abrir(arbol.root, tazo, false, get_node("/root/Tazos").ultima_serie)
	await show.termino
	arbol.paused = false
	_supervivencia.avisar(TEXTO_HITO % hito.noche)


# Unas bolsas especiales tiradas, con su haz (WorldItem): junto a donde va la pieza de su
# zona. Siempre en los mismos lugares
func _poner_bolsas() -> void:
	var lugares := _lugares_de_piezas()
	var bolsa := load(BOLSA) as InventoryItemData
	for zona: int in BOLSAS_ZONAS:
		if not lugares.has(zona):
			continue
		var objeto: Node3D = load("res://scripts/WorldItem.gd").new()
		objeto.set("item_data", bolsa)
		var donde: Vector2 = lugares[zona] + BOLSA_LADO
		objeto.position = Vector3(donde.x, 0.5, donde.y)
		add_child(objeto)


# Montones de chatarra (Chatarra.gd) junto a unos postes de cada zona, para el taller.
# Siempre los mismos: CHATARRA_POR_ZONA postes repartidos a lo largo de la lista de cada zona
func _poner_chatarra() -> void:
	var postes: Variant = JSON.parse_string(FileAccess.get_file_as_string(postes_json))
	var por_zona := {}
	for poste: Dictionary in postes["postes"]:
		var zona := ZonasMapa.zona_en(poste["x"], poste["z"])
		if zona >= 0:
			if not por_zona.has(zona):
				por_zona[zona] = []
			por_zona[zona].append(Vector2(poste["x"], poste["z"]))
	for zona: int in por_zona:
		var lista: Array = por_zona[zona]
		for k in CHATARRA_POR_ZONA:
			var donde: Vector2 = lista[(k * 2 + 1) * lista.size() / (CHATARRA_POR_ZONA * 2)] + CHATARRA_LADO
			var monton := Chatarra.new()
			monton.position = Vector3(donde.x, 0.0, donde.y)
			monton.rotation.y = float(zona * 7 + k) * 1.3
			add_child(monton)


# Fierros frente a unas casas en obra negra (MapCasas.es_obra_negra): dan alambron. En los
# primeros esta tirado un plano del taller que todavia no tienes (Recetas.PLANOS; el del
# machetón lo suelta el jefe). Siempre las mismas casas: dependen solo de los datos
func _poner_obras() -> void:
	var casas: Variant = JSON.parse_string(FileAccess.get_file_as_string(casas_json))
	var obras := []
	for casa: Dictionary in casas["casas"]:
		if MAP_CASAS.es_obra_negra(casa["x"], casa["z"]):
			obras.append(casa)
	if obras.is_empty():
		return
	var planos: Array = PLANOS_EN_OBRAS.filter(func(p: String) -> bool: return not get_node("/root/Taller").planos.has(p))
	var cuantas := mini(OBRAS, obras.size())
	for k in cuantas:
		var casa: Dictionary = obras[k * obras.size() / cuantas]
		var r := float(casa["rotacion_y"])
		var frente := Vector2(sin(r), cos(r))
		var donde := Vector2(casa["x"], casa["z"]) + frente * (float(casa.get("fondo", 7.0)) / 2.0 + OBRA_FRENTE)
		var monton := Chatarra.new()
		monton.obra = true
		if k < planos.size():
			monton.plano = planos[k]
		monton.position = Vector3(donde.x, 0.0, donde.y)
		monton.rotation.y = r
		add_child(monton)


# Los del mapa real, o los que le dieron (el safehouse)
func _poner_misiones() -> void:
	var mundo := MisionesMundo.new()
	mundo.name = "MisionesMundo"
	# Partida corre siempre, por su HUD; esto no debe seguir en la pausa
	mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	mundo.puntos_path = puntos_json
	mundo.casas_path = casas_json
	mundo.postes_path = postes_json
	for propiedad: String in misiones_config:
		mundo.set(propiedad, misiones_config[propiedad])
	add_child(mundo)
	mundo.avisos_por(_supervivencia)


# Un pedazo por zona; el de donde empiezas ya lo traes
func _poner_piezas() -> void:
	var inicio := ZonasMapa.zona_en(_jugador.global_position.x, _jugador.global_position.z)
	_zona_actual = inicio
	PiezasMapa.dar(inicio)
	var lugares := _lugares_de_piezas()
	for zona in ZonasMapa.cuantas():
		if PiezasMapa.tiene(zona) or not lugares.has(zona):
			continue
		var pieza := PiezaMapa.new()
		pieza.zona = zona
		add_child(pieza)
		pieza.global_position = Vector3(lugares[zona].x, 0.0, lugares[zona].y)


# Frente a la tienda mas cerca del centro de cada zona; si no hay, junto al poste mas
# cercano (siempre estan en la banqueta). Siempre los mismos: dependen solo de los datos.
func _lugares_de_piezas() -> Dictionary:
	var lugares := {}
	var distancias := {}
	var centros := []
	for zona in ZonasMapa.cuantas():
		centros.append(ZonasMapa.a_mundo(ZonasMapa.centro(zona)))
	var puntos: Variant = JSON.parse_string(FileAccess.get_file_as_string(puntos_json))
	for p: Dictionary in puntos["puntos"]:
		if not p.get("interactivo", false) or p["tipo"] == "punto" or p.get("aire_libre", false):
			continue
		var zona := ZonasMapa.zona_en(p["x"], p["z"])
		if zona < 0:
			continue
		var d: float = centros[zona].distance_to(Vector2(p["x"], p["z"]))
		if d < distancias.get(zona, INF):
			distancias[zona] = d
			var frente := Vector2(sin(float(p["rotacion_y"])), cos(float(p["rotacion_y"])))
			lugares[zona] = Vector2(p["x"], p["z"]) + frente * (float(p.get("fondo", 8.0)) / 2.0 + PIEZA_FRENTE)
	var postes: Variant = JSON.parse_string(FileAccess.get_file_as_string(postes_json))
	var con_tienda := lugares.keys()
	for poste: Dictionary in postes["postes"]:
		var zona := ZonasMapa.zona_en(poste["x"], poste["z"])
		if zona < 0 or zona in con_tienda:
			continue
		var d: float = centros[zona].distance_to(Vector2(poste["x"], poste["z"]))
		if d < distancias.get(zona, INF):
			distancias[zona] = d
			lugares[zona] = Vector2(poste["x"], poste["z"]) + Vector2(PIEZA_POSTE, 0.0)
	return lugares


func _anochecio() -> void:
	# Se llego de otra escena a media noche: es la misma noche, no se cuenta otra vez
	if _ciclo.get("noche_continuada"):
		_ciclo.noche_continuada = false
		if _refugio:
			_refugio.noche = noche
		return
	_noches.anochecio()
	noche = _noches.noche
	get_node("/root/Tazos").nueva_noche()
	if _refugio:
		_refugio.noche = noche
	if noche % SAQUEO_CADA == 0:
		get_node("/root/Baul").saqueadas.clear()
	var hito: HitoNoche = _noches.hito_de(noche)
	if hito and hito.texto != "":
		_avisar_luego(hito.texto)
	var jefe: int = _noches.jefe_de()
	if jefe == HitoNoche.Tipo.GARRAFONERO:
		_jefe_pendiente = true
	elif jefe >= 0 and not hito:
		# Repeticion de la Madre o la Mojiganga: su entrada (EntradaJefe) ya deja pasar, solo se avisa
		_avisar_luego(TEXTO_JEFE_SUELTO)


# Despues del "Ya salieron." de Supervivencia, para que no lo tape
func _avisar_luego(texto: String) -> void:
	await get_tree().create_timer(4.5).timeout
	_supervivencia.avisar(texto)


func _process(delta: float) -> void:
	# El reloj (Ciclo.hora) y en que dia o noche vas; el record si ya hay
	var cual := "Noche %d" % noche if _ciclo.es_noche() else "Día %d" % (noche + 1)
	_estado.text = "%s · %s" % [Ciclo.texto_hora(_ciclo.hora()), cual]
	if _noches.record > 0:
		_estado.text += " · Récord %d" % _noches.record
	if _refugio:
		_estado.text += " · Tinaco %d/%d" % [_refugio.vida, Refugio.TINACO_VIDA]
	_revisar_zona(delta)
	if not _jefe_pendiente or get_tree().paused or not _ciclo.es_noche():
		return
	_espera_jefe -= delta
	if _espera_jefe > 0.0:
		return
	_espera_jefe = JEFE_REINTENTO
	var centro := _refugio.global_position if _refugio else _jugador.global_position
	if _jugador.global_position.distance_to(centro) > JEFE_CERCA:
		return
	var jefe := _zombis.aparecer_jefe(centro)
	if jefe:
		_jefe_pendiente = false
		# Mas vida en sus repeticiones (Noches.fuerza_jefe)
		var fuerza: float = _noches.fuerza_jefe()
		if fuerza > 1.0:
			jefe.set("_vida", roundi(int(jefe.get("_vida")) * fuerza))
		jefe.murio.connect(_jefe_murio)
		_supervivencia.avisar(TEXTO_JEFE)


# Al cruzar a otra zona se dice su nombre
func _revisar_zona(delta: float) -> void:
	if not piezas_en_el_mapa or get_tree().paused or not _jugador.is_physics_processing():
		return
	_espera_zona -= delta
	if _espera_zona > 0.0:
		return
	_espera_zona = ZONA_CADA
	var zona := ZonasMapa.zona_en(_jugador.global_position.x, _jugador.global_position.z)
	if zona >= 0 and zona != _zona_actual:
		_zona_actual = zona
		if ZonasMapa.nombre(zona) != "":   # las zonas sin nombre (el sureste) no avisan
			_supervivencia.avisar(TEXTO_ZONA % ZonasMapa.nombre(zona))


# Ya no termina nada: se dice y sigue la noche. Al amanecer cae solo (Zombis._amanecer): eso es
# que se fue
func _jefe_murio() -> void:
	if _ciclo.es_noche():
		_supervivencia.avisar(TEXTO_JEFE_MUERTO % Personaje.nombre)
	else:
		_supervivencia.avisar(TEXTO_JEFE_SE_FUE)


# Antes perdias la partida; ahora se avisa y el tinaco se arregla al amanecer (first guess)
func _tumbaron() -> void:
	_tinaco_caido = true
	_supervivencia.avisar(TEXTO_TUMBARON)


# Las teclas de prueba del safehouse: la cuenta de noches vuelve a cero (el record no)
func reiniciar() -> void:
	_noches.noche = 0
	noche = 0
	_jefe_pendiente = false
	_tinaco_caido = false
	_ciclo.retener_noche = false
	if _refugio:
		_refugio.reiniciar()
	# El botin que quedo tirado (CajaBotin.gd)
	get_tree().call_group("botin", "queue_free")


func _armar_pantalla() -> void:
	_estado = Label.new()
	_estado.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_estado.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_estado.offset_left = 8.0
	_estado.offset_bottom = -6.0
	_estado.add_theme_font_size_override("font_size", 14)
	_estado.add_theme_color_override("font_outline_color", Color.BLACK)
	_estado.add_theme_constant_override("outline_size", 4)
	add_child(_estado)
