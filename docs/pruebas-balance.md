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
| Recarga temprana contra en seco | Temprana (R con balas): 12+1 en 1.5 s. En seco (se vació): 12 en ~1.78 s, con la corredera | `Pistola.gd` `_recargar`, `RACK_ACERCA`, largo de `pistol_cock.wav` | ¿Se nota que conviene recargar antes de vaciar? ¿Pesa demasiado la corredera en plena pelea? |
| Ayuda al apuntar | 2.5° (antes 4°) | `Pistola.gd` `AYUDA` | ¿Demasiado fácil o difícil con el mouse? |
| Tiro a la cabeza | ×3 (24: un zombi de 30 cae con 2 tiros) desde 1.4 m de alto | `Pistola.gd` `CABEZA_MULT`, `CABEZA_DESDE` | ¿Se le atina o es pura suerte con la dispersión? |
| Dispersión de la pistola | 0.012 rad (0.004 apuntando) | `Pistola.gd` `DISPERSION`, `APUNTA_DISPERSION` | ¿Se siente que falla sin razón? |
| Empujón atrás al disparar | 0.6 m/s | `player.gd` `RETROCESO_TIRO` (0 lo quita) | ¿Estorba al disparar en grupo? |
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
| Emboscadas (defensa, no en fácil) | 2-3 cazadores cada 35-60 s desde las 23:00, del lado donde andas; van por ti y no cuentan para la siguiente oleada | `Hordas.gd` `EMBOSCADA_CADA`, `EMBOSCADA_GRUPO`, `EMBOSCADA_DESDE`; `MODOS` `emboscadas` | ¿Te castigan por alejarte del tinaco o solo estorban? |
| Estela por muertes con espada | 27 en la defensa (la mitad de los ~55 zombis que caen por noche); solo estética, no da daño | `DefensaTinaco.gd` `ESTELA_MUERTES`, `Player.muertes_espada` | ¿Se llega a 27 con espada a media noche, o hay que bajarla? |
| Tope del tinaco | 8 a la vez; los demás van por ti | `Zombis.cupo_tinaco` (en `defensa_tinaco.tscn`) | ¿Aguanta el tinaco y te queda presión a ti? |
| Más zombis por grupo | medio ×1.25, difícil ×1.6 | `Hordas.MODOS` `dificultad` | ¿Rinde a las 5:00 (FPS) y se gana? |
| Caminar a medio machetazo | 60 % de la velocidad, sin correr, viendo hacia la cámara (antes de JJ: quieto) | `player.gd` `GOLPE_VELOCIDAD`, `ATAQUE_LENTO` | ¿Te deja salirte a tiempo o se vuelve demasiado fácil? |
| Retroceso de la pistola | la cámara sube 0.6° por tiro (0.35° apuntando) y regresa en 0.2 s; la mira se abre 4 px por tiro | `Pistola.gd` `MIRA_PATADA`, `APUNTA_PATADA`, `MIRA_FLORECE`, `MIRA_CIERRA`; `player.gd` `PATADA_VUELVE` | ¿Se puede disparar rápido y seguir atinando? |
| Nervios en la mira | intensidad 1: desvío ×2.5, mira +6 px | `Pistola.gd` `NERVIOS_DISPERSION`, `NERVIOS_MIRA`, `NERVIOS_SIGUE` | ¿Se siente la presión o solo estorba? |
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
| 15 | medio, con enjambre y el protagonista nuevo (el_compa, machetazos y pistola de Quaternius; rama `protagonista-compa`) | **6:00**, 64 % (la más baja 40) | 96 en 16 | 2 de 5 | **62 %** | El machete pegó menos que en la 11-14 (72-74 %). Tinaco en **32 %**: el enjambre le pega más. Pistola 53 % (440 de daño). Máximo 12 vivos a las 5:01; 55-60 FPS |

Desde que el golpe empujaba (~0.5 m), el machete fallaba más y el combo perdía el segundo golpe. Después de la partida 5 se quitó el empujón.

**Después de la 14: zombis en enjambre** (`docs/pruebas-enjambre.md`). Ya no caminan en fila: van por carriles, cortan camino y se rebasan. En las pruebas sin ventana llegan al tinaco ~1 s antes (13.5 s contra 14.3 s en grupos de 9) y ya no se atoran en los tambos. Las partidas de arriba son con el caminar de antes; la siguiente partida con el monitor dirá si el modo medio quedó más duro. En el safehouse, la tecla 0 regresa al caminar de antes para comparar.

## Pendientes de la pelea

Lo que pidió JJ después de la partida 15 (4 de noviembre de 2026):

- **Animación de curarse** (Q, `Player._curarse`): cambiarla por una de comer o tomar; la UAL de Quaternius trae `Consume`, y ya está en `resources/personajes/animaciones_humanas.res`.
- **El zombi bloquea a veces**: 10 % de probabilidad de que un machetazo rebote, con un poco de lag (el brazo regresa y tardas en poder pegar otra vez) y sin daño.
- **Sonido del bloqueo** (`Sonidos._bloqueo`, el choque al parar un golpe con clic derecho): el de ahora es provisional; falta uno mejor.
- **Mejor interfaz durante la pelea**: la vida, el tinaco, el arma y las balas.
- **El zombi gordo, un tipo aparte** (`Zombie.Tipo.GORDO`): faltan sus ataques y sus números (`GORDO_VIDA`, `GORDO_VELOCIDAD`, `GORDO_DANO` en `scripts/map/Zombie.gd`, por ahora iguales a los del normal). Mientras no estén definidos, no sale en las hordas. Los normales ahora son el zombi PSX y los monstruos 0-3 del pack, con un skin al azar.
- **Detección** (en el mapa y en el safehouse; en la defensa ya salen alertas): los zombis deambulan hasta que te ven a 25 m, te oyen a 12 m o escuchan un balazo a 40 m, y entonces corren. Los números están al principio de `Zombie.gd` (`VE_DESDE`, `OYE_DESDE`, `OYE_DISPARO`, `CONTAGIA`). Hay que probar si las noches del mapa se quedan muy tranquilas: muchos sueltos nunca te encuentran.

## La Madre del Cárcamo (propuesta de AG, 2026-11-07)

Se prueba en `godot --path . scenes/lombrices.tscn` (el cárcamo) o con Shift+L en el safehouse. La meta (AG, 2026-11-07): una pelea de 6 a 10 minutos para alguien que juega bien, en la que lo normal es morir la primera vez que se gane con machete, pistola y unas cuantas sales y molotovs, y que sin ellas cueste mucho más. Todo son primeras adivinanzas:

| Qué | Número | Dónde |
|---|---|---|
| Sacos de la Madre | 6 × 70 de vida, radio 0.24 m, sin sanar (AG: con regeneración era una chamba); bala 5, molotov 2 cada 0.5 s; solo se pegan con ella afuera (tirada, barriendo, asomada o aturdida). Reventar uno la tumba 2 s | `MadreCarcamo.SACOS`, `SACO_VIDA`, `SACO_RADIO`, `ATURDIDA_DURA` |
| Fases | cada 2 sacos reventados (fase 2: se entierran y hacen látigos; fase 3: torres) | `MadreCarcamo._herir` |
| Descanso entre ataques | 2.2 / 1.6 / 1.0 s por fase; en fase 3, 40 % de encadenar otro sin descanso | `MadreCarcamo.DESCANSO`, `ENCADENA` |
| Avisos | mordida: 0.6 s de tierra y un gruñido grave, sin anillo; torre: una sombra tenue que crece | `AVISA_DURA`, `EnjambreLombrices._armar_anillo` |
| Daño de la Madre | choque 16, mordida 26 | `DANO_CHOQUE`, `DANO_MORDIDA` |
| Crías | 80 × 12 puntos; se arrastran a 4 m/s con arranques de 0.5 s a 7 m/s y oleadas de 2 s si hay 15+ cerca; te adelantan (apuntan a donde vas); en fase 2+ hasta 3 trepan paredes y se te dejan caer; saltan desde 4.5 m (hasta 12 a la vez, cada 1.8-4 s), muerden 9, cada pegada frena 8 % y chupa 4/s (máx. 6). Machete: corta 2 por golpe; tajo cargado: hasta 12; la cabeza no es más fácil de pegar que el cuerpo | `EnjambreLombrices` (`SALTO_*`, `PEGADA_*`, `CORTES_*`) |
| Torre | cada 16 s en fase 3, 16 de daño en 2.6 m | `TORRE_*` |
| Bola de crías | fase 2+, cada 15-25 s, 8-12 lombrices; se anuda 1 s, rueda a 5 m/s, se avienta desde 3 m por 18; 40 de vida (4 machetazos; el tajo cargado la rompe de una); al romperse quedan atontadas 1.5 s | `EnjambreLombrices.BOLA_*` |
| Machete contra crías | 4 cortes por machetazo | `CORTES_POR_DANO` 0.34 |
| Pasarela | las crías suben por la rampa más cercana a ti; la Madre escupe la mitad de las veces si estás arriba | `rampas`, `SUBE_DESDE` |
| Crecer | un punto por mitad cada 1.6 / 1.2 / 0.8 s | `CRECE_CADA` |
| Sal / molotov | sal 1.5 m por 12 s, una cabeza por lombriz cada 0.8 s; molotov 2 m por 5 s, quema un punto de la cola de cada lombriz cada 0.25 s (no las parte) | `Arrojadizo`, `SAL_CADA`, `FUEGO_CADA` |
| Cajas del cárcamo | una sal y una molotov, se rellenan cada cambio de fase | `PruebaLombrices.CAJAS` |
| Paga | $400, un tazo holo y el Diente de la Madre | `PruebaLombrices.PAGA` |

Anotar aquí: cuánto duró la pelea, cuántas sales y molotovs se usaron, cuántas veces te desmayaste y en qué fase.

## La Mojiganga (propuesta de AG, 2026-11-09; ajustada para el machete el 2026-11-10)

Se prueba en `godot --path . scenes/catrina.tscn` (la plaza del desfile) o con Shift+X en el safehouse (sale despierta; `-- --catrina` la saca al cargar). `-- --medir=40` corre los eventos forzados; `-- --cheese` revisa que no se atore atrás de un carro; `-- --bot=<s>` pelea sola por intentos (ver abajo). Todos los números están al principio de `scripts/catrina/Catrina.gd`.

Historia: AG la jugó el 2026-11-10 dos veces. La primera: "no te agarra, la animación del jugador está fuera de lugar y está muy fácil" (se endureció: 1400 de vida, combos, amagos, carga de lejos, frenesí). La segunda: "a puro machete es imposible, pero se atora en un carro y la mato a balazos; quiero más zombis en la fase 2". Meta: jefe de Dark Souls, 3-5 intentos de alguien que juega bien, que se pueda a machete.

| Qué | Número | Dónde |
|---|---|---|
| Vida | 1000; la fase 2 empieza en 670 y la 3 en 340; no se las salta | `VIDA`, `FASE_2`, `FASE_3` |
| Frenesí | abajo de 150 en la fase 3: todo × 1.5 y casi sin esperas; las velas se ponen rojas | `FRENESI`, `FRENESI_RAPIDEZ` |
| Machete | × 1.25 al cartón (la pistola no) | `MACHETE_MULT` |
| Pie plantado | tras el golpe del pisotón (1.8 s en total, antes 1.3) el pie se queda: machetazo a 3.2 m de él × 2 y cuenta doble para tumbarla; en la fase 3, la mano del manotazo | `PIE_ALCANCE`, `PIE_MULT`, `PIE_AGUANTE`, `PISA_DURA` |
| Flores a machete | de rodillas o doblada tras fallar el agarrón (2.5 s, antes 1.9), el machete le da también a la flor más cercana | `_agachada`, `AGARRA_DURA` |
| Pisotón | a menos de 3.5 m; 0.8 s de aviso; 26 en 2.5 m (antes 32); 30 % de amago | `PISA_*`, `RETRASO*` |
| Onda | 8 (antes 13), 0.45 de ancho, solo le pega al que está **afuera** del radio del pisotón: adentro se rueda el pisotón, a media distancia se brinca la onda | `ONDA_*`, `_seguir_onda` |
| Agarrón | igual; aprieta 6 (antes 8); 6 apretones para zafarte (antes 8); espera 5.5 s entre agarrones (antes 4) | `DANO_APRIETA`, `ZAFARSE`, `ESPERAS` |
| Fase 2 | grito: 3-5 zombis (antes 2-3), hasta 8 vivos (antes 4); además uno cada 10 s desde los portales mientras dure la fase | `AYUDANTES*`, `GOTEO_CADA` |
| Carros y ofrendas | los revienta al chocar con ellos, con el pisotón (4.5 m) y con la barrida (5 m); si se atora en algo que no rompe, rodea de lado 1.4 s | `ROMPE_*`, `ATASCO_*`, `RODEO_DURA` |
| Lo demás | igual que antes: pose cada 4-5 ataques, flores 4 × 70 (a balazos solo con la guardia abierta), aguante 200, fuego × 1.15 por parte quemada, combos, carga de lejos, bala a más de 15 m a la mitad | |

**El bot**: pelea por intentos como en el juego (desmayarse reinicia la pelea; cada intento empieza con vida llena y 5 tacos). Rueda antes de cada golpe (75 % de acierto, o 90 % con `--bueno`), no sabe de los amagos, brinca la onda, mata a los zombis que se le acercan, se cura abajo de 40. `--modo=machete` le pega encima, rueda hacia ella en el pisotón y castiga el pie y las flores bajas; `--modo=mixto` además dispara (simulado: 8 por tiro cada 0.3 s, 60 % de puntería, a las flores si está abierta). `--intentos=N` (8).

**Corridas finales (2026-11-10, 8 intentos cada una)**:
- Mixto bueno: una ganó al intento 8 y otra al 1 (112 s); las demás llegan a la fase 3 (la dejó en 10 de vida una vez). Mixto normal: ganó al intento 4.
- Machete bueno: ninguna gana aún; llega a la fase 3 dos de 8 (la mejor la dejó en 207). Machete normal: fase 3 dos de 8.
- Todos los intentos duran ~1 minuto: el bot esquiva mal (no lee los amagos, no se aparta de la barrida ni de los zombis). Alguien que juega bien debería durar más y ganar a machete; si no, lo siguiente a mover es `MACHETE_MULT` o `PISA_DURA`.
- `--cheese`: revienta el carro a los 3.4 s (pasa).

Anotar aquí cuánto duró, cuántas veces te desmayaste y en qué fase, a machete y con pistola.

## Verificaciones pendientes: zombis PSX y detección

Solo se probó con escenas de prueba y capturas: el visor de los cinco skins, una noche de 70 s de la defensa sin nadie defendiendo (sin errores, 57-61 FPS), y `map_test` y la pantalla de inicio sin errores. Falta probarlo jugando:

- **Safehouse, a mano**:
  - ¿se sienten bien las distancias? Vista a 25 m (solo al frente), oído a 12 m, y un balazo a 40 m;
  - ¿el contagio a 8 m hace que arranquen en grupo?
  - al correr, ¿trotan o esprintan sin patinar?
  - ¿el daño del zarpazo cae cuando baja la mano?
  - en los skins nuevos: el flash blanco, la barra, el reventón, los restos, el gruñido del golpe a tiempo (tecla 9) y la caída al amanecer (`Death01`).
- **Noche en `map_test`**: ver si queda demasiado tranquila, porque muchos sueltos nunca te encuentran. Revisar el conteo de salieron/matados al amanecer.
- **Jefe**: en la última noche debe seguir siendo el gordo teñido.
- **Rendimiento**: correr `godot --path . tools/medir_mapa.tscn` y compararlo con el commit anterior.
- **Defensa jugada de verdad**, para compararla con la partida 15.
- **Zombis en fila en el tinaco**: cuando nadie los mata, los de atrás se quedan corriendo en su lugar. Deberían rodear el tinaco y pegarle desde el siguiente espacio libre, o detenerse (JJ, para otra sesión).

## Después del piloto: hordas que piden mejores armas

La horda piloto se tiene que poder ganar con lo que trae el jugador (machete, pistola, puño y comida), sin ser ni muy fácil ni muy difícil. Más adelante, una noche o una colonia más dura debería ganarse solo si mejoraste tu armamento. Para eso, `Hordas.dificultad` (1 en la piloto) multiplica la presión. Falta decidir si también sube la vida o la velocidad de los zombis, y cuánto daño hace falta para cada nivel. Una prueba sin defender (el jugador parado junto al tinaco) acaba con el tinaco a las 23:30 más o menos.

## Al terminar

Escribe los resultados y los números propuestos en esta página, o en un issue, para votarlos en equipo. Lo que se decida pasa a `docs/especificaciones.md` y a `docs/misiones.md` §0 (la vida del tinaco y la paga).
