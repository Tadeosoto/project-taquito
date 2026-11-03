class_name EfectosPixel
extends Node3D

# Efectos de pixel art (pixelfx, MIT) como sprites que miran a la camara, encima de lo
# que ya se siente en 3D (flash blanco, congelada, sacudida, Liquido). Las hojas salen de
# tools/pixelfx/ (efectos.json y exportar.mjs) y viven en resources/fx/.
#
# Es una propuesta de AG: cada lugar tiene variantes que se cambian en el safehouse (F2-F7)
# para que el equipo escoja. Lo crea Zombis.gd y se encuentra por el grupo "efectos_pixel",
# no por la clase, porque player.gd lo cargan scripts de tools/.
#
# Corre con el tiempo del juego, asi que se detiene en la congelada de un golpe, como todo lo
# demas (lo que recomienda pixelfx), y en pausa.
#
# Tres maneras de mostrar una hoja:
# - lanzar(): una vez, en un Sprite3D de la reserva (golpes, muertes, recoger...).
# - material_bucle() / cuadro_bucle(): se repite solo con shaders/sprite_pixel.gdshader, sin
#   script por cuadro (tambos, chispas de postes, haces, marca de los cazadores, chorros del
#   tinaco). Un material compartido por hoja.
# - pantalla(): encima de toda la pantalla (rayos al amanecer, la tele que se apaga al desmayarte).
# Los efectos de la segunda ronda (EXTRAS y los que se repiten) se apagan juntos con F9 en el
# safehouse para comparar.

const GRUPO := "efectos_pixel"
const CARPETA := "res://resources/fx/"
const SHADER_BUCLE := preload("res://shaders/sprite_pixel.gdshader")
const CUANTOS := 16            # sprites en la reserva; si se acaban se reusa el mas viejo
# El personaje de pixelfx mide 38 px; como el nuestro mide unos 1.8 m, un pixel de la hoja
# mide esto a escala 1
const PIXEL := 1.8 / 38.0
const ACERCAR := 0.45          # m hacia la camara, para que el cuerpo no se coma el efecto
const CAJA := 6.0              # m: lo que puede medir un efecto que se repite, para que no lo recorte la camara
const CAPA_PANTALLA := 9       # sobre Supervivencia (8), bajo el inventario (11)
# Las que suman luz (los rayos) van abajo de Supervivencia: si no, se veian encima del negro al desmayarte
const CAPA_LUZ := 7
# Los de la segunda ronda: se apagan con extras = false
const EXTRAS := ["tablas", "pisada", "jefe", "premio", "curar"]

# Cada lugar, sus variantes (la primera es la que queda por omision, salvo PREDETERMINADA). `hoja` vacia = nada.
# `puno`: la hoja a mano limpia; `mata`: la del golpe que mata; `voltea`: la hoja ve a la
# derecha y se orienta en el mundo hacia donde va el golpe, en vez de mirar a la camara.
const LUGARES := {
	"golpe": [
		{ "nombre": "A tajo (puno: estocada)", "hoja": "golpe_machete", "puno": "golpe_puno", "escala": 0.6, "voltea": true },
		{ "nombre": "B barrida con polvo", "hoja": "golpe_barrida", "escala": 0.7, "voltea": true },
		{ "nombre": "C nada", "hoja": "" },
	],
	"impacto": [
		{ "nombre": "A chispa de agua sucia", "hoja": "impacto_chispa", "escala": 0.8, "voltea": true },
		{ "nombre": "B golpe seco", "hoja": "impacto_seco", "escala": 0.8 },
		{ "nombre": "C seco, critico al matar", "hoja": "impacto_seco", "mata": "impacto_critico", "escala": 0.8, "voltea": true },
	],
	"herido": [
		{ "nombre": "A garras", "hoja": "herido_garra", "escala": 0.8, "voltea": true },
		{ "nombre": "B chispa de sangre", "hoja": "herido_chispa", "escala": 0.8, "voltea": true },
		{ "nombre": "C nada", "hoja": "" },
	],
	"muerte": [
		{ "nombre": "A humo", "hoja": "muerte_humo", "escala": 1.0 },
		{ "nombre": "B pesos", "hoja": "muerte_monedas", "escala": 0.9 },
		{ "nombre": "C nada", "hoja": "" },
	],
	"amanecer": [
		{ "nombre": "A ceniza", "hoja": "amanecer_ceniza", "escala": 1.0 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"recoger": [
		{ "nombre": "A brillo", "hoja": "recoger_brillo", "escala": 0.6 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"tablas": [
		{ "nombre": "A astillas", "hoja": "tablas_astillas", "escala": 0.8 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"pisada": [
		{ "nombre": "A polvo", "hoja": "jefe_pisada", "escala": 1.0 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"jefe": [
		{ "nombre": "A sacudida", "hoja": "jefe_llega", "escala": 1.0 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"premio": [
		{ "nombre": "A monedas", "hoja": "premio_monedas", "escala": 0.35 },
		{ "nombre": "B nada", "hoja": "" },
	],
	"curar": [
		{ "nombre": "A flor", "hoja": "curar", "escala": 0.6 },
		{ "nombre": "B nada", "hoja": "" },
	],
}

# La variante que queda por omision cuando no es la primera: JJ escogio la barrida
const PREDETERMINADA := {"golpe": 1}

# Compartido entre escenas: lo que se escoge en el safehouse sigue al pasar al mapa (F10)
static var variantes := {}
static var extras := true
static var _hojas := {}        # nombre -> { textura, fps, cuadros, columnas, tamano, pivote, golpe_en }
static var _materiales := {}   # clave -> ShaderMaterial de sprite_pixel
static var _quad: QuadMesh

var _sprites: Array[Sprite3D] = []
var _tiempos: Array[float] = []
var _hoja_de: Array = []
var _siguiente := 0
var _capa: CanvasLayer
var _capa_luz: CanvasLayer


func _ready() -> void:
	add_to_group(GRUPO)
	_capa = CanvasLayer.new()
	_capa.layer = CAPA_PANTALLA
	add_child(_capa)
	_capa_luz = CanvasLayer.new()
	_capa_luz.layer = CAPA_LUZ
	add_child(_capa_luz)
	for i in CUANTOS:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.double_sided = true
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		s.top_level = true
		add_child(s)
		_sprites.append(s)
		_tiempos.append(-1.0)
		_hoja_de.append(null)
	set_process(false)


func variante(lugar: String) -> int:
	return variantes.get(lugar, PREDETERMINADA.get(lugar, 0))


func nombre_variante(lugar: String) -> String:
	return LUGARES[lugar][variante(lugar)]["nombre"]


# La siguiente variante de ese lugar; regresa su nombre para el panel
func cambiar(lugar: String) -> String:
	variantes[lugar] = (variante(lugar) + 1) % LUGARES[lugar].size()
	return nombre_variante(lugar)


# `pos`: el origen del efecto, en el piso bajo quien lo hace. `hacia`: a donde va el golpe
# (para orientar las hojas que ven a la derecha). `opcion`: "puno" o "mata", si la variante
# tiene otra hoja para eso
func lanzar(lugar: String, pos: Vector3, hacia := Vector3.ZERO, escala := 1.0, opcion := "") -> void:
	if not extras and lugar in EXTRAS:
		return
	var v: Dictionary = LUGARES[lugar][variante(lugar)]
	var nombre: String = v.get(opcion, v["hoja"]) if opcion != "" else v["hoja"]
	if nombre == "":
		return
	var hoja := hoja_de(nombre)
	var camara := get_viewport().get_camera_3d()
	if hoja.is_empty() or camara == null:
		return
	var i := _siguiente
	_siguiente = (_siguiente + 1) % CUANTOS
	var s := _sprites[i]
	var hacia_camara := (camara.global_position - pos).normalized()
	var lado := camara.global_basis.x
	var arriba := Vector3.UP
	var plano := Vector3(hacia.x, 0.0, hacia.z)
	var normal := camara.global_basis.z
	# El golpe visto en pantalla: hacia el fondo va hacia arriba, hacia la camara hacia abajo
	var en_pantalla := plano - normal * plano.dot(normal)
	var orientada: bool = v.get("voltea", false) and en_pantalla.length_squared() > 0.0001
	if orientada:
		# La hoja ve a la derecha: sigue de frente a la camara, pero girada en pantalla para que
		# su X vaya hacia el golpe. Sin girar, un golpe hacia el fondo se veia como barrida de
		# lado y el volteo salia casi al azar; acostada en el piso casi no se veia
		lado = en_pantalla.normalized()
		arriba = normal.cross(lado)
	var px: float = PIXEL * float(v.get("escala", 1.0)) * escala
	var tamano: Vector2 = hoja["tamano"]
	var pivote: Vector2 = hoja["pivote"]
	s.texture = hoja["textura"]
	s.hframes = hoja["columnas"]
	s.vframes = ceili(float(hoja["cuadros"]) / hoja["columnas"])
	s.frame = mini(int(hoja["golpe_en"] * hoja["fps"]), hoja["cuadros"] - 1)
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED if orientada else BaseMaterial3D.BILLBOARD_ENABLED
	s.global_basis = Basis(lado, arriba, normal) if orientada else Basis.IDENTITY
	# El sprite va centrado: se recorre para que el pivote de la hoja quede en `pos`
	var dx := (tamano.x * 0.5 - pivote.x) * px
	var dy := (pivote.y - tamano.y * 0.5) * px
	s.global_position = pos + lado * dx + arriba * dy + hacia_camara * ACERCAR
	s.visible = true
	_tiempos[i] = hoja["golpe_en"]
	_hoja_de[i] = hoja
	set_process(true)


func _process(delta: float) -> void:
	var quedan := false
	for i in CUANTOS:
		if _tiempos[i] < 0.0:
			continue
		_tiempos[i] += delta
		var hoja: Dictionary = _hoja_de[i]
		var cuadro := int(_tiempos[i] * hoja["fps"])
		if cuadro >= hoja["cuadros"]:
			_tiempos[i] = -1.0
			_sprites[i].visible = false
			continue
		_sprites[i].frame = cuadro
		quedan = true
	if not quedan:
		set_process(false)


func limpiar() -> void:
	for i in CUANTOS:
		_tiempos[i] = -1.0
		_sprites[i].visible = false
	set_process(false)


# Una hoja encima de toda la pantalla, de `desde` a `hasta` segundos de la hoja (las que se
# repiten dan vueltas). `fundido`: s de entrada y salida suaves. `recorte`: px que se le quitan
# abajo (los rayos traen su propio piso iluminado, que en pantalla se veia como una franja).
# Se espera con await. Corre con el tiempo del juego: en pausa se detiene
func pantalla(nombre: String, desde: float, hasta: float, aditivo := false, alfa := 1.0, fundido := 0.0, recorte := 0.0) -> void:
	var hoja := hoja_de(nombre)
	if hoja.is_empty():
		return
	var region := AtlasTexture.new()
	region.atlas = hoja["textura"]
	var cuadro := TextureRect.new()
	cuadro.texture = region
	cuadro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cuadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cuadro.stretch_mode = TextureRect.STRETCH_SCALE
	cuadro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if aditivo:
		var mezcla := CanvasItemMaterial.new()
		mezcla.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		cuadro.material = mezcla
	(_capa_luz if aditivo else _capa).add_child(cuadro)
	var tamano: Vector2 = hoja["tamano"]
	var dura: float = hoja["cuadros"] / hoja["fps"]
	var t := desde
	while t < hasta and is_instance_valid(cuadro):
		var i := mini(int(fmod(t, dura) * hoja["fps"]) if hoja["loop"] else int(t * hoja["fps"]), hoja["cuadros"] - 1)
		region.region = Rect2(Vector2(i % hoja["columnas"], i / hoja["columnas"]) * tamano, tamano - Vector2(0.0, recorte))
		var k := alfa
		if fundido > 0.0:
			k *= clampf(minf(t - desde, hasta - t) / fundido, 0.0, 1.0)
		cuadro.modulate.a = k
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(cuadro):
		cuadro.queue_free()


# --- Los que se repiten solos (shaders/sprite_pixel.gdshader) ---

# Un material por hoja y manera, compartido por todos los que la usan. `periodo` 0 = lo que
# dura la hoja; mas = un hueco sin nada entre vuelta y vuelta. `con_direccion`: la hoja ve a la
# derecha y cada cuadro se voltea segun su instance uniform `hacia`
static func material_bucle(nombre: String, alfa := 1.0, periodo := 0.0, con_direccion := false) -> ShaderMaterial:
	var clave := "%s|%s|%s|%s" % [nombre, alfa, periodo, con_direccion]
	if _materiales.has(clave):
		return _materiales[clave]
	var hoja := hoja_de(nombre)
	if hoja.is_empty():
		return null
	var material := ShaderMaterial.new()
	material.shader = SHADER_BUCLE
	material.set_shader_parameter("hoja", hoja["textura"])
	material.set_shader_parameter("columnas", hoja["columnas"])
	material.set_shader_parameter("filas", ceili(float(hoja["cuadros"]) / hoja["columnas"]))
	material.set_shader_parameter("cuadros", hoja["cuadros"])
	material.set_shader_parameter("fps", hoja["fps"])
	material.set_shader_parameter("periodo", maxf(periodo, hoja["cuadros"] / hoja["fps"]))
	material.set_shader_parameter("tamano", hoja["tamano"])
	material.set_shader_parameter("pivote", hoja["pivote"])
	material.set_shader_parameter("pixel", PIXEL)
	material.set_shader_parameter("con_direccion", con_direccion)
	material.set_meta("alfa", alfa)
	material.set_shader_parameter("alfa", alfa if extras else 0.0)
	_materiales[clave] = material
	return material


# La malla de todos los que se repiten: un cuadro de 1 x 1 que el shader estira y voltea
static func malla_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad


# Uno solo que se repite, para colgarlo de algo (el pivote de la hoja queda en su origen).
# `escala` multiplica el tamano a escala de personaje; cada uno arranca en otra fase
static func cuadro_bucle(nombre: String, escala := 1.0, alfa := 1.0, periodo := 0.0, con_direccion := false) -> MeshInstance3D:
	var material := material_bucle(nombre, alfa, periodo, con_direccion)
	if material == null:
		return null
	var cuadro := MeshInstance3D.new()
	cuadro.mesh = malla_quad()
	cuadro.material_override = material
	cuadro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuadro.custom_aabb = AABB(Vector3.ONE * -CAJA, Vector3.ONE * CAJA * 2.0)
	cuadro.scale = Vector3.ONE * escala
	cuadro.set_instance_shader_parameter("fase", randf() * 10.0)
	return cuadro


# F9 en el safehouse: la segunda ronda de efectos, toda prendida o toda apagada
static func poner_extras(prendidos: bool) -> void:
	extras = prendidos
	for material: ShaderMaterial in _materiales.values():
		material.set_shader_parameter("alfa", material.get_meta("alfa") if prendidos else 0.0)


static func hoja_de(nombre: String) -> Dictionary:
	if _hojas.has(nombre):
		return _hojas[nombre]
	var hoja := {}
	var texto := FileAccess.get_file_as_string(CARPETA + nombre + ".json")
	var datos = JSON.parse_string(texto) if texto != "" else null
	var textura := load(CARPETA + nombre + ".png") as Texture2D
	if datos is Dictionary and textura:
		hoja = {
			"textura": textura,
			"fps": float(datos["fps"]),
			"cuadros": int(datos["frames"]),
			"columnas": int(datos["columns"]),
			"tamano": Vector2(datos["frameSize"][0], datos["frameSize"][1]),
			"pivote": Vector2(datos["pivot"][0], datos["pivot"][1]),
			"golpe_en": float(datos.get("golpe_en", 0.0)),
			"loop": bool(datos.get("loop", false)),
		}
	else:
		push_warning("EfectosPixel: no encontre la hoja %s" % nombre)
	_hojas[nombre] = hoja
	return hoja
