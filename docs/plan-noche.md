# Megaplan "Noches de fuera"

Campaña de varias sesiones: Santa Mugre como fortaleza, el afuera bajo Serenol, el reparto de agua sin Serenol de noche (el ciclo de dinero y mejoras), y las otras dos fortalezas. Lore y misiones van de la mano: no se programa nada que no esté primero en `lore.md` y `misiones.md`.

## Cómo se usa (para Claude y para JJ)

1. **Al abrir sesión:** lee este archivo, dile a JJ **"Hoy toca: <primer bloque con casillas sin tachar>"** (una línea, con el tamaño y qué lo desbloquea) y pregunta si lo hacen o prefiere otro.
2. **Un bloque ≈ una sesión.** Al terminar: tacha `- [x]`, escribe una fila en el **Registro** (fecha, bloque, qué se hizo, siguiente) y, si hubo decisiones nuevas, pásalas a "Decisiones".
3. Marcas: ✅ decidido por JJ · 💡 propuesta sin votar · ⛔ bloqueado por otro bloque.
4. Antes de cada entrada de lore o misión: `graphify query "<pregunta>" --graph docs/graphify-out/graph.json`, y las skills `/game-lore`, `narrative-quest-narrative-coherence` y `/game-quest` (ver `CLAUDE.md`).
5. Cada bloque de código tendrá su propio plan al empezar. Reglas de siempre: avisar a JJ antes de tocar su código de pelea, agregar cada mecánica a la safehouse, textos para el jugador en español, medir FPS con `tools/medir_mapa.tscn`.

## Registro de sesiones

| Fecha | Bloque | Qué se hizo | Siguiente |
|---|---|---|---|
| 2026-11-11 | Diseño | Se plantearon las tres fortalezas, el ciclo del agua de noche y se votaron 10 choques de lore (abajo). Se creó este megaplan y la rama `lore-noche-fortalezas` | L1 |
| 2026-11-11 | L0 a L6 | Pasada de `lore.md`: línea de tiempo, §5 (policía de día, palacio afuera), §8 (zombis reconocen el Serenol), §9 (Chuy sospecha, templo de Santa Mugre), §10, §11 (Gotera vende agua limpia), §13 (tres fortalezas, Reservorios, Haciendas sin gobernadora), §14 (agua de noche, defensa de la reja), §16 (Doña Refugio, túneles, plaza de la Catrina), índice, nombres y preguntas | L7 |

## Decisiones de JJ (✅)

**El mundo**
- **Santa Mugre = fortaleza de la Virgen del Tinaco**, un refugio religioso donde empieza el personaje. Dentro no hay zombis de noche (salvo que falle la reja), no entra la policía. Creen que los de fuera están poseídos por el demonio y que el agua del tinaco de la plaza los protege, y no es mentira (es agua sin Serenol).
- **El templo:** interior visitable; detrás del altar, un cuarto subterráneo con un pozo. El padre saca el agua, la filtra y dice que es bendita; por eso no pierdes la personalidad.
- **Las purificadoras son ilegales**, pero en las fortalezas no entra la policía y ahí se vende agua sin Serenol a precio justo.
- **Afuera:** casi todos los NPC están bajo Serenol ("zombi" en sentido figurado: aman a GelA, trabajan mucho), **no dan misiones**; hay policías; nada abre de noche; los zombis no atacan a quien trae Serenol. Hordas de noche numerosas (menos que la defensa del tinaco, pero hay que disparar sin parar) y drops raros escondidos.
- **Fortaleza de la mafia (La Gotera):** otra ciudad amurallada con estética de favela, donde viven los pobres. Descubrieron un yacimiento subterráneo, notaron que quien bebe de ahí no cambia de personalidad y levantaron su propia barricada. Saben que el agua de GelA tiene algo. Sistema de túneles con la Madre del Cárcamo (los túneles se trabajan después).
- **Fortaleza GelA:** albercas, mansiones, campos de golf; dos reservorios inmensos (uno para ellos, pocos; otro para el suministro general, visiblemente adulterado). Amurallada. En la fortaleza rica todos saben el secreto del Serenol. Dejan entrar a gente porque quieren protección contra los zombis, que de vez en cuando sí entran. Resistencia interna y un hijo rebelde. **Va sobre las canchas de fútbol del ITESO** (tomando casas si hace falta) con las bodegas grandes de alrededor como fábrica; alternativa: un terreno vacío grande con bodegas grandes junto.

**El ciclo de dinero (gran parte del gameplay)**
- De día las autoridades disparan a quien reparte agua; por eso se reparte **de noche**. La estrategia: **barricada con un tinaco y bocinas** para atraer zombis (los atrae el agua y el sonido) y así repartir agua sin Serenol a las casas de fuera de las fortalezas que la necesiten. La misión de reparto puede ser **defender el tinaco** o **defender la camioneta** mientras hace las entregas. Es de donde salen el dinero y las mejoras del personaje.
- Viable a pie antes del amanecer; si amanece y te ven con el tambo, disparan los policías.

**Misiones y lugares**
- La defensa del tinaco de Santa Mugre **no es voluntaria**: una noche al azar falla la reja, se meten zombis, cae la noche y te avisan "corre al tinaco". **Defender la reja** es una misión recurrente voluntaria.
- Otras: llevar a alguien al médico sin que lo alcancen (varias clínicas = casas con cruz verde), la antena de Sofía (torres de luz del OSM), Decreto 47 (documentos en una bodega de GelA), mafia: llevar cosas de **punto a punto** (hay 19 negocios "punto") que desbloquean compras ilegales, cacerías (la Mojiganga, la Madre del Cárcamo; la entrada a los jefes queda fuera de la ciudad/fortaleza), misiones con el hijo rebelde de GelA.
- El primer lote de misiones debe quedar cerca de la fortaleza. Se pueden sustituir casas por edificios de misión (hay más de mil).

**Choques de lore resueltos (votados el 2026-11-11)**

| # | Choque | Decisión |
|---|---|---|
| 1 | Chuy no sabe del Serenol (§9) vs el pozo que protege | **Chuy sospecha**: nota que quienes toman de su pozo no se "apagan" y lo calla porque el culto le conviene |
| 2 | Pozo del templo vs Doña Refugio / "El tinaco que no se vacía" | **Es el mismo pozo**: Doña Refugio es la vieja del pozo bajo el templo; el padre lo administra |
| 3 | Madre del Cárcamo (nace del lodo de GelA, §16) vs túneles de la mafia | **Los túneles son solo la entrada**: la Madre y el yacimiento quedan separados; los túneles conectan con los cárcamos de GelA. §16 intacto |
| 4 | Los Gotera "nunca venden agua", dueños de la válvula (1.1) | **Venden agua limpia a precio justo**: la mafia que protege a los pobres; la válvula sigue como su palanca contra GelA |
| 5 | Quién sabe del Serenol (3.1) | **Cuatro niveles**: GelA lo sabe todo; trabajadores de GelA casi todos bajo Serenol; la mafia sabe que "algo hay en el agua de la llave"; Santa Mugre solo la fe. **Gente de fuera sabe que el agua tiene algo y pide agua limpia: tu gremio se la lleva** |
| 6 | Zombis: "no te reconocen", te atacan por carne y agua (§8) | **Reconocen el Serenol** y no atacan a quien lo trae; los atrae el agua limpia y el sonido; la mayoría de la gente está bajo Serenol y no es zombi |
| 7 | Gobernadora y Gerardo en Haciendas de San Jodido | **Se mudan a la fortaleza GelA**; Haciendas queda como colonia común de casas chicas |
| 8 | Palacio en el centro de Santa Mugre | **El palacio está afuera**, en o cerca de la plaza de la Catrina; el edificio del palacio de Santa Mugre pasa a ser **una escuela** |
| 9 | Santa Mugre: "la mayoría de la ciudad", peso del régimen | **Refugio religioso**: fieles que salieron de Serenol, con dóciles mezclados que no saben; sin inspectores adentro |
| 10 | "La noche sin ley" vs policía afuera | **Policía solo de día**; de noche el Estado se retira |

## Propuestas por votar (💡)

- La Palmada ya no tiene el pozo de los abuelos en un patio (quedó bajo el templo de Santa Mugre): confirmar, y quién queda en La Palmada.
- La capilla de Los Garrafones se mudó a Santa Mugre tras la clausura de 2032 (el tinaco de la Virgen en la plaza): confirmar.
- Nombre del hijo rebelde de GelA, del chofer/camioneta, de la escuela de Santa Mugre y del nuevo palacio.
- Cuándo se amuralla cada fortaleza (línea de tiempo §3) y qué incidente hace fallar la reja de Santa Mugre.
- Cuánto cuesta el agua limpia en cada fortaleza (economía, ligar con `mejoras.md`).

## Sitios medidos en `map_test` (coordenadas del juego)

| Sitio | Dónde | Nota |
|---|---|---|
| Canchas del ITESO (fortaleza GelA) | fila de 5 de ~90 × 110 m en x 380 a 622, z ≈ -755; otra de 94 × 93 en (189, -760) | ninguna casa a 150 m; Biblioteca ITESO (-43, -816), Parque Tecnológico (17, -649); a ~1500 m de Santa Mugre |
| Alternativa GelA: baldío sur | (-300, 630) con las naves de La Gigantera (60 × 68 m, z ≈ 700: (6,719), (-59,714), (-125,709), (-190,704), (-256,699), (-321,695)) | más cerca de la fortaleza de la Virgen |
| Cancha grande | (-244, -721), 172 × 182 | 43 casas alrededor |
| Bodega para la oficina de GelA | (-333, 645) | a ~209 m de la reja poniente (-420, ~455) |
| Negocios "punto" | 19 en el mapa; el más cercano a la reja poniente en (-656, 609), a ~282 m | para las entregas de la mafia |
| Torres de luz | 32 (`power=tower` del OSM) | antenas |
| Rejas de Santa Mugre | poniente (-420, ~455), oriente (-185, ~473) | código de las rejas en la rama `rejas-avenida-santa-mugre` |

Viabilidad a pie: unos 10 m/s corriendo; la noche dura 480 s de reloj (`Ciclo.noche_duracion`), pero antes de la transición del amanecer quedan unos 450 s. Todo lo de la primera tanda debe quedar a ≤ ~250 m de una reja.

## Checklist

### Fase L: lore y misiones (texto)

- [x] **L0** Preparar (hecho leyendo `lore.md` directo; el grafo no se consultó, queda para L12): grafo consultado (nodos: Santa Mugre, culto, Padre Chuy, tinaco comunitario, contratos de la noche, Vela, Gotera, válvula, Madre, Haciendas, Serenol, zombis, El Nocturno), leer `revision-historia` 1.1, 1.2, 2.4, 3.1 (S)
- [x] **L1** `lore.md`: sección "Las tres fortalezas" + Santa Mugre = facción de la Virgen (los de fuera, "poseídos"; el agua protege y es verdad) (M)
- [x] **L2** `lore.md`: templo con el cuarto del pozo, Chuy que sospecha, Doña Refugio; reescribir §9 (M)
- [x] **L3** `lore.md`: el afuera (Serenol, policía de día, zombis que reconocen el Serenol, nada abre de noche, diálogos de "zombi esclavo"), purificadoras ilegales vs fortalezas; reescribir §8 (M)
- [x] **L4** `lore.md`: agua clandestina de noche (de día disparan; barricada + tinaco + bocinas; defender tinaco o camioneta; ciclo de dinero y mejoras), evento de la reja, jefes con entrada fuera (plaza de la Catrina, túneles) (M)
- [x] **L5** `lore.md`: fortaleza de la mafia (favela, yacimiento, túneles, saben del agua de GelA); reescribir §11 y §13 La Gotera (M)
- [x] **L6** `lore.md`: fortaleza GelA en las canchas del ITESO (albercas, golf, dos reservorios, todos saben, resistencia, hijo rebelde, fábrica en bodegas); mudar gobernadora y Gerardo; palacio afuera y escuela en Santa Mugre; línea de tiempo, §13, índice, §19 (L)
- [ ] **L7** `personajes.md`: padre Chuy, Doña Refugio, hijo rebelde, resistencia, jefes de la mafia ajustados, Gerardo, policías, chofer; matriz "Quién está con quién" (M)
- [ ] **L8** `misiones.md`: reescribir el piloto 0 y la Vela como familia "Defensa externa" (defender tinaco, defender camioneta), guardia de la reja (recurrente), evento de la reja (no misión) (M)
- [ ] **L9** `misiones.md`: misiones de fuera (al médico, antena de Sofía, Decreto 47, reparto) con quién da, dónde, objetivo, riesgo y paga, y pasada de coherencia (M)
- [ ] **L10** `misiones.md`: mafia punto a punto (19 puntos, desbloquea compras ilegales), cacerías (Mojiganga, Madre), GelA e hijo rebelde (M)
- [ ] **L11** `especificaciones.md` §2, §4.8 y §6, y `revision-historia.md` "Lo decidido" (S)
- [ ] **L12** Reconstruir el grafo: `/graphify docs --update` desde `docs/`, revisar aristas sueltas, commit aparte de `docs/graphify-out/` (la extracción completa costó ~750k tokens de entrada; puede posponerse) (M)
- [ ] **L12b** Revisión final de coherencia: grep de las frases viejas que contradicen los 10 choques (§8 "no te reconocen", §13 "la mayoría de la ciudad", "palacio" en Santa Mugre, "Haciendas" con gobernadora, "aquí el agua no se vende", Chuy inocente, "noche sin ley") (S)
- [ ] **L13** Pedirle a Alan el grafo del código (no está en el repo ni en ramas remotas) o generarlo con `/graphify scripts` (S)

### Fase S: sistemas (cada uno con su plan al empezar; dependen de que L esté lista en lo que toquen)

- [ ] **S1** Misión nocturna: `MisionData.noche`, dadores de tarde, la misión sobrevive al cambio de escena (hoy fallan al anochecer y los dadores desaparecen) (M)
- [ ] **S2** Pasos nuevos: DEFENDER, ESCOLTAR, LLEVAR_CARGA (amanecer = policía), CAZAR, ENTRAR_A (L)
- [ ] **S3** Policía de día que dispara a quien lleva agua (no hay código de policía hoy) (M)
- [ ] **S4** Hordas de noche de afuera, continuas pero menores que la defensa (`Hordas`, `Zombis.espontaneos`) (M)
- [ ] **S5** Drops raros escondidos (S)
- [ ] **S6** NPC de fuera bajo Serenol, sin misiones, con diálogos; los zombis los ignoran (S)
- [ ] **S7** Mercado ilegal desbloqueable por la mafia (M)
- [ ] **S8** Paso de escena a los jefes con regreso (`PasoColonia` generalizado; hoy `catrina.tscn` y `lombrices.tscn` terminan con `quit()`) (M)
- [ ] **S9** `MuroColonia` a datos, para varias fortalezas (M)
- [ ] **S10** Defensa externa: barricada + tinaco + bocinas en el mapa (reusar `Barricada`, `TinacoDefensa`, `Bocina`; `TinacoComunitario` es solo visual) (L)
- [ ] **S11** Camioneta de reparto con ruta que los zombis atacan (L)
- [ ] **S12** Medir FPS tras cada sistema (S)

### Fase P: lugares en `map_test`

- [ ] **P0** Palacio nuevo afuera de Santa Mugre, en o cerca de la plaza de la Catrina; el palacio del mapa de Blender de Santa Mugre pasa a ser una escuela (modelo y `santa_mugre.json`)
- [ ] **P1** Bodega de GelA (oficina) · **P2** torres de luz como antenas · **P3** varias clínicas (casa con cruz verde) · **P4** puntos y casas de entrega · **P5** plaza de la Catrina · **P6** entrada a los túneles · **P7** sitios de la defensa externa

### Fase F: fortalezas

- [ ] **F1** Evento de la reja + defensa del tinaco de Santa Mugre (no voluntaria) · **F2** guardia de la reja · **F3** templo interior con pozo · **F4** fortaleza de la mafia (favela, tienda ilegal; túneles después) · **F5** fortaleza GelA en las canchas del ITESO

### Fase M: misiones una por una (primero el núcleo del dinero)

Cada una: texto listo en `misiones.md` (fase L) → código → safehouse → prueba en ventana → tachar.

- [ ] **M1** Defensa externa del tinaco · **M2** Camioneta de reparto · **M3** Guardia de la reja · **M4** Radio de Sofía · **M5** Al médico · **M6** Decreto 47 · **M7** Entregas de la mafia · **M8** Cacería de la Mojiganga · **M9** Cacería de la Madre · **M10** Hijo rebelde y resistencia

### Orden y riesgos

L antes que todo → S1, S2, S8, S10 → P y F1 en paralelo → M1 y M2 (el núcleo del ciclo de dinero) → F3 y M3 a M6 → F4, F5 y M7 a M10.
Riesgos: choques de lore sin votar, costo de cuadros por tantos lugares nuevos, el grafo del código que falta.
