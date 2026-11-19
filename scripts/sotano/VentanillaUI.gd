extends JuegoSotano

# La ventanilla del Primo en el Sotano: pesos por fichas y fichas por pesos (Fichas.gd), detras de
# la reja. Lo que dice es de docs/personajes.md: se cree importante y no lo es.

const PAQUETES := [10, 50, 100]
const LINEAS_COMPRA := [
	"Ahí te van. Que te rindan, mijo.",
	"Fichas limpias, de las buenas. ¿Ves? Aquí todo es legal.",
	"Ándale. La tercera de la izquierda anda caliente, pero yo no te dije.",
]
const LINEAS_COBRO := [
	"Lo mío es lo mío, mijo. La comisión es pa' la Virgen.",
	"Cuéntalos bien, que aquí nadie roba.",
]

var _pesos: Label
var _linea := 0


func _init() -> void:
	titulo = "La ventanilla del Primo"
	ayuda = "1/2/3 comprar  ·  C cobrar todo  ·  Esc salir"


func _armar() -> void:
	contenido.add_child(etiqueta("\"¿Cuántas fichas? Cada una, %d pesos.\"" % Fichas_precio(), 16))
	for i in PAQUETES.size():
		contenido.add_child(etiqueta("%d  ·  %d fichas por $%d" % [i + 1, PAQUETES[i], PAQUETES[i] * Fichas_precio()], 16, AMARILLO))
	contenido.add_child(etiqueta("C  ·  cobrar tus fichas (el Primo se queda el %d %%)" % roundi(Fichas_comision() * 100.0), 16, AMARILLO))
	_pesos = etiqueta("", 16)
	contenido.add_child(_pesos)
	var cartera := get_node_or_null("/root/Cartera")
	if cartera:
		cartera.cambio.connect(_mostrar_pesos)
	_mostrar_pesos()


func _exit_tree() -> void:
	super._exit_tree()
	var cartera := get_node_or_null("/root/Cartera")
	if cartera and cartera.cambio.is_connected(_mostrar_pesos):
		cartera.cambio.disconnect(_mostrar_pesos)


func _tecla(codigo: int) -> void:
	var f := get_node_or_null("/root/Fichas")
	if f == null:
		return
	match codigo:
		KEY_1, KEY_2, KEY_3:
			var compradas: int = f.comprar(PAQUETES[codigo - KEY_1])
			if compradas <= 0:
				avisar("\"Sin lana no hay fichas, mijo.\"")
			else:
				Sonidos.tocar(self, "ficha_mesa", -4.0)
				avisar("%d fichas. \"%s\"" % [compradas, LINEAS_COMPRA[_linea % LINEAS_COMPRA.size()]], 4.0)
				_linea += 1
		KEY_C:
			var pesos: int = f.cobrar()
			if pesos <= 0:
				avisar("\"¿Qué me vas a cobrar si no traes nada?\"")
			else:
				Sonidos.tocar(self, "monedas_caen", -5.0)
				avisar("$%d. \"%s\"" % [pesos, LINEAS_COBRO[_linea % LINEAS_COBRO.size()]], 4.0)
				_linea += 1


func _mostrar_pesos() -> void:
	var cartera := get_node_or_null("/root/Cartera")
	_pesos.text = "Traes $%d" % (cartera.pesos if cartera else 0)


# Los numeros son los de Fichas.gd (por su ruta: tools/ no conoce los autoloads)
func Fichas_precio() -> int:
	var f := get_node_or_null("/root/Fichas")
	return f.PRECIO if f else 5


func Fichas_comision() -> float:
	var f := get_node_or_null("/root/Fichas")
	return f.COMISION if f else 0.1
