# El Sótano (the Gotera's underground casino)

AG, 2026-11-18.
- **v2** (2026-11-19, branch `sotano-v2`): two halls, Texas Hold'em instead of the lotería, the game on the cabinet screen, simpler fruit machines, people.
- **v3** (2026-11-19, branch `sotano-v3`): solid boxes (nothing floats any more), real seats and bottles, readable reel cards, the machines renamed **EL GORDO**, tube neon from Blender, a roomier hall 2, poker card animations.

The story is in `docs/lore.md` §11 "El Sótano". Keep this file in sync with the code.

**Naming:** the machines are called EL GORDO in the game (they used to be "OL PLEY"). The code still calls them `OlPley`: `GabineteOlPley`, `OlPleyUI`, the `Marca_OlPley_*` marks and `gabinete_olpley.glb`.

## Getting in

- **Door:** the `casa_vecino` marker `Sotano` in the Santa Mugre colonia JSON (and in `resources/mapa/santa_mugre/marcas.json`), beside the door of the Mini Super Santa Mugre on the tianguis street.
  - `"abierto": "noche"`.
  - `"bodega": true` makes `Colonia._bodega` add a plastic strip curtain, crates and a red bulb.
- **Walkable house:** a `CasaPropia` like the neighbours' houses: combat off, the door on the west wall at z 3.11. The scene is `scenes/casas/sotano.tscn`: root `scripts/sotano/Sotano.gd` plus the Blender room `Cuarto` (`models/sotano/sotano.glb`).
- **Permission:** the `Fichas` autoload (`scripts/sotano/Fichas.gd`, reset per run in `Partida._otra_vez`) holds `permiso` and `fichas`.
  - With no permission, a chain at the foot of the stairs blocks the way (`CadenaChoque-colonly`). The guard takes the one-time `CUOTA` ($300) at the `MuebleCasa` beside him.
  - The Gotera missions will grant `permiso = 1` (escalón 1, `docs/misiones.md`).
- **Safehouse:** an arrow `Sotano` at (-15, 0, 40.2), always open. `.` grants permission and +50 chips.
- **Standalone test scene:** `godot --path . scenes/sotano_prueba.tscn` (`scripts/sotano/PruebaSotano.gd`). The casino is in the `.tscn`, so it shows in the editor.
  - It puts you before the chain with $1000.
  - Keys: `.` permission and chips, `P` +$500, `K` remove the permission, `H` all EL GORDO hot, `R` back to the stairs, `F12` start from scratch, `F1` hide the help.
  - `-- --foto=<file.png>` saves one screenshot and quits.
  - `-- --fotos=<dir>` saves a screenshot from each camera in `FOTOS` and quits. The cameras are low and side views (machines, window, bar, poker, every neon), to catch floating or hollow things.
  - `-- --poker=<dir>` sits at the poker table and saves a frame every 0.15 s, to see the cards move.

## The rooms (Blender)

`tools/blender/sotano/sotano.py` builds everything in Godot coordinates, in scene metres (`CasaPropia` scales by 1.25).
- Run it in an empty file, or in `models/sotano/fuente/sotano.blend`.
- It exports `sotano.glb`, `gabinete_olpley.glb` and `botellas.glb`.

**Faces must point outward.** `caja()` and `cable_recto()` call `_afuera()` (`bmesh.ops.recalc_face_normals`). In v2 the boxes came out inside out:
- walls and cabinets looked hollow;
- the floor you saw was the bottom face of the floor box, 0.4 below its collision (0.5 m in the game), so everyone looked like they floated.

`probar_sotano` now checks that the floor's top face points up.

- **Shell:**
  - Walls 0.4 thick (`GRUESO`), ceiling at 3 m, beams.
  - Stairs: solid steps with nosing, side stringers, a handrail, and a hidden walking ramp (`Rampa-colonly`).
  - Hall 1 (`SALON`, 14 × 10): the machines.
  - The arch (`ARCO`, with jambs and lintel) leads to hall 2 (`SALON2`, 14 × 10, the same z as hall 1).
- **Hall 1:**
  - The Primo's window: counter at 1 m, bars 0.2 apart, a green lamp, cash box and fan.
  - The guard and his chain.
  - Ten EL GORDO (eight on the north wall, two on the south), each with a bar stool.
  - Two fruit machines facing the room.
  - The race track as an island in the south half (`PISTA`, finish at `PISTA_META` 16.5; the horses run along +x).
  - The altar, the speaker, crates, two columns.
- **Hall 2:**
  - Bar on the north wall: back bar with three shelves of bottles, a red fridge with a lit glass door, the counter with taps and bottles, and five tall stools.
  - Poker table in the middle (`MESA`), with room around it: felt, padded rail, chip stacks, a high lamp, three folding chairs (`Poker_0..2`), your spot (`Poker_tu`), the dealer (`Crupier`).
  - Caguama freezer in the south-west corner, the bathroom door on the east wall, a high table with beers.
- **Seats:** `banco()` is a cantina stool (chrome post, foot ring, red vinyl cushion). `silla_plegable()` is a brewery folding chair with the Coronela logo on its back, taken from the poster atlas.
  - Seat height `ASIENTO` 0.5: the `Sitting_Idle` thighs sit at 0.52.
  - That clip leaves the hips 0.38 behind the feet, so `Sotano.CADERA` moves each seated NPC forward. `tools/sotano/medir_sentado.gd` measures it.
- **Bottles:** `botella()` turns a profile on the lathe (`girar()`) and joins glass, label and cap into one mesh (`juntar()`).
  - Types in `BOTELLAS`: tequila, mezcal (with its worm), whisky, rum, beer, caguama.
  - `botellas.glb` has one of each at the origin (`Botella_<tipo>`), for the waitress's tray.
- **Name suffixes:**
  - `-convcol`: solid box.
  - `-colonly`: collision only. Must be unique, or Godot renames the body.
- **Empties `Marca_*`** place everything else: lights, neons, posters, cabinets, NPCs, seats, the walking route `Camino_*`.
- **Neon:** `tools/blender/sotano/neones.py` exports `models/sotano/neones.glb`, one `Neon_<name>` empty per sign, facing +Z.
  - **Tubes:** text and shape curves with a bevel (fonts with no fill give outline tubes), turned into meshes.
  - **Halo:** a thicker copy of each tube in an additive material. It glows without environment glow.
  - **Bulbs:** two meshes per sign (`_focos_a`, `_focos_b`) that take turns.
  - **Brackets:** black rails behind each sign.
  - **Fonts:** block letters use Blender's font; the hand-written words use `fonts/Pacifico.ttf` (OFL, credited in `CREDITS.md`).
  - **Signs:**
    - EL GORDO: hangs back to back from the middle beam of hall 1.
    - ¡Premio!: over the south machines.
    - PÓKER: with the four suits and "Texas".
    - ABIERTO 24 HRS.
    - Tecatl with a beer mug: on the bar front.
    - BAÑO: with an arrow.
- **Art:** `tools/blender/sotano/arte.py` renders with flat Workbench and no AA (`SOLO=(...)` renders only some):
  - `textures/sotano/cartas.png`: 24 lotería cards, 96 × 144 each (the size they show on the screen) and with no name. `OlPleyUI` writes the names.
  - `calcomanias.png` and `pantalla.png`: the EL GORDO cabinet and its idle screen.
  - `pantalla_juego.png`: the 384 × 288 game screen background.
  - `baraja.png`: 52 cards plus the El Tinaco back.
  - `anuncios.png`: six beer posters (`CERVEZAS`): Tecatl, Indita, Coronela, Modelito, Pacífica and the caguama deal.
  - `textures/maquinita/adorno_frutas.png`.
- **Materials:** `scripts/sotano/SotanoPostImport.gd` is the import script of every Sótano `.glb`. It swaps Blender materials by name for the game's:
  - textures;
  - glowing tubes;
  - `neon_*`: neon cores;
  - `*_halo`: additive halos;
  - `foco_*`: bulbs;
  - `vidrio_*`: glossy glass (mezcal is see-through);
  - `cromo`.

  A new `.glb` needs `import_script/path` set in its `.import` file. The Blender scripts delete materials when cleaning up, because a preview texture got embedded once.

## What's inside (`Sotano.gd`)

- **Light:** ten tube lights (two fail: `PARPADEAN`), the window lamp, the poker lamp.
- **Neon** (`NEONES`): instances from `neones.glb`, each with:
  - its scale;
  - a coloured light;
  - bulbs taking turns every `FOCOS` s;
  - some signs fail (`_parpadear` hides the sign).
- **Beer posters** (`CARTELES`): one shared material per poster.
- **Games and things to use:**
  - The ten EL GORDO (`GabineteOlPley`) and the two fruit machines in chip mode.
  - The window (`VentanillaUI`), the poker (`PokerUI`), the races (`CarrerasUI`).
  - The freezer (a caguama for 3 chips), the bar (a Tecatl from the bartender for 2 chips; the same caguama item), the altar, the bathroom door (text only).
- **People:**
  - Talkers on `npc.tscn`: guard, Primo, bartender, dealer, onlooker. The onlooker points out the hot EL GORDO.
  - Seated: four at EL GORDO stools and three on the poker chairs (`Civiles` with `Sitting_Idle`, moved forward by `CADERA`).
  - `GenteSotano`: five walkers on fixed routes of `Camino_*` and the waitress.
    - Some walkers stay in hall 1, around the track; others go through the arch to the bar.
    - The waitress carries a tray with two real Tecatl bottles. Her `MuebleCasa` follows her and sells a Tecatl.
- **Ambience:** the speaker loops `bocina_musica`, and the two fans spin.
- **Leaving with chips:** the Primo shouts once if you go up the stairs carrying chips.

## The games (the house cheats, with tells)

- **Chips:** $5 each (`Fichas.PRECIO`). Cashing out leaves 10% with the Primo.
- **EL GORDO** (`OlPleyUI`): the camera flies to the cabinet, and the game runs in a 384 × 288 `SubViewport` that the cabinet shows on its screen (`GabineteOlPley.mostrar_en_pantalla`).
  - **Reels:** lotería cards that scroll and stop one by one with a bounce. Each card shows its name in caps, in `PixelifySans` with no antialiasing (`_poner_carta`).
  - **On a win:** the pay line blinks, the counters show bet, chips and prize, and pixelfx plays: coins (`resources/fx/olpley_monedas`) or confetti (`olpley_confeti`).
  - **The board** is `Carretes`: about 89% return, a win one spin in four, El Tinaco is wild and pays double. `SIN_CAJA`; when it is `CALIENTE`, the marquee light blinks.
- **Fruit machines (everywhere):** simpler play in `TragamonedasUI`.
  - One fruit at a time: ←/→ moves the bet to another fruit, ↑/↓ sets 1–9 coins, Space spins.
  - The TIRAR and SALIR labels sit on the front panel above their button groups (`tools/map_import/make_maquinita.gd`).
  - `Maquinita.moneda = "fichas"` charges chips and keeps them open at night.
- **Texas Hold'em:**
  - **Rules** (`Holdem.gd`): fixed limit (blinds 1/2, raises of 2 then 4, 3 raises per round), best 5 of 7 with Spanish names, no side pots. The house takes 10% of each pot (up to 5).
  - **AI:** Doña Cuca is tight and Tacho bluffs. "El de la gorra" is the house's player: from the turn on he knows whether he beats you. The bartender and the onlooker drop hints.
  - **Table** (`PokerUI`): the camera flies to your seat and looks under the lamp. The board and the neighbours' cards lie on the felt in 3D.
  - **Cards move:**
    - The dealer deals one card at a time from his deck, in an arc and spinning (`_repartir`, `_volar`).
    - Board cards come out face down and flip (`_voltear`).
    - A player who folds tosses his cards to the deck (`_tirar_al_mazo`).
    - At showdown the neighbours' cards flip one by one.
    - Your two cards on screen enter face down and flip.
  - **Keys:** C check/call, R raise, F fold, Space next hand, Esc stand up. You play with your chips.
  - The NPCs' stacks persist between hands, and they rebuy at the window when broke.
- **Races** (`CarrerasUI`):
  - Odds 2/3/5/8/12, with chances proportional to 1/odds.
  - A bet of 5+ halves your horse's luck, and the house's horse trembles first (`Sotano.temblar`).

## Tests

- `godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<dir>` (needs a window; the folder must exist) ends with `RESULTADO: BIEN`. Steps:
  1. Enter the Sótano and check the people; the walkers stand on the floor and the floor's top face points up.
  2. Check the chain and the cuota.
  3. Buy chips at the window.
  4. Play 20 EL GORDO spins on the screen.
  5. Play a poker hand.
  6. Run a race.
  7. Buy beers at the freezer, the bar and from the waitress.
  8. Play a simple fruit spin.
  9. Cash out and leave.
- `godot --path . --headless -s tools/sotano/probar_holdem.gd` runs known hands plus 2000 AI hands and checks there are no stalls and no lost chips.

## Pending

- Real sounds (JJ picks). The games reuse `boton`, `paso` and `moneda`; the speaker uses `bocina_musica`.
- The Gotera missions that grant `permiso`.
- Walkers pass through the player and each other (no navigation).
