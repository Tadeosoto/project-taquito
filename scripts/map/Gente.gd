class_name Gente
extends Node3D

# La gente del barrio de dia (docs/especificaciones.md 4.7). Camina por las banquetas
# (resources/map/banquetas_mapa.json, tools/map_import/banquetas.gd), hay quien se queda
# afuera de las tiendas a platicar y perros echados. Al avisar que va a oscurecer se apuran
# y ya no sale nadie; de noche no hay nadie y al amanecer vuelven.
#
# Caminan con el modelo ninja: es el unico humano con ciclo de caminar (falta pasarle
# animaciones a los demas, 10.2). Los que platican usan los otros modelos, con el clip que
# traen. Solo se decide cerca del jugador; todo sale de reservas, dentro de CargaCuadro.

const CargaCuadro := preload("res://scripts/map/CargaCuadro.gd")
const NINJA := preload("res://models/ninja_male.fbx")
const NPC := preload("res://scenes/npc.tscn")
const PERRO := preload("res://models/personajes/perro/perro.scn")
const GALON := preload("res://resources/productos/galon_agua.tres")
const PLATICAN := ["cholo", "taquero", "psx_man", "chava_psx", "mujer_psx", "gangster_dealer"]
const COLORES := [Color(0.75, 0.3, 0.25), Color(0.25, 0.5, 0.75), Color(0.8, 0.65, 0.3), Color(0.35, 0.6, 0.4), Color(0.65, 0.45, 0.7), Color(0.75, 0.75, 0.72)]
const COLOR_GARRAFONERO := Color(0.15, 0.3, 0.75)
const CLIP_CAMINA := "CharacterArmature|Walk"
const CLIP_CARGA := "CharacterArmature|Walk_Carry"
const ESCALA_NINJA := 0.55

const CAMINANTES := 12
const VELOCIDAD := 1.4
const PRISA := 2.2
const ANILLO := Vector2(25.0, 60.0)
const QUITAR_A := 75.0
const CADA := 0.5
const INTENTOS := 6
const CELDA := 32.0
const UNE_A := 14.0        # m: al acabarse una banqueta sigue por otra si esta asi de cerca
const ALTO_LIBRE := 0.6    # arriba de esto es una azotea o una barda
const ALTO_PERSONA := 1.7
const ALTO_PERRO := 0.55
const PLATICA_A := 30.0
const PLATICA_QUITAR := 40.0
const MAX_PLATICAN := 6
const MAX_PERROS := 3
const PLATICA_FRACCION := 0.6
const PERRO_CADA := 3
const LINEAS := {
	"": ["Dicen que el agua ya viene limpia. Dicen.", "De noche ni te asomes, joven.", "Yo no salgo sin mi garrafón.", "Mi compadre tomó de la llave y ya no contesta.", "¿Ya oíste los gemidos? Son los vecinos. Creo.", "Aquí todo tranquilo. Hasta que oscurece."],
	"oxxo": ["Ya no hay hielo. Ni hay de qué.", "Vine por un gansito y me quedé por el miedo."],
	"abarrotes": ["La señora fía, pero a los zombis no.", "Compra cloralex: te va a hacer falta."],
	"licoreria": ["Mientras no sea agua, se puede tomar.", "La caguama no se infecta, joven. Es ciencia."],
	"farmacia": ["El Vaporub lo cura todo. Hasta eso, creo.", "Pedí algo para los nervios y me dieron una tabla."],
	"ferreteria": ["Las tablas se están acabando: atranca bien.", "Con cinta y machete se arregla casi todo."],
	"taqueria": ["De pastor, con todo. Sin agua de la llave.", "Si te ofrecen de lengua, pregunta de quién."],
	"purificadora": ["Esta sí está limpia. Me lo juró el de la camioneta.", "El agua es lo único que vale ya."],
	"gasolinera": ["La gasolina no es para tomar. Ya hubo quien.", "Sirve para las botellas, tú me entiendes."],
}

@export_file("*.json") var banquetas_path := "res://resources/map/banquetas_mapa.json"
@export_file("*.json") var puntos_path := "res://resources/map/puntos_mapa.json"

var caminando: Array[Dictionary] = []
var platicando := {}       # indice de lugar -> nodo
var perros := {}           # indice de lugar -> nodo

var _lineas: Array = []
var _celdas := {}          # Vector2i -> [[linea, indice de punto], ...]
var _finales := {}         # Vector2i -> [[linea, 0 o ultimo], ...]
var _lugares: Array[Dictionary] = []
var _libres: Array[Dictionary] = []
var _garrafonero: Dictionary = {}
var _jugador: Node3D
var _ciclo: Node
var _saliendo := false
var _espera := 0.0
var _materiales := {}
var _rayo: PhysicsRayQueryParameters3D


func _ready() -> void:
	_rayo = PhysicsRayQueryParameters3D.new()
	_rayo.collision_mask = 1
	_jugador = get_tree().get_first_node_in_group("jugador")
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo:
		_ciclo.aviso_atardecer.connect(func() -> void: _saliendo = true)
		_ciclo.anochecio.connect(_quitar_a_todos)
		_ciclo.amanecio.connect(func() -> void: _saliendo = false)
	_cargar_banquetas()
	_cargar_lugares()


func _process(delta: float) -> void:
	if _jugador == null:
		return
	_caminar(delta)
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = CADA
	_armar_reserva()
	if not hay_gente():
		return
	_sacar_caminante()
	_platicantes()


func hay_gente() -> bool:
	return not _saliendo and not (_ciclo and _ciclo.es_noche())


# --- Caminantes ---

func _armar_reserva() -> void:
	if _garrafonero.is_empty():
		if CargaCuadro.hay():
			var inicio := Time.get_ticks_usec()
			_garrafonero = _armar_caminante(COLOR_GARRAFONERO, CLIP_CARGA)
			var galon: Node3D = GALON.crear_modelo(0.4)
			if galon:
				galon.position = Vector3(0.0, 0.6, -0.42)
				_garrafonero["nodo"].add_child(galon)
			_libres.append(_garrafonero)
			CargaCuadro.gastar(inicio)
	elif _libres.size() + caminando.size() < CAMINANTES and CargaCuadro.hay():
		var inicio := Time.get_ticks_usec()
		_libres.append(_armar_caminante(COLORES[(_libres.size() + caminando.size()) % COLORES.size()], CLIP_CAMINA))
		CargaCuadro.gastar(inicio)


func _armar_caminante(color: Color, clip: String) -> Dictionary:
	var nodo := Node3D.new()
	var modelo := NINJA.instantiate() as Node3D
	modelo.transform = Transform3D(Basis.from_scale(Vector3(-ESCALA_NINJA, ESCALA_NINJA, -ESCALA_NINJA)), Vector3.ZERO)
	nodo.add_child(modelo)
	add_child(nodo)
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in malla.mesh.get_surface_count():
			malla.set_surface_override_material(s, _pintado(malla.get_active_material(s), color))
	var animacion := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animacion.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	nodo.visible = false
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	return {"nodo": nodo, "animacion": animacion, "clip": clip, "linea": [], "i": 0, "sentido": 1, "avance": 0.0}


# Compartidos por color: no se compila un material por persona
func _pintado(fuente: Material, color: Color) -> Material:
	var clave := [fuente, color]
	if not _materiales.has(clave):
		var nuevo := fuente.duplicate()
		if nuevo is BaseMaterial3D:
			(nuevo as BaseMaterial3D).albedo_color = color
		_materiales[clave] = nuevo
	return _materiales[clave]


func _sacar_caminante() -> void:
	if _libres.is_empty():
		return
	var camara := get_viewport().get_camera_3d()
	var centro := _jugador.global_position
	for intento in INTENTOS:
		var giro := randf() * TAU
		var radio := randf_range(ANILLO.x, ANILLO.y)
		var punto := centro + Vector3(cos(giro) * radio, 0.0, sin(giro) * radio)
		var opciones: Array = _celdas.get(_celda(Vector2(punto.x, punto.z)), [])
		if opciones.is_empty():
			continue
		var opcion: Array = opciones.pick_random()
		var linea: Array = _lineas[opcion[0]]
		var i: int = opcion[1]
		var donde: Vector2 = linea[i]
		var en_mundo := Vector3(donde.x, 1.0, donde.y)
		if centro.distance_to(en_mundo) < ANILLO.x:
			continue
		if camara and not camara.is_position_behind(en_mundo) and camara.is_position_in_frustum(en_mundo):
			continue
		var y := _altura(donde)
		if y == INF:
			continue
		var c: Dictionary = _libres.pop_at(randi() % _libres.size())
		c["linea"] = linea
		c["i"] = i
		c["sentido"] = 1 if randf() < 0.5 or i == 0 else -1
		if i + c["sentido"] >= linea.size():
			c["sentido"] = -1
		c["avance"] = 0.0
		c["y"] = y
		var nodo: Node3D = c["nodo"]
		nodo.visible = true
		nodo.process_mode = Node.PROCESS_MODE_INHERIT
		nodo.global_position = Vector3(donde.x, y, donde.y)
		var animacion: AnimationPlayer = c["animacion"]
		animacion.play(c["clip"])
		animacion.seek(randf() * animacion.current_animation_length, true)
		caminando.append(c)
		return


func _caminar(delta: float) -> void:
	var velocidad := VELOCIDAD if not _saliendo else PRISA
	for c: Dictionary in caminando.duplicate():
		var linea: Array = c["linea"]
		var i: int = c["i"]
		var siguiente: int = i + c["sentido"]
		if siguiente < 0 or siguiente >= linea.size():
			_fin_de_linea(c)
			continue
		var a: Vector2 = linea[i]
		var b: Vector2 = linea[siguiente]
		var largo := a.distance_to(b)
		c["avance"] += velocidad * delta
		if c["avance"] >= largo:
			# Lo que sigue tiene que ser banqueta: si no, se da la vuelta
			var y := _altura(b)
			if y == INF:
				c["sentido"] = -c["sentido"]
				c["avance"] = 0.0
				continue
			c["y"] = y
			c["i"] = siguiente
			c["avance"] -= largo
			continue
		var p := a.lerp(b, c["avance"] / maxf(largo, 0.01))
		var nodo: Node3D = c["nodo"]
		nodo.global_position = Vector3(p.x, c["y"], p.y)
		nodo.rotation.y = atan2(-(b.x - a.x), -(b.y - a.y))
	if Engine.get_process_frames() % 30 == 0:
		for c: Dictionary in caminando.duplicate():
			if (c["nodo"] as Node3D).global_position.distance_to(_jugador.global_position) > QUITAR_A:
				_guardar(c)


func _fin_de_linea(c: Dictionary) -> void:
	var fin: Vector2 = (c["linea"] as Array)[c["i"]]
	var mejor: Array = []
	var cerca := UNE_A
	for clave in [_celda(fin)] + _vecinas(_celda(fin)):
		for otro: Array in _finales.get(clave, []):
			var punto: Vector2 = (_lineas[otro[0]] as Array)[otro[1]]
			var d := fin.distance_to(punto)
			if _lineas[otro[0]] != c["linea"] and d < cerca and _altura(punto) != INF:
				cerca = d
				mejor = otro
	if mejor.is_empty():
		c["sentido"] = -c["sentido"]
		c["avance"] = 0.0
		return
	c["linea"] = _lineas[mejor[0]]
	c["i"] = mejor[1]
	c["sentido"] = 1 if mejor[1] == 0 else -1
	c["avance"] = 0.0


func _guardar(c: Dictionary) -> void:
	caminando.erase(c)
	var nodo: Node3D = c["nodo"]
	nodo.visible = false
	(c["animacion"] as AnimationPlayer).stop()
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	_libres.append(c)


func _quitar_a_todos() -> void:
	_saliendo = true
	for c: Dictionary in caminando.duplicate():
		_guardar(c)
	for nodo: Node3D in platicando.values():
		nodo.queue_free()
	platicando.clear()
	for nodo: Node3D in perros.values():
		nodo.queue_free()
	perros.clear()


# --- Los que se quedan afuera de las tiendas ---

func _platicantes() -> void:
	var p := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	for i: int in platicando.keys():
		if p.distance_to(_lugares[i]["donde"]) > PLATICA_QUITAR:
			platicando[i].queue_free()
			platicando.erase(i)
	for i: int in perros.keys():
		if p.distance_to(_lugares[i]["perro"]) > PLATICA_QUITAR:
			perros[i].queue_free()
			perros.erase(i)
	for i in _lugares.size():
		var lugar: Dictionary = _lugares[i]
		if not CargaCuadro.hay():
			return
		if lugar["persona"] and not platicando.has(i) and platicando.size() < MAX_PLATICAN and p.distance_to(lugar["donde"]) < PLATICA_A:
			var inicio := Time.get_ticks_usec()
			_poner_platicante(i)
			CargaCuadro.gastar(inicio)
		if lugar["con_perro"] and not perros.has(i) and perros.size() < MAX_PERROS and p.distance_to(lugar["perro"]) < PLATICA_A:
			var inicio := Time.get_ticks_usec()
			_poner_perro(i)
			CargaCuadro.gastar(inicio)


func _poner_platicante(i: int) -> void:
	var lugar: Dictionary = _lugares[i]
	var donde: Vector2 = lugar["donde"]
	var y := _altura(donde)
	if y == INF:
		lugar["persona"] = false
		return
	var npc := NPC.instantiate() as Node3D
	var ninja := npc.get_node("Model")
	npc.remove_child(ninja)
	ninja.free()
	npc.set("dialogue", lugar["linea"])
	add_child(npc)
	npc.global_position = Vector3(donde.x, y, donde.y)
	npc.rotation.y = lugar["mira"]
	var nombre: String = lugar["modelo"]
	_poner_modelo(npc, load("res://models/personajes/%s/%s.scn" % [nombre, nombre]), ALTO_PERSONA)
	platicando[i] = npc


func _poner_perro(i: int) -> void:
	var lugar: Dictionary = _lugares[i]
	var donde: Vector2 = lugar["perro"]
	var y := _altura(donde)
	if y == INF:
		lugar["con_perro"] = false
		return
	var perro := Node3D.new()
	add_child(perro)
	perro.global_position = Vector3(donde.x, y, donde.y)
	perro.rotation.y = lugar["mira"] + 0.8
	_poner_modelo(perro, PERRO, ALTO_PERRO)
	perros[i] = perro


# Cada modelo viene en otra escala: se mide por sus huesos, ya con su clip puesto
func _poner_modelo(padre: Node3D, escena: PackedScene, alto: float) -> void:
	var modelo := escena.instantiate() as Node3D
	padre.add_child(modelo)
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if malla.skin == null:
			malla.visible = false
	var animacion := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animacion and not animacion.get_animation_list().is_empty():
		var clip: String = animacion.get_animation_list()[0]
		var a := animacion.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR
		animacion.play(clip)
		if a.length > 0.0:
			animacion.seek(randf() * a.length, true)
	var esqueleto := modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto == null or esqueleto.get_bone_count() == 0:
		return
	esqueleto.force_update_all_bone_transforms()
	var bajo := INF
	var arriba := -INF
	var centro := Vector3.ZERO
	var inversa := padre.global_transform.affine_inverse()
	for b in esqueleto.get_bone_count():
		var en_padre := inversa * (esqueleto.global_transform * esqueleto.get_bone_global_pose(b).origin)
		bajo = minf(bajo, en_padre.y)
		arriba = maxf(arriba, en_padre.y)
		centro += en_padre
	centro /= esqueleto.get_bone_count()
	var factor := alto / maxf(arriba - bajo, 0.001)
	modelo.scale *= factor
	modelo.position = modelo.position * factor - Vector3(centro.x * factor, bajo * factor, centro.z * factor)


# --- Datos ---

func _cargar_banquetas() -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(banquetas_path))
	if not datos is Dictionary:
		push_warning("Gente: no se pudo leer %s" % banquetas_path)
		return
	for plana: Array in datos["banquetas"]:
		var linea: Array = []
		for p: Array in plana:
			linea.append(Vector2(p[0], p[1]))
		var indice := _lineas.size()
		_lineas.append(linea)
		for i in linea.size():
			var clave := _celda(linea[i])
			if not _celdas.has(clave):
				_celdas[clave] = []
			_celdas[clave].append([indice, i])
		for i in [0, linea.size() - 1]:
			var clave := _celda(linea[i])
			if not _finales.has(clave):
				_finales[clave] = []
			_finales[clave].append([indice, i])


# Siempre los mismos lugares: dependen de cada tienda, no del azar del momento
func _cargar_lugares() -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(puntos_path))
	if not datos is Dictionary:
		push_warning("Gente: no se pudo leer %s" % puntos_path)
		return
	for p: Dictionary in datos["puntos"]:
		if not p.get("interactivo", false) or p["tipo"] == "punto" or p.get("aire_libre", false):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = String(p.get("origen", p.get("nombre", ""))).hash()
		var ry: float = p["rotacion_y"]
		var frente := Vector2(sin(ry), cos(ry))
		var lado := Vector2(frente.y, -frente.x)
		var centro := Vector2(p["x"], p["z"])
		var calle: float = p.get("fondo", 8.0) / 2.0 + 1.5
		var ancho: float = p.get("ancho", 6.0) / 2.0
		var giro: String = p.get("giro", "")
		var opciones: Array = LINEAS[""] + LINEAS.get(giro, [])
		_lugares.append({
			"donde": centro + frente * calle + lado * maxf(ancho - 0.3, 1.8),
			"perro": centro + frente * calle - lado * maxf(ancho - 0.3, 1.8),
			"mira": ry + rng.randf_range(-0.5, 0.5),
			"linea": opciones[rng.randi() % opciones.size()],
			"modelo": PLATICAN[rng.randi() % PLATICAN.size()],
			"persona": rng.randf() < PLATICA_FRACCION,
			"con_perro": rng.randi() % PERRO_CADA == 0,
		})


# Altura de la banqueta; INF si ahi hay una casa o una barda
func _altura(punto: Vector2) -> float:
	_rayo.from = Vector3(punto.x, 12.0, punto.y)
	_rayo.to = Vector3(punto.x, -2.0, punto.y)
	var pego := get_world_3d().direct_space_state.intersect_ray(_rayo)
	if pego.is_empty() or pego.position.y > ALTO_LIBRE:
		return INF
	return pego.position.y


func _celda(punto: Vector2) -> Vector2i:
	return Vector2i(floori(punto.x / CELDA), floori(punto.y / CELDA))


func _vecinas(celda: Vector2i) -> Array:
	var todas := []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x != 0 or y != 0:
				todas.append(celda + Vector2i(x, y))
	return todas
