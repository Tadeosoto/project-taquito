extends Node

# Quien eres (scripts/CreadorPersonaje.gd lo edita). Autoload `Personaje`. Aqui estan todos los
# numeros, para afinarlos en un solo lugar. El tono de piel cambia como te trata la gente
# (precios, paga, lo que te dicen) y nada mas: a los zombis les da igual, ese es el chiste.
# Propuesta de trabajo de AG, falta que el equipo la vote (docs/especificaciones.md 10.2).
# Se recuerda entre partidas y reiniciar la partida no lo borra.

const RUTA := "user://personaje.cfg"
const NOMBRE_MAX := 12
const NOMBRES := ["Chuy", "Lupe", "Beto", "Toño", "Memo", "Nacho", "Paco", "Güicho", "Chema", "Goyo", "Paty", "Chayo"]
const CUERPO := preload("res://scripts/CuerpoPersonaje.gd")

# Valores en [0 del deslizador, en medio, 1 del deslizador]. En medio es el juego sin cambios
const PRECIOS := [0.9, 1.0, 1.3]
const PAGA := [1.1, 1.0, 0.75]
const VIDA := [80.0, 100.0, 125.0]
const VELOCIDAD_COMPLEXION := [1.1, 1.0, 0.9]
const DANO := [0.85, 1.0, 1.2]
const VELOCIDAD_TALLA := [1.08, 1.0, 0.92]
const ALCANCE := [0.8, 1.0, 1.2]
const ESCALA_TALLA := [0.88, 1.0, 1.12]
const ANCHO := [0.75, 1.0, 1.35]
# Ya trae la cabeza grande: mas de esto tapa la vista desde la camara del juego
const ESCALA_CABEZA := [0.7, 1.0, 1.3]

const PIEL := [Color(0.96, 0.8, 0.68), Color(0.85, 0.64, 0.47), Color(0.66, 0.45, 0.29),
	Color(0.44, 0.28, 0.17), Color(0.24, 0.14, 0.09)]
const ROPA := [Color(0.13, 0.13, 0.16), Color(0.62, 0.14, 0.12), Color(0.15, 0.3, 0.6),
	Color(0.2, 0.42, 0.22), Color(0.75, 0.6, 0.2), Color(0.72, 0.72, 0.7)]
const ROPA_NOMBRES := ["Negro", "Rojo", "Azul", "Verde", "Mostaza", "Gris"]

const MATERIAL_CABEZA := "CabezaPiel"
# Los personajes del pack PSX (el protagonista, el_compa) traen la piel pintada en la textura:
# junto a ella va piel.png, blanco donde es piel (tools/personajes/el_compa.gd). Cada pixel de
# piel queda de tu color por su sombra: su brillo entre el brillo promedio de la piel pintada
const MASCARA_PIEL := "piel.png"
const RODILLA_PIEL := 215.0   # de 255: arriba de esto las luces se van suavizando en vez de quemarse
static var _pieles := {}      # ruta de la textura -> lo que hace falta para repintarla
const TONO_CLARO := 0.35
const TONO_OSCURO := 0.65
# Lo que dice la gente, por tono: claro, en medio, oscuro. %s es tu nombre; "" es que no dice
# nada de mas. El chiste son los que hablan, no el jugador: sin groserias de color.
const LINEAS := {
	"tienda": [
		["¡Pásele, güerito! ¿Qué se le ofrece, %s?", "¡%s! Para usted le busco lo mejor."],
		["¿Qué va a llevar, %s?"],
		["Mire, %s, primero me enseña el dinero, ¿eh?", "Las manos donde las vea, %s. Es que es por seguridad, no es por usted."],
	],
	"vecino": [
		["¡Qué gusto, %s!"],
		[""],
		["A ver, %s... ¿usted sí es de por aquí?"],
	],
	"paga": [
		["Y un extrita, por ser usted."],
		[""],
		["Es lo que hay, no es personal."],
	],
	"calle": [
		["Buenas, joven %s. ¡Qué milagro por aquí!", "Se ve que usted es de buena familia."],
		[""],
		["Ya vi mi cartera, ¿eh?", "Aquí no damos limosna, joven."],
	],
}

var nombre := ""
var tono := 0.5
var complexion := 0.5
var talla := 0.5
var cabeza := 0.5
var ropa := 0
# Otra ruta en las pruebas, para no pisar el personaje de quien juega
var ruta := RUTA

var _malla_sin_capucha: ArrayMesh
var _malla_con_capucha: Mesh


func _ready() -> void:
	cargar()


func cargar() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(ruta) != OK:
		nombre = NOMBRES.pick_random()
		return
	nombre = limpiar_nombre(str(archivo.get_value("personaje", "nombre", "")))
	tono = clampf(float(archivo.get_value("personaje", "tono", 0.5)), 0.0, 1.0)
	complexion = clampf(float(archivo.get_value("personaje", "complexion", 0.5)), 0.0, 1.0)
	talla = clampf(float(archivo.get_value("personaje", "talla", 0.5)), 0.0, 1.0)
	cabeza = clampf(float(archivo.get_value("personaje", "cabeza", 0.5)), 0.0, 1.0)
	ropa = clampi(int(archivo.get_value("personaje", "ropa", 0)), 0, ROPA.size() - 1)


func guardar() -> void:
	nombre = limpiar_nombre(nombre)
	var archivo := ConfigFile.new()
	archivo.set_value("personaje", "nombre", nombre)
	archivo.set_value("personaje", "tono", tono)
	archivo.set_value("personaje", "complexion", complexion)
	archivo.set_value("personaje", "talla", talla)
	archivo.set_value("personaje", "cabeza", cabeza)
	archivo.set_value("personaje", "ropa", ropa)
	archivo.save(ruta)


# Sin nombre te toca uno
func limpiar_nombre(texto: String) -> String:
	var limpio := texto.strip_edges().left(NOMBRE_MAX)
	return limpio if limpio != "" else NOMBRES.pick_random()


func al_azar() -> void:
	nombre = NOMBRES.pick_random()
	tono = randf()
	complexion = randf()
	talla = randf()
	cabeza = randf()
	ropa = randi() % ROPA.size()


# --- Lo que cambia ---

static func _en(valores: Array, t: float) -> float:
	if t < 0.5:
		return lerpf(valores[0], valores[1], t * 2.0)
	return lerpf(valores[1], valores[2], (t - 0.5) * 2.0)


func factor_precio() -> float:
	return _en(PRECIOS, tono)


func factor_paga() -> float:
	return _en(PAGA, tono)


func vida_max() -> int:
	return roundi(_en(VIDA, complexion))


func factor_velocidad() -> float:
	return _en(VELOCIDAD_COMPLEXION, complexion) * _en(VELOCIDAD_TALLA, talla)


func factor_dano() -> float:
	return _en(DANO, complexion)


func factor_alcance() -> float:
	return _en(ALCANCE, talla)


func color_piel() -> Color:
	var lugar := tono * (PIEL.size() - 1)
	var i := mini(int(lugar), PIEL.size() - 2)
	return (PIEL[i] as Color).lerp(PIEL[i + 1], lugar - i)


# Lo que se ve de tu cuerpo en el creador. La piel no sale aqui: eso lo descubres jugando
func resumen_cuerpo() -> String:
	return "Vida %d · Velocidad %s · Golpe %s · Alcance %s" % [vida_max(),
		_por_ciento(factor_velocidad()), _por_ciento(factor_dano()), _por_ciento(factor_alcance())]


static func _por_ciento(factor: float) -> String:
	var cambio := roundi((factor - 1.0) * 100.0)
	return "%+d %%" % cambio if cambio != 0 else "="


# Lo que te dice la gente en `lugar` (LINEAS); "" si no dice nada
func linea(lugar: String) -> String:
	var banda := 0 if tono < TONO_CLARO else (2 if tono > TONO_OSCURO else 1)
	var texto: String = (LINEAS[lugar][banda] as Array).pick_random()
	return texto % nombre if texto.contains("%s") else texto


# --- Como se ve ---

# La capucha del ninja es del mismo material que su ropa y le tapa toda la cara, y sin cara no
# se ve de que color eres. Lo que se mueve con el hueso de la cabeza pasa a ser una superficie
# aparte, pintada de piel. La malla nueva se comparte; la del modelo original no se toca
func _descubrir_cabeza(malla: MeshInstance3D) -> void:
	if malla.has_meta("cabeza_descubierta"):
		return
	malla.set_meta("cabeza_descubierta", true)
	if _malla_sin_capucha == null:
		_malla_sin_capucha = _partir_capucha(malla)
		if _malla_sin_capucha:
			_malla_con_capucha = malla.mesh
	# Solo el cuerpo del ninja: el arma en la mano tambien esta adentro del modelo, y se volvia
	# un cuerpo diminuto color piel
	if _malla_sin_capucha and malla.mesh == _malla_con_capucha:
		malla.mesh = _malla_sin_capucha


func _partir_capucha(malla: MeshInstance3D) -> ArrayMesh:
	if malla.skin == null:
		return null
	var hueso_cabeza := -1
	for b in malla.skin.get_bind_count():
		if malla.skin.get_bind_name(b) == "Head":
			hueso_cabeza = b
	if hueso_cabeza < 0:
		return null
	var fuente := malla.mesh as ArrayMesh
	if fuente == null:
		return null
	var nueva := ArrayMesh.new()
	var capucha := []
	var capucha_material: BaseMaterial3D = null
	var capucha_banderas := 0
	for s in fuente.get_surface_count():
		var arreglos := fuente.surface_get_arrays(s)
		var banderas := fuente.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var material := fuente.surface_get_material(s)
		if material and material.resource_name == "Main":
			capucha = arreglos.duplicate()
			var ropa_indices := PackedInt32Array()
			var capucha_indices := PackedInt32Array()
			var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]
			var por_vertice: int = 8 if banderas != 0 else 4
			for t in range(0, indices.size(), 3):
				var de_cabeza := true
				for v in 3:
					de_cabeza = de_cabeza and _hueso_principal(arreglos, indices[t + v], por_vertice) == hueso_cabeza
				var destino := capucha_indices if de_cabeza else ropa_indices
				destino.append(indices[t])
				destino.append(indices[t + 1])
				destino.append(indices[t + 2])
			arreglos[Mesh.ARRAY_INDEX] = ropa_indices
			capucha[Mesh.ARRAY_INDEX] = capucha_indices
			capucha_material = material.duplicate() as BaseMaterial3D
			capucha_material.resource_name = MATERIAL_CABEZA
			capucha_banderas = banderas
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos, [], {}, banderas)
		nueva.surface_set_material(nueva.get_surface_count() - 1, material)
	if capucha_material == null or (capucha[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
		return null
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, capucha, [], {}, capucha_banderas)
	nueva.surface_set_material(nueva.get_surface_count() - 1, capucha_material)
	return nueva


static func _hueso_principal(arreglos: Array, vertice: int, por_vertice: int) -> int:
	var huesos: PackedInt32Array = arreglos[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arreglos[Mesh.ARRAY_WEIGHTS]
	var mejor := 0
	for i in range(1, por_vertice):
		if pesos[vertice * por_vertice + i] > pesos[vertice * por_vertice + mejor]:
			mejor = i
	return huesos[vertice * por_vertice + mejor]


# El modelo con tu piel, tu ropa y tu cuerpo: el ninja (materiales Skin y Main) o un personaje
# del pack PSX (textura con piel.png al lado; la ropa de esos queda para despues). Se puede
# llamar muchas veces. Materiales propios: los vecinos usan los mismos del modelo y no deben cambiar
func vestir(modelo: Node3D) -> void:
	for malla: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if malla.mesh == null:
			continue
		_descubrir_cabeza(malla)
		for i in malla.mesh.get_surface_count():
			var material := malla.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			if _pintar_piel(malla, i, material):
				continue
			var color: Variant = null
			if material.resource_name == "Skin" or material.resource_name == MATERIAL_CABEZA:
				color = color_piel()
			elif material.resource_name == "Main":
				color = ROPA[ropa]
			if color == null:
				continue
			if malla.get_surface_override_material(i) == null:
				material = material.duplicate() as BaseMaterial3D
				malla.set_surface_override_material(i, material)
			material.albedo_color = color
	if not modelo.has_meta("base_personaje"):
		modelo.set_meta("base_personaje", modelo.basis)
	modelo.basis = (modelo.get_meta("base_personaje") as Basis).scaled(Vector3.ONE * _en(ESCALA_TALLA, talla))
	# Con el retarget el esqueleto se llama GeneralSkeleton
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	var esqueleto := esqueletos[0] as Skeleton3D
	var cuerpo := esqueleto.get_node_or_null("CuerpoPersonaje")
	if cuerpo == null:
		cuerpo = CUERPO.new()
		cuerpo.name = "CuerpoPersonaje"
		esqueleto.add_child(cuerpo)
	cuerpo.set("ancho", _en(ANCHO, complexion))
	cuerpo.set("cabeza", _en(ESCALA_CABEZA, cabeza))


# La textura con la piel de tu tono, si el material tiene piel.png junto a su textura. Se guarda
# la original en el material para repintar desde ella cada vez
func _pintar_piel(malla: MeshInstance3D, superficie: int, material: BaseMaterial3D) -> bool:
	var original: Texture2D = material.get_meta("textura_piel", material.albedo_texture)
	if original == null or original.resource_path == "":
		return false
	var ruta := original.resource_path
	if not _pieles.has(ruta):
		var mascara_ruta := ruta.get_base_dir().path_join(MASCARA_PIEL)
		if not ResourceLoader.exists(mascara_ruta):
			_pieles[ruta] = null
		else:
			_pieles[ruta] = _preparar_piel(original, load(mascara_ruta) as Texture2D)
	var piel: Dictionary = _pieles[ruta] if _pieles[ruta] != null else {}
	if piel.is_empty():
		return false
	var tono := color_piel()
	if piel["tono"] != tono:
		piel["tono"] = tono
		_repintar(piel, tono)
	if malla.get_surface_override_material(superficie) == null:
		material = material.duplicate() as BaseMaterial3D
		material.set_meta("textura_piel", original)
		malla.set_surface_override_material(superficie, material)
	material.albedo_texture = piel["textura"]
	return true


# Los pixeles de piel y cuanto (la mascara puede tener orillas grises), una vez por textura
static func _preparar_piel(original: Texture2D, mascara_textura: Texture2D) -> Dictionary:
	var imagen := original.get_image()
	if imagen.is_compressed():
		imagen.decompress()
	imagen.convert(Image.FORMAT_RGBA8)
	var mascara := mascara_textura.get_image()
	if mascara.is_compressed():
		mascara.decompress()
	mascara.convert(Image.FORMAT_L8)
	mascara.resize(imagen.get_width(), imagen.get_height(), Image.INTERPOLATE_NEAREST)
	var valores := mascara.get_data()
	var datos := imagen.get_data()
	var donde := PackedInt32Array()
	var cuanto := PackedFloat32Array()
	var suma := 0.0
	var peso := 0.0
	for p in valores.size():
		if valores[p] > 0:
			donde.append(p)
			cuanto.append(valores[p] / 255.0)
			suma += (datos[p * 4] + datos[p * 4 + 1] + datos[p * 4 + 2]) * cuanto[-1]
			peso += cuanto[-1]
	return {"datos": datos, "ancho": imagen.get_width(), "alto": imagen.get_height(), "media": suma / maxf(peso, 1.0),
		"donde": donde, "cuanto": cuanto, "tono": Color(-1, -1, -1), "textura": ImageTexture.create_from_image(imagen)}


static func _repintar(piel: Dictionary, tono: Color) -> void:
	var datos: PackedByteArray = (piel["datos"] as PackedByteArray).duplicate()
	var color := Vector3(tono.r, tono.g, tono.b) * 255.0
	var media: float = piel["media"]
	var donde: PackedInt32Array = piel["donde"]
	var cuanto: PackedFloat32Array = piel["cuanto"]
	for k in donde.size():
		var b := donde[k] * 4
		var m := cuanto[k]
		var sombra := (datos[b] + datos[b + 1] + datos[b + 2]) / media
		for c in 3:
			var antes := datos[b + c]
			var nuevo := color[c] * sombra
			if nuevo > RODILLA_PIEL:
				nuevo = RODILLA_PIEL + (nuevo - RODILLA_PIEL) * 0.35
			datos[b + c] = clampi(roundi(lerpf(antes, nuevo, m)), 0, 255)
	var imagen := Image.create_from_data(piel["ancho"], piel["alto"], false, Image.FORMAT_RGBA8, datos)
	(piel["textura"] as ImageTexture).update(imagen)
