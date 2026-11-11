class_name CarcamoNivel
extends Node3D
# El cuarto de bombeo del carcamo (PruebaLombrices): un reservorio de GelA con estetica de pool
# room. Piso de concreto gris, muros pintados de blanco, una alberca de Serenol oscuro en medio que
# parece no tener fondo (ahi vive la Madre), barandales amarillos y un mezzanine alrededor a MEZZ_ALTO con su barandal. Llegas por
# la puerta del muro norte, ya arriba; bajas por dos rampas (oeste y este, pegadas al mezzanine)
# o por dos escaleras (sur). Letreros de planta, la gota de GelA en los muros y moho de muro
# descuidado (shaders/pared_moho).
#
# El barandal de la alberca esta en la capa 2 (PruebaLombrices le suma esa capa al jugador): el
# campo de las lombrices no lo ve, asi la Madre y las crias salen de la alberca sin treparlo. El
# del mezzanine si esta en la capa 1, para que las crias no se caigan por la orilla.

const LADO := 28.0
const MURO_ALTO := 10.0         # 7 dejaba atravesar el techo brincando desde el mezzanine
const MEZZ_ALTO := 3.5
const MEZZ_ANCHO := 2.5
const ALBERCA := 4.5            # medio lado de la alberca
const HONDO := 0.9
const AGUA := -0.12             # altura de la superficie
const BARANDAL := 1.1
const BARANDAL_ALBERCA := 0.6   # m de la orilla al barandal
const HUECO := 0.8              # medio ancho de los huecos con escalerilla (norte y sur)
const RAMPA_ANCHO := 1.6
const RAMPA_LARGO := 7.0
const ESCALERA_ANCHO := 1.3
const ESCALERA_LARGO := 4.2
const ESCALERA_X := 7.5
const PUERTA := 1.2             # medio ancho de la puerta de entrada
const PUERTA_ALTO := 2.4
const ALUMBRADO := preload("res://scripts/map/MapAlumbrado.gd")
const GOTA := "res://textures/logos-negocios/gela-gota.svg"
const COLOR_AMARILLO := Color(0.95, 0.72, 0.05)
const COLOR_GELA := Color(0.12, 0.5, 0.78)

# Luz ambiente azul: 0.8 para las capturas (JJ), luego 0.4, 0.3, 0.2 y 0.15 para que se vea mas tetrico
# (JJ, 2026-11-09). Antes 0.22 escondia a la Madre y a las crias; ahora JJ lo quiere asi. -- --ambiente=<n> lo cambia para probar
var ambiente := 0.15

const MEDIO := LADO / 2.0
const ADENTRO := MEDIO - MEZZ_ANCHO   # borde interior del mezzanine
const ENTRADA := Vector3(0.0, MEZZ_ALTO + 1.1, -MEDIO + 1.2)
const EJE_MEZZ := MEDIO - MEZZ_ANCHO / 2.0   # el anillo por donde caminan las crias arriba

# [pie, punta] de cada rampa y escalera: por ahi suben las crias (EnjambreLombrices.rampas)
var rampas: Array = []

var _concreto: StandardMaterial3D
var _pared: ShaderMaterial
var _concreto_tex: ImageTexture
var _amarillo: StandardMaterial3D
var _franjas: StandardMaterial3D
var _metal: StandardMaterial3D
var _rejilla: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _colores := {}                  # Color -> material liso compartido (letreros)
var _titilan: Array = []            # [luz, material del foco, semilla, energia]


func _ready() -> void:
	_rng.seed = 3
	_materiales()
	_piso_y_alberca()
	_muros_y_techo()
	_mezzanine()
	_rampas()
	_escaleras()
	_barandal_alberca()
	_tubos()
	_letreros()
	_gotas()
	_luces()
	_juntar()


# --- Materiales (texturas hechas aqui, en pixeles grandes como lo demas) ---

func _materiales() -> void:
	# Concreto gris: manchado con ruido, piedritas y una junta de colado cada 2.4 m
	_concreto_tex = _textura_ruido(128, 0.44, 0.07, 0.03, true, 11)
	_concreto = StandardMaterial3D.new()
	_concreto.albedo_texture = _concreto_tex
	_concreto.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_concreto.uv1_triplanar = true
	_concreto.uv1_scale = Vector3.ONE / 2.4
	_concreto.roughness = 0.85
	# Muros pintados de blanco, con la pintura dispareja y moho (shaders/pared_moho)
	_pared = ShaderMaterial.new()
	_pared.shader = load("res://shaders/pared_moho.gdshader")
	_pared.set_shader_parameter("pintura", _textura_ruido(128, 0.88, 0.035, 0.0, false, 12))
	_pared.set_shader_parameter("ruido", _ruido_tex(256, 0.012, 5, 21))
	_pared.set_shader_parameter("detalle", _ruido_tex(256, 0.05, 3, 22))
	_pared.set_shader_parameter("muro_alto", MURO_ALTO)
	_pared.set_shader_parameter("mezz_alto", MEZZ_ALTO)
	_amarillo = StandardMaterial3D.new()
	_amarillo.albedo_color = COLOR_AMARILLO
	_amarillo.roughness = 0.5
	# Franjas de precaucion amarillo con negro, en diagonal
	var franjas := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			franjas.set_pixel(x, y, COLOR_AMARILLO if (x + y) % 16 < 8 else Color(0.06, 0.06, 0.06))
	_franjas = StandardMaterial3D.new()
	_franjas.albedo_texture = ImageTexture.create_from_image(franjas)
	_franjas.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_franjas.uv1_triplanar = true
	_franjas.uv1_scale = Vector3.ONE / 0.6
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.42, 0.46, 0.48)
	_metal.metallic = 0.6
	_metal.roughness = 0.45
	# Rejilla de metal (tipo Irving): soleras cada 6 cm y travesanos cada 25 cm, con huecos que dejan
	# ver para abajo
	var rejilla := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var solera := x % 4 == 0
			var travesano := y % 16 == 0
			var tono := 0.55 + _rng.randf() * 0.06
			rejilla.set_pixel(x, y, Color(tono, tono, tono * 1.03, 1.0) if solera or travesano else Color(0, 0, 0, 0))
	rejilla.generate_mipmaps()
	_rejilla = StandardMaterial3D.new()
	_rejilla.albedo_texture = ImageTexture.create_from_image(rejilla)
	_rejilla.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_rejilla.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_rejilla.alpha_scissor_threshold = 0.4
	_rejilla.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rejilla.uv1_triplanar = true
	_rejilla.uv1_scale = Vector3.ONE / 0.5
	_rejilla.metallic = 0.6
	_rejilla.roughness = 0.5


# --- Geometria ---

func _piso_y_alberca() -> void:
	# El piso con el hueco de la alberca: cuatro losas alrededor y el fondo
	var ancho := MEDIO - ALBERCA
	_caja(Vector3(LADO, 1.0, ancho), Vector3(0, -0.5, -(ALBERCA + ancho / 2.0)), _concreto)
	_caja(Vector3(LADO, 1.0, ancho), Vector3(0, -0.5, ALBERCA + ancho / 2.0), _concreto)
	_caja(Vector3(ancho, 1.0, ALBERCA * 2.0), Vector3(-(ALBERCA + ancho / 2.0), -0.5, 0), _concreto)
	_caja(Vector3(ancho, 1.0, ALBERCA * 2.0), Vector3(ALBERCA + ancho / 2.0, -0.5, 0), _concreto)
	# Por dentro: concreto que se va a negro hacia abajo, y el fondo negro (shaders/alberca_hondo)
	var hondo := ShaderMaterial.new()
	hondo.shader = load("res://shaders/alberca_hondo.gdshader")
	hondo.set_shader_parameter("concreto", _concreto_tex)
	_caja(Vector3(ALBERCA * 2.0, 0.4, ALBERCA * 2.0), Vector3(0, -HONDO - 0.2, 0), hondo)
	for lado in 4:
		var signo := -1.0 if lado % 2 == 0 else 1.0
		var forro := _malla(Vector3(ALBERCA * 2.0, HONDO, 0.02) if lado < 2 else Vector3(0.02, HONDO, ALBERCA * 2.0), hondo)
		var pegado := ALBERCA - 0.01
		forro.position = Vector3(0, -HONDO / 2.0, signo * pegado) if lado < 2 else Vector3(signo * pegado, -HONDO / 2.0, 0)
	# La orilla con franja de precaucion (sin colision)
	for lado in 4:
		var largo := ALBERCA * 2.0 + 0.8
		var franja := _malla(Vector3(largo, 0.02, 0.4) if lado < 2 else Vector3(0.4, 0.02, largo), _franjas)
		var signo := -1.0 if lado % 2 == 0 else 1.0
		franja.position = Vector3(0, 0.01, signo * (ALBERCA + 0.2)) if lado < 2 else Vector3(signo * (ALBERCA + 0.2), 0.01, 0)
	# El Serenol: oscuro, se ve lo que esta cerca de la superficie y lo hondo se pierde en negro
	# (shaders/serenol_alberca)
	var agua := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * ALBERCA * 2.0
	plano.subdivide_width = 8
	plano.subdivide_depth = 8
	var agua_mat := ShaderMaterial.new()
	agua_mat.shader = load("res://shaders/serenol_alberca.gdshader")
	plano.material = agua_mat
	agua.mesh = plano
	agua.position.y = AGUA
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(agua)


func _muros_y_techo() -> void:
	var grueso := 1.0
	var largo := LADO + grueso * 2.0
	_caja(Vector3(largo, MURO_ALTO, grueso), Vector3(0, MURO_ALTO / 2.0, MEDIO + grueso / 2.0), _pared)
	_caja(Vector3(grueso, MURO_ALTO, LADO), Vector3(-MEDIO - grueso / 2.0, MURO_ALTO / 2.0, 0), _pared)
	_caja(Vector3(grueso, MURO_ALTO, LADO), Vector3(MEDIO + grueso / 2.0, MURO_ALTO / 2.0, 0), _pared)
	# El norte con el hueco de la puerta, arriba en el mezzanine
	var z := -MEDIO - grueso / 2.0
	var lado_x := (largo / 2.0 - PUERTA)
	_caja(Vector3(lado_x, MURO_ALTO, grueso), Vector3(-(PUERTA + lado_x / 2.0), MURO_ALTO / 2.0, z), _pared)
	_caja(Vector3(lado_x, MURO_ALTO, grueso), Vector3(PUERTA + lado_x / 2.0, MURO_ALTO / 2.0, z), _pared)
	_caja(Vector3(PUERTA * 2.0, MEZZ_ALTO, grueso), Vector3(0, MEZZ_ALTO / 2.0, z), _pared)
	var dintel := MURO_ALTO - MEZZ_ALTO - PUERTA_ALTO
	_caja(Vector3(PUERTA * 2.0, dintel, grueso), Vector3(0, MURO_ALTO - dintel / 2.0, z), _pared)
	# El pasillo por donde llegas: oscuro, de concreto
	var concreto := StandardMaterial3D.new()
	concreto.albedo_color = Color(0.3, 0.31, 0.3)
	var fondo := 3.0
	var zc := -MEDIO - grueso - fondo / 2.0
	_caja(Vector3(PUERTA * 2.0 + 0.4, 0.3, fondo + grueso), Vector3(0, MEZZ_ALTO - 0.15, zc + grueso / 2.0), concreto)
	_caja(Vector3(PUERTA * 2.0 + 0.4, 0.3, fondo), Vector3(0, MEZZ_ALTO + PUERTA_ALTO + 0.15, zc), concreto)
	_caja(Vector3(0.3, PUERTA_ALTO, fondo), Vector3(-PUERTA - 0.15, MEZZ_ALTO + PUERTA_ALTO / 2.0, zc), concreto)
	_caja(Vector3(0.3, PUERTA_ALTO, fondo), Vector3(PUERTA + 0.15, MEZZ_ALTO + PUERTA_ALTO / 2.0, zc), concreto)
	_caja(Vector3(PUERTA * 2.0, PUERTA_ALTO, 0.3), Vector3(0, MEZZ_ALTO + PUERTA_ALTO / 2.0, zc - fondo / 2.0 - 0.15), concreto)
	# Franja de precaucion a la altura de la cintura en todo el cuarto (planta baja)
	for muro in _muros():
		var franja := _malla(Vector3(LADO, 0.25, 0.02), _franjas)
		franja.basis = Basis(muro[2], Vector3.UP, (muro[2] as Vector3).cross(Vector3.UP))
		franja.position = muro[0] + Vector3.UP * 1.0 + muro[1] * 0.01
	# Techo de lamina, con colision: brincando desde el mezzanine la cabeza lo atravesaba
	_caja(Vector3(largo, 0.3, largo), Vector3(0, MURO_ALTO + 0.15, 0), concreto)
	for x: float in [-9.0, 0.0, 9.0]:
		var viga := _malla(Vector3(0.35, 0.5, LADO), _metal)
		viga.position = Vector3(x, MURO_ALTO - 0.25, 0)


func _mezzanine() -> void:
	# Cuatro tramos de rejilla de metal alrededor, sobre vigas y postes; abajo se puede caminar.
	# La colision es una losa invisible; se ve la rejilla arriba y las vigas debajo
	var y := MEZZ_ALTO - 0.15
	var tramos := [
		[Vector3(LADO, 0.3, MEZZ_ANCHO), Vector3(0, y, -EJE_MEZZ)],
		[Vector3(LADO, 0.3, MEZZ_ANCHO), Vector3(0, y, EJE_MEZZ)],
		[Vector3(MEZZ_ANCHO, 0.3, ADENTRO * 2.0), Vector3(-EJE_MEZZ, y, 0)],
		[Vector3(MEZZ_ANCHO, 0.3, ADENTRO * 2.0), Vector3(EJE_MEZZ, y, 0)],
	]
	for tramo in tramos:
		var medida: Vector3 = tramo[0]
		var centro: Vector3 = tramo[1]
		_caja(medida, centro, null)
		var piso := _malla(Vector3(medida.x, 0.04, medida.z), _rejilla)
		piso.position = Vector3(centro.x, MEZZ_ALTO - 0.02, centro.z)
		piso.add_to_group("carcamo_rejilla")
		# Vigas atravesadas cada 2 m y dos largueros en las orillas
		var a_lo_largo := medida.x > medida.z
		var largo := maxf(medida.x, medida.z)
		var ancho := minf(medida.x, medida.z)
		for n in int(largo / 2.0) + 1:
			var t := -largo / 2.0 + n * largo / int(largo / 2.0)
			var viga := _malla(Vector3(0.12, 0.22, ancho) if a_lo_largo else Vector3(ancho, 0.22, 0.12), _metal)
			viga.position = centro + (Vector3(t, 0, 0) if a_lo_largo else Vector3(0, 0, t)) + Vector3.UP * 0.02
			viga.add_to_group("carcamo_rejilla")
		for lado: float in [-1.0, 1.0]:
			var orilla := (ancho / 2.0 - 0.06) * lado
			var larguero := _malla(Vector3(largo, 0.28, 0.1) if a_lo_largo else Vector3(0.1, 0.28, largo), _metal)
			larguero.position = centro + (Vector3(0, 0, orilla) if a_lo_largo else Vector3(orilla, 0, 0))
			larguero.add_to_group("carcamo_rejilla")
	# Rodapie con franjas en la orilla interior
	for lado in 4:
		var signo := -1.0 if lado % 2 == 0 else 1.0
		var rodapie := _malla(Vector3(ADENTRO * 2.0, 0.3, 0.04) if lado < 2 else Vector3(0.04, 0.3, ADENTRO * 2.0), _franjas)
		rodapie.position = Vector3(0, y, signo * ADENTRO) if lado < 2 else Vector3(signo * ADENTRO, y, 0)
	# Postes (fuera del camino de las rampas)
	var p := ADENTRO + 0.15
	for x: float in [-p, -p / 2.0, 0.0, p / 2.0, p]:
		for z: float in [-p, p]:
			_caja(Vector3(0.3, MEZZ_ALTO - 0.3, 0.3), Vector3(x, (MEZZ_ALTO - 0.3) / 2.0, z), _amarillo)
	for z: float in [-p / 2.0, 0.0, p / 2.0]:
		for x: float in [-p, p]:
			_caja(Vector3(0.3, MEZZ_ALTO - 0.3, 0.3), Vector3(x, (MEZZ_ALTO - 0.3) / 2.0, z), _amarillo)
	# El barandal del borde, con huecos donde llegan la rampa oeste (norte), la rampa este (sur)
	# y las dos escaleras (sur)
	var a := ADENTRO
	var r := a - RAMPA_ANCHO
	var e0 := ESCALERA_X - ESCALERA_ANCHO / 2.0
	var e1 := ESCALERA_X + ESCALERA_ANCHO / 2.0
	_barandal(Vector3(-r, MEZZ_ALTO, -a), Vector3(a, MEZZ_ALTO, -a), 1)
	_barandal(Vector3(-a, MEZZ_ALTO, -a), Vector3(-a, MEZZ_ALTO, a), 1)
	_barandal(Vector3(a, MEZZ_ALTO, -a), Vector3(a, MEZZ_ALTO, a), 1)
	_barandal(Vector3(-a, MEZZ_ALTO, a), Vector3(-e1, MEZZ_ALTO, a), 1)
	_barandal(Vector3(-e0, MEZZ_ALTO, a), Vector3(e0, MEZZ_ALTO, a), 1)
	_barandal(Vector3(e1, MEZZ_ALTO, a), Vector3(r, MEZZ_ALTO, a), 1)


func _rampas() -> void:
	# Oeste: arriba en el borde del mezzanine norte, baja hacia el sur pegada al oeste.
	# Este: igual pero al reves (arriba en el sur, baja hacia el norte)
	var x := ADENTRO - RAMPA_ANCHO / 2.0
	for signo: float in [-1.0, 1.0]:
		var arriba := Vector3(signo * x, MEZZ_ALTO, signo * ADENTRO)
		var abajo := Vector3(signo * x, 0.0, signo * (ADENTRO - RAMPA_LARGO))
		_cuesta(arriba, abajo, RAMPA_ANCHO, _rejilla, false)
		# Barandal del lado de afuera (el otro lado es el borde del mezzanine)
		var orilla := Vector3(-signo * RAMPA_ANCHO / 2.0, 0, 0)
		_barandal(arriba + orilla, abajo + orilla, 1)
		rampas.append([abajo + (abajo - arriba).normalized() * 0.5 * Vector3(1, 0, 1), arriba])


func _escaleras() -> void:
	for signo: float in [-1.0, 1.0]:
		var arriba := Vector3(signo * ESCALERA_X, MEZZ_ALTO, ADENTRO)
		var abajo := Vector3(signo * ESCALERA_X, 0.0, ADENTRO - ESCALERA_LARGO)
		_cuesta(arriba, abajo, ESCALERA_ANCHO, null, true)
		var escalones := 14
		for n in escalones:
			var alto := MEZZ_ALTO * (n + 1) / escalones
			var z := ADENTRO - ESCALERA_LARGO + ESCALERA_LARGO * (n + 0.5) / escalones
			var esc := _malla(Vector3(ESCALERA_ANCHO, 0.05, ESCALERA_LARGO / escalones + 0.02), _rejilla)
			esc.position = Vector3(signo * ESCALERA_X, alto - 0.04, z)
			var nariz := _malla(Vector3(ESCALERA_ANCHO, 0.04, 0.06), _amarillo)
			nariz.position = esc.position + Vector3(0, 0.02, -ESCALERA_LARGO / escalones / 2.0)
		for lado: float in [-1.0, 1.0]:
			var orilla := Vector3(lado * ESCALERA_ANCHO / 2.0, 0, 0)
			_barandal(arriba + orilla, abajo + orilla, 1)
		rampas.append([abajo + Vector3(0, 0, -0.5), arriba])


func _barandal_alberca() -> void:
	# Alrededor de la alberca, con dos huecos (norte y sur) donde hay escalerilla
	var b := ALBERCA + BARANDAL_ALBERCA
	_barandal(Vector3(-HUECO, 0, -b), Vector3(-b, 0, -b), 2)
	_barandal(Vector3(-b, 0, -b), Vector3(-b, 0, b), 2)
	_barandal(Vector3(-b, 0, b), Vector3(-HUECO, 0, b), 2)
	_barandal(Vector3(HUECO, 0, b), Vector3(b, 0, b), 2)
	_barandal(Vector3(b, 0, b), Vector3(b, 0, -b), 2)
	_barandal(Vector3(b, 0, -b), Vector3(HUECO, 0, -b), 2)
	# Escalerillas de tubo, colgadas de la orilla
	for signo: float in [-1.0, 1.0]:
		var z := signo * (ALBERCA - 0.1)
		for x: float in [-0.3, 0.3]:
			var tubo := _malla(Vector3(0.06, HONDO + 0.9, 0.06), _metal)
			tubo.position = Vector3(x, (0.9 - HONDO) / 2.0, z)
		for n in 3:
			var paso := _malla(Vector3(0.6, 0.05, 0.05), _metal)
			paso.position = Vector3(0, -HONDO + 0.25 + n * 0.3, z)


func _tubos() -> void:
	# Tuberia de bombeo: dos tubos que bajan del techo a las esquinas norte de la alberca y uno
	# que corre por el muro oeste. Solo se ven (sin colision: no estorban a las lombrices)
	var azul := StandardMaterial3D.new()
	azul.albedo_color = Color(0.16, 0.36, 0.55)
	azul.roughness = 0.5
	var esquina := ALBERCA - 0.3
	for x: float in [-esquina, esquina]:
		var tubo := _cilindro(0.22, MURO_ALTO + HONDO, azul)
		tubo.position = Vector3(x, (MURO_ALTO - HONDO) / 2.0, -esquina)
		var brida := _cilindro(0.32, 0.1, _metal)
		brida.position = Vector3(x, 0.5, -esquina)
		var codo := _cilindro(0.22, MEDIO - esquina, azul)
		codo.rotation.x = PI / 2.0
		codo.position = Vector3(x, MURO_ALTO - 0.8, -esquina - (MEDIO - esquina) / 2.0)
	var largo := _cilindro(0.25, LADO, azul)
	largo.rotation.x = PI / 2.0
	largo.position = Vector3(-MEDIO + 0.35, MURO_ALTO - 1.1, 0)


func _letreros() -> void:
	var rojo := Color(0.75, 0.1, 0.08)
	var negro := Color(0.06, 0.06, 0.06)
	var blanco := Color(0.96, 0.96, 0.94)
	var norte := Vector3(0, 0, -MEDIO)
	var sur := Vector3(0, 0, MEDIO)
	var oeste := Vector3(-MEDIO, 0, 0)
	var este := Vector3(MEDIO, 0, 0)
	# Sobre la puerta y en los muros
	_letrero(norte + Vector3(0, MEZZ_ALTO + PUERTA_ALTO + 0.55, 0), Vector3.BACK, Vector2(4.2, 0.6), blanco, "CÁRCAMO DE BOMBEO 03", negro, 0.32)
	_letrero(sur + Vector3(0, 5.6, 0), Vector3.FORWARD, Vector2(5.0, 0.9), COLOR_AMARILLO, "PELIGRO\nÁREA DE BOMBEO", negro, 0.32)
	_letrero(oeste + Vector3(0, 2.1, 5.0), Vector3.RIGHT, Vector2(2.6, 0.9), blanco, "SOLO PERSONAL\nAUTORIZADO", rojo, 0.26)
	_letrero(este + Vector3(0, 2.1, -5.0), Vector3.LEFT, Vector2(3.0, 0.9), blanco, "USO OBLIGATORIO DE\nEQUIPO DE PROTECCIÓN", Color(0.1, 0.3, 0.65), 0.22)
	_letrero(este + Vector3(0, 5.4, 6.0), Vector3.LEFT, Vector2(2.4, 0.7), COLOR_AMARILLO, "NO FUMAR", negro, 0.34)
	_letrero(oeste + Vector3(0, 5.4, -6.0), Vector3.RIGHT, Vector2(3.2, 0.7), blanco, "NIVEL MÁX. TANQUE 2.4 m", negro, 0.24)
	# Numeros pintados de cada muro, grandes, arriba
	_texto("B-03", Vector3(-MEDIO + 0.06, MURO_ALTO - 1.0, -8.0), Vector3.RIGHT, 1.2, negro)
	_texto("B-03", Vector3(MEDIO - 0.06, MURO_ALTO - 1.0, 8.0), Vector3.LEFT, 1.2, negro)
	# En el barandal de la alberca
	var b := ALBERCA + BARANDAL_ALBERCA
	_letrero(Vector3(-2.6, 0.55, -b - 0.05), Vector3.FORWARD, Vector2(1.6, 0.5), COLOR_AMARILLO, "PELIGRO\nNO NADAR", negro, 0.15, false)
	_letrero(Vector3(2.6, 0.55, b + 0.05), Vector3.BACK, Vector2(1.6, 0.5), COLOR_AMARILLO, "PELIGRO\nNO NADAR", negro, 0.15, false)
	_letrero(Vector3(-b - 0.05, 0.55, 2.6), Vector3.LEFT, Vector2(1.6, 0.5), blanco, "PROFUNDIDAD\n%.1f m" % HONDO, negro, 0.14, false)
	_letrero(Vector3(b + 0.05, 0.55, -2.6), Vector3.RIGHT, Vector2(1.6, 0.5), blanco, "PROFUNDIDAD\n%.1f m" % HONDO, negro, 0.14, false)
	# Pintado en el piso junto a la alberca
	var piso := _texto("NO PISAR LA ORILLA", Vector3(0, 0.02, -b - 1.1), Vector3.UP, 0.4, Color(0.75, 0.55, 0.04))
	# Que se lea llegando por la entrada (del norte)
	piso.rotation = Vector3(-PI / 2.0, PI, 0)


func _gotas() -> void:
	# La gota de GelA (solo el logo) pintada en azul, dos por muro y una sobre la puerta (adentro)
	var textura := _gota_azul()
	if textura == null:
		return
	var proporcion := float(textura.get_height()) / textura.get_width()
	for muro in _muros():
		for a: float in [-7.0, 7.0]:
			_decal(muro, a, 5.2, Vector2(2.4, 2.4 * proporcion), textura, Color.WHITE)
	# Una chica en cada escalera, al pie
	for signo: float in [-1.0, 1.0]:
		_decal([Vector3(0, 0, MEDIO), Vector3.FORWARD, Vector3.LEFT], -signo * (ESCALERA_X + 2.0), 1.9, Vector2(0.9, 0.9 * proporcion), textura, Color.WHITE)


func _luces() -> void:
	# De noche y casi a oscuras: de las 9 lamparas del techo casi todas estan fundidas, una sigue
	# prendida (bajita, sobre la entrada) y dos titilan como los postes de la calle y el foco de El
	# Punto (Alumbrado.parpadeo), con chispas. Lo demas lo alumbran los tambos y el Serenol
	var prendida := Vector2(-9.0, -9.0)
	var titilan := {Vector2(0.0, 0.0): 17, Vector2(9.0, 9.0): 41}
	var fundido := StandardMaterial3D.new()
	fundido.albedo_color = Color(0.22, 0.21, 0.19)
	fundido.roughness = 0.3
	var chispas: Array[Vector3] = []
	for x: float in [-9.0, 0.0, 9.0]:
		for z: float in [-9.0, 0.0, 9.0]:
			var donde := Vector2(x, z)
			var campana := _cilindro(0.45, 0.25, _metal)
			campana.position = Vector3(x, MURO_ALTO - 0.9, z)
			var cable := _malla(Vector3(0.03, 0.8, 0.03), _metal)
			cable.position = Vector3(x, MURO_ALTO - 0.4, z)
			var foco: StandardMaterial3D = fundido
			if donde == prendida or titilan.has(donde):
				foco = StandardMaterial3D.new()
				foco.albedo_color = Color(1, 0.95, 0.85)
				foco.emission_enabled = true
				foco.emission = Color(1, 0.93, 0.78)
				foco.emission_energy_multiplier = 2.5
			var bulbo := _malla(Vector3(0.5, 0.06, 0.5), foco)
			bulbo.position = Vector3(x, MURO_ALTO - 1.04, z)
			if foco == fundido:
				continue
			# La de en medio, sobre la alberca, es un reflector con sombra
			var luz: Light3D
			if donde == Vector2.ZERO:
				var reflector := SpotLight3D.new()
				reflector.rotation.x = -PI / 2.0
				reflector.spot_range = 14.0
				reflector.spot_angle = 45.0
				reflector.shadow_enabled = true
				luz = reflector
			else:
				var omni := OmniLight3D.new()
				omni.omni_range = 13.0
				luz = omni
			luz.light_color = Color(1.0, 0.9, 0.75)
			luz.light_energy = 1.6 if titilan.has(donde) else 0.45
			luz.position = Vector3(x, MURO_ALTO - 1.3, z)
			add_child(luz)
			if titilan.has(donde):
				bulbo.set_meta("suelta", true)
				_titilan.append([luz, foco, titilan[donde], luz.light_energy])
				chispas.append(Vector3(x, MURO_ALTO - 1.1, z))
	var nodo: Node3D = ALUMBRADO.armar_chispas(chispas, 0.0)
	if nodo:
		add_child(nodo)
	# El letrero de SALIDA sobre la puerta, con su luz verde de emergencia
	var salida := _malla(Vector3(1.0, 0.32, 0.06), _salida())
	salida.position = Vector3(0, MEZZ_ALTO + PUERTA_ALTO + 0.2, -MEDIO + 0.06)
	salida.set_meta("suelta", true)
	_texto("SALIDA", salida.position + Vector3.BACK * 0.04, Vector3.BACK, 0.2, Color(0.95, 1.0, 0.95))
	var verde := OmniLight3D.new()
	verde.light_color = Color(0.3, 1.0, 0.45)
	verde.light_energy = 0.2
	verde.omni_range = 3.0
	verde.position = salida.position + Vector3.BACK * 0.6
	add_child(verde)
	var mundo := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.0, 0.0, 0.01)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.32, 0.38, 0.48)
	entorno.ambient_light_energy = ambiente
	entorno.fog_enabled = true
	entorno.fog_light_color = Color(0.03, 0.04, 0.06)
	entorno.fog_density = 0.035
	mundo.environment = entorno
	add_child(mundo)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for foco in _titilan:
		var brillo := Alumbrado.parpadeo(foco[2], t)
		(foco[0] as Light3D).light_energy = foco[3] * brillo
		(foco[1] as StandardMaterial3D).emission_energy_multiplier = 2.5 * brillo
		(foco[1] as StandardMaterial3D).albedo_color = Color(1, 0.95, 0.85).darkened(0.8 * (1.0 - brillo))


func _salida() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.75, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.1, 0.8, 0.3)
	m.emission_energy_multiplier = 1.5
	return m


# Junta todas las piezas fijas (barandales, vigas, escalones, letreros, losas...) en una malla por
# material: eran ~400 llamadas de dibujo, casi todas de barandal. La colision no cambia. Se quedan
# sueltas las que cambian (meta "suelta": focos que titilan) y la rejilla va aparte (grupo
# carcamo_rejilla, para medirla)
func _juntar() -> void:
	var lotes := {}
	var inverso := global_transform.affine_inverse()
	for malla: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var primitiva := malla.mesh as PrimitiveMesh
		if primitiva == null or primitiva.material == null or malla.get_meta("suelta", false):
			continue
		var rejilla := malla.is_in_group("carcamo_rejilla")
		var clave := [primitiva.material, rejilla]
		if not lotes.has(clave):
			lotes[clave] = [SurfaceTool.new(), rejilla]
		(lotes[clave][0] as SurfaceTool).append_from(primitiva, 0, inverso * malla.global_transform)
		malla.get_parent().remove_child(malla)
		malla.queue_free()
	for clave in lotes:
		var junta := MeshInstance3D.new()
		var mesh := (lotes[clave][0] as SurfaceTool).commit()
		mesh.surface_set_material(0, clave[0])
		junta.mesh = mesh
		if lotes[clave][1]:
			junta.add_to_group("carcamo_rejilla")
		add_child(junta)


# --- Piezas ---

# Muros: [centro de la cara a nivel de piso, normal hacia el cuarto, direccion a lo largo];
# lo largo x la normal apunta hacia abajo (lo alto del Decal)
func _muros() -> Array:
	return [
		[Vector3(0, 0, -MEDIO), Vector3.BACK, Vector3.RIGHT],
		[Vector3(0, 0, MEDIO), Vector3.FORWARD, Vector3.LEFT],
		[Vector3(-MEDIO, 0, 0), Vector3.RIGHT, Vector3.FORWARD],
		[Vector3(MEDIO, 0, 0), Vector3.LEFT, Vector3.BACK],
	]


func _caja(medida: Vector3, donde: Vector3, material: Material, capa := 1) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = capa
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medida
	forma.shape = caja
	cuerpo.add_child(forma)
	if material:
		var malla := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = medida
		bm.material = material
		malla.mesh = bm
		cuerpo.add_child(malla)
	cuerpo.position = donde
	add_child(cuerpo)
	return cuerpo


func _malla(medida: Vector3, material: Material) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = medida
	bm.material = material
	malla.mesh = bm
	add_child(malla)
	return malla


func _cilindro(radio: float, alto: float, material: Material) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = alto
	cm.radial_segments = 10
	cm.material = material
	malla.mesh = cm
	add_child(malla)
	return malla


# Una losa inclinada de `arriba` a `abajo` (centros de sus bordes). `material` null = invisible
# (las escaleras: se camina sobre una cuesta y se ven los escalones)
func _cuesta(arriba: Vector3, abajo: Vector3, ancho: float, material: Material, escalera: bool) -> void:
	var largo := arriba.distance_to(abajo)
	var cuerpo := _caja(Vector3(ancho, 0.25, largo), Vector3.ZERO, null)
	var adelante := (abajo - arriba).normalized()
	# Que la cara de arriba quede justo en la linea arriba-abajo
	var z := adelante
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	cuerpo.basis = Basis(x, y, z)
	cuerpo.position = (arriba + abajo) / 2.0 - y * 0.125
	if escalera or material == null:
		return
	# La rejilla arriba y dos largueros de lado; nariz amarilla arriba y abajo
	var piso := _malla(Vector3(ancho, 0.04, largo), material)
	piso.basis = cuerpo.basis
	piso.add_to_group("carcamo_rejilla")
	piso.position = (arriba + abajo) / 2.0 - y * 0.02
	for lado: float in [-1.0, 1.0]:
		var larguero := _malla(Vector3(0.1, 0.28, largo), _metal)
		larguero.basis = cuerpo.basis
		larguero.position = (arriba + abajo) / 2.0 + x * (ancho / 2.0 - 0.05) * lado - y * 0.14
	for punta: Vector3 in [arriba + adelante * 0.05, abajo - adelante * 0.05]:
		var nariz := _malla(Vector3(ancho, 0.03, 0.08), _amarillo)
		nariz.basis = cuerpo.basis
		nariz.position = punta + y * 0.005


# Barandal amarillo de `desde` a `hasta` (a nivel de piso; si van a distinta altura, inclinado):
# postes cada ~1.5 m, pasamanos y travesano. La colision es una lamina delgada en la `capa`
func _barandal(desde: Vector3, hasta: Vector3, capa: int) -> void:
	var largo := desde.distance_to(hasta)
	if largo < 0.05:
		return
	var postes := maxi(1, ceili(largo / 1.5))
	for n in postes + 1:
		var p := desde.lerp(hasta, float(n) / postes)
		var poste := _cilindro(0.04, BARANDAL, _amarillo)
		poste.position = p + Vector3.UP * BARANDAL / 2.0
	var z := (hasta - desde).normalized()
	var x := Vector3.UP.cross(z).normalized()
	if x.length_squared() < 0.5:
		x = Vector3.RIGHT
	var y := z.cross(x)
	for alto: float in [BARANDAL, BARANDAL * 0.5]:
		var tubo := _malla(Vector3(0.07, 0.07, largo), _amarillo)
		tubo.basis = Basis(x, y, z)
		tubo.position = (desde + hasta) / 2.0 + Vector3.UP * alto
	var lamina := _caja(Vector3(0.08, BARANDAL, largo), Vector3.ZERO, null, capa)
	lamina.basis = Basis(x, Vector3.UP, x.cross(Vector3.UP)) if absf(desde.y - hasta.y) < 0.01 else Basis(x, y, z)
	lamina.position = (desde + hasta) / 2.0 + Vector3.UP * BARANDAL / 2.0


func _letrero(donde: Vector3, normal: Vector3, medida: Vector2, fondo: Color, texto: String, tinta: Color, tam: float, en_muro := true) -> void:
	var placa := _liso(fondo)
	var lado := Vector3.UP.cross(normal).normalized()
	var malla := _malla(Vector3(medida.x, medida.y, 0.03), placa)
	malla.basis = Basis(lado, Vector3.UP, normal)
	malla.position = donde + normal * (0.03 if en_muro else 0.0)
	# Marco negro
	var marco := _liso(Color(0.05, 0.05, 0.05))
	var borde := _malla(Vector3(medida.x + 0.08, medida.y + 0.08, 0.02), marco)
	borde.basis = malla.basis
	borde.position = malla.position - normal * 0.01
	_texto(texto, malla.position + normal * 0.02, normal, tam, tinta)


func _texto(texto: String, donde: Vector3, normal: Vector3, tam: float, color: Color) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = 64
	etiqueta.pixel_size = tam / 64.0
	etiqueta.modulate = color
	etiqueta.outline_size = 0
	etiqueta.shaded = true
	etiqueta.double_sided = false
	etiqueta.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if normal != Vector3.UP:
		var lado := Vector3.UP.cross(normal).normalized()
		etiqueta.basis = Basis(lado, Vector3.UP, normal)
	etiqueta.position = donde
	add_child(etiqueta)
	return etiqueta


# `muro` = [centro, normal, a lo largo]. El Decal proyecta hacia su -Y: Y = normal, X = a lo
# largo, Z = abajo
func _decal(muro: Array, a_lo_largo: float, y: float, tamano: Vector2, textura: Texture2D, color: Color) -> void:
	var decal := Decal.new()
	decal.texture_albedo = textura
	decal.modulate = color
	var normal: Vector3 = muro[1]
	var lado: Vector3 = muro[2]
	decal.basis = Basis(lado, normal, lado.cross(normal))
	decal.size = Vector3(tamano.x, 0.4, tamano.y)
	decal.position = muro[0] + lado * a_lo_largo + Vector3.UP * y + normal * 0.1
	decal.cull_mask = 1
	add_child(decal)


# Un material liso de un color, compartido (para que las piezas se junten en una malla)
func _liso(color: Color) -> StandardMaterial3D:
	if not _colores.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		_colores[color] = m
	return _colores[color]


# La gota del SVG es negra (currentColor): se pinta del azul de GelA conservando su alfa
func _gota_azul() -> Texture2D:
	var original := load(GOTA) as Texture2D
	if original == null:
		return null
	var imagen := original.get_image()
	if imagen.is_compressed():
		imagen.decompress()
	imagen.convert(Image.FORMAT_RGBA8)
	for y in imagen.get_height():
		for x in imagen.get_width():
			var a := imagen.get_pixel(x, y).a
			imagen.set_pixel(x, y, Color(COLOR_GELA, a))
	return ImageTexture.create_from_image(imagen)


# Ruido sin costuras en escala de grises, para los shaders
func _ruido_tex(lado: int, frecuencia: float, octavas: int, semilla: int) -> ImageTexture:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = frecuencia
	ruido.fractal_octaves = octavas
	return ImageTexture.create_from_image(ruido.get_seamless_image(lado, lado))


# Ruido sin costuras de `lado` px alrededor de `tono` (+- `varia`), con `piedras` de piedritas
# oscuras y claras y, si `junta`, una raya oscura en los bordes (la junta del colado)
func _textura_ruido(lado: int, tono: float, varia: float, piedras: float, junta: bool, semilla: int) -> ImageTexture:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla
	ruido.frequency = 0.035
	ruido.fractal_octaves = 4
	var base := ruido.get_seamless_image(lado, lado)
	var fino := FastNoiseLite.new()
	fino.seed = semilla + 1
	fino.frequency = 0.3
	var grano := fino.get_seamless_image(lado, lado)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var imagen := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var v := tono + (base.get_pixel(x, y).r - 0.5) * 2.0 * varia + (grano.get_pixel(x, y).r - 0.5) * varia * 0.6
			if piedras > 0.0 and rng.randf() < piedras:
				v += rng.randf_range(-0.12, 0.08)
			if junta and (x == 0 or y == 0):
				v *= 0.55
			imagen.set_pixel(x, y, Color(v, v, v * 1.02))
	return ImageTexture.create_from_image(imagen)
