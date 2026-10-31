class_name Refugio
extends Node3D

# El refugio (docs/especificaciones.md 1.3): un patio con barda, una entrada por lado y en
# medio el tinaco. Si lo tumban se acaba la partida (Partida.gd). Una entrada por lado
# para que los zombis, que no tienen rutas, siempre tengan una derecho (Zombie._destino).
# Origen al centro, en el piso. Se arma con cajas y un solo material por color.

signal cayo
signal aviso(texto: String)

const MEDIO := 7.0            # medio lado del patio
const BARDA_ALTO := 2.6
const BARDA_GRUESO := 0.4
const TINACO_VIDA := 300
const TINACO_AL_AMANECER := 100
const TINACO_RADIO := 0.8
const TINACO_ALTO := 1.8
const COLOR_BARDA := Color(0.55, 0.52, 0.47)
const COLOR_TINACO := Color(0.1, 0.1, 0.12)
const COLOR_TABLA := Color(0.5, 0.34, 0.18)
const SHADER := preload("res://shaders/ps1_combined.gdshader")
# Cuando el jugador anda lejos no hay zombis aqui (Zombis.LEJOS), y el ataque se simula:
# dano por segundo segun la noche, repartido entre las entradas
const ASEDIO := [1.0, 1.5, 2.0]
const ASEDIO_CAMBIA := 10.0   # s atacando la misma entrada

var vida := TINACO_VIDA
var noche := 0                # la pone Partida.gd

var entradas: Array[EntradaRefugio] = []
var _jugador: Node3D
var _ciclo: Node
var _caido := false
var _avisado := false
var _blanco_asedio: EntradaRefugio
var _cambia_en := 0.0
var _resto := 0.0


func _enter_tree() -> void:
	add_to_group("refugio")


func _ready() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador")
	_ciclo = get_tree().get_first_node_in_group("ciclo")
	if _ciclo:
		_ciclo.amanecio.connect(_amanecer)
	var barda := _material(COLOR_BARDA)
	var hueco := EntradaRefugio.ANCHO
	var tramo := MEDIO - hueco / 2.0
	var tabla := _material(COLOR_TABLA)
	for i in 4:
		var lado := Node3D.new()
		lado.rotation.y = i * PI / 2.0
		add_child(lado)
		for signo in [-1.0, 1.0]:
			_caja(lado, Vector3(tramo + BARDA_GRUESO, BARDA_ALTO, BARDA_GRUESO),
				Vector3(signo * (hueco + tramo) / 2.0, BARDA_ALTO / 2.0, MEDIO), barda)
		var entrada := EntradaRefugio.new()
		entrada.position = Vector3(0.0, 0.0, MEDIO)
		lado.add_child(entrada)
		entrada.armar(tabla)
		entrada.debil.connect(func() -> void: aviso.emit("¡Están tumbando una entrada!"))
		entrada.rota.connect(func() -> void: aviso.emit("¡Tumbaron una entrada!"))
		entradas.append(entrada)
	_tinaco()


func _physics_process(delta: float) -> void:
	if _caido or _ciclo == null or not _ciclo.es_noche() or noche <= 0 or _jugador == null:
		return
	if _jugador.global_position.distance_to(global_position) <= Zombis.LEJOS:
		return
	_cambia_en -= delta
	_resto += ASEDIO[mini(noche, ASEDIO.size()) - 1] * delta
	if _resto < 1.0:
		return
	var dano := int(_resto)
	_resto -= dano
	for entrada in entradas:
		if entrada.abierta():
			recibir_golpe(dano)
			return
	if _blanco_asedio == null or _cambia_en <= 0.0:
		_blanco_asedio = entradas.pick_random()
		_cambia_en = ASEDIO_CAMBIA
	_blanco_asedio.recibir_golpe(dano)


# Lo que le pega un zombi al tinaco
func recibir_golpe(dano: int) -> void:
	if _caido:
		return
	vida = maxi(vida - dano, 0)
	if vida <= 0:
		_caido = true
		cayo.emit()
	elif vida <= TINACO_VIDA / 2 and not _avisado:
		_avisado = true
		aviso.emit("¡El tinaco no aguanta!")


func adentro(punto: Vector3, margen := 0.0) -> bool:
	var local := to_local(punto)
	return absf(local.x) <= MEDIO + margen and absf(local.z) <= MEDIO + margen


func entrada_cercana(punto: Vector3) -> EntradaRefugio:
	var mejor: EntradaRefugio = null
	for entrada in entradas:
		if mejor == null or entrada.global_position.distance_squared_to(punto) < mejor.global_position.distance_squared_to(punto):
			mejor = entrada
	return mejor


# Donde reapareces: adentro, a un lado del tinaco. El origen del jugador esta a 1 m del piso
func punto_regreso() -> Transform3D:
	return Transform3D(global_basis, to_global(Vector3(3.0, 1.2, 3.0)))


func reiniciar() -> void:
	vida = TINACO_VIDA
	noche = 0
	_caido = false
	_avisado = false
	for entrada in entradas:
		entrada.reiniciar()


func _amanecer() -> void:
	vida = mini(vida + TINACO_AL_AMANECER, TINACO_VIDA)
	_avisado = false


func _tinaco() -> void:
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = TINACO_RADIO
	cilindro.height = TINACO_ALTO
	forma.shape = cilindro
	forma.position.y = TINACO_ALTO / 2.0
	cuerpo.add_child(forma)
	var malla := CylinderMesh.new()
	malla.top_radius = TINACO_RADIO * 0.85
	malla.bottom_radius = TINACO_RADIO
	malla.height = TINACO_ALTO
	malla.radial_segments = 10
	malla.rings = 1
	var tinaco := MeshInstance3D.new()
	tinaco.mesh = malla
	tinaco.material_override = _material(COLOR_TINACO)
	tinaco.position.y = TINACO_ALTO / 2.0
	cuerpo.add_child(tinaco)
	var letrero := Label3D.new()
	letrero.text = "TINACO"
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.modulate = Color(1.0, 0.85, 0.1)
	letrero.position.y = TINACO_ALTO + 0.4
	add_child(letrero)


func _caja(padre: Node3D, medida: Vector3, donde: Vector3, material: Material) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.position = donde
	padre.add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medida
	forma.shape = caja
	cuerpo.add_child(forma)
	var malla := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	cubo.size = medida
	malla.mesh = cubo
	malla.material_override = material
	cuerpo.add_child(malla)


func _material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("wobble_enabled", false)
	material.set_shader_parameter("affine_enabled", false)
	return material
