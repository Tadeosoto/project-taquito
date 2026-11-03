extends Node

# Autoload `Bonos`: lo que dan los amuletos puestos (dos lugares, InventoryItemData.amuleto) y
# las estampitas usadas (duran la partida). Los que pelean y cobran preguntan aqui: el jugador
# (vida, fuerza, alcance, dano que recibe, luz), los zombis (pesos) y las bolsas de tazos
# (suerte). Encima de las habilidades de los tazos, que siguen en Tazos.gd.
# Ningun bono lee al Personaje: el tono de piel no cambia el combate (CLAUDE.md).
#
# Los amuletos puestos no ocupan lugar en el inventario y no se pierden al desmayarte; al
# reiniciar la partida se van con todo lo demas.

signal cambio

const LUGARES := 2
const ESTAMPITA_DEFENSA := 0.05
const ESTAMPITA_FUERZA := 0.05
const RECIBIDO_MIN := 0.2      # por mucho que te protejas, el golpe te hace al menos esto

var puestos: Array = [null, null]          # InventoryItemData o null
var estampitas := { "defensa": 0, "fuerza": 0, "punto": 0 }


func reiniciar() -> void:
	puestos = [null, null]
	for k in estampitas:
		estampitas[k] = 0
	cambio.emit()


# Pone el amuleto en el primer lugar libre. Si estan llenos se quita el mas viejo (el del
# primer lugar), los demas se recorren y el nuevo va al ultimo. Regresa el quitado, o null:
# quien llama lo regresa al inventario
func poner(amuleto: InventoryItemData) -> InventoryItemData:
	var libre := puestos.find(null)
	if libre >= 0:
		puestos[libre] = amuleto
		cambio.emit()
		return null
	var quitado: InventoryItemData = puestos.pop_front()
	puestos.append(amuleto)
	cambio.emit()
	return quitado


func quitar(lugar: int) -> InventoryItemData:
	var quitado: InventoryItemData = puestos[lugar]
	puestos[lugar] = null
	cambio.emit()
	return quitado


func lleno() -> bool:
	return not puestos.has(null)


# Usar una estampita: "punto" va directo a los puntos de habilidad
func usar_estampita(cual: String) -> void:
	if not estampitas.has(cual):
		return
	estampitas[cual] += 1
	if cual == "punto":
		get_node("/root/Tazos").dar_puntos(1)
	cambio.emit()


# Suma de una llave de los amuletos puestos
func suma(llave: String) -> float:
	var total := 0.0
	for amuleto: InventoryItemData in puestos:
		if amuleto and amuleto.amuleto.has(llave):
			var v: Variant = amuleto.amuleto[llave]
			total += float(v) if not v is bool else (1.0 if v else 0.0)
	return total


func vida_extra() -> int:
	return roundi(suma("vida"))


func factor_fuerza() -> float:
	return 1.0 + suma("fuerza") + estampitas["fuerza"] * ESTAMPITA_FUERZA


func factor_alcance() -> float:
	return 1.0 + suma("alcance")


func factor_pesos() -> float:
	return 1.0 + suma("pesos")


func suerte() -> float:
	return suma("suerte")


func luz() -> bool:
	return suma("luz") > 0.0


# Cuanto del golpe te llega: la defensa siempre, lo de noche, lo de turbas (cazadores) y lo de
# los fuertes (cazadores y el jefe) segun quien pega
func factor_recibido(de_noche: bool, de_turba: bool, de_fuerte: bool) -> float:
	var f: float = (1.0 - suma("defensa")) * (1.0 - estampitas["defensa"] * ESTAMPITA_DEFENSA)
	if de_noche:
		f *= 1.0 - suma("noche")
	if de_turba:
		f *= 1.0 - suma("turba")
	if de_fuerte:
		f *= 1.0 - suma("fuertes")
	return maxf(f, RECIBIDO_MIN)


# Una linea para la pagina de habilidades: lo que dan las estampitas usadas
func texto_estampitas() -> String:
	var partes: Array[String] = []
	if estampitas["punto"] > 0:
		partes.append("+%d %s" % [estampitas["punto"], "punto" if estampitas["punto"] == 1 else "puntos"])
	if estampitas["defensa"] > 0:
		partes.append("-%d %% de daño" % roundi(estampitas["defensa"] * ESTAMPITA_DEFENSA * 100.0))
	if estampitas["fuerza"] > 0:
		partes.append("+%d %% de fuerza" % roundi(estampitas["fuerza"] * ESTAMPITA_FUERZA * 100.0))
	return ", ".join(partes)
