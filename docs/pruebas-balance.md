# Pendiente: pruebas de balance de la pelea

Rama: `golpe-direccion`. Hasta ahora los números se pusieron a ojo, solo para que la escena funcione. Falta jugarla para decidir cuánto vale cada cosa. Esta guía es para quien haga la prueba (Alan, para empezar).

## Cómo correr la prueba

```bash
git fetch && git switch golpe-direccion && git pull
godot --path . --headless --import           # una vez, por las clases nuevas
godot --path . scenes/defensa_tinaco.tscn    # la noche del tinaco (6 min)
godot --path . scenes/safehouse.tscn         # para probar armas contra zombis sueltos
```

Usa un mouse: con el touchpad de una laptop, Hyprland deja de leerlo mientras aprietas WASD y la mira se queda quieta.

**Controles**

- WASD para moverte y el mouse para la cámara.
- Clic izquierdo pega o dispara. R cambia entre la pistola y el arma de golpe.
- Clic derecho apunta con la pistola.
- Tab abre el inventario.

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

## Lo que hay que definir

| Factor | Ahora | Dónde se cambia | Pregunta |
|---|---|---|---|
| Daño del puño | 5 | `scripts/player.gd` `DANO_PUNO` | ¿Sirve de algo pelear sin arma? |
| Daño del machete | 12 (3 golpes) | `resources/productos/machete.tres` (`dano`) | |
| Daño del machete reforzado | 18 (2 golpes) | `resources/productos/machete_reforzado.tres` | ¿Vale lo que cuesta conseguirlo? |
| Daño de la pistola | 15 (2 tiros) | `scripts/Pistola.gd` `DANO` | ¿La pistola le gana siempre al machete? |
| Cadencia, cargador y recarga | 0.22 s, 12, 1.5 s, balas infinitas | `Pistola.gd` `CADENCIA`, `CARGADOR`, `RECARGA` | ¿Las balas deben acabarse (spec §1.4)? |
| Ayuda al apuntar | 4° | `Pistola.gd` `AYUDA` | ¿Demasiado fácil o difícil con el mouse? |
| Vida del zombi | 30 | `scripts/map/Zombie.gd` `VIDA` | |
| Velocidad del zombi | 3-5 m/s (corredores más rápidos) | `Zombie.gd` `VELOCIDAD`; `cazador` | El jugador camina a 10 m/s en el mapa, más rápido que todos |
| Daño del zombi al jugador | 12 (vida 100, 0.7 s invulnerable) | `Zombie.gd` `DANO`; `Salud.gd` | ¿Cuántos golpes aguantas? |
| Ritmo de ataque del zombi | 1.5 s; alcance 1.5 m | `Zombie.gd` `ATAQUE_DURA`, `ALCANCE` | |
| Vida del tinaco | 300; cada zombi le quita 2/s | `scripts/defensa/TinacoDefensa.gd` `VIDA` | El doc dice 100, pero con 100 una horda lo rompía en segundos |
| Oleadas | 5 a 20 zombis por oleada; la grande a medianoche y corredores a las 3 | `scripts/defensa/Hordas.gd` `OLEADAS` | ¿Hay respiros? ¿La última se siente final? |
| Máximo de zombis a la vez | 30 | `scripts/map/Zombis.gd` `MAX_TOTAL` | ¿Rinde? Mide con `tools/medir_mapa.tscn` |
| Paga del amanecer | 150 pesos y un galón (nada si cae el tinaco) | `DefensaTinaco.gd` `PAGA` | ¿Compensa la noche comparada con las misiones? |
| Jefe (mapa, última noche) | vida 400, daño 25, 3 m/s | `Zombie.gd` `JEFE_*` | |
| Golpes a tiempo | ventana 0.3 s | `Zombie.gd` `CORTE`; tecla 9 en el safehouse | ¿Se entiende sin explicarlo? |

Las habilidades de los tazos y el cuerpo del personaje (complexión y altura) multiplican la vida, el daño y la velocidad. Prueba primero con el personaje normal y sin tazos (F12 en el safehouse los borra).

## Al terminar

Escribe los resultados y los números propuestos en esta página, o en un issue, para votarlos en equipo. Lo que se decida pasa a `docs/especificaciones.md` y a `docs/misiones.md` §0 (la vida del tinaco y la paga).
