# Pruebas del caminar de los zombis (enjambre)

Alan reportó que los zombis caminaban en fila india, de punto a punto, como robots, sin verse amenazantes. Este documento junta lo que se midió antes y después del cambio, y cómo volver a medirlo.

## Por qué caminaban en fila

El camino viene de `CampoFlujo.gd`: una rejilla de 1.25 m alrededor de la meta, y cada celda sabe hacia qué vecina se llega antes. Esa dirección es una de ocho (de 45 en 45 grados), y como la rejilla se llena con cuatro vecinos, los caminos salen en escalera. Todos los zombis de una celda recibían el mismo vector exacto y lo usaban directo como velocidad, así que tomaban la misma línea, uno detrás de otro, y daban vueltas en seco al cambiar de celda. Además todos iban a velocidad fija.

## Lo que cambió (`Zombie.enjambre`)

- **Atajos**: el zombi sigue el campo 8 celdas adelante y, si ese punto se ve derecho (tres rayos: las dos orillas del cuerpo y el centro), va derecho a él. Si no, usa la dirección del campo mezclada entre las cuatro celdas de alrededor (`direccion_suave`), sin brincos de 45 grados.
- **Carriles**: cada zombi va a su lado del camino (hasta 1.5 m) y se mece un poco. Cerca de su meta (un hueco de la barricada, el tinaco, el jugador) se junta otra vez al camino para que sí pase y sí pegue. Si otro más lento lo frena lejos de la meta, se abre para rebasarlo.
- **Giro poco a poco**: acelera hacia donde quiere ir en vez de cambiar de dirección de golpe.
- **Velocidad que sube y baja** (±15 %) y arrancones de vez en cuando: unos alcanzan a otros y se amontonan.
- **Sin quedarse empujando**: si choca de frente contra algo (un tambo, un poste, la punta de una pieza), se va de lado a lo largo de eso enseguida. Cerca de un hueco solo va derecho si lo ve; llegando de lado, la punta de una pieza se lo tapaba.
- El jefe solo gira poco a poco: su velocidad es parte de su balance.

Con la tecla **0** en el safehouse se regresa al caminar de antes, para comparar jugando.

## Cómo se midió

Con dos pruebas sin ventana que corrían el código del juego (no una copia), las mismas semillas con el caminar nuevo y con el de antes: la barricada de la defensa sobre piso plano, sin mapa, y el safehouse de noche (el jugador brincando de lugar cada 8 s, turbas cada 15 s). Esas pruebas ya no están en el repo (vivieron en la rama `enjambre`); para comparar ahora, la tecla 0 del safehouse cambia entre los dos caminares.

Lo que se midió en la barricada:

- **mismo camino**: % de las celdas de 0.5 m que pisa un zombi que ya pisó otro de su grupo. Es el "trenecito" aunque vayan separados.
- **fila**: % del tiempo que un zombi trae otro justo enfrente (menos de 2.5 m adelante y 0.6 m de lado).
- **llegada**: segundos de que sale a que le pega al tinaco.
- **rodeos**: veces que se atoró y se hizo a un lado, por zombi. **sin llegar**: zombis que no llegaron en 45 s.

## Resultados: barricada (20 corridas, mismas semillas)

| | Antes | Enjambre |
|---|---|---|
| **Grupos de 9** (semillas 1-20) | | |
| Mismo camino | 26.3 % | **17.3 %** |
| Fila | 8.2 % | 6.6 % |
| Llegada (media) | 14.3 s | 13.5 s |
| Rodeos por zombi | 0.08 | **0.00** |
| Sin llegar | 0 | 0 |
| **Grupos de 7, 40 % corredores** (semillas 101-120) | | |
| Mismo camino | 20.7 % | **12.3 %** |
| Fila | 5.2 % | 2.5 % |
| Llegada (media) | 13.1 s | 12.4 s |
| Rodeos por zombi | 0.05 | **0.00** |
| Sin llegar | 0 | 0 |

Prueba de aguante con el enjambre: 40 corridas de grupos de 9 con 40 % de corredores (semillas 301-340), 0 rodeos y todos llegaron.

En el camino se encontraron y arreglaron dos atorones que el enjambre traía al principio: zombis que se quedaban empujando la punta de una pieza junto a un hueco (2 de 20 corridas) y rodeos contra los tambos, que cabían entre los dos rayos de las orillas.

## Resultados: safehouse

50 s de noche por semilla, turbas de 8 cada 15 s y el jugador brincando de lugar cada 8 s. "Lento" es el % del tiempo caminando (a más de 4 m del jugador) en que van a menos del 30 % de su velocidad: atorados en una pared o trabados entre ellos.

| Semilla | Antes: rodeos / lento | Enjambre: rodeos / lento |
|---|---|---|
| 1 | 0 / 10.1 % | 0 / 11.5 % |
| 2 | 0 / 24.3 % | 0 / 16.8 % |
| 3 | 1 / 16.3 % | 0 / 5.3 % |
| 4 | 0 / 6.7 % | 1 / 5.8 % |
| **Promedio** | **14.4 %** | **9.9 %** |

Entre casas y negocios no se atoran más que antes, y van trabados menos tiempo.

## Rendimiento

Mismo costo que antes. En el safehouse, todo el juego sin dibujar, por cuadro: 4 zombis 2.8 ms antes / 3.1 ms ahora, 12 zombis 3.6 / 3.7 ms, 28 zombis 6.8 / 6.5 ms (las diferencias van para los dos lados: es ruido). El presupuesto a 60 FPS es 16.7 ms.

Pendiente aparte, que no es del enjambre (pasa igual con el caminar de antes): una noche de 120 s en el safehouse con turbas cada 15 s y el jugador sin morirse se alentaba mucho después del segundo 60. Vale la pena buscar qué crece (sangre, restos, turbas) por las noches largas.

## Falta

- Jugarlo: la defensa con el monitor (¿el modo medio quedó más duro?, ver `docs/pruebas-balance.md`) y el mapa de verdad, con calles angostas, que ninguna de las dos pruebas cubre.
- Si los carriles se sienten muy abiertos o muy cerrados: `CARRIL` y `VAIVEN` arriba de `Zombie.gd`. Con 2.5 m el "mismo camino" bajaba poco (de 16.7 a 15.1 %) y llegaban más desparramados.
