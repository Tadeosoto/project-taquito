# El Sótano (the Gotera's underground casino)

AG, 2026-11-18; v2 on 2026-11-19 (branch `sotano-v2`): two halls, Texas Hold'em instead of the lotería, OL PLEY played on the cabinet screen, simpler fruit machines, neon, beer ads and people. The story is in `docs/lore.md` §11 "El Sótano". Keep this file in sync with the code.

## Getting in

- **Door:** the `casa_vecino` marker `Sotano` in the Santa Mugre colonia JSON (and `resources/mapa/santa_mugre/marcas.json`), beside the door of the Mini Super Santa Mugre on the tianguis street.
  - `"abierto": "noche"`.
  - `"bodega": true` makes `Colonia._bodega` add a plastic strip curtain, crates and a red bulb.
- **Walkable house:** a `CasaPropia` like the neighbours' houses (combat off; the door on the west wall at z 3.11). The scene is `scenes/casas/sotano.tscn`: root `scripts/sotano/Sotano.gd` plus the Blender room `Cuarto` (`models/sotano/sotano.glb`).
- **Permission:** the `Fichas` autoload (`scripts/sotano/Fichas.gd`, reset per run in `Partida._otra_vez`) holds `permiso` and `fichas`.
  - With no permission, a chain at the foot of the stairs blocks the way (`CadenaChoque-colonly`). The guard takes the one-time `CUOTA` ($300) at the `MuebleCasa` beside him.
  - The Gotera missions will grant `permiso = 1` (escalón 1, `docs/misiones.md`).
- **Safehouse:** an arrow `Sotano` at (-15, 0, 40.2), always open. `.` grants permission and +50 chips.
- **Standalone test scene:** `godot --path . scenes/sotano_prueba.tscn` (`scripts/sotano/PruebaSotano.gd`; the casino is in the `.tscn`, so it shows in the editor).
  - Puts you before the chain with $1000.
  - Keys: `.` permission and chips, `P` +$500, `K` remove the permission, `H` all OL PLEY hot, `R` back to the stairs, `F12` from scratch, `F1` hides the help.
  - `-- --foto=<file.png>` saves a screenshot and quits.

## The rooms (Blender)

`tools/blender/sotano/sotano.py` builds everything in Godot coordinates (scene metres; `CasaPropia` scales by 1.25). Run it in an empty file or in `models/sotano/fuente/sotano.blend`. It exports `sotano.glb` and `gabinete_olpley.glb`.

- **Shell:**
  - Walls 0.4 thick (`GRUESO`), ceiling at 3 m, beams.
  - Stairs: solid steps with nosing, side stringers, a handrail, and a hidden walking ramp (`Rampa-colonly`).
  - Hall 1 (`SALON`, 14 × 10): the machines.
  - The arch (`ARCO`, with jambs and lintel) leads to hall 2 (`SALON2`, 10 × 8): the poker table, the bar, the bathroom door and the race track.
- **Hall 1:**
  - The Primo's window: counter at 1 m, bars 0.2 apart, a green lamp, cash box and fan, so you see him.
  - The guard and his chain.
  - Ten OL PLEY: eight on the north wall, two on the south.
  - Two fruit machines facing the room (`giro` 90).
  - The altar, the speaker, crates, two columns.
- **Hall 2:**
  - Bar: back bar with bottles, a red fridge with a lit glass door, the counter with taps, and five stools.
  - Poker table: felt, padded rail, chip stacks, a hanging lamp, three NPC chairs (`Poker_0..2`), your spot (`Poker_tu`), the dealer (`Crupier`).
  - Race track along the south wall: the horses run along +x.
  - Bathroom door; caguama freezer.
- **Name suffixes:**
  - `-convcol`: solid box.
  - `-colonly`: collision only. Must be unique, or Godot renames the body.
- **Empties `Marca_*`** place everything else: lights, neons, ads, cabinets, NPCs, seats, the walking route `Camino_*`.
- **Art:** `tools/blender/sotano/arte.py` renders, with flat Workbench and no AA (`SOLO=(...)` renders some):
  - `textures/sotano/cartas.png`: 24 lotería cards (OL PLEY reels).
  - `calcomanias.png` and `pantalla.png`: the cabinet and its idle screen.
  - `pantalla_juego.png`: the game screen background.
  - `baraja.png`: 52 cards and the El Tinaco back.
  - `anuncios.png`: six beer posters, `CERVEZAS`: Tecatl, Indita, Coronela, Modelito, Pacífica and the caguama deal.
  - `textures/maquinita/adorno_frutas.png`.
- **Materials:** `scripts/sotano/SotanoPostImport.gd` (the `.glb` import script) swaps Blender materials by name for the game's. The Blender scripts delete materials when cleaning up, because a preview texture got embedded once.

## What's inside (`Sotano.gd`)

- **Light:** eight tube lights (two fail: `PARPADEAN`), the window lamp, the poker lamp.
- **Neon signs** (`NEONES`, `Label3D` with a light; some fail): OL PLEY, ABIERTO 24 HRS, PÓKER, TECATL, BAÑO.
- **Beer posters** (`CARTELES`, one shared material per poster).
- **Games and things to use:**
  - The ten OL PLEY (`GabineteOlPley`) and the two fruit machines in chip mode.
  - The window (`VentanillaUI`), the poker (`PokerUI`), the races (`CarrerasUI`).
  - The freezer (caguama, 3 chips), the bar (a Tecatl from the bartender, 2 chips; same caguama item), the altar, the bathroom door (text).
- **People:**
  - Talkers on `npc.tscn`: guard, Primo, bartender, dealer, onlooker. The onlooker points out the hot OL PLEY.
  - Seated: four at OL PLEY and three at the poker table (`Civiles` with `Sitting_Idle`, at floor level).
  - `GenteSotano`: five walkers on fixed routes of `Camino_*` (some stay in hall 1, some go through the arch to the bar; they pause now and then) and the waitress with a tray, whose `MuebleCasa` follows her and sells a Tecatl.
- **Ambience:** the speaker loops `bocina_musica`, and the two fans spin.
- **Leaving with chips:** the Primo shouts once if you go up the stairs carrying chips.

## The games (the house cheats, with tells)

- **Chips:** $5 each (`Fichas.PRECIO`). Cashing out leaves 10% with the Primo.
- **OL PLEY:**
  - `OlPleyUI`, like the fruit machine: the camera flies to the cabinet and the game runs in a 256 × 192 `SubViewport` that the cabinet shows on its screen (`GabineteOlPley.mostrar_en_pantalla`).
  - Reels of lotería cards scroll for real and stop one by one with a bounce. The pay line blinks, the counters show bet, chips and prize, and wins play pixelfx coins (`resources/fx/olpley_monedas`, `ui/coin-collect`) or confetti for big and Tinaco wins (`olpley_confeti`). The cabinet buttons sink (`apretar`).
  - `Carretes` is the board: ~89% return, a win one spin in four, El Tinaco wild pays double. `SIN_CAJA`; `CALIENTE` makes the marquee light blink.
- **Fruit machines (everywhere):** simpler play in `TragamonedasUI`. One fruit at a time; ←/→ move the bet to another fruit, ↑/↓ coins 1–9, Space spins (with no bet it bets the last amount). The notice says which fruit and its multiplier. `Maquinita.moneda = "fichas"` charges chips and keeps them open at night.
- **Texas Hold'em:**
  - `Holdem.gd`: fixed limit (blinds 1/2, raises of 2 then 4, 3 raises per round), best 5 of 7 with Spanish names, no side pots, and the house takes 10% of each pot (up to 5).
  - AI: Doña Cuca is tight, Tacho bluffs. "El de la gorra" is the house's: from the turn on he knows whether he beats you; he raises if so and folds if not. The bartender and the onlooker drop hints.
  - `PokerUI`: the camera flies to the table. The board and the NPCs' cards (face down until showdown) sit on the felt in 3D; your two cards, the pot and everyone's last action are on screen. C check/call, R raise, F fold, Space next hand, Esc stand up. You play with your chips.
  - The NPCs' stacks persist between hands (`_fichas_vecinos`), and they rebuy at the window when broke.
- **Races:** `CarrerasUI`, odds 2/3/5/8/12, chances proportional to 1/odds. A bet of 5+ halves your horse's luck, and the house's horse trembles first (`Sotano.temblar`). `Sotano.correr` moves the horses along x.

## Tests

- `godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<dir>` (needs a window) ends with `RESULTADO: BIEN`. Steps:
  - Enter the Sótano and check the people.
  - Check the chain and the cuota.
  - Buy chips at the window.
  - Play 20 OL PLEY spins on the screen.
  - Play a poker hand.
  - Run a race.
  - Buy beers at the freezer, the bar and from the waitress.
  - Play a simple fruit spin.
  - Cash out and leave.
- `godot --path . --headless -s tools/sotano/probar_holdem.gd` runs known hands plus 2000 AI hands, with no stalls and no lost chips.

## Pending

- Real sounds (JJ picks); the games reuse `boton`, `paso`, `moneda`, and the speaker uses `bocina_musica`.
- The Gotera missions that grant `permiso`.
- Walkers pass through the player and each other (no navigation).
