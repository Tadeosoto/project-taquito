extends SceneTree
# Repinta la textura de hombre_04 (pack PSX) para el primer protagonista:
# camisa mostaza con hojas abierta al pecho, cadena con cruz, pantalón negro,
# cinturón con hebilla dorada, botas beige, piel morena, pelo negro con canas
# y bigote. Lee Character_04_original.png y escribe Character_04.png (el
# nombre que busca el FBX). Las islas son las de tools/personajes/islas.gd
# (islas.png en la carpeta para verlas con su número).
# Tambien escribe piel.png, la mascara de la piel para el tono (Personaje.vestir).
#   godot --path . --headless -s tools/personajes/el_compa.gd
#   godot --path . --headless --import
# Con -- --homero pinta el segundo protagonista (homenaje de JJ a Homero Gomez, el defensor de la
# mariposa monarca): el mismo modelo con guayabera blanca cerrada de manga larga, por fuera del
# pantalon, con alforzas, cuatro bolsillos y botones, pantalon negro y zapatos negros. Va a
# protagonistas/homero/ (Character_04.png y piel.png); Personaje.vestir cambia la textura.
#   godot --path . --headless -s tools/personajes/el_compa.gd -- --homero
# Con -- --ramon pinta el tercero (Ramon): playera negra de manga corta, pantalon de mezclilla azul y
# tenis oscuros, sin bigote ni canas. Va a protagonistas/ramon/; el gorro de pescador azul no
# es textura: es una malla aparte en el hueso de la cabeza (scripts/personajes/GorroPescador.gd).
#   godot --path . --headless -s tools/personajes/el_compa.gd -- --ramon
# Con -- --emiliano pinta el cuarto (Emiliano, homenaje a Zapata): saco cafe de manga larga con
# punos de camisa, chaleco verde olivo con botones y leontina dorada, camisa blanca, paliacate rojo
# al cuello, pantalon gris oscuro con cinturon y hebilla, zapatos negros y bigote grande. Va a
# protagonistas/emiliano/; el sombrero charro es malla aparte (scripts/personajes/SombreroCharro.gd).
#   godot --path . --headless -s tools/personajes/el_compa.gd -- --emiliano

const CARPETA := "res://models/personajes/protagonistas/el_compa/"
const CARPETA_HOMERO := "res://models/personajes/protagonistas/homero/"
const CARPETA_RAMON := "res://models/personajes/protagonistas/ramon/"
const CARPETA_EMILIANO := "res://models/personajes/protagonistas/emiliano/"
const SEMILLA := 7

# --- Colores ---
const MOSTAZA := Color(0.74, 0.52, 0.17)
const HOJA := Color(0.30, 0.17, 0.06)
const HOJA_VENA := Color(0.55, 0.36, 0.12)
const PIEL := Color(0.50, 0.33, 0.24)
const PELO := Color(0.07, 0.06, 0.06)
const CANA := Color(0.42, 0.41, 0.40)
const NEGRO := Color(0.075, 0.075, 0.085)
const CINTO := Color(0.06, 0.045, 0.035)
const ORO := Color(0.86, 0.68, 0.26)
const ORO_OSCURO := Color(0.50, 0.36, 0.10)
const BOTA := Color(0.80, 0.67, 0.46)
const SUELA := Color(0.30, 0.21, 0.13)

# --- Islas (números de islas.png) ---
const CHAMARRA := [3, 8, 14, 15]
const ANTEBRAZOS := [5, 30]                  # manga corta: los antebrazos son piel
const PECHO_ISLA := 15
const CABEZA := [1, 9, 10, 27, 28, 29, 31]   # piel y pelo se separan por color
const SOLO_PELO := [27, 31]                   # canas solo aquí: en 10/28 lo oscuro también son ojos y cejas
const MANOS := [4, 13, 17, 20]
const PANTALON := [11, 16, 18, 19, 21, 22]
const HEBILLA_ISLA := 21
const ZAPATOS := [0, 2, 6, 7, 12, 23, 25, 26]
const SUELAS := [24, 32]

# --- Pecho abierto: la playera interior es una franja horizontal en la isla 15
# (x 204-325, centro y 203.5); el cuello está del lado de x grande. Se pinta
# de piel y se abre en V hacia el cuello.
const PECHO_CENTRO_Y := 203.5
const PECHO_X := Vector2(200, 334)      # de la cintura al cuello
const PECHO_ANCHO := Vector2(5.0, 15.0) # medio ancho en la cintura y en el cuello
# Cadena: de los lados del cuello a un punto del pecho, con cruz colgando.
# El cuello de la playera original: un triángulo de piel junto a la franja.
const CUELLO := Rect2(322, 189, 32, 34)
const CADENA_ARRIBA_X := 326.0
const CADENA_ABAJO_X := 270.0
const CRUZ := Rect2(257, 202.5, 12, 2.2)       # palo largo (hacia la cintura = -x)
const CRUZ_BRAZO := Rect2(263.5, 199.5, 2, 8)

# --- Hebilla: frente del pantalón, isla 21, alrededor del botón original.
const HEBILLA := Rect2i(4, 389, 22, 22)

# --- Bigote: caja en el espacio del modelo (X al frente, Y arriba, Z a los
# lados, cara centrada en z = 0). Cada píxel de piel de la cabeza se ubica en
# 3D con las UV de la malla, así sale recto y parejo aunque las dos mitades de
# la cara estén giradas distinto en la textura. Nariz ~4.23, boca ~4.12.
const BIGOTE_Y := Vector2(4.152, 4.188)   # de abajo a arriba
const BIGOTE_MEDIO := 0.08                # medio ancho (z)
const BIGOTE_FRENTE := 0.03               # x mínima: solo la cara de enfrente

const CANAS_PELO := 0.06
const CANAS_BIGOTE := 0.025
const VETA := 0.55        # cuánto de la sombra original queda en la camisa (la veta de la chamarra se notaba)

var img: Image
var etiqueta: PackedInt32Array
var w: int
var h: int
var rng := RandomNumberGenerator.new()
var posiciones := {}   # Vector2i (píxel) -> Vector3 (punto de la malla en reposo)
var homero := false
var ramon := false
var emiliano := false

# --- Emiliano: como la guayabera, en el espacio del modelo (X al frente, Y arriba, Z a los lados) ---
const SACO := Color(0.30, 0.20, 0.13)
const CHALECO := Color(0.29, 0.30, 0.18)
const CAMISA := Color(0.90, 0.89, 0.84)
const PALIACATE := Color(0.64, 0.07, 0.07)
const PANTALON_GRIS := Color(0.10, 0.10, 0.11)
const TWEED := 0.07                 # variacion por pixel de la lana
const CHALECO_ANCHO := 0.20         # |z| hasta donde se ve el chaleco (lo demas es el saco abierto)
const CHALECO_DESDE := 2.50         # y de abajo del chaleco
const CAMISA_V := 3.45              # y donde abre la V del chaleco (camisa adentro)
const PALIACATE_NUDO := 3.80        # y del nudo; la punta cuelga hasta PALIACATE_PUNTA
const PALIACATE_PUNTA := 3.55
const BOTONES_CHALECO := [2.62, 2.80, 2.98, 3.16, 3.34]
const LEONTINA_Y := 3.0             # y de los extremos de la cadena del reloj
const SACO_HASTA := 2.28            # y del dobladillo del saco sobre el pantalon
const BIGOTE_GRANDE := Vector3(4.135, 4.198, 0.115)   # y de abajo, y de arriba, medio ancho

# --- Ramon ---
const PLAYERA := Color(0.075, 0.075, 0.08)
const MEZCLILLA := Color(0.17, 0.29, 0.52)
const MEZCLILLA_GRANO := 0.07      # variacion por pixel del tejido
const TENIS := Color(0.16, 0.16, 0.18)
const TENIS_SUELA := Color(0.85, 0.84, 0.80)

# --- Homero: la guayabera se dibuja en el espacio del modelo (como el bigote), asi las alforzas
# salen derechas aunque las islas esten giradas. X al frente, Y arriba, Z a los lados. El torso va
# de la cintura (y 2.62) al cuello (3.98); la guayabera baja a la cadera (GUAYABERA_HASTA), sobre
# el pantalon. Un pixel de la textura son ~0.011 de modelo en el pecho
const GUAYABERA := Color(0.93, 0.92, 0.88)       # blanco hueso: el blanco puro se quemaba
const GUAYABERA_LINEA := 0.78                    # la sombra de alforzas y costuras
const BOTON := Color(0.80, 0.79, 0.74)
const ZAPATO := Color(0.07, 0.06, 0.055)
const GUAYABERA_HASTA := 2.40                    # y del dobladillo
const LINEA := 0.007                             # medio grueso de una linea
const ALFORZAS_FRENTE := [0.105, 0.135, 0.33, 0.36]   # |z| de las alforzas de enfrente
const ALFORZAS_ATRAS := [0.0, 0.03, 0.2, 0.23]          # |z| de las de atras
const BOTONES_Y := [2.55, 2.78, 3.01, 3.24, 3.47, 3.70, 3.90]
const BOLSAS := [Rect2(0.15, 3.33, 0.15, 0.2), Rect2(0.15, 2.66, 0.17, 0.22)]  # z, y, ancho, alto (de un lado)
const PUNO_Y := 2.42                             # la costura del puno de la manga


func _init() -> void:
	homero = "--homero" in OS.get_cmdline_user_args()
	ramon = "--ramon" in OS.get_cmdline_user_args()
	emiliano = "--emiliano" in OS.get_cmdline_user_args()
	rng.seed = SEMILLA
	img = Image.load_from_file(ProjectSettings.globalize_path(CARPETA + "Character_04_original.png"))
	img.convert(Image.FORMAT_RGBA8)
	w = img.get_width()
	h = img.get_height()
	etiqueta = load("res://tools/personajes/islas.gd").etiquetar(img).etiqueta
	var orig := img.duplicate() as Image
	posiciones = _posiciones()
	var hojas := _hojas()
	# Donde quedo piel: Personaje.vestir la vuelve a pintar con el tono que escojas
	var mascara := Image.create(w, h, false, Image.FORMAT_L8)

	# Promedio de luz por isla (y por piel/pelo en la cabeza) para conservar
	# la sombra original sin importar qué tan claro era el color de antes.
	var prom := {}
	for y in h:
		for x in w:
			var e := etiqueta[y * w + x]
			if e < 0: continue
			var k := _clave(e, orig.get_pixel(x, y))
			if not prom.has(k): prom[k] = Vector2.ZERO
			prom[k] += Vector2(_luz(orig.get_pixel(x, y)), 1)

	for y in h:
		for x in w:
			var e := etiqueta[y * w + x]
			if e < 0: continue
			var c := orig.get_pixel(x, y)
			var k := _clave(e, c)
			var f := clampf(_luz(c) / (prom[k].x / prom[k].y), 0.45, 1.6)
			var p := Vector2(x + 0.5, y + 0.5)
			var nuevo := c
			var es_piel := false
			var q: Variant = posiciones.get(Vector2i(x, y))
			if homero and q != null and (e in CHAMARRA or e in ANTEBRAZOS or (e in PANTALON and q.y > GUAYABERA_HASTA)):
				nuevo = _guayabera(e, q, f)
			elif homero and (e in CHAMARRA or e in ANTEBRAZOS):
				# Las orillas de la isla que no tocan la malla (no tienen punto 3D): se quedaban mostaza
				nuevo = GUAYABERA * 0.9
			elif homero and e in PANTALON:
				nuevo = NEGRO * clampf(f, 0.6, 1.9)
			elif homero and (e in ZAPATOS or e in SUELAS):
				nuevo = ZAPATO * lerpf(1.0, f, 0.45)
			elif emiliano and q != null and (e in CHAMARRA or e in ANTEBRAZOS):
				nuevo = _traje(e, q, f)
			elif emiliano and (e in CHAMARRA or e in ANTEBRAZOS):
				nuevo = SACO * 0.85
			elif emiliano and e in PANTALON and q != null and q.y > SACO_HASTA and q.y < 2.62 \
					and not (q.x > -0.06 and absf(q.z) < CHALECO_ANCHO):
				# Los faldones del saco, abierto de enfrente
				nuevo = _lana(SACO) * clampf(lerpf(1.0, f, 0.35), 0.75, 1.15) * (0.75 if q.y < SACO_HASTA + 0.02 else 1.0)
			elif emiliano and e in PANTALON:
				var cinto := c.s > 0.15 and c.r - c.b > 0.05
				nuevo = (CINTO if cinto else PANTALON_GRIS) * clampf(f, 0.6, 1.9)
				if e == HEBILLA_ISLA and HEBILLA.has_point(Vector2i(x, y)):
					nuevo = _hebilla(x - HEBILLA.position.x, y - HEBILLA.position.y)
			elif emiliano and (e in ZAPATOS or e in SUELAS):
				nuevo = ZAPATO * lerpf(1.0, f, 0.6)
			elif ramon and e in CHAMARRA:
				# Cuello redondo: el triangulo de piel del cuello original tambien va negro (dejaba manchas)
				nuevo = PLAYERA * clampf(lerpf(1.0, f, 0.5), 0.6, 1.8)
			elif ramon and e in PANTALON:
				var cinto := c.s > 0.15 and c.r - c.b > 0.05
				if cinto:
					nuevo = CINTO * clampf(f, 0.6, 1.9)
				else:
					nuevo = MEZCLILLA * clampf(lerpf(1.0, f, 0.7), 0.55, 1.5) \
							* (1.0 + rng.randf_range(-MEZCLILLA_GRANO, MEZCLILLA_GRANO))
			elif ramon and e in ZAPATOS:
				nuevo = TENIS * lerpf(1.0, f, 0.45)
			elif ramon and e in SUELAS:
				nuevo = TENIS_SUELA * clampf(f, 0.8, 1.1)
			elif e in CHAMARRA:
				var fc := clampf(lerpf(1.0, f, VETA), 0.6, 1.2)
				nuevo = MOSTAZA * fc
				var hv: float = hojas[y * w + x]
				if hv > 1.5: nuevo = HOJA_VENA * fc
				elif hv > 0.5: nuevo = HOJA * fc
				if e == PECHO_ISLA:
					var pecho := _pecho(p)
					# el cuello de la playera original (clarito y rojizo) también es piel
					if pecho < 0.0 and CUELLO.has_point(p) and c.r - c.b > 0.12 and c.s > 0.3 and c.v > 0.45:
						pecho = 0.9
					if pecho >= 0.0:
						nuevo = PIEL * pecho
						es_piel = true
					var joya := _joya(p)
					if joya > 0.0:
						nuevo = ORO if joya > 1.5 else ORO_OSCURO
						es_piel = false
			elif e in ANTEBRAZOS:
				nuevo = PIEL * clampf(lerpf(1.0, f, 0.5), 0.7, 1.2)
				es_piel = true
			elif k.ends_with("piel") or e in MANOS:
				nuevo = PIEL * f
				es_piel = true
				if e in CABEZA and not ramon and _bigote(Vector2i(x, y)):
					nuevo = (CANA if rng.randf() < CANAS_BIGOTE and not emiliano else PELO) * clampf(f, 0.7, 1.3)
					es_piel = false
			elif k.ends_with("pelo"):
				var cana := e in SOLO_PELO and not ramon and not emiliano and rng.randf() < CANAS_PELO
				nuevo = (CANA if cana else PELO) * clampf(f, 0.6, 1.5)
			elif e in PANTALON:
				var cinto := c.s > 0.15 and c.r - c.b > 0.05
				nuevo = (CINTO if cinto else NEGRO) * clampf(f, 0.6, 1.9)
				if e == HEBILLA_ISLA and HEBILLA.has_point(Vector2i(x, y)):
					nuevo = _hebilla(x - HEBILLA.position.x, y - HEBILLA.position.y)
			elif e in ZAPATOS:
				nuevo = BOTA * lerpf(1.0, f, 0.45)   # aplana las agujetas
			elif e in SUELAS:
				nuevo = SUELA * f
			nuevo.a = c.a
			img.set_pixel(x, y, nuevo)
			if es_piel:
				mascara.set_pixel(x, y, Color.WHITE)
	var destino := CARPETA_HOMERO if homero else (CARPETA_RAMON if ramon else (CARPETA_EMILIANO if emiliano else CARPETA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	img.save_png(ProjectSettings.globalize_path(destino + "Character_04.png"))
	mascara.save_png(ProjectSettings.globalize_path(destino + "piel.png"))
	print("listo: ", destino + "Character_04.png")
	quit()


func _luz(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


# En la cabeza separa piel de pelo por color: la piel es clara y rojiza.
func _clave(e: int, c: Color) -> String:
	if e in CABEZA:
		return "%d_%s" % [e, "piel" if _luz(c) > 0.30 and c.r - c.b > 0.10 else "pelo"]
	return str(e)


# Hojas alargadas repartidas en rejilla con desorden. 0 fuera, 1 hoja, 2 vena.
func _hojas() -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(w * h)
	const PASO := 17
	for gy in range(-PASO, h + PASO, PASO):
		for gx in range(-PASO, w + PASO, PASO):
			var c := Vector2(gx + rng.randf_range(-5, 5), gy + rng.randf_range(-5, 5))
			var ang := rng.randf_range(0, TAU)
			var largo := rng.randf_range(6.0, 9.0)     # medio largo
			var ancho := rng.randf_range(2.2, 3.2)     # medio ancho
			var eje := Vector2.from_angle(ang)
			var r := int(largo) + 1
			for y in range(int(c.y) - r, int(c.y) + r + 1):
				for x in range(int(c.x) - r, int(c.x) + r + 1):
					if x < 0 or y < 0 or x >= w or y >= h: continue
					var d := Vector2(x + 0.5, y + 0.5) - c
					var u := d.dot(eje) / largo
					var v := d.dot(eje.orthogonal())
					if absf(u) >= 1.0: continue
					var borde := ancho * (1.0 - u * u)
					if absf(v) <= borde:
						m[y * w + x] = 2.0 if absf(v) < 0.5 and absf(u) < 0.8 else 1.0
	return m


# La guayabera de Homero en el punto q del modelo (f: la sombra de la tela original)
func _guayabera(e: int, q: Vector3, f: float) -> Color:
	# Poca de la sombra original: en blanco la veta de la chamarra se veia como madera
	var luz := clampf(lerpf(1.0, f, 0.25), 0.82, 1.05)
	var z := absf(q.z)
	var frente := q.x > -0.06
	var en_torso := e in CHAMARRA and e != 3 and e != 8 or e in PANTALON
	if e in ANTEBRAZOS:
		# Manga larga: la costura del puno cerca de la muneca
		if absf(q.y - PUNO_Y) < LINEA:
			luz *= GUAYABERA_LINEA
		return GUAYABERA * luz
	if not en_torso:
		return GUAYABERA * luz
	# El dobladillo, por fuera del pantalon
	if q.y < GUAYABERA_HASTA + 0.02:
		luz *= 0.82
	if frente:
		# Botones y la tira donde van
		for by: float in BOTONES_Y:
			if absf(q.y - by) < 0.016 and z < 0.016:
				return BOTON * (0.6 if absf(q.y - by) < 0.006 and z < 0.006 else 1.0)
		if absf(z - 0.022) < LINEA * 0.6:
			luz *= GUAYABERA_LINEA
		# Bolsas con su cartera y su boton
		for b: Rect2 in BOLSAS:
			var dentro := z > b.position.x and z < b.end.x and q.y > b.position.y and q.y < b.end.y
			if dentro:
				var orilla := minf(minf(z - b.position.x, b.end.x - z), q.y - b.position.y)
				var cartera := absf(q.y - (b.end.y - 0.05)) < LINEA
				if absf(q.y - (b.end.y - 0.025)) < 0.012 and absf(z - b.get_center().x) < 0.012:
					return BOTON
				if orilla < LINEA * 1.4 or cartera:
					luz *= GUAYABERA_LINEA
				return GUAYABERA * luz
		for a: float in ALFORZAS_FRENTE:
			if absf(z - a) < LINEA:
				luz *= GUAYABERA_LINEA
	else:
		for a: float in ALFORZAS_ATRAS:
			if absf(z - a) < LINEA:
				luz *= GUAYABERA_LINEA
	return GUAYABERA * luz


func _lana(color: Color) -> Color:
	return color * (1.0 + rng.randf_range(-TWEED, TWEED))


# El traje de Emiliano en el punto q del modelo (f: la sombra de la tela original)
func _traje(e: int, q: Vector3, f: float) -> Color:
	var luz := clampf(lerpf(1.0, f, 0.35), 0.75, 1.15)
	var z := absf(q.z)
	var torso := e in CHAMARRA and e != 3 and e != 8
	if not torso:
		# Mangas largas del saco y el puno de la camisa asomado en la muneca
		if e in ANTEBRAZOS and q.y < PUNO_Y + 0.03:
			return CAMISA * luz
		return _lana(SACO) * luz
	if q.x <= -0.06:
		return _lana(SACO) * luz
	# Paliacate: anudado al cuello y la punta colgando
	if q.y > 3.88 and z < 0.2:
		return PALIACATE * luz
	if q.y > PALIACATE_PUNTA and q.y < 3.88:
		var ancho := 0.025 + (q.y - PALIACATE_PUNTA) * 0.12
		if q.y > PALIACATE_NUDO and z < 0.05 or z < ancho * 0.6:
			return PALIACATE * luz * (0.8 if absf(q.y - PALIACATE_NUDO) < 0.012 else 1.0)
	# La camisa en la V del chaleco
	if q.y > CAMISA_V and z < (q.y - CAMISA_V) * 0.55:
		return CAMISA * luz
	if z < CHALECO_ANCHO and q.y > CHALECO_DESDE:
		# Botones
		for by: float in BOTONES_CHALECO:
			if absf(q.y - by) < 0.013 and z < 0.013:
				return ORO_OSCURO
		# Leontina: la cadena en U de bolsa a bolsa y el dije colgando en medio
		var t := z / 0.13
		if t < 1.0 and absf(q.y - (LEONTINA_Y - 0.09 * (1.0 - t * t))) < 0.008:
			return ORO if int(z * 300.0) % 2 == 0 else ORO_OSCURO
		if z < 0.012 and q.y < LEONTINA_Y - 0.09 and q.y > LEONTINA_Y - 0.17:
			return ORO
		# La orilla del chaleco junto al saco
		if CHALECO_ANCHO - z < 0.012:
			return CHALECO * luz * 0.7
		return _lana(CHALECO) * luz
	# La solapa del saco, mas oscura en la orilla
	if z - CHALECO_ANCHO < 0.025:
		return SACO * luz * 0.7
	return _lana(SACO) * luz


# Factor de luz de la piel del pecho, o -1 si p queda fuera de la V.
func _pecho(p: Vector2) -> float:
	if p.x < PECHO_X.x or p.x > PECHO_X.y: return -1.0
	var t := (p.x - PECHO_X.x) / (PECHO_X.y - PECHO_X.x)
	var medio := lerpf(PECHO_ANCHO.x, PECHO_ANCHO.y, t)
	var dy := absf(p.y - PECHO_CENTRO_Y)
	if dy > medio: return -1.0
	var luz := 1.0
	if dy < 0.8: luz = 0.85                  # esternón
	if medio - dy < 1.5: luz = 0.65          # sombra de la camisa
	return luz


# 2 = oro claro, 1 = oro oscuro, 0 = nada.
func _joya(p: Vector2) -> float:
	if CRUZ.has_point(p) or CRUZ_BRAZO.has_point(p):
		return 2.0 if int(p.x + p.y) % 3 != 0 else 1.0
	for lado in [-1.0, 1.0]:
		var a := Vector2(CADENA_ARRIBA_X, PECHO_CENTRO_Y + lado * (PECHO_ANCHO.y - 3.0))
		var b := Vector2(CADENA_ABAJO_X, PECHO_CENTRO_Y)
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(q) < 0.75:
			return 2.0 if int(p.x) % 2 == 0 else 1.0
	return 0.0


# Hebilla grande: marco oscuro, oro con un rombo grabado.
func _hebilla(x: int, y: int) -> Color:
	var s := HEBILLA.size
	if x == 0 or y == 0 or x == s.x - 1 or y == s.y - 1: return ORO_OSCURO
	var d := absf(x - s.x * 0.5 + 0.5) + absf(y - s.y * 0.5 + 0.5)
	if absi(int(d) - 6) == 0: return ORO_OSCURO
	return ORO * (1.1 if (x + y) % 5 == 0 else 1.0)


func _bigote(px: Vector2i) -> bool:
	if not posiciones.has(px): return false
	var q: Vector3 = posiciones[px]
	if emiliano:
		# Grande y caido a los lados: mas ancho, y en las puntas baja
		var baja := maxf(absf(q.z) - 0.06, 0.0) * 0.5
		return q.x > BIGOTE_FRENTE - 0.02 and absf(q.z) < BIGOTE_GRANDE.z \
				and q.y > BIGOTE_GRANDE.x - baja and q.y < BIGOTE_GRANDE.y - baja
	return q.x > BIGOTE_FRENTE and absf(q.z) < BIGOTE_MEDIO and q.y > BIGOTE_Y.x and q.y < BIGOTE_Y.y


# Rasteriza los triángulos de la malla en el espacio UV: para cada píxel, el
# punto 3D que le corresponde (interpolado con baricéntricas).
func _posiciones() -> Dictionary:
	var modelo: Node3D = load(CARPETA + "el_compa.fbx").instantiate()
	var mi := modelo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tam := Vector2(w, h)
	var res := {}
	for t in range(0, idx.size(), 3):
		var a := uv[idx[t]] * tam
		var b := uv[idx[t + 1]] * tam
		var c := uv[idx[t + 2]] * tam
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-6: continue
		var lo := a.min(b).min(c).floor()
		var hi := a.max(b).max(c).ceil()
		for y in range(maxi(int(lo.y), 0), mini(int(hi.y), h - 1) + 1):
			for x in range(maxi(int(lo.x), 0), mini(int(hi.x), w - 1) + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				var l1 := (p - a).cross(c - a) / area
				var l2 := (b - a).cross(p - a) / area
				var l0 := 1.0 - l1 - l2
				if l0 < -0.01 or l1 < -0.01 or l2 < -0.01: continue
				res[Vector2i(x, y)] = pos[idx[t]] * l0 + pos[idx[t + 1]] * l1 + pos[idx[t + 2]] * l2
	modelo.free()
	return res
