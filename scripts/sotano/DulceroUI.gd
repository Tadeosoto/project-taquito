extends JuegoSotano

# El puesto del de los dulces, en el bano del Sotano (lo sienta Sotano.gd en Marca_Bano_dulcero, con
# su mesita de sotano.py banho()): "¿Algo pa la fiesta, joven?". Vende con fichas lo del inventario:
# dulces, cigarros y, si le preguntas bien, las tachas (docs/items.md). 1-4 compras, Esc te vas.

const MERCANCIA := [
	["Un mazapán", "res://resources/productos/mazapan.tres", 2, "\"Pa' endulzarte la noche.\""],
	["Un gansito", "res://resources/productos/gansito.tres", 3, "\"El de siempre, joven.\""],
	["Unos cigarros", "res://resources/productos/cigarros.tres", 3, "\"Sueltos no, ¿eh? Cajetilla.\""],
	["\"Algo pa' la fiesta\"", "res://resources/productos/tachas.tres", 16, "\"Shhh. Yo no te vendí nada.\""],
]
const SALUDOS := [
	"\"¿Algo pa' la fiesta, joven?\"",
	"\"Dulces, chicles, cigarros... y lo otro, si trae con qué.\"",
	"\"Pásele, pásele. Aquí nadie ve nada.\"",
]

static var _saludo := 0


func _init() -> void:
	titulo = "El de los dulces"
	ayuda = AYUDA_FILA


func _armar() -> void:
	contenido.add_child(etiqueta(SALUDOS[_saludo % SALUDOS.size()], 18, AMARILLO))
	_saludo += 1
	for k in MERCANCIA.size():
		var m: Array = MERCANCIA[k]
		contenido.add_child(etiqueta("%d  %s · %d fichas" % [k + 1, m[0], m[2]], 16))


func _tecla(codigo: int) -> void:
	if codigo >= KEY_1 and codigo <= KEY_4:
		comprar(codigo - KEY_1)


func comprar(k: int) -> void:
	var m: Array = MERCANCIA[k]
	var f := get_node_or_null("/root/Fichas")
	var inventario := get_node_or_null("/root/Inventory")
	if f == null or inventario == null:
		return
	if not f.gastar(int(m[2])):
		avisar("\"Sin fichas no hay fiesta, joven.\"")
		return
	if inventario.add_item(load(m[1])):
		Sonidos.tocar(self, "ficha_mesa", -6.0)
		avisar(m[3])
	else:
		f.fichas += int(m[2])
		avisar("\"Ya no le cabe nada, joven.\"")


# La fila: un boton por cosa, con su precio
func _armar_botones() -> void:
	var lista := []
	for k in MERCANCIA.size():
		lista.append({"texto": "%s (%d)" % [str(MERCANCIA[k][0]).replace("\"", ""), MERCANCIA[k][2]], "hacer": comprar.bind(k)})
	botones(lista)
