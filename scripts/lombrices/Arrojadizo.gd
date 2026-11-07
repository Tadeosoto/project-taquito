class_name Arrojadizo
extends Node3D
# Lo que avienta el Lanzador (y lo que escupe la Madre): vuela en parabola (a mano, sin cuerpo de
# fisica) y al tocar algo revienta en su zona (ZonaLombrices): la sal en un circulo blanco, la
# molotov en fuego y el escupitajo de la Madre en un charco de lodo de Serenol.

const GRAVEDAD := 14.0
const VIDA := 4.0
const SAL_RADIO := 1.5
const SAL_DURA := 12.0
const FUEGO_RADIO := 2.0
const FUEGO_DURA := 5.0
const LODO_DANO := 3            # vida por segundo dentro del charco
const LODO_FRENA := 0.6

var tipo := 1          # InventoryItemData.arrojar: 1 sal, 2 molotov; 3 lodo (la Madre)
var radio_zona := 0.0  # 0 = el de su tipo
var dura_zona := 0.0
var velocidad := Vector3.ZERO
var _edad := 0.0
var _excluir: Array[RID] = []


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
		var bola := SphereMesh.new()
		bola.radius = 0.22
		bola.height = 0.44
		bola.radial_segments = 6
		bola.rings = 3
		malla.mesh = bola
		material.albedo_color = Color(0.1, 0.45, 0.38)
		material.emission_enabled = true
		material.emission = Color(0.1, 0.8, 0.65)
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
	velocidad.y -= GRAVEDAD * delta
	var desde := global_position
	var hasta := desde + velocidad * delta
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta, 1, _excluir)
	var pego := get_world_3d().direct_space_state.intersect_ray(rayo)
	rotation += Vector3(7.0, 3.0, 0.0) * delta
	if pego:
		_reventar(pego.position)
		return
	global_position = hasta
	if _edad > VIDA:
		_reventar(global_position)


func _reventar(donde: Vector3) -> void:
	var padre := get_parent()
	if tipo == 2:
		ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.FUEGO, FUEGO_RADIO, FUEGO_DURA)
		Sonidos.tocar(self, "whack", -6.0, 0.6)
	elif tipo == 3:
		var lodo := ZonaLombrices.crear(padre, donde, ZonaLombrices.Tipo.LODO, radio_zona if radio_zona > 0.0 else 1.6, dura_zona if dura_zona > 0.0 else 9.0)
		lodo.dano = LODO_DANO
		lodo.frena = LODO_FRENA
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
