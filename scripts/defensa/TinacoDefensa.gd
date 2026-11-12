class_name TinacoDefensa
extends StaticBody3D

# El tinaco de la defensa (docs/misiones.md §0): el blanco de los zombis (Zombie._destino
# lo busca en su grupo) mientras tenga vida. Lo arma Barricada._tinaco con el modelo.
# Se va saliendo el agua por donde le pegan; roto, se riega todo y deja de ser blanco,
# pero la noche sigue (al amanecer se cobra la mitad).

signal cambio
signal cayo
signal aviso(texto: String)

# Como el del refugio (Refugio.TINACO_VIDA): cada zombi le quita 2 por segundo
# (Zombie.DANO_RECINTO), y con 100 una horda lo rompia en unos segundos
const VIDA := 300
const AVISO_EN := 0.5     # fraccion de vida a la que avisa que no aguanta
# Chorros (EfectosPixel): uno mas a cada fraccion de vida perdida. [angulo, alto en fraccion]
const CHORROS := [[0.5, 0.25], [2.6, 0.45], [4.4, 0.15], [1.6, 0.6], [3.5, 0.3]]
const CHORRO_ESCALA := 0.6

var vida := VIDA
var radio := 1.0
var alto := 1.0

var _chorros: Array[MeshInstance3D] = []
var _avisado := false


func _enter_tree() -> void:
	add_to_group("tinaco_defensa")


# Ya con el modelo puesto: cuanto mide, para el alcance de los zombis y los chorros
func armar(nuevo_radio: float, nuevo_alto: float) -> void:
	radio = nuevo_radio
	alto = nuevo_alto
	for datos: Array in CHORROS:
		var hacia := Vector3(cos(datos[0]), 0.0, sin(datos[0]))
		var chorro := EfectosPixel.cuadro_bucle("tinaco_chorro", CHORRO_ESCALA, 1.0, 0.0, false, false, true)
		if chorro == null:
			return
		chorro.position = hacia * radio * 0.95 + Vector3.UP * alto * datos[1]
		chorro.set_instance_shader_parameter("hacia", global_basis * hacia)
		add_child(chorro)
		_chorros.append(chorro)
	_goteras()


# Lo que le pega un zombi
func recibir_golpe(dano: int) -> void:
	if vida <= 0:
		return
	vida = maxi(vida - dano, 0)
	_goteras()
	cambio.emit()
	if vida <= 0:
		cayo.emit()
	elif vida <= VIDA * AVISO_EN and not _avisado:
		_avisado = true
		aviso.emit("El tinaco anda valiendo berga")


func fraccion() -> float:
	return float(vida) / VIDA


func reiniciar() -> void:
	vida = VIDA
	_avisado = false
	_goteras()
	cambio.emit()


# Roto, salen todos
func _goteras() -> void:
	var perdida := 1.0 - fraccion()
	for i in _chorros.size():
		_chorros[i].visible = perdida >= (i + 1) / float(_chorros.size() + 1)
