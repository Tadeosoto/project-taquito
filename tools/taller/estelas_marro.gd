extends Node3D

# Prueba del combo del marro (Fase T, JJ 2026-11-25): el compa con un marro en la mano hace
# Sword_Heavy_A, B y C con la estela de verdad (EstelaBarrido.gd) en la ventana de cada clip, como
# Player._estela_golpe con ESTELA_GOLPE. Sirve para medir las ventanas y grabar el video.
#   godot --path . tools/taller/estelas_marro.tscn -- --medir      # imprime la rapidez de la cabeza
#   godot --path . --write-movie /ruta/cuadro.png --fixed-fps 30 tools/taller/estelas_marro.tscn

const MODELO := "res://models/personajes/protagonistas/el_compa/el_compa.fbx"
const BIBLIOTECA := preload("res://resources/personajes/animaciones_humanas.res")
const ESTELA := preload("res://scripts/EstelaBarrido.gd")
const ESCALA := 0.39
const ARMA_GIRO := Vector3(-90.0, 180.0, 0.0)   # el de player.gd: lo largo en X, mango en +X
const MARRO_LARGO := 0.85                         # m del puño a la cabeza
const ESTELA_PASO := 6.0
# s del clip en que la cabeza barre (medido con --medir: lo que pasa del 35 % de su rapidez maxima)
# (2026-11-25: A pasa de ~13 a 52-63 m/s a los 0.37 s, B a los 0.34, C a los 0.44)
const VENTANAS := {"Sword_Heavy_A": Vector2(0.35, 0.55), "Sword_Heavy_B": Vector2(0.32, 0.46),
	"Sword_Heavy_C": Vector2(0.43, 0.61)}
# Lo que se graba: [clip, velocidad, texto]
const GUION := [
	["Idle", 1.0, ""],
	["Sword_Heavy_A", 1.0, "Golpe 1 (Sword_Heavy_A)"], ["Sword_Heavy_A_Rec", 1.0, "Golpe 1 (Sword_Heavy_A)"],
	["Sword_Heavy_B", 1.0, "Golpe 2 (Sword_Heavy_B)"], ["Sword_Heavy_B_Rec", 1.0, "Golpe 2 (Sword_Heavy_B)"],
	["Sword_Heavy_C", 1.0, "Golpe 3 (Sword_Heavy_C)"], ["Sword_Heavy_C_Rec", 1.0, "Golpe 3 (Sword_Heavy_C)"],
	["Sword_Heavy_A", 1.0, "Combo seguido"], ["Sword_Heavy_B", 1.0, "Combo seguido"],
	["Sword_Heavy_C", 1.0, "Combo seguido"], ["Sword_Heavy_C_Rec", 1.0, "Combo seguido"],
	["Sword_Heavy_A", 0.35, "Combo en camara lenta"], ["Sword_Heavy_B", 0.35, "Combo en camara lenta"],
	["Sword_Heavy_C", 0.35, "Combo en camara lenta"], ["Sword_Heavy_C_Rec", 1.0, "Combo en camara lenta"],
	["Idle", 1.0, ""],
]

var _ap: AnimationPlayer
var _mano: BoneAttachment3D
var _punta: Marker3D
var _estela: Node
var _letrero: Label
var _camara: Camera3D
var _medir := false
var _paso := 0
var _t := 0.0
var _antes := []
var _mano_antes := Vector3.ZERO
var _punta_antes := Vector3.ZERO
var _velocidades := []


func _ready() -> void:
	_medir = "--medir" in OS.get_cmdline_user_args()
	var modelo := (load(MODELO) as PackedScene).instantiate() as Node3D
	modelo.transform = Transform3D(Basis.from_scale(Vector3(-ESCALA, ESCALA, -ESCALA)), Vector3.ZERO)
	add_child(modelo)
	_ap = modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap == null:
		_ap = AnimationPlayer.new()
		modelo.add_child(_ap)
	_ap.add_animation_library("h", BIBLIOTECA)
	var esqueleto := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_mano = BoneAttachment3D.new()
	_mano.bone_name = "RightHand"
	esqueleto.add_child(_mano)
	_armar_marro()
	_estela = ESTELA.new()
	add_child(_estela)
	_escenario()
	_empezar(0)


# Un marro de prueba: mango de madera y cabeza de fierro, en metros del mundo (el hueso trae la
# escala del modelo); la punta de la estela va en la cabeza
func _armar_marro() -> void:
	var marro := Node3D.new()
	marro.rotation_degrees = ARMA_GIRO
	marro.scale = Vector3.ONE / ESCALA
	_mano.add_child(marro)
	var mango := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.02
	cm.height = MARRO_LARGO + 0.12
	mango.mesh = cm
	mango.rotation_degrees.z = 90.0
	mango.position.x = -MARRO_LARGO * 0.5 + 0.06
	mango.material_override = _color(Color(0.5, 0.32, 0.15))
	marro.add_child(mango)
	var cabeza := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.11, 0.24)
	cabeza.mesh = bm
	cabeza.position.x = -MARRO_LARGO
	cabeza.material_override = _color(Color(0.25, 0.25, 0.28))
	marro.add_child(cabeza)
	_punta = Marker3D.new()
	_punta.position.x = -MARRO_LARGO - 0.04
	marro.add_child(_punta)


func _color(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _escenario() -> void:
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(8, 8)
	piso.mesh = plano
	piso.material_override = _color(Color(0.45, 0.42, 0.38))
	add_child(piso)
	var luz := DirectionalLight3D.new()
	luz.shadow_enabled = true
	luz.rotation_degrees = Vector3(-50, 35, 0)
	add_child(luz)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.32, 0.4, 0.52)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	add_child(entorno)
	_camara = Camera3D.new()
	_camara.fov = 50.0
	add_child(_camara)
	# Como la camara del juego: atras y arriba del hombro, viendo hacia donde pega
	_camara.look_at_from_position(Vector3(1.4, 1.9, 3.2), Vector3(0, 0.9, -0.6))
	var capa := CanvasLayer.new()
	add_child(capa)
	_letrero = Label.new()
	_letrero.position = Vector2(12, 8)
	_letrero.add_theme_font_size_override("font_size", 20)
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	capa.add_child(_letrero)


func _empezar(paso: int) -> void:
	_paso = paso
	_t = 0.0
	_antes = []
	_ap.play("h/" + GUION[paso][0])
	_ap.pause()
	_letrero.text = GUION[paso][2]


func _process(delta: float) -> void:
	var clip: String = GUION[_paso][0]
	# La estela con la pose del cuadro anterior (el hueso se acomoda despues del seek)
	_seguir_estela(clip, _t)
	if _medir and VENTANAS.has(clip) or _medir and clip.begins_with("Sword_Heavy") and not clip.ends_with("Rec"):
		var v := _punta.global_position.distance_to(_punta_antes) / maxf(delta * GUION[_paso][1], 0.0001)
		_velocidades.append([_t, v])
	_punta_antes = _punta.global_position
	_t += delta * float(GUION[_paso][1])
	var largo := _ap.get_animation("h/" + clip).length
	if clip == "Idle":
		largo = 0.8
	if _t >= largo:
		_cerrar_medida(clip)
		if _paso + 1 >= GUION.size():
			get_tree().quit()
			return
		_empezar(_paso + 1)
		return
	_ap.seek(fmod(_t, _ap.get_animation("h/" + clip).length), true)


func _seguir_estela(clip: String, t: float) -> void:
	var ventana: Vector2 = VENTANAS.get(clip, Vector2(-1, -1))
	if t < ventana.x or t > ventana.y:
		_antes = []
		return
	var mano := _mano.global_position
	var hacia := _punta.global_position - mano
	if _antes.is_empty():
		_antes = [mano, hacia]
		return
	var pasos := maxi(ceili(rad_to_deg((_antes[1] as Vector3).angle_to(hacia)) / ESTELA_PASO), 1)
	for i in range(1, pasos + 1):
		var f := float(i) / pasos
		var donde: Vector3 = (_antes[0] as Vector3).lerp(mano, f)
		_estela.agregar(donde, donde + (_antes[1] as Vector3).slerp(hacia, f))
	_antes = [mano, hacia]


func _cerrar_medida(clip: String) -> void:
	if not _medir or _velocidades.is_empty():
		return
	var maximo := 0.0
	for par in _velocidades:
		maximo = maxf(maximo, par[1])
	var desde := -1.0
	var hasta := -1.0
	var linea := ""
	for par in _velocidades:
		if par[1] > maximo * 0.35:
			if desde < 0.0:
				desde = par[0]
			hasta = par[0]
		linea += "%.2f:%.0f " % [par[0], par[1]]
	print("%s max %.1f m/s  ventana %.2f-%.2f\n  %s" % [clip, maximo, desde, hasta, linea])
	_velocidades.clear()
