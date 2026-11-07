# Mejoras y economía — diseño

Documento de trabajo para diseñar **cómo crece el jugador** (movimientos, daño, velocidad) y **cómo lo paga** (pesos, tazos, misiones), de modo que su escala de poder vaya a la par de lo que gana y de lo que crecen los zombis.

Leyenda (la misma de `especificaciones.md`): ✅ decidido · 💡 propuesta · 🗳️ por votar · 🧱 ya está en el código.

Pedido de JJ (2026-11-06): el jugador empieza solo con el combo de dos machetazos; el golpe cargado, el golpe giratorio, bloquear y rodar se aprenden; la velocidad de ataque se mejora. Las mejoras de la pistola y las pastillas con *buffs* se discuten después.

> **🧪 Ya hay un banco de pruebas para esta economía (2026-11).** `scenes/escena_carrera.tscn` es el refugio mini (safehouse en modo carrera) con todas las tiendas físicas y una tienda de mejoras tipo **"punto"**; se compra **solo con pesos** y cada noche se mide con `Registro` (ataques, mecánicas, ítems, enemigos y oleadas) en `user://pruebas/`. El catálogo de mejoras está en `scripts/Mejoras.gd` y se probó contra la defensa compartida; el **godmode** (`scenes/defensa_tinaco.tscn` directo) pone el mismo catálogo al máximo con ítems infinitos. Los movimientos que hoy son gratis (rodar/bloquear) siguen gratis; el punto vende cargado, giratorio, estela, stats y buffs. Lo de complexión/altura queda para después. Ver `docs/pruebas-balance.md`.

---

## 1. La idea

- ✅ **Empiezas débil y aprendes a pelear.** Cada movimiento nuevo cambia cómo juegas, no solo cuánto pegas.
- 💡 **Una mejora ≈ lo que ganas en una noche buena.** Así cada amanecer trae una decisión de compra, y no se puede comprar todo en una partida (como el árbol de tazos, §4.12 de `especificaciones.md`).
- 💡 **El tiempo para matar un zombi normal se mantiene parecido** a lo largo de la partida. Lo que crece son los grupos, los tipos de zombi y la presión. Las mejoras sirven para aguantar más zombis a la vez, no para que cada uno muera más rápido sin fin.
- ✅ **Nada de esto lee al `Personaje`** (tono de piel): el combate no discrimina (`CLAUDE.md`, Character).

---

## 2. Lo que hay hoy 🧱

Todos los números están en el código; aquí van para tener la referencia junta.

### 2.1 El jugador

| Movimiento | Daño | A quién le pega | Dónde está |
|---|---|---|---|
| Machetazo A / B (combo en X) | arma (machete 12, reforzado 18) | el zombi más cercano en un cono al frente, alcance 2.4 m | `Player._atacar`, `ATAQUE_*` |
| Puñetazos (jab, cruzado, gancho) | 5, 5 y 8 (gancho ×1.6) | igual | `Player.PUNOS`, `DANO_PUNO` |
| Golpe cargado: estocada | arma ×1.5 | hasta 6 en 2 m al frente mientras avanzas 3.5 m | `ESTOCADA_*`, `CARGA_DURA` 0.4 s |
| Golpe giratorio (en el aire) | arma ×1.5 | hasta 6 alrededor, alcance ×1.3 | `GIRO_*` |
| Bloquear | recibes 25 % | golpes de frente; te desliza según el daño | `BLOQUEO_*` |
| Rodar | — | invulnerable ~0.32 s, avanza 3 m | `RODAR_*` |
| Pistola | 8 (cabeza ×3) | un zombi; con ayuda de puntería | `Pistola.gd` |

Tiempos medidos (`docs/pruebas-balance.md` tiene cómo probarlos jugando):

- Machete: 3 golpes por zombi, ~0.9 s encadenando (un golpe cada 0.30–0.33 s).
- Machete reforzado: 2 golpes, ~0.6 s.
- A mano limpia: 6 golpes, ~1.7 s.
- Pistola: 4 tiros, o 2 si uno es a la cabeza.
- La estocada y el giro (18 con el machete) **no matan solos** a un zombi de 30: lo dejan listo para un machetazo. Con el reforzado (27) tampoco; con Fuerza nivel 2 (+20 %, 32) sí.

### 2.2 Los zombis

| Qué | Valor | Dónde |
|---|---|---|
| Vida | 30 (jefe 400) | `Zombie.VIDA` |
| Velocidad | 3–5 m/s | `Zombie.VELOCIDAD` |
| Daño | 12 (6 en la defensa del tinaco) | `Zombie.DANO`, `Zombis.dano_jugador` |
| Pesos al morir | 1–3 | `Zombie.PESOS` |
| Noche del mapa | ~30 zombis en 6 min; sueltos de 2 a 4 vivos (cuadra entera o destruida), +15 % por noche, 1–2 turbas de 7–8 | `resources/zombis/noche_mapa.tres` |
| Defensa del tinaco | ~80 en 3:30, grupos de 3 a 9 | `Hordas.gd` |

Hoy los zombis **no crecen en vida ni en daño**: solo en cantidad (por noche y por deterioro de la zona).

### 2.3 El dinero

| Fuente | Cuánto | Notas |
|---|---|---|
| Al empezar | $120 | `Cartera.PESOS_INICIO` |
| Zombi | $1–3 (+1 por nivel de Bolsillos) | ~$60 en una noche del mapa |
| Misiones de día | $60–100 cada una, una vez por día | `resources/misiones/*.tres` |
| Defensa del tinaco ganada | $150 + galón de agua | `DefensaTinaco.PAGA` |
| Maquinitas | variable | apuesta |

Una noche buena del mapa con una misión: **~$150–200**. Con la defensa del tinaco: **~$300**.

Precios de referencia: gansito $15, tacos $45, botiquín $120, tablas $35, bate $150.

### 2.4 Lo que ya mejora al jugador

Los tazos (`especificaciones.md` §4.12, `scripts/Habilidades.gd`): Fuerza +10 % de daño por nivel, Aguante +10 % de vida, Patas +10 % de velocidad, Brazo largo +10 % de alcance, Piel dura −15 % de daño de noche, y las de Negocio. Una partida da ~10–15 bolsas y el árbol cuesta ~58 puntos.

---

## 3. El kit inicial 💡

| Tienes desde el principio | Se aprende |
|---|---|
| Combo de dos machetazos (A y B) | Golpe cargado (estocada) |
| Puñetazos sin arma | Golpe giratorio |
| Caminar, correr, brincar | Bloquear |
| La pistola 🗳️ (¿se empieza con ella o se compra?) | Rodar |
| | Velocidad de ataque (niveles) |
| | Estela del protagonista (agua para el compa, monarca para Homero): mejora de daño |

🧱 Hoy el cargado y el giro solo se prenden en el safehouse (teclas 7 y 6) y en la defensa del tinaco. Bloquear y rodar están siempre. Para el kit inicial hace falta un lugar que diga qué movimientos tienes (§6).

---

## 4. Las mejoras 💡

Costos en pesos como primera propuesta, pensando en ~$150–200 por noche. Todos los números son para afinar jugando.

### 4.1 Movimientos

| Mejora | Qué hace | Por qué la quieres | Costo 💡 |
|---|---|---|---|
| **Rodar** | Esquivar con invulnerabilidad; sale de un acorralamiento | La primera defensa: barata y para todos | $100 |
| **Bloquear** | Recibes 25 % del daño de frente y te desliza | Aguantar en un pasillo o junto al tinaco | $150 |
| **Golpe cargado** | Estocada que atraviesa: hasta 6 en línea, ×1.5 | Abrir una fila de zombis en una entrada | $250 |
| **Golpe giratorio** | En el aire, pega en redondo a hasta 6, ×1.5 | Salir de un círculo | $300 |

Orden sugerido: **rodar → bloquear → cargado → giratorio**. Lo defensivo primero, porque una noche de 30 zombis se aguanta con el combo básico si no te rodean; lo de área después, cuando crecen los grupos (turbas, defensa del tinaco).

### 4.2 Niveles

| Mejora | Por nivel | Niveles | Costo por nivel 💡 |
|---|---|---|---|
| **Velocidad de ataque** | −8 % al tiempo entre golpes del combo (`COMBO_DESDE`, `ATAQUE_ENFRIAR`) y la animación más rápida | 3 | $120 / $200 / $300 |
| **Carga rápida** | −0.1 s a `CARGA_DURA` | 2 | $100 / $180 |
| **Estocada larga** | +1 m de avance y +1 zombi | 2 | $150 / $250 |
| **Estela del protagonista** | +X % de daño (agua o monarca); se ve la estela | 1 | $400 🗳️ o un tazo holo |

Con velocidad de ataque 3 (−24 %), el machete mata en ~0.7 s en vez de ~0.9 s.

### 4.3 Armas (ya existen)

El arma es la otra mitad del daño. Hoy: puño 5, machete 12, machete reforzado 18 (receta machete + cinta canela) y bate (falta su daño). 🗳️ ¿Se compran en la ferretería, se encuentran o solo se craftean?

### 4.4 Después

- **Pistola**: cargador, recarga, daño, mira. Se diseña aparte.
- **Pastillas y comida con *buffs***: daño, velocidad o piel dura por un rato (las tachas del punto, el café, el tejuino...). Se diseña aparte.
- **Contraataque** después de bloquear a tiempo (`Melee_Hook` de Quaternius), y que un golpe muy fuerte rompa el bloqueo (`Idle_Shield_Break`).

---

## 5. La escala de poder

La regla para balancear: **cuánto daño sacas por segundo y a cuántos a la vez, contra cuántos zombis salen y cuánta vida traen**.

### 5.1 Del jugador (propuesta)

| Momento | Kit | Mata un zombi en | Aguanta |
|---|---|---|---|
| Noche 1 | combo + machete | ~0.9 s | sueltos de 2–4; una turba es peligrosa |
| Noches 2–3 | + rodar, bloquear | igual | turbas de 7–8 sin morir |
| Media partida | + cargado, velocidad 1–2, reforzado | ~0.5 s; área cada pocos segundos | la defensa del tinaco en `medio` |
| Final | + giratorio, estela, Fuerza | ~0.4 s; área en redondo | `dificil`, el jefe |

### 5.2 De los zombis (propuesta)

Que crezcan **en cantidad y en tipo**, y solo poco en vida:

- **Cantidad**: lo de hoy (+15 % por noche, más en zonas destruidas, turbas).
- **Tipos** (`especificaciones.md` §4.8): corredor (frágil, rápido) desde la noche 2; gordo (`Zombie.Tipo.GORDO`, aguanta más, castiga quedarse quieto) desde la 3; cargador como mini-jefe.
- **Vida**: +10 % por noche como mucho 🗳️. Si sube más rápido que el daño del jugador, las mejoras se sienten como "quedarte igual".

### 5.3 Del dinero

Si una noche da ~$150–200 y cada mejora cuesta lo de una noche, en una partida de 3 noches (la de prueba) alcanza para **2–3 mejoras**. 🗳️ Hay que decidir si la partida es de 3 noches o más larga (`especificaciones.md` §1.2): con 3 noches los costos de arriba son altos; con 7 o más, están bien.

Hay que cuidar que comprar curación (tacos $45, botiquín $120) no se coma todo: si una noche dura cuesta $100 en curación, la mejora se aleja. Eso es parte de la decisión (curarte o mejorar), pero hay que medirlo.

---

## 6. Cómo se aprende 🗳️

| Opción | Cómo | A favor | En contra |
|---|---|---|---|
| A. **Se compra** | Con pesos, con un maestro (un NPC: el que te enseñó a usar el machete) | Usa la economía que ya existe; decisión de cada amanecer | Hay que inventar al maestro y su lugar |
| B. **Con tazos** | Un tazo raro o holo desbloquea el movimiento (`especificaciones.md` §4.12 ya lo propone para "rodar, golpe cargado, contraataque") | Ya existe todo el sistema; sorpresa | Depende de la suerte de las bolsas |
| C. **Por misión** | Cada movimiento es premio de una misión (enseñarte a bloquear defendiendo el puesto) | Lo cuenta la historia | Más misiones que escribir |
| D. **Mezcla** 💡 | Los movimientos por misión o maestro (pesos); los niveles (velocidad, carga) con puntos de tazo | Cada sistema hace una cosa | Dos lugares donde gastar |

Recomendación de trabajo: **D**. Los movimientos cambian cómo juegas y conviene que lleguen en orden, así que van por misión o con el maestro. Los niveles son números y encajan en la página de habilidades de los tazos, que ya enseña "Ahora / Siguiente".

Para programarlo, un solo lugar que diga qué movimientos tienes (por ejemplo `Tazos.desbloqueadas` o un autoload `Mejoras`) y que `Player` lo lea antes de dejar salir cada movimiento, como hoy lee `golpe_cargado` y `giro_aereo`. El safehouse seguiría dando todo para probar.

---

## 7. Preguntas abiertas 🗳️

- ¿Cuántas noches dura una partida? Define cuánto dinero hay en total.
- ¿Se empieza con la pistola?
- ¿Cómo se aprende cada cosa (§6)?
- ¿Cuánto daño extra da la estela y cómo se gana?
- ¿La vida de los zombis sube por noche?
- ¿Las mejoras se pierden al reiniciar la partida (como los tazos) o hay algo que se quede entre partidas?
- ¿Los costos van en pesos aunque el agua sea lo caro? ¿Alguna mejora cuesta agua?

## 8. Dónde se cambian los números

| Qué | Archivo |
|---|---|
| Daño, alcance, tiempos del combo, cargado, giro, bloqueo, rodar | `scripts/player.gd` (constantes de arriba) |
| Daño de las armas | `resources/productos/*.tres` (`dano`) |
| Vida, velocidad, daño y pesos de los zombis | `scripts/map/Zombie.gd` |
| Cuántos salen de noche | `resources/zombis/noche_mapa.tres`, `scripts/defensa/Hordas.gd` |
| Pago de misiones | `resources/misiones/*.tres` |
| Habilidades de los tazos | `scripts/Habilidades.gd` |
| Resultados de las pruebas | `docs/pruebas-balance.md` |
