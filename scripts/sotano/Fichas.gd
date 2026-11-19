extends Node

# Las fichas del Sotano, el casino de los Gotera bajo Santa Mugre (docs/sistemas/sotano.md), y el
# permiso para bajar. Autoload `Fichas`: los scripts que cargan los de tools/ (Maquinita, por
# MapPuntos) lo buscan con get_node("/root/Fichas"), no por su nombre.
# Se compran con pesos en la ventanilla del Primo y se cobran ahi mismo con su comision. Afuera no
# valen nada, pero no se pierden: se quedan en la bolsa hasta la siguiente vez que bajes.
# El permiso: 0 = el de la puerta no te deja pasar; 1 = mandadero de los Gotera (el escalon 1 de
# docs/misiones.md, que daran sus misiones) o pagaste la cuota una vez.

signal cambio

const PRECIO := 5            # pesos por ficha (las maquinitas de la foto aceptan monedas de $5)
const COMISION := 0.1        # lo que se queda el Primo al cobrar tus fichas
const CUOTA := 300           # pesos, una sola vez, para que el de la puerta te deje pasar
const CUOTA_VIP := 500       # pesos, una sola vez, el pase al cuarto VIP (lo cobra el guarura)

var fichas := 0:
	set(valor):
		fichas = maxi(valor, 0)
		cambio.emit()
var permiso := 0:
	set(valor):
		permiso = valor
		cambio.emit()


var desaguadora := false            # si ya venciste a La Desaguadora (el premio es una vez)
var vip := false:
	set(valor):
		vip = valor
		cambio.emit()


func reiniciar() -> void:
	fichas = 0
	permiso = 0
	vip = false
	desaguadora = false


# Pesos -> fichas: cuantas compraste (las que alcance)
func comprar(cuantas: int) -> int:
	var cartera := get_node_or_null("/root/Cartera")
	if cartera == null:
		return 0
	cuantas = mini(cuantas, cartera.pesos / PRECIO)
	if cuantas <= 0:
		return 0
	cartera.pesos -= cuantas * PRECIO
	fichas += cuantas
	return cuantas


# Todas tus fichas -> pesos, menos la comision. Regresa los pesos que te dio
func cobrar() -> int:
	var cartera := get_node_or_null("/root/Cartera")
	if cartera == null or fichas <= 0:
		return 0
	var pesos := int(floor(fichas * PRECIO * (1.0 - COMISION)))
	fichas = 0
	cartera.pesos += pesos
	return pesos


# La cuota del de la puerta: true si la pagaste (o ya tenias permiso)
func pagar_cuota() -> bool:
	if permiso > 0:
		return true
	var cartera := get_node_or_null("/root/Cartera")
	if cartera == null or cartera.pesos < CUOTA:
		return false
	cartera.pesos -= CUOTA
	permiso = 1
	return true


# Gastar fichas en un juego: false si no alcanzan
func gastar(cuantas: int) -> bool:
	if cuantas <= 0 or fichas < cuantas:
		return false
	fichas -= cuantas
	return true
