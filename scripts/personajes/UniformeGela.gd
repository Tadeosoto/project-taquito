class_name UniformeGela
extends RefCounted

# Chaleco y gorra azul de GelA para un civil del pack PSX (los guardias del reten de la
# avenida): los civiles todavia no tienen mascara de ropa, asi que en vez de pintar la textura
# se les cuelgan dos mallas de los huesos Chest y Head (BoneAttachment3D), medidas en metros del
# mundo desde la pose de descanso, como el gorro de Ramon (GorroPescador). Una malla y un
# material compartidos por todos.

const COLOR := Color(0.1, 0.33, 0.72)
const CHALECO := Vector3(0.44, 0.5, 0.28)     # ancho, alto, fondo (m)
const CHALECO_BAJA := 0.06                    # m debajo del hueso Chest
const GORRA_RADIO := 0.115
const GORRA_ALTO := 0.08
const GORRA_SUBE := 0.17                      # m arriba del hueso Head (la coronilla)
const VISERA := Vector3(0.2, 0.02, 0.12)

static var _material: StandardMaterial3D
static var _chaleco: BoxMesh
static var _gorra: CylinderMesh
static var _visera: BoxMesh


# `civil` es el nodo padre de Civiles.poner, ya en el arbol; su -Z es el frente del civil
static func vestir(civil: Node3D) -> void:
	var esqueletos := civil.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	var esqueleto := esqueletos[0] as Skeleton3D
	_armar()
	var frente := -civil.global_basis.z.normalized()
	_colgar(esqueleto, "Chest", _chaleco, Vector3.DOWN * CHALECO_BAJA, frente)
	_colgar(esqueleto, "Head", _gorra, Vector3.UP * GORRA_SUBE, frente)
	_colgar(esqueleto, "Head", _visera, Vector3.UP * (GORRA_SUBE - GORRA_ALTO / 2 + 0.01) + frente * (GORRA_RADIO + 0.03), frente)


static func _colgar(esqueleto: Skeleton3D, hueso: String, malla: Mesh, corrido: Vector3, frente: Vector3) -> void:
	var i := esqueleto.find_bone(hueso)
	if i < 0:
		return
	var pegado := BoneAttachment3D.new()
	pegado.bone_name = hueso
	esqueleto.add_child(pegado)
	var donde := esqueleto.global_transform * esqueleto.get_bone_global_pose(i)
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pegado.add_child(pieza)
	# En metros del mundo y viendo al frente del civil, aunque el esqueleto este escalado
	pieza.global_transform = Transform3D(Basis.looking_at(frente, Vector3.UP), donde.origin + corrido)


static func _armar() -> void:
	if _material:
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR
	_chaleco = BoxMesh.new()
	_chaleco.size = CHALECO
	_chaleco.material = _material
	_gorra = CylinderMesh.new()
	_gorra.top_radius = GORRA_RADIO
	_gorra.bottom_radius = GORRA_RADIO
	_gorra.height = GORRA_ALTO
	_gorra.radial_segments = 8
	_gorra.rings = 1
	_gorra.material = _material
	_visera = BoxMesh.new()
	_visera.size = VISERA
	_visera.material = _material
