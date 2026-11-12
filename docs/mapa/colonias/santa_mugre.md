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
4. **El tianguis** (Calle Bahía de Santiago, de Pichilingue a la avenida). Carpas de lona de colores sobre tubos a los dos lados de la calle, con la espalda en la banqueta y las lonas casi tocándose sobre el pasillo: un techo seguido de lona, apretado y caótico, con las banquetas libres. Solo de día; de noche quedan los fierros y las mesas. El **puesto de fruta de Toño** va en la esquina con la avenida, junto a la parroquia.
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
- En el bloqueo (`tools/blender/mapa/colonias/santa_mugre.json`, `bordes`) cada lado tiene un tapón de color: norte GelA (naranja), poniente camión, oriente derrumbe, sur barda. Una barda gris rodea todo el recorte; donde la avenida (Av. Bahía de Todos los Sedientos) sale por el poniente y el oriente, en lugar del camión y el derrumbe hay una **reja de fierro** (`rejas` del `.json`, pieza `reja`), con la barda partida alrededor. Adentro de cada reja hay una flecha amarilla de salida (marca `salida_colonia`) que lleva a `map_test` por ese lado; en `map_test` la misma reja (`MuroColonia`) tiene su flecha de entrada por fuera. El paso lo hace `scripts/mapa/PasoColonia.gd` (fundido, la hora del día y el lado).

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

## Como quedo (2026-11-10)

- **Negocios** (`tiendas` del `.json`, nombres parodiados como todo el juego): OXO (avenida), Tacos La Casa del Taco y Mini Super Santa Mugre (Bahia de Sin Agua), Carnitas Via Mugre y Abarrotes San Ignacio (al norte), Farmacia Mas o Menos Buena, Ferreteria El Clavo y Cremeria La Casita (avenida, lado sur), Vinos y Licores El Ultimo (avenida), Purificadora Gota Pura (punta norte del tianguis) y **El Punto**, que se movio junto al primer callejon porque en su lugar quedo la cancha. Cada uno con su cortina, su letrero y su flecha; los puestos del tianguis se quitan de enfrente de las puertas.
- **Lo que se agrego despues de la ficha** (pedido de AG): la cancha de futbol rapido en la manzana del noroeste, murales y propaganda de GelA, lotes con vida (taller mecanico, juegos, fonda), seis callejones con su patio, tres rutas por las azoteas con escalera, postes con cables, la vecindad con patio largo y los tapones de los bordes.
- **La casa del jugador:** la puerta de la vecindad lleva a la casa de JJ (`scenes/casa_personaje.tscn`, se camina, sin pelea y abierta de noche), como los cuartos de la familia en la vecindad. Adentro: la cama (dormir hasta la siguiente orilla y curarte), el ropero (cambiarte), la vitrina de trofeos, el album en la mesa, la libreta en el sillon, la tele con noticias de GelA, el baul (se vacia con la partida), el altar de la Virgen del Tinaco, los garrafones y el mapa de papel en la pared.
- **Las casas de los vecinos** (7-10): se entran caminando como la del jugador. El Güero (platica), el taller de Sofía con la radio pirata (solo abre de noche), Toño (platica y vende mazapanes) y la casa clausurada por GelA (el sello y lo que dejaron, una vez por partida). Sus misiones vienen después.
- **En el juego** (`scenes/mapa.tscn`): Ciclo, zombis de noche (`noche_mapa.tres`), Supervivencia, Partida (pieza del mapa, misiones con sus vecinos) y gente en las banquetas.
- **La cancha, mas chica** (AG, 2026-11-10, con la foto de una cancha de favela): de 22 × 36 m de losa a 12.6 × 19.6 (futbolito de 11 × 18), en medio de la manzana del noroeste y encajonada: muro de block pintado de azul con grafitis y propaganda por dentro, malla hasta 5 m con lonas de anuncios, piso a franjas verde y amarillo, un escalon para los que miran y siete casas de 3 y 4 pisos pegadas a la malla (`Cancha_Casa_*`). Se entra por un callejon desde Bahia de Pelagatos (`Callejon_Cancha`) y una reja. Lo que sobro de la manzana lo lleno `bloqueo.py` con casas y lotes.
- **Detalles de las casas** (2026-11-10): `kit._detalles_casa` les pone, con azar fijo por casa, climas de ventana en los pisos de arriba y, en la azotea, antena, calentador solar, tanque de gas y tendedero con ropa. Todo con el material de la fachada y color de vertice: ni materiales ni superficies nuevas (`casa_malla(detalles=False)` los quita).
- **Mirador de la cancha**: una casa de dos pisos (`Cancha_Mirador`) en la esquina del callejon de la cancha, con escalera de fierro: desde su azotea se ve el partido y, de noche, es un escape. Las casas del `.json` aceptan `"detalles": false`.
- **Tendederos en los callejones**: `colonia._tendederos` cruza cuerdas de fachada a fachada cada 4.5-8 m en cada callejon (empedrado sin banqueta), colgadas a 3.4-5.2 m, tres de cada cuatro con ropa. Una sola malla (`Tendederos`), sin choque.
- **Para orientarse de lejos**: dos espectaculares en azoteas (`Espectacular_Cancha`: "Cuida el agua" de GelA hacia la plaza y Lazcano atras; `Espectacular_Avenida`: GelA hacia la avenida y el garrafon atras) y la antena pirata de Sofia, roja y blanca de 12 m, sobre su taller (`Antena_Sofia`): el taller sigue sin letrero, pero la antena se ve de toda la colonia. Van sobre casas a mano con reserva (`Casa_Antena_Sofia`, `Casa_Espectacular`), para que `bloqueo.py` no las cambie.

## Noche del 2026-11-10: hecho y pendiente (para AG)

Hecho (un commit cada uno, `probar_colonia.gd` en BIEN despues de cada uno):
1. Cancha chica y encajonada (pruebas nuevas: se entra caminando por el callejon).
2. Climas, antenas, calentadores solares, tanques de gas y tendederos en las casas.
3. Mirador con escalera junto a la cancha (prueba nueva: se sube a la azotea).
4. Tendederos con ropa cruzando los callejones.
5. Espectaculares de GelA y la antena pirata de Sofia.
6. Capillitas de la Virgen del Tinaco cerca de la entrada de los callejones y basura junto a sus paredes (`colonia._vida_callejones`, malla `Callejones_Vida`, sin choque).
7. Rejas de herreria (negras, blancas, verdes o rojas, una por casa) en las ventanas de planta baja (`kit._detalles_casa`, sobre el mosaico `VENTANA_ABAJO`).
8. Media canchita de basquet como quinta variante de los lotes (`lote` `basquet`; `bloqueo.VARIANTES_LOTE` se turna, asi que los baldios cambiaron de variante).
9. Reflectores de la cancha prendidos de noche (marca nueva `reflector` en `Colonia.gd`, dos `SpotLight3D` sin sombra que siguen a `Ciclo.valor()`; prueba nueva de dia y de noche). Los dos espectaculares tambien se iluminan de noche (reflectores hacia arriba, `baja` negativa, `alcance` 7 m).
10. Focos colgados en los callejones (24, uno cada 10-15 m): `colonia.focos_callejones` da donde van, `colonia.py` dibuja cable y foco, `exportar.py` los escribe como marcas `foco` (no van en el `.json`) y `Colonia.gd` pone una `OmniLight3D` chica de noche; uno de cada cuatro parpadea.
11. Casas de ladrillo sin aplanar como en la foto (`casa` con `"acabado": "ladrillo"`: mosaico `LADRILLO` en los muros lisos, color ladrillo alrededor de las ventanas, dalas grises en cada losa y castillos en las esquinas). Cuatro de las de la cancha, y una de cada cinco casas `auto` de dos pisos o mas (`colonia.LADRILLO_CADA`, fijo por nombre).
12. Reten de GelA en el carril norte de la avenida, frente a la plaza (`Base_GelA`, pieza `base_gela`): caseta blanca y azul, pipa de agua con "Cuida el agua", vallas atravesadas, conos, garrafones y bandera. Cierra medio carril. Los guardias de dia vienen despues (ver preguntas).
13. Dos negocios nuevos, solo por fuera, con flecha que dice "Proximamente": **Tortilleria La Lupita** en Bahia de Sin Agua junto al tianguis (`tortilleria`: toldo verde, mostrador de azulejo, maquina) y **Abarrotes Doña Mary**, tiendita de cochera en el mirador de la cancha sobre Pelagatos (`tiendita`: toldo rojo, refri de refrescos, el de paletas, rejas). Sus giros `tortilleria` y `tiendita` aun no tienen interior en `Interiores.escenas`.
14. Botin en las azoteas para el que sube: uno en una casa de cada ruta de azoteas y otro en el mirador de la cancha, turnando chatarra (tiliches), Takis con tazo y tacos o caguama (`colonia.botin_azoteas`, marcas `botin` que escribe `exportar.py` y arma `Colonia.gd`; prueba nueva).
15. Mision **La pelota en la azotea** (`resources/misiones/pelota.tres`): el profe de la cascarita, parado en el callejon de la cancha (marca `mision` `Profe_Cancha`), te pide bajar la pelota de la azotea del mirador (marca `Pelota`) y regresarsela; 50 pesos. Para eso: `MisionData.donde` ("marca:<nombre>") pone al que la da en una marca de la colonia, y `RECOGER` acepta `lugar` "marca:<nombre>" (la cosa con flecha, sin ladridos; su modelo de `objetos`[0] o una pelota). Sin colonia (safehouse, `map_test`) cae a lo de antes: poste y perro. El safehouse tiene un lugar mas para el que la da. Prueba nueva.
16. Chamacos jugando futbolito en la cancha de dia (`scripts/mapa/NinosCancha.gd`, marca `ninos`: seis civiles al 70 %, el mas cercano persigue la pelota y la patea a otro lado, los demas rodean; de noche no hay nadie) y dos guardias en el reten de GelA de dia (marca `vecino`: un civil quieto que se va de noche). Los guardias llevan chaleco y gorra azul de GelA (`scripts/personajes/UniformeGela.gd`, marca `vecino` con `"uniforme": "gela"`: mallas colgadas de los huesos `Chest` y `Head`, porque los civiles aun no tienen mascara de ropa). Pruebas nuevas de dia y de noche.
17. Arreglos vistos en capturas de Godot: los grafitis y lonas de la cancha salian en espejo, el reverso azul de las lonas peleaba con el anuncio, la tortilleria habia quedado dentro de la casa y un puesto del tianguis tapaba su flecha (`bloqueo.py` ya quita los puestos frente a cualquier puerta, no solo las automaticas).
18. Pasillo angosto de tierra (1.1 m, `Pasillo_Tianguis`, con su reserva) que cruza la manzana grande de Bahia de Sin Agua a la calle de la vecindad a la altura de la tortilleria: de noche los zombis te siguen en fila. No es callejon (tierra, no empedrado), asi que sin casas de frente, basura ni tendederos. `bloqueo._encima` ahora revisa lado por lado las reservas de menos de `TIRA` 2 m: el relleno ponia una casa encima (con todas las reservas perdia 40 casas del relleno, por eso solo las angostas). Prueba nueva: se cruza caminando.
19. De noche la cancha es trampa (AG): con los reflectores prendidos, si estas adentro cada 6 s hace `Zombie.ruido` a 35 m, como un balazo (`scripts/mapa/LuzTrampa.gd`, marca `trampa`). Una sola reja: la aguantas o te acorralan. Numeros para ajustar jugando.
20. La tortilleria ya se entra: `scenes/interiores/tortilleria.tscn` (ventanilla verde, la señora de la masa) vende **Kilo de tortillas** (`resources/productos/tortillas.tres`, $22, cura 15, se apila; modelito en `models/objetos/tortillas/`) y Jarritos. Giro `tortilleria` en `mapa.tscn` y en el safehouse (local de taqueria al final de la fila). Prueba nueva. Doña Mary sigue en "Proximamente".
21. El palacio de gobierno se ilumina de noche "como si nada" (`lore.md`): cuatro reflectores en el piso viendo a la fachada y cinco focos bajo el portal (marcas `reflector` y `foco`). Fila de cuatro civiles en la tortilleria de dia (marcas `vecino` `Fila_Tortilleria_*`).
22. Carros abandonados (32) junto a la banqueta de las calles: la mitad enteros, los demas sobre ladrillos o quemados, alguna combi (`carro` con `estado` y `modelo`; `colonia.carros_estacionados` los pone cada 28-50 m lejos de marcas, puestos, el reten y los cruces; con choque, no van al `.json`). **Ya no son cajas**: son 4 modelos de Sketchfab (`models/vehiculos/`: Grand Vitara, Tsuru, vocho de 1967 y van blanca, sin pintar) que dibuja `scripts/mapa/CarrosColonia.gd` desde `resources/mapa/santa_mugre/carros_modelo.json` (38 en total, con los del taller y el quemado de la casa derrumbada); en el .glb solo queda su caja de choque. `ladrillos` = sin llantas (`CarrosModelo.sin_ruedas` quita las piezas sueltas de las llantas) y sobre dos blocks bajo cada una; `quemado` = `CarrosModelo.quemado` con `shaders/ps1_quemado.gdshader` (pintura ceniza y oxido, manchas negras de hollin y los vidrios, lo casi negro de la textura, negros del todo).
23. Muros envejecidos (`shaders/ps1_fachada_kit.gdshader`): franja de humedad oscura y verdosa que sube del piso con borde ondulado (`humedad_alto` 0.5-1.2 m, `humedad_fuerza`), costra blanca de salitre en su orilla (`salitre_fuerza`) y `saturacion` 1.2 para que el color de las casas no se vea deslavado. Solo en las casas del mapa en Blender.
24. Topes (15) a media cuadra en los tramos de mas de 40 m de las calles con banqueta, amarillo y negro, con choque en rampa: se pasan caminando (`tope`, `colonia.topes`, no van al `.json`; prueba nueva). Los baches y grietas ya los pinta `ps1_suelo` segun el deterioro.
25. Mercado techado detras del palacio, frente a la calle de z 333 (`Mercado`, pieza `mercado`, 30 x 18 m, con reserva): techo de lamina a dos aguas en postes de fierro, dos filas de puestos con fruta, cajas de chiles y costales, un foco colgado en cada uno, y su letrero "Mercado Municipal Santa Mugre" (marca nueva `letrero`). Quito siete casas auto; las que dependen de casas auto (antena, espectacular, tortilleria) siguen en su lugar.
26. Costo: con carros, topes, mercado y los 12 civiles nuevos bajo de ~282 a ~245 fps en la plaza; los civiles (chamacos, guardias, fila) ya no se dibujan ni se animan a mas de 70 m (`NinosCancha.LEJOS`) y quedo en 275 (avenida 294, cancha 264; llamadas de dibujo 680 contra 560 antes de carros y mercado: cada color de lona y carro es otra superficie por cuadro).
27. Charcos en la mitad de los baches del asfalto (`ps1_suelo.charco`, `charcos` 0.5): oscuros y lisos, brillan con las luces de noche. Vale para `map_test` tambien (mismo shader).
28. El tianguis de noche queda en fierros y tablones (ficha §4): `puesto` pone la lona y la mercancia en `k.dia`, `colonia.py` lo saca como objeto `Dia_<nombre>`, `MapaPostImport` lo junta en cuadros `Dia_x_y` (grupo `solo_dia`) y `Colonia.gd` los esconde con `Ciclo.valor()`. Sirve para cualquier pieza que ponga algo en `k.dia`. Prueba nueva.
29. Lo que prometia la ficha: la **fila del agua** en la llave del kiosco (cinco civiles con su garrafon azul, `Fila_Agua_*`), los **vecinos de la vecindad** de dia (la señora en el lavadero con `Interact`, el señor sentado con `Sitting_Idle`, un niño al 70 %) y la **devocion en el atrio** (13 veladoras con flama y el tinaco impreso, el tinaquito de yeso de la Virgen con flores, estampitas en la reja y un foco que las hace brillar de noche). La marca `vecino` acepta `escala` y `garrafon`.
30. **Verticalidad** (AG: todo era plano; cambios locales y sutiles): la cancha esta hundida 1.2 m (`y` -1.2) y se baja por una zanja con escalones, muros y barandal desde el callejon (`bajada`). El piso del recorte ya acepta huecos: `hundidos` en el `.json` (rectangulos con su `fondo`), y `colonia._piso` arma el piso en cajas alrededor y otra al fondo de cada hueco. Lo que va adentro lleva su `y` (cancha, chamacos, reflectores).
31. Mas verticalidad: el palacio sobre un **basamento** de cantera de 0.45 m con escalones a todo lo ancho (`basamento`, palacio con `y` 0.45) y un **puente peatonal** de fierro a 5 m sobre la avenida frente a la plaza (`puente`, con mantas de GelA y escaleras de fierro en cada banqueta; desde arriba se ve la avenida y el reten). Ojo al poner escaleras que llegan de lado a algo: la rampa debe rebasar la orilla apenas (0.1 m) y quedar un poco mas alta (5.15 contra 5.0), o el cuerpo topa con la orilla como si fuera escalon. Pruebas nuevas.
32. Tres misiones chicas en los lugares nuevos (cada quien parado en su marca `mision`): **Tortillas para la vecina** (la del lavadero: dos kilos de La Lupita, 70 pesos), **Agua para la fila** (el señor del final de la fila del kiosco: un galon de la purificadora, 60) y **Chiles para el mercado** (la marchanta: el costal de chiles en un puesto del tianguis, 45; producto nuevo `costal_chiles.tres`). `MisionesMundo._tienda` ahora tambien encuentra las flechas de la colonia (`Colonia.puertas`) para giros que no estan en `puntos.json`. El safehouse tiene tres lugares mas para los que las dan. Pruebas nuevas.
33. Placas azules con el nombre de las calles en su poste (47): los nombres parodiados de la ficha en `nombres_calles` del `.json` (Av. Bahia de Todos los Sedientos, Bahia de Sin Agua, Pipilingue, Pelagatos, Privada del Tinaco, Callejon del Medidor, Cerrada de la Gota); `colonia.placas_calles` las pone en las puntas y a medio tramo de los largos, `exportar.py` las vuelve marcas `placa` y `Colonia.gd` arma poste, placa y texto por las dos caras.
34. De noche el reten de GelA queda solo y su caja azul se abre una vez por noche: suelta 1-2 cosas al azar (galon de agua, tacos, Takis con tazo, cinta; si no caben quedan tiradas) y se vuelve a llenar al amanecer (`scripts/mapa/CajaGela.gd`, marca `caja_gela`). De dia el aviso dice que la cuidan. Prueba nueva.
35. Noche mas oscura en `scenes/mapa.tscn` (AG): luna 0.18 (antes 0.35), ambiente 0.45 (antes 0.75) y niebla y fondo mas negros; solo este mapa, `map_test` sigue igual. Revisar jugando: en una captura con el jugador en la calle, el poste mas cercano casi no iluminaba el piso a sus pies (`MapAlumbrado` reparte 16 luces cerca del dron; puede ser la altura o el alcance de 22 m).
36. Mas verticalidad: el **atrio** de la parroquia sobre un basamento de 0.6 m con escalones (las veladoras y el tinaquito bajan a la calle, pasando los escalones: el atrio sabe su `y`) y el **kiosco** sobre un plinto octagonal de cantera de 0.45 m con escalones alrededor (`plinto`, choque de ocho cuñas en rampa); la fila del agua se recorrio hacia afuera. Pruebas nuevas.
37. Ruta de azoteas nueva al poniente de la cancha, sobre Pelagatos (`Ruta_Cancha` en `rutas`: tres casas de dos pisos con escalera) y un tablon que cruza el callejon de la cancha hasta la azotea del mirador. **Ojo:** cualquier cambio de reservas o rutas recorre la numeracion y la alternancia del relleno de `bloqueo.py`: la casa de la tortilleria se volvio un baldio. Las tres casas de las que cuelga algo puesto a mano ahora son piezas a mano con su reserva: `Casa_Tortilleria`, `Casa_Antena_Sofia` y `Casa_Espectacular` (antes `Lote_57`, `Casa_218` y `Lote_17`). Hagan lo mismo con cualquier cosa nueva que se ponga sobre una casa `auto`.
38. **Manzana en terraza** al noreste (entre las calles de x -237, x -194 y z 283): toda la manzana 0.75 m arriba sobre su muro de mamposteria, con escalinatas de piedra desde la banqueta sur y la poniente (`terrazas` en el `.json`; `colonia._terrazas` arma la plataforma y sube lo que cae adentro por su centro, sin tocar el `.json`; pieza `escalinata`). Leccion para rampas que llegan a algo mas alto: la rampa debe llegar justo a la altura en la orilla y seguir plana encima; si rebasa la altura o se queda corta, el cuerpo se apoya en la orilla a mas de 45 grados y se atora. Prueba nueva.
39. **Jardines hundidos** en la plaza: los seis pastos entre los andadores 0.25 m abajo, con orilla en talud de 0.6 m (se entra y se sale caminando); lo que esta adentro (arboles, bancas) baja con ellos. Para eso el piso del recorte ahora es una malla triangulada (`tessellate_polygon`) con huecos poligonales y choque de malla: `hundidos` acepta `poligono`, `pieza` (la huella de un jardin), `borde` (talud) y `bajar_piezas`. La cancha y su zanja son un solo poligono. El spawn cae en un jardin (queda 0.25 m abajo). Prueba nueva.
40. Costo despues de la verticalidad (dia): plaza 232 fps y 882 llamadas de dibujo (antes 275 y 678: la fila del agua con sus garrafones, el plinto, el atrio y los jardines quedan a la vista del spawn), tianguis 236, vecindad 250, avenida 258, cancha 247; de noche 254-290. Si pesa: los garrafones son una malla por civil (se pueden juntar en un MultiMesh) y los civiles de la fila podrian esconderse a menos de 70 m.
41. **Tianguis nuevo** (noviembre 2026, JJ): los 44 `puesto` del `.json` se cambiaron por dos tramos de `tianguis` (Sur, de la avenida a la calle de Toño, y Norte, hasta la purificadora) que arma `scripts/mapa/Tianguis.gd`: carpas de cinco tipos (`models/tianguis/carpas`), giros de fruta, verdura, abarrotes, chácharas, limpieza, tortillas, ropa, tacos y tejuino con piezas del proyecto, marchantes, compradores y gente pasando por el pasillo. Deja huecos frente a las puertas (tortilleria, Mini Super, purificadora) y en las calles que cruzan (la de Toño, el callejon de la purificadora, `Pasillo_Tianguis`). Tacos El Guero y el Tejuino de Don Chuy quedaron dentro del tianguis, debajo de una carpa (`bajo_carpa`). Prueba de noche cambiada a los tramos. Costo en la PC de JJ (`tools/tianguis/medir_tianguis.gd`): +3 a 5 ms de GPU y +1 a 2 ms de CPU dentro del tianguis.

Costo medido con `tools/mapa/medir_colonia.gd` (maquina de AG, de dia), antes de esta noche y despues de los 7 puntos: plaza 293 a 287 fps (primitivas 124k a 228k), tianguis 283 a 278 (195k a 339k), vecindad 287 a 280, avenida 335 a 321, cancha 304 a 298 (llamadas de dibujo 539 a 661). Baja 2-4 % de fps pero casi se doblan las primitivas: **Arreglado (2026-11-11):** los detalles (material `detalle_kit` de las casas y los objetos `Detalle_*` de los callejones, partidos en trozos de 20 m) van en cuadros de 24 m aparte que `MapaPostImport` deja de dibujar a 55 m y que no hacen sombra. Medido despues: plaza 132k primitivas (antes 228k, sin detalles 124k), 560 llamadas, tianguis 206k, cancha 151k; los fps quedan igual.

Para revisar caminando (`scenes/mapa.tscn`): el color del muro y del piso de la cancha en Godot (en Blender se ven deslavados), si la ropa y los cables se ven bien de noche, y si los espectaculares se leen de lejos con la niebla.

Ideas que siguen, en orden (del plan de esa noche):
- Puertas de herreria (zaguanes).
- La fila de la tortilleria (gente de dia) y el interior de Doña Mary.
- Mas pasillos como el del tianguis donde haga falta (casi todas las manzanas ya tienen callejon).
- Suelo: grietas, parches, banquetas rotas por las raices.

