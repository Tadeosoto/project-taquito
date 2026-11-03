# Guadalajaja — Especificaciones del juego

> Documento vivo para ponernos de acuerdo en qué juego estamos haciendo. **Todos pueden editarlo**: abre un PR o comenta en el PR que lo cambie.
>
> Última actualización: 2026-11-02

## Cómo usar este documento

Cada sección o punto lleva una etiqueta:

| Etiqueta | Significa |
|---|---|
| ✅ **Decidido** | Ya lo acordamos; se puede programar. |
| 🗳️ **Por decidir** | Hay varias opciones; votamos en la sección [Decisiones grandes](#1-decisiones-grandes-por-votar). |
| 💡 **Propuesta** | Idea sugerida, nadie la ha aprobado. Coméntala, mejórala o tachála. |
| 🧱 **Ya existe** | Ya está en el repo (aunque sea prototipo). |

Para votar, pon tus iniciales junto a la opción, por ejemplo `Votos: JJ, TS`. Cuando una decisión se cierre, muévela al [registro de decisiones](#14-registro-de-decisiones) con la fecha.

**Regla general:** no inventar la rueda. Cada mecánica dice de qué juego la tomamos; si alguien duda cómo debe sentirse algo, que juegue/vea ese juego.

---

## 0. La idea en un párrafo

Survival-shooter en tercera persona con look de PS1, en un pedazo **real** de Zapopan. Es un **mundo normal** —la ciudad trabaja, compra, come tacos y ve la novela— con **dos cosas raras**: **de noche** salen **zombis** (caníbales, con sed de agua limpia) y **el agua limpia es cara y escasa**. Las dos las une **GelA**, el monopolio: su agua vuelve dóciles a nueve de cada diez y zombis a uno de cada diez. **De día** tomas contratos y te preparas; **de noche** sales a cumplirlos (vela, recolección, reparto, cacería) y sobrevives. Tono: humor tapatío y absurdo (botarga del Simi, Takis, palomas) sobre un problema real (el agua).

> La historia completa, la ciudad, la gente y las subhistorias están en **[`docs/lore.md`](lore.md)**. Ahí se explica por qué el agua es cara, por qué hay zombis y por qué el gobierno es de la misma familia dueña de la empresa. En el código los zombis siguen llamándose `Zombie` (`scripts/map/Zombie.gd`, `Zombis.gd`): es solo el nombre interno.

**Juegos de referencia** (de aquí copiamos sin pena):

| Juego | Qué tomamos |
|---|---|
| *Dying Light* | Día tranquilo / noche peligrosa, misiones de día, noche con mejor recompensa. |
| *7 Days to Die* | Hordas que crecen cada noche, aviso antes de que oscurezca. |
| *Left 4 Dead* | "Director" que decide cuándo y cuántos zombies mandar; zombies especiales; objetos que atraen zombies. |
| *Days Gone* / *World War Z* | Hordas grandes que se mueven como un río. |
| *Resident Evil* (1-4) | Inventario limitado, objetos que ocupan espacio, munición escasa. |
| *GTA San Andreas* | Mundo abierto, marcadores amarillos para entrar a tiendas/misiones, misiones cortas de barrio. |
| *Dead Rising* | Humor, armas improvisadas, rescatar sobrevivientes que te siguen. |
| *Unturned* / *DayZ* / juegos `.io` | Multijugador sencillo en un mapa compartido, pierdes tus cosas al morir. |

---

## 1. Decisiones grandes (por votar)

Estas cambian mucho cómo se programa todo lo demás. Conviene cerrarlas **antes** de repartir trabajo.

### 1.1 🗳️ Plataforma y multijugador

Propuesta de Juanjo: **juego de navegador multijugador**: quien entra a la página aparece en el mapa con los demás.

| Opción | Pros | Contras | Votos |
|---|---|---|---|
| **A. Navegador + multijugador** (propuesta) | Se comparte con un link; jugar con amigos es lo más divertido. | Lo más difícil (ver [sección 11](#11-multijugador-en-navegador-implicaciones-técnicas)): necesita servidor, el render cambia a *Compatibility* y hay que diseñar todo "en red" desde el inicio. | JJ |
| B. Navegador, un jugador | Se comparte con un link, sin servidor. | Solo. Igual hay que pasar a *Compatibility*. | |
| C. PC (Steam), un jugador | Lo que ya tenemos; mejor rendimiento. | Hay que descargar el juego. | |
| D. C primero, A después | Avanzamos rápido en mecánicas. | **Meter multijugador después cuesta reescribir casi todo** (quién controla a los zombis, inventario, misiones). Si vamos a A, mejor saberlo desde ahora. | AG |

### 1.2 🗳️ Estructura / meta del juego

| Opción | Referencia | Votos |
|---|---|---|
| **A. Sandbox sin fin** (propuesta): sobrevive lo más que puedas, récord de noches. Encaja con multijugador persistente. | Unturned, DayZ, Minecraft | JJ, AG |
| B. Sobrevive N noches (ej. 7), cada una más difícil, jefe al final. | 7 Days to Die, Don't Starve | |
| C. Roguelite: mueres y reinicias, pero desbloqueas cosas permanentes. | Vampire Survivors, Hades | |
| D. Campaña con historia y final (¿quién contaminó el agua?). | Dead Rising, GTA | |

> 💡 A y D se pueden mezclar: sandbox sin fin + misiones principales opcionales que cuentan la historia.
>
> 💡 **Propuesta de trabajo de AG (2026-10-31), falta que el equipo la confirme**: B, con 3 noches y un zombi jefe. Se pierde si tumban el tinaco del refugio; se gana matando al jefe. Es distinto de lo que se votó arriba.
>
> 💡 **Preferencia de JJ (2026-11-02)**: **A, sandbox**, para que el juego se pueda jugar sin depender del lore. La partida de 3 noches se queda como **modo reto**, no como la estructura. Falta que el equipo lo confirme (ver `docs/lore.md` §1).
>
> 🧪 **La partida de 3 noches y el jefe son un piloto de prueba**: no definen la mecánica final del juego.

### 1.3 🗳️ Qué pasa de noche

| Opción | Referencia | Votos |
|---|---|---|
| **A. Libre por todo el mapa** (propuesta): los zombis aparecen alrededor de cada jugador, donde esté. | Dying Light, DayZ | JJ |
| B. Refugio que se refuerza (barricadas) + salir a misiones nocturnas que pagan más. | 7 Days to Die, Dying Light | |
| C. Defender un punto fijo por oleadas. | CoD Zombies | |

> 💡 Con A, las tiendas (o la azotea de tu casa) podrían ser "zonas seguras a medias" para no tener que pelear toda la noche.
>
> 💡 **Propuesta de trabajo de AG (2026-10-31), falta que el equipo la confirme**: B. Tres refugios fijos hechos con las mismas piezas, uno activo a la vez, con una entrada por lado que se atranca con tablas y un tinaco que hay que proteger. Si te alejas, el ataque se simula: al volver encuentras el daño. Las misiones nocturnas esperan al sistema de misiones (6.3).

### 1.4 🗳️ Cómo se apunta y dispara

| Opción | Referencia | Votos |
|---|---|---|
| A. Cámara al hombro + mira, con *aim assist* suave para control. | RE4 remake, Fortnite | AG |
| **B. Lock-on automático**: se fija al enemigo más cercano y cambias de objetivo con un botón. Muy PS1 y fácil con control. | RE clásico, Syphon Filter, Zelda OoT | JJ |
| C. Disparo libre sin mira hacia donde mira el personaje. | Twin-stick, GTA 1/2 | |

> En multijugador por navegador, B es también lo más simple de sincronizar (se manda "disparé al zombi #123", no un rayo).

### 1.5 🗳️ Qué pasa al morir

| Opción | Referencia | Votos |
|---|---|---|
| A. Sueltas tu mochila donde moriste; reapareces en el último refugio y puedes ir a recuperarla. | DayZ, Rust, Minecraft |AG|
| B. Pierdes una parte del dinero/objetos y reapareces al amanecer. | GTA (hospital) | |
| C. Te vuelves zombie y otro jugador te puede "curar" con agua limpia. | Original, divertido en multijugador | |
| D. Vuelves a nacer pero ahora en el imss | | |

> ✅ **C ahora sí es canon**: el Serenol mata a uno de cada diez y lo levanta; si se te llena la sed, **te mueres y te levantas**. La "cura" del agua limpia sirve para el dócil, no para el zombi. Se puede programar como muerte especial.

> 💡 **Propuesta de trabajo de AG (2026-10-31), falta que el equipo la confirme**: A. Tus objetos se quedan en una bolsa donde caíste (si vuelves a caer antes de recogerla, la anterior se pierde); el dinero y la mochila puesta se quedan contigo. Reapareces en el refugio con 50 de vida. Morir no termina la partida.

### 1.6 🗳️ Alcance de la primera versión jugable

"Alcance" = **cuánto juego intentamos terminar para la primera versión que se pueda jugar de principio a fin**, según cuántas personas trabajan y cuánto tiempo hay. Sirve para no empezar 30 cosas y no terminar ninguna.

| Opción | Qué incluye | Votos |
|---|---|---|
| A. Mínimo (pocas semanas) | 1 ciclo día/noche, 2 misiones, 1 tipo de zombi, 3 armas. | |
| B. Demo (1-2 meses, 2-4 personas) | 1 colonia, 3 noches, 5-6 misiones, 3 zombis, inventario y tiendas. |AG|
| C. Juego corto (3-6 meses) | Todo el mapa, ~15 misiones, todos los objetos de esta lista. | |

Preguntas para fijarlo: ¿cuántos somos?, ¿cuántas horas a la semana cada quien?, ¿hay fecha límite (entrega de clase, concurso, festival)?
Somos 4, lo que se pueda cuando se pueda.
---

## 2. Historia y mundo

✅ **Premisa (revisada 2026-11-02).** La empresa **GelA**, de la familia Lazcano, se quedó con el agua de Guadalajara. El agua de la llave lleva **Serenol**: nueve de cada diez quedan **dóciles** (gente normal que quiere a la empresa y no lo sabe) y uno de cada diez se muere y se levanta como **zombi**. Los zombis son **caníbales** y tienen **sed de agua sin Serenol**. **No hay contagio por mordida.**

✅ **La historia completa está en [`docs/lore.md`](lore.md).** Este resumen es solo para no perder el hilo al leer las mecánicas.

Lo que hay que saber:

- **El agua es el centro de todo.** Es cara, es medicina (la cura de la "sed" es agua limpia) y es poder (quien la controla controla el voto).
- **La familia Lazcano tiene dos tronos**: **Germán** es dueño de GelA; su hija **Georgina "Gela"** es la gobernadora. Los dóciles votan por ella: es el **voto de la llave**.
- **El crimen organizado real no toma de la llave** (los Gotera: drogas y armas; compran agua embotellada). La ciudad le echa la culpa a "las pandillas", que es justo lo que el régimen necesita.
- **El culto de la Virgen del Tinaco**: un tinaco manchado con la Virgen; la gente cree que limpia el agua y en realidad la limpia el **padre Chuy** con un filtro robado. El milagro sí cura (es agua limpia), y por eso GelA lo quiere cerrar.
- **Subhistorias**: el **cobalto** de la varilla del 84 (las casas en obra negra y unas lámparas que bajan vida) y las **cruces de caca** de un vecino loco. Se cuentan hablando con la gente, no en cinemáticas.
- **El lore no bloquea nada**: el sandbox se juega sin saberlo (ver `docs/lore.md` §1).
- **Facciones** (para misiones): la **cuadrilla** de contratos, el culto del tinaco, los cotos de San Jodido, los Gotera, los blancos de GelA y la propia gobernadora.
- **El mapa** 🧱: ~1.7 × 1.7 km reales de Zapopan, con nueve zonas de nombre parodia (El Mante Tieso, Los Garrafones, La Florida Marchita, La Palmada, Parques de Santa Mugre, Parques del Mosco, Haciendas de San Jodido, El Último Trago y La Gotera). Ver `docs/mapa/README.md` y `docs/lore.md` §13.


## 3. Ciclo principal (core loop)

```
DÍA ──► aceptar misiones ──► juntar objetos / dinero / agua ──► comprar en tiendas
 ▲                                                                    │
 │                                                                    ▼
AMANECER ◄── sobrevivir ◄── usar armas/consumibles ◄── NOCHE: hordas de zombis
```

### 3.1 Ciclo día/noche ✅ (detalles 💡)

- Reloj del juego con luz del sol, color del cielo y niebla que cambian (la niebla del mapa ya existe 🧱).
- **Shader de día/noche** 🧱 (en `map_test.tscn`): el global shader uniform `noche` (0 = día, 1 = noche) que leen las lámparas. Se cambia con `Alumbrado.configurar_noche(valor)` (`scripts/map/Alumbrado.gd`). De noche hay luz de luna azulada que deja ver el juego sin alumbrado, y el alumbrado público se nota: las lámparas se prenden escalonadas y hay luces reales cerca del jugador (ver `docs/mapa/README.md`). Lo mueve el reloj; la tecla **N** salta al siguiente atardecer o amanecer para probar.
- 🧱 El **reloj** ya existe (`scripts/map/Ciclo.gd`): avanza la hora y mueve `noche`, el sol, el ambiente y la niebla, con día de 12 min, noche de 8 y aviso 1 min antes de oscurecer. Falta que en multijugador lo lleve el servidor.
- 💡 Duración: **día 12 min + noche 8 min** (20 min reales por día de juego). En multijugador el reloj es el mismo para todos (lo lleva el servidor).
- 💡 Atardecer con aviso (campana de iglesia, sirena, el radio) 1 min antes de que salgan los zombis, como en *7 Days to Die*.
- 💡 De día los zombis se esconden del sol en bodegas y drenajes; de noche salen a caminar.
- 💡 Cada noche es un poco más difícil (más zombis, zombis especiales), estilo *7 Days to Die*. En sandbox sin fin se puede reiniciar la dificultad cada N noches o depender de cuántos jugadores hay.

---

## 4. Mecánicas

### 4.1 Movimiento y cámara 🧱

Tercera persona, cámara relativa, correr con Shift, saltar. Ya existe en `scripts/player.gd`. Falta:

- 💡 Estamina para correr (barra que se vacía), estilo *Dying Light*.
- 💡 Esquivar / empujón (empujar a un zombi para quitártelo de encima, como *Left 4 Dead*). Muy útil y fácil: una animación + impulso.

### 4.2 Combate

- **Cuerpo a cuerpo**: machete, bate, chancla… Una animación de golpe + área de daño delante del jugador. Lo más fácil de hacer primero. 🧱 Ya se pelea con clic izquierdo o F: pega con la mejor arma que traigas (machete 12, reforzado 18) o a puño (5), sin equiparla. Por ahora solo con el machete. Daños y vida 💡 para discutir. 🧱 Cada golpe se siente: el zombi se pone blanco, suena un whack seco, salen gotas pesadas de agua sucia desde adentro del cuerpo hacia donde iba el golpe (caen con gravedad y dejan manchas en el piso que se borran a los 15 s), el zombi sale empujado y tú rebotas tantito, la cámara se sacude y el juego se congela unos cuadros; con más daño, más fuerza. Al matarlo se hincha y revienta como globo de agua sucia, y deja un charco que se seca y su pellejo mojado, que a los pocos segundos se pudre y deja el esqueleto (dura un minuto; máximo 16). Los que se caen al amanecer no revientan. Cuando te pegan a ti: el juego se congela unos cuadros, te pones blanco, se sacude la cámara, dos cuadros de la pantalla en puro blanco y negro, te empuja como 1.5 m hacia donde iba el golpe y sale sangre para allá.
- **Armas de fuego**: pistola, cuerno de chivo, ballesta. Tipo de apuntado 🗳️ (ver 1.4). Munición escasa, recarga.
- **Arrojables**: molotov (fuego en área), paloma (aturde), bocina (atrae zombis, ver objetos). Se lanzan en arco con previsualización de trayectoria (*GTA*, *Fortnite*).
- 💡 **Ruido**: disparar hace ruido y atrae zombis; machete es silencioso. Da sentido a elegir arma (*DayZ*, *The Last of Us*).

### 4.3 Salud y estados 💡

- **Vida** (se cura con comida/medicina). 🧱 Ya existe lo mínimo (`scripts/Salud.gd`, autoload `Salud`, empieza en 60 de 100 de prueba): se cura desde el inventario y ahí se ve el estado (Bien / Herido / Grave). Todavía nada hace daño.
- **Estamina** (correr, golpear).
- 💡 **La sed** (lo que antes se llamaba "infección"): se llena **tomando agua de la llave**, no por una mordida. El agua limpia la baja; la capilla del tinaco es la única que es gratis (con cupo). Si se llena, **te mueres y te levantas como zombi**: es la única muerte que no se deshace. Une la mecánica con el tema del agua. Ver `docs/lore.md` §6 y §9. (El **1 de cada 10** es la estadística de la ciudad; si tú te llenas, es seguro.)
- 💡 **La tentación**: poder tomar agua de la llave para ahorrar, a cambio de subir la sed y perder el control de noche. Es la decisión central del juego; falta balancearla (ver `docs/lore.md` §15).
- 💡 Nada de hambre/sed obligatoria al principio: complica mucho y aburre. Los consumibles dan *buffs* temporales en vez de "no morirte de hambre".

### 4.4 Inventario estilo Resident Evil 🧱 (parcial)

Ya existe un inventario circular con inspección 3D de objetos (`scripts/Inventory.gd`, `scenes/InventoryUI.tscn`), en `map_test.tscn`: Tab lo abre y pausa el juego, y tiene los comandos Examinar, Utilizar (cura) y Combinar (recetas). Los objetos del mapa se recogen con Espacio. El menú está **inspirado en Silent Hill 2**, sin copiarlo (hilera de objetos que se pierde en lo oscuro, solo los comandos que aplican, y en Estado el juego pausado para ver dónde estás y cómo andas de vida), no en Resident Evil como decía el registro de decisiones: hay que confirmarlo con el equipo.

🧱 **Mochilas**: sin mochila caben 6 objetos, cada objeto ocupa 1 lugar (o sea, la opción A de abajo sin armas de 2) y lo que no cabe se queda tirado. Recoger una mochila más grande la equipa para siempre, no ocupa lugar y se ve en Equipo; una más chica se queda tirada. Por ahora: mochila escolar (8), del Partido Verde (10) y mochilón del Nocturno (14), las tres con el mismo modelo en distinto color. Números 💡 para discutir. Falta decidir:

| Opción | Referencia | Votos |
|---|---|---|
| A. Ranuras (slots): 6 al inicio, cada objeto ocupa 1 (armas grandes 2). La mochila del Partido Verde sube a 8-10. | RE1/RE2 clásico | |
| B. Cuadrícula tipo Tetris: cada objeto tiene forma; acomodar es parte del juego. | RE4 | |

- 💡 Objetos apilables (balas, pesos, Takis) hasta un máximo por ranura.
- 💡 *Hotbar* de 4 accesos rápidos (1-4 / cruceta del control) para no abrir el inventario en plena horda.
- 💡 Baúl/caja en el refugio para guardar lo que no cabe (la "caja mágica" de RE).

### 4.5 Economía ✅

**Una moneda: pesos.** El agua limpia no es dinero: es un **recurso caro**.

| Qué | Cómo se consigue | Para qué |
|---|---|---|
| **Pesos** | Contratos nocturnos, botín de zombis, máquinas de las tiendas. | Comprar en tiendas normales, pagar el agua. |
| **Agua limpia** | La capilla (con cupo), el tinaco comunitario, las purificadoras (caras). | Beber, curar la sed, truequear con 2-3 NPCs. |

- 🧱 La cartera ya existe (`scripts/Cartera.gd`, autoload `Cartera`: pesos y agua, empieza con 120 y 3 de prueba). **Pendiente de código: quitar `agua` de la cartera y de los productos** (`moneda` en `resources/productos/*.tres`); todo se paga en pesos.
- 🧱 **Por qué el agua es cara** (`docs/lore.md` §10): el monopolio prohíbe filtrar (Decreto 47), las purificadoras son franquicias y los zombis atacan el agua clandestina. La escasez es contable: hay agua, falta el permiso y el precio.
- 💡 **Purificar agua** (agua sucia + Cloralex = agua limpia): una receta de *crafteo* sencilla que conecta con el tema (y es delito).
- 💡 Crafteo mínimo (como *Dead Rising* / *The Last of Us*): molotov = botella + trapo + **gasolina** (de la gasolinera) o **alcohol** (tequila/caguama vacía, más flojo); machete mejorado = machete + cinta. 🧱 El sistema ya existe (`scripts/RecetaData.gd`, `resources/recetas/`, comando Combinar del inventario) con la receta del machete.


### 4.6 Tiendas e interiores 💡

- Las tiendas tienen un **marcador amarillo** en la puerta (flecha/cilindro como *GTA San Andreas*). Al pararte en él: pantalla negra → apareces en el interior → otra flecha para salir. 🧱 Ya funciona: la flecha (`scripts/map/MapPuntos.gd`, señal `entrar_negocio`) te lleva con pantalla negra a la escena del interior de su giro (`scripts/interiores/Interiores.gd`); con S o Esc vuelves a la calle. En los puestos al aire libre (puesto de tacos, tejuino) no hay pantalla negra: la cámara se acerca al que te atiende ahí en el puesto (parado detrás del carrito o dentro del puesto de tacos) y con S o Esc se aleja. El punto sí te mete a un cuarto: obra negra con hollín y grafitis negros, un colchón en el piso con alguien tirado y el que te atiende a un lado (`scenes/interiores/punto.tscn`).
- Los interiores son **escenas aparte** (no están dentro del mapa), así no se modela cada tienda por dentro. Un interior por giro, reutilizado.
- **Giros** (los negocios salen del DENUE; ver `docs/mapa/README.md`). De cada giro solo lleva marcador y cuadro en el minimapa **uno cada 80 m** (abarrotes uno cada 150 m); los demás se ven igual pero son decorado. Lo que vende cada uno es una propuesta 💡:

| Giro | En el mapa | Cómo se compra | Vende 💡 |
|---|---|---|---|
| OXO | modelo de OXXO | interior | gansito, refresco, cigarros, mazapán |
| Abarrotes | Tienda 3B o local de colonia | interior | lo mismo que el OXO pero más barato, cloralex, galón de agua |
| Farmacia | Guadalaraja, Dr Simio (kiosco con el Simi bailando) o local verde | interior | cosas curativas: vaporub, botiquín, pastillas |
| Taquería | local de colonia con lona | interior | tacos |
| Puesto de tacos | puesto en la banqueta | **al aire libre**: menú con el taquero, sin pantalla negra | tacos; ahí van las misiones *Cocinar tacos* y *Defender el puesto* |
| Gasolinera | modelo de Pemex (nombre Perez) | interior | gasolina (para molotov) |
| Ferretería | local de colonia | interior | tablas, cinta, llave, armas cuerpo a cuerpo |
| Purificadora | local azul con gota | interior | garrafón, agua limpia |
| Tejuino | carrito en la banqueta | al aire libre | tejuino |
| **El punto** | una casa al azar por colonia, en obra negra y con el deterioro al máximo | interior: un cuarto en obra negra con un colchón y alguien tirado | cosas ilegales (tachas…). No sale en el minimapa. |
| Tortillería | local de colonia | decorado (sin marcador) | — |

- 🧱 **El agua legal y la ilegal** (`docs/lore.md` §9 y §10): las **purificadoras** del mapa son franquicias **Puri-GelA** y son la única agua legal; cobran **caro en pesos**. Purificar por tu cuenta (cloralex, pozo, filtro) es **delito** (Decreto 47); el agua clandestina se consigue en **misiones** y es más barata. La **capilla del Tinaco**, en Los Garrafones, es el único lugar donde el agua buena es gratis: dejas agua sucia de noche y recoges limpia al amanecer, con cupo. 💡 Por implementar: la capilla, el cupo y su misión.

- **Marcas**: los nombres ya son parodia (OXO, Dr Simio, Guadalaraja, Perez); los modelos todavía traen la marca real pintada.
- Dentro: mostrador con NPC que vende (menú de compra), y las **máquinas** (de dinero/premios) para la misión de sacar dinero.
- 🧱 **Interiores armados** (`scenes/interiores/`): no son cuartos que se caminan sino una **escena fija en primera persona**: ves al que te atiende detrás del mostrador y atrás los estantes o refrigeradores con lo que se vende. Estás **adentro** del local en los abarrotes, la farmacia, la ferretería y la tiendita (OXO y gasolinera, con letrero rojo y anaqueles); solo la **purificadora** te atiende desde la banqueta por su ventana, con el nombre pintado arriba. En la **taquería** es al revés: estás sentado en una mesa roja de fierro (marca de refresco inventada, servilletero, salero y salsas roja y verde; sillas plegables rojas) en un local blanco y rojo con refrigeradores rojos, y ves por la cortina abierta el puesto de tacos en la banqueta con su trompo, al taquero de espaldas, la calle y las casas de enfrente. Atrás del vendedor, copiando fotos de referencia (`scripts/interiores/Estante.gd`): en los abarrotes repisas de abarrotes y botanas, un anaquel rojo de papitas de lado y tiras de papitas colgando; en la farmacia anaqueles azules con filo amarillo llenos de cajitas y letreros "NUEVOS PRODUCTOS" / "¡CUÍDATE!"; en la ferretería panel ranurado con herramientas y blisters colgados y un anaquel metálico. La mercancía lleva etiquetas dibujadas (marcas inventadas: papitas, frijoles, paracetamol, pinzas…; `tools/make_empaques.py` → `textures/interiores/empaques.png`). Los mostradores copian fotos de referencia (`scripts/interiores/Mostrador.gd`): vitrina refrigerada blanca con filos azules en los abarrotes, mostrador blanco sobre anaqueles negros con filo rojo llenos de dulces en el OXO, frente azul con calcomanías de oferta en la farmacia, vitrina con cajitas de tornillos en la ferretería y, en la purificadora, la misma fachada que en el mapa (muro blanco con franjas azules, puerta de barrotes, despachador automático, ventanal de aluminio abierto y el anuncio sobre postes) con una repisa blanca en la ventanilla. Adentro la cámara está cerrada sobre el mostrador para que los estantes llenen la pantalla (no se ven muros vacíos), con el vendedor un poco a la derecha. Con el mouse volteas un poco. **Todos llevan mostrador y vendedor**; el vendedor por ahora es el NPC ninja con un diálogo corto, falta su personaje (encargada, taquero, velador…). Se ven solos con `godot --path . scenes/interiores/<giro>.tscn`. En el editor se acomodan moviendo los nodos `Mueble` (dices cuánto mide y el modelo se escala solo) y `Refrigerador` (refrigeradores de puerta de vidrio armados con cajas, `scripts/interiores/Refrigerador.gd`).
- 🧱 **Lo que venden**: al entrar, lo que vende ese giro flota dando vueltas frente al mostrador, solo el que estás viendo (al cambiar se va de lado y entra el siguiente); abajo una franja con su **nombre, efecto, descripción y precio** (en pesos, o en AGUA en azul) y arriba a la derecha tu dinero. Q/E (o A/D) cambia de producto; Espacio compra: cobra y lo agrega al inventario (si no te alcanza o no te cabe, te lo dice). Cada producto es un `.tres` en `resources/productos/` (nombre, descripción, efecto, precio, moneda y su modelo) y cada interior dice cuáles vende (`productos`) y si es más caro (`precio_factor`: la tiendita del OXO y la gasolinera ×1.15). Por ahora: tiendita = gansito, takis, jarritos, cigarros, mazapán, caguama; abarrotes = lo mismo sin cigarros + cloralex y galón; farmacia = botiquín, vaporub (2 de agua), galón; taquería = tacos, jarritos, caguama; ferretería = tablas, cinta, bate, machete (2 de agua); purificadora = galón, cloralex; el punto = tachas, cigarros, caguama. Precios y efectos 💡 para discutir.
- 🧱 **Maquinitas de frutas** ("Cóctel de Frutas", como las de afuera de las tienditas): salen junto a la puerta de cerca de la mitad de los abarrotes y licorerías. Te acercas, Espacio, y le apuestas pesos de tu cartera a 8 frutas ($1 por moneda, hasta 9 por fruta); el foco da vueltas por los 24 cuadros y paga según la fruta (manzana x3 ... BAR x35). Cada máquina tiene su caja de monedas y su dificultad (la placa con DIP switches, `scripts/tragamonedas.gd`), así que unas pagan mejor que otras y ninguna paga más de lo que trae. Si ganas dinero salen cohetes en el cielo. Se juega en la máquina misma: los botones se prenden y se hunden, y los contadores de PREMIOS, CRÉDITOS y de cada fruta se prenden. **Se le nota cómo anda sin que nadie te lo diga**: con monedas en la charola está normal; charola vacía, luces tenues y panel apagado = casi no tiene caja y no te va a pagar (lo que le apuestes la va llenando); una veladora prendida con su estampita encima = rara (5 %), el siguiente tiro gana seguro. Números 💡 para discutir. **En coop** 💡: todavía no hay red, pero los focos se ven en el mueble y los cohetes en el cielo, y están separados de la lógica para que el servidor decida y los demás jugadores lo vean. Falta: NPCs que juegan y que el tendero cambie la dificultad por día (`docs/tragamonedas_notas.md`), y la misión de sacar dinero (6.1).
- 🗳️ ¿Las tiendas cierran de noche? ¿Son refugio seguro? ¿Los zombis pueden entrar? 💡 Propuesta de trabajo de AG (2026-10-31), falta que el equipo la confirme: de noche todo cierra (tiendas, puestos y maquinitas) y si estás adentro al anochecer te sacan a la calle, para que no sirvan de escondite.

### 4.7 NPCs 🧱 (parcial)

Ya hay NPCs con diálogo en burbuja y aviso de "Espacio/X" (`scripts/npc.gd`). Falta:

- 💡 NPCs que **dan misiones** (marcador encima, como el "!" de *WoW* o la letra de *GTA*).
- 🧱 De día hay gente (`scripts/map/Gente.gd`): caminan por las banquetas (por ahora con el modelo ninja pintado, el único con ciclo de caminar), un garrafonero con su galón, gente afuera de las tiendas con la que puedes platicar y perros echados. Al avisar que va a oscurecer se apuran y de noche no hay nadie, así que la calle vacía también avisa.
- 💡 Comportamiento "seguir al jugador" (se usa en Simi, rescates, escoltas: programarlo una vez y reutilizarlo).

> ✅ El **reparto** (30 voces, 10 vendedores, habitantes sin diálogo, y la regla de las tres preguntas para decidir quién habla) está en **[`docs/personajes.md`](personajes.md)**.

### 4.8 Los zombis y las hordas 💡

✅ **Nombre.** En el mundo se les dice **zombis**; en el código siguen llamándose `Zombie` / `Zombis` (`scripts/map/Zombie.gd`, `Zombis.gd`). **Son caníbales y tienen sed de agua sin Serenol**: comen a quien se mueve y atacan tinacos, purificadoras y cisternas (`docs/lore.md` §8).

✅ **El índice de deterioro ES el índice de infección.** `Deterioro.zona(x, z)` decide dónde hay más zombis (umbral 0.45 = zona tomada) y coincide con lo que se ve destruido porque las dos cosas son la misma: pobreza (`docs/lore.md` §7). No hace falta código nuevo: `Zombis.maximo()` ya lo usa.

Referencia del grupo: [reel de Instagram](https://www.instagram.com/reel/DehepkqD5PW/). (No se pudo ver sin cuenta; **que alguien describa qué tiene que tomarse de ahí**.) Asumimos hordas que se mueven en masa tipo *Days Gone* / *World War Z*.

🧱 **Prototipo actual** (`scripts/map/Zombis.gd`, `Zombie.gd`): de noche un Director como el de *Left 4 Dead* (`scripts/map/Director.gd`) mide qué tan apretado andas y da vueltas entre armar, sostener, bajar y dar un respiro. Salen sueltos alrededor del jugador, fuera de la cámara, más donde está más destruido y uno más cada noche (hasta 12), y cada 90-180 s una turba que corre hacia ti, hasta 30 en total. Llegan por las calles (`CampoFlujo.gd`), no se pueden encimar (te rodean y hacen fila en las entradas, así que los pasos angostos sirven para defenderse) y pegan; dan unos pesos al morir y se caen al amanecer. De día no hay. Si llegas a 0 de vida tus objetos se quedan en una bolsa y despiertas en el refugio (propuesta de 1.5). De noche todo cierra (propuesta de 4.6). Si no hay jugador cerca del mismo lado de la barda, van por la entrada más cercana del refugio y luego por el tinaco; si andas a más de 70 m, el ataque se simula. **Ojo: esto es solo un prototipo; no define la mecánica final.**

✅ **La mecánica definida** (`docs/lore.md` §8):

- **Son caníbales.** Comen a quien se mueve. Por eso atacan al jugador y a cualquier NPC en la calle.
- **Tienen sed de agua sin Serenol.** Atacan el tinaco comunitario, las purificadoras y la capilla. **La vela** es el contrato de defender el tinaco hasta el amanecer.
- **De día se esconden del sol** en bodegas abandonadas, drenajes y túneles. Ahí están las **camadas**: la mazmorra del juego.
- **La puerta cerrada los detiene**: empujan, no abren. La barricada es del refugio, no de la casa.
- **Uno de cada diez** infectados se muere y se levanta; los otros nueve son dóciles y viven normal.
- **Al morir sueltan lo que traían.** Cada zombi tiene un **oficio** (obrero, taquero, repartidor, tiendero, albañil, chavo, botarga) y de ahí sale el botín: pesos (5-60), objetos útiles y, muy de vez en cuando, un **papel raro** con algo del lore. El cuerpo se desvanece; el botín se queda.
- **El tinaco y las entradas no son objetivos** de los zombis normales: van por la gente y por el agua. El tinaco es objetivo de **la vela** (defensa) y del jefe de la partida de prueba.

Cómo se hace normalmente (y cómo lo haríamos):

1. **Director** (como *Left 4 Dead*): un script central que mide la tensión (vida del jugador, zombis cerca, hora) y decide cuándo mandar una horda, cuándo dar un respiro y dónde aparecen (siempre fuera de cámara, en calles cercanas).
2. **Movimiento en grupo**: en vez de que cada zombi calcule su ruta (caro), se calcula **un campo de flujo** (flow field) hacia el jugador/ruido por zona y todos lo siguen, con separación entre ellos (*boids*). Así cientos de zombis se ven como un río por las calles.
3. **Niveles de detalle**: zombis lejos = dibujados con `MultiMesh` y animación en el shader, sin física; cerca = zombi completo con colisión y animaciones. Igual que ya hacemos con las casas y árboles del mapa.
4. **Ruido**: disparos, molotov, bocina y paloma crean "puntos de ruido" que redirigen la horda.
5. 💡 **Más zombis donde está más destruido** (JJ): el mapa ya tiene un nivel de deterioro por zona (cuadras casi intactas y otras destruidas, ver `docs/mapa/README.md`). El Director multiplica cuántos zombis salen en una zona por ese nivel: `Deterioro.zona(x, z)` en `scripts/map/Deterioro.gd`, la misma fórmula que pinta las casas y calles en el shader. Así lo que se ve avisa del peligro.

Presupuesto 💡: ~30 zombis completos cerca + ~200 "baratos" lejos (hay que medir, sobre todo en navegador).

**Tipos de zombi** 💡 (copiados de *Left 4 Dead* y adaptados):

| Zombi | Basado en | Qué hace |
|---|---|---|
| **Flaco** (normal) | Común de L4D | Lento, en grupos. |
| **Corredor** | Runner de *Dying Light* / *28 días* | Rápido, frágil. Aparece de noche. |
| **Hinchado** | Boomer | Gordo; al caer empuja y hace ruido, que atrae a otros. |
| **Escupidor** | Spitter | Escupe sangre; si te mancha, te hace daño despacio. |
| **Cargador** | Tank | Grande, trae garrafones como armadura. Mini-jefe de noches avanzadas. |
| **Botarga** | Original | La botarga de la Gota o del Simi, de noche, sola en una esquina. Jefe o easter egg. |


### 4.9 Casas en obra negra y otras rarezas 💡

✅ **Las casas en obra negra son las contaminadas.** El juego ya las pinta así (5 % de las casas en deterioro medio, 15 % en el máximo; `MapCasas._obra_negra` + `shaders/ps1_casa.gdshader`): paredes sin aplanar, block a la vista, hollín, un colchón en el piso. En el lore son las que se construyeron con la **varilla del 84** —el cobalto del "Chernobyl mexicano" de Ciudad Juárez, que también llegó a una fundidora de Guadalajara—: ahí murió la gente y el régimen enterró el expediente (`docs/lore.md` §16). 💡 Por hacer: que entrar baje vida despacio y que se pueda encontrar un medidor (geiger).

💡 **Las lámparas del 84.** Algunos postes del alumbrado salieron del mismo lote: zumban, dan una luz verdosa y **bajan vida** si te quedas debajo (la probabilidad es baja). `scripts/map/Alumbrado.gd` ya decide el estado de cada lámpara por semilla; sería un estado raro más. La gente les dice "la luz que te chupa".

💡 **Las cruces de caca.** En una colonia al azar aparecen cruces hechas con popó; las hace un vecino **no infectado** que está loco, de noche. Se puede poner como calcomanía (`scripts/map/Calcomanias.gd`) y como un NPC con el que se platica de noche. Es el recordatorio de que no todo lo que anda de noche es un zombi.

### 4.10 El celular 💡

✅ **Qué es.** Un teléfono de prepago con la pantalla estrellada. Es la UI de los mensajes: misiones, avisos, amenazas, publicidad de la Gota y el **grupo del barrio**. Reemplaza la libreta de misiones y es el canal de "conversación" del lore (`docs/lore.md` §12).

**La pantalla** (640×480, fuente del juego):

- Lista de chats con puntito de "no leído".
- Burbujas: tú escribes con el teclado; el otro contesta.
- "Escribiendo..." mientras llega la respuesta.
- **Aviso**: un sonido y un badge cuando llega un mensaje, aunque no tengas el celular abierto.
- **No hay batería, ni señal, ni rastreo, ni estafas, ni cámara.** Se descartaron: no se programan.

**Los contactos** (`docs/personajes.md`):

| Contacto | Tipo | Para qué |
|---|---|---|
| **Sofía** | **IA** | La única a la que le preguntas lo que sea del mundo. Contesta con el canon y no spoilea el final |
| **Padre Chuy** | IA (opcional) o escrita | Agua, capilla, consejo |
| **Gabriel** | Escrita | Contratos, pagos, encargos |
| **Beto** | Escrita | El hilo personal: se mete en broncas |
| **La Gota** | Escrita | Publicidad, avisos de corte, promociones |
| **Número desconocido** | Escrita | Don Nemesio, la gobernadora, amenazas |
| **Grupo del barrio** | Escrita | Varios NPCs: rumores, avisos, cadenas |

**Misiones por mensaje.** El NPC te manda el objetivo y el marcador aparece solo: no hay que volver a hablarle.

**La IA.** Solo Sofía (y, si se quiere, el cura) usa modelo; el resto son mensajes escritos y respuestas rápidas de botón. La respuesta es **asíncrona**: mandas, sigues jugando, llega en 10-30 s.

- **Prompt**: su ficha de `personajes.md` + un trozo de `lore.md` (RAG).
- **Guardarraíles**: no inventa lore, no spoilea, no sale del personaje, no habla de política real.
- **Límite por jugador y caché** de preguntas repetidas.
- **La llave del modelo va en un servidor**, nunca en el cliente.

**Implementación.** `Contacto` (Resource): nombre, número, avatar, `tipo` (IA/escrito), `persona`; `MensajeData` para los hilos escritos. UI: `CanvasLayer` con una lista y un `LineEdit`. IA: `HTTPRequest` + `JSON` al proxy. Aviso: `Sonidos.gd`.

**Lo que no se hace** (por alcance): batería, señal, rastreo, estafas, cámara, y que la IA conteste a los 30 personajes.

---

### 4.11 Mapa de papel 🧱

Con el inventario abierto, **M** (Select en el control) muestra el mapa, en 9 pedazos con nombre: El Mante Tieso, Los Garrafones, La Florida Marchita, La Palmada, Parques de Santa Mugre, Parques del Mosco, Haciendas de San Jodido, El Último Trago y La Gotera. Empiezas con el de donde apareces y los demás se encuentran tirados frente a una tienda de cada zona; los que faltan salen en negro con un signo. No ocupan lugar, no se pierden al desmayarte y se acaban con la partida. Al cruzar a otra zona sale su nombre. 💡 Después podrían venderse o darse en misiones.

---

## 5. Objetos

✅ El catálogo completo —items, efectos, precios, modelos y lo que falta— está en **[`docs/items.md`](items.md)**.

Resumen:

- **Inventario:** 6 lugares base; mochilas de 8, 10 y 14.
- **Dinero:** pesos. El agua es un recurso caro, no una moneda.
- **Tipos:** consumibles, armas, munición, arrojables, materiales, equipo, documentos y llaves.
- **Pendiente de código:** pasar `machete` y `vaporub` a pesos; renombrar el mochilón; corregir "infección" → "sed" y "zombies" → "zombis".

---

## 6. Misiones

✅ La lista completa —el piloto, los contratos de la noche, las de día y las de historia— está en **[`docs/misiones.md`](misiones.md)**.

Resumen:

- **El piloto:** defender el **tinaco comunitario** hasta el amanecer (8 minutos, tres oleadas).
- **Contratos de la noche:** vela, reparto clandestino, recolección, encargo y cacería.
- **Misiones de día:** transportar, encontrar, corretear, tiro al blanco, manifestación, acompañar, defender el puesto, limpiar una camada, etc.
- **Historia:** las cinco pistas de `docs/lore.md` §17.

### 6.0 Lo que ya hay 🧱

Tres misiones de día, con vecinos que traen un **!** amarillo cerca de donde empiezas: **Encargo de compras** (2 galones de la farmacia; paga $100 y 2 tablas), **Repartir garrafones** (4 casas en 100 s; paga $90) y **Buscar al perro** (se oye ladrar en una zona marcada, y lo cargas de regreso; paga $60 y un pedazo de mapa). Una a la vez y cada una una vez al día. Si anochece o se acaba el tiempo, falla y se puede intentar mañana. Se siguen con la línea de abajo a la izquierda, la flecha, el minimapa y el mapa de papel. Precios y tiempos 💡 para balancear jugando. Para agregar una sin programar: copiar un `.tres` de `resources/misiones/` (ver `CLAUDE.md`).

### 6.3 Sistema de misiones 🧱 (cómo programarlo)

Para que cualquiera pueda agregar misiones sin tocar código:

- `MisionData` (Resource `.tres`, igual que `InventoryItemData`): nombre, NPC que la da, descripción, recompensa, si es de día/noche, y una **lista de pasos**.
- Tipos de paso reutilizables: `ir_a(punto)`, `recoger(objeto, n)`, `entregar(objeto, npc)`, `derrotar(tipo, n)`, `seguirme(npc, n)`, `sobrevivir(segundos)`, `alcanzar(npc)`.
- Un gestor de misiones (autoload, como `Inventory`) lleva la misión activa, el marcador en el minimapa 🧱 y la flecha en pantalla.

Con eso, casi todas las misiones de arriba son S.

---

## 7. Enemigos 💡

| Enemigo | Comportamiento | Referencia |
|---|---|---|
| Zombis | **Los muertos que se levantan** (`docs/lore.md` §8): caníbales, atacan a quien se mueve y huelen el agua limpia. Huyen si pierden a la mitad. **No son una pandilla.** | Hordas de L4D (la pelea) |
| Policías | Aparecen **solo de día** si haces desmadre (manifestación, robo). De noche no hay ley. ¿Nivel de búsqueda tipo GTA? | Estrellas de GTA |
| ¿Otros jugadores? | 🗳️ ¿Se puede dañar a otros jugadores (PvP)? | DayZ (sí) / Unturned (opcional) |

> ✅ Los zombis de esta tabla y los de 4.8 son **los mismos**. El crimen organizado de verdad (**los Gotera**, `docs/lore.md` §11) es otra cosa: no toma de la llave y no se parece a ellos. No mezclar las dos cosas al programar IA.
>
> ✅ **Son caníbales** (`docs/lore.md` §8): comen a quien se mueve y buscan agua sin Serenol. De los infectados, solo **uno de cada diez** se levanta.

---

## 8. Interfaz (HUD) 💡

- 🧱 **Pantalla de inicio** (`scenes/inicio.tscn`): GUADALAJAJA, "No te tomes el agua." y el menú Jugar, Controles, Créditos y Salir, sobre una escenita de noche. Falta poder volver a ella desde el juego.
- Vida, estamina, la sed (esquina inferior).
- **Celular**: avisos de mensaje (badge + sonido); se abre desde el inventario.
- Minimapa redondo estilo GTA 🧱 (ya existe en `map_test.tscn`) con marcadores de misión y tiendas.
- Reloj/sol-luna para la hora del día.
- Munición del arma actual + hotbar.
- Todo en español informal, fuente pixelada.

---

## 9. Arte y sonido

- Look PS1 🧱: resolución 640×480, *dither*, vértices que tiemblan (shaders en `shaders/`).
- 💡 Música: de día cumbia/banda de radio vieja; de noche, tensión. ¿Alguien del equipo hace música?
- 💡 Sonidos clave: gemido de zombi, campana del atardecer, el grito del agua ("¡el agua!") como aviso, palomas tronando.

---

## 10. Modelos 3D: qué hay y qué falta

### 10.1 Ya en el repo 🧱

| Modelo | Dónde | Notas |
|---|---|---|
| Jugador / NPC (ninja) | `models/ninja_male.fbx` | Provisional; compartido por jugador y NPCs. |
| Caguama Agua Mala | `models/aguamala.glb` | Objeto de inventario. |
| Taco al pastor | `models/taco_pastor.glb` | Objeto de inventario. |
| Takis, Jarritos, moneda de 1 peso | `models/objetos/` | Descargados, aún sin usar. |
| Mapa de Zapopan | `resources/map/cuadros/` | Calles, casas, árboles. |
| Casas modelo | `models/casas/` | Urbi, Semi Residencial, Mexican House 3, multifamiliar (sin usar). |
| Tiendas | `models/tiendas/` | OXXO, Farmacia Guadalajara, Pemex, carrito de comida, puesto de tacos… |
| Señal de alto | `models/props/alto/` | |
| Bodegas | `models/bodegas/` | bodega_industrial (Industrial Warehouse: de su frente salen los vanos con portón de `MapBodegas.gd`), rack, estante_oxidado, cajas. Ya colocadas en el mapa. |
| Personajes | `models/personajes/` | **Sin colocar.** Gente: cholo (animado, civil), gang_member, gangster_dealer, indian_gangster, policia (3 policías, sin rig), soldado, mujer_psx, chava_psx, hombre_psx (base sin textura), psx_man, amerindios ⚠️ (malla estirada al importar). NPCs de misiones: **repartidor** (trabajador de chamarra azul; pesado, 24 mil triángulos), **taquero** (animado), **encargada** de tienda, **cientifico**, **perro** (animado). Modelos de zombi (los archivos se llaman `zombie_*`): zombie_ripper (idle/caminar/atacar/correr), zombie_psx, zombie_gordo (idle, correr, golpe, morir, 2 ataques: sirve de zombi base y de hinchado). Simi: **`dr_simi/simi_botarga.scn`** = botarga con esqueleto de Mixamo y el baile (15 s, `bailar` en loop), sacada del kiosco por `tools/map_import/separar_simi.gd`; el kiosco completo es `dr_simi/scene.gltf`. simi_muneco (sin rig, de repuesto). |
| Armas | `models/armas/` | machete, melee_psx (pack cuerpo a cuerpo), pistola_mk23, pistola_colt ⚠️ (sale en piezas), cuerno_de_chivo, ballesta, bate, resortera, balas. |
| Objetos | `models/objetos/` | Del Mexican Starter Pack solo se usan `mochila` y `mazapan` (`.scn`, `tools/map_import/separar_pack.gd`). Inventario: botella + trapo (molotov), tachas (pastillas), tejuino, gansito, chancla, cigarro, vaporub, cloralex, botiquin, cinta, tablas, bocina, llave, galon_agua. Misiones: paquete (pila de cajas), patito (tiro al blanco), carrito_super (carrera), refrescos. |
| Props de calle | `models/props/` | alto, coladera (nido), despachador_agua (garrafón en su base). |
| Interiores | `models/interiores/` | mostrador, estante_fruta, maquina_refrescos, m3_mart (tiendita completa, 5.5 mil triángulos). |
| Animaciones | `models/animaciones/` | Quaternius Universal Animation Library 1 y 2 (CC0, `tools/fetch_cc0.py`), esqueleto humanoide propio (no Mixamo): se pasan a otros personajes con el retarget de Godot (`BoneMap` + `SkeletonProfileHumanoid`). Incluyen: machetazo (`Sword_Attack`, `Sword_Regular_A/B/C`), pistola (`Pistol_Aim_*`, `Pistol_Shoot`, `Pistol_Reload`), lanzar (`OverhandThrow`), esquivar (`Roll`), empujón (`Push_Loop`, `Hit_Knockback`), golpes (`Punch_Jab/Cross`, `Melee_Hook`), recibir golpe y morir (`Hit_Chest`, `Hit_Head`, `Death01`), **zombie** (`Zombie_Walk_Fwd_Loop`, `Zombie_Idle_Loop`, `Zombie_Scratch`), cargar garrafón (`Walk_Carry_Loop`), comer/beber (`Consume`), bailar (`Dance_Loop`), correr, agacharse, caminar, hablar por teléfono. |

Cada modelo trae una captura **`preview.png`** en su carpeta (y `<nombre>_preview.png` junto a cada `.scn` suelta), generada por `tools/map_import/capturas.gd`; sirve de vistazo y de ícono provisional del inventario. Los modelos pesados se reducen al importar (`TiendaPostImport.MAX_TRIANGULOS`) y todos usan el shader PS1; `TiendaPostImport.TINTES` repinta materiales (tejuino, trapo). Créditos en `CREDITS.md`.

### 10.2 Faltan ❌

| Prioridad | Modelo | Notas |
|---|---|---|
| Alta | **Personaje jugable** definitivo | ¿Quién es? ¿se puede personalizar (en multijugador ayuda distinguirse)? Candidatos: hombre_psx, mujer_psx, chava_psx + animaciones de Quaternius. ✅ Avatar silencioso, "el Nocturno" (`docs/lore.md` §15): cada jugador hace el suyo (propuesta de AG, 2026-10-31) con el ninja recoloreado (`scripts/CreadorPersonaje.gd`): nombre, complexión y talla con pros y contras, cabeza y ropa. El tono de piel es una sátira del colorismo, como en *South Park*: cambia precios, paga y lo que te dice la gente, y no toca el combate. Por decidir antes de publicar: si se queda este chiste y cómo se escriben esas líneas. |
| Alta | Juntar animaciones con personajes | Retarget de las de Quaternius al jugador, zombis y NPCs (hoy cada modelo trae solo las suyas). |
| Media | Interiores: más muebles propios | Las escenas ya están armadas (`scenes/interiores/`) con mostrador, estantes oxidados, máquina, la tiendita m3_mart y objetos; faltan muebles de farmacia y anaqueles de ferretería. |
| Media | Objetos que se quitaron porque salían mal: garrafón (para repartir garrafones; el del despachador `props/despachador_agua` sí sirve de referencia), botella de agua, agua sucia, lámpara, celular, máquina de tienda, tequila, paloma, veladora | Buscar otros en Sketchfab o modelar low-poly. |
| Media | Arreglar: pistola_colt, amerindios | Salen en piezas / malla estirada; buscar reemplazo o arreglar en Blender. |
| Baja | Repartidor más ligero | El modelo elegido queda en 24 mil triángulos (meshoptimizer no baja más). |
| Baja | Escupidor, cargador, botarga | Variantes del zombi base (textura/color). |
| Baja | Torta ahogada, grafitis | Nada usable en Sketchfab: modelar low-poly / calcomanías. |
| Baja | Marcador amarillo de misión | |
| — | **Sonidos y música** | Pendientes. |

Fuentes: Sketchfab con licencia CC (hay script: `tools/map_import/fetch_sketchfab.py`, agrega créditos a `CREDITS.md` solo; en git solo va la versión horneada `<modelo>.scn` que usa Godot, ver `tools/map_import/hornear_modelos.gd`), Mixamo para animaciones, o modelar en Blender en low-poly (lo más PS1).

---

## 11. Multijugador en navegador: implicaciones técnicas

Si se vota 1.1 A, esto es lo que implica (para que se decida sabiendo):

1. **Render**: Godot en navegador **no soporta Forward+** (el render actual). Hay que pasar el proyecto a **Compatibility** (WebGL 2). Los shaders PS1 deberían funcionar, pero hay que probar todos (`ps1_combined`, fachadas, suelo, casas, minimapa) y la niebla/iluminación se verán distintas.
2. **Rendimiento**: hoy el mapa va a ~150-190 FPS en la laptop de Juanjo con Forward+. En navegador esperar bastante menos; puede que haya que bajar distancia de dibujo y número de zombis.
3. **Descarga**: el mapa (~11 MB) + modelos (~30 MB) se bajan al abrir la página. Aceptable, pero hay que cuidarlo.
4. **Hilos**: la carga del mapa en segundo plano usa hilos; en web eso necesita cabeceras especiales del servidor (COOP/COEP) o exportar sin hilos (más tirones al cargar). Probar.
5. **Servidor**: hace falta un **servidor dedicado** (Godot sin pantalla, `--headless`) corriendo en algún lado (VPS, Fly.io, Railway…). Los navegadores se conectan por **WebSocket** (`WebSocketMultiplayerPeer`). Tiene costo mensual (bajo).
6. **Autoridad**: el servidor decide dónde están los zombis, quién le pegó a quién, el reloj día/noche y el inventario (si no, es facilísimo hacer trampa). Esto significa que **cada mecánica se programa pensando en red** desde el inicio.
7. **¿Un mundo para todos o salas?** 🗳️ Un solo mundo con todos los que entren (como un `.io`) es lo más bonito, pero cientos de zombis × muchos jugadores pesa. Lo normal es **salas de hasta 8-16 jugadores**; si una se llena se abre otra.
8. **Persistencia**: si el sandbox es sin fin, ¿se guarda tu inventario al cerrar la página? Necesitaría cuentas/guardado en el servidor. 💡 Para empezar: no se guarda nada, cada sesión empieza de cero (como los `.io`).

💡 **Recomendación técnica**: primero una prueba chica de 1-2 semanas: exportar `map_test.tscn` a web en Compatibility, medir FPS, y conectar 2 jugadores por WebSocket que se vean moverse. Si eso jala, seguimos con multijugador; si no, se decide con datos.

---

## 12. Plan de trabajo 💡

Borrador; se ajusta cuando se cierren las decisiones de la sección 1.

| Hito | Qué | Depende de |
|---|---|---|
| **0. Decisiones** | Votar sección 1. Repartir áreas. | — |
| **1. Prueba web/red** | Lo de la recomendación de la sección 11. | 1.1 |
| **2. Loop mínimo** | Pasar jugador/NPC/inventario al mapa real; ciclo día/noche; machete; 1 zombi que persigue y pega; morir/reaparecer. | 1.3, 1.5 |
| **3. Misiones** | Sistema de misiones (6.3) + 3 misiones S (encargo OXXO, repartir garrafones, encontrar cosas). | Hito 2 |
| **4. Hordas** | Director + flow field + LOD de zombis; ruido. | Hito 2 |
| **5. Economía y tiendas** | Pesos/agua, interior genérico, comprar/vender, marcador amarillo. | Hito 3 |
| **6. Contenido** | Más armas, objetos, misiones (Simi, cacerías, tiro al blanco), zombis especiales. | Hitos 3-5 |
| **7. Pulido** | HUD, sonido, música, balance. | Todo |

### Áreas (pon tu nombre)

| Área | Responsable |
|---|---|
| Jugador, cámara y combate | |
| Zombis, IA y hordas | |
| Misiones y NPCs | |
| Inventario, objetos y economía | |
| Tiendas e interiores | |
| Mapa (ya existe: Juanjo) | Juanjo |
| Multijugador / web | |
| Modelos 3D y animación | |
| Sonido y música | |
| UI / HUD | |

---

## 13. Preguntas abiertas

- [ ] ¿Cuántos somos y cuántas horas a la semana? ¿Hay fecha de entrega? (define 1.6)
- [ ] ¿Qué hay que tomar del reel de Instagram de las hordas? ¿Cantidad, cómo se mueven, cómo se ven?
- [ ] ¿Dónde está el baile del Simi? ¿Es una animación de Mixamo, una escena aparte, otra rama?
- [x] **Personaje jugable**: avatar silencioso; cada jugador hace el suyo con el creador (`scripts/CreadorPersonaje.gd`) y el mundo le dice "el Nocturno" (`docs/lore.md` §15). Confirmar antes de publicar el tema del tono de piel.
- [ ] ¿Se puede pegar a otros jugadores (PvP)?
- [x] **¿Las tiendas son zona segura de noche?** No: de noche cierran y te sacan (`docs/lore.md` §20).
- [ ] **Antes de publicar**: una opción para apagar los destellos de pantalla completa (el cuadro de impacto) y la sacudida. A la gente con epilepsia fotosensible le puede hacer daño. Por ahora solo se apaga en código (`Supervivencia.IMPACTO_ACTIVO`).
- [ ] ¿Hay vehículos? (bici, carrito de súper, camión) — dan mucho juego en el mapa real pero son trabajo L.
- [x] **Marcas reales**: se decidió parodia. Los nombres ya cambiaron (OXO, Dr Simio, Guadalaraja, Perez); falta repintar los modelos.
- [ ] Tachas, droga y cuerno de chivo: ¿el tono es parodia? Afecta la clasificación si se publica en alguna tienda (itch.io no tiene problema).
- [ ] ¿Se confirma el sandbox (1.2 A) y la partida de 3 noches como modo reto?
- [ ] ¿El jugador puede tomar agua de la llave a propósito (la tentación) sin romper el balance? (`docs/lore.md` §15)
- [x] ~~¿Qué final hay: sacar la verdad, abrir la válvula, curar a la ciudad, o los tres?~~ No hay final: sandbox; la ciudad cambia por zona en el orden agua → enojo → verdad (lore §17, 2026-11-02).
- [ ] ¿La capilla del tinaco se puede perder para siempre si fallas una misión? (`docs/lore.md` §9)
- [ ] ¿Los modelos `zombie_*` se quedan o se rehacen? (`docs/lore.md` §22)
- [ ] 💡 ¿La quietud te hace invisible del todo o solo reduce el rango? (propuesta: invisible a más de ~5 m; más cerca, te detectan)
- [ ] 💡 ¿Ofrecer agua a un dócil se implementa como acción (soltar garrafón o vaso)? ¿Qué tan probable es que se la tome?

---

## 14. Registro de decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-27 | Premisa: agua sucia de Guadalajara → zombies (superada el 2026-11-02). Día = misiones, noche = sobrevivir. Monedas: pesos y agua limpia. Inventario estilo RE. Look PS1 en el mapa real de Zapopan. | Equipo (lo que ya se había platicado) |
| 2026-10-28 | Shader de día/noche y alumbrado público en el mapa: noche con luz de luna (se ve el juego sin lámparas), postes con lámparas apagadas o parpadeantes según el deterioro. Falta el reloj del ciclo. | JJ |
| 2026-10-28 | Giros de negocios (4.6) y qué vende cada uno; un interactivo por giro cada 80 m (abarrotes 150 m) con flecha amarilla; puestos de tacos y tejuino se compran al aire libre; nuevos ferretería, purificadora y "el punto" (venta ilegal, una casa en obra negra por colonia). Marcas parodia en los nombres. Casas en obra negra: 5 % en deterioro medio, 15 % en el máximo. Los locales de colonia van dentro de la hilera de casas. | JJ |
| 2026-10-31 | **Propuesta de trabajo, no cierra los votos de 1.2, 1.3 y 1.5**: partida de 3 noches con jefe, refugios con barricadas y tinaco, bolsa recuperable al morir, todo cerrado de noche. Se programa para probarla; el equipo decide después de jugarla. | AG |
| 2026-10-31 | Pantalla de inicio: el juego ya abre en ella y Jugar lleva al mapa real (`map_test.tscn`), no al prototipo `world.tscn`. | AG |
| 2026-10-31 | Mapa de papel en el inventario, por pedazos que se encuentran en el mundo, con zonas de nombres parodia y sobre el agua (4.11). | AG |
| 2026-11-02 | **Se escribe `docs/lore.md`** (la biblia de historia). Premisa revisada: GelA (la familia Lazcano) se queda con el agua; el **Serenol** vuelve dóciles a los que no pagan; los violentos son los vecinos infectados (**"cholos"**, después **zombis**); **Georgina Lazcano** es la gobernadora y los dóciles votan por ella. | JJ |
| 2026-11-02 | **Economía del agua**: las purificadoras son franquicias **Puri-GelA** y el agua limpia es cara en pesos; purificar por tu cuenta es delito (**Decreto 47**); la clandestina sale de **misiones**. El **índice de deterioro ES el índice de infección** (umbral 0.45). | JJ |
| 2026-11-02 | **Culto y subhistorias**: la **Virgen del Tinaco** (el padre Chuy filtra el agua y el milagro cura), el **cobalto de la varilla del 84** (las casas en obra negra y unas lámparas que bajan vida) y las **cruces de caca**. Se cuentan hablando con NPCs; el lore no bloquea nada. | JJ |
| 2026-11-02 | **Sandbox**: preferencia de JJ por el sandbox (1.2 A), con la partida de 3 noches como modo reto. No cierra el voto del equipo. | JJ |
| 2026-11-02 | **La noche sin ley**: Ley de Convivencia Nocturna (2032), el Estado se retira y matar de noche no se investiga; la única consecuencia es la memoria del barrio. Los zombis **son caníbales** y buscan agua sin Serenol; de día se esconden en bodegas. **La puerta cerrada los detiene.** **1 de cada 10** infectados se levanta. **Al morir sueltan lo que traían.** La partida de 3 noches y el jefe son un **piloto**, no canon. | JJ |
| 2026-11-02 | **Cambio de canon: zombis, dóciles y Nocturno.** Los enemigos son **zombis** (caníbales, sedientos de agua limpia); nueve de cada diez son **dóciles normales** que quieren a la empresa y no lo saben; el Serenol es secreto y teoría conspirativa; el jugador es **el Nocturno** (cazarecompensas de contratos nocturnos); **los pesos son la moneda** y el agua es un recurso caro; el **tinaco es comunitario**. | JJ |
| 2026-11-02 | **El mundo en dos capas**: la ciudad es **normal**; lo raro son (1) los **zombis** nocturnos (el shooter) y (2) la **escasez y el precio del agua limpia** (la economía). **GelA**, el monopolio del agua y de sus productos, **une las dos cosas**: su agua es la que mata a uno de cada diez y lo levanta. La política es la capa opcional. | JJ |
| 2026-11-02 | **El celular**: chat de mensajes con contactos (**Sofía** y, opcional, el cura con IA; el resto escrito) + **grupo del barrio**. Reemplaza la libreta de misiones y es el canal de conversación. **Sin batería, señal, rastreo, estafas ni cámara.** La llave de la IA va en el servidor y las respuestas son asíncronas. | JJ |
