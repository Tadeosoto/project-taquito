# El Sótano (the Gotera's underground casino)

AG, 2026-11-18 (branch `sotano-casino`). The story is in `docs/lore.md` §11 "El Sótano": the Gotera's casino under a grocery in Santa Mugre, which nobody calls a casino. Keep this file in sync with the code.

## Getting in

- **Door:** the `casa_vecino` marker `Sotano` in the Santa Mugre colonia JSON (and `resources/mapa/santa_mugre/marcas.json`), beside the door of the Mini Super Santa Mugre on the tianguis street. `"abierto": "noche"`: by day it says "Ahorita no, mijo". `"bodega": true` makes `Colonia._bodega` put a plastic strip curtain, soda crates and a red bulb on the facade (shared static materials).
- It's a walkable `CasaPropia` like the neighbours' houses, so combat is off inside and the entry and exit points are the usual ones (door on the west wall at z 3.11). The scene is `scenes/casas/sotano.tscn`: root `scripts/sotano/Sotano.gd` plus the Blender room `Cuarto` (`models/sotano/sotano.glb`).
- **Permission:** the `Fichas` autoload (`scripts/sotano/Fichas.gd`, reset with the run in `Partida._otra_vez`):
  - It holds `permiso` and `fichas`.
  - With no permission, a chain at the foot of the stairs blocks the way (`CadenaChoque-colonly`). The guard asks for the one-time `CUOTA` ($300), paid at the `MuebleCasa` beside him; `_quitar_cadena` frees the chain's static body and hides it.
  - The Gotera missions will grant `permiso = 1` (escalón 1, `docs/misiones.md`).
- **Safehouse:** a second arrow `Sotano` at (-15, 0, 40.2), always open; `.` grants permission and +50 chips.

## The room (Blender)

- `tools/blender/sotano/sotano.py` builds the room and the OL PLEY cabinet in Godot coordinates (scene metres; `CasaPropia` scales by 1.25). Run it in an empty file or in `models/sotano/fuente/sotano.blend`. It exports `sotano.glb` and `gabinete_olpley.glb`.
  - Name suffixes `-convcol` (solid box) and `-colonly` (collision only). Collision-only names must be unique, or Godot renames the body (`@StaticBody3D@…`).
  - The stairs are visible steps plus a hidden ramp, `Rampa-colonly`.
  - Empties `Marca_*` place everything else: lights, cabinets, NPCs, seats, the lotería table, the track, the altar, the freezer, the speaker.
  - The tin horses are `Caballo_1..5`.
- `tools/blender/sotano/arte.py` renders, with flat Workbench and no AA:
  - `textures/sotano/cartas.png`: 24 lotería cards. The drawings are Segoe UI Emoji line glyphs. The last ones belong to this world: El Apagado, La Pipa, El Machete, La Garrafa, El Camión and El Tinaco (gold frame, the wild).
  - `calcomanias.png`: the OL PLEY marquee, door, side and labels.
  - `pantalla.png`: the attract screen.
  - `textures/maquinita/adorno_frutas.png`, used by the fruit-machine adorno below.

  `SOLO=(...)` renders just some of them. If the card list changes, change `CartasLoteria.NOMBRES`/`VERSOS` too.
- `scripts/sotano/SotanoPostImport.gd` (import script of those `.glb`) swaps each Blender material by name for the game's: textures with nearest filtering, unshaded tubes, neon and screen. `sotano.py` and `maquinita.py` delete the materials when they clean up, because a preview texture left in Blender got embedded in the `.glb`.

## What's inside (`Sotano.gd`)

- Six OL PLEY (`GabineteOlPley`: model, collision box, a material per body colour) and two fruit machines in chip mode.
- The Primo's window (`VentanillaUI`).
- The lotería table (`LoteriaUI`) and the track (`CarrerasUI`).
- The freezer: a caguama for 3 chips. The altar, with text.
- People: the guard, the Primo, the caller and an onlooker, all talkers on `npc.tscn` with lines. Six seated players (`Civiles` with `Sitting_Idle`, at floor level: the clip already has the chair height).
- Ambience: six tube lights (two fail), the OL PLEY neon as a `Label3D` with a pink light, the speaker playing `bocina_musica` on a loop, and the fan (its blades reparented to a pivot).
- If you go up the stairs carrying chips, the Primo shouts once that they're worthless outside.
- **Games share `JuegoSotano`:** a full-screen panel with title, chips, a notice and help. The player is disabled while it's open and the mouse is freed. Esc closes it. `tecla()` lets the test play it. Opened through `Sotano._abrir` (group `juego_sotano`, one at a time).

## The games (the house cheats, with tells)

- **Chips:** `Fichas.PRECIO` is $5 a chip; cashing out leaves `COMISION` (10%) with the Primo. They don't expire.
- **OL PLEY, "Lotería de carretes":**
  - `Carretes` is the board (one per cabinet), with three reels, `PESOS` and `PAGOS`. A three-of-a-kind pays per the table, and El Tinaco as wild pays double. Two equal on the first reels, or a lone Tinaco, returns the bet. That's ~89% return and a win one spin in four (computed over every combination).
  - House states: `SIN_CAJA` blocks prizes the box can't cover. `CALIENTE` (4% when the box is over 300) wins the next spin for sure, and the cabinet's marquee light blinks (`GabineteOlPley.mostrar_estado`).
  - `OlPleyUI`: bet 1 to 5, the reels stop one by one.
- **Fruit machines:** `Maquinita.moneda = "fichas"` makes them charge and pay chips (`TragamonedasUI._saldo/_sumar/_bolsa`) and stay open at night. Outside they're the same as always.
- **Lotería:** `LoteriaUI`, 3 chips a board, 4 players. The caller calls a card every 2.4 s with its verse (written for the game). Patterns are a line, a column, a diagonal or the four corners. The pot minus 2 chips goes to the winner. Tacho is the plant: with probability 0.3 the deck is stacked so his first row comes out early, and he shouts faster. He never loses twice in a row.
- **Races:** `CarrerasUI`, odds 2/3/5/8/12, with chances proportional to 1/odds (~20% for the house). A bet of 5 or more halves your horse's luck. The tell: the horse the house wants trembles before the start (`Sotano.temblar`). `Sotano.correr` moves the horses in jerks; the panel hides during the race.

## Fruit-machine adorno (all machines)

- **What it is:** `tools/blender/sotano/maquinita.py` builds `models/maquinita/adorno_frutas.glb`, a dressing that `Maquinita._ready` hangs on every machine: an arched topper with bulbs and "CÓCTEL DE FRUTAS", a strawberry on top, chrome trim, a non-slip kick plate, side stickers, labels, lock, coin box and cable.
- **Why the playing mesh stays:** the playing mesh doesn't change, because `ps1_maquinita.gdshader` reads its atlas UVs and vertex colours.
- **Cost:** one atlas material plus one for the bulbs, and `visibility_range_end` 40 m. `medir_colonia`: within noise (+0.3 ms at the worst spot).
- **Gotcha:** the side gold rail of the upper body covers the side at x 0.338, so the upper stickers sit outside it (`RIEL`).
- **Photo tool:** `godot --path . tools/sotano/foto_maquinita.tscn -- --carpeta=<dir>` photographs one machine alone.

## Test

`godot --path . tools/sotano/probar_sotano.tscn -- --capturas=<dir>` (needs a window) loads the safehouse and enters the Sótano. It checks the chain and the cuota, buys chips, plays OL PLEY 20 times, a full lotería (accelerated time) and a race, buys a caguama, checks the fruit machines, cashes out and leaves. It ends with `RESULTADO: BIEN`.

## Pending

- Real sounds (JJ picks): the speaker uses `bocina_musica`, and the games reuse `boton`, `paso` and `moneda`.
- The Gotera missions that grant `permiso`.
- The onlooker's lines could point at the tells (which OL PLEY is hot, Tacho).
