@tool
class_name Tambos
extends Mostrador

# Tambos azules de plastico (de 200 l) parados en hilera y apilados en `niveles`, uno
# encima de otro en cada columna, con una tabla entre cada nivel, como en el fondo de las purificadoras. Usa las piezas del
# Mostrador; su `estilo` no se usa y `color` es el azul del plastico. El origen es el
# centro de la base de la hilera.

const RADIO := 0.29
const ALTO_TAMBO := 0.88

@export var columnas := 3:
	set(valor):
		columnas = valor
		_reconstruir()
@export var niveles := 2:
	set(valor):
		niveles = valor
		_reconstruir()


func _armar() -> void:
	var plastico := _ps1(color)
	plastico.set_shader_parameter("metal", false)
	var tapa := _ps1(color.darkened(0.25))
	tapa.set_shader_parameter("metal", false)
	var madera := _ps1(Color(0.55, 0.42, 0.28))
	madera.set_shader_parameter("metal", false)
	var paso := RADIO * 2.0 + 0.03
	var y := 0.0
	for nivel in niveles:
		var inicio := -paso * (columnas - 1) / 2.0
		for i in columnas:
			var base := Vector3(inicio + paso * i + _rng.randf_range(-0.03, 0.03), y, _rng.randf_range(-0.03, 0.03))
			_tambo(base, plastico, tapa)
		y += ALTO_TAMBO
		if nivel < niveles - 1:
			_caja(Vector3(paso * columnas, 0.03, RADIO * 2.0), Vector3(0, y + 0.015, 0), madera)
			y += 0.03


# Un tambo: cuerpo, dos aros, el borde de la tapa y los dos tapones
func _tambo(base: Vector3, plastico: Material, tapa: Material) -> void:
	_cilindro(RADIO, RADIO, ALTO_TAMBO - 0.04, base + Vector3(0, (ALTO_TAMBO - 0.04) / 2.0, 0), plastico)
	for t in [0.33, 0.66]:
		_cilindro(RADIO + 0.012, RADIO + 0.012, 0.04, base + Vector3(0, ALTO_TAMBO * t, 0), plastico)
	_cilindro(RADIO - 0.01, RADIO, 0.04, base + Vector3(0, ALTO_TAMBO - 0.02, 0), tapa)
	for lado in [-1.0, 1.0]:
		_cilindro(0.035, 0.035, 0.03, base + Vector3(lado * RADIO * 0.55, ALTO_TAMBO + 0.01, 0), tapa)
