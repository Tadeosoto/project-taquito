@tool
class_name Mesa
extends Mostrador

# Mesa de taqueria (foto de referencia del usuario): mesa cuadrada de fierro con la
# cubierta roja de una marca de refresco (inventada: `texto`) y filo blanco, sillas
# plegables rojas alrededor y, al centro, servilletero, salero y dos salseros (roja y
# verde). Usa las piezas del Mostrador; su `estilo` no se usa. `color` es el rojo de
# la mesa y las sillas. El origen es el centro de la base.

const LADO := 0.72
const ALTO_MESA := 0.74
const SILLA := preload("res://models/interiores/silla_plegable/silla_plegable.scn")
const ALTO_SILLA := 0.85

# Sillas en este orden: atras (-Z), izquierda, derecha, adelante (+Z). La mesa de la
# camara deja fuera la de adelante, donde va uno sentado
@export_flags("atras", "izquierda", "derecha", "adelante") var sillas := 15:
	set(valor):
		sillas = valor
		_reconstruir()
# Servilletero, salero y salseros
@export var centro := true:
	set(valor):
		centro = valor
		_reconstruir()


func _armar() -> void:
	var fierro := _ps1(color.darkened(0.15))
	var cubierta := ALTO_MESA
	# Cubierta: lamina blanca y encima el rojo, con el marco de fierro alrededor
	var blanco := _ps1(BLANCO)
	blanco.set_shader_parameter("metal", false)
	_caja(Vector3(LADO, 0.025, LADO), Vector3(0, cubierta - 0.0125, 0), blanco)
	# Poco desgaste: con el polvo de lo que ve hacia arriba el rojo quedaba rosa
	var rojo := _ps1(color)
	rojo.set_shader_parameter("desgaste", 0.12)
	_caja(Vector3(LADO - 0.07, 0.004, LADO - 0.07), Vector3(0, cubierta + 0.002, 0), rojo)
	var marco := _ps1(Color(0.35, 0.35, 0.37))
	for signo in [-1.0, 1.0]:
		_caja(Vector3(LADO + 0.02, 0.035, 0.015), Vector3(0, cubierta - 0.012, signo * (LADO / 2 + 0.007)), marco)
		_caja(Vector3(0.015, 0.035, LADO + 0.02), Vector3(signo * (LADO / 2 + 0.007), cubierta - 0.012, 0), marco)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caja(Vector3(0.035, cubierta - 0.03, 0.035), Vector3(sx * (LADO / 2 - 0.04), (cubierta - 0.03) / 2, sz * (LADO / 2 - 0.04)), fierro)
		_caja(Vector3(0.025, 0.025, LADO - 0.1), Vector3(sx * (LADO / 2 - 0.04), 0.14, 0), fierro)
	# Marca en blanco, leyendose desde +Z
	_letrero(texto if texto != "" else "Cola Loca", Vector3(0, cubierta + 0.005, -0.2), LADO * 0.5, Color(0.95, 0.94, 0.9))
	var marca: Label3D = _partes.get_child(_partes.get_child_count() - 1)
	marca.rotation.x = -PI / 2
	marca.shaded = true
	if centro:
		_centro(Vector3(0.0, cubierta + 0.004, 0.0))
	for i in 4:
		if sillas & (1 << i):
			_silla(i)


# Servilletero de lamina, salero de vidrio y los salseros de barro con su cuchara,
# juntos al centro: el servilletero atras y lo demas alrededor de el
func _centro(base: Vector3) -> void:
	var lamina := _ps1(Color(0.72, 0.73, 0.75))
	var servilletero := base + Vector3(0, 0, -0.05)
	_caja(Vector3(0.13, 0.01, 0.07), servilletero + Vector3(0, 0.005, 0), lamina)
	for signo in [-1.0, 1.0]:
		_caja(Vector3(0.13, 0.08, 0.004), servilletero + Vector3(0, 0.045, signo * 0.03), lamina)
	_caja(Vector3(0.12, 0.085, 0.054), servilletero + Vector3(0, 0.05, 0), _plano(Color(0.95, 0.95, 0.92)))
	var sal := base + Vector3(-0.1, 0, 0.03)
	_cilindro(0.018, 0.018, 0.04, sal + Vector3(0, 0.02, 0), _plano(Color(0.92, 0.92, 0.9)))
	_cilindro(0.022, 0.022, 0.065, sal + Vector3(0, 0.0325, 0), _vidrio())
	_cilindro(0.023, 0.023, 0.02, sal + Vector3(0, 0.075, 0), _ps1(Color(0.8, 0.8, 0.82)))
	var barro := _ps1(Color(0.55, 0.28, 0.15))
	barro.set_shader_parameter("metal", false)
	# Salseros: cuerpo bajo, la salsa adentro y un borde (toro) mas alto que ella, para
	# que se vea hundida y no rebosando
	for i in 2:
		var salsa: Vector3 = base + [Vector3(0.0, 0, 0.05), Vector3(0.1, 0, 0.02)][i]
		_cilindro(0.042, 0.03, 0.025, salsa + Vector3(0, 0.0125, 0), barro)
		_cilindro(0.036, 0.036, 0.004, salsa + Vector3(0, 0.027, 0), _ps1([Color(0.6, 0.1, 0.05), Color(0.35, 0.55, 0.15)][i]))
		var borde := TorusMesh.new()
		borde.inner_radius = 0.034
		borde.outer_radius = 0.046
		borde.rings = 12
		borde.ring_segments = 6
		borde.material = barro
		_malla(borde, salsa + Vector3(0, 0.032, 0), Vector3(1, 0.8, 1))
		var cuchara: Basis = Basis(Vector3.UP, [0.5, -0.4][i]) * Basis(Vector3.RIGHT, -0.35)
		var mango := MeshInstance3D.new()
		mango.mesh = BoxMesh.new()
		(mango.mesh as BoxMesh).size = Vector3(0.01, 0.004, 0.09)
		(mango.mesh as BoxMesh).material = lamina
		mango.transform = Transform3D(cuchara, salsa + Vector3(0, 0.045, 0.01))
		_partes.add_child(mango)


# Silla plegable de fierro (Sketchfab "Folding Chair - Low Poly", frente a +Z) pintada
# de rojo, un poco desacomodada; vista hacia la mesa
func _silla(lado: int) -> void:
	var silla := SILLA.instantiate() as Node3D
	var caja := Mueble.medir(silla)
	var escala := ALTO_SILLA / caja.size.y
	var giro: float = [0.0, PI / 2, -PI / 2, PI][lado] + _rng.randf_range(-0.25, 0.25)
	var donde: Vector3 = [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)][lado]
	var base := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z) * escala
	var pos := donde * (LADO / 2 + 0.18 + _rng.randf_range(0.0, 0.12)) + Vector3(_rng.randf_range(-0.06, 0.06), 0, 0)
	var xform := Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * escala), pos)
	silla.transform = xform * Transform3D(Basis(), -base / escala)
	var pintura := _ps1(color)
	pintura.set_shader_parameter("desgaste", 0.35)
	for malla in silla.find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).material_override = pintura
	_partes.add_child(silla)
