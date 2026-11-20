# Missions (code)

How the mission system works in code. Read it before changing `Misiones`, `MisionesMundo`, `PasoMision`/`MisionData`, a step type, a `lugar` keyword, or adding a mission. The mission design (who gives what, lines, pay) is in `docs/misiones.md`; the root `CLAUDE.md` keeps only a summary. (Moved out of the root `CLAUDE.md` on 2026-11-20 to keep it under 25 KB.)

## The autoload and the journal

`Misiones` autoload (`scripts/Misiones.gd`):

- **Offers and the journal:** people give missions by day; offers stop at the dusk warning. Missions are played by day or night. Any number wait in the journal (`aceptadas`, no cap) but only `activa` advances (`elegir` switches it, progress is kept).
- **Step hours:** each `PasoMision.cuando` (DIA, NOCHE, CUALQUIERA) says when that step can be done. Outside it the mission waits (no failure, its timer stops), so a night delivery can end with an ENTREGAR to the giver the next day.
- **LUGAR missions:** `MisionData.inicio = LUGAR` missions start at a place (`empezar_en_lugar`), stay out of the journal and push the journal's mission aside until they end.
- **Once per day:** each mission once per day; it fails when its timer ends.
- **Across scenes:** the state survives scene changes. Only `Inicio` and the safehouse call `reiniciar()`.
- **The journal UI:** `MisionesUI.gd` (inventory tab, J). Enter makes a mission the active one (`Misiones.elegir`) and opens the paper map on its pointer. It's refused during a LUGAR mission or while `manos_ocupadas` (carrying the dog).
- **Carried things and hour hints:** a step's `carga` is only carried during its hour. Accepting one whose first step is at another hour shows the protagonist's thought on screen (`Supervivencia.avisar`), not a giver line.
- **Giver initials on maps:** important givers have `MisionData.inicial`. While they offer work, `MisionesMundo` lists them in `Misiones.dadores`, and `MapaUI`/`MapMinimapa` draw the initial in a white circle. Only `medicina_noche` has one ("M"), as a test.

## What's in the world (`MisionesMundo`)

`scripts/map/MisionesMundo.gd`, created by `Partida`, holds what's in the world:

- givers: `npc.tscn` using `al_hablar`, a callable returning the line for each press;
- the objective arrow and the objective line;
- delivery spots;
- the dog (`CosaMision.gd`);
- the minimap and paper-map targets.

**To add a mission without code:**
1. Copy a `.tres` in `resources/misiones/`: a `MisionData` with `PasoMision` steps (`TENER_OBJETOS`, `ENTREGAR`, `VISITAR`, `RECOGER`).
2. Add it to `Misiones.ARCHIVOS`.
3. Give it a giver spot. The safehouse's `vecinos` list has one per mission plus the tazos kid.

A new `lugar` keyword or step type needs code in `MisionesMundo`.

**House deliveries** (`lugar = "casas"`, P4): random house fronts 18-120 m from the giver (`_lugares_de_casas`).
- Never a house inside a fortress, nor one outside whose front faces the wall (`MuroColonia.adentro`).
- For the water delivery (`LLEVAR_CARGA` to `casas`), accepted inside a Blender colony: the arrow points to the nearest exit, and the houses are picked outside near that gate.
- In Santa Mugre, like "Al médico", it isn't offered until the gate is open.

## Route steps (S2a)

**`ESCOLTAR`** spawns an `Acompanante` at the giver; the step ends when both reach `lugar` (`casas`, `giro:x`, `marca:x`). `scripts/map/Acompanante.gd`:
- Follows the player at 3.6 m/s through `Zombis.campo_jugador`, the flow field, which keeps running by day while any exists.
- Goes straight within 3.5 m and teleports next to you if stuck.
- Has `vida`, `recibir_golpe` and `cayo`.
- `Zombie._destino` goes for the nearest one if it's closer than the player.

**`LLEVAR_CARGA`** is `VISITAR` with `carga` in hand and `pesos_por_entrega` per stop.

Both are one-hour steps:
- `Misiones.ruta_en_curso()` is true while in hour, and `elegir` is refused meanwhile.
- The mission fails if the hour ends (dawn = police) or on `Misiones.desmayo()` (from `Supervivencia._desmayarse`).
- Use `Misiones.cambio_de_escena()`, not a bare `es_noche = false`: it avoids a false failure on the unknown-hour frame.

## DEFENDER, CAZAR, ENTRAR_A

**`DEFENDER`** holds `segundos` within 20 m of `lugar`.
- The clock only runs there (`Misiones.defendiendo`); zero = win.
- `Zombis.aparecer_turba(cuantos, angulo)` fires every `ola_cada` s. The size is `cuantos`, not `turba`; `turba` is CAMIONETA's.
- An optional `acompanante` stays put (`Acompanante.quieto`, draws zombies from 22 m) and its fall fails the mission.
- Zombies hit an `Acompanante` from its `radio`, and walk to a far, still one along the streets (`campo_jugador`).

**`CAZAR`** puts a red-"!" zombie near `lugar` when you're within 70 m (`Zombis.sacar`, unalerted). Maps show a 25 m area.
- Its death by hits completes the step; `Zombie.cayo_al_amanecer` excludes the dawn fall.
- It respawns if lost.

**`ENTRAR_A`** is an arrow at `lugar`, a one-point `VISITAR`.

**`ENTRAR_A` with `escena`** enters a boss scene through `PasoJefe` (`scripts/mapa/PasoJefe.gd`: `entrar`, `volver(gano)`, flag `desde_juego`).
- `catrina.tscn` and `lombrices.tscn` check the flag. With it they return to the map on a win or a faint; without it they restart as test scenes.
- Winning completes the step (`MisionesMundo._resolver_jefe`).
- `MuroColonia` puts the player back where they entered.

**Boss entrances** are fixed `EntradaJefe` nodes (`scripts/mapa/EntradaJefe.gd`: a yellow arrow like a shop, `id`/`escena`/`nombre`, always open). Missions point to them with `lugar = "entrada:<id>"`.
- Without the matching ENTRAR_A mission, winning gives no prize, advances nothing and only marks the boss beaten (`PasoJefe.hay_premio()`, which the boss scenes check).
- A beaten boss shows a "repetir la pelea" legend and needs the interact key to re-enter.
- You reappear 4 m in front of the arrow (its +Z).

## Vehicles on streets and CAMIONETA

**`CallesRuta`** (`scripts/mapa/CallesRuta.gd`) reads the streets from `textures/map/minimapa.png`:
- `entre`/`entre_varias`: A* and Dijkstra on a 2 m grid;
- `seguir`;
- `es_calle`.

**`ConductorCarro`** (`scripts/mapa/ConductorCarro.gd`) drives any +Z-front `Node3D` along such a route (`iniciar`, `llego`, `pausa`, `parar_al_final`).

**`CAMIONETA`** (S11): `CamionetaReparto`, an `Acompanante`, drives house stops at jog speed until before dawn. Hordes come at stops and while driving (`ola_andando`).

**`lugar = "salida_colonia"`** (Santa Mugre's chofer): accepting cuts to night outside a random colony gate with the truck driving. `MuroColonia` closes the colony to `CallesRuta`.

## Tinaco defences

- **The outside tinaco defence** is an ENTRAR_A scene (`defender_tinaco`, see `scripts/defensa/CLAUDE.md`). In the big map it is offered by Chava at each of the five `SitiosTinaco` tinacos.
- **The gate event (F1)** is `evento_reja.tres`, given by nobody, so it's not in `ARCHIVOS`.
  - `Misiones.cae_la_noche` wears the gate every real nightfall and, inside Santa Mugre, rolls the failure. The `anochecio` that a scene emits on its first frame doesn't count (`MisionesMundo.NOCHE_DE_ESCENA_MS`).
  - It starts as a LUGAR mission: DEFENDER at `lugar = "tinaco_plaza"` with `acompanante = "tinaco"` (`TinacoVida`, an invisible `Acompanante` with the tinaco's radius). Hordes come from the failed gate (`Misiones.reja_falla`).
  - Losing asks "¿Otra vez?" (`PreguntaReja`, 3 retries, each easier). Without retries, `Misiones.tinaco_perdido` is set and `TinacoComunitario.quitar_virgen` runs; `Colonia` builds it without the Virgen from then on.
  - Safehouse: Shift+F10. Test: `tools/mapa/probar_evento_reja.gd`.

## The Decreto 47 papers

`lugar = "papeles_decreto"` (RECOGER ×2) places the two papers on the archive tables of the palace offices (`PalacioOficinas.papel(i)`), once `PalacioOficinas.listo`; from a Blender colony (no palace) there's no pointer. The arrow goes to the palace door (`frente_puerta()`) while you're outside the offices, and to the nearest paper inside. Forcing the door, entering and the zombies inside are `PalacioOficinas`'s (see `docs/mapa/tecnico.md`, palace). `BodegaGela` no longer belongs to this mission: it opens for a step with `lugar = "papeles_bodega"` (none yet). Test: `tools/mapa/probar_decreto.gd`.

## Mafia (M7) and police

- **The chain:** `mafia_1`..`8` chain via `MisionData.requiere`/`abierto_de_noche`.
- **Where:** `donde`/`lugar` `punto:<origen>` puts the giver and the delivery beside the door, off the store arrow.
- **The box:** `PasoMision.soltable`. Attack drops it, Space picks it up.
- **La Gotera:** 5 deliveries open it (`Misiones.favela_abierta`).
- **Police by day:** `Cuicos`/`Cuico` shoot whoever carries the box. Cuicos, `DropsRaros` and outside nights are in `docs/sistemas/noche-zombis.md`.
- **Police slang:** cuicos, cerdos, marranos (not "blancos").
- **Carrying:** `Player.cargar`/`soltar_carga` show something held, with `Walk_Carry`.
- **Tests and store arrows:** stepping onto a store's yellow arrow enters the store, so tests must stand beside it.

## Test missions and test scripts

**Test missions:** `escolta_noche`, `reparto_noche`, `antena_noche`, `caceria_noche`, `entrada_dia`, `defender_tinaco`, `camioneta_noche`.

**Headless tests** (`godot --path . --headless -s <script>`):

| Script | What it covers |
|---|---|
| `tools/mapa/probar_al_medico.gd` | clinics in both fortresses |
| `tools/mapa/probar_reparto.gd` | house deliveries outside fortresses |
| `tools/mapa/probar_evento_reja.gd` | F1 |
| `tools/mapa/probar_decreto.gd` | the Decreto 47 in the palace offices |
| `tools/mapa/probar_fortalezas.gd` | — |
| `tools/mapa/probar_palacio.gd` | — |
