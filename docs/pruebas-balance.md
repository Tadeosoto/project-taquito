# Pendiente: pruebas de balance de la pelea

Rama: `golpe-direccion`. Hasta ahora los números se pusieron a ojo, solo para que la escena funcione. Falta jugarla para decidir cuánto vale cada cosa. Esta guía es para quien haga la prueba (Alan, para empezar).

## Cómo correr la prueba

```bash
git fetch && git switch golpe-direccion && git pull
godot --path . --headless --import           # una vez, por las clases nuevas
godot --display-driver wayland --path . scenes/defensa_tinaco.tscn    # la noche del tinaco (3:30 min); en Hyprland, con Wayland o el mouse se sale
godot --path . scenes/safehouse.tscn         # para probar armas contra zombis sueltos
```

Usa un mouse: con el touchpad de una laptop, Hyprland deja de leerlo mientras aprietas WASD y la mira se queda quieta.

**Controles**

- WASD para moverte y el mouse para la cámara.
- Clic izquierdo pega o dispara. E (o R) cambia entre la pistola y el arma de golpe.
- Q te cura sin abrir el inventario: se come lo que mejor llene la vida que te falta. Te deja quieto 0.8 s.
- Clic derecho apunta con la pistola.
- Tab abre el inventario.
- M prende y apaga la música en la defensa (ahí no hay mapa de papel).

**Niveles de dificultad.** La defensa tiene tres. Juega los tres en orden, de fácil a difícil, y escoge cada uno al lanzar la escena. Sin `--modo` sale el medio.

```bash
godot --display-driver wayland --path . scenes/defensa_tinaco.tscn -- --modo=facil
godot --display-driver wayland --path . scenes/defensa_tinaco.tscn -- --modo=medio
godot --display-driver wayland --path . scenes/defensa_tinaco.tscn -- --modo=dificil
```

Fuera de Hyprland puedes quitar `--display-driver wayland`. La consola imprime el modo al empezar (`Defensa: modo medio, noche de 210 s`): revisa que sea el que escogiste.

| Nivel | Qué esperar | Se debería poder |
|---|---|---|
| **Fácil** (`facil`) | Grupos de 3 a 7 zombis. El siguiente grupo no sale mientras siga vivo casi todo el anterior, así que nunca se juntan más de dos. Los corredores de las 3:00 entran por huecos distintos | Ganar con vida de sobra la primera vez. Si aquí te desmayas, avísanos: algo está mal |
| **Medio** (`medio`) | Los mismos grupos, pero el último trae 9. El siguiente sale a los 20 s aunque no hayas acabado, y los corredores entran todos por el hueco más cercano. De las 3:00 en adelante se juntan unos 8 | Ganar curándote a tiempo con Q. JJ ganó dos veces: una con el tinaco al 61 % y otra al 4 % |
| **Difícil** (`dificil`) | Como el medio, con grupos 1.3 veces más grandes (hasta 12 a las 5:00) | No se ha jugado. Es para saber cuánto falta para que pida mejores armas: anota a qué hora pierdes y por qué (te desmayaste o rompieron el tinaco) |

Para medir la partida, agrega `--monitor=<carpeta>` (por ejemplo `-- --modo=dificil --monitor=partida_dificil`). Al amanecer deja `resumen.txt` en esa carpeta: pégalo en la tabla de resultados de abajo, con el nivel que jugaste.

**Atajos**

- En la defensa, G genera otra barricada. Para repetir la misma, corre `godot --path . scenes/defensa_tinaco.tscn -- --semilla=N`; la semilla sale en la consola.
- En el safehouse, N salta al anochecer y F12 reinicia todo. Las demás teclas vienen en el panel de la pantalla.

**Qué jugar.** Juega al menos 3 noches completas de la defensa:

1. una defendiendo con el machete,
2. otra solo con la pistola,
3. otra mezclando las dos.

Si se puede, juega una cuarta sin defender, para ver cuánto aguanta el tinaco solo (con la barricada de la semilla N, en la prueba acelerada cayó como a las 23:20).

**Qué anotar en cada noche**

- La semilla de la barricada.
- La hora a la que cayó el tinaco, o cuánta vida le quedó al amanecer.
- Cuántas veces te desmayaste.
- En qué oleada se puso imposible y en cuál se aburrió.
- Cuántos golpes o tiros mata a un zombi, y si se siente bien.
- Si los corredores de las 3:00 se ven y se sienten distintos.
- Si en algún momento hubo un respiro largo, sin zombis llegando.
- Si llegaban por varios huecos de la barricada o todos por el mismo.
- Si plantado en un hueco podías con todo, o te rodeaban.

## Lo que hay que definir

| Factor | Ahora | Dónde se cambia | Pregunta |
|---|---|---|---|
| Daño del puño | 5 | `scripts/player.gd` `DANO_PUNO` | ¿Sirve de algo pelear sin arma? |
| Daño del machete | 12 (3 golpes) | `resources/productos/machete.tres` (`dano`) | |
| Daño del machete reforzado | 18 (2 golpes) | `resources/productos/machete_reforzado.tres` | ¿Vale lo que cuesta conseguirlo? |
| Daño de la pistola | 8 (4 tiros; antes 15, luego 4) | `scripts/Pistola.gd` `DANO` | JJ: la pistola debilita al grupo mientras se acerca; el machete (3 golpes) remata |
| Cadencia, cargador y recarga | 0.22 s, 12, 1.5 s, balas infinitas | `Pistola.gd` `CADENCIA`, `CARGADOR`, `RECARGA` | ¿Las balas deben acabarse (spec §1.4)? |
| Ayuda al apuntar | 2.5° (antes 4°) | `Pistola.gd` `AYUDA` | ¿Demasiado fácil o difícil con el mouse? |
| Empujón del golpe | 0 (se probó 2.5 m/s, ~0.5 m) | `Zombie.gd` `EMPUJON`, `EMPUJON_FRENA` | Pedido de Alan; JJ lo quitó porque el combo fallaba el segundo golpe |
| Zombis por machetazo | 1, el más cercano (2 en la 10ª prueba) | `player.gd` `ATAQUE_MAXIMO` | Amontonados, un combo mataba hasta 5 (9ª prueba) |
| Aturdir al pegar | Apagado (`ATURDIR` false). Encendido: 20 % por golpe cuerpo a cuerpo, además del golpe a tiempo | `Zombie.gd` `ATURDIR`, `ATURDE_PROB` | Lo pidió Alan, pero en la 8ª prueba los zombis casi no pegaban y JJ lo quitó. Nunca al jefe ni con la pistola |
| Curarse con Q | 0.8 s quieto; 5 curaciones (y la mochila escolar) al empezar la defensa | `player.gd` `CURAR_DURA`; `DefensaTinaco.gd` `PROVISIONES` | ¿Se puede curar a media pelea o te matan? |
| Vida del zombi | 30 | `scripts/map/Zombie.gd` `VIDA` | |
| Velocidad del zombi | 3-5 m/s (corredores más rápidos) | `Zombie.gd` `VELOCIDAD`; `cazador` | El jugador camina a 10 m/s en el mapa, más rápido que todos |
| Daño del zombi al jugador | 12 en el mapa; 6 en la defensa | `Zombie.gd` `DANO`; en la defensa `dano_jugador` del nodo Zombis | Con 12 te desmayabas antes de la 1:00 (ver Resultados) |
| Ritmo de ataque del zombi | 1.5 s; alcance 1.5 m | `Zombie.gd` `ATAQUE_DURA`, `ALCANCE` | |
| Vida del tinaco | 300; cada zombi le quita 2/s | `scripts/defensa/TinacoDefensa.gd` `VIDA` | El doc dice 100, pero con 100 una horda lo rompía en segundos |
| Grupos de la horda | 3 a las 22:00, 4 a las 23:00, 7 a medianoche (dos lados), 5-7 en la madrugada (corredores a las 3:00), 6 a las 4:00 y 7 a las 5:00 (con 9 se atascaba); nada después de las 5:30 | `scripts/defensa/Hordas.gd` `GRUPOS` | ¿Da tiempo de disparar mientras se acercan? |
| Cuándo sale el siguiente grupo | Cuando del anterior queda 1; mínimo 5 s; a los 20 s sale aunque no hayas acabado, solo si quedan menos de los que trae (nunca más de dos grupos juntos) | `Hordas.gd` `QUEDAN`, `ESPERA_MIN`, `ESPERA_MAX` | ¿Llega justo cuando terminas? |
| Respiro | Si la intensidad llega a 0.8, el siguiente grupo espera 6 s más | `Hordas.gd` `TOPE`, `RESPIRO` | ¿Alcanza para curarse? |
| Hueco que escoge cada zombi | 40 % el más cercano, si no otro al azar; los corredores igual (antes siempre el más cercano y llegaban todos a la vez) | `Zombie.gd` `HUECO_CERCANO` | ¿Llegan por todos lados? |
| Máximo de zombis a la vez | 30 en el mapa; 40 en la defensa | `scripts/map/Zombis.gd` `max_total` (en la escena) | ¿Rinde? Mide los FPS en el pico de las 5:00 |
| Paga del amanecer | 150 pesos y un galón (nada si cae el tinaco) | `DefensaTinaco.gd` `PAGA` | ¿Compensa la noche comparada con las misiones? |
| Jefe (mapa, última noche) | vida 400, daño 25, 3 m/s | `Zombie.gd` `JEFE_*` | |
| Golpes a tiempo | ventana 0.3 s | `Zombie.gd` `CORTE`; tecla 9 en el safehouse | ¿Se entiende sin explicarlo? |

Las habilidades de los tazos y el cuerpo del personaje (complexión y altura) multiplican la vida, el daño y la velocidad. Prueba primero con el personaje normal y sin tazos (F12 en el safehouse los borra).

## Resultados

Partidas de JJ con el monitor (`godot --display-driver wayland --path . scenes/defensa_tinaco.tscn -- --monitor=<carpeta>`). Meta con dificultad 1: llegar a las 6:00 con 75 % de vida.

| Partida | Cambio | Hasta | Daño recibido | Curaciones | Machete pegó | Nota |
|---|---|---|---|---|---|---|
| 2 | relleno constante, zombi pega 12 | 23:23 | 100 en 9 golpes | 0 | 65 % | Uno cada ~5 s con solo 1-3 encima |
| 3 | 5 curaciones | 0:08 | 190 en 16 | 3 | 52 % | A medianoche saltó a 23 vivos |
| 4 | por grupos | 0:38 | 130 en 11 | 1 | 44 % | Uno cada ~10 s; la pistola ya sirve (168 de daño) |
| 5 | zombi pega 6, pistola 4 tiros | **6:00**, 71 % de vida | 174 en 29 | 5 (145) | 57 % | Ganó, pero el tinaco quedó en 8 %: de las 4:00 en adelante se juntaron 13-16 vivos |

Después de la 5: la noche baja a 3:30 min (JJ cree que así ya no se acumulan), se quita el empujón del golpe y se corrigió un atorón de zombis entre un edificio del mapa y los costales.

| Partida | Cambio | Hasta | Daño recibido | Curaciones | Machete pegó | Nota |
|---|---|---|---|---|---|---|
| 6 | noche de 3:30, sin empujón | **6:00**, **76 %** de vida (la más baja 52) | 78 en 13 | 2 de 5 | 66 % | Cumple la meta. Nunca más de 12 vivos (6 en promedio); tinaco en 36 %; 58-60 FPS |
| 7 | grupos del final de 6-7, nunca más de dos grupos juntos, corredores por cualquier hueco | **6:00**, 58 % sin curarse (la más baja 58) | 42 en 7 | 0 de 5 | 57 % | Se quitó el atasco del final (máximo 9 vivos). Tinaco en 75 %. Ya se inclina un poco a favor del jugador |
| 8 | modo medio (las reglas de la 6) | **6:00**, 70 % sin curarse | 30 en 5 | 0 de 5 | 76 % | Mucho más fácil que la 6 con las mismas reglas: JJ ya le agarró la mano. Máximo 11 vivos; tinaco en 79 % |
| 9 | modo medio sin aturdir (`ATURDIR` false) | **6:00**, 70 % (la más baja 46) | 90 en 15 | 2 de 5 | 60 % | Sin aturdir sí te pegan: el triple del daño de la 8, repartido toda la noche y en rachas a las 3:45 y 5:20. Máximo 10 vivos; tinaco en 46 % |
| 10 | medio sin aturdir, machete a 2 zombis como máximo | **6:00**, 58 % (la más baja 46) | 132 en 22 | 3 de 5 | 71 % | El más apretado: golpes desde la 1:00 hasta el final. Máximo 11 vivos; tinaco en 86 % |
| 11 | medio sin aturdir, machete a 1 zombi | **6:00**, 46 % (la más baja **10**) | 114 en 19 | 2 de 5 | 72 % | Llegó a 10 de vida a las 5:12 y aguantó sin curarse hasta ahí. De 3:00 en adelante se juntan 8 en promedio (12 a las 3:43). Tinaco en 61 % |
| 12 | bolitas de 3 de varios lados, hueco de adentro 75/25, el que alcanza el tinaco le sigue pegando | **6:00**, 64 % sin curarse | 36 en 6 | 0 de 5 | 67 % | Casi no te pegan después de las 2:00, pero a las 5:00 se juntan 11 en promedio (15 a las 5:24). Pistola hizo más daño que el machete (870 vs 774). Tinaco en 66 % |

Se probó en la 12ª: el zombi que ya alcanza el tinaco le sigue pegando, hueco de adentro 75 % el más cercano y 25 % el segundo, y grupos partidos en bolitas de 3 de varios lados. Llegaban de uno en uno y era más fácil. Después se probó, sin jugarla, apretar los grupos del medio (4, 6 y 7 toda la noche) con bolitas de 4 que entraban juntas por el mismo hueco. JJ prefirió la 11ª y todo se regresó a como estaba ahí.

| Partida | Cambio | Hasta | Daño recibido | Curaciones | Machete pegó | Nota |
|---|---|---|---|---|---|---|
| 13 | otra vez las reglas de la 11 | **6:00**, 28 % (la más baja 28) | 102 en 17 | 1 de 5 | 73 % | El tinaco quedó en **4 %** (12 de 300): casi se pierde. Golpes parejos de 4:00 a 6:00 sin curarse. Máximo 11 vivos |
| 14 | medio (igual que la 13) | **6:00**, 52 % (la más baja 46) | 138 en 23 | 3 de 5 | 74 % | Se curó a tiempo, cada vez que bajaba de ~50. Daño parejo toda la noche, desde las 22:00. Tinaco en 57 %, máximo 10 vivos |

Desde que el golpe empujaba (~0.5 m), el machete fallaba más y el combo perdía el segundo golpe. Después de la partida 5 se quitó el empujón.

## Después del piloto: hordas que piden mejores armas

La horda piloto se tiene que poder ganar con lo que trae el jugador (machete, pistola, puño y comida), sin ser ni muy fácil ni muy difícil. Más adelante, una noche o una colonia más dura debería ganarse solo si mejoraste tu armamento. Para eso, `Hordas.dificultad` (1 en la piloto) multiplica la presión. Falta decidir si también sube la vida o la velocidad de los zombis, y cuánto daño hace falta para cada nivel. Una prueba sin defender (el jugador parado junto al tinaco) acaba con el tinaco a las 23:30 más o menos.

## Al terminar

Escribe los resultados y los números propuestos en esta página, o en un issue, para votarlos en equipo. Lo que se decida pasa a `docs/especificaciones.md` y a `docs/misiones.md` §0 (la vida del tinaco y la paga).
