class_name GabineteOlPley
extends StaticBody3D

# Una maquinita EL GORDO del Sotano (antes OL PLEY; el codigo sigue diciendo OlPley): el modelo
# de Blender (models/sotano/gabinete_olpley.glb, de
# tools/blender/sotano/sotano.py), su caja de choque, su placa (Carretes.gd) y la sena de la casa:
# cuando la placa esta CALIENTE (el siguiente tiro gana) la marquesina parpadea con su foco.
# El color del cuerpo es uno de COLORES (como en la foto: rojas, negras y moradas); un material
# por color, compartido. Origen al centro de la base, viendo a +Z.

const MODELO := preload("res://models/sotano/gabinete_olpley.glb")
const COLORES := [Color(0.7, 0.1, 0.1), Color(0.12, 0.12, 0.13), Color(0.4, 0.15, 0.55)]
const MEDIDA := Vector3(0.66, 1.83, 0.6)
const PARPADEO := 0.18               # s entre prendido y apagado de la sena
const PALANCA_ANGULO := 55.0         # grados que baja la palanca al jalarla (hacia ti)
const PALANCA_BAJA := 0.22           # s
const PALANCA_SUBE := 0.45           # s, con rebote

static var _cuerpos := {}            # color -> StandardMaterial3D

var color := 0
var placa := Carretes.new()

var _foco: OmniLight3D
var _t := 0.0


func _ready() -> void:
	var modelo := MODELO.instantiate()
	add_child(modelo)
	var cuerpo := _cuerpo(color)
	for nodo in modelo.find_children("*", "MeshInstance3D", true, false):
		var malla := (nodo as MeshInstance3D).mesh
		for i in malla.get_surface_count():
			var m := malla.surface_get_material(i)
			if m and m.resource_name == "gabinete":
				(nodo as MeshInstance3D).set_surface_override_material(i, cuerpo)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = MEDIDA
	forma.shape = caja
	forma.position.y = MEDIDA.y / 2.0
	add_child(forma)
	_foco = OmniLight3D.new()
	_foco.light_color = Color(1.0, 0.85, 0.3)
	_foco.light_energy = 0.0
	_foco.omni_range = 1.4
	_foco.position = Vector3(0.0, 1.72, 0.45)
	add_child(_foco)
	set_process(false)


# La pantalla del gabinete enseña `textura` (el SubViewport del juego, OlPleyUI); null la regresa a
# la de "inserte ficha"
func mostrar_en_pantalla(textura: Texture2D) -> void:
	var pantalla := find_child("Pantalla", true, false) as MeshInstance3D
	if pantalla == null:
		return
	if textura == null:
		pantalla.set_surface_override_material(0, null)
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = textura
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pantalla.set_surface_override_material(0, m)


# La palanca del lado derecho (el vacio "Palanca" de sotano.py gabinete()): baja hacia ti y regresa
# con rebote. Es una corrutina: vuelve cuando la palanca llego abajo (ahi arrancan los carretes)
func jalar_palanca() -> void:
	var palanca := find_child("Palanca", true, false) as Node3D
	Sonidos.tocar(self, "slot_palanca", -4.0)
	if palanca == null:
		return
	var tween := create_tween()
	tween.tween_property(palanca, "rotation:x", deg_to_rad(PALANCA_ANGULO), PALANCA_BAJA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(palanca, "rotation:x", 0.0, PALANCA_SUBE).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(PALANCA_BAJA).timeout


# Un boton del tablero se hunde y regresa ("Boton_0".."Boton_5" o "Boton_grande")
func apretar(boton: String) -> void:
	var b := find_child(boton, true, false) as Node3D
	if b == null:
		return
	var y0 := b.position.y
	var tween := create_tween()
	tween.tween_property(b, "position:y", y0 - 0.008, 0.06)
	tween.tween_property(b, "position:y", y0, 0.1)


func mostrar_estado(estado: int) -> void:
	set_process(estado == Carretes.Estado.CALIENTE)
	if estado != Carretes.Estado.CALIENTE:
		_foco.light_energy = 0.0


func _process(delta: float) -> void:
	_t += delta
	_foco.light_energy = 1.6 if int(_t / PARPADEO) % 2 == 0 else 0.0


static func _cuerpo(i: int) -> StandardMaterial3D:
	if not _cuerpos.has(i):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORES[i % COLORES.size()]
		m.roughness = 0.6
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_cuerpos[i] = m
	return _cuerpos[i]
