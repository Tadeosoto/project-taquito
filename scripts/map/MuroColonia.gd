class_name MuroColonia
extends Node3D
## Una fortaleza amurallada del mapa completo, leida de resources/map/fortalezas.json por su `id`
## (S9): la barda por su poligono, sus rejas de fierro y, si tiene colonia de Blender, una flecha
## amarilla por fuera de cada reja que lleva a scenes/mapa.tscn con esa colonia (PasoColonia). Adentro
## no se camina: se entra por la flecha. En map_test hay una por fortaleza:
## - santa_mugre: el recorte de Parques de Santa Mugre (las bardas Barda_* y las `rejas` de
##   tools/blender/mapa/colonias/santa_mugre.json: si cambian alla, cambian en el .json de aqui), con
##   la lamina de los fieles encima del block (`alto_muralla`) y dos rejas cerradas en la avenida.
## - la_gotera: por las calles de Haciendas de San Jodido (docs/mapa/colonias/la_gotera.md), con sus dos
##   rejas abiertas en la Av. del Cedro hacia el tianguis.
## - gela: Los Reservorios, la barda del ITESO con su caseta y la pluma cerrada (sin colonia todavia).
## - arroyo: el corredor verde del arroyo, de la entrada de los tuneles (P6, al sur de la cancha de la
##   Unidad Deportiva Parques del Bosque) al Camino Real a Colima. Sin rejas: la entrada es la boca de
##   ladrillo de las cañerías (`boca`) en la tapa norte, la misma boveda que se ve adentro de tuneles.tscn.
## Todo choca en la capa 1, como las casas: jugador, zombis y CampoFlujo la ven sin cambios.

const PS1_SHADER := preload("res://shaders/ps1_combined.gdshader")
const DATOS := "res://resources/map/fortalezas.json"

## La entrada de fortalezas.json que se arma
@export var id := "santa_mugre"
@export var jugador_path: NodePath

const GRUESO := 0.3
const COLOR_FIERRO := Color(0.12, 0.12, 0.13)
## De la reja a la flecha de entrada, y a donde aparece el jugador al salir de la colonia de Blender
const FLECHA_FUERA := 2.2
const LLEGADA_FUERA := 5.4
## La boca de las cañerías (`boca` en el .json, JJ): una escalera de ladrillo que baja BAJADA m hacia adentro
## del arroyo, con sus muros a la altura de la barda (no se brincan), y abajo el arco del colector con su reja. El suelo del mapa no
## se dibuja sobre el hueco (los globales `hoyo_*`, shaders/ps1_hoyo.gdshaderinc)
const BAJADA := 4.8            # del suelo al pasillo del tunel: la clave queda 0.8 m bajo tierra
const PELDANO := Vector2(0.3, 0.2)   # huella y peralte
const DESCANSO := 1.0          # el rellano de abajo, frente al arco
const PARED := 0.4             # grueso de los muros del pozo
const ABERTURA := 1.6          # el paso del pretil del frente, donde esta la flecha
const CABEZAL := 0.8           # grueso del muro del arco

## Lo leido del .json
var nombre := ""
var colonia := ""
var poligono := PackedVector2Array()
var cerrada := true
var alto := 2.6
var alto_muralla := 0.0
## Cada reja: {lado, centro, rumbo, largo, abierta, afuera} (Vector2 en x, z; `afuera` calculado)
var rejas: Array[Dictionary] = []
## La caja del poligono (para quien solo necesita un rectangulo, como la camioneta)
var rect := Rect2()

var _datos: Dictionary = {}
var _calles := Rect2()
var _con_hoyo := false
var _material_muro: ShaderMaterial
var _material_fierro: ShaderMaterial
var _material_lamina: ShaderMaterial

static var _cache: Dictionary = {}


## Las entradas de fortalezas.json (se lee una vez)
static func todas() -> Dictionary:
	if _cache.is_empty():
		var leido = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
		if leido is Dictionary:
			_cache = leido
	return _cache


## El muro de la fortaleza `cual` en la escena, o null
static func de(arbol: SceneTree, cual: String) -> MuroColonia:
	for muro: Node in arbol.get_nodes_in_group("muro_colonia"):
		if muro is MuroColonia and muro.id == cual:
			return muro
	return null


# Si `punto` cae dentro de alguna fortaleza de la escena. Ahi no aparecen zombis de noche (Zombis), no
# entran los cuicos (Cuicos) y la gente habla como de adentro (Gente)
static func adentro(arbol: SceneTree, punto: Vector3) -> bool:
	var p := Vector2(punto.x, punto.z)
	for muro: Node in arbol.get_nodes_in_group("muro_colonia"):
		if muro is MuroColonia and muro.contiene(p):
			return true
	return false


## Si `p` cae adentro de la barda, o a menos de `margen` m de ella
func contiene(p: Vector2, margen := 0.0) -> bool:
	if not rect.grow(margen).has_point(p):
		return false
	if Geometry2D.is_point_in_polygon(p, poligono):
		return true
	if margen <= 0.0:
		return false
	var n := poligono.size() if cerrada else poligono.size() - 1
	for i in n:
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < margen:
			return true
	return false


func _enter_tree() -> void:
	add_to_group("muro_colonia")
	_leer()
	# Los carros (CallesRuta) no cruzan por adentro
	if _calles.has_area():
		CallesRuta.cerrar(_calles)
	# Si se llego de la colonia de Blender por una reja (PasoColonia), el jugador aparece afuera de ella.
	# Esto va aqui, antes de que el jugador, el dron y Supervivencia lean su posicion (este nodo va
	# antes que ellos en la escena y todavia no entran al arbol)
	var jugador := get_node_or_null(jugador_path) as Node3D
	if jugador == null:
		return
	# Si se vuelve de una escena de jefe (PasoJefe), donde se entro a ella (lo toma el primer muro)
	var de_regreso := PasoJefe.tomar_regreso()
	if de_regreso != Vector3.INF:
		jugador.position = de_regreso
		return
	if colonia == "" or PasoColonia.colonia != colonia or not tiene_reja(PasoColonia.lado):
		return
	var donde := _afuera(PasoColonia.tomar_lado(), LLEGADA_FUERA)
	jugador.position = Vector3(donde.x, 1.5, donde.y)


func _exit_tree() -> void:
	if _con_hoyo:
		RenderingServer.global_shader_parameter_set("hoyo_medida", Vector4.ZERO)
	if _calles.has_area():
		CallesRuta.abrir(_calles)


func _leer() -> void:
	if not _datos.is_empty():
		return
	_datos = todas().get(id, {})
	if _datos.is_empty():
		push_error("MuroColonia: no hay '%s' en %s" % [id, DATOS])
		return
	nombre = _datos.get("nombre", id)
	colonia = _datos.get("colonia", "")
	cerrada = _datos.get("cerrada", true)
	alto = _datos.get("alto", alto)
	alto_muralla = _datos.get("alto_muralla", 0.0)
	poligono = PackedVector2Array()
	for v: Array in _datos.get("poligono", []):
		poligono.append(Vector2(v[0], v[1]))
	rect = Rect2(poligono[0], Vector2.ZERO)
	for v in poligono:
		rect = rect.expand(v)
	var c: Array = _datos.get("calles", [])
	if c.size() == 4:
		_calles = Rect2(c[0], c[1], c[2] - c[0], c[3] - c[1])
	var medio := _centro()
	for r: Dictionary in _datos.get("rejas", []):
		var centro := Vector2(r["centro"][0], r["centro"][1])
		var rumbo := Vector2(r["rumbo"][0], r["rumbo"][1]).normalized()
		var normal := Vector2(-rumbo.y, rumbo.x)
		rejas.append({
			"lado": r["lado"], "centro": centro, "rumbo": rumbo, "largo": float(r["largo"]),
			"abierta": r.get("abierta", false),
			"afuera": normal if normal.dot(centro - medio) > 0.0 else -normal,
		})


func _ready() -> void:
	if poligono.is_empty():
		return
	var color: Array = _datos.get("color", [0.62, 0.6, 0.57])
	var lamina: Array = _datos.get("color_lamina", [0.3, 0.36, 0.3])
	_material_muro = _material(Color(color[0], color[1], color[2]))
	_material_fierro = _material(COLOR_FIERRO)
	_material_lamina = _material(Color(lamina[0], lamina[1], lamina[2]))
	var huecos: Array = []
	for reja in rejas:
		huecos.append([reja["centro"], reja["largo"]])
	var caseta: Dictionary = _datos.get("caseta", {})
	if not caseta.is_empty():
		huecos.append([Vector2(caseta["centro"][0], caseta["centro"][1]), float(caseta["hueco"])])
	var boca: Dictionary = _datos.get("boca", {})
	if not boca.is_empty():
		huecos.append([Vector2(boca["centro"][0], boca["centro"][1]), float(boca["ancho"])])
	_barda(huecos)
	for reja in rejas:
		_reja(reja)
		if colonia != "":
			_flecha_de_entrada(reja["lado"])
	if not caseta.is_empty():
		_caseta(Vector2(caseta["centro"][0], caseta["centro"][1]), float(caseta["hueco"]))
	if not boca.is_empty():
		_boca(Vector2(boca["centro"][0], boca["centro"][1]), Vector2(boca["rumbo"][0], boca["rumbo"][1]).normalized(),
				float(boca["ancho"]))


func _material(base: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PS1_SHADER
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("deterioro_modo", 2)
	material.set_shader_parameter("affine_enabled", false)
	material.set_shader_parameter("jitter_enabled", false)
	material.set_shader_parameter("wobble_enabled", false)
	return material


func _centro() -> Vector2:
	var suma := Vector2.ZERO
	for v in poligono:
		suma += v
	return suma / poligono.size()


# --- La barda ---

# La barda por el poligono, con huecos ([centro, ancho]) donde caen sobre la linea de un tramo. Un hueco
# puede caer en una esquina y abarcar dos tramos: a cada uno le quita su parte
func _barda(huecos: Array) -> void:
	var n := poligono.size() if cerrada else poligono.size() - 1
	for i in n:
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var cortes: Array[Vector2] = []   # (desde, hasta) en metros sobre el tramo
		var largo := a.distance_to(b)
		var dir := (b - a) / largo
		for hueco: Array in huecos:
			var c: Vector2 = hueco[0]
			var t := (c - a).dot(dir)
			var desde_hueco := maxf(t - hueco[1] / 2.0, 0.0)
			var hasta_hueco := minf(t + hueco[1] / 2.0, largo)
			if absf((c - a).cross(dir)) < 1.0 and desde_hueco < hasta_hueco:
				cortes.append(Vector2(desde_hueco, hasta_hueco))
		cortes.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var desde := -GRUESO / 2.0   # cada tramo se pasa medio grueso para cerrar las esquinas
		for corte in cortes:
			if corte.x > desde:
				_pared(a + dir * desde, a + dir * corte.x)
			desde = corte.y
		_pared(a + dir * desde, a + dir * (largo + GRUESO / 2.0))


func _pared(a: Vector2, b: Vector2) -> void:
	var largo := a.distance_to(b)
	if largo < 0.05:
		return
	var dir := (b - a) / largo
	var centro := (a + b) / 2.0
	var nodo := Node3D.new()
	nodo.position = Vector3(centro.x, 0.0, centro.y)
	nodo.rotation.y = atan2(dir.x, dir.y)
	add_child(nodo)
	# Del piso (y 0) hacia arriba; baja 1 m bajo el piso por si el terreno sube
	_cuerpo(nodo, Vector3(0.0, alto / 2.0 - 0.5, 0.0), Vector3(GRUESO, alto + 1.0, largo), _material_muro)
	# Encima del block, la lamina hasta alto_muralla (con su choque: no se brinca), mas delgada
	var sube := alto_muralla - alto
	if sube > 0.0:
		_choque(nodo, Vector3(0.0, alto + sube / 2.0, 0.0), Vector3(GRUESO, sube, largo))
		_caja(nodo, Vector3(0.06, sube, largo), Vector3(0.0, alto + sube / 2.0, 0.0), _material_lamina)


# --- Las rejas ---

func tiene_reja(lado: String) -> bool:
	return not _reja_de(lado).is_empty()


func _reja_de(lado: String) -> Dictionary:
	for reja in rejas:
		if reja["lado"] == lado:
			return reja
	return {}


# El punto a `m` metros afuera de la reja de `lado`, en el piso (la camioneta de reparto sale de ahi)
func afuera(lado: String, m: float) -> Vector3:
	var donde := _afuera(lado, m)
	return Vector3(donde.x, global_position.y, donde.y)


# Hacia donde es afuera por la reja de `lado`
func hacia_afuera(lado: String) -> Vector3:
	var dir: Vector2 = _reja_de(lado).get("afuera", Vector2.ZERO)
	return Vector3(dir.x, 0.0, dir.y)


# Punto (x, z) a `m` metros de la reja de `lado`, hacia afuera
func _afuera(lado: String, m: float) -> Vector2:
	var reja := _reja_de(lado)
	return reja["centro"] + reja["afuera"] * m


# Reja de fierro a lo largo de su rumbo: postes de concreto, travesanos y barrotes. Cerrada (las dos hojas
# juntas al centro, con el poste de en medio; con alto_muralla, el porton de lamina de los fieles detras de
# los barrotes y su dintel) o abierta (cada hoja girada 90 grados sobre su poste, hacia afuera, y el hueco
# libre). Las dos chocan de lado a lado (en map_test no se entra caminando: se entra por la flecha)
func _reja(reja: Dictionary) -> void:
	var centro: Vector2 = reja["centro"]
	var dir: Vector2 = reja["rumbo"]
	var largo: float = reja["largo"]
	var abierta: bool = reja["abierta"]
	# El +X local del nodo de la reja en el mundo (x, z): hacia ahi, o al reves, se abren las hojas
	var sx := signf((reja["afuera"] as Vector2).dot(Vector2(dir.y, -dir.x)))
	var postes := Node3D.new()
	postes.name = "Reja_" + reja["lado"]
	postes.position = Vector3(centro.x, 0.0, centro.y)
	postes.rotation.y = atan2(dir.x, dir.y)
	add_child(postes)
	for z in [-largo / 2.0 + 0.3, largo / 2.0 - 0.3]:
		_caja(postes, Vector3(GRUESO + 0.1, alto + 0.3, 0.6), Vector3(0.0, (alto + 0.3) / 2.0, z), _material_muro)
	var nodo := Node3D.new()
	nodo.name = "Hojas"
	postes.add_child(nodo)
	if not abierta:
		_caja(nodo, Vector3(GRUESO + 0.1, alto + 0.3, 0.6), Vector3(0.0, (alto + 0.3) / 2.0, 0.0), _material_muro)
	for hoja in [-1.0, 1.0]:
		var z0: float = -largo / 2.0 + 0.6 if hoja < 0.0 else 0.3
		var z1: float = -0.3 if hoja < 0.0 else largo / 2.0 - 0.6
		var ancho_hoja := z1 - z0
		var raiz := Node3D.new()
		nodo.add_child(raiz)
		if abierta:
			# La bisagra en el poste de su orilla; la hoja girada hacia afuera
			raiz.position = Vector3(0.0, 0.0, z0 if hoja < 0.0 else z1)
			raiz.rotation.y = (sx if hoja < 0.0 else -sx) * PI / 2.0
			z0 = 0.0 if hoja < 0.0 else -ancho_hoja
			z1 = z0 + ancho_hoja
			_choque(raiz, Vector3(0.0, alto / 2.0 - 0.5, (z0 + z1) / 2.0), Vector3(0.12, alto + 1.0, ancho_hoja))
		for y in [0.25, alto - 0.35, alto * 0.5]:
			_caja(raiz, Vector3(0.07, 0.07, ancho_hoja), Vector3(0.0, y, (z0 + z1) / 2.0), _material_fierro)
		var zs: Array[float] = []
		var cuantos := maxi(2, int(ancho_hoja / 0.2))
		for i in cuantos + 1:
			zs.append(z0 + ancho_hoja * i / cuantos)
		var barrote := BoxMesh.new()
		barrote.size = Vector3(0.035, alto - 0.1, 0.035)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = barrote
		multi.instance_count = zs.size()
		for i in zs.size():
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.0, alto / 2.0 - 0.05, zs[i])))
		var barrotes := MultiMeshInstance3D.new()
		barrotes.multimesh = multi
		barrotes.material_override = _material_fierro
		raiz.add_child(barrotes)
	var alto_choque := alto
	if not abierta and alto_muralla > alto:
		# El porton de los fieles: lamina detras de los barrotes, los postes alargados y el dintel
		# (como piezas.reja del mapa de Blender)
		alto_choque = alto_muralla
		_caja(nodo, Vector3(0.06, alto_muralla, largo - 1.2), Vector3(0.0, alto_muralla / 2.0, 0.0), _material_lamina)
		for z in [-largo / 2.0 + 0.3, 0.0, largo / 2.0 - 0.3]:
			_caja(nodo, Vector3(GRUESO + 0.1, alto_muralla - alto, 0.6), Vector3(0.0, (alto + alto_muralla) / 2.0 + 0.3, z), _material_muro)
		_caja(nodo, Vector3(GRUESO + 0.2, 0.5, largo), Vector3(0.0, alto_muralla + 0.35, 0.0), _material_muro)
	_choque(nodo, Vector3(0.0, alto_choque / 2.0 - 0.5, 0.0), Vector3(GRUESO + 0.1, alto_choque + 1.0, largo))


# La flecha amarilla por fuera de la reja: pisarla entra a la colonia de Blender por esa reja
func _flecha_de_entrada(lado: String) -> void:
	var donde := _afuera(lado, FLECHA_FUERA)
	var area := Area3D.new()
	area.name = "Entrada_" + lado
	area.position = Vector3(donde.x, 0.0, donde.y)
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	area.add_child(forma)
	area.add_child(MapPuntos.flecha())
	var letrero := Label3D.new()
	letrero.text = _datos.get("entrar", "Entrar a " + nombre)
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.position = Vector3(0.0, 2.6, 0.0)
	letrero.visibility_range_end = 25.0
	area.add_child(letrero)
	area.body_entered.connect(func(cuerpo: Node3D) -> void:
		if cuerpo is Player:
			PasoColonia.ir_a(self, PasoColonia.MAPA_COLONIA, lado, -2.0, colonia))
	add_child(area)


# --- La caseta (Los Reservorios) ---

# La caseta de vigilancia a un lado del hueco, por fuera, y la pluma cerrada atravesada
func _caseta(donde: Vector2, hueco: float) -> void:
	# El tramo de la barda donde cae el hueco
	var largo := Vector2.UP
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var dir := (b - a).normalized()
		var t := (donde - a).dot(dir)
		if absf((donde - a).cross(dir)) < 1.0 and t >= 0.0 and t <= a.distance_to(b):
			largo = dir
			break
	var afuera := Vector2(-largo.y, largo.x)
	if afuera.dot(_centro() - donde) > 0.0:
		afuera = -afuera
	var nodo := Node3D.new()
	nodo.name = "Caseta"
	nodo.position = Vector3(donde.x, 0.0, donde.y)
	nodo.rotation.y = atan2(largo.x, largo.y)
	add_child(nodo)
	# En local, +Z corre a lo largo de la barda y +X hacia afuera (o al reves: se voltea con `lado`)
	var lado := signf(Vector2(largo.y, -largo.x).dot(afuera))
	var cuarto := Vector3(lado * 2.2, 0.0, hueco / 2.0 + 1.6)
	_cuerpo(nodo, cuarto + Vector3(0.0, 1.3, 0.0), Vector3(2.6, 2.6, 2.4), _material_muro)
	_cuerpo(nodo, cuarto + Vector3(0.0, 2.75, 0.0), Vector3(3.2, 0.2, 3.0), _material(Color(0.2, 0.35, 0.65)))
	# La pluma: brazo a rayas rojas y blancas a 1 m, de poste a poste; el choque cierra todo el hueco
	_caja(nodo, Vector3(0.3, 1.2, 0.3), Vector3(0.0, 0.6, hueco / 2.0 - 0.2), _material_fierro)
	var tramos := 7
	for i in tramos:
		var z := hueco / 2.0 - 0.4 - (hueco - 0.6) * (i + 0.5) / tramos
		var color := Color(0.8, 0.12, 0.1) if i % 2 == 0 else Color(0.92, 0.92, 0.9)
		_caja(nodo, Vector3(0.1, 0.1, (hueco - 0.6) / tramos), Vector3(0.0, 1.0, z), _material(color))
	_choque(nodo, Vector3(0.0, 1.0, 0.0), Vector3(GRUESO, 3.0, hueco))


# --- La boca de las cañerías (la entrada de los tuneles del arroyo) ---

# La escalera que baja a las cañerías, en el hueco de la barda y hacia adentro del arroyo: muros de
# ladrillo viejo a los lados y al frente, a la altura de la barda, (con el paso de ABERTURA donde esta la flecha EntradaJefe), los
# peldaños de concreto, un barandal oxidado a cada lado, el rellano, una losa de techo y, al fondo, el muro con el arco del
# colector y detras los primeros TunelesNivel.BOCA_LARGO m del mismo tunel de tuneles.tscn (TunelesNivel
# con `boca`: pasillos, canal, boveda y la reja con el hueco forzado). Lo de abajo no se pisa: la flecha te
# mete antes: solo se pasa por el paso, que la flecha tapa (el suelo del mapa sigue chocando encima, solo
# deja de verse)
func _boca(centro: Vector2, rumbo: Vector2, _ancho: float) -> void:
	var adentro := Vector2(-rumbo.y, rumbo.x)
	if adentro.dot(_centro() - centro) < 0.0:
		adentro = -adentro
	var nodo := Node3D.new()
	nodo.name = "Boca"
	nodo.position = Vector3(centro.x, 0.0, centro.y)
	nodo.rotation.y = atan2(adentro.x, adentro.y)   # su +Z hacia adentro, su X a lo largo de la barda
	add_child(nodo)
	var medio := TunelesNivel.ANCHO / 2.0
	var PRETIL := alto   # los muros del pozo salen del suelo lo mismo que la barda: no se brincan
	var peldanos := roundi(BAJADA / PELDANO.y)
	var arco_z := PELDANO.x + peldanos * PELDANO.x + DESCANSO   # la cara del muro del arco
	var fondo := -BAJADA - 0.5
	# El tramo de tunel: su -Z hacia adentro (media vuelta), su boca en la cara del muro del arco
	var tramo := TunelesNivel.new()
	tramo.name = "Tramo"
	tramo.boca = true
	tramo.largo = TunelesNivel.BOCA_LARGO
	tramo.position = Vector3(0.0, -BAJADA, arco_z)
	tramo.rotation.y = PI
	nodo.add_child(tramo)
	var ladrillo := TunelesNivel.material_ladrillo(tramo.global_transform, false)
	# Los muros del pozo, de abajo hasta el pretil (chocan)
	var largo := arco_z + CABEZAL + PELDANO.x
	for lado in [-1.0, 1.0]:
		_cuerpo(nodo, Vector3(lado * (medio + PARED / 2.0), (fondo + PRETIL) / 2.0, largo / 2.0 - PELDANO.x),
				Vector3(PARED, PRETIL - fondo, largo), ladrillo)
	# El pretil del frente, con el paso en medio
	var tramo_pretil := medio - ABERTURA / 2.0
	for lado in [-1.0, 1.0]:
		_cuerpo(nodo, Vector3(lado * (ABERTURA / 2.0 + tramo_pretil / 2.0), PRETIL / 2.0, -PELDANO.x / 2.0),
				Vector3(tramo_pretil, PRETIL, PELDANO.x), ladrillo)
	# El muro del arco: de abajo hasta el pretil, menos el hueco del colector (CSG, choca)
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	nodo.add_child(csg)
	var muro := CSGBox3D.new()
	muro.size = Vector3(TunelesNivel.ANCHO + 2.0 * PARED, PRETIL - fondo, CABEZAL)
	muro.position = Vector3(0.0, (fondo + PRETIL) / 2.0, arco_z + CABEZAL / 2.0)
	muro.material = ladrillo
	csg.add_child(muro)
	var arranque := -BAJADA + TunelesNivel.MURO
	var recto := CSGBox3D.new()
	recto.size = Vector3(TunelesNivel.ANCHO, arranque - fondo + 0.01, CABEZAL + 0.2)
	recto.position = Vector3(0.0, (fondo + arranque) / 2.0, arco_z + CABEZAL / 2.0)
	recto.operation = CSGShape3D.OPERATION_SUBTRACTION
	recto.material = ladrillo   # las caras del hueco toman el material de lo que resta
	csg.add_child(recto)
	var arco := CSGCylinder3D.new()
	arco.radius = TunelesNivel.RADIO
	arco.height = CABEZAL + 0.2
	arco.sides = TunelesNivel.SEGMENTOS * 2
	arco.smooth_faces = false
	arco.rotation.x = PI / 2.0
	arco.position = Vector3(0.0, arranque, arco_z + CABEZAL / 2.0)
	arco.operation = CSGShape3D.OPERATION_SUBTRACTION
	arco.material = ladrillo
	csg.add_child(arco)
	# Los peldaños (macizos hasta abajo), la guarnicion de arriba y el rellano, de concreto
	var concreto := StandardMaterial3D.new()
	concreto.albedo_texture = CarcamoNivel._textura_ruido(128, 0.4, 0.07, 0.04, true, 31)
	concreto.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	concreto.uv1_triplanar = true
	concreto.uv1_scale = Vector3.ONE / 2.4
	concreto.albedo_color = Color(0.7, 0.68, 0.62)
	concreto.roughness = 0.9
	_cuerpo(nodo, Vector3(0.0, -0.1, 0.0), Vector3(TunelesNivel.ANCHO, 0.2, PELDANO.x * 2.0), concreto)
	# Cada peldaño un poco distinto de sucio, con la nariz gastada mas oscura: si no, la bajada se veia lisa
	var sucio := concreto.duplicate() as StandardMaterial3D
	sucio.albedo_color = Color(0.5, 0.48, 0.43)
	var nariz := concreto.duplicate() as StandardMaterial3D
	nariz.albedo_color = Color(0.25, 0.24, 0.22)
	for i in range(1, peldanos + 1):
		var arriba := -PELDANO.y * i
		_cuerpo(nodo, Vector3(0.0, (arriba + fondo) / 2.0, PELDANO.x * (i + 0.5)),
				Vector3(TunelesNivel.ANCHO, arriba - fondo, PELDANO.x), concreto if i % 2 == 0 else sucio)
		_caja(nodo, Vector3(TunelesNivel.ANCHO - 0.02, 0.04, 0.05), Vector3(0.0, arriba - 0.015, PELDANO.x * i + 0.02), nariz)
	_cuerpo(nodo, Vector3(0.0, (-BAJADA + fondo) / 2.0, arco_z - DESCANSO / 2.0),
			Vector3(TunelesNivel.ANCHO, -BAJADA - fondo, DESCANSO), concreto)
	# El barandal oxidado de cada lado, a lo largo de la bajada (solo se ve)
	var oxido := StandardMaterial3D.new()
	oxido.albedo_color = TunelesNivel.COLOR_OXIDO
	oxido.metallic = 0.3
	oxido.roughness = 0.8
	var corrido := peldanos * PELDANO.x
	var inclinado := sqrt(corrido * corrido + BAJADA * BAJADA)
	for lado in [-1.0, 1.0]:
		var x: float = lado * (medio - 0.12)
		var tubo := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.05, 0.05, inclinado)
		tubo.mesh = caja
		tubo.material_override = oxido
		tubo.position = Vector3(x, 0.9 - BAJADA / 2.0, PELDANO.x + corrido / 2.0)
		tubo.rotation.x = atan2(BAJADA, corrido)
		nodo.add_child(tubo)
		for k in 5:
			var f := (k + 0.5) / 5.0
			_caja(nodo, Vector3(0.04, 0.9, 0.04), Vector3(x, 0.45 - BAJADA * f, PELDANO.x + corrido * f), oxido)
	# El techo: una losa de concreto sobre los muros, que sobresale un poco (choca)
	var losa := concreto.duplicate() as StandardMaterial3D
	losa.albedo_color = Color(0.55, 0.53, 0.49)
	_cuerpo(nodo, Vector3(0.0, PRETIL + 0.1, (largo - 2.0 * PELDANO.x) / 2.0),
			Vector3(TunelesNivel.ANCHO + 2.0 * PARED + 0.4, 0.2, largo + 0.4), losa)
	# El suelo del mapa no se dibuja dentro del pozo
	var eje := Vector4(centro.x, centro.y, adentro.x, adentro.y)
	RenderingServer.global_shader_parameter_set("hoyo_eje", eje)
	RenderingServer.global_shader_parameter_set("hoyo_medida", Vector4(-medio - 0.05, medio + 0.05, -0.02, arco_z + 0.05))
	_con_hoyo = true


# --- Piezas ---

func _caja(padre: Node3D, tam: Vector3, donde: Vector3, material: Material) -> void:
	var malla := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	malla.mesh = box
	malla.position = donde
	malla.material_override = material
	padre.add_child(malla)


func _choque(padre: Node3D, donde: Vector3, tam: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = donde
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	forma.shape = caja
	cuerpo.add_child(forma)
	padre.add_child(cuerpo)


# Caja que se ve y choca
func _cuerpo(padre: Node3D, donde: Vector3, tam: Vector3, material: Material) -> void:
	_choque(padre, donde, tam)
	_caja(padre, tam, donde, material)
