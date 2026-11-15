class_name RitmoNoche
extends Resource

# Como salen los zombis de noche en el mapa (JJ, 2026-11-04): no se trata de estar matando
# todo el tiempo, sino de poder cumplir objetivos nocturnos con sustos. Ratos tranquilos, de
# vez en cuando uno o dos sueltos (mas seguido donde esta mas destruido, Deterioro.relativo),
# y una o dos turbas por noche de 7-8 en bola a una hora al azar. La meta es ~30 muertos en
# una noche de 6 min (en la defensa del tinaco, frenetica, son ~80). Zombis.gd lo usa si
# tiene `ritmo`; si no, el Director de siempre. Todo es para ajustar jugando: al amanecer
# Partida dice cuantos salieron y cuantos mataste (y la consola, con mas detalle).
# El del safehouse y el mapa de Blender es resources/zombis/noche_mapa.tres. El de map_test (afuera
# de las fortalezas, S4 de docs/plan-noche.md) es noche_afuera.tres: continuo pero menos que la
# defensa (lore §14): grupitos de 1-3 cada 12-30 s, hasta 4-7 sueltos y 2-3 turbas de 6-8, ~50 por noche.

@export_group("Sueltos")
# s sin nada al anochecer
@export var calma_inicial := 25.0
# s entre un grupito y otro: donde esta mas entero y donde esta mas destruido
@export var cada_entero := Vector2(35.0, 55.0)
@export var cada_destruido := Vector2(15.0, 25.0)
# Cuantos salen juntos
@export var grupo := Vector2i(1, 2)
# Mas sueltos vivos que esto no sale ninguno (entero, destruido)
@export var vivos_entero := 2
@export var vivos_destruido := 4
# Cada noche despues de la primera, los grupitos salen esta fraccion mas seguido
@export var mas_por_noche := 0.15
# Si el Director dice que hay que respirar (te pegaron mucho, mataste muchos cerca), no
# salen sueltos hasta que se calme
@export var respetar_director := true

@export_group("Turbas")
# Cuantas por noche (al azar entre los dos)
@export var turbas := Vector2i(1, 2)
# De cuantos
@export var turba := Vector2i(7, 8)
# En que parte de la noche pueden salir (0 = anochece, 1 = amanece)
@export_range(0.0, 1.0) var turba_desde := 0.15
@export_range(0.0, 1.0) var turba_hasta := 0.8
# s minimos entre una turba y otra
@export var turba_separadas := 70.0
# rad de ancho del lado de donde salen: chico = en bola
@export var turba_abre := 0.2
# Cazadores: mas rapidos y siempre van por ti
@export var turba_cazadores := true


func cada(deterioro: float, noche: int) -> float:
	var minimo := lerpf(cada_entero.x, cada_destruido.x, deterioro)
	var maximo := lerpf(cada_entero.y, cada_destruido.y, deterioro)
	return randf_range(minimo, maximo) / (1.0 + mas_por_noche * maxi(noche - 1, 0))


func vivos_max(deterioro: float) -> int:
	return roundi(lerpf(vivos_entero, vivos_destruido, deterioro))


# Las horas (s desde que anochecio) de las turbas de esta noche, separadas
func horas_turbas(noche_dura: float) -> Array[float]:
	var cuantas := randi_range(turbas.x, turbas.y)
	var horas: Array[float] = []
	for intento in 40:
		if horas.size() >= cuantas:
			break
		var t := randf_range(turba_desde, turba_hasta) * noche_dura
		if horas.all(func(h: float) -> bool: return absf(h - t) >= turba_separadas):
			horas.append(t)
	horas.sort()
	return horas
