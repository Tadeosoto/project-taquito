class_name Director
extends RefCounted

# El que decide cuando salen los zombis de noche, como el de Left 4 Dead
# (docs/especificaciones.md 4.8). Mide que tan apretado anda el jugador (`intensidad`: sube
# con los golpes y con matar cerca, y baja sola si nadie lo esta atacando) y da vueltas:
#   ARMANDO   salen sueltos y cada rato una turba, hasta que el jugador llega a TOPE
#   SOSTENER  sigue igual unos segundos
#   BAJANDO   ya no sale nadie hasta que la intensidad baje de ALIVIO
#   RESPIRO   tampoco, un rato, para que se recupere
# Solo decide: Zombis.gd es el que los pone. En coop esto lo correria el servidor, con una
# intensidad por jugador.

enum Fase { ARMANDO, SOSTENER, BAJANDO, RESPIRO }

const TOPE := 0.7
const ALIVIO := 0.4
const SOSTENER_DURA := Vector2(3.0, 5.0)
const RESPIRO_DURA := Vector2(30.0, 45.0)
const RESPIRO_MOVIENDOSE := 1.5  # si el jugador anda caminando se acaba mas pronto
const BAJA_POR_SEGUNDO := 0.03
const POR_DANO := 0.015          # por punto de vida perdido
const POR_MUERTE := 0.03         # por zombi matado cerca
const MUERTE_CERCA := 10.0
const ATACADO_A := 6.0           # m: con un zombi mas cerca no baja la intensidad
const TURBA_PRIMERA := Vector2(25.0, 45.0)
const TURBA_CADA := Vector2(90.0, 180.0)
const TURBA_BASE := 6
const TURBA_POR_NOCHE := 2
const TURBA_AZAR := 3

var fase := Fase.RESPIRO
var intensidad := 0.0
var _tiempo := 0.0
var _turba_en := 0.0


func _init() -> void:
	reiniciar()


# Al anochecer: empieza tranquilo y la primera turba tarda un poco
func reiniciar() -> void:
	fase = Fase.ARMANDO
	intensidad = 0.0
	_tiempo = 0.0
	_turba_en = randf_range(TURBA_PRIMERA.x, TURBA_PRIMERA.y)


func recibio_dano(cantidad: int) -> void:
	intensidad = minf(intensidad + cantidad * POR_DANO, 1.0)


func mato_cerca() -> void:
	intensidad = minf(intensidad + POR_MUERTE, 1.0)


func desmayo() -> void:
	intensidad = 1.0


func puede_sueltos() -> bool:
	return fase == Fase.ARMANDO or fase == Fase.SOSTENER


# Avanza; regresa cuantos zombis debe traer una turba ahora (0 casi siempre)
func avanzar(delta: float, atacado: bool, moviendose: bool, noche: int) -> int:
	if not atacado:
		intensidad = maxf(intensidad - BAJA_POR_SEGUNDO * delta, 0.0)
	match fase:
		Fase.ARMANDO:
			if intensidad >= TOPE:
				_cambiar(Fase.SOSTENER, randf_range(SOSTENER_DURA.x, SOSTENER_DURA.y))
				return 0
			_turba_en -= delta
			if _turba_en <= 0.0:
				_turba_en = randf_range(TURBA_CADA.x, TURBA_CADA.y)
				return TURBA_BASE + maxi(noche, 1) * TURBA_POR_NOCHE + randi_range(0, TURBA_AZAR)
		Fase.SOSTENER:
			_tiempo -= delta
			if _tiempo <= 0.0:
				_cambiar(Fase.BAJANDO, 0.0)
		Fase.BAJANDO:
			if intensidad < ALIVIO:
				_cambiar(Fase.RESPIRO, randf_range(RESPIRO_DURA.x, RESPIRO_DURA.y))
		Fase.RESPIRO:
			_tiempo -= delta * (RESPIRO_MOVIENDOSE if moviendose else 1.0)
			if _tiempo <= 0.0:
				_cambiar(Fase.ARMANDO, 0.0)
	return 0


func nombre_fase() -> String:
	return ["Armando", "Sosteniendo", "Bajando", "Respiro"][fase]


func _cambiar(nueva: Fase, dura: float) -> void:
	fase = nueva
	_tiempo = dura
