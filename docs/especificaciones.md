# Guadalajaja — Especificaciones del juego

> Documento vivo para ponernos de acuerdo en qué juego estamos haciendo. **Todos pueden editarlo**: abre un PR o comenta en el PR que lo cambie.
>
> Última actualización: 2026-10-27

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

Survival de zombies en tercera persona con look de PS1, en un pedazo **real** de Zapopan. El agua sucia de Guadalajara convirtió a parte de la gente en zombies. **De día** haces misiones/encargos para la gente del barrio y te pagan con objetos, pesos o agua limpia. **De noche** salen los zombies y usas lo que juntaste para sobrevivir. Tono: humor tapatío y absurdo (botarga del Simi, Takis, palomas) sobre un problema real (el agua).

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
| C. PC (Linux/Windows), un jugador | Lo que ya tenemos; mejor rendimiento. | Hay que descargar el juego. | |
| D. C primero, A después | Avanzamos rápido en mecánicas. | **Meter multijugador después cuesta reescribir casi todo** (quién controla a los zombies, inventario, misiones). Si vamos a A, mejor saberlo desde ahora. | |

### 1.2 🗳️ Estructura / meta del juego

| Opción | Referencia | Votos |
|---|---|---|
| **A. Sandbox sin fin** (propuesta): sobrevive lo más que puedas, récord de noches. Encaja con multijugador persistente. | Unturned, DayZ, Minecraft | JJ |
| B. Sobrevive N noches (ej. 7), cada una más difícil, jefe al final. | 7 Days to Die, Don't Starve | |
| C. Roguelite: mueres y reinicias, pero desbloqueas cosas permanentes. | Vampire Survivors, Hades | |
| D. Campaña con historia y final (¿quién contaminó el agua?). | Dead Rising, GTA | |

> 💡 A y D se pueden mezclar: sandbox sin fin + misiones principales opcionales que cuentan la historia.

### 1.3 🗳️ Qué pasa de noche

| Opción | Referencia | Votos |
|---|---|---|
| **A. Libre por todo el mapa** (propuesta): los zombies aparecen alrededor de cada jugador, donde esté. | Dying Light, DayZ | JJ |
| B. Refugio que se refuerza (barricadas) + salir a misiones nocturnas que pagan más. | 7 Days to Die, Dying Light | |
| C. Defender un punto fijo por oleadas. | CoD Zombies | |

> 💡 Con A, las tiendas (o la azotea de tu casa) podrían ser "zonas seguras a medias" para no tener que pelear toda la noche.

### 1.4 🗳️ Cómo se apunta y dispara

| Opción | Referencia | Votos |
|---|---|---|
| A. Cámara al hombro + mira, con *aim assist* suave para control. | RE4 remake, Fortnite | |
| **B. Lock-on automático**: se fija al enemigo más cercano y cambias de objetivo con un botón. Muy PS1 y fácil con control. | RE clásico, Syphon Filter, Zelda OoT | JJ |
| C. Disparo libre sin mira hacia donde mira el personaje. | Twin-stick, GTA 1/2 | |

> En multijugador por navegador, B es también lo más simple de sincronizar (se manda "disparé al zombie #123", no un rayo).

### 1.5 🗳️ Qué pasa al morir

| Opción | Referencia | Votos |
|---|---|---|
| A. Sueltas tu mochila donde moriste; reapareces en el último refugio y puedes ir a recuperarla. | DayZ, Rust, Minecraft | |
| B. Pierdes una parte del dinero/objetos y reapareces al amanecer. | GTA (hospital) | |
| C. Te vuelves zombie y otro jugador te puede "curar" con agua limpia. | Original, divertido en multijugador | |

### 1.6 🗳️ Alcance de la primera versión jugable

"Alcance" = **cuánto juego intentamos terminar para la primera versión que se pueda jugar de principio a fin**, según cuántas personas trabajan y cuánto tiempo hay. Sirve para no empezar 30 cosas y no terminar ninguna.

| Opción | Qué incluye | Votos |
|---|---|---|
| A. Mínimo (pocas semanas) | 1 ciclo día/noche, 2 misiones, 1 tipo de zombie, 3 armas. | |
| B. Demo (1-2 meses, 2-4 personas) | 1 colonia, 3 noches, 5-6 misiones, 3 zombies, inventario y tiendas. | |
| C. Juego corto (3-6 meses) | Todo el mapa, ~15 misiones, todos los objetos de esta lista. | |

Preguntas para fijarlo: ¿cuántos somos?, ¿cuántas horas a la semana cada quien?, ¿hay fecha límite (entrega de clase, concurso, festival)?

---

## 2. Historia y mundo

💡 **Premisa** (✅ base acordada): el agua sucia de Guadalajara convirtió a algunos de sus habitantes en zombies.

Ideas para desarrollarla (todas 💡):

- **El agua es el centro de todo.** El agua limpia es dinero, medicina y cura. Los zombies vienen del agua; se ven "aguados", hinchados, escurren.
- **Origen del brote**: una planta tratadora, la presa, un pozo, una refresquera… se puede ir descubriendo con misiones (estilo *Dead Rising*: notas, radio, testigos).
- **Garrafoneros**: el repartidor de agua es la persona más importante del barrio. Un NPC repartidor puede ser el "vendedor de armas" (como Ammu-Nation en GTA).
- **Facciones** (para misiones): cholos del barrio, policías, vecinos del coto, la gente del Simi, el que vende agua "limpia" (¿de verdad lo es?).
- **El mapa** 🧱: ~1.7 × 1.7 km reales de Zapopan (colonias Agua Blanca, Haciendas de San José, Parques del Bosque…) con OXXOs, farmacias, puestos, gasolinera y altos. Ver `docs/mapa/README.md`.

---

## 3. Ciclo principal (core loop)

```
DÍA ──► aceptar misiones ──► juntar objetos / dinero / agua ──► comprar en tiendas
 ▲                                                                    │
 │                                                                    ▼
AMANECER ◄── sobrevivir ◄── usar armas/consumibles ◄── NOCHE: hordas de zombies
```

### 3.1 Ciclo día/noche ✅ (detalles 💡)

- Reloj del juego con luz del sol, color del cielo y niebla que cambian (la niebla del mapa ya existe 🧱).
- 💡 Duración: **día 12 min + noche 8 min** (20 min reales por día de juego). En multijugador el reloj es el mismo para todos (lo lleva el servidor).
- 💡 Atardecer con aviso (campana de iglesia, sirena, el radio) 1 min antes de que salgan los zombies, como en *7 Days to Die*.
- 💡 De día también hay pocos zombies sueltos (peligro bajo), de noche muchos.
- 💡 Cada noche es un poco más difícil (más zombies, zombies especiales), estilo *7 Days to Die*. En sandbox sin fin se puede reiniciar la dificultad cada N noches o depender de cuántos jugadores hay.

---

## 4. Mecánicas

### 4.1 Movimiento y cámara 🧱

Tercera persona, cámara relativa, correr con Shift, saltar. Ya existe en `scripts/player.gd`. Falta:

- 💡 Estamina para correr (barra que se vacía), estilo *Dying Light*.
- 💡 Esquivar / empujón (empujar a un zombie para quitártelo de encima, como *Left 4 Dead*). Muy útil y fácil: una animación + impulso.

### 4.2 Combate

- **Cuerpo a cuerpo**: machete, bate, chancla… Una animación de golpe + área de daño delante del jugador. Lo más fácil de hacer primero.
- **Armas de fuego**: pistola, cuerno de chivo, ballesta. Tipo de apuntado 🗳️ (ver 1.4). Munición escasa, recarga.
- **Arrojables**: molotov (fuego en área), paloma (aturde), bocina (atrae zombies, ver objetos). Se lanzan en arco con previsualización de trayectoria (*GTA*, *Fortnite*).
- 💡 **Ruido**: disparar hace ruido y atrae zombies; machete es silencioso. Da sentido a elegir arma (*DayZ*, *The Last of Us*).

### 4.3 Salud y estados 💡

- **Vida** (se cura con comida/medicina).
- **Estamina** (correr, golpear).
- 💡 **Infección**: si un zombie te muerde se llena una barra; el agua limpia la baja. Si se llena, te vuelves zombie (ver 1.5 C). Une la mecánica con el tema del agua.
- 💡 Nada de hambre/sed obligatoria al principio: complica mucho y aburre. Los consumibles dan *buffs* temporales en vez de "no morirte de hambre".

### 4.4 Inventario estilo Resident Evil 🧱 (parcial)

Ya existe un inventario circular con inspección 3D de objetos (`scripts/Inventory.gd`, `scenes/InventoryUI.tscn`). Falta decidir:

| Opción | Referencia | Votos |
|---|---|---|
| A. Ranuras (slots): 6 al inicio, cada objeto ocupa 1 (armas grandes 2). La mochila del Partido Verde sube a 8-10. | RE1/RE2 clásico | |
| B. Cuadrícula tipo Tetris: cada objeto tiene forma; acomodar es parte del juego. | RE4 | |

- 💡 Objetos apilables (balas, pesos, Takis) hasta un máximo por ranura.
- 💡 *Hotbar* de 4 accesos rápidos (1-4 / cruceta del control) para no abrir el inventario en plena horda.
- 💡 Baúl/caja en el refugio para guardar lo que no cabe (la "caja mágica" de RE).

### 4.5 Economía ✅

Dos monedas:

| Moneda | Cómo se consigue | Para qué |
|---|---|---|
| **Pesos** (moneda de peso) | Misiones, máquinas de las tiendas, zombies. | Comprar en tiendas normales. |
| **Agua limpia** | Misiones difíciles, nocturnas, purificando agua. | Moneda "fuerte": armas buenas, curar infección, trueque con NPCs. |

- 💡 **Purificar agua** (agua sucia + Cloralex = agua limpia): una receta de *crafteo* sencilla que conecta con el tema.
- 💡 Crafteo mínimo (como *Dead Rising* / *The Last of Us*), solo unas cuantas recetas: molotov = tequila/caguama vacía + trapo; machete mejorado = machete + cinta.

### 4.6 Tiendas e interiores 💡

- Las tiendas tienen un **marcador amarillo** en la puerta (flecha/cilindro como *GTA San Andreas*). Al pararte en él: pantalla negra → apareces en el interior → otra flecha para salir.
- Los interiores son **escenas aparte** (no están dentro del mapa), así no se modela cada tienda por dentro. Un interior por tipo, reutilizado: OXXO, farmacia, tienda de abarrotes, taquería, tortillería, gasolinera.
- Dentro: mostrador con NPC que vende (menú de compra), y las **máquinas** (de dinero/premios) para la misión de sacar dinero.
- 🗳️ ¿Las tiendas cierran de noche? ¿Son refugio seguro? ¿Los zombies pueden entrar?

### 4.7 NPCs 🧱 (parcial)

Ya hay NPCs con diálogo en burbuja y aviso de "Espacio/X" (`scripts/npc.gd`). Falta:

- 💡 NPCs que **dan misiones** (marcador encima, como el "!" de *WoW* o la letra de *GTA*).
- 💡 NPCs que caminan por la banqueta de día (peatones simples).
- 💡 Comportamiento "seguir al jugador" (se usa en Simi, rescates, escoltas: programarlo una vez y reutilizarlo).

### 4.8 Zombies y hordas dinámicas 💡

Referencia del grupo: [reel de Instagram](https://www.instagram.com/reel/DehepkqD5PW/). (No se pudo ver sin cuenta; **que alguien describa qué tiene que tomarse de ahí**.) Asumimos hordas que se mueven en masa tipo *Days Gone* / *World War Z*.

Cómo se hace normalmente (y cómo lo haríamos):

1. **Director** (como *Left 4 Dead*): un script central que mide la tensión (vida del jugador, zombies cerca, hora) y decide cuándo mandar una horda, cuándo dar un respiro y dónde aparecen (siempre fuera de cámara, en calles cercanas).
2. **Movimiento en grupo**: en vez de que cada zombie calcule su ruta (caro), se calcula **un campo de flujo** (flow field) hacia el jugador/ruido por zona y todos lo siguen, con separación entre ellos (*boids*). Así cientos de zombies se ven como un río por las calles.
3. **Niveles de detalle**: zombies lejos = dibujados con `MultiMesh` y animación en el shader, sin física; cerca = zombie completo con colisión y animaciones. Igual que ya hacemos con las casas y árboles del mapa.
4. **Ruido**: disparos, molotov, bocina y paloma crean "puntos de ruido" que redirigen la horda.

Presupuesto 💡: ~30 zombies completos cerca + ~200 "baratos" lejos (hay que medir, sobre todo en navegador).

**Tipos de zombie** 💡 (copiados de *Left 4 Dead* y adaptados):

| Zombie | Basado en | Qué hace |
|---|---|---|
| **Aguado** (normal) | Común de L4D | Lento, en grupos. |
| **Corredor** | Runner de *Dying Light* / *28 días* | Rápido, frágil. Aparece de noche. |
| **Hinchado** | Boomer | Gordo de agua sucia; al morir explota y moja: atrae a otros / sube infección. |
| **Escupidor** | Spitter | Escupe charcos de agua contaminada que hacen daño. |
| **Garrafonero** | Tank | Grande, trae garrafones como armadura. Mini-jefe de noches avanzadas. |
| **Botarga zombie** | Original | Botarga podrida del Simi/de algún negocio. Jefe o easter egg. |

---

## 5. Objetos

Columnas: **Modelo** = si ya hay modelo 3D en el repo (🧱) o falta (❌). Efectos y precios son 💡 para discutir.

### 5.1 Lista del equipo

| Objeto | Tipo | Efecto propuesto | Modelo |
|---|---|---|---|
| Caguama | Consumible | Recupera vida; mareo ligero (cámara se mece) unos segundos. Vacía → sirve para molotov. | 🧱 `models/aguamala.glb` ("Caguama Agua Mala") |
| Mochila del Partido Verde | Equipo | Aumenta ranuras de inventario. | 🧱 `models/objetos/mexican_starter_pack/mochila.scn` |
| Pistola | Arma de fuego | Daño medio, poco ruido relativo. | 🧱 `models/armas/pistola_mk23/`, `pistola_colt/` |
| Balas | Munición | Para pistola (¿y cuerno?). Apilable. | 🧱 `models/armas/balas/` (cajas de munición) |
| Takis Fuego | Consumible | *Buff* de daño o velocidad de golpe por 30 s. | 🧱 `models/objetos/takis/` |
| Tachas | Consumible | Velocidad y estamina infinita 20 s; después "bajón" (lento). Pantalla distorsionada. | 🧱 `models/objetos/tachas/` (dos pastillas) |
| Cuerno de chivo | Arma de fuego | Automática, mucho daño y **mucho ruido**. Rara. | 🧱 `models/armas/cuerno_de_chivo/` |
| Ballesta | Arma | Silenciosa, se recuperan las flechas. | 🧱 `models/armas/ballesta/` |
| Machete | Cuerpo a cuerpo | Silencioso, arma inicial. | 🧱 `models/armas/machete/` |
| Bomba molotov | Arrojable | Fuego en área. Se puede craftear. | 🧱 `models/objetos/botella/` + `trapo/` (toalla pintada sucia) |
| Paloma (cohete) | Arrojable | Aturde a los enemigos cercanos. | ❌ (el modelo bajado salía mal) |
| Tacos | Consumible | Recupera vida. | 🧱 `models/taco_pastor.glb` |
| Agua limpia | Moneda / consumible | Dinero "fuerte"; baja la infección. | 🧱 `models/objetos/galon_agua/`; ❌ botella de agua y garrafón (los bajados salían mal) |
| Refresco Jarritos | Consumible | Recupera estamina. | 🧱 `models/objetos/jarritos/` |
| Moneda de peso | Moneda | Dinero normal. | 🧱 `models/objetos/moneda_peso/` |
| Cigarro | Consumible | Sacas humo un ratito. 💡 Para que sirva de algo: el humo **te esconde del olfato** de los zombies unos segundos. | 🧱 `models/objetos/cigarro/` (cajetilla) |

### 5.2 💡 Objetos sugeridos (agregar los que gusten)

| Objeto | Tipo | Efecto | Referencia | Modelo (`models/`) |
|---|---|---|---|---|
| **Bocina con banda** | Arrojable | Toca música y atrae a todos los zombies cercanos; luego explota (o no). | *Pipe bomb* de L4D | 🧱 `objetos/bocina/` |
| **Cloralex** | Material | Agua sucia + Cloralex = agua limpia. | Crafteo tema agua | 🧱 `objetos/cloralex/` |
| **Agua sucia** (bote) | Material | Se junta de charcos/llaves; se purifica. | — | ❌ (la bajada salía en piezas) |
| **Chancla** | Arrojable | Aturde a un solo enemigo, se recoge de nuevo. La de tu jefa nunca falla. | Humor | 🧱 `objetos/chancla/` (la Crocse elegida es de pago) |
| **Bate / varilla** | Cuerpo a cuerpo | Armas de inicio alternativas al machete. | *Dead Rising* | 🧱 `armas/bate/`, `armas/melee_psx/` |
| **Resortera** | Arma | Silenciosa, munición = piedras (infinitas pero débil). Para tiro al blanco. | — | 🧱 `armas/resortera/` |
| **Torta ahogada** | Consumible | Cura mucho pero pica: pantalla roja unos segundos. | Comida local | ❌ |
| **Tejuino** | Consumible | Cura algo de infección (¿lo fermentado mata el bicho?). | Comida local | 🧱 `objetos/tejuino/` (vaso con hielos pintado café) |
| **Vaporub** | Consumible | Cura todo (es la creencia popular). Raro. | Humor | 🧱 `objetos/vaporub/` |
| **Botiquín del Simi** | Consumible | Curación grande. | *First aid kit* | 🧱 `objetos/botiquin/` |
| **Veladora** | Colocable | Ilumina la zona; los zombies le tienen miedo un rato (zona segura temporal). | *Dying Light* (luz UV) | ❌ |
| **Tequila / mezcal** | Material | Para molotov o para curar (¿?). | — | ❌ (el modelo bajado salía mal) |
| **Cinta canela** | Material | Reparar/mejorar armas, barricadas. | *Dead Rising*, *TLOU* | 🧱 `objetos/cinta/` (azul) |
| **Tablas** | Material | Barricadas (si se vota refugio, 1.3 B). | *7 Days to Die* | 🧱 `objetos/tablas/` |
| **Lámpara / celular** | Equipo | Linterna de noche (con batería). | Todos los survival | ❌ (los bajados salían mal) |
| **Gansito** | Consumible | Barato y común; poca vida. | — | 🧱 `objetos/gansito/` |
| **Llave de un coto** | Clave | Abre una zona cerrada del mapa. | Llaves de RE | 🧱 `objetos/llave/` |

---

## 6. Misiones

Las misiones se programan **una vez como sistema** (ver 6.3) y luego cada misión es casi solo datos. Columna **Dificultad de programar**: S = fácil (reusa sistemas), M = media, L = difícil.

### 6.1 Lista del equipo

| Misión | Cómo funciona | Basada en | Paga | Prog. |
|---|---|---|---|---|
| **Transportar droga de noche** | Recoges un paquete en A y lo llevas a B **de noche**. Si mueres lo pierdes. | Misiones de entrega de GTA | Mucha agua limpia | S |
| **Transportar algo de día** | Igual, de día; con límite de tiempo o "no corras" (es frágil: un garrafón, un pastel). | *Crazy Taxi*, *Death Stranding* | Pesos | S |
| **Pelearse con cholos** | Al aceptar, aparecen N cholos en un punto del mapa; derrótalos. | GTA SA (guerras de pandillas) | Pesos/objeto | M (IA de pelea humana) |
| **Encontrar cosas regadas** | Buscar N objetos en el mapa y volver con el NPC. | Coleccionables de GTA | Objeto | S |
| **Corretear a alguien** | Un NPC huye por una ruta; alcánzalo antes de que escape. | Persecuciones de GTA, *Sleeping Dogs* | Pesos | M |
| **Botarga del Simi** | Te pones la botarga (baila 🧱 `models/personajes/dr_simi/simi_botarga.scn`); al acercarte a un NPC se pone a bailar y te sigue; junta 6 y todos bailan. | Original (tipo *Pikmin* / "seguir al líder") | Objeto especial | S-M (reusa "seguir") |
| **Tiro al blanco** | Ver 6.2: botellas en una barda o feria. | Minijuegos de RDR / GTA | Pesos/munición | S |
| **Sacar dinero de máquinas** | Dentro de una tienda, "romper" las máquinas (minijuego de botones o golpes) sin que te vea el encargado. | Robos de tiendas en GTA | Pesos | S-M |
| **Manifestación / pelear con policías** | Te unes a una marcha (por el agua, obvio); llegan policías; aguantar X tiempo o llegar a un punto. | Disturbios de *Sleeping Dogs*/GTA | Pesos/agua | L (multitud + IA) |

### 6.2 💡 Misiones sugeridas (de juegos parecidos, fáciles de hacer)

| Misión | Cómo funciona | Basada en | Prog. |
|---|---|---|---|
| **Repartir garrafones** | Llevas garrafones casa por casa en tu ruta antes de que oscurezca. Encaja perfecto con el tema. | Paperboy, misiones de reparto de GTA | S |
| **Rescatar sobreviviente** | Un vecino atrapado; llévalo al refugio (te sigue, reusa Simi). | *Dead Rising* | S |
| **Limpiar un nido** | Una casa/coladera llena de zombies; destrúyela de día cuando están dormidos. | Nidos de *Dying Light*, *State of Decay* | M |
| **Defender el puesto** | Ayuda al taquero a aguantar 2 min de zombies mientras cierra. | Horda de CoD/L4D | S (reusa hordas) |
| **Muestras de agua** | Un científico te pide agua de 3 llaves/charcos; cuenta la historia del brote. | Coleccionables de historia | S |
| **Carrera** | Checkpoints por la colonia a pie (o en carrito de súper). | Carreras de GTA | S |
| **Pintar bardas** | Grafitea N bardas marcadas (decal) antes que la pandilla rival. | Tags de GTA SA, *Jet Set Radio* | S |
| **Cocinar tacos** | Minijuego de pedidos en un puesto: arma el taco que te piden. | *Overcooked*, *Papa's Taco Mia* | M |
| **Buscar al perro perdido** | Sigue pistas/ladridos; regresa al perro (te sigue). | Clásico de RPG | S |
| **Encargo de compras** | Compra lista X en el OXXO y entrégala. Enseña las tiendas. | Tutorial | S |
| **Sobrevive hasta el amanecer** | Misión nocturna: quédate vivo en una zona marcada. | *7 Days to Die* | S |
| **Cooperativas** (si hay multijugador) | Una persona maneja/carga, la otra defiende; misiones que piden 2+ jugadores. | *L4D*, *GTA Online* | M |

**Tiro al blanco**, ideas concretas: (a) caguamas vacías sobre una barda con resortera/pistola, puntos por tiempo; (b) puesto de feria con patitos; (c) zombies "de práctica" atados. La (a) es la más fácil.

### 6.3 Sistema de misiones 💡 (cómo programarlo)

Para que cualquiera pueda agregar misiones sin tocar código:

- `MisionData` (Resource `.tres`, igual que `InventoryItemData`): nombre, NPC que la da, descripción, recompensa, si es de día/noche, y una **lista de pasos**.
- Tipos de paso reutilizables: `ir_a(punto)`, `recoger(objeto, n)`, `entregar(objeto, npc)`, `derrotar(tipo, n)`, `seguirme(npc, n)`, `sobrevivir(segundos)`, `alcanzar(npc)`.
- Un gestor de misiones (autoload, como `Inventory`) lleva la misión activa, el marcador en el minimapa 🧱 y la flecha en pantalla.

Con eso, casi todas las misiones de arriba son S.

---

## 7. Enemigos humanos 💡

| Enemigo | Comportamiento | Referencia |
|---|---|---|
| Cholos | Pelean cuerpo a cuerpo/en grupo, huyen si pierden a la mitad. | Pandillas de GTA SA |
| Policías | Aparecen si haces desmadre (manifestación, robo). ¿Nivel de búsqueda tipo GTA? | Estrellas de GTA |
| ¿Otros jugadores? | 🗳️ ¿Se puede dañar a otros jugadores (PvP)? | DayZ (sí) / Unturned (opcional) |

---

## 8. Interfaz (HUD) 💡

- Vida, estamina, infección (esquina inferior).
- Minimapa redondo estilo GTA 🧱 (ya existe en `map_test.tscn`) con marcadores de misión y tiendas.
- Reloj/sol-luna para la hora del día.
- Munición del arma actual + hotbar.
- Todo en español informal, fuente pixelada.

---

## 9. Arte y sonido

- Look PS1 🧱: resolución 640×480, *dither*, vértices que tiemblan (shaders en `shaders/`).
- 💡 Música: de día cumbia/banda de radio vieja; de noche, tensión. ¿Alguien del equipo hace música?
- 💡 Sonidos clave: gemido de zombie, campana del atardecer, el grito del garrafonero ("¡el agua!") como aviso, palomas tronando.

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
| Personajes | `models/personajes/` | **Sin colocar.** Gente: cholo (animado), gang_member, gangster_dealer, indian_gangster, policia (3 policías, sin rig), soldado, mujer_psx, chava_psx, hombre_psx (base sin textura), psx_man, amerindios ⚠️ (malla estirada al importar). NPCs de misiones: **garrafonero** (trabajador de chamarra azul; pesado, 24 mil triángulos), **taquero** (animado), **encargada** de tienda, **cientifico**, **perro** (animado). Zombies: zombie_ripper (idle/caminar/atacar/correr), zombie_psx, zombie_gordo (idle, correr, golpe, morir, 2 ataques: sirve de zombie base y de hinchado). Simi: **`dr_simi/simi_botarga.scn`** = botarga con esqueleto de Mixamo y el baile (15 s, `bailar` en loop), sacada del kiosco por `tools/map_import/separar_simi.gd`; el kiosco completo es `dr_simi/scene.gltf`. simi_muneco (sin rig, de repuesto). |
| Armas | `models/armas/` | machete, melee_psx (pack cuerpo a cuerpo), pistola_mk23, pistola_colt ⚠️ (sale en piezas), cuerno_de_chivo, ballesta, bate, resortera, balas. |
| Objetos | `models/objetos/` | Del Mexican Starter Pack solo se usan `mochila` y `mazapan` (`.scn`, `tools/map_import/separar_pack.gd`). Inventario: botella + trapo (molotov), tachas (pastillas), tejuino, gansito, chancla, cigarro, vaporub, cloralex, botiquin, cinta, tablas, bocina, llave, galon_agua. Misiones: paquete (pila de cajas), patito (tiro al blanco), carrito_super (carrera), refrescos. |
| Props de calle | `models/props/` | alto, coladera (nido), despachador_agua (garrafón en su base). |
| Interiores | `models/interiores/` | mostrador, estante_fruta, maquina_refrescos, m3_mart (tiendita completa, 5.5 mil triángulos). |
| Animaciones | `models/animaciones/` | Quaternius Universal Animation Library 1 y 2 (CC0, `tools/fetch_cc0.py`), esqueleto humanoide propio (no Mixamo): se pasan a otros personajes con el retarget de Godot (`BoneMap` + `SkeletonProfileHumanoid`). Incluyen: machetazo (`Sword_Attack`, `Sword_Regular_A/B/C`), pistola (`Pistol_Aim_*`, `Pistol_Shoot`, `Pistol_Reload`), lanzar (`OverhandThrow`), esquivar (`Roll`), empujón (`Push_Loop`, `Hit_Knockback`), golpes (`Punch_Jab/Cross`, `Melee_Hook`), recibir golpe y morir (`Hit_Chest`, `Hit_Head`, `Death01`), **zombie** (`Zombie_Walk_Fwd_Loop`, `Zombie_Idle_Loop`, `Zombie_Scratch`), cargar garrafón (`Walk_Carry_Loop`), comer/beber (`Consume`), bailar (`Dance_Loop`), correr, agacharse, caminar, hablar por teléfono. |

Cada modelo trae una captura **`preview.png`** en su carpeta (y `<nombre>_preview.png` junto a cada `.scn` suelta), generada por `tools/map_import/capturas.gd`; sirve de vistazo y de ícono provisional del inventario. Los modelos pesados se reducen al importar (`TiendaPostImport.MAX_TRIANGULOS`) y todos usan el shader PS1; `TiendaPostImport.TINTES` repinta materiales (tejuino, trapo). Créditos en `CREDITS.md`.

### 10.2 Faltan ❌

| Prioridad | Modelo | Notas |
|---|---|---|
| Alta | **Personaje jugable** definitivo | ¿Quién es? ¿se puede personalizar (en multijugador ayuda distinguirse)? Candidatos: hombre_psx, mujer_psx, chava_psx + animaciones de Quaternius. |
| Alta | Juntar animaciones con personajes | Retarget de las de Quaternius al jugador, zombies y NPCs (hoy cada modelo trae solo las suyas). |
| Media | Interiores armados: OXXO, farmacia, abarrotes | Ya hay mostrador, estantes, máquina y la tiendita m3_mart; falta armar las escenas. |
| Media | Objetos que se quitaron porque salían mal: garrafón (para repartir garrafones; el del despachador `props/despachador_agua` sí sirve de referencia), botella de agua, agua sucia, lámpara, celular, máquina de tienda, tequila, paloma, veladora | Buscar otros en Sketchfab o modelar low-poly. |
| Media | Arreglar: pistola_colt, amerindios | Salen en piezas / malla estirada; buscar reemplazo o arreglar en Blender. |
| Baja | Garrafonero más ligero | El modelo elegido queda en 24 mil triángulos (meshoptimizer no baja más). |
| Baja | Escupidor, garrafonero zombie, botarga zombie | Variantes del zombie base (textura/color). |
| Baja | Torta ahogada, grafitis | Nada usable en Sketchfab: modelar low-poly / calcomanías. |
| Baja | Marcador amarillo de misión | |
| — | **Sonidos y música** | Pendientes. |

Fuentes: Sketchfab con licencia CC (hay script: `tools/map_import/fetch_sketchfab.py`, agrega créditos a `CREDITS.md` solo; en git solo va la versión horneada `<modelo>.scn` que usa Godot, ver `tools/map_import/hornear_modelos.gd`), Mixamo para animaciones, o modelar en Blender en low-poly (lo más PS1).

---

## 11. Multijugador en navegador: implicaciones técnicas

Si se vota 1.1 A, esto es lo que implica (para que se decida sabiendo):

1. **Render**: Godot en navegador **no soporta Forward+** (el render actual). Hay que pasar el proyecto a **Compatibility** (WebGL 2). Los shaders PS1 deberían funcionar, pero hay que probar todos (`ps1_combined`, fachadas, suelo, casas, minimapa) y la niebla/iluminación se verán distintas.
2. **Rendimiento**: hoy el mapa va a ~150-190 FPS en la laptop de Juanjo con Forward+. En navegador esperar bastante menos; puede que haya que bajar distancia de dibujo y número de zombies.
3. **Descarga**: el mapa (~11 MB) + modelos (~30 MB) se bajan al abrir la página. Aceptable, pero hay que cuidarlo.
4. **Hilos**: la carga del mapa en segundo plano usa hilos; en web eso necesita cabeceras especiales del servidor (COOP/COEP) o exportar sin hilos (más tirones al cargar). Probar.
5. **Servidor**: hace falta un **servidor dedicado** (Godot sin pantalla, `--headless`) corriendo en algún lado (VPS, Fly.io, Railway…). Los navegadores se conectan por **WebSocket** (`WebSocketMultiplayerPeer`). Tiene costo mensual (bajo).
6. **Autoridad**: el servidor decide dónde están los zombies, quién le pegó a quién, el reloj día/noche y el inventario (si no, es facilísimo hacer trampa). Esto significa que **cada mecánica se programa pensando en red** desde el inicio.
7. **¿Un mundo para todos o salas?** 🗳️ Un solo mundo con todos los que entren (como un `.io`) es lo más bonito, pero cientos de zombies × muchos jugadores pesa. Lo normal es **salas de hasta 8-16 jugadores**; si una se llena se abre otra.
8. **Persistencia**: si el sandbox es sin fin, ¿se guarda tu inventario al cerrar la página? Necesitaría cuentas/guardado en el servidor. 💡 Para empezar: no se guarda nada, cada sesión empieza de cero (como los `.io`).

💡 **Recomendación técnica**: primero una prueba chica de 1-2 semanas: exportar `map_test.tscn` a web en Compatibility, medir FPS, y conectar 2 jugadores por WebSocket que se vean moverse. Si eso jala, seguimos con multijugador; si no, se decide con datos.

---

## 12. Plan de trabajo 💡

Borrador; se ajusta cuando se cierren las decisiones de la sección 1.

| Hito | Qué | Depende de |
|---|---|---|
| **0. Decisiones** | Votar sección 1. Repartir áreas. | — |
| **1. Prueba web/red** | Lo de la recomendación de la sección 11. | 1.1 |
| **2. Loop mínimo** | Pasar jugador/NPC/inventario al mapa real; ciclo día/noche; machete; 1 zombie que persigue y pega; morir/reaparecer. | 1.3, 1.5 |
| **3. Misiones** | Sistema de misiones (6.3) + 3 misiones S (encargo OXXO, repartir garrafones, encontrar cosas). | Hito 2 |
| **4. Hordas** | Director + flow field + LOD de zombies; ruido. | Hito 2 |
| **5. Economía y tiendas** | Pesos/agua, interior genérico, comprar/vender, marcador amarillo. | Hito 3 |
| **6. Contenido** | Más armas, objetos, misiones (Simi, cholos, tiro al blanco), zombies especiales. | Hitos 3-5 |
| **7. Pulido** | HUD, sonido, música, balance. | Todo |

### Áreas (pon tu nombre)

| Área | Responsable |
|---|---|
| Jugador, cámara y combate | |
| Zombies, IA y hordas | |
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
- [ ] ¿El personaje jugable es alguien en particular (historia) o cada jugador hace el suyo?
- [ ] ¿Se puede pegar a otros jugadores (PvP)?
- [ ] ¿Las tiendas son zona segura de noche?
- [ ] ¿Hay vehículos? (bici, carrito de súper, camión) — dan mucho juego en el mapa real pero son trabajo L.
- [ ] **Marcas reales** (OXXO, Simi, Farmacia Guadalajara, Takis, Jarritos, Pemex, Partido Verde): para un proyecto de escuela/gratis no hay bronca práctica, pero si algún día se publica o se cobra, conviene cambiarlas por parodias ("OXO", "Dr. Simio"…). ¿Lo decidimos desde ahora para no rehacer modelos después?
- [ ] Tachas, droga y cuerno de chivo: ¿el tono es parodia? Afecta la clasificación si se publica en alguna tienda (itch.io no tiene problema).

---

## 14. Registro de decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-27 | Premisa: agua sucia de Guadalajara → zombies. Día = misiones, noche = sobrevivir. Monedas: pesos y agua limpia. Inventario estilo RE. Look PS1 en el mapa real de Zapopan. | Equipo (lo que ya se había platicado) |
