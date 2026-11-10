# Parques de Santa Mugre (colonia piloto del mapa en Blender)

> **Estado:** aprobada por AG (2026-11-10). Nada de esto está modelado todavía; sigue la tubería de Blender.
> Croquis: [`santa_mugre_croquis.png`](santa_mugre_croquis.png) (calles de OSM, huellas de Google Open Buildings, tiendas reales del DENUE; rejilla cada 20 m en coordenadas del juego).

## Qué es

El corazón de Santa Mugre, recortado de la colonia real (Parques de Santa María, Zapopan) en su tamaño real: la **plaza de Santo Toribio** con su parroquia, la avenida de las tiendas al sur y las cuadras de alrededor. Según `docs/lore.md` es "el centro denso: vecindades, tinacos en cada azotea, el tianguis, el palacio de gobierno, las filas del agua", con el tinaco comunitario en el parque y la propaganda en cada pared.

## El recorte

- **Esquinas** (metros del juego, el mismo marco que `resources/map/minimapa.json`): x **-420 a -185**, z **258 a 482**. Mide **235 × 224 m**: se cruza caminando en ~1 min y corriendo en ~25 s.
- Se queda en su lugar real, así que el minimapa, el mapa de papel y `ZonasMapa` funcionan sin tocarlos.

## Calles (reales)

| Calle | Dónde | Cómo es |
|---|---|---|
| **Av. Bahía de Todos los Santos** | sur, z 450-473 | Avenida con **camellón** (dos sentidos separados). La de las tiendas. |
| **Calle Bahía de Santiago** | x -278, de z 330 a la avenida | La calle principal norte-sur. Pasa junto a la parroquia. |
| **Calle Bahía de Pichilingue** | z 328, de x -281 a -191 | Oriente-poniente, al norte. |
| **Calle Bahía de Pelícanos** | x -412, todo el lado poniente | Borde oeste del recorte. |
| Calles sin nombre (`living_street`) | varias | Angostas, de un carril, algunas cerradas: privadas y callejones. |

✅ **Las calles se parodian**, como las colonias (`lore.md` §13: las reales no salen en el juego). Nombres aprobados por AG:

| Real | En el juego |
|---|---|
| Av. Bahía de Todos los Santos | **Av. Bahía de Todos los Sedientos** |
| Calle Bahía de Santiago | **Calle Bahía de Sin Agua** |
| Calle Bahía de Pichilingue | **Calle Bahía de Pipilingue** |
| Calle Bahía de Pelícanos | **Calle Bahía de Pelagatos** |
| Calles sin nombre | Privada del Tinaco, Callejón del Medidor, Cerrada de la Gota |

## Lugares

Los números son los del croquis.

1. **Plaza de Santo Toribio** (x -408 a -326, z 387 a 450). La plaza real con su kiosco en medio y un andador en curva. Aquí va el **tinaco comunitario**, el banco de agua del barrio: la fila del agua, los garrafones y un letrero de GelA con el horario. Es uno de los tres lugares de la misión "La vela del tinaco" (`docs/misiones.md` §0). Pasto seco, bancas, una fuente sin agua y propaganda en los postes.
   - ✅ El tinaco va **encima del kiosco**: el kiosco de la música se volvió la torre de agua del barrio, con mangueras, una llave abajo y la fila alrededor. Se ve desde las calles.
2. **Parroquia de Santo Toribio** (x -325 a -292, z 393 a 452). La iglesia real. Por fuera es una fachada grande; no se entra (por ahora).
   - ✅ **Se le nota un poco** el culto a la Virgen del Tinaco: la iglesia es normal, pero afuera hay veladoras con tinacos dibujados y estampitas pegadas en el portón. El culto vive en Los Garrafones y se está colando.
3. **Palacio de gobierno** (x -375 a -320, z 352 a 386). En el lado norte de la plaza, frente al kiosco, donde hoy hay un edificio largo. Dos pisos, portales, escudo de la familia Lazcano, mantas de GelA ("Trabajamos para llevarte agua"). **De noche se ilumina como si nada.** Aquí trabaja el Güero y está el archivo de la misión H4 (El Decreto 47). Por ahora solo la fachada y su puerta como marcador para el futuro.
4. **El tianguis** (Calle Bahía de Santiago, de Pichilingue a la avenida). Puestos con lonas de colores a los dos lados de la calle, cerrada a los coches. Solo de día; de noche quedan los fierros de los puestos. El **puesto de fruta de Toño** va en la esquina con la avenida, junto a la parroquia.
5. **La vecindad del jugador** (x -231 a -190, z 372 a 428). La privada real que entra desde la calle de z 372. Un patio largo con lavaderos, tendederos, tinacos en las azoteas, una escalera de fierro y puertas a los cuartos. Uno es **el cuarto del jugador** (escena aparte, segura). En el patio, 2-3 vecinos de día: la señora del lavadero, un niño y un señor en su silla. De noche el patio es calle, y es peligroso.
6. **El Yonke de Don Chava** (x -406 a -376, z 336 a 386). Se muda aquí desde donde está hoy (-232, 115, fuera del recorte): un baldío sobre Bahía de Pelícanos, junto a la plaza. Usa el mismo `YonkeMapa.gd`.
7. **Casa del Güero** (Pichilingue, x -262 a -236). Casa chica y bien pintada: la única de la cuadra con medidor de GelA nuevo. **Quién da misión:** de tarde, al volver del palacio. Adentro, las copias del Decreto 47 escondidas.
8. **El taller de Sofía** (callejón sin salida de x -326, al noroeste). Un taller mecánico con la cortina abajo; adentro, la radio pirata. **Quién da misión, de noche** (Sofía transmite de noche; `personajes.md`). Hay que saber dónde está: no tiene letrero.
9. **La casa clausurada** (calle de un sentido de x -199, al noreste). Sellos de clausura de GelA en la puerta y el medidor arrancado: a la familia le cortaron el agua y se fue. **Para saquear:** tiliches, comida, quizá un tazo. Se vacía una vez por partida.
10. **Casa de Toño** (calle de z 380, al este de Bahía de Santiago). Detrás de su puesto. **Vecino que intercambia:** de tarde compra y vende lo que le lleves (tiliches por objetos), y te cuenta chismes.

✅ AG aprobó las cuatro casas (7-10). Ideas guardadas para otra colonia: una familia con un zombi encerrado en el cuarto de atrás, y la señora que vende agua "de pozo" (falsa).

## Tiendas (las reales del DENUE que caen dentro)

| Tienda | Dónde (x, z) | Lado |
|---|---|---|
| Oxxo | -260, 451 | avenida, lado norte |
| Taquería La Casa de los Tacos | -269, 389 | Bahía de Santiago |
| Mini Super Santa María (abarrotes) | -259, 408 | Bahía de Santiago |
| Carnitas Vía 710 | -297, 285 | norte |
| Mini Super San Ignacio (abarrotes) | -298, 270 | norte |
| Farmacia Más Bueno, Ferretería, Cremería La Casita de Paty, Venta de Tacos | z ~475 | avenida, lado sur |

Cada una con su flecha amarilla y su interior de `scenes/interiores/`, como hoy.

✅ **Regla para todas las colonias** (AG): cada una tiene al menos un negocio de cada giro (ver [`README.md`](README.md)). A Santa Mugre le faltan tres, que se inventan:

| Tienda inventada | Dónde (x, z) | Por qué ahí |
|---|---|---|
| **Licorería** | -240, 475 | Avenida, lado sur, entre las tiendas reales. Ahí se compra el alcohol del Molotov. |
| **Purificadora** | -272, 345 | Calle Bahía de Sin Agua, en la punta norte del tianguis: la fila del agua se cruza con los puestos. |
| **El punto** | -372, 300 | Una casa en obra negra al fondo del callejón de x -370, con el deterioro al máximo. No sale en el minimapa (`especificaciones.md`). |

## Los bordes

El recorte se cierra sin paredes invisibles, con cosas que tienen sentido en el barrio:

- **Norte** (calle de z 263): **vallas de obra de GelA** atravesadas, tubos apilados y una manta: "Trabajamos para llevarte agua".
- **Poniente** (Bahía de Pelícanos): se camina la calle; del otro lado, **bardas y lotes enrejados**.
- **Oriente** (calle de x -188): una **casa derrumbada** sobre la calle y coches quemados.
- **Sur** (la avenida): se caminan los dos lados y el camellón. Del lado sur, las casas son **fachadas** (las tiendas sí se entran). En las puntas de la avenida, un **camión volteado** (poniente) y el **derrumbe** (oriente); las calles que salen al sur se tapan con barda.
- En el bloqueo (`tools/blender/mapa/colonias/santa_mugre.json`, `bordes`) cada lado tiene un tapón de color: norte GelA (naranja), poniente camión, oriente derrumbe, sur barda. Una barda gris rodea todo el recorte.

## Gente, luz y noche

- **De día:** el tianguis lleno, gente caminando por las banquetas (`Gente.gd`), la fila del agua en el tinaco, los vecinos de la vecindad.
- **Postes:** en las banquetas de la avenida y de Bahía de Santiago, más los de la plaza. En las privadas, focos colgados de los cables.
- **De noche:** "muy peligroso; los zombis salen en grupo y el palacio se ilumina como si nada" (`lore.md`). El índice de deterioro de Santa Mugre es 0.55-0.70: pocas tiendas con la cortina rota, algún tambo encendido.

## Lo que sigue (después de aprobar esto)

1. La tubería de Blender: el kit, el archivo de la colonia y la exportación a Godot (`scenes/mapa.tscn`).
2. El bloqueo con cajas grises de todas las cuadras, para caminarlo.
3. Las piezas del kit y el detalle.
4. Las tiendas, la gente, los postes, los zombis.
5. El cuarto del jugador. 6. Las otras casas.
