class_name PuntoDebil
extends StaticBody3D
# Un punto debil de La Mojiganga (Catrina.gd): una flor de papel del peinado o el nudo de
# zombis del pecho. Una esfera chica en la capa de los zombis (2), asi la pistola la ve antes
# que el cuerpo grande; contesta recibir_golpe como un zombi y se lo pasa a la Catrina con su id.
# Va pegada a una marca del modelo (o a un hueso), asi sigue la animacion.

const CAPA_ZOMBIS := 2

var catrina: Node
var id := ""
var radio := 0.35
var malla: MeshInstance3D


func armar(catrina_: Node, id_: String, radio_: float, material: Material) -> void:
	catrina = catrina_
	id = id_
	radio = radio_
	collision_layer = CAPA_ZOMBIS
	collision_mask = 0
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = radio
	forma.shape = esfera
	add_child(forma)
	malla = MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = radio
	bola.height = radio * 2.0
	bola.radial_segments = 8
	bola.rings = 4
	bola.material = material
	malla.mesh = bola
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla)


func activo(si: bool) -> void:
	visible = si
	collision_layer = CAPA_ZOMBIS if si else 0


# Igual que Zombie.recibir_golpe: 0 = nada, 1 = pego, 2 = mato
func recibir_golpe(dano: int, desde: Vector3, _fuerza := 1.0, _truena_en := 80, cuerpo_a_cuerpo := true, _cabeza := false, _fuente := "") -> int:
	if catrina == null or not is_instance_valid(catrina) or not visible:
		return 0
	return catrina.golpe_punto(id, dano, desde, cuerpo_a_cuerpo)
