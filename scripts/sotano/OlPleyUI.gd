extends JuegoSotano

# Jugar en una maquinita OL PLEY del Sotano: la "Loteria de carretes" (Carretes.gd decide; aqui
# solo se muestra). Tres cartas que giran y paran una tras otra; apuestas de 1 a 5 fichas.

const GIRO := [0.7, 1.0, 1.3]       # s que gira cada carrete antes de parar
const CAMBIO := 0.06                # s entre carta y carta mientras gira

var placa: Carretes
var gabinete: Node                  # el gabinete del cuarto (Sotano.gd), para su seña y su sonido

var _apuesta := 1
var _cartas: Array[TextureRect] = []
var _apuesta_l: Label


func _init() -> void:
	titulo = "OL PLEY · Lotería de carretes"
	ayuda = "←/→ apuesta  ·  Espacio jalar  ·  Esc salir"


func _armar() -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_child(fila)
	var carretes := HBoxContainer.new()
	carretes.add_theme_constant_override("separation", 10)
	fila.add_child(carretes)
	for i in 3:
		var c := carta([0, CartasLoteria.TINACO, 5][i], 104.0)
		carretes.add_child(c)
		_cartas.append(c)
	var tabla := VBoxContainer.new()
	tabla.add_theme_constant_override("separation", 0)
	fila.add_child(tabla)
	tabla.add_child(etiqueta("Tercia paga (x apuesta):", 12, AMARILLO))
	var ordenadas := Carretes.PAGOS.keys()
	ordenadas.sort_custom(func(a: int, b: int) -> bool: return Carretes.PAGOS[a] > Carretes.PAGOS[b])
	for c: int in ordenadas:
		tabla.add_child(etiqueta("%-12s x%d" % [CartasLoteria.NOMBRES[c], Carretes.PAGOS[c]], 12))
	tabla.add_child(etiqueta("Con Tinaco: doble", 12, AMARILLO))
	tabla.add_child(etiqueta("2 iguales o 1 Tinaco: x1", 12))
	_apuesta_l = etiqueta("", 18, AMARILLO)
	_apuesta_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(_apuesta_l)
	_mostrar_apuesta()


func _tecla(codigo: int) -> void:
	if _ocupado:
		return
	match codigo:
		KEY_LEFT, KEY_A:
			_apuesta = maxi(_apuesta - 1, 1)
			_mostrar_apuesta()
		KEY_RIGHT, KEY_D:
			_apuesta = mini(_apuesta + 1, Carretes.APUESTA_MAX)
			_mostrar_apuesta()
		KEY_SPACE, KEY_ENTER:
			jalar()


func jalar() -> void:
	if _ocupado:
		return
	var f := get_node_or_null("/root/Fichas")
	if f == null or not f.gastar(_apuesta):
		avisar("No traes fichas. La ventanilla está junto a la escalera.")
		return
	_ocupado = true
	Sonidos.tocar(self, "boton", -6.0)
	var tiro := placa.tirar(_apuesta)
	var final: Array = tiro["carretes"]
	var t := 0.0
	var parados := 0
	while parados < 3:
		await get_tree().create_timer(CAMBIO, true, false, true).timeout
		t += CAMBIO
		for i in range(parados, 3):
			_cartas[i].texture = CartasLoteria.textura(Carretes.PESOS.keys()[randi() % Carretes.PESOS.size()])
		while parados < 3 and t >= GIRO[parados]:
			_cartas[parados].texture = CartasLoteria.textura(final[parados])
			Sonidos.tocar(self, "paso", -10.0)
			parados += 1
	var pago: int = tiro["pago"]
	if pago > 0:
		f.fichas += pago
		Sonidos.tocar(self, "moneda", -4.0)
		var tinaco: bool = final.has(CartasLoteria.TINACO) and pago > _apuesta
		avisar(("¡%d fichas! El Tinaco paga doble." if tinaco else "¡Ganaste %d fichas!") % pago)
	else:
		avisar("Nada. \"La que sigue es la buena\", dice el de al lado.")
	if gabinete and gabinete.has_method("mostrar_estado"):
		gabinete.mostrar_estado(placa.estado)
	_ocupado = false


func _mostrar_apuesta() -> void:
	_apuesta_l.text = "Apuesta: %d ficha%s" % [_apuesta, "" if _apuesta == 1 else "s"]
