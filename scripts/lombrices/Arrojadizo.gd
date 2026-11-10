class_name Arrojadizo
extends Node3D
# Lo que avienta el Lanzador (y lo que escupe la Madre): vuela a mano, sin cuerpo de fisica. La
# molotov va en parabola y revienta en fuego (ZonaLombrices). El escupitajo de la Madre (tipo 3) es
# como un balazo: derecho, sin gravedad, y si te da te baja `dano`; no deja charco (JJ).

const GRAVEDAD := 14.0
const VIDA := 4.0
const SAL_RADIO := 1.5
const SAL_DURA := 12.0
const FUEGO_RADIO := 2.0
const FUEGO_DURA := 5.0
# El escupitajo: una gota que se estira con la velocidad y tiembla, con una cola de gotitas, de
# Serenol como agua radioactiva del azul de las espinas (shaders/escupitajo.gdshader)
const ESCUPE_COLOR := Color(0.18, 0.77, 1.0)
# A escala de la Madre (MadreCarcamo.ESCALA): crece con ella
const ESCUPE_RADIO := 0.15 * MadreCarcamo.ESCALA
const ESCUPE_ESTIRA := 0.07      # x la rapidez: cuanto se alarga
const ESCUPE_COLA := [0.1 * MadreCarcamo.ESCALA, 0.075 * MadreCarcamo.ESCALA, 0.055 * MadreCarcamo.ESCALA, 0.04 * MadreCarcamo.ESCALA]   # radio de cada gotita de la cola
const ESCUPE_COLA_CADA := 1      # cuadros de atraso entre gotitas

static var _material_escupe: ShaderMaterial

var tipo := 1          # InventoryItemData.arrojar: 1 sal, 2 molotov; 3 lodo (la Madre)
var dano := 0           # el escupitajo: lo que te baja si te da
var velocidad := Vector3.ZERO
var _edad := 0.0
var _excluir: Array[RID] = []
var _gota: MeshInstance3D
var _cola: Array[MeshInstance3D] = []
var _rastro := PackedVector3Array()


static func lanzar(padre: Node, desde: Vector3, vel: Vector3, tipo_: int, excluir: Array[RID]) -> Arrojadizo:
	var a := Arrojadizo.new()
	a.tipo = tipo_
	a.velocidad = vel
	a._excluir = excluir
	padre.add_child(a)
	a.global_position = desde
	return a


func _ready() -> void:
	var malla := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if tipo == 2:
		var botella := CylinderMesh.new()
		botella.top_radius = 0.03
		botella.bottom_radius = 0.06
		botella.height = 0.28
		botella.radial_segments = 6
		malla.mesh = botella
		material.albedo_color = Color(0.25, 0.4, 0.15)
		# La mecha prendida
		var mecha := OmniLight3D.new()
		mecha.light_color = Color(1.0, 0.6, 0.2)
		mecha.light_energy = 1.2
		mecha.omni_range = 2.0
		mecha.position.y = 0.18
		add_child(mecha)
	elif tipo == 3:
		malla.free()
		_armar_escupitajo()
		return
	else:
		var bolsa := BoxMesh.new()
		bolsa.size = Vector3(0.14, 0.2, 0.08)
		malla.mesh = bolsa
		material.albedo_color = Color(0.9, 0.9, 0.95)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	malla.material_override = material
	add_child(malla)


func _physics_process(delta: float) -> void:
	_edad += delta
	if tipo != 3:
		velocidad.y -= GRAVEDAD * delta
	var desde := global_position
	var hasta := desde + velocidad * delta
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta, 1, _excluir)
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	if tipo == 3:
		_mover_escupitajo(desde)
	else:
		rotation += Vector3(7.0, 3.0, 0.0) * delta
	if pego:
		if tipo == 3 and pego.collider and pego.collider.is_in_group("jugador") and pego.collider.has_method("recibir_dano"):
			pego.collider.recibir_dano(dano, desde, 0.6)
		_reventar(pego.position)
		return
	global_position = hasta
	if _edad > VIDA:
		_reventar(global_position)


func _armar_escupitajo() -> void:
	if _material_escupe == null:
		_material_escupe = ShaderMaterial.new()
		_material_escupe.shader = load("res://shaders/escupitajo.gdshader")
	_gota = _esfera(ESCUPE_RADIO)
	add_child(_gota)
	# La cola va suelta en el mundo: cada gotita en donde estuvo la gota unos cuadros antes
	for radio: float in ESCUPE_COLA:
		var gotita := _esfera(radio)
		gotita.top_level = true
		gotita.visible = false
		add_child(gotita)
		_cola.append(gotita)
	var luz := OmniLight3D.new()
	luz.light_color = ESCUPE_COLOR
	luz.light_energy = 0.8
	luz.omni_range = 2.5
	add_child(luz)


func _esfera(radio: float) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 8
	esfera.rings = 4
	esfera.material = _material_escupe
	malla.mesh = esfera
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return malla


# Estirada hacia donde va y temblando como algo espeso; la cola la sigue
func _mover_escupitajo(desde: Vector3) -> void:
	var rapidez := velocidad.length()
	if rapidez > 0.1:
		var adelante := velocidad / rapidez
		var arriba := Vector3.UP if absf(adelante.y) < 0.95 else Vector3.RIGHT
		var largo := clampf(1.0 + rapidez * ESCUPE_ESTIRA, 1.0, 1.9)
		var tiembla := sin(_edad * 26.0) * 0.1
		var ancho := (1.0 + tiembla) / sqrt(largo)
		_gota.basis = Basis.looking_at(adelante, arriba).scaled_local(Vector3(ancho, ancho * (1.0 - tiembla * 0.5), largo * (1.0 - tiembla)))
	_rastro.insert(0, desde)
	var cabe := (_cola.size() + 1) * ESCUPE_COLA_CADA
	if _rastro.size() > cabe:
		_rastro.resize(cabe)
	for n in _cola.size():
		var atras := (n + 1) * ESCUPE_COLA_CADA
		_cola[n].visible = _rastro.size() > atras
		if _cola[n].visible:
			_cola[n].global_position = _rastro[atras]


func _reventar(donde: Vector3) -> void:
	var padre := get_parent()
	if tipo == 2:
		ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.FUEGO, FUEGO_RADIO, FUEGO_DURA)
		Sonidos.tocar(self, "whack", -6.0, 0.6)
	elif tipo == 3:
		pass
	else:
		ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.SAL, SAL_RADIO, SAL_DURA)
	var efectos := get_tree().get_first_node_in_group("efectos_pixel")
	if efectos and efectos.has_method("lanzar"):
		match tipo:
			2:
				efectos.lanzar("molotov_revienta", donde)
			3:
				efectos.lanzar("lodo_choque", donde)
				Sonidos.tocar(self, "squelch", -8.0, 0.7)
			_:
				efectos.lanzar("cria_cabeza", donde + Vector3.UP * 0.2, Vector3.ZERO, 0.8)
	queue_free()
