extends Node

# La gente que camina en el Sotano (lo crea Sotano.gd): jugadores que van de las maquinitas a la
# barra, al bano y de regreso, y la mesera con su charola, que te vende una Tecatl si la alcanzas.
# Sin navegacion: cada quien sigue una RUTA de vacios "Marca_Camino_k" del cuarto
# (tools/blender/sotano/sotano.py), escogidos para no atravesar columnas, la mesa ni la pista.
# Se cruzan entre ellos y contigo sin chocar (son de adorno). En metros de la escena del Sotano.

const RUTA_SALON := [0, 1, 2, 3, 4, 5, 6]               # el salon de las maquinitas, en vuelta
const RUTA_LARGA := [0, 1, 2, 3, 7, 8, 9, 10, 11, 7, 3, 4, 5, 6]   # pasa por el arco a la barra
const CAMINANTES := [["hombre_04", RUTA_SALON, 0], ["mujer_09", RUTA_LARGA, 3], ["hombre_11", RUTA_LARGA, 9],
	["mujer_14", RUTA_SALON, 4], ["hombre_32", RUTA_LARGA, 12]]
const MESERA := ["mujer_31", RUTA_LARGA, 6]
const VELOCIDAD := 1.0               # m/s (escena)
const PAUSA := Vector2(0.0, 2.5)     # s que se detienen en cada punto, al azar
const TECATL_FICHAS := 2
const BOTELLAS := preload("res://models/sotano/botellas.glb")

const CHAROLA_ARRIBA := 0.05        # m de la charola arriba de las manos (escena)

var sotano: Node3D
var _gente: Array = []               # por persona: [Node3D, ruta, indice, pausa, AnimationPlayer, mesera]
# La mesera camina con Walk_Carry (los brazos al frente) y la charola va, nivelada, entre sus manos
var _charola_nodo: Node3D
var _esqueleto: Skeleton3D
var _manos := Vector2i(-1, -1)


func _ready() -> void:
	if sotano == null:
		return
	for c: Array in CAMINANTES:
		_poner(c[0], c[1], c[2], false)
	_poner(MESERA[0], MESERA[1], MESERA[2], true)


func _poner(modelo: String, ruta: Array, desde: int, mesera: bool) -> void:
	var nodo := Node3D.new()
	nodo.name = "Mesera" if mesera else "Caminante_%d" % _gente.size()
	sotano.add_child(nodo)
	nodo.position = _punto(ruta[desde % ruta.size()])
	var anim := Civiles.poner(nodo, modelo, "Walk_Carry" if mesera else "Walk")
	if mesera:
		_charola_nodo = _charola()
		_charola_nodo.top_level = true
		nodo.add_child(_charola_nodo)
		var esqueletos := nodo.find_children("*", "Skeleton3D", true, false)
		if not esqueletos.is_empty():
			_esqueleto = esqueletos[0]
			_manos = Vector2i(_esqueleto.find_bone("LeftHand"), _esqueleto.find_bone("RightHand"))
		var vender := MuebleCasa.crear("Pedirle una Tecatl a la mesera (%d fichas)" % TECATL_FICHAS, Vector3(0, 0, 0), _vender, 1.0)
		nodo.add_child(vender)
	_gente.append([nodo, ruta, (desde + 1) % ruta.size(), 0.0, anim, mesera])


func _physics_process(delta: float) -> void:
	for p: Array in _gente:
		var nodo: Node3D = p[0]
		if p[3] > 0.0:
			p[3] -= delta
			if p[3] <= 0.0:
				_animar(p, "Walk")
			continue
		var meta := _punto(p[1][p[2]])
		var hacia := meta - nodo.position
		hacia.y = 0.0
		var d := hacia.length()
		if d < 0.05:
			p[2] = (p[2] + 1) % p[1].size()
			var pausa := randf_range(PAUSA.x, PAUSA.y)
			if pausa > 0.6:
				p[3] = pausa
				_animar(p, "Idle")
			continue
		var paso := minf(VELOCIDAD * delta, d)
		nodo.position += hacia / d * paso
		# El civil ve a su -Z: look_at lo voltea hacia donde va
		nodo.look_at(sotano.to_global(nodo.position + hacia), Vector3.UP)


func _animar(p: Array, clip: String) -> void:
	var anim: AnimationPlayer = p[4]
	if anim == null:
		return
	# La mesera no suelta la charola: camina con Walk_Carry y para con ese mismo cuadro congelado
	if p[5]:
		anim.speed_scale = 0.0 if clip == "Idle" else 1.0
		return
	if anim.has_animation(Civiles.LIB + "/" + clip):
		anim.play(Civiles.LIB + "/" + clip)


# La charola entre las manos de la mesera, nivelada y viendo a donde ella ve (despues de que la
# animacion movio los huesos: en _process)
func _process(_delta: float) -> void:
	if _charola_nodo == null or _esqueleto == null or _manos.x < 0 or _manos.y < 0:
		return
	var izq := _esqueleto.to_global(_esqueleto.get_bone_global_pose(_manos.x).origin)
	var der := _esqueleto.to_global(_esqueleto.get_bone_global_pose(_manos.y).origin)
	var escala := sotano.global_transform.basis.get_scale()
	var mesera := _charola_nodo.get_parent() as Node3D
	var giro := Basis(Vector3.UP, mesera.global_rotation.y).scaled(escala)
	_charola_nodo.global_transform = Transform3D(giro, (izq + der) / 2.0 + Vector3.UP * CHAROLA_ARRIBA * escala.y)


func _punto(k: int) -> Vector3:
	return sotano.call("marca", "Camino_%d" % k).origin


# La charola de la mesera: una bandeja con dos cervezas (la pone entre sus manos _process)
func _charola() -> Node3D:
	var charola := Node3D.new()
	var bandeja := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.18
	disco.bottom_radius = 0.18
	disco.height = 0.015
	disco.radial_segments = 10
	bandeja.mesh = disco
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.75, 0.78)
	metal.metallic = 0.6
	bandeja.material_override = metal
	charola.add_child(bandeja)
	# Dos Tecatl de verdad (models/sotano/botellas.glb, de sotano.py)
	var botellas := BOTELLAS.instantiate()
	var cerveza := botellas.find_child("Botella_cerveza", true, false) as Node3D
	for k in 2:
		if cerveza:
			var b := cerveza.duplicate() as Node3D
			b.transform = Transform3D(Basis(), Vector3(-0.06 + k * 0.12, 0.008, 0.0))
			charola.add_child(b)
	botellas.free()
	return charola


func _vender() -> void:
	sotano.call("_caguama", TECATL_FICHAS, "\"Ahí tienes, mi rey. Bien helada.\"")
