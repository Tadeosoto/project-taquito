class_name Maquinita
extends StaticBody3D

# La maquinita de frutas de afuera de las tiendas (docs/especificaciones.md 4.6). Origen
# al centro de la base, frente a +Z. Te acercas, Espacio y TragamonedasUI te deja jugar
# con los botones de la maquina; Tragamonedas (la placa) decide y aqui solo se muestra.
#
# COOP: todo lo que los demas tendrian que ver pasa por los mostrar_*() y
# elegir/apretar_boton(), que no deciden nada: se vuelven @rpc("call_local") y la placa
# la corre el servidor. Los focos, botones y contadores se ven en el mueble y los cohetes
# (Cohetes.gd) en el cielo, asi que se notarian desde lejos sin hacer nada mas.
#
# Lo que se le nota por fuera (mostrar_estado): con monedas en la charola esta normal;
# charola vacia y luces tenues = sin monedas, no va a pagar; veladora encendida arriba =
# el siguiente tiro gana seguro.

# Regiones del atlas (px), las dibuja tools/map_import/make_maquinita.gd
const ATLAS := 1024.0
const PANEL := Rect2i(0, 0, 480, 640)
const BOTONES := Rect2i(480, 0, 480, 216)
const ABAJO := Rect2i(0, 640, 512, 384)
const CHAROLA := Rect2i(512, 640, 256, 64)
const CUERPO := Rect2i(768, 640, 256, 256)
const COLOR_VERDE := Rect2i(512, 704, 64, 64)
const COLOR_NARANJA := Rect2i(576, 704, 64, 64)
const COLOR_AZUL := Rect2i(640, 704, 64, 64)
const COLOR_ROJO := Rect2i(704, 704, 64, 64)
const COLOR_DORADO := Rect2i(512, 768, 64, 64)
const COLOR_MONEDA := Rect2i(576, 768, 64, 64)
const COLOR_METAL := Rect2i(640, 768, 64, 64)
const COLOR_VELA := Rect2i(704, 768, 64, 64)
const ESTAMPA := Rect2i(512, 832, 64, 96)
# Dentro de PANEL; shaders/ps1_maquinita.gdshader tiene los mismos numeros
const TABLERO_ORIGEN := Vector2i(86, 172)
const TABLERO_CASILLA := 44
const CONTADOR_PREMIOS := Rect2i(60, 116, 164, 44)
const CONTADOR_CREDITOS := Rect2i(256, 116, 164, 44)
const APUESTA_X := 40
const APUESTA_Y := 490
const APUESTA_COLUMNA := 50
const APUESTA_LADO := 32

const ANCHO := 0.64
const FONDO := 0.6
# Lo alto del panel en medio y a los lados: arriba es curvo como la foto
const ALTO := 1.98
const ALTO_HOMBRO := 1.86
const PANEL_ABAJO := 1.16
# Lo que baja la curva en px del panel, de medio a la orilla
const CURVA_PANEL_PX := (ALTO - ALTO_HOMBRO) / (ALTO - PANEL_ABAJO) * 640.0
const RADIO_JUGAR := 1.3
# Colores de las fotos del usuario
const COLORES := [Color(1.0, 0.82, 0.1), Color(0.72, 0.08, 0.08)]

# La rampa de los botones: de (y, z) a (y, z)
const RAMPA_DESDE := Vector2(1.0, 0.3)
const RAMPA_HASTA := Vector2(PANEL_ABAJO, 0.06)
const RAMPA := 0.288
# Botones: 0-7 las frutas abajo (4 azules, 4 rojos), 8-13 arriba (3 verdes, 3 naranjas).
# Los que no estan aqui son de adorno (el shader los deja apagados)
const BOTON_TIRAR := 8
const BOTON_QUITAR := 11
const BOTON_SALIR := 13
const BOTON_MEDIDA := Vector2(0.066, 0.055)
const BOTON_ALTO := 0.012

# Duracion del giro (s): el foco arranca rapido y va frenando hasta su destino
const GIRO := 4.0
const VUELTAS := 3
const APRETAR := 0.12
# Luz de la maquina sin monedas
const ENERGIA_SIN_MONEDAS := 0.3

signal giro_terminado

static var _malla: ArrayMesh
static var _malla_monedas: ArrayMesh
static var _malla_veladora: ArrayMesh
static var _material: ShaderMaterial

# Quien es en el mapa (`origen` del negocio): la placa y su caja no se pierden al alejarte
var id := ""
var placa: Tragamonedas
# Sigue el festejo de mostrar_premio
var mostrando_premio := false

var _malla_instancia: MeshInstance3D
var _monedas: MeshInstance3D
var _veladora: Node3D
var _apretado_tween: Tween
var _player_inside := false
var _ocupada := false
var _aviso: Label3D
var _voz: AudioStreamPlayer3D


func _ready() -> void:
	placa = Tragamonedas.de(id)
	add_to_group("interactuable")
	_malla_instancia = MeshInstance3D.new()
	_malla_instancia.mesh = malla()
	_malla_instancia.material_override = _material_compartido()
	var color: Color = COLORES[absi(hash(id)) % COLORES.size()]
	_malla_instancia.set_instance_shader_parameter("color_gabinete", Vector3(color.r, color.g, color.b))
	add_child(_malla_instancia)

	_monedas = MeshInstance3D.new()
	_monedas.mesh = malla_monedas()
	_monedas.material_override = _material_compartido()
	add_child(_monedas)

	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO, ALTO, FONDO)
	forma.shape = caja
	forma.position.y = ALTO / 2.0
	add_child(forma)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var zona := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = RADIO_JUGAR
	cilindro.height = 2.0
	zona.shape = cilindro
	zona.position = Vector3(0.0, 1.0, 0.7)
	area.add_child(zona)
	add_child(area)
	area.body_entered.connect(_al_entrar)
	area.body_exited.connect(_al_salir)

	_aviso = Label3D.new()
	_aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso.no_depth_test = true
	_aviso.pixel_size = 0.008
	_aviso.position = Vector3(0.0, 1.5, 0.45)
	_aviso.visible = false
	add_child(_aviso)

	_voz = AudioStreamPlayer3D.new()
	_voz.position.y = 1.2
	_voz.unit_size = 4.0
	_voz.max_distance = 40.0
	add_child(_voz)
	mostrar_estado(placa.estado())


# --- Lo que se ve (ver COOP arriba) ---

# El foco da VUELTAS y frena hasta `destino`. Termina con la señal giro_terminado
func mostrar_giro(destino: int, duracion := GIRO) -> void:
	var total := Tragamonedas.TABLERO.size()
	var desde := _foco_actual()
	var pasos := VUELTAS * total + posmod(destino - desde, total)
	var anterior := 0.0
	for i in range(1, pasos + 1):
		# Freno: el tiempo de cada paso crece hacia el final
		var t := float(i) / pasos
		var momento := duracion * pow(t, 2.2)
		await get_tree().create_timer(maxf(momento - anterior, 0.01)).timeout
		anterior = momento
		_poner_foco((desde + i) % total)
		_sonar("paso")
	giro_terminado.emit()


# El tablero festeja, PREMIOS cuenta mientras caen las monedas y, si ganaste dinero, cohetes
func mostrar_premio(premio: int, gano: bool, cohetes: int) -> void:
	mostrando_premio = true
	mostrar_contador_premios(0)
	if gano:
		_malla_instancia.set_instance_shader_parameter("festejo", 1.0)
		if cohetes > 0:
			Cohetes.lanzar(self, global_transform * Vector3(0.0, ALTO, 1.2), cohetes)
	if premio > 0:
		const CAIDAS := 25
		var caidas := mini(premio, CAIDAS)
		for i in caidas:
			_sonar("moneda")
			mostrar_contador_premios(premio * (i + 1) / caidas)
			await get_tree().create_timer(0.07).timeout
	else:
		_sonar("perder")
	if gano:
		await get_tree().create_timer(1.5).timeout
		_malla_instancia.set_instance_shader_parameter("festejo", 0.0)
	mostrando_premio = false


# Las pistas de afuera: monedas en la charola, luces y veladora
func mostrar_estado(estado: Tragamonedas.Estado) -> void:
	_monedas.visible = estado != Tragamonedas.Estado.SIN_MONEDAS
	_malla_instancia.set_instance_shader_parameter("energia", ENERGIA_SIN_MONEDAS if estado == Tragamonedas.Estado.SIN_MONEDAS else 1.0)
	if estado == Tragamonedas.Estado.SEGURA and _veladora == null:
		_veladora = _armar_veladora()
		add_child(_veladora)
	elif estado != Tragamonedas.Estado.SEGURA and _veladora:
		_veladora.queue_free()
		_veladora = null


func mostrar_contador_creditos(valor: int) -> void:
	_malla_instancia.set_instance_shader_parameter("creditos", clampi(valor, 0, 9999))


func mostrar_contador_premios(valor: int) -> void:
	_malla_instancia.set_instance_shader_parameter("premios", clampi(valor, 0, 9999))


# Los contadores de la hilera, de 1 digito por fruta, en un solo entero de 4 bits cada uno
func mostrar_apuestas(apuestas: Dictionary) -> void:
	var bits := 0
	for i in Tragamonedas.FRUTAS.size():
		bits |= (clampi(apuestas.get(Tragamonedas.FRUTAS[i], 0), 0, 9) as int) << (i * 4)
	# El shader los lee como int de 32 bits con signo
	_malla_instancia.set_instance_shader_parameter("apuestas", bits - (1 << 32) if bits >= (1 << 31) else bits)


func elegir_boton(boton: int) -> void:
	_malla_instancia.set_instance_shader_parameter("boton_elegido", boton)


# Se hunde y brilla un momento
func apretar_boton(boton: int) -> void:
	_malla_instancia.set_instance_shader_parameter("boton_apretado", boton)
	_sonar("boton")
	if _apretado_tween and _apretado_tween.is_valid():
		_apretado_tween.kill()
	_apretado_tween = create_tween()
	_apretado_tween.tween_interval(APRETAR)
	_apretado_tween.tween_callback(func() -> void:
		_malla_instancia.set_instance_shader_parameter("boton_apretado", -1))


# Sola otra vez: la luz de adorno y los contadores en cero
func descansar() -> void:
	_poner_foco(-1)
	elegir_boton(-1)
	mostrar_contador_creditos(0)
	mostrar_contador_premios(0)
	mostrar_apuestas({})


func _poner_foco(foco: int) -> void:
	_malla_instancia.set_instance_shader_parameter("foco", foco)


func _foco_actual() -> int:
	var foco: Variant = _malla_instancia.get_instance_shader_parameter("foco")
	return foco if foco != null and foco >= 0 else 0


func _sonar(nombre: String) -> void:
	_voz.stream = Sonidos.sonido(nombre)
	_voz.play()


# La veladora de encima, con su lucecita: solo existe en las maquinas seguras
func _armar_veladora() -> Node3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla_veladora()
	nodo.material_override = _material_compartido()
	nodo.position = Vector3(0.08, _alto_panel(0.08) - 0.005, -0.1)
	nodo.visibility_range_end = 150.0
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 0.5
	luz.omni_range = 1.4
	luz.position.y = 0.2
	nodo.add_child(luz)
	return nodo


# --- Jugar ---

func is_player_inside() -> bool:
	return _player_inside and not _ocupada


func interact() -> void:
	if _ocupada:
		return
	_ocupada = true
	_aviso.visible = false
	# Con load y no por su nombre: usa la Cartera, y los scripts de tools/ que cargan
	# MapPuntos (huellas_tiendas.gd, con -s) todavia no tienen autoloads
	var ui: CanvasLayer = load("res://scripts/map/TragamonedasUI.gd").new()
	ui.set("maquinita", self)
	ui.tree_exited.connect(func() -> void:
		_ocupada = false
		_actualizar_aviso())
	get_tree().current_scene.add_child(ui)


func _al_entrar(body: Node3D) -> void:
	if body is Player:
		_player_inside = true
		_actualizar_aviso()


func _al_salir(body: Node3D) -> void:
	if body is Player:
		_player_inside = false
		_actualizar_aviso()


func _actualizar_aviso() -> void:
	if not is_inside_tree():
		return
	var tecla := "Espacio" if Input.get_connected_joypads().is_empty() else "X"
	_aviso.text = "%s: jugar" % tecla
	_aviso.visible = _player_inside and not _ocupada


# --- Tablero y botones: lo usa tambien tools/map_import/make_maquinita.gd ---

# La casilla (x, y) del tablero de 7 x 7 del foco `i`, en sentido del reloj desde arriba
# a la izquierda. El shader hace lo contrario en foco_de_casilla
static func celda_foco(i: int) -> Vector2i:
	if i < 7:
		return Vector2i(i, 0)
	if i < 12:
		return Vector2i(6, i - 6)
	if i < 19:
		return Vector2i(18 - i, 6)
	return Vector2i(0, 24 - i)


# Centro del boton en la rampa: m a lo ancho y m hacia arriba de la rampa
static func boton_centro(boton: int) -> Vector2:
	if boton < 8:
		return Vector2(-0.259 + boton * 0.074, 0.115)
	var i := boton - 8
	return Vector2((-0.24 if i < 3 else 0.03) + (i % 3) * 0.07, 0.205)


# --- La malla, una para todas ---

static func _material_compartido() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/ps1_maquinita.gdshader")
		_material.set_shader_parameter("atlas", load("res://textures/map/maquinita.png"))
		_material.set_shader_parameter("wobble_enabled", false)
		_material.set_shader_parameter("affine_enabled", false)
		_material.set_shader_parameter("snap_resolution", 240.0)
	return _material


static func malla() -> ArrayMesh:
	if _malla:
		return _malla
	var st := _nueva()
	var x := ANCHO / 2.0
	var atras := -FONDO / 2.0
	# Perfil de lado, de abajo a arriba por el frente (y, z)
	var pata := Vector2(0.0, 0.2)
	var abajo_arriba := Vector2(0.86, 0.2)
	var charola_abajo := Vector2(0.86, RAMPA_DESDE.y)
	var hombro := Vector2(ALTO_HOMBRO, _z_panel(ALTO_HOMBRO))
	# Frente de abajo, debajo de la repisa, la franja, la rampa de los botones
	_cara(st, x, pata, abajo_arriba, ABAJO, false)
	_cara(st, x, abajo_arriba, charola_abajo, CUERPO, true)
	_cara(st, x, charola_abajo, RAMPA_DESDE, CHAROLA, false)
	_cara(st, x, RAMPA_DESDE, RAMPA_HASTA, BOTONES, false)
	# Espalda de abajo; el panel, su tapa y su espalda se hacen por tiras por la curva
	_cara(st, x, Vector2(ALTO_HOMBRO, atras), Vector2(0.0, atras), CUERPO, true)
	_arriba_curvo(st, x, atras)
	# Los dos lados (el perfil de arriba, cerrado), de una pieza
	_lados(st, x, PackedVector2Array([Vector2(0.0, atras), pata, abajo_arriba, charola_abajo,
			RAMPA_DESDE, RAMPA_HASTA, hombro, Vector2(ALTO_HOMBRO, atras)]))
	# Los rieles dorados de los lados, como los de la foto, y la charola de las monedas
	var dorado := Color.BLACK
	for lado in [-1.0, 1.0]:
		var centro: float = lado * x
		_caja(st, Vector3(centro - 0.018, 0.9, atras), Vector3(centro + 0.018, PANEL_ABAJO, RAMPA_DESDE.y + 0.012), COLOR_DORADO, dorado)
		_caja(st, Vector3(centro - 0.018, PANEL_ABAJO, atras), Vector3(centro + 0.018, ALTO_HOMBRO + 0.05, RAMPA_HASTA.y + 0.03), COLOR_DORADO, dorado)
	_caja(st, Vector3(-0.17, 0.46, 0.2), Vector3(0.17, 0.5, 0.34), COLOR_METAL, dorado)
	_caja(st, Vector3(-0.17, 0.5, 0.32), Vector3(0.17, 0.54, 0.34), COLOR_METAL, dorado)
	for boton in 14:
		_boton(st, boton)
	_malla = _cerrar(st)
	return _malla


# Unas cuantas monedas regadas en la charola: se apagan si la maquina no tiene
static func malla_monedas() -> ArrayMesh:
	if _malla_monedas:
		return _malla_monedas
	var st := _nueva()
	var azar := RandomNumberGenerator.new()
	azar.seed = 5
	for i in 16:
		var c := Vector3(azar.randf_range(-0.14, 0.14), 0.5 + azar.randi_range(0, 2) * 0.007, azar.randf_range(0.215, 0.31))
		_caja(st, c - Vector3(0.016, 0.0, 0.016), c + Vector3(0.016, 0.006, 0.016), COLOR_MONEDA, Color.BLACK)
	_malla_monedas = _cerrar(st)
	return _malla_monedas


# La veladora (vaso rojo y llama) y su estampita recargada; origen en la tapa del mueble
static func malla_veladora() -> ArrayMesh:
	if _malla_veladora:
		return _malla_veladora
	var st := _nueva()
	const LADOS := 8
	var uv := _uv(COLOR_VELA)
	var r := 0.032
	var alto := 0.13
	for i in LADOS:
		var a0 := TAU * i / LADOS
		var a1 := TAU * (i + 1) / LADOS
		var p0 := Vector3(sin(a0) * r, 0.0, cos(a0) * r)
		var p1 := Vector3(sin(a1) * r, 0.0, cos(a1) * r)
		_quad(st, [p0, p0 + Vector3.UP * alto, p1 + Vector3.UP * alto, p1], uv, Color.BLACK)
	# Tapa del vaso: la cera, y dos cuadros cruzados para la llama
	var tapa := Vector3.UP * alto
	for i in LADOS:
		var a0 := TAU * i / LADOS
		var a1 := TAU * (i + 1) / LADOS
		for v: Vector3 in [tapa, tapa + Vector3(sin(a1) * r, 0.0, cos(a1) * r), tapa + Vector3(sin(a0) * r, 0.0, cos(a0) * r)]:
			st.set_color(Color.BLACK)
			st.set_uv(uv.position)
			st.add_vertex(v)
	var llama := Color(0.0, 0.0, 1.0)
	for eje: Vector3 in [Vector3(0.016, 0.0, 0.0), Vector3(0.0, 0.0, 0.016)]:
		var a := tapa - eje
		var b := tapa + eje
		var punta := tapa + Vector3.UP * 0.06
		for v: Vector3 in [a, punta, b, b, punta, a]:
			st.set_color(llama)
			st.set_uv(uv.position)
			st.add_vertex(v)
	# La estampita recargada en el vaso
	var e := _uv(ESTAMPA)
	var base := Vector3(-0.1, 0.0, 0.0)
	var ancho := Vector3(0.062, 0.0, 0.0)
	var subir := Vector3(0.0, 0.095, -0.025)
	_quad(st, [base, base + subir, base + subir + ancho, base + ancho], e, Color.BLACK)
	_quad(st, [base + ancho, base + ancho + subir, base + subir, base], _uv(COLOR_METAL), Color.BLACK)
	_malla_veladora = _cerrar(st)
	return _malla_veladora


static func _nueva() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cada cara plana: se ven las aristas, como en PS1
	st.set_smooth_group(-1)
	return st


static func _cerrar(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


# Cuatro esquinas en sentido del reloj vistas desde afuera, con su region del atlas
static func _quad(st: SurfaceTool, p: Array, uv: Rect2, color: Color) -> void:
	var t := [Vector2(uv.position.x, uv.end.y), uv.position, Vector2(uv.end.x, uv.position.y), uv.end]
	for i in [0, 1, 3, 3, 1, 2]:
		st.set_color(color)
		st.set_uv(t[i])
		st.add_vertex(p[i])


static func _caja(st: SurfaceTool, a: Vector3, b: Vector3, region: Rect2i, color: Color) -> void:
	var uv := _uv(region)
	_quad(st, [Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z)], uv, color)
	_quad(st, [Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, a.y, a.z)], uv, color)
	_quad(st, [Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), Vector3(b.x, a.y, a.z)], uv, color)
	_quad(st, [Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)], uv, color)
	_quad(st, [Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z)], uv, color)
	_quad(st, [Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z)], uv, color)


# Un cuadro de lado a lado entre dos puntos del perfil (y, z), con su region del atlas.
# `pinta`: lleva el color del gabinete
static func _cara(st: SurfaceTool, x: float, a: Vector2, b: Vector2, region: Rect2i, pinta: bool) -> void:
	_quad(st, [Vector3(-x, a.x, a.y), Vector3(-x, b.x, b.y), Vector3(x, b.x, b.y), Vector3(x, a.x, a.y)],
			_uv(region), Color(1.0 if pinta else 0.0, 0.0, 0.0))


static func _alto_panel(x: float) -> float:
	var u := x / (ANCHO / 2.0)
	return ALTO - (ALTO - ALTO_HOMBRO) * u * u


static func _z_panel(y: float) -> float:
	return lerpf(RAMPA_HASTA.y, 0.0, (y - PANEL_ABAJO) / (ALTO - PANEL_ABAJO))


# El panel, su tapa y su espalda, en tiras a lo ancho para la curva de arriba
static func _arriba_curvo(st: SurfaceTool, x: float, atras: float) -> void:
	const TIRAS := 12
	var uv := _uv(PANEL)
	var pintado := Color(1.0, 0.0, 0.0)
	var liso := _uv(CUERPO)
	for i in TIRAS:
		var x0 := lerpf(-x, x, float(i) / TIRAS)
		var x1 := lerpf(-x, x, float(i + 1) / TIRAS)
		var y0 := _alto_panel(x0)
		var y1 := _alto_panel(x1)
		var abajo0 := Vector3(x0, PANEL_ABAJO, RAMPA_HASTA.y)
		var abajo1 := Vector3(x1, PANEL_ABAJO, RAMPA_HASTA.y)
		var arriba0 := Vector3(x0, y0, _z_panel(y0))
		var arriba1 := Vector3(x1, y1, _z_panel(y1))
		# Frente con el dibujo: uv plano, para que la curva recorte el dibujo sin torcerlo
		var u0 := lerpf(uv.position.x, uv.end.x, float(i) / TIRAS)
		var u1 := lerpf(uv.position.x, uv.end.x, float(i + 1) / TIRAS)
		var v0 := uv.position.y + uv.size.y * (ALTO - y0) / (ALTO - PANEL_ABAJO)
		var v1 := uv.position.y + uv.size.y * (ALTO - y1) / (ALTO - PANEL_ABAJO)
		var puntos := [abajo0, arriba0, arriba1, arriba1, abajo1, abajo0]
		var uvs := [Vector2(u0, uv.end.y), Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v1), Vector2(u1, uv.end.y), Vector2(u0, uv.end.y)]
		for j in puntos.size():
			st.set_color(Color.BLACK)
			st.set_uv(uvs[j])
			st.add_vertex(puntos[j])
		# Tapa y espalda arriba del hombro
		var atras0 := Vector3(x0, y0, atras)
		var atras1 := Vector3(x1, y1, atras)
		_quad(st, [arriba0, atras0, atras1, arriba1], liso, pintado)
		_quad(st, [atras1, atras0, Vector3(x0, ALTO_HOMBRO, atras), Vector3(x1, ALTO_HOMBRO, atras)], liso, pintado)


# Una caja sobre la rampa, de su color, con su numero en el verde del color de vertice
static func _boton(st: SurfaceTool, boton: int) -> void:
	var centro := boton_centro(boton)
	var origen := Vector3(centro.x, RAMPA_DESDE.x, RAMPA_DESDE.y)
	var d := Vector3(0.0, RAMPA_HASTA.x - RAMPA_DESDE.x, RAMPA_HASTA.y - RAMPA_DESDE.y).normalized()
	var n := Vector3(0.0, 0.832, 0.555)
	var region := COLOR_AZUL if boton < 4 else (COLOR_ROJO if boton < 8 else (COLOR_VERDE if boton < 11 else COLOR_NARANJA))
	var uv := _uv(region)
	var color := Color(0.0, (boton + 1) / 16.0, 0.0)
	var s := Vector3(BOTON_MEDIDA.x / 2.0, 0.0, 0.0)
	var t := d * BOTON_MEDIDA.y / 2.0
	var c := origen + d * centro.y
	var alto := n * BOTON_ALTO
	# Bajo el tablero tambien, para que hundido no se abra un hueco
	var base := -n * 0.012
	_quad(st, [c - s - t + alto, c - s + t + alto, c + s + t + alto, c + s - t + alto], uv, color)
	_quad(st, [c - s - t + base, c - s - t + alto, c + s - t + alto, c + s - t + base], uv, color)
	_quad(st, [c + s + t + base, c + s + t + alto, c - s + t + alto, c - s + t + base], uv, color)
	_quad(st, [c - s + t + base, c - s + t + alto, c - s - t + alto, c - s - t + base], uv, color)
	_quad(st, [c + s - t + base, c + s - t + alto, c + s + t + alto, c + s + t + base], uv, color)


static func _lados(st: SurfaceTool, x: float, perfil: PackedVector2Array) -> void:
	var triangulos := Geometry2D.triangulate_polygon(perfil)
	var uv := _uv(CUERPO)
	for lado in [-1.0, 1.0]:
		var orden: Array = Array(triangulos)
		if lado < 0.0:
			orden.reverse()
		for i: int in orden:
			var punto := perfil[i]
			st.set_color(Color(1.0, 0.0, 0.0))
			st.set_uv(uv.position + uv.size * Vector2(punto.y / FONDO + 0.5, punto.x / ALTO))
			st.add_vertex(Vector3(lado * x, punto.x, punto.y))


static func _uv(region: Rect2i) -> Rect2:
	return Rect2(Vector2(region.position) / ATLAS, Vector2(region.size) / ATLAS)
