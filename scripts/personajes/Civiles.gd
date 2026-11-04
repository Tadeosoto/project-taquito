class_name Civiles
extends RefCounted

# Los civiles del pack PSX (models/personajes/pack_psx/hombre_* y mujer_*, CC-BY, Elbolillo)
# para la gente del mapa: el que atiende cada tienda o puesto (MapPuntos, Interiores; npc.gd
# con `modelo`) y los que caminan por las banquetas (Gente). Traen el retarget de el_compa
# (tools/personajes/retarget_civiles.gd), asi que les sirven las animaciones de Quaternius de
# resources/personajes/animaciones_humanas.res.
# Sin tinte ni materiales propios: cada modelo trae su textura y se comparte.

const BIBLIOTECA := preload("res://resources/personajes/animaciones_humanas.res")
const LIB := "h"
const CARPETA := "res://models/personajes/pack_psx/%s/%s.fbx"
# La del protagonista: con ella miden de 1.54 a 1.86 m, cada quien su estatura
const ESCALA := 0.39
# Escritos a mano: en el juego exportado no estan los .fbx para listar la carpeta.
# Sin mujer_01: el pack la trae sin textura y sale toda blanca, no parece persona
const MODELOS := [
	"hombre_01", "hombre_02", "hombre_03", "hombre_04", "hombre_05", "hombre_06", "hombre_07",
	"hombre_08", "hombre_09", "hombre_10", "hombre_11", "hombre_12", "hombre_13", "hombre_14",
	"hombre_15", "hombre_16", "hombre_29", "hombre_30", "hombre_31", "hombre_32",
	"mujer_02", "mujer_03", "mujer_04", "mujer_05", "mujer_06", "mujer_07",
	"mujer_08", "mujer_09", "mujer_10", "mujer_11", "mujer_12", "mujer_13", "mujer_14",
	"mujer_15", "mujer_16", "mujer_29", "mujer_30", "mujer_31", "mujer_32", "mujer_33",
]


# nombre -> PackedScene. Sin guardarlas aqui nadie las retiene (las instancias no) y cada load()
# volvia a leer el modelo del disco: ~3.5 ms por vendedor al caminar, contra ~1 ms del ninja
static var _escenas := {}


# Siempre el mismo para la misma semilla (el nombre de la tienda): el que se ve por la cortina
# es el que atiende adentro
static func elegir(semilla: String) -> String:
	# rand_from_seed revuelve el hash: nombres parecidos ("safehouse/3", "safehouse/4") daban
	# civiles seguidos de la lista
	return MODELOS[rand_from_seed(semilla.hash())[0] % MODELOS.size()]


static func al_azar() -> String:
	return MODELOS.pick_random()


# Los carga en hilos al empezar, para que la primera tienda de cada uno no trabe el cuadro
static func calentar() -> void:
	for nombre: String in MODELOS:
		if not _escenas.has(nombre):
			ResourceLoader.load_threaded_request(CARPETA % [nombre, nombre])


static func _escena(nombre: String) -> PackedScene:
	if not _escenas.has(nombre):
		var ruta := CARPETA % [nombre, nombre]
		var escena: PackedScene
		# Si calentar() ya lo pidio, se espera a ese hilo en vez de cargarlo otra vez
		if ResourceLoader.load_threaded_get_status(ruta) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			escena = ResourceLoader.load_threaded_get(ruta) as PackedScene
		if escena == null:
			escena = load(ruta) as PackedScene
		_escenas[nombre] = escena
	return _escenas[nombre]


# Pone al civil dentro de `padre`, viendo a su -Z como el ninja de npc.tscn, con `clip` de la
# biblioteca en bucle y empezado en un punto al azar para que no se muevan todos igual
static func poner(padre: Node3D, nombre: String, clip := "Idle") -> AnimationPlayer:
	var modelo := _escena(nombre).instantiate() as Node3D
	modelo.name = "Civil"
	modelo.transform = Transform3D(Basis.from_scale(Vector3(-ESCALA, ESCALA, -ESCALA)), Vector3.ZERO)
	padre.add_child(modelo)
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var animacion := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animacion == null:
		animacion = AnimationPlayer.new()
		modelo.add_child(animacion)
	if not animacion.has_animation_library(LIB):
		animacion.add_animation_library(LIB, BIBLIOTECA)
	var nombre_clip := LIB + "/" + clip
	if animacion.has_animation(nombre_clip):
		var a := animacion.get_animation(nombre_clip)
		a.loop_mode = Animation.LOOP_LINEAR
		animacion.play(nombre_clip)
		if a.length > 0.0:
			animacion.seek(randf() * a.length, true)
	return animacion
