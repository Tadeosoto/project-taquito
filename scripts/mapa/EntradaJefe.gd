class_name EntradaJefe
extends Area3D
## Una entrada fija a la pelea con un jefe (la plaza de la Mojiganga, los tuneles de la Madre):
## la flecha amarilla de los comercios, puesta en el mapa donde se defina. Se puede encontrar sin
## que nadie te mande (docs/plan-noche.md S8, JJ): pisarla te mete a la pelea, y como llegaras
## debil ganar ahi no da premio ni avanza la historia. Solo cuenta si traes la mision de entrar
## ahi (un paso ENTRAR_A con esta `escena`). Si ya derrotaste al jefe, pisarla no te mete: sale la
## leyenda y con Espacio repites la pelea (sin premio, salvo con la mision).
##
## Se coloca como un nodo en la escena del mapa (map_test.tscn) con este script y `escena`, `id`
## y `nombre`; las misiones apuntan a ella con `lugar = "entrada:<id>"`. Al volver de la pelea
## apareces `SALIDA_A` m frente a la flecha (su +Z): gira el nodo para que mire a la calle.

const CARTEL_RADIO := 25.0
const SALIDA_A := 4.0

## Para las misiones: `lugar = "entrada:<id>"`
@export var id := ""
@export_file("*.tscn") var escena := ""
## "la Mojiganga": lo que sale en la leyenda de repetir
@export var nombre := ""
## Lo que se lee sobre la flecha
@export var texto := "Entrar"

var _dentro := false
var _leyenda: Label3D


func _ready() -> void:
	add_to_group("entradas_jefe")
	monitorable = false
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = MapPuntos.MARCADOR_RADIO
	cilindro.height = 2.0
	forma.shape = cilindro
	forma.position.y = 1.0
	add_child(forma)
	add_child(MapPuntos.flecha())
	var letrero := _texto_3d(texto, 2.6)
	letrero.visibility_range_end = CARTEL_RADIO
	add_child(letrero)
	_leyenda = _texto_3d("", 3.3)
	_leyenda.visible = false
	add_child(_leyenda)
	body_entered.connect(_entro)
	body_exited.connect(_salio)


func _texto_3d(contenido: String, alto: float) -> Label3D:
	var letrero := Label3D.new()
	letrero.text = contenido
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.pixel_size = 0.008
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = MapPuntos.MARCADOR_COLOR
	letrero.position = Vector3(0.0, alto, 0.0)
	return letrero


# La mision activa es entrar justo aqui, y es su hora
func con_mision() -> bool:
	var paso := Misiones.paso()
	return paso != null and paso.tipo == PasoMision.Tipo.ENTRAR_A and paso.escena == escena \
			and Misiones.en_hora()


func _entro(cuerpo: Node3D) -> void:
	if not cuerpo is Player or escena == "":
		return
	_dentro = true
	if PasoJefe.vencido(PasoJefe.jefe_de(escena)) and not con_mision():
		# Ya lo derrotaste: no te mete solo, preguntas con Espacio
		_leyenda.text = "Ya derrotaste a %s.\n%s: repetir la pelea (sin premio)" % [nombre if nombre != "" else "ese jefe", \
				"Espacio" if Input.get_connected_joypads().is_empty() else "X"]
		_leyenda.visible = true
		add_to_group("interactuable")
		return
	_entrar()


func _salio(cuerpo: Node3D) -> void:
	if not cuerpo is Player:
		return
	_dentro = false
	_leyenda.visible = false
	remove_from_group("interactuable")


# Lo llama el jugador con el boton de saltar (grupo `interactuable`)
func is_player_inside() -> bool:
	return _dentro


func interact() -> void:
	_leyenda.visible = false
	remove_from_group("interactuable")
	_entrar()


func _entrar() -> void:
	PasoJefe.entrar(self, escena, con_mision(), global_position + global_transform.basis.z * SALIDA_A + Vector3.UP)
