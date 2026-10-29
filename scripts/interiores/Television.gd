@tool
class_name Television
extends Mostrador

# Television vieja de bulbo (CRT) en su repisa de fierro anclada al muro, como en las
# taquerias, con el futbol puesto. Usa las piezas del Mostrador; su `estilo` no se usa.
# El origen es donde la repisa toca el muro, y +Z sale del muro hacia el cuarto. La
# tele se gira `giro` grados sobre la repisa para ver hacia las mesas.

const REPISA := Vector3(0.55, 0.025, 0.5)
const CUERPO := Vector3(0.56, 0.46, 0.4)

@export_range(-90.0, 90.0) var giro := 0.0:
	set(valor):
		giro = valor
		_reconstruir()


func _armar() -> void:
	var fierro := _ps1(Color(0.2, 0.2, 0.21))
	# Repisa con su placa en el muro y dos escuadras
	_caja(REPISA, Vector3(0, -REPISA.y / 2, REPISA.z / 2), fierro)
	_caja(Vector3(REPISA.x, 0.3, 0.02), Vector3(0, -0.15, 0.01), fierro)
	for signo in [-1.0, 1.0]:
		var escuadra := MeshInstance3D.new()
		escuadra.mesh = BoxMesh.new()
		(escuadra.mesh as BoxMesh).size = Vector3(0.025, 0.025, 0.42)
		(escuadra.mesh as BoxMesh).material = fierro
		escuadra.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(38)), Vector3(signo * (REPISA.x / 2 - 0.04), -0.14, 0.17))
		_partes.add_child(escuadra)
	var raiz := _partes
	var tele := Node3D.new()
	tele.position = Vector3(0, 0, REPISA.z / 2)
	tele.rotation.y = deg_to_rad(giro)
	raiz.add_child(tele)
	_partes = tele
	# Caja de plastico gris: el frente, el cinescopio que se angosta atras y el bisel
	var plastico := _ps1(Color(0.3, 0.29, 0.28))
	plastico.set_shader_parameter("metal", false)
	var frente := CUERPO.z / 2
	_caja(Vector3(CUERPO.x, CUERPO.y, 0.18), Vector3(0, CUERPO.y / 2, frente - 0.09), plastico)
	_caja(Vector3(CUERPO.x * 0.7, CUERPO.y * 0.72, CUERPO.z - 0.18), Vector3(0, CUERPO.y * 0.48, frente - 0.18 - (CUERPO.z - 0.18) / 2), plastico)
	var pantalla := Vector2(0.4, 0.31)
	var centro := Vector3(-0.04, CUERPO.y * 0.55, frente + 0.002)
	# Cancha de futbol: pasto, linea media, circulo, marcador y lineas de barrido
	_caja(Vector3(pantalla.x, pantalla.y, 0.004), centro, _plano(Color(0.25, 0.55, 0.3)))
	_caja(Vector3(0.006, pantalla.y * 0.9, 0.002), centro + Vector3(0.03, 0, 0.003), _plano(Color(0.85, 0.9, 0.85)))
	var circulo := TorusMesh.new()
	circulo.inner_radius = 0.045
	circulo.outer_radius = 0.051
	circulo.rings = 16
	circulo.ring_segments = 3
	circulo.material = _plano(Color(0.85, 0.9, 0.85))
	var anillo := _malla(circulo, centro + Vector3(0.03, 0, 0.003), Vector3(1, 1, 0.1))
	anillo.rotation.x = PI / 2
	_caja(Vector3(0.1, 0.022, 0.002), centro + Vector3(-pantalla.x / 2 + 0.07, pantalla.y / 2 - 0.03, 0.003), _plano(Color(0.1, 0.12, 0.2)))
	for i in 3:
		var y := -pantalla.y / 2 + pantalla.y * (i + 0.5) / 3.0
		_caja(Vector3(pantalla.x, 0.012, 0.002), centro + Vector3(0, y, 0.0035), _plano(Color(0.18, 0.4, 0.22)))
	_caja(Vector3(pantalla.x + 0.04, pantalla.y + 0.04, 0.01), centro + Vector3(0, 0, -0.004), _ps1(Color(0.12, 0.12, 0.12)))
	# Perillas y bocina a la derecha de la pantalla
	var perilla := _ps1(Color(0.1, 0.1, 0.1))
	for i in 2:
		_cilindro(0.016, 0.016, 0.015, centro + Vector3(pantalla.x / 2 + 0.06, 0.09 - i * 0.06, 0.004), perilla)
		(_partes.get_child(_partes.get_child_count() - 1) as Node3D).rotation.x = PI / 2
	for i in 4:
		_caja(Vector3(0.06, 0.006, 0.003), centro + Vector3(pantalla.x / 2 + 0.06, -0.04 - i * 0.022, 0.002), perilla)
	# Antena de conejo
	for signo in [-1.0, 1.0]:
		var varilla := MeshInstance3D.new()
		varilla.mesh = BoxMesh.new()
		(varilla.mesh as BoxMesh).size = Vector3(0.006, 0.35, 0.006)
		(varilla.mesh as BoxMesh).material = _ps1(Color(0.7, 0.7, 0.72))
		varilla.transform = Transform3D(Basis(Vector3.BACK, signo * 0.45), Vector3(signo * 0.075, CUERPO.y + 0.16, -0.05))
		_partes.add_child(varilla)
	_caja(Vector3(0.07, 0.025, 0.06), Vector3(0, CUERPO.y + 0.012, -0.05), perilla)
	# El resplandor verdoso de la pantalla
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.6, 0.85, 0.75)
	luz.light_energy = 0.25
	luz.omni_range = 1.4
	luz.position = centro + Vector3(0, 0, 0.25)
	_partes.add_child(luz)
	_partes = raiz
