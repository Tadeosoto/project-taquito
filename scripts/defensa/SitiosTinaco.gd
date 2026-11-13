class_name SitiosTinaco
extends RefCounted

## Los cinco tinacos de la defensa en el mapa completo (docs/mapa/zona-enfoque.md, M1 de
## docs/plan-noche.md): un parque o llano cada uno, con un tinaco puesto (FortalezasMapa) y a Chava
## parado afuera dando el contrato de dia (MisionesMundo). Al aceptarlo se entra a la defensa de ESE
## tinaco (PasoJefe + DefensaTinaco), de noche. Cada uno tiene su nivel: los dos mas cerca de Santa
## Mugre son los mas faciles y se complican conforme se alejan (JJ, 2026-11-12); la paga sube igual.
## (JJ intercambio despues los niveles de Parques del Mosco y de Parque Triangulito: el Mosco es el 3 y el
## Triangulito el 2.)
##
## `nivel` 1 a 5, `modo` el de Hordas.MODOS, `factor` lo que multiplica a `dificultad` (el tamano de
## los grupos), `pesos` lo que paga al amanecer (mas el galon de agua del .tres).

const SITIOS := [
	{"nombre": "Bahía de Banderas", "pos": Vector2(-336.0, -1.0), "nivel": 1, "modo": "facil", "factor": 1.0, "pesos": 150},
	{"nombre": "Parques del Mosco", "pos": Vector2(330.0, 95.0), "nivel": 3, "modo": "medio", "factor": 1.0, "pesos": 200},
	{"nombre": "Parque Triangulito", "pos": Vector2(-331.0, -359.0), "nivel": 2, "modo": "facil", "factor": 1.2, "pesos": 175},
	{"nombre": "Parque Central", "pos": Vector2(157.0, -344.0), "nivel": 4, "modo": "medio", "factor": 1.2, "pesos": 225},
	{"nombre": "Monos Rojos", "pos": Vector2(494.0, -529.0), "nivel": 5, "modo": "dificil", "factor": 1.0, "pesos": 250},
]
## Chava se para a esto del eje del tinaco (m, hacia el este): afuera de su cuerpo (radio ~1.1)
const CHAVA_A := 3.4

## El que se juega ahora (-1: ninguno; la escena de defensa sola usa su parque de prueba)
static var elegido := -1


static func sitio(k: int = elegido) -> Dictionary:
	return SITIOS[k] if k >= 0 and k < SITIOS.size() else {}


## Centro (x, 0, z) del tinaco `k`
static func centro(k: int = elegido) -> Vector3:
	var s := sitio(k)
	return Vector3(s["pos"].x, 0.0, s["pos"].y) if not s.is_empty() else Vector3.ZERO
