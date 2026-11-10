class_name ZonaLombrices
extends Node3D
# Un circulo en el piso que les hace algo a las lombrices (EnjambreLombrices._zonas lee el grupo
# "zonas_lombriz") y a veces a ti:
#   SAL: las empuja y se come sus cabezas; si te cae encima, quema las que traes pegadas.
#   FUEGO: las quema enteras (sin partirlas) y le pega a los sacos de la Madre; a ti tambien.
#   REPELE: un tambo prendido: las aleja. Patearlo (Player._golpear) lo tira y deja FUEGO.
#   LODO: el escupitajo de la Madre o el charco del carcamo: te frena y te puede quemar.
# `dura` 0 = para siempre.

enum Tipo { SAL, FUEGO, REPELE, LODO }

const ALUMBRADO := preload("res://scripts/map/MapAlumbrado.gd")

const COLOR_SAL := Color(0.95, 0.95, 0.9)
const COLOR_LODO := Color(0.12, 0.32, 0.28)
const FUEGO_CADA := 0.7
const FUEGO_DANO := 4
const FUEGO_LLAMAS := 10
const PATADA_LARGO := 2.2

@export var tipo := Tipo.SAL
@export var radio := 2.0
@export var dura := 20.0
@export var dano := 0              # LODO: vida por segundo
@export var frena := 1.0           # LODO: x tu velocidad adentro
@export var ver := true            # false: sin disco (la alberca del carcamo ya se ve)

var _edad := 0.0
var _toca := 0.0
var _chupa := 0.0
var _jugador: Node3D
var _visual: Node3D
var _luz: OmniLight3D
var _pateado := false


static func crear(padre: Node, donde: Vector3, tipo_: Tipo, radio_: float, dura_: float) -> ZonaLombrices:
	var zona := ZonaLombrices.new()
	zona.tipo = tipo_
	zona.radio = radio_
	zona.dura = dura_
	# La posicion antes de entrar: _ready arma las llamas donde esta (antes salian en el origen,
	# que en el carcamo es el charco)
	zona.position = (padre as Node3D).to_local(donde) if padre is Node3D else donde
	padre.add_child(zona)
	return zona


func _ready() -> void:
	add_to_group("zonas_lombriz")
	if tipo == Tipo.REPELE:
		add_to_group("tambos_lombriz")
	_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	match tipo:
		Tipo.SAL:
			_disco(COLOR_SAL, 0.85)
			_bucles("sal_burbujas", 3, 0.25)
			Sonidos.tocar(self, "fizz", -8.0)
		Tipo.LODO:
			if ver:
				_disco(COLOR_LODO, 0.9)
			# El charco del carcamo (dura 0) ya tiene su superficie; el escupitajo burbujea
			if dura > 0.0:
				_bucles("lodo_charco", 1, radio * 0.35)
		Tipo.FUEGO:
			_llamas()


func _disco(color: Color, alfa: float) -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = radio
	disco.bottom_radius = radio
	disco.height = 0.02
	disco.radial_segments = 16
	disco.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alfa)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disco.material = material
	var malla := MeshInstance3D.new()
	malla.mesh = disco
	malla.position.y = 0.02
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla)
	_visual = malla


# Hojas de pixel que se repiten (EfectosPixel.cuadro_bucle; F9 las apaga como los demas)
func _bucles(hoja: String, cuantos: int, escala: float) -> void:
	for n in cuantos:
		var bucle := EfectosPixel.cuadro_bucle(hoja, escala, 1.0, 0.0, false, true)
		if bucle == null:
			return
		var a := TAU * n / cuantos + randf() * 0.5
		var r := 0.0 if cuantos == 1 else radio * 0.55
		bucle.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		add_child(bucle)


func _llamas() -> void:
	var lugares: Array[Vector3] = []
	for n in FUEGO_LLAMAS:
		var a := TAU * n / FUEGO_LLAMAS + randf() * 0.4
		var r := radio * sqrt(randf()) * 0.85
		lugares.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var fuego: MultiMeshInstance3D = ALUMBRADO._sprites("fuego_tambo", lugares, 0.5, 0.0, 0.0)
	if fuego:
		add_child(fuego)
		_visual = fuego
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.55, 0.2)
	_luz.light_energy = 2.0
	_luz.omni_range = radio * 2.5
	_luz.position.y = 0.8
	add_child(_luz)


func _physics_process(delta: float) -> void:
	_edad += delta
	if dura > 0.0:
		var queda := dura - _edad
		if queda <= 0.0:
			queue_free()
			return
		# Se apaga el ultimo segundo
		if queda < 1.0:
			if _luz:
				_luz.light_energy = 2.0 * queda
			if _visual:
				_visual.scale = Vector3.ONE * maxf(queda, 0.05)
	if _jugador == null or not is_instance_valid(_jugador):
		return
	var adentro := Vector2(_jugador.global_position.x - global_position.x,
		_jugador.global_position.z - global_position.z).length() < radio \
		and absf(_jugador.global_position.y - 1.0 - global_position.y) < 1.5
	match tipo:
		Tipo.FUEGO:
			_toca -= delta
			if adentro and _toca <= 0.0 and _jugador.has_method("recibir_dano"):
				_toca = FUEGO_CADA
				_jugador.recibir_dano(FUEGO_DANO, global_position, 0.5)
		Tipo.LODO:
			if _jugador.get("lastres") != null:
				if adentro:
					_jugador.lastres[self] = frena
				else:
					_jugador.lastres.erase(self)
			if adentro and dano > 0:
				_chupa += dano * delta
				var salud := get_node_or_null("/root/Salud")
				if salud and _chupa >= 1.0:
					salud.vida -= int(_chupa)
					_chupa -= int(_chupa)


func _exit_tree() -> void:
	if _jugador and is_instance_valid(_jugador) and _jugador.get("lastres") != null:
		_jugador.lastres.erase(self)


# Un tambo pateado se cae y riega fuego hacia donde lo pateaste
func patear(hacia: Vector3) -> void:
	if tipo != Tipo.REPELE or _pateado:
		return
	_pateado = true
	hacia.y = 0.0
	var donde := global_position + hacia.normalized() * PATADA_LARGO
	ZonaLombrices.crear(get_parent(), donde, Tipo.FUEGO, 1.8, 10.0)
	for hijo in get_children():
		if hijo is Node3D:
			(hijo as Node3D).rotation.z = deg_to_rad(80.0)
	radio = 0.0
	remove_from_group("zonas_lombriz")
