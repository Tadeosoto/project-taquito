# Guadalajaja — Game Design Document

> **Note (2026-11-23):** `testing-juanjo` was merged after this snapshot (116 commits: the cañerías and tunnels, cuicos, carretilla, stamina, the cucarrata, pterodactyl and Simi bosses, the palace offices, La Gotera in Blender, mission system S1-S11...). Only the parts that touch the sandbox are updated here; the rest of this document does not describe his content yet (**needs review**).

*Snapshot of the project as implemented on branch `sandbox-sin-fin` (from `santa-mugre-fortaleza` `f635557`), 2026-11-23. Updated the same day with the team's design decisions: endless sandbox, night milestones, tazos as the only progression, starting life 60, Dark Souls death with a guarded bag, and saving.*

This document describes what the code, data files and assets actually do. The design docs in `docs/` were read too, and where they disagree with the code, **the code is reported** and the clash is flagged **needs review**. Numbers marked *(first guess)* are labelled as untuned in the code or in `docs/pruebas-balance.md`.

In-game names stay in Spanish, as they appear to the player. Legend used in tables:

| Mark | Meaning |
|---|---|
| **Done** | Implemented and reachable in normal play or the dev safehouse |
| **Partial** | Implemented in part, or only in a test scene |
| **Design** | Only in design docs; no code yet |
| **needs review** | Unclear, or the docs and the code disagree |

---

## 1. Overview

### 1.1 Concept

A third-person survival action game with a PS1 look, set in a **real 1.7 × 1.7 km piece of Zapopan, Jalisco** (from OpenStreetMap), renamed as a parody Guadalajara. The city is ordinary (it works, shops, eats tacos) except for two things:

1. **At night, zombies come out.** They are cannibals and thirst for water without Serenol.
2. **Clean water is expensive and scarce.**

Both come from **GelA**, the Lazcano family's water monopoly. Its tap water carries **Serenol**: nine in ten people become docile, one in ten dies and rises as a zombie. The tone is Tapatío absurd humour (Takis, palomas, the Simi mascot parody) over a real problem (water). Tagline on the start screen: *"No te tomes el agua."*

### 1.2 Genre and references

Survival / action, third person, open map, day-night loop. The team's stated references: *Dying Light* (quiet day, deadly night), *7 Days to Die* (growing hordes, dusk warning), *Left 4 Dead* (the pacing Director), *Resident Evil 1-4* (limited inventory), *GTA San Andreas* (yellow markers for shops and missions), *Dead Rising* (humour, improvised weapons), *Kingdom Hearts* (skill points and synthesis), *Silent Hill 2* (inventory menu mood, the secret boss room).

### 1.3 Core loop

```
DAY ──► take missions ──► gather items / money ──► buy in shops / craft
 ▲                                                         │
 │                                                         ▼
DAWN ◄── survive ◄── use weapons and consumables ◄── NIGHT: zombies
```

What exists today:

- **Day:** walk the map, take one of 8 day missions, shop in 12 store types, play fruit machines, craft at El Yonke, open Takis tazo bags.
- **Night:** shops close and kick you out; the Director spawns loose zombies and hunter mobs; zombies drop pesos and crafting materials. At 0 life you faint, drop your items in a bag that a leader zombie carries at night, and wake at the respawn point.
- **Structure: endless sandbox** (team decision, 2026-11-23). The game never ends. An endless night counter shows *"Sobreviviste la noche N"* at each dawn and keeps a best record. Hordes grow each night and milestones add the garrafonero (3), more Saltabardas and hunters (5), the Panzón (7), La Madre del Cárcamo (10) and La Mojiganga (15); after that the bosses repeat, stronger. Each milestone gives a holo tazo. Everything is saved to disk (§8.5).

### 1.4 Tech stack

| Item | Value |
|---|---|
| Engine | Godot 4.7, Forward Plus renderer, Jolt Physics |
| Language | GDScript only; no build system, linter or test suite |
| Render | 640 × 480 internal resolution, `viewport` stretch, nearest filtering; `--alta` flag gives crisp 1080p UI with the 3D still at 480 px (`ModoAlta.gd`) |
| PS1 look | Dither post-process, vertex snapping (characters and props only), affine UVs (`shaders/ps1_combined.gdshader`) |
| Map pipeline | OpenStreetMap + OSM2World + Google Open Buildings (Python and Godot tools in `tools/map_import/`); a second, hand-built colonia map in Blender (`tools/blender/mapa/`) |
| Characters | PSX civilian pack, retargeted to `SkeletonProfileHumanoid`; Quaternius UAL1/UAL2 animation clips (CC0) |
| Effects | pixelfx sprite sheets (MIT) on billboards, plus 3D liquid and gib systems |
| Data | Items, missions, tazos, recipes and zombie tuning are `.tres` Resources in `resources/` |
| Autoloads | `Inventory`, `Cartera`, `Salud`, `PiezasMapa`, `Misiones`, `Personaje`, `Tazos`, `Tiliches`, `Taller`, `Bonos`, `Libreta`, `Baul`, `Fichas`, `Pruebas`, `Mejoras`, `Registro`, `Noches`, `Guardado`, `ModoAlta` |
| UI language | Informal Mexican Spanish |
| Repo history | 439 commits, 2026-10-11 to 2026-11-19; team of 4 (JJ, AG, Alan, one more) |

---

## 2. World and locations

### 2.1 Scenes (levels)

| Scene | What it is | How you reach it | Status |
|---|---|---|---|
| `scenes/inicio.tscn` | Start screen: a small night scene built in code, menu *Jugar / Menú test / Pruebas / Controles / Créditos / Salir* | Main scene | Done |
| `scenes/map_test.tscn` | **The real map**: ~1.7 × 1.7 km of Zapopan, streamed in chunks, ~7,900 buildings, shops, day/night, zombies, missions | *Jugar* → character creator → loading screen | Done |
| `scenes/mapa.tscn` | **Parques de Santa Mugre** fortress, built by hand in Blender: walls, gates, plaza with the tinaco, tianguis, school, temple, neighbours' houses | Yellow arrows at the two avenue gates of Santa Mugre (`PasoColonia`); time of day carries over | Partial (pilot colonia) |
| `scenes/casa_personaje.tscn` | The protagonist's own house, walked as the real player with combat off: bed, closet, trophy case, album, libreta, TV, chest, altar | Yellow arrow at the first Urbi house | Done |
| `scenes/casas/*.tscn` | Neighbours' houses in Santa Mugre: `guero`, `sofia`, `tono`, `clausurada`, `templo` (with the well room), `sotano` | `casa_vecino` markers in `mapa.tscn` | Partial |
| `scenes/casas/sotano.tscn` | **El Sótano**, the Gotera's underground casino; secret drain arena below | Door by the Mini Super on the tianguis street, open at night; $300 fee or Gotera permission | Done (permission missions missing) |
| `scenes/interiores/*.tscn` | 13 fixed first-person shop scenes (see §6.3) | Yellow arrow at each store door | Done |
| `scenes/safehouse.tscn` | Dev yard, 100 m, with one of every system and key pages (F1) | Run by path; F10 jumps to `map_test` | Done (dev only) |
| `scenes/defensa_tinaco.tscn` | Tinaco defence: barricade, hordes, chained nights; godmode test | *Menú test* / *Pruebas*, or by path | Partial (test) |
| `scenes/escena_carrera.tscn` | Career/economy test: mini refuge, all shops, upgrades shop | *Menú test* / *Pruebas* | Partial (test) |
| `scenes/lombrices.tscn` | Boss arena: La Madre del Cárcamo (worm swarm) | By path or Shift+L in the safehouse | Partial: ends with `quit()`, no return |
| `scenes/catrina.tscn` | Boss arena: La Mojiganga (parade catrina) | By path or Shift+X in the safehouse | Partial: ends with `quit()`, no return |
| `scenes/world.tscn` | Old prototype (ninja, two NPCs) | By path only | Legacy |
| `scenes/sotano_prueba.tscn`, `locales_preview.tscn`, `tianguis_borrador.tscn`, `santa_mugre_psm.tscn` | Test and preview scenes | By path | Dev only |

**Needs review:** the lore says the player *starts* in the Santa Mugre fortress, but *Jugar* loads `map_test.tscn`, starting in front of a pharmacy outside the walls.

### 2.2 The nine zones

The map is divided into nine parody-named zones (`scripts/map/ZonasMapa.gd`). Entering one shows its name; the paper map has one piece per zone. The **deterioration index** (`Deterioro.zona(x, z)`) both paints the ruin on houses and streets and scales how many zombies spawn: in the lore they are the same thing (poverty).

| Zone | Real colonia it parodies | Deterioration (lore) | Water | At night |
|---|---|---|---|---|
| El Mante Tieso | El Mante / La Gigantera | 0.45-0.60 | Tap | Warehouse shifts, loose zombies |
| Los Garrafones | Invented | 0.30-0.40 | The old tinaco chapel (moved away) | Zombies, *blancos* (police), pilgrims |
| La Florida Marchita | La Florida | 0.35-0.50 | Half-paid subscription | Quiet, but not quite |
| La Palmada | La Palmada | 0.40-0.55 | Chava's well | Medium, clean-water pockets |
| Parques de Santa Mugre | Parques de Santa María | 0.55-0.70 | Temple well and plaza tinaco | Safe inside the wall; deadly outside |
| Parques del Mosco | Parques del Bosque | 0.60-0.75 | The worst | The worst |
| Haciendas de San Jodido | Haciendas de San José | 0.20-0.30 | Well and subscription | Safe for them |
| El Último Trago | Invented (the cantinas) | 0.50-0.65 | Expensive jugs | The night market |
| La Gotera | Invented | 0.70-0.80 | Their own aquifer | Fortress: no entry without permission |

Zone 0.45+ counts as "taken" for zombie spawning (`Zombis.maximo()`).

### 2.3 Fortresses

| Fortress | Where | In the game | Entry / unlock |
|---|---|---|---|
| **Santa Mugre** (Virgen del Tinaco) | Parques de Santa Mugre | **Built** in `mapa.tscn`: 4.5 m wall (32 sections), two gates with guard posts, eight lookouts, street altars, the school (ex-palace), temple with the well room, plaza tinaco on the kiosk, night vigil, dusk procession. No spontaneous zombies inside (`Zombis.espontaneos` off) | Two gates on the avenue: west (-420, ~455) and east (-185, ~473) in `map_test` coordinates |
| **La Gotera** (the mafia) | South-east, walled favela | Design only (plan block F4). Their casino, El Sótano, is built under Santa Mugre | Gotera missions raise a trust step (4 steps); none implemented. *needs review:* step names and count are 💡 proposals |
| **Los Reservorios** (GelA) | Behind Haciendas, on the ITESO football pitches | Design only (plan block F5) | Hired as a guard (mission A4 / M10) |

### 2.4 Places inside Santa Mugre (`mapa.tscn`)

| Place | What's there | Status |
|---|---|---|
| Plaza de Santo Toribio | Tinaco on top of the kiosk, water queue, six walkways with low parapets and `Barricada_0..5` marks for the gate-failure defence | Done (defence not wired, block F1) |
| Parroquia / Templo | Enterable by day: nave, Virgen del Tinaco, padre Chuy (talks, never admits what he suspects); behind the altarpiece, the well room | Done (no missions or water yet) |
| Escuela Primaria Santa Mugre | Ex-palace; plaque, bell, recess with five kids and a ball | Done (name pending vote) |
| Tianguis | Coloured stalls, chile sack for a mission | Done |
| Player's vecindad | Long patio with laundry and stairs | Done (exterior) |
| El Yonke de Don Chava | Crafting workshop (La Chava); closed at night | Done |
| Casa del Güero | Neighbour, gives a mission in the afternoon (design); dialogue lines | Partial |
| Taller de Sofía | Pirate radio; night contact | Partial (lines only) |
| Casa clausurada | Lootable once; refills every 7 nights (first guess) | Partial |
| Casa de Toño | Trader (materials for items) | Partial (lines only) |
| Abarrotes Doña Mary | Enterable shop | Done |
| El Sótano | Casino (see §8.10) | Done |
| Stores | Oxxo, taquería, two abarrotes, pharmacy, ferretería, invented licorería, purificadora and *el punto* | Done |

### 2.5 How locations connect

```
inicio ──Jugar / Partida nueva──► creator ──► map_test (outside) ◄──gates (PasoColonia)──► mapa (Santa Mugre)
inicio ──Continuar──► saved scene and spot          │                                     │
                     yellow arrows: shops, own house             casa_vecino markers: temple,
                     F10 from safehouse                          neighbours, El Sótano ──► drain arena
                     Juanjo's boss entrances (EntradaJefe, PasoJefe): cañerías ──► tuneles ──► lombrices; panteón ──► catrina
inicio ──Menú test / Pruebas──► defensa_tinaco, escena_carrera, map_test
safehouse (by path) ── Shift+L / Shift+X ──► bosses in the yard
```

Inventory, money, life and the night count persist across scene changes (they are autoloads; the night lives in `Noches`). Clock and zombies are per-scene nodes; the gates and arena trips pass the time of day along, and a scene that starts at night continues the same night instead of counting a new one.

### 2.6 Unlock conditions

| What | Condition | Status |
|---|---|---|
| Shops, stalls, fruit machines | Open by day only; closed and you are kicked out at nightfall (shutters come down over 8 s) | Done |
| El Sótano | Night only; $300 one-time fee (`Fichas.CUOTA`) or Gotera permission (`permiso = 1`). VIP room: $500 (`CUOTA_VIP`) | Done (permission source missing) |
| La Desaguadora (secret boss) | Knock three times on the closed bathroom stall in El Sótano | Done |
| Paper-map pieces | Start with your zone; find the rest in front of a store in each zone; one from the *Buscar al perro* mission | Done |
| Crafting recipe sets 2-5 | 3, 9, 15, 21 distinct items crafted | Done |
| Crafting set 6 | All previous recipes plus that weapon's blueprint (two in obra-negra houses, one from the boss) | Done |
| Collecting crafting materials | Requires the *cangurera* (reward of mission *La cangurera del tianguis*) | Done |
| La Gotera, Los Reservorios | Mafia missions / guard job | Design |
| La Madre del Cárcamo's arena | Night 10 onward, at night: yellow arrow (needs review: placed at the south lot, (-300, 630)) | Done |
| La Mojiganga's plaza | Night 15 onward, at night: yellow arrow (needs review: placed at the big court, (-244, -721)) | Done |
| Tajo cargado / Giro en el aire | Holo tazos *El Jefe* / *Luna roja* (milestone rewards on nights 3 and 7) | Done |

---

## 3. Player

### 3.1 Character creation

`Personaje` autoload, saved in `user://personaje.cfg` and kept across new games. Five protagonists: **Genaro** (the plain `el_compa` model), **Homero**, **Ramón**, **Emiliano**, **Felipe**, each with skin tone, build, height, head and clothes; some wear hats (fisherman's hat, charro sombrero). Each protagonist has a swing-trail style (water for el compa, monarch butterflies for Homero).

**Rule that crosses systems:** skin tone only changes how the *world* treats you (prices, mission pay, lines). Combat, zombie drops and fruit machines never read it. *needs review:* no price or line currently reads skin tone either; the rule is a constraint, not a feature yet.

### 3.2 Base stats

| Stat | Value | Source |
|---|---|---|
| Life | 100 max; **starts at 60** (team decision 2026-11-23); test scenes start full | `Salud.gd` (`vida_max = 100`, `VIDA_INICIO = 60`) |
| Walk speed | 5 m/s (10 in `map_test`) | `player.gd` `speed`; `map_test.tscn` override |
| Sprint speed | 9 m/s (18 in `map_test`) | `sprint_speed` |
| Jump velocity / gravity | 13 / 40 | `jump_velocity`, `gravity` |
| Invulnerability after a hit | 0.7 s | `INVULNERABLE` |
| Inventory slots | 6 (backpacks: 8, 10, 14) | `Inventory.CAPACIDAD_BASE` |
| Starting money | $120 and 3 *agua* | `Cartera.PESOS_INICIO`, `AGUA_INICIO` |
| Wake-up life after fainting | 50 | `Supervivencia.VIDA_AL_DESPERTAR` |
| Life states | Bien (> 60 %), Herido (> 25 %), Grave | `Salud.estado()` |

**needs review:** you wake from a faint with 50, less than the 60 you start with. The second currency *agua* stays for now (team decision) but has no source in the game (§6.1).

### 3.3 Progression and leveling

There is **no XP or character level**. **Tazos are the only progression system** (team decision, 2026-11-23). Everything below is saved with the game; only *Partida nueva* resets it.

| System | What it gives | Currency | Kept on Partida nueva? | Status |
|---|---|---|---|---|
| **Tazos → skills** (§4.2) | 16 skills, 44 points total, including the charged slash and the aerial spin | Points from *new* tazos | No | Done |
| **Weapons and gear** | Better melee damage, guns, backpacks, amulets | Pesos, crafting | No | Done |
| **Crafting rank** (§6.6) | Unlocks recipe sets 2-6 | Distinct items crafted | **Yes** (rank, blueprints, trophies) | Done (AG proposal, not voted) |
| **Upgrade shop** (`Mejoras`, §4.3) | Moves, stats, one-night buffs | Pesos | — | **Test scenes only** (career test); not in the game |
| **Libreta** (bestiary) | Lore and combat tips per enemy | Seeing / fighting / killing | **Yes** | Done |

The charged slash and the aerial spin are learned through the tazo skills *Tajo cargado* and *Giro en el aire* (`Partida._aplicar_habilidades` sets `Player.golpe_cargado` / `giro_aereo`; JJ's attack code is unchanged). The safehouse still turns them on with keys 7/6. Roll and block are always available.

### 3.4 Controls

| Action | Keyboard / mouse | Gamepad | Input action |
|---|---|---|---|
| Move | WASD / arrows | Left stick | `move_*` |
| Camera | Mouse | Right stick | `camera_*` |
| Jump / interact (talk, pick up, enter) | Space | A (0) | `jump` |
| Sprint | Shift | RT (7) | `sprint` |
| Attack / shoot | Left click, F | X (2) | `attack` |
| Block (melee) / aim (gun) | Right click | LT | `bloquear`, `apuntar` |
| Roll | Alt, or double-tap a WASD key within 0.25 s | B (1) | `rodar` |
| Heal (eat best healing item) | Q | D-pad up | `curarse` |
| Reload | R | — | `recargar` |
| Melee weapon / gun / throwables | 1 / 2 (again: next gun) / 3 (again: salt ↔ Molotov) | RB cycles | `arma_1..5`, `cambiar_arma` |
| Look back | Middle mouse, mouse 8 | R3 | `mirar_atras` |
| Inventory (pauses the game) | Tab | Start (6) | `inventory_toggle` |
| Paper map | M | Select (4) | `inventory_map` |
| Skills page | H (inventory open) | Y (3) | `inventory_skills` |
| Tazo album | T (inventory open) | LB (9) | `inventory_album` |
| Tiliches (materials) | B (inventory open) | RB (10) | `inventory_tiliches` |
| Libreta (bestiary) | L (inventory open) | R3 (8) | `inventory_guide` |
| Inventory navigation | Q/E, arrows, Enter, Esc | D-pad, A, B | `inventory_*` |
| Drone camera toggle | V | — | (code, `MapDron`) |
| Skip to next dusk/dawn | N | — | (debug, `Ciclo`) |
| Leave a shop | S or Esc | — | (code, `Interiores`) |

**needs review:** Q and E are bound to both gameplay (`curarse`) and inventory navigation; this only works because the open inventory pauses the tree. Some key/button pairs overlap (RB is both `cambiar_arma` and `inventory_tiliches`; R3 is both `mirar_atras` per the docs and `inventory_guide`).

---

## 4. Abilities and skills

### 4.1 Combat moves

Damage is the best weapon damage you carry (no equipping needed; *Equipar* in the inventory overrides it), × the damage factor from skills, amulets and buffs.

| Move | Input | Damage | Targets / reach | Timing / cooldown | Unlock |
|---|---|---|---|---|---|
| Machete combo A / B | Attack, repeated | Weapon (machete 12, reinforced 18) | Nearest zombie in a front cone, 2.4 m | Next swing from 0.30-0.33 s; cooldown 0.6 s; combo window 0.5 s | Always |
| Punches (jab, cross, hook) | Attack, unarmed | 5, 5, 8 (hook ×1.6) | Same cone | Same | Always |
| **Charged attack = heavy slash** (*tajo*) | Hold attack ≥ 0.12 s, charge 0.4 s, release | Weapon × 2.5 (machete: 30, kills a normal zombie) | Up to 4, 2.4 m ahead; steps 1.8 m forward | Lasts 0.85 s; cancellable from 0.6 s | Tazo skill *Tajo cargado* |
| Aerial spin | Attack in the air | Weapon × 1.5 | Up to 6, all round, reach × 1.3 | 0.95 s | Tazo skill *Giro en el aire* |
| Air thrust (dive) | Attack in the air while sprinting | Weapon × 1.5 | Up to 6, 2 m ahead; 5 m dive | ~0.8 s | With the charged attack |
| Block | Right click (melee) | Take 25 % of a frontal hit | Front half; slides you 0.06 m per damage point (0.2-1.5 m) | Walk at 40 % in guard; 0.3 s invulnerable after a parry | Always |
| Roll | Alt / double-tap | — | 3 m forward; invulnerable ~0.3 s | 0.4 s before the next roll | Always |
| Heal | Q | Item's healing × factors | — | Locks you 1.2 s (drink clip) | Always |
| Timed hit | Hit a zombie during its 0.3 s growl tell | Normal; would stun if `Zombie.ATURDIR` were on (it is off) | — | — | Toggle (safehouse key 9) |

**needs review:** `docs/mejoras.md` §2.1 still describes the charged attack as a thrust (×1.5, up to 6). In the code the thrust became the air dive and the charged attack is the ×2.5 heavy slash.

### 4.2 Tazo skills (`scripts/Habilidades.gd`)

Points come only from **new** tazos (rare 1, holo 2, every **2** new commons 1; was 3 before 2026-11-23). The 48 tazos give exactly 44 points, which is exactly the cost of the whole tree. Levels can be refunded at any time. Six skills are locked until you own a specific tazo.

| Skill | Category | Effect per level | Levels | Cost per level | Unlocked by |
|---|---|---|---|---|---|
| Aguante | Cuerpo | +10 % max life | 3 | 1, 1, 2 | — |
| Fuerza | Cuerpo | +10 % damage | 3 | 1, 1, 2 | — |
| Patas | Cuerpo | +10 % walk/run speed | 3 | 1, 1, 2 | — |
| Brazo largo | Cuerpo | +10 % melee reach | 3 | 1, 1, 1 | — |
| Tajo cargado | Cuerpo | Enables the heavy slash (§4.1) | 1 | 2 *(first guess)* | Tazo *El Jefe* (holo; night 3 reward) |
| Giro en el aire | Cuerpo | Enables the aerial spin (§4.1) | 1 | 2 *(first guess)* | Tazo *Luna roja* (holo; night 7 reward) |
| Segundo aire | Sobrevivir | Once per night, rise with 30 % life instead of fainting | 1 | 3 | Tazo *Virgen del Tinaco* (holo) |
| Buen diente | Sobrevivir | +25 % healing from food and medicine | 2 | 1, 1 | — |
| Piel dura | Sobrevivir | −15 % zombie damage at night | 2 | 1, 2 | — |
| Pies de gato | Sobrevivir | Zombies notice you later (chase radius × 0.85/level) and spawn 3 m/level further away; not hunters or bosses | 2 | 1, 2 | Tazo *Gato negro* (rare) |
| Bolsillos | Negocio | +1 peso per zombie | 2 | 1, 1 | — |
| Regateo | Negocio | −10 % prices in pesos | 2 | 1, 2 | — |
| Mochilero | Negocio | +1 inventory slot | 2 | 1, 2 | — |
| Buena racha | Negocio | Special bag chance on Takis: 1/8 → 1/6 → 1/4 | 2 | 1, 1 | — |
| Imán | Negocio | Loose items within 2.5 m fly to you | 1 | 2 | Tazo *Tinaco* (rare) |
| Ojo de halcón | Negocio | Zombies shown on the minimap | 1 | 2 | Tazo *Búho* (rare) |

Total: 44 points (`docs/mejoras.md` used to say "~58"; corrected).

### 4.3 Upgrade shop catalogue (`scripts/Mejoras.gd`, career test only)

Bought with pesos at the *punto* upgrades shop in `escena_carrera.tscn`. Godmode sets everything to max. Outside the tests the factors are off. **Kept only for test scenes** (team decision 2026-11-23): the game's progression is tazos.

| Upgrade | Type | Effect | Levels | Cost (pesos) |
|---|---|---|---|---|
| Golpe cargado | Move | Enables the heavy slash | 1 | 250 |
| Golpe giratorio | Move | Enables the aerial spin | 1 | 300 |
| Estela del protagonista | Move | Character trail and +10 % damage | 1 | 400 |
| Aguante | Stat | +10 % max life | 3 | 100 / 180 / 280 |
| Fuerza | Stat | +10 % damage | 3 | 120 / 200 / 300 |
| Patas | Stat | +10 % speed | 3 | 100 / 180 / 280 |
| Brazo largo | Stat | +10 % reach | 3 | 90 / 160 / 240 |
| Piel dura | Stat | −15 % damage taken | 2 | 150 / 260 |
| Buen diente | Stat | +25 % healing | 2 | 80 / 150 |
| Taco de pastor especial | Buff (one night) | +20 % damage | 1 | 90 |
| Café de olla | Buff (one night) | +20 % speed | 1 | 70 |
| Té de tejuino | Buff (one night) | −20 % damage taken | 1 | 110 |

These duplicate the tazo skills under the same names; that is fine now that the shop is a test tool only.

### 4.4 Firearms (`scripts/Pistola.gd`, `Pistola.ARMAS`)

All share the gun slot (key 2). Headshots (ray hit ≥ 1.4 m × zombie size) do ×3. Aim assist: the nearest visible zombie within 2.5° of the crosshair. Ammo is endless; only the magazine limits fire. Shots alert zombies within 40 m.

| Gun | Damage | Pellets | Fire interval | Magazine | Reload | Range | Spread (hip / aim, rad) | Special | Price | How obtained |
|---|---|---|---|---|---|---|---|---|---|---|
| Pistola (MK23) | 8 | 1 | 0.22 s | 12 | 1.5 s (auto when empty) | 60 m | 0.012 / 0.004 | None | — | Always carried (not an inventory item) |
| La Tinaquera (shotgun) | 6 | 8 | 0.85 s | 6 | 2.2 s, shell by shell (0.4 s each) | 22 m | 0.06 / 0.04 | Within 7 m: pushes 7 m/s, stuns, 35 % head pop on kill | $900 | Not sold anywhere yet (illegal market, plan S7) |
| La Matraca (LMG) | 7 | 1 | 0.09 s, auto | 100 | 3.5 s | 70 m | 0.03 / 0.016 | Spin-up 0.35 s; overheats; walk ×0.75, no sprint while firing, no roll; slows zombies ×0.6 for 350 ms | $2500 | Same |
| La Chicharra (SMG) | 4 | 1 | 0.07 s, auto | 30 | 1.6 s | 40 m | 0.028 × 1.8 hip / 0.012 | Slows zombies ×0.75 for 250 ms | $1200 | Same |

Camera: Fortnite-style over the right shoulder with a gun; aiming zooms to 45° FOV and slows walking to 50 %. Recoil climbs and must be pulled down; the crosshair spreads with the Director's tension ("nerves"). **needs review:** aim scheme (shoulder aim vs lock-on) is still an open vote; the shoulder camera is JJ's test.

### 4.5 Throwables (key 3, `Lanzador`)

| Item | Effect | Use | Price / source |
|---|---|---|---|
| Bolsa de sal (10 handfuls) | A heavy sweeping throw: kills every worm in a 3.3 m, ±75° arc; burns latched worms | Click per handful | $25, tiendita |
| Molotov de limón | Fire area 2 m for 5 s; burns zombies (3 damage every 0.5 s for 3 s), kills worms and the Madre's sacs; hurts you too | Hold to move the landing point 3→16 m over 1.2 s, release | Craft: gasoline bottle + trapo |
| Molotov de cereza | As above, 1.5 × the reach (3 m fire) | Same | Craft: cherry gasoline + trapo |
| Palomita (paper firework) | Bang that stuns zombies nearby; can stun you if it goes off in your hand | Throw | No shop (safehouse only) — *needs review* |
| Bocina bluetooth | Decoy: pulls nearby zombies for a few seconds | Throw | $150, abarrotes |
| Bocina encintada | Louder decoy that pulls zombies from far while it plays | Throw | Craft: bocina + botella de agua |

### 4.6 Consumable effects

| Item | Heal | Other effect | Status |
|---|---|---|---|
| Gansito, Mazapán | 10 | — | Done |
| Kilo de tortillas | 15 | Stacks | Done |
| Caguama, Jarritos | 25 | Leave an empty bottle (for Molotovs). Caguama "dizziness" | Heal done; dizziness *not implemented* |
| Tacos al pastor | 30 | — | Done |
| Caldo de pollo (craft) | 60 | — | Done |
| Suero oral (craft) | 40 | — | Done |
| Botiquín del Simi | 70 | — | Done |
| Vaporub | 100 | — | Done |
| Remedio de la abuela, Té de la Virgen (craft) | Full | — | Done |
| Milagro del tinaco (craft) | Full | Recharges Segundo aire | Done |
| Takis Fuego | — | "+damage for 30 s" | **Not implemented** (text only); buying Takis rolls the tazo bag |
| Tachas | — | "Speed and endless stamina 20 s, then a crash" | **Not implemented**; there is no stamina stat |
| Cigarros | — | "Smoke hides you from zombies' smell" | **Not implemented** |
| Galón de agua | — | "Baja la infección" (lowers thirst) | **Not implemented**: no thirst stat; used in missions |

---

## 5. Monsters and enemies

### 5.1 Common zombies (`scripts/map/Zombie.gd`, `resources/zombis/`)

| Enemy | Life | Speed | Damage | Behaviour | Where | Drops |
|---|---|---|---|---|---|---|
| **Zombi** (normal) | 30 | 3-5 m/s alerted; wanders at 0.8 m/s | 12 (6 in the tinaco defence) | Wanders until it sees you (25 m, 120° cone, line of sight), hears you (12 m), hears a shot (40 m) or is hit; alerts others within 8 m; follows street flow fields, surrounds, queues at gaps. Attack range 1.5 m, hit lands at 0.65 s, 1.5 s cycle | Everywhere at night outside fortresses; more where deterioration is high | $1-3 (+Bolsillos, ×amulets) + materials (§6.2) |
| **Cazador** (hunter / mob member) | 30 | × 1.4 (sprints) | 12 | Always alerted, always hunts the player; arrives in tight mobs of 7-8 | Map mobs (1-2 per night); defence ambushes (2-3) and "runner" fractions | Better materials (good 50 %, fine 8 %); trophies |
| **Zombi de GelA** (variant) | 30 (× 1.0) | Normal | 12 | Light GelA uniform tint | Night | Polvo de Serenol; *Casco de GelA* trophy |
| **Zombi de cobalto** (variant) | 45 (× 1.5) | Normal | 12 | Glows | Zones with obra-negra houses | *Cobalto* trophy |
| **Zombi gordo** (`Tipo.GORDO`) | 30 (placeholder = normal) | Normal | 12 | Separate type; attacks undefined | **Not spawned** | — |
| **Líder de la bolsa** (`Zombie.lider`) | 90 (× 3) *(first guess)* | Normal | 12 | Size × 1.2; carries your death bag on his back (backpack on the `Chest` bone); wanders within 4 m of the bag spot; every 8-12 s, if calm, plays the Drink clip and destroys one water item from your bag; drops the bag when killed | Night, where you fainted (not inside Santa Mugre) | Your bag + normal loot | Done |
| **Guardias de la bolsa** (`Zombie.guardia`) | 30 | Normal | 12 | 3-5 (more in ruined zones, +1 per 5 nights) plus a hunter from night 6; spawn within 45 m, give up past 15 m from the bag, leave past 70 m (kills are remembered) | Same | Normal loot | Done |

Skins: random from the PSX zombie and four PSX-pack monsters, heights ±6 %. Hit feel: white flash, whack, dirty-water spray, freeze frames, swelling and bursting on death, gibs that rot to a skeleton (≤ 16), headshot kills pop the head. All zombies collapse at dawn. Zombies do **not** attack people carrying Serenol (lore; *not modelled*: there are no outside NPCs at night).

**needs review:** the spec says each zombie has a trade (*oficio*: obrero, taquero, repartidor...) that sets its loot and pays 5-60 pesos; the code pays 1-3 and has no trades.

### 5.2 Special zombies

| Enemy | Life | Damage | Behaviour | Where | Drops | Status |
|---|---|---|---|---|---|---|
| **El Saltabardas** | 40 | Leap 10, claw 8 | Stalks on all fours, shrieks, leaps on a ballistic arc and pins you; mash attack/jump (7 presses, decaying) to throw it off. Roll dodges the leap, a frontal block parries, a hit in the air knocks it down | One at a time at night (`Zombis`, first after a delay, then periodically); from night 5 the wait is × 0.6 *(first guess)* | As a hunter | Done (AG proposal, not voted) |
| **El Panzón** | 400 | Slam 20; charge combo 10 + 3 × 8, thrown ~6 m; rock 25 (30 to the tinaco) | Slams within 2.2 m; at 6-14 m roars and charges at 8 m/s (dazed 3 s and ×2 damage if it hits a wall); past 14 m rips and throws a slab; targets the tinaco if you are > 25 m away | Defence hordes from 24:00 (35 % chance on *medio*, 60 % *difícil*); map mobs from night 7 (35 % per mob, *first guess*); Shift+J in the safehouse | 3 hunter loot rolls + $15-30 | Partial (AG proposal for the gordo; JJ hasn't confirmed) |

### 5.3 Bosses

| Boss | Life | Attacks (damage) | Phases / mechanics | Where | Rewards | Status |
|---|---|---|---|---|---|---|
| **El garrafonero** (`Zombie.es_jefe`) | 400 (× 1.25 per boss round after night 15) | Hit 25; pushes you twice as far; 8 to enclosures | Size × 1.7, speed 3, blue-tinted gordo model, never stunned; stomps announce it | Night 3 and its repeats (18, 27...), spawns near the player; no longer holds the night: collapses at dawn if alive | *Diente del jefe* trophy + first missing blueprint; loot × 2 | Done |
| **La Madre del Cárcamo** + crías | 6 sacs × 70 (sacs only hittable when exposed; damage ÷ `aguante` on repeats) | Crash 16, bite 26, tower 16 (2.6 m); worms: bite 9, touch 3, latch drains 4/s | Phase per 2 sacs: burrows and whips, then towers; worm swarm of 80 × 12 Verlet dots that climb walls, leap, roll into a ball (40 life); salt and fire kill worms | `lombrices.tscn`, reached by a night arrow from night 10; win or faint returns to the map | $400, a holo tazo, *Diente de la Madre* | Done (AG proposal) |
| **La Mojiganga** (parade catrina) | 1000 (phase 2 at 670, phase 3 at 340; frenzy < 150; damage ÷ `aguante` on repeats) | Stomp 26, shockwave 8, grab-squeeze 6, sweep 24, slap 26, braid 13, scream 10, thrown 8 (20 into a wall) | Dark Souls-style: combos, feints, grab (mash 6 to escape), phase 2 calls 3-5 zombies (max 8); flowers 4 × 70 take bullets only when exposed; machete × 1.25 to cardboard | `catrina.tscn`, reached by a night arrow from night 15 ("the parade"); win or faint returns to the map | *Corona de cempasúchil* (amulet: 25 % of kills drop healing petals, +4), *Fémur de la Mojiganga* (weapon, 22) | Done (AG proposal; a real street parade is not built) |
| **La Desaguadora** (secret) | 1800 | Claw 35, puddle 22, hair 28, drop 14, scream 18, back attack 22; drain water 4 | Silent Hill 2-style drain room with volumetric fog that reddens per phase; you cannot faint here (rescued to the bathroom with 30 life); sinks and resurfaces beside you if you run | Below El Sótano's bathroom | 300 chips + *Varilla del desagüe* (weapon, 24), once per saved game | Done |

**needs review:** `docs/pruebas-balance.md` calls all boss numbers first guesses; the Mojiganga is not yet beatable with the machete alone in bot runs.

### 5.4 Spawning (`Zombis.gd`, `Director.gd`, `RitmoNoche.gd`)

Pool of 30 pre-built zombies (40 in the defence). They spawn 24-36 m away, off camera, on the street, and despawn beyond 70 m.

**Map night rhythm** (`resources/zombis/noche_mapa.tres`, used by `map_test` and the safehouse):

| Parameter | Value |
|---|---|
| Quiet start | 25 s |
| Loose groups | 1-2 zombies every 35-55 s (intact blocks) to 15-25 s (ruined blocks) |
| Loose alive at once | 2 (intact) to 4 (ruined) |
| Growth per night | +15 % frequency; mob size and loose-alive cap × 1.15^(night−1) *(first guess)*, capped by the 30-zombie pool |
| Mobs per night | 1-2, of 7-8 hunters (grows per night), between 15 % and 80 % of the night, ≥ 70 m apart |
| Director | Tracks tension; pauses loose spawns during its rest phase |
| Saltabardas | One at a time; × 0.6 wait from night 5 |
| Hunters in loose groups | 25 % of groups from night 5 *(first guess)* |
| Panzón with a mob | 35 % from night 7 *(first guess)* |

**Night milestones** (`resources/noches/hitos.tres`, `Noches` autoload; every number is a first guess and tunable without code):

| Night | Event | Holo tazo reward (on surviving it) |
|---|---|---|
| 3 | El garrafonero | El Jefe (unlocks Tajo cargado) |
| 5 | Saltabardas more often, hunter groups | a missing holo |
| 7 | Panzón joins mobs | Luna roja (unlocks Giro en el aire) |
| 10 | La Madre del Cárcamo huntable (arena arrow) | a missing holo |
| 15 | La Mojiganga's parade (arena arrow) | a missing holo |
| 18, 21, 24... | Boss repeats in turn every 3 nights, × 1.25 toughness per round | — |

Target: ~30 zombies in a 6-minute map night (JJ wants nights where objectives are possible, not constant killing).

**Tinaco defence hordes** (`scripts/defensa/Hordas.gd`, 22:00 to 06:00, night of 210 s):

| Hour | 22:00 | 23:00 | 24:00 | 00:48 | 02:00 | 03:00 | 04:00 | 05:00 |
|---|---|---|---|---|---|---|---|---|
| Group size (fácil) | 3 | 4 | 7 | 5 | 6 | 7 | 6 | 7 |
| Group size (medio/difícil) | 3 | 4 | 7 | 5 | 6 | 7 | 7 | 9 |
| Runner fraction | 0 | 0 | 0 | 0.1 | 0.1 | 0.4 | 0.15 | 0.2 |

| Mode | Difficulty × | Ambushes (2-3 hunters every 35-60 s from 23:00) | Panzón chance | Cap |
|---|---|---|---|---|
| fácil | 1.0 | No | 0 | Yes |
| medio (default) | 1.25 | Yes | 35 % | No |
| difícil | 1.6 | Yes | 60 % | No |

Chained nights multiply difficulty by 1.25 per night; zombie damage +1 per night up to 12. About 80 zombies per defence night.

---

## 6. Items, rewards and economy

### 6.1 Currencies

| Currency | Start | Earned from | Spent on | Notes |
|---|---|---|---|---|
| **Pesos** | $120 | Zombies ($1-3), missions ($45-100), tinaco defence ($150), Madre ($400), fruit machines, cashing out chips | Shops, crafting, casino fee, upgrades (career) | The design's only currency |
| *Agua* | 3 (`Cartera.AGUA_INICIO`) | **Nothing** | Machete and Vaporub (`moneda = 1`, 2 *agua* each, `Interior._comprar`); shown in `TiendaUI` | Kept as a second currency for now (team decision 2026-11-23). **needs review: needs a real source** |
| **Fichas** (casino chips) | 0 | Buying at the Primo's window; La Desaguadora (300) | El Sótano games | 10 % commission when cashing out (`Fichas.COMISION`); saved with the game |
| **Tazo points** | 0 | New tazos, milestone holos | Skills | 44 total |
| **Tiliches** (materials) | 0 | Zombies, scrap piles, obra-negra piles, el punto | Crafting | Need the cangurera; saved with the game |

Reference income (from `docs/mejoras.md`): a good map night plus one mission ≈ $150-200; with the tinaco defence ≈ $300.

### 6.2 Loot tables

**Zombie kill** (`Materiales.botin`, `Zombie._morir`), rolled independently:

| Roll | Normal zombie | Hunter / boss |
|---|---|---|
| Pesos | 1-3 coins (+1/level Bolsillos; × amulet pesos bonus) | Same (boss: loot × 2) |
| One *suelto* (tier 1) material of a random family | 70 % | 70 % |
| One *bueno* (tier 2) | 8 % + 12 % at night + 20 % × zone deterioration | 50 % |
| One *fino* (tier 3) | 2 % | 8 % |
| Varilla corta | 10 % | 10 % |
| Healing petals (+4 life) | 25 % with *Corona de cempasúchil* | Same |

Loot pops out as bouncing boxes coloured by tier and coins that fly to you within 4 m (Imán: 2.5 m pickup) after 0.35 s; they last 30 s.

**Other sources:**

| Source | Contents |
|---|---|
| Scrap pile by a lamp post (3 per zone) | 2-4 *suelto* materials; 40 % a varilla corta |
| Obra-negra house pile (10 per map load) | Alambrón; two of them hold blueprints (*Lanza de varilla*, *Bate con clavos de cobalto*) |
| Map-piece spots | Paper-map piece per zone; Takis tazo bags beside zones 1, 3, 5, 7 (with a light beam) |
| Buying Takis | 1 in 8 gives a special tazo bag (Buena racha: 1/6, 1/4) |
| GelA offering box at the west gate | 1-2 things at night, once |
| Casa clausurada | Loot once, refills every 7 nights (*needs review:* contents) |
| Death bag (`BolsaMuerte`) | Your items when you faint; a new death replaces the old bag |

**Crafting materials** (`scripts/Materiales.gd`):

| Family | Suelto (tier 1) | Bueno (tier 2) | Fino (tier 3) |
|---|---|---|---|
| Fierro | Rebaba | Tuerca | Engrane |
| Trapo | Hilacha | Trapo | Cuero |
| Cable | Alambrito | Cable | Cobre |
| Lumbre | Cerillo | Thinner | Pólvora |
| Agua | Agua sucia | Agua de la llave | Agua destilada |
| Vela | Pabilo | Veladora | Agua bendita |

| Special material | Source |
|---|---|
| Varilla corta | Zombies, scrap |
| Alambrón | Obra-negra piles |
| Plata de Taxco | Bought at el punto, $120 |
| Baba verde | Killing a burning zombie |
| Polvo de Serenol | GelA zombie |
| Varilla armada, Varilla del 84 | Crafted |

| Trophy (kept even on Partida nueva, at most one each per night) | Feat |
|---|---|
| Marca de cazador | Kill a hunter |
| Ojo de turba | Kill 5 of a mob within 10 s |
| Ceniza | Kill with fire |
| Tapa del tinaco | A night with no tinaco damage |
| Diente del jefe | Kill the boss |
| Chancla de oro | Kill with no weapon |
| Casco de GelA | GelA zombie |
| Cobalto | Cobalt zombie |

### 6.3 Shops

Enter by stepping on the yellow arrow; Q/E or A/D browse, Space buys. Open by day only.

| Interior | Sells | Price factor |
|---|---|---|
| Tiendita (OXO) | Caguama, cigarros, gansito, jarritos, mazapán, sal, takis, trapo | × 1.15 |
| Abarrotes | Bocina, galón de agua, gansito, jarritos, mazapán, takis | × 1 |
| Abarrotes Doña Mary | Botella de agua, cigarros, gansito, jarritos, mazapán, takis | × 1 |
| Farmacia | Botiquín, galón de agua, vaporub | × 1 |
| Ferretería | Bate, cinta, machete, tablas, trapo | × 1 |
| Gasolinera | Fills an empty bottle: gasolina de limón ($30), de cereza ($40) | × 1 (*needs review:* the spec says × 1.15) |
| Licorería | Alcohol del 96, caguama, cigarros | × 1 |
| El punto (obra-negra house, not on the minimap) | Caguama, cigarros, Plata de Taxco, tachas | × 1 |
| Purificadora | Cloralex, galón de agua | × 1 |
| Taquería / puesto de tacos | Caguama, jarritos, tacos | × 1 |
| Tortillería La Lupita | Jarritos, tortillas | × 1 |
| El Yonke (La Chava) | Crafting (§6.6) | — |
| Punto de mejoras (career test) | Upgrades (§4.3) | — |

**needs review:** the spec lists Cloralex at the abarrotes; the scene sells a bocina instead.

### 6.4 Item catalogue (`resources/productos/*.tres`)

| Item | Type | Price | Key stat / effect |
|---|---|---|---|
| Gansito | Food | 15 | Heal 10 |
| Mazapán | Food | 8 | Heal 10 |
| Kilo de tortillas | Food | 22 | Heal 15 |
| Jarritos | Drink | 20 | Heal 25, leaves bottle |
| Caguama | Drink | 50 | Heal 25, leaves bottle |
| Tacos al pastor | Food | 45 | Heal 30 |
| Botiquín del Simi | Medicine | 120 | Heal 70 |
| Vaporub | Medicine | 2 *agua* | Heal 100 |
| Takis Fuego | Snack | 25 | Tazo bag chance (buff not implemented) |
| Takis bolsa especial | Tazo bag | — | Open: one tazo |
| Tachas, Cigarros | Consumable | 80, 40 | Not implemented |
| Galón de agua | Water | 35 | Mission item (thirst not implemented) |
| Botella de agua | Material | 15 | For the bocina encintada |
| Botella vacía | Material | — | Fill at the gas station |
| Gasolina de limón / cereza | Material | 30 / 40 | Molotov ingredient |
| Trapo | Material | 10 | Molotov ingredient |
| Alcohol del 96 | Material | 40 | No recipe uses it now (*needs review*) |
| Cinta canela | Material | 25 | Machete upgrade |
| Tablas | Material | 35 | Barricades (*needs review:* no player barricade building in the map) |
| Cloralex | Material | 30 | "Dirty water + Cloralex = clean water" (no recipe) |
| Machete | Melee | 2 *agua* | 12 damage |
| Machete reforzado | Melee | Craft | 18 damage |
| Bate | Melee | 150 | **No damage value** (`dano` 0) — *needs review*: it never beats the machete |
| Fémur de la Mojiganga | Melee | Boss | 22, knockback × 2, speed × 0.8 |
| Varilla del desagüe | Melee | Boss | 24, knockback × 1.6, speed × 0.85 |
| La Tinaquera / La Chicharra / La Matraca | Gun | 900 / 1200 / 2500 | See §4.4 |
| Sal, Molotovs, Palomita, Bocinas | Throwable | See §4.5 | See §4.5 |
| Mochila escolar / del Partido Verde / Mochilón | Backpack | — | 8 / 10 / 14 slots (equip on pickup, no slot) |
| Cangurera | Gear | Mission | Holds tiliches |
| Corona de cempasúchil | Amulet | Boss | 25 % healing petals |
| Plata de Taxco | Material | 120 | Goes to tiliches |
| Diente de la Madre | Trophy | — | "Someone would pay well" — *needs review:* no buyer |
| Costal de chiles | Quest item | — | Mission *Chiles para el mercado* |

**needs review:** the *Mochilón* is still named "del garrafonero" (docs want "del Nocturno"); the galón's effect text says "infección" (canon word is *sed*); the cigarettes' text says "zombies" (canon: *zombis*).

### 6.5 Inventory combine recipes (`resources/recetas/`)

| Result | A | B |
|---|---|---|
| Machete reforzado | Machete | Cinta canela |
| Molotov de limón | Gasolina de limón | Trapo |
| Molotov de cereza | Gasolina de cereza | Trapo |
| Bocina encintada | Bocina | Botella de agua |

### 6.6 Crafting at El Yonke (`scripts/Recetas.gd`, 39 recipes)

Each recipe costs tiliches and pesos (Regateo lowers the pesos). Set N opens after 0 / 3 / 9 / 15 / 21 distinct items crafted; set 6 also needs the blueprint.

| Set | Recipe | Pesos | Materials | Result |
|---|---|---|---|---|
| 1 | Caldo de pollo | 20 | 2 agua sucia, 1 pabilo, 1 cerillo | Heal 60 |
| 1 | Remedio de la abuela | 30 | 2 pabilo, 1 agua sucia | Full heal |
| 1 | Pulsera de hilo rojo | 25 | 2 hilacha, 1 pabilo | Amulet +10 life |
| 1 | Cadena de fantasía | 25 | 2 rebaba, 1 hilacha | Amulet +5 % strength |
| 1 | Rodilleras | 40 | 3 cerillo, 3 agua sucia, 3 alambrito | Amulet −5 % damage |
| 1 | Tubo de fierro | 30 | 3 rebaba, 1 varilla corta | Weapon 14, knockback × 1.3 |
| 1 | Medalla de San Judas | 150 | 4 trophies + 3 varilla del 84 | Amulet +20 % pesos |
| 2 | Suero oral | 35 | 2 agua de la llave, 1 pabilo | Heal 40 |
| 2 | Lámpara de pilas | 45 | 2 alambrito, 1 cable, 1 varilla corta | Amulet: light at night |
| 2 | Escapulario | 40 | 3 pabilo, 1 hilacha, 1 varilla corta | Amulet −10 % damage |
| 2 | Pulsera de San Benito | 50 | 3 alambrito, 1 tuerca, 4 trapo | Amulet +25 life |
| 2 | Cadena gruesa | 50 | 3 rebaba, 1 tuerca, 1 trapo | +10 % strength, −5 % damage |
| 2 | Coderas | 60 | 3 thinner, 3 agua de la llave, 3 cable | −10 % damage, +5 % reach |
| 2 | Antorcha de thinner | 45 | 2 thinner, 2 trapo, 1 varilla corta | Weapon 10, sets on fire |
| 2 | Bate con alambre de púas | 55 | 3 tuerca, 3 alambrito | Weapon 17, knockback × 1.5 |
| 3 | Estampita de San Expedito | 80 | 2 thinner, 2 agua de la llave, 2 cable, 4 varilla armada | +1 skill point |
| 3 | Rosario de semillas | 60 | 2 trapo, 2 veladora, 2 varilla corta | −20 % damage at night |
| 3 | Medalla de la Virgen | 90 | 5 veladora, 3 tuerca, 1 alambrón | More rare/holo tazos |
| 3 | Faja de cargador | 90 | 5 trapo, 3 tuerca, 1 ceniza | +40 max life |
| 3 | Cadena de oro | 100 | 5 tuerca, 3 thinner, 1 chancla de oro | +20 % strength |
| 3 | Varilla armada | 30 | 5 varilla corta, 1 alambrón, 1 baba verde | Material |
| 3 | Coa afilada | 90 | 5 tuerca, 3 trapo, 1 varilla armada | Weapon 20, reach × 1.25 |
| 4 | Té de la Virgen | 120 | 2 agua destilada, 1 agua bendita, 1 plata | Full heal |
| 4 | Estampita del Santo Niño | 150 | 3 cuero, 3 agua bendita, 2 tapa del tinaco, 1 plata | −5 % damage for the run |
| 4 | Ojo de venado | 150 | 3 cuero, 1 marca de cazador, 1 varilla del 84 | −20 % from hunters/boss, +15 life |
| 4 | Herradura | 160 | 5 thinner, 5 agua de la llave, 5 cable, 1 cobre, 1 plata | −20 % damage from mobs |
| 4 | Brazalete de cobre | 140 | 5 cerillo, 5 agua sucia, 5 alambrito, 1 cobre, 1 baba verde | Throwables hit harder and farther |
| 4 | Corona de lata | 180 | 5 cuero, 1 engrane, 1 cobre, 3 ceniza | +15 life, +10 % strength, −5 % damage, +10 % pesos |
| 4 | Machete de cañero | 150 | 3 engrane, 3 cuero, 1 varilla armada, 1 marca de cazador | Weapon 24, speed × 1.25 |
| 5 | Varilla del 84 | 60 | 9 rebaba, 1 polvo de Serenol, 2 varilla armada | Material |
| 5 | Milagro del tinaco | 200 | 5 agua destilada, 3 agua bendita, 2 polvo de Serenol, 1 plata | Full heal + recharge Segundo aire |
| 5 | Estampita de San Miguel | 200 | 5 engrane, 3 cuero, 2 casco de GelA, 1 plata | +5 % strength for the run |
| 5 | Chamarra del Nocturno | 220 | 5 hilacha, 3 cuero, 1 casco de GelA, 5 varilla corta | +30 life, −10 % damage, +10 % pesos |
| 5 | Medalla de GelA | 250 | Casco, cobalto, diente del jefe, plata, 3 varilla del 84 | +30 % pesos, −5 % damage |
| 5 | Listón de la Virgen | 250 | 5 thinner, 5 agua de la llave, 5 cable, 1 polvo, 3 cobalto | −20 % all damage |
| 5 | Marro | 230 | 5 engrane, 1 varilla del 84, 2 ojo de turba, 1 plata | Weapon 30, knockback × 2.5, speed × 0.8 |
| 6 | Machetón del 84 | 500 | 5 engrane, 5 baba verde, 3 cobalto, 3 diente del jefe, 3 varilla del 84 | Weapon 40, speed × 1.25 |
| 6 | Lanza de varilla | 400 | 3 varilla del 84, 3 ojo de turba, 3 marca de cazador, 5 alambrón | Weapon 30, reach × 1.6 |
| 6 | Bate con clavos de cobalto | 400 | 3 ceniza, 3 tapa del tinaco, 3 cobalto, 5 chancla de oro | Weapon 32, knockback × 3 |

Amulets go in **two slots** (`Bonos.LUGARES = 2`) and take no inventory space; damage reduction can never go below 20 % of a hit. Estampitas last the whole run.

**needs review:** set 6 needs 3 *Diente del jefe* or 5 *Chancla de oro*, but each trophy drops at most once per night; with endless nights this is now a long-term goal, but nobody has confirmed that intent. The *Brazalete de cobre* says throwables go farther; the docs say "no use yet" — *needs review* against `Lanzador`.

### 6.7 Tazos (collectibles, `resources/tazos/`)

48 tazos in 4 series of 12 (6 common, 4 rare, 2 holo each). Bag roll weights: common 65, rare 28, holo 7, preferring ones you don't have. Duplicates trade 3-for-1 (same rarity) with the tazo kid (by day, near the mission givers).

| Series | Rare / holo tazos (unlocks) | Commons |
|---|---|---|
| 0 · La colonia | Tinaco (Imán), Perro del barrio, Gota limpia, Luna; holo: Virgen del Tinaco (Segundo aire), El Jefe | Zombi, Garrafón, Paloma, Takis, Machete, Poste |
| 1 · La noche | Cazador, Búho (Ojo de halcón), Gato negro (Pies de gato), Amanecer; holo: Luna roja, Calavera de azúcar | Zombi gordo, Tambo prendido, Tablas, Rata, Foco fundido, Huesos |
| 2 · Los vecinos | Padre Chuy, Dr. López, Inspector Nava, El Patrón; holo: Obispo Marín, El Nocturno | El garrafonero, Doña Rosa, Beto Ríos, Karla la beata, El taquero, La radio de Sofía |
| 3 · GelA | Lic. Buenrostro, Gerardo Lazcano, Germán Lazcano, Gota negra; holo: Georgina Lazcano, El tinaco que no se vacía | Garrafón GelA, Serenol, Decreto 47, Varilla del 84, Puri-GelA, La pipa |

**needs review:** the holo *El tinaco que no se vacía* and the *Milagro del tinaco* description refer to the legend of the tinaco that never empties, which the team **removed from canon on 2026-11-12**. The milestone rewards exclude that tazo (`TablaHitos.tazos_excluidos`), but bags can still give it.

Milestone rewards: El Jefe (night 3) and Luna roja (night 7) are fixed; nights 5, 10 and 15 give a holo you are missing.

### 6.8 Quest and achievement rewards

| Source | Reward |
|---|---|
| Day missions | $45-100, items (§7.1) |
| Tinaco defence won | $150 + galón de agua; nothing if the tinaco breaks (prevents losing on purpose for pay) |
| Night milestones (3, 5, 7, 10, 15) | One holo tazo each |
| La Madre del Cárcamo | $400, holo tazo, Diente de la Madre |
| La Mojiganga | Corona de cempasúchil, Fémur |
| La Desaguadora | 300 chips, Varilla del desagüe |
| El garrafonero | Diente del jefe, a blueprint |
| Trophies | See §6.2 |
| Completing a tazo series | Confetti only (no points) |

### 6.9 Gambling

**Fruit machines** ("Cóctel de Frutas", outside about half of the abarrotes and liquor stores). Bet $1-9 on one of 8 fruits; the light runs around 24 squares.

| Fruit | Manzana | Naranja | Cereza | Campana | Melón | Sandía | Siete | BAR |
|---|---|---|---|---|---|---|---|---|
| Pays × | 3 | 4 | 5 | 7 | 10 | 15 | 25 | 35 |

Each machine has a coin box (starts at 100, never pays more than it holds) and a DIP-switch difficulty that blocks big wins (Sandía, Siete, BAR) 10 / 35 / 60 / 85 % of the time. Visible states: coins in the tray (normal), dark panel (empty box, 20 % of machines), a lit votive candle (5 %: the next spin wins). Wins fire rockets in the sky.

**El Sótano** (chips): EL GORDO slot machines (pull a lever), Texas Hold'em against three neighbours, blackjack, roulette (with a double-or-nothing *doblete*), baccarat (5 % commission), horse races on TV, a bar. The house cheats, with tells. Live decoration: slot players, walkers, shady people, a waitress.

---

## 7. Quests, story and NPCs

### 7.1 Implemented missions (`resources/misiones/`, `Misiones.ARCHIVOS`)

One active at a time, each once per day; it fails at nightfall or when its timer ends and can be retried the next day. Offers stop at the dusk warning. Tracked by an on-screen line, an arrow, the minimap and the paper map. Givers wear a yellow **!**.

| Mission | Giver | Steps | Pay | Item rewards |
|---|---|---|---|---|
| Encargo de compras | Señora (`mujer_psx`) | Buy 2 galones at the farmacia → deliver | $100 | 2 tablas + Takis tazo bag |
| Repartir garrafones | Repartidor (`psx_man`) | Carry water to 4 houses in 100 s | $90 | Takis tazo bag |
| Buscar al perro | Chava (`chava_psx`) | Find Firulais by his barking → carry him back | $60 | Map piece (or $60 more if you have all) |
| La cangurera del tianguis | Cholo | Buy 2 Jarritos at the abarrotes → deliver | — | Cangurera |
| La pelota en la azotea | Profe de la cancha | Climb the lookout roof, get the ball → return | $50 | — |
| Tortillas para la vecina | Vecina del lavadero | Buy 2 kg at La Lupita → deliver | $70 | — |
| Agua para la fila | Abuelo de la fila | Get a galón at the purificadora → deliver | $60 | — |
| Chiles para el mercado | Marchanta | Pick up the chile sack at the tianguis → deliver | $45 | — |

Step types in code: `TENER_OBJETOS`, `ENTREGAR`, `VISITAR`, `RECOGER`. New missions can be added as `.tres` files without code.

### 7.2 Designed but not implemented

| Group | Missions | Source |
|---|---|---|
| Night contracts | Defender el tinaco (external defence, $150-250), Defender la camioneta ($60-100 per stop), Guardia de la reja, Reparto clandestino, Recolección, Encargo, Cacería | `docs/misiones.md` §2 |
| Gate-failure event | Random night (wear rises +0.05/night, −0.25 per guard shift; chance = wear ÷ 3, min 2 %); defend the plaza tinaco; 3 retries | §2 (numbers 💡) |
| Missions outside | Al médico, La antena de Sofía, El Decreto 47, Reparto, La hija de Nava | "Las misiones de fuera" |
| Mafia | Point-to-point deliveries (19 *punto* stores), Las cuentas claras; unlock La Gotera | L10 section |
| Hunts | La Mojiganga, La Madre | L10 |
| GelA | Guard job, Arturo, Gerardo | L10 |
| Story | H1-H5 (the five clues of *La revelación*), A1-A4 support missions, each with two paths | §4 |
| Day ideas | ~19 (taco cooking, races, target practice, protest, escorts...) | §3 |

Campaign plan "Noches de fuera" (`docs/plan-noche.md`): phase L (text) is done except **L12** (rebuild the narrative graph) — that is the next unchecked block. Phases S (12 systems), P (8 places), F (5 fortress blocks) and M (10 missions) are all open.

### 7.3 Story summary

Five years ago the state gave Guadalajara's water to **GelA** (Germán Lazcano); his daughter **Georgina "Gela"** is governor, elected by the docile "tap vote". Serenol in tap water makes nine in ten docile and kills and raises one in ten. Clean water is illegal to filter (Decreto 47). Three walled fortresses hold out: **Santa Mugre** (the cult of the Virgen del Tinaco, a stained tinaco filled by padre Chuy from a well under the temple; Chuy suspects why it works and stays silent), **La Gotera** (the mafia, with its own aquifer; sells clean water at fair prices) and **Los Reservorios** (GelA, where everyone knows). Outside, most people are under Serenol, give no missions, and police shoot water carriers by day, so the water trade happens at night. The player is **El Nocturno**, a night contractor in the water guild. Sub-stories: the cobalt rebar of '84 (obra-negra houses, lamps that drain life) and the madman's crosses of excrement. The lore never blocks play: the sandbox works without it.

### 7.4 NPCs in the game

| NPC | Where | What they do | Status |
|---|---|---|---|
| Mission givers (8) | Near the start / Santa Mugre marks | Offer, reminder, thanks and goodbye lines | Done |
| Store sellers | Every shop (PSX civilian matching the door) | Sell; short line | Done |
| Walkers (≤ 12), people outside stores (≤ 6), sitting dogs (≤ 3), garrafonero with jug | Map sidewalks, by day only | Ambience; some talk; hurry at dusk | Done |
| Niño de los tazos | By day near givers | Trades duplicate tazos | Done |
| La Chava | El Yonke | Crafting, trophy case | Done |
| Padre Chuy | Temple | Talks, never confesses | Done (no missions) |
| Güero, Sofía, Toño | Their houses | Dialogue lines | Partial (no missions; the Güero's lines still mention the palace) |
| Gate guards, lookouts, vigil, procession, school kids, teacher | Santa Mugre | Ambience | Done |
| El Sótano staff and patrons | Casino | Guard (fee), Primo (chips), bartender, waitress, players | Done |

The design cast (`docs/personajes.md`) has 30 voiced characters, 10 sellers and ~600 lines; most are not in the game yet. A phone UI with an AI contact (Sofía) is designed (spec §4.10) but not implemented.

---

## 8. Systems

### 8.1 Combat

- **Melee** hits only the nearest live zombie in the cone (one target per swing; area only on the special moves). Each hit: white flash, whack sound, dirty-water drops, camera shake, a few freeze frames (scaled by damage). No knockback (`Zombie.EMPUJON` 0) and no stun (`Zombie.ATURDIR` false) — both turned off after playtests.
- **Getting hit:** freeze, white flash, 2 frames of black-and-white, pushed ~1.5 m (3 m by the boss), blood spray, 0.7 s invulnerability.
- **Action buffer** (Smash-style): swing, jump, roll and thrust pressed during another action fire when allowed (0.3 s buffer; 0.15 s for swings).
- **Walk vs jog:** swinging walks; jogging and sprinting only while doing nothing else. S during a swing backpedals.
- **Fire:** Molotovs and the torch burn zombies (3 damage every 0.5 s for 3 s).
- Tension: the Director's intensity drives spawns and gun spread ("nerves").

### 8.2 Day/night cycle (`scripts/map/Ciclo.gd`)

Default day 12 min + night 8 min (`map_test` uses 8 + 6, JJ's call), 30 s transitions, dusk warning 1 min before (church bell, people hurry, procession in Santa Mugre). Dawn is 6:00; with 8 + 6, dusk is 19:42. Street lamps switch on in steps, real lights near the player. Shops shut with rattling shutters; the drone is disabled at night in `map_test`. N skips to the next transition.

### 8.3 Survival and fainting (`Supervivencia.gd`)

Life bar top-left; red edges below 35 %; "Cúrate wey" warning. Segundo aire skips one faint per night. The planned **thirst** (*sed*: drinking tap water fills it; full thirst = permanent death as a zombie) is **design only**.

**Death works like Dark Souls** (team decision, 2026-11-23):

1. At 0 life the CRT-off effect plays. Your inventory items go into a death bag (`Noches.bolsa`); money, backpack, cangurera and tazos stay with you. Used estampitas end.
2. You wake at the respawn point with 50 life. Zombies within 20 m are cleared. **The night counter does not reset.**
3. Fainting again before you recover the bag destroys the old one.
4. **By night** a leader zombie carries the bag on his back and drinks the water in it. A guard group watches it (§5.1). You can only take the bag after killing the leader, who drops it.
5. **By day** the bag lies unguarded on the floor (AG's call). If it is still there at dusk, the leader picks it up again.
6. There are no guards inside Santa Mugre. The bag is marked on the minimap.

### 8.4 Structure (`Partida.gd`, `Noches.gd`)

An endless sandbox: there is no last night and no end screen.

- `Noches` (autoload) counts the nights, keeps the best record (`user://noches.cfg`, shown on the start screen and in the HUD) and runs the milestones (§5.4).
- At dawn: *"Sobreviviste la noche N"*, the milestone tazo, and an autosave.
- With a refuge (safehouse), losing the tinaco only warns you; it is repaired at dawn *(first guess)*.
- The neighbours' looted houses refill every 7 nights *(first guess)*.
- Boss fights use Juanjo's `EntradaJefe`/`PasoJefe`. Without a mission they open on their milestone night (Madre 10, Mojiganga 15). Fainting in one leaves your bag at its entrance.

### 8.5 Saving (`Guardado.gd`)

Everything is saved to `user://partida.cfg` (AG's call, 2026-11-23):

- **What:** inventory, backpack, weapon, cangurera, money and *agua*, life, map pieces, tazos (album, points, levels), tiliches, amulets and estampitas, chest and looted houses, chips and permissions, the night, the milestones given and the death bag, plus the scene, the position and the hour.
- **When:** at dawn, on arena trips, on Santa Mugre gate crossings and when the window closes. Only `map_test` and `mapa` save on their own; the safehouse and test scenes don't.
- **Start screen:** **Continuar** loads it. **Partida nueva** asks to confirm, then wipes it.
- **Not saved:** zombies, items on the floor, bullets in the magazine, deterioration.

Other files on disk:

| File | Contents |
|---|---|
| `user://partida.cfg` | The saved game |
| `user://noches.cfg` | Best night record |
| `user://personaje.cfg` | Character creator choices |
| `user://taller.cfg` | Workshop rank, blueprints, trophy case |
| `user://libreta.cfg` | Bestiary progress |
| `user://puntos_*.json`, `casas_*.json`, `banquetas_safehouse.json` | Generated layout caches for test scenes |
| `user://campo_carcamo.bin` | Baked distance field for the worm arena |
| `user://pruebas/` | Balance-test logs (`Registro`, `MonitorDefensa`) |

### 8.6 UI

| Screen | Key | Notes |
|---|---|---|
| Start screen | — | Night diorama, menu (Continuar / Partida nueva when a save exists), best-night record, credits read from `CREDITS.md` |
| Character creator | (start, closet, C in career) | Five protagonists, appearance |
| HUD | — | Life bar, clock "Día n / Noche n" and record, round minimap (map_test; marks the death bag and boss arrows), weapon/ammo and "Q curar (n)", crosshair per gun, mission line and arrow, material notices, zone names |
| Inventory | Tab | Silent Hill 2-inspired ring that fades into darkness; Examinar (3D inspect), Utilizar, Combinar, Equipar, Abrir; Estado shows the paused world and health |
| Paper map | M | 9 pieces, missing ones blank |
| Skills | H | Shows current vs next with real numbers; red cost if short; locked skills show the tazo silhouette |
| Album | T | One series per screen, spinning 3D tazo |
| Tiliches | B | Materials; V at the workshop opens the trophy case |
| Libreta | L | Bestiary page drawn in code: entries *zombi, cazador, infectado, gordo, jefe, crías, madre, remedios*, each in 3 unlock levels |
| Dialogue box | talk to an NPC (Space) | Pauses the game; typewriter text with blips, speaker name, a placeholder talking portrait, tags `[feliz]`/`[enojo]`/`[clave]` with pixelfx puffs, sparkles and an anger mark (`DialogueBox`, from branch `dialogos-test`). Replaced the 3D speech bubble. Covers the bottom HUD while open; real portraits pending |
| Shop | arrow | Rotating product, name, effect, price, your money |
| Fruit machine / casino | Space | Button rows: arrows + one button |

Planned: stamina bar, thirst meter, phone, hotbar, better fight HUD (JJ's pending list).

### 8.7 Map streaming and rendering

Chunks streamed from `resources/map/cuadros/` with a per-frame load budget (`CargaCuadro.gd`), loading less on foot than in the drone. Builders for houses, warehouses, walls, trees, grass, lamps; deterioration shader; burning barrels and sparking lamps in ruined zones. `tools/medir_mapa.tscn` measures FPS. Visual systems: liquid drops and splats, zombie gibs, pixelfx accents (hit, death, dawn, pickup, rays), PS1 sky and horizon in Santa Mugre.

### 8.8 Day people (`Gente.gd`)

Walkers on real sidewalks from OSM, random PSX civilians with Quaternius walk clips; people by stores; dogs. They hurry at dusk, vanish at night and return at dawn.

### 8.9 Own house and chest

Bed (sleep to the next transition, full life), closet (creator), trophy case, album, libreta, TV with GelA news, a chest (`Baul`, saved storage), altar, paper map on the wall. You can enter at night.

### 8.10 El Sótano

Underground casino of the Gotera under a Santa Mugre store; open at night; one control scheme for every game; secret boss. Pending: real sounds, the permission missions, walker collisions.

### 8.11 Test and dev tools

| Tool | Purpose |
|---|---|
| Safehouse | Every mechanic in a 100 m yard; key pages (F1); $500 start; Shift+G/J/L/X spawn Saltabardas, Panzón, Madre, Mojiganga; F12 restart. Page "Noches sin fin": Ctrl+H eve of the next milestone, Ctrl+O milestone tazo, Ctrl+Y drop a guarded bag, Ctrl+G / Ctrl+Shift+G save / load |
| Godmode defence | Full upgrade catalogue, infinite items, one night |
| Career test | Economy with the upgrade shop; `Registro` CSV logs per night |
| Bot fights | `--bot` for La Mojiganga; `--medir`, `--cheese` |
| Measurement | `tools/medir_mapa.tscn`, `MonitorDefensa`, `--perfil` in the worm arena |
| Graphs | graphify narrative graph (`docs/graphify-out/`) and code graph (`scripts/graphify-out/`) |

---

## 9. Project status

### 9.1 Done

- Real-map pipeline, streaming, day/night cycle, shutters, street lighting, deterioration.
- Player movement, camera, melee combo, heavy slash, aerial spin, air thrust, block, roll, healing, action buffer, hit feel.
- Pistol plus three guns with full feel (recoil, reloads, casings, heat).
- Throwables: salt, two Molotovs, palomita, two speakers; gas station.
- Zombies: wandering and detection, swarm walking on flow fields, Director and night rhythm, hunters and mobs, variants, Saltabardas, gore and pixel effects.
- Inventory, backpacks, combine recipes, paper map, world pickups, death bag guarded by a leader zombie at night.
- Endless sandbox: night counter with record, milestones from a `.tres`, boss repeats, arena trips back to the map, save/continue.
- 12 shop types with first-person interiors; fruit machines.
- 8 day missions with data-driven steps.
- Tazos (48), skills (16), reveal animation, album, trade kid.
- Crafting: 39 recipes, materials, loot boxes, trophies, blueprints, amulets.
- Libreta (bestiary).
- Santa Mugre fortress map with temple, school, procession, vigil, neighbours' houses.
- Protagonist's house; El Sótano casino with 6 game types and the secret boss.
- Character creator with five protagonists.

### 9.2 Partial or placeholder

| Item | State |
|---|---|
| 3-night challenge mode | JJ wanted it as a challenge mode; removed with the sandbox, not rebuilt |
| Tinaco defence | Standalone test scene; not in the map (plan S10) |
| Upgrade shop | Test scenes only (by decision) |
| Boss arena entrances | Placed at provisional spots (needs review); La Mojiganga's parade is a warning + arrow, not a street parade |
| Panzón | Built, AG proposal, not confirmed for the gordo slot |
| Gordo type | Placeholder stats, never spawned |
| Guns | Not sold; no illegal market (S7) |
| Palomita | No shop or drop |
| Consumable buffs (Takis, tachas, cigarros, caguama dizziness) | Text only |
| Thirst, stamina | Not implemented |
| Neighbours Güero, Sofía, Toño | Lines only |
| Temple well, water handouts | Visual only |
| La Gotera, Los Reservorios | Not built |
| Police | No code (S3) |
| Outside NPCs under Serenol at night | Not built (S6) |
| Seller characters | Generic civilians with short lines |
| Sounds | Many generated placeholders; JJ picks the real files (block sound, guns, casino) |
| Clothes colour for the new protagonist model | Pending |
| Multiplayer | Not started (open vote: browser multiplayer vs PC) |

### 9.3 Known bugs and issues

| Issue | Source |
|---|---|
| Zombies queued at the tinaco run in place when nobody kills them; they should circle and attack from the next free spot | `docs/pruebas-balance.md` |
| Map nights may be too quiet: many loose zombies never find the player since detection was added | `docs/pruebas-balance.md` |
| Casino walkers pass through the player and each other (no navigation) | `docs/sistemas/sotano.md` |
| La Mojiganga not beatable with machete only in bot runs; the cheese fix (bursting the car) passes | `docs/pruebas-balance.md` |
| Civilians may T-pose when a clip is missing (`Kneel_Idle`); falls back to Idle | `docs/mapa/colonias/santa_mugre.md` |
| `shaders/jittershader.gdshader` writes `POSITION` only inside an `if`, which leaves meshes invisible when the branch is off | `CLAUDE.md` |
| A headless run with a parse error hangs forever (dev hazard) | `CLAUDE.md` |
| Data bugs: Bate has no damage; Mochilón name; galón and cigarettes text | §6.4 |
| `MenuTest`'s map test and the safehouse's F10 open `map_test`, which autosaves at dawn over the real save | `Guardado.ESCENAS` |

### 9.4 Open TODOs (from `docs/pruebas-balance.md` "Pendientes de la pelea" and the plan)

- New healing animation (Quaternius `Consume`) for Q.
- 10 % chance a zombie blocks a machete hit (bounce and lag, no damage).
- Better block sound.
- Better fight HUD (life, tinaco, weapon, ammo).
- Gordo zombie attacks and numbers.
- Tune weapon damage, zombie life/speed, tinaco life, hordes and pay (all first guesses).
- Playtest checks: PSX zombie skins, detection distances, the milestones and the guarded bag, FPS before/after (`tools/medir_mapa.tscn` was not rerun after this change).
- Campaign plan: L12 graph rebuild; S1-S12 systems; P0-P7 places; F1-F5 fortresses; M1-M10 missions.
- Give *agua* a real source (or remove it); rename the mochilón; fix "infección" → "sed", "zombies" → "zombis".
- Gotera missions that grant casino permission.
- Real spots for the boss arrows; a real street parade for La Mojiganga.

### 9.5 Needs review (all flagged items in one place)

| # | Topic | Conflict |
|---|---|---|
| 1 | ~~Starting life~~ | **Settled 2026-11-23:** 60/100 in code. New: you wake from a faint with 50, below the start |
| 2 | ~~Skill tree total~~ | **Settled:** 44 in code, spec and `mejoras.md` |
| 3 | Charged attack | Code: heavy slash × 2.5, up to 4; `mejoras.md` §2.1 table still says thrust × 1.5, up to 6 (now flagged there). Unlock settled: tazo skill |
| 4 | Second currency | Kept by decision; **needs a real source** (only 3 at start; Machete and Vaporub cost 2) and contradicts spec §4.5 "una moneda" |
| 5 | Tinaco life | Code 300; design doc 100 |
| 6 | Zombie pay and trades | Spec: 5-60 pesos by trade; code 1-3, no trades |
| 7 | Removed legend | Tazo "El tinaco que no se vacía" and Milagro del tinaco text vs canon change of 2026-11-12 (excluded from milestone rewards, still in bags) |
| 8 | Start location | Lore: start in Santa Mugre; *Jugar* starts outside in `map_test` |
| 9 | ~~Run structure~~ | **Settled:** endless sandbox. JJ's "3 nights as a challenge mode" was dropped |
| 10 | ~~Two upgrade systems~~ | **Settled:** tazos only; Mejoras is a test tool |
| 11 | Shop catalogues | Abarrotes: spec Cloralex vs scene bocina; gasolinera price factor |
| 12 | Bate damage | `dano` 0 |
| 13 | Diente de la Madre | No buyer |
| 14 | Crafting set 6 | Trophy counts vs once-per-night drops; less of a problem now that nights never end |
| 15 | Brazalete de cobre | Docs say unused; item text says it works |
| 16 | Skin tone affects prices | Rule stated; nothing reads it |
| 17 | Gamepad overlaps | RB, R3, Q/E double bindings |
| 18 | Gotera trust steps | Count and names are proposals |
| 19 | Lore canon in the code | Güero's lines mention the palace; La Palmada well; school and palace names pending |
| 20 | Alcohol del 96, Tablas, Cloralex | Sold but no current use in the map |
| 21 | Horde growth cap | 15 %/night growth stops at the 30-zombie pool (`Zombis.max_total`) around night 8 |
| 22 | Boss arrow spots | Madre at the south lot (-300, 630), Mojiganga at the big court (-244, -721): no measured cárcamo or Catrina plaza yet |
| 23 | Leader drinks your water | Destroys the player's water items (fits lore: zombies want clean water); confirm the team wants item loss |
| 24 | Tinaco defence vs sandbox | `plan-noche.md`: the Santa Mugre tinaco defence is forced; losing the tinaco used to end the run, now nothing ends. What losing it costs is undecided |
| 25 | Many new numbers | Milestones, guard counts, leader stats, skill costs, refill and growth rates are all *first guess* |

---

## 10. File map

| System | Main files |
|---|---|
| Start screen, creator, loading | `scripts/Inicio.gd`, `scripts/CreadorPersonaje.gd`, `scenes/inicio.tscn` |
| Player, combat moves | `scripts/player.gd`, `scripts/character_animation.gd`, `scripts/EstelaBarrido.gd`, `scripts/InclinarCuerpo.gd`, `scenes/player.tscn`, `scenes/protagonista.tscn` |
| Guns | `scripts/Pistola.gd`, `scripts/AgarrePistola.gd`, `scripts/Casquillo.gd`, `scripts/Cargador.gd` |
| Throwables | `scripts/lombrices/Lanzador.gd`, `Arrojadizo.gd`, `ZonaLombrices.gd`, `Palomita.gd`; `scripts/map/Senuelo.gd`; `scripts/interiores/Gasolinera.gd` |
| Character | `scripts/Personaje.gd`, `scripts/CuerpoPersonaje.gd`, `scripts/personajes/` |
| Life, money | `scripts/Salud.gd`, `scripts/Cartera.gd` |
| Inventory | `scripts/Inventory.gd`, `scripts/InventoryItemData.gd`, `scripts/InventoryUI.gd`, `scripts/InventoryInspectViewer.gd`, `scripts/WorldItem.gd`, `scripts/RecetaData.gd`, `resources/productos/`, `resources/recetas/` |
| Paper map | `scripts/MapaUI.gd`, `scripts/PiezasMapa.gd`, `scripts/map/PiezaMapa.gd`, `scripts/map/ZonasMapa.gd` |
| Missions | `scripts/Misiones.gd`, `scripts/MisionData.gd`, `scripts/PasoMision.gd`, `scripts/map/MisionesMundo.gd`, `scripts/map/CosaMision.gd`, `resources/misiones/` |
| Tazos, skills | `scripts/Tazos.gd`, `scripts/TazoData.gd`, `scripts/Habilidades.gd`, `scripts/HabilidadesUI.gd`, `scripts/AlbumTazos.gd`, `scripts/TazoRevelacion.gd`, `scripts/map/NinoTazos.gd`, `resources/tazos/` |
| Crafting | `scripts/Taller.gd`, `scripts/Recetas.gd`, `scripts/Materiales.gd`, `scripts/Tiliches.gd`, `scripts/TilichesUI.gd`, `scripts/Bonos.gd`, `scripts/map/Hazanas.gd`, `scripts/map/CajaBotin.gd`, `scripts/map/Chatarra.gd`, `scripts/interiores/TallerUI.gd`, `Yonke.gd`, `scripts/map/YonkeMapa.gd`, `resources/taller/` |
| Upgrades (tests) | `scripts/Mejoras.gd`, `scripts/MejorasUI.gd`, `scripts/Pruebas.gd`, `scripts/PruebasUI.gd`, `scripts/Registro.gd`, `scripts/MenuTest.gd` |
| Bestiary | `scripts/Libreta.gd`, `scripts/LibretaEntradas.gd`, `scripts/LibretaUI.gd`, `tools/libreta/` |
| Day/night, structure, survival | `scripts/map/Ciclo.gd`, `scripts/map/Partida.gd`, `scripts/Noches.gd`, `scripts/HitoNoche.gd`, `scripts/TablaHitos.gd`, `resources/noches/hitos.tres`, `scripts/map/Supervivencia.gd`, `scripts/map/BolsaMuerte.gd`, `scripts/map/GuardiaBolsa.gd`, `scripts/map/Refugio.gd`, `scripts/map/EntradaRefugio.gd` |
| Save, boss trips | `scripts/Guardado.gd`, `scripts/mapa/PasoJefe.gd`, `scripts/mapa/EntradaJefe.gd` (Juanjo's) |
| Zombies | `scripts/map/Zombie.gd`, `Zombis.gd`, `Director.gd`, `RitmoNoche.gd`, `ConfigZombis.gd`, `CampoFlujo.gd`, `Deterioro.gd`, `resources/zombis/` |
| Special enemies | `scripts/map/Saltabardas.gd`, `scripts/map/Panzon.gd`, `scripts/map/RocaPanzon.gd` |
| Bosses | `scripts/lombrices/` (Madre, swarm, solver), `scripts/catrina/` (Mojiganga), `scripts/sotano/Desaguadora.gd`, `Desague.gd` |
| Effects | `scripts/map/EfectosPixel.gd`, `Liquido.gd`, `RestosZombi.gd`, `resources/fx/`, `tools/pixelfx/`, `shaders/` |
| Tinaco defence | `scripts/defensa/` (`DefensaTinaco.gd`, `Hordas.gd`, `Barricada.gd`, `TinacoDefensa.gd`, `MonitorDefensa.gd`), `scenes/defensa_tinaco.tscn`, `scenes/escena_carrera.tscn`, `scripts/refugio/RefugioCarrera.gd` |
| Real map | `scripts/map/MapStreamer.gd`, `CargaCuadro.gd`, `MapPuntos.gd`, `MapCasas.gd`, `MapBodegas.gd`, `MapBardas.gd`, `MapArboles.gd`, `MapPasto.gd`, `MapAlumbrado.gd`, `Alumbrado.gd`, `MapDron.gd`, `MapMinimapa.gd`, `MuroColonia.gd`, `tools/map_import/`, `resources/map/` |
| Blender colonia map | `scripts/mapa/` (`Colonia.gd`, `PasoColonia.gd`, `Procesion.gd`, `Campana.gd`, `Palomas.gd`, `Horizonte.gd`, `Tianguis.gd`, `TinacoComunitario.gd`, `LuzTrampa.gd`), `tools/blender/mapa/`, `scenes/mapa.tscn` |
| Shops and interiors | `scripts/interiores/Interiores.gd`, `Interior.gd`, `TiendaUI.gd`, `Mostrador.gd`, `Estante.gd`, `Refrigerador.gd`, `scenes/interiores/` |
| Houses | `scripts/interiores/CasaPropia.gd`, `CasaVecino.gd`, `MueblesCasa.gd`, `Templo.gd`, `scripts/CasaPersonaje.gd`, `scripts/Baul.gd`, `scripts/BaulUI.gd`, `scenes/casa_personaje.tscn`, `scenes/casas/` |
| Fruit machines | `scripts/tragamonedas.gd`, `scripts/map/Maquinita.gd`, `TragamonedasUI.gd`, `Cohetes.gd` |
| Casino | `scripts/sotano/` (`Sotano.gd`, `Fichas.gd`, `JuegoSotano.gd`, `OlPleyUI.gd`, `Holdem.gd`, `PokerUI.gd`, `Blackjack.gd`, `Ruleta.gd`, `Baccarat.gd`, `CarrerasUI.gd`, `VidaSotano.gd`), `tools/blender/sotano/` |
| NPCs and people | `scripts/npc.gd`, `scenes/npc.tscn`, `scripts/dialogue_box.gd`, `scenes/dialogue_box.tscn`, `scripts/map/Gente.gd` |
| Sound | `scripts/Sonidos.gd`, `audio/` |
| Dev safehouse | `scripts/map/Safehouse.gd`, `scenes/safehouse.tscn` |
| Design docs | `docs/especificaciones.md` (spec), `lore.md`, `personajes.md`, `misiones.md`, `items.md`, `mejoras.md`, `plan-noche.md`, `pruebas-balance.md`, `revision-historia.md`, `docs/sistemas/*.md`, `docs/mapa/` |
