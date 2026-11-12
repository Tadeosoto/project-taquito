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
| 2026-11-12 | L7 | `personajes.md`: Gerardo (rebelde, medio hermano, ya sabe), Germán ciego, Chuy que calla, sin Doña Refugio ni la leyenda (tinaco manchado), Chava con pozo propio y Nacho Garrafón, Nemesio protector, Arturo y la resistencia, policías sin cara, matriz de fortalezas. `lore.md` ajustado (§9, §13, §14, §16, glosario). **Pendiente para L8 a L10:** `misiones.md` A4 (Gerardo ya no es "falsa esperanza ingenua": sabe) y A6 (pozo: Chava contra GelA y Gotera, sin Refugio) | L8 |
| 2026-11-12 | L8 | `misiones.md`: la Vela pasa a "Defensa externa" (defender el tinaco fuera de las fortalezas, dado por Chava/Gabriel; defender la camioneta con Nacho), guardia de la reja (recurrente, la da la parroquia) y evento de la reja (no misión; la reja falla por desgaste que baja con cada guardia). El piloto de prueba no cambia. **Pendiente:** `misiones.md` A4 y A6 siguen nombrando a Doña Refugio y a Gerardo ingenuo; se arreglan en L10 | L9 |
| 2026-11-12 | L9 | `misiones.md`, sección "Las misiones de fuera": al médico (Karla, fiel mordido, casa con cruz verde), cadena de la antena (piezas y luego defender el pie de la torre mientras alguien sube), Decreto 47 en la bodega de GelA cerca de la reja poniente (H4 actualizada), reparto (Chava desde su casa, Gabriel en Santa Mugre, gremio en La Gotera, también desde la fortaleza hacia afuera) y la hija de Nava; pasada de coherencia. `personajes.md`: Gabriel pasa a Santa Mugre. **Decidido después:** Nava paga antes de salir; Sofía sube la torre; el médico es anónimo (solo dejas al enfermo en su enfermería); si no hay torre a ≤250 m de una reja, se coloca una. **Pendiente:** medir las clínicas a ≤250 m; A4 y A6 (L10) | L10 |
| 2026-11-12 | L10 | `misiones.md`, sección "Las misiones de la mafia, las cacerías y GelA": **✅ JJ: las misiones de la mafia desbloquean la entrada a La Gotera** (💡 cuatro escalones: afuera, mandadero, de confianza, de la casa; túneles y Madre en el 3), entregas punto a punto con el Primo y Nemesio, Las cuentas claras, cacerías de la Mojiganga y la Madre pedidas desde La Gotera, y GelA (guardia, Arturo, Gerardo, zombi del coto). A4 y A6 reescritas sin Doña Refugio. **Pendiente:** medir los 19 puntos en tres grupos y las clínicas; actualizar `lore.md` (Gotera: permiso) en L11/L12b | L11 |
| 2026-11-12 | L11 | `especificaciones.md` §2 (fortalezas, culto sin Refugio, facciones), §4.8 (zombis reconocen Serenol, defensa externa) y §6 (contratos y misiones de fuera, mafia, GelA); `revision-historia.md`: tabla "Cambios posteriores". **Pendiente:** el §14 y las preguntas abiertas de la spec, y el ajuste de `lore.md` sobre el permiso de La Gotera (L12b) | L12b |
| 2026-11-12 | L12b | Grep de frases viejas en los docs narrativos: arreglados `lore.md` (barrio sabe que se vende adentro, permiso de La Gotera por escalones, regla 17), `personajes.md` (Villalobos sin golf, en Haciendas, Arturo ex jardinero) y `misiones.md` (sótano en Haciendas). Sin problema: "noche sin ley" (el Estado se retira, coherente), "la mayoría de la ciudad" (solo en el glosario, "los de la llave"), "palacio" de Santa Mugre (ya es escuela). **Pendiente:** §14 y preguntas abiertas de la spec | L13 o fase S |
| 2026-11-12 | S1a | Plan de S1 con JJ: la gente da las misiones de día; diario con varias aceptadas y **una activa**; hora por paso (`PasoMision.cuando`); misiones de lugar (`MisionData.inicio`) sin diario; volver con el dador si lo pide; iniciales de los dadores en el mapa. Hecho S1a: `Misiones` con `aceptadas`/`elegir`/`empezar_en_lugar`, fuera de hora espera (sin falla ni tiempo), sobrevive al cambio de escena (`reiniciar` solo en `Inicio` y la safehouse), puntos de visita que esperan su hora y no se repiten al volver, misión de prueba `medicina_noche` (de noche + avisar de día), dador en la safehouse. Prueba headless de la lógica: 22/22 | S1b (diario y línea del Noc), S1c (iniciales en el mapa) |
| 2026-11-12 | S1b | Diario (`MisionesUI.gd`, pestaña "Diario" del inventario, J / botón 15 del control): misiones aceptadas, la activa con ▶, lo que falta, "Esto es de noche/día"; Enter la vuelve activa y abre el mapa con su puntero. El dador avisa "(Eso es de noche.)" al aceptar (leí "el noc" como el NPC). La carga del paso solo se lleva a su hora; la cosa en el suelo y los puntos de visita son de su misión y se quitan al cambiar; con el perro en brazos no se cambia de misión (`Misiones.manos_ocupadas`). Pruebas headless OK | S1c (iniciales en el mapa) |
| 2026-11-12 | S1c | Iniciales de los dadores importantes (`MisionData.inicial`) en el mapa de papel y el minimapa, círculo blanco con la letra, solo mientras ofrecen trabajo (de noche no). De prueba, "M" en Medicina de noche. Además, con JJ: **el aviso de "es de noche" lo piensa el protagonista** (sale en pantalla "<nombre>: Esto me toca de noche."), ya no lo dice el dador; **el diario no tiene límite** (la lista se recorre de 10 en 10). Prueba headless en la safehouse: 6/6 | S2 |
| 2026-11-12 | S2a | Plan con JJ: S2 se parte en S2a (ESCOLTAR + LLEVAR_CARGA), S2b (DEFENDER) y S2c (CAZAR, ENTRAR_A). `Acompanante.gd` (te sigue a 3.6 m/s, 60 de vida, los zombis lo atacan si lo tienen más cerca que a ti: `Zombie._destino`). ESCOLTAR: sale con quien dio la misión, destino `casas`/`giro:`/`marca:`, llegan los dos y termina; si cae falla. LLEVAR_CARGA: como VISITAR con la carga en brazos, `pesos_por_entrega` por entrega. Las dos son de una hora: si se acaba con la ruta en camino (amanecer = policía) o te desmayas (`Misiones.desmayo`), falla; en ruta no se cambia de misión. Te sigue por el campo de flujo de los zombis (`Zombis.campo_jugador`, que ahora también corre de día mientras haya un acompañante) y va derecho cuando está a menos de 3.5 m; atorado reaparece junto a ti. Misiones de prueba `escolta_noche` y `reparto_noche` (safehouse, fila de z = 10). JJ: a la policía le dicen cuicos, cerdos, marranos (quienes no tienen Serenol los odian, menos los de GelA); ya en los textos nuevos y en `medicina_noche` | S2b |
| 2026-11-12 | S2b | DEFENDER sin tocar `Hordas`: las turbas ya existentes (`Zombis.aparecer_turba`, salen alrededor del jugador) cada `ola_cada` s mientras estés a ≤20 m del lugar (`MisionesMundo._revisar_defensa`); el tiempo (`segundos`) solo corre ahí (`Misiones.defendiendo`) y al acabar ganas. Con `acompanante` queda un protegido quieto (`Acompanante.quieto`, atrae a los zombis desde 22 m aunque estés más cerca; si cae, falla). Falla también si se acaba la hora o te desmayas. Misión de prueba `antena_noche` (Sofía, 20 s, 2 zombis cada 8 s). **Sin balance** (S4 y S10 harán la defensa externa de verdad con barricada y tinaco) | S2c |
| 2026-11-12 | S2c | CAZAR: un zombi marcado con "!" rojo sale al acercarte a 70 m del lugar (`Zombis.sacar`, sin alerta), los mapas marcan un área de 25 m; al morir a golpes cumple el paso (`Zombie.cayo_al_amanecer` distingue la caída del amanecer, que no cuenta); si se aleja o se acaba la hora, vuelve a salir. ENTRAR_A: una flecha en `lugar` (como VISITAR con un punto); `PasoMision.escena` queda reservada para S8. Misiones de prueba `caceria_noche` y `entrada_dia`. **S2 completo** | S8 (paso de escena a los jefes) o S3/S4 |

## Para la siguiente sesión (dejado el 2026-11-12, cambio de PC)

**Hecho en la sesión del 2026-11-12:** L10, L11 y L12b (texto: mafia y puerta de La Gotera por escalones, cacerías, GelA; spec y revisión al día; grep de coherencia), S1a y S1b (código: misiones de día o de noche, diario). Ver las filas del registro de arriba.

**Hoy toca: S8** (M): paso de escena a los jefes con regreso (`catrina.tscn` y `lombrices.tscn` hoy terminan con `quit()`); desbloquea ENTRAR_A de verdad y las cacerías. S2 completo el 2026-11-12.

**Por probar en ventana** (no se ha jugado, solo pruebas headless):
- Safehouse (`godot --path . scenes/safehouse.tscn`): aceptar "Medicina de noche" (dador nuevo, el último de la fila, en x = 34) y otra; Tab y J abren el diario; Enter cambia la activa y abre el mapa con el puntero; de noche llevar la medicina (la carga solo aparece de noche) y de día volver a cobrar.
- Las 8 misiones de día de antes siguen igual (ya no fallan al anochecer: esperan al día siguiente).
- Las pestañas de abajo del inventario ahora son 7: revisar que "Habilidades ¡N!" no se encime.
- S1c: la "M" de Medicina de noche en el mapa de papel (M) y en el minimapa, que se quita al aceptarla y de noche; el pensamiento del Machetes al aceptarla; el diario con más de 10 misiones (▲▼).
- Cruzar la reja de Santa Mugre (PasoColonia) con una misión a medias: debe seguir y recolocar su puntero.

**Detalles conocidos sin arreglar:**
- Si estás parado dentro de un punto de visita cuando cambia la hora, no cuenta hasta salir y volver a entrar (`body_entered`).
- Si cambias de escena con el perro en brazos, el perro se queda en la otra escena (el paso ya cuenta como recogido; `manos_ocupadas` se limpia).
- Botón del control para el diario: el 15 (Share/Capture), el único libre; quizá no exista en todos los controles.
- `Misiones.empezar_en_lugar` existe pero nada lo usa todavía (lo usarán F1, F2 y M1 a M3).

**Dudas para JJ:**
- ✅ Resuelto el 2026-11-12: "el noc" era **el protagonista** (ya lo piensa él) y el diario va **sin límite**.
- ¿Qué dadores llevan inicial? Ninguno de los vecinos de ahora es personaje importante; la "M" de Medicina de noche es de prueba y se quita cuando haya dadores reales (Chava, Gabriel, el padre Chuy, Arturo...).
- Pagas de "Medicina de noche" (80) y de todas las de L10: 💡, se fijan con el balance.
- Los escalones de La Gotera (3/6/7 entregas) y "Las cuentas claras": 💡.
- S7 (mercado ilegal) necesita guardar el escalón de La Gotera en la partida: no tiene bloque propio.
- L12 (reconstruir el grafo, ~750k tokens) y L13 (grafo del código con Alan) siguen pendientes; el grafo narrativo está viejo respecto a L7 a L12b.
- §14 y las preguntas abiertas de `especificaciones.md` no se revisaron.

## Decisiones de JJ (✅)

**Personajes (L7, 2026-11-12)**
- **Gerardo = el hijo rebelde de GelA**: medio hermano de Georgina (hijo menor de Germán), siempre vivió en la fortaleza, **supo del Serenol hace poco**. Doble cara: heredero modelo de cara a todos, infiltrado que filtra a la resistencia. Germán se hace el ciego.
- **Resistencia GelA** = gente de servicio + familias ricas con un hijo arrepentido; no se fían entre sí. Contacto del jugador: **Arturo**. Entras a la fortaleza **contratado de guardia** porque se les metieron zombis.
- **Chuy nunca habla**: su silencio es su pecado; el jugador decide si lo delata o lo deja.
- **Doña Refugio y la leyenda del tinaco que no se vacía se eliminan.** El culto venera un **tinaco manchado** en la plaza de Santa Mugre. Pozo del templo: solo de Chuy.
- **Chava** tiene un **pozo propio en La Palmada, fuera de las fortalezas**: de ahí sale el agua del reparto; es parte del gremio y quiere proteger a los de afuera. **Nacho Garrafón** (💡 nombre de Claude) es el chofer fijo de la camioneta.
- **La reja de Santa Mugre falla por descuido**: desgaste que sube cada noche y baja con cada guardia de la reja, probabilidad de evento según el desgaste (L8). **Solo falla si estás dentro de Santa Mugre; es muy esporádico; si pierdes el tinaco hay **tres reintentos**, la dificultad sigue el progreso del juego (siempre defendible) **y cada reintento la baja un poco**; **si pierden el tinaco, los fieles se ponen tristes**; **paga el padre y el monto se decide con el balance económico**; si dejas que se pierda, lo sustituyen por uno nuevo y ya no hay **ofrenda y velas bajo la silueta de la Virgen** (el altar del templo no se toca); si ganas, te pagan en dinero. El tinaco se llena de **agua bendita del templo** y la Virgen era una manifestación de esa agua.** **Nemesio** = protector de los pobres con las manos sucias; teme que GelA descubra el yacimiento. **Policías** = anónimos y sin cara, y **son los blancos**: el brazo armado de Gela. **Buenrostro es su jefe y vive en la fortaleza GelA.** **El Inspector Nava** (el único blanco con nombre) tiene a su hija convertida en zombi y perdida entre los de la noche: "que sufra el policía". **Su misión:** te manda a buscarla con su vestimenta y descripción, la reconoces por la ropa, **no la matas (si la matas, fallas)**, y **llevas a Nava hasta ella**: él te lo dice, quiere terminar con su sufrimiento y **se deja matar por su hija en lugar de que tú la mates**. **Te paga igual.** Es un policía normal: no pasa nada con su puesto. Se diseña en L9.

**El mundo**
- **La Gotera se abre con las misiones de la mafia (2026-11-12):** sin permiso no se entra; las entregas de punto a punto suben de escalón (L10).
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
| 2 | Pozo del templo vs Doña Refugio / "El tinaco que no se vacía" | **Es el mismo pozo**: Doña Refugio es la vieja del pozo bajo el templo; el padre lo administra. ⚠️ **Reemplazado el 2026-11-12:** Doña Refugio y la leyenda se eliminan; el pozo del templo es solo de Chuy y el de La Palmada es otro, de Chava |
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
- Cuándo se amuralla cada fortaleza (línea de tiempo §3). (✅ Resuelto el 2026-11-12: la reja falla por **desgaste**, que sube cada noche y baja con cada guardia de la reja; ver `misiones.md` "El evento de la reja".)
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
- [x] **L7** `personajes.md`: padre Chuy, ~~Doña Refugio~~ (eliminada), hijo rebelde (= Gerardo), resistencia, jefes de la mafia ajustados, Gerardo, policías, chofer; matriz "Quién está con quién" (M)
- [x] **L8** `misiones.md`: reescribir el piloto 0 y la Vela como familia "Defensa externa" (defender tinaco, defender camioneta), guardia de la reja (recurrente), evento de la reja (no misión) (M)
- [x] **L9** `misiones.md`: misiones de fuera (al médico, antena de Sofía, Decreto 47, reparto) con quién da, dónde, objetivo, riesgo y paga, y pasada de coherencia (M)
- [x] **L10** `misiones.md`: mafia punto a punto (19 puntos, desbloquea compras ilegales), cacerías (Mojiganga, Madre), GelA e hijo rebelde (M)
- [x] **L11** `especificaciones.md` §2, §4.8 y §6, y `revision-historia.md` "Lo decidido" (S)
- [ ] **L12** Reconstruir el grafo: `/graphify docs --update` desde `docs/`, revisar aristas sueltas, commit aparte de `docs/graphify-out/` (la extracción completa costó ~750k tokens de entrada; puede posponerse) (M)
- [x] **L12b** Revisión final de coherencia: grep de las frases viejas que contradicen los 10 choques (§8 "no te reconocen", §13 "la mayoría de la ciudad", "palacio" en Santa Mugre, "Haciendas" con gobernadora, "aquí el agua no se vende", Chuy inocente, "noche sin ley") (S)
- [ ] **L13** Pedirle a Alan el grafo del código (no está en el repo ni en ramas remotas) o generarlo con `/graphify scripts` (S)

### Fase S: sistemas (cada uno con su plan al empezar; dependen de que L esté lista en lo que toquen)

- [x] **S1** (S1a, S1b y S1c ✅) Misión nocturna: `MisionData.noche`, dadores de tarde, la misión sobrevive al cambio de escena (hoy fallan al anochecer y los dadores desaparecen) (M)
- [x] **S2** Pasos nuevos (L), en tres sesiones: **S2a** ESCOLTAR + LLEVAR_CARGA (amanecer = policía) ✅ · **S2b** DEFENDER ✅ · **S2c** CAZAR y ENTRAR_A ✅ (ENTRAR_A solo llega a la entrada; el cambio de escena es de S8)
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
