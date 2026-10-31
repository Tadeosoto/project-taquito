extends Node

# La conexion del coop (autoload `Red`): un jugador hospeda y los demas entran, por Steam
# (lo de verdad) o por ENet (para probar con varias ventanas en la misma PC, sin Steam).
# Sin conexion todo sigue funcionando: jugar solo es no llamar nada de aqui.
#
# Los RPC viven en este autoload, no en los nodos de la escena: existe siempre con la
# misma ruta, asi que no truena si llega algo mientras otro jugador carga un mapa.
#
# Steam se usa por nombre (Engine.get_singleton, ClassDB) para que el juego siga
# corriendo aunque falte addons/godotsteam. App ID 480 es Spacewar, la prueba de Valve:
# hasta tener la app propia en Steam.

signal jugadores_cambiaron
signal estado_recibido(id: int, posicion: Vector3, giro: float, moviendose: bool, en_aire: bool, corriendo: bool, se_ve: bool)
signal aviso(texto: String)

const MENU := "res://scenes/menu.tscn"
const PUERTO := 24777
const MAX_JUGADORES := 4
const STEAM_APP_ID := 480
const STEAM_LOBBY_AMIGOS := 1

# id de red -> nombre de todos los que estan, tu incluido
var jugadores := {}
var nombre := "Jugador"
var escena_actual := ""
# Lo ultimo que salio mal, para que el menu lo diga al volver
var ultimo_aviso := ""

var _en_red := false
var _steam: Object = null
var _lobby := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_se_fue)
	multiplayer.connected_to_server.connect(_conectado)
	multiplayer.connection_failed.connect(func() -> void: _volver_al_menu("No se pudo conectar."))
	multiplayer.server_disconnected.connect(func() -> void: _volver_al_menu("Se fue el que hospedaba."))
	# Steam abre el juego asi cuando aceptas una invitacion con el juego cerrado
	var argumentos := OS.get_cmdline_args()
	var i := argumentos.find("+connect_lobby")
	if i >= 0 and i + 1 < argumentos.size():
		_unirse_steam_al_arrancar.call_deferred(argumentos[i + 1].to_int())


func _process(_delta: float) -> void:
	if _steam:
		_steam.run_callbacks()


func en_red() -> bool:
	return _en_red


func es_host() -> bool:
	return not _en_red or multiplayer.is_server()


func mi_id() -> int:
	return multiplayer.get_unique_id() if _en_red else 1


func steam_disponible() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")


# --- ENet: varias ventanas en la misma PC, o la misma red ---

func hospedar_enet(escena: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PUERTO, MAX_JUGADORES - 1) != OK:
		aviso.emit("No se pudo abrir el puerto %d." % PUERTO)
		return false
	multiplayer.multiplayer_peer = peer
	_empezar_host(escena)
	return true


func unirse_enet(direccion: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(direccion, PUERTO) != OK:
		aviso.emit("No se pudo conectar a %s." % direccion)
		return false
	multiplayer.multiplayer_peer = peer
	return true


# --- Steam ---

func iniciar_steam() -> bool:
	if _steam:
		return true
	if not steam_disponible():
		aviso.emit("Falta el addon de Steam.")
		return false
	var steam := Engine.get_singleton("Steam")
	var resultado: Dictionary = steam.steamInitEx(STEAM_APP_ID, true)
	if resultado.get("status", 1) != 0:
		aviso.emit("Steam: %s" % resultado.get("verbal", "no inicio"))
		return false
	_steam = steam
	nombre = steam.getPersonaName()
	steam.lobby_created.connect(_lobby_creado)
	steam.lobby_joined.connect(_lobby_unido)
	steam.join_requested.connect(func(lobby: int, _amigo: int) -> void: unirse_lobby(lobby))
	return true


var _escena_por_hospedar := ""


func hospedar_steam(escena: String) -> bool:
	if not iniciar_steam():
		return false
	_escena_por_hospedar = escena
	_steam.createLobby(STEAM_LOBBY_AMIGOS, MAX_JUGADORES)
	aviso.emit("Creando partida en Steam...")
	return true


func unirse_lobby(lobby: int) -> void:
	if iniciar_steam():
		aviso.emit("Entrando...")
		_steam.joinLobby(lobby)


# La ventana de Steam para invitar amigos a tu partida
func invitar() -> void:
	if _steam and _lobby != 0:
		_steam.activateGameOverlayInviteDialog(_lobby)


func _unirse_steam_al_arrancar(lobby: int) -> void:
	unirse_lobby(lobby)


func _lobby_creado(resultado: int, lobby: int) -> void:
	if resultado != 1:
		aviso.emit("Steam no pudo crear la partida (%d)." % resultado)
		return
	_lobby = lobby
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_host(0)
	if error != OK:
		aviso.emit("Steam no pudo hospedar (%d)." % error)
		return
	peer.set("server_relay", true)
	multiplayer.multiplayer_peer = peer
	_empezar_host(_escena_por_hospedar)


func _lobby_unido(lobby: int, _permisos: int, _bloqueado: bool, respuesta: int) -> void:
	# 1 = entro (CHAT_ROOM_ENTER_RESPONSE_SUCCESS)
	if respuesta != 1:
		aviso.emit("No se pudo entrar a la partida (%d)." % respuesta)
		return
	var dueno: int = _steam.getLobbyOwner(lobby)
	# El dueno tambien recibe esta senal al crearla
	if dueno == _steam.getSteamID():
		return
	_lobby = lobby
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_client(dueno, 0)
	if error != OK:
		aviso.emit("No se pudo conectar con el que hospeda (%d)." % error)
		return
	peer.set("server_relay", true)
	multiplayer.multiplayer_peer = peer


# --- Comun ---

func _empezar_host(escena: String) -> void:
	_en_red = true
	jugadores = {1: nombre}
	jugadores_cambiaron.emit()
	escena_actual = escena
	_cargar(escena)


func _conectado() -> void:
	_en_red = true
	_hola.rpc_id(1, nombre)


# Solo el host cambia de escena, y se van todos con el. Solo o sin red, cambia y ya
func cambiar_escena(escena: String) -> void:
	if not _en_red:
		_cargar(escena)
	elif es_host():
		escena_actual = escena
		_ir_a.rpc(escena)
		_cargar(escena)


func salir() -> void:
	if _en_red:
		multiplayer.multiplayer_peer.close()
	_limpiar()
	if _steam and _lobby != 0:
		_steam.leaveLobby(_lobby)
	_lobby = 0


func _limpiar() -> void:
	_en_red = false
	jugadores.clear()
	escena_actual = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	jugadores_cambiaron.emit()


func _volver_al_menu(texto: String) -> void:
	ultimo_aviso = texto
	salir()
	aviso.emit(texto)
	_cargar(MENU)


func _cargar(escena: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(escena)


func _se_fue(id: int) -> void:
	if not multiplayer.is_server() or not jugadores.has(id):
		return
	aviso.emit("%s se fue." % jugadores[id])
	jugadores.erase(id)
	_lista.rpc(jugadores)
	jugadores_cambiaron.emit()


# Un jugador acaba de conectar y se presenta. Solo lo atiende el host
@rpc("any_peer", "call_remote", "reliable")
func _hola(su_nombre: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if jugadores.size() >= MAX_JUGADORES:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	jugadores[id] = su_nombre
	_lista.rpc(jugadores)
	jugadores_cambiaron.emit()
	_ir_a.rpc_id(id, escena_actual)


@rpc("authority", "call_remote", "reliable")
func _lista(todos: Dictionary) -> void:
	jugadores = todos
	jugadores_cambiaron.emit()


@rpc("authority", "call_remote", "reliable")
func _ir_a(escena: String) -> void:
	escena_actual = escena
	_cargar(escena)


func enviar_estado(posicion: Vector3, giro: float, moviendose: bool, en_aire: bool, corriendo: bool, se_ve: bool) -> void:
	if _en_red and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_estado.rpc(posicion, giro, moviendose, en_aire, corriendo, se_ve)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _estado(posicion: Vector3, giro: float, moviendose: bool, en_aire: bool, corriendo: bool, se_ve: bool) -> void:
	estado_recibido.emit(multiplayer.get_remote_sender_id(), posicion, giro, moviendose, en_aire, corriendo, se_ve)
