extends Node3D

# Borrador del pasillo del tianguis: una calle con banquetas y fachadas de relleno, y encima un
# tramo de Tianguis (scripts/mapa/Tianguis.gd, el mismo que arma Colonia.gd en el mapa) centrado
# en el origen. Sirve para ver el tianguis sin cargar la colonia (tools/tianguis/captura_tianguis.gd).

@export var semilla := 7
@export var largo := 40.0           # tramo de calle
@export var arroyo := 8.0           # de banqueta a banqueta (Bahia de Santiago: ~8 m)
@export var banqueta := 1.5
@export var pasillo := 2.6          # libre entre los tubos de enfrente de las dos filas
@export var fachadas := true        # muros de relleno detras de las banquetas, para ver el encierro
@export var gente := true           # marchantes, compradores y los que pasan (civiles del juego)

var _rng := RandomNumberGenerator.new()
var _materiales := {}


func _ready() -> void:
	_rng.seed = semilla
	_calle()
	var t := Tianguis.new()
	t.name = "Tramo"
	t.semilla = semilla
	t.largo = largo
	t.arroyo = arroyo
	t.pasillo = pasillo
	t.gente = gente
	t.position.x = -largo / 2.0
	add_child(t)


func _calle() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Calle"
	add_child(cuerpo)
	var ancho_total := arroyo + banqueta * 2.0
	_caja(cuerpo, Vector3(0, -0.05, 0), Vector3(largo + 10, 0.1, ancho_total + 10), _material(Color(0.2, 0.2, 0.21)), true)
	for lado in [-1.0, 1.0]:
		var z: float = lado * (arroyo / 2.0 + banqueta / 2.0)
		_caja(cuerpo, Vector3(0, 0.075, z), Vector3(largo + 10, 0.15, banqueta), _material(Color(0.56, 0.54, 0.5)), true)
		if not fachadas:
			continue
		# Casas pegadas de colores, de 1 y 2 pisos, con su puerta y ventana oscuras
		var x := -largo / 2.0 - 5.0
		while x < largo / 2.0 + 5.0:
			var w := _rng.randf_range(4.0, 8.0)
			var h := 3.0 if _rng.randf() < 0.5 else 5.8
			var zc: float = lado * (arroyo / 2.0 + banqueta + 0.3)
			var color := Color.from_hsv(_rng.randf(), _rng.randf_range(0.15, 0.45), _rng.randf_range(0.6, 0.85))
			_caja(cuerpo, Vector3(x + w / 2.0, h / 2.0, zc), Vector3(w, h, 0.6), _material(color), true)
			var hueco := _material(Color(0.12, 0.11, 0.1))
			var cara: float = zc - lado * 0.31
			_caja(cuerpo, Vector3(x + w * 0.3, 1.05, cara), Vector3(1.0, 2.1, 0.02), hueco, false)
			_caja(cuerpo, Vector3(x + w * 0.68, 1.5, cara), Vector3(1.3, 1.0, 0.02), hueco, false)
			x += w


func _material(color: Color) -> StandardMaterial3D:
	var clave := color.to_html(false)
	if not _materiales.has(clave):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.95
		_materiales[clave] = m
	return _materiales[clave]


func _caja(padre: Node3D, centro: Vector3, tam: Vector3, mat: Material, choca: bool) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = centro
	padre.add_child(mi)
	if choca:
		var f := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = tam
		f.shape = forma
		f.position = centro
		padre.add_child(f)
