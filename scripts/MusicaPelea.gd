class_name MusicaPelea
extends AudioStreamPlayer
# La musica de pelea (JJ): cada vez que entra toca una cancion al azar de res://soundtrack/, en
# bucle, distinta de la anterior si hay mas de una. Para quitar una cancion basta con borrar (o
# sacar de la carpeta) su .mp3; para agregar otra, ponerla ahi. Si la carpeta queda vacia suena
# pt_tema. Las peleas con cancion propia (JJ, 2026-11-18) la piden por su ruta: TINACO, CUCARRATA.
#
# Uso: var m := MusicaPelea.new(); add_child(m); m.entrar() ... m.salir()   (m.entrar(CUCARRATA): esa)
# Quien ya tiene su propio AudioStreamPlayer puede pedir solo la pista: MusicaPelea.pista_al_azar()
# Sigue sonando con el arbol en pausa (el inventario abierto).

const CARPETA := "res://soundtrack/"
const RESPALDO := "res://audio/musica/pt_tema.mp3"
const EXTENSIONES := ["mp3", "ogg", "wav"]
const SILENCIO := -40.0   # dB
# Las que no van al azar (JJ, 2026-11-18)
const TINACO := "res://soundtrack/PT tema.mp3"      # la defensa del tinaco
const CUCARRATA := "res://soundtrack/pefd.mp3"      # la pelea de la cucarrata

static var _ultima := ""

# dB al sonar y segundos de los fundidos
var volumen := -8.0
var entra := 2.0
var sale := 2.5

var _tween: Tween
var _saliendo := false


# Las canciones que hay en la carpeta (ResourceLoader ve tambien las de un juego exportado)
static func pistas() -> PackedStringArray:
	var lista := PackedStringArray()
	if DirAccess.dir_exists_absolute(CARPETA):
		for archivo in ResourceLoader.list_directory(CARPETA):
			if archivo.get_extension().to_lower() in EXTENSIONES:
				lista.append(CARPETA + archivo)
	return lista


# Una cancion al azar, que no repite la ultima, ya en bucle
static func pista_al_azar() -> AudioStream:
	var lista := pistas()
	# Para oir una sola: godot --path . <escena> -- --pista=notprfect (parte del nombre basta)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pista="):
			var busca := arg.trim_prefix("--pista=").to_lower()
			for ruta in lista:
				if busca in ruta.get_file().to_lower():
					lista = PackedStringArray([ruta])
					break
	if lista.size() > 1 and _ultima in lista:
		lista.remove_at(lista.find(_ultima))
	var ruta := RESPALDO if lista.is_empty() else lista[randi() % lista.size()]
	_ultima = ruta
	return pista(ruta)


# Esa cancion, ya en bucle; si no esta (la borraron de soundtrack/), la de respaldo
static func pista(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		ruta = RESPALDO
	var pista := load(ruta) as AudioStream
	if pista is AudioStreamMP3:
		(pista as AudioStreamMP3).loop = true
	elif pista is AudioStreamOggVorbis:
		(pista as AudioStreamOggVorbis).loop = true
	elif pista is AudioStreamWAV:
		(pista as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(pista as AudioStreamWAV).loop_end = int((pista as AudioStreamWAV).get_length() * (pista as AudioStreamWAV).mix_rate)
	return pista


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_db = SILENCIO


# Ya suena (o esta entrando); falso mientras se apaga
func sonando() -> bool:
	return playing and not _saliendo


# Entra una cancion nueva: `ruta` si se da, si no una al azar; si ya sonaba una, la deja
func entrar(ruta := "") -> void:
	if sonando():
		return
	if not playing:
		stream = pista(ruta) if ruta != "" else pista_al_azar()
		volume_db = SILENCIO
		play()
	_saliendo = false
	_fundir(volumen, entra)


func salir() -> void:
	if not playing or _saliendo:
		return
	_saliendo = true
	_fundir(SILENCIO, sale)


# Corta en seco (reiniciar una pelea)
func cortar() -> void:
	if _tween:
		_tween.kill()
	_saliendo = false
	stop()
	volume_db = SILENCIO


func _fundir(db: float, segundos: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", db, segundos)
	if db <= SILENCIO:
		_tween.tween_callback(func() -> void:
			_saliendo = false
			stop())
