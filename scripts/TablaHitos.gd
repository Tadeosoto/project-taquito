class_name TablaHitos
extends Resource

# Los hitos de la noche sin fin y como crece todo noche tras noche (autoload Noches). Todos
# los numeros son primera propuesta (first guess): se ajustan jugando, sin tocar codigo.

@export var hitos: Array[HitoNoche] = []
## Las turbas (y los sueltos vivos que caben) crecen este factor cada noche: 1.15 = ~15 %
## (first guess). Con el tope de Zombis.max_total deja de crecer hacia la noche 8
@export var crecer_turbas := 1.15
## Despues del ultimo hito, una noche de jefe cada tantas noches: garrafonero, Madre del
## Carcamo, Mojiganga y otra vez (first guess)
@export var repetir_cada := 3
## Cada vuelta completa de jefes, su vida se multiplica por esto (first guess)
@export var repetir_fuerza := 1.25
## Desde el hito de Saltabardas: su espera entre uno y otro se multiplica por esto (first guess)
@export var saltabardas_factor := 0.6
## Desde ese hito, esta fraccion de los grupitos de sueltos salen cazadores (first guess)
@export var cazadores_sueltos := 0.25
## Desde el hito del Panzon: probabilidad de que una turba traiga uno (first guess)
@export var panzon_en_turba := 0.35
## Tazos que nunca salen de premio de hito (la leyenda que se quito del canon)
@export var tazos_excluidos: Array[String] = ["tinaco_eterno"]
